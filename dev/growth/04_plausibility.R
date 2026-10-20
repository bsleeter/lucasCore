# Experiment 3: do the forms behave sensibly where the data are thin? Full-data cell fits (n >= 100), plot-level least squares.
#   A_q95        asymptote / 95th percentile of observed volume (>> 1: the curve keeps climbing past anything observed)
#   cmai_age     age of culmination of mean annual increment V(t)/t (forestry sanity check: ~20-120 yr)
#   grow_old     V(300) / V(age of the 99th percentile of observed ages): growth predicted beyond the data
#   v10_share    V(10) / V(100): early growth (0 for the lagged Weibull by construction)
suppressPackageStartupMessages({ library(data.table); library(parallel) })
source("F:/lucasCore/dev/growth/curves.R")
x <- readRDS("F:/lucasCore/dev/growth/fia_prepared.rds")[undisturbed & untreated & age_ok & vol_ok & latest & sc != 201]
cells <- x[, .N, by = .(sc, ecodiv)][N >= 100]
run <- function(i) { cc <- cells[i]; d <- x[sc == cc$sc & ecodiv == cc$ecodiv]; a99 <- quantile(d$stdage, .99); q95 <- quantile(d$vol, .95)
  rbindlist(lapply(names(FORMS), function(fm) { p <- fit_form(fm, d$stdage, d$vol); if (is.null(p)) return(NULL)
    t <- 1:500; v <- predict_form(fm, p, t); mai <- v / t
    data.table(sc = cc$sc, ecodiv = cc$ecodiv, n = nrow(d), form = fm, A_q95 = p[["A"]] / q95, cmai_age = t[which.max(mai)],
               grow_old = predict_form(fm, p, 300) / max(predict_form(fm, p, a99), 1e-6), v10_share = predict_form(fm, p, 10) / max(predict_form(fm, p, 100), 1e-6),
               a99 = a99, at_bound = isTRUE(attr(p, "at_bound"))) })) }
cl <- makeCluster(min(20, detectCores() - 2)); clusterExport(cl, c("x", "cells", "FORMS", "fit_form", "predict_form")); invisible(clusterEvalQ(cl, library(data.table)))
r <- rbindlist(parLapply(cl, seq_len(nrow(cells)), run)); stopCluster(cl)
fwrite(r, "F:/lucasCore/dev/growth/out_exp3_plausibility.csv")
print(r[, .(cells = .N, A_q95_med = round(median(A_q95), 2), A_q95_gt3 = sum(A_q95 > 3), cmai_med = median(cmai_age),
            cmai_out_15_150 = sum(cmai_age < 15 | cmai_age > 150), grow_old_med = round(median(grow_old), 2), grow_old_gt1.5 = sum(grow_old > 1.5),
            v10_med = round(median(v10_share), 3), at_bound = sum(at_bound)), by = form])
