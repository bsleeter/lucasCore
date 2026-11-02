# =============================================================================
# 15-data-download.R - stage 15: fetch the Data Sources into Data Sources Home for a region (to-do 12)
# =============================================================================
# Its own scenario ("Data Download"), not part of a Build: the region is this scenario's Study Area units (blank = all of CONUS)
# plus Data Download: Buffer, in EPSG:5070. One download serves every Build whose study area it holds. Each dataset goes through
# src/download.R's steps (up to date? plan, check, fetch with resume, unpack and clip, record in manifest.csv and files.csv) into
# its place under the home folder (src/datahome.R), where a blank Data Sources path finds it. Datasets: Data Download: Datasets
# (Data Sources columns), blank = every one src/download-sources.R can fetch. Check only lists what would download, and how big.
# Download Results gets one row per dataset; a failed dataset does not stop the others.
# Home layout (plan, "Second study areas: home layout"): By region (the default) writes the region's clips into
# <home>/regions/<Region name>/ (blank = from the Study Area units) and the datasets kept whole (FIA, PRISM, LOCA2, FPA-FOD)
# at the top, shared by every region; National ignores the Study Area and keeps every dataset whole at the top. Write-once
# (src/download.R): no file in the home is ever replaced, so a second region never changes what another library read.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "strata.R")); source(pkg_file("src", "download.R")); source(pkg_file("src", "download-sources.R"))
suppressPackageStartupMessages({ library(terra); library(sf) })
STAGE <- "15 Data Download"

opt <- read_ds("DataDownloadOptions"); def <- sheet_defaults("DataDownloadOptions", quiet = TRUE)
o <- function(k, d = NULL) { v <- if (nrow(opt) && k %in% names(opt)) opt[[k]][1] else NA; if (is.null(v) || is.na(v) || (is.character(v) && !nzchar(v))) v <- def[[k]][1]
  if (is.null(v) || is.na(v)) d else v }
dsrc <- as.data.table(datasheet(prj, ds("DataSource"), lookupsAsFactors = FALSE, optional = TRUE))
home <- if (nrow(dsrc) && "DataSourcesHome" %in% names(dsrc)) dsrc$DataSourcesHome[1] else NA_character_
if (is.na(home) || !nzchar(home)) fail("Data Sources: set Data Sources Home, the folder the download fills")
home <- normalizePath(home, winslash = "/", mustWork = FALSE); dir.create(home, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(home)) fail("Data Sources Home %s cannot be created", home)
home_create(home, env$PackageDirectory)
layout <- home_layout(env$PackageDirectory)

# a log per run in <home>/logs, as well as the run log
logf <- file.path(home, "logs", sprintf("download-%s.log", format(Sys.time(), "%Y%m%d-%H%M%S")))
log <- function(x) { say("%s", x); cat(format(Sys.time(), "%H:%M:%S "), x, "\n", sep = "", file = logf, append = TRUE) }

# ---- the region ------------------------------------------------------------------------------------------------------------
buffer_km <- as.numeric(o("BufferKm", 10))
hl <- o("HomeLayout", 2L)   # a list column reads as its label ("National (...)") or its number
national <- if (is.numeric(hl)) identical(as.integer(hl), 1L) else grepl("^National", as.character(hl))
sa <- read_ds("StudyArea"); want <- if (nrow(sa) && !national) unique(as.character(sa$UnitId)) else character()
region_home <- NULL
if (length(want)) {
  ul <- stsim_list("SecondaryStratum"); ul[, Id := as.integer(Id)]; uid <- ul$Id[match(want, ul$Name)]
  if (anyNA(uid)) fail("Study Area units not in the unit list: %s", paste(want[is.na(uid)], collapse = ", "))
  rows <- sources_from_sheet(as.data.table(datasheet(prj, ds("StratumSource"), optional = TRUE, lookupsAsFactors = FALSE)))
  by_num <- setNames(rows, vapply(rows, function(s) as.character(s$Number), ""))
  parts <- split(unit_native(uid), unit_source(uid))
  poly <- do.call(c, lapply(names(parts), function(k) { sp <- strata_polygons(by_num[[k]], env$PackageDirectory); sp <- sp[sp$StratumId %in% parts[[k]], ]
    if (!nrow(sp)) fail("no %s polygons for the study area units %s", by_num[[k]]$Preset, paste(parts[[k]], collapse = ", "))
    st_geometry(st_transform(st_make_valid(sp), 5070)) }))
  # stage 1 widens the study area by a modal source's fill distance (States, Counties: 29 km), so the buffer is at least that
  # plus 1 km, or a Build for these units would not fit inside its own download
  fill_km <- max(0, vapply(by_num[names(parts)], function(s) if (identical(tolower(s$Fill), "modal")) as.numeric(s$FillDistance) / 1000 + 1 else 0, 0), na.rm = TRUE)
  if (fill_km > buffer_km) { say("Buffer %g km widened to %g km: the Build pads %s by its modal fill distance", buffer_km, fill_km,
                                 paste(unique(vapply(by_num[names(parts)], function(s) s$Preset, "")), collapse = ", ")); buffer_km <- fill_km }
  poly <- st_buffer(st_union(poly), buffer_km * 1000)
  box <- as.numeric(st_bbox(poly))
  region <- list(box = box, poly = poly, units = paste(want, collapse = "; "), buffer_km = buffer_km)
  say("Region: %s + %g km (%.0f x %.0f km)", region$units, buffer_km, (box[3] - box[1]) / 1000, (box[4] - box[2]) / 1000)
  # its own folder: the clips of one region never share a folder with another region's
  rn <- o("RegionName", ""); rn <- tryCatch(region_name(if (!is.na(rn) && nzchar(trimws(rn))) trimws(rn) else want), error = function(e) fail("Data Download: Region name: %s", conditionMessage(e)))
  region_home <- file.path(home, "regions", rn); home_create(region_home, env$PackageDirectory)
  say("Region folder: regions/%s (national copies at the top of the home)", rn)
} else {
  region <- list(box = c(-2400000, 200000, 2300000, 3200000), poly = NULL, units = "CONUS", buffer_km = NA_real_)
  say("Region: all of CONUS (%s; national copies at the top of the home)", if (national) "Home layout National" else "no Study Area") }

# ---- the datasets ----------------------------------------------------------------------------------------------------------
H <- download_handlers()
asked <- trimws(strsplit(o("Datasets", ""), ",")[[1]]); asked <- asked[nzchar(asked)]
if (length(asked)) { bad <- setdiff(asked, layout$Column); if (length(bad)) fail("Data Download: Datasets: %s are not Data Sources columns", paste(bad, collapse = ", "))
  cant <- setdiff(asked, names(H)); if (length(cant)) say("Not fetched by this version (%s): %s", "see the Data Download plan", paste(cant, collapse = ", ")) }
todo <- if (length(asked)) intersect(asked, names(H)) else names(H)
# national copies of the datasets their sources clip (NLCD by WCS, LANDFIRE by LFPS jobs, perimeters by REST, C-CAP, gNATSGO,
# NASA CMS) need the sources' national files, which this version does not fetch yet (plan, home layout work item 3)
clip_only <- if (is.null(region$poly)) todo[vapply(H[todo], function(h) isTRUE(h$method %in% c("wcs", "lfps", "rest", "cog", "stac", "login")), TRUE)] else character()
todo <- setdiff(todo, clip_only)
check_only <- isTRUE(as.logical(o("CheckOnly", FALSE)))
y_to <- o("YearTo", NA_integer_)
ctx <- list(home = home, region_home = region_home, region = region, years = c(as.integer(o("YearFrom", 1985L)), if (is.na(y_to)) NA_integer_ else as.integer(y_to)),
            keep = isTRUE(as.logical(o("KeepNational", FALSE))), connections = as.integer(o("Connections", 4L)), opts = opt, log = log, prj = prj)
say("%s %d datasets into %s%s", if (check_only) "Checking" else "Downloading", length(todo), home, if (ctx$keep) " (national copies kept)" else "")
progressBar(type = "begin", totalSteps = length(todo))
res <- rbindlist(lapply(todo, function(k) { h <- H[[k]]
  r <- tryCatch(run_dataset(h, ctx, layout, check_only), error = function(e) {
    # a missing or expired login is a step for the user, not a failure: the run goes on and the manifest is left as it was
    if (identical(h$method, "login") && grepl("needs an Earthdata login|refused the token", conditionMessage(e))) { log(sprintf("%s: needs a login: %s", h$name, conditionMessage(e)))
      return(data.table(DataSource = k, Dataset = h$name, Status = "needs login", Files = NA_integer_, SizeMb = NA_real_, Minutes = NA_real_, Next = conditionMessage(e))) }
    if (grepl("no file is needed", conditionMessage(e))) { log(sprintf("%s: not needed: %s", h$name, conditionMessage(e)))
      return(data.table(DataSource = k, Dataset = h$name, Status = "not needed", Files = 0L, SizeMb = NA_real_, Minutes = NA_real_, Next = conditionMessage(e))) }
    log(sprintf("%s: FAILED: %s", h$name, conditionMessage(e))); if (!check_only) record_failure(store_for(h, ctx), h, conditionMessage(e))
    data.table(DataSource = k, Dataset = h$name, Status = "failed", Files = NA_integer_, SizeMb = NA_real_, Minutes = NA_real_,
               Next = if (grepl("^write-once", conditionMessage(e))) substr(conditionMessage(e), 1, 300) else sprintf("%s (rerun to resume)", substr(conditionMessage(e), 1, 300))) })
  progressBar(); r }), fill = TRUE)
for (k in setdiff(asked, names(H))) { pk <- identical(layout[Column == k, Access], "package")
  res <- rbind(res, data.table(DataSource = k, Dataset = layout[Column == k, Name], Status = if (pk) "skipped" else "manual",
    Next = if (pk) "Ships with lucasCore: a blank Data Sources path reads the package copy" else if (identical(layout[Column == k, Access], "user"))
      "No public source: put your copy at its place in the home folder, or set its Data Sources path" else
      "Not fetched by this version: put it at its place in the home folder, or set its Data Sources path"), fill = TRUE) }
for (k in clip_only) res <- rbind(res, data.table(DataSource = k, Dataset = H[[k]]$name, Status = "manual",
  Next = "Clipped by its source: a national copy is not fetched by this version. Run the download By region, or put the national file at its place at the top of the home"), fill = TRUE)
write_ds(res, "OutputDataDownload")
progressBar(type = "end")

say("%s", paste(sprintf("%s %d", names(table(res$Status)), as.integer(table(res$Status))), collapse = ", "))
if (check_only) say("Check only: %.1f GB would download", sum(res$SizeMb, na.rm = TRUE) / 1000)
check(STAGE, "every dataset done, skipped or checked", all(res$Status %in% c("done", "skipped", "would download", "manual", "needs login", "not needed")),
      paste(res[Status == "failed", sprintf("%s: %s", DataSource, Next)], collapse = "; "))
finish_checks()
