# =============================================================================
# wood-products.R - the fate of harvested carbon after it leaves the ecosystem (to-do 59, step 2; stage 18 calls it)
# =============================================================================
# The USFS harvested wood products model (IPCC production approach), as the HWP-C calculator applies it (Stockmann et al. 2012;
# Anderson et al. 2013) on Smith et al. 2006's regional factors. Parameters: defaults/wood-products (README.md there gives every source).
# Plain functions, no SyncroSim: the stage passes the run's removals in and writes the results out.
#
# The chain, each year:
#   removed carbon (Forestry Sector flows, Mg C)  by region, forest type and cause (harvest or land clearing)
#     land clearing: the utilized share goes on like harvest; the rest is emitted that year (without energy capture)
#     softwood / hardwood   carbon share from Smith Table 4: softwood share of growing-stock volume x specific gravity
#     sawlog / pulpwood     Smith Table 4 sawtimber share of each wood type's growing stock
#     bark                  Smith Table 5 bark to wood: bark goes with the mill residue, burned with energy capture
#     fuelwood / industrial Smith Table 5 fuelwood and industrial roundwood ratios, used as shares of the wood (so carbon is
#                           conserved; Smith's ratios exceed 1 for pulpwood, which also comes from tops and cull)
#     primary products      Smith Table D6 by region, wood type and log size; "Fuel and other emissions" is burned with energy capture
#     end uses              McKeever's ratios by year; 8% of solid wood is lost when placed in use (discarded that year)
#     in use                one pool per end use, first-order decay with its half-life (Smith Table D3)
#     discards              Skog 2008 fates by year: burned with or without energy capture, composted (emitted), recovered (back in
#                           use, half-life 2.6 years, then discarded again), landfills, dumps
#     landfills             a fixed share never decays; the rest decays with its half-life (wood 29, paper 14.5 years)
#     dumps                 decay with their half-life (wood 16.5, paper 8.25 years)
# Timing: carbon enters a pool at the end of its year and decays from the next, so the share left t years after production is
# exp(-ln 2 t / half-life), as Smith's Table 8 gives it. Fuel, burning and composting are emitted in the year they happen.
# Landfill and dump decay counts as CO2, as in HWP-C (the Inventory reports landfill methane in the waste sector).
#
# Before the run (spin-up): each region's harvest history (regional-harvest-history.csv, volume; only its shape is used) is scaled,
# by region and wood type, to the run's own removals over its first decade, and fed in from 1906 to the year before the run starts.
#
# Uncertainty: Monte Carlo draws of triangular multipliers (uncertainty.csv: Min and Max are the 90% bounds), one per parameter
# element and draw, held for the whole series: each primary product ratio, end-use ratio and discard fate (ratios renormalized to
# sum to 1), each half-life, the landfill fixed shares, the industrial and fuelwood ratios, the harvest history (by period; the run's
# own removals have none: they are the run's), and the land-clearing utilized share. Draw 0 is the central case (every multiplier 1).
# =============================================================================

WP_SOLID_LOSS <- "LossInUseWood"
WP_FUEL_PRODUCT <- "Fuel and other emissions"
WP_FUEL_USE <- "fuelwood and other"
WP_PAPER_USE <- "wood pulp"
WP_FATES <- c("Burned with energy capture", "Burned without energy capture", "Composted", "Recovered", "Landfills", "Dumps")

# ---- parameters -----------------------------------------------------------------------------------------------------------------
wp_params <- function(dir = file.path("defaults", "wood-products")) {
  rd <- function(f) data.table::fread(file.path(dir, f), na.strings = "", encoding = "UTF-8")
  P <- list(regions = rd("regions.csv"), growing = rd("growing-stock.csv"), crosswalk = rd("forest-type-crosswalk.csv"),
            roundwood = rd("roundwood-factors.csv"), primary = rd("primary-products.csv"), eu_ratio = rd("end-use-ratios.csv"),
            half_life = rd("end-use-half-lives.csv"), fates = rd("discard-fates.csv"), swds = rd("swds.csv"),
            settings = rd("settings.csv"), uncertainty = rd("uncertainty.csv"), history = rd("regional-harvest-history.csv"))
  P$growing[is.na(ForestTypeGroup), ForestTypeGroup := ""]
  P$crosswalk[is.na(ForestTypeGroup), ForestTypeGroup := ""]; P$crosswalk[is.na(Wood), Wood := ""]
  P$uncertainty[is.na(Material), Material := ""]
  P$end_uses <- P$half_life$EndUse
  P$products <- sort(unique(P$primary$Product))
  wp_check_params(P)
  P
}

# A setting of settings.csv; wp_set() changes one (the stage's options override the defaults).
wp_setting <- function(P, k) { v <- P$settings[Setting == k, Value]; if (length(v) != 1) stop("wood products setting missing: ", k); as.numeric(v) }
wp_set <- function(P, k, v) { if (!k %in% P$settings$Setting) stop("not a wood products setting: ", k); P$settings <- data.table::copy(P$settings)[Setting == k, Value := v]; P }

wp_check_params <- function(P) {
  s <- P$primary[, .(s = sum(Fraction)), by = .(Region, Wood, LogSize)]
  if (any(abs(s$s - 1) > 0.005)) stop("primary product fractions do not sum to 1")
  s <- P$eu_ratio[, .(s = sum(Ratio)), by = .(Product, Year)]
  if (any(abs(s$s - 1) > 0.005)) stop("end-use ratios do not sum to 1")
  if (length(setdiff(unique(P$eu_ratio$EndUse), P$end_uses))) stop("an end use has no half-life: ", paste(setdiff(unique(P$eu_ratio$EndUse), P$end_uses), collapse = ", "))
  if (length(setdiff(P$products, unique(P$eu_ratio$Product)))) stop("a primary product has no end-use ratios")
  if (!setequal(unique(P$fates$Fate), WP_FATES)) stop("discard fates are not the six expected")
  invisible(TRUE)
}

# ---- triangular draws ---------------------------------------------------------------------------------------------------------
# The triangle [lo, mode, hi] whose (1 - interval)/2 and (1 + interval)/2 quantiles are q_lo and q_hi.
wp_triangle <- function(q_lo, mode, q_hi, interval = 0.9) {
  if (q_lo >= mode && q_hi <= mode) return(c(mode, mode, mode))
  p <- (1 - interval) / 2; lo <- q_lo - (mode - q_lo); hi <- q_hi + (q_hi - mode)
  root <- function(a, b, c, pick) { d <- sqrt(max(b^2 - 4 * a * c, 0)); r <- c((-b - d) / (2 * a), (-b + d) / (2 * a)); pick(r) }
  for (i in 1:200) {
    # (q_lo - lo)^2 = p (hi - lo)(mode - lo), the root below q_lo
    lo_n <- if (q_lo < mode) root(1 - p, -2 * q_lo + p * (hi + mode), q_lo^2 - p * hi * mode, function(r) max(r[r < q_lo])) else mode
    # (hi - q_hi)^2 = p (hi - lo)(hi - mode), the root above q_hi
    hi_n <- if (q_hi > mode) root(1 - p, -2 * q_hi + p * (lo_n + mode), q_hi^2 - p * lo_n * mode, function(r) min(r[r > q_hi])) else mode
    if (abs(lo_n - lo) + abs(hi_n - hi) < 1e-12) break
    lo <- lo_n; hi <- hi_n }
  c(lo, mode, hi)
}
wp_rtri <- function(n, tri) {
  lo <- tri[1]; m <- tri[2]; hi <- tri[3]; if (hi - lo < 1e-12) return(rep(m, n))
  u <- stats::runif(n); fm <- (m - lo) / (hi - lo)
  ifelse(u < fm, lo + sqrt(u * (hi - lo) * (m - lo)), hi - sqrt((1 - u) * (hi - lo) * (hi - m)))
}

# The uncertainty row(s) of a parameter: one per period (FirstYear-LastYear) or a single row.
wp_unc <- function(P, parameter, material = "") {
  u <- P$uncertainty[Parameter == parameter & Material == material]
  if (!nrow(u)) u <- P$uncertainty[Parameter == parameter & Material == ""]
  if (!nrow(u)) stop("no uncertainty row for ", parameter, " ", material)
  u[, `:=`(FirstYear = data.table::fifelse(is.na(FirstYear), -Inf, as.numeric(FirstYear)), LastYear = data.table::fifelse(is.na(LastYear), Inf, as.numeric(LastYear)))]
  u
}
# n x k multipliers, one column per element, for one uncertainty row; central draws are all 1.
wp_mult <- function(n, k, row, central) {
  if (central) return(matrix(1, n, k))
  tri <- wp_triangle(row$Min, row$Mode, row$Max, row$Interval); matrix(wp_rtri(n * k, tri), n, k)
}

# Draws of every uncertain parameter. n draws; central = TRUE gives one draw with every multiplier 1 (the published values).
wp_draws <- function(P, n = wp_setting(P, "Draws"), seed = 1L, central = FALSE) {
  if (central) n <- 1L
  if (!is.null(seed)) set.seed(seed)
  n <- as.integer(n); D <- list(n = n, central = central)
  per <- function(u) lapply(seq_len(nrow(u)), function(i) u[i])
  # primary product ratios: one multiplier per element and period
  u <- wp_unc(P, "PrimaryProdRatios"); D$pp_periods <- u[, .(FirstYear, LastYear)]
  D$pp <- lapply(per(u), function(r) wp_mult(n, nrow(P$primary), r, central))
  # industrial roundwood and fuelwood ratios: one multiplier per element and period
  u <- wp_unc(P, "TimberProdRatios"); D$tp_periods <- u[, .(FirstYear, LastYear)]
  D$tp_irr <- lapply(per(u), function(r) wp_mult(n, nrow(P$roundwood), r, central))
  D$tp_fr <- lapply(per(u), function(r) wp_mult(n, nrow(P$roundwood), r, central))
  # the harvest history: one multiplier per period
  u <- wp_unc(P, "Harvest"); D$hv_periods <- u[, .(FirstYear, LastYear)]
  D$hv <- vapply(per(u), function(r) wp_mult(n, 1, r, central)[, 1], numeric(n)); dim(D$hv) <- c(n, nrow(u))
  # end-use ratios: one multiplier per product and end use
  pe <- unique(P$eu_ratio[, .(Product, EndUse)]); D$eu_pairs <- pe
  D$eu <- wp_mult(n, nrow(pe), wp_unc(P, "EndUseRatios"), central)
  # half-lives in use, by end use (fuel has none)
  D$hl <- wp_mult(n, length(P$end_uses), wp_unc(P, "EndUse_HalfLives"), central); colnames(D$hl) <- P$end_uses
  # discard fates, landfill and dump parameters, by material
  D$fate <- list(); D$lf_fixed <- D$lf_hl <- D$dump_hl <- D$rec_hl <- matrix(1, n, 2, dimnames = list(NULL, c("wood", "paper")))
  for (m in c("wood", "paper")) {
    D$fate[[m]] <- wp_mult(n, length(WP_FATES), wp_unc(P, "DiscardedDispositionRatios", m), central); colnames(D$fate[[m]]) <- WP_FATES
    D$lf_fixed[, m] <- wp_mult(n, 1, wp_unc(P, "LandfillDecayLimits", m), central)
    D$lf_hl[, m] <- wp_mult(n, 1, wp_unc(P, "Landfill_HalfLives", m), central)
    D$dump_hl[, m] <- wp_mult(n, 1, wp_unc(P, "Dump_HalfLives", m), central)
    D$rec_hl[, m] <- wp_mult(n, 1, wp_unc(P, "Recovered_HalfLives", m), central) }
  # the land-clearing utilized share
  D$lcu <- pmin(1, pmax(0, wp_setting(P, "LandClearingUtilized") * wp_mult(n, 1, wp_unc(P, "LandClearingUtilized"), central)[, 1]))
  D
}
wp_period <- function(periods, years) vapply(years, function(y) { k <- which(periods$FirstYear <= y & periods$LastYear >= y); if (length(k)) k[1] else if (y < min(periods$FirstYear)) 1L else nrow(periods) }, 1L)

# ---- removals: region, forest type and cause to region, wood type and log size --------------------------------------------------
# rem: Iteration, Year, Region (Smith's: NE ... PWW), Cause ("Harvest" or "Clearing"), Carbon (Mg C), and either ForestType (a
# lucasCore forest type group, "Forest: " prefix allowed) or Wood ("SW"/"HW", the history). Returns Iteration, Year, Region, Wood,
# LogSize, Cause, Source, Carbon; attribute "unmatched" lists forest types that took the regional average.
wp_split <- function(rem, P) {
  rem <- data.table::as.data.table(data.table::copy(rem))
  if (!"Source" %in% names(rem)) rem[, Source := "Run"]
  if (!"ForestType" %in% names(rem)) rem[, ForestType := NA_character_]
  if (!"Wood" %in% names(rem)) rem[, Wood := NA_character_]
  bad <- setdiff(unique(rem$Region), P$regions$Region); if (length(bad)) stop("not a wood products region: ", paste(bad, collapse = ", "))
  bad <- setdiff(unique(rem$Cause), c("Harvest", "Clearing")); if (length(bad)) stop("removal cause must be Harvest or Clearing: ", paste(bad, collapse = ", "))
  rem[, ft := sub("^[^:]*: *", "", ForestType)]   # "Forest: Douglas-fir Group", "Wetland: Oak/Gum/Cypress Group"
  cw <- P$crosswalk[, .(ft = ForestType, Group = ForestTypeGroup, WoodFix = Wood)]
  rem <- merge(rem, cw, by = "ft", all.x = TRUE)
  unmatched <- unique(rem[!is.na(ft) & is.na(Group), ft])
  rem[is.na(Group), Group := ""]; rem[is.na(WoodFix), WoodFix := ""]
  g <- P$growing[, .(Region, Group = ForestTypeGroup, sf = SoftwoodFraction, sawS = SoftwoodSawtimberFraction, sawH = HardwoodSawtimberFraction,
                     sgS = SoftwoodSpecificGravity, sgH = HardwoodSpecificGravity)]
  avg <- g[Group == ""][, Group := NULL]
  rem <- merge(rem, g, by = c("Region", "Group"), all.x = TRUE)
  miss <- rem[, is.na(sf)]
  if (any(miss)) { unmatched <- unique(c(unmatched, rem[miss & Group != "", paste(Region, Group)]))
    a <- avg[match(rem$Region[miss], avg$Region)]; for (k in names(avg)[-1]) data.table::set(rem, which(miss), k, a[[k]]) }
  if (rem[, anyNA(sf)]) stop("a region has no average growing-stock row")
  # softwood share of the carbon: volume share x specific gravity
  rem[, swc := data.table::fcase(!is.na(Wood), as.numeric(Wood == "SW"), WoodFix == "SW", 1, WoodFix == "HW", 0,
                                 default = sf * sgS / (sf * sgS + (1 - sf) * sgH))]
  out <- data.table::rbindlist(list(
    rem[, .(Iteration, Year, Region, Wood = "SW", LogSize = "Sawlog", Cause, Source, Carbon = Carbon * swc * sawS)],
    rem[, .(Iteration, Year, Region, Wood = "SW", LogSize = "Pulpwood", Cause, Source, Carbon = Carbon * swc * (1 - sawS))],
    rem[, .(Iteration, Year, Region, Wood = "HW", LogSize = "Sawlog", Cause, Source, Carbon = Carbon * (1 - swc) * sawH)],
    rem[, .(Iteration, Year, Region, Wood = "HW", LogSize = "Pulpwood", Cause, Source, Carbon = Carbon * (1 - swc) * (1 - sawH))]))
  out <- out[Carbon > 0, .(Carbon = sum(Carbon)), by = .(Iteration, Year, Region, Wood, LogSize, Cause, Source)]
  data.table::setattr(out, "unmatched", unmatched)
  out
}

# ---- spin-up: the harvest history scaled to the run ----------------------------------------------------------------------------
# split: wp_split() of the run's removals; start: the run's first year; decade: years used for the scaling.
# Returns list(history = rows to add, in wp_split's form, Source "History"; scale = the factor by iteration, region and wood type).
wp_spinup <- function(split, P, start = min(split$Year), decade = 10L, first = 1906L) {
  yrs <- start + seq_len(decade) - 1L
  run <- split[Year %in% yrs, .(RunCarbon = sum(Carbon)), by = .(Iteration, Region, Wood)]
  h <- P$history[Year %in% yrs, .(HistoryVolume = sum(Removals), Years = .N), by = .(Region, Wood)]
  sc <- merge(run, h, by = c("Region", "Wood"), all.x = TRUE)
  short <- sc[is.na(Years) | Years < decade]
  if (nrow(short)) { last <- P$history[Region %in% short$Region, max(Year)]
    stop(sprintf("the harvest history of %s ends in %d: it cannot be scaled to a run whose first decade is %d-%d", paste(unique(short$Region), collapse = ", "), last, min(yrs), max(yrs))) }
  sc[, Scale := data.table::fifelse(HistoryVolume > 0, RunCarbon / HistoryVolume, 0)]
  pre <- if (start > first) first:(start - 1L) else integer(0)
  hist <- merge(P$history[Year %in% pre, .(Region, Wood, Year, Removals)], sc[, .(Iteration, Region, Wood, Scale)], by = c("Region", "Wood"), allow.cartesian = TRUE)
  avg <- P$growing[ForestTypeGroup == "", .(Region, sawS = SoftwoodSawtimberFraction, sawH = HardwoodSawtimberFraction)]
  hist <- merge(hist, avg, by = "Region")
  hist[, saw := data.table::fifelse(Wood == "SW", sawS, sawH)]
  out <- data.table::rbindlist(list(hist[, .(Iteration, Year, Region, Wood, LogSize = "Sawlog", Cause = "Harvest", Source = "History", Carbon = Removals * Scale * saw)],
                                    hist[, .(Iteration, Year, Region, Wood, LogSize = "Pulpwood", Cause = "Harvest", Source = "History", Carbon = Removals * Scale * (1 - saw))]))
  list(history = out[Carbon > 0], scale = sc[, .(Iteration, Region, Wood, RunCarbon, HistoryVolume, Scale)])
}

# ---- carbon to products and end uses, one draw ---------------------------------------------------------------------------------
# x: wp_split rows of one iteration (run and history); years: the model years. Returns the end-use inputs (years x end uses), the
# solid wood and paper lost when placed in use, and the carbon emitted directly with and without energy capture, by year.
wp_inputs <- function(x, P, D, d, years) {
  ny <- length(years); yi <- match(x$Year, years)
  eu_in <- matrix(0, ny, length(P$end_uses), dimnames = list(NULL, P$end_uses))
  emit_ec <- emit_no <- loss_wood <- loss_paper <- rep(0, ny)
  # land clearing: the utilized share goes on
  util <- x$Carbon * data.table::fifelse(x$Cause == "Clearing", D$lcu[d], 1)
  emit_no <- emit_no + tabulate_sum(yi, x$Carbon - util, ny)
  # the harvest history's own uncertainty
  hv <- data.table::fifelse(x$Source == "History", D$hv[cbind(d, wp_period(D$hv_periods, x$Year))], 1); util <- util * hv
  # bark, fuelwood and industrial roundwood (Smith Table 5, by roundwood region)
  rr <- P$regions$RoundwoodRegion[match(x$Region, P$regions$Region)]
  ri <- match(paste(rr, x$Wood, x$LogSize), P$roundwood[, paste(RoundwoodRegion, Wood, LogSize)])
  if (anyNA(ri)) stop("no roundwood factors for ", paste(unique(paste(rr, x$Wood, x$LogSize)[is.na(ri)]), collapse = ", "))
  tp <- wp_period(D$tp_periods, x$Year)
  b <- P$roundwood$BarkToWood[ri]
  irr <- P$roundwood$IndustrialRoundwoodRatio[ri] * vapply(seq_along(ri), function(i) D$tp_irr[[tp[i]]][d, ri[i]], 0)
  fr <- P$roundwood$FuelwoodRatio[ri] * vapply(seq_along(ri), function(i) D$tp_fr[[tp[i]]][d, ri[i]], 0)
  wood <- util / (1 + b)
  emit_ec <- emit_ec + tabulate_sum(yi, util - wood + wood * fr / (irr + fr), ny)
  ind <- wood * irr / (irr + fr)
  # primary products (Smith Table D6), with their multipliers, renormalized per row
  pk <- paste(P$primary$Region, P$primary$Wood, P$primary$LogSize); xk <- paste(x$Region, x$Wood, x$LogSize)
  pp_per <- wp_period(D$pp_periods, x$Year)
  prod <- matrix(0, ny, length(P$products), dimnames = list(NULL, P$products))
  for (k in unique(paste(xk, pp_per))) {
    rows <- which(paste(xk, pp_per) == k); pr <- which(pk == xk[rows[1]])
    if (!length(pr)) stop("no primary product ratios for ", xk[rows[1]])
    f <- P$primary$Fraction[pr] * D$pp[[pp_per[rows[1]]]][d, pr]; f <- f / sum(f)
    v <- tabulate_sum(yi[rows], ind[rows], ny)
    pj <- match(P$primary$Product[pr], P$products)
    prod[, pj] <- prod[, pj] + outer(v, f) }
  e <- wp_enduses(prod, P, D, d, years)
  list(eu_in = e$eu_in, loss_wood = e$loss_wood, loss_paper = e$loss_paper, emit_ec = emit_ec + e$emit_ec, emit_no = emit_no,
       removed = tabulate_sum(yi, x$Carbon * hv, ny))
}
tabulate_sum <- function(i, v, n) { out <- rep(0, n); if (length(i)) { s <- rowsum(v, i, reorder = TRUE); out[as.integer(rownames(s))] <- s[, 1] }; out }

# Primary products (years x products, carbon) to end uses, by year: the end-use ratios held at the first and last year of the table,
# with their multipliers, renormalized per product and year. loss = FALSE drops the loss when placed in use (Smith's tables have none).
wp_enduses <- function(prod, P, D, d, years, loss = TRUE) {
  ny <- length(years); emit_ec <- loss_wood <- loss_paper <- rep(0, ny)
  eu_in <- matrix(0, ny, length(P$end_uses), dimnames = list(NULL, P$end_uses))
  ey <- pmin(pmax(years, min(P$eu_ratio$Year)), max(P$eu_ratio$Year))
  loss_w <- if (loss) wp_setting(P, WP_SOLID_LOSS) else 0; loss_p <- if (loss) wp_setting(P, "LossInUsePaper") else 0
  for (p in colnames(prod)) {
    if (!any(prod[, p] > 0)) next
    if (p == WP_FUEL_PRODUCT) { emit_ec <- emit_ec + prod[, p]; next }
    r <- P$eu_ratio[Product == p]
    m <- D$eu[d, match(paste(r$Product, r$EndUse), paste(D$eu_pairs$Product, D$eu_pairs$EndUse))]
    r <- r[, .(EndUse, Year, R = Ratio * m)][, R := R / sum(R), by = Year]
    W <- matrix(0, ny, length(P$end_uses), dimnames = list(NULL, P$end_uses))
    for (u in unique(r$EndUse)) { ru <- r[EndUse == u]; W[, u] <- ru$R[match(ey, ru$Year)] }
    W[is.na(W)] <- 0
    pv <- prod[, p] * W
    if (p == "Wood pulp") { loss_paper <- loss_paper + rowSums(pv) * loss_p; pv <- pv * (1 - loss_p) }
    else { fu <- pv[, WP_FUEL_USE]; pv[, WP_FUEL_USE] <- 0; emit_ec <- emit_ec + fu
      loss_wood <- loss_wood + rowSums(pv) * loss_w; pv <- pv * (1 - loss_w) }
    eu_in <- eu_in + pv }
  list(eu_in = eu_in, loss_wood = loss_wood, loss_paper = loss_paper, emit_ec = emit_ec)
}

# One unit of carbon in industrial roundwood (region, wood, log size) or in one primary product, produced in `year`, followed for
# `horizon` years with the central parameters: the share in use, in landfills (and dumps), burned for energy and emitted otherwise,
# by years after production (0 = the end of the production year). For checks against Smith 2006 Tables 6 and 8.
wp_pulse <- function(P, year, horizon = 100L, region = NULL, wood = NULL, logsize = NULL, product = NULL, loss = FALSE, D = wp_draws(P, central = TRUE)) {
  years <- year + 0:horizon; ny <- length(years)
  prod <- matrix(0, ny, length(P$products), dimnames = list(NULL, P$products))
  if (!is.null(product)) prod[1, product] <- 1
  else { pr <- P$primary[Region == region & Wood == wood & LogSize == logsize]; if (!nrow(pr)) stop("no primary product ratios for ", region, " ", wood, " ", logsize)
    prod[1, pr$Product] <- pr$Fraction / sum(pr$Fraction) }
  e <- wp_enduses(prod, P, D, 1L, years, loss = loss)
  inp <- list(eu_in = e$eu_in, loss_wood = e$loss_wood, loss_paper = e$loss_paper, emit_ec = e$emit_ec, emit_no = rep(0, ny))
  pl <- wp_pools(inp, P, D, 1L, years); o <- pl$out
  data.table::data.table(After = 0:horizon, InUse = rowSums(pl$inuse), Recovered = o[, "Recovered"], Landfill = o[, "LandfillDecaying"] + o[, "LandfillFixed"] + o[, "Dump"],
                         Energy = cumsum(o[, "EmittedEnergy"]), Emitted = cumsum(o[, "EmittedNoEnergy"]))
}

# ---- pools in use and in disposal sites, one draw -----------------------------------------------------------------------------
wp_pools <- function(inp, P, D, d, years) {
  ny <- length(years); eu <- P$end_uses
  k_of <- function(h) data.table::fifelse(h > 0, log(2) / h, Inf)
  hl <- P$half_life$HalfLife * D$hl[d, eu]; keep <- exp(-k_of(hl)); keep[eu == WP_FUEL_USE] <- 0
  paper <- eu == WP_PAPER_USE
  sw <- P$swds; sv <- function(m, k) sw[Material == m][[k]]
  par <- lapply(c(wood = "wood", paper = "paper"), function(m) list(
    fixed = min(1, sv(m, "LandfillFixedFraction") * D$lf_fixed[d, m]),
    lf = exp(-log(2) / (sv(m, "LandfillHalfLife") * D$lf_hl[d, m])), dump = exp(-log(2) / (sv(m, "DumpHalfLife") * D$dump_hl[d, m])),
    rec = exp(-log(2) / (sv(m, "RecoveredHalfLife") * D$rec_hl[d, m]))))
  # discard fates by year, with their multipliers, renormalized
  fy <- pmin(pmax(years, min(P$fates$Year)), max(P$fates$Year))
  fate <- lapply(c(wood = "wood", paper = "paper"), function(m) {
    f <- data.table::dcast(P$fates[Material == m], Year ~ Fate, value.var = "Fraction")
    M <- as.matrix(f[match(fy, Year), WP_FATES, with = FALSE]) * matrix(D$fate[[m]][d, WP_FATES], ny, length(WP_FATES), byrow = TRUE)
    M / rowSums(M) })
  inuse <- matrix(0, ny, length(eu), dimnames = list(NULL, eu))
  out <- matrix(0, ny, 9, dimnames = list(NULL, c("Recovered", "LandfillDecaying", "LandfillFixed", "Dump", "EmittedEnergy", "EmittedNoEnergy",
                                                  "Discarded", "LandfillEmitted", "DumpEmitted")))
  P_eu <- rep(0, length(eu)); st <- list(wood = c(rec = 0, lfd = 0, lff = 0, dump = 0), paper = c(rec = 0, lfd = 0, lff = 0, dump = 0))
  for (t in seq_len(ny)) {
    disc_eu <- P_eu * (1 - keep); P_eu <- P_eu * keep + inp$eu_in[t, ]
    inuse[t, ] <- P_eu
    disc <- c(wood = sum(disc_eu[!paper]) + inp$loss_wood[t], paper = sum(disc_eu[paper]) + inp$loss_paper[t])
    ec <- inp$emit_ec[t]; no <- inp$emit_no[t]; lfe <- 0; dpe <- 0
    for (m in c("wood", "paper")) { s <- st[[m]]; q <- par[[m]]
      d_m <- disc[[m]] + s[["rec"]] * (1 - q$rec)          # recovered products leaving use are discarded again
      lfe <- lfe + s[["lfd"]] * (1 - q$lf); dpe <- dpe + s[["dump"]] * (1 - q$dump)
      f <- fate[[m]][t, ]
      s[["rec"]] <- s[["rec"]] * q$rec + d_m * f[["Recovered"]]
      s[["lfd"]] <- s[["lfd"]] * q$lf + d_m * f[["Landfills"]] * (1 - q$fixed)
      s[["lff"]] <- s[["lff"]] + d_m * f[["Landfills"]] * q$fixed
      s[["dump"]] <- s[["dump"]] * q$dump + d_m * f[["Dumps"]]
      ec <- ec + d_m * f[["Burned with energy capture"]]
      no <- no + d_m * (f[["Burned without energy capture"]] + f[["Composted"]])
      st[[m]] <- s }
    no <- no + lfe + dpe
    out[t, ] <- c(st$wood[["rec"]] + st$paper[["rec"]], st$wood[["lfd"]] + st$paper[["lfd"]], st$wood[["lff"]] + st$paper[["lff"]],
                  st$wood[["dump"]] + st$paper[["dump"]], ec, no, sum(disc), lfe, dpe) }
  list(inuse = inuse, out = out)
}

# ---- the model -----------------------------------------------------------------------------------------------------------------
# rem: the run's removals (see wp_split). spinup: feed the scaled harvest history from 1906. end: the last year (default the run's).
# Returns list(
#   years:  Iteration, Draw, Year, Removed (carbon entering, history included), InUse, Recovered, Landfill, Dump, Stored (their sum),
#           EmittedEnergy, EmittedNoEnergy, StockChange (Stored less the year before), Source ("History" before the run, "Run" after)
#   enduse: Iteration, Year, EndUse, InUse (mean over draws)
#   scale:  the spin-up's scaling factors; unmatched: forest types that took the regional average; draws: D)
wp_model <- function(rem, P, D = wp_draws(P), spinup = TRUE, start = NULL, end = NULL, first = 1906L) {
  x <- wp_split(rem, P); unmatched <- attr(x, "unmatched")
  if (is.null(start)) start <- min(x$Year); if (is.null(end)) end <- max(x$Year)
  sc <- NULL
  if (spinup) { s <- wp_spinup(x, P, start = start, first = first); x <- data.table::rbindlist(list(s$history, x), use.names = TRUE); sc <- s$scale }
  years <- seq(if (spinup) min(first, start) else start, end)
  x <- x[Year %in% years]
  res <- list(); eus <- list()
  for (it in sort(unique(x$Iteration))) { xi <- x[Iteration == it]; acc <- 0
    for (d in seq_len(D$n)) {
      inp <- wp_inputs(xi, P, D, d, years); pl <- wp_pools(inp, P, D, d, years); o <- pl$out
      inuse <- rowSums(pl$inuse); stored <- inuse + o[, "Recovered"] + o[, "LandfillDecaying"] + o[, "LandfillFixed"] + o[, "Dump"]
      res[[length(res) + 1]] <- data.table::data.table(Iteration = it, Draw = if (D$central) 0L else d, Year = years, Removed = inp$removed,
        InUse = inuse, Recovered = o[, "Recovered"], Landfill = o[, "LandfillDecaying"] + o[, "LandfillFixed"], Dump = o[, "Dump"], Stored = stored,
        EmittedEnergy = o[, "EmittedEnergy"], EmittedNoEnergy = o[, "EmittedNoEnergy"], StockChange = stored - c(0, stored[-length(stored)]),
        Source = data.table::fifelse(years < start, "History", "Run"))
      acc <- acc + pl$inuse / D$n }
    eus[[length(eus) + 1]] <- data.table::data.table(Iteration = it, Year = rep(years, ncol(acc)), EndUse = rep(colnames(acc), each = length(years)), InUse = as.vector(acc)) }
  list(years = data.table::rbindlist(res), enduse = data.table::rbindlist(eus)[InUse > 0], scale = sc, unmatched = unmatched, draws = D, start = start)
}

# Mean and interval over draws, by iteration and over all (Iteration NA), for each variable.
wp_summary <- function(m, interval = 0.9) {
  v <- c("Removed", "InUse", "Recovered", "Landfill", "Dump", "Stored", "EmittedEnergy", "EmittedNoEnergy", "StockChange")
  L <- data.table::melt(m$years, id.vars = c("Iteration", "Draw", "Year", "Source"), measure.vars = v, variable.name = "Variable", value.name = "Value", variable.factor = FALSE)
  q <- (1 - interval) / 2
  f <- function(z) list(Mean = mean(z), Lower = unname(stats::quantile(z, q)), Upper = unname(stats::quantile(z, 1 - q)))
  rbind(L[, f(Value), by = .(Iteration, Year, Source, Variable)], L[, f(Value), by = .(Year, Source, Variable)][, Iteration := NA_integer_], use.names = TRUE)
}
