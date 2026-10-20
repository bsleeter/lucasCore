# =============================================================================
# strata.R - secondary and tertiary strata from any polygon source (shared by tools/new-library.R and stage 1)
# =============================================================================
# The primary stratum is fixed: the FIA ecodivisions the growth curves are fitted on. Secondary and tertiary strata are chosen per
# library from a preset (defaults/strata/presets.csv) or any polygon file, described by one row of these columns:
#   File, Layer          polygon source (Layer for a geodatabase or GeoPackage; blank for a shapefile)
#   IdField              numeric id field: the stsim Id (states: STATEFP, counties: GEOID, HUC8: huc8, pyromes: PYROME)
#   NameTemplate         stsim Name from fields, e.g. "{name} ({huc8})"; blank when ListFile names the ids
#   ValueField           instead of IdField: a text field mapped to ids by CrosswalkFile (Value, Id) - federal manager, GAP status
#   CrosswalkFile        Value -> Id for ValueField sources
#   ListFile             the stsim list (Name, Id) when it is not built from the source (states, counties, federal lands)
#   Dissolve             TRUE: dissolve the polygons by IdField first (EPA Level III from the Level IV file)
#   Overlap              which polygon wins where polygons overlap: Last (file order) | Min | Max (of the id)
#   Fill                 land cells no polygon covers: Modal (most common id within FillDistance) | Nearest | Default
#   FillDistance         metres, for Modal (states: 29000 m = the 59-cell window of the CONUS 1km build)
#   DefaultId            the id of uncovered cells for Fill = Default (federal lands: 9 Non Federal)
# Ids must fit stsim's 32-bit integers, so HUC10 and HUC12 codes cannot be ids.
# Files named in a row are read relative to defaults/strata when they are not absolute.
# =============================================================================

STRATA_COLS <- c("Preset", "File", "Layer", "IdField", "NameTemplate", "ValueField", "CrosswalkFile", "ListFile",
                 "Dissolve", "Overlap", "Fill", "FillDistance", "DefaultId")

# a strata source row (list) with blanks as NA
strata_row <- function(x) { x <- as.list(x); for (k in STRATA_COLS) { v <- x[[k]]
    if (is.null(v) || length(v) == 0 || (is.character(v) && !nzchar(v))) v <- NA
    x[[k]] <- v[1] }
  x$Dissolve <- isTRUE(as.logical(x$Dissolve)) || identical(toupper(as.character(x$Dissolve)), "YES")
  if (is.na(x$Overlap)) x$Overlap <- "Last"; if (is.na(x$Fill)) x$Fill <- "Nearest"
  x }

# the presets shipped with the package, keyed by name
strata_presets <- function(pkgdir) {
  p <- data.table::fread(file.path(pkgdir, "defaults", "strata", "presets.csv"), sep = ",", colClasses = "character", na.strings = "")
  setNames(lapply(seq_len(nrow(p)), function(i) strata_row(p[i])), p$Preset) }

strata_file <- function(f, pkgdir) if (is.na(f)) NA_character_ else if (grepl("^([A-Za-z]:|/|\\\\)", f)) f else file.path(pkgdir, "defaults", "strata", f)

# fill a "{field}" template from a data frame's columns
fill_template <- function(tpl, d) { out <- rep(tpl, nrow(d))
  for (k in regmatches(tpl, gregexpr("\\{[^}]+\\}", tpl))[[1]]) { f <- gsub("[{}]", "", k)
    if (!f %in% names(d)) stop(sprintf("name template field %s is not in the source", f), call. = FALSE)
    out <- mapply(function(o, v) sub(k, v, o, fixed = TRUE), out, as.character(d[[f]]), USE.NAMES = FALSE) }
  out }

# the polygons of a source in EPSG:5070 with an integer column StratumId; `bbox` (an sf bbox in 5070) limits what is read
strata_polygons <- function(s, pkgdir, bbox = NULL) {
  f <- strata_file(s$File, pkgdir); if (is.na(f) || !file.exists(f)) stop(sprintf("strata source %s not found (%s)", s$Preset, f), call. = FALSE)
  args <- list(dsn = f, quiet = TRUE); if (!is.na(s$Layer)) args$layer <- s$Layer
  if (!is.null(bbox)) { crs0 <- sf::st_crs(do.call(sf::read_sf, c(args, list(query = sprintf("SELECT * FROM \"%s\" LIMIT 0",
      if (!is.na(s$Layer)) s$Layer else tools::file_path_sans_ext(basename(f)))))))
    args$wkt_filter <- sf::st_as_text(sf::st_transform(sf::st_as_sfc(bbox), crs0)) }
  p <- suppressWarnings(sf::st_transform(do.call(sf::read_sf, args), "EPSG:5070"))
  if (!is.na(s$ValueField)) {
    if (!s$ValueField %in% names(p)) stop(sprintf("%s has no field %s", basename(f), s$ValueField), call. = FALSE)
    cw <- data.table::fread(strata_file(s$CrosswalkFile, pkgdir), sep = ",", colClasses = "character")
    p$StratumId <- as.integer(cw$Id[match(as.character(p[[s$ValueField]]), cw$Value)])
    attr(p, "unmatched") <- sort(unique(as.character(p[[s$ValueField]][is.na(p$StratumId)])))
    p <- p[!is.na(p$StratumId), ]
  } else {
    if (!s$IdField %in% names(p)) stop(sprintf("%s has no field %s", basename(f), s$IdField), call. = FALSE)
    id <- suppressWarnings(as.numeric(p[[s$IdField]]))
    if (any(is.na(id)) || any(id > .Machine$integer.max)) stop(sprintf("%s: %s is not a whole number that fits a 32-bit id", s$Preset, s$IdField), call. = FALSE)
    p$StratumId <- as.integer(id)
  }
  if (s$Dissolve) { keep <- intersect(c("StratumId", regmatches(s$NameTemplate, gregexpr("(?<=\\{)[^}]+", s$NameTemplate, perl = TRUE))[[1]]), names(p))
    p <- suppressMessages(stats::aggregate(sf::st_make_valid(p[, keep]), by = list(StratumId = p$StratumId), FUN = function(v) v[1]))
    p$StratumId.1 <- NULL; p <- p[, unique(c("StratumId", keep))] }
  p }

# the stsim list (Name, Id) of a source: its ListFile, or one row per id named from NameTemplate
strata_list <- function(s, pkgdir) {
  if (!is.na(s$ListFile)) { l <- data.table::fread(strata_file(s$ListFile, pkgdir), sep = ",", colClasses = "character")
    return(data.table::data.table(Name = l$Name, Id = as.integer(l$Id))) }
  if (is.na(s$NameTemplate)) stop(sprintf("strata source %s needs a NameTemplate or a ListFile", s$Preset), call. = FALSE)
  p <- sf::st_drop_geometry(strata_polygons(s, pkgdir))
  l <- unique(data.table::data.table(Name = fill_template(s$NameTemplate, p), Id = p$StratumId))
  if (anyDuplicated(l$Id)) stop(sprintf("%s: one id has several names - add the id to the NameTemplate", s$Preset), call. = FALSE)
  if (anyDuplicated(l$Name)) stop(sprintf("%s: several ids share a name - add the id to the NameTemplate", s$Preset), call. = FALSE)
  l[order(Id)] }

# a strata raster on grid R for the land cells of P (the primary strata): rasterize, resolve overlaps, fill uncovered land cells
strata_raster <- function(s, pkgdir, R, P) {
  p <- strata_polygons(s, pkgdir, bbox = sf::st_bbox(terra::ext(R) + 50000, crs = sf::st_crs(5070)))
  fun <- switch(tolower(s$Overlap), last = "last", min = "min", max = "max", first = "first", stop(sprintf("unknown Overlap %s", s$Overlap)))
  if (fun == "last") r <- terra::rasterize(terra::vect(p), R, "StratumId") else r <- terra::rasterize(terra::vect(p), R, "StratumId", fun = fun)
  gap <- !is.na(P) & is.na(r)
  n_gap <- terra::global(gap, "sum", na.rm = TRUE)[[1]]
  if (n_gap > 0) {
    fill <- tolower(s$Fill)
    if (fill == "default") { if (is.na(s$DefaultId)) stop(sprintf("%s: Fill = Default needs a DefaultId", s$Preset), call. = FALSE)
      r <- terra::cover(r, terra::init(R, as.integer(s$DefaultId)))
    } else if (fill == "modal") { w <- 2 * round(as.numeric(s$FillDistance) / terra::res(R)[1]) + 1
      r <- terra::cover(r, terra::focal(r, w = matrix(1, w, w), fun = "modal", na.policy = "only", na.rm = TRUE))
    } else if (fill != "nearest") stop(sprintf("unknown Fill %s", s$Fill), call. = FALSE)
    # Nearest, and any land cell a modal window did not reach: the id of the nearest polygon
    cells <- which(terra::values(!is.na(P) & is.na(r), mat = FALSE) == 1)
    if (length(cells)) { pts <- sf::st_as_sf(as.data.frame(terra::xyFromCell(R, cells)), coords = c("x", "y"), crs = 5070)
      r[cells] <- p$StratumId[sf::st_nearest_feature(pts, p)] }
  }
  r <- terra::mask(r, P)
  attr(r, "filled") <- n_gap; attr(r, "unmatched") <- attr(p, "unmatched")
  r }
