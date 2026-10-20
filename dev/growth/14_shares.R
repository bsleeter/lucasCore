# Experiment 14: foliage and root share fits. Variants, scored as pool bias by age band against FIA (in-sample):
#   type_sq     per forest type, minimise sum (num - s den)^2  (stage 2 as first built: big plots dominate)
#   type_ratio  per forest type, minimise sum (num - s den)^2 / den  (= ratio of sums at each age)
#   eco_ratio   per forest type x ecodivision where it has >= 200 plots, else type_ratio
suppressPackageStartupMessages(library(data.table))
source("F:/lucasCore/src/carbon.R")
D <- "F:/lucas-master/Data Sources/FIA/"
x <- carbon_data(paste0(D, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds"), paste0(D, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds"),
                 list(MinInventoryYear = 1997, VolumeCapQuantile = 0.999))
cw <- fread("F:/lucasCore/defaults/growth/forest-type-crosswalk.csv", colClasses = "character")
g2sc <- cw[StateClassId != "201", .(fortyp_grp = as.integer(unlist(strsplit(FiaTypeGroups, ";")))), by = StateClassId][!duplicated(fortyp_grp)]
x <- merge(x, g2sc, by = "fortyp_grp"); setnames(x, "StateClassId", "sc")
fit_share_w <- function(t, num, den, weighted) { ok <- den > 0; t <- t[ok]; num <- num[ok]; den <- den[ok]; w <- if (weighted) 1 / den else rep(1, length(den))
  s_all <- sum(num) / sum(den); best <- NULL
  for (st in list(c(s_all, s_all, 20), c(min(s_all * 2, 1), s_all, 10), c(s_all / 2, s_all, 40))) {
    o <- optim(st, function(p) sum(w * (num - share_curve(t, c(s0 = p[1], s_inf = p[2], tau = p[3])) * den)^2), method = "L-BFGS-B", lower = c(0, 0, 1), upper = c(1, 1, 200))
    if (is.null(best) || o$value < best$value) best <- o }
  c(s0 = best$par[1], s_inf = best$par[2], tau = best$par[3]) }
pred <- function(d, weighted, by_eco) {
  out <- copy(d)[, `:=`(fol = NA_real_, bg = NA_real_)]
  for (s in unique(d$sc)) { ds <- d[sc == s]
    pf <- fit_share_w(ds$stdage, ds$c_fol, ds$c_live, weighted); pb <- fit_share_w(ds$stdage, ds$c_bg, ds$c_live, weighted)
    out[sc == s, `:=`(fol = share_curve(stdage, pf) * c_live, bg = share_curve(stdage, pb) * c_live)]
    if (by_eco) for (e in ds[, .N, by = ecodiv][N >= 200]$ecodiv) { de <- ds[ecodiv == e]
      pf <- fit_share_w(de$stdage, de$c_fol, de$c_live, weighted); pb <- fit_share_w(de$stdage, de$c_bg, de$c_live, weighted)
      out[sc == s & ecodiv == e, `:=`(fol = share_curve(stdage, pf) * c_live, bg = share_curve(stdage, pb) * c_live)] } }
  out }
V <- list(type_sq = pred(x, FALSE, FALSE), type_ratio = pred(x, TRUE, FALSE), eco_ratio = pred(x, TRUE, TRUE))
band <- function(a) cut(a, c(0, 5, 10, 20, 30, 50, 100, 400), labels = c("1-5", "6-10", "11-20", "21-30", "31-50", "51-100", ">100"))
r <- rbindlist(lapply(names(V), function(v) V[[v]][, .(variant = v, fol_bias_pct = round(100 * (sum(fol) / sum(c_fol) - 1), 1),
                                                         root_bias_pct = round(100 * (sum(bg) / sum(c_bg) - 1), 1)), by = .(band = band(stdage))]))
print(dcast(r, band ~ variant, value.var = "fol_bias_pct")[order(band)]); print(dcast(r, band ~ variant, value.var = "root_bias_pct")[order(band)])
cat("\nfoliage bias by forest type, >100 yr (type_ratio vs eco_ratio):\n")
print(merge(V$type_ratio[stdage > 100, .(n = .N, type_ratio = round(100 * (sum(fol) / sum(c_fol) - 1), 1)), by = sc],
            V$eco_ratio[stdage > 100, .(eco_ratio = round(100 * (sum(fol) / sum(c_fol) - 1), 1)), by = sc], by = "sc")[order(-n)][1:10])
