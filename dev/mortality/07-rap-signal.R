# =============================================================================
# 07-rap-signal.R - to-do 3, phase 0: is RAP tree production a better signal of tree mortality than tree canopy cover?
# =============================================================================
# User, 2026-11-22: asked for an NDVI-based annual series; RAP vegetation NPP v3 (annual, 30 m, 1986 on, built from Landsat NDVI,
# band 4 = trees; already a lucasCore download) is the nearest published one. Canopy cover placed the die-off poorly in Colorado
# spruce and fir, so the same FIA test is repeated with RAP: per clean remeasured plot in the pyrome, the share of live carbon
# killed between its two visits against the change, over the same years and within --radius of the public point, in
#   (a) USFS tree canopy cover (as 06-turnover-scaling.R), (b) RAP tree NPP, (c) RAP total NPP,
# each also as an index relative to the pyrome's forest mean of that year (NPP swings with the weather everywhere at once).
# NPP at a visit is the mean of the three years centred on it. Same fixed clean-forest mask as 06.
# Read-only. Usage: Rscript dev/mortality/07-rap-signal.R <FIA DataMart folder> <region folder> <pyromes shp> <out folder> --pyrome=27 --states=CA
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
p <- m[, .(live0 = sum(live0), dead = sum(dead), clean = all(fire == 0 & cut == 0 & logging == 0 & !bad)), by = .(PLT_CN, LAT, LON, MEASYEAR, REMPER)][live0 > 0 & clean == TRUE]
py <- read_sf(PY); py <- py[py$PYROME == PYR, ]
p <- p[lengths(st_intersects(st_transform(st_as_sf(p, coords = c("LON", "LAT"), crs = 4269, remove = FALSE), st_crs(py)), py)) > 0]
p[, `:=`(y1 = MEASYEAR, y0 = MEASYEAR - round(REMPER), frac = dead / live0)]
f_tc <- function(k) file.path(R, "land-cover/tree-canopy", sprintf("science_tcc_conus_%d.tif", k)); f_rp <- function(k) file.path(R, "land-cover/rap-npp", sprintf("rap-npp-v3-%d.tif", k))
p <- p[y0 >= BASE & file.exists(f_tc(y1)) & file.exists(f_rp(y1 + 1))]
G <- rast(Sys.glob(file.path(R, "land-cover/nlcd-annual", sprintf("Annual_NLCD_LndCov_%d_*.tif", BASE)))[1]); n <- ncell(G)
rd <- function(f) { r <- rast(f); levels(r) <- NULL; coltab(r) <- NULL; stopifnot(all(dim(r) == dim(G))); values(r, mat = FALSE) }
yrs <- (BASE - 1):(max(p$y1) + 1); bad <- rep(FALSE, n)
for (k in BASE:min(max(yrs), 2025)) { f <- file.path(R, "disturbance/lcms", k, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", k)); if (file.exists(f)) bad <- bad | rd(f) %in% c(1, 2, 3, 5, 6, 7, 8, 9)
  f <- file.path(R, "disturbance/mtbs", sprintf("mtbs_CONUS_%d.tif", k)); if (file.exists(f)) bad <- bad | rd(f) %in% 1:4 }
t0 <- rd(f_tc(BASE)); mask <- values(G, mat = FALSE) %in% 41:43 & t0 <= 100 & t0 >= 20 & !bad; rm(bad, t0)
v <- buffer(project(vect(as.matrix(p[, .(LON, LAT)]), crs = "EPSG:4269"), crs(G)), RAD)
r <- init(G, NA); tc <- sapply(yrs, function(k) { if (!file.exists(f_tc(k))) return(rep(NA_real_, nrow(p))); x <- rd(f_tc(k)); x[!mask | x > 100] <- NA; values(r) <- x; extract(r, v, fun = mean, na.rm = TRUE)[, 2] }); colnames(tc) <- yrs
values(r) <- as.numeric(mask); p[, px := extract(r, v, fun = sum, na.rm = TRUE)[, 2]]
# RAP on its own lon/lat grid: the clean-forest mask carried to it, the buffers likewise
R0 <- rast(f_rp(yrs[1])); mk <- project(r, R0[[1]], method = "near"); mk <- ifel(mk == 1, 1, NA); vg <- project(v, crs(R0))
rap <- lapply(yrs, function(k) { x <- rast(f_rp(k)); tre <- mask(x[[4]], mk); tot <- mask(sum(x), mk)
  list(tre = extract(tre, vg, fun = mean, na.rm = TRUE)[, 2], tot = extract(tot, vg, fun = mean, na.rm = TRUE)[, 2], mtre = global(tre, "mean", na.rm = TRUE)[1, 1], mtot = global(tot, "mean", na.rm = TRUE)[1, 1]) })
tre <- sapply(rap, `[[`, "tre"); tot <- sapply(rap, `[[`, "tot"); mtre <- sapply(rap, `[[`, "mtre"); mtot <- sapply(rap, `[[`, "mtot"); mtc <- colMeans(tc, na.rm = TRUE)
cat("pyrome clean-forest means by year (canopy %, RAP tree NPP, RAP total NPP):\n"); print(data.table(year = yrs, canopy = round(mtc, 1), tree_npp = round(mtre), total_npp = round(mtot)))
at <- function(m, y, w) { i <- match(y, yrs); if (w == 0) m[cbind(seq_along(i), i)] else (m[cbind(seq_along(i), i - 1)] + m[cbind(seq_along(i), i)] + m[cbind(seq_along(i), i + 1)]) / 3 }
chg <- function(m, w, norm = NULL) { if (!is.null(norm)) m <- sweep(m, 2, norm, `/`); a <- at(m, p$y0, w); b <- at(m, p$y1, w); (a - b) / a }
p[, `:=`(canopy = chg(tc, 0), canopy_idx = chg(tc, 0, mtc), tree_npp = chg(tre, 1), tree_npp_idx = chg(tre, 1, mtre), total_npp = chg(tot, 1), total_npp_idx = chg(tot, 1, mtot))]
p <- p[px >= 300 & is.finite(canopy) & is.finite(tree_npp) & is.finite(total_npp)]; fwrite(p, file.path(OUT, sprintf("rap-signal-p%d.csv", PYR)))
cat(sprintf("\nPyrome %d (%s): %d clean remeasured plots; mean share of carbon killed %.3f; %d plots (%.1f%%) over the 70%% line\n", PYR, py$NAME[1], nrow(p), sum(p$dead) / sum(p$live0), sum(p$frac >= 0.7), 100 * mean(p$frac >= 0.7)))
sig <- c("canopy", "canopy_idx", "tree_npp", "tree_npp_idx", "total_npp", "total_npp_idx")
cat("\ncorrelation of each signal's loss around the plot with the plot's share of carbon killed (Pearson, Spearman), all plots and plots under 70%:\n")
print(rbindlist(lapply(sig, function(k) data.table(signal = k, pearson = round(cor(p[[k]], p$frac), 2), spearman = round(cor(p[[k]], p$frac, method = "spearman"), 2),
  pearson_under70 = round(cor(p[frac < 0.7][[k]], p[frac < 0.7]$frac), 2), spearman_under70 = round(cor(p[frac < 0.7][[k]], p[frac < 0.7]$frac, method = "spearman"), 2)))))
cat("\nmean loss in each signal around plots, by the plot's share killed:\n")
print(p[, c(list(plots = .N), lapply(.SD, function(x) round(mean(x), 3))), by = .(killed = cut(frac, c(-0.001, 0.1, 0.3, 0.5, 0.7, 1))), .SDcols = sig][order(killed)])
cat("\nas a test for a plot over the 70% line: of the tenth of plots with the largest loss in each signal, the share truly over 70% (and the share of all such plots found)\n")
print(rbindlist(lapply(sig, function(k) { top <- p[[k]] >= quantile(p[[k]], 0.9); data.table(signal = k, over70_in_top_tenth_pct = round(100 * mean(p$frac[top] >= 0.7), 1), found_pct = round(100 * sum(top & p$frac >= 0.7) / sum(p$frac >= 0.7), 1), base_rate_pct = round(100 * mean(p$frac >= 0.7), 1)) })))
