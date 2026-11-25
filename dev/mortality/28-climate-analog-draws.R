# =============================================================================
# 28-climate-analog-draws.R - to-do 3, climate method: can a drought index choose which historical years a projection draws?
# =============================================================================
# 27-climate-loca2-check.R showed a fitted response to temperature cannot be carried past the record. This tests the other design:
# the amount stays the record's (as the empirical method of 2.0.2), and the climate of a projection year decides which historical
# years are likely to be drawn for it: a year is drawn with a weight that falls with the distance between its drought index and the
# projection year's (a Gaussian kernel). No rate can exceed the record's; a run with more dry spells draws the outbreak years more often.
# Units are the western ecodivisions (their forest-weighted monthly climate; the national rule's yearly rates, 1991-2022).
# Indexes, each the mean of the last W water years, standardized against the unit's own PRISM years 1981-2020:
#   precipitation; precipitation less demand (Thornthwaite, heat index fixed at the PRISM normal); mean temperature (for reference)
# 1. Hindcast: each historical year's rate predicted from the other years of its unit (the years within 2 of it left out), weighted
#    by the index, against the plain mean of those years (what unweighted draws give). Skill = 1 - squared error / the plain mean's.
#    "Pooled" lets a unit borrow the years of every unit, as rates relative to each unit's mean.
# 2. LOCA2: the index of each run (monthly delta method against PRISM's 1991-2020 months), how often it lies outside the record,
#    and the rate the weighted draws give by period, as a ratio of the record's mean (1 = the empirical method).
# Usage: Rscript dev/mortality/28-climate-analog-draws.R <rule-national-300m.tif> <ecodiv.gpkg> <PRISM cache of 26 (rds)> <LOCA2 folder> <out folder> [--cache=<rds>]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) }); options(width = 230); terraOptions(progress = 0); source("src/loca2.R")
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; rf <- pos[1]; ef <- pos[2]; pcache <- pos[3]; ldir <- pos[4]; odir <- pos[5]; cf <- opt("cache", ""); BL <- 20L; MINF <- 0.05
WEST <- c(`240` = "240", `260` = "260", `310` = "310", `320` = "320", `330` = "330", `340` = "340", `2401` = "M240", `2601` = "M260", `3101` = "M310", `3301` = "M330", `3401` = "M340")
yrs <- 1991:2022; fy <- 2023:2100; ref <- 1981:2020; norm <- 1991:2020; GAP <- 2L; rec_y <- 1990:2022

r <- rast(rf); eco <- vect(ef); west <- eco[eco$StrtmId %in% as.integer(names(WEST)), ]; rw <- crop(r, ext(west), snap = "out")
B <- aggregate(rw, BL, sum, na.rm = TRUE); v <- values(B); ev <- extract(rasterize(west, B[[1]], "StrtmId"), seq_len(ncell(B)))[, 1]
keep <- which(!is.na(ev) & !is.na(v[, "forest"]) & v[, "forest"] >= MINF * BL^2 * 100); K <- readRDS(pcache); stopifnot(nrow(K$TX) == length(keep))
okp <- rowSums(is.na(K$PP) | is.na(K$TX) | is.na(K$TN)) == 0; ec <- WEST[as.character(ev[keep])]; U <- sort(unique(ec)); F0 <- v[keep, "forest"]; pts <- project(xyFromCell(B, keep), crs(B), "EPSG:4269")
Wm <- sapply(U, function(u) { w <- F0 * (ec == u) * okp; w / sum(w) }); umean <- function(M) { M[!okp, ] <- 0; t(crossprod(Wm, M)) }   # months x units
pm <- CJ(y = 1979:2022, m = 1:12); PR <- list(pm = pm, P = umean(K$PP), TX = umean(K$TX), TN = umean(K$TN)); lat <- as.vector(crossprod(Wm, pts[, 2])); names(lat) <- U; rm(K)
FL <- v[keep, as.character(rec_y), drop = FALSE]; FL[is.na(FL)] <- 0; cum <- t(apply(FL, 1, cumsum)); E <- FL[, as.character(yrs)]; N <- pmax(F0 - cum[, as.character(yrs - 1L)], E)
RATE <- sapply(U, function(u) colSums(E[ec == u, , drop = FALSE]) / colSums(N[ec == u, , drop = FALSE])); rownames(RATE) <- yrs; fw <- sapply(U, function(u) sum(F0[ec == u])); REL <- sweep(RATE, 2, colMeans(RATE), "/")
big <- names(sort(colSums(sapply(U, function(u) colSums(E[ec == u, , drop = FALSE]))), decreasing = TRUE)); aw <- fw * colMeans(RATE)   # (area weights: forest x mean rate)

# ---- LOCA2 monthly by unit ------------------------------------------------------------------------------------------------------
runs <- rbindlist(lapply(list.dirs(ldir, recursive = FALSE, full.names = FALSE), function(g) rbindlist(lapply(list.dirs(file.path(ldir, g), recursive = FALSE, full.names = FALSE), function(m)
  data.table(gcm = g, member = m, ssp = setdiff(list.dirs(file.path(ldir, g, m), recursive = FALSE, full.names = FALSE), "historical"))))))
runs <- runs[mapply(function(g, m, s) loca2_has_run(ldir, g, m, s), gcm, member, ssp)][, run := paste(gcm, ssp)]
win <- ext(min(pts[, 1]) - 0.2, max(pts[, 1]) + 0.2, min(pts[, 2]) - 0.2, max(pts[, 2]) + 0.2)
lread <- function(g, m, run, var) rbindlist(lapply(seq_len(nrow(fs <- loca2_best(loca2_files(ldir, g, m, run, var), win))), function(i) { x <- crop(loca2_rast(fs$file[i]), win); tm <- time(x); k <- which(as.integer(format(tm, "%Y")) >= 1979)
  if (!length(k)) return(NULL); M <- as.matrix(extract(x[[k]], pts)); if (ncol(M) > length(k)) M <- M[, -1]; okl <- rowSums(is.na(M)) == 0; W <- sapply(U, function(u) { w <- F0 * (ec == u) * okl; w / sum(w) }); M[!okl, ] <- 0
  o <- as.data.table(t(crossprod(W, M))); setnames(o, U); cbind(data.table(y = as.integer(format(tm[k], "%Y")), m = as.integer(format(tm[k], "%m"))), o) }))
if (nzchar(cf) && file.exists(cf)) LO <- readRDS(cf) else { hist <- list(); LO <- list()
  for (i in seq_len(nrow(runs))) { t0 <- Sys.time(); g <- runs$gcm[i]; m <- runs$member[i]; if (is.null(hist[[g]])) hist[[g]] <- lapply(c(pr = "pr", tasmax = "tasmax", tasmin = "tasmin"), function(vv) lread(g, m, "historical", vv))
    LO[[runs$run[i]]] <- lapply(c(pr = "pr", tasmax = "tasmax", tasmin = "tasmin"), function(vv) unique(rbind(hist[[g]][[vv]], lread(g, m, runs$ssp[i], vv)), by = c("y", "m"))[order(y, m)])
    cat(sprintf("  %s read in %.1f minutes\n", runs$run[i], as.numeric(difftime(Sys.time(), t0, units = "mins")))) }; if (nzchar(cf)) saveRDS(LO, cf) }
dim_ <- c(31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
# a run as PRISM-like monthly series by the delta method: temperature shifted, precipitation scaled, month by month, to PRISM's 1991-2020
clim <- function(P, TX, TN, mt) list(mt = mt, P = P, TM = (TX + TN) / 2)
PRc <- clim(PR$P, PR$TX, PR$TN, PR$pm); mclim <- function(M, mt) sapply(1:12, function(k) colMeans(M[mt$m == k & mt$y %in% norm, , drop = FALSE]))   # units x 12
LC <- lapply(LO, function(L) { mt <- L$pr[, .(y, m)]; P <- as.matrix(L$pr[, U, with = FALSE]) * 86400 * dim_[mt$m]; TM <- (as.matrix(L$tasmax[, U, with = FALSE]) + as.matrix(L$tasmin[, U, with = FALSE])) / 2 - 273.15
  fP <- mclim(PRc$P, PRc$mt) / pmax(mclim(P, mt), 1e-6); dT <- mclim(PRc$TM, PRc$mt) - mclim(TM, mt); list(mt = mt, P = P * t(fP)[mt$m, ], TM = TM + t(dT)[mt$m, ]) })

# ---- indexes ---------------------------------------------------------------------------------------------------------------------
doy <- c(15, 46, 75, 106, 136, 167, 197, 228, 259, 289, 320, 350); dl <- sapply(1:12, function(m) { dec <- 0.409 * sin(2 * pi * doy[m] / 365 - 1.39); 24 / pi * acos(pmax(-1, pmin(1, -tan(lat * pi / 180) * tan(dec)))) })
Tn <- mclim(PRc$TM, PRc$mt); I <- rowSums((pmax(Tn, 0) / 5)^1.514); al <- 6.75e-7 * I^3 - 7.71e-5 * I^2 + 1.792e-2 * I + 0.49239
annual <- function(C) { mt <- C$mt; wy <- mt$y + (mt$m >= 10); PET <- sapply(seq_along(U), function(u) 16 * (10 * pmax(C$TM[, u], 0) / I[u])^al[u] * (dl[u, mt$m] / 12) * (dim_[mt$m] / 30))
  ys <- sort(unique(wy)); ys <- ys[sapply(ys, function(y) sum(wy == y) == 12)]; f <- function(M, fun) { o <- t(sapply(ys, function(y) fun(M[wy == y, , drop = FALSE]))); dimnames(o) <- list(ys, U); o }
  list(`precipitation` = f(C$P, colSums), `precipitation less demand` = f(C$P - PET, colSums), `mean temperature` = f(C$TM, colMeans)) }
AP <- annual(PRc); AL <- lapply(LC, annual); mu <- lapply(AP, function(M) colMeans(M[as.character(ref), ])); sdv <- lapply(AP, function(M) apply(M[as.character(ref), ], 2, sd))
idx <- function(A, nm, W, years) { Z <- sweep(sweep(A[[nm]], 2, mu[[nm]]), 2, sdv[[nm]], "/"); o <- t(sapply(years, function(y) colMeans(Z[as.character((y - W + 1L):y), , drop = FALSE]))); dimnames(o) <- list(years, U); o }
specs <- CJ(Index = names(AP), W = c(3L, 5L, 7L), sorted = FALSE)

# ---- 1. hindcast -----------------------------------------------------------------------------------------------------------------
kern <- function(d, h) { w <- -0.5 * (d / h)^2; exp(w - max(w)) }
hind <- function(X, h, pooled) { P <- RATE * NA; M <- P; for (u in U) for (y in yrs) { far <- abs(yrs - y) > GAP; M[as.character(y), u] <- mean(RATE[far, u])
    if (pooled) { w <- kern(as.vector(X[far, ]) - X[as.character(y), u], h); P[as.character(y), u] <- sum(w * as.vector(REL[far, ])) / sum(w) * mean(RATE[far, u]) }
    else { w <- kern(X[far, u] - X[as.character(y), u], h); P[as.character(y), u] <- sum(w * RATE[far, u]) / sum(w) } }
  rel <- function(Q) sweep(Q, 2, colMeans(RATE), "/"); se <- function(Q) colSums((rel(Q) - rel(RATE))^2)
  list(skill = 1 - sum(se(P) * aw) / sum(se(M) * aw), by = 1 - se(P) / se(M), cor = sapply(U, function(u) cor(P[, u], RATE[, u], method = "spearman")), P = P) }
hs <- rbindlist(lapply(seq_len(nrow(specs)), function(i) { X <- idx(AP, specs$Index[i], specs$W[i], yrs); rbindlist(lapply(c(0.25, 0.5, 1), function(h) rbindlist(lapply(c(FALSE, TRUE), function(p) { o <- hind(X, h, p)
  data.table(Index = specs$Index[i], Years = specs$W[i], Width = h, Analogs = if (p) "all units" else "own unit", Skill = o$skill, MedianRankCor = median(o$cor), UnitsBetter = sum(o$by > 0)) })))) }))
fwrite(hs, file.path(odir, "climate-analog-hindcast.csv")); r2 <- function(d) d[, lapply(.SD, function(x) if (is.double(x)) round(x, 2) else x)]
cat(sprintf("%d units, %d-%d. Hindcast skill (1 = perfect, 0 = no better than unweighted draws, below 0 = worse), best kernel width of each index and window:\n", length(U), min(yrs), max(yrs)))
print(r2(hs[, .SD[which.max(Skill)], by = .(Index, Years, Analogs)][order(-Skill)]))
bestS <- hs[, .SD[which.max(Skill)], by = Index][order(-Skill)]; cat("\nbest setting of each index, skill by unit (largest first):\n")
bu <- sapply(seq_len(nrow(bestS)), function(i) hind(idx(AP, bestS$Index[i], bestS$Years[i], yrs), bestS$Width[i], bestS$Analogs[i] == "all units")$by[big]); colnames(bu) <- bestS$Index; print(round(t(bu), 2))
# the trend: the same after a straight trend is taken out of each unit's index and rates is not possible for a draw, so the check is
# the rank correlation of the index with the rate inside each half of the record
cat("\nrank correlation of the index with the rate, forest-weighted mean over units: whole record, 1991-2006, 2007-2022\n")
print(r2(rbindlist(lapply(seq_len(nrow(bestS)), function(i) { X <- idx(AP, bestS$Index[i], bestS$Years[i], yrs); f <- function(k) sum(sapply(U, function(u) cor(X[k, u], RATE[k, u], method = "spearman")) * aw) / sum(aw)
  data.table(Index = bestS$Index[i], Years = bestS$Years[i], whole = f(rep(TRUE, length(yrs))), first_half = f(yrs <= 2006), second_half = f(yrs > 2006)) }))))

# ---- 2. LOCA2 --------------------------------------------------------------------------------------------------------------------
per <- function(y) fifelse(y <= 2040, "2023-2040", fifelse(y <= 2070, "2041-2070", "2071-2100"))
lo <- rbindlist(lapply(seq_len(nrow(bestS)), function(i) { nm <- bestS$Index[i]; W <- bestS$Years[i]; h <- bestS$Width[i]; pooled <- bestS$Analogs[i] == "all units"; X <- idx(AP, nm, W, yrs)
  rbindlist(lapply(names(AL), function(rn) { Z <- idx(AL[[rn]], nm, W, fy); Zh <- idx(AL[[rn]], nm, W, yrs)
    ex <- sapply(U, function(u) sapply(as.character(fy), function(y) { if (pooled) { w <- kern(as.vector(X) - Z[y, u], h); sum(w * as.vector(REL)) / sum(w) } else { w <- kern(X[, u] - Z[y, u], h); sum(w * REL[, u]) / sum(w) } }))
    out <- sapply(U, function(u) Z[, u] < min(X[, u]) | Z[, u] > max(X[, u]))
    data.table(Index = nm, run = rn, Year = fy, ratio = as.vector(ex %*% aw) / sum(aw), outside = as.vector(out %*% fw) / sum(fw), index = as.vector(Z %*% fw) / sum(fw), hist_sd = sd(as.vector(Zh %*% fw) / sum(fw)), prism_sd = sd(as.vector(X %*% fw) / sum(fw))) })) }))
fwrite(lo, file.path(odir, "climate-analog-loca2.csv"))
cat("\nLOCA2: the rate the weighted draws give, as a ratio of the record's mean rate (1 = the empirical method), by period; and the share of forest whose index is outside the record\n")
s <- lo[, .(ratio = mean(ratio), outside = mean(outside), index = mean(index)), by = .(Index, run, period = per(Year))]
print(r2(dcast(s, Index + run ~ period, value.var = c("ratio", "outside", "index"))))
cat("\nthe index's spread between years over 1991-2022, each run against PRISM (West mean):\n"); print(r2(unique(lo[, .(Index, run, hist_sd, prism_sd)])))
cat("the highest ratio the record allows (every draw the unit's worst year):", round(sum(apply(REL, 2, max) * aw) / sum(aw), 2), "; its 5 worst years:", round(sum(apply(REL, 2, function(x) mean(sort(x, decreasing = TRUE)[1:5])) * aw) / sum(aw), 2), "\n")

# ---- figure ----------------------------------------------------------------------------------------------------------------------
cols <- setNames(c("#1b7837", "#e08214", "#b2182b", "#5aae61", "#d6604d")[seq_len(nrow(runs))], runs$run); lty <- setNames(ifelse(runs$gcm == runs$gcm[1], 1, 2), runs$run); sm <- function(x) as.vector(stats::filter(x, rep(1 / 5, 5), sides = 2))
png(file.path(odir, "climate-analog-draws.png"), width = 2700, height = 1700, res = 170); par(mfrow = c(2, nrow(bestS)), mar = c(3.2, 4, 3.4, 1), mgp = c(2.2, 0.7, 0))
for (i in seq_len(nrow(bestS))) { nm <- bestS$Index[i]; X <- idx(AP, nm, bestS$Years[i], yrs); xp <- as.vector(X %*% fw) / sum(fw); d <- lo[Index == nm]
  plot(yrs, xp, type = "l", lwd = 3, xlim = c(1991, 2100), ylim = range(d$index, xp), xlab = "", ylab = "index (standard deviations)", main = sprintf("%s, %d years\nblack: PRISM; dotted: the record's range", nm, bestS$Years[i]))
  for (rn in names(AL)) lines(d[run == rn, Year], d[run == rn, index], col = cols[rn], lty = lty[rn], lwd = 1.6); abline(h = range(xp), lty = 3); if (i == 1) legend("bottomleft", names(AL), col = cols, lty = lty, lwd = 2, bty = "n", cex = 0.75) }
for (i in seq_len(nrow(bestS))) { nm <- bestS$Index[i]; d <- lo[Index == nm]; plot(NA, xlim = c(2023, 2100), ylim = range(0, lo$ratio, 1.2), xlab = "", ylab = "rate / the record's mean rate", main = sprintf("rate the weighted draws give (5-year mean)\nhindcast skill %.2f", bestS$Skill[i]))
  abline(h = 1, lty = 2); for (rn in names(AL)) lines(fy, sm(d[run == rn, ratio]), col = cols[rn], lty = lty[rn], lwd = 1.8) }
invisible(dev.off()); cat("\nwritten to", odir, "\n")
