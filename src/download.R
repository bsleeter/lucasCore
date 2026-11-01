# =============================================================================
# download.R - the Data Download engine (to-do 12, stage 15): plan, check, fetch with resume, unpack, clip, record
# =============================================================================
# One dataset at a time, the same six steps (implementation plan, "How a download runs"):
#   1. up to date?  the manifest says done, its region holds this one (or the copy is national), and every file files.csv lists is
#                   on disk at its recorded size: skipped, nothing fetched
#   2. plan         the dataset's handler (src/download-sources.R) lists its files: url, the name to save it under, and how to
#                   finish (unzip, pick the files the stages read, clip)
#   3. check        HEAD each url for its size (Check only stops here and reports what would download)
#   4. fetch        curl::multi_download into <home>/.downloads/<column>/, resuming partial files (a stopped run picks up where it
#                   was); each file's size is checked against the server's
#   5. finish       the handler unpacks and clips into the dataset's place under the home folder (src/datahome.R); national
#                   copies are clipped to the region unless Keep national copies is ticked
#   6. record       files.csv gets each file's size and sha256, the manifest one row (status, region, source, version, DOI);
#                   the downloaded archives are deleted
# A dataset that fails is recorded failed with its error, and the others go on. No rsyncrosim here: the stage passes `log`.
# =============================================================================

# ---- the region ----------------------------------------------------------------------------------------------------------
# region: list(box = c(xmin, ymin, xmax, ymax) in EPSG:5070, poly = sf polygon (EPSG:5070) or NULL for CONUS, units, buffer_km)
region_box_ll <- function(region) {   # the box in lon/lat (EPSG:4326), for services and archives indexed that way
  b <- sf::st_bbox(sf::st_transform(sf::st_segmentize(sf::st_as_sfc(sf::st_bbox(setNames(region$box, c("xmin", "ymin", "xmax", "ymax")), crs = sf::st_crs(5070))), 5000), 4326))
  as.numeric(b) }

# ---- clipping ------------------------------------------------------------------------------------------------------------
# a raster cut to the region (its own grid and values, compressed); a categorical raster's .vat.dbf / .vat.cpg go with it
clip_raster <- function(src, dest, region) {
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  r <- terra::rast(src)
  if (is.null(region$poly)) { if (normalizePath(src, mustWork = FALSE) != normalizePath(dest, mustWork = FALSE)) file.copy(src, dest, overwrite = TRUE) } else {
    b <- terra::project(terra::vect(sf::st_as_sfc(sf::st_bbox(setNames(region$box, c("xmin", "ymin", "xmax", "ymax")), crs = sf::st_crs(5070)))), terra::crs(r))
    e <- terra::intersect(terra::ext(b), terra::ext(r)); if (is.null(e)) stop(sprintf("%s does not reach the region", basename(src)), call. = FALSE)
    terra::crop(r, e, snap = "out", filename = dest, overwrite = TRUE, datatype = terra::datatype(r)[1], gdal = c("COMPRESS=DEFLATE", "TILED=YES", "BIGTIFF=IF_SAFER")) }
  for (s in c(".vat.dbf", ".vat.cpg")) if (file.exists(paste0(src, s))) file.copy(paste0(src, s), paste0(dest, s), overwrite = TRUE)
  dest }

# a vector layer cut to the region (features touching the box), written as a GeoPackage
clip_vector <- function(src, dest, region, layer = NULL) {
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  args <- list(dsn = src, quiet = TRUE); if (!is.null(layer)) args$layer <- layer
  if (!is.null(region$poly)) { crs0 <- sf::st_crs(do.call(sf::read_sf, c(args[c("dsn", "quiet")], list(query = sprintf('SELECT * FROM "%s" LIMIT 0', if (is.null(layer)) sf::st_layers(src)$name[1] else layer)))))
    args$wkt_filter <- sf::st_as_text(sf::st_transform(sf::st_segmentize(sf::st_as_sfc(sf::st_bbox(setNames(region$box, c("xmin", "ymin", "xmax", "ymax")), crs = sf::st_crs(5070))), 5000), crs0)) }
  x <- do.call(sf::read_sf, args)
  if (file.exists(dest)) file.remove(dest)
  sf::write_sf(x, dest, layer = if (is.null(layer)) tools::file_path_sans_ext(basename(dest)) else layer)
  dest }

# unzip, all or the named members (paths inside the archive), into a folder; returns the extracted paths
unzip_to <- function(zip, exdir, files = NULL) {
  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
  if (!is.null(files)) { have <- utils::unzip(zip, list = TRUE)$Name
    miss <- setdiff(files, have); if (length(miss)) stop(sprintf("%s lacks %s", basename(zip), paste(miss, collapse = ", ")), call. = FALSE) }
  utils::unzip(zip, files = files, exdir = exdir, junkpaths = FALSE)
  file.path(exdir, if (is.null(files)) utils::unzip(zip, list = TRUE)$Name else files) }

# ---- fetching ------------------------------------------------------------------------------------------------------------
# the size of each url: HEAD, else (servers that refuse HEAD, such as Box) the total of a one-byte ranged GET; NA when neither says
url_sizes <- function(urls) vapply(urls, function(u) {
  h <- curl::new_handle(nobody = TRUE, followlocation = TRUE, timeout = 60)
  r <- tryCatch(curl::curl_fetch_memory(u, handle = h), error = function(e) NULL)
  if (!is.null(r) && r$status_code < 400) { cl <- curl::parse_headers_list(r$headers)[["content-length"]]; if (!is.null(cl) && as.numeric(cl) > 0) return(as.numeric(cl)) }
  h <- curl::new_handle(followlocation = TRUE, timeout = 60, range = "0-0")
  r <- tryCatch(curl::curl_fetch_memory(u, handle = h), error = function(e) NULL)
  if (is.null(r) || r$status_code != 206) return(NA_real_)
  cr <- curl::parse_headers_list(r$headers)[["content-range"]]
  if (is.null(cr) || !grepl("/[0-9]+$", cr)) NA_real_ else as.numeric(sub(".*/", "", cr)) }, 0, USE.NAMES = FALSE)

# fetch urls to files, `connections` at a time. A file already at the size the server reports is kept; a shorter one resumes
# (HTTP 206); a server that ignores the range (200) or a file that ends up the wrong size starts again. Stops naming what failed.
fetch_files <- function(urls, dest, connections = 4, log = message, sizes = url_sizes(urls)) {
  for (d in unique(dirname(dest))) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  good <- function(i) file.exists(dest[i]) && (if (is.na(sizes[i])) isTRUE(attr(dest, "done")[i]) else file.size(dest[i]) == sizes[i])
  attr(dest, "done") <- rep(FALSE, length(dest))
  for (try in 1:4) {
    todo <- which(!vapply(seq_along(urls), good, TRUE)); if (!length(todo)) return(invisible(TRUE))
    if (try > 1) log(sprintf("  retrying %d of %d files (%d)", length(todo), length(urls), try - 1))
    # a partial file bigger than the server's size is wrong: start it again
    for (i in todo) if (file.exists(dest[i]) && !is.na(sizes[i]) && file.size(dest[i]) > sizes[i]) file.remove(dest[i])
    for (ch in split(todo, ceiling(seq_along(todo) / max(1, connections)))) {
      r <- curl::multi_download(urls[ch], dest[ch], resume = TRUE, progress = FALSE, multiplex = FALSE,
                                connecttimeout = 60, low_speed_time = 300, low_speed_limit = 100, failonerror = TRUE)
      for (k in seq_along(ch)) { i <- ch[k]; st <- r$status_code[k]
        if (isTRUE(r$success[k]) && (st == 206 || (st == 200 && r$resumefrom[k] == 0))) attr(dest, "done")[i] <- TRUE
        else if (isTRUE(r$success[k]) && st == 200 && r$resumefrom[k] > 0) { file.remove(dest[i]); log(sprintf("  %s: the server ignored the resume; starting it again", basename(dest[i]))) }
        else if (!isTRUE(r$success[k]) && !is.na(r$error[k])) log(sprintf("  %s: %s", basename(dest[i]), r$error[k])) } } }
  bad <- which(!vapply(seq_along(urls), good, TRUE))
  stop(sprintf("could not fetch %s", paste(basename(dest[bad]), collapse = ", ")), call. = FALSE) }
# ---- one dataset ---------------------------------------------------------------------------------------------------------
# a handler (src/download-sources.R) is list(column, name, plan = function(ctx) -> data.table(url, file), finish =
# function(ctx, files) -> the place's path; optional version, note). ctx: home, region, years, place (the dataset's folder),
# dl (its download folder), keep (keep national copies), connections, opts, log
dataset_up_to_date <- function(home, column, region) {
  if (!isTRUE(manifest_covers(home, column, region$box))) return(FALSE)
  # a CONUS download needs a national copy
  if (is.null(region$poly) && !identical(read_manifest(home)[Column == column, Copy], "national")) return(FALSE)
  f <- read_files(home)[Column == column]
  nrow(f) > 0 && all(file.exists(file.path(home, f$Path))) && all(file.size(file.path(home, f$Path)) == as.numeric(f$Bytes)) }

run_dataset <- function(h, ctx, layout, check_only = FALSE) {
  t0 <- Sys.time(); col <- h$column; log <- ctx$log
  out <- function(status, files = NA_integer_, mb = NA_real_, nxt = NA_character_)
    data.table::data.table(DataSource = col, Dataset = h$name, Status = status, Files = as.integer(files), SizeMb = round(mb, 1),
                           Minutes = round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 2), Next = nxt)
  if (dataset_up_to_date(ctx$home, col, ctx$region)) { log(sprintf("%s: up to date (manifest and files.csv)", h$name)); return(out("skipped", nrow(read_files(ctx$home)[Column == col]))) }
  hp <- layout[Column == col, HomePath]; first <- strsplit(hp, "|", fixed = TRUE)[[1]][1]
  ctx$place <- file.path(ctx$home, if (grepl("*", first, fixed = TRUE)) dirname(first) else first)
  ctx$dl <- file.path(ctx$home, ".downloads", col)
  items <- h$plan(ctx)
  if (!nrow(items)) return(out("failed", 0, 0, "the source lists no files for these years or this region"))
  items[, dest := file.path(ctx$dl, file)]; if (!"fetch" %in% names(items)) items[, fetch := TRUE]
  get <- items[fetch == TRUE]; remote <- items[fetch == FALSE]
  if (check_only) { s <- url_sizes(get$url); miss <- sum(is.na(s))
    log(sprintf("%s: %d files to fetch, %.0f MB%s%s", h$name, nrow(get), sum(s, na.rm = TRUE) / 1e6, if (miss) sprintf(" (%d sizes unknown)", miss) else "",
                if (nrow(remote)) sprintf("; %d archives read remotely for the region only", nrow(remote)) else ""))
    return(out("would download", nrow(items), sum(s, na.rm = TRUE) / 1e6,
               paste(c(if (miss) sprintf("%d files did not report a size", miss), if (nrow(remote)) "read remotely: only the region is written"), collapse = "; "))) }
  mb <- 0
  if (nrow(get)) { sizes <- url_sizes(get$url)
    log(sprintf("%s: fetching %d files (%.0f MB%s)", h$name, nrow(get), sum(sizes, na.rm = TRUE) / 1e6, if (anyNA(sizes)) ", some sizes unknown" else ""))
    fetch_files(get$url, get$dest, ctx$connections, log, sizes); mb <- sum(file.size(get$dest), na.rm = TRUE) / 1e6 }
  if (nrow(remote)) log(sprintf("%s: reading %d archives remotely, writing the region only", h$name, nrow(remote)))
  log(sprintf("%s: %.0f MB fetched; unpacking%s", h$name, mb, if (is.null(ctx$region$poly) || ctx$keep) "" else " and clipping to the region"))
  path <- h$finish(ctx, items)
  # record: every file under the place, with checksums; the manifest row
  fr <- files_rows(ctx$home, col, path, sha = TRUE); write_files(ctx$home, fr)
  copy <- if (is.null(ctx$region$poly) || ctx$keep || isTRUE(h$national)) "national" else "clipped"
  src <- layout[Column == col]
  write_manifest(ctx$home, data.table::data.table(Column = col, Dataset = h$name, Source = src$Source, Version = if (!is.null(h$version)) h$version else src$Version,
    Url = paste(unique(dirname(items$url)), collapse = " "), Doi = src$Doi, Method = "direct", Copy = copy,
    Units = ctx$region$units, BufferKm = ctx$region$buffer_km, Xmin = ctx$region$box[1], Ymin = ctx$region$box[2], Xmax = ctx$region$box[3], Ymax = ctx$region$box[4],
    Files = nrow(fr), Bytes = sprintf("%.0f", sum(as.numeric(fr$Bytes))), Downloaded = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), Status = "done",
    Note = if (!is.null(h$note)) h$note else NA_character_))
  unlink(ctx$dl, recursive = TRUE)
  log(sprintf("%s: done, %d files, %.0f MB at %s", h$name, nrow(fr), sum(as.numeric(fr$Bytes)) / 1e6, substring(path, nchar(ctx$home) + 2)))
  out("done", nrow(fr), sum(as.numeric(fr$Bytes)) / 1e6) }

# a failed dataset: its manifest row says so (kept from an earlier done run otherwise untouched files would be lost: only a
# dataset with no done row gets a failed row)
record_failure <- function(home, h, msg) {
  m <- read_manifest(home)[Column == h$column]
  if (!nrow(m) || m$Status != "done") write_manifest(home, data.table::data.table(Column = h$column, Dataset = h$name, Status = "failed", Note = substr(msg, 1, 500))) }
