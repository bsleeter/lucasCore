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
# which cells become forest: those with enough passing pixels, or as many as make the Build's forest area the 30 m rule's
FOREST_CELL_RULE <- c(share = "A share of the cell's pixels", area = "Area-matched")
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
  list(definition = pick("ForestDefinition", FOREST_DEFINITION, "Forest in the Start Year"), threshold = th, gate = pick("CanopyGate", FOREST_GATE, "Where"), rule = pick("CellRule", FOREST_CELL_RULE, "Cells That Become Forest"), share = sh, folder = f) }

# the cells tree canopy makes forest. One element per cell:
#   nlcd    the start-year NLCD class        share   the share of the cell's 30 m pixels that pass the rule (NA = none read)
#   woody   TRUE on woody wetland cells (they keep their wetland class)
# Only barren (31), shrub (52) and grass (71) can change: forest is forest already; water, ice, developed and farm land keep
# their class (as under the any-year rule); wetlands keep theirs.
canopy_forest <- function(nlcd, share, woody = FALSE, min_share = 0.5) nlcd %in% c(31L, 52L, 71L) & !(woody %in% TRUE) & !is.na(share) & share >= min_share

# Area-matched (Forest Cover: Cells That Become Forest). A cell takes its most common class, so on a coarse grid a landscape that is
# mostly forest gains forest (P26 at 500 m, 2026-11-18: the 10% rule gives 87.2% of the land at 30 m and 93.7% on the grid). Here
# the canopy makes forest of only as many cells as bring each unit's forest area up to the 30 m rule's: per unit, the cells still
# to add = the sum of the cells' 30 m forest share under the rule (NLCD forest or woody wetland, or a barren, shrub or grass pixel
# that passes) less the cells that are forest already, never below 0; they are the candidates with the most passing pixels.
#   share   each cell's share of passing pixels (the ranking)   cand      the cells the canopy may change (canopy_forest's classes)
#   target  each cell's 30 m forest share under the rule        existing  TRUE on cells that are forest already
#   unit    the unit each cell is in (the secondary stratum; one value = the whole study area); land  the cells that count
canopy_area_match <- function(share, cand, unit, target, existing, land = !is.na(target)) {
  out <- rep(FALSE, length(share)); unit <- rep_len(unit, length(share)); unit[is.na(unit)] <- -1L; ok <- land & !is.na(target)
  d <- data.table::data.table(i = seq_along(share), share, cand = cand %in% TRUE & land & !is.na(share) & share > 0, unit, target = ifelse(ok, target, 0), existing = existing %in% TRUE & land)
  need <- d[, .(n = max(0, round(sum(target) - sum(existing)))), by = unit]
  pick <- d[cand == TRUE][order(unit, -share)][, k := seq_len(.N), by = unit][need, on = "unit", nomatch = 0][k <= n, i]
  out[pick] <- TRUE; out }

# the 0/1 raster of 30 m pixels that pass: canopy cover (percent; over 100 or NA = no data, which never passes) at or over the
# threshold, and - with a gate - a 1 in `potential` (same grid: 1 where BpS is forest)
canopy_pass <- function(canopy, threshold, potential = NULL) {
  p <- terra::classify(canopy, rbind(c(-Inf, threshold, 0), c(threshold, 100.5, 1), c(100.5, Inf, 0)), right = FALSE); p <- terra::subst(p, NA, 0)
  if (!is.null(potential)) p <- p * terra::subst(potential, NA, 0)
  p }

# ---- the forest area check: the Build's forest against FIA's (user 2026-11-18: "it would be useful after a build to know how well it
# compares against FIA so a user can fine tune this setting") ---------------------------------------------------------------------
# FIA calls a condition forest land (COND_STATUS_CD 1) when it has, or had before a disturbance, at least 10% canopy cover of trees,
# is an acre or more and 120 feet wide, and is not developed for another use; 2 is other land, 3 and 4 water, 5 not sampled.
# The estimate is a ratio over plots, each plot's newest visit in the last `span` inventory years: forest condition proportion over
# forest and other land. It ignores FIA's strata and the plots' coordinates are fuzzed (up to a mile), so it is an approximation;
# its standard error is the ratio estimator's, plots taken as a simple random sample.

# the plots of every state table in the FIA DataMart folder inside a longitude/latitude box (xmin, ymin, xmax, ymax; NAD83)
fia_plots_box <- function(dm, box) {
  fs <- list.files(dm, "^[A-Z]{2}_PLOT[.]csv$", full.names = TRUE); if (!length(fs)) return(data.table::data.table())
  data.table::rbindlist(lapply(fs, function(f) { x <- data.table::fread(f, select = c("CN", "INVYR", "STATECD", "UNITCD", "COUNTYCD", "PLOT", "LAT", "LON"), colClasses = list(character = "CN"), showProgress = FALSE)
    x <- x[!is.na(LAT) & !is.na(LON) & LON >= box[1] & LON <= box[3] & LAT >= box[2] & LAT <= box[4]]; if (nrow(x)) x[, State := substr(basename(f), 1, 2)]; x }), fill = TRUE) }

# the conditions of the given plots (PLT_CN, COND_STATUS_CD, CONDPROP_UNADJ), from the states' COND tables
fia_conds <- function(dm, plots) {
  if (!nrow(plots)) return(data.table::data.table(PLT_CN = character(), COND_STATUS_CD = integer(), CONDPROP_UNADJ = numeric()))
  data.table::rbindlist(lapply(unique(plots$State), function(s) { f <- file.path(dm, paste0(s, "_COND.csv")); if (!file.exists(f)) return(NULL)
    data.table::fread(f, select = c("PLT_CN", "COND_STATUS_CD", "CONDPROP_UNADJ"), colClasses = list(character = "PLT_CN"), showProgress = FALSE)[PLT_CN %in% plots$CN] })) }

# FIA's forest share of the land: plots (CN, INVYR, STATECD, UNITCD, COUNTYCD, PLOT; already inside the study area) and their
# conditions. Returns share and se (fractions; NA with fewer than min_plots plots), plots, and the first, last and median visit year
fia_forest_share <- function(plots, conds, span = 12, min_plots = 20) {
  none <- list(share = NA_real_, se = NA_real_, plots = 0L, from = NA_integer_, to = NA_integer_, median = NA_integer_)
  if (!nrow(plots) || !nrow(conds)) return(none)
  p <- data.table::as.data.table(plots)[INVYR >= max(INVYR) - span + 1 & INVYR < 9999][order(-INVYR)]; p <- p[!duplicated(p[, .(STATECD, UNITCD, COUNTYCD, PLOT)])]
  cd <- data.table::as.data.table(conds)[PLT_CN %in% p$CN]
  pp <- cd[, .(f = sum(CONDPROP_UNADJ[COND_STATUS_CD == 1], na.rm = TRUE), land = sum(CONDPROP_UNADJ[COND_STATUS_CD %in% 1:2], na.rm = TRUE)), by = PLT_CN][land > 0]
  n <- nrow(pp); yr <- p[CN %in% pp$PLT_CN, INVYR]; out <- list(share = NA_real_, se = NA_real_, plots = n, from = if (n) min(yr) else NA_integer_, to = if (n) max(yr) else NA_integer_, median = if (n) as.integer(stats::median(yr)) else NA_integer_)
  if (n < min_plots) return(out)
  R <- sum(pp$f) / sum(pp$land); out$share <- R; out$se <- sqrt(sum((pp$f - R * pp$land)^2) / (n - 1) / n) / mean(pp$land); out }

# what the comparison says, in a sentence: within two standard errors, or how far off and which way
forest_area_verdict <- function(build, fia, se) {
  if (is.na(fia)) return("too few FIA plots in the study area to compare")
  d <- 100 * (build - fia); if (abs(build - fia) <= 2 * se) return(sprintf("within two standard errors of FIA (%+.1f points)", d))
  sprintf("%.1f points %s than FIA, more than two standard errors", abs(d), if (d > 0) "more forest" else "less forest") }
