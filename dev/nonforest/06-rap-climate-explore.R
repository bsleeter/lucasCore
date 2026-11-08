# =============================================================================
# 06-rap-climate-explore.R - which grass and shrub climate response reproduces RAP's year-to-year variation best (to-do 39 step 7)
# =============================================================================
# (user, 2026-11-07: stay with the RAP fit, calibrate it to the variability RAP observes.) The water-year fit (05-rap-climate-fit.R)
# beats the window mean in most windows but reproduces only about 0.4 of RAP's year-to-year variation (0.33-0.39 in the Mediterranean).
# Candidates, each one pooled regression over every window (no window effects: NPP is already a ratio to the window's own 1991-2020
# mean), judged by leave-one-window-out prediction (the window's rows out of the fit):
#   A  water-year P ratio, last water year's, T anomaly                                   (the model as built)
#   S  A with the water year's P split by season: Oct-Dec, Jan-Mar, Apr-Jun, Jul-Sep ratios to their own normals
#   L  log(NPP ratio) on log(P ratio) and log(last year's): a multiplicative response
#   D  A with the P terms' slopes varying with aridity (x log of the window's normal water-year P)
#   SD seasons and aridity together
#   each by life form (Annual grass / Perennial grass / Shrub) or all life forms together (one map per year in the model)
# Scores, median over windows and by region (Mediterranean or elsewhere): r, RMSE, SD ratio (predicted / observed), share of windows
# where the prediction beats the window's own mean. For the best model, a variance-matched version (the response scaled so its SD
# matches RAP's in each ecodivision) shows the RMSE that matching costs.
# Reads 04-rap-climate-sample.csv and PRISM monthly precipitation (PRISM env: a home's climate/prism). Prints; writes
# dev/nonforest/06-rap-climate-explore.csv.
# Usage: PRISM=<dir> Rscript dev/nonforest/06-rap-climate-explore.R
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages({ library(data.table); library(terra) }); options(width = 200)
PRISM <- Sys.getenv("PRISM"); if (!dir.exists(PRISM)) stop("set PRISM to a home's climate/prism")
OUT <- file.path(pkg, "dev", "nonforest"); NORMAL <- 1991:2020; MIN_CELLS <- 50; MIN_YEARS <- 30
s <- fread(file.path(OUT, "04-rap-climate-sample.csv"))[is.na(error) | error == ""]
s[, LifeForm := fifelse(StateClassId == "Grassland: Annual", "Annual grass", fifelse(startsWith(StateClassId, "Grassland"), "Perennial grass", fifelse(startsWith(StateClassId, "Shrubland"), "Shrub", NA_character_)))]
d <- s[!is.na(LifeForm), .(cells = sum(cells), npp = weighted.mean(NppAnnual + NppPerennial + NppShrub, nppCells, na.rm = TRUE), WyPpt = WyPpt[1], WyPptLag = WyPptLag[1],
       WyPptNormal = WyPptNormal[1], Tmean = Tmean[1], TmeanNormal = TmeanNormal[1], x = x[1], y = y[1]), by = .(StratumId, window, LifeForm, Year)]
d <- d[cells >= MIN_CELLS & is.finite(npp)]
d[, nppNormal := mean(npp[Year %in% NORMAL]), by = .(StratumId, window, LifeForm)]; d <- d[nppNormal > 0.05]

# ---- seasonal water-year precipitation at the window centres ----------------------------------------------------------------
ctr <- unique(d[, .(StratumId, window, x, y)]); pts <- vect(as.matrix(ctr[, .(x, y)]), crs = "EPSG:5070")
yrs <- sort(unique(d$Year)); mons <- unique(unlist(lapply(c(yrs, NORMAL), function(y) c(sprintf("%d%02d", y - 1, 10:12), sprintf("%d%02d", y, 1:9)))))
mf <- file.path(PRISM, "monthly-us25m", "ppt", sprintf("prism_ppt_us_25m_%s.tif", mons)); if (!all(file.exists(mf))) stop("PRISM monthly missing: ", paste(head(basename(mf[!file.exists(mf)]), 3), collapse = ", "))
mv <- as.matrix(terra::extract(rast(mf), project(pts, crs(rast(mf[1]))), method = "bilinear", ID = FALSE)); colnames(mv) <- mons
season <- list(OND = c(-1, 10:12), JFM = 1:3, AMJ = 4:6, JAS = 7:9)
sp <- function(y, s) { m <- if (s == "OND") sprintf("%d%02d", y - 1, 10:12) else sprintf("%d%02d", y, season[[s]]); rowSums(mv[, m, drop = FALSE]) }
sea <- rbindlist(lapply(yrs, function(y) data.table(ctr[, .(StratumId, window)], Year = y, OND = sp(y, "OND"), JFM = sp(y, "JFM"), AMJ = sp(y, "AMJ"), JAS = sp(y, "JAS"))))
nrs <- ctr[, .(StratumId, window)]; for (k in names(season)) nrs[, (paste0(k, "n")) := Reduce(`+`, lapply(NORMAL, function(y) sp(y, k))) / length(NORMAL)]
d <- merge(merge(d, sea, by = c("StratumId", "window", "Year")), nrs, by = c("StratumId", "window"))
# a season with almost no normal rain (a dry summer) gives ratios of noise: its anomaly is in mm of the water year's normal instead
for (k in names(season)) d[, (paste0("s_", k)) := (get(k) - get(paste0(k, "n"))) / WyPptNormal]
d[, `:=`(ratio = npp / nppNormal, pr = WyPpt / WyPptNormal - 1, pl = WyPptLag / WyPptNormal - 1, ta = Tmean - TmeanNormal, ar = log(WyPptNormal / 500))]
d <- d[is.finite(pr) & is.finite(pl)]; d[, n := .N, by = .(StratumId, window, LifeForm)]; d <- d[n >= MIN_YEARS]
d[, `:=`(win = paste(StratumId, window, LifeForm), med = grepl("^Mediterranean", StratumId))]
cat(sprintf("%d windows x life forms, %d window-years\n", uniqueN(d$win), nrow(d)))

# ---- candidates ------------------------------------------------------------------------------------------------------------
# ratio - 1 on terms without intercept (1.0 = normal climate); L on log(ratio) with log(P ratios)
M <- list(A = "I(ratio - 1) ~ 0 + pr + pl + ta",
          S = "I(ratio - 1) ~ 0 + s_OND + s_JFM + s_AMJ + s_JAS + pl + ta",
          L = "log(pmax(ratio, 0.05)) ~ 0 + log1p(pr) + log1p(pl) + ta",   # a year of no growth floored at 0.05
          D = "I(ratio - 1) ~ 0 + pr + pl + ta + pr:ar + pl:ar",
          SD = "I(ratio - 1) ~ 0 + s_OND + s_JFM + s_AMJ + s_JAS + pl + ta + s_OND:ar + s_JFM:ar + s_AMJ:ar + pl:ar")
pred <- function(fit, x, form) { p <- predict(fit, x); if (startsWith(form, "log")) exp(p) else 1 + p }
# leave-one-window-out: the window's rows out of the fit; by eco = fitted within the window's ecodivision (and life form)
loo <- function(form, by_lf, by_eco) {
  gg <- d[, paste(if (by_eco) StratumId else "", if (by_lf) LifeForm else "")]
  set(d, j = "grp", value = gg)
  rbindlist(lapply(split(d, by = "grp"), function(G) { f_all <- lm(as.formula(form), data = G)
    rbindlist(lapply(split(G, by = "win"), function(w) { fit <- if (uniqueN(G$win) > 1) lm(as.formula(form), data = G[win != w$win[1]]) else f_all
      p <- pred(fit, w, form)
      data.table(win = w$win[1], StratumId = w$StratumId[1], LifeForm = w$LifeForm[1], med = w$med[1], r = suppressWarnings(cor(w$ratio, p)), rmse = sqrt(mean((w$ratio - p)^2)),
                 base = sqrt(mean((w$ratio - mean(w$ratio))^2)), sdr = sd(p) / sd(w$ratio)) })) })) }
score <- function(z, label) z[, .(model = label, r = round(median(r, na.rm = TRUE), 3), rmse = round(median(rmse), 3), sd_ratio = round(median(sdr), 2), beats_mean = round(mean(rmse < base), 2)), by = .(region = fifelse(med, "Mediterranean", "elsewhere"))]
res <- list()
if (!nzchar(Sys.getenv("ONLY_VM"))) for (m in names(M)) for (lf in c(TRUE, FALSE)) for (eco in c(TRUE, FALSE)) { if (!eco && m %in% c()) next
  t0 <- Sys.time(); z <- loo(M[[m]], lf, eco); lab <- sprintf("%s %s %s", m, if (lf) "by life form" else "all forms", if (eco) "by ecodivision" else "CONUS")
  res[[lab]] <- score(z, lab); cat(sprintf("%-40s %.1f s\n", lab, as.numeric(difftime(Sys.time(), t0, units = "secs")))) }
if (!length(res)) res <- list(fread(file.path(OUT, "06-rap-climate-explore.csv")))   # ONLY_VM: the table of the last full run
tab <- rbindlist(res); setorder(tab, region, -r)
cat("\nLeave-one-window-out, median over windows:\n"); print(tab, nrows = 100)

# ---- variance matching: the best all-forms model scaled to RAP's SD by ecodivision ------------------------------------------
best <- tab[region == "Mediterranean" & grepl("all forms", model)][1]$model; bm <- strsplit(best, " ")[[1]][1]; be <- grepl("by ecodivision", best)
cat(sprintf("\nVariance matching %s:\n", best))
d[, grp := if (be) StratumId else ""]
vm <- rbindlist(lapply(split(d, by = "grp"), function(G) rbindlist(lapply(split(G, by = "win"), function(w) {
  fit <- lm(as.formula(M[[bm]]), data = G[win != w$win[1]]); p <- pred(fit, w, M[[bm]])
  # the scale that makes the other windows' predictions as variable as their RAP
  po <- pred(fit, G[win != w$win[1]], M[[bm]]); k <- G[win != w$win[1], sd(ratio)] / sd(po)
  rbindlist(lapply(c(0, 0.5, 0.75, 1), function(al) { q <- 1 + k^al * (p - 1)
  data.table(alpha = al, win = w$win[1], med = w$med[1], k = k^al, r = suppressWarnings(cor(w$ratio, q)), rmse = sqrt(mean((w$ratio - q)^2)), base = sqrt(mean((w$ratio - mean(w$ratio))^2)), sdr = sd(q) / sd(w$ratio)) })) }))))
print(vm[, .(scale = round(median(k), 2), r = round(median(r, na.rm = TRUE), 3), rmse = round(median(rmse), 3), sd_ratio = round(median(sdr), 2), beats_mean = round(mean(rmse < base), 2)), by = .(alpha, region = fifelse(med, "Mediterranean", "elsewhere"))][order(region, alpha)])
cat("(alpha: the response scaled by k^alpha, k = RAP's SD over the fit's in the other windows of the ecodivision; 0 = unscaled, 1 = matched)
")
if (nzchar(Sys.getenv("ONLY_VM"))) quit(save = "no")
fwrite(tab, file.path(OUT, "06-rap-climate-explore.csv")); cat("wrote dev/nonforest/06-rap-climate-explore.csv\n")
