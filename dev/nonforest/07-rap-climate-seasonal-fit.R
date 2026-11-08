# =============================================================================
# 07-rap-climate-seasonal-fit.R - the grass and shrub climate response the model uses: seasons + aridity, half variance-scaled (to-do 39 step 7)
# =============================================================================
# (user, 2026-11-07: use model SD half-scaled.) 06-rap-climate-explore.R found model SD the best everywhere in leave-one-window-out
# prediction: the water year's rain split into four seasons, last water year's rain and the temperature anomaly, with the slopes of
# the rain terms varying with aridity, one fit over every life form per ecodivision:
#   NPP ratio - 1 = sum over seasons k of (b_k + a_k ar) s_k + (b_l + a_l ar) pl + b_t ta          (no a_JAS: summer rain is small)
#   s_k = (season k's rain - its 1991-2020 normal) / the water year's normal;  pl = last water year / normal - 1;  ta = T - T normal
#   ar  = log(the water year's normal / 500 mm)
# It reproduces about half of RAP's year-to-year SD; scaling the response by k^0.5 (k = RAP's SD over the fit's in the ecodivision)
# reproduces about three quarters at a 4-7% RMSE cost. The scale is folded into the coefficients (the model is linear, no intercept).
# The window-years' range of ar per ecodivision is kept: the model clamps ar to it (the interaction is not extrapolated).
# An ecodivision with fewer than MIN_WINDOWS (30) windows takes the CONUS fit (fitted and scaled over every window): with 10 terms, the
# fits of the small ones (6-28 windows) turned rain slopes strongly negative at one end of their aridity range.
# Reads 04-rap-climate-sample.csv and PRISM monthly precipitation (PRISM env: a home's climate/prism).
# Writes dev/nonforest/07-rap-climate-seasonal-fit.csv, which tools/make_rap_climate_coefficients.R turns into the package default.
# Usage: PRISM=<dir> Rscript dev/nonforest/07-rap-climate-seasonal-fit.R
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages({ library(data.table); library(terra) }); options(width = 200)
PRISM <- Sys.getenv("PRISM"); if (!dir.exists(PRISM)) stop("set PRISM to a home's climate/prism")
OUT <- file.path(pkg, "dev", "nonforest"); NORMAL <- 1991:2020; MIN_CELLS <- 50; MIN_YEARS <- 30; MIN_WINDOWS <- 30; ALPHA <- 0.5
s <- fread(file.path(OUT, "04-rap-climate-sample.csv"))[is.na(error) | error == ""]
s[, LifeForm := fifelse(StateClassId == "Grassland: Annual", "Annual grass", fifelse(startsWith(StateClassId, "Grassland"), "Perennial grass", fifelse(startsWith(StateClassId, "Shrubland"), "Shrub", NA_character_)))]
d <- s[!is.na(LifeForm), .(cells = sum(cells), npp = weighted.mean(NppAnnual + NppPerennial + NppShrub, nppCells, na.rm = TRUE), WyPptLag = WyPptLag[1],
       WyPptNormal = WyPptNormal[1], Tmean = Tmean[1], TmeanNormal = TmeanNormal[1], x = x[1], y = y[1]), by = .(StratumId, window, LifeForm, Year)]
d <- d[cells >= MIN_CELLS & is.finite(npp)]
d[, nppNormal := mean(npp[Year %in% NORMAL]), by = .(StratumId, window, LifeForm)]; d <- d[nppNormal > 0.05]

# ---- seasonal water-year precipitation at the window centres (as 06) ---------------------------------------------------------
ctr <- unique(d[, .(StratumId, window, x, y)]); pts <- vect(as.matrix(ctr[, .(x, y)]), crs = "EPSG:5070")
yrs <- sort(unique(d$Year)); mons <- unique(unlist(lapply(c(yrs, NORMAL), function(y) c(sprintf("%d%02d", y - 1, 10:12), sprintf("%d%02d", y, 1:9)))))
mf <- file.path(PRISM, "monthly-us25m", "ppt", sprintf("prism_ppt_us_25m_%s.tif", mons)); if (!all(file.exists(mf))) stop("PRISM monthly missing")
mv <- as.matrix(terra::extract(rast(mf), project(pts, crs(rast(mf[1]))), method = "bilinear", ID = FALSE)); colnames(mv) <- mons
season <- list(OND = 10:12, JFM = 1:3, AMJ = 4:6, JAS = 7:9)
sp <- function(y, k) { m <- if (k == "OND") sprintf("%d%02d", y - 1, 10:12) else sprintf("%d%02d", y, season[[k]]); rowSums(mv[, m, drop = FALSE]) }
sea <- rbindlist(lapply(yrs, function(y) data.table(ctr[, .(StratumId, window)], Year = y, OND = sp(y, "OND"), JFM = sp(y, "JFM"), AMJ = sp(y, "AMJ"), JAS = sp(y, "JAS"))))
nrs <- ctr[, .(StratumId, window)]; for (k in names(season)) nrs[, (paste0(k, "n")) := Reduce(`+`, lapply(NORMAL, function(y) sp(y, k))) / length(NORMAL)]
d <- merge(merge(d, sea, by = c("StratumId", "window", "Year")), nrs, by = c("StratumId", "window"))
for (k in names(season)) d[, (paste0("s_", k)) := (get(k) - get(paste0(k, "n"))) / WyPptNormal]
d[, `:=`(ratio = npp / nppNormal, pl = WyPptLag / WyPptNormal - 1, ta = Tmean - TmeanNormal, ar = log(WyPptNormal / 500))]
d <- d[is.finite(s_OND) & is.finite(pl)]; d[, n := .N, by = .(StratumId, window, LifeForm)]; d <- d[n >= MIN_YEARS]
d[, win := paste(StratumId, window, LifeForm)]
cat(sprintf("%d windows x life forms, %d window-years\n", uniqueN(d$win), nrow(d)))

# ---- fit, scale, write -------------------------------------------------------------------------------------------------------
FORM <- I(ratio - 1) ~ 0 + s_OND + s_JFM + s_AMJ + s_JAS + pl + ta + s_OND:ar + s_JFM:ar + s_AMJ:ar + pl:ar
TERMS <- c(s_OND = "OndCoef", s_JFM = "JfmCoef", s_AMJ = "AmjCoef", s_JAS = "JasCoef", pl = "PrecipLagCoef", ta = "TempCoef",
           `s_OND:ar` = "OndAridCoef", `s_JFM:ar` = "JfmAridCoef", `s_AMJ:ar` = "AmjAridCoef", `pl:ar` = "PrecipLagAridCoef")
fit1 <- function(G, label) { f <- lm(FORM, data = G); cf <- coef(f); p <- 1 + fitted(f)
  k <- sd(G$ratio) / sd(p); sc <- k^ALPHA
  q <- 1 + sc * (p - 1)
  data.table(StratumId = label, Windows = uniqueN(G$win), WindowYears = nrow(G), Scale = sc, R2 = summary(f)$r.squared,
             SdRatioUnscaled = sd(p) / sd(G$ratio), SdRatioScaled = sd(q) / sd(G$ratio), AridMin = min(G$ar), AridMax = max(G$ar)
             )[, (unname(TERMS)) := as.list(sc * cf[names(TERMS)])][] }
eco <- rbindlist(lapply(split(d, by = "StratumId"), function(G) if (uniqueN(G$win) >= MIN_WINDOWS) fit1(G, G$StratumId[1])))
conus <- fit1(d, "CONUS")
out <- rbind(eco, conus); setorder(out, StratumId)
fwrite(out, file.path(OUT, "07-rap-climate-seasonal-fit.csv"))
print(out[, lapply(.SD, function(v) if (is.numeric(v)) signif(v, 3) else v)])
cat(sprintf("ecodivisions with fewer than %d windows take the CONUS fit; wrote dev/nonforest/07-rap-climate-seasonal-fit.csv\n", MIN_WINDOWS))
