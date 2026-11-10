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
# a forest class: the upland forest type groups and their forested wetland twins (Wetland: Spruce/Fir Group etc., to-do 53)
is_forest_class <- function(x) !is.na(x) & grepl("^(Forest: |Wetland: .+ Group$)", x)
is_wetland_forest <- function(x) !is.na(x) & grepl("^Wetland: .+ Group$", x)   # the three forested wetland classes (to-do 53)
say  <- function(...) updateRunLog(sprintf(...))

# the R version and, in a git checkout of the package, its commit: a Build logs this line and the model record reads it from the log
software_line <- function() {
  git <- function(...) tryCatch(suppressWarnings(system2("git", c("-C", shQuote(env$PackageDirectory), ...), stdout = TRUE, stderr = FALSE)), error = function(e) character())
  head <- if (dir.exists(file.path(env$PackageDirectory, ".git"))) git("rev-parse", "--short", "HEAD") else character()
  sprintf("Software: R %s%s", getRversion(), if (length(head) == 1) sprintf("; lucasCore commit %s%s", head, if (length(git("status", "--porcelain", "--untracked-files=no"))) " with uncommitted changes" else "") else "") }

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

# the project's Data Sources: a blank cell (or an empty sheet) takes the package default path; required columns must exist on disk.
# Files the package ships: the dissolved FIA ecodivisions (ECOMAP 2007 divisions; ECOMAP 2025 renumbers them, so a fresh download
# would not match the package's strata tables)
PACKAGE_SOURCES <- list(EcodivisionFile = c("defaults", "strata", "ecodivisions", "EcoDivisions_Dissolve.shp"))
# A blank path reads, in order: its place under Data Sources Home (src/datahome.R), the package's own copy (package.xml has no default paths:
# the build machine's were removed 2026-11-02, so a dataset missing from the home stops with what to do)
source(file.path(env$PackageDirectory, "src", "datahome.R"))
# optional = TRUE: a column with nothing set, at home or by default, gives NA instead of stopping (NCCPI, fetched when blank)
read_data_sources <- function(cols, optional = FALSE) {
  d <- as.data.table(datasheet(prj, ds("DataSource"), lookupsAsFactors = FALSE, optional = TRUE))
  def <- sheet_defaults("DataSource", quiet = TRUE)
  home <- if (nrow(d) && "DataSourcesHome" %in% names(d)) d$DataSourcesHome[1] else NA_character_
  hl <- if (!is.na(home) && nzchar(home)) home_layout(env$PackageDirectory) else NULL
  out <- list(); regions <- !is.null(hl) && length(home_regions(home)) > 0
  # the editions this library reads (Data Source Editions, set on the Data Sources page; no row = the first edition)
  ed <- tryCatch(as.data.table(datasheet(prj, ds("DataSourceEdition"), optional = TRUE, lookupsAsFactors = FALSE)), error = function(e) data.table())
  ed <- if (nrow(ed) && all(c("DataSource", "Edition") %in% names(ed))) setNames(as.character(ed$Edition), ed$DataSource) else character()
  for (k in cols) { v <- if (nrow(d) && k %in% names(d)) d[[k]][1] else NA_character_; how <- "set"; dir <- NA_character_
    if ((is.na(v) || !nzchar(v)) && !is.null(hl) && k %in% hl$Column) {
      # with region folders, the folder is chosen by the study area: the smallest region whose manifest covers it (datahome.R)
      want_ed <- if (k %in% names(ed) && !is.na(ed[[k]]) && nzchar(ed[[k]])) ed[[k]] else NULL
      pk <- tryCatch(home_pick(home, k, hl[Column == k, HomePath], if (regions || !is.null(want_ed)) study_box() else NULL, want_ed), error = function(e) fail("%s", conditionMessage(e)))
      if (is.null(pk) && !is.null(want_ed)) fail("Data Sources: %s: edition %s, which this library reads (Data Sources page), is not in Data Sources Home %s", k, want_ed, home)
      if (!is.null(pk) && is.null(.home_cov$said_ed[[k]])) { .home_cov$said_ed[[k]] <- TRUE
        others <- tryCatch(home_editions(home, k), error = function(e) data.table())
        # (the other editions in the folder read from: another region's copy is not an edition)
        pd <- normalizePath(pk$dir, winslash = "/", mustWork = FALSE); base <- home_label(home, sub("/editions/[^/]+$", "", pd))
        others <- if (nrow(others)) others[Dir != pd & Folder == base] else others
        if (nrow(others)) say("Data Sources: %s: the home also holds %s; this library reads %s. A change of edition is made on the Data Sources page", k,
                             paste(sprintf("%s (%s, %s)", ifelse(nzchar(others$Edition), others$Edition, "the first edition"), others$Version, others$Folder), collapse = ", "),
                             if (is.null(want_ed)) "the first edition" else sprintf("edition %s", want_ed)) }
      if (!is.null(pk)) { v <- pk$path; how <- "home"; dir <- pk$dir; .home_cov$home <- home; .home_cov$dirs[[k]] <- pk$dir; .home_cov$used <- union(.home_cov$used, k)
        if ((regions || !is.null(want_ed)) && is.null(.home_cov$said[[k]])) { .home_cov$said[[k]] <- TRUE; say("Data Sources: %s from %s", k, home_label(home, pk$dir)) }
        if (!is.null(.home_cov$box)) home_covers(k, .home_cov$box, .home_cov$what) } }
    if (is.na(v) || !nzchar(v)) { v <- def[[k]][1]; how <- "default" }
    if ((is.null(v) || is.na(v) || !nzchar(v)) && !is.null(PACKAGE_SOURCES[[k]])) { v <- do.call(pkg_file, as.list(PACKAGE_SOURCES[[k]])); how <- "package" }
    if (is.null(v) || is.na(v) || !nzchar(v)) { if (optional) { out[k] <- list(NA_character_); next }
      fail("Data Sources: %s is not set and is not in Data Sources Home%s: run a Data Download scenario for this study area, or set its path on the Data Sources page", k,
           if (is.null(hl)) " (Data Sources Home is not set)" else "") }
    if (!file.exists(v)) fail("Data Sources: %s not found (%s)", k, v)
    .home_cov$read[[k]] <- list(DataSource = k, Origin = how, Dir = dir, Path = v)
    out[[k]] <- v }
  out }

# a strata preset with no File on this machine reads its polygons from Data Sources Home (src/strata.R strata_path): the national
# copy a Data Download scenario puts at the top of the home (looked up with no study area box: study_box() reads strata polygons
# itself). Recorded in Data Sources Used like the Data Sources the stage read.
strata_from_home <- function(col) {
  d <- as.data.table(datasheet(prj, ds("DataSource"), lookupsAsFactors = FALSE, optional = TRUE))
  home <- if (nrow(d) && "DataSourcesHome" %in% names(d)) d$DataSourcesHome[1] else NA_character_
  if (is.na(home) || !nzchar(home)) return(NA_character_)
  hp <- home_layout(env$PackageDirectory)[Column == col, HomePath]; if (length(hp) != 1) return(NA_character_)
  pk <- home_pick(home, col, hp)
  if (is.null(pk)) return(NA_character_)
  if (is.null(.home_cov$home)) .home_cov$home <- home
  if (is.null(.home_cov$read[[col]])) .home_cov$read[[col]] <- list(DataSource = col, Origin = "home", Dir = pk$dir, Path = pk$path)
  pk$path }
options(lucas.strata.home = strata_from_home)

# the study area's box (EPSG:5070, xmin, ymin, xmax, ymax), for choosing among region folders: stage 1's primary strata raster
# when the scenario has one, else the Study Area units' polygons; all of CONUS with no Study Area
study_box <- function() {
  if (!is.null(.home_cov$study_box)) return(.home_cov$study_box)
  b <- tryCatch({
    ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
    sa <- read_ds("StudyArea"); want <- if (nrow(sa)) unique(as.character(sa$UnitId)) else character()
    if (nrow(ic) && "StratumFileName" %in% names(ic) && !is.na(ic$StratumFileName[1]) && file.exists(ic$StratumFileName[1])) {
      r <- terra::rast(ic$StratumFileName[1]); as.vector(terra::ext(terra::project(terra::as.polygons(terra::ext(r), crs = terra::crs(r)), "EPSG:5070")))[c(1, 3, 2, 4)]
    } else if (!length(want)) c(-2400000, 200000, 2300000, 3200000) else {
      if (!exists("strata_polygons", mode = "function")) source(pkg_file("src", "strata.R"))
      ul <- stsim_list("SecondaryStratum"); uid <- as.integer(ul$Id)[match(want, ul$Name)]
      if (anyNA(uid)) stop("Study Area units not in the unit list: ", paste(want[is.na(uid)], collapse = ", "))
      rows <- sources_from_sheet(as.data.table(datasheet(prj, ds("StratumSource"), optional = TRUE, lookupsAsFactors = FALSE)))
      by_num <- setNames(rows, vapply(rows, function(s) as.character(s$Number), ""))
      parts <- split(unit_native(uid), unit_source(uid))
      bb <- do.call(rbind, lapply(names(parts), function(k) { sp <- strata_polygons(by_num[[k]], env$PackageDirectory); as.numeric(sf::st_bbox(sp[sp$StratumId %in% parts[[k]], ])) }))
      c(min(bb[, 1]), min(bb[, 2]), max(bb[, 3]), max(bb[, 4])) } },
    error = function(e) { say("Data Sources Home: the study area is not known yet (%s); reading the top of the home first", conditionMessage(e)); NULL })
  .home_cov$study_box <- b; b }

# the Data Sources a stage read, for Data Sources Used (written by finish_checks): where each came from, and its files' sizes and
# checksum (from the home's files.csv: one file's sha256, or the sha256 of the sorted path and sha256 list of a folder). A path set
# by hand has no checksum. A home dataset whose files no longer match files.csv is noted: the write-once rule was broken
data_sources_used <- function() {
  if (!length(.home_cov$read)) return(NULL)
  stage <- if (exists("STAGE")) STAGE else NA_character_
  rbindlist(lapply(.home_cov$read, function(x) {
    f <- if (identical(x$Origin, "home")) read_files(x$Dir)[Column == x$DataSource] else data.table()
    if (nrow(f)) { fp <- file.path(x$Dir, f$Path); ok <- all(file.exists(fp)) && all(file.size(fp) == as.numeric(f$Bytes))
      sh <- if (nrow(f) == 1) f$Sha256 else digest::digest(paste(sort(paste(f$Path, f$Sha256)), collapse = "\n"), algo = "sha256", serialize = FALSE)
      return(data.table(Stage = stage, DataSource = x$DataSource, Origin = home_label(.home_cov$home, x$Dir), Path = x$Path,
                        Files = nrow(f), Bytes = sum(as.numeric(f$Bytes)), Sha256 = sh, Note = if (ok) NA_character_ else "files on disk differ from files.csv")) }
    fl <- if (dir.exists(x$Path)) list.files(x$Path, recursive = TRUE, full.names = TRUE) else x$Path
    data.table(Stage = stage, DataSource = x$DataSource, Origin = x$Origin, Path = x$Path, Files = length(fl),
               Bytes = sum(as.numeric(file.size(fl)), na.rm = TRUE), Sha256 = NA_character_,
               Note = if (identical(x$Origin, "home")) "no files.csv rows (laid out by hand)" else "not from Data Sources Home: no checksum") })) }

# ---- Data Sources Home coverage (to-do 12, phase 5) -------------------------------------------------------------------------
# A dataset read from the home folder holds only the region its Data Download was run for (manifest.csv). Each Build stage calls
# home_coverage(<its grid>) once: every home dataset read so far, and every one read after, must cover that grid (less one cell of
# tolerance, the grid being snapped outward), or the stage stops naming the dataset, the region it holds and what to do. A home
# file with no manifest row (put there by hand) is not checked; a set path is never checked. home_coverage(x, cols, what) checks
# the named columns against a wider extent (a fitting region, a kernel's reach) without changing the stage's own.
.home_cov <- new.env(); .home_cov$used <- character(); .home_cov$box <- NULL; .home_cov$what <- "the study area"; .home_cov$dirs <- list(); .home_cov$read <- list()
home_coverage <- function(x, cols = NULL, what = "the study area", warn_only = FALSE) {
  e <- if (inherits(x, "SpatRaster")) { r <- terra::res(x)[1]; terra::as.polygons(terra::ext(x) - r, crs = terra::crs(x)) } else if (inherits(x, "SpatVector")) terra::as.polygons(terra::ext(x), crs = terra::crs(x)) else terra::vect(sf::st_as_sfc(sf::st_bbox(x)))
  box <- as.vector(terra::ext(terra::project(e, "EPSG:5070")))[c(1, 3, 2, 4)]
  if (is.null(cols)) { .home_cov$box <- box; .home_cov$what <- what; cols <- .home_cov$used } else cols <- intersect(cols, .home_cov$used)
  for (k in cols) if (warn_only) tryCatch(home_covers(k, box, what), error = function(e) say("Warning: %s", sub("^.*?Data Sources: ", "", conditionMessage(e)))) else home_covers(k, box, what)
  invisible(box) }
home_covers <- function(k, box, what) {
  dir <- .home_cov$dirs[[k]]; if (is.null(dir)) dir <- .home_cov$home; at <- home_label(.home_cov$home, dir)
  ok <- manifest_covers(dir, k, box); if (!isFALSE(ok)) return(invisible(TRUE))
  m <- read_manifest(dir)[Column == k]
  if (!identical(m$Status, "done")) fail("Data Sources: %s in Data Sources Home (%s) is marked %s by its last Data Download (%s); run the Data Download again, or set its path",
                                         k, at, m$Status, if (is.na(m$Note)) "no note" else m$Note)
  fail("Data Sources: %s in Data Sources Home (%s, %s) was downloaded for %s%s and does not cover %s; run a Data Download for this study area (or one holding it) into %s, or set its path",
       k, at, m$Dataset, m$Units, if (is.na(m$BufferKm) || !nzchar(m$BufferKm)) "" else sprintf(" + %s km", m$BufferKm), what, .home_cov$home) }

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

# the dependency ids of the scenario being run, in priority order. A run writes into a result scenario that lists no dependencies of its
# own (found 2026-10-30: dependency(scn) was empty inside stage 11), so they are read from its parent, the scenario the user ran
run_dependencies <- function() {
  d <- suppressWarnings(as.integer(rsyncrosim::dependency(scn)$ScenarioId)); if (length(d)) return(d)
  L <- ssimLibrary(main_library()); s <- as.data.table(rsyncrosim::scenario(L, summary = TRUE))
  p <- if ("ParentId" %in% names(s)) s[ScenarioId == rsyncrosim::scenarioId(scn), ParentId] else NA
  if (length(p) != 1 || is.na(p)) return(integer(0))
  d <- as.data.table(rsyncrosim::dependency(rsyncrosim::scenario(L, p))); if (nrow(d)) as.integer(d[order(Priority), ScenarioId]) else integer(0) }

# the flow spatial multiplier rows of one Flow Multiplier Type in this scenario's dependencies (the first that has any), with each file's
# full path: a scenario that writes its own rows hides its dependencies' (stage 11's climate rows would hide the Build's Site
# Productivity row), so it carries these over
dependency_multipliers <- function(type) {
  L <- ssimLibrary(main_library())
  for (id in run_dependencies()) {
    x <- as.data.table(datasheet(rsyncrosim::scenario(L, id), "stsim_FlowSpatialMultiplier", optional = TRUE, lookupsAsFactors = FALSE))
    if (nrow(x) && "FlowMultiplierTypeId" %in% names(x)) { x <- x[FlowMultiplierTypeId %in% type]
      if (nrow(x)) return(x[, MultiplierFileName := file.path(paste0(main_library(), ".data"), sprintf("Scenario-%d", id), "stsim_FlowSpatialMultiplier", basename(MultiplierFileName))][]) } }
  NULL }

# A stage rerun on its own (tools/quick-test.R) takes a copy of the Build's Initial Conditions Spatial maps but not their Properties
# sheet; the two are one feed, which a dependency supplies whole, so a run on the result found the maps without their grid ("Object
# reference not set", 2026-11-07). Saving the maps' row again makes SyncroSim write their Properties, as stages 1 and 5 do
# (Properties cannot be saved directly: its negative Albers corner fails validation). In a Build they are already there.
keep_ic_properties <- function(scn, ic, stage) {
  if (!nrow(ic)) return(invisible())
  icp <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatialProperties", optional = TRUE))
  if (nrow(icp)) return(invisible())
  saveDatasheet(scn, as.data.frame(ic[1, intersect(names(ic), c("StratumFileName", "SecondaryStratumFileName", "TertiaryStratumFileName", "StateClassFileName", "AgeFileName")), with = FALSE]), "stsim_InitialConditionsSpatial")
  say("Initial Conditions Spatial: saved again in this result so SyncroSim writes its Properties (stage %s rerun on its own)", stage) }

# the rows of one sheet in this scenario's first dependency that has any (lookups as names), or NULL: stage 11's CO2 flow multipliers
# carry the Build's stsim_FlowMultiplier rows over, as its climate rows carry the Site Productivity row
dependency_rows <- function(sheet) {
  L <- ssimLibrary(main_library())
  for (id in run_dependencies()) {
    x <- as.data.table(datasheet(rsyncrosim::scenario(L, id), sheet, optional = TRUE, lookupsAsFactors = FALSE))
    if (nrow(x)) return(x) }
  NULL }

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

# the Annual NLCD land cover file of each year: Collection 1.0 (C1V0) or 1.2 (C1V2, the only one MRLC publishes since June 2026).
# C1V0 first, so a folder holding both keeps the collection earlier Builds used; a year with neither gives the C1V2 name
nlcd_file <- function(folder, y) vapply(y, function(yy) { f <- file.path(folder, sprintf("Annual_NLCD_LndCov_%d_CU_C1V%d.tif", yy, c(0L, 2L)))
  if (file.exists(f[1])) f[1] else f[2] }, "")

# interagency fire perimeters of the years y0-y1, with the year as integer column yr. The NIFC feature service (and its GeoPackage)
# names the year FIRE_YEAR_INT; the shapefile cuts it to FIRE_YEAR_. Perimeters of unknown year carry 9999
read_fire_perimeters <- function(file, y0, y1, fields = character(0)) {
  lay <- sf::st_layers(file)$name[1]
  have <- names(sf::st_read(file, query = sprintf('SELECT * FROM "%s" WHERE FID = 0', lay), quiet = TRUE))
  yf <- intersect(c("FIRE_YEAR_INT", "FIRE_YEAR_"), have)[1]
  if (is.na(yf)) fail("Fire perimeters: %s has no FIRE_YEAR_INT or FIRE_YEAR_ field", basename(file))
  # SELECT * keeps the geometry: a field list drops it from a GeoPackage (the Data Download's copy), though not from a shapefile
  fp <- sf::st_read(file, query = sprintf('SELECT * FROM "%s" WHERE %s >= %d AND %s <= %d AND %s <> 9999', lay, yf, as.integer(y0), yf, as.integer(y1), yf), quiet = TRUE)
  # a shapefile cuts field names to 10 characters (FEATURE_CA); a GeoPackage keeps them whole (FEATURE_CATEGORY): either answers to the short name
  for (k in setdiff(fields, names(fp))) { m <- grep(paste0("^", k), names(fp), value = TRUE)[1]; if (!is.na(m)) names(fp)[names(fp) == m] <- k }
  fp <- fp[, unique(c(yf, intersect(fields, names(fp))))]; fp$yr <- as.integer(fp[[yf]]); fp }

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
# Automatic tiles (Spatial Tiles = 0, to-do 22): a tile holds whole units, so a tiled run cannot finish before its largest unit, and
# more than ceiling(1 / that unit's share) tiles cannot help. Pack the units into 1 to that many tiles (as pack_tiles does) and take
# the fewest tiles whose largest tile is within 5% of the best, capped by the units and the cores (P26: Plumas 19.8% -> 5, the number
# found by trial; Placer's tertiary units, one 52% -> 2, where floor(1 / share) would say 1). Peak memory of one ST-Sim job, measured
# on P26 on 2026-10-24: about 1.5 GB plus 10 KB per cell.
TILE_JOB_GB <- 1.5; TILE_CELL_KB <- 10
auto_tiles <- function(u, land, cores = parallel::detectCores()) {
  ua <- table(u[land]); s <- max(ua) / sum(ua); x <- sort(as.numeric(ua), decreasing = TRUE)
  hi <- max(1L, min(as.integer(ceiling(1 / s - 1e-9)), length(ua), as.integer(cores)))
  mk <- vapply(seq_len(hi), function(n) { load <- numeric(n); for (v in x) { k <- which.min(load); load[k] <- load[k] + v }; max(load) }, 0)
  list(n = which(mk <= 1.05 * min(mk))[1], share = s, unit = names(ua)[which.max(ua)], units = length(ua), cores = as.integer(cores)) }
tile_unit_name <- function(lvl, id) { l <- stsim_list(c(Primary = "Stratum", Secondary = "SecondaryStratum", Tertiary = "TertiaryStratum")[[lvl]])
  nm <- l$Name[match(as.character(id), as.character(l$Id))]; if (length(nm) && !is.na(nm)) nm else as.character(id) }
# log lines on the tiles: the largest unit and the best count, the speed-up and peak memory of the tiles used (tl = pack_tiles' result,
# NULL for one job), and plain warnings when more tiles cannot help or one unit dominates
tile_notes <- function(a, tl, n, lvl, unit_name) {
  out <- sprintf("Spatial tiles: the largest %s unit (%s) holds %.1f%% of the land, so a tiled run takes at least that share of a one-job run; the most tiles that help is %d (%d units, %d cores)",
                 lvl, unit_name, 100 * a$share, a$n, a$units, a$cores)
  if (!is.null(tl)) {
    job <- TILE_JOB_GB + TILE_CELL_KB * max(tl$load) / 2^20; all <- n * TILE_JOB_GB + TILE_CELL_KB * sum(tl$load) / 2^20
    out <- c(out, sprintf("Spatial tiles: %d tiles, at best %.1fx faster than one job; estimated peak memory %.1f GB for the largest tile's job, %.0f GB for all %d at once (a 32 GB machine holds about %d such jobs, 64 GB about %d; Library > Properties > Multiprocessing sets how many run at once)",
                          n, sum(tl$load) / max(tl$load), job, all, n, floor(32 / job), floor(64 / job)))
    if (n > a$n) out <- c(out, sprintf("Spatial tiles: %d tiles is more than %d, so the extra jobs cannot make the run finish sooner", n, a$n)) }
  if (a$share > 0.5) out <- c(out, sprintf("Spatial tiles: one %s unit holds %.0f%% of the land, so tiles of this level make a run at most %.1fx faster; a finer Spatial Tiles Strata level would split it",
                                           lvl, 100 * a$share, 1 / a$share))
  out }

# workers for a parallel raster step: at most n and cap, the cores less one, and gb_each GB of free memory a worker. Free memory
# from Windows (terra::free_RAM() stops at 16 GB on the build machine, which has 1 TB). Each worker should then get
# terraOptions(memfrac = 0.6 / workers), set after library(terra), which resets it: left at terra's 0.6, every worker plans on most of the free memory, and on a colleague's
# machine stage 5's NLCD workers failed with std::bad_alloc (2026-11-10)
par_workers <- function(n, cap = 20, gb_each = 2) {
  kb <- if (.Platform$OS.type == "windows") suppressWarnings(as.numeric(tryCatch(system2("powershell", c("-NoProfile", "-Command",
          "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory"), stdout = TRUE), error = function(e) NA)[1])) else NA_real_
  if (is.na(kb)) kb <- tryCatch(terra::free_RAM(), error = function(e) NA_real_)
  m <- if (is.na(kb)) cap else max(1, floor(kb / 1024^2 / gb_each))
  as.integer(max(1, min(n, cap, parallel::detectCores() - 1, m))) }

# Annual NLCD on the model grid R (a crop of lattice L): modal aggregation of the 30 m classes. The aggregation blocks are fixed to the
# CONUS crop the CONUS 1km build used (lattice extent + one block, snapped to the NLCD 30 m grid), so a regional build aggregates the
# same 30 m pixels into each cell as a CONUS build. NLCD's Albers WKT differs from EPSG:5070 only in naming, so extents are used as is.
nlcd_on_grid <- function(nf, L, R) {
  n30 <- terra::rast(nf); b <- grid_blocks(n30, L, R)
  n <- terra::aggregate(terra::crop(n30, b$ext), fact = b$fact, fun = "modal", na.rm = TRUE)
  terra::project(n, R, method = "near") }
# the 30 m extent of those aggregation blocks and the aggregation factor (MTBS and LANDFIRE disturbance sit on the same 30 m grid,
# so stage 6 aggregates them over the same blocks)
# The anchor is the national Annual NLCD file's extent (NLCD_CONUS_EXT), not the file's own: a regional clip from the Data Download
# has a smaller extent, and anchoring on it moved every block by up to 4 pixels (P26 2026-11-01: 7.7% of 150 m cells changed class)
# (an argument, not a global: stages 5 and 6 send grid_blocks to parallel workers on its own)
grid_blocks <- function(n30, L, R, NLCD_CONUS_EXT = c(-2415585, 2384415, 164805, 3314805)) {   # xmin, xmax, ymin, ymax of Annual_NLCD_LndCov_*_CU (EPSG:5070, 30 m)
  res_m <- terra::res(R)[1]; fact <- round(res_m / terra::res(n30)[1]); blk <- fact * terra::res(n30)[1]
  nat <- terra::rast(terra::ext(NLCD_CONUS_EXT), resolution = terra::res(n30), crs = terra::crs(n30))
  conus <- terra::ext(terra::crop(nat, terra::ext(L) + blk)); want <- terra::ext(R) + blk
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
  # Data Sources Used: what this stage read (a library made before 2026-11-02 lacks the sheet until tools/sync-library.R adds it)
  u <- data_sources_used()
  if (!is.null(u) && nrow(u)) { bad <- u[!is.na(Note) & Note == "files on disk differ from files.csv"]
    if (nrow(bad)) say("Warning: %s in Data Sources Home differ from their files.csv record (a file was replaced or removed)", paste(bad$DataSource, collapse = ", "))
    tryCatch(write_ds(u, "OutputDataSources", append = TRUE), error = function(e) say("Data Sources Used not written (%s): run tools/sync-library.R on this library", conditionMessage(e))) }
  if (!length(.checks)) return(invisible())
  x <- rbindlist(.checks); write_ds(x, "OutputValidation", append = TRUE)
  bad <- x[Status != "Pass"]
  # the error names what failed, not only which check, so the Studio failure box is enough to act on (2026-11-09)
  if (nrow(bad)) fail("%d validation check(s) failed: %s", nrow(bad), paste(sprintf("%s%s", bad$Check,
    ifelse(nzchar(trimws(bad$Detail)), paste0(" (", substr(trimws(bad$Detail), 1, 400), ")"), "")), collapse = "; "))
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
