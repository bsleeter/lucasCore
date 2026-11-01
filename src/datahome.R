# =============================================================================
# datahome.R - the Data Sources Home folder (to-do 12): each dataset's standard place in it, and the manifest
# =============================================================================
# Data Sources: Data Sources Home names one folder. defaults/library/data-sources.csv (HomePath) gives every Data Sources column its
# place under it: a folder column's subfolder ("land-cover/nlcd-annual"), or a file column's subfolder and file pattern, alternatives
# split by "|" ("disturbance/fire-perimeters/*.shp|*.gpkg"). A pattern must match exactly one file. A blank Data Sources path reads
# its home place (src/shared.R, read_data_sources). The Data Download stage writes this layout, and two tables at the top:
#   manifest.csv  one row per dataset: what it is, where it came from, the region it covers (EPSG:5070) and its status
#   files.csv     one row per file: path under the home folder, bytes, sha256, modified time (a rerun skips finished files)
# The Build's coverage checks and the metadata generator (to-do 14) read the manifest. No rsyncrosim here: tools and tests source it.
# =============================================================================

MANIFEST_COLS <- c("Column", "Dataset", "Source", "Version", "Url", "Doi", "Method", "Copy", "Units", "BufferKm",
                   "Xmin", "Ymin", "Xmax", "Ymax", "Files", "Bytes", "Downloaded", "Status", "Note")
FILES_COLS <- c("Column", "Path", "Bytes", "Sha256", "Modified")
MANIFEST_STATUS <- c("done", "partial", "manual", "failed")

# the package's data sources table: Column, HomePath and the descriptive columns
home_layout <- function(pkgdir) data.table::fread(file.path(pkgdir, "defaults", "library", "data-sources.csv"), sep = ",",
                                                   colClasses = "character", na.strings = "", encoding = "UTF-8")

# the home place of one HomePath: the folder or the one matching file, else NA with attribute "found" (files matched, 0 or 2+)
home_path <- function(home, homepath) {
  if (is.null(home) || is.na(home) || !nzchar(home) || is.na(homepath)) return(structure(NA_character_, found = 0L))
  parts <- strsplit(homepath, "|", fixed = TRUE)[[1]]
  # a folder counts only when it holds something: Make folders / home_create leave every place empty
  if (!grepl("*", parts[1], fixed = TRUE)) { p <- file.path(home, parts[1]); return(if (dir.exists(p) && length(list.files(p))) p else structure(NA_character_, found = 0L)) }
  dir <- dirname(file.path(home, parts[1])); pats <- c(basename(parts[1]), parts[-1])
  f <- unique(unlist(lapply(pats, function(p) Sys.glob(file.path(dir, p))))); f <- f[!dir.exists(f)]
  if (length(f) == 1) f else structure(NA_character_, found = length(f)) }

# every dataset's home place, and whether it is there: Column, Place (the HomePath), Path (NA if missing), Found (files matched)
home_status <- function(home, pkgdir) {
  d <- home_layout(pkgdir)[!is.na(HomePath)]
  r <- lapply(d$HomePath, function(h) home_path(home, h))
  data.table::data.table(Column = d$Column, Place = d$HomePath, Path = vapply(r, function(x) x[1], ""),
                         Found = vapply(r, function(x) if (is.na(x[1])) attr(x, "found") else 1L, 1L)) }

# make the empty layout (folders only; nothing is moved or deleted). Returns the folders it made
home_create <- function(home, pkgdir) {
  d <- home_layout(pkgdir)[!is.na(HomePath)]
  dirs <- file.path(home, unique(c(vapply(d$HomePath, function(h) { p <- strsplit(h, "|", fixed = TRUE)[[1]][1]
    if (grepl("*", p, fixed = TRUE)) dirname(p) else p }, ""), "logs")))
  made <- dirs[!dir.exists(dirs)]; for (x in made) dir.create(x, recursive = TRUE)
  invisible(made) }

# ---- manifest.csv and files.csv ------------------------------------------------------------------------------------------
.home_table <- function(home, name, cols) {
  f <- file.path(home, name)
  if (!file.exists(f)) return(data.table::as.data.table(setNames(rep(list(character(0)), length(cols)), cols)))
  x <- data.table::fread(f, sep = ",", colClasses = "character", na.strings = "", encoding = "UTF-8")
  for (k in setdiff(cols, names(x))) x[, (k) := rep(NA_character_, nrow(x))]
  x[, cols, with = FALSE] }
read_manifest <- function(home) .home_table(home, "manifest.csv", MANIFEST_COLS)
read_files <- function(home) .home_table(home, "files.csv", FILES_COLS)

# settings.csv: Key,Value pairs that belong to the person filling the home folder rather than to a scenario (LfpsEmail: the address
# LANDFIRE Product Service jobs are submitted with; the Data Download page writes it)
home_setting <- function(home, key) { f <- file.path(home, "settings.csv"); if (!file.exists(f)) return(NA_character_)
  x <- data.table::fread(f, colClasses = "character", na.strings = ""); v <- x$Value[x$Key == key]; if (length(v)) v[1] else NA_character_ }

# replace the rows of the given columns (manifest: one row per Column; files: every row of those Columns), keep the rest. Written
# through a temporary file and renamed, so a stopped run never leaves half a table
.write_home_table <- function(home, name, cols, old, rows) {
  rows <- data.table::as.data.table(rows); for (k in setdiff(cols, names(rows))) rows[, (k) := rep(NA_character_, nrow(rows))]
  rows <- rows[, cols, with = FALSE][, (cols) := lapply(.SD, as.character)]
  out <- rbind(old[!Column %in% rows$Column], rows); data.table::setorder(out, Column)
  f <- file.path(home, name); tmp <- paste0(f, ".tmp"); data.table::fwrite(out, tmp); file.rename(tmp, f)
  invisible(out) }
write_manifest <- function(home, rows) {
  rows <- data.table::as.data.table(rows)
  if (anyDuplicated(rows$Column)) stop("manifest: one row per dataset (", paste(unique(rows$Column[duplicated(rows$Column)]), collapse = ", "), ")", call. = FALSE)
  bad <- setdiff(rows$Status, MANIFEST_STATUS); if (length(bad)) stop("manifest: unknown status ", paste(bad, collapse = ", "), call. = FALSE)
  .write_home_table(home, "manifest.csv", MANIFEST_COLS, read_manifest(home), rows) }
write_files <- function(home, rows) .write_home_table(home, "files.csv", FILES_COLS, read_files(home), rows)

# the file rows of one dataset as on disk now: every file under its home place, path relative to the home folder. sha256 only
# when asked (it reads every byte)
files_rows <- function(home, column, path, sha = FALSE) {
  # a file column: the file and its sidecars (a shapefile's .dbf, .shx, .prj; a raster's .aux.xml)
  f <- if (dir.exists(path)) list.files(path, recursive = TRUE, full.names = TRUE) else {
    a <- list.files(dirname(path), full.names = TRUE); a[startsWith(basename(a), paste0(tools::file_path_sans_ext(basename(path)), "."))] }
  if (!length(f)) return(data.table::data.table())
  i <- file.info(f, extra_cols = FALSE); rel <- substring(normalizePath(f, winslash = "/"), nchar(normalizePath(home, winslash = "/")) + 2)
  data.table::data.table(Column = column, Path = rel, Bytes = sprintf("%.0f", i$size),
                         Sha256 = if (sha) vapply(f, function(x) digest::digest(file = x, algo = "sha256"), "") else NA_character_,
                         Modified = format(i$mtime, "%Y-%m-%dT%H:%M:%S")) }

# does the manifest show a dataset done for a box (EPSG:5070: xmin, ymin, xmax, ymax)? TRUE / FALSE, or NA when the manifest has no
# row for it (a path set by hand, or a home folder laid out by hand: nothing to check against). National copies cover everything
manifest_covers <- function(home, column, box) {
  m <- read_manifest(home)[Column == column]
  if (!nrow(m)) return(NA)
  if (m$Status != "done") return(FALSE)
  if (identical(m$Copy, "national")) return(TRUE)
  e <- suppressWarnings(as.numeric(unlist(m[, .(Xmin, Ymin, Xmax, Ymax)])))
  if (anyNA(e)) return(FALSE)
  # within a metre: the box goes through text in manifest.csv (15 significant digits)
  box[1] >= e[1] - 1 && box[2] >= e[2] - 1 && box[3] <= e[3] + 1 && box[4] <= e[4] + 1 }
