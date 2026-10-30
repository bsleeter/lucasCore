# =============================================================================
# 1-study-area.R - stage 1: the model grid, the study area, and the primary, secondary and tertiary strata rasters
# =============================================================================
# Replaces the strata chunk of "Build LUCAS Model CONUS Annual NLCD FIA Update.Rmd" (L107-203), with the land mask the CONUS 1km
# model actually used (found by reproducing its rasters, 2026-10-19):
#   lattice     rast(vect(ecodivisions), res): EPSG:5070, anchored at the ecodivision bounding box (shared.R, model_lattice)
#   study area  the Study Area sheet: units of any Stratum Source (ecodivision, state, county, HUC, pyrome, ...; blank = all of CONUS).
#               A cell is in the study area when that source's raster - with the source's own fill rule for land cells no polygon
#               covers, as for strata - gives one of the units (user decision 2026-10-21: the study area no longer has to be
#               secondary strata units)
#   primary     FIA ecodivision StratumId (fixed: the growth curves are fitted on it), masked by the start-year Annual NLCD
#               aggregated to the cell size (modal) -> land cells, then by the study area
#   secondary   Build Options' Secondary Strata source (blank = States, the CONUS 1km model), on the study area's land cells
#   tertiary    likewise (blank = Federal Lands); uncovered land takes the source's fill rule
# Secondary and tertiary values are universal unit ids (source Number x 1e8 + the source's id; src/strata.R) so any source fits the
# project's stsim lists. The study area uses the same lattice and NLCD aggregation blocks as a CONUS build, so cells line up.
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
  if (!nrow(stsim_list(k))) fail("stsim %s is empty: create the library with tools/new-library.R (or File > New from the lucasCore template)", k)
ul <- stsim_list("SecondaryStratum"); ul[, Id := as.integer(Id)]
if (!all(ul$Id >= UNIT_OFFSET)) fail("this library's strata lists predate universal unit lists: run tools/new-library.R <library> --rebuild-strata")
rows <- sources_from_sheet(as.data.table(datasheet(prj, ds("StratumSource"), optional = TRUE, lookupsAsFactors = FALSE)))
if (!length(rows)) fail("Stratum Sources is empty: run tools/new-library.R")
by_num <- setNames(rows, vapply(rows, function(s) as.character(s$Number), ""))
pick <- function(v, default, what) { nm <- if (is.null(v) || !length(v) || is.na(v[1])) default else v[1]
  if (!nm %in% names(rows)) fail("Build Options: %s source '%s' is not in Stratum Sources (%s)", what, nm, paste(names(rows), collapse = ", "))
  rows[[nm]] }
sec <- pick(opt$SecondarySourceId, "States", "Secondary Strata"); ter <- pick(opt$TertiarySourceId, "Federal Lands", "Tertiary Strata")
say("Strata: primary = FIA ecodivisions; secondary = %s; tertiary = %s", sec$Preset, ter$Preset)

# ---- the study area ---------------------------------------------------------------------------------------------------
eco <- st_transform(read_sf(src$EcodivisionFile), MODEL_CRS)
if (!"StrtmId" %in% names(eco)) fail("%s has no StrtmId field", basename(src$EcodivisionFile))
L <- model_lattice(eco, res_m)
sa <- as.data.table(datasheet(scn, ds("StudyArea"), optional = TRUE, lookupsAsFactors = FALSE))
want <- if (nrow(sa)) unique(as.character(sa$UnitId)) else character()
if (length(want)) {
  uid <- ul$Id[match(want, ul$Name)]
  if (anyNA(uid)) fail("Study Area units not in the unit list: %s", paste(want[is.na(uid)], collapse = ", "))
  parts <- split(unit_native(uid), unit_source(uid))
  miss <- setdiff(names(parts), names(by_num)); if (length(miss)) fail("Study Area: no Stratum Source with Number %s", paste(miss, collapse = ", "))
  # each source's polygons for its units; the extent grows by the source's modal fill distance so coastal fill sees the same
  # neighbours, and is snapped out to the lattice
  ex <- NULL
  for (k in names(parts)) { s <- by_num[[k]]; sp <- strata_polygons(s, env$PackageDirectory); sp <- sp[sp$StratumId %in% parts[[k]], ]
    if (!nrow(sp)) fail("no %s polygons for the study area units %s", s$Preset, paste(parts[[k]], collapse = ", "))
    pad <- res_m + if (tolower(s$Fill) == "modal") as.numeric(s$FillDistance) else 0
    e <- ext(vect(sp)) + pad; ex <- if (is.null(ex)) e else union(ex, e) }
  R <- crop(L, align(intersect(ex, ext(L)), L, snap = "out"))
  say("Study area: %s (%d x %d cells of %d m)", paste(want, collapse = ", "), ncol(R), nrow(R), res_m)
} else { R <- L; say("Study area: all of CONUS (%d x %d cells of %d m)", ncol(R), nrow(R), res_m) }
progressBar()

# ---- land mask: start-year Annual NLCD, modal-aggregated (shared.R, nlcd_on_grid: same blocks as a CONUS build) --------
nf <- file.path(src$NlcdFolder, sprintf("Annual_NLCD_LndCov_%d_CU_C1V0.tif", y0))
if (!file.exists(nf)) fail("Annual NLCD %d not found: %s", y0, nf)
n <- nlcd_on_grid(nf, L, R); say("NLCD %d: modal aggregation to %d m", y0, res_m)
P <- mask(rasterize(vect(eco), R, "StrtmId"), n)
if (length(want)) {
  keep <- NULL
  for (k in names(parts)) { r <- strata_raster(by_num[[k]], env$PackageDirectory, R, P); hit <- r %in% parts[[k]]
    keep <- if (is.null(keep)) hit else keep | hit }
  P <- mask(P, keep, maskvalues = c(0, NA))
}
progressBar()

# ---- strata: the chosen sources on the study area's land cells, as universal unit ids ------------------------------------
S <- strata_raster(sec, env$PackageDirectory, R, P); um_s <- attr(S, "unmatched"); fs_ <- attr(S, "filled")
if (fs_ > 0) say("Secondary: %d land cells outside the %s polygons filled (%s)", fs_, sec$Preset, sec$Fill)
S <- S + sec$Number * UNIT_OFFSET
P <- mask(P, S)
progressBar()
Tr <- strata_raster(ter, env$PackageDirectory, R, P); um_t <- attr(Tr, "unmatched"); ft_ <- attr(Tr, "filled")
if (ft_ > 0) say("Tertiary: %d land cells outside the %s polygons filled (%s)", ft_, ter$Preset, ter$Fill)
Tr <- Tr + ter$Number * UNIT_OFFSET
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

# spatial multiprocessing (Build Options): the tile mask goes into this result, so the historical run and every projection that depend
# on the Build are split the same way (a projection may set its own in Run Settings; stage 9 then writes that one)
# Spatial Tiles: blank = one job, 0 = automatic (auto_tiles), a number = that many
tiles_in <- if ("SpatialTiles" %in% names(opt) && !is.na(opt$SpatialTiles[1])) as.integer(opt$SpatialTiles[1]) else NA_integer_
lvl <- tile_level(if ("SpatialTilesStrata" %in% names(opt)) opt$SpatialTilesStrata[1] else NA)
tu <- values(list(Primary = P, Secondary = S, Tertiary = Tr)[[lvl]], mat = FALSE)
ta <- auto_tiles(tu, !na_p); tnm <- tile_unit_name(lvl, ta$unit)
tiles <- if (is.na(tiles_in)) 1L else if (tiles_in == 0L) ta$n else tiles_in
if (!is.na(tiles_in) && tiles_in == 0L) say("Spatial tiles: automatic (Build Options) -> %d %s", tiles, if (tiles == 1) "tile: one job" else "tiles")
if (tiles > 1) {
  tl <- pack_tiles(tu, !na_p, tiles)
  if (tl$units < tiles) say("Spatial tiles: only %d %s units for %d tiles - some tiles stay empty", tl$units, lvl, tiles)
  saveDatasheet(scn, data.frame(MaskFileName = write_raster(setValues(rast(P), tl$values), "Build-Tiles.tif", "INT2U")), "core_SpatialMultiprocessing")
  say("Spatial multiprocessing: %s", tile_summary(tl, tiles, lvl))
  for (m in tile_notes(ta, tl, tiles, lvl, tnm)) say("%s", m)
  check(STAGE, "every land cell is in a tile", !any(is.na(tl$values[!na_p])), sprintf("%d cells without a tile", sum(is.na(tl$values[!na_p]))))
} else if (!is.na(tiles_in) && tiles_in == 0L) { for (m in tile_notes(ta, NULL, 1L, lvl, tnm)) say("%s", m)
} else if (is.na(tiles_in) && ta$n > 1) say("Spatial tiles: none (one job). Build Options > Split runs into tiles, automatic, would use %d tiles of whole %s units (the largest, %s, holds %.1f%% of the land)",
                                             ta$n, lvl, tnm, 100 * ta$share)

summ <- rbindlist(lapply(list(list(P, "Primary", "Stratum"), list(S, "Secondary", "SecondaryStratum"), list(Tr, "Tertiary", "TertiaryStratum")), function(lv) {
  f <- as.data.table(freq(lv[[1]]))[, .(Id = as.integer(value), Cells = as.integer(count))]
  l <- stsim_list(lv[[3]]); f[, Name := l$Name[match(Id, as.integer(l$Id))]]; f[, Level := lv[[2]]]; f[, .(Level, Name, Id, Cells)] }))
write_ds(summ, "OutputStrataSummary")
for (lv in list(list("Secondary", sec), list("Tertiary", ter)))
  say("%s: %d of %d %s units have cells", lv[[1]], summ[Level == lv[[1]], .N], sum(unit_source(ul$Id) == lv[[2]]$Number), lv[[2]]$Preset)
progressBar()
finish_checks()
progressBar(type = "end")
