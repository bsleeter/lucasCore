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
say(software_line())
STAGE <- "1 Study Area"; stage_begin()
progressBar(type = "begin", totalSteps = 6)

src <- read_data_sources(c("EcodivisionFile", "NlcdFolder"))
opt <- read_ds("BuildOptions")
res_m <- opt$Resolution[1]; y0 <- opt$StartYear[1]
for (k in c("Stratum", "SecondaryStratum"))   # (the Tertiary Stratum list starts empty: this stage adds the strata the Build has, below)
  if (!nrow(stsim_list(k))) fail("stsim %s is empty: create the library with tools/new-library.R (or File > New from the lucasCore template)", k)
ul <- stsim_list("SecondaryStratum"); ul[, Id := as.integer(Id)]
if (!all(ul$Id >= UNIT_OFFSET)) fail("this library's strata lists predate universal unit lists: run tools/new-library.R <library> --rebuild-strata")
rows <- sources_from_sheet(as.data.table(datasheet(prj, ds("StratumSource"), optional = TRUE, lookupsAsFactors = FALSE)))
if (!length(rows)) fail("Stratum Sources is empty: run tools/new-library.R")
by_num <- setNames(rows, vapply(rows, function(s) as.character(s$Number), ""))
pick <- function(v, default, what) { nm <- if (is.null(v) || !length(v) || is.na(v[1])) default else v[1]
  if (!nm %in% names(rows)) fail("Build Options: %s source '%s' is not in Stratum Sources (%s)", what, nm, paste(names(rows), collapse = ", "))
  rows[[nm]] }
SMALL_UNIT_CELLS <- 25L
sec <- pick(opt$SecondarySourceId, "States", "Secondary Strata"); ter <- pick(opt$TertiarySourceId, "Federal Lands", "Tertiary Strata")
say("Strata: primary = FIA ecodivisions; secondary = %s; tertiary = %s", sec$Preset, ter$Preset)

# ---- the study area ---------------------------------------------------------------------------------------------------
eco <- st_transform(read_sf(src$EcodivisionFile), MODEL_CRS)
if (!"StrtmId" %in% names(eco)) fail("%s has no StrtmId field", basename(src$EcodivisionFile))
L <- model_lattice(eco, res_m)
sa <- as.data.table(datasheet(scn, ds("StudyArea"), optional = TRUE, lookupsAsFactors = FALSE))
want <- if (nrow(sa)) unique(as.character(sa$UnitId)) else character()
# the user's own boundary file replaces the named units (Study Area page, "A boundary file"; shared.R, study_boundary)
bd <- tryCatch(study_boundary(original = TRUE), error = function(e) fail("%s", conditionMessage(e)))
if (!is.null(bd)) {
  if (length(want)) say("Study area: the boundary file is used; the %d named unit%s on the Study Area page %s ignored", length(want), if (length(want) == 1) "" else "s", if (length(want) == 1) "is" else "are")
  want <- character()
  ex <- intersect(ext(vect(bd$poly)) + res_m, ext(L)); if (is.null(ex)) fail("Study Area boundary file: %s lies outside the model's grid", basename(bd$file))
  R <- crop(L, align(ex, L, snap = "out"))
  say("Study area: %s, the polygons of %s (%.0f km2; %d x %d cells of %d m)", bd$name, bd$file, as.numeric(st_area(bd$poly)) / 1e6, ncol(R), nrow(R), res_m)
} else if (length(want)) {
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
if (length(want) || !is.null(bd)) {
  # a Build whose own Study Area page is empty takes the study area of a scenario it depends on (SyncroSim's dependencies: a Data
  # Download scenario, so the units are entered once; user 2026-11-21). The result holds the rows either way, so the log says which
  sa_from <- tryCatch({ me <- as.integer(rs_me()); tb <- rs_table(ds("StudyArea")); tb2 <- rs_table(ds("StudyAreaBoundary"))
    p <- rs_sql(sprintf("select ScenarioId from core_ScenarioResult where ResultId = %d", me))$ScenarioId; p <- if (length(p)) as.integer(p[1]) else me
    if (rs_sql(sprintf("select (select count(*) from \"%s\" where ScenarioId = %d) + (select count(*) from \"%s\" where ScenarioId = %d and BoundaryFileName is not null) n", tb, p, tb2, p))$n > 0) NULL else {
      d <- rs_sql(sprintf("select d.DependencyId id, s.Name nm from core_ScenarioDependency d join core_Scenario s on s.ScenarioId = d.DependencyId where d.ScenarioId = %d and (exists (select 1 from \"%s\" a where a.ScenarioId = d.DependencyId) or exists (select 1 from \"%s\" b where b.ScenarioId = d.DependencyId and b.BoundaryFileName is not null)) order by d.Priority", p, tb, tb2))
      if (nrow(d)) sprintf("%s [%d]", d$nm[1], d$id[1]) else NULL } }, error = function(e) NULL)
  if (!is.null(sa_from)) say("Study area: taken from the scenario this Build depends on, %s (the Build's own Study Area page is empty)", sa_from)
}
home_coverage(R)   # every Data Source read from the home folder must hold the study area (shared.R)
progressBar()

# ---- land mask: start-year Annual NLCD, modal-aggregated (shared.R, nlcd_on_grid: same blocks as a CONUS build) --------
nf <- nlcd_file(src$NlcdFolder, y0)
if (!file.exists(nf)) fail("Annual NLCD %d not found: %s", y0, nf)
n <- nlcd_on_grid(nf, L, R); say("NLCD %d: modal aggregation to %d m", y0, res_m)
P <- mask(rasterize(vect(eco), R, "StrtmId"), n)
if (!is.null(bd)) { P <- mask(P, rasterize(vect(bd$poly), R, 1))   # (a cell is in when its centre is)
} else if (length(want)) {
  keep <- NULL
  for (k in names(parts)) { r <- strata_raster(by_num[[k]], env$PackageDirectory, R, P); hit <- r %in% parts[[k]]
    keep <- if (is.null(keep)) hit else keep | hit }
  P <- mask(P, keep, maskvalues = c(0, NA))
}
progressBar()

# ---- strata: the chosen sources on the study area's land cells, as universal unit ids ------------------------------------
# (strata_units: universal unit ids. A stack - Land Manager, Land Designation - takes each cell's unit from the first of its sources
# that covers the cell, and says which gave how many cells: a source listed below ones that cover it gives none)
stack_say <- function(level, s, r) { n <- attr(r, "cells"); if (is.null(n)) return(invisible())
  say("%s: %s takes each cell from the first of its sources that covers it: %s; the other %d cells from %s", level, s$Preset,
      paste(sprintf("%s %d cells", names(n), n), collapse = ", "), attr(r, "filled"), attr(r, "rest"))
  if (any(n == 0)) say("%s: no cells from %s (no unit of %s in the study area, or the sources above cover it)", level, paste(names(n)[n == 0], collapse = ", "),
                       if (sum(n == 0) == 1) "it" else "them") }
S <- strata_units(sec, env$PackageDirectory, R, P, rows); um_s <- attr(S, "unmatched"); fs_ <- attr(S, "filled"); num_s <- attr(S, "numbers")
if (fs_ > 0 && is.null(attr(S, "cells"))) say("Secondary: %d land cells outside the %s polygons filled (%s)", fs_, sec$Preset, sec$Fill)
stack_say("Secondary", sec, S)
P <- mask(P, S)
progressBar()
Tr <- strata_units(ter, env$PackageDirectory, R, P, rows); um_t <- attr(Tr, "unmatched"); ft_ <- attr(Tr, "filled"); num_t <- attr(Tr, "numbers")
if (ft_ > 0 && is.null(attr(Tr, "cells"))) say("Tertiary: %d land cells outside the %s polygons filled (%s)", ft_, ter$Preset, ter$Fill)
stack_say("Tertiary", ter, Tr)
for (u in list(list(um_s, "Secondary"), list(um_t, "Tertiary"))) if (length(u[[1]]))
  say("%s: source values with no crosswalk id (treated as uncovered): %s", u[[2]], paste(u[[1]], collapse = ", "))
# units the study area does not name leave it (strata.R, strata_unnamed): boundary slivers of other units, and the few cells no
# polygon of a slot covers. Each is named in the log with its cells; a unit not named that holds 1% of the land or more is kept and said
if (length(want)) {
  gone <- NULL
  for (lv in list(list("Secondary", S, num_s), list("Tertiary", Tr, num_t))) {
    dflt <- unlist(lapply(rows, function(m) if (as.integer(m$Number) %in% lv[[3]] && !is.na(m$DefaultId)) as.numeric(m$Number) * UNIT_OFFSET + as.numeric(m$DefaultId)))
    d <- strata_unnamed(values(lv[[2]], mat = FALSE), uid, lv[[3]], dflt); if (!nrow(d)) next
    d[, Name := ul$Name[match(Id, ul$Id)]]; rm_ <- d[Drop == TRUE]; kp <- d[Drop == FALSE & Default == FALSE]
    if (nrow(rm_)) { say("%s: %d unit%s the study area does not name removed from it (%d cells): %s", lv[[1]], nrow(rm_), if (nrow(rm_) == 1) "" else "s", sum(rm_$Cells),
                         paste(sprintf("%s %d%s", rm_$Name, rm_$Cells, ifelse(rm_$Default, " (cells no unit covers, under 0.1% of the land)", "")), collapse = "; "))
      hit <- lv[[2]] %in% rm_$Id; gone <- if (is.null(gone)) hit else gone | hit }
    if (nrow(kp)) say("%s: kept though the study area does not name %s (1%% of the land or more, so not a sliver): %s. These are cells of a named unit of another kind; add the unit to the Study Area page if all of it is wanted",
                      lv[[1]], if (nrow(kp) == 1) "it" else "them", paste(sprintf("%s %d cells (%.1f%%)", kp$Name, kp$Cells, 100 * kp$Share), collapse = "; ")) }
  if (!is.null(gone)) { P <- mask(P, gone, maskvalues = 1); S <- mask(S, P); Tr <- mask(Tr, P) }
}
# the tertiary strata of this Build join the project's Tertiary Stratum list, which holds only the strata Builds use (shared.R)
tadd <- tryCatch(define_tertiary_strata(Tr, ul), error = function(e) fail("Tertiary strata: %s", conditionMessage(e)))
if (length(tadd)) say("Tertiary strata: %d unit%s added to the project's Tertiary Stratum list (%s%s). The list holds only the strata Builds use: ST-Sim's summary output costs time for every stratum defined",
                      length(tadd), if (length(tadd) == 1) "" else "s", paste(utils::head(tadd, 8), collapse = "; "), if (length(tadd) > 8) sprintf("; and %d more", length(tadd) - 8) else "")
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

# the boundary file's outline stays with the result (Build Results > Study Area Boundary): GeoJSON in longitude and latitude, which is
# written the same byte for byte each time, so a stage that reads it is still copied when stage 1 runs again on the same file
if (!is.null(bd)) { bf <- file.path(TD(), "study-area-boundary.geojson"); if (file.exists(bf)) file.remove(bf)
  write_sf(st_sf(name = bd$name, geometry = st_transform(bd$poly, 4326)), bf, driver = "GeoJSON", quiet = TRUE)
  write_ds(data.table(Name = bd$name, SourceFile = bd$file, Sha256 = digest::digest(file = bd$file, algo = "sha256"), AreaKm2 = round(as.numeric(st_area(bd$poly)) / 1e6, 1), BoundaryFileName = bf), "OutputStudyBoundary")
  say("Study area: the outline is kept with this result (Build Results > Study Area Boundary), so the model record and a data release carry it") }
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
# Grid (user 2026-11-21; shared.R, grid_tiles): rectangles of about equal land cells, whatever the strata. They split strata units, so
# they serve the historical run (its change comes from maps, its only targets are zeros); stage 9 gives a projection whole-unit tiles
grid <- "SpatialTilesStrata" %in% names(opt) && is_grid_level(opt$SpatialTilesStrata[1])
if (grid) {
  tiles <- if (is.na(tiles_in)) 1L else if (tiles_in == 0L) auto_grid(sum(!na_p)) else tiles_in
  if (!is.na(tiles_in) && tiles_in == 0L) say("Spatial tiles: automatic (Build Options) -> %d grid %s (the square root of the study area's %s land cells in thousands, capped by the %d cores: past that, merging the tiles costs more than smaller tiles save)", tiles,
                                              if (tiles == 1) "tile: one job" else "tiles", format(sum(!na_p), big.mark = ","), parallel::detectCores())
  if (tiles > 1) { g <- grid_tiles(!na_p, nrow(P), ncol(P), tiles)
    saveDatasheet(scn, data.frame(MaskFileName = write_raster(setValues(rast(P), g$values), "Build-Tiles.tif", "INT2U")), "core_SpatialMultiprocessing")
    say("Spatial multiprocessing: %s", grid_summary(g, res_m)); for (m in grid_notes(g)) say("%s", m)
    check(STAGE, "every land cell is in a tile", !any(is.na(g$values[!na_p])), sprintf("%d cells without a tile", sum(is.na(g$values[!na_p])))) }
} else {
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
}

summ <- rbindlist(lapply(list(list(P, "Primary", "Stratum"), list(S, "Secondary", "SecondaryStratum"), list(Tr, "Tertiary", "TertiaryStratum")), function(lv) {
  f <- as.data.table(freq(lv[[1]]))[, .(Id = as.integer(value), Cells = as.integer(count))]
  l <- stsim_list(lv[[3]]); f[, Name := l$Name[match(Id, as.integer(l$Id))]]; f[, Level := lv[[2]]]; f[, .(Level, Name, Id, Cells)] }))
write_ds(summ, "OutputStrataSummary")
for (lv in list(list("Secondary", sec, num_s), list("Tertiary", ter, num_t))) {
  say("%s: %d of %d %s units have cells", lv[[1]], summ[Level == lv[[1]], .N], sum(unit_source(ul$Id) %in% lv[[3]]), lv[[2]]$Preset)
  # small units are kept (a park's land outside its wilderness can be small and matter) and named, so a boundary sliver is seen
  sm <- summ[Level == lv[[1]] & Cells < SMALL_UNIT_CELLS][order(Cells)]
  if (nrow(sm)) say("%s: %d unit%s under %d cells (kept: named in the study area, or of a kind the study area names no unit of): %s%s", lv[[1]], nrow(sm), if (nrow(sm) == 1) "" else "s", SMALL_UNIT_CELLS,
                    paste(sprintf("%s %d", head(sm$Name, 12), head(sm$Cells, 12)), collapse = "; "), if (nrow(sm) > 12) sprintf("; and %d more (Build Results > Strata Summary)", nrow(sm) - 12) else "") }
progressBar()
finish_checks()
stage_done()
progressBar(type = "end")
