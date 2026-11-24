# =============================================================================
# 11-salo-comparison.R - to-do 3, phase 0: the event rule against the Salo / Pyregence tree mortality maps (California)
# =============================================================================
# User, 2026-11-23: "I have placed some mapping in the lucasData/disturbance/salo folder. These may be good for comparison".
# Pyregence_TreeMortMaps.zip: <year>-mortality-30m.tif for 2016, 2017, 2018 (and 10 m versions), California, UTM 10N, Float32,
# 0 or a value from 0.1 to 1 per pixel (read here as the share of the pixel mapped as dead trees that year; no metadata in the
# zip says so, and whether 2016 holds all standing dead or only that year's is not stated).
# Three comparisons, all in one region (the southern Sierra pyrome):
#   A  how much forest Salo maps, by year and for 2016-2018 together, against what the rule flags
#   B  placement at 300 m and 900 m: the rule's flagged share (rule-<tag>-300m.tif from 08-rule-combined.R --write) against
#      Salo's mean share, canopy-only and combined
#   C  Salo itself against the mapped dead trees (the pixel tables 10-reference-combined.R wrote), beside the rule's scores
# Writes <out>/salo-<year>-30m.tif (Salo on the region's 30 m grid) and salo-300m.tif. Read-only on the data home.
# Usage: Rscript dev/mortality/11-salo-comparison.R <region folder> <salo folder> <out folder (holds rap-tree, rule-*-300m.tif, *-pixels-combined.csv)>
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
a <- commandArgs(TRUE); R <- a[1]; S <- a[2]; OUT <- a[3]; terraOptions(progress = 0); options(width = 250); YS <- 2016:2018
G <- rast(Sys.glob(file.path(R, "land-cover/nlcd-annual", "Annual_NLCD_LndCov_2007_*.tif"))[1]); levels(G) <- NULL; coltab(G) <- NULL
fm <- rast(file.path(OUT, "rap-tree", "forest-mask.tif")); crs(fm) <- crs(G)
fs <- function(y) file.path(OUT, sprintf("salo-%d-30m.tif", y))
for (y in YS) if (!file.exists(fs(y))) { r <- rast(file.path(S, sprintf("%d-mortality-30m.tif", y)))
  r <- crop(r, project(as.polygons(ext(G), crs = crs(G)), crs(r)), snap = "out"); project(r, G, method = "bilinear", filename = fs(y), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE) }
sa <- rast(fs(YS)); names(sa) <- YS; crs(sa) <- crs(G)
tot <- file.path(OUT, "salo-sum-30m.tif"); if (!file.exists(tot)) writeRaster(mask(min(sum(sa), 1), fm), tot, datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE)
T <- rast(tot)

cat("===== A. Area: Salo over the pyrome's forest (forest in NLCD with canopy >= 20 at the start of the rule's record) =====\n")
nf <- global(fm, "sum", na.rm = TRUE)[1, 1]; cat(sprintf("forest %.0f km2; Salo covers %.1f%% of it (not NA)\n", nf * 9e-4, 100 * global(!is.na(T), "sum")[1, 1] / nf))
sy <- mask(sa, fm)
print(data.table(year = c(YS, "2016-2018 summed"), mean_share_pct = round(100 * c(global(sy, "mean", na.rm = TRUE)[, 1], global(T, "mean", na.rm = TRUE)[1, 1]), 2),
                 dead_area_km2 = round(9e-4 * c(global(sy, "sum", na.rm = TRUE)[, 1], global(T, "sum", na.rm = TRUE)[1, 1]), 0),
                 pixels_any_pct = round(100 * c(global(sy > 0, "sum", na.rm = TRUE)[, 1], global(T > 0, "sum", na.rm = TRUE)[1, 1]) / nf, 2)))
cat("\nshare of forest pixels at or over a Salo share (2016-2018 summed):\n")
print(data.table(salo_share = c(0.1, 0.2, 0.3, 0.5, 0.7), forest_pct = round(100 * vapply(c(0.1, 0.2, 0.3, 0.5, 0.7), function(t) global(T >= t, "sum", na.rm = TRUE)[1, 1], 0) / nf, 2)))

cat("\n===== B. Placement: the rule's flagged share against Salo's mean share =====\n")
rules <- c(canopy = "rule-canopy-300m.tif", combined = "rule-combined-300m.tif", conifer = "rule-combined-conifer-300m.tif", canopy_conifer = "rule-canopy-conifer-300m.tif", canopy_in_lcms = "rule-canopy-lcms-300m.tif"); rules <- rules[file.exists(file.path(OUT, rules))]
t300 <- rast(file.path(OUT, rules[2]))[[1]]
s300f <- file.path(OUT, "salo-300m.tif")
if (!file.exists(s300f)) { z <- crop(c(T, sa), ext(t300)); z <- mask(z, crop(fm, ext(t300))); writeRaster(aggregate(z, 10, mean, na.rm = TRUE), s300f, overwrite = TRUE) }
s300 <- rast(s300f); names(s300) <- c("sum", YS)
for (tag in names(rules)) { r <- rast(file.path(OUT, rules[tag])); yy <- as.integer(names(r)[-1]); f <- r[[1]]
  d <- data.table(forest = values(f)[, 1], early = values(sum(r[[1 + which(yy %in% 2012:2015)]]))[, 1], late = values(sum(r[[1 + which(yy %in% 2016:2018)]]))[, 1],
                  salo = values(s300[["sum"]])[, 1], row = rowFromCell(f, 1:ncell(f)), col = colFromCell(f, 1:ncell(f)))[forest >= 50 & !is.na(salo)]
  d[, all := early + late]
  cat(sprintf("\n--- %s rule, %d cells of 300 m with >= 50 forest pixels. Flagged by the rule: 2012-2015 %.2f%%, 2016-2018 %.2f%% of forest; Salo mean share %.2f%%\n",
              tag, nrow(d), 100 * sum(d$early) / sum(d$forest), 100 * sum(d$late) / sum(d$forest), 100 * weighted.mean(d$salo, d$forest)))
  cc <- function(x, y) sprintf("%.2f (Spearman %.2f)", cor(x, y), cor(x, y, method = "spearman"))
  cat(sprintf("300 m: rule 2012-2018 against Salo %s; rule 2016-2018 against Salo %s\n", cc(d$all / d$forest, d$salo), cc(d$late / d$forest, d$salo)))
  b <- d[, .(forest = sum(forest), all = sum(all), late = sum(late), salo = weighted.mean(salo, forest)), by = .(r = (row - 1) %/% 3, c = (col - 1) %/% 3)][forest >= 450]
  cat(sprintf("900 m (%d cells): rule 2012-2018 against Salo %s; rule 2016-2018 against Salo %s\n", nrow(b), cc(b$all / b$forest, b$salo), cc(b$late / b$forest, b$salo)))
  print(d[, .(cells = .N, forest_km2 = round(sum(forest) * 9e-4), rule_2012_2018_pct = round(100 * sum(all) / sum(forest), 2), rule_2016_2018_pct = round(100 * sum(late) / sum(forest), 2)),
          by = .(salo_share = cut(salo, c(-0.001, 0, 0.02, 0.05, 0.1, 0.2, 1), labels = c("0", "0-2%", "2-5%", "5-10%", "10-20%", "over 20%")))][order(salo_share)])
  tr <- d$all / d$forest; top <- tr >= quantile(tr, 0.9); ts <- d$salo >= quantile(d$salo, 0.9)
  cat(sprintf("the tenth of cells the rule flags most hold %.0f%% of Salo's dead area; %.0f%% of them are also in Salo's top tenth\n", 100 * sum(d$salo[top] * d$forest[top]) / sum(d$salo * d$forest), 100 * mean(ts[top]))) }

cat("\n===== C. Salo against the mapped dead trees, beside the rule's scores (per 30 m pixel) =====\n")
auc <- function(s, pos) { r <- rank(s); n1 <- as.numeric(sum(pos)); n0 <- as.numeric(sum(!pos)); (sum(r[pos]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
for (nm in c("stovall", "koontz")) { p <- fread(file.path(OUT, sprintf("%s-pixels-combined.csv", nm)))
  p <- p[nlcd %in% 41:43 & !is.na(t0) & t0 >= 20 & clean & !is.na(s_canopy) & !is.na(s_comb)]; xy <- xyFromCell(G, p$cell)
  p[, salo := extract(min(sum(sa), 1), xy)[, 1]][, salo16 := extract(sa[[1]], xy)[, 1]]; p <- p[!is.na(salo)]
  cat(sprintf("\n--- %s: %d pixels; mean share of trees killed %.2f; Salo mean share 2016-2018 summed %.3f (2016 alone %.3f); Salo is zero on %.0f%% of pixels, and on %.0f%% of those >= 70%% killed\n",
              nm, nrow(p), mean(p$kill_w), mean(p$salo), mean(p$salo16), 100 * mean(p$salo == 0), 100 * mean(p$salo[p$kill_w >= 0.7] == 0)))
  print(rbindlist(lapply(c(salo = "salo", canopy = "s_canopy", combined = "s_comb"), function(v) data.table(pearson = round(cor(p[[v]], p$kill_w), 2), spearman = round(cor(p[[v]], p$kill_w, method = "spearman"), 2),
    auc70 = round(auc(p[[v]], p$kill_w >= 0.7), 3))), idcol = "score"))
  print(p[, .(pixels = .N, salo_mean = round(mean(salo), 3), salo_any_pct = round(100 * mean(salo > 0), 1), combined = round(mean(s_comb), 3)), by = .(killed = cut(kill_w, c(-0.001, 0.1, 0.3, 0.5, 0.7, 0.9, 1)))][order(killed)])
  b <- p[, .(n = .N, kill = mean(kill_w), true70 = mean(kill_w >= 0.7), salo = mean(salo), comb = mean(s_comb), can = mean(s_canopy)), by = .(br = rowFromCell(G, cell) %/% 33, bc = colFromCell(G, cell) %/% 33)][n >= 100]
  cat(sprintf("990 m blocks (%d): correlation with the mean share killed: Salo %.2f, canopy %.2f, combined %.2f; with the share of pixels >= 70%% killed: Salo %.2f, canopy %.2f, combined %.2f\n",
              nrow(b), cor(b$salo, b$kill), cor(b$can, b$kill), cor(b$comb, b$kill), cor(b$salo, b$true70), cor(b$can, b$true70), cor(b$comb, b$true70))) }
