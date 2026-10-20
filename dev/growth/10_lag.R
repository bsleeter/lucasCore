# Experiment 10: is the 10-year lag needed? FIA merchantable volume counts trees >= 5 in dbh, so the true lag is the age a stand
# reaches that size - species-specific. Same data and pooled model as stage 2 (src/growth.R), per forest type:
#   L10    fixed 10-year lag (stage 2 as built)
#   L0     no lag (plain Weibull onset)
#   Lfit   lag fitted per forest type (shared by its ecodivisions), 0-40 yr
# (A) empirical onset: share of plots with any merchantable volume, by age; (B) 5-fold CV grouped by plot, bias by age band.
suppressPackageStartupMessages({ library(data.table); library(parallel) })
source("F:/lucasCore/src/growth.R")
D <- "F:/lucas-master/Data Sources/FIA/"
opt <- list(MinInventoryYear = 1997, VolumeCapQuantile = 0.999, Penalty = 0.01, MinPlotsEcodivision = 5)
x <- growth_data(paste0(D, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds"), paste0(D, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds"), opt)
cw <- fread("F:/lucasCore/defaults/growth/forest-type-crosswalk.csv", colClasses = "character")
sets <- unique(cw[, .(set = FiaTypeGroups, name = StateClassName)], by = "set")
grp <- function(s) as.integer(strsplit(s, ";")[[1]])

# ---- (A) onset ----
on <- rbindlist(lapply(seq_len(nrow(sets)), function(i) { d <- x[fortyp_grp %in% grp(sets$set[i]) & stdage <= 60]
  b <- d[, .(share = mean(vol > 0), mean_vol = mean(vol), n = .N), by = .(age = pmin(stdage, 60))][order(age)]
  b[, cs := frollmean(share, 3, align = "center")]
  data.table(type = sets$name[i], plots_age_le20 = d[stdage <= 20, .N], vol_1_5 = round(d[stdage <= 5, mean(vol)], 1), vol_6_10 = round(d[stdage %in% 6:10, mean(vol)], 1),
             vol_11_15 = round(d[stdage %in% 11:15, mean(vol)], 1), age50 = b[cs >= 0.5, suppressWarnings(min(age))], age90 = b[cs >= 0.9, suppressWarnings(min(age))]) }))
fwrite(on, "F:/lucasCore/dev/growth/out_exp10_onset.csv"); cat("(A) onset of merchantable volume\n"); print(on[order(age50)])

# ---- (B) cross-validation ----
fit_single_L <- function(t, v, lag) { A0 <- max(quantile(v, .95), 5); best <- NULL
  st <- list(c(A0, 0.01, 0.8), c(A0, 0.001, 1.3), c(A0 * 1.3, 0.03, 0.6))
  for (s in st) { if (is.null(lag)) s <- c(s, 8)
    f <- function(p) sum((v - wb_curve(t, p[1], p[2], p[3], if (is.null(lag)) p[4] else lag))^2)
    o <- tryCatch(optim(s, f, method = "L-BFGS-B", lower = c(1, 1e-6, 0.1, 0)[seq_along(s)], upper = c(5000, 1, 4, 40)[seq_along(s)],
                        control = list(maxit = 5000, parscale = c(A0, 0.01, 1, 10)[seq_along(s)])), error = function(e) NULL)
    if (!is.null(o) && (is.null(best) || o$value < best$value)) best <- o }
  p <- best$par; c(A = p[1], k = p[2], c = p[3], L = if (is.null(lag)) p[4] else lag) }
fit_type_L <- function(d, p0, lambda, lag) { eco <- sort(unique(d$ecodiv)); ie <- match(d$ecodiv, eco); E <- length(eco); pen <- lambda * nrow(d) * var(d$vol)
  free <- is.null(lag)
  obj <- function(par) { A <- par[1:E]; k <- par[E + 1:E]; L <- if (free) par[2 * E + 2] else lag
    sum((d$vol - wb_curve(d$stdage, A[ie], k[ie], par[2 * E + 1], L))^2) + pen * (mean(((A - p0[["A"]]) / p0[["A"]])^2) + mean(log(k / p0[["k"]])^2)) }
  st <- c(rep(p0[["A"]], E), rep(p0[["k"]], E), p0[["c"]], if (free) p0[["L"]])
  o <- optim(st, obj, method = "L-BFGS-B", lower = c(rep(1, E), rep(1e-6, E), 0.1, if (free) 0), upper = c(rep(5000, E), rep(1, E), 4, if (free) 40),
             control = list(maxit = 20000, parscale = c(rep(p0[["A"]], E), rep(p0[["k"]], E), p0[["c"]], if (free) 10)))
  list(eco = eco, A = o$par[1:E], k = o$par[E + 1:E], c = o$par[2 * E + 1], L = if (free) o$par[2 * E + 2] else lag) }
pred_L <- function(m, p0, d) { i <- match(d$ecodiv, m$eco); A <- ifelse(is.na(i), p0[["A"]], m$A[i]); k <- ifelse(is.na(i), p0[["k"]], m$k[i])
  wb_curve(d$stdage, A, k, m$c, m$L) }

fold_ids <- function(pid, k = 5, seed = 20261019) { u <- unique(pid); set.seed(seed); f <- sample(rep_len(seq_len(k), length(u))); f[match(pid, u)] }
VARIANTS <- list(L10 = 10, L0 = 0, Lfit = NULL)
run_set <- function(i) { d <- x[fortyp_grp %in% grp(sets$set[i])]; d[, fold := fold_ids(pid)]
  out <- list(); lag_fit <- c()
  for (v in names(VARIANTS)) { pr <- rep(NA_real_, nrow(d))
    for (k in 1:5) { tr <- d[fold != k]; tr <- tr[ecodiv %in% tr[, .N, by = ecodiv][N >= 5]$ecodiv]; te <- which(d$fold == k)
      p0 <- fit_single_L(tr$stdage, tr$vol, VARIANTS[[v]]); m <- fit_type_L(tr, p0, 0.01, if (is.null(VARIANTS[[v]])) NULL else VARIANTS[[v]])
      if (v == "Lfit") lag_fit <- c(lag_fit, m$L); pr[te] <- pred_L(m, p0, d[te]) }
    out[[v]] <- data.table(type = sets$name[i], variant = v, stdage = d$stdage, vol = d$vol, pred = pr) }
  # the lag fitted on all data, for the record
  p0 <- fit_single_L(d$stdage, d$vol, NULL); dd <- d[ecodiv %in% d[, .N, by = ecodiv][N >= 5]$ecodiv]; m <- fit_type_L(dd, p0, 0.01, NULL)
  list(pred = rbindlist(out), lag = data.table(type = sets$name[i], lag_all = m$L, lag_cv_min = min(lag_fit), lag_cv_max = max(lag_fit), plots = nrow(d))) }

cl <- makeCluster(min(nrow(sets), detectCores() - 1))
clusterExport(cl, c("x", "sets", "grp", "VARIANTS", "wb_curve", "fit_single_L", "fit_type_L", "pred_L", "fold_ids"))
invisible(clusterEvalQ(cl, library(data.table)))
t0 <- Sys.time(); R <- parLapply(cl, seq_len(nrow(sets)), run_set); stopCluster(cl)
cat(sprintf("\n(B) %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
P <- rbindlist(lapply(R, `[[`, "pred")); LG <- rbindlist(lapply(R, `[[`, "lag"))
saveRDS(P, "F:/lucasCore/dev/growth/out_exp10_pred.rds"); fwrite(LG, "F:/lucasCore/dev/growth/out_exp10_lags.csv")
P[, band := cut(stdage, c(0, 10, 20, 30, 50, 100, 400), labels = c("1-10", "11-20", "21-30", "31-50", "51-100", ">100"))]
cat("overall\n"); print(P[, .(rmse = round(sqrt(mean((vol - pred)^2)), 2), bias = round(mean(pred - vol), 2)), by = variant])
cat("\nbias by age band (m3/ha; observed mean in brackets)\n")
bb <- P[, .(bias = round(mean(pred - vol), 1), obs = round(mean(vol), 1), n = .N / 3), by = .(band, variant)]
print(dcast(bb, band + obs + n ~ variant, value.var = "bias"))
cat("\nRMSE by age band\n"); print(dcast(P[, .(rmse = round(sqrt(mean((vol - pred)^2)), 1)), by = .(band, variant)], band ~ variant, value.var = "rmse"))
cat("\nfitted lag per type (all data; range over the 5 CV folds) with onset ages\n"); print(merge(LG, on[, .(type, age50, age90, vol_6_10)], by = "type")[order(lag_all)], digits = 3)
tb <- P[, .(rmse = sqrt(mean((vol - pred)^2))), by = .(type, variant)]; print(dcast(tb, type ~ variant, value.var = "rmse")[, best := c("L10", "L0", "Lfit")[apply(cbind(L10, L0, Lfit), 1, which.min)]][, .N, by = best])
