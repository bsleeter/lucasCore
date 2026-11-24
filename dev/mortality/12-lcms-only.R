# =============================================================================
# 12-lcms-only.R - to-do 3, phase 0: LCMS as the only source of the die-off, and ways to scale its area back
# =============================================================================
# User, 2026-11-23: "I would rather save the canopy/rap approach for later ... My preferred approach would be to accept LCMS as
# the source, but we need to figure out how to scale back its area". LCMS's stress class (12 Insect, Disease, or Drought
# Stress; 4 Desiccation) covers about a third of the southern Sierra's conifer forest in 2012-2018, against 7% mapped dead by
# Salo and 4% of stands over the 70% line in FIA. Candidate ways to rank pixels using only what stage 6 already has (LCMS,
# NLCD, the forest type groups), so the top of the ranking can be taken until FIA's area is met:
#   years      stress years in the window
#   run        longest run of consecutive stress years
#   cell300    mean stress years over the conifer pixels of the pixel's 300 m cell (how solid the patch is)
#   cell900    the same over the 900 m cell
#   years+cell years, ties broken by cell300
#   years_left years, plus 4 if NLCD moves the pixel out of forest within three years after the window
# Each is scored against Salo (dead share 2016-2018 summed, on the region grid by 11-salo-comparison.R) per pixel and over
# 600 m cells, and against the mapped dead trees (pixel tables of 10-reference-combined.R).
# Read-only on the data home. Usage: Rscript dev/mortality/12-lcms-only.R <region folder> <out folder> [--window=2012-2018]
#   [--keep=220,240,260,280,340,360,370] [--target=4.1]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; R <- pos[1]; OUT <- pos[2]; terraOptions(progress = 0); options(width = 250); set.seed(1)
w <- as.integer(strsplit(opt("window", "2012-2018"), "-")[[1]]); WY <- w[1]:w[2]; KEEP <- as.integer(strsplit(opt("keep", "220,240,260,280,340,360,370"), ",")[[1]]); TARGET <- as.numeric(opt("target", 4.1)) / 100
f_nl <- function(k) Sys.glob(file.path(R, "land-cover/nlcd-annual", sprintf("Annual_NLCD_LndCov_%d_*.tif", k)))[1]
G <- rast(f_nl(w[1] - 1)); levels(G) <- NULL; coltab(G) <- NULL; NC <- ncol(G)
rv <- function(f) { r <- rast(f); levels(r) <- NULL; coltab(r) <- NULL; values(r, mat = FALSE) }
lc <- function(k) rv(file.path(R, "disturbance/lcms", k, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", k)))
ix <- which(rv(file.path(OUT, "ftg-30m.tif")) %in% KEEP & rv(f_nl(w[1] - 1)) %in% 41:43)          # conifer forest the year before the window
d <- data.table(cell = ix, salo = rv(file.path(OUT, "salo-sum-30m.tif"))[ix], years = 0L, run = 0L, bad = FALSE); cur <- integer(length(ix))
for (k in (w[1] - 5):(w[2] + 4)) {v <- lc(k)[ix]; d[, bad := bad | v %in% c(1L, 2L, 3L, 5L, 6L, 7L, 8L, 9L)]
  f <- file.path(R, "disturbance/mtbs", sprintf("mtbs_CONUS_%d.tif", k)); if (file.exists(f)) d[, bad := bad | rv(f)[ix] %in% 1:4]
  if (k %in% WY) { s <- v %in% c(4L, 12L); cur <- ifelse(s, cur + 1L, 0L); d[, years := years + s][, run := pmax(run, cur)] } }
out <- o2 <- rep(FALSE, length(ix)); for (k in (w[1] + 1):(w[2] + 3)) { nf <- !(rv(f_nl(k))[ix] %in% 41:43); o2 <- o2 | nf; if (k > w[2]) out <- out | nf }; d[, left := out][, left_any := o2]   # out of forest after the window; in or after it
d <- d[bad == FALSE & !is.na(salo)]
d[, `:=`(row = (cell - 1) %/% NC, col = (cell - 1) %% NC)]
d[, cell300 := mean(years), by = .(row %/% 10, col %/% 10)][, cell900 := mean(years), by = .(row %/% 30, col %/% 30)]
d[, `:=`(years_cell = years + cell300 / 10, years_left = years + 4 * left)]
cat(sprintf("Region %s: %d clean conifer forest pixels (%.0f km2), window %d-%d\n", basename(R), nrow(d), nrow(d) * 9e-4, w[1], w[2]))
cat(sprintf("LCMS stress class in any year: %.1f%% of them; Salo mean dead share %.2f%%; Salo >= 30%% on %.2f%%, >= 50%% on %.2f%%; NLCD leaves forest within three years after on %.2f%%\n",
            100 * mean(d$years > 0), 100 * mean(d$salo), 100 * mean(d$salo >= 0.3), 100 * mean(d$salo >= 0.5), 100 * mean(d$left)))
cat("\nby number of stress years:\n")
print(d[, .(km2 = round(.N * 9e-4), pct_of_forest = round(100 * .N / nrow(d), 1), salo_mean_pct = round(100 * mean(salo), 1), salo_30plus_pct = round(100 * mean(salo >= 0.3), 1), nlcd_left_forest_pct = round(100 * mean(left), 1)), by = years][order(years)])

auc <- function(s, p) { r <- rank(s); n1 <- as.numeric(sum(p)); n0 <- as.numeric(sum(!p)); (sum(r[p]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
S <- c("years", "run", "cell300", "cell900", "years_cell", "years_left"); sm <- d[sample(.N, min(.N, 2e6))]
pick <- function(s) { o <- order(-s, runif(length(s))); z <- rep(FALSE, length(s)); z[o[seq_len(round(TARGET * length(s)))]] <- TRUE; z }
cat(sprintf("\neach ranking against Salo. 'top' = the top %.1f%% of pixels by the ranking (the FIA area), ties broken at random:\n", 100 * TARGET))
res <- rbindlist(lapply(S, function(v) { z <- pick(d[[v]]); d[, sel := z]
  c6 <- d[, .(sel = mean(sel), salo = mean(salo), n = .N), by = .(row %/% 20, col %/% 20)][n >= 100]
  data.table(ranking = v, spearman_pixel = round(cor(sm[[v]], sm$salo, method = "spearman"), 2), auc_salo30 = round(auc(sm[[v]], sm$salo >= 0.3), 3), auc_salo50 = round(auc(sm[[v]], sm$salo >= 0.5), 3),
             top_salo_mean_pct = round(100 * mean(d$salo[z]), 1), top_salo30_pct = round(100 * mean(d$salo[z] >= 0.3), 1), top_salo_zero_pct = round(100 * mean(d$salo[z] == 0), 1),
             cells600_r = round(cor(c6$sel, c6$salo), 2), cells600_spearman = round(cor(c6$sel, c6$salo, method = "spearman"), 2)) }))
zs <- pick(d$salo); res <- rbind(res, data.table(ranking = "(Salo itself: ceiling)", top_salo_mean_pct = round(100 * mean(d$salo[zs]), 1), top_salo30_pct = round(100 * mean(d$salo[zs] >= 0.3), 1), top_salo_zero_pct = 0), fill = TRUE)
zr <- runif(nrow(d)) < TARGET; res <- rbind(res, data.table(ranking = "(random: floor)", top_salo_mean_pct = round(100 * mean(d$salo[zr]), 1), top_salo30_pct = round(100 * mean(d$salo[zr] >= 0.3), 1), top_salo_zero_pct = round(100 * mean(d$salo[zr] == 0), 1)), fill = TRUE)
print(res)

cat("\nagainst the mapped dead trees (per 30 m pixel; the combined canopy and RAP score beside them):\n")
key <- d[, .(cell, years, run, cell300, cell900, years_cell, years_left)]; setkey(key, cell)
for (nm in c("stovall", "koontz")) { f <- file.path(OUT, sprintf("%s-pixels-combined.csv", nm)); if (!file.exists(f)) next
  p <- merge(fread(f), key, by = "cell"); p <- p[!is.na(s_comb)]
  cat(sprintf("--- %s: %d pixels in clean conifer forest; %.1f%% have >= 70%% of trees killed; LCMS stress in any year on %.0f%%\n", nm, nrow(p), 100 * mean(p$kill_w >= 0.7), 100 * mean(p$years > 0)))
  print(rbindlist(lapply(c(S, "s_comb"), function(v) data.table(ranking = v, spearman = round(cor(p[[v]], p$kill_w, method = "spearman"), 2), auc70 = round(auc(p[[v]], p$kill_w >= 0.7), 3)))))
  print(p[, .(pixels = .N, killed_mean = round(mean(kill_w), 2), over70_pct = round(100 * mean(kill_w >= 0.7), 1)), by = years][order(years)]) }

cat("\nrules that need no ranking: the LCMS stress class together with NLCD moving the pixel out of forest (left = within three years after the window; left_any = in the window or within three years after):\n")
rl <- list("stress any year" = d$years >= 1, "left forest (no LCMS)" = d$left, "left_any (no LCMS)" = d$left_any, "stress 1+ and left" = d$years >= 1 & d$left, "stress 2+ and left" = d$years >= 2 & d$left,
           "stress 1+ and left_any" = d$years >= 1 & d$left_any, "stress 2+ and left_any" = d$years >= 2 & d$left_any, "stress 2 to 6 and left_any" = d$years >= 2 & d$years <= 6 & d$left_any)
print(rbindlist(lapply(names(rl), function(nm) { z <- rl[[nm]]; d[, sel := z]; c6 <- d[, .(sel = mean(sel), salo = mean(salo), n = .N), by = .(row %/% 20, col %/% 20)][n >= 100]
  data.table(rule = nm, km2 = round(sum(z) * 9e-4), pct_of_forest = round(100 * mean(z), 2), salo_mean_pct = round(100 * mean(d$salo[z]), 1), salo30_pct = round(100 * mean(d$salo[z] >= 0.3), 1), salo_zero_pct = round(100 * mean(d$salo[z] == 0), 1),
             share_of_salo_dead_area_pct = round(100 * sum(d$salo[z]) / sum(d$salo), 1), cells600_r = round(cor(c6$sel, c6$salo), 2), cells600_spearman = round(cor(c6$sel, c6$salo, method = "spearman"), 2)) })))
for (nm in c("stovall", "koontz")) { f <- file.path(OUT, sprintf("%s-pixels-combined.csv", nm)); if (!file.exists(f)) next
  p <- merge(fread(f)[, .(cell, kill_w)], d[, .(cell, years, left, left_any)], by = "cell")
  cat(sprintf("--- %s trees, %d pixels: mean share killed %.2f, %.1f%% over 70%%\n", nm, nrow(p), mean(p$kill_w), 100 * mean(p$kill_w >= 0.7)))
  print(rbindlist(lapply(list("stress 1+ and left" = p$years >= 1 & p$left, "stress 1+ and left_any" = p$years >= 1 & p$left_any, "stress 2+ and left_any" = p$years >= 2 & p$left_any), function(z)
    data.table(flagged_pct = round(100 * mean(z), 1), killed_mean_flagged = round(mean(p$kill_w[z]), 2), over70_flagged_pct = round(100 * mean(p$kill_w[z] >= 0.7), 1), killed_mean_rest = round(mean(p$kill_w[!z]), 2))), idcol = "rule")) }
