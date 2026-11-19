# =============================================================================
# forest-cover.R - what counts as forest in the start year: NLCD's classes, or tree canopy cover (stage 5; Forest Cover page)
# =============================================================================
# Annual NLCD under-maps open forest in the West: it calls 44% of Yellowstone's land forest or woody wetland in 2016 and 66% of the
# Northern Sierra Nevada pyrome's (P26), where FIA has 83% and 85%; the rest is mostly its shrub and grass classes, on land whose
# LANDFIRE BpS is forest. User, 2026-11-18: "rather than use NLCD to tell us what is forest in 1985, we use the tree cover product
# ... set the tree cover % threshold (i.e. 10%)".
# The rule (checked 2026-11-18 against FIA forest area, newest plot visits of 2012-2022, with USFS Science Tree Canopy Cover 2016):
# a 30 m pixel is forest when its canopy cover is at or over the threshold AND its BpS is forest. At 10%:
#     Yellowstone 85.8% of the land (FIA 83.3, s.e. 1.9)   P26 85.8% (FIA 85.3, s.e. 1.0)   Great Dismal Swamp 57.5% (FIA 52.1, s.e. 5.2)
# 10% is also FIA's own definition of forest land. Without the BpS gate the same threshold gives 90.9% and 90.1% in the two western
# regions: the canopy product gives NLCD's shrub and grass a median cover of 20-25% there, so canopy alone takes in most shrubland.
# What it changes in stage 5: a natural cell NLCD calls barren, shrub or grass in the start year (not a wetland) starts as forest, of
# the forest type map's type and the age map's age, when at least half of its 30 m pixels pass the rule. NLCD still gives every
# other class, and a cell NLCD calls forest stays forest whatever its canopy (FIA keeps a burned or cut stand as forest land).
# No rsyncrosim here: tests/unit-forest-cover.R sources it.
# =============================================================================

FOREST_DEFINITION <- c(nlcd = "Annual NLCD", canopy = "Annual NLCD and tree canopy cover")
FOREST_GATE <- c(bps = "Only where LANDFIRE BpS is forest", none = "Anywhere")
# USFS Science Tree Canopy Cover (CONUS, 30 m, one file a year, percent 0-100; larger values are no data), as Data Download names it
TCC_FILE <- "science_tcc_conus_%d.tif"; TCC_YEARS <- 1985:2023

# Forest Cover (single row; a list column reads as its number or its label; blank = the default): definition ("nlcd" or "canopy"),
# threshold (percent canopy cover, 1-100, blank 10), gate ("bps" or "none"), share (the share of a cell's pixels that must pass,
# blank 0.5) and folder (a folder of canopy files, or NA = Data Sources Home)
forest_cover_options <- function(x) {
  x <- data.table::as.data.table(x); g <- function(k) if (nrow(x) && k %in% names(x)) x[[k]][1] else NA
  pick <- function(k, labels, what) { v <- g(k); if (is.na(v) || !nzchar(as.character(v))) return(names(labels)[1]); v <- as.character(v)
    i <- if (v %in% as.character(seq_along(labels))) as.integer(v) else match(v, labels)
    if (is.na(i)) stop(sprintf("Forest Cover: %s is '%s'; use %s", what, v, paste(labels, collapse = " or ")), call. = FALSE); names(labels)[i] }
  th <- suppressWarnings(as.numeric(g("CanopyThreshold"))); if (is.na(th)) th <- 10
  if (th < 1 || th > 100) stop(sprintf("Forest Cover: Canopy Threshold is %s; give 1 to 100 (percent)", th), call. = FALSE)
  sh <- suppressWarnings(as.numeric(g("CellShare"))); if (is.na(sh)) sh <- 0.5
  if (sh <= 0 || sh > 1) stop(sprintf("Forest Cover: Share of the Cell is %s; give more than 0, up to 1", sh), call. = FALSE)
  f <- g("TreeCanopyFolder"); f <- if (is.na(f) || !nzchar(as.character(f))) NA_character_ else as.character(f)
  list(definition = pick("ForestDefinition", FOREST_DEFINITION, "Forest in the Start Year"), threshold = th, gate = pick("CanopyGate", FOREST_GATE, "Where"), share = sh, folder = f) }

# the cells tree canopy makes forest. One element per cell:
#   nlcd    the start-year NLCD class        share   the share of the cell's 30 m pixels that pass the rule (NA = none read)
#   woody   TRUE on woody wetland cells (they keep their wetland class)
# Only barren (31), shrub (52) and grass (71) can change: forest is forest already; water, ice, developed and farm land keep
# their class (as under the any-year rule); wetlands keep theirs.
canopy_forest <- function(nlcd, share, woody = FALSE, min_share = 0.5) nlcd %in% c(31L, 52L, 71L) & !(woody %in% TRUE) & !is.na(share) & share >= min_share

# the 0/1 raster of 30 m pixels that pass: canopy cover (percent; over 100 or NA = no data, which never passes) at or over the
# threshold, and - with a gate - a 1 in `potential` (same grid: 1 where BpS is forest)
canopy_pass <- function(canopy, threshold, potential = NULL) {
  p <- terra::classify(canopy, rbind(c(-Inf, threshold, 0), c(threshold, 100.5, 1), c(100.5, Inf, 0)), right = FALSE); p <- terra::subst(p, NA, 0)
  if (!is.null(potential)) p <- p * terra::subst(potential, NA, 0)
  p }
