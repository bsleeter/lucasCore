# =============================================================================
# siteproductivity.R - growth multipliers by FIA site class (to-do 35 step 3; docs/treemap-plan.md)
# =============================================================================
# Every cell of one forest type, ecodivision and age grows on one curve. FIA's site class (SITECLCD: 1 = 225+ ... 7 = 0-19 cu ft/ac/yr
# of potential growth) explains much of the scatter of plot carbon around it (phase 0: California mixed conifer carries 1.59 x the
# curve at site class 2 and 0.52 x at 6). For each forest type x ecodivision and site class:
#   ratio       each fitting plot's live carbon / its type x ecodivision curve at its age (stand ages above the curve's last age use it)
#   type        all ecodivisions: the class's mean ratio / the type's mean ratio, shrunk with SITE_PRIOR_PLOTS pseudo-plots toward the
#               type's trend across classes (a plot-weighted straight line); a class without plots takes the trend
#   cell        a type x ecodivision with at least SITE_MIN_CELL_PLOTS plots: its own class means / its mean, shrunk toward the type's
#               value the same way; fewer plots: the type's values; a type without plots: 1
#   normalised  so the plot-weighted mean over the plots the values come from is 1 (the curve stays right on average), then capped
# A plot belongs to the forest type whose own FIA group it is before a type that pools several (Western White Pine fits 12 western
# groups), as stage 5 maps TreeMap's groups. No SyncroSim calls: tests source this file.
# =============================================================================

SITE_CLASSES <- 1:7
SITE_PRIOR_PLOTS <- 20       # pseudo-plots pulling a class toward its prior (1 for a type, the type's value for a cell)
SITE_MIN_CELL_PLOTS <- 30    # a type x ecodivision needs this many plots with a site class for values of its own
SITE_CAP <- c(0.3, 2.5)

# the forest type (state class id) of each FIA group: a type's own group first, pooled types last; cw = Growth Inputs' crosswalk
site_type_of <- function(cw) {
  gm <- data.table::as.data.table(cw)[, .(g = as.integer(strsplit(as.character(FiaTypeGroups), ";")[[1]])), by = .(id = as.integer(StateClassId))]
  gm[, k := .N, by = id]; data.table::setorder(gm, k); gm[!duplicated(g)] }

# the fitting plots with a site class and their ratio to the curve
#   xc      carbon_data(): plt_cn, condid, ecodiv, fortyp_grp, stdage, c_live
#   sites   fia_sites(): plt_cn, condid, siteclcd
#   curves  StateClassId, StratumId (integer ids), Age, TotalLive
#   eco     ecodiv, StratumId
site_plots <- function(xc, sites, cw, curves, eco) {
  gm <- site_type_of(cw)
  x <- data.table::as.data.table(xc)[, .(plt_cn = as.character(plt_cn), condid = as.integer(condid), ecodiv = as.character(ecodiv), fortyp_grp, stdage, c_live)]
  x[, StateClassId := gm$id[match(fortyp_grp, gm$g)]][, StratumId := eco$StratumId[match(ecodiv, eco$ecodiv)]]
  s <- data.table::as.data.table(sites)[, .(plt_cn = as.character(plt_cn), condid = as.integer(condid), siteclcd)]
  x <- merge(x, s, by = c("plt_cn", "condid"))
  x <- x[!is.na(StateClassId) & !is.na(StratumId) & siteclcd %in% SITE_CLASSES]
  cv <- data.table::as.data.table(curves)[, .(StateClassId = as.integer(StateClassId), StratumId = as.integer(StratumId), Age = as.integer(Age), TotalLive)]
  amax <- cv[, .(amax = max(Age)), by = .(StateClassId, StratumId)]
  x <- merge(x, amax, by = c("StateClassId", "StratumId"))[, Age := as.integer(pmin(stdage, amax))]
  x <- merge(x, cv, by = c("StateClassId", "StratumId", "Age"))
  x[TotalLive > 0.5, .(StateClassId, StratumId, SiteClass = as.integer(siteclcd), r = c_live / TotalLive)] }

# class values from plots p (SiteClass, r): ratio of class mean to overall mean, shrunk toward prior (a length-7 vector) by k pseudo-plots;
# classes without plots take the prior. Returns n, raw and value per class
site_classes <- function(p, prior, k = SITE_PRIOR_PLOTS) {
  tm <- mean(p$r); t <- p[, .(n = .N, raw = mean(r) / tm), by = SiteClass]
  out <- data.table::data.table(SiteClass = SITE_CLASSES, prior = prior)
  out <- merge(out, t, by = "SiteClass", all.x = TRUE)[is.na(n), n := 0L]
  out[, value := ifelse(n > 0, (n * raw + k * prior) / (n + k), prior)][] }

# the multipliers for cells (StateClassId, StratumId) from site_plots() output p
site_multipliers <- function(p, cells, k = SITE_PRIOR_PLOTS, min_cell = SITE_MIN_CELL_PLOTS, cap = SITE_CAP) {
  p <- data.table::as.data.table(p); cells <- unique(data.table::as.data.table(cells)[, .(StateClassId = as.integer(StateClassId), StratumId = as.integer(StratumId))])
  # type level: shrink each class toward the type's trend across classes (a plot-weighted straight line through the class ratios), so a
  # thinly sampled class 1 or 7 is not pulled back toward 1 past its neighbour; a class without plots takes the trend; one class: 1
  typ <- p[, { v0 <- site_classes(.SD, rep(1, 7), 0); have <- v0$n > 0
    pr <- if (sum(have) >= 2) pmax(stats::predict(stats::lm(raw ~ SiteClass, data = v0[have], weights = n), v0), 0.05) else rep(1, 7)
    site_classes(.SD, pr, k) }, by = StateClassId]
  out <- cells[, {
    tv <- typ[StateClassId == .BY$StateClassId]; cp <- p[StateClassId == .BY$StateClassId & StratumId == .BY$StratumId]
    if (!nrow(tv)) data.table::data.table(SiteClass = SITE_CLASSES, Plots = 0L, RawRatio = NA_real_, Multiplier = 1, Basis = "no plots with a site class: 1", w = 1 / 7)
    else if (nrow(cp) >= min_cell) { v <- site_classes(cp, tv[order(SiteClass), value], k)
      data.table::data.table(SiteClass = v$SiteClass, Plots = v$n, RawRatio = v$raw, Multiplier = v$value, Basis = "forest type x ecodivision", w = v$n / sum(v$n)) }
    else { tv <- tv[order(SiteClass)]
      data.table::data.table(SiteClass = tv$SiteClass, Plots = tv$n, RawRatio = tv$raw, Multiplier = tv$value,
                             Basis = sprintf("forest type, all ecodivisions (%d plots here)", nrow(cp)), w = tv$n / sum(tv$n)) }
  }, by = .(StateClassId, StratumId)]
  # normalise over the plots the values come from, then cap
  out[, Multiplier := Multiplier / sum(w * Multiplier), by = .(StateClassId, StratumId)]
  out[, Multiplier := pmin(pmax(Multiplier, cap[1]), cap[2])][, w := NULL][] }
