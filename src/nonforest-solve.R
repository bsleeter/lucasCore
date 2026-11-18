# =============================================================================
# nonforest-solve.R - the steady state of a grassland, shrubland or wetland class's carbon budget as ST-Sim steps it, and the rates
# that hold a class at target stocks (to-do 39, docs/ui-improvements.md: the revised approach, step 1 emergent wetlands)
# =============================================================================
# ST-Sim moves carbon once a year in flow order: the flows of one order are computed from the stocks at the start of that order's step,
# then the next order runs on the updated stocks (dev/nonforest/01-nonsage-fix.R reproduced the package's grass and shrub starting
# pools this way to 4 decimals). A flow's rate is its pathway multiplier times the value of every flow group it belongs to that has a
# row (a group without a row counts 1): for emergent wetlands "<pool> ->" is the pool's total yearly loss and each flow's own "[Type]"
# group its share of it. Growth flows from Atmosphere carry Net Growth x their share. So one year is an affine map S -> M S + c, and the
# steady state solves (I - M) S = c over the pools that lose carbon. Pools with no outflow (Deep Soil, Aquatic) are sinks: their yearly
# inflow at the steady state is reported instead of a stock.
# Used by tools/make_emergent_wetland.R (package tables) and tests/unit-nonforest-solve.R; no SyncroSim calls.
# =============================================================================
suppressPackageStartupMessages(library(data.table))

NF_SINKS <- c("Deep Soil", "Aquatic")

# one class's flows: pathways (FromStockTypeId, ToStockTypeId, FlowTypeId, Multiplier), its group values (FlowGroupId, Value), the
# group membership (FlowTypeId, FlowGroupId) and flow order (FlowTypeId, Order); returns the flows with rate and order
nf_flows <- function(path, mult, memb, order) {
  v <- setNames(as.numeric(mult$Value), mult$FlowGroupId)
  # ST-Sim's automatic "<flow type> [Type]" groups are not in the membership table
  gm <- rbind(memb[, .(FlowTypeId, FlowGroupId)], data.table(FlowTypeId = unique(path$FlowTypeId))[, FlowGroupId := paste(FlowTypeId, "[Type]")])[FlowGroupId %in% names(v)]
  f <- copy(path)[, .(From = FromStockTypeId, To = ToStockTypeId, FlowTypeId, Multiplier = as.numeric(Multiplier))]
  f[is.na(Multiplier), Multiplier := 1]
  f[, rate := Multiplier * vapply(FlowTypeId, function(x) prod(v[gm[FlowTypeId == x, FlowGroupId]]), 1)]
  f[, ord := as.numeric(order$Order[match(FlowTypeId, order$FlowTypeId)])]
  if (anyNA(f$ord)) stop("no flow order for ", paste(unique(f[is.na(ord), FlowTypeId]), collapse = "; "))
  f[rate != 0] }

# the yearly affine map S -> M S + c, composed over the flow orders
nf_annual_map <- function(f, growth) {
  pools <- sort(setdiff(unique(c(f$From, f$To)), "Atmosphere")); n <- length(pools)
  M <- diag(n); dimnames(M) <- list(pools, pools); c0 <- setNames(rep(0, n), pools)
  for (o in sort(unique(f$ord))) {
    A <- diag(n); dimnames(A) <- list(pools, pools); b <- setNames(rep(0, n), pools)
    for (k in which(f$ord == o)) { fr <- f$From[k]; to <- f$To[k]; r <- f$rate[k]
      if (fr == "Atmosphere") { b[to] <- b[to] + growth * r } else { A[fr, fr] <- A[fr, fr] - r; if (to != "Atmosphere") A[to, fr] <- A[to, fr] + r } }
    M <- A %*% M; c0 <- as.vector(A %*% c0) + b; names(c0) <- pools }
  list(M = M, c = c0, pools = pools) }

# steady state: stocks of the pools that lose carbon, and each sink's yearly inflow
nf_steady <- function(f, growth) {
  m <- nf_annual_map(f, growth); p <- m$pools
  sink <- p %in% NF_SINKS | !(p %in% f$From[f$From != "Atmosphere"])
  k <- !sink; S <- setNames(rep(0, length(p)), p)
  if (any(k)) S[k] <- solve(diag(sum(k)) - m$M[k, k, drop = FALSE], m$c[k])
  inflow <- (m$M %*% S + m$c)[, 1] - S
  list(stock = S[k], sink = inflow[sink]) }

# simulate n years from S0 (a check on nf_steady, and for pools that never settle)
nf_simulate <- function(f, growth, S0, years) {
  m <- nf_annual_map(f, growth); S <- setNames(rep(0, length(m$pools)), m$pools); S[intersect(names(S0), m$pools)] <- S0[intersect(names(S0), m$pools)]
  for (y in seq_len(years)) S <- (m$M %*% S + m$c)[, 1]
  S }

# ---- any class: scale one pool's outflow rates so its steady stock hits a target ------------------------------------------------
# For classes without "<pool> ->" total-loss groups (grassland, shrubland): every "[Type]" group of a flow out of the pool is multiplied
# by one factor, keeping their split (emission, decay, transfer), found by a bounded root search on the ordered steady state. Returns
# the group values and the factor; stops if no factor (rates up to 1) reaches the target.
# pool may be several pools: their outflows share the factor and the target is their summed stock (litter pools fitted as one); `over`
# names the pools whose stock counts toward the target when that differs from the pools scaled (e.g. scale every fast dead pool, count
# the aboveground ones)
nf_fit_pool <- function(path, mult, memb, order, growth, pool, target, over = pool, only = NULL) {
  m <- copy(mult)[, Value := as.numeric(Value)]
  grp <- intersect(paste(unique(path[FromStockTypeId %in% pool, FlowTypeId]), "[Type]"), m[Value > 0, FlowGroupId])
  if (!is.null(only)) grp <- intersect(grp, only)   # fit these outflows only (e.g. AG Slow's emission, keeping its fixed transfer)
  if (!length(grp)) stop("no flow out of ", paste(pool, collapse = ", "))
  v0 <- m[match(grp, FlowGroupId), Value]
  stock <- function() { s <- nf_steady(nf_flows(path, m, memb, order), growth)$stock; sum(s[intersect(over, names(s))]) }
  gap <- function(f) { m[match(grp, FlowGroupId), Value := v0 * f]; stock() - target }
  hi <- 1 / max(v0); g_lo <- gap(1e-6); g_hi <- gap(hi)
  if (sign(g_lo) == sign(g_hi)) stop(sprintf("%s: no loss rate up to 1 holds %.3f Mg C/ha (%.3f at the fastest)", paste(pool, collapse = ", "), target, g_hi + target))
  f <- uniroot(gap, c(1e-6, hi), f.lower = g_lo, f.upper = g_hi, tol = 1e-13)$root; gap(f)
  list(mult = m, factor = f, groups = grp) }

# set every outflow of a pool to a fixed total (shares kept): e.g. annual dieback of grass foliage (1)
nf_set_loss <- function(path, mult, pool, total) {
  m <- copy(mult)[, Value := as.numeric(Value)]
  grp <- intersect(paste(unique(path[FromStockTypeId == pool, FlowTypeId]), "[Type]"), m[Value > 0, FlowGroupId])
  if (!length(grp)) stop("no flow out of ", pool)
  v0 <- m[match(grp, FlowGroupId), Value]; m[match(grp, FlowGroupId), Value := v0 * total / sum(v0)]; m }

# ---- age: a growth curve by age and the pools along it after a stand-replacing fire --------------------------------------------
# One year at age a (ST-Sim: transitions, then flows; a flow multiplier or state attribute by age is looked up at the cell's age that
# year): `rates_at(a)` gives that year's group values and `growth_at(a)` its Net Growth. A fire moves each stock by the event fractions
# `fire` (From, To, share; To may be outside the pools) before the year at age 0. Returns the stocks at the start of each age 0..max:
# a cell whose age is A at the start of a year holds the stocks the previous year (age A - 1) left; age 0 = just after the fire.
nf_after_fire <- function(path, memb, order, rates_at, growth_at, S0, fire, max_age) {
  S <- S0
  for (k in seq_len(nrow(fire))) { f <- fire$From[k]; if (!f %in% names(S)) next
    amt <- S0[[f]] * fire$Share[k]; S[f] <- S[f] - amt; if (fire$To[k] %in% names(S)) S[fire$To[k]] <- S[fire$To[k]] + amt }
  out <- vector("list", max_age + 1); out[[1]] <- S
  for (a in 0:(max_age - 1)) { m <- nf_annual_map(nf_flows(path, rates_at(a), memb, order), growth_at(a))
    x <- setNames(rep(0, length(m$pools)), m$pools); x[intersect(names(S), m$pools)] <- S[intersect(names(S), m$pools)]
    x <- (m$M %*% x + m$c)[, 1]; S[names(x)] <- x; out[[a + 2]] <- S }
  rbindlist(lapply(seq_along(out), function(i) data.table(Age = i - 1L, pool = names(out[[i]]), Value = unname(out[[i]])))) }

# ---- emergent wetlands: the rates that hold a class at its targets --------------------------------------------------------------
# Pools: Foliage and Fine Root (growth), AG and BG Very Fast (litter), BG Slow (soil 0-30 cm), Deep Soil (burial sink), Aquatic.
# Targets (Mg C/ha, Mg C/ha/yr): NPP, ag_share (share of NPP to foliage), foliage and roots as PEAK live carbon (what field studies
# measure), ag_litter, bg_litter and soil (BG Slow) as year-end stocks, and burial (BG Slow -> Deep Soil). Growth runs first in the
# year (flow order 1) and turnover later (6), so a live pool peaks at its year-end stock plus the year's growth: the year-end target is
# peak - growth, and a pool whose growth is at least its peak dies back fully (turnover 1, year-end 0). The shares of each litter
# pool's loss (emission, lateral transport, decay to BG Slow) and BG Slow's lateral share are kept from `mult`; BG Slow's emission
# share is what burial and lateral transport leave. Each pool's total loss is fitted so its steady stock hits the target; the burial
# share so the burial flux does.
NF_EMERGENT <- list(
  growth_fol = "Net Growth Wetland Emergent: Atmosphere -> Foliage [Type]", growth_root = "Net Growth Wetland Emergent: Atmosphere -> Fine Roots [Type]",
  k_fol = "Biomass Turnover: Foliage -> AG Very Fast [Type]", k_root = "Biomass Turnover: Fine Roots -> BG Very Fast [Type]",
  k_ag = "AG Very Fast ->", k_bg = "BG Very Fast ->", k_soil = "BG Slow ->",
  burial = "Stabilization: BG Slow -> Deep Soil [Type]", soil_emit = "Emission: BG Slow -> Atmosphere (Wetland) [Type]", soil_lat = "Lateral Transport: BG Slow -> Aquatic [Type]")
NF_EMERGENT_POOLS <- c(k_fol = "Biomass: Foliage", k_root = "Biomass: Fine Root", k_ag = "DOM: Aboveground Very Fast", k_bg = "DOM: Belowground Very Fast", k_soil = "DOM: Belowground Slow")

nf_fit_emergent <- function(path, mult, memb, order, tg, tol = 1e-10, max_iter = 5000) {
  g <- NF_EMERGENT; m <- copy(mult)[, Value := as.numeric(Value)]
  setv <- function(grp, x) m[FlowGroupId == grp, Value := x]
  getv <- function(grp) m[FlowGroupId == grp, Value]
  for (grp in unlist(g)) if (!grp %in% m$FlowGroupId) stop("no row for ", grp)
  setv(g$growth_fol, tg$ag_share); setv(g$growth_root, 1 - tg$ag_share)
  target <- c(k_fol = tg$foliage - tg$npp * tg$ag_share, k_root = tg$roots - tg$npp * (1 - tg$ag_share), k_ag = tg$ag_litter, k_bg = tg$bg_litter, k_soil = tg$soil)
  dieback <- names(target)[1:2][target[1:2] <= 1e-9]
  for (j in dieback) setv(g[[j]], 1)
  target <- target[setdiff(names(target), dieback)]
  lat <- getv(g$soil_lat); beta <- min(0.5, 1 - lat - 1e-6)
  steady <- function() nf_steady(nf_flows(path, m, memb, order), tg$npp)
  set_beta <- function(b) { setv(g$burial, b); setv(g$soil_emit, 1 - b - lat) }
  # one value at a time, the others fixed (Gauss-Seidel): a bounded root search, since a pool's steady stock falls as its loss rises
  solve1 <- function(set, lo, hi, gap, what) {
    f <- function(x) { set(x); gap(steady()) }
    flo <- f(lo); fhi <- f(hi)
    if (sign(flo) == sign(fhi)) stop(sprintf("%s: no value in [%g, %g] meets the target (%s)", what, lo, hi, if (fhi > 0) "even the largest leaves too much" else "even the smallest leaves too little"))
    x <- uniroot(f, c(lo, hi), f.lower = flo, f.upper = fhi, tol = 1e-13)$root; set(x); x }
  for (it in seq_len(max_iter)) {
    old <- c(vapply(names(target), function(j) getv(g[[j]]), 1), beta = beta)
    for (j in names(target)) { pool <- NF_EMERGENT_POOLS[[j]]; grp <- g[[j]]
      solve1(function(x) setv(grp, x), 1e-9, 1, function(ss) ss$stock[[pool]] - target[[j]], pool) }
    beta <- solve1(set_beta, 1e-9, 1 - lat - 1e-9, function(ss) tg$burial - ss$sink[["Deep Soil"]], "burial into Deep Soil")
    new <- c(vapply(names(target), function(j) getv(g[[j]]), 1), beta = beta)
    if (max(abs(new / old - 1)) < tol) break }
  if (max(abs(new / old - 1)) >= tol) stop("the fit did not converge")
  set_beta(beta)
  ss <- nf_steady(nf_flows(path, m, memb, order), tg$npp)
  hit <- max(abs(ss$stock[NF_EMERGENT_POOLS[names(target)]] / target - 1))
  if (any(m$Value[m$FlowGroupId %in% unlist(g)] > 1) || hit > 1e-6) stop("a fitted rate is above 1 or a target is not met (a pool turns over faster than once a year)")
  list(mult = m, steady = ss, dieback = unname(NF_EMERGENT_POOLS[dieback])) }

# ---- emergent wetlands: methane -------------------------------------------------------------------------------------------------
# BG Slow and BG Very Fast each release carbon to the atmosphere by two flows: as CO2 and as CH4 (to Atmosphere: CH4), both shares of
# the pool's total loss. Each has its own temperature response, as every dead pool's decay has: methane the group Q10 Wetland CH4 (from
# both pools); the litter's CO2 the Q10 its emission always had (Q10 Slow Flows); the soil's CO2 the group Q10 Wetland Soil, which is
# why emergent wetlands have a soil CO2 flow type of their own (the soil emission of every other class has no Q10).
# At the normal climate (every multiplier 1) methane is carved out of the emission the class already had: a pool's CO2 and CH4 shares
# add to its emission share before methane, so no pool, burial or lateral export of the fit changes. Away from the normal climate
# the pools' losses follow the Q10s, so their stocks do move. One fraction of the belowground emission serves both pools, solved so
# the steady state releases the target (Mg C/ha/yr as CH4).
NF_CH4 <- list(sink = "Atmosphere: CH4", max_share = 0.3, q10 = "Q10 Wetland CH4", soil_q10 = "Q10 Wetland Soil", shared_soil = "Emission: BG Slow -> Atmosphere",
               shared = c(soil = "Emission: BG Slow -> Atmosphere", litter = "Emission: BG Very Fast -> Atmosphere"),   # the flow types of every other class
               co2 = c(soil = "Emission: BG Slow -> Atmosphere (Wetland)", litter = "Emission: BG Very Fast -> Atmosphere (Wetland)"),
               ch4 = c(soil = "Emission: BG Slow -> Atmosphere CH4", litter = "Emission: BG Very Fast -> Atmosphere CH4"))
# rates written before methane (the legacy tables): the soil's and the litter's emission under the shared flows' names and no CH4 rows. A flow without a
# row would count 1, so the CH4 rows are added at 0
nf_ch4_prepare <- function(mult) { g <- NF_CH4; ty <- function(x) paste(x, "[Type]"); m <- copy(mult)[, Value := as.numeric(Value)]
  for (k in names(g$co2)) if (!ty(g$co2[[k]]) %in% m$FlowGroupId) m[FlowGroupId == ty(g$shared[[k]]), FlowGroupId := ty(g$co2[[k]])]
  add <- setdiff(ty(g$ch4), m$FlowGroupId); if (length(add)) m <- rbind(m, data.table(FlowGroupId = add, Value = 0), fill = TRUE)
  m }
# the methane fraction of the belowground emission that meets the target; each pool's CH4 share is written to `digits` decimals and its
# CO2 share is what is left of the pool's emission share, so the two add to it exactly
nf_fit_ch4 <- function(path, mult, memb, order, growth, target, digits = 6) {
  g <- NF_CH4; co2 <- paste(g$co2, "[Type]"); ch4 <- paste(g$ch4, "[Type]"); m <- nf_ch4_prepare(mult)
  if (!all(c(g$co2, g$ch4) %in% path$FlowTypeId) || any(g$shared %in% path$FlowTypeId) || !all(path[FlowTypeId %in% g$ch4, ToStockTypeId] == g$sink)) stop("the pathways do not hold the wetland CO2 and CH4 emission flows")
  e <- m$Value[match(co2, m$FlowGroupId)] + m$Value[match(ch4, m$FlowGroupId)]   # each pool's whole emission share
  set <- function(f) { x <- copy(m); c4 <- round(e * f, digits); x[match(ch4, FlowGroupId), Value := c4]; x[match(co2, FlowGroupId), Value := round(e - c4, digits + 2)]; x }
  all_gas <- nf_steady(nf_flows(path, set(1), memb, order), growth)$sink[[g$sink]]   # fraction 1: every bit of the belowground emission
  share <- target / all_gas
  if (share > g$max_share) stop(sprintf("methane %.3f Mg C/ha/yr is %.0f%% of the belowground emission (%.3f); the most allowed is %.0f%%", target, 100 * share, all_gas, 100 * g$max_share))
  list(mult = set(share), share = share, gas = all_gas) }
