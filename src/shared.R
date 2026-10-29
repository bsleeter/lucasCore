# =============================================================================
# shared.R - helpers used by every lucasCore transformer
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })

# SyncroSim Studio points PROJ at its own bundled database, which terra's newer PROJ cannot read (every projection then fails
# with "Cannot find coordinate operations"). The console does not set it. Same fix as lucasFireC2F.
# (the path may be the 8.3 short form, C:/PROGRA~1/SYNCRO~1, so match case-insensitively on "syncro"). Parallel workers call it too.
clear_syncrosim_proj <- function() for (v in c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA")) if (grepl("syncro", tolower(Sys.getenv(v)), fixed = TRUE)) Sys.unsetenv(v)
clear_syncrosim_proj()

PKG <- "lucasCore"
ds  <- function(name) paste0(PKG, "_", name)

# datasheet reads retry: the console occasionally fails a read with "Object reference not set to an instance of an object"
datasheet <- function(...) { for (k in 1:3) { r <- tryCatch(rsyncrosim::datasheet(...), error = function(e) e)
    if (!inherits(r, "error")) return(r)
    if (k < 3) { message("datasheet read failed (", conditionMessage(r), "); retrying"); Sys.sleep(3 * k) } }
  stop(r) }

# the running scenario and environment (namespaced: terra also exports project())
env <- rsyncrosim::ssimEnvironment()
lib <- suppressWarnings(rsyncrosim::ssimLibrary())
scn <- rsyncrosim::scenario()
prj <- rsyncrosim::project()

# stop with a message SyncroSim shows in the run log; log a line
fail <- function(...) stop(sprintf(...), call. = FALSE)
say  <- function(...) updateRunLog(sprintf(...))

# a datasheet of this package as a data.table; an empty option sheet comes back as one row of the package defaults
DEFAULTED_SHEETS <- c("BuildOptions", "GrowthOptions", "ClimateOptions", "CarbonOptions", "ProjectionOptions", "SuitabilityOptions")
read_ds <- function(name, ...) { x <- as.data.table(datasheet(scn, ds(name), optional = TRUE, lookupsAsFactors = FALSE, ...))
  if (!nrow(x) && name %in% DEFAULTED_SHEETS) { d <- sheet_defaults(name); if (!is.null(d)) x <- d }
  # a single-row sheet saved with some columns blank takes the default for those columns
  if (nrow(x) == 1 && name %in% DEFAULTED_SHEETS) { d <- sheet_defaults(name, quiet = TRUE)
    for (k in names(d)) if (k %in% names(x) && is.na(x[[k]][1]) && !is.na(d[[k]][1])) x[[k]] <- d[[k]] }
  x }

# the last projection year: Projection Options (Run Settings), else Build Options' legacy column (libraries made before 2026-10-24),
# else 2100
projection_end <- function() {
  po <- as.data.table(datasheet(scn, ds("ProjectionOptions"), optional = TRUE, lookupsAsFactors = FALSE))
  v <- if (nrow(po) && "ProjectionEndYear" %in% names(po)) po$ProjectionEndYear[1] else NA
  if (is.na(v)) { b <- as.data.table(datasheet(scn, ds("BuildOptions"), optional = TRUE, lookupsAsFactors = FALSE))
    v <- if (nrow(b) && "ProjectionEndYear" %in% names(b)) b$ProjectionEndYear[1] else NA }
  if (is.na(v)) 2100L else as.integer(v) }

# the defaultValue of each column of a sheet in package.xml, as one row
.defaults_said <- new.env()
sheet_defaults <- function(name, quiet = FALSE) {
  xml <- paste(readLines(file.path(env$PackageDirectory, "package.xml"), warn = FALSE), collapse = "\n")
  blk <- regmatches(xml, regexpr(sprintf('(?s)<dataSheet name="%s"[^>]*(?<!/)>.*?</dataSheet>', name), xml, perl = TRUE))
  if (!length(blk)) return(NULL)
  cols <- regmatches(blk, gregexpr('<column [^>]*>', blk))[[1]]
  att <- function(tag, a) { m <- regmatches(tag, regexpr(sprintf('%s="[^"]*"', a), tag)); if (length(m)) sub('^[^"]*"(.*)"$', "\\1", m) else NA_character_ }
  out <- list()
  for (tg in cols) { k <- att(tg, "name"); v <- att(tg, "defaultValue"); ty <- att(tg, "dataType")
    out[[k]] <- switch(ty, Integer = as.integer(v), Double = as.numeric(v), Boolean = if (is.na(v)) NA else v != "0", v) }
  if (all(vapply(out, is.na, TRUE))) return(NULL)
  if (!quiet && is.null(.defaults_said[[name]])) { .defaults_said[[name]] <- TRUE
    shown <- out[!vapply(out, is.na, TRUE)]
    say("%s is empty: using the package defaults (%s)", name, paste(names(shown), unlist(lapply(shown, as.character)), sep = " = ", collapse = ", ")) }
  as.data.table(out) }

# the project's Data Sources: a blank cell (or an empty sheet) takes the package default path; required columns must exist on disk
read_data_sources <- function(cols) {
  d <- as.data.table(datasheet(prj, ds("DataSource"), lookupsAsFactors = FALSE, optional = TRUE))
  def <- sheet_defaults("DataSource", quiet = TRUE)
  out <- list()
  for (k in cols) { v <- if (nrow(d) && k %in% names(d)) d[[k]][1] else NA_character_
    if (is.na(v) || !nzchar(v)) v <- def[[k]][1]
    if (is.null(v) || is.na(v) || !nzchar(v)) fail("Data Sources: %s is not set and has no default", k)
    if (!file.exists(v)) fail("Data Sources: %s not found (%s)", k, v)
    out[[k]] <- v }
  out }

# saveDatasheet goes through text: whole-number doubles go as integers and nothing is written in scientific notation
options(scipen = 999)
int_cols <- function(x) { x <- as.data.frame(x)
  for (k in names(x)) if (is.double(x[[k]]) && all(is.na(x[[k]]) | (x[[k]] == round(x[[k]]) & abs(x[[k]]) < .Machine$integer.max))) x[[k]] <- as.integer(x[[k]])
  x }
write_ds   <- function(x, name, ...) saveDatasheet(scn, int_cols(x), ds(name), ...)
write_stsim <- function(x, name, target = scn, ...) saveDatasheet(target, int_cols(x), paste0("stsim_", name), ...)

# the library the user opened. With multiprocessing on, SyncroSim runs a stage in a copy of it
# (<library>.temp/MultiProc/Scenario-N/tK/Job-1.ssim), whose .data folder holds no other scenario's files (found 2026-10-23:
# Projection Start could not find the historical run's maps)
main_library <- function() sub("\\.temp[/\\\\]MultiProc[/\\\\].*$", "", normalizePath(env$LibraryFilePath, winslash = "/", mustWork = FALSE))

# Transition Size Distribution / Size Prioritization rows for some groups, keeping every other group's rows (stages 9 and 10 each write
# their own groups'; a later stage, or stage 9 rerun in a projection, must not drop the others). Rows carry Timestep = the historical
# end + 1 so a continuous run's historical years keep their exact maps (found 2026-10-23).
write_size_dist <- function(sd, pri, groups, ts) {
  had <- c(); keep <- function(name) { x <- as.data.table(datasheet(scn, paste0("stsim_", name), optional = TRUE, lookupsAsFactors = FALSE)); had[name] <<- nrow(x) > 0
    if (nrow(x)) x <- x[!TransitionGroupId %in% groups]; x[, setdiff(names(x), c(paste0(name, "Id"), "ScenarioId")), with = FALSE] }
  if (nrow(sd)) sd[, Timestep := as.integer(ts)]; if (nrow(pri)) pri[, Timestep := as.integer(ts)]
  a <- rbind(keep("TransitionSizeDistribution"), sd, fill = TRUE); b <- rbind(keep("TransitionSizePrioritization"), pri, fill = TRUE)
  # an emptied sheet is written empty too, or the result would keep the dependency's rows
  if (nrow(a) || had[["TransitionSizeDistribution"]]) write_stsim(a, "TransitionSizeDistribution")
  if (nrow(b) || had[["TransitionSizePrioritization"]]) write_stsim(b, "TransitionSizePrioritization")
  invisible(nrow(a)) }

# a package file (defaults/...) as a data.table, every column as read
pkg_file <- function(...) file.path(env$PackageDirectory, ...)
read_default <- function(...) { f <- pkg_file("defaults", ...); if (!file.exists(f)) fail("package default %s is missing", f)
  fread(f, sep = ",", colClasses = "character", na.strings = "", encoding = "UTF-8") }

# Carbon Assumptions - Dead Organic Matter Parameters (to-do 21): the scenario's rows (from its Carbon Assumptions dependency), else the
# package default (defaults/cbm/dom-parameters.csv); logs every row that differs from the default. Columns as the sheet, Pool as its label.
read_dom_parameters <- function() {
  def <- read_default("cbm", "dom-parameters.csv")[, .(StratumId = NA_character_, Pool, BaseDecayRate = as.numeric(BaseDecayRate),
          ReferenceTemperature = as.numeric(ReferenceTemperature), Q10 = as.numeric(Q10), ShareEmitted = as.numeric(ShareEmitted), TransferToBGSlow = as.numeric(TransferToBGSlow))]
  x <- as.data.table(datasheet(scn, ds("DomParameter"), optional = TRUE, lookupsAsFactors = FALSE))
  if (!nrow(x)) { say("Dead Organic Matter Parameters: none in this scenario (no Carbon Assumptions dependency) - the package default (CBM-CFS3)"); return(def) }
  pl <- def$Pool; if (is.numeric(x$Pool)) x[, Pool := pl[Pool]]
  x <- x[, .(StratumId = as.character(StratumId), Pool = as.character(Pool), BaseDecayRate = as.numeric(BaseDecayRate), ReferenceTemperature = as.numeric(ReferenceTemperature),
             Q10 = as.numeric(Q10), ShareEmitted = as.numeric(ShareEmitted), TransferToBGSlow = as.numeric(TransferToBGSlow))]
  bad <- setdiff(pl, x[is.na(StratumId), Pool]); if (length(bad)) fail("Dead Organic Matter Parameters: no all-ecodivisions row for %s", paste(bad, collapse = ", "))
  m <- merge(x, def[, -"StratumId"], by = "Pool", suffixes = c("", "_def"))
  d <- m[!is.na(StratumId) | abs(BaseDecayRate - BaseDecayRate_def) > 1e-9 | abs(ReferenceTemperature - ReferenceTemperature_def) > 1e-9 | abs(Q10 - Q10_def) > 1e-9 |
         abs(ShareEmitted - ShareEmitted_def) > 1e-9 | (Pool == "AG Slow" & !isTRUE(all.equal(TransferToBGSlow, TransferToBGSlow_def)))]
  say("Dead Organic Matter Parameters: %d rows from Carbon Assumptions; %s", nrow(x), if (nrow(d)) paste0("differing from the package default: ",
      paste(sprintf("%s%s (rate %.4g, ref %.1f C, Q10 %.3g, emitted %.3g)", ifelse(is.na(d$StratumId), "", paste0(d$StratumId, " / ")), d$Pool, d$BaseDecayRate,
                    d$ReferenceTemperature, d$Q10, d$ShareEmitted), collapse = "; ")) else "the package default")
  x }

# Carbon Assumptions - Growth Inputs (to-do 29): the package's forest type crosswalk and merchantable carbon density with the scenario's
# rows (from its Carbon Assumptions dependency) laid over them (src/growth.R growth_inputs); logs what differs from the package
read_growth_inputs <- function(scl = stsim_list("StateClass")) {
  u <- as.data.table(datasheet(scn, ds("GrowthInput"), optional = TRUE, lookupsAsFactors = FALSE))
  g <- tryCatch(growth_inputs(read_default("growth", "forest-type-crosswalk.csv"), read_default("growth", "merch-carbon-density.csv"), u, scl),
                error = function(e) fail(conditionMessage(e)))
  say("Growth Inputs: %s", if (!nrow(u)) "none in this scenario - the package defaults" else if (!length(g$changed)) sprintf("%d rows from Carbon Assumptions, all the package defaults", nrow(u))
      else sprintf("%d rows from Carbon Assumptions; differing from the package: %s", nrow(u), paste(g$changed, collapse = "; ")))
  g }

# a project-scope stsim list (Name, Id) as a data.table
stsim_list <- function(name) as.data.table(datasheet(prj, paste0("stsim_", name), lookupsAsFactors = FALSE, optional = TRUE))

# ---- the model lattice ----------------------------------------------------------------------------------------------
# Every lucasCore grid sits on one EPSG:5070 lattice anchored at the lower-left corner of the FIA ecodivision bounding box
# (xmin -2355030.67, ymin 269687.90). That is the grid the CONUS 1km model was built on (rast(vect(ecodivisions), res = 1000)),
# so a state or regional build lands on the same cells as a CONUS build and can be compared or merged cell for cell.
MODEL_CRS <- "EPSG:5070"
model_lattice <- function(ecodiv, res) {
  # rast(SpatVector, res) keeps the cell size exact and grows xmax/ymax; rast(ext, resolution) would keep the extent and stretch
  # the cells (999.9 m), which moves every boundary cell
  r <- terra::rast(terra::vect(ecodiv), res = res); terra::crs(r) <- MODEL_CRS; r
}

# write a raster to the transfer folder (its path goes into a file column) and return the path
TD <- function() env$TransferDirectory
write_raster <- function(r, file, datatype = "INT4S", NAflag = NA) {
  p <- file.path(TD(), file)
  args <- list(r, p, overwrite = TRUE, datatype = datatype, gdal = c("COMPRESS=DEFLATE", "TILED=YES", if (startsWith(datatype, "FLT")) "PREDICTOR=3"))
  if (!is.na(NAflag)) args$NAflag <- NAflag
  do.call(terra::writeRaster, args)
  p }

# Spatial multiprocessing tiles: whole units of one strata level packed into n tiles of about equal land area (largest unit first, each
# into the emptiest tile), so no unit - and no target on that level - is split between tiles. u: each cell's unit, land: the study area's
# cells. Stage 1 writes the Build's tiles from Build Options; stage 9 writes a projection's when Run Settings sets its own.
TILE_LEVELS <- c("Primary", "Secondary", "Tertiary")
tile_level <- function(v) { v <- as.character(v[1]); if (!length(v) || is.na(v) || !nzchar(v)) return("Secondary")
  TILE_LEVELS[if (grepl("^[123]$", v)) as.integer(v) else { k <- match(sub("[: ].*", "", v), TILE_LEVELS); if (is.na(k)) 2L else k }] }
pack_tiles <- function(u, land, n) {
  ua <- sort(table(u[land]), decreasing = TRUE); load <- numeric(n); tile_of <- integer(length(ua))
  for (j in seq_along(ua)) { k <- which.min(load); tile_of[j] <- k; load[k] <- load[k] + ua[[j]] }
  tv <- rep(NA_integer_, length(u)); tv[land] <- tile_of[match(as.character(u[land]), names(ua))]
  list(values = tv, load = load, units = length(ua)) }
tile_summary <- function(tl, n, lvl) sprintf("%d tiles of whole %s units (%d units; largest tile %.0f%%, smallest %.0f%% of the land)",
                                              n, lvl, tl$units, 100 * max(tl$load) / sum(tl$load), 100 * min(tl$load) / sum(tl$load))

# Annual NLCD on the model grid R (a crop of lattice L): modal aggregation of the 30 m classes. The aggregation blocks are fixed to the
# CONUS crop the CONUS 1km build used (lattice extent + one block, snapped to the NLCD 30 m grid), so a regional build aggregates the
# same 30 m pixels into each cell as a CONUS build. NLCD's Albers WKT differs from EPSG:5070 only in naming, so extents are used as is.
nlcd_on_grid <- function(nf, L, R) {
  n30 <- terra::rast(nf); b <- grid_blocks(n30, L, R)
  n <- terra::aggregate(terra::crop(n30, b$ext), fact = b$fact, fun = "modal", na.rm = TRUE)
  terra::project(n, R, method = "near") }
# the 30 m extent of those aggregation blocks and the aggregation factor (MTBS and LANDFIRE disturbance sit on the same 30 m grid,
# so stage 6 aggregates them over the same blocks)
grid_blocks <- function(n30, L, R) {
  res_m <- terra::res(R)[1]; fact <- round(res_m / terra::res(n30)[1]); blk <- fact * terra::res(n30)[1]
  conus <- terra::ext(terra::crop(n30, terra::ext(L) + blk)); want <- terra::ext(R) + blk
  x0 <- terra::xmin(conus) + floor((terra::xmin(want) - terra::xmin(conus)) / blk) * blk
  y0 <- terra::ymin(conus) + floor((terra::ymin(want) - terra::ymin(conus)) / blk) * blk
  x1 <- min(terra::xmax(conus), terra::xmin(conus) + ceiling((terra::xmax(want) - terra::xmin(conus)) / blk) * blk)
  y1 <- min(terra::ymax(conus), terra::ymin(conus) + ceiling((terra::ymax(want) - terra::ymin(conus)) / blk) * blk)
  list(ext = terra::ext(max(x0, terra::xmin(conus)), x1, max(y0, terra::ymin(conus)), y1), fact = fact) }

# fill NA cells of r (inside mask m) with the modal value of their neighbours, repeating until none is left (the CONUS 1km build's
# iterative focal fill, run at twice the cell size for speed); `default` everywhere when r has no values at all
fill_modal <- function(r, m, default) {
  if (all(is.na(terra::values(r, mat = FALSE)))) return(terra::mask(terra::init(m, default), m))
  ra <- terra::aggregate(r, 2, "modal", na.rm = TRUE)
  while (terra::global(is.na(ra), "sum")[[1]] > 0) ra <- terra::focal(ra, 9, "modal", na.policy = "only", na.rm = TRUE)
  terra::mask(terra::cover(r, terra::project(ra, r, method = "near")), m) }

# ---- validation -----------------------------------------------------------------------------------------------------
# Checks never pass silently on NA: a check that cannot be computed is a failure (see memory: checks must not return NA).
.checks <- list()
check <- function(stage, what, ok, detail = "") {
  if (length(ok) != 1 || is.na(ok)) { ok <- FALSE; detail <- paste("could not be computed;", detail) }
  .checks[[length(.checks) + 1]] <<- data.table(Stage = stage, Check = what, Status = if (ok) "Pass" else "FAIL", Detail = detail)
  say("%s - %s: %s %s", stage, what, if (ok) "pass" else "FAIL", detail)
  invisible(ok) }
# save the checks to Validation and stop the stage when any failed
finish_checks <- function() {
  if (!length(.checks)) return(invisible())
  x <- rbindlist(.checks); write_ds(x, "OutputValidation", append = TRUE)
  bad <- x[Status != "Pass"]
  if (nrow(bad)) fail("%d validation check(s) failed: %s", nrow(bad), paste(bad$Check, collapse = "; "))
  invisible() }

# the primary strata (ecodivision) names of the study area: the values of stage 1's primary strata raster, or NULL when no stage 1
# result is in the scenario (then a stage works on all of CONUS)
study_ecodivisions <- function() {
  ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
  if (!nrow(ic) || is.na(ic$StratumFileName[1])) return(NULL)
  v <- terra::unique(terra::rast(ic$StratumFileName[1]))[[1]]; l <- stsim_list("Stratum")
  l$Name[match(v[!is.na(v)], as.integer(l$Id))] }

# every value of a raster must be an Id in the stsim list (NA cells excluded); returns the values not in the list
raster_ids_in_list <- function(r, list_name) {
  v <- terra::unique(r)[[1]]; v <- v[!is.na(v)]
  ids <- as.integer(stsim_list(list_name)$Id)
  setdiff(as.integer(v), ids) }
