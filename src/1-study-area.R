# =============================================================================
# 1-study-area.R - stage 1: the model grid and the primary, secondary and tertiary strata rasters
# =============================================================================
# Replaces the strata chunk of "Build LUCAS Model CONUS Annual NLCD FIA Update.Rmd" (L107-203), with the land mask the CONUS 1km
# model actually used (found by reproducing its rasters, 2026-10-19):
#   lattice    rast(vect(ecodivisions), res): EPSG:5070, anchored at the ecodivision bounding box (shared.R, model_lattice)
#   primary    FIA ecodivision StratumId (fixed: the growth curves are fitted on it), masked by the start-year Annual NLCD
#              aggregated to the cell size (modal) -> land cells
#   secondary  from the project's Stratum Sources row (any polygon source; States in the CONUS 1km model), masked by primary
#   tertiary   likewise (Federal Lands in the CONUS 1km model); uncovered land takes the row's fill rule
# The study area is a set of secondary strata units (blank = all). It uses the same lattice and the same NLCD aggregation
# blocks as a CONUS build, so a regional build lands on the same cells.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "strata.R"))
suppressPackageStartupMessages({ library(terra); library(sf) })
STAGE <- "1 Study Area"
progressBar(type = "begin", totalSteps = 6)

src <- read_data_sources(c("EcodivisionFile", "NlcdFolder"))
opt <- read_ds("BuildOptions")
res_m <- opt$Resolution[1]; y0 <- opt$StartYear[1]
for (k in c("Stratum", "SecondaryStratum", "TertiaryStratum"))
  if (!nrow(stsim_list(k))) fail("stsim %s is empty: create the library with tools/new-library.R", k)
ss <- as.data.table(datasheet(prj, ds("StratumSource"), optional = TRUE, lookupsAsFactors = FALSE))
for (lv in c("Secondary", "Tertiary")) if (!lv %in% ss$Level) fail("Stratum Sources has no %s row: run tools/new-library.R", lv)
sec <- strata_row(ss[Level == "Secondary"]); ter <- strata_row(ss[Level == "Tertiary"])
say("Strata: primary = FIA ecodivisions; secondary = %s; tertiary = %s", sec$Preset, ter$Preset)

# ---- the study area on the model lattice ---------------------------------------------------------------------------
eco <- st_transform(read_sf(src$EcodivisionFile), MODEL_CRS)
if (!"StrtmId" %in% names(eco)) fail("%s has no StrtmId field", basename(src$EcodivisionFile))
L <- model_lattice(eco, res_m)
sl <- stsim_list("SecondaryStratum")
want <- trimws(strsplit(ifelse(is.na(opt$StudyAreaUnits[1]), "", opt$StudyAreaUnits[1]), ",")[[1]]); want <- want[nzchar(want)]
if (length(want)) {
  bad <- setdiff(want, sl$Name); if (length(bad)) fail("Study Area names not in the Secondary Strata list (%s): %s", sec$Preset, paste(bad, collapse = ", "))
  keep_ids <- as.integer(sl$Id[match(want, sl$Name)])
  sp <- strata_polygons(sec, env$PackageDirectory); sp <- sp[sp$StratumId %in% keep_ids, ]
  if (!nrow(sp)) fail("no %s polygons for the study area", sec$Preset)
  # the units' extent, grown by the modal fill distance so coastal fill sees the same neighbours, snapped out to the lattice
  pad <- res_m + if (tolower(sec$Fill) == "modal") as.numeric(sec$FillDistance) else 0
  R <- crop(L, align(intersect(ext(vect(sp)) + pad, ext(L)), L, snap = "out"))
  say("Study area: %s (%d x %d cells of %d m)", paste(want, collapse = ", "), ncol(R), nrow(R), res_m)
} else { R <- L; keep_ids <- as.integer(sl$Id); say("Study area: all of CONUS (%d x %d cells of %d m)", ncol(R), nrow(R), res_m) }
progressBar()
# ---- land mask: start-year Annual NLCD, modal-aggregated (shared.R, nlcd_on_grid: same blocks as a CONUS build) --------
nf <- file.path(src$NlcdFolder, sprintf("Annual_NLCD_LndCov_%d_CU_C1V0.tif", y0))
if (!file.exists(nf)) fail("Annual NLCD %d not found: %s", y0, nf)
n <- nlcd_on_grid(nf, L, R); say("NLCD %d: modal aggregation to %d m", y0, res_m)
progressBar()

# ---- strata ---------------------------------------------------------------------------------------------------------
P <- mask(rasterize(vect(eco), R, "StrtmId"), n)
S <- strata_raster(sec, env$PackageDirectory, R, P); um_s <- attr(S, "unmatched")
if (attr(S, "filled") > 0) say("Secondary: %d land cells outside the %s polygons filled (%s)", attr(S, "filled"), sec$Preset, sec$Fill)
S[!(S %in% keep_ids)] <- NA
P <- mask(P, S)
progressBar()
Tr <- strata_raster(ter, env$PackageDirectory, R, P); um_t <- attr(Tr, "unmatched")
if (attr(Tr, "filled") > 0) say("Tertiary: %d land cells outside the %s polygons filled (%s)", attr(Tr, "filled"), ter$Preset, ter$Fill)
for (u in list(list(um_s, "Secondary"), list(um_t, "Tertiary"))) if (length(u[[1]]))
  say("%s: source values with no crosswalk id (treated as uncovered): %s", u[[2]], paste(u[[1]], collapse = ", "))
progressBar()

# ---- checks and outputs ---------------------------------------------------------------------------------------------
na_p <- is.na(values(P, mat = FALSE)); na_s <- is.na(values(S, mat = FALSE)); na_t <- is.na(values(Tr, mat = FALSE))
check(STAGE, "study area has cells", sum(!na_p) > 0, sprintf("%d cells", sum(!na_p)))
check(STAGE, "strata cover the same cells", !any(xor(na_p, na_s)) && !any(xor(na_p, na_t)),
      sprintf("primary-only %d, secondary-only %d, tertiary mismatch %d", sum(!na_p & na_s), sum(na_p & !na_s), sum(xor(na_p, na_t))))
for (lv in list(list(P, "Stratum"), list(S, "SecondaryStratum"), list(Tr, "TertiaryStratum"))) {
  miss <- raster_ids_in_list(lv[[1]], lv[[2]])
  check(STAGE, sprintf("%s raster values are stsim %s Ids", lv[[2]], lv[[2]]), !length(miss),
        if (length(miss)) sprintf("not in the list: %s", paste(miss, collapse = ", ")) else "") }

fp <- write_raster(P, "PrimaryStrata.tif"); fs <- write_raster(S, "SecondaryStrata.tif"); ft <- write_raster(Tr, "TertiaryStrata.tif")
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
row <- if (nrow(ic)) ic[1] else data.table(StratumFileName = NA_character_)
row$StratumFileName <- fp; row$SecondaryStratumFileName <- fs; row$TertiaryStratumFileName <- ft
saveDatasheet(scn, as.data.frame(row), "stsim_InitialConditionsSpatial")

summ <- rbindlist(lapply(list(list(P, "Primary", "Stratum"), list(S, "Secondary", "SecondaryStratum"), list(Tr, "Tertiary", "TertiaryStratum")), function(lv) {
  f <- as.data.table(freq(lv[[1]]))[, .(Id = as.integer(value), Cells = as.integer(count))]
  l <- stsim_list(lv[[3]]); f[, Name := l$Name[match(Id, as.integer(l$Id))]]; f[, Level := lv[[2]]]; f[, .(Level, Name, Id, Cells)] }))
write_ds(summ, "OutputStrataSummary")
# units of each list with no cell: expected for a regional build, a warning sign for a CONUS one (the 2026-10-19 bounding-box bug
# dropped 18 northern-border counties this way)
for (lv in list(c("Secondary", "SecondaryStratum"), c("Tertiary", "TertiaryStratum"))) { l <- stsim_list(lv[2])
  say("%s: %d of %d %s units have cells", lv[1], summ[Level == lv[1], .N], nrow(l), ss[Level == lv[1]]$Preset) }
progressBar()
finish_checks()
progressBar(type = "end")
