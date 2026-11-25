# =============================================================================
# 29-climate-analog-pyromes.R - to-do 3, climate method: 28-climate-analog-draws.R with pyromes as units and a better water balance
# =============================================================================
# As 28 (read its header), with: units = the pyromes of --units=<file>::<id field>::<name field> inside the western ecodivisions that hold
# --min-flagged km2 of events; and two more indexes, a Hargreaves demand (less sensitive to warming than Thornthwaite's) and a soil-store deficit.
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
okp <- rowSums(is.na(K$PP) | is.na(K$TX) | is.na(K$TN)) == 0; F0 <- v[keep, "forest"]; pts <- project(xyFromCell(B, keep), crs(B), "EPSG:4269")
# units: the polygons of --units=<file>:<id field>:<name field> (pyromes), within the western ecodivisions; a unit needs --min-flagged km2 of events
us <- strsplit(opt("units", ""), "::", fixed = TRUE)[[1]]; uv <- project(vect(us[1]), crs(B)); ec <- paste0("P", extract(rasterize(uv, B[[1]], us[2]), keep)[, 1]); ec[ec == "PNA"] <- NA
fk <- rowSums(v[keep, as.character(yrs), drop = FALSE], na.rm = TRUE); ut <- data.table(u = ec, f = F0, e = fk, ok = okp)[!is.na(u) & ok == TRUE, .(forest_km2 = sum(f) * 9e-4, flagged_km2 = sum(e) * 9e-4, blocks = .N), by = u]
ut[, name := as.data.frame(uv)[match(sub("^P", "", u), as.character(uv[[us[2]]][, 1])), us[3]]]; U <- sort(ut[flagged_km2 >= as.numeric(opt("min-flagged", 30)) & blocks >= 20, u]); ec[!ec %in% U] <- NA
cat(sprintf("%d units with at least %s km2 of events and 20 blocks (of %d with eligible forest); they hold %.0f%% of the West's events\n", length(U), opt("min-flagged", 30), nrow(ut), 100 * ut[u %in% U, sum(flagged_km2)] / sum(fk * 9e-4)))
`%is%` <- function(x, u) !is.na(x) & x == u
Wm <- sapply(U, function(u) { w <- F0 * (ec %is% u) * okp; w / sum(w) }); umean <- function(M) { M[!okp, ] <- 0; t(crossprod(Wm, M)) }   # months x units
pm <- CJ(y = 1979:2022, m = 1:12); PR <- list(pm = pm, P = umean(K$PP), TX = umean(K$TX), TN = umean(K$TN)); lat <- as.vector(crossprod(Wm, pts[, 2])); names(lat) <- U; rm(K)
FL <- v[keep, as.character(rec_y), drop = FALSE]; FL[is.na(FL)] <- 0; cum <- t(apply(FL, 1, cumsum)); E <- FL[, as.character(yrs)]; N <- pmax(F0 - cum[, as.character(yrs - 1L)], E)
RATE <- sapply(U, function(u) colSums(E[ec %is% u, , drop = FALSE]) / colSums(N[ec %is% u, , drop = FALSE])); rownames(RATE) <- yrs; fw <- sapply(U, function(u) sum(F0[ec %is% u])); REL <- sweep(RATE, 2, colMeans(RATE), "/")
big <- names(sort(colSums(sapply(U, function(u) colSums(E[ec %is% u, , drop = FALSE]))), decreasing = TRUE)); aw <- fw * colMeans(RATE)   # (area weights: forest x mean rate)

# ---- LOCA2 monthly by unit ------------------------------------------------------------------------------------------------------
runs <- rbindlist(lapply(list.dirs(ldir, recursive = FALSE, full.names = FALSE), function(g) rbindlist(lapply(list.dirs(file.path(ldir, g), recursive = FALSE, full.names = FALSE), function(m)
  data.table(gcm = g, member = m, ssp = setdiff(list.dirs(file.path(ldir, g, m), recursive = FALSE, full.names = FALSE), "historical"))))))
runs <- runs[mapply(function(g, m, s) loca2_has_run(ldir, g, m, s), gcm, member, ssp)][, run := paste(gcm, ssp)]
win <- ext(min(pts[, 1]) - 0.2, max(pts[, 1]) + 0.2, min(pts[, 2]) - 0.2, max(pts[, 2]) + 0.2)
lread <- function(g, m, run, var) rbindlist(lapply(seq_len(nrow(fs <- loca2_best(loca2_files(ldir, g, m, run, var), win))), function(i) { x <- crop(loca2_rast(fs$file[i]), win); tm <- time(x); k <- which(as.integer(format(tm, "%Y")) >= 1979)
  if (!length(k)) return(NULL); M <- as.matrix(extract(x[[k]], pts)); if (ncol(M) > length(k)) M <- M[, -1]; okl <- rowSums(is.na(M)) == 0; W <- sapply(U, function(u) { w <- F0 * (ec %is% u) * okl; w / sum(w) }); M[!okl, ] <- 0
  o <- as.data.table(t(crossprod(W, M))); setnames(o, U); cbind(data.table(y = as.integer(format(tm[k], "%Y")), m = as.integer(format(tm[k], "%m"))), o) }))
if (nzchar(cf) && file.exists(cf)) LO <- readRDS(cf) else { hist <- list(); LO <- list()
  for (i in seq_len(nrow(runs))) { t0 <- Sys.time(); g <- runs$gcm[i]; m <- runs$member[i]; if (is.null(hist[[g]])) hist[[g]] <- lapply(c(pr = "pr", tasmax = "tasmax", tasmin = "tasmin"), function(vv) lread(g, m, "historical", vv))
    LO[[runs$run[i]]] <- lapply(c(pr = "pr", tasmax = "tasmax", tasmin = "tasmin"), function(vv) unique(rbind(hist[[g]][[vv]], lread(g, m, runs$ssp[i], vv)), by = c("y", "m"))[order(y, m)])
    cat(sprintf("  %s read in %.1f minutes\n", runs$run[i], as.numeric(difftime(Sys.time(), t0, units = "mins")))) }; if (nzchar(cf)) saveRDS(LO, cf) }
dim_ <- c(31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
# a run as PRISM-like monthly series by the delta method: temperature shifted, precipitation scaled, month by month, to PRISM's 1991-2020
clim <- function(P, TX, TN, mt) list(mt = mt, P = P, TX = TX, TN = TN, TM = (TX + TN) / 2)
PRc <- clim(PR$P, PR$TX, PR$TN, PR$pm); mclim <- function(M, mt) sapply(1:12, function(k) colMeans(M[mt$m == k & mt$y %in% norm, , drop = FALSE]))   # units x 12
LC <- lapply(LO, function(L) { mt <- L$pr[, .(y, m)]; P <- as.matrix(L$pr[, U, with = FALSE]) * 86400 * dim_[mt$m]; TX <- as.matrix(L$tasmax[, U, with = FALSE]) - 273.15; TN <- as.matrix(L$tasmin[, U, with = FALSE]) - 273.15
  fP <- mclim(PRc$P, PRc$mt) / pmax(mclim(P, mt), 1e-6); dX <- mclim(PRc$TX, PRc$mt) - mclim(TX, mt); dN <- mclim(PRc$TN, PRc$mt) - mclim(TN, mt); clim(P * t(fP)[mt$m, ], TX + t(dX)[mt$m, ], TN + t(dN)[mt$m, ], mt) })

# ---- indexes ---------------------------------------------------------------------------------------------------------------------
doy <- c(15, 46, 75, 106, 136, 167, 197, 228, 259, 289, 320, 350); dl <- sapply(1:12, function(m) { dec <- 0.409 * sin(2 * pi * doy[m] / 365 - 1.39); 24 / pi * acos(pmax(-1, pmin(1, -tan(lat * pi / 180) * tan(dec)))) })
Tn <- mclim(PRc$TM, PRc$mt); I <- rowSums((pmax(Tn, 0) / 5)^1.514); al <- 6.75e-7 * I^3 - 7.71e-5 * I^2 + 1.792e-2 * I + 0.49239
# extraterrestrial radiation as mm of evaporation a day (units x 12), for the Hargreaves demand: 0.0023 Ra (T + 17.8) sqrt(Tmax - Tmin)
Ra <- sapply(1:12, function(m) { J <- doy[m]; ph <- lat * pi / 180; dr <- 1 + 0.033 * cos(2 * pi * J / 365); dec <- 0.409 * sin(2 * pi * J / 365 - 1.39); ws <- acos(pmax(-1, pmin(1, -tan(ph) * tan(dec))))
  0.408 * (24 * 60 / pi) * 0.0820 * dr * (ws * sin(ph) * sin(dec) + cos(ph) * cos(dec) * sin(ws)) })
annual <- function(C) { mt <- C$mt; wy <- mt$y + (mt$m >= 10); nU <- length(U); PETt <- sapply(seq_len(nU), function(u) 16 * (10 * pmax(C$TM[, u], 0) / I[u])^al[u] * (dl[u, mt$m] / 12) * (dim_[mt$m] / 30))
  PETh <- sapply(seq_len(nU), function(u) pmax(0, 0.0023 * Ra[u, mt$m] * (C$TM[, u] + 17.8) * sqrt(pmax(C$TX[, u] - C$TN[, u], 0)) * dim_[mt$m]))
  # one soil store of 150 mm with a snow pack (rain share rises from 0 at 0 C to 1 at 6 C; the pack melts by the same share): deficit = demand - actual
  AWC <- 150; soil <- rep(AWC, nU); pack <- rep(0, nU); DEF <- PETh * 0; for (j in seq_len(nrow(mt))) { rf <- pmax(0, pmin(1, C$TM[j, ] / 6)); pack <- pack + C$P[j, ] * (1 - rf); melt <- pack * rf; pack <- pack - melt; w <- C$P[j, ] * rf + melt
    d <- w - PETh[j, ]; wet <- d >= 0; aet <- PETh[j, ]; s1 <- soil; s1[wet] <- pmin(AWC, soil[wet] + d[wet]); dr <- soil[!wet] * (1 - exp(d[!wet] / AWC)); aet[!wet] <- w[!wet] + dr; s1[!wet] <- soil[!wet] - dr; soil <- s1; DEF[j, ] <- PETh[j, ] - aet }
  ys <- sort(unique(wy)); ys <- ys[sapply(ys, function(y) sum(wy == y) == 12)]; f <- function(M, fun) { o <- t(sapply(ys, function(y) fun(M[wy == y, , drop = FALSE]))); dimnames(o) <- list(ys, U); o }
  list(`precipitation` = f(C$P, colSums), `precipitation less demand (Thornthwaite)` = f(C$P - PETt, colSums), `precipitation less demand (Hargreaves)` = f(C$P - PETh, colSums),
       `water deficit (Hargreaves, soil store)` = f(DEF, colSums), `mean temperature` = f(C$TM, colMeans)) }
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
fwrite(hs, file.path(odir, "climate-analog-pyromes-hindcast.csv")); r2 <- function(d) d[, lapply(.SD, function(x) if (is.double(x)) round(x, 2) else x)]
cat(sprintf("%d units, %d-%d. Hindcast skill (1 = perfect, 0 = no better than unweighted draws, below 0 = worse), best kernel width of each index and window:\n", length(U), min(yrs), max(yrs)))
print(r2(hs[, .SD[which.max(Skill)], by = .(Index, Years, Analogs)][order(-Skill)]))
bestS <- hs[, .SD[which.max(Skill)], by = Index][order(-Skill)]; cat("\nbest setting of each index, skill by unit (largest first):\n")
ball <- sapply(seq_len(nrow(bestS)), function(i) hind(idx(AP, bestS$Index[i], bestS$Years[i], yrs), bestS$Width[i], bestS$Analogs[i] == "all units")$by); colnames(ball) <- bestS$Index; bu <- ball[head(big, 12), ]; rownames(bu) <- paste(head(big, 12), substr(ut[match(head(big, 12), u), name], 1, 22)); print(round(bu, 2))
cat("over all units: median skill, and the share of units where the weighted draws beat the unweighted
"); print(round(rbind(median = apply(ball, 2, median), share_better = colMeans(ball > 0)), 2))
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
fwrite(lo, file.path(odir, "climate-analog-pyromes-loca2.csv"))
cat("\nLOCA2: the rate the weighted draws give, as a ratio of the record's mean rate (1 = the empirical method), by period; and the share of forest whose index is outside the record\n")
s <- lo[, .(ratio = mean(ratio), outside = mean(outside), index = mean(index)), by = .(Index, run, period = per(Year))]
print(r2(dcast(s, Index + run ~ period, value.var = c("ratio", "outside", "index"))))
cat("\nthe index's spread between years over 1991-2022, each run against PRISM (West mean):\n"); print(r2(unique(lo[, .(Index, run, hist_sd, prism_sd)])))
cat("the highest ratio the record allows (every draw the unit's worst year):", round(sum(apply(REL, 2, max) * aw) / sum(aw), 2), "; its 5 worst years:", round(sum(apply(REL, 2, function(x) mean(sort(x, decreasing = TRUE)[1:5])) * aw) / sum(aw), 2), "\n")

# ---- figure ----------------------------------------------------------------------------------------------------------------------
cols <- setNames(c("#1b7837", "#e08214", "#b2182b", "#5aae61", "#d6604d")[seq_len(nrow(runs))], runs$run); lty <- setNames(ifelse(runs$gcm == runs$gcm[1], 1, 2), runs$run); sm <- function(x) as.vector(stats::filter(x, rep(1 / 5, 5), sides = 2))
png(file.path(odir, "climate-analog-pyromes.png"), width = 2700, height = 1700, res = 170); par(mfrow = c(2, nrow(bestS)), mar = c(3.2, 4, 3.4, 1), mgp = c(2.2, 0.7, 0))
for (i in seq_len(nrow(bestS))) { nm <- bestS$Index[i]; X <- idx(AP, nm, bestS$Years[i], yrs); xp <- as.vector(X %*% fw) / sum(fw); d <- lo[Index == nm]
  plot(yrs, xp, type = "l", lwd = 3, xlim = c(1991, 2100), ylim = range(d$index, xp), xlab = "", ylab = "index (standard deviations)", main = sprintf("%s, %d years\nblack: PRISM; dotted: the record's range", nm, bestS$Years[i]))
  for (rn in names(AL)) lines(d[run == rn, Year], d[run == rn, index], col = cols[rn], lty = lty[rn], lwd = 1.6); abline(h = range(xp), lty = 3); if (i == 1) legend("bottomleft", names(AL), col = cols, lty = lty, lwd = 2, bty = "n", cex = 0.75) }
for (i in seq_len(nrow(bestS))) { nm <- bestS$Index[i]; d <- lo[Index == nm]; plot(NA, xlim = c(2023, 2100), ylim = range(0, lo$ratio, 1.2), xlab = "", ylab = "rate / the record's mean rate", main = sprintf("rate the weighted draws give (5-year mean)\nhindcast skill %.2f", bestS$Skill[i]))
  abline(h = 1, lty = 2); for (rn in names(AL)) lines(fy, sm(d[run == rn, ratio]), col = cols[rn], lty = lty[rn], lwd = 1.8) }
invisible(dev.off()); cat("\nwritten to", odir, "\n")

# ---- a moving baseline: dry or wet against the surrounding years, not against the record (user, 2026-11-24) --------------------------
# The forest is taken to adjust to the climate it has had: a projection year's index is its value less the mean of the --baseline-years
# (30) around it ("centered") or before it ("trailing"), over the record's own spread; the record is treated the same way. "fixed" is the
# record's 1981-2020 baseline, as above. A window cut short by the ends of a series uses the years it has (at least the 10 nearest).
BWIN <- as.integer(opt("baseline-years", 30))
idxb <- function(A, nm, W, years, mode) { if (mode == "fixed") return(idx(A, nm, W, years)); D <- A[[nm]]; ay <- as.integer(rownames(D)); al <- if (startsWith(mode, "blend:")) as.numeric(sub("blend:", "", mode)) else 1
  Z <- t(sapply(ay, function(y) { w <- intersect(if (mode == "trailing") (y - BWIN):(y - 1L) else (y - BWIN %/% 2L):(y + BWIN %/% 2L - 1L), ay); if (length(w) < 10) w <- ay[order(abs(ay - y))][1:10]
    (D[as.character(y), ] - (al * colMeans(D[as.character(w), , drop = FALSE]) + (1 - al) * mu[[nm]])) / sdv[[nm]] })); dimnames(Z) <- dimnames(D)
  o <- t(sapply(years, function(y) colMeans(Z[as.character((y - W + 1L):y), , drop = FALSE]))); dimnames(o) <- list(years, U); o }
nm0 <- opt("example-index", "water deficit (Hargreaves, soil store)"); W0 <- hs[Index == nm0 & Analogs == "own unit"][which.max(Skill), Years]; hb <- list()
mb <- rbindlist(lapply(c("fixed", "centered", "trailing"), function(mode) { X <- idxb(AP, nm0, W0, yrs, mode); sk <- sapply(c(0.25, 0.5, 1), function(h) hind(X, h, FALSE)$skill); h <- c(0.25, 0.5, 1)[which.max(sk)]; hb[[mode]] <<- h; o <- hind(X, h, FALSE)
  half <- function(k) sum(sapply(U, function(u) cor(X[k, u], RATE[k, u], method = "spearman")) * aw) / sum(aw)
  lr <- rbindlist(lapply(names(AL), function(rn) { Z <- idxb(AL[[rn]], nm0, W0, fy, mode); ex <- sapply(U, function(u) sapply(as.character(fy), function(y) { w <- kern(X[, u] - Z[y, u], h); sum(w * REL[, u]) / sum(w) }))
    out <- sapply(U, function(u) Z[, u] < min(X[, u]) | Z[, u] > max(X[, u])); data.table(run = rn, Year = fy, ratio = as.vector(ex %*% aw) / sum(aw), outside = as.vector(out %*% fw) / sum(fw)) }))
  cbind(data.table(Baseline = mode, Width = h, Skill = max(sk), UnitsBetter = mean(o$by > 0), RankCor_2007_2022 = half(yrs > 2006)), dcast(lr[, .(ratio = mean(ratio)), by = .(run, period = per(Year))], . ~ period, value.var = "ratio", fun.aggregate = mean)[, -1],
        data.table(lowest_run_2071_2100 = lr[Year > 2070, mean(ratio), by = run][, min(V1)], highest_run_2071_2100 = lr[Year > 2070, mean(ratio), by = run][, max(V1)], outside_2071_2100 = lr[Year > 2070, mean(outside)])) }))
cat(sprintf("\nbaselines compared, %s, %d years, all units: hindcast skill; and the LOCA2 rate as a ratio of the record's mean (mean of the runs by period, then the lowest and highest run late in the century)\n", nm0, W0)); print(r2(mb)); fwrite(mb, file.path(odir, "climate-analog-pyromes-baselines.csv"))

# ---- example: one unit's yearly area under the weighted draws (--example=<unit>, --example-index=<index name>) --------------------
exu <- opt("example", ""); if (nzchar(exu) && exu %in% U) { nm <- nm0; W <- W0; BASE <- opt("example-baseline", "fixed"); h <- if (is.null(hb[[BASE]])) 0.25 else hb[[BASE]]
  X <- idxb(AP, nm, W, yrs, BASE)[, exu]; r <- RATE[, exu]; k <- ec %is% exu; km <- 9e-4; obs <- colSums(E[k, , drop = FALSE]) * km; open0 <- sum(pmax(F0[k] - cum[k, "2022"], 0)) * km
  sk <- hind(idxb(AP, nm, W, yrs, BASE), h, FALSE)$by[exu]; set.seed(1); nit <- 500L; BK <- as.integer(opt("example-block", 5))
  sim <- function(Z) { ex <- numeric(length(fy)); dr <- matrix(0, nit, length(fy)); op <- open0; opi <- rep(open0, nit)
    # blocks of BK years drawn together (as 2.0.2: a block starts at any historical year and runs on from the last year to the first);
    # a block's weight falls with the root mean square distance between its years' index and the projection years' it would fill
    nh <- length(r); for (b in seq(1, length(fy), by = BK)) { jj <- b:min(b + BK - 1L, length(fy)); hi <- sapply(seq_len(nh), function(s) (s + seq_along(jj) - 2L) %% nh + 1L); hi <- matrix(hi, nrow = length(jj))   # years of the block x starts
      w <- if (is.null(Z)) rep(1, nh) else kern(sqrt(colMeans((matrix(X[hi], nrow = length(jj)) - Z[jj])^2)), h); w <- w / sum(w); st <- sample.int(nh, nit, TRUE, w)
      for (q in seq_along(jj)) { j <- jj[q]; ex[j] <- op * sum(w * r[hi[q, ]]); op <- op - ex[j]; a <- opi * r[hi[q, st]]; dr[, j] <- a; opi <- opi - a } }; list(ex = ex, dr = dr) }
  s0 <- sim(NULL); ZL <- lapply(AL, function(A) idxb(A, nm, W, fy, BASE)[, exu]); S <- lapply(ZL, sim)
  cat(sprintf("\nexample %s %s: index %s, %d years, baseline %s, kernel %.2f, hindcast skill %.2f; %.0f km2 of eligible forest standing in 2022; observed %d-%d %.1f km2 a year\n", exu, ut[u == exu, name], nm, W, BASE, h, sk, open0, min(yrs), max(yrs), mean(obs)))
  tt <- rbind(data.table(run = "unweighted draws (2.0.2)", km2_per_year = mean(s0$ex), total_2023_2100 = sum(s0$ex), p10 = quantile(rowSums(s0$dr), 0.1), p90 = quantile(rowSums(s0$dr), 0.9)),
              rbindlist(lapply(names(S), function(n) data.table(run = n, km2_per_year = mean(S[[n]]$ex), total_2023_2100 = sum(S[[n]]$ex), p10 = quantile(rowSums(S[[n]]$dr), 0.1), p90 = quantile(rowSums(S[[n]]$dr), 0.9)))))
  print(tt[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 1) else x)]); fwrite(tt, file.path(odir, sprintf("climate-analog-example-%s-block%d-%s.csv", exu, BK, BASE)))
  png(file.path(odir, sprintf("climate-analog-example-%s-block%d-%s.png", exu, BK, BASE)), width = 2400, height = 1900, res = 190); layout(matrix(1:3, 3), heights = c(1, 1.25, 1.25)); par(mar = c(2.5, 4.5, 2.6, 1), mgp = c(2.4, 0.7, 0))
  plot(yrs, X, type = "l", lwd = 3, xlim = c(1991, 2100), ylim = range(X, unlist(ZL)), xlab = "", ylab = "index (SD)", main = sprintf("%s (%s): %s, mean of %d years, %s baseline. Black: PRISM; dotted: the record's range", ut[u == exu, name], exu, nm, W, BASE), cex.main = 1)
  for (n in names(ZL)) lines(fy, ZL[[n]], col = cols[n], lty = lty[n], lwd = 1.6); abline(h = range(X), lty = 3); legend("topleft", names(ZL), col = cols, lty = lty, lwd = 2, bty = "n", cex = 0.8, ncol = 2)
  ym <- max(obs, sapply(S, function(s) max(s$ex)), quantile(s0$dr, 0.9)) * 1.05
  plot(yrs, obs, type = "h", lwd = 5, lend = 1, col = "grey60", xlim = c(1991, 2100), ylim = c(0, ym), xlab = "", ylab = "km2 per year", main = sprintf("Mean yearly area over the iterations, blocks of %d years. Grey bars: observed; dashed: unweighted draws (2.0.2); colours: drought-weighted draws", BK), cex.main = 1)
  lines(fy, s0$ex, lty = 2, lwd = 2); for (n in names(S)) lines(fy, S[[n]]$ex, col = cols[n], lty = lty[n], lwd = 1.6)
  one <- names(S)[1]; q <- apply(S[[one]]$dr, 2, quantile, c(0.1, 0.5, 0.9)); ym2 <- max(obs, q[3, ], S[[one]]$dr[1, ]) * 1.05
  plot(yrs, obs, type = "h", lwd = 5, lend = 1, col = "grey60", xlim = c(1991, 2100), ylim = c(0, ym2), xlab = "", ylab = "km2 per year", main = sprintf("What single iterations look like (%s): band = 10th to 90th percentile of %d iterations, green = one iteration, black = the mean", one, nit), cex.main = 1)
  polygon(c(fy, rev(fy)), c(q[1, ], rev(q[3, ])), col = adjustcolor(cols[one], 0.25), border = NA); lines(fy, S[[one]]$dr[1, ], col = cols[one], lwd = 1.3); lines(fy, S[[one]]$ex, lwd = 2)
  invisible(dev.off()); cat("written", file.path(odir, sprintf("climate-analog-example-%s-block%d-%s.png", exu, BK, BASE)), "\n") }

# ---- partial adjustment: the baseline moves only part of the way (--alphas; 0 = the record's baseline, 1 = the surrounding years) -----
# "blend:a": the index is the value less (a x the mean of the surrounding years + (1 - a) x the record's mean). The forest adjusts to
# a share a of a change in climate; the rest of a drying trend still reaches the draws.
ALS <- as.numeric(strsplit(opt("alphas", "0,0.25,0.5,0.75,1"), ",")[[1]]); late <- function(d) d[Year > 2070, mean(ratio), by = run]
ab <- rbindlist(lapply(ALS, function(al) { mode <- sprintf("blend:%g", al); X <- idxb(AP, nm0, W0, yrs, mode); sk <- sapply(c(0.25, 0.5, 1), function(h) hind(X, h, FALSE)$skill); h <- c(0.25, 0.5, 1)[which.max(sk)]
  lr <- rbindlist(lapply(names(AL), function(rn) { Z <- idxb(AL[[rn]], nm0, W0, fy, mode); ex <- sapply(U, function(u) sapply(as.character(fy), function(y) { w <- kern(X[, u] - Z[y, u], h); sum(w * REL[, u]) / sum(w) }))
    out <- sapply(U, function(u) Z[, u] < min(X[, u]) | Z[, u] > max(X[, u])); data.table(run = rn, Year = fy, ratio = as.vector(ex %*% aw) / sum(aw), outside = as.vector(out %*% fw) / sum(fw)) }))
  cbind(data.table(Adjusts = al, Width = h, Skill = max(sk)), dcast(lr[, .(ratio = mean(ratio)), by = .(run, period = per(Year))], . ~ period, value.var = "ratio", fun.aggregate = mean)[, -1],
        data.table(lowest_run_late = min(late(lr)$V1), highest_run_late = max(late(lr)$V1), outside_late = lr[Year > 2070, mean(outside)])) }))
cat(sprintf("\npartial adjustment of the baseline, %s, %d years, all units (Adjusts: 0 = the record's baseline, 1 = the surrounding years); LOCA2 rate as a ratio of the record's mean\n", nm0, W0)); print(r2(ab)); fwrite(ab, file.path(odir, "climate-analog-pyromes-adjust.csv"))
# the example unit, in blocks of --example-block years (1 = single years). Each iteration starts its first block at a different point
# (a random first block of 1 to BK years), so iterations do not all change block in the same year; the mean is over those starts too.
if (nzchar(exu) && exu %in% U) { r <- RATE[, exu]; k <- ec %is% exu; km <- 9e-4; obs <- colSums(E[k, , drop = FALSE]) * km; open0 <- sum(pmax(F0[k] - cum[k, "2022"], 0)) * km; acol <- hcl.colors(length(ALS) + 1, "YlOrRd")[seq_along(ALS)]
  BK <- as.integer(opt("example-block", 5)); nh <- length(r); nf <- length(fy); nit <- 500L
  blocks <- function(first) { st <- unique(c(1L, seq(first + 1L, nf, by = BK))); lapply(seq_along(st), function(q) st[q]:(if (q < length(st)) st[q + 1L] - 1L else nf)) }
  # --example-pool=all: the blocks of every unit are candidates, as rates relative to their unit's mean, scaled to this unit's mean
  # --example-pool=scale: the unit's own blocks, drawn with equal chances as in 2.0.2; each drawn year's rate is multiplied by the pooled
  # curve (the mean relative rate of all unit-years at that index, smoothed, 1 on average over the record) at the projection year's index.
  # The curve is held at its end values beyond the 5th and 95th percentiles of the record's index, so the multiplier is bounded.
  PM <- opt("example-pool", "own"); POOL <- PM == "all"; SCALE <- PM == "scale"; mr <- mean(RATE[, exu]); ptag <- if (POOL) "-pooled" else if (SCALE) "-scaled" else ""
  CH <- as.numeric(opt("curve-width", 0.3)); cvs <- new.env()
  curve1 <- function(X) { key <- sprintf("%.10f", sum(X)); if (is.null(cvs[[key]])) { xv <- as.vector(X); rv <- as.vector(REL); lim <- quantile(xv, c(0.05, 0.95)); g <- seq(lim[1], lim[2], length.out = 41)
      m <- sapply(g, function(z) { w <- kern(xv - z, CH); sum(w * rv) / sum(w) }); f <- approxfun(g, m, rule = 2); cvs[[key]] <- approxfun(g, m / mean(f(xv)), rule = 2) }; cvs[[key]] }
  bw <- function(X, Z, jj, h) { hi <- matrix(sapply(seq_len(nh), function(s) (s + seq_along(jj) - 2L) %% nh + 1L), nrow = length(jj)); vs <- if (POOL) U else exu
    if (SCALE) return(list(R = pmin(matrix(RATE[, exu][hi], nrow = length(jj)) * curve1(X)(Z[jj]), 1), w = rep(1 / nh, nh)))
    d <-sapply(vs, function(v) sqrt(colMeans((matrix(X[hi, v], nrow = length(jj)) - Z[jj])^2))); w <- kern(as.vector(d), h)
    R <- do.call(cbind, lapply(vs, function(v) matrix((if (POOL) REL[, v] * mr else RATE[, v])[hi], nrow = length(jj)))); list(R = R, w = w / sum(w)) }
  expect <- function(X, Z, h) rowMeans(sapply(seq_len(BK), function(first) { e <- numeric(nf); op <- open0; for (jj in blocks(first)) { b <- bw(X, Z, jj, h); for (q in seq_along(jj)) { e[jj[q]] <- op * sum(b$w * b$R[q, ]); op <- op - e[jj[q]] } }; e }))
  draw <- function(X, Z, h) { set.seed(1); t(sapply(seq_len(nit), function(it) { e <- numeric(nf); op <- open0; for (jj in blocks(sample.int(BK, 1))) { b <- bw(X, Z, jj, h); s <- sample.int(length(b$w), 1, prob = b$w); for (q in seq_along(jj)) { e[jj[q]] <- op * b$R[q, s]; op <- op - e[jj[q]] } }; e })) }
  XA <- lapply(ALS, function(al) idxb(AP, nm0, W0, yrs, sprintf("blend:%g", al))); ZA <- lapply(ALS, function(al) sapply(names(AL), function(rn) idxb(AL[[rn]], nm0, W0, fy, sprintf("blend:%g", al))[, exu]))
  if (POOL) { cat("\nthe pooled relation: mean relative rate (1 = a unit's own mean) of the unit-years in each fifth of the index, driest last\n")
    print(r2(rbindlist(lapply(seq_along(ALS), function(q) { X <- as.vector(XA[[q]]); b <- cut(X, quantile(X, 0:5 / 5), include.lowest = TRUE, labels = paste0("fifth_", 1:5)); as.data.table(c(list(Adjusts = ALS[q]), as.list(tapply(as.vector(REL), b, mean)), list(index_range = sprintf("%.2f to %.2f", min(X), max(X))))) })))) }
  if (SCALE) { cat(sprintf("\nthe pooled curve (multiplier on the drawn rate; kernel %.2f) at the record's index percentiles, and its range over the projection years of the runs\n", CH))
    print(r2(rbindlist(lapply(seq_along(ALS), function(q) { f <- curve1(XA[[q]]); p <- quantile(as.vector(XA[[q]]), c(0.05, 0.25, 0.5, 0.75, 0.95)); zz <- f(as.vector(ZA[[q]])); as.data.table(c(list(Adjusts = ALS[q]), setNames(as.list(f(p)), paste0("p", c(5, 25, 50, 75, 95))), list(proj_mean = mean(zz), proj_late = mean(f(as.vector(ZA[[q]][fy > 2070, ]))), proj_share_at_top = mean(as.vector(ZA[[q]]) >= p[5])))) })))) }
  ea <- lapply(seq_along(ALS), function(q) sapply(names(AL), function(rn) expect(XA[[q]], ZA[[q]][, rn], ab[Adjusts == ALS[q], Width]))); names(ea) <- ALS
  et <- rbindlist(lapply(names(ea), function(a1) data.table(Adjusts = as.numeric(a1), run = colnames(ea[[a1]]), `2023-2040` = colMeans(ea[[a1]][fy <= 2040, ]), `2041-2070` = colMeans(ea[[a1]][fy > 2040 & fy <= 2070, ]), `2071-2100` = colMeans(ea[[a1]][fy > 2070, ]), total = colSums(ea[[a1]]))))
  cat(sprintf("\n%s %s, blocks of %d years: mean yearly area (km2) by how far the baseline adjusts; mean of the runs, then the lowest and highest run's total 2023-2100 (unweighted draws: %.1f km2 a year, observed %.1f)\n", exu, ut[u == exu, name], BK, mean(RATE[, exu]) * open0, mean(obs)))
  print(r2(et[, .(`2023-2040` = mean(`2023-2040`), `2041-2070` = mean(`2041-2070`), `2071-2100` = mean(`2071-2100`), total_low = min(total), total_high = max(total), pct_of_forest_high = 100 * max(total) / open0), by = Adjusts])); fwrite(et, file.path(odir, sprintf("climate-analog-example-%s-adjust-block%d%s.csv", exu, BK, ptag)))
  sm5 <- function(v) as.vector(stats::filter(v, rep(1 / 5, 5), sides = 2)); ia <- as.numeric(strsplit(opt("example-alphas", "0,0.5,1"), ",")[[1]]); ia <- ia[ia %in% ALS]; one <- names(AL)[1]
  png(file.path(odir, sprintf("climate-analog-example-%s-adjust-block%d%s.png", exu, BK, ptag)), width = 2400, height = 1150 + 620 * length(ia), res = 190); layout(matrix(seq_len(1 + length(ia)), ncol = 1), heights = c(1.5, rep(1, length(ia)))); par(mar = c(2.6, 4.5, 3.2, 1), mgp = c(2.4, 0.7, 0))
  plot(yrs, obs, type = "h", lwd = 5, lend = 1, col = "grey60", xlim = c(1991, 2100), ylim = c(0, max(obs)), xlab = "", ylab = "km2 per year", main = sprintf("%s (%s), blocks of %d years%s: mean yearly area by how far the baseline adjusts to the changing climate\nband = range of the %d climate runs, line = their mean (5-year running mean); grey = observed; dashed = unweighted draws", ut[u == exu, name], exu, BK, if (POOL) ", draws pooled over all pyromes" else if (SCALE) ", own blocks scaled by the pooled drought curve" else "", length(AL)), cex.main = 0.95)
  for (q in rev(seq_along(ALS))) { M <- apply(ea[[q]], 2, sm5); ok <- !is.na(M[, 1]); polygon(c(fy[ok], rev(fy[ok])), c(apply(M[ok, ], 1, min), rev(apply(M[ok, ], 1, max))), col = adjustcolor(acol[q], 0.3), border = NA); lines(fy[ok], rowMeans(M[ok, ]), col = acol[q], lwd = 2.2) }
  abline(h = mean(RATE[, exu]) * open0, lty = 2); legend("topleft", sprintf("adjusts %g%%%s", 100 * ALS, ifelse(ALS == 0, " (the record's baseline)", ifelse(ALS == 1, " (the surrounding years)", ""))), col = acol, lwd = 3, bty = "n", cex = 0.85)
  for (al in ia) { q <- match(al, ALS); D <- draw(XA[[q]], ZA[[q]][, one], ab[Adjusts == al, Width]); qq <- apply(D, 2, quantile, c(0.1, 0.9)); pk <- apply(D, 1, max)
    cat(sprintf("iterations, adjusts %g%% (%s): highest year of an iteration, median %.1f km2, 90th percentile %.1f (observed highest %.1f); total 2023-2100 mean %.0f (%.0f to %.0f)\n", 100 * al, one, median(pk), quantile(pk, 0.9), max(obs), mean(rowSums(D)), quantile(rowSums(D), 0.1), quantile(rowSums(D), 0.9)))
    plot(yrs, obs, type = "h", lwd = 5, lend = 1, col = "grey60", xlim = c(1991, 2100), ylim = c(0, max(obs)), xlab = "", ylab = "km2 per year", main = sprintf("Iterations, adjusts %g%% (%s): band = 10th to 90th percentile of %d, thin line = one iteration, thick = the mean; total 2023-2100: %.0f km2 (%.0f to %.0f)", 100 * al, one, nit, mean(rowSums(D)), quantile(rowSums(D), 0.1), quantile(rowSums(D), 0.9)), cex.main = 0.9)
    polygon(c(fy, rev(fy)), c(qq[1, ], rev(qq[2, ])), col = adjustcolor(acol[q], 0.35), border = NA); lines(fy, D[1, ], col = "grey25", lwd = 1); lines(fy, colMeans(D), col = acol[q], lwd = 2.6) }
  invisible(dev.off()); cat("written", sprintf("climate-analog-example-%s-adjust-block%d%s.png", exu, BK, ptag), "\n") }

# ---- timing only (--example-timing=0,0.3,0.6,1): the blocks of 2.0.2, placed by dryness -------------------------------------------------
# Each iteration draws its blocks of the unit's own record with equal chances, exactly as 2.0.2 does. The blocks are then placed in time:
# a period's score is rho x its dryness (the index against the surrounding years, standardised over the periods) + sqrt(1 - rho^2) x noise,
# and the most severe drawn block goes to the highest score. rho = 0 is 2.0.2 (random order); rho = 1 puts the worst block in the driest
# period. The set of blocks in an iteration is the same at every rho (same seed), so totals change only through the order forest is used.
TR <- opt("example-timing", ""); if (nzchar(TR) && nzchar(exu) && exu %in% U) { rhos <- as.numeric(strsplit(TR, ",")[[1]]); q1 <- match(1, ALS); zs <- function(v) if (length(v) > 1 && sd(v) > 0) (v - mean(v)) / sd(v) else v * 0
  rmB <- function(v) { o <- as.vector(stats::filter(v, rep(1 / BK, BK), sides = 1)); o[!is.na(o)] }
  rc <- sapply(U, function(u) cor(rmB(XA[[q1]][, u]), rmB(REL[, u]), method = "spearman"))
  cat(sprintf("\ntiming only, %s: what the record shows. Rank correlation of %d-year mean dryness (against the surrounding years) with %d-year mean mortality: all units (forest-weighted) %.2f, units above zero %.0f%%, this unit %.2f\n", exu, BK, BK, sum(rc * aw) / sum(aw), 100 * mean(rc > 0), rc[exu]))
  # the amount knob (--example-amount=0,0.25,0.5,1): the drawn rate of a year is raised by A x the depth of the dry period it falls in. Depth = the
  # year's dryness above zero, as a share of the deepest dryness of the unit's record (1 = as deep as the record's worst), held at --depth-cap (2).
  DREF <- max(XA[[match(1, ALS)]][, exu]); DCAP <- as.numeric(opt("depth-cap", 2)); depth <- function(Z) pmin(pmax(Z, 0) / DREF, DCAP)
  tdraw <- function(Z, rho, A = 0) { dep <- depth(Z); set.seed(1); t(sapply(seq_len(nit), function(it) { bl <- blocks(sample.int(BK, 1)); s <- sample.int(nh, length(bl), replace = TRUE); full <- which(lengths(bl) == BK); nz <- rnorm(length(full))
    sev <- sapply(s[full], function(a) mean(r[(a + 0:(BK - 1L) - 1L) %% nh + 1L])); dry <- sapply(bl[full], function(jj) mean(Z[jj])); s2 <- s; s2[full[order(rho * zs(dry) + sqrt(1 - rho^2) * nz)]] <- s[full][order(sev)]
    e <- numeric(nf); op <- open0; for (b in seq_along(bl)) { jj <- bl[[b]]; for (q in seq_along(jj)) { e[jj[q]] <- op * min(1, r[(s2[b] + q - 2L) %% nh + 1L] * (1 + A * dep[jj[q]])); op <- op - e[jj[q]] } }; e })) }
  Z1 <- ZA[[q1]]; tt <- rbindlist(lapply(rhos, function(rho) rbindlist(lapply(colnames(Z1), function(rn) { D <- tdraw(Z1[, rn], rho); z <- Z1[, rn]; th <- quantile(z, c(1, 2) / 3); m <- colMeans(D)
    data.table(rho = rho, run = rn, mean_km2 = mean(D), total_p10 = quantile(rowSums(D), 0.1), total_p90 = quantile(rowSums(D), 0.9), peak_median = median(apply(D, 1, max)), wettest_third = mean(m[z <= th[1]]), middle_third = mean(m[z > th[1] & z <= th[2]]), driest_third = mean(m[z > th[2]])) }))))
  tt[, dry_to_wet := driest_third / wettest_third]; cat("by run: mean yearly area, the 10th and 90th percentile iteration's total, the median iteration's highest year, and mean yearly area in the wettest, middle and driest third of the run's projection years\n"); print(r2(tt), nrows = 200)
  cat("mean of the runs\n"); print(r2(tt[, lapply(.SD, mean), by = rho, .SDcols = -"run"])); fwrite(tt, file.path(odir, sprintf("climate-analog-example-%s-timing-block%d.csv", exu, BK)))
  tcol <- hcl.colors(length(rhos) + 1, "Viridis")[seq_along(rhos)]; z <- Z1[, one]
  png(file.path(odir, sprintf("climate-analog-example-%s-timing-block%d.png", exu, BK)), width = 2400, height = 800 + 620 * length(rhos), res = 190); layout(matrix(seq_len(1 + length(rhos)), ncol = 1), heights = c(1.1, rep(1, length(rhos)))); par(mar = c(2.6, 4.5, 3.2, 1), mgp = c(2.4, 0.7, 0))
  zh <- XA[[q1]][, exu]
  plot(fy, z, type = "n", xlim = c(1991, 2100), ylim = range(z, zh), xlab = "", ylab = "dryness (SD)", main = sprintf("%s (%s), timing only, blocks of %d years: dryness against the surrounding years (to 2022 the record, PRISM; then %s)\nbrown = drier than the surrounding years, blue = wetter; the same blocks are drawn at every setting, only their order changes", ut[u == exu, name], exu, BK, one), cex.main = 0.95)
  segments(yrs, 0, yrs, zh, lwd = 5, lend = 1, col = ifelse(zh > 0, "#B5651D", "#4F81BD")); segments(fy, 0, fy, z, lwd = 5, lend = 1, col = ifelse(z > 0, "#B5651D", "#4F81BD")); abline(h = 0); abline(v = 2022.5, lty = 3)
  for (i in seq_along(rhos)) { D <- tdraw(z, rhos[i]); qq <- apply(D, 2, quantile, c(0.1, 0.9)); m <- colMeans(D)
    plot(yrs, obs, type = "h", lwd = 5, lend = 1, col = "grey60", xlim = c(1991, 2100), ylim = c(0, max(obs)), xlab = "", ylab = "km2 per year", main = sprintf("Strength %.1f%s: band = 10th to 90th percentile of %d iterations, thin line = one iteration, thick = the mean; total 2023-2100: %.0f km2 (%.0f to %.0f)", rhos[i], if (rhos[i] == 0) " (2.0.2, random order)" else "", nit, mean(rowSums(D)), quantile(rowSums(D), 0.1), quantile(rowSums(D), 0.9)), cex.main = 0.9)
    polygon(c(fy, rev(fy)), c(qq[1, ], rev(qq[2, ])), col = adjustcolor(tcol[i], 0.3), border = NA); lines(fy, D[1, ], col = "grey25", lwd = 1); lines(fy, m, col = tcol[i], lwd = 2.6) }
  invisible(dev.off()); cat("written", sprintf("climate-analog-example-%s-timing-block%d.png", exu, BK), "\n")
  AM <- opt("example-amount", ""); if (nzchar(AM)) { As <- as.numeric(strsplit(AM, ",")[[1]]); r0 <- as.numeric(strsplit(opt("example-amount-strengths", "0,0.3"), ",")[[1]])
    cat(sprintf("\namount knob, %s: depth of the dry periods (1 = the record's deepest, %.2f SD; held at %g). Share of projection years in a dry period and their mean depth, by run\n", exu, DREF, DCAP))
    print(r2(rbindlist(lapply(colnames(Z1), function(rn) { d <- depth(Z1[, rn]); data.table(run = rn, dry_years = mean(d > 0), mean_depth_dry = mean(d[d > 0]), mean_depth_all = mean(d), deepest = max(d)) }))))
    at <- rbindlist(lapply(r0, function(rho) rbindlist(lapply(As, function(A) rbindlist(lapply(colnames(Z1), function(rn) { D <- tdraw(Z1[, rn], rho, A); zz <- Z1[, rn]; th <- quantile(zz, c(1, 2) / 3); m <- colMeans(D)
      data.table(strength = rho, amount = A, run = rn, mean_km2 = mean(D), total = mean(rowSums(D)), total_p10 = quantile(rowSums(D), 0.1), total_p90 = quantile(rowSums(D), 0.9), peak_median = median(apply(D, 1, max)), wettest_third = mean(m[zz <= th[1]]), driest_third = mean(m[zz > th[2]])) }))))))
    base <- at[strength == 0 & amount == 0, .(run, t0 = total)]; at <- merge(at, base, by = "run")[, pct_more := 100 * (total / t0 - 1)][, t0 := NULL][order(strength, amount, run)]
    cat("by strength and amount: mean of the runs, then the lowest and highest run's increase in the total over 2.0.2 (%)\n")
    print(r2(at[, .(mean_km2 = mean(mean_km2), total = mean(total), pct_more = mean(pct_more), pct_more_low_run = min(pct_more), pct_more_high_run = max(pct_more), peak_median = mean(peak_median), driest_to_wettest = mean(driest_third / wettest_third), pct_of_forest = 100 * mean(total) / open0), by = .(strength, amount)]))
    fwrite(at, file.path(odir, sprintf("climate-analog-example-%s-amount-block%d.csv", exu, BK))); rs <- as.numeric(opt("example-amount-chart-strength", 0.3)); acl <- hcl.colors(length(As) + 1, "YlOrRd", rev = TRUE)[-1]
    DD <- lapply(As, function(A) tdraw(z, rs, A)); ymx <- max(obs, sapply(DD, function(D) quantile(D, 0.999)))
    png(file.path(odir, sprintf("climate-analog-example-%s-amount-block%d.png", exu, BK)), width = 2400, height = 800 + 620 * length(As), res = 190); layout(matrix(seq_len(1 + length(As)), ncol = 1), heights = c(1.1, rep(1, length(As)))); par(mar = c(2.6, 4.5, 3.2, 1), mgp = c(2.4, 0.7, 0))
    plot(fy, z, type = "n", xlim = c(1991, 2100), ylim = range(z, zh), xlab = "", ylab = "dryness (SD)", main = sprintf("%s (%s), timing strength %.1f, blocks of %d years: dryness against the surrounding years (to 2022 the record, PRISM; then %s)\ndashed = the record's deepest dry period (depth 1); a year's rate is raised by the amount x its depth", ut[u == exu, name], exu, rs, BK, one), cex.main = 0.95)
    segments(yrs, 0, yrs, zh, lwd = 5, lend = 1, col = ifelse(zh > 0, "#B5651D", "#4F81BD")); segments(fy, 0, fy, z, lwd = 5, lend = 1, col = ifelse(z > 0, "#B5651D", "#4F81BD")); abline(h = 0); abline(v = 2022.5, lty = 3); abline(h = DREF, lty = 2)
    for (i in seq_along(As)) { D <- DD[[i]]; qq <- apply(D, 2, quantile, c(0.1, 0.9))
      plot(yrs, obs, type = "h", lwd = 5, lend = 1, col = "grey60", xlim = c(1991, 2100), ylim = c(0, ymx), xlab = "", ylab = "km2 per year", main = sprintf("Amount +%g%% at the record's deepest dry period%s: band = 10th to 90th percentile of %d iterations, thin = one iteration, thick = the mean; total 2023-2100: %.0f km2 (%.0f to %.0f)", 100 * As[i], if (As[i] == 0) " (timing only)" else "", nit, mean(rowSums(D)), quantile(rowSums(D), 0.1), quantile(rowSums(D), 0.9)), cex.main = 0.9)
      polygon(c(fy, rev(fy)), c(qq[1, ], rev(qq[2, ])), col = adjustcolor(acl[i], 0.3), border = NA); lines(fy, D[1, ], col = "grey25", lwd = 1); lines(fy, colMeans(D), col = acl[i], lwd = 2.6) }
    invisible(dev.off()); cat("written", sprintf("climate-analog-example-%s-amount-block%d.png", exu, BK), "\n") }
  }

# ---- lag test (--lag-test=yes): does mortality follow dryness some years later? ---------------------------------------------------------
# Dryness of a year = the index less the mean of the --baseline-years around it, over the record's spread (PRISM, water years from 1980).
# For a window of W years ending L years before the mortality year, the rank correlation with the unit's yearly rate, unit by unit, then
# forest-weighted; and the mean relative rate of the driest third of unit-years over the wettest third. The same mortality years are used at
# every lag (1996 on, so the longest window and lag fit). Negative lags (dryness AFTER the mortality) are the placebo: a lag that scores
# no better than they do is not evidence. "Centre" = L + (W - 1) / 2, the years from the middle of the window to the mortality year.
if (opt("lag-test", "") == "yes") { D <- AP[[nm0]]; ay <- as.integer(rownames(D)); EX <- intersect(strsplit(opt("lag-units", "P27,P47,P45"), ",")[[1]], U)
  Zd <- t(sapply(ay, function(y) { w <- intersect((y - BWIN %/% 2L):(y + BWIN %/% 2L - 1L), ay); (D[as.character(y), ] - colMeans(D[as.character(w), , drop = FALSE])) / sdv[[nm0]] })); dimnames(Zd) <- dimnames(D)
  ecb <- WEST[as.character(ev[keep])]; ecoU <- sapply(U, function(u) { t1 <- tapply(F0[ec %is% u], ecb[ec %is% u], sum); names(t1)[which.max(t1)] }); WS <- c(1L, 3L, 5L, 7L)
  cat(sprintf("\nlag test, %s, PRISM %d-%d. Units by ecodivision (number, share of the weight):\n", nm0, min(ay), max(ay))); print(r2(data.table(eco = ecoU, w = aw)[, .(units = .N, weight = sum(w) / sum(aw)), by = eco][order(-weight)]))
  xl <- function(W, L, years) { o <- t(sapply(years, function(y) colMeans(Zd[as.character((y - L - W + 1L):(y - L)), , drop = FALSE]))); dimnames(o) <- list(years, U); o }
  scan <- function(years, lags) rbindlist(lapply(WS, function(W) rbindlist(lapply(lags, function(L) { X <- xl(W, L, years); R <- sweep(RATE[as.character(years), ], 2, colMeans(RATE[as.character(years), ]), "/")
    rc <- sapply(U, function(u) cor(X[, u], R[, u], method = "spearman")); th <- quantile(as.vector(X), c(1, 2) / 3)
    as.data.table(c(list(Window = W, Lag = L, Centre = L + (W - 1) / 2, cor = sum(rc * aw) / sum(aw), units_above_zero = mean(rc > 0), driest_to_wettest = mean(R[X > th[2]]) / mean(R[X <= th[1]])),
                    as.list(tapply(rc * aw, ecoU, sum) / tapply(aw, ecoU, sum)), as.list(setNames(rc[EX], EX)))) }))))
  ym <- (min(ay) + 10L + 7L - 1L):2022; main <- scan(ym, 0:10); plac <- scan(ym[ym <= 2018], -4:10)
  cat(sprintf("\nmortality years %d-%d, lags 0 to 10 (cor = forest-weighted rank correlation; then by ecodivision; then the example units)\n", min(ym), max(ym))); print(r2(main), nrows = 200)
  cat(sprintf("\nwith the placebo (negative lags), mortality years %d-2018\n", min(ym))); print(r2(plac[, .(Window, Lag, Centre, cor, units_above_zero, driest_to_wettest)]), nrows = 200)
  fwrite(main, file.path(odir, "climate-lag-test.csv")); fwrite(plac, file.path(odir, "climate-lag-test-placebo.csv"))
  wc <- hcl.colors(length(WS) + 1, "Viridis")[seq_along(WS)]; es <- names(sort(tapply(aw, ecoU, sum), decreasing = TRUE)); es <- es[seq_len(min(5, length(es)))]; ecl <- hcl.colors(length(es), "Dark 3")
  png(file.path(odir, "climate-lag-test.png"), width = 2400, height = 2500, res = 190); layout(matrix(1:3, 3)); par(mar = c(4, 4.5, 3.2, 1), mgp = c(2.4, 0.7, 0))
  plot(NA, xlim = range(plac$Lag), ylim = range(plac$cor, 0), xlab = "years from the end of the dryness window to the mortality year (negative = dryness after the mortality: the placebo)", ylab = "rank correlation", main = sprintf("Dryness and mortality by lag, all %d pyromes (forest-weighted), mortality years %d-2018; one line per window length", length(U), min(ym)), cex.main = 1)
  rect(par("usr")[1], par("usr")[3], -0.5, par("usr")[4], col = "grey93", border = NA); abline(h = 0); for (i in seq_along(WS)) lines(plac[Window == WS[i], Lag], plac[Window == WS[i], cor], col = wc[i], lwd = 2.5, type = "b", pch = 16); legend("topleft", sprintf("%d-year window", WS), col = wc, lwd = 3, bty = "n")
  W1 <- as.integer(opt("lag-window", 3)); m1 <- main[Window == W1]
  plot(NA, xlim = c(0, 10), ylim = range(unlist(m1[, ..es]), m1$cor, 0), xlab = "lag (years)", ylab = "rank correlation", main = sprintf("By ecodivision, %d-year window, mortality years %d-2022 (black = all pyromes)", W1, min(ym)), cex.main = 1); abline(h = 0)
  for (i in seq_along(es)) lines(m1$Lag, m1[[es[i]]], col = ecl[i], lwd = 2.2, type = "b", pch = 16); lines(m1$Lag, m1$cor, lwd = 3.5); legend("topleft", sprintf("%s (%d pyromes)", es, as.integer(table(ecoU)[es])), col = ecl, lwd = 3, bty = "n", ncol = 2)
  xc <- hcl.colors(length(EX), "Dark 3"); plot(NA, xlim = c(0, 10), ylim = range(unlist(m1[, ..EX]), 0), xlab = "lag (years)", ylab = "rank correlation", main = sprintf("The example pyromes, %d-year window", W1), cex.main = 1); abline(h = 0)
  for (i in seq_along(EX)) lines(m1$Lag, m1[[EX[i]]], col = xc[i], lwd = 2.5, type = "b", pch = 16); legend("topleft", sprintf("%s %s", EX, ut[match(EX, u), name]), col = xc, lwd = 3, bty = "n")
  invisible(dev.off()); cat("written climate-lag-test.png\n") }
