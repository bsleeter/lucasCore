# Experiment 1: which curve form, and plot-level data or age medians? Cell-wise fits (type group x ecodivision, n >= 100),
# 5-fold cross-validation grouped by plot; scored on held-out plot volumes.
suppressPackageStartupMessages({ library(data.table); library(parallel) })
source("F:/lucasCore/dev/growth/curves.R")
x <- readRDS("F:/lucasCore/dev/growth/fia_prepared.rds")
x <- x[undisturbed & untreated & age_ok & vol_ok & latest & sc != 201]
x[, fold := fold_ids(pid)]
cells <- x[, .N, by = .(sc, ecodiv)][N >= 100]
cat("cells with n >= 100:", nrow(cells), " records:", sum(cells$N), "\n")
methods <- c(paste0(names(FORMS), ":plot"), "weibull_t10:median")
run_cell <- function(i) {
  cc <- cells[i]; d <- x[sc == cc$sc & ecodiv == cc$ecodiv]
  out <- list()
  for (m in methods) { form <- sub(":.*", "", m); how <- sub(".*:", "", m)
    pred <- rep(NA_real_, nrow(d)); bound <- 0
    for (k in 1:5) { tr <- d[fold != k]; te <- which(d$fold == k)
      if (how == "median") { a <- median_by_age(tr$stdage, tr$vol); p <- fit_form(form, a$t, a$v) } else p <- fit_form(form, tr$stdage, tr$vol)
      bound <- bound + isTRUE(attr(p, "at_bound")); pred[te] <- predict_form(form, p, d$stdage[te]) }
    r <- d$vol - pred
    out[[m]] <- data.table(sc = cc$sc, ecodiv = cc$ecodiv, n = nrow(d), method = m, rmse = sqrt(mean(r^2, na.rm = TRUE)),
                           bias = mean(pred - d$vol, na.rm = TRUE), mae = mean(abs(r), na.rm = TRUE), failed = sum(is.na(pred)), bound = bound,
                           sst = sum((d$vol - mean(d$vol))^2), sse = sum(r^2, na.rm = TRUE)) }
  rbindlist(out) }
cl <- makeCluster(min(20, detectCores() - 2)); clusterExport(cl, c("x", "cells", "methods", "FORMS", "fit_form", "predict_form", "median_by_age"))
invisible(clusterEvalQ(cl, library(data.table)))
t0 <- Sys.time(); res <- rbindlist(parLapply(cl, seq_len(nrow(cells)), run_cell)); stopCluster(cl)
cat(sprintf("%.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
fwrite(res, "F:/lucasCore/dev/growth/out_exp1_forms_cv.csv")
s <- res[, .(cells = .N, R2_cv = 1 - sum(sse) / sum(sst), rmse_w = sqrt(sum(sse) / sum(n)), bias_w = sum(bias * n) / sum(n),
             wins = 0L, bound_fits = sum(bound > 0), failed = sum(failed)), by = method]
w <- res[, .SD[which.min(rmse)], by = .(sc, ecodiv)][, .N, by = method]; s[w, wins := i.N, on = "method"]
print(s[order(-R2_cv)])
