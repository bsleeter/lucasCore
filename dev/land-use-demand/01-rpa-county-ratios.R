# =============================================================================
# 01-rpa-county-ratios.R - land-use demand from the 2020 RPA Assessment county projections, as ratios to their own calibration step (exploratory)
# =============================================================================
# User request 2026-11-14: alternatives to resampling historical years for how much land use changes in a projection; first the RPA
# county transitions as a relative multiplier (dev/avoided-conversion/ssp-projections.md, Option B):
#   target(unit, year) = the area stage 9 draws from the NLCD record x ratio(unit, decade of the year, RPA future)
#   ratio = the RPA gross transition per year in that decade / the RPA gross transition per year in 2012-2020 (its calibration step)
# Data: Mihiar, Lewis & Coulston 2023, doi:10.2737/RDS-2023-0026 (county_landuse_projections_RPA.rds): a list of 20 futures (5 climate
# models x 4 RCP-SSP pairs) > 6 steps (2012-2020, then five decades to 2070) > 3,075 counties (5-digit FIPS) > a 6 x 6 matrix, rows =
# the use at the start, columns = the use at the end (cr crop, ps pasture, rg range, fr forest, ur urban), t1 / t2 = the totals, in
# hundreds of acres. Private non-federal land only.
# LUCAS groups from RPA cells (from > to):
#   Urbanization             cr, ps, rg, fr > ur
#   Ag Expansion: Cropland   rg, fr > cr          Ag Expansion: Pasture   rg, fr > ps
#   Ag Contraction: Cropland cr > rg, fr          Ag Contraction: Pasture ps > rg, fr
#   Ag Change                cr > ps and ps > cr
# Writes, beside this script: 01-rpa-national.csv (area per year by future, step and group, with the ratio), 01-rpa-state-ratios.csv
# (the ratio pooled by state, the mean and range over the five climate models), 01-rpa-county-stability.csv (how many counties have a
# usable calibration rate), and cache/01-rpa-county.rds (every county, future, step and group; not in git).
# Usage: Rscript dev/land-use-demand/01-rpa-county-ratios.R     (LUCAS_DATA_HOME = the Data Sources folder)
# =============================================================================
pkg <- local({ d <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))); while (!file.exists(file.path(d, "package.xml")) && dirname(d) != d) d <- dirname(d); d })   # the package folder
DS <- Sys.getenv("LUCAS_DATA_HOME", "E:/lucasData")
suppressPackageStartupMessages(library(data.table))
OUT <- file.path(pkg, "dev/land-use-demand"); CA <- file.path(OUT, "cache"); dir.create(CA, showWarnings = FALSE)
say <- function(...) cat(sprintf(...), "\n")
f <- file.path(DS, "land-use/rpa-2020/county_landuse_projections_RPA.rds"); if (!file.exists(f)) stop("RPA county projections not found: ", f)
KM2 <- 100 * 0.0040468564   # hundreds of acres to km2
MAC <- 100 / 1e6            # hundreds of acres to million acres
USE <- c("cr", "ps", "rg", "fr", "ur")
GROUPS <- list(Urbanization = list(from = c("cr", "ps", "rg", "fr"), to = "ur"),
               `Ag Expansion: Cropland` = list(from = c("rg", "fr"), to = "cr"), `Ag Expansion: Pasture` = list(from = c("rg", "fr"), to = "ps"),
               `Ag Contraction: Cropland` = list(from = "cr", to = c("rg", "fr")), `Ag Contraction: Pasture` = list(from = "ps", to = c("rg", "fr")),
               `Ag Change: Cropland to Pasture` = list(from = "cr", to = "ps"), `Ag Change: Pasture to Cropland` = list(from = "ps", to = "cr"))

# ---- the long table: one row per future, step, county and group, in hundreds of acres over the step --------------------------------
x <- readRDS(f)
d <- rbindlist(lapply(names(x), function(s) rbindlist(lapply(names(x[[s]]), function(st) { a <- simplify2array(unclass(x[[s]][[st]]))   # 6 x 6 x counties
  g <- rbindlist(lapply(names(GROUPS), function(k) data.table(Fips = dimnames(a)[[3]], Group = k, Area = colSums(a[GROUPS[[k]]$from, GROUPS[[k]]$to, , drop = FALSE], dims = 2))))
  # urbanization by the use it takes, and the totals, for the checks below
  src <- rbindlist(lapply(USE[1:4], function(u) data.table(Fips = dimnames(a)[[3]], Group = paste("Urbanization from", u), Area = a[u, "ur", ])))
  tot <- rbindlist(lapply(USE, function(u) data.table(Fips = dimnames(a)[[3]], Group = paste("Total", u, "at start"), Area = a[u, "t1", ])))
  rbind(g, src, tot)[, `:=`(Future = s, Step = st)] }))))
d[, c("Gcm", "Pair") := tstrsplit(sub("_(rcp[0-9]+_ssp[0-9])$", "|\\1", Future), "|", fixed = TRUE)]
d[, Years := as.integer(sub(".*-", "", Step)) - as.integer(sub("-.*", "", Step))]
d[, State := substr(Fips, 1, 2)]
say("RPA: %d futures (%s) x %d steps x %d counties", uniqueN(d$Future), paste(sort(unique(d$Pair)), collapse = ", "), uniqueN(d$Step), uniqueN(d$Fips))
CAL <- "2012-2020"; flow <- d[!grepl("^Total", Group)]

# ---- checks against the RPA Land Resources chapter (Riitters et al. 2023, Table 4-9 and 4-10) ---------------------------------------
dev20 <- d[Group == "Total ur at start" & Step == "2020-2030", .(Mac = sum(Area) * MAC), by = Future]
gain <- flow[Group == "Urbanization" & Step != CAL, .(Mac = sum(Area) * MAC), by = Future]
ffr <- flow[Group == "Urbanization from fr" & Step != CAL, .(Mac = sum(Area) * MAC), by = Future]
say("Developed land in 2020: %.1f-%.1f million acres across futures (chapter: 97.7)", min(dev20$Mac), max(dev20$Mac))
say("Developed gain 2020-2070: %.1f-%.1f, mean %.1f million acres (chapter: 41.3-57.0, mean 50.7)", min(gain$Mac), max(gain$Mac), mean(gain$Mac))
say("  lowest %s, highest %s", gain[which.min(Mac), Future], gain[which.max(Mac), Future])
say("Forest to developed 2020-2070: %.1f-%.1f, mean %.1f million acres (chapter: 19.8-26, mean 23.2)", min(ffr$Mac), max(ffr$Mac), mean(ffr$Mac))
cal <- flow[Step == CAL & Group == "Urbanization", .(Mac = sum(Area) * MAC / 8), by = Future]
say("Calibration step, new developed land: %.2f-%.2f million acres a year across futures (the step is itself projected)", min(cal$Mac), max(cal$Mac))

# ---- national: area a year and the ratio to the calibration step ------------------------------------------------------------------
nat <- flow[Group %in% names(GROUPS), .(Km2PerYear = sum(Area) * KM2 / Years[1]), by = .(Pair, Gcm, Step, Group)]
nat[, Ratio := Km2PerYear / Km2PerYear[Step == CAL], by = .(Pair, Gcm, Group)]
fwrite(nat[order(Group, Pair, Gcm, Step)], file.path(OUT, "01-rpa-national.csv"))
say("\nNational ratio to 2012-2020, the mean of the five climate models (range over them):")
w <- nat[Step != CAL, .(v = sprintf("%.2f (%.2f-%.2f)", mean(Ratio), min(Ratio), max(Ratio))), by = .(Group, Pair, Step)]
print(dcast(w, Group + Pair ~ Step, value.var = "v"), nrows = 100)
say("\nNational area a year in 2012-2020, km2 (mean of the futures): %s", paste(nat[Step == CAL, .(a = mean(Km2PerYear)), by = Group][, sprintf("%s %.0f", Group, a)], collapse = "; "))

# ---- by state: the ratio of pooled areas (the metadata advises against using single counties) ------------------------------------------
st <- flow[Group %in% names(GROUPS), .(PerYear = sum(Area) * KM2 / Years[1]), by = .(State, Pair, Gcm, Step, Group)]
st[, Ratio := PerYear / PerYear[Step == CAL], by = .(State, Pair, Gcm, Group)]
sto <- st[Step != CAL, .(CalKm2PerYear = NA_real_, Ratio = mean(Ratio), RatioMin = min(Ratio), RatioMax = max(Ratio)), by = .(State, Group, Pair, Step)]
sto[st[Step == CAL, .(c = mean(PerYear)), by = .(State, Group, Pair)], CalKm2PerYear := i.c, on = .(State, Group, Pair)]
fwrite(sto[order(Group, State, Pair, Step)], file.path(OUT, "01-rpa-state-ratios.csv"))
say("\nState ratios, Urbanization (states x pairs x decades): quantiles 5%% %.2f, 25%% %.2f, 50%% %.2f, 75%% %.2f, 95%% %.2f; %d of %d not finite",
    quantile(sto[Group == "Urbanization", Ratio], 0.05, na.rm = TRUE), quantile(sto[Group == "Urbanization", Ratio], 0.25, na.rm = TRUE), quantile(sto[Group == "Urbanization", Ratio], 0.5, na.rm = TRUE),
    quantile(sto[Group == "Urbanization", Ratio], 0.75, na.rm = TRUE), quantile(sto[Group == "Urbanization", Ratio], 0.95, na.rm = TRUE), sto[Group == "Urbanization", sum(!is.finite(Ratio))], sto[Group == "Urbanization", .N])

# ---- by county: how usable is the county's own ratio? ---------------------------------------------------------------------------
co <- flow[Group %in% names(GROUPS), .(PerYear = sum(Area) * KM2 / Years[1]), by = .(Fips, State, Pair, Gcm, Step, Group)]
co[, Cal := PerYear[Step == CAL], by = .(Fips, Pair, Gcm, Group)]; co[, Ratio := PerYear / Cal]
saveRDS(co, file.path(CA, "01-rpa-county.rds"))
# a calibration rate under 0.04 km2 a year (10 acres) is too small to divide by
stab <- co[Step != CAL, .(Counties = uniqueN(Fips), ZeroCalibration = uniqueN(Fips[Cal == 0]), SmallCalibration = uniqueN(Fips[Cal > 0 & Cal < 0.04]),
                          Q05 = quantile(Ratio[Cal >= 0.04], 0.05), Q50 = quantile(Ratio[Cal >= 0.04], 0.5), Q95 = quantile(Ratio[Cal >= 0.04], 0.95), Max = max(Ratio[Cal >= 0.04]),
                          AreaShareUsable = sum(Cal[Cal >= 0.04]) / sum(Cal)), by = .(Group, Pair)]
fwrite(stab[order(Group, Pair)], file.path(OUT, "01-rpa-county-stability.csv"))
say("\nCounty ratios (decades 2020-2070 against 2012-2020), counties with at least 0.04 km2 a year in the calibration step:")
print(stab[, .(Group, Pair, Counties, ZeroCalibration, SmallCalibration, Q05 = round(Q05, 2), Q50 = round(Q50, 2), Q95 = round(Q95, 2), Max = round(Max, 1), AreaShareUsable = round(AreaShareUsable, 3))], nrows = 100)
# how much of the county spread is the climate model rather than the pair or the decade
sp <- co[Group == "Urbanization" & Step != CAL & Cal >= 0.04, .(Spread = max(Ratio) / min(Ratio)), by = .(Fips, Pair, Step)]
say("\nUrbanization, a county's highest / lowest ratio over the five climate models: median %.2f, 95%% %.2f", median(sp$Spread), quantile(sp$Spread, 0.95))
