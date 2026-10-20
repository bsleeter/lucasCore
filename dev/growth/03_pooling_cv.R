# Experiment 2: how should sparse and empty cells get a curve? (run after experiment 1 picks the form)
# For every type group: compare, on held-out plots (5-fold, grouped by plot), for cells of every size (n >= 5):
#   cell      cell-wise least squares where n >= NMIN, else the type group's CONUS-wide curve
#   conus     the type group's CONUS-wide curve everywhere (the simplest fallback)
#   shrunk    asymptote per ecodivision shrunk toward the CONUS-wide asymptote (shape k, c shared by the type group):
#             a penalised least-squares fit, lambda chosen by cross-validation - partial pooling without nlme's convergence fragility
#   nlme      nonlinear mixed model: random asymptote by ecodivision (where it converges)
# And leave-one-ecodivision-out for well-sampled cells: how good is the fallback for a cell with NO data?
suppressPackageStartupMessages({ library(data.table); library(parallel) })
source("F:/lucasCore/dev/growth/curves.R")
a <- commandArgs(TRUE); FORM <- if (length(a)) a[1] else "richards"; NMIN <- 100
x <- readRDS("F:/lucasCore/dev/growth/fia_prepared.rds")
x <- x[undisturbed & untreated & age_ok & vol_ok & latest & sc != 201]
x[, fold := fold_ids(pid)]
F <- FORMS[[FORM]]; pn <- names(F$start(100)[[1]])

# shared-shape fit: one asymptote per ecodivision, shape shared; penalty lambda * sum((A_e - A_0)^2 / A_0^2) * n_total pulls sparse
# ecodivisions toward the pooled asymptote A_0 (lambda = 0: free asymptotes; large: one curve)
fit_shared <- function(d, lambda, p0) {
  eco <- sort(unique(d$ecodiv)); ie <- match(d$ecodiv, eco); A0 <- p0[["A"]]; shape <- p0[setdiff(pn, "A")]
  obj <- function(par) { A <- par[seq_along(eco)]; sh <- setNames(par[-seq_along(eco)], names(shape))
    pr <- numeric(nrow(d)); for (j in seq_along(eco)) { r <- ie == j; pr[r] <- F$f(d$stdage[r], c(A = A[j], sh)) }
    sum((d$vol - pr)^2) + lambda * nrow(d) * var(d$vol) * sum(((A - A0) / A0)^2) / length(eco) }
  o <- optim(c(rep(A0, length(eco)), shape), obj, method = "L-BFGS-B",
             lower = c(rep(F$lower[["A"]], length(eco)), F$lower[names(shape)]), upper = c(rep(F$upper[["A"]], length(eco)), F$upper[names(shape)]),
             control = list(maxit = 3000))
  list(eco = eco, A = setNames(o$par[seq_along(eco)], eco), shape = setNames(o$par[-seq_along(eco)], names(shape))) }
pred_shared <- function(m, d, p0) {
  A <- m$A[d$ecodiv]; A[is.na(A)] <- p0[["A"]]
  F$f(d$stdage, c(A = 1, m$shape)) * A }   # every form here is linear in A

run_ftg <- function(g) {
  d <- x[sc == g]; if (nrow(d) < 30) return(NULL)
  pred <- data.table(i = seq_len(nrow(d)), cell = NA_real_, conus = NA_real_, s0 = NA_real_, s1 = NA_real_, s3 = NA_real_, s10 = NA_real_)
  for (k in 1:5) { tr <- d[fold != k]; te <- which(d$fold == k); dt <- d[te]
    p0 <- fit_form(FORM, tr$stdage, tr$vol); if (is.null(p0)) next
    pred[te, conus := predict_form(FORM, p0, dt$stdage)]
    pc <- rep(NA_real_, length(te))
    for (e in unique(dt$ecodiv)) { r <- dt$ecodiv == e; tre <- tr[ecodiv == e]
      p <- if (nrow(tre) >= NMIN) fit_form(FORM, tre$stdage, tre$vol) else NULL
      pc[r] <- if (is.null(p)) predict_form(FORM, p0, dt$stdage[r]) else predict_form(FORM, p, dt$stdage[r]) }
    pred[te, cell := pc]
    for (lam in c(0, 1, 3, 10)) { m <- fit_shared(tr, lam / 100, p0); pred[te, (paste0("s", lam)) := pred_shared(m, dt, p0)] }
  }
  pred[, `:=`(sc = g, ecodiv = d$ecodiv, vol = d$vol, stdage = d$stdage)]
  pred }

# leave-one-ecodivision-out: for each cell with n >= NMIN, fit the type group without it; predict the cell from the CONUS-wide fit
loeo <- function(g) { d <- x[sc == g]; cs <- d[, .N, by = ecodiv][N >= NMIN]$ecodiv; if (length(unique(d$ecodiv)) < 2) return(NULL)
  rbindlist(lapply(cs, function(e) { tr <- d[ecodiv != e]; te <- d[ecodiv == e]; if (nrow(tr) < 30) return(NULL)
    p0 <- fit_form(FORM, tr$stdage, tr$vol); pe <- fit_form(FORM, te$stdage, te$vol)
    data.table(sc = g, ecodiv = e, n = nrow(te), rmse_fallback = sqrt(mean((te$vol - predict_form(FORM, p0, te$stdage))^2)),
               bias_fallback = mean(predict_form(FORM, p0, te$stdage) - te$vol),
               rmse_own_insample = sqrt(mean((te$vol - predict_form(FORM, pe, te$stdage))^2))) })) }

cl <- makeCluster(min(20, detectCores() - 2)); clusterExport(cl, c("x", "FORM", "F", "pn", "NMIN", "FORMS", "fit_form", "predict_form", "fit_shared", "pred_shared"))
invisible(clusterEvalQ(cl, library(data.table)))
t0 <- Sys.time()
P <- rbindlist(parLapply(cl, sort(unique(x$sc)), run_ftg)); LO <- rbindlist(parLapply(cl, sort(unique(x$sc)), loeo)); stopCluster(cl)
cat(sprintf("%s: %.1f min\n", FORM, as.numeric(Sys.time() - t0, units = "mins")))
fwrite(P, sprintf("F:/lucasCore/dev/growth/out_exp2_pred_%s.csv", FORM)); fwrite(LO, sprintf("F:/lucasCore/dev/growth/out_exp2_loeo_%s.csv", FORM))
P[, nc := .N, by = .(sc, ecodiv)][, size := cut(nc, c(0, 30, 100, 300, 1000, Inf), labels = c("<30", "30-100", "100-300", "300-1000", ">1000"))]
long <- melt(P, id.vars = c("sc", "ecodiv", "vol", "size"), measure.vars = c("cell", "conus", "s0", "s1", "s3", "s10"), variable.name = "method", value.name = "pred")
print(dcast(long[, .(rmse = sqrt(mean((vol - pred)^2, na.rm = TRUE))), by = .(size, method)], size ~ method, value.var = "rmse"))
print(dcast(long[, .(bias = mean(pred - vol, na.rm = TRUE)), by = .(size, method)], size ~ method, value.var = "bias"))
cat("\nleave-one-ecodivision-out (cells n >= 100): fallback RMSE vs the cell's own in-sample fit\n")
print(LO[, .(cells = .N, rmse_fallback = sqrt(weighted.mean(rmse_fallback^2, n)), rmse_own = sqrt(weighted.mean(rmse_own_insample^2, n)),
             bias_fallback = weighted.mean(bias_fallback, n))])
