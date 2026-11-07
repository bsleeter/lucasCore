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
nf_fit_pool <- function(path, mult, memb, order, growth, pool, target) {
  m <- copy(mult)[, Value := as.numeric(Value)]
  grp <- intersect(paste(unique(path[FromStockTypeId == pool, FlowTypeId]), "[Type]"), m[Value > 0, FlowGroupId])
  if (!length(grp)) stop("no flow out of ", pool)
  v0 <- m[match(grp, FlowGroupId), Value]
  gap <- function(f) { m[match(grp, FlowGroupId), Value := v0 * f]; nf_steady(nf_flows(path, m, memb, order), growth)$stock[[pool]] - target }
  hi <- 1 / max(v0); g_lo <- gap(1e-6); g_hi <- gap(hi)
  if (sign(g_lo) == sign(g_hi)) stop(sprintf("%s: no loss rate up to 1 holds %.2f Mg C/ha", pool, target))
  f <- uniroot(gap, c(1e-6, hi), f.lower = g_lo, f.upper = g_hi, tol = 1e-13)$root; gap(f)
  list(mult = m, factor = f, groups = grp) }

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
  burial = "Stabilization: BG Slow -> Deep Soil [Type]", soil_emit = "Emission: BG Slow -> Atmosphere [Type]", soil_lat = "Lateral Transport: BG Slow -> Aquatic [Type]")
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
