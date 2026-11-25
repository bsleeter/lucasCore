# =============================================================================
# 26-climate-carryover-west.R - to-do 3, climate method: longer climate windows, and carry-over from recent die-off nearby
# =============================================================================
# Follows 25-climate-index-west.R (same blocks, record, indexes and scale), with two changes:
#   - windows of 1 to 8 years (25 stopped at 4, where every index was still improving)
#   - a carry-over term: the share of the eligible forest of the block and its 8 neighbours flagged in the 3 years before (log10 of
#     the yearly share, standardized). An outbreak, once started, keeps going where the insects are, whatever the weather does.
# Years 1994-2022 (the carry-over needs 3 earlier years and 1990 holds the record's backlog).
# The later-period test (fitted on 1994-2006, applied to 2007-2022) is run two ways for the carry-over: "one step" uses the observed
# die-off of the years before (what a forecast one year ahead would know) and "free" feeds the model's own predicted die-off
# forward from 2006, as a projection must. Ratios are predicted over observed area.
# Usage: Rscript dev/mortality/26-climate-carryover-west.R <rule-national-300m.tif> <ecodiv.gpkg> <PRISM monthly folder> <out folder>
#          [--block=20] [--min-forest=0.05] [--workers=16] [--cache=<rds>]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra); library(parallel) }); options(width = 230); terraOptions(progress = 0)
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; rf <- pos[1]; ef <- pos[2]; pdir <- pos[3]; odir <- pos[4]; dir.create(odir, showWarnings = FALSE, recursive = TRUE)
BL <- as.integer(opt("block", 20)); MINF <- as.numeric(opt("min-forest", 0.05)); NW <- as.integer(opt("workers", 16)); cf <- opt("cache", "")
WEST <- c(`240` = "240", `260` = "260", `310` = "310", `320` = "320", `330` = "330", `340` = "340", `2401` = "M240", `2601` = "M260", `3101` = "M310", `3301` = "M330", `3401` = "M340")
yrs <- 1994:2022; SPLIT <- 2006L; y0 <- 1980L; mon <- CJ(y = (y0 - 1L):max(yrs), m = 1:12); nM <- nrow(mon); ally <- y0:max(yrs); rec_y <- 1990:max(yrs)

r <- rast(rf); eco <- vect(ef); west <- eco[eco$StrtmId %in% as.integer(names(WEST)), ]; rw <- crop(r, ext(west), snap = "out")
B <- aggregate(rw, BL, sum, na.rm = TRUE); v <- values(B); ev <- extract(rasterize(west, B[[1]], "StrtmId"), seq_len(ncell(B)))[, 1]
keep <- which(!is.na(ev) & !is.na(v[, "forest"]) & v[, "forest"] >= MINF * BL^2 * 100)
pf <- function(v, y, m) file.path(pdir, v, sprintf("prism_%s_us_30s_%d%02d.tif", v, y, m))
if (nzchar(cf) && file.exists(cf)) { K <- readRDS(cf); stopifnot(nrow(K$PP) == length(keep), ncol(K$PP) == nM) } else {
  r0 <- rast(pf("ppt", yrs[1], 1)); pts <- project(xyFromCell(B, keep), crs(B), crs(r0)); ex <- as.vector(ext(pts)) + c(-0.2, 0.2, -0.2, 0.2); fa <- max(1L, round(BL * 300 / 800))
  cl <- makeCluster(NW); clusterExport(cl, c("pf", "pdir", "pts", "ex", "fa", "mon"), envir = environment()); invisible(clusterEvalQ(cl, { suppressPackageStartupMessages(library(terra)); terraOptions(progress = 0) }))
  out <- parLapplyLB(cl, seq_len(nM), function(j) sapply(c("ppt", "tmax", "tmin"), function(v) { g <- aggregate(crop(rast(pf(v, mon$y[j], mon$m[j])), ext(ex)), fa, mean, na.rm = TRUE); values(g, mat = FALSE)[cellFromXY(g, pts)] })); stopCluster(cl)
  K <- list(PP = sapply(out, function(o) o[, "ppt"]), TX = sapply(out, function(o) o[, "tmax"]), TN = sapply(out, function(o) o[, "tmin"]), lat = pts[, 2]); rm(out); if (nzchar(cf)) saveRDS(K, cf, compress = FALSE) }
ok <- rowSums(is.na(K$PP) | is.na(K$TX) | is.na(K$TN)) == 0; keep <- keep[ok]; PP <- K$PP[ok, ]; TX <- K$TX[ok, ]; TN <- K$TN[ok, ]; lat <- K$lat[ok]; TM <- (TX + TN) / 2; rm(K)
nB <- length(keep); ec <- WEST[as.character(ev[keep])]; F0 <- v[keep, "forest"]; FLall <- v[, as.character(rec_y), drop = FALSE]; FLall[is.na(FLall)] <- 0; FL <- FLall[keep, , drop = FALSE]
Fall <- v[, "forest"]; Fall[is.na(Fall)] <- 0; nb <- function(x) { g <- B[[1]]; values(g) <- x; values(focal(g, 3, "sum", na.rm = TRUE), mat = FALSE)[keep] }   # block + 8 neighbours
Fnb <- pmax(nb(Fall), 1); FLnb <- sapply(seq_along(rec_y), function(j) nb(FLall[, j])); colnames(FLnb) <- rec_y; colnames(FL) <- rec_y
cy <- function(M, y) M[, as.character(y), drop = FALSE]; cum <- t(apply(FL, 1, cumsum)); colnames(cum) <- rec_y
E <- cy(FL, yrs); N <- pmax(F0 - cy(cum, yrs - 1L), E)
carry_raw <- function(M3) log10(M3 / Fnb / 3 + 1e-5)   # M3: flagged in the 3 years before, block + neighbours
CR <- sapply(yrs, function(y) carry_raw(rowSums(cy(FLnb, (y - 3L):(y - 1L))))); cmu <- mean(CR); csd <- sd(as.vector(CR)); CZ <- (CR - cmu) / csd
cat(sprintf("%d blocks; %d-%d: %.0f km2 flagged; carry-over term: %.0f%% of block-years have die-off within the block and its neighbours in the 3 years before\n", nB, min(yrs), max(yrs), sum(E) * 9e-4, 100 * mean(CR > -5)))

# ---- indexes ---------------------------------------------------------------------------------------------------------------------
dm <- c(31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31); doy <- c(15, 46, 75, 106, 136, 167, 197, 228, 259, 289, 320, 350)
dl <- sapply(1:12, function(m) { dec <- 0.409 * sin(2 * pi * doy[m] / 365 - 1.39); 24 / pi * acos(pmax(-1, pmin(1, -tan(lat * pi / 180) * tan(dec)))) })
Tn <- sapply(1:12, function(m) rowMeans(TM[, mon$m == m, drop = FALSE])); I <- rowSums((pmax(Tn, 0) / 5)^1.514); al <- 6.75e-7 * I^3 - 7.71e-5 * I^2 + 1.792e-2 * I + 0.49239
PET <- matrix(0, nB, nM); for (j in seq_len(nM)) { m <- mon$m[j]; t <- pmax(TM[, j], 0); PET[, j] <- 16 * (10 * t / pmax(I, 1e-6))^al * (dl[, m] / 12) * (dm[m] / 30) }
AWC <- 150; soil <- rep(AWC, nB); pack <- rep(0, nB); DEF <- matrix(0, nB, nM)
for (j in seq_len(nM)) { rfr <- pmax(0, pmin(1, TM[, j] / 6)); pack <- pack + PP[, j] * (1 - rfr); melt <- pack * rfr; pack <- pack - melt; w <- PP[, j] * rfr + melt
  dlt <- w - PET[, j]; wet <- dlt >= 0; aet <- PET[, j]; s1 <- soil; s1[wet] <- pmin(AWC, soil[wet] + dlt[wet])
  dr <- soil[!wet] * (1 - exp(dlt[!wet] / AWC)); aet[!wet] <- w[!wet] + dr; s1[!wet] <- soil[!wet] - dr; soil <- s1; DEF[, j] <- PET[, j] - aet }
wy <- mon$y + (mon$m >= 10); agg <- function(M, months, fun = rowMeans) sapply(ally, function(y) fun(M[, wy == y & mon$m %in% months, drop = FALSE]))
raw <- list(`mean temperature` = agg(TM, 1:12), `max temperature Jun-Aug` = agg(TX, 6:8), `water deficit` = agg(DEF, 1:12, rowSums),
            `precipitation less demand` = agg(PP - PET, 1:12, rowSums), `precipitation` = agg(PP, 1:12, rowSums))
rm(PP, TX, TN, TM, PET, DEF); z <- lapply(raw, function(M) (M - rowMeans(M)) / pmax(apply(M, 1, sd), 1e-9))
win <- function(Z, w, lag) { out <- matrix(NA_real_, nB, length(yrs)); for (k in seq_along(yrs)) out[, k] <- rowMeans(Z[, match(yrs[k] - lag - (w - 1):0, ally), drop = FALSE]); out }

# ---- scoring (as 25) -------------------------------------------------------------------------------------------------------------
ef <- factor(ec); base <- data.table(eco = rep(ec, length(yrs)), yr = rep(yrs, each = nB), e = as.vector(E), n = as.vector(N))
ll <- function(e, n, p) { p <- pmin(pmax(p, 1e-12), 1 - 1e-12); sum(e * log(p) + (n - e) * log(1 - p)) }
llg <- function(by) { x <- base[, .(e = sum(e), n = sum(n)), by = by]; ll(x$e, x$n, x$e / x$n) }
ll0 <- llg("eco"); llC <- llg(c("eco", "yr")); ty <- base[, .(e = sum(e), n = sum(n)), by = .(eco, yr)]; llT <- ll(ty$e, ty$n, fitted(glm(cbind(e, n - e) ~ eco + eco:yr, binomial, ty)))
gfit <- function(Xs, trend = FALSE, rows = NULL) { d <- copy(base); for (i in seq_along(Xs)) set(d, j = paste0("x", i), value = round(as.vector(Xs[[i]]), 1)); if (!is.null(rows)) d <- d[rows]
  xs <- paste0("x", seq_along(Xs)); d <- d[n > 0, .(e = sum(e), n = sum(n)), by = c("eco", if (trend) "yr", xs)]
  m <- suppressWarnings(glm(as.formula(paste("cbind(e, n - e) ~ 0 + eco +", if (trend) "eco:yr +", paste(xs, collapse = " + "))), binomial, d)); cc <- coef(m)
  list(ll = ll(d$e, d$n, fitted(m)), b = cc[xs], a = setNames(cc[paste0("eco", levels(ef))], levels(ef))) }
sh <- function(Xs) (gfit(Xs)$ll - ll0) / (llC - ll0); after <- function(Xs) (gfit(Xs, TRUE)$ll - llT) / (llC - llT)
held <- function(Xs) { tot <- c(0, 0); for (e1 in levels(ef)) { b <- gfit(Xs, rows = base$eco != e1)$b; k <- base$eco == e1 & base$n > 0; d <- base[k]; eta <- Reduce(`+`, Map(function(X, bi) bi * round(as.vector(X)[k], 1), Xs, b))
    a0 <- uniroot(function(a) sum(d$n * plogis(a + eta)) - sum(d$e), c(-40, 10))$root; l0 <- ll(sum(d$e), sum(d$n), sum(d$e) / sum(d$n)); dy <- d[, .(e = sum(e), n = sum(n)), by = yr]
    tot <- tot + c(ll(d$e, d$n, plogis(a0 + eta)) - l0, ll(dy$e, dy$n, dy$e / dy$n) - l0) }; tot[1] / tot[2] }
cat(sprintf("\neach ecodivision's own straight trend: %.2f of the year-to-year signal\n", (llT - ll0) / (llC - ll0)))
W <- rbindlist(lapply(names(z), function(nm) rbindlist(lapply(1:8, function(w) rbindlist(lapply(0:2, function(lag) data.table(Index = nm, Years = w, Lag = lag, Share = sh(list(win(z[[nm]], w, lag))))))))))
fwrite(W, file.path(odir, "climate-carryover-west-windows.csv")); r2 <- function(d) d[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)]
cat("\nshare of the signal by window (years averaged), lag 0:\n"); print(r2(dcast(W[Lag == 0], Index ~ paste0(Years, "yr"), value.var = "Share")))
cat("lag 1:\n"); print(r2(dcast(W[Lag == 1], Index ~ paste0(Years, "yr"), value.var = "Share")))
best <- W[, .SD[which.max(Share)], by = Index][order(-Share)]; XB <- lapply(seq_len(nrow(best)), function(i) win(z[[best$Index[i]]], best$Years[i], best$Lag[i])); names(XB) <- best$Index
best[, `:=`(AfterTrend = sapply(XB, function(X) after(list(X))), HeldOut = sapply(XB, function(X) held(list(X))))]; cat("\nbest window and lag of each index:\n"); print(r2(best))

# ---- carry-over ------------------------------------------------------------------------------------------------------------------
t1 <- best$Index[1]; mo <- intersect(c("precipitation less demand", "precipitation", "water deficit"), best$Index); t2 <- mo[which.max(best[match(mo, Index), AfterTrend])]
M <- list(`climate: best index` = list(XB[[t1]]), `climate: best + moisture` = list(XB[[t1]], XB[[t2]]), `carry-over only` = list(CZ),
          `best index + carry-over` = list(XB[[t1]], CZ), `best + moisture + carry-over` = list(XB[[t1]], XB[[t2]], CZ))
cat(sprintf("\nbest index: %s (%d years, lag %d); moisture term: %s (%d years, lag %d)\n", t1, best$Years[1], best$Lag[1], t2, best[Index == t2, Years], best[Index == t2, Lag]))
cs <- rbindlist(lapply(names(M), function(nm) { f <- gfit(M[[nm]]); data.table(Model = nm, Share = (f$ll - ll0) / (llC - ll0), AfterTrend = after(M[[nm]]), HeldOut = held(M[[nm]]), Slopes = paste(round(f$b, 2), collapse = ", ")) }))
cat("models with the carry-over (it uses the observed die-off of the 3 years before; slopes are per standard deviation, in the order named):\n"); print(r2(cs)); fwrite(cs, file.path(odir, "climate-carryover-west-models.csv"))

# ---- later period: fitted to the split year, applied after it; the carry-over one step ahead and free-running ---------------------
tr <- base$yr <= SPLIT; m0 <- base[tr, .(r = sum(e) / sum(n)), by = eco]; ei <- match(ec, levels(ef))
run <- function(Xs, f, carry = c("none", "observed", "free"), from = SPLIT + 1L) { carry <- match.arg(carry); nx <- length(Xs) - (carry != "none"); FLp <- FL; P <- matrix(NA_real_, nB, length(yrs)); colnames(P) <- yrs
  for (y in yrs) { k <- match(y, yrs); eta <- f$a[ei]; for (i in seq_len(nx)) eta <- eta + f$b[i] * Xs[[i]][, k]
    if (carry != "none") { cz <- if (carry == "observed" || y < from) CZ[, k] else { full <- matrix(0, ncell(B), 3); full[keep, ] <- cy(FLp, (y - 3L):(y - 1L)); (carry_raw(nb(rowSums(full))) - cmu) / csd }; eta <- eta + f$b[nx + 1L] * cz }
    op <- if (carry == "free") pmax(F0 - rowSums(cy(FLp, rec_y[rec_y < y])), 0) else N[, k]; P[, k] <- op * plogis(eta); if (carry == "free" && y >= from) FLp[, as.character(y)] <- P[, k] }; P }
tab <- function(P, lab) data.table(eco = ec, p = rowSums(P[, yrs > SPLIT, drop = FALSE]), e = rowSums(E[, yrs > SPLIT, drop = FALSE]))[, .(observed_km2 = sum(e) * 9e-4, r = sum(p) / sum(e)), by = eco][, setnames(.SD, "r", lab)]
fc <- gfit(M[["climate: best index"]], rows = tr); fm <- gfit(M[["climate: best + moisture"]], rows = tr); fk <- gfit(M[["best index + carry-over"]], rows = tr); fo <- gfit(M[["carry-over only"]], rows = tr)
Pc <- run(M[["climate: best index"]], fc); Pm <- run(M[["climate: best + moisture"]], fm); P1 <- run(M[["best index + carry-over"]], fk, "observed"); Pf <- run(M[["best index + carry-over"]], fk, "free"); Po <- run(M[["carry-over only"]], fo, "free")
mr <- merge(base[!tr, .(e = sum(e), n = sum(n)), by = eco], m0, by = "eco")[, .(eco, mean_rate = n * r / e)]
lt <- Reduce(function(x, y) merge(x, y, by = c("eco", "observed_km2")), list(tab(Pc, "climate"), tab(Pm, "climate_moisture"), tab(P1, "carry_one_step"), tab(Pf, "carry_free"), tab(Po, "carry_only_free")))
lt <- merge(mr, lt, by = "eco")[order(-observed_km2)]; num <- setdiff(names(lt), c("eco", "observed_km2"))
lt <- rbind(lt, cbind(data.table(eco = "West", observed_km2 = sum(lt$observed_km2)), lt[, lapply(.SD, function(x) sum(x * observed_km2) / sum(observed_km2)), .SDcols = num])[, names(lt), with = FALSE])
cat(sprintf("\nlater period: fitted on %d-%d, applied to %d-%d; predicted over observed area (1 = right)\n", min(yrs), SPLIT, SPLIT + 1L, max(yrs))); print(r2(lt)); fwrite(lt, file.path(odir, "climate-carryover-west-later.csv"))
yc <- function(P) sapply(levels(ef), function(e1) cor(colSums(P[ec == e1, yrs > SPLIT, drop = FALSE]), colSums(E[ec == e1, yrs > SPLIT, drop = FALSE])))
cat("\ncorrelation of predicted with observed yearly area within the later period, by ecodivision:\n"); print(round(rbind(climate = yc(Pc), carry_one_step = yc(P1), carry_free = yc(Pf)), 2))

# ---- figure ----------------------------------------------------------------------------------------------------------------------
big <- base[, .(e = sum(e)), by = eco][order(-e)][1:6, eco]; png(file.path(odir, "climate-carryover-west.png"), width = 2600, height = 1500, res = 170); par(mfrow = c(2, 3), mar = c(3, 4, 3, 1), mgp = c(2.2, 0.7, 0))
for (e1 in big) { k <- ec == e1; nn <- colSums(N[k, ]); o <- 100 * colSums(E[k, ]) / nn; l1 <- 100 * colSums(Pc[k, ]) / nn; l2 <- 100 * colSums(Pf[k, ]) / nn
  barplot(o, names.arg = yrs, col = "grey78", border = NA, las = 2, cex.names = 0.6, space = 0, ylim = c(0, max(o, l1, l2) * 1.05), ylab = "% of open forest per year")
  lines(seq_along(yrs) - 0.5, l1, col = "#2166ac", lwd = 2); lines(seq_along(yrs) - 0.5, l2, col = "#b2182b", lwd = 2); abline(v = match(SPLIT, yrs), lty = 2)
  title(sprintf("%s: fitted to %d (dashed), then projected\nblue: climate only; red: climate + carry-over, free-running", e1, SPLIT), cex.main = 0.9) }
invisible(dev.off()); cat("\nwritten to", odir, "\n")
