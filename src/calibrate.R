# =============================================================================
# calibrate.R - stage 3b: calibrate DOM decay to observed dead carbon (experiment 17, 2026-10-20); no SyncroSim calls
# =============================================================================
# Targets: FIA standing dead (measured), down dead and litter (FIA's national model estimates) by stand age band; soil to gSSURGO
# (user 2026-10-20: FIA soil carbon is not reliable). Parameters per cell (>= MinPlots FIA plots) or per forest type (its cells with
# plots pooled): decay multipliers for snags (decay, emission and fall), down wood (AG medium + BG fast), forest floor (AG very fast +
# fast + slow) - the pools grouped as FIADB defines its pools (src/dom.R FIA_DOM, 2026-10-26; before, AG fast counted as down wood and
# BG fast as soil) - on a log scale within [0.05, 20], and the share of stands whose last disturbance was a clearcut rather than
# high-severity fire. Then one soil multiplier per cell so mineral soil (BG very fast + slow), averaged over the disturbance cycle,
# matches the cell's mean gSSURGO carbon.
# Known limitation (accepted 2026-10-20): down dead cannot match at every age - after a clearcut the model drops all branches and tops
# into down wood (too much in young stands) while mature stands get too little; the fitted clearcut share sits near 1.
# =============================================================================

CAL_BANDS <- c(0, 10, 20, 40, 60, 80, 100, 150, 300)
CAL_POOLS <- c("standing_dead", "down_dead", "litter")

# FIA dead carbon per state class x ecodivision x age band (each class uses the plots of its FIA group set)
fia_dom_data <- function(cond_file, dist_file, opt, cw) {
  x <- data.table::as.data.table(if (is.character(cond_file)) readRDS(cond_file) else cond_file); d <- data.table::as.data.table(if (is.character(dist_file)) readRDS(dist_file) else dist_file)   # a table, or the USGS .Rds file
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
  r <- turnover_rates(k$StateClass, sw, as.numeric(ctx$dens[StateClassId == k$sc, DeciduousShare]), ctx$cbm, k$cbm_eco, k$cbm_species, lt_user(k))   # CBM Crosswalk row and Live Turnover values when the cell has them
  vals <- dom_flow_values(r, sw, k$temp, ctx$cbm, dp = if (!is.null(ctx$dpt)) dom_parameters(ctx$dpt, k$Stratum))   # Carbon Assumptions dead pool parameters
  fixed <- character()
  if (!is.null(k$snag_fall) && !is.na(k$snag_fall)) { vals <- set_snag_fall(vals, k$snag_fall); fixed <- SNAG_FALL_FLOWS }   # measured snag fall
  list(k = k, live = live, vals = vals, fixed = fixed,
       hist = spinup_history(ctx$ev, k$StateClass, k$ri, k$hist_cc, k$Stratum),   # historical cycles (Spin-up: share ended by clearcut)
       fire = disturbance_matrices(ctx$ev, FIRE_GROUP, k$StateClass, k$ri, k$Stratum),   # the cell's own event rows (Disturbance Flows)
       harv = disturbance_matrices(ctx$ev, CLEARCUT_GROUP, k$StateClass, k$ri, k$Stratum)) }
cal_dom <- function(S, fo, mult, w) { m <- dom_matrices(S$vals, fo, mult, S$fixed)
  (1 - w) * dom_by_age(m, S$live, S$k$ri, S$hist, S$fire) + w * dom_by_age(m, S$live, S$k$ri, S$hist, S$harv) }

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

# cycle-averaged mineral soil carbon (FIA_DOM$soil: BG very fast + slow; dead coarse roots are down dead), the quantity matched to gSSURGO, of one cell for given multipliers
cal_bg <- function(k, ctx, mult, w) { S <- cal_setup(k, ctx); d <- cal_dom(S, ctx$fo, mult, w)
  mean(rowSums(d[1:min(S$k$ri, nrow(d)), FIA_DOM$soil, drop = FALSE])) }

# soil multiplier of one cell so the cycle-averaged mineral soil carbon equals the target (NA when it cannot be reached)
cal_soil <- function(k, ctx, mult, w) {
  if (is.na(k$soil_target)) return(NA_real_)
  S <- cal_setup(k, ctx)
  bg <- function(ms) { d <- cal_dom(S, ctx$fo, utils::modifyList(mult, list(soil = ms)), w)
    mean(rowSums(d[1:min(S$k$ri, nrow(d)), FIA_DOM$soil, drop = FALSE])) }
  r <- tryCatch(stats::uniroot(function(lm) log(bg(exp(lm))) - log(k$soil_target), c(log(0.02), log(50)))$root, error = function(e) NA_real_)
  exp(r) }

# ---- measured calibration (to-do 19, 2026-10-27; docs/dom-calibration-proposal.md) ------------------------------------------------
# Targets: FIA's down woody material plots (src/fia.R fia_dead_wood) - snags (measured standing dead), down logs (coarse woody debris +
# piles; AG medium), fine woody debris (AG fast), litter (AG very fast), duff (AG slow) - in mature stands only (stand age >= MinAge,
# no fire or cutting recorded at the plot in the past RECENT years): there the dead pools are the balance of turnover and decay, while
# a young stand's are mostly what its last fire or harvest left. Snag fall is fixed from remeasured standing dead trees (snag_fall_rates),
# so the snag multiplier fits only decay while standing. The spin-up's last disturbance is high-severity fire. Decay is regional (user
# decision 2026-10-27): snag, down log and fine woody debris multipliers are shared by an ecodivision's forest types, litter and duff
# multipliers are per forest type (cal_fit_measured). Soil to gSSURGO afterwards (cal_soil), as before.
MEAS_POOLS <- c("standing", "cwd", "fwd", "litter", "duff")
MEAS_SIM <- list(standing = c("SnagStem", "SnagBranch"), cwd = "AGM", fwd = "AGF", litter = "AGVF", duff = "AGS")   # dead roots are not on the transects
MEAS_RECENT <- 30
MEAS_MULT <- c("snag", "cwd", "fwd", "litter", "duff")

# mature-stand targets per state class x ecodivision x age band (bands from min_age), as fia_dom_data's: list(obs, ages)
dwm_targets <- function(dw, cw, min_age = 60) {
  x <- dw$dwm[!is.na(stdage) & stdage >= min_age & stdage <= max(CAL_BANDS) & !(since_fire %in% 0:MEAS_RECENT) & !(since_cut %in% 0:MEAS_RECENT) &
              is.finite(cwd) & is.finite(fwd) & is.finite(litter) & is.finite(duff) & is.finite(standing)]
  # a few records are impossible (negative, or thousands of Mg C/ha): drop negatives and each pool's top 0.1% (as the growth data's cap)
  for (p in MEAS_POOLS) { cap <- stats::quantile(x[[p]], 0.999); x <- x[get(p) >= 0 & get(p) <= cap] }
  g <- cw[, .(fortyp_grp = as.integer(unlist(strsplit(FiaTypeGroups, ";")))), by = StateClassId]
  x <- merge(x, g, by = "fortyp_grp", allow.cartesian = TRUE); data.table::setnames(x, "StateClassId", "sc")
  x[, band := cut(stdage, unique(c(min_age, CAL_BANDS[CAL_BANDS > min_age])), include.lowest = TRUE)]
  list(obs = x[, c(list(n = .N), lapply(.SD, mean)), by = .(sc, ecodiv, band), .SDcols = MEAS_POOLS], ages = x[, .N, by = .(sc, ecodiv, band, stdage)]) }

# annual stem snag fall per state class x ecodivision from remeasured snags not killed by a recent fire (carbon-weighted share fallen
# between visits -> k = -ln(1 - share) / years); cells with fewer than min_snags snags take their forest type's pooled rate, then all
fall_rate <- function(d) { sh <- min(sum(d$wC[d$fell]) / sum(d$wC), 0.999); -log(1 - sh) / stats::weighted.mean(d$yrs, d$wC) }
snag_fall_rates <- function(dw, cw, min_snags = 200) {
  g <- cw[, .(fortyp_grp = as.integer(unlist(strsplit(FiaTypeGroups, ";")))), by = StateClassId]
  x <- merge(dw$fall[fire_killed == FALSE & wC > 0], g, by = "fortyp_grp", allow.cartesian = TRUE); data.table::setnames(x, "StateClassId", "sc")
  list(cell = x[, .(snags = .N, rate = fall_rate(.SD)), by = .(sc, ecodiv)], type = x[, .(snags = .N, rate = fall_rate(.SD)), by = sc],
       all = fall_rate(x), min_snags = min_snags) }

# fit a set of cells: each decay multiplier to its own measured pool, in the order carbon flows (user decision 2026-10-27) - snags to
# standing dead, then down logs (AG medium, fed by snag fall) and fine woody debris (AG fast, fed by branch snag fall), then litter (AG
# very fast), then duff (AG slow, fed by all of them). A pool depends only on its own multiplier and those fitted before it, so one pass
# in this order is the solution, and no multiplier can stand in for another pool's misfit (fitting all pools' misfit at once let snag
# decay trade against down log decay). Snag, down log and fine woody debris multipliers are shared by all rows (an ecodivision's
# types, or one type's ecodivisions); litter and duff are fitted per state class. Each multiplier: Brent's 1-D search on the log scale
# within [0.05, 20], which evaluates interior values and so does not stall where a pool's loss reaches its whole stock (a gradient
# method jumped to the bound there, 2026-10-27). A row's misfit in a pool is scaled by its measured mean (floored at 0.5 Mg C/ha).
# Returns one row per input row: the five multipliers and the misfit at CBM rates and after (all pools).
cal_fit_measured <- function(rows, ctx, dat) {
  SS <- lapply(seq_len(nrow(rows)), function(i) cal_setup(rows[i], ctx))
  OB <- lapply(seq_len(nrow(rows)), function(i) dat$obs[sc == rows$sc[i] & ecodiv == rows$ecodiv[i]])
  AG <- lapply(seq_len(nrow(rows)), function(i) dat$ages[sc == rows$sc[i] & ecodiv == rows$ecodiv[i]])
  SC <- lapply(OB, function(o) pmax(sapply(MEAS_POOLS, function(p) stats::weighted.mean(o[[p]], o$n)), 0.5))   # floor: a pool measured ~0 in a cell
  types <- unique(rows$sc); ti <- match(rows$sc, types)
  pool_loss <- function(p5, i, pools = MEAS_POOLS) { sim <- cal_dom(SS[[i]], ctx$fo, as.list(stats::setNames(exp(p5), MEAS_MULT)), 0)
    sim <- sapply(MEAS_SIM[pools], function(p) rowSums(sim[, p, drop = FALSE]))
    pr <- AG[[i]][, lapply(stats::setNames(pools, pools), function(p) sum(N * sim[stdage + 1, p]) / sum(N)), by = band]
    m <- merge(OB[[i]], pr, by = "band", suffixes = c("", "_sim"))
    sum(sapply(pools, function(p) sum(m$n * ((m[[paste0(p, "_sim")]] - m[[p]]) / SC[[i]][[p]])^2))) }
  P <- matrix(0, length(SS), 5, dimnames = list(NULL, MEAS_MULT))   # log multipliers per row; 0 = CBM
  fit1 <- function(g, idx) { pool <- MEAS_POOLS[match(g, MEAS_MULT)]
    stats::optimize(function(v) { Q <- P; Q[idx, g] <- v; sum(sapply(idx, function(i) pool_loss(Q[i, ], i, pool))) }, c(log(0.05), log(20)))$minimum }
  for (g in c("snag", "cwd", "fwd")) P[, g] <- fit1(g, seq_along(SS))
  for (g in c("litter", "duff")) for (t in seq_along(types)) { idx <- which(ti == t); P[idx, g] <- fit1(g, idx) }
  data.table::rbindlist(lapply(seq_along(SS), function(i) c(as.list(exp(P[i, ])), list(loss0 = pool_loss(rep(0, 5), i), loss1 = pool_loss(P[i, ], i))))) }
