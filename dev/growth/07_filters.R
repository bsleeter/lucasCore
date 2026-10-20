# Experiment 7: do the data filters matter? Cell fits (n >= 100) trained on different subsets, all scored on the same held-out
# plots (5 folds by plot): latest visit, untreated, undisturbed, any condition - the population the curves should describe.
#   base        latest visit, untreated, all conditions
#   all_visits  every visit of each plot-condition (remeasurements add age-volume pairs)
#   cond1       condition 1 only (the old script)
#   treated_in  treated (partially cut) conditions included
#   old_way     condition 1, treated included, plot number alone as id, age medians (the old script's whole recipe)
suppressPackageStartupMessages({ library(data.table); library(parallel) })
source("F:/lucasCore/dev/growth/curves.R")
FORM <- "weibull_t10"
x0 <- readRDS("F:/lucasCore/dev/growth/fia_prepared.rds")[undisturbed & age_ok & vol_ok & sc != 201]
x0[, fold := fold_ids(pid)]
test_pool <- x0[latest & untreated]
cells <- test_pool[, .N, by = .(sc, ecodiv)][N >= 100]
VAR <- list(base = quote(latest & untreated), all_visits = quote((untreated)), cond1 = quote(latest & untreated & cond1),
            treated_in = quote((latest)), old_way = quote((cond1)))
run <- function(i) { cc <- cells[i]; d <- x0[sc == cc$sc & ecodiv == cc$ecodiv]; te_all <- d[latest & untreated]
  rbindlist(lapply(names(VAR), function(v) { pred <- rep(NA_real_, nrow(te_all)); v100 <- c()
    for (k in 1:5) { tr <- d[fold != k][eval(VAR[[v]])]; te <- which(te_all$fold == k); if (nrow(tr) < 30) next
      if (v == "old_way") { tr[, pnum := sub("^.*-", "", pid)]; tr <- tr[, .(vol = mean(vol)), by = .(pnum, stdage)]
        a <- median_by_age(tr$stdage, tr$vol); p <- fit_form(FORM, a$t, a$v) } else p <- fit_form(FORM, tr$stdage, tr$vol)
      pred[te] <- predict_form(FORM, p, te_all$stdage[te]); v100 <- c(v100, predict_form(FORM, p, 100)) }
    data.table(sc = cc$sc, ecodiv = cc$ecodiv, n = nrow(te_all), variant = v, rmse = sqrt(mean((te_all$vol - pred)^2, na.rm = TRUE)),
               bias = mean(pred - te_all$vol, na.rm = TRUE), v100 = mean(v100), ntrain = nrow(d[eval(VAR[[v]])])) })) }
cl <- makeCluster(min(20, detectCores() - 2)); clusterExport(cl, c("x0", "cells", "VAR", "FORM", "FORMS", "fit_form", "predict_form", "median_by_age"))
invisible(clusterEvalQ(cl, library(data.table)))
r <- rbindlist(parLapply(cl, seq_len(nrow(cells)), run)); stopCluster(cl)
fwrite(r, "F:/lucasCore/dev/growth/out_exp7_filters.csv")
r[, v100_vs_base := v100 / v100[variant == "base"], by = .(sc, ecodiv)]
print(r[, .(cells = .N, train_rows = sum(ntrain), rmse = round(sqrt(weighted.mean(rmse^2, n)), 1), bias = round(weighted.mean(bias, n), 1),
            V100_vs_base_median = round(median(v100_vs_base), 3), V100_vs_base_p10 = round(quantile(v100_vs_base, .1), 3), V100_vs_base_p90 = round(quantile(v100_vs_base, .9), 3)), by = variant])
