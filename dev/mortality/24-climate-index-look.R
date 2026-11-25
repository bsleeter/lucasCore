# =============================================================================
# 24-climate-index-look.R - to-do 3, climate method: a first look at which climate indexes track drought and insect mortality
# =============================================================================
# One study area (a Build result of a library, read-only). For every historical year it takes the Build's mortality maps (stage 6) and
# the PRISM 800 m monthly grids (precipitation, maximum and minimum temperature, maximum vapour pressure deficit), builds candidate
# yearly indexes on the PRISM grid, and scores each index, averaging window (1-4 years) and lag (0-3 years) two ways:
#   - over time: rank correlation of the study area's yearly rate with the forest-weighted mean of the index
#   - over space and time: a logistic model of events on open forest by PRISM cell and year, with the index as the only term, scored
#     as a share of what a free effect for every year explains (the most any index that is the same everywhere could reach)
# Every index but the PRISM vapour pressure deficit can be made from monthly precipitation and temperature, which is all LOCA2 has.
# A year is a water year (October of the year before to September). Indexes are z-scores of each PRISM cell against its own years.
# The water balance is crude: Thornthwaite demand, one 150 mm soil store, snow by temperature. A first look only.
# Usage: Rscript dev/mortality/24-climate-index-look.R <library.ssim> <Build result id> <PRISM monthly folder> <out folder> [--min-age=20]
# =============================================================================
suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(data.table); library(terra) }); options(width = 220); terraOptions(progress = 0)
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; lib <- normalizePath(pos[1], winslash = "/"); sid <- as.integer(pos[2]); pdir <- pos[3]; odir <- pos[4]; mage <- as.numeric(opt("min-age", 20))
dir.create(odir, showWarnings = FALSE, recursive = TRUE); source("src/mortality.R")
con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
g <- q("select TransitionGroupId id from stsim_TransitionGroup where Name = '%s'", MORT_GROUP)$id; scl <- q("select Name, Id from stsim_StateClass")
sm <- q("select Timestep, MultiplierFileName f from stsim_TransitionSpatialMultiplier where ScenarioId = %d and TransitionGroupId = %d order by Timestep", sid, g)
ic <- q("select * from stsim_InitialConditionsSpatial where ScenarioId = %d", sid); dbDisconnect(con)
d <- file.path(paste0(lib, ".data"), sprintf("Scenario-%d", sid)); S <- rast(file.path(d, "stsim_InitialConditionsSpatial", ic$StateClassFileName))
vS <- values(S, mat = FALSE); vA <- values(rast(file.path(d, "stsim_InitialConditionsSpatial", ic$AgeFileName)), mat = FALSE)
pw <- fread("defaults/transitions/pathways/mortality.csv"); elig <- !is.na(vS) & vS %in% as.integer(scl$Id[match(pw$StateClassIdSource, scl$Name)]) & !is.na(vA) & vA >= mage
ev <- rep(NA_integer_, ncell(S)); for (i in seq_len(nrow(sm))) { f <- sm$f[i]; if (is.na(f) || grepl("^Off|Allowed", f)) next
  v <- values(rast(file.path(d, "stsim_TransitionSpatialMultiplier", f)), mat = FALSE); k <- !is.na(v) & v > 0 & is.na(ev); ev[k] <- sm$Timestep[i] }
yrs <- sort(unique(sm$Timestep[sm$Timestep <= max(ev, na.rm = TRUE)])); yrs <- min(yrs):max(yrs)
cat(sprintf("%s result %d: %d eligible cells at or over age %g; %d event cells, %d-%d\n", basename(lib), sid, sum(elig), mage, sum(!is.na(ev) & elig), min(yrs), max(yrs)))

# ---- PRISM monthly on its own grid over the study area ---------------------------------------------------------------------------
pf <- function(v, y, m) file.path(pdir, v, sprintf("prism_%s_us_30s_%d%02d.tif", v, y, m))
r0 <- rast(pf("ppt", yrs[1], 1)); e <- ext(project(as.polygons(ext(S), crs = crs(S)), crs(r0))) + 0.02; G <- crop(r0, e)
xy <- project(xyFromCell(S, which(elig)), crs(S), crs(G)); pc <- cellFromXY(G, xy); cells <- sort(unique(pc[!is.na(pc)])); ci <- match(pc, cells)
lat <- yFromCell(G, cells); nC <- length(cells); y0 <- min(yrs) - 5L; mon <- CJ(y = (y0 - 1L):max(yrs), m = 1:12); nM <- nrow(mon)
cat(sprintf("PRISM: %d cells of %g arc-seconds hold the eligible forest; reading %d months x 4 variables\n", nC, round(res(G)[1] * 3600), nM))
rd <- function(v) { M <- matrix(NA_real_, nC, nM); for (j in seq_len(nM)) M[, j] <- values(crop(rast(pf(v, mon$y[j], mon$m[j])), G), mat = FALSE)[cells]; M }
cf <- opt("cache", ""); if (nzchar(cf) && file.exists(cf)) { K <- readRDS(cf); PP <- K$PP; TX <- K$TX; TN <- K$TN; VP <- K$VP } else { PP <- rd("ppt"); TX <- rd("tmax"); TN <- rd("tmin"); VP <- rd("vpdmax"); if (nzchar(cf)) saveRDS(list(PP = PP, TX = TX, TN = TN, VP = VP), cf, compress = FALSE) }; TM <- (TX + TN) / 2
ok <- rowSums(is.na(PP) | is.na(TX) | is.na(TN) | is.na(VP)) == 0; cat(sprintf("  %d cells without data dropped\n", sum(!ok)))

# ---- water balance: Thornthwaite demand, snow by temperature, one soil store ----------------------------------------------------
dm <- c(31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31); doy <- c(15, 46, 75, 106, 136, 167, 197, 228, 259, 289, 320, 350)
dl <- sapply(1:12, function(m) { dec <- 0.409 * sin(2 * pi * doy[m] / 365 - 1.39); 24 / pi * acos(pmax(-1, pmin(1, -tan(lat * pi / 180) * tan(dec)))) })   # day length, cells x 12
Tn <- sapply(1:12, function(m) rowMeans(TM[, mon$m == m, drop = FALSE])); I <- rowSums((pmax(Tn, 0) / 5)^1.514); al <- 6.75e-7 * I^3 - 7.71e-5 * I^2 + 1.792e-2 * I + 0.49239
PET <- matrix(0, nC, nM); for (j in seq_len(nM)) { m <- mon$m[j]; t <- pmax(TM[, j], 0); PET[, j] <- 16 * (10 * t / pmax(I, 1e-6))^al * (dl[, m] / 12) * (dm[m] / 30) }
AWC <- 150; soil <- rep(AWC, nC); pack <- rep(0, nC); DEF <- matrix(0, nC, nM)
for (j in seq_len(nM)) { rf <- pmax(0, pmin(1, TM[, j] / 6)); pack <- pack + PP[, j] * (1 - rf); melt <- pack * rf; pack <- pack - melt; w <- PP[, j] * rf + melt
  dlt <- w - PET[, j]; wet <- dlt >= 0; aet <- PET[, j]; s1 <- soil; s1[wet] <- pmin(AWC, soil[wet] + dlt[wet])
  dr <- soil[!wet] * (1 - exp(dlt[!wet] / AWC)); aet[!wet] <- w[!wet] + dr; s1[!wet] <- soil[!wet] - dr; soil <- s1; DEF[, j] <- PET[, j] - aet }
es <- function(t) 6.108 * exp(17.27 * t / (t + 237.3)); VE <- es(TX) - es(TN)   # (vapour pressure deficit from temperature alone: dew point = the minimum)

# ---- yearly indexes by water year, as z-scores of each cell ----------------------------------------------------------------------
wy <- mon$y + (mon$m >= 10); ally <- y0:max(yrs)
agg <- function(M, months, fun = rowMeans) sapply(ally, function(y) fun(M[, wy == y & mon$m %in% months, drop = FALSE]))
raw <- list(`precipitation (water year)` = agg(PP, 1:12, rowSums), `precipitation less demand (water year)` = agg(PP - PET, 1:12, rowSums),
            `water deficit (water year)` = agg(DEF, 1:12, rowSums), `max temperature (Jun-Aug)` = agg(TX, 6:8), `mean temperature (water year)` = agg(TM, 1:12),
            `min temperature (coldest of Dec-Feb)` = agg(TN, c(12, 1, 2), function(x) apply(x, 1, min)), `vapour pressure deficit, PRISM (May-Sep)` = agg(VP, 5:9),
            `vapour pressure deficit from temperature (May-Sep)` = agg(VE, 5:9))
z <- lapply(raw, function(M) (M - rowMeans(M)) / pmax(apply(M, 1, sd), 1e-9))
win <- function(Z, w, lag) { out <- matrix(NA_real_, nC, length(yrs)); for (k in seq_along(yrs)) { j <- match(yrs[k] - lag - (w - 1):0, ally); out[, k] <- rowMeans(Z[, j, drop = FALSE]) }; out }

# ---- events and open forest by PRISM cell and year --------------------------------------------------------------------------------
el <- which(elig); evc <- ev[el]; N <- matrix(0, nC, length(yrs)); E <- N
for (k in seq_along(yrs)) { op <- is.na(evc) | evc >= yrs[k]; N[, k] <- tabulate(ci[op], nC); E[, k] <- tabulate(ci[!is.na(evc) & evc == yrs[k]], nC) }
N[!ok, ] <- 0; E[!ok, ] <- 0; wt <- N[, 1]; rate <- colSums(E) / colSums(N); ll <- function(e, n, p) { p <- pmin(pmax(p, 1e-12), 1 - 1e-12); sum(e * log(p) + (n - e) * log(1 - p)) }
ll0 <- ll(sum(E), sum(N), sum(E) / sum(N)); llY <- sum(mapply(function(e, n) ll(e, n, e / n), colSums(E), colSums(N))); ceil <- 1 - llY / ll0
cat(sprintf("yearly rate: mean %.3f%%, highest %.3f%% in %d; %d of %d years hold half of the events; a free effect for each year explains %.1f%% (McFadden)\n",
            100 * mean(rate), 100 * max(rate), yrs[which.max(rate)], which(cumsum(sort(colSums(E), decreasing = TRUE)) >= sum(E) / 2)[1], length(yrs), 100 * ceil))
fit1 <- function(x, e, n) { k <- n > 0; b <- round(x[k] * 20) / 20; dt <- data.table(b = b, e = e[k], n = n[k])[, .(e = sum(e), n = sum(n)), by = b]
  m <- suppressWarnings(glm(cbind(e, n - e) ~ b, binomial, dt)); c(r2 = 1 - ll(dt$e, dt$n, fitted(m)) / ll(sum(dt$e), sum(dt$n), sum(dt$e) / sum(dt$n)), slope = unname(coef(m)[2])) }
# the warming trend: mortality peaks late and temperature rises, so an index must explain more than the calendar year does
Ey <- colSums(E); Ny <- colSums(N); r2y <- function(m) 1 - ll(Ey, Ny, fitted(m)) / ll0; rT <- r2y(glm(cbind(Ey, Ny - Ey) ~ yrs, binomial))
after <- function(mu) (r2y(suppressWarnings(glm(cbind(Ey, Ny - Ey) ~ yrs + mu, binomial))) - rT) / (ceil - rT)
cat(sprintf("the calendar year alone (a straight trend) explains %.2f of what free year effects explain; rank correlation of the rate with the year %.2f\n", rT / ceil, cor(yrs, rate, method = "spearman")))
res <- rbindlist(lapply(names(z), function(nm) rbindlist(lapply(1:4, function(w) rbindlist(lapply(0:3, function(lag) { X <- win(z[[nm]], w, lag); mu <- colSums(X * wt, na.rm = TRUE) / sum(wt)
  f <- fit1(as.vector(X), as.vector(E), as.vector(N)); ft <- fit1(rep(mu, each = nC), as.vector(E), as.vector(N))
  data.table(Index = nm, Years = w, Lag = lag, RankCor = cor(mu, rate, method = "spearman"), TimeShare = ft[["r2"]] / ceil, LocalShare = f[["r2"]] / ceil, AfterTrend = after(mu), Slope = f[["slope"]]) }))))))
fwrite(res, file.path(odir, "climate-index-scores.csv"))
cat("\nbest window and lag of each index (TimeShare: the index's area mean each year, as a share of what free year effects explain;\nAfterTrend: what the index adds once a straight trend in the year is in the model, as a share of what the trend leaves unexplained;\nLocalShare: the index at each PRISM cell and year, same scale; Slope: change in log odds per standard deviation, local):\n")
best <- res[, .SD[which.max(TimeShare)], by = Index][order(-TimeShare)]; print(best[, .(Index, Years, Lag, RankCor = round(RankCor, 2), TimeShare = round(TimeShare, 2), AfterTrend = round(AfterTrend, 2), LocalShare = round(LocalShare, 2), Slope = round(Slope, 2))])
cat("\nthe top 12 of all index, window and lag combinations by TimeShare:\n"); print(res[order(-TimeShare)][1:12, .(Index, Years, Lag, RankCor = round(RankCor, 2), TimeShare = round(TimeShare, 2), AfterTrend = round(AfterTrend, 2), LocalShare = round(LocalShare, 2))])
vp <- cor(as.vector(z[["vapour pressure deficit, PRISM (May-Sep)"]]), as.vector(z[["vapour pressure deficit from temperature (May-Sep)"]]), use = "complete.obs")
cat(sprintf("\nvapour pressure deficit from temperature alone against PRISM's, cell-year z-scores: correlation %.2f\n", vp))
# leave the peak years out: does the best index still order the other years?
top <- best[1]; X <- win(z[[top$Index]], top$Years, top$Lag); mu <- colSums(X * wt, na.rm = TRUE) / sum(wt); pk <- order(rate, decreasing = TRUE)[1:5]
cat(sprintf("best index (%s, %d years, lag %d): rank correlation %.2f over all years, %.2f without the 5 highest years (%s)\n", top$Index, top$Years, top$Lag,
            cor(mu, rate, method = "spearman"), cor(mu[-pk], rate[-pk], method = "spearman"), paste(sort(yrs[pk]), collapse = ", ")))

# ---- figure: the yearly rate with the best window of four indexes ----------------------------------------------------------------
png(file.path(odir, "climate-index-look.png"), width = 2200, height = 1500, res = 170); par(mfrow = c(2, 2), mar = c(3, 4, 3, 4), mgp = c(2.2, 0.7, 0))
for (nm in best$Index[1:4]) { b <- best[Index == nm]; X <- win(z[[nm]], b$Years, b$Lag); mu <- colSums(X * wt, na.rm = TRUE) / sum(wt)
  barplot(100 * rate, names.arg = yrs, col = "grey75", border = NA, ylab = "mortality, % of open forest per year", las = 2, cex.names = 0.6, space = 0)
  par(new = TRUE); plot(seq_along(yrs) - 0.5, mu, type = "l", lwd = 2.2, col = "#b2182b", axes = FALSE, xlab = "", ylab = "", xlim = c(0, length(yrs))); axis(4, col.axis = "#b2182b"); abline(h = 0, lty = 3, col = "#b2182b")
  title(sprintf("%s\nmean of %d yr, lag %d: rank cor %.2f, time share %.2f", nm, b$Years, b$Lag, b$RankCor, b$TimeShare), cex.main = 0.85) }
invisible(dev.off()); cat("written:", file.path(odir, c("climate-index-scores.csv", "climate-index-look.png")), "\n")
