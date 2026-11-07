# =============================================================================
# 05-rap-climate-fit.R - a yearly climate response of grass and shrub growth fitted to RAP NPP (to-do 39 step 7)
# =============================================================================
# The tree-ring method (dev/climate/07-itrdb-full-period.R) on RAP: per window and life form, the year's NPP over its 1991-2020 mean
# (the PRISM normal period, so 1.0 = normal climate, as every climate multiplier in the model) is regressed on
#   ratio = 1 + bp (P / P normal - 1) + bl (P last year / P normal - 1) + bt (T - T normal)
# with P and T from annual PRISM at the window centre (04-rap-climate-sample.R). Life forms are the model's classes grouped by how they
# grow: Annual grass (Grassland: Annual), Perennial grass (Natural and Irrigated Perennial), Shrub (every Shrubland class). NPP is the
# class's total RAP herb + shrub NPP, the quantity its growth rows hold. A window x life form needs MIN_CELLS cells and MIN_YEARS years.
# Coefficients are pooled by ecodivision x life form with a random-effects (DerSimonian-Laird) mean; with fewer than MIN_WINDOWS
# windows the life form's CONUS pool is used.
# Checks:
#   skill    leave-one-window-out: each window predicted from the other windows' pool, against Miami NPP (the non-forest multiplier
#            today, f(P) / f(P normal), Lieth 1975) and against the window's mean (no climate)
#   placebo  the same fit with the years' climate shuffled (one permutation for all windows, so spatial patterns stay): coefficients
#            should be about 0; repeated PLACEBO times
# Writes dev/nonforest/05-rap-climate-{window-fits,pooled,skill,placebo}.csv.
# Usage: Rscript dev/nonforest/05-rap-climate-fit.R
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages(library(data.table))
MIN_CELLS <- 50; MIN_YEARS <- 30; MIN_WINDOWS <- 5; PLACEBO <- 20; NORMAL <- 1991:2020; OUT <- file.path(pkg, "dev", "nonforest")
s <- fread(file.path(OUT, "04-rap-climate-sample.csv"))[is.na(error) | error == ""]
s[, LifeForm := fifelse(StateClassId == "Grassland: Annual", "Annual grass", fifelse(startsWith(StateClassId, "Grassland"), "Perennial grass", fifelse(startsWith(StateClassId, "Shrubland"), "Shrub", NA_character_)))]
s <- s[!is.na(LifeForm)]
# one row per window x life form x year: the cell-weighted mean NPP of its classes
d <- s[, .(cells = sum(cells), npp = weighted.mean(NppAnnual + NppPerennial + NppShrub, nppCells, na.rm = TRUE), Ppt = Ppt[1], PptLag = PptLag[1], Tmean = Tmean[1],
           PptNormal = PptNormal[1], TmeanNormal = TmeanNormal[1]), by = .(StratumId, window, LifeForm, Year)]
d <- d[cells >= MIN_CELLS & is.finite(npp) & !is.na(Ppt) & !is.na(PptLag)]
d[, nppNormal := mean(npp[Year %in% NORMAL]), by = .(StratumId, window, LifeForm)]
d <- d[nppNormal > 0.05]   # windows with almost no growth give ratios of noise
d[, `:=`(ratio = npp / nppNormal, pratio = Ppt / PptNormal, pratio_lag = PptLag / PptNormal, tanom = Tmean - TmeanNormal)]
miami_nf <- function(p) 6116 * (1 - exp(-6.05e-5 * p)); d[, miami := miami_nf(Ppt) / miami_nf(PptNormal)]
d[, n := .N, by = .(StratumId, window, LifeForm)]; d <- d[n >= MIN_YEARS]
cat(sprintf("%d windows x life forms, %d window-years\n", uniqueN(d[, paste(StratumId, window, LifeForm)]), nrow(d)))
print(d[, .(windows = uniqueN(paste(StratumId, window))), by = .(LifeForm)][order(LifeForm)])

# ---- per window fits, pooled ------------------------------------------------------------------------------------------------
fit <- function(x, y = "ratio") { b <- summary(lm(as.formula(sprintf("%s ~ pratio + pratio_lag + tanom", y)), data = x))$coef
  if (nrow(b) < 4) return(NULL)
  list(n = nrow(x), sd_ratio = sd(x$ratio), r_miami = cor(x$ratio, x$miami), b0 = b[1, 1], bp = b["pratio", 1], bp_se = b["pratio", 2], bl = b["pratio_lag", 1], bl_se = b["pratio_lag", 2], bt = b["tanom", 1], bt_se = b["tanom", 2]) }
wf <- d[, fit(.SD), by = .(StratumId, window, LifeForm)]
dl <- function(est, se) { ok <- is.finite(est) & is.finite(se) & se > 0; est <- est[ok]; se <- se[ok]; if (length(est) < 2) return(c(mean = NA, se = NA))
  w <- 1 / se^2; m <- sum(w * est) / sum(w); Q <- sum(w * (est - m)^2); k <- length(est)
  tau2 <- max(0, (Q - (k - 1)) / (sum(w) - sum(w^2) / sum(w))); ws <- 1 / (se^2 + tau2); c(mean = sum(ws * est) / sum(ws), se = sqrt(1 / sum(ws))) }
pool <- function(x) { a <- dl(x$bp, x$bp_se); b <- dl(x$bl, x$bl_se); t <- dl(x$bt, x$bt_se)
  data.table(windows = nrow(x), PrecipCoef = a[["mean"]], PrecipSe = a[["se"]], PrecipLagCoef = b[["mean"]], PrecipLagSe = b[["se"]], TempCoef = t[["mean"]], TempSe = t[["se"]]) }
conus <- wf[, pool(.SD), by = LifeForm]
eco <- wf[, pool(.SD), by = .(StratumId, LifeForm)]
eco[, Source := fifelse(windows >= MIN_WINDOWS & is.finite(PrecipCoef), "ecodivision", "CONUS life form")]
for (k in c("PrecipCoef", "PrecipLagCoef", "TempCoef")) eco[Source != "ecodivision", (k) := conus[[k]][match(LifeForm, conus$LifeForm)]]
cat("\nCONUS pools by life form (ratio per unit precipitation ratio; per degree C):\n"); print(conus[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 3) else v)])
cat("\nBy ecodivision:\n"); print(eco[order(LifeForm, -windows), .(LifeForm, StratumId, windows, Source, PrecipCoef = round(PrecipCoef, 3), PrecipLagCoef = round(PrecipLagCoef, 3), TempCoef = round(TempCoef, 3))], nrows = 100)

# ---- leave-one-window-out skill ---------------------------------------------------------------------------------------------
sk <- rbindlist(lapply(split(wf, by = c("StratumId", "window", "LifeForm")), function(me) {
  oth <- wf[LifeForm == me$LifeForm & StratumId == me$StratumId & !(window == me$window)]; if (nrow(oth) < MIN_WINDOWS) oth <- wf[LifeForm == me$LifeForm & !(StratumId == me$StratumId & window == me$window)]
  cf <- pool(oth); x <- d[StratumId == me$StratumId & window == me$window & LifeForm == me$LifeForm]
  p_rap <- 1 + cf$PrecipCoef * (x$pratio - 1) + cf$PrecipLagCoef * (x$pratio_lag - 1) + cf$TempCoef * x$tanom
  sc <- function(p) c(rmse = sqrt(mean((x$ratio - p)^2)), r = suppressWarnings(cor(x$ratio, p)), sd_ratio = sd(p) / sd(x$ratio))
  data.table(StratumId = me$StratumId, window = me$window, LifeForm = me$LifeForm, model = c("Miami NPP (today)", "RAP response"), rbind(sc(x$miami), sc(p_rap)),
             base_rmse = sqrt(mean((x$ratio - mean(x$ratio))^2))) }))
cat("\nLeave-one-window-out skill (median over windows); 'better than mean' = share of windows where the model beats the window's own mean:\n")
print(sk[, .(rmse = round(median(rmse), 3), r = round(median(r, na.rm = TRUE), 2), sd_pred_over_sd_obs = round(median(sd_ratio), 2), better_than_mean = round(mean(rmse < base_rmse), 2)), by = .(LifeForm, model)][order(LifeForm, model)])

# ---- placebo: shuffled years ------------------------------------------------------------------------------------------------
set.seed(20261107); yrs <- sort(unique(d$Year))
pl <- rbindlist(lapply(seq_len(PLACEBO), function(i) { perm <- setNames(sample(yrs), yrs)
  cl <- unique(d[, .(StratumId, window, Year, pratio, pratio_lag, tanom)]); cl[, Year := as.integer(perm[as.character(Year)])]
  x <- merge(d[, .(StratumId, window, LifeForm, Year, ratio, miami)], cl, by = c("StratumId", "window", "Year"))
  f <- x[, fit(.SD), by = .(StratumId, window, LifeForm)]; f[, pool(.SD), by = LifeForm][, draw := i] }))
cat("\nPlacebo (climate of shuffled years), CONUS pools: mean and 95% range over draws, against the real fit:\n")
print(merge(pl[, .(placebo_bp = sprintf("%.3f (%.3f, %.3f)", mean(PrecipCoef), quantile(PrecipCoef, .025), quantile(PrecipCoef, .975)),
                   placebo_bt = sprintf("%.4f (%.4f, %.4f)", mean(TempCoef), quantile(TempCoef, .025), quantile(TempCoef, .975))), by = LifeForm],
            conus[, .(LifeForm, real_bp = round(PrecipCoef, 3), real_bt = round(TempCoef, 4))], by = "LifeForm"))
fwrite(wf, file.path(OUT, "05-rap-climate-window-fits.csv")); fwrite(rbind(conus[, StratumId := "CONUS"][, Source := "CONUS life form"], eco, fill = TRUE), file.path(OUT, "05-rap-climate-pooled.csv"))
fwrite(sk, file.path(OUT, "05-rap-climate-skill.csv")); fwrite(pl, file.path(OUT, "05-rap-climate-placebo.csv"))
cat("wrote dev/nonforest/05-rap-climate-*.csv\n")
