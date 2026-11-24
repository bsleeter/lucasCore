# =============================================================================
# 10-reference-combined.R - to-do 3, phase 0: the combined rule against the mapped dead trees (Stovall 2019, Koontz 2021)
# =============================================================================
# User, 2026-11-23: the combined rule (08-rule-combined.R) is the event rule; it had only been checked at 1 km around FIA plots.
# This scores the same 30 m pixels 02-reference-sites.R used (share of trees killed per pixel, weighted by height squared or
# basal area) with the rule in its final form, canopy-only and combined, and asks which ranks the killed pixels better:
#   score(y) as in 08 (canopy loss against y-span; RAP tree production loss, three-year means over the region's forest mean,
#   read from the cache 08 left in <rap-tree folder>); a pixel's score is its highest over --years (2012-2018), which is what
#   "first crossing" tests. Clean = no fire, cutting or other named cause from the first baseline year to the last year + 1.
# Printed per reference set: correlation with the share killed; the area under the curve for pixels >= 70% killed; precision
# and recall at the FIA-matched lines and at the line that flags the same area as is truly >= 70% killed; and the same at
# 990 m blocks (flagged share against the true share), since single pixels were known to be poor.
# Read-only. Usage: Rscript dev/mortality/10-reference-combined.R <region folder> <rap-tree folder> <stovall csv> <koontz csv> <out folder>
#   [--years=2012-2018] [--span=5] [--weight=0.35] [--line-canopy=0.45] [--line-combined=0.28] [--min-trees=4]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; R <- pos[1]; RT <- pos[2]; OUT <- pos[5]; MIN_N <- as.integer(opt("min-trees", 4)); terraOptions(progress = 0); options(width = 250)
yr <- as.integer(strsplit(opt("years", "2012-2018"), "-")[[1]]); YRS <- yr[1]:yr[2]; SPAN <- as.integer(opt("span", 5)); WT <- as.numeric(opt("weight", 0.35))
LC <- as.numeric(opt("line-canopy", 0.45)); LB <- as.numeric(opt("line-combined", 0.28))
G <- rast(Sys.glob(file.path(R, "land-cover/nlcd-annual", sprintf("Annual_NLCD_LndCov_%d_*.tif", min(YRS) - SPAN)))[1]); levels(G) <- NULL; coltab(G) <- NULL
ALL <- (min(YRS) - SPAN):(max(YRS) + 1); NY <- (min(YRS) - SPAN - 1):(max(YRS) + 1)
M <- fread(file.path(RT, "forest-means.csv")); M <- M$mean[match(NY, M$year)]; M3 <- (M + c(NA, head(M, -1)) + c(M[-1], NA)) / 3; names(M3) <- NY

# the rule's two scores for the pixels (cells of G) given
score <- function(cells) {
  xy <- xyFromCell(G, cells); ex <- function(f) { r <- rast(f); levels(r) <- NULL; coltab(r) <- NULL; extract(r, xy)[, 1] }
  tc <- vapply(ALL, function(k) { v <- ex(file.path(R, "land-cover/tree-canopy", sprintf("science_tcc_conus_%d.tif", k))); v[v > 100] <- NA; as.numeric(v) }, numeric(length(cells)))
  bad <- vapply(ALL, function(k) { b <- ex(file.path(R, "disturbance/lcms", k, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", k))) %in% c(1, 2, 3, 5, 6, 7, 8, 9)
    f <- file.path(R, "disturbance/mtbs", sprintf("mtbs_CONUS_%d.tif", k)); if (file.exists(f)) b <- b | ex(f) %in% 1:4; b }, logical(length(cells)))
  np <- vapply(NY, function(k) as.numeric(ex(file.path(RT, sprintf("rap-tree-%d.tif", k)))), numeric(length(cells)))
  n3 <- function(k) { j <- match(k, NY); (np[, j - 1] + np[, j] + np[, j + 1]) / 3 / M3[as.character(k)] }
  sc <- sb <- sn <- matrix(NA_real_, length(cells), length(YRS))
  for (i in seq_along(YRS)) { y <- YRS[i]; t0 <- tc[, match(y - SPAN, ALL)]; t1 <- tc[, match(y, ALL)]; cl <- ifelse(!is.na(t0) & t0 >= 20, (t0 - t1) / t0, NA)
    a0 <- n3(y - SPAN); a1 <- n3(y); nl <- ifelse(is.na(a0) | is.na(a1) | a0 < 0.05, 0, pmax(-1, pmin(1, 1 - a1 / a0)))
    sc[, i] <- cl; sn[, i] <- nl; sb[, i] <- (cl + WT * nl) / 2 }
  mx <- function(m) { v <- suppressWarnings(apply(m, 1, max, na.rm = TRUE)); v[!is.finite(v)] <- NA; v }
  data.table(nlcd = ex(sources(G)), t0 = tc[, 1], clean = rowSums(bad) == 0, s_canopy = mx(sc), s_rap = mx(sn), s_comb = mx(sb)) }

auc <- function(s, pos) { r <- rank(s); n1 <- as.numeric(sum(pos)); n0 <- as.numeric(sum(!pos)); (sum(r[pos]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
at <- function(s, k, line, name) { f <- s >= line
  data.table(rule = name, line = round(line, 3), flagged_pct = round(100 * mean(f), 1), precision70 = round(100 * mean(k[f] >= 0.7), 1), recall70 = round(100 * sum(f & k >= 0.7) / sum(k >= 0.7), 1),
             precision50 = round(100 * mean(k[f] >= 0.5), 1), mean_kill_flagged = round(mean(k[f]), 2), mean_kill_rest = round(mean(k[!f]), 2)) }
report <- function(d, label) {
  n0 <- nrow(d); d <- d[nlcd %in% 41:43 & !is.na(t0) & t0 >= 20 & clean & !is.na(s_canopy) & !is.na(s_comb)]; p70 <- mean(d$kill_w >= 0.7)
  cat(sprintf("\n===== %s =====\n%d pixels with >= %d trees; %d forest, canopy >= 20 in %d and clean %d-%d; %.1f%% have >= 70%% of trees killed (weighted), mean killed %.2f\n",
              label, n0, MIN_N, nrow(d), min(ALL), min(ALL), max(ALL), 100 * p70, mean(d$kill_w)))
  cat("\nper 30 m pixel: how well each score ranks the share killed\n")
  print(rbindlist(lapply(c(canopy = "s_canopy", rap = "s_rap", combined = "s_comb"), function(v) data.table(pearson = round(cor(d[[v]], d$kill_w), 2), spearman = round(cor(d[[v]], d$kill_w, method = "spearman"), 2),
    auc70 = round(auc(d[[v]], d$kill_w >= 0.7), 3), auc50 = round(auc(d[[v]], d$kill_w >= 0.5), 3))), idcol = "score"))
  cat("\nat the FIA-matched lines, and at the line that flags as much area as is truly >= 70% killed:\n")
  print(rbind(at(d$s_canopy, d$kill_w, LC, "canopy, FIA line"), at(d$s_comb, d$kill_w, LB, "combined, FIA line"),
              at(d$s_canopy, d$kill_w, quantile(d$s_canopy, 1 - p70), "canopy, area-matched"), at(d$s_comb, d$kill_w, quantile(d$s_comb, 1 - p70), "combined, area-matched")))
  cat("\nmean score by share of trees killed:\n")
  print(d[, .(pixels = .N, canopy = round(mean(s_canopy), 3), rap = round(mean(s_rap), 3), combined = round(mean(s_comb), 3),
              flagged_canopy_pct = round(100 * mean(s_canopy >= LC), 1), flagged_combined_pct = round(100 * mean(s_comb >= LB), 1)),
          by = .(killed = cut(kill_w, c(-0.001, 0.1, 0.3, 0.5, 0.7, 0.9, 1)))][order(killed)])
  qc <- quantile(d$s_canopy, 1 - p70); qb <- quantile(d$s_comb, 1 - p70)
  b <- d[, .(n = .N, true70 = mean(kill_w >= 0.7), kill = mean(kill_w), fc = mean(s_canopy >= qc), fb = mean(s_comb >= qb), fcF = mean(s_canopy >= LC), fbF = mean(s_comb >= LB),
             mc = mean(s_canopy), mb = mean(s_comb)), by = .(br = rowFromCell(G, cell) %/% 33, bc = colFromCell(G, cell) %/% 33)][n >= 100]
  cat(sprintf("\n990 m blocks with >= 100 pixels: %d. Correlation of the flagged share with the share truly >= 70%% killed:\n", nrow(b)))
  print(data.table(rule = c("canopy", "combined"), area_matched_line = round(c(cor(b$fc, b$true70), cor(b$fb, b$true70)), 2), fia_line = round(c(cor(b$fcF, b$true70), cor(b$fbF, b$true70)), 2),
                   mean_score_vs_mean_killed = round(c(cor(b$mc, b$kill), cor(b$mb, b$kill)), 2)))
  invisible(d) }

# ---- Stovall et al. 2019 -----------------------------------------------------------------------------------------------
s <- fread(pos[3], select = c("x", "y", "zmax", "mort_year")); s <- s[mort_year %in% c("Live", "2014", "2016")]
s[, cell := cellFromXY(G, crds(project(vect(as.matrix(s[, .(x, y)]), crs = "EPSG:32611"), crs(G))))][, killed := mort_year != "Live"][, w := zmax^2]
ps <- s[!is.na(cell), .(n = .N, kill_w = sum(w * killed) / sum(w)), by = cell][n >= MIN_N]; ps <- cbind(ps, score(ps$cell))
fwrite(ps, file.path(OUT, "stovall-pixels-combined.csv")); report(ps, "Stovall et al. 2019: NEON Soaproot Saddle and Teakettle (killed = alive in the 2012 photo, dead by 2016)")

# ---- Koontz et al. 2021 ------------------------------------------------------------------------------------------------
k <- fread(pos[4]); kp <- project(vect(as.matrix(k[, .(x, y)]), crs = if (is.numeric(k$crs)) sprintf("EPSG:%d", k$crs[1]) else as.character(k$crs[1])), crs(G))
k[, cell := cellFromXY(G, crds(kp))]; nz <- function(v) fifelse(is.na(v), 0, as.numeric(v))
pk <- k[!is.na(cell), .(n = sum(nz(total_count)), kill_w = sum(nz(dead_ba)) / sum(nz(total_ba)), forest = forest[1]), by = cell][n >= MIN_N & is.finite(kill_w)]; pk <- cbind(pk, score(pk$cell))
fwrite(pk, file.path(OUT, "koontz-pixels-combined.csv")); dk <- report(pk, "Koontz et al. 2021: drone sites (killed = dead in 2018, cumulative)")
cat("\nKoontz by national forest (Spearman with the share killed):\n")
print(dk[, .(pixels = .N, killed = round(mean(kill_w), 2), canopy = round(cor(s_canopy, kill_w, method = "spearman"), 2), rap = round(cor(s_rap, kill_w, method = "spearman"), 2), combined = round(cor(s_comb, kill_w, method = "spearman"), 2)), by = forest])
