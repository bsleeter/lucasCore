# =============================================================================
# 15-data-download.R - stage 15: fetch the Data Sources into Data Sources Home for a region (to-do 12)
# =============================================================================
# Its own scenario ("Data Download"), not part of a Build: the region is this scenario's Study Area units (blank = all of CONUS)
# plus Data Download: Buffer, in EPSG:5070. One download serves every Build whose study area it holds. Each dataset goes through
# src/download.R's steps (up to date? plan, check, fetch with resume, unpack and clip, record in manifest.csv and files.csv) into
# its place under the home folder (src/datahome.R), where a blank Data Sources path finds it. Datasets: Data Download: Datasets
# (Data Sources columns), blank = every one src/download-sources.R can fetch. Check only lists what would download, and how big.
# Download Results gets one row per dataset; a failed dataset does not stop the others.
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
sa <- read_ds("StudyArea"); want <- if (nrow(sa)) unique(as.character(sa$UnitId)) else character()
if (length(want)) {
  ul <- stsim_list("SecondaryStratum"); ul[, Id := as.integer(Id)]; uid <- ul$Id[match(want, ul$Name)]
  if (anyNA(uid)) fail("Study Area units not in the unit list: %s", paste(want[is.na(uid)], collapse = ", "))
  rows <- sources_from_sheet(as.data.table(datasheet(prj, ds("StratumSource"), optional = TRUE, lookupsAsFactors = FALSE)))
  by_num <- setNames(rows, vapply(rows, function(s) as.character(s$Number), ""))
  parts <- split(unit_native(uid), unit_source(uid))
  poly <- do.call(c, lapply(names(parts), function(k) { sp <- strata_polygons(by_num[[k]], env$PackageDirectory); sp <- sp[sp$StratumId %in% parts[[k]], ]
    if (!nrow(sp)) fail("no %s polygons for the study area units %s", by_num[[k]]$Preset, paste(parts[[k]], collapse = ", "))
    st_geometry(st_transform(st_make_valid(sp), 5070)) }))
  poly <- st_buffer(st_union(poly), buffer_km * 1000)
  box <- as.numeric(st_bbox(poly))
  region <- list(box = box, poly = poly, units = paste(want, collapse = "; "), buffer_km = buffer_km)
  say("Region: %s + %g km (%.0f x %.0f km)", region$units, buffer_km, (box[3] - box[1]) / 1000, (box[4] - box[2]) / 1000)
} else {
  region <- list(box = c(-2400000, 200000, 2300000, 3200000), poly = NULL, units = "CONUS", buffer_km = NA_real_)
  say("Region: all of CONUS (national copies)") }

# ---- the datasets ----------------------------------------------------------------------------------------------------------
H <- download_handlers()
asked <- trimws(strsplit(o("Datasets", ""), ",")[[1]]); asked <- asked[nzchar(asked)]
if (length(asked)) { bad <- setdiff(asked, layout$Column); if (length(bad)) fail("Data Download: Datasets: %s are not Data Sources columns", paste(bad, collapse = ", "))
  cant <- setdiff(asked, names(H)); if (length(cant)) say("Not fetched by this version (%s): %s", "see the Data Download plan", paste(cant, collapse = ", ")) }
todo <- if (length(asked)) intersect(asked, names(H)) else names(H)
check_only <- isTRUE(as.logical(o("CheckOnly", FALSE)))
y_to <- o("YearTo", NA_integer_)
ctx <- list(home = home, region = region, years = c(as.integer(o("YearFrom", 1985L)), if (is.na(y_to)) NA_integer_ else as.integer(y_to)),
            keep = isTRUE(as.logical(o("KeepNational", FALSE))), connections = as.integer(o("Connections", 4L)), opts = opt, log = log, prj = prj)
say("%s %d datasets into %s%s", if (check_only) "Checking" else "Downloading", length(todo), home, if (ctx$keep) " (national copies kept)" else "")
progressBar(type = "begin", totalSteps = length(todo))
res <- rbindlist(lapply(todo, function(k) { h <- H[[k]]
  r <- tryCatch(run_dataset(h, ctx, layout, check_only), error = function(e) {
    log(sprintf("%s: FAILED: %s", h$name, conditionMessage(e))); if (!check_only) record_failure(home, h, conditionMessage(e))
    data.table(DataSource = k, Dataset = h$name, Status = "failed", Files = NA_integer_, SizeMb = NA_real_, Minutes = NA_real_,
               Next = sprintf("%s (rerun to resume)", substr(conditionMessage(e), 1, 300))) })
  progressBar(); r }), fill = TRUE)
for (k in setdiff(asked, names(H))) res <- rbind(res, data.table(DataSource = k, Dataset = layout[Column == k, Name], Status = "manual",
  Next = "Not fetched by this version: put it at its place in the home folder, or set its Data Sources path"), fill = TRUE)
write_ds(res, "OutputDataDownload")
progressBar(type = "end")

say("%s", paste(sprintf("%s %d", names(table(res$Status)), as.integer(table(res$Status))), collapse = ", "))
if (check_only) say("Check only: %.1f GB would download", sum(res$SizeMb, na.rm = TRUE) / 1000)
check(STAGE, "every dataset done, skipped or checked", all(res$Status %in% c("done", "skipped", "would download", "manual")),
      paste(res[Status == "failed", sprintf("%s: %s", DataSource, Next)], collapse = "; "))
finish_checks()
