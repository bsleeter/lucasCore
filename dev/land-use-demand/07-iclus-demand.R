# =============================================================================
# 07-iclus-demand.R - urbanization from EPA ICLUS v2.1.1: which classes, which base decade, and the ratios (exploratory)
# =============================================================================
# From 06-iclus-county.R's county tables (pixels by class at each decade and the next, four runs). Questions:
#   1. which ICLUS classes stand for NLCD developed land? ICLUS classes are land uses by housing density (10 exurban low, 11 exurban
#      high, 12 suburban, 13 urban low, 14 urban high, 15 commercial, 16 industrial, 17 institutional, 18 transportation); NLCD's are
#      impervious cover. County areas of ICLUS 2010 class sets against NLCD 2010 developed (04-nlcd-county-change.R)
#   2. the base decade: 2000-2010 is two observed maps (US-NLUD), 2010-2020 the first modelled decade
#   3. the ratio of each later decade to the base, by SSP (the mean of the two climate models), nationally and by county
# Writes 07-iclus-ratios-national.csv.
# Usage: Rscript dev/land-use-demand/07-iclus-demand.R   (after 04 and 06)
# =============================================================================
pkg <- local({ d <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))); while (!file.exists(file.path(d, "package.xml")) && dirname(d) != d) d <- dirname(d); d })
suppressPackageStartupMessages(library(data.table)); OUT <- file.path(pkg, "dev/land-use-demand"); CA <- file.path(OUT, "cache"); say <- function(...) cat(sprintf(...), "\n")
RUNS <- c("ssp2_rcp45_hadgem2_es", "ssp2_rcp45_giss_e2_r", "ssp5_rcp85_hadgem2_es", "ssp5_rcp85_giss_e2_r"); PX <- 90 * 90 / 1e6
x <- rbindlist(lapply(RUNS, function(r) readRDS(file.path(CA, sprintf("06-iclus-%s.rds", r)))[, Run := r])); x[, Ssp := toupper(sub("_.*", "", Run))]
SETS <- list(`10-16 (exurban and up)` = 10:16, `11-16 (exurban high and up)` = 11:16, `12-16 (suburban and up)` = 12:16, `13-16 (urban and up)` = 13:16, `12-18 (suburban and up, institutional, transportation)` = 12:18)

# ---- 1. class sets against NLCD developed land in 2010 -----------------------------------------------------------------------------
n <- readRDS(file.path(CA, "04-nlcd-2010-2020.rds"))[, .(Nlcd = sum(N[a %in% 21:24]) * 900 / 1e6, Nlcd2224 = sum(N[a %in% 22:24]) * 900 / 1e6), by = Fips]
i10 <- x[Run == RUNS[1] & Year == 2010]
say("ICLUS 2010 class areas against NLCD 2010 developed land, by county (km2):")
print(rbindlist(lapply(names(SETS), function(k) { m <- merge(i10[a %in% SETS[[k]], .(Iclus = sum(N) * PX), by = Fips], n, by = "Fips")
  data.table(Classes = k, IclusKm2 = round(sum(m$Iclus)), NlcdKm2 = round(sum(m$Nlcd)), IclusOverNlcd = round(sum(m$Iclus) / sum(m$Nlcd), 2), Spearman = round(cor(m$Iclus, m$Nlcd, method = "spearman"), 2),
             OverNlcd2224 = round(sum(m$Iclus) / sum(m$Nlcd2224), 2)) })))
say("ICLUS 2010 area by class (thousand km2): %s", paste(i10[, .(k = sum(N) * PX / 1e3), by = a][order(a), sprintf("%d: %.0f", a, k)], collapse = ", "))

# ---- 2 and 3. new land in a class set by decade: from outside the set into it -------------------------------------------------------
nat <- rbindlist(lapply(names(SETS), function(k) x[!(a %in% SETS[[k]]) & b %in% SETS[[k]], .(Km2 = sum(N) * PX), by = .(Run, Ssp, Year)][, Classes := k]))
say("\nNew land in each class set, thousand km2 a decade (the mean of the two climate models; 2000 = the two observed maps):")
print(dcast(nat[, .(Km2 = mean(Km2) / 1e3), by = .(Classes, Ssp, Year)], Classes + Ssp ~ Year, value.var = "Km2")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 1) else v)])
say("For scale: NLCD new developed land 2010-2020 was 34.7 thousand km2; RPA's 2012-2020 step 35 thousand km2 a decade")
gc <- nat[Year >= 2010, .(Spread = max(Km2) / min(Km2)), by = .(Classes, Ssp, Year)]; say("The two climate models differ by at most %.0f%% in a decade's national area", 100 * (max(gc$Spread) - 1))
r <- nat[, .(Km2 = mean(Km2)), by = .(Classes, Ssp, Year)]; r[, Ratio := Km2 / Km2[Year == 2010], by = .(Classes, Ssp)]
fwrite(r[Year >= 2010][order(Classes, Ssp, Year)], file.path(OUT, "07-iclus-ratios-national.csv"))
say("\nNational ratio to 2010-2020 (the first modelled decade):"); print(dcast(r[Year >= 2020], Classes + Ssp ~ Year, value.var = "Ratio")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])

# ---- by county: how usable is a county's own ratio? (set 12-16) -------------------------------------------------------------------
K <- SETS[["12-16 (suburban and up)"]]
co <- x[!(a %in% K) & b %in% K, .(Km2 = sum(N) * PX), by = .(Fips, Run, Ssp, Year)][, .(Km2 = mean(Km2)), by = .(Fips, Ssp, Year)]
co <- co[CJ(Fips = unique(x$Fips), Ssp = unique(co$Ssp), Year = unique(co$Year)), on = .(Fips, Ssp, Year)]; co[is.na(Km2), Km2 := 0]
co[, Base := Km2[Year == 2010], by = .(Fips, Ssp)]; co[, Ratio := Km2 / Base]
st <- co[Year >= 2020, .(Counties = uniqueN(Fips), ZeroBase = uniqueN(Fips[Base == 0]), Under1Km2 = uniqueN(Fips[Base > 0 & Base < 1]), ZeroLater = mean(Km2[Base >= 1] == 0),
                         Q05 = quantile(Ratio[Base >= 1], 0.05), Q50 = median(Ratio[Base >= 1]), Q95 = quantile(Ratio[Base >= 1], 0.95), Max = max(Ratio[Base >= 1])), by = Ssp]
say("\nCounty ratios to 2010-2020, classes 12-16 (counties with at least 1 km2 in the base decade):")
print(st[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])
say("  share of the base decade's area in counties with at least 1 km2: %s", paste(co[Year == 2010, .(s = sum(Km2[Base >= 1]) / sum(Km2)), by = Ssp][, sprintf("%s %.3f", Ssp, s)], collapse = ", "))
ex <- c(Placer = "06061", `Santa Clara` = "06085", Riverside = "06065", Travis = "48453", Harris = "48201", Cook = "17031")
say("Example counties, ratio in 2040-2050 and 2080-2090, SSP2 then SSP5: %s", paste(vapply(names(ex), function(k) sprintf("%s %s", k, paste(sprintf("%.2f", co[Fips == ex[[k]] & Year %in% c(2040, 2080)][order(Ssp, Year), Ratio]), collapse = " / ")), ""), collapse = "; "))
