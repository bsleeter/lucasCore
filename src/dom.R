# =============================================================================
# dom.R - CBM dead-organic-matter dynamics with spin-up, in matrix form (stage 3b calibration; stage 4 initial stocks); no SyncroSim
# =============================================================================
# One year of the forest stock-flow model as stsim applies it (defaults/stockflow/stsim_FlowOrder.csv, equally ranked flows applied
# simultaneously): DOM flows of order < 6 (snag fall, snag and medium decay, BG slow emission), then biomass turnover from the live pools
# (order 6, inputs u(a) from the stage 2 curves at age a), then the remaining DOM flows (order 6.5-6.7). Every flow is a fixed fraction
# of its source stock, so a year is linear in the DOM pools x:  x(a+1) = A x(a) + B u(a),  A = Apost Apre,  B = Apost.
# Spin-up (CBM, as lucasbuilder's): cycles of growth to the return interval RI, each ended by the historical disturbance D (live and
# DOM pools moved by the LUCAS event flows), repeated until DOM is stable. Its limit is a fixed point solved directly:
#   x_end = A^RI x0 + c,  x0 = D_dom x_end + D_live l(RI)  ->  x0 = (I - D_dom A^RI)^-1 (D_dom c + D_live l(RI))
# then the most recent disturbance, then growth to each age: DOM by age since the last disturbance.
# =============================================================================

DOM_POOLS <- c(AGVF = "DOM: Aboveground Very Fast", BGVF = "DOM: Belowground Very Fast", AGF = "DOM: Aboveground Fast", BGF = "DOM: Belowground Fast",
               AGM = "DOM: Aboveground Medium", AGS = "DOM: Aboveground Slow", BGS = "DOM: Belowground Slow", SnagStem = "DOM: Snag Stem",
               SnagBranch = "DOM: Snag Branch")
# FIA dead-carbon pools and the DOM pools they are compared with, by FIADB's definitions (user decision 2026-10-26; dev/nfcms/FINDINGS.md):
#   standing dead  CARBON_AG of standing dead trees                                        Snag Stem + Snag Branch
#   down dead      CARBON_DOWN_DEAD: wood > 3 in on the ground, stumps and their roots     AG Medium (down stems) + BG Fast (dead coarse roots)
#   litter         CARBON_LITTER: the forest floor - litter, fine woody debris, humus       AG Very Fast + AG Fast (branch litter) + AG Slow (humus)
#   soil           mineral soil, no roots (matched to gSSURGO, not FIA)                     BG Very Fast + BG Slow
# The LUCAS stock groups pool the same way (DOM: Standing Deadwood, DOM: Down Deadwood, DOM: Litter, DOM: Soil + Deep Soil).
FIA_DOM <- list(standing_dead = c("SnagStem", "SnagBranch"), down_dead = c("AGM", "BGF"), litter = c("AGVF", "AGF", "AGS"), soil = c("BGVF", "BGS"))
# calibration groups: which pools' outflows (decay, emission, and snag fall unless it is fixed) each multiplier scales. The measured
# calibration (to-do 19, 2026-10-27) has one multiplier per pool FIA's down woody material plots measure: snags, down logs (AG medium,
# with the unmeasured dead coarse roots), fine woody debris (AG fast), litter (AG very fast) and duff (AG slow); the modelled-target
# calibration has snags, down wood and one forest floor multiplier (AG very fast + fast + slow). Soil (BG very fast + slow) to gSSURGO.
DECAY_GROUPS <- list(snag = c("SnagStem", "SnagBranch"), cwd = c("AGM", "BGF"), fwd = "AGF", litter = "AGVF", duff = "AGS",
                     floor = c("AGVF", "AGF", "AGS"), soil = c("BGVF", "BGS"))
# snag fall: in the measured calibration a fixed rate from FIA's remeasured standing dead trees (set_snag_fall), outside the snag multiplier
SNAG_FALL_FLOWS <- c(stem = "Transfer: Snag Stem -> AG Medium", branch = "Transfer: Snag Branch -> AG Fast")

# set the annual stem snag fall to stem_rate; branch snags fall faster in proportion, as CBM's two rates do
set_snag_fall <- function(vals, stem_rate) {
  if (is.null(stem_rate) || !length(stem_rate) || is.na(stem_rate)) return(vals)
  vals[SNAG_FALL_FLOWS] <- vals[SNAG_FALL_FLOWS] * stem_rate / vals[[SNAG_FALL_FLOWS[["stem"]]]]; vals }

# scale the DOM outflows (decay, emission, snag fall) of each decay group by its multiplier; AG Slow -> BG Slow keeps the CBM rate, and
# the flows named in 'fixed' (the snag fall when it is measured) keep theirs.
# A pool cannot lose more than its stock in a year: if a pool's outflows exceed 1 they are scaled down together. Used both in calibration
# and for the flow multipliers stage 3 writes, so the model runs with exactly the rates that were calibrated.
scale_decay <- function(vals, mult = NULL, fixed = character()) {
  fp <- FOREST_PATHWAYS[match(names(vals), FlowType)]
  if (anyNA(fp$From)) stop("flow types without a forest pathway: ", paste(names(vals)[is.na(fp$From)], collapse = ", "), call. = FALSE)
  from <- names(DOM_POOLS)[match(fp$From, DOM_POOLS)]
  if (!is.null(mult)) for (g in names(mult)) { k <- !is.na(from) & from %in% DECAY_GROUPS[[g]] & !names(vals) %in% c("Transfer: AG Slow -> BG Slow", fixed); vals[k] <- vals[k] * mult[[g]] }
  for (p in unique(na.omit(from))) { k <- !is.na(from) & from == p; t <- sum(vals[k]); if (t > 1) vals[k] <- vals[k] / t }
  vals }

# build the annual matrices from named flow values (dom_flow_values) and the flow order; mult, fixed: as scale_decay
dom_matrices <- function(vals, flow_order, mult = NULL, fixed = character()) {
  vals <- scale_decay(vals, mult, fixed)
  fp <- FOREST_PATHWAYS[match(names(vals), FlowType)]
  if (anyNA(fp$From)) stop("flow types without a forest pathway: ", paste(names(vals)[is.na(fp$From)], collapse = ", "), call. = FALSE)
  code <- function(s) names(DOM_POOLS)[match(s, DOM_POOLS)]
  fl <- data.table::data.table(flow = names(vals), from = code(fp$From), to = code(fp$To), from_live = fp$From %in% LIVE_POOLS,
                               live = names(LIVE_POOLS)[match(fp$From, LIVE_POOLS)], value = unname(vals),
                               order = as.numeric(flow_order$Order[match(names(vals), flow_order$FlowTypeId)]))
  if (anyNA(fl$order)) stop("flow types without a flow order: ", paste(fl$flow[is.na(fl$order)], collapse = ", "), call. = FALSE)
  n <- length(DOM_POOLS); P <- names(DOM_POOLS)
  group_matrix <- function(f) { M <- diag(n); dimnames(M) <- list(P, P)
    for (k in seq_len(nrow(f))) { i <- f$from[k]; M[i, i] <- M[i, i] - f$value[k]; if (!is.na(f$to[k])) M[f$to[k], i] <- M[f$to[k], i] + f$value[k] }
    M }
  turn_order <- unique(fl[from_live == TRUE, order]); if (length(turn_order) != 1) stop("biomass turnover flows must share one order", call. = FALSE)
  Apre <- diag(n); Apost <- diag(n)
  for (o in sort(unique(fl[from_live == FALSE, order]))) { M <- group_matrix(fl[from_live == FALSE & order == o])
    if (o < turn_order) Apre <- M %*% Apre else Apost <- M %*% Apost }
  Tm <- matrix(0, n, length(LIVE_POOLS), dimnames = list(P, names(LIVE_POOLS)))   # live pool stock -> DOM input per year
  for (k in which(fl$from_live)) Tm[fl$to[k], fl$live[k]] <- Tm[fl$to[k], fl$live[k]] + fl$value[k]
  list(A = Apost %*% Apre, Apost = Apost, Tm = Tm) }

# disturbance as matrices from the LUCAS event flows of one transition group (rows with no state class, or this class), for a stand
# of the given age: event flows can depend on age (fire: one set of live-pool rows for ages 0-10, another from 11), so for each
# from -> to stock pair the row with the largest FromAgeMin not above the age applies; a pair with only a blank age applies at every age.
# (Fixed 2026-10-26: the largest FromAgeMin was taken over the whole event, so from age 11 fire dropped every dead-pool row - the
# spin-up's fires never burned forest floor, woody debris or snags, while ST-Sim's runs did.)
# As in ST-Sim (dev/stsim/01-flow-row-precedence.R, 02-stratum-row-precedence.R, 2026-10-27/28): for each from -> to pair the most
# specific rows present apply - ecodivision + state class, then ecodivision, then state class, then blank - and hide that pair's less
# specific rows at every age; the other pairs keep their own rows. (Stage 3 expands ecodivision rows with a blank class to every class,
# so the untested ecodivision-only vs class-only order never arises.)
event_rows <- function(events, group, state_class, stratum = NA) {
  e <- data.table::copy(events[TransitionGroupId == group])
  if (!"FromStratumId" %in% names(e)) e[, FromStratumId := NA_character_]
  e <- e[(is.na(FromStateClassId) | FromStateClassId == state_class) & (is.na(FromStratumId) | (!is.na(stratum) & FromStratumId == stratum))]
  e[, lvl := 2L * (!is.na(FromStratumId)) + (!is.na(FromStateClassId))]
  e <- e[, .SD[lvl == max(lvl)], by = .(FromStockTypeId, ToStockTypeId)]
  e[, lvl := NULL][] }
disturbance_matrices <- function(events, group, state_class, age, stratum = NA) {
  e <- event_rows(events, group, state_class, stratum)
  e[, amin := suppressWarnings(as.numeric(FromAgeMin))][is.na(amin), amin := 0]
  e <- e[amin <= age][, .SD[amin == max(amin)], by = .(FromStockTypeId, ToStockTypeId)]
  if (!nrow(e)) stop("no event flows for ", group, call. = FALSE)
  P <- names(DOM_POOLS); code <- function(s) names(DOM_POOLS)[match(s, DOM_POOLS)]
  Dd <- diag(length(P)); dimnames(Dd) <- list(P, P); Dl <- matrix(0, length(P), length(LIVE_POOLS), dimnames = list(P, names(LIVE_POOLS)))
  for (k in seq_len(nrow(e))) { fr <- e$FromStockTypeId[k]; to <- code(e$ToStockTypeId[k]); v <- as.numeric(e$Multiplier[k])
    if (fr %in% DOM_POOLS) { i <- code(fr); Dd[i, i] <- Dd[i, i] - v; if (!is.na(to)) Dd[to, i] <- Dd[to, i] + v }
    else if (fr %in% LIVE_POOLS) { j <- names(LIVE_POOLS)[match(fr, LIVE_POOLS)]; if (!is.na(to)) Dl[to, j] <- Dl[to, j] + v } }
  list(Dd = Dd, Dl = Dl) }

# the disturbance that ends the spin-up's historical cycles (Carbon Assumptions: Spin-up): high-severity fire, or a share of clearcuts.
# The dynamics are linear, so the average over cycles ended at random by fire or clearcut is the fixed point of the averaged matrices.
FIRE_GROUP <- "Fire: High Severity [Type]"; CLEARCUT_GROUP <- "Forest Harvest: Forest Clearcut [Type]"
spinup_history <- function(events, state_class, age, clearcut_share = 0, stratum = NA) {
  f <- disturbance_matrices(events, FIRE_GROUP, state_class, age, stratum)
  if (is.null(clearcut_share) || is.na(clearcut_share) || clearcut_share == 0) return(f)
  h <- disturbance_matrices(events, CLEARCUT_GROUP, state_class, age, stratum); s <- clearcut_share
  list(Dd = (1 - s) * f$Dd + s * h$Dd, Dl = (1 - s) * f$Dl + s * h$Dl) }

# DOM by age since the last disturbance for one cell. live: matrix (ages 0..MaxAge) x 5 live pools; ri: return interval (yr)
dom_by_age <- function(mats, live, ri, hist, last, max_age = nrow(live) - 1) {
  la <- function(a) live[min(a, nrow(live) - 1) + 1, ]
  A <- mats$A; B <- mats$Apost; Tm <- mats$Tm; n <- nrow(A)
  Ari <- diag(n); c0 <- numeric(n)
  for (a in 0:(ri - 1)) { c0 <- A %*% c0 + B %*% (Tm %*% la(a)); Ari <- A %*% Ari }
  x0 <- solve(diag(n) - hist$Dd %*% Ari, hist$Dd %*% c0 + hist$Dl %*% la(ri))   # start of a spin-up cycle (fixed point)
  x_end <- Ari %*% x0 + c0                                                         # end of the last historical cycle
  x <- last$Dd %*% x_end + last$Dl %*% la(ri)                                      # the most recent disturbance
  out <- matrix(0, max_age + 1, n, dimnames = list(NULL, rownames(A))); out[1, ] <- x
  for (a in 0:(max_age - 1)) { x <- A %*% x + B %*% (Tm %*% la(a)); out[a + 2, ] <- x }
  out }

# the FIA-comparable sums of a DOM-by-age matrix
fia_dom_sums <- function(dom) sapply(FIA_DOM, function(p) rowSums(dom[, p, drop = FALSE]))

# rows for high-severity fire's live wood pairs from the per-forest-type snag shares (Carbon Assumptions: Fire Snag Share, else
# defaults/spinup/fire-snag-share.csv): share = the part of live aboveground wood left standing (stems share x 0.65 / 0.545, branches
# share x 0.30 / 0.545 of the pool, the blank rows' split), the rest of the pool burned (emission rows rescaled together). The rows
# start from what the cell's wood pairs resolve to without the share and are written for its class (and ecodivision, when the share row
# names one), at every age row - older stands (FromAgeMin >= 11) get the share, younger ones keep their values - because in ST-Sim a
# more specific row hides the less specific rows of its pair at every age. events: the event flow table (text columns); shares:
# StateClass name, Share, optional Stratum name. Returns the events with those rows in place of any at the same level.
FIRE_HS <- "Fire: High Severity [Type]"
fire_snag_rows <- function(events, shares) {
  WOOD <- c(`Biomass: Merchantable` = "DOM: Snag Stem", `Biomass: Other Wood` = "DOM: Snag Branch"); SPLIT <- c(`Biomass: Merchantable` = 0.65, `Biomass: Other Wood` = 0.30)
  events <- data.table::copy(events); if (!"FromStratumId" %in% names(events)) events[, FromStratumId := NA_character_]
  if (!nrow(shares)) return(events)
  if (!"Stratum" %in% names(shares)) shares[, Stratum := NA_character_]
  new <- data.table::rbindlist(lapply(seq_len(nrow(shares)), function(j) { s <- shares$Stratum[j]; c0 <- shares$StateClass[j]
    x <- event_rows(events, FIRE_HS, c0, s)[FromStockTypeId %in% names(WOOD)][, `:=`(FromStratumId = s, FromStateClassId = c0)]
    if (!nrow(x)) return(NULL)
    old <- suppressWarnings(as.numeric(x$FromAgeMin)) >= 11 & !is.na(x$FromAgeMin)
    for (fr in names(WOOD)) { k <- old & x$FromStockTypeId == fr
      snag <- shares$Share[j] * SPLIT[[fr]] / 0.545
      x[k & ToStockTypeId == WOOD[[fr]], Multiplier := as.character(round(snag, 6))]
      em <- k & grepl("^Atmosphere", x$ToStockTypeId); other <- k & !em & x$ToStockTypeId != WOOD[[fr]]
      rest <- 1 - snag - sum(as.numeric(x$Multiplier[other])); v <- as.numeric(x$Multiplier[em])
      if (sum(v) > 0) x[em, Multiplier := as.character(round(v / sum(v) * rest, 6))] }
    x }), use.names = TRUE)
  if (!nrow(new)) return(events)
  same <- paste(events$TransitionGroupId, events$FromStratumId, events$FromStateClassId, events$FromStockTypeId) %in%
    unique(paste(new$TransitionGroupId, new$FromStratumId, new$FromStateClassId, new$FromStockTypeId))
  rbind(events[!same], new, fill = TRUE) }

# ---- Carbon Assumptions: Disturbance Flows (high-severity fire and clearcut) ------------------------------------------------------
# A sheet row (ecodivision and forest type optional, disturbance, minimum stand age, from pool, to pool, share) is one event flow; a
# row to "Atmosphere" is the carbon burned, written as ST-Sim's three gas rows (GAS_SPLIT, the shares of every LUCAS default row). The
# flow type follows the destination: DOM or live pools = mortality, Atmosphere = emission of each gas, Forestry Sector = harvest.
DF_GROUPS <- c(`High-severity fire` = "Fire: High Severity [Type]", Clearcut = "Forest Harvest: Forest Clearcut [Type]")
GAS_SPLIT <- c(CO2 = 0.9, CO = 0.09, CH4 = 0.01)
# the default event rows of the two disturbances as sheet rows (gas rows merged into one Atmosphere row)
events_to_sheet <- function(events) {
  e <- data.table::copy(events[TransitionGroupId %in% DF_GROUPS])
  if (!"FromStratumId" %in% names(e)) e[, FromStratumId := NA_character_]
  e[, To := ifelse(grepl("^Atmosphere: ", ToStockTypeId), "Atmosphere", ToStockTypeId)]
  e[, .(Share = round(sum(as.numeric(Multiplier)), 6)), by = .(StratumId = FromStratumId, StateClassId = FromStateClassId,
       Disturbance = names(DF_GROUPS)[match(TransitionGroupId, DF_GROUPS)], AgeMin = suppressWarnings(as.integer(FromAgeMin)), FromStockTypeId, ToStockTypeId = To)] }
# sheet rows -> event rows in the event table's columns (template: an event table); classes: every state class name, for ecodivision
# rows with a blank forest type (expanded to each class, so they rank above class-only rows as in event_rows)
sheet_to_events <- function(x, template, classes) {
  x <- data.table::copy(x)
  x[, grp := ifelse(as.character(Disturbance) %in% c("High-severity fire", "1"), DF_GROUPS[[1]], ifelse(as.character(Disturbance) %in% c("Clearcut", "2"), DF_GROUPS[[2]], NA_character_))]
  if (anyNA(x$grp)) stop("Disturbance Flows: unknown disturbance ", paste(unique(x$Disturbance[is.na(x$grp)]), collapse = ", "), call. = FALSE)
  eco <- x[!is.na(StratumId) & is.na(StateClassId)]
  if (nrow(eco)) { exp <- eco[rep(seq_len(nrow(eco)), each = length(classes))][, StateClassId := rep(classes, nrow(eco))]
    own <- paste(x$grp, x$StratumId, x$StateClassId, x$FromStockTypeId, x$ToStockTypeId)
    exp <- exp[!paste(grp, StratumId, StateClassId, FromStockTypeId, ToStockTypeId) %in% own]   # an explicit ecodivision + class row wins
    x <- rbind(x[!(!is.na(StratumId) & is.na(StateClassId))], exp) }
  atm <- x$ToStockTypeId == "Atmosphere"; n <- sum(atm)
  gas <- x[atm][rep(seq_len(n), each = 3)][, `:=`(to = rep(paste0("Atmosphere: ", names(GAS_SPLIT)), n), ft = rep(paste0("LULC: Emission Live ", names(GAS_SPLIT)), n),
                                                     v = Share * rep(GAS_SPLIT, n))]
  rows <- rbind(x[!atm][, `:=`(to = ToStockTypeId, ft = ifelse(ToStockTypeId == "Forestry Sector", "LULC: Harvest Live", "LULC: Mortality Live"), v = Share)], gas)
  out <- template[rep(1L, nrow(rows))]; for (k in names(out)) data.table::set(out, j = k, value = NA_character_)
  out[, `:=`(FromStratumId = as.character(rows$StratumId), FromStateClassId = as.character(rows$StateClassId), FromAgeMin = as.character(rows$AgeMin),
             FromStockTypeId = rows$FromStockTypeId, ToStockTypeId = rows$to, TransitionGroupId = rows$grp, FlowTypeId = rows$ft, Multiplier = as.character(round(rows$v, 8)))]
  out }
# every row set more specific than blank (class, ecodivision + class) gets the age rows of the next less specific level that start below
# its own youngest row - in ST-Sim it hides those rows at every age, so stands younger than its first age would otherwise have no flow
complete_ages <- function(events) {
  e <- data.table::copy(events); if (!"FromStratumId" %in% names(e)) e[, FromStratumId := NA_character_]
  e[, `:=`(lvl = 2L * (!is.na(FromStratumId)) + (!is.na(FromStateClassId)), amin = suppressWarnings(as.numeric(FromAgeMin)))][is.na(amin), amin := 0]
  for (L in c(1L, 3L)) {
    keys <- unique(e[lvl == L, .(TransitionGroupId, FromStratumId, FromStateClassId, FromStockTypeId, ToStockTypeId)])
    add <- data.table::rbindlist(lapply(seq_len(nrow(keys)), function(i) { k <- keys[i]
      own <- e[lvl == L & TransitionGroupId == k$TransitionGroupId & FromStockTypeId == k$FromStockTypeId & ToStockTypeId == k$ToStockTypeId &
               FromStateClassId == k$FromStateClassId & (is.na(FromStratumId) & is.na(k$FromStratumId) | FromStratumId %in% k$FromStratumId)]
      low <- e[lvl < L & TransitionGroupId == k$TransitionGroupId & FromStockTypeId == k$FromStockTypeId & ToStockTypeId == k$ToStockTypeId &
               (is.na(FromStateClassId) | FromStateClassId == k$FromStateClassId) & (is.na(FromStratumId) | FromStratumId %in% k$FromStratumId)]
      if (!nrow(low)) return(NULL)
      low <- low[lvl == max(lvl) & amin < min(own$amin)]
      if (nrow(low)) low[, `:=`(FromStratumId = k$FromStratumId, FromStateClassId = k$FromStateClassId, lvl = L)] }), use.names = TRUE)
    if (nrow(add)) e <- rbind(e, add) }
  e[, c("lvl", "amin") := NULL][] }
# the largest share of any pool that one event moves, over every cell (stratum, state class) and age row: each pool's rows must add to <= 1
event_balance <- function(events, cells) {
  worst <- list(v = 0, what = "")
  for (g in DF_GROUPS) for (i in seq_len(nrow(cells))) { e <- event_rows(events, g, cells$StateClass[i], cells$Stratum[i])
    e[, amin := suppressWarnings(as.numeric(FromAgeMin))][is.na(amin), amin := 0]
    for (a in unique(e$amin)) { s <- e[amin <= a][, .SD[amin == max(amin)], by = .(FromStockTypeId, ToStockTypeId)][, .(t = sum(as.numeric(Multiplier))), by = FromStockTypeId]
      j <- which.max(s$t); if (s$t[j] > worst$v) worst <- list(v = s$t[j], what = sprintf("%s, %s / %s, age %g+, %s", sub(" \\[Type\\]$", "", g), cells$Stratum[i], cells$StateClass[i], a, s$FromStockTypeId[j])) } }
  worst }
