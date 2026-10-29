# =============================================================================
# growth.R - merchantable volume growth curves from FIA (stage 2); no SyncroSim calls, so dev scripts and tests can use it
# =============================================================================
# The method came out of experiments 1-7 (dev/growth, plan doc tab "Growth curves", 2026-10-19):
#   form      V(t) = A (1 - exp(-k (t - L)^c)) for t > L, else 0. Five forms tied on cross-validation; this one had the most
#             plausible behaviour outside the data (peak mean annual increment ~44 yr).
#   lag       L = the age merchantable volume starts (FIA counts trees >= 5 in dbh), fitted per forest type (experiment 10,
#             2026-10-20: 0-2 yr for most hardwoods, 5-9 for southern and eastern pines, 16-24 for slow western conifers). It
#             halved the young-stand bias of the old universal 10 yr (-22 -> -9 m3/ha at 1-10 yr, +10 -> +6 at 21-30).
#             Types with fewer than MinPlotsLag plots take the lag of their class (east/west x softwood/hardwood), fitted on the
#             class's pooled plots: their own lag swung by 10-20 yr between cross-validation folds.
#   data      FIA conditions: latest visit of each plot-condition, undisturbed (dstrbcd1 = 0), untreated (trtcd1 = 0), age 1-400,
#             volume below the type group's 99.9th percentile; plot id = state + unit + county + plot. Fitted to plot volumes
#             (mean), not age medians (medians ran ~11% low; the old recipe ~10% low at age 100).
#   pooling   one model per forest type: A and k for each ecodivision with plots, c shared, penalty lambda toward the type's
#             CONUS-wide curve. As good as per-cell fits where data are rich, much better where they are sparse.
#   empty     ecodivisions with no plots of the type: A and log k from a plot-weighted regression on ecodivision climate
#             (PRISM normals: mean temperature, log precipitation); fewer than 3 ecodivisions with plots: the CONUS-wide curve.
# =============================================================================

wb_curve <- function(t, A, k, c, lag) ifelse(t <= lag, 0, A * (1 - exp(-k * pmax(t - lag, 0)^c)))

# FIA conditions -> fitting data (one row per plot-condition, latest visit)
growth_data <- function(cond_file, dist_file, opt) {
  x <- data.table::as.data.table(if (is.character(cond_file)) readRDS(cond_file) else cond_file); d <- data.table::as.data.table(if (is.character(dist_file)) readRDS(dist_file) else dist_file)   # a table, or the USGS .Rds file
  x <- merge(x, d, by = c("plt_cn", "condid"), all.x = TRUE)
  x[, pid := sprintf("%02d-%d-%03d-%05d", statecd, unitcd, countycd, plot)]
  x[, vol := net_merchantable_bole_wood_vol_live_trees_cuft_per_acre * 0.0699725]   # ft3/ac -> m3/ha
  x[, ecodiv := as.character(ecodiv)]
  x <- x[!is.na(stdage) & !is.na(vol) & !is.na(fortyp_grp) & invyr >= opt$MinInventoryYear & invyr <= 2100 &
         dstrbcd1 %in% 0 & trtcd1 %in% 0 & stdage >= 1 & stdage <= 400]
  x[, vcap := stats::quantile(vol, opt$VolumeCapQuantile), by = fortyp_grp]; x <- x[vol <= vcap]
  data.table::setorder(x, pid, condid, -invyr); x <- x[!duplicated(paste(pid, condid))]
  x[, .(pid, ecodiv, fortyp_grp, stdage, vol)] }

# least squares fit of the single (CONUS-wide) curve, several starts; lag = NULL fits the lag too (0 to max_lag)
fit_single <- function(t, v, lag, max_lag = 40) {
  A0 <- max(stats::quantile(v, 0.95), 5); best <- NULL; free <- is.null(lag)
  for (s in list(c(A0, 0.01, 0.8), c(A0, 0.001, 1.3), c(A0 * 1.3, 0.03, 0.6))) {
    if (free) s <- c(s, 8)
    o <- tryCatch(stats::optim(s, function(p) sum((v - wb_curve(t, p[1], p[2], p[3], if (free) p[4] else lag))^2), method = "L-BFGS-B",
                               lower = c(1, 1e-6, 0.1, 0)[seq_along(s)], upper = c(5000, 1, 4, max_lag)[seq_along(s)],
                               control = list(maxit = 5000, parscale = c(A0, 0.01, 1, 10)[seq_along(s)])), error = function(e) NULL)
    if (!is.null(o) && is.finite(o$value) && (is.null(best) || o$value < best$value)) best <- o }
  if (is.null(best)) return(NULL)
  c(A = best$par[1], k = best$par[2], c = best$par[3], L = if (free) best$par[4] else lag) }

# pooled fit: A_e and k_e per ecodivision, c shared; relative deviations from the CONUS-wide p0 penalised (lambda).
# lag = NULL fits one lag for the type (column L)
fit_type <- function(d, p0, lambda, lag, max_lag = 40) {
  eco <- sort(unique(d$ecodiv)); ie <- match(d$ecodiv, eco); E <- length(eco); pen <- lambda * nrow(d) * stats::var(d$vol)
  free <- is.null(lag)
  obj <- function(par) { A <- par[1:E]; k <- par[E + 1:E]
    sum((d$vol - wb_curve(d$stdage, A[ie], k[ie], par[2 * E + 1], if (free) par[2 * E + 2] else lag))^2) +
      pen * (mean(((A - p0[["A"]]) / p0[["A"]])^2) + mean(log(k / p0[["k"]])^2)) }
  o <- stats::optim(c(rep(p0[["A"]], E), rep(p0[["k"]], E), p0[["c"]], if (free) p0[["L"]]), obj, method = "L-BFGS-B",
                    lower = c(rep(1, E), rep(1e-6, E), 0.1, if (free) 0), upper = c(rep(5000, E), rep(1, E), 4, if (free) max_lag),
                    # A ~ 100s, k ~ 0.001, L ~ 10: rescaled so L-BFGS-B converges
                    control = list(maxit = 20000, parscale = c(rep(p0[["A"]], E), rep(p0[["k"]], E), p0[["c"]], if (free) 10)))
  data.table::data.table(ecodiv = eco, A = o$par[1:E], k = o$par[E + 1:E], c = o$par[2 * E + 1], L = if (free) o$par[2 * E + 2] else lag,
                         Plots = d[, .N, by = ecodiv][match(eco, ecodiv), N], converged = o$convergence == 0) }

# the lag of a forest type (or of a class of types): the pooled model with the lag free, on ecodivisions with enough plots
fit_lag <- function(d, opt) {
  cells <- d[, .N, by = ecodiv][N >= opt$MinPlotsEcodivision]$ecodiv
  p0 <- fit_single(d$stdage, d$vol, NULL, opt$MaximumLag); if (is.null(p0)) stop("the lag fit failed", call. = FALSE)
  fit_type(d[ecodiv %in% cells], p0, opt$Penalty, NULL, opt$MaximumLag)$L[1] }

# curves for every ecodivision in `all_eco` (with climate table clim: ecodiv, z_t, z_p) for one forest type's data, given its lag
fit_forest_type <- function(d, all_eco, clim, opt, lag) {
  p0 <- fit_single(d$stdage, d$vol, lag); if (is.null(p0)) stop("the CONUS-wide fit failed", call. = FALSE)
  cells <- d[, .N, by = ecodiv][N >= opt$MinPlotsEcodivision]$ecodiv
  m <- if (length(cells)) fit_type(d[ecodiv %in% cells], p0, opt$Penalty, lag) else NULL
  out <- data.table::data.table(ecodiv = all_eco)
  if (!is.null(m)) out <- merge(out, m, by = "ecodiv", all.x = TRUE)
  else out[, `:=`(A = NA_real_, k = NA_real_, c = NA_real_, Plots = NA_integer_, converged = NA)]
  out[!is.na(A), Method := "Fitted"]
  cshape <- if (!is.null(m)) m$c[1] else p0[["c"]]
  empty <- out[is.na(A), ecodiv]
  if (length(empty)) {
    if (!is.null(m) && nrow(m) >= 3) {
      mm <- merge(m, clim, by = "ecodiv")
      fa <- stats::lm(A ~ z_t + z_p, data = mm, weights = Plots); fk <- stats::lm(log(k) ~ z_t + z_p, data = mm, weights = Plots)
      ce <- clim[match(empty, clim$ecodiv)]
      Ae <- pmin(pmax(stats::predict(fa, ce), 0.25 * min(mm$A)), 1.5 * max(mm$A))
      ke <- pmin(pmax(exp(stats::predict(fk, ce)), min(mm$k) / 1.5), max(mm$k) * 1.5)
      out[match(empty, ecodiv), `:=`(A = Ae, k = ke, c = cshape, Method = "Climate")]
    } else out[match(empty, ecodiv), `:=`(A = p0[["A"]], k = p0[["k"]], c = p0[["c"]], Method = "CONUS")]
  }
  out[is.na(Plots), Plots := 0L]
  out[, `:=`(L = lag, TotalPlots = nrow(d), ConusA = p0[["A"]], ConusK = p0[["k"]], ConusC = p0[["c"]])]
  out[] }

# ecodivision climate: PRISM normals averaged over each ecodivision polygon, standardised
ecodiv_climate <- function(eco_file, prism_folder) {
  f_t <- Sys.glob(file.path(prism_folder, "normals", "PRISM_tmean_30yr_normal_*_annual_bil", "*.bil"))[1]
  f_p <- Sys.glob(file.path(prism_folder, "normals", "PRISM_ppt_30yr_normal_*_annual_bil", "*.bil"))[1]
  if (is.na(f_t) || is.na(f_p)) stop("PRISM annual tmean/ppt normals not found under ", prism_folder, "/normals", call. = FALSE)
  tm <- terra::rast(f_t); pp <- terra::rast(f_p)
  eco <- terra::vect(sf::st_transform(sf::read_sf(eco_file), terra::crs(tm)))
  cl <- data.table::data.table(ecodiv = eco$ecodiv, mat = terra::extract(tm, eco, fun = mean, na.rm = TRUE)[, 2],
                               map = terra::extract(pp, eco, fun = mean, na.rm = TRUE)[, 2])
  cl <- cl[, .(mat = mean(mat), map = mean(map)), by = ecodiv]
  cl[, `:=`(z_t = (mat - mean(mat)) / stats::sd(mat), z_p = (log(map) - mean(log(map))) / stats::sd(log(map)))]
  cl[] }

# ---- Carbon Assumptions: Growth Inputs (to-do 29) ---------------------------------------------------------------------
# The package defaults (forest-type-crosswalk.csv, merch-carbon-density.csv) with the user's rows laid over them. cw, dens: the two
# default tables (character columns, as read_default reads them); user: the sheet's rows (StateClassId as the state class name,
# GrowthClass as its label or code), or NULL; scl: the stsim State Class list (Id, Name). Returns list(cw, dens, fine, changed):
# cw and dens as the defaults with the user's values, fine = fixed fine root share per StateClassId (NA = Li et al. 2003), changed =
# the forest types whose inputs differ from the package's (one line each). A row for a state class the package has no growth
# inputs for stops with an error: such a class has no FIA type groups, density or curves to start from.
GROWTH_CLASSES <- c(`East Softwood` = "EastSoftwood", `East Hardwood` = "EastHardwood", `West Softwood` = "WestSoftwood", `West Hardwood` = "WestHardwood")
growth_inputs <- function(cw, dens, user, scl) {
  cw <- data.table::copy(cw); dens <- data.table::copy(dens)
  fine <- stats::setNames(rep(NA_real_, nrow(cw)), cw$StateClassId); changed <- character()
  if (is.null(user) || !nrow(user)) return(list(cw = cw, dens = dens, fine = fine, changed = changed))
  u <- data.table::as.data.table(user)
  u[, sid := as.character(scl$Id[match(as.character(StateClassId), scl$Name)])]
  u[is.na(sid), sid := as.character(StateClassId)]                 # a sheet read with lookups as ids
  bad <- u[!sid %in% cw$StateClassId, unique(as.character(StateClassId))]
  if (length(bad)) stop("Growth Inputs: no package growth inputs for ", paste(bad, collapse = ", "), " (only the package's forest types can be changed)", call. = FALSE)
  if (anyDuplicated(u$sid)) stop("Growth Inputs: more than one row for ", paste(unique(u$StateClassId[duplicated(u$sid)]), collapse = ", "), call. = FALSE)
  gc <- as.character(u$GrowthClass); num <- suppressWarnings(as.integer(gc))
  u[, lag := ifelse(!is.na(num), unname(GROWTH_CLASSES)[num], unname(GROWTH_CLASSES[gc]))]
  u[is.na(lag) & gc %in% GROWTH_CLASSES, lag := gc[is.na(lag) & gc %in% GROWTH_CLASSES]]
  for (i in seq_len(nrow(u))) { s <- u$sid[i]; j <- match(s, cw$StateClassId); k <- match(s, dens$StateClassId); d <- character()
    grp <- gsub("[[:space:]]", "", as.character(u$FiaTypeGroups[i]))
    if (!is.na(grp) && nzchar(grp)) { if (!grepl("^[0-9]+(;[0-9]+)*$", grp)) stop("Growth Inputs: FIA forest type groups for ", u$StateClassId[i], " must be codes separated by ';' (got '", grp, "')", call. = FALSE)
      if (grp != cw$FiaTypeGroups[j]) d <- c(d, sprintf("FIA groups %s (package %s)", grp, cw$FiaTypeGroups[j])); data.table::set(cw, j, "FiaTypeGroups", grp) }
    if (!is.na(u$lag[i])) { if (u$lag[i] != cw$LagClass[j]) d <- c(d, sprintf("growth class %s (package %s)", u$lag[i], cw$LagClass[j])); data.table::set(cw, j, "LagClass", u$lag[i]) }
    for (col in c("MgCPerM3", "DeciduousShare")) { v <- suppressWarnings(as.numeric(u[[if (col == "MgCPerM3") "MerchCarbonDensity" else col]][i]))
      if (!is.na(v)) { if (abs(v - as.numeric(dens[[col]][k])) > 1e-9) d <- c(d, sprintf("%s %g (package %s)", col, v, dens[[col]][k])); data.table::set(dens, k, col, as.character(v)) } }
    f <- suppressWarnings(as.numeric(u$FineRootShare[i])); if (!is.na(f)) { fine[[s]] <- f; d <- c(d, sprintf("fine root share %g (package: Li et al. 2003)", f)) }
    if (length(d)) changed <- c(changed, sprintf("%s: %s", u$StateClassId[i], paste(d, collapse = ", "))) }
  list(cw = cw, dens = dens, fine = fine, changed = changed) }
