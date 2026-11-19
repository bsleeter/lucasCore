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
# when a disturbed forest cell counts as forest again in the historical record (stage 6): NLCD shows forest, or its canopy is back
FOREST_RECOVERY <- c(canopy = "NLCD forest, or tree canopy cover at the threshold", nlcd = "NLCD forest only")
# USFS Science Tree Canopy Cover (CONUS, 30 m, one file a year, percent 0-100; larger values are no data), as Data Download names it
TCC_FILE <- "science_tcc_conus_%d.tif"; TCC_YEARS <- 1985:2023
# how much carbon a forest cell holds for its type and age (stage 8): its type's curve as it is, or scaled by the cell's canopy
FOREST_STOCKING <- c(off = "The same for every cell of a forest type", canopy = "By the cell's tree canopy cover")

# Forest Cover (single row; a list column reads as its number or its label; blank = the default): definition ("nlcd" or "canopy"),
# threshold (percent canopy cover, 1-100, blank 10), gate ("bps" or "none"), share (the share of a cell's pixels that must pass,
# blank 0.5). The canopy files are a Data Source (TreeCanopyFolder), not a setting of this sheet
forest_cover_options <- function(x) {
  x <- data.table::as.data.table(x); g <- function(k) if (nrow(x) && k %in% names(x)) x[[k]][1] else NA
  pick <- function(k, labels, what) { v <- g(k); if (is.na(v) || !nzchar(as.character(v))) return(names(labels)[1]); v <- as.character(v)
    i <- if (v %in% as.character(seq_along(labels))) as.integer(v) else match(v, labels)
    if (is.na(i)) stop(sprintf("Forest Cover: %s is '%s'; use %s", what, v, paste(labels, collapse = " or ")), call. = FALSE); names(labels)[i] }
  th <- suppressWarnings(as.numeric(g("CanopyThreshold"))); if (is.na(th)) th <- 10
  if (th < 1 || th > 100) stop(sprintf("Forest Cover: Canopy Threshold is %s; give 1 to 100 (percent)", th), call. = FALSE)
  sh <- suppressWarnings(as.numeric(g("CellShare"))); if (is.na(sh)) sh <- 0.5
  if (sh <= 0 || sh > 1) stop(sprintf("Forest Cover: Share of the Cell is %s; give more than 0, up to 1", sh), call. = FALSE)
  # the recovery threshold is its own: the canopy product does not fall under about 20% on burned forest (Yellowstone, MTBS high
  # severity 1988: median 56% in 1987, 20% in 1989, 97% of the pixels still at or over 10%; at or over 30%: 8% in 1989, 33% in 2000,
  # 53% in 2023), so the start-year threshold would call a stand forest again the year after it burned
  rt <- suppressWarnings(as.numeric(g("RecoveryThreshold"))); if (is.na(rt)) rt <- 40   # (40 since 2026-11-19: at 30% shrub regrowth passed as forest in P26, median return 4 years; at 40% the return matches the projection curve)
  if (rt < 1 || rt > 100) stop(sprintf("Forest Cover: Recovery Threshold is %s; give 1 to 100 (percent)", rt), call. = FALSE)
  ma <- suppressWarnings(as.numeric(g("StockingMatureAge"))); if (is.na(ma)) ma <- 30
  if (ma < 0 || ma > 300) stop(sprintf("Forest Cover: Stocking Mature Age is %s; give 0 to 300 (years)", ma), call. = FALSE)
  list(definition = pick("ForestDefinition", FOREST_DEFINITION, "Forest in the Start Year"), threshold = th, gate = pick("CanopyGate", FOREST_GATE, "Where"), rule = pick("CellRule", FOREST_CELL_RULE, "Cells That Become Forest"), recovery = pick("CanopyRecovery", FOREST_RECOVERY, "Recovery"), recovery_threshold = rt, share = sh,
       stocking = pick("Stocking", FOREST_STOCKING, "Stocking"), mature_age = ma) }

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

# Recovery (stage 6; user 2026-11-18: "we could also use that to tell us when a disturbed stand has recovered ... everything forward
# from there is consistent using that threshold"). A disturbed forest cell returns to its type in the year NLCD shows forest for the
# second year running; NLCD is slow to call an open regrowing stand forest, and never does on a cell the canopy rule made forest.
# With the canopy rule on, the cell also returns in the year its share of pixels at the recovery threshold (its own, default 30%: see
# forest_cover_options) has been at or over the cell share for two
# years running (as NLCD's rule asks two years). The pathways still hold a cell in its disturbed class for its minimum return age.
#   prev, cur  each cell's share of passing pixels the year before and in the year (NA = no canopy read)
# lost = the cell lost its forest (a high-severity fire or a clearcut on most of it) in either of the two years: both passing years
# must come after the loss, because the canopy map of the loss year still shows the stand that stood before it (P26, 2026-11-19:
# 1,150 of 3,900 returning cells came back the year after their fire)
canopy_return_on <- function(prev, cur, min_share = 0.5, lost = FALSE) !is.na(prev) & !is.na(cur) & prev >= min_share & cur >= min_share & !lost

# years from a disturbance to the first return map that is on after it: on = a cells x years logical matrix (columns = years),
# lost = each cell's disturbance year (NA = none). Returns the lag in years, NA where no map is on after the disturbance.
return_lag <- function(on, years, lost) { out <- rep(NA_integer_, length(lost))
  for (j in seq_along(years)) { k <- is.na(out) & !is.na(lost) & years[j] > lost & on[, j]; out[k] <- years[j] - lost[k] }
  out }

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

# ---- forest stocking (stage 8; user 2026-11-19) -------------------------------------------------------------------------------------
# The stock curves give every cell of a forest type the same carbon at an age, whatever its canopy. TreeMap 2016 (FIA plots imputed
# to 30 m) says stock follows canopy: on undisturbed P26 forest it holds 0.26 of the model's aboveground live carbon on cells under
# 20% canopy and 1.54 on cells over 70%. The curves are FIA's mean over all forest land, open stands included, so the total is about
# right and its place is wrong. The stocking multiplier moves it: a mature cell's mean canopy over the mean of the mature cells of its
# forest type and ecodivision, kept within the cap and with a mean of 1 in each group. It multiplies with the site productivity
# multiplier (how fast the site grows trees, against how fully trees occupy it; their correlation over Yellowstone's forest is 0.09).
# A stand younger than `mature` has a low canopy for its age, which the curve already holds, so it gets none of its own (stage 8
# fills it from the mature forest near it); in P26 canopy levels off between 20 and 30 years.
#   canopy   the cell's mean tree canopy cover (percent)      group   forest type and ecodivision      mature   TRUE where the cell
#   is forest old enough for its canopy to count. Returns list(mult = NA where the cell has none of its own, own, table).
stocking_multiplier <- function(canopy, group, mature, cap = c(0.3, 2.5), min_cells = 30L) {
  m <- rep(NA_real_, length(canopy)); ok <- mature %in% TRUE & !is.na(canopy) & !is.na(group); tab <- list()
  for (g in unique(group[ok])) { i <- which(ok & group == g); mu <- mean(canopy[i])
    # a group too small for a mean of its own, or with no canopy at all, keeps 1
    if (length(i) < min_cells || mu <= 0) { m[i] <- 1; tab[[g]] <- data.table::data.table(Group = g, Cells = length(i), MeanCanopy = mu, Own = FALSE); next }
    r <- canopy[i] / mu
    for (k in 1:50) { r <- pmin(pmax(r, cap[1]), cap[2]); s <- mean(r); if (abs(s - 1) < 1e-9) break; r <- r / s }   # the cap moves the mean: bring it back to 1
    m[i] <- pmin(pmax(r, cap[1]), cap[2]); tab[[g]] <- data.table::data.table(Group = g, Cells = length(i), MeanCanopy = mu, Own = TRUE) }
  list(mult = m, own = ok, table = data.table::rbindlist(tab)) }

# ---- the stocking curve, fitted to TreeMap where the Build has it (user 2026-11-19) --------------------------------------------------
# Carbon in proportion to canopy fits P26 but over-corrects Yellowstone's dense lodgepole, where TreeMap's carbon levels off above
# about 50% canopy (TreeMap over the model's start: 0.93 under 20% canopy, 0.64 at 60-70%). So where TreeMap and the canopy of its
# year are in reach, each forest type's carbon follows a curve that saturates: f(c) = c^b / (c^b + k^b), k the canopy at half the
# ceiling and b the steepness (b = 1 rises fastest at the start; a larger b is slow at first, then steep, then flat). Only its shape
# counts: the multiplier is f(canopy) over its mean in the group. A large k is the straight proportion again.
stocking_curve <- function(canopy, k, b) { c <- pmax(canopy, 0)^b; c / (c + k^b) }
STOCKING_GRID <- list(k = c(seq(10, 150, 5), 200, 300, 500, 1000), b = seq(0.5, 4, 0.25))
# least squares of TreeMap carbon on a * f(canopy), over whole percents of canopy weighted by their cells (a is solved, k and b
# searched on the grid). Returns list(k, b, r2) or NULL with fewer than five canopy values
stocking_fit1 <- function(canopy, carbon) {
  d <- data.table::data.table(c = round(canopy), y = carbon)[is.finite(c) & is.finite(y), .(y = mean(y), w = .N), by = c]; if (nrow(d) < 5) return(NULL)
  best <- NULL; tot <- sum(d$w * (d$y - stats::weighted.mean(d$y, d$w))^2)
  for (b in STOCKING_GRID$b) for (k in STOCKING_GRID$k) { fv <- stocking_curve(d$c, k, b); den <- sum(d$w * fv^2); if (den <= 0) next
    a <- sum(d$w * d$y * fv) / den; sse <- sum(d$w * (d$y - a * fv)^2); if (is.null(best) || sse < best$sse) best <- list(k = k, b = b, sse = sse) }
  if (is.null(best)) return(NULL); list(k = best$k, b = best$b, r2 = if (tot > 0) 1 - best$sse / tot else NA_real_) }
# a curve per forest type with at least min_cells cells, and one for all forest that the other types take. canopy = the cell's mean
# canopy in TreeMap's year, carbon = TreeMap's live carbon of the cell, type = its forest type. Returns Type, K, B, R2, Cells, Own
stocking_fit <- function(canopy, carbon, type, min_cells = 200L) {
  ok <- is.finite(canopy) & is.finite(carbon) & !is.na(type); all <- stocking_fit1(canopy[ok], carbon[ok]); if (is.null(all)) return(NULL)
  out <- list(data.table::data.table(Type = "(all forest)", K = all$k, B = all$b, R2 = all$r2, Cells = sum(ok), Own = TRUE))
  for (t in unique(type[ok])) { i <- ok & type == t; ft <- if (sum(i) >= min_cells) stocking_fit1(canopy[i], carbon[i]) else NULL
    out[[length(out) + 1]] <- if (is.null(ft)) data.table::data.table(Type = t, K = all$k, B = all$b, R2 = NA_real_, Cells = sum(i), Own = FALSE) else data.table::data.table(Type = t, K = ft$k, B = ft$b, R2 = ft$r2, Cells = sum(i), Own = TRUE) }
  data.table::rbindlist(out) }
# each cell's f(canopy) by its type's curve (a type the fit did not see takes all forest's)
stocking_value <- function(canopy, type, fit) { i <- match(type, fit$Type); i[is.na(i)] <- match("(all forest)", fit$Type); stocking_curve(canopy, fit$K[i], fit$B[i]) }
stocking_curve_label <- function(k, b) if (k >= 500) "TreeMap: in proportion to canopy" else sprintf("TreeMap: half its ceiling at %g%% canopy, steepness %g", k, b)
