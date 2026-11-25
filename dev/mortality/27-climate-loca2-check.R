# =============================================================================
# 27-climate-loca2-check.R - to-do 3, climate method: the 7-year temperature index from LOCA2, against PRISM and out to 2100
# =============================================================================
# 26-climate-carryover-west.R found the 7-year mean temperature (a z-score of each 6 km block against its own 1980-2022 years) the
# best single index of drought and insect mortality across the West. This asks whether it can drive a projection:
#   1. the same index from each LOCA2 run in the data home, by the delta method stage 11 uses (the run's anomaly against its own
#      1991-2020 normal, added to PRISM's 1991-2020 normal), set against PRISM's over 1994-2022: level, spread and trend
#   2. where the index goes by 2050 and 2100, against the highest value the fit ever saw
#   3. the rates the fitted response gives to 2100, as it is and with the index capped at the fitted range, and the forest used up
# The response is refitted here on calendar-year temperature (LOCA2's annual mean, as src/loca2.R reads it): an intercept for each
# ecodivision and one slope. Forest lost is not regrown and nothing else removes forest, so "used up" is an upper bound of this event.
# Usage: Rscript dev/mortality/27-climate-loca2-check.R <rule-national-300m.tif> <ecodiv.gpkg> <PRISM cache of 26 (rds)> <LOCA2 folder> <out folder>
#          [--block=20] [--min-forest=0.05] [--window=7] [--cache=<rds>]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) }); options(width = 230); terraOptions(progress = 0); source("src/loca2.R")
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; rf <- pos[1]; ef <- pos[2]; pcache <- pos[3]; ldir <- pos[4]; odir <- pos[5]; dir.create(odir, showWarnings = FALSE, recursive = TRUE)
BL <- as.integer(opt("block", 20)); MINF <- as.numeric(opt("min-forest", 0.05)); WN <- as.integer(opt("window", 7)); cf <- opt("cache", "")
WEST <- c(`240` = "240", `260` = "260", `310` = "310", `320` = "320", `330` = "330", `340` = "340", `2401` = "M240", `2601` = "M260", `3101` = "M310", `3301` = "M330", `3401` = "M340")
yrs <- 1994:2022; fy <- 2023:2100; zy <- 1980:2022; norm <- 1991:2020; mon <- CJ(y = 1979:2022, m = 1:12); rec_y <- 1990:2022

r <- rast(rf); eco <- vect(ef); west <- eco[eco$StrtmId %in% as.integer(names(WEST)), ]; rw <- crop(r, ext(west), snap = "out")
B <- aggregate(rw, BL, sum, na.rm = TRUE); v <- values(B); ev <- extract(rasterize(west, B[[1]], "StrtmId"), seq_len(ncell(B)))[, 1]
keep <- which(!is.na(ev) & !is.na(v[, "forest"]) & v[, "forest"] >= MINF * BL^2 * 100); K <- readRDS(pcache); stopifnot(nrow(K$TX) == length(keep), ncol(K$TX) == nrow(mon))
pts <- project(xyFromCell(B, keep), crs(B), "EPSG:4269"); TMm <- (K$TX + K$TN) / 2; rm(K); TP <- sapply(1979:2022, function(y) rowMeans(TMm[, mon$y == y, drop = FALSE])); colnames(TP) <- 1979:2022; rm(TMm)

# ---- LOCA2 annual mean temperature at the blocks, each run ------------------------------------------------------------------------
runs <- rbindlist(lapply(list.dirs(ldir, recursive = FALSE, full.names = FALSE), function(g) rbindlist(lapply(list.dirs(file.path(ldir, g), recursive = FALSE, full.names = FALSE), function(m)
  data.table(gcm = g, member = m, ssp = setdiff(list.dirs(file.path(ldir, g, m), recursive = FALSE, full.names = FALSE), "historical"))))))
runs <- runs[mapply(function(g, m, s) loca2_has_run(ldir, g, m, s), gcm, member, ssp)][, run := paste(gcm, ssp)]; ly <- 1979:2100
if (nzchar(cf) && file.exists(cf)) TL <- readRDS(cf) else { win <- ext(min(pts[, 1]) - 0.2, max(pts[, 1]) + 0.2, min(pts[, 2]) - 0.2, max(pts[, 2]) + 0.2)
  TL <- lapply(seq_len(nrow(runs)), function(i) { t0 <- Sys.time(); x <- loca2_annual(ldir, runs$gcm[i], runs$member[i], runs$ssp[i], "tmean", ly, win); m <- as.matrix(extract(x, pts)); if (ncol(m) > length(ly)) m <- m[, -1]
    colnames(m) <- ly; cat(sprintf("  %s read in %.1f minutes\n", runs$run[i], as.numeric(difftime(Sys.time(), t0, units = "mins")))); m }); names(TL) <- runs$run; if (nzchar(cf)) saveRDS(TL, cf) }
ok <- rowSums(is.na(TP)) == 0 & Reduce(`&`, lapply(TL, function(m) rowSums(is.na(m)) == 0)); cat(sprintf("%d blocks, %d without LOCA2 or PRISM dropped; runs: %s\n", length(keep), sum(!ok), paste(runs$run, collapse = ", ")))
keep <- keep[ok]; TP <- TP[ok, ]; TL <- lapply(TL, function(m) m[ok, ]); nB <- length(keep); ec <- WEST[as.character(ev[keep])]; ef <- factor(ec)
F0 <- v[keep, "forest"]; FL <- v[keep, as.character(rec_y), drop = FALSE]; FL[is.na(FL)] <- 0; cum <- t(apply(FL, 1, cumsum)); E <- FL[, as.character(yrs)]; N <- pmax(F0 - cum[, as.character(yrs - 1L)], E)

# ---- the index: z-score against PRISM's 1980-2022, mean of the window; LOCA2 by the delta method -----------------------------------
cy <- function(M, y) M[, as.character(y), drop = FALSE]; mu <- rowMeans(cy(TP, zy)); sdv <- pmax(apply(cy(TP, zy), 1, sd), 1e-9); pn <- rowMeans(cy(TP, norm))
zw <- function(Tm, years) { Z <- (Tm - mu) / sdv; out <- sapply(years, function(y) rowMeans(cy(Z, (y - WN + 1L):y))); colnames(out) <- years; out }
ZP <- zw(TP, yrs); ZL <- lapply(TL, function(m) zw(m - rowMeans(cy(m, norm)) + pn, c(yrs, fy)))
um <- function(Z) { o <- sapply(levels(ef), function(e1) colSums(Z[ef == e1, , drop = FALSE] * F0[ef == e1]) / sum(F0[ef == e1])); cbind(o, West = colSums(Z * F0) / sum(F0)) }   # forest-weighted means: years x units
cat(sprintf("\n1. the %d-year index over %d-%d, forest-weighted mean of the West: level, spread between years, and trend per decade\n", WN, min(yrs), max(yrs)))
st <- function(x) c(mean = mean(x), sd = sd(x), trend_per_decade = 10 * unname(coef(lm(x ~ yrs))[2])); s1 <- rbind(PRISM = st(um(ZP)[, "West"]), t(sapply(ZL, function(Z) st(um(Z)[as.character(yrs), "West"])))); print(round(s1, 2))
cat("   the same by ecodivision, mean level (PRISM first):\n"); print(round(rbind(PRISM = colMeans(um(ZP)), t(sapply(ZL, function(Z) colMeans(um(Z)[as.character(yrs), ])))), 2))
zmax <- quantile(ZP, 0.99); cat(sprintf("\n2. the fit saw index values up to %.2f (99th percentile of block-years; highest %.2f). The index later, West mean, and the share of blocks above that:\n", zmax, max(ZP)))
s2 <- rbindlist(lapply(names(ZL), function(n) { Z <- ZL[[n]]; data.table(run = n, `2030` = um(Z)["2030", "West"], `2050` = um(Z)["2050", "West"], `2075` = um(Z)["2075", "West"], `2100` = um(Z)["2100", "West"],
  above_2050 = mean(Z[, "2050"] > zmax), above_2100 = mean(Z[, "2100"] > zmax)) })); print(s2[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)])

# ---- the response, refitted, and what it gives -----------------------------------------------------------------------------------
d <- data.table(eco = rep(ec, length(yrs)), e = as.vector(E), n = as.vector(N), x = round(as.vector(ZP), 1))[n > 0, .(e = sum(e), n = sum(n)), by = .(eco, x)]
m <- glm(cbind(e, n - e) ~ 0 + eco + x, binomial, d); b <- coef(m)[["x"]]; a0 <- setNames(coef(m)[paste0("eco", levels(ef))], levels(ef))[ec]
obs <- sum(E) / sum(N); cat(sprintf("\n3. response refitted on calendar-year temperature: slope %.2f per standard deviation (each SD multiplies the odds by %.1f); observed mean rate %d-%d %.3f%% a year\n", b, exp(b), min(yrs), max(yrs), 100 * obs))
proj <- function(Z, cap = Inf) { open <- pmax(F0 - cum[, "2022"], 0); out <- list(); for (y in fy) { p <- plogis(a0 + b * pmin(Z[, as.character(y)], cap)); k <- open * p
    out[[length(out) + 1]] <- data.table(Year = y, eco = ec, killed = k, open = open, free = F0 * p); open <- open - k }; rbindlist(out) }
res <- rbindlist(lapply(names(ZL), function(n) rbind(cbind(run = n, form = "as fitted", proj(ZL[[n]])), cbind(run = n, form = "capped at the fitted range", proj(ZL[[n]], zmax)))))
per <- function(y) fifelse(y <= 2040, "2023-2040", fifelse(y <= 2070, "2041-2070", "2071-2100"))
w1 <- res[, .(rate_pct = 100 * sum(killed) / sum(open)), by = .(run, form, period = per(Year))]; cat("   West: yearly rate on the forest still standing, % (observed 1994-2022 above):\n"); print(dcast(w1, form + run ~ period, value.var = "rate_pct")[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)])
start <- sum(pmax(F0 - cum[, "2022"], 0)); w2 <- res[, .(used_pct = 100 * sum(killed) / start), by = .(run, form)]; w3 <- res[Year <= 2050, .(used_2050 = 100 * sum(killed) / start), by = .(run, form)]
cat(sprintf("   West: share of the eligible forest standing in 2022 that the event takes (1991-2022 took %.1f%% of the 1990 forest):\n", 100 * sum(FL[, as.character(1991:2022)]) / sum(F0)))
print(merge(w3, w2, by = c("run", "form"))[order(form, run), .(form, run, by_2050 = round(used_2050, 1), by_2100 = round(used_pct, 1))])
e2 <- res[form == "capped at the fitted range", .(used_pct = 100 * sum(killed)), by = .(run, eco)]; e2 <- merge(e2, data.table(eco = ec, s = pmax(F0 - cum[, "2022"], 0))[, .(s = sum(s)), by = eco], by = "eco")[, used := round(used_pct / s, 1)]
cat("   by ecodivision, capped form, % of the 2022 forest taken by 2100:\n"); print(dcast(e2, eco ~ run, value.var = "used")); fwrite(res[, .(killed_km2 = sum(killed) * 9e-4, open_km2 = sum(open) * 9e-4), by = .(run, form, eco, Year)], file.path(odir, "climate-loca2-projection.csv"))

# ---- figure ----------------------------------------------------------------------------------------------------------------------
cols <- setNames(c("#1b7837", "#e08214", "#b2182b", "#5aae61", "#d6604d")[seq_len(nrow(runs))], runs$run); lty <- setNames(ifelse(runs$gcm == runs$gcm[1], 1, 2), runs$run)
png(file.path(odir, "climate-loca2-check.png"), width = 2700, height = 950, res = 170); par(mfrow = c(1, 3), mar = c(3.2, 4, 3, 1), mgp = c(2.2, 0.7, 0))
plot(yrs, um(ZP)[, "West"], type = "l", lwd = 3, xlim = c(1994, 2100), ylim = range(sapply(ZL, function(Z) range(um(Z)[, "West"])), um(ZP)[, "West"]), xlab = "", ylab = "index (standard deviations)", main = sprintf("%d-year temperature index, West\nblack: PRISM", WN))
for (n in names(ZL)) lines(c(yrs, fy), um(ZL[[n]])[, "West"], col = cols[n], lty = lty[n], lwd = 1.8); abline(h = zmax, lty = 3); text(1996, zmax, "top of the fitted range", pos = 3, cex = 0.8, adj = 0); legend("topleft", names(ZL), col = cols, lty = lty, lwd = 2, bty = "n", cex = 0.8, inset = c(0, 0.08))
ob <- 100 * colSums(E) / colSums(N); for (fm in c("as fitted", "capped at the fitted range")) { w <- res[form == fm, .(rate = 100 * sum(killed) / sum(open)), by = .(run, Year)]
  plot(yrs, ob, type = "h", lwd = 4, col = "grey70", xlim = c(1994, 2100), ylim = c(0, max(w$rate, ob)), xlab = "", ylab = "% of standing forest per year", main = sprintf("Mortality rate, West: %s\ngrey: observed", fm))
  for (n in names(ZL)) lines(w[run == n, Year], w[run == n, rate], col = cols[n], lty = lty[n], lwd = 1.8) }
invisible(dev.off()); cat("\nwritten to", odir, "\n")
