# =============================================================================
# 06-itrdb-vs-miami.R - annual ring-width index vs the stage 7 Miami forest multiplier at each ITRDB site (1985 to the chronology end)
# =============================================================================
# Sites with >= 15 years of standard chronology since 1985 (PRISM annual on disk starts 1985). Per site: SD of the ring-width index
# (RWI) and of the Miami multiplier; slope of RWI on Miami (1 = Miami's interannual sensitivity matches ring growth); and RWI on the
# precipitation ratio (this year and last year) and temperature anomaly. Summaries by ecodivision.
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) })
for (v in c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA")) if (grepl("syncro", tolower(Sys.getenv(v)))) Sys.unsetenv(v)
OUT <- "F:/lucasCore/dev/climate"; PR <- "F:/lucas-master/Data Sources/Climate/prism"
sites <- fread(file.path(OUT, "itrdb-sites.csv"))[n_since1985 >= 15 & !is.na(lat)]
ser <- fread(file.path(OUT, "itrdb-series.csv"))[site %in% sites$site & year >= 1984]
pf <- function(var, y) Sys.glob(file.path(PR, "annual", var, "*", sprintf("PRISM_*_%d_bil.bil", y)))[1]
Tn <- rast(Sys.glob(file.path(PR, "normals", "PRISM_tmean_30yr_normal_*_annual_bil", "*.bil"))[1])
Pn <- rast(Sys.glob(file.path(PR, "normals", "PRISM_ppt_30yr_normal_*_annual_bil", "*.bil"))[1])
pts <- vect(sites, geom = c("lon", "lat"), crs = "EPSG:4326"); pts <- project(pts, crs(Tn))
ex <- function(r) extract(r, pts, ID = FALSE)[[1]]
tn <- ex(Tn); pn <- ex(Pn)
miami <- function(t, p) pmin(2540 / (1 + exp(1.584 - 0.0622 * t)), (0.551 * p^1.055) / exp(0.000306 * p))
cl <- rbindlist(lapply(1985:2023, function(y) { t <- ex(rast(pf("tmean", y))); p <- ex(rast(pf("precip", y)))
  data.table(site = sites$site, year = y, miami = miami(t, p) / miami(tn, pn), pratio = p / pn, tanom = t - tn) }))
cl[, pratio_lag := shift(pratio), by = site]
d <- merge(ser, cl, by = c("site", "year"))[!is.na(miami)]
d <- merge(d, sites[, .(site, ecodiv, species, elev)], by = "site")
st <- d[, { m1 <- lm(rwi ~ miami); ok2 <- sum(!is.na(pratio_lag)) >= 10
  m2 <- if (ok2) lm(rwi ~ pratio + pratio_lag + tanom) else NULL
  .(n = .N, sd_rwi = sd(rwi), sd_miami = sd(miami), r_miami = cor(rwi, miami), slope_miami = coef(m1)[2],
    b_p = if (ok2) coef(m2)["pratio"] else NA_real_, b_plag = if (ok2) coef(m2)["pratio_lag"] else NA_real_, b_t = if (ok2) coef(m2)["tanom"] else NA_real_,
    r2_p = if (ok2) summary(m2)$r.squared else NA_real_) }, by = .(site, ecodiv, species)]
fwrite(st, file.path(OUT, "itrdb-site-fits.csv"))
cat(nrow(st), "sites,", sum(st$n), "site-years\n\n")
q <- function(v) sprintf("%.2f [%.2f-%.2f]", median(v, na.rm = TRUE), quantile(v, 0.25, na.rm = TRUE), quantile(v, 0.75, na.rm = TRUE))
cat("Median [IQR] across sites:\n")
cat("  SD of ring-width index      ", q(st$sd_rwi), "\n  SD of Miami multiplier      ", q(st$sd_miami), "\n  ratio SD(RWI)/SD(Miami)     ", q(st$sd_rwi / st$sd_miami),
    "\n  correlation RWI vs Miami    ", q(st$r_miami), "\n  slope RWI on Miami          ", q(st$slope_miami),
    "\n  RWI per precip ratio        ", q(st$b_p), "\n  RWI per last year's precip  ", q(st$b_plag), "\n  RWI per +1 C               ", q(st$b_t), "\n  R2 precip+lag+temp          ", q(st$r2_p), "\n")
cat("\nBy ecodivision (sites >= 5):\n")
print(st[, .(sites = .N, sd_rwi = round(median(sd_rwi), 2), sd_miami = round(median(sd_miami), 2), r = round(median(r_miami), 2), slope = round(median(slope_miami), 2),
             b_p = round(median(b_p, na.rm = TRUE), 2), b_plag = round(median(b_plag, na.rm = TRUE), 2)), by = ecodiv][sites >= 5][order(-sites)])
cat("\nBy species (sites >= 8):\n")
print(st[, .(sites = .N, sd_rwi = round(median(sd_rwi), 2), r = round(median(r_miami), 2), slope = round(median(slope_miami), 2)), by = species][sites >= 8][order(-sites)])
