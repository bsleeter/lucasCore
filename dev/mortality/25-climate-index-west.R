# =============================================================================
# 25-climate-index-west.R - to-do 3, climate method: which climate indexes track drought and insect mortality across the West?
# =============================================================================
# The national rule's 300 m tally (17-rule-national.R with the fitted lines: eligible softwood forest and pixels flagged per year,
# 1990-2022) is summed to blocks of --block cells (20 = 6 km) in the western ecodivisions, and PRISM 800 m monthly precipitation and
# maximum and minimum temperature are averaged to about the same size. Per block and water year (October to September) the
# candidate indexes of 24-climate-index-look.R are built as z-scores of the block against its own years, each as a mean of 1-4
# years ending 0-3 years before the event year. Every index can be made from monthly precipitation and temperature (all LOCA2 has).
# A logistic model of flagged pixels on the open forest, with an intercept for each ecodivision, scores them:
#   Share       what the index explains of the gap between "each ecodivision at its mean rate" and "each ecodivision and year free"
#               (the second is what the empirical method replays); Local = the block's own index, Unit = the ecodivision's mean
#   AfterTrend  the same once each ecodivision has its own straight trend in the year
#   HeldOut     the slope fitted without an ecodivision, applied to it (its mean rate kept), same scale; pooled over ecodivisions
#   Later       fitted on 1991-2006 and applied to 2007-2022: predicted area as a ratio of the observed, against the ratio the
#               1991-2006 mean rate gives (what a no-climate projection from that period would have said)
# Pairs of indexes are scored the same way. The water balance is crude (Thornthwaite, one 150 mm store, snow by temperature).
# Usage: Rscript dev/mortality/25-climate-index-west.R <rule-national-300m.tif> <ecodiv.gpkg> <PRISM monthly folder> <out folder>
#          [--block=20] [--min-forest=0.05] [--workers=16] [--cache=<rds>]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra); library(parallel) }); options(width = 230); terraOptions(progress = 0)
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; rf <- pos[1]; ef <- pos[2]; pdir <- pos[3]; odir <- pos[4]; dir.create(odir, showWarnings = FALSE, recursive = TRUE)
BL <- as.integer(opt("block", 20)); MINF <- as.numeric(opt("min-forest", 0.05)); NW <- as.integer(opt("workers", 16)); cf <- opt("cache", "")
WEST <- c(`240` = "240", `260` = "260", `310` = "310", `320` = "320", `330` = "330", `340` = "340", `2401` = "M240", `2601` = "M260", `3101` = "M310", `3301` = "M330", `3401` = "M340")
yrs <- 1991:2022; y0 <- min(yrs) - 7L; mon <- CJ(y = (y0 - 1L):max(yrs), m = 1:12); nM <- nrow(mon); ally <- y0:max(yrs)

# ---- blocks: forest, flagged per year, ecodivision ------------------------------------------------------------------------------
r <- rast(rf); eco <- vect(ef); west <- eco[eco$StrtmId %in% as.integer(names(WEST)), ]; rw <- crop(r, ext(west), snap = "out")
B <- aggregate(rw, BL, sum, na.rm = TRUE); v <- values(B); ev <- extract(rasterize(west, B[[1]], "StrtmId"), seq_len(ncell(B)))[, 1]
keep <- which(!is.na(ev) & !is.na(v[, "forest"]) & v[, "forest"] >= MINF * BL^2 * 100); nB <- length(keep); ec <- WEST[as.character(ev[keep])]
F0 <- v[keep, "forest"]; FL <- v[keep, as.character(1990:max(yrs)), drop = FALSE]; FL[is.na(FL)] <- 0; cum <- t(apply(FL, 1, cumsum))
E <- FL[, as.character(yrs), drop = FALSE]; N <- pmax(F0 - cum[, as.character(yrs - 1L), drop = FALSE], E)
cat(sprintf("%d blocks of %g km with at least %g%% eligible softwood forest; %d-%d: %.0f km2 flagged of %.0f km2 (%.1f%%)\n", nB, BL * 0.3, 100 * MINF, min(yrs), max(yrs),
            sum(E) * 9e-4, sum(F0) * 9e-4, 100 * sum(E) / sum(F0)))
print(data.table(eco = ec, f = F0, e = rowSums(E))[, .(blocks = .N, forest_km2 = round(sum(f) * 9e-4), flagged_km2 = round(sum(e) * 9e-4), pct_per_year = round(100 * sum(e) / sum(f) / length(yrs), 3)), by = eco][order(-flagged_km2)])

# ---- PRISM monthly, averaged to about the block size, at the block centres ------------------------------------------------------
pf <- function(v, y, m) file.path(pdir, v, sprintf("prism_%s_us_30s_%d%02d.tif", v, y, m))
if (nzchar(cf) && file.exists(cf)) { K <- readRDS(cf); stopifnot(nrow(K$PP) == nB, ncol(K$PP) == nM) } else {
  r0 <- rast(pf("ppt", yrs[1], 1)); pts <- project(xyFromCell(B, keep), crs(B), crs(r0)); ex <- as.vector(ext(pts)) + c(-0.2, 0.2, -0.2, 0.2); fa <- max(1L, round(BL * 300 / 800))
  cl <- makeCluster(NW); clusterExport(cl, c("pf", "pdir", "pts", "ex", "fa", "mon"), envir = environment())
  invisible(clusterEvalQ(cl, { suppressPackageStartupMessages(library(terra)); terraOptions(progress = 0) }))
  t0 <- Sys.time(); out <- parLapplyLB(cl, seq_len(nM), function(j) sapply(c("ppt", "tmax", "tmin"), function(v) { g <- aggregate(crop(rast(pf(v, mon$y[j], mon$m[j])), ext(ex)), fa, mean, na.rm = TRUE)
    values(g, mat = FALSE)[cellFromXY(g, pts)] })); stopCluster(cl); cat(sprintf("PRISM: %d months x 3 variables read in %.1f minutes\n", nM, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  K <- list(PP = sapply(out, function(o) o[, "ppt"]), TX = sapply(out, function(o) o[, "tmax"]), TN = sapply(out, function(o) o[, "tmin"]), lat = pts[, 2]); rm(out); if (nzchar(cf)) saveRDS(K, cf, compress = FALSE) }
PP <- K$PP; TX <- K$TX; TN <- K$TN; lat <- K$lat; TM <- (TX + TN) / 2; ok <- rowSums(is.na(PP) | is.na(TX) | is.na(TN)) == 0
if (any(!ok)) { cat(sprintf("  %d blocks without climate dropped\n", sum(!ok))); PP <- PP[ok, ]; TX <- TX[ok, ]; TN <- TN[ok, ]; TM <- TM[ok, ]; lat <- lat[ok]; E <- E[ok, ]; N <- N[ok, ]; ec <- ec[ok]; F0 <- F0[ok]; nB <- sum(ok) }

# ---- water balance and yearly indexes (as 24-climate-index-look.R) --------------------------------------------------------------
dm <- c(31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31); doy <- c(15, 46, 75, 106, 136, 167, 197, 228, 259, 289, 320, 350)
dl <- sapply(1:12, function(m) { dec <- 0.409 * sin(2 * pi * doy[m] / 365 - 1.39); 24 / pi * acos(pmax(-1, pmin(1, -tan(lat * pi / 180) * tan(dec)))) })
Tn <- sapply(1:12, function(m) rowMeans(TM[, mon$m == m, drop = FALSE])); I <- rowSums((pmax(Tn, 0) / 5)^1.514); al <- 6.75e-7 * I^3 - 7.71e-5 * I^2 + 1.792e-2 * I + 0.49239
PET <- matrix(0, nB, nM); for (j in seq_len(nM)) { m <- mon$m[j]; t <- pmax(TM[, j], 0); PET[, j] <- 16 * (10 * t / pmax(I, 1e-6))^al * (dl[, m] / 12) * (dm[m] / 30) }
AWC <- 150; soil <- rep(AWC, nB); pack <- rep(0, nB); DEF <- matrix(0, nB, nM)
for (j in seq_len(nM)) { rfr <- pmax(0, pmin(1, TM[, j] / 6)); pack <- pack + PP[, j] * (1 - rfr); melt <- pack * rfr; pack <- pack - melt; w <- PP[, j] * rfr + melt
  dlt <- w - PET[, j]; wet <- dlt >= 0; aet <- PET[, j]; s1 <- soil; s1[wet] <- pmin(AWC, soil[wet] + dlt[wet])
  dr <- soil[!wet] * (1 - exp(dlt[!wet] / AWC)); aet[!wet] <- w[!wet] + dr; s1[!wet] <- soil[!wet] - dr; soil <- s1; DEF[, j] <- PET[, j] - aet }
es <- function(t) 6.108 * exp(17.27 * t / (t + 237.3)); VE <- es(TX) - es(TN); wy <- mon$y + (mon$m >= 10)
agg <- function(M, months, fun = rowMeans) sapply(ally, function(y) fun(M[, wy == y & mon$m %in% months, drop = FALSE]))
raw <- list(`precipitation` = agg(PP, 1:12, rowSums), `precipitation less demand` = agg(PP - PET, 1:12, rowSums), `water deficit` = agg(DEF, 1:12, rowSums),
            `max temperature Jun-Aug` = agg(TX, 6:8), `mean temperature` = agg(TM, 1:12), `min temperature, coldest of Dec-Feb` = agg(TN, c(12, 1, 2), function(x) do.call(pmin, as.data.frame(x))),
            `vapour pressure deficit from temperature May-Sep` = agg(VE, 5:9))
rm(PP, TX, TN, TM, PET, DEF, VE, K); z <- lapply(raw, function(M) (M - rowMeans(M)) / pmax(apply(M, 1, sd), 1e-9))
win <- function(Z, w, lag) { out <- matrix(NA_real_, nB, length(yrs)); for (k in seq_along(yrs)) out[, k] <- rowMeans(Z[, match(yrs[k] - lag - (w - 1):0, ally), drop = FALSE]); out }
ef <- factor(ec); wt <- F0; umean <- function(X) { o <- X; for (e1 in levels(ef)) { k <- ef == e1; o[k, ] <- rep(colSums(X[k, , drop = FALSE] * wt[k]) / sum(wt[k]), each = sum(k)) }; o }

# ---- scoring ---------------------------------------------------------------------------------------------------------------------
base <- data.table(eco = rep(ec, length(yrs)), yr = rep(yrs, each = nB), e = as.vector(E), n = as.vector(N))
ll <- function(e, n, p) { p <- pmin(pmax(p, 1e-12), 1 - 1e-12); sum(e * log(p) + (n - e) * log(1 - p)) }
llg <- function(by) { x <- base[, .(e = sum(e), n = sum(n)), by = by]; ll(x$e, x$n, x$e / x$n) }
ll0 <- llg("eco"); llC <- llg(c("eco", "yr")); ty <- base[, .(e = sum(e), n = sum(n)), by = .(eco, yr)]; mT <- glm(cbind(e, n - e) ~ eco + eco:yr, binomial, ty); llT <- ll(ty$e, ty$n, fitted(mT))
cat(sprintf("\nyear-to-year signal: each ecodivision's own straight trend explains %.2f of the gap between its mean rate and its free yearly rates\n", (llT - ll0) / (llC - ll0)))
# a model of the listed covariate matrices (rounded to 0.1 and grouped: the likelihood is the same): its fit, with or without the trends
gfit <- function(Xs, trend = FALSE, rows = NULL) { d <- copy(base); for (i in seq_along(Xs)) set(d, j = paste0("x", i), value = round(as.vector(Xs[[i]]), 1)); if (!is.null(rows)) d <- d[rows]
  xs <- paste0("x", seq_along(Xs)); d <- d[n > 0, .(e = sum(e), n = sum(n)), by = c("eco", if (trend) "yr", xs)]
  m <- suppressWarnings(glm(as.formula(paste("cbind(e, n - e) ~ eco +", if (trend) "eco:yr +", paste(xs, collapse = " + "))), binomial, d)); list(ll = ll(d$e, d$n, fitted(m)), b = coef(m)[xs], m = m) }
share <- function(Xs) (gfit(Xs)$ll - ll0) / (llC - ll0); after <- function(Xs) (gfit(Xs, TRUE)$ll - llT) / (llC - llT)
res <- rbindlist(lapply(names(z), function(nm) rbindlist(lapply(1:4, function(w) rbindlist(lapply(0:3, function(lag) { X <- win(z[[nm]], w, lag); U <- umean(X); f <- gfit(list(X))
  data.table(Index = nm, Years = w, Lag = lag, Local = (f$ll - ll0) / (llC - ll0), Unit = share(list(U)), AfterTrend = after(list(X)), Slope = unname(f$b)) }))))))
fwrite(res, file.path(odir, "climate-index-west-scores.csv")); rnd <- function(d) { d <- copy(d); for (k in names(d)) if (is.double(d[[k]])) set(d, j = k, value = round(d[[k]], 2)); d }
best <- res[, .SD[which.max(Local)], by = Index][order(-Local)]; cat("\nbest window and lag of each index:\n"); print(rnd(best))
cat("\nthe same by window, lag 1 (shows what the window does):\n"); print(dcast(res[Lag == 1], Index ~ paste0(Years, "yr"), value.var = "Local")[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)])

# held out: the slopes fitted without an ecodivision, applied to it with its own mean rate kept (intercept solved to its total)
held <- function(Xs) { tot <- c(0, 0); per <- list(); for (e1 in levels(ef)) { b <- gfit(Xs, rows = base$eco != e1)$b; k <- base$eco == e1 & base$n > 0; d <- base[k]; eta <- Reduce(`+`, Map(function(X, bi) bi * round(as.vector(X)[k], 1), Xs, b))
    a0 <- uniroot(function(a) sum(d$n * plogis(a + eta)) - sum(d$e), c(-40, 10))$root; l1 <- ll(d$e, d$n, plogis(a0 + eta)); l0 <- ll(sum(d$e), sum(d$n), sum(d$e) / sum(d$n))
    dy <- d[, .(e = sum(e), n = sum(n)), by = yr]; lc <- ll(dy$e, dy$n, dy$e / dy$n); tot <- tot + c(l1 - l0, lc - l0); per[[e1]] <- (l1 - l0) / (lc - l0) }; list(pooled = tot[1] / tot[2], per = unlist(per)) }
# later: fitted on the first half, applied to the second (intercepts and slopes from the first half)
later <- function(Xs, split = 2006L) { tr <- base$yr <= split; f <- gfit(Xs, rows = tr); d <- copy(base[!tr & n > 0]); for (i in seq_along(Xs)) set(d, j = paste0("x", i), value = round(as.vector(Xs[[i]])[!tr & base$n > 0], 1))
  d[, p := predict(f$m, d, type = "response")]; m0 <- base[tr, .(r = sum(e) / sum(n)), by = eco]; d <- merge(d, m0, by = "eco")
  d[, .(observed_km2 = sum(e) * 9e-4, climate_ratio = sum(n * p) / sum(e), mean_rate_ratio = sum(n * r) / sum(e)), by = eco] }
spec <- function(b) win(z[[b$Index]], b$Years, b$Lag); XB <- lapply(seq_len(nrow(best)), function(i) spec(best[i])); names(XB) <- best$Index
hs <- lapply(XB, function(X) held(list(X))); best[, HeldOut := sapply(hs, `[[`, "pooled")]
cat("\nsingle indexes at their best window and lag, with the held-out score (pooled, then by ecodivision):\n"); print(rnd(best[, .(Index, Years, Lag, Local, Unit, AfterTrend, HeldOut, Slope)]))
print(round(do.call(rbind, lapply(hs, `[[`, "per")), 2))
pr <- as.data.table(t(combn(names(XB), 2))); setnames(pr, c("A", "B"))
pr[, c("Local", "AfterTrend", "HeldOut") := { o <- lapply(seq_len(.N), function(i) { Xs <- list(XB[[A[i]]], XB[[B[i]]]); c((gfit(Xs)$ll - ll0) / (llC - ll0), after(Xs), held(Xs)$pooled) }); list(sapply(o, `[`, 1), sapply(o, `[`, 2), sapply(o, `[`, 3)) }]
cat("\npairs of indexes (each at its own best window and lag):\n"); print(rnd(pr[order(-HeldOut)])); fwrite(pr, file.path(odir, "climate-index-west-pairs.csv"))
top1 <- best[which.max(HeldOut)]; top2 <- pr[which.max(HeldOut)]; X1 <- list(XB[[top1$Index]]); X2 <- list(XB[[top2$A]], XB[[top2$B]])
cat(sprintf("\nlater period: fitted on 1991-2006, applied to 2007-2022 (ratio of predicted to observed area; 1 = right)\n  single: %s; pair: %s + %s\n", top1$Index, top2$A, top2$B))
l1 <- later(X1); l2 <- later(X2); lt <- merge(l1[, .(eco, observed_km2, mean_rate_ratio, single = climate_ratio)], l2[, .(eco, pair = climate_ratio)], by = "eco")[order(-observed_km2)]
lt <- rbind(lt, lt[, .(eco = "West", observed_km2 = sum(observed_km2), mean_rate_ratio = sum(mean_rate_ratio * observed_km2) / sum(observed_km2), single = sum(single * observed_km2) / sum(observed_km2), pair = sum(pair * observed_km2) / sum(observed_km2))])
print(rnd(lt)); fwrite(lt, file.path(odir, "climate-index-west-later.csv"))
f2 <- gfit(X2); cat("\npair model, whole record: slopes per standard deviation (log odds):\n"); print(round(f2$b, 2))
se <- suppressWarnings(glm(cbind(e, n - e) ~ eco + eco:x1 + eco:x2, binomial, { d <- copy(base); d[, `:=`(x1 = round(as.vector(X2[[1]]), 1), x2 = round(as.vector(X2[[2]]), 1))]; d[n > 0, .(e = sum(e), n = sum(n)), by = .(eco, x1, x2)] }))
cc <- coef(se); cat("the same slopes fitted for each ecodivision apart (do they agree in sign and size?):\n")
print(data.table(eco = levels(ef), A = round(cc[paste0("eco", levels(ef), ":x1")], 2), B = round(cc[paste0("eco", levels(ef), ":x2")], 2)))

# ---- figure: yearly rate by ecodivision, observed and from the pair model with held-out slopes ---------------------------------
big <- base[, .(e = sum(e)), by = eco][order(-e)][1:min(6, nlevels(ef)), eco]
png(file.path(odir, "climate-index-west.png"), width = 2600, height = 1500, res = 170); par(mfrow = c(2, 3), mar = c(3, 4, 3, 1), mgp = c(2.2, 0.7, 0))
for (e1 in big) { b <- gfit(X2, rows = base$eco != e1)$b; k <- base$eco == e1 & base$n > 0; d <- base[k]; eta <- b[1] * round(as.vector(X2[[1]])[k], 1) + b[2] * round(as.vector(X2[[2]])[k], 1)
  a0 <- uniroot(function(a) sum(d$n * plogis(a + eta)) - sum(d$e), c(-40, 10))$root; d[, p := plogis(a0 + eta)]; y <- d[, .(obs = 100 * sum(e) / sum(n), fit = 100 * sum(n * p) / sum(n)), by = yr][order(yr)]
  barplot(y$obs, names.arg = y$yr, col = "grey75", border = NA, las = 2, cex.names = 0.6, space = 0, ylim = c(0, max(y$obs, y$fit) * 1.05), ylab = "% of open forest per year")
  lines(seq_along(y$yr) - 0.5, y$fit, col = "#b2182b", lwd = 2.2); title(sprintf("%s: observed (bars) and climate model (line)\nslopes fitted without this ecodivision; cor %.2f", e1, cor(y$obs, y$fit)), cex.main = 0.9) }
invisible(dev.off()); cat("\nwritten to", odir, "\n")
