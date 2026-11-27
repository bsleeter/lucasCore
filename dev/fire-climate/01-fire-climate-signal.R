# =============================================================================
# 01-fire-climate-signal.R - to-do 9: how strongly does yearly burned area follow fire-season climate, by pyrome?
# =============================================================================
# Burned area by pyrome and year from the MTBS burned-area boundaries (wildfire and wildland fire use; prescribed fire left out),
# 1984-2023, against climate indexes of the same pyrome and year from PRISM 800 m monthly precipitation, maximum and minimum
# temperature (and PRISM's own maximum VPD, for comparison only: LOCA2 has precipitation and temperature alone, so every index a
# projection can use must come from those three). Each index is a z-score of the pyrome against its own 1984-2023 years.
# Per pyrome and index:
#   rho       Spearman correlation of burned area with the index
#   rhoDetr   the same after both are detrended (a shared trend is not a year-to-year signal)
#   slope     log change in burned area per SD of the index (quasi-Poisson GLM, log link), with its R2 on log(area + 1 km2)
#   later     fitted on 1984-2003, burned area predicted for 2004-2023 as a ratio of the observed, against the ratio the
#             1984-2003 mean gives (what a projection with no climate, from that period, would say)
# Usage: Rscript dev/fire-climate/01-fire-climate-signal.R <out folder> [--workers=16] [--first=1984] [--last=2023]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra); library(sf); library(parallel) }); options(width = 230); terraOptions(progress = 0)
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
odir <- a[!grepl("^--", a)][1]; dir.create(odir, showWarnings = FALSE, recursive = TRUE)
NW <- as.integer(opt("workers", 16)); Y1 <- as.integer(opt("first", 1984)); Y2 <- as.integer(opt("last", 2023))
PR <- "E:/lucasData/climate/prism/monthly-us30s"; PYF <- "E:/lucasData/study-area/pyromes/Pyromes_CONUS_20200206.shp"; MTF <- "E:/lucasData/disturbance/mtbs-perimeters/mtbs_perims_DD.shp"
source("src/mortality.R")   # mortality_deficit: the same monthly water balance the mortality climate settings use

# ---- pyromes and burned area ------------------------------------------------------------------------------------------------
py <- st_read(PYF, quiet = TRUE); py <- st_make_valid(st_transform(py, 5070)); py$km2 <- as.numeric(st_area(py)) / 1e6
cen <- st_coordinates(st_transform(st_centroid(st_geometry(py)), 4326)); py$lon <- cen[, 1]; py$lat <- cen[, 2]
bf <- file.path(odir, "burned.rds")
if (!file.exists(bf)) {
  m <- st_read(MTF, quiet = TRUE); m$year <- as.integer(substr(as.character(m$ig_date), 1, 4))
  cat("MTBS types:", paste(sprintf("%s %d", names(table(m$incid_type)), table(m$incid_type)), collapse = "; "), "\n")
  m <- m[m$incid_type %in% c("Wildfire", "Wildland Fire Use", "Unknown") & m$year >= Y1 & m$year <= Y2, ]
  m <- st_make_valid(st_transform(m, 5070)); x <- suppressWarnings(st_intersection(m[, c("event_id", "year")], py[, "PYROME"]))
  b <- data.table(PYROME = x$PYROME, year = x$year, km2 = as.numeric(st_area(x)) / 1e6)[, .(km2 = sum(km2), fires = .N), by = .(PYROME, year)]
  saveRDS(b, bf) }
b <- readRDS(bf)

# ---- PRISM monthly means by pyrome ------------------------------------------------------------------------------------------
cf <- file.path(odir, "prism-pyrome.rds")
if (!file.exists(cf)) {
  f0 <- file.path(PR, "tmax", "prism_tmax_us_30s_198401.tif"); z <- rasterize(vect(st_transform(py, crs(rast(f0)))), rast(f0), "PYROME"); zf <- file.path(odir, "pyrome-zones.tif"); writeRaster(z, zf, overwrite = TRUE)
  job <- CJ(v = c("ppt", "tmax", "tmin", "vpdmax"), y = (Y1 - 3L):Y2, m = 1:12)
  cl <- makeCluster(NW); on.exit(stopCluster(cl), add = TRUE)
  clusterExport(cl, c("PR", "zf")); clusterEvalQ(cl, { suppressPackageStartupMessages(library(terra)); terraOptions(progress = 0); z <- rast(zf); NULL })
  t0 <- Sys.time()
  res <- parLapply(cl, split(job, seq_len(nrow(job)) %% (NW * 4)), function(jj) do.call(rbind, lapply(seq_len(nrow(jj)), function(i) {
    f <- file.path(PR, jj$v[i], sprintf("prism_%s_us_30s_%d%02d.tif", jj$v[i], jj$y[i], jj$m[i])); if (!file.exists(f)) return(NULL)
    zz <- zonal(rast(f), z, "mean", na.rm = TRUE); data.frame(v = jj$v[i], y = jj$y[i], m = jj$m[i], PYROME = zz[[1]], value = zz[[2]]) })))
  cl_res <- rbindlist(res); cat(sprintf("PRISM: %d pyrome-months read in %.1f min\n", nrow(cl_res), as.numeric(Sys.time() - t0, units = "mins")))
  saveRDS(cl_res, cf) }
pm <- dcast(readRDS(cf), PYROME + y + m ~ v, value.var = "value"); setorder(pm, PYROME, y, m)

# ---- indexes by pyrome and year (fire season May-September; water year October-September) ------------------------------------
es <- function(t) 0.6108 * exp(17.27 * t / (t + 237.3))   # kPa
FS <- 5:9
ix <- pm[, { lat <- py$lat[match(PYROME[1], py$PYROME)]; d <- mortality_deficit(y, m, pmax(ppt, 0), tmax, tmin, lat)
  wy <- y + (m >= 10L); vpa <- es(tmax) - es(tmin)
  yrs <- Y1:Y2
  .(year = yrs,
    Tmax = vapply(yrs, function(k) mean(tmax[y == k & m %in% FS]), 0),
    VpdPrism = vapply(yrs, function(k) mean(vpdmax[y == k & m %in% FS]), 0),
    VpdTemp = vapply(yrs, function(k) mean(vpa[y == k & m %in% FS]), 0),
    Deficit = as.numeric(d[as.character(yrs)]),
    PrecipSeason = vapply(yrs, function(k) -sum(ppt[y == k & m %in% FS]), 0),
    PrecipWater = vapply(yrs, function(k) -sum(ppt[wy == k]), 0),
    PrecipPrior = vapply(yrs, function(k) sum(ppt[wy == k - 1L]), 0),
    Deficit2 = vapply(yrs, function(k) mean(d[as.character((k - 1L):k)]), 0)) }, by = PYROME]
# (precipitation of the season and water year with the sign turned, so that for every index but PrecipPrior higher = drier)
ix[, Hot.Dry := NA_real_]
zs <- function(v) (v - mean(v, na.rm = TRUE)) / sd(v, na.rm = TRUE)
IDX <- c("Tmax", "VpdPrism", "VpdTemp", "Deficit", "Deficit2", "PrecipSeason", "PrecipWater", "PrecipPrior")
for (k in IDX) ix[, (k) := zs(get(k)), by = PYROME]
ix[, Hot.Dry := zs(Tmax + PrecipSeason), by = PYROME]; IDX <- c(IDX, "Hot.Dry")
dt <- merge(ix, b, by = c("PYROME", "year"), all.x = TRUE); dt[is.na(km2), `:=`(km2 = 0, fires = 0L)]
dt <- merge(dt, data.table(PYROME = py$PYROME, NAME = py$NAME, pkm2 = py$km2, lon = py$lon, lat = py$lat), by = "PYROME")
fwrite(dt, file.path(odir, "pyrome-year.csv"))

# ---- scores --------------------------------------------------------------------------------------------------------------
score <- function(d, k) { x <- d[[k]]; yb <- d$km2; ok <- !is.na(x); x <- x[ok]; yb <- yb[ok]; yr <- d$year[ok]
  if (sum(yb > 0) < 8) return(NULL)
  dtr <- function(v) resid(lm(v ~ yr))
  g <- tryCatch(glm(yb ~ x, family = quasipoisson()), error = function(e) NULL); s <- if (is.null(g)) NA_real_ else unname(coef(g)[2])
  ly <- log(yb + 1); r2 <- summary(lm(ly ~ x))$r.squared
  e <- yr <= 2003; l <- !e; later <- NA_real_; base <- NA_real_
  if (sum(yb[e] > 0) >= 5) { ge <- tryCatch(glm(yb[e] ~ x[e], family = quasipoisson()), error = function(e) NULL)
    if (!is.null(ge)) later <- sum(exp(coef(ge)[1] + coef(ge)[2] * x[l])) / sum(yb[l]); base <- mean(yb[e]) * sum(l) / sum(yb[l]) }; later <- unname(later)
  data.table(index = k, rho = cor(x, yb, method = "spearman"), rhoDetr = cor(dtr(x), dtr(yb), method = "spearman"), slope = s, r2 = r2, later = later, base = base) }
sc <- dt[, rbindlist(lapply(IDX, function(k) score(.SD, k))), by = .(PYROME, NAME, pkm2, lon, lat)]
burn <- dt[, .(meanKm2 = mean(km2), early = mean(km2[year <= 2003]), late = mean(km2[year > 2003]), yearsWithFire = sum(km2 > 0)), by = PYROME]
sc <- merge(sc, burn, by = "PYROME"); sc[, West := lon < -100]
fwrite(sc, file.path(odir, "pyrome-scores.csv"))

wm <- function(v, w) sum(v * w, na.rm = TRUE) / sum(w[!is.na(v)])
cat("\n== by index, pyromes weighted by mean burned area (West = centroid west of 100 W) ==\n")
print(sc[, .(pyromes = .N, rho = round(wm(rho, meanKm2), 2), rhoDetr = round(wm(rhoDetr, meanKm2), 2), slope = round(wm(slope, meanKm2), 2), r2 = round(wm(r2, meanKm2), 2),
             later_vs_obs = round(wm(later, meanKm2), 2), nochange_vs_obs = round(wm(base, meanKm2), 2)), by = .(West, index)][order(-West, -rho)])
cat("\n== the best index of each large western pyrome (mean burned area >= 50 km2/yr) ==\n")
best <- sc[West == TRUE & meanKm2 >= 50][order(PYROME, -rho)][, .SD[1], by = PYROME]
print(best[, .(PYROME, NAME, meanKm2 = round(meanKm2), early = round(early), late = round(late), index, rho = round(rho, 2), rhoDetr = round(rhoDetr, 2), slope = round(slope, 2), later = round(later, 2), base = round(base, 2))])
cat("\n== Pyrome 27 ==\n"); print(sc[PYROME == 27][order(-rho), .(index, rho = round(rho, 2), rhoDetr = round(rhoDetr, 2), slope = round(slope, 2), r2 = round(r2, 2), later = round(later, 2), base = round(base, 2))])
