# =============================================================================
# calibrate.R - stage 3b: calibrate DOM decay to observed dead carbon (experiment 17, 2026-10-20); no SyncroSim calls
# =============================================================================
# Targets: FIA standing dead (measured), down dead and litter (FIA's national model estimates) by stand age band; soil to gSSURGO
# (user 2026-10-20: FIA soil carbon is not reliable). Parameters per cell (>= MinPlots FIA plots) or per forest type (its cells with
# plots pooled): decay multipliers for snags (decay, emission and fall), down wood (AG medium + fast), forest floor (AG very fast + slow),
# on a log scale within [0.05, 20], and the share of stands whose last disturbance was a clearcut rather than high-severity fire. Then
# one soil multiplier per cell so the belowground pools, averaged over the disturbance cycle, match the cell's mean gSSURGO carbon.
# Known limitation (accepted 2026-10-20): down dead cannot match at every age - after a clearcut the model drops all branches and tops
# into down wood (too much in young stands) while mature stands get too little; the fitted clearcut share sits near 1.
# =============================================================================

CAL_BANDS <- c(0, 10, 20, 40, 60, 80, 100, 150, 300)
CAL_POOLS <- c("standing_dead", "down_dead", "litter")

# FIA dead carbon per state class x ecodivision x age band (each class uses the plots of its FIA group set)
fia_dom_data <- function(cond_file, dist_file, opt, cw) {
  x <- data.table::as.data.table(readRDS(cond_file)); d <- data.table::as.data.table(readRDS(dist_file))
  x <- merge(x, d, by = c("plt_cn", "condid"))
  x <- x[dstrbcd1 %in% 0 & trtcd1 %in% 0 & !is.na(stdage) & stdage >= 1 & stdage <= max(CAL_BANDS) & invyr >= opt$MinInventoryYear]
  x[, pid := sprintf("%02d-%d-%03d-%05d", statecd, unitcd, countycd, plot)]; data.table::setorder(x, pid, condid, -invyr); x <- x[!duplicated(paste(pid, condid))]
  f <- 2.2417
  x[, `:=`(standing_dead = c_ag_standing_dead_trees_short_tons_per_acre * f, down_dead = c_down_dead_tons_per_acre * f,
           litter = c_litter_tons_per_acre * f, ecodiv = as.character(ecodiv))]
  g <- cw[, .(fortyp_grp = as.integer(unlist(strsplit(FiaTypeGroups, ";")))), by = StateClassId]
  x <- merge(x, g, by = "fortyp_grp", allow.cartesian = TRUE); data.table::setnames(x, "StateClassId", "sc")
  x[, band := cut(stdage, CAL_BANDS)]
  list(obs = x[, .(n = .N, standing_dead = mean(standing_dead), down_dead = mean(down_dead), litter = mean(litter)), by = .(sc, ecodiv, band)],
       ages = x[, .N, by = .(sc, ecodiv, band, stdage)]) }

# model pieces of one cell (k: a row of the cells table; ctx: shared inputs)
cal_setup <- function(k, ctx) {
  w <- ctx$cw[StateClassId == k$sc]; sw <- grepl("Softwood$", w$LagClass)
  live <- as.matrix(ctx$cc[Stratum == k$Stratum & StateClass == k$StateClass][order(Age), names(LIVE_POOLS), with = FALSE])
  r <- turnover_rates(k$StateClass, sw, as.numeric(ctx$dens[StateClassId == k$sc, DeciduousShare]), ctx$cbm)
  list(k = k, live = live, vals = dom_flow_values(r, sw, k$temp, ctx$cbm),
       hist = disturbance_matrices(ctx$ev, "Fire: High Severity [Type]", k$StateClass, k$ri),
       harv = disturbance_matrices(ctx$ev, "Forest Harvest: Forest Clearcut [Type]", k$StateClass, k$ri)) }
cal_dom <- function(S, fo, mult, w) { m <- dom_matrices(S$vals, fo, mult)
  (1 - w) * dom_by_age(m, S$live, S$k$ri, S$hist, S$hist) + w * dom_by_age(m, S$live, S$k$ri, S$hist, S$harv) }

cal_loss <- function(par, SS, OB, AG, scale, fo) {
  mult <- list(snag = exp(par[1]), cwd = exp(par[2]), floor = exp(par[3])); w <- stats::plogis(par[4]); tot <- 0
  for (j in seq_along(SS)) { sim <- fia_dom_sums(cal_dom(SS[[j]], fo, mult, w)); ag <- AG[[j]]
    pr <- ag[, lapply(stats::setNames(CAL_POOLS, CAL_POOLS), function(p) sum(N * sim[stdage + 1, p]) / sum(N)), by = band]
    m <- merge(OB[[j]], pr, by = "band", suffixes = c("", "_sim"))
    for (p in CAL_POOLS) tot <- tot + sum(m$n * ((m[[paste0(p, "_sim")]] - m[[p]]) / scale[[p]])^2) }
  tot }

# fit one set of cells (a cell alone, or a forest type's cells with plots): returns multipliers, clearcut share and loss before/after
cal_fit <- function(rows, ctx, dat) {
  SS <- lapply(seq_len(nrow(rows)), function(i) cal_setup(rows[i], ctx))
  OB <- lapply(seq_len(nrow(rows)), function(i) dat$obs[sc == rows$sc[i] & ecodiv == rows$ecodiv[i]])
  AG <- lapply(seq_len(nrow(rows)), function(i) dat$ages[sc == rows$sc[i] & ecodiv == rows$ecodiv[i]])
  ob <- data.table::rbindlist(OB); scale <- sapply(CAL_POOLS, function(p) stats::weighted.mean(ob[[p]], ob$n))
  l0 <- cal_loss(c(0, 0, 0, 0), SS, OB, AG, scale, ctx$fo)
  o <- stats::optim(c(0, 0, 0, 0), cal_loss, SS = SS, OB = OB, AG = AG, scale = scale, fo = ctx$fo, method = "L-BFGS-B",
                    lower = c(rep(log(0.05), 3), -6), upper = c(rep(log(20), 3), 6), control = list(maxit = 300))
  list(snag = exp(o$par[1]), cwd = exp(o$par[2]), floor = exp(o$par[3]), clearcut = stats::plogis(o$par[4]), loss0 = l0, loss1 = o$value) }

# soil multiplier of one cell so the cycle-averaged belowground carbon equals the target (NA when it cannot be reached)
cal_soil <- function(k, ctx, mult, w) {
  if (is.na(k$soil_target)) return(NA_real_)
  S <- cal_setup(k, ctx)
  bg <- function(ms) { d <- cal_dom(S, ctx$fo, utils::modifyList(mult, list(soil = ms)), w)
    mean(rowSums(d[1:min(S$k$ri, nrow(d)), c("BGVF", "BGF", "BGS"), drop = FALSE])) }
  r <- tryCatch(stats::uniroot(function(lm) log(bg(exp(lm))) - log(k$soil_target), c(log(0.02), log(50)))$root, error = function(e) NA_real_)
  exp(r) }
