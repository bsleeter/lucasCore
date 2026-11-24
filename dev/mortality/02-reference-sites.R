# =============================================================================
# 02-reference-sites.R - to-do 3, phase 0: canopy cover loss against sites of known tree mortality (southern Sierra Nevada)
# =============================================================================
# Which fall in USFS tree canopy cover marks a 30 m pixel where most of the trees died? Two reference sets (user, 2026-11-22:
# "reference sites of known mortality to calibrate the approach"):
#   Stovall et al. 2019 (figshare 10.6084/m9.figshare.7609193, ALLtrees_v2.csv): 1.8 million lidar tree crowns at NEON SOAP and
#     TEAK, x/y in UTM 11N, zmax = height, mort_year = the first aerial photo year (2009, 2010, 2012, 2014, 2016) a crown is
#     dead, or Live. Killed in the die-off = alive in the 2012 photo and dead by 2016. Calibration set.
#   Koontz et al. 2021 (OSF 10.17605/OSF.IO/3CWF9, data-from-rasterized-classified-trees.csv): 20 m cells of drone-classified
#     trees at 32 sites, flown 2018 (dead = cumulative), basal area by status. Independent test; sites chosen in beetle-hit stands.
# Per 30 m pixel of the NLCD grid: the share of trees killed (by count, and weighted by height squared or basal area as a stand-in
# for carbon), the canopy cover before (2011) and after (the lowest of 2016-2018), LCMS classes 2012-2018, fire and cutting.
# Read-only. Usage: Rscript dev/mortality/02-reference-sites.R <region folder> <stovall csv> <koontz csv> <out folder> [--min-trees=4]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; R <- pos[1]; OUT <- pos[4]; dir.create(OUT, recursive = TRUE, showWarnings = FALSE); MIN_N <- as.integer(opt("min-trees", 4))
terraOptions(progress = 0); options(width = 250)
nl <- function(k) rast(Sys.glob(file.path(R, "land-cover/nlcd-annual", sprintf("Annual_NLCD_LndCov_%d_*.tif", k)))[1])
G <- nl(2011)

# pixel values of the region's layers on a window of the NLCD grid
layers <- function(win, post_years) {
  g <- crop(G, win, snap = "out")
  on <- function(r) { levels(r) <- NULL; coltab(r) <- NULL; r <- crop(r, project(as.polygons(ext(g), crs = crs(g)), crs(r)), snap = "out")
    if (!compareGeom(r, g, stopOnError = FALSE)) r <- project(r, g, method = "near"); values(r, mat = FALSE) }
  tc <- function(k) { v <- on(rast(file.path(R, "land-cover/tree-canopy", sprintf("science_tcc_conus_%d.tif", k)))); v[v > 100] <- NA; v }
  lc <- function(k) on(rast(file.path(R, "disturbance/lcms", k, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", k))))
  mt <- function(k) { f <- file.path(R, "disturbance/mtbs", sprintf("mtbs_CONUS_%d.tif", k)); if (!file.exists(f)) return(rep(FALSE, ncell(g)))
    v <- tryCatch(on(rast(f)), error = function(e) NULL); if (is.null(v)) rep(FALSE, ncell(g)) else v %in% 1:4 }
  yrs <- 2010:max(post_years); xs <- lapply(yrs, lc)
  tcs <- lapply(2011:max(post_years), tc); names(tcs) <- 2011:max(post_years)
  list(g = g, nlcd = values(g, mat = FALSE), t0 = tcs[["2011"]], tpost = do.call(pmin, tcs[as.character(post_years)]), tcs = tcs,
       other = Reduce(`|`, lapply(xs, function(v) v %in% c(1, 2, 3, 5, 6, 7, 8, 9))), stress = Reduce(`|`, lapply(xs[yrs >= 2012], function(v) v %in% c(4, 11, 12))),
       burn = Reduce(`|`, lapply(yrs, mt))) }

report <- function(d, label) {
  d[, rel := (t0 - tpost) / t0]
  cat(sprintf("\n===== %s =====\n%d pixels with >= %d trees alive before the die-off, forest in NLCD 2011, canopy 2011 >= 20%%; %d clean (no fire, cutting or other named cause 2010 on)\n",
              label, nrow(d), MIN_N, sum(d$clean)))
  d <- d[clean == TRUE]
  cat(sprintf("share of trees killed: mean %.2f by count, %.2f weighted; pixels with >= 50%% killed (weighted) %.1f%%, >= 70%% killed %.1f%%\n",
              mean(d$kill_n), mean(d$kill_w), 100 * mean(d$kill_w >= 0.5), 100 * mean(d$kill_w >= 0.7)))
  cat(sprintf("canopy cover: 2011 mean %.1f, lowest after mean %.1f; relative loss mean %.3f; correlation with share killed (weighted) %.2f (Spearman %.2f)\n",
              mean(d$t0), mean(d$tpost), mean(d$rel), cor(d$rel, d$kill_w), cor(d$rel, d$kill_w, method = "spearman")))
  cat("\ncanopy loss by share of trees killed (weighted):\n")
  d[, kb := cut(kill_w, c(-0.001, 0.1, 0.3, 0.5, 0.7, 0.9, 1), labels = c("0-10%", "10-30%", "30-50%", "50-70%", "70-90%", "90-100%"))]
  print(d[, .(pixels = .N, canopy_2011 = round(mean(t0), 1), canopy_after = round(mean(tpost), 1), rel_loss_mean = round(mean(rel), 3), rel_loss_median = round(median(rel), 3),
              rel_loss_q10 = round(quantile(rel, 0.1), 3), rel_loss_q90 = round(quantile(rel, 0.9), 3), lcms_stress_pct = round(100 * mean(stress), 1)), by = kb][order(kb)])
  cat("\na canopy-loss threshold as a test for a pixel with >= 70% (and >= 50%) of its trees killed (weighted):\n")
  th <- rbindlist(lapply(c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7), function(t) { f <- d$rel >= t
    data.table(canopy_loss = t, flagged_pct = round(100 * mean(f), 2),
               precision70 = round(100 * mean(d$kill_w[f] >= 0.7), 1), recall70 = round(100 * sum(f & d$kill_w >= 0.7) / sum(d$kill_w >= 0.7), 1),
               precision50 = round(100 * mean(d$kill_w[f] >= 0.5), 1), recall50 = round(100 * sum(f & d$kill_w >= 0.5) / sum(d$kill_w >= 0.5), 1),
               mean_kill_flagged = round(mean(d$kill_w[f]), 2)) }))
  print(th)
  cat(sprintf("\nLCMS drought or insect class (12, 4, 11) in any year 2012 on: %.1f%% of all clean pixels; %.1f%% of those with >= 70%% killed; %.1f%% of those with < 10%% killed\n",
              100 * mean(d$stress), 100 * mean(d$stress[d$kill_w >= 0.7]), 100 * mean(d$stress[d$kill_w < 0.1])))
  invisible(d) }

# ---- Stovall et al. 2019 -----------------------------------------------------------------------------------------------
s <- fread(pos[2], select = c("x", "y", "zmax", "mort_year"))
s <- s[mort_year %in% c("Live", "2014", "2016")]   # alive in the 2012 photo
pt <- project(vect(as.matrix(s[, .(x, y)]), crs = "EPSG:32611"), crs(G))
L <- layers(ext(pt) + 300, 2016:2018)
s[, cell := cellFromXY(L$g, crds(pt))][, killed := mort_year != "Live"][, w := zmax^2]
ps <- s[!is.na(cell), .(n = .N, kill_n = mean(killed), kill_w = sum(w * killed) / sum(w), height = mean(zmax)), by = cell][n >= MIN_N]
ps[, `:=`(t0 = L$t0[cell], tpost = L$tpost[cell], nlcd = L$nlcd[cell], stress = L$stress[cell], clean = !(L$other[cell] | L$burn[cell]))]
for (k in names(L$tcs)) set(ps, j = paste0("tcc_", k), value = L$tcs[[k]][ps$cell])
ps <- ps[nlcd %in% 41:43 & !is.na(t0) & t0 >= 20 & !is.na(tpost)]
fwrite(ps, file.path(OUT, "stovall-pixels.csv"))
ds <- report(ps, "Stovall et al. 2019: NEON Soaproot Saddle and Teakettle (killed = alive in the 2012 photo, dead by 2016; weight = height squared; canopy after = lowest of 2016-2018)")
cat("\ncanopy cover by year (mean) for pixels by share killed:\n")
print(ds[, c(list(pixels = .N), lapply(.SD, function(v) round(mean(v, na.rm = TRUE), 1))), by = kb, .SDcols = patterns("^tcc_")][order(kb)])

# ---- Koontz et al. 2021 ------------------------------------------------------------------------------------------------
k <- fread(pos[3]); cat(sprintf("\nKoontz: %d cells, crs values: %s\n", nrow(k), paste(unique(k$crs), collapse = "; ")))
kp <- project(vect(as.matrix(k[, .(x, y)]), crs = if (is.numeric(k$crs)) sprintf("EPSG:%d", k$crs[1]) else as.character(k$crs[1])), crs(G))
inside <- relate(kp, as.polygons(ext(G), crs = crs(G)), "intersects")[, 1]
cat(sprintf("%d cells of %d sites lie inside the region's rasters (of %d sites)\n", sum(inside), uniqueN(k$site[inside]), uniqueN(k$site)))
if (sum(inside) > 100) {
  k <- k[inside]; kp <- kp[inside]; L2 <- layers(ext(kp) + 300, 2017:2018)
  k[, cell := cellFromXY(L2$g, crds(kp))]
  nz <- function(v) fifelse(is.na(v), 0, as.numeric(v))
  pk <- k[!is.na(cell), .(n = sum(nz(total_count)), kill_n = sum(nz(dead_count)) / sum(nz(total_count)), kill_w = sum(nz(dead_ba)) / sum(nz(total_ba)), site = site[1], forest = forest[1]), by = cell][n >= MIN_N & is.finite(kill_w)]
  pk[, `:=`(t0 = L2$t0[cell], tpost = L2$tpost[cell], nlcd = L2$nlcd[cell], stress = L2$stress[cell], clean = !(L2$other[cell] | L2$burn[cell]))]
  pk <- pk[nlcd %in% 41:43 & !is.na(t0) & t0 >= 20 & !is.na(tpost)]
  fwrite(pk, file.path(OUT, "koontz-pixels.csv"))
  dk <- report(pk, "Koontz et al. 2021: drone sites (killed = dead in 2018, cumulative; weight = basal area; canopy after = lowest of 2017-2018)")
  cat("\nby national forest:\n"); print(dk[, .(pixels = .N, sites = uniqueN(site), kill_w = round(mean(kill_w), 2), rel_loss = round(mean(rel), 3), cor = round(cor(rel, kill_w), 2)), by = forest]) }
