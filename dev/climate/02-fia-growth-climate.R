# =============================================================================
# 02-fia-growth-climate.R - does FIA live-carbon growth between remeasurements follow the climate of the interval?
# =============================================================================
# Pairs consecutive visits of the same plot (single condition at both visits, same forest type group, no disturbance or treatment
# recorded at the second visit, stand age advancing within 5 years of the interval, interval 3-15 years). Observed growth = change in
# total live-tree carbon per year; expected = the stage 2 carbon curve (dev/libs/carbon-curves.csv) over the same ages. Model:
#   obs - exp = beta * exp * (X - 1)       X = the interval's mean climate index (county, years v1+1 .. v2)
# beta = 1: the index's sensitivity is right; 0: growth does not follow it; between: an empirical damping of that index.
# Also fit with ecodivision x forest-type intercepts (absorbs curve bias) and by region.
# =============================================================================
suppressPackageStartupMessages(library(data.table))
OUT <- "F:/lucasCore/dev/climate"; ST2HA <- 2.2417   # short tons/acre -> Mg/ha
x <- as.data.table(readRDS("F:/lucas-master/Data Sources/FIA/USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds"))
d <- as.data.table(readRDS("F:/lucas-master/Data Sources/FIA/USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds"))
x <- merge(x, d[, .(plt_cn, condid, dstrbcd1, trtcd1)], by = c("plt_cn", "condid"), all.x = TRUE)
x[, `:=`(p = paste(statecd, unitcd, countycd, plot, sep = "-"), GEOID = statecd * 1000 + countycd, C = c_total_all_live_trees_short_tons_per_acre * ST2HA)]
x[, nc := .N, by = .(p, invyr)]
v <- x[nc == 1 & !is.na(stdage) & !is.na(C)][order(p, invyr)]
v[, `:=`(invyr0 = shift(invyr), C0 = shift(C), age0 = shift(stdage), ftg0 = shift(fortyp_grp)), by = p]
pr <- v[!is.na(invyr0)][, dt := invyr - invyr0]
n0 <- nrow(pr)
pr <- pr[dt %between% c(3, 15) & fortyp_grp == ftg0 & dstrbcd1 %in% c(0, NA) & trtcd1 %in% c(0, NA) & age0 > 0 & abs((stdage - age0) - dt) <= 5]
cat(sprintf("pairs: %d consecutive visits, %d kept (single condition, same type, undisturbed, untreated, age consistent)\n", n0, nrow(pr)))

# expected growth from the stage 2 carbon curve (ecodivision name x state class name)
cc <- fread("F:/lucasCore/dev/libs/carbon-curves.csv")[, .(StratumId, StateClassId, Age, TotalLive)]
eco <- fread("F:/lucas-master/Data Sources/FIA/EcoDivision_Strata.csv", colClasses = "character")
cw <- fread("F:/lucasCore/defaults/growth/forest-type-crosswalk.csv", colClasses = "character")
cwl <- cw[, .(g = as.integer(strsplit(FiaTypeGroups, "|", fixed = TRUE)[[1]])), by = .(StateClassId, StateClassName)]
cwl[, own := as.integer(StateClassId) == g]; setorder(cwl, g, -own); cwl <- cwl[!duplicated(g)]
pr[, eco_name := eco$StratumName[match(ecodiv, eco$ecodiv)]]
pr[, sc_name := paste0("Forest: ", cwl$StateClassName[match(fortyp_grp, cwl$g)])]
amax <- max(cc$Age); curve <- function(e, s, a) cc$TotalLive[match(paste(e, s, pmin(a, amax)), paste(cc$StratumId, cc$StateClassId, cc$Age))]
pr[, exp_rate := (curve(eco_name, sc_name, age0 + dt) - curve(eco_name, sc_name, age0)) / dt]
pr[, obs_rate := (C - C0) / dt]
pr <- pr[!is.na(exp_rate)]
cat(sprintf("with a curve: %d; mean observed %.2f, expected %.2f Mg C/ha/yr\n", nrow(pr), mean(pr$obs_rate), mean(pr$exp_rate)))

# interval climate: mean over growing years invyr0+1 .. invyr
cl <- fread(file.path(OUT, "county-climate.csv"))
pr[, id := .I]
iv <- pr[, .(Year = (invyr0 + 1):invyr), by = .(id, GEOID)]
iv <- merge(iv, cl, by = c("GEOID", "Year"))
ic <- iv[, .(miami = mean(miami), pratio = mean(pratio), tanom = mean(tanom), ny = .N), by = id]
pr <- merge(pr, ic, by = "id")[ny == dt & invyr <= 2023]
pr[, region := fifelse(substr(ecodiv, 1, 1) == "M", "mountain", "lowland")][, west := as.integer(substr(gsub("M", "", ecodiv), 1, 1)) >= 3]
cat(sprintf("with climate for every interval year: %d pairs\n\n", nrow(pr)))

# trim gross outliers (measurement / unrecorded disturbance): residual beyond 1st-99th percentile
pr[, resid := obs_rate - exp_rate]; q <- quantile(pr$resid, c(0.01, 0.99)); pr <- pr[resid %between% q]
fit <- function(dd, idx, label) {
  if (idx == "tanom") { dd[, z := exp_rate * get(idx)] } else dd[, z := exp_rate * (get(idx) - 1)]
  m1 <- lm(resid ~ 0 + z, dd); m2 <- lm(resid ~ z + factor(paste(eco_name, sc_name)), dd)
  data.table(subset = label, index = idx, n = nrow(dd), sd_X = round(sd(dd[[idx]]), 3),
             beta = round(coef(m1)[["z"]], 2), se = round(summary(m1)$coef["z", 2], 2),
             beta_fe = round(coef(m2)[["z"]], 2), se_fe = round(summary(m2)$coef["z", 2], 2)) }
out <- rbindlist(c(lapply(c("miami", "pratio", "tanom"), function(i) fit(copy(pr), i, "CONUS")),
                   lapply(c("miami", "pratio"), function(i) fit(copy(pr[west == TRUE]), i, "West")),
                   lapply(c("miami", "pratio"), function(i) fit(copy(pr[west == FALSE]), i, "East")),
                   lapply(c("miami", "pratio"), function(i) fit(copy(pr[statecd == 6]), i, "California"))))
print(out)
fwrite(out, file.path(OUT, "fia-growth-climate-fit.csv")); fwrite(pr[, .(p, statecd, ecodiv, sc_name, invyr0, invyr, dt, age0, obs_rate, exp_rate, miami, pratio, tanom)], file.path(OUT, "fia-pairs.csv"))
cat("\n(tanom beta is per degree C: fractional growth change per +1 C interval mean)\n")
