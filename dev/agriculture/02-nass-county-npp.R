# =============================================================================
# 02-nass-county-npp.R - cropland and pasture growth (NPP) by county, ecodivision and year from NASS county yields (to-do 39 step 6)
# =============================================================================
# NASS Quick Stats county survey estimates (qs.crops bulk file; dev extract: SOURCE SURVEY, county level, domain TOTAL, annual, 1984
# on, PRODUCTION and AREA HARVESTED). Each crop in defaults/stockflow/ag-crop-coefficients.csv (USDA Tech. Bull. 1939, 2nd ed. 2024,
# Ch 3 Table 3-3: dry matter content, harvest index, root:shoot; revised from West et al. 2010) gives, per county and year,
#   aboveground biomass (Mg dry/ha) = production (lb x 0.4536e-3 Mg) x dry matter / harvest index / harvested ha
#   NPP (Mg C/ha/yr)               = aboveground x (1 + root:shoot) x 0.45   (Table 3-4 herbaceous carbon fraction)
# NLCD 82 cropland takes the field crops, NLCD 81 pasture/hay alfalfa and other hay. Cotton: NASS reports lint, about LINT_TURNOUT of
# seed cotton by weight (to check), and the harvest index is taken on seed cotton (lint alone gave 2.5 Mg dry/ha of aboveground
# biomass, too little for the crop).
# By ecodivision, per crop and year: the mean over its counties weighted by harvested ha x the share of the county's area in the
# ecodivision. The crop MIX is then held at its BASE-years mean area: the survey's mix shifts as series end (many stop in 2008 or 2018;
# California's county survey lost most of its cotton, wheat and barley), which moved a plain yearly mean by a factor of two. So
#   level  = sum_c w_c mean_y(npp_c,y) / sum_c w_c                  (w_c the crop's mean harvested ha over BASE)
#   index  = sum_c w_c npp_c,y / sum_c w_c mean(npp_c), over the crops the survey has that year
#   NPP_y  = level x index_y; the aboveground and harvested shares are the level's (fixed mix)
# Also written: the area NASS covers.
# Not covered: vegetables, fruit and nuts (few county survey rows), grazed pasture (no yield). Counties of the 2022 TIGER file:
# Connecticut's planning regions do not match NASS's old counties (dropped).
# Inputs: NASS (the extract, tab-separated text), COUNTIES (TIGER county shapefile). Writes dev/agriculture/02-nass-county-npp.csv
# (county x year x class) and 02-nass-ecodivision-npp.csv (ecodivision x year x class).
# Usage: NASS=<county-survey txt> COUNTIES=<shp> Rscript dev/agriculture/02-nass-county-npp.R
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages({ library(data.table); library(sf) }); options(width = 200)
NASS <- Sys.getenv("NASS"); COUNTIES <- Sys.getenv("COUNTIES"); OUT <- file.path(pkg, "dev", "agriculture")
if (!file.exists(NASS) || !file.exists(COUNTIES)) stop("set NASS and COUNTIES")
FC <- 0.45; LB <- 0.45359237e-3; HA_PER_ACRE <- 0.40468564; LINT_TURNOUT <- 0.38; BASE <- 1985:2023

cf <- fread(file.path(pkg, "defaults/stockflow/ag-crop-coefficients.csv"))
x <- fread(NASS, sep = "\t", quote = "", select = c("COMMODITY_DESC", "CLASS_DESC", "PRODN_PRACTICE_DESC", "UTIL_PRACTICE_DESC", "STATISTICCAT_DESC", "UNIT_DESC",
                                                     "STATE_FIPS_CODE", "COUNTY_CODE", "YEAR", "VALUE"), colClasses = list(character = c("STATE_FIPS_CODE", "COUNTY_CODE", "VALUE")))
x <- x[PRODN_PRACTICE_DESC == "ALL PRODUCTION PRACTICES" & COUNTY_CODE != "998"]
x[, v := suppressWarnings(as.numeric(gsub(",", "", VALUE)))]   # (D) withheld, (Z) less than half a unit: missing
x[, GEOID := paste0(sprintf("%02d", as.integer(STATE_FIPS_CODE)), sprintf("%03d", as.integer(COUNTY_CODE)))]
# each coefficient row: its commodity, class (* = every class), utilization and production unit
cf[, key := paste(Commodity, Class, Util, sep = "|")]
x[, key := paste(COMMODITY_DESC, CLASS_DESC, UTIL_PRACTICE_DESC, sep = "|")]; x[COMMODITY_DESC == "TOBACCO", key := paste("TOBACCO", "*", UTIL_PRACTICE_DESC, sep = "|")]
x <- x[key %in% cf$key]
w <- dcast(x, GEOID + YEAR + key + COMMODITY_DESC + CLASS_DESC ~ STATISTICCAT_DESC, value.var = "v", fun.aggregate = function(z) sum(z, na.rm = FALSE))
setnames(w, c("AREA HARVESTED", "PRODUCTION"), c("acres", "prod"))
# the production unit must be the coefficient table's
pu <- unique(x[STATISTICCAT_DESC == "PRODUCTION", .(key, UNIT_DESC)]); bad <- merge(pu, cf[, .(key, Unit)], by = "key")[UNIT_DESC != Unit]
if (nrow(bad)) { print(bad); stop("production units differ from ag-crop-coefficients.csv") }
w <- merge(w[is.finite(acres) & is.finite(prod) & acres > 0 & prod > 0], cf[, .(key, LbPerUnit, Crop, StateClassId, DryMatter, HarvestIndex, RootShoot)], by = "key")
w[, ha := acres * HA_PER_ACRE]
w[Crop == "Cotton", prod := prod / LINT_TURNOUT]   # lint -> seed cotton
w[, ag := prod * LbPerUnit * LB * DryMatter / HarvestIndex / ha]   # Mg dry aboveground per harvested ha
w[, `:=`(npp = ag * (1 + RootShoot) * FC, agC = ag * FC, harvC = ag * HarvestIndex * FC)]
# implausible county-years (a unit slip or a tiny area): outside the 0.5-99.5% range of their crop's aboveground biomass are left out
w[, c("lo", "hi") := as.list(quantile(ag, c(0.005, 0.995))), by = Crop]; drop <- w[ag < lo | ag > hi, .N]; w <- w[ag >= lo & ag <= hi]
cat(sprintf("%d county x year x crop rows (%d outliers dropped), %d counties, %d-%d\n", nrow(w), drop, uniqueN(w$GEOID), min(w$YEAR), max(w$YEAR)))
print(w[, .(rows = .N, ha_per_year = round(sum(ha) / uniqueN(YEAR)), npp = round(weighted.mean(npp, ha), 2), ag_share = round(sum(agC * ha) / sum(npp * ha), 3)), by = .(StateClassId, Crop)][order(StateClassId, -ha_per_year)])

cty <- w[, .(ha = sum(ha), npp = weighted.mean(npp, ha), agC = weighted.mean(agC, ha), harvC = weighted.mean(harvC, ha), crops = .N), by = .(GEOID, YEAR, StateClassId)]
fwrite(cty, file.path(OUT, "02-nass-county-npp.csv"))

# ---- counties to ecodivisions: share of each county's area in each ecodivision ---------------------------------------------------
eco <- st_read(file.path(pkg, "defaults/strata/ecodivisions/EcoDivisions_Dissolve.shp"), quiet = TRUE)
base <- unique(st_drop_geometry(eco)[!startsWith(eco$ecodiv, "M"), c("ecodiv", "StrtmNm")])
eco$name <- ifelse(startsWith(eco$ecodiv, "M"), paste(base$StrtmNm[match(sub("^M", "", eco$ecodiv), base$ecodiv)], "Mountains"), eco$StrtmNm)
eco <- st_make_valid(st_transform(aggregate(eco["geometry"], by = list(name = eco$name), FUN = function(x) x[1]), 5070))
co <- st_make_valid(st_transform(st_read(COUNTIES, quiet = TRUE)[, c("GEOID")], 5070)); co$area <- as.numeric(st_area(co))
sf_use_s2(FALSE); ix <- suppressWarnings(st_intersection(co, eco))
share <- data.table(GEOID = ix$GEOID, StratumId = ix$name, share = as.numeric(st_area(ix)) / ix$area)[share > 1e-4]
share[, share := share / sum(share), by = GEOID]   # coastal slivers outside every ecodivision
miss <- setdiff(unique(cty$GEOID), share$GEOID); if (length(miss)) cat(sprintf("%d NASS counties not in the county file (left out): %s\n", length(miss), paste(head(miss, 8), collapse = ", ")))
e <- merge(w[, .(GEOID, YEAR, StateClassId, Crop, ha, npp, agC, harvC)], share, by = "GEOID", allow.cartesian = TRUE)[, wt := ha * share]
ec <- e[, .(npp = weighted.mean(npp, wt), agC = weighted.mean(agC, wt), harvC = weighted.mean(harvC, wt), ha = sum(wt), counties = uniqueN(GEOID)), by = .(StratumId, YEAR, StateClassId, Crop)]
# the fixed mix: each crop's mean harvested ha over BASE (years without it count 0) and its mean values
mix <- ec[YEAR %in% BASE, .(w = sum(ha) / length(BASE), npp_m = mean(npp), agC_m = mean(agC), harvC_m = mean(harvC)), by = .(StratumId, StateClassId, Crop)]
ec <- merge(ec, mix, by = c("StratumId", "StateClassId", "Crop"))
lev <- mix[, .(level = sum(w * npp_m) / sum(w), agShare = sum(w * agC_m) / sum(w * npp_m), harvShare = sum(w * harvC_m) / sum(w * npp_m)), by = .(StratumId, StateClassId)]
ed <- ec[, .(index = sum(w * npp) / sum(w * npp_m), mixCovered = sum(w) , ha = sum(ha), counties = max(counties), crops = .N), by = .(StratumId, YEAR, StateClassId)]
ed <- merge(ed, lev, by = c("StratumId", "StateClassId"))[, `:=`(npp = level * index, mixCovered = mixCovered / mix[, sum(w), by = .(StratumId, StateClassId)][.SD, on = .(StratumId, StateClassId), V1])]
setorder(ed, StateClassId, StratumId, YEAR); fwrite(ed, file.path(OUT, "02-nass-ecodivision-npp.csv"))
print(ed[YEAR %between% c(1985, 2023), .(level = round(level[1], 2), agShare = round(agShare[1], 3), harvShare = round(harvShare[1], 3), npp_1985_94 = round(mean(npp[YEAR <= 1994]), 2),
                                          npp_2014_23 = round(mean(npp[YEAR >= 2014]), 2), cv = round(sd(npp) / mean(npp), 3), kha = round(mean(ha) / 1000), mixCovered_min = round(min(mixCovered), 2)), by = .(StateClassId, StratumId)], nrows = 60)
cat("wrote dev/agriculture/02-nass-county-npp.csv and 02-nass-ecodivision-npp.csv\n")
