# =============================================================================
# 1-study-area.R - stage 1: the model grid and the primary, secondary and tertiary strata rasters
# =============================================================================
# Replaces the strata chunk of "Build LUCAS Model CONUS Annual NLCD FIA Update.Rmd" (L107-203), with the land mask the CONUS 1km
# model actually used (found by reproducing its rasters, 2026-10-19):
#   lattice    rast(vect(ecodivisions), res): EPSG:5070, anchored at the ecodivision bounding box (shared.R, model_lattice)
#   primary    ecodivision StratumId, masked by the start-year Annual NLCD aggregated to the cell size (modal) -> land cells
#   secondary  state FIPS; cells off the state polygons (coast) take the modal state of a 59 x 59 window; masked by primary
#   tertiary   federal land manager (National Atlas ADMIN1 matched to the Tertiary Strata names); everything else 9 (Non Federal)
# A state build uses the same lattice and the same NLCD aggregation blocks as a CONUS build, then keeps the cells of its states.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
suppressPackageStartupMessages({ library(terra); library(sf) })
STAGE <- "1 Study Area"
progressBar(type = "begin", totalSteps = 6)

src <- read_data_sources(c("EcodivisionFile", "StatesFile", "FederalLandsFile", "NlcdFolder"))
opt <- read_ds("BuildOptions")
res_m <- opt$Resolution[1]; y0 <- opt$StartYear[1]; win <- opt$SecondaryFillWindow[1]; if (win %% 2 == 0) win <- win + 1
for (k in c("Stratum", "SecondaryStratum", "TertiaryStratum"))
  if (!nrow(stsim_list(k))) fail("stsim %s is empty: run stage 0 (Initialize Definitions) first", k)

# ---- inputs, all in EPSG:5070 -------------------------------------------------------------------------------------
eco <- st_transform(read_sf(src$EcodivisionFile), MODEL_CRS)
if (!all(c("StrtmId") %in% names(eco))) fail("%s has no StrtmId field", basename(src$EcodivisionFile))
states <- st_transform(read_sf(src$StatesFile), MODEL_CRS)
if (!all(c("NAME", "STATEFP") %in% names(states))) fail("%s needs fields NAME and STATEFP", basename(src$StatesFile))
states$SecondaryId <- as.integer(states$STATEFP)
fed <- st_transform(read_sf(src$FederalLandsFile), MODEL_CRS)
if (!"ADMIN1" %in% names(fed)) fail("%s has no ADMIN1 field", basename(src$FederalLandsFile))
progressBar()

# ---- the study area on the model lattice ---------------------------------------------------------------------------
L <- model_lattice(eco, res_m)
want <- trimws(strsplit(ifelse(is.na(opt$StudyAreaStates[1]), "", opt$StudyAreaStates[1]), ",")[[1]]); want <- want[nzchar(want)]
if (length(want)) {
  bad <- setdiff(want, states$NAME); if (length(bad)) fail("Study Area States not in %s: %s", basename(src$StatesFile), paste(bad, collapse = ", "))
  keep_ids <- states$SecondaryId[states$NAME %in% want]
  # the states' extent, grown by the gap-fill window so coastal fill sees the same neighbours, snapped out to the lattice
  e <- ext(vect(states[states$NAME %in% want, ])) + win * res_m
  R <- crop(L, align(intersect(e, ext(L)), L, snap = "out"))
  say("Study area: %s (%d x %d cells of %d m)", paste(want, collapse = ", "), ncol(R), nrow(R), res_m)
} else { R <- L; keep_ids <- states$SecondaryId; say("Study area: CONUS (%d x %d cells of %d m)", ncol(R), nrow(R), res_m) }

# ---- land mask: start-year Annual NLCD, modal-aggregated ------------------------------------------------------------
# The aggregation blocks are fixed to the CONUS crop the original build used (lattice extent + one block, snapped to the NLCD
# 30 m grid), so a state build aggregates exactly the same 30 m pixels into each cell as a CONUS build does.
nf <- file.path(src$NlcdFolder, sprintf("Annual_NLCD_LndCov_%d_CU_C1V0.tif", y0))
if (!file.exists(nf)) fail("Annual NLCD %d not found: %s", y0, nf)
n30 <- rast(nf); fact <- round(res_m / res(n30)[1]); blk <- fact * res(n30)[1]
# NLCD's Albers WKT differs from EPSG:5070 only in naming, so extents are used as they are (as the original build did)
conus <- ext(crop(n30, ext(L) + blk))
want_e <- ext(R) + blk
x0 <- xmin(conus) + floor((xmin(want_e) - xmin(conus)) / blk) * blk; y0e <- ymin(conus) + floor((ymin(want_e) - ymin(conus)) / blk) * blk
x1 <- min(xmax(conus), xmin(conus) + ceiling((xmax(want_e) - xmin(conus)) / blk) * blk)
y1 <- min(ymax(conus), ymin(conus) + ceiling((ymax(want_e) - ymin(conus)) / blk) * blk)
n <- crop(n30, ext(max(x0, xmin(conus)), x1, max(y0e, ymin(conus)), y1))
say("NLCD %d: aggregating %d x %d pixels by %d (modal)", y0, ncol(n), nrow(n), fact)
n <- aggregate(n, fact = fact, fun = "modal", na.rm = TRUE)
n <- project(n, R, method = "near")
progressBar()

# ---- strata ---------------------------------------------------------------------------------------------------------
P <- mask(rasterize(vect(eco), R, "StrtmId"), n)
S <- rasterize(vect(states), R, "SecondaryId")
S <- mask(cover(S, focal(S, w = matrix(1, win, win), fun = "modal", na.policy = "only", na.rm = TRUE)), P)
S[!(S %in% keep_ids)] <- NA
P <- mask(P, S)
progressBar()

tl <- stsim_list("TertiaryStratum")
fed$TertiaryId <- as.integer(tl$Id[match(fed$ADMIN1, tl$Name)])
unmatched <- sort(unique(fed$ADMIN1[is.na(fed$TertiaryId)]))
if (length(unmatched)) say("Federal lands with no Tertiary Strata name (counted as Non Federal): %s", paste(unmatched, collapse = ", "))
non_fed <- as.integer(tl$Id[tl$Name == "Non Federal"]); if (length(non_fed) != 1) fail("Tertiary Strata has no single 'Non Federal' row")
Tr <- rasterize(vect(fed[!is.na(fed$TertiaryId), ]), R, "TertiaryId")
Tr <- mask(cover(Tr, init(R, non_fed)), P)
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
progressBar()
finish_checks()
progressBar(type = "end")
