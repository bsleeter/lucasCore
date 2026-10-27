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
# calibration groups: which pools' outflows (decay, emission and snag fall) each multiplier scales - the same pools as the FIA targets
DECAY_GROUPS <- list(snag = c("SnagStem", "SnagBranch"), cwd = c("AGM", "BGF"), floor = c("AGVF", "AGF", "AGS"), soil = c("BGVF", "BGS"))

# scale the DOM outflows (decay, emission, snag fall) of each decay group by its multiplier; AG Slow -> BG Slow keeps the CBM rate.
# A pool cannot lose more than its stock in a year: if a pool's outflows exceed 1 they are scaled down together. Used both in calibration
# and for the flow multipliers stage 3 writes, so the model runs with exactly the rates that were calibrated.
scale_decay <- function(vals, mult = NULL) {
  fp <- FOREST_PATHWAYS[match(names(vals), FlowType)]
  if (anyNA(fp$From)) stop("flow types without a forest pathway: ", paste(names(vals)[is.na(fp$From)], collapse = ", "), call. = FALSE)
  from <- names(DOM_POOLS)[match(fp$From, DOM_POOLS)]
  if (!is.null(mult)) for (g in names(mult)) { k <- !is.na(from) & from %in% DECAY_GROUPS[[g]] & names(vals) != "Transfer: AG Slow -> BG Slow"; vals[k] <- vals[k] * mult[[g]] }
  for (p in unique(na.omit(from))) { k <- !is.na(from) & from == p; t <- sum(vals[k]); if (t > 1) vals[k] <- vals[k] / t }
  vals }

# build the annual matrices from named flow values (dom_flow_values) and the flow order; mult: decay-group multipliers (scale_decay)
dom_matrices <- function(vals, flow_order, mult = NULL) {
  vals <- scale_decay(vals, mult)
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
disturbance_matrices <- function(events, group, state_class, age) {
  e <- events[TransitionGroupId == group & (is.na(FromStateClassId) | FromStateClassId == state_class)]
  e[, amin := suppressWarnings(as.numeric(FromAgeMin))][is.na(amin), amin := 0]
  e <- e[amin <= age][, .SD[amin == max(amin)], by = .(FromStockTypeId, ToStockTypeId)]
  if (!nrow(e)) stop("no event flows for ", group, call. = FALSE)
  P <- names(DOM_POOLS); code <- function(s) names(DOM_POOLS)[match(s, DOM_POOLS)]
  Dd <- diag(length(P)); dimnames(Dd) <- list(P, P); Dl <- matrix(0, length(P), length(LIVE_POOLS), dimnames = list(P, names(LIVE_POOLS)))
  for (k in seq_len(nrow(e))) { fr <- e$FromStockTypeId[k]; to <- code(e$ToStockTypeId[k]); v <- as.numeric(e$Multiplier[k])
    if (fr %in% DOM_POOLS) { i <- code(fr); Dd[i, i] <- Dd[i, i] - v; if (!is.na(to)) Dd[to, i] <- Dd[to, i] + v }
    else if (fr %in% LIVE_POOLS) { j <- names(LIVE_POOLS)[match(fr, LIVE_POOLS)]; if (!is.na(to)) Dl[to, j] <- Dl[to, j] + v } }
  list(Dd = Dd, Dl = Dl) }

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
