# =============================================================================
# 07-itrdb-full-period.R - tree-ring benchmark over the full PRISM record (1895-2023, current PRISM release, us_25m)
# =============================================================================
# Sites with >= 30 years of standard chronology overlapping 1896..2023. Climate at each site from the annual PRISM files in
# prism/annual-us25m; anomalies against the 1991-2020 mean of the same files (one release throughout).
# Per site: (A) RWI ~ Miami forest multiplier (slope beta: 1 = Miami's sensitivity matches ring growth);
#           (B) RWI ~ precip ratio + last year's precip ratio + temperature anomaly.
# Pooled by ecodivision with a random-effects (DerSimonian-Laird) mean of the site coefficients.
# Leave-one-site-out skill: predict a site's RWI from (1) raw Miami, (2) Miami damped by its ecodivision beta (fitted without the
# site), (3) the (B) response with its ecodivision coefficients (fitted without the site). Writes dev/climate/itrdb-full-*.csv.
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) })
for (v in c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA")) if (grepl("syncro", tolower(Sys.getenv(v)))) Sys.unsetenv(v)
OUT <- "F:/lucasCore/dev/climate"; PR <- "F:/lucas-master/Data Sources/Climate/prism/annual-us25m"
YRS <- 1895:2023
tfile <- function(v, y) file.path(PR, v, sprintf("prism_%s_us_25m_%d.tif", v, y))
miss <- c(YRS[!file.exists(tfile("tmean", YRS))], YRS[!file.exists(tfile("ppt", YRS))]); if (length(miss)) stop("PRISM files missing: ", paste(unique(miss), collapse = ", "))
sites <- fread(file.path(OUT, "itrdb-sites.csv"))[!is.na(lat) & !is.na(ecodiv)]
ser <- fread(file.path(OUT, "itrdb-series.csv"))[site %in% sites$site & year %between% c(1895, 2023)]
pts <- project(vect(sites, geom = c("lon", "lat"), crs = "EPSG:4326"), crs(rast(tfile("tmean", 2000))))
Tr <- rast(tfile("tmean", YRS)); Pr <- rast(tfile("ppt", YRS))
tv <- as.matrix(extract(Tr, pts, ID = FALSE)); pv <- as.matrix(extract(Pr, pts, ID = FALSE))
ni <- which(YRS %in% 1991:2020); tn <- rowMeans(tv[, ni]); pn <- rowMeans(pv[, ni])
miami <- function(t, p) pmin(2540 / (1 + exp(1.584 - 0.0622 * t)), (0.551 * p^1.055) / exp(0.000306 * p))
cl <- data.table(site = rep(sites$site, length(YRS)), year = rep(YRS, each = nrow(sites)), t = as.vector(tv), p = as.vector(pv),
                 tn = rep(tn, length(YRS)), pn = rep(pn, length(YRS)))
cl[, `:=`(miami = miami(t, p) / miami(tn, pn), pratio = p / pn, tanom = t - tn)]
setorder(cl, site, year); cl[, pratio_lag := shift(pratio), by = site]
d <- merge(ser, cl[, .(site, year, miami, pratio, pratio_lag, tanom)], by = c("site", "year"))[!is.na(miami) & !is.na(pratio_lag)]
d[, n := .N, by = site]; d <- d[n >= 30]
d <- merge(d, sites[, .(site, ecodiv, species)], by = "site")
cat(sprintf("%d sites, %d site-years (%d-%d)\n", uniqueN(d$site), nrow(d), min(d$year), max(d$year)))
print(d[, .(sites = uniqueN(site)), by = ecodiv][order(-sites)])

# ---- per-site fits ----------------------------------------------------------------------------------------------------
st <- d[, { a <- summary(lm(rwi ~ miami))$coef; b <- summary(lm(rwi ~ pratio + pratio_lag + tanom))$coef
  .(n = .N, sd_rwi = sd(rwi), sd_miami = sd(miami), r = cor(rwi, miami), beta = a["miami", 1], beta_se = a["miami", 2],
    bp = b["pratio", 1], bp_se = b["pratio", 2], bl = b["pratio_lag", 1], bl_se = b["pratio_lag", 2], bt = b["tanom", 1], bt_se = b["tanom", 2]) },
  by = .(site, ecodiv, species)]
# random-effects mean (DerSimonian-Laird) of a coefficient over sites
dl <- function(est, se) { w <- 1 / se^2; m <- sum(w * est) / sum(w); Q <- sum(w * (est - m)^2); k <- length(est)
  tau2 <- max(0, (Q - (k - 1)) / (sum(w) - sum(w^2) / sum(w))); ws <- 1 / (se^2 + tau2); c(mean = sum(ws * est) / sum(ws), se = sqrt(1 / sum(ws)), tau = sqrt(tau2)) }
pool <- function(s) { if (nrow(s) < 2) return(data.table(beta = NA_real_, bp = NA_real_, bl = NA_real_, bt = NA_real_))
  data.table(beta = dl(s$beta, s$beta_se)[["mean"]], bp = dl(s$bp, s$bp_se)[["mean"]], bl = dl(s$bl, s$bl_se)[["mean"]], bt = dl(s$bt, s$bt_se)[["mean"]]) }
allp <- pool(st)
eco <- st[, c(.(sites = .N, sd_rwi = median(sd_rwi), sd_miami = median(sd_miami), r = median(r)), pool(.SD)), by = ecodiv][order(-sites)]
cat("\nPooled (random effects), all sites:\n"); print(round(allp, 3))
cat("\nBy ecodivision:\n"); print(eco[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])

# ---- leave-one-site-out skill -------------------------------------------------------------------------------------------
# a site's coefficients come from the other sites of its ecodivision (random-effects mean), or all other sites when fewer than 3
sk <- rbindlist(lapply(unique(st$site), function(s) { me <- st[site == s]; oth <- st[site != s & ecodiv == me$ecodiv]
  if (nrow(oth) < 3) oth <- st[site != s]; cf <- pool(oth); x <- d[site == s]
  p1 <- x$miami; p2 <- 1 + cf$beta * (x$miami - 1); p3 <- 1 + cf$bp * (x$pratio - 1) + cf$bl * (x$pratio_lag - 1) + cf$bt * x$tanom
  sc <- function(p) c(rmse = sqrt(mean((x$rwi - p)^2)), r = cor(x$rwi, p), sd_ratio = sd(p) / sd(x$rwi))
  data.table(site = s, ecodiv = me$ecodiv, model = c("Miami (as built)", "Miami damped by ecodivision", "Tree-ring response"),
             rbind(sc(p1), sc(p2), sc(p3)), base_rmse = sqrt(mean((x$rwi - mean(x$rwi))^2))) }))
cat("\nLeave-one-site-out skill (median over sites): RMSE vs the site's own RWI; 'mean only' RMSE predicts each year with the site mean\n")
print(sk[, .(rmse = round(median(rmse), 3), r = round(median(r), 2), sd_pred_over_sd_rwi = round(median(sd_ratio), 2), better_than_mean = round(mean(rmse < base_rmse), 2)), by = model])
cat("mean only:", round(median(sk[model == "Miami (as built)", base_rmse]), 3), "\n")
cat("\nBy ecodivision, RMSE:\n"); print(dcast(sk[, .(rmse = round(median(rmse), 3)), by = .(ecodiv, model)], ecodiv ~ model, value.var = "rmse"))
fwrite(st, file.path(OUT, "itrdb-full-site-fits.csv")); fwrite(eco, file.path(OUT, "itrdb-full-ecodiv.csv")); fwrite(sk, file.path(OUT, "itrdb-full-skill.csv"))
