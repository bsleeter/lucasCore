# =============================================================================
# strata.R - study areas and secondary / tertiary strata from any polygon source (shared by tools/new-library.R and stage 1)
# =============================================================================
# The primary stratum is fixed: the FIA ecodivisions the growth curves are fitted on. The project's Stratum Sources sheet lists every
# polygon source (the presets in defaults/strata/presets.csv, plus any custom row); each scenario picks its secondary and tertiary
# source in Build Options and its study area (units of any source) in Study Area. Because stages cannot write project lists, the stsim
# Secondary and Tertiary Strata lists are "universal": every unit of every source (tools/new-library.R), named "<Prefix>: <name>" with
# Id = Number x UNIT_OFFSET + the source's own id. One row per source, these columns:
#   Number, Prefix       the source's number (the Id offset; never reuse one) and the prefix of its unit names
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
# A source's own ids must be below UNIT_OFFSET (1e8) and Number x 1e8 must fit stsim's 32-bit integers (Number <= 20), so HUC10 and
# HUC12 codes cannot be ids. Files named in a row are read relative to defaults/strata when they are not absolute. A preset whose File
# is blank, or names a file this machine lacks, reads its polygons from Data Sources Home (strata_path; presets.csv DataSource).
# A stack (user 2026-11-20: Secondary = Land Manager, Tertiary = Land Designation) is a source with no polygons or units of its own:
# presets.csv Stack names other sources in order, and each cell takes the unit of the first of them whose polygons cover it (a park
# before the national forest whose boundary overlaps it; wilderness before a monument that holds it). Cells none covers take the
# StackRest source's unit under its own fill rule (blank = the last of the stack): Land Manager's are the Federal Lands owner classes,
# Land Designation's "Not designated wilderness". Its cells carry the members' own unit ids, so the unit lists need nothing new, and
# its Number (100 and up) is never a unit id. The Stratum Sources sheet has no Stack column: a row is a stack by its preset's name.
# =============================================================================

STRATA_COLS <- c("Preset", "Number", "Prefix", "File", "Layer", "IdField", "NameTemplate", "ValueField", "CrosswalkFile", "ListFile",
                 "Dissolve", "Overlap", "Fill", "FillDistance", "DefaultId")
UNIT_OFFSET <- 1e8
unit_id <- function(number, id) as.integer(as.numeric(number) * UNIT_OFFSET + as.numeric(id))
unit_source <- function(uid) as.integer(as.numeric(uid) %/% UNIT_OFFSET)
unit_native <- function(uid) as.integer(as.numeric(uid) %% UNIT_OFFSET)

# the universal unit list (Name, Id) over every source row: "<Prefix>: <name>", Number x 1e8 + id
universal_list <- function(rows, pkgdir) data.table::rbindlist(lapply(Filter(function(s) is.null(strata_stack(s, pkgdir)), rows), function(s) {
  if (is.na(s$Number) || is.na(s$Prefix)) stop(sprintf("strata source %s needs a Number and a Prefix", s$Preset), call. = FALSE)
  l <- strata_list(s, pkgdir)
  if (any(l$Id >= UNIT_OFFSET)) stop(sprintf("%s: ids must be below %.0f", s$Preset, UNIT_OFFSET), call. = FALSE)
  data.table::data.table(Name = paste0(s$Prefix, ": ", l$Name), Id = unit_id(s$Number, l$Id)) }))

# a strata source row (list) with blanks as NA
strata_row <- function(x) { x <- as.list(x); for (k in STRATA_COLS) { v <- x[[k]]
    if (is.null(v) || length(v) == 0 || (is.character(v) && !nzchar(v))) v <- NA
    x[[k]] <- v[1] }
  x$Dissolve <- isTRUE(as.logical(x$Dissolve)) || identical(toupper(as.character(x$Dissolve)), "YES")
  if (is.na(x$Overlap)) x$Overlap <- "Last"; if (is.na(x$Fill)) x$Fill <- "Nearest"
  x$Number <- suppressWarnings(as.integer(x$Number))
  x }
# the project's Stratum Sources sheet (Name = the preset name) as source rows keyed by name
sources_from_sheet <- function(ss) { ss <- data.table::as.data.table(ss); if ("Name" %in% names(ss)) data.table::setnames(ss, "Name", "Preset")
  setNames(lapply(seq_len(nrow(ss)), function(i) strata_row(ss[i])), ss$Preset) }

# the presets shipped with the package, keyed by name
strata_presets <- function(pkgdir) {
  p <- data.table::fread(file.path(pkgdir, "defaults", "strata", "presets.csv"), sep = ",", colClasses = "character", na.strings = "")
  setNames(lapply(seq_len(nrow(p)), function(i) strata_row(p[i])), p$Preset) }

# a stack's members (in order) and the source of its uncovered cells, from the preset of its name; NULL for a source of its own polygons
strata_stack <- function(s, pkgdir) {
  p <- data.table::fread(file.path(pkgdir, "defaults", "strata", "presets.csv"), sep = ",", colClasses = "character", na.strings = "")
  i <- match(s$Preset, p$Preset); if (is.na(i) || !"Stack" %in% names(p) || is.na(p$Stack[i]) || !nzchar(p$Stack[i])) return(NULL)
  m <- trimws(strsplit(p$Stack[i], ";", fixed = TRUE)[[1]]); m <- m[nzchar(m)]
  rest <- if ("StackRest" %in% names(p) && !is.na(p$StackRest[i]) && nzchar(p$StackRest[i])) trimws(p$StackRest[i]) else m[length(m)]
  list(members = m, rest = rest) }

strata_file <- function(f, pkgdir) if (is.na(f)) NA_character_ else if (grepl("^([A-Za-z]:|/|\\\\)", f)) f else file.path(pkgdir, "defaults", "strata", f)

# the Data Sources Home dataset a preset's polygons come from (presets.csv DataSource: StatesFile, CountiesFile, ...), else NA
strata_home_column <- function(preset, pkgdir) {
  p <- data.table::fread(file.path(pkgdir, "defaults", "strata", "presets.csv"), sep = ",", colClasses = "character", na.strings = "")
  v <- if ("DataSource" %in% names(p)) p$DataSource[match(preset, p$Preset)] else NA_character_
  if (length(v) != 1 || is.na(v) || !nzchar(v)) NA_character_ else v }

# where a source's polygons are read: its File when that exists on this machine; else, for a preset, its place in Data Sources Home
# (a Data Download scenario fetches every preset's polygons there). The home is looked up by the function in option
# lucas.strata.home (column -> path or NA; set by src/shared.R for the stages); without it only a File can be read.
strata_path <- function(s, pkgdir) {
  f <- strata_file(s$File, pkgdir); if (!is.na(f) && file.exists(f)) return(f)
  col <- strata_home_column(s$Preset, pkgdir); look <- getOption("lucas.strata.home")
  lay <- if (!is.na(col)) strata_presets(pkgdir)[[s$Preset]]$Layer else NA   # (the home copy is read with the preset's layer)
  p <- if (!is.na(col) && is.function(look)) { if (length(formals(look)) > 1) look(col, lay) else look(col) } else NA_character_
  if (!is.na(p) && file.exists(p)) return(structure(p, home = TRUE))
  stop(sprintf("strata source %s: %s", s$Preset,
    if (!is.na(col)) sprintf("%snot in Data Sources Home: run a Data Download scenario (dataset %s), or set the source's File on the Stratum Sources page",
                             if (!is.na(f)) sprintf("%s not found, and ", f) else "", col)
    else if (!is.na(f)) sprintf("%s not found (set the source's File on the Stratum Sources page)", f)
    else "no File: set one on the Stratum Sources page"), call. = FALSE) }

# fill a "{field}" template from a data frame's columns
fill_template <- function(tpl, d) { out <- rep(tpl, nrow(d))
  for (k in regmatches(tpl, gregexpr("\\{[^}]+\\}", tpl))[[1]]) { f <- gsub("[{}]", "", k)
    if (!f %in% names(d)) stop(sprintf("name template field %s is not in the source", f), call. = FALSE)
    out <- mapply(function(o, v) sub(k, v, o, fixed = TRUE), out, as.character(d[[f]]), USE.NAMES = FALSE) }
  out }

# curved polygons (MULTISURFACE, CURVEPOLYGON: PAD-US has some) made straight-edged by GDAL, which sf and terra cannot rasterize
linear_polygons <- function(p) {
  bad <- !as.character(sf::st_geometry_type(p)) %in% c("POLYGON", "MULTIPOLYGON")
  if (!any(bad)) return(p)
  a <- tempfile(fileext = ".gpkg"); b <- tempfile(fileext = ".gpkg"); on.exit(unlink(c(a, b)))
  sf::write_sf(sf::st_sf(i = which(bad), geometry = sf::st_geometry(p)[bad]), a, quiet = TRUE)
  sf::gdal_utils("vectortranslate", a, b, options = c("-nlt", "CONVERT_TO_LINEAR", "-nlt", "PROMOTE_TO_MULTI"), quiet = TRUE)
  x <- sf::read_sf(b); g <- sf::st_geometry(p); g[x$i] <- sf::st_set_crs(sf::st_geometry(x), sf::st_crs(p)); sf::st_geometry(p) <- g
  p }

# the polygons of a source in EPSG:5070 with an integer column StratumId; `bbox` (an sf bbox in 5070) limits what is read
strata_polygons <- function(s, pkgdir, bbox = NULL) {
  f <- strata_path(s, pkgdir)
  # a home copy is laid out by the package (src/download-sources.R), so the preset's read fields apply, not the library row's
  # (a library made before the home kept, say, Federal Lands as the National Atlas file: ADMIN1, no layer)
  if (isTRUE(attr(f, "home"))) { pr <- strata_presets(pkgdir)[[s$Preset]]
    for (k in c("Layer", "IdField", "ValueField", "CrosswalkFile", "NameTemplate", "Dissolve")) s[[k]] <- pr[[k]]
    f <- as.character(f) }
  args <- list(dsn = f, quiet = TRUE); if (!is.na(s$Layer)) args$layer <- s$Layer
  if (!is.null(bbox)) { crs0 <- sf::st_crs(do.call(sf::read_sf, c(args, list(query = sprintf("SELECT * FROM \"%s\" LIMIT 0",
      if (!is.na(s$Layer)) s$Layer else tools::file_path_sans_ext(basename(f)))))))
    # densified first: an Albers rectangle's edges are curves in lon/lat, and a 4-corner polygon cuts off the northern border
    args$wkt_filter <- sf::st_as_text(sf::st_transform(sf::st_segmentize(sf::st_as_sfc(bbox), 5000), crs0)) }
  p <- suppressWarnings(sf::st_transform(linear_polygons(do.call(sf::read_sf, args)), "EPSG:5070"))
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

# a source's polygons on grid R with overlaps resolved and nothing filled: cells no polygon covers stay NA. list(r, p = the polygons)
strata_cover <- function(s, pkgdir, R) {
  p <- strata_polygons(s, pkgdir, bbox = sf::st_bbox(terra::ext(R) + 50000, crs = sf::st_crs(5070)))
  fun <- switch(tolower(s$Overlap), last = "last", min = "min", max = "max", first = "first", stop(sprintf("unknown Overlap %s", s$Overlap)))
  if (!nrow(p)) return(list(r = terra::init(R, NA_integer_), p = p))   # (no polygon of the source reaches the grid)
  r <- if (fun == "last") terra::rasterize(terra::vect(p), R, "StratumId") else terra::rasterize(terra::vect(p), R, "StratumId", fun = fun)
  list(r = r, p = p) }

# a strata raster on grid R for the land cells of P (the primary strata): rasterize, resolve overlaps, fill uncovered land cells
strata_raster <- function(s, pkgdir, R, P) {
  cv <- strata_cover(s, pkgdir, R); r <- cv$r; p <- cv$p
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
    if (length(cells) && !nrow(p)) stop(sprintf("%s: no polygon reaches the study area, so its uncovered cells cannot take the nearest unit", s$Preset), call. = FALSE)
    if (length(cells)) { pts <- sf::st_as_sf(as.data.frame(terra::xyFromCell(R, cells)), coords = c("x", "y"), crs = 5070)
      r[cells] <- p$StratumId[sf::st_nearest_feature(pts, p)] }
  }
  r <- terra::mask(r, P)
  attr(r, "filled") <- n_gap; attr(r, "unmatched") <- attr(p, "unmatched")
  r }

# a slot's units on grid R for the land cells of P, as universal ids (Number x UNIT_OFFSET + the source's own id). A source of its
# own polygons: strata_raster. A stack: the first member whose polygons cover the cell, the rest from its StackRest source.
# rows: every source row by name. Attributes: filled (cells no polygon covered), unmatched, numbers (the Numbers its units can
# have), and for a stack cells (land cells each member gave, in order) and rest (the source of the others)
strata_units <- function(s, pkgdir, R, P, rows) {
  st <- strata_stack(s, pkgdir)
  if (is.null(st)) { r <- strata_raster(s, pkgdir, R, P); out <- r + s$Number * UNIT_OFFSET
    attr(out, "filled") <- attr(r, "filled"); attr(out, "unmatched") <- attr(r, "unmatched"); attr(out, "numbers") <- s$Number; return(out) }
  miss <- setdiff(c(st$members, st$rest), names(rows))
  if (length(miss)) stop(sprintf("%s stacks %s, which Stratum Sources does not list: add the source%s to the library", s$Preset, paste(miss, collapse = ", "), if (length(miss) > 1) "s" else ""), call. = FALSE)
  land <- !is.na(P); out <- NULL; um <- character(); n <- integer()
  for (k in st$members) { m <- rows[[k]]; cv <- strata_cover(m, pkgdir, R); u <- terra::mask(cv$r + m$Number * UNIT_OFFSET, P)
    new <- if (is.null(out)) !is.na(u) else is.na(out) & !is.na(u)
    n[k] <- as.integer(terra::global(new & land, "sum", na.rm = TRUE)[[1]]); out <- if (is.null(out)) u else terra::cover(out, u)
    um <- c(um, attr(cv$p, "unmatched")) }
  n_gap <- as.integer(terra::global(land & is.na(out), "sum", na.rm = TRUE)[[1]])
  if (n_gap > 0) { m <- rows[[st$rest]]; out <- terra::cover(out, strata_raster(m, pkgdir, R, P) + m$Number * UNIT_OFFSET) }
  out <- terra::mask(out, P)
  attr(out, "filled") <- n_gap; attr(out, "unmatched") <- unique(um); attr(out, "cells") <- n; attr(out, "rest") <- st$rest
  attr(out, "numbers") <- unique(vapply(rows[unique(c(st$members, st$rest))], function(m) as.integer(m$Number), 1L))
  out }

# ---- units the study area does not name (user 2026-11-20: remove them from the study area) ------------------------------------------
# A study area of named units (a park, the forest around it, their wilderness areas) leaves cells in a slot that belong to none of
# them: a sliver of another unit where two boundaries disagree (2 cells of a wilderness nobody named), or the few cells no polygon of
# the slot covers. Those cells leave the study area. v: a slot's universal unit ids by cell (NA = not land); named: the universal ids
# of the study area's units; numbers: the Numbers the slot's units can have; defaults: the universal ids of its sources' uncovered
# classes (Non Federal, Not designated wilderness). The rule, for a slot the study area names units of (any other slot - states or
# watersheds under a park - is left alone: an empty table):
#   a named unit stays, whatever its size;
#   a unit not named is removed, unless it holds `keep` of the land or more (1%): that is no sliver but land a named unit of another
#     kind brought in (a named wilderness inside a forest that was not named), and removing it would take a named unit's land;
#   an uncovered class stays (Not designated wilderness is most of a forest), unless it holds under `sliver` of the land (0.1%).
# Returns Id, Cells, Share, Default, Drop for the units present and not named.
strata_unnamed <- function(v, named, numbers, defaults, sliver = 0.001, keep = 0.01) {
  none <- data.table::data.table(Id = numeric(), Cells = integer(), Share = numeric(), Default = logical(), Drop = logical())
  if (!length(named) || !any(unit_source(named) %in% numbers)) return(none)
  v <- v[!is.na(v)]; if (!length(v)) return(none)
  t <- data.table::data.table(Id = as.numeric(v))[, .(Cells = .N), by = Id][!Id %in% as.numeric(named)]
  if (!nrow(t)) return(none)
  t[, Share := Cells / length(v)][, Default := Id %in% as.numeric(defaults)]
  t[, Drop := ifelse(Default, Share < sliver, Share < keep)]
  t[order(-Cells)] }
