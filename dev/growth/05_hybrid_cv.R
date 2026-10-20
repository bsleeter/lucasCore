# Experiments 4-5: (4) where to switch from a cell's own fit to the pooled fit, and how hard to pull toward the type group;
# (5) whether the growth rate k should vary by ecodivision too (asymptote A and k per ecodivision, shape c shared).
# Out-of-fold predictions (5 folds grouped by plot) for every cell with n >= 5 and every method; combined offline into hybrids.
suppressPackageStartupMessages({ library(data.table); library(parallel) })
source("F:/lucasCore/dev/growth/curves.R")
FORM <- "weibull_t10"; F <- FORMS[[FORM]]
x <- readRDS("F:/lucasCore/dev/growth/fia_prepared.rds")[undisturbed & untreated & age_ok & vol_ok & latest & sc != 201]
x[, fold := fold_ids(pid)]
LAMBDAS <- c(0, 0.003, 0.01, 0.03, 0.1, 0.3, 1)

# pooled fit with per-ecodivision A (and optionally k), shared c; relative deviations from the pooled values are penalised
fit_pooled <- function(d, lambda, p0, vary_k) {
  eco <- sort(unique(d$ecodiv)); ie <- match(d$ecodiv, eco); E <- length(eco)
  pen <- lambda * nrow(d) * var(d$vol)
  unpack <- function(par) list(A = par[1:E], k = if (vary_k) par[E + 1:E] else rep(par[E + 1], E), c = par[length(par)])
  obj <- function(par) { u <- unpack(par); t <- pmax(d$stdage - 10, 0)
    pr <- ifelse(d$stdage <= 10, 0, u$A[ie] * (1 - exp(-u$k[ie] * t^u$c)))
    sum((d$vol - pr)^2) + pen * (mean(((u$A - p0[["A"]]) / p0[["A"]])^2) + if (vary_k) mean(log(u$k / p0[["k"]])^2) else 0) }
  st <- c(rep(p0[["A"]], E), if (vary_k) rep(p0[["k"]], E) else p0[["k"]], p0[["c"]])
  lo <- c(rep(F$lower[["A"]], E), rep(F$lower[["k"]], if (vary_k) E else 1), F$lower[["c"]])
  hi <- c(rep(F$upper[["A"]], E), rep(F$upper[["k"]], if (vary_k) E else 1), F$upper[["c"]])
  o <- optim(st, obj, method = "L-BFGS-B", lower = lo, upper = hi, control = list(maxit = 5000))
  u <- unpack(o$par); list(eco = eco, A = setNames(u$A, eco), k = setNames(u$k, eco), c = u$c) }
pred_pooled <- function(m, d, p0) { A <- m$A[d$ecodiv]; k <- m$k[d$ecodiv]; A[is.na(A)] <- p0[["A"]]; k[is.na(k)] <- p0[["k"]]
  ifelse(d$stdage <= 10, 0, A * (1 - exp(-k * pmax(d$stdage - 10, 0)^m$c))) }

run_ftg <- function(g) {
  d <- x[sc == g]; if (nrow(d) < 30) return(NULL)
  P <- data.table(sc = g, ecodiv = d$ecodiv, vol = d$vol, stdage = d$stdage, fold = d$fold)
  for (k in 1:5) { tr <- d[fold != k]; te <- which(d$fold == k); dt <- d[te]
    p0 <- fit_form(FORM, tr$stdage, tr$vol); if (is.null(p0)) next
    P[te, conus := predict_form(FORM, p0, dt$stdage)]
    own <- rep(NA_real_, length(te))
    for (e in unique(dt$ecodiv)) { r <- dt$ecodiv == e; tre <- tr[ecodiv == e]
      if (nrow(tre) >= 30) { p <- fit_form(FORM, tre$stdage, tre$vol); own[r] <- predict_form(FORM, p, dt$stdage[r]) } }
    P[te, own := own]
    for (lam in LAMBDAS) for (vk in c(FALSE, TRUE)) { m <- fit_pooled(tr, lam, p0, vk)
      P[te, (sprintf("%s_%g", if (vk) "Ak" else "A", lam)) := pred_pooled(m, dt, p0)] } }
  P }

cl <- makeCluster(min(20, detectCores() - 2)); clusterExport(cl, c("x", "FORM", "F", "FORMS", "LAMBDAS", "fit_form", "predict_form", "fit_pooled", "pred_pooled"))
invisible(clusterEvalQ(cl, library(data.table)))
t0 <- Sys.time(); P <- rbindlist(parLapply(cl, sort(unique(x$sc)), run_ftg), fill = TRUE); stopCluster(cl)
cat(sprintf("%.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
saveRDS(P, "F:/lucasCore/dev/growth/out_exp45_pred.rds")

# ---- summaries ----
P[, nc := .N, by = .(sc, ecodiv)][, size := cut(nc, c(0, 30, 100, 300, 1000, Inf), labels = c("<30", "30-100", "100-300", "300-1000", ">1000"))]
pm <- grep("^(A|Ak)_", names(P), value = TRUE)
long <- melt(P, id.vars = c("sc", "ecodiv", "vol", "size", "nc"), measure.vars = c("conus", "own", pm), variable.name = "method", value.name = "pred")
tab <- long[!is.na(pred), .(rmse = sqrt(mean((vol - pred)^2)), bias = mean(pred - vol)), by = .(size, method)]
cat("\nRMSE by cell size (own = cell fit where n >= 30 in training)\n"); print(dcast(tab, method ~ size, value.var = "rmse"), digits = 4)
cat("\nBias by cell size\n"); print(dcast(tab, method ~ size, value.var = "bias"), digits = 3)
# hybrids: own fit where n >= T, pooled method m otherwise
hy <- rbindlist(lapply(c(100, 300, 1000, 1e9), function(T) rbindlist(lapply(pm, function(m) {
  pr <- ifelse(P$nc >= T & !is.na(P$own), P$own, P[[m]])
  data.table(T = T, pooled = m, rmse = sqrt(mean((P$vol - pr)^2, na.rm = TRUE)),
             rmse_sparse = sqrt(mean(((P$vol - pr)^2)[P$nc < 300], na.rm = TRUE)), bias = mean(pr - P$vol, na.rm = TRUE)) }))))
cat("\nHybrids (T = 1e9: pooled everywhere), best 12 by overall RMSE\n"); print(hy[order(rmse)][1:12], digits = 4)
fwrite(hy, "F:/lucasCore/dev/growth/out_exp45_hybrids.csv"); fwrite(tab, "F:/lucasCore/dev/growth/out_exp45_bysize.csv")
