# =============================================================================
# 16-climate-feasibility.R - to-do 3: does yearly die-off in a test pyrome follow drought and temperature at all?
# =============================================================================
# A feasibility look before the national climate fit, not a fit: one pyrome gives about 32 yearly values, strongly correlated
# from year to year, so this can show whether there is a signal and at what lag, and cannot choose between predictors.
# Climate: PRISM 4 km in the data home (water-year precipitation from the monthly files, October to September; annual mean
# temperature), averaged over the pyrome's eligible conifer forest (weights = the forest pixel count of the rule's 300 m file).
# For windows of k = 1..4 years ending in a year: precipitation and temperature as standard scores against 1991-2020, and a
# crude moisture index (precipitation score minus temperature score; it stands in for a water balance index, which needs monthly
# temperature the home does not hold). The yearly rate (log) is set against each index 0 to 4 years earlier: rank correlation,
# raw and with the linear trend taken out of both (a rising rate and a warming climate correlate whether or not one drives the other).
# Usage: Rscript dev/mortality/16-climate-feasibility.R <rule-...-by-group.csv> <rule-...-300m.tif> <PRISM folder> <out csv>
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) })
a <- commandArgs(TRUE); terraOptions(progress = 0); options(width = 220)
d <- fread(a[1])[Year > min(Year)]; r <- rast(a[2])[[1]]; PR <- a[3]
w <- aggregate(r, 10, sum, na.rm = TRUE); p <- as.points(w, na.rm = TRUE); p <- p[values(p)[, 1] > 0, ]; wt <- values(p)[, 1]
yrs <- 1984:2023; f <- function(v, k) file.path(PR, v, sprintf("prism_%s_us_25m_%s.tif", basename(v), k))
pm <- rast(f("monthly-us25m/ppt", format(seq(as.Date("1983-10-01"), as.Date("2023-09-01"), by = "month"), "%Y%m"))); pp <- project(p, crs(pm))
mo <- as.matrix(extract(pm, pp)[, -1]); wm <- colSums(mo * wt, na.rm = TRUE) / sum(wt)                      # forest-weighted monthly precipitation
P <- vapply(seq_along(yrs), function(i) sum(wm[(12 * (i - 1) + 1):(12 * i)]), 0); names(P) <- yrs             # water year ending in September of the year
tm <- as.matrix(extract(rast(f("annual-us25m/tmean", yrs)), pp)[, -1]); Tm <- colSums(tm * wt, na.rm = TRUE) / sum(wt); names(Tm) <- yrs
cat(sprintf("%s: %d forest points; water-year precipitation mean %.0f mm (sd %.0f), mean temperature %.1f C; temperature trend %.2f C per decade\n", basename(dirname(a[1])), length(wt), mean(P), sd(P), mean(Tm), 10 * coef(lm(Tm ~ yrs))[2]))
roll <- function(x, k) { v <- frollmean(x, k); names(v) <- names(x); v }; z <- function(x) (x - mean(x[as.character(1991:2020)], na.rm = TRUE)) / sd(x[as.character(1991:2020)], na.rm = TRUE)
idx <- list(); for (k in 1:4) { pz <- z(roll(P, k)); tz <- z(roll(Tm, k)); idx[[sprintf("precip_%dyr", k)]] <- pz; idx[[sprintf("temp_%dyr", k)]] <- tz; idx[[sprintf("moisture_%dyr", k)]] <- pz - tz }
all <- d[, .(rate = 100 * sum(flagged_km2) / sum(forest_km2)), by = Year][order(Year)]; big <- d[, .(f = mean(forest_km2)), by = group][order(-f)][1:min(3, .N), group]
series <- c(list(`all groups` = all), lapply(setNames(big, paste("group", big)), function(g) d[group == g, .(rate = 100 * flagged_km2 / forest_km2), by = Year][order(Year)]))
dt <- function(y, x) residuals(lm(y ~ x)); out <- list()
for (nm in names(series)) { s <- series[[nm]]; y <- log(pmax(s$rate, 1e-4)); Y <- s$Year
  for (v in names(idx)) for (L in 0:4) { x <- idx[[v]][as.character(Y - L)]; ok <- !is.na(x)
    out[[length(out) + 1]] <- data.table(series = nm, index = v, lag = L, n = sum(ok), rho = cor(y[ok], x[ok], method = "spearman"), rho_detrended = cor(dt(y[ok], Y[ok]), dt(x[ok], Y[ok]), method = "spearman")) } }
out <- rbindlist(out); fwrite(out, a[4])
cat("\nrank correlation of the log yearly rate with the moisture index (precipitation score minus temperature score; negative = more die-off when drier and warmer), by window and lag, all groups:\n")
print(dcast(out[series == "all groups" & grepl("moisture", index)], index ~ lag, value.var = "rho")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])
cat("\nthe same with the linear trend taken out of both:\n")
print(dcast(out[series == "all groups" & grepl("moisture", index)], index ~ lag, value.var = "rho_detrended")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])
cat("\nprecipitation alone and temperature alone, trend taken out, all groups:\n")
print(dcast(out[series == "all groups" & !grepl("moisture", index)], index ~ lag, value.var = "rho_detrended")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])
cat("\nstrongest index and lag for each series (trend taken out), and the share of the variance in the log rate it would explain alone:\n")
print(out[, .SD[which.max(abs(rho_detrended))], by = series][, .(series, index, lag, rho = round(rho, 2), rho_detrended = round(rho_detrended, 2), r2_detrended_pct = round(100 * rho_detrended^2))])
cat(sprintf("\nwith %d years and %d index-lag pairs tried, the strongest of unrelated series would reach about |rho| = %.2f by chance (5%% level, ignoring year-to-year correlation, which makes it larger)\n",
            nrow(all), uniqueN(out[, .(index, lag)]), qnorm(1 - 0.025 / uniqueN(out[, .(index, lag)])) / sqrt(nrow(all) - 3)))
cat("\nyearly values, all groups:\n"); print(data.table(Year = all$Year, rate_pct = round(all$rate, 3), precip_z = round(idx$precip_1yr[as.character(all$Year)], 2), temp_z = round(idx$temp_1yr[as.character(all$Year)], 2), moisture_3yr = round(idx$moisture_3yr[as.character(all$Year)], 2)), nrows = 40)
