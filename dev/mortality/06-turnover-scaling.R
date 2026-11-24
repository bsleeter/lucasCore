# =============================================================================
# 06-turnover-scaling.R - to-do 3, phase 0: can canopy change scale background (stem turnover) mortality? FIA plots in one pyrome
# =============================================================================
# User, 2026-11-22: "it seems we could use the resulting map to also scale mortality rates"; SyncroSim takes an annual spatial
# multiplier on the turnover flow. The test before deciding (design doc, "A second layer"): per remeasured FIA plot in the pyrome,
# the share of live aboveground carbon killed between its two visits (non-fire; conditions with fire, cutting or logging deaths
# left out, as 04-fia-comparison.R) against the change in USFS tree canopy cover over the same years within --radius (1000 m)
# of the public plot point (coordinates are moved by up to about a mile, so the neighbourhood, not the pixel).
# Canopy is averaged over pixels that are forest in NLCD --base (2001) with canopy >= 20% then and have no fire, cutting or other
# named LCMS/MTBS cause from --base on (one fixed mask, so a plot's two years see the same pixels).
# Prints: the relation in bins, correlations, a straight-line fit of annual mortality rate on annual canopy change, and how much
# of the plot-to-plot variation it explains; separately for plots over and under the 70% line (the event takes those over it).
# Read-only. Usage: Rscript dev/mortality/06-turnover-scaling.R <FIA DataMart folder> <region folder> <pyromes shp> <out folder>
#                     --pyrome=27 --states=CA [--radius=1000] [--base=2001]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(sf); library(terra) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; dm <- pos[1]; R <- pos[2]; PY <- pos[3]; OUT <- pos[4]; dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
PYR <- as.integer(opt("pyrome", 27)); ST <- strsplit(opt("states", "CA"), ",")[[1]]; RAD <- as.numeric(opt("radius", 1000)); BASE <- as.integer(opt("base", 2001))
options(width = 250); terraOptions(progress = 0)
m <- rbindlist(lapply(ST, function(s) {
  pl <- fread(file.path(dm, sprintf("%s_PLOT.csv", s)), select = c("CN", "REMPER", "MEASYEAR", "LAT", "LON"), colClasses = list(character = "CN"))
  t <- fread(file.path(dm, sprintf("%s_TREE.csv", s)), select = c("CN", "PREV_TRE_CN", "PLT_CN", "CONDID", "STATUSCD", "PREV_STATUS_CD", "AGENTCD", "CARBON_AG", "TPA_UNADJ"), colClasses = list(character = c("CN", "PREV_TRE_CN", "PLT_CN")))
  for (k in c("STATUSCD", "PREV_STATUS_CD", "AGENTCD", "CARBON_AG", "TPA_UNADJ")) set(t, j = k, value = as.numeric(t[[k]]))
  x <- merge(t[PREV_STATUS_CD %in% 1 & STATUSCD %in% 1:3 & !is.na(PREV_TRE_CN) & nzchar(PREV_TRE_CN)], t[, .(PREV_TRE_CN = CN, c0 = CARBON_AG * TPA_UNADJ)], by = "PREV_TRE_CN")[!is.na(c0)]
  x[, ag := AGENTCD %/% 10][, d := STATUSCD == 2]
  x <- x[, .(live0 = sum(c0[STATUSCD != 3]), cut = sum(c0[STATUSCD == 3]), dead = sum(c0[d & !ag %in% 3]), fire = sum(c0[d & ag %in% 3]), logging = sum(c0[d & ag %in% 8])), by = .(PLT_CN, CONDID = as.integer(CONDID))]
  co <- fread(file.path(dm, sprintf("%s_COND.csv", s)), select = c("PLT_CN", "CONDID", "DSTRBCD1", "DSTRBCD2", "DSTRBCD3", "TRTCD1", "TRTCD2", "TRTCD3"), colClasses = list(character = "PLT_CN"))
  co <- co[, .(PLT_CN, CONDID = as.integer(CONDID), bad = DSTRBCD1 %in% 30:32 | DSTRBCD2 %in% 30:32 | DSTRBCD3 %in% 30:32 | TRTCD1 %in% c(10, 20) | TRTCD2 %in% c(10, 20) | TRTCD3 %in% c(10, 20))]
  x <- merge(x, co, by = c("PLT_CN", "CONDID"))
  merge(x, pl[, .(PLT_CN = CN, REMPER = as.numeric(REMPER), MEASYEAR, LAT, LON)], by = "PLT_CN")[!is.na(REMPER) & REMPER > 0 & !is.na(LAT)] }))
# plots whose every forest condition is clean
p <- m[, .(live0 = sum(live0), dead = sum(dead), clean = all(fire == 0 & cut == 0 & logging == 0 & !bad)), by = .(PLT_CN, LAT, LON, MEASYEAR, REMPER)][live0 > 0 & clean == TRUE]
py <- read_sf(PY); py <- py[py$PYROME == PYR, ]
p <- p[lengths(st_intersects(st_transform(st_as_sf(p, coords = c("LON", "LAT"), crs = 4269, remove = FALSE), st_crs(py)), py)) > 0]
p[, `:=`(y1 = MEASYEAR, y0 = MEASYEAR - round(REMPER), frac = dead / live0)][, rate := frac / REMPER]
f_tc <- function(k) file.path(R, "land-cover/tree-canopy", sprintf("science_tcc_conus_%d.tif", k))
p <- p[y0 >= BASE & file.exists(f_tc(y1))]
G <- rast(Sys.glob(file.path(R, "land-cover/nlcd-annual", sprintf("Annual_NLCD_LndCov_%d_*.tif", BASE)))[1]); n <- ncell(G)
rd <- function(f) { r <- rast(f); levels(r) <- NULL; coltab(r) <- NULL; stopifnot(all(dim(r) == dim(G))); values(r, mat = FALSE) }
yrs <- BASE:max(p$y1); bad <- rep(FALSE, n)
for (k in BASE:min(max(yrs) + 1, 2025)) { f <- file.path(R, "disturbance/lcms", k, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", k)); if (file.exists(f)) bad <- bad | rd(f) %in% c(1, 2, 3, 5, 6, 7, 8, 9)
  f <- file.path(R, "disturbance/mtbs", sprintf("mtbs_CONUS_%d.tif", k)); if (file.exists(f)) bad <- bad | rd(f) %in% 1:4 }
t0 <- rd(f_tc(BASE)); mask <- values(G, mat = FALSE) %in% 41:43 & t0 <= 100 & t0 >= 20 & !bad; rm(bad, t0)
v <- buffer(project(vect(as.matrix(p[, .(LON, LAT)]), crs = "EPSG:4269"), crs(G)), RAD)
r <- init(G, NA); tc <- sapply(yrs, function(k) { x <- rd(f_tc(k)); x[!mask | x > 100] <- NA; values(r) <- x; extract(r, v, fun = mean, na.rm = TRUE)[, 2] }); colnames(tc) <- yrs
values(r) <- as.numeric(mask); p[, px := extract(r, v, fun = sum, na.rm = TRUE)[, 2]]
p[, `:=`(c0 = tc[cbind(seq_len(.N), match(y0, yrs))], c1 = tc[cbind(seq_len(.N), match(y1, yrs))])][, rel := (c0 - c1) / c0][, rel_yr := rel / REMPER]
p <- p[px >= 300 & is.finite(rel)]; fwrite(p, file.path(OUT, sprintf("turnover-scaling-p%d.csv", PYR)))
cat(sprintf("Pyrome %d (%s): %d clean remeasured plots with first visit %d on and >= 300 clean forest pixels within %g m; visits %d-%d to %d-%d\n", PYR, py$NAME[1], nrow(p), BASE, RAD, min(p$y0), max(p$y0), min(p$y1), max(p$y1)))
cat(sprintf("share of carbon killed between visits: mean %.3f (annual rate %.4f); %d plots (%.1f%%) over the 70%% line\n", sum(p$dead) / sum(p$live0), sum(p$dead / p$REMPER) / sum(p$live0), sum(p$frac >= 0.7), 100 * mean(p$frac >= 0.7)))
rep1 <- function(d, label) { cat(sprintf("\n----- %s: %d plots -----\n", label, nrow(d)))
  cat(sprintf("correlation of the plot's share killed with canopy loss around it over the same years: %.2f (Spearman %.2f)\n", cor(d$frac, d$rel), cor(d$frac, d$rel, method = "spearman")))
  d[, cb := cut(rel, c(-Inf, 0, 0.05, 0.1, 0.15, 0.2, 0.3, Inf), labels = c("canopy rose", "fell 0-5%", "5-10%", "10-15%", "15-20%", "20-30%", "over 30%"))]
  print(d[, .(plots = .N, canopy_loss = round(mean(rel), 3), share_killed = round(sum(dead) / sum(live0), 3), annual_rate = round(sum(dead / REMPER) / sum(live0), 4), median_killed = round(median(frac), 3)), by = cb][order(cb)])
  f <- lm(rate ~ rel_yr, d, weights = live0); s <- summary(f)
  cat(sprintf("carbon-weighted line: annual mortality rate = %.4f + %.2f x annual canopy loss; R2 %.2f. At no canopy change the rate is %.4f; the mean rate is %.4f\n",
              coef(f)[1], coef(f)[2], s$r.squared, coef(f)[1], weighted.mean(d$rate, d$live0)))
  bm <- d[, .(rate = sum(dead / REMPER) / sum(live0), rel_yr = weighted.mean(rel_yr, live0), w = sum(live0)), by = cb]
  cat(sprintf("the same line explains %.0f%% of the variation between the canopy-loss bins\n", 100 * summary(lm(rate ~ rel_yr, bm, weights = w))$r.squared)); invisible(f) }
rep1(copy(p), "all plots"); rep1(copy(p[frac < 0.7]), "plots under the 70% line (what turnover covers once the event takes the rest)")
cat("\nby the period of the remeasurement (second visit), plots under the 70% line:\n")
print(p[frac < 0.7, .(plots = .N, canopy_loss = round(mean(rel), 3), share_killed = round(sum(dead) / sum(live0), 3), annual_rate = round(sum(dead / REMPER) / sum(live0), 4)), by = .(second_visit = cut(y1, c(0, 2013, 2016, 2019, 2030), labels = c("to 2013", "2014-2016", "2017-2019", "2020 on")))][order(second_visit)])
