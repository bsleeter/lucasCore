# Validate stage 2 carbon pools against FIA's measured pools by age band (in-sample; every cell with plots, plot-weighted)
suppressPackageStartupMessages(library(data.table))
source("F:/lucasCore/src/carbon.R")
D <- "F:/lucas-master/Data Sources/FIA/"
x <- carbon_data(paste0(D, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds"), paste0(D, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds"),
                 list(MinInventoryYear = 1997, VolumeCapQuantile = 0.999))
cc <- fread("F:/lucasCore/dev/libs/carbon-curves.csv"); cw <- fread("F:/lucasCore/defaults/growth/forest-type-crosswalk.csv", colClasses = "character")
codes <- fread("F:/lucas-master/Data Sources/FIA/EcoDivision_Strata.csv", colClasses = "character"); st <- fread("F:/lucasCore/defaults/stsim/stsim_Stratum.csv")
cc[, ecodiv := codes$ecodiv[match(as.character(st$Id[match(StratumId, st$Name)]), codes$StratumId)]][, sc := cw$StateClassId[match(sub("^Forest: ", "", StateClassId), cw$StateClassName)]]
# each plot to its forest state class (201 shares 200's plots: use 200 only)
g2sc <- cw[StateClassId != "201", .(fortyp_grp = as.integer(unlist(strsplit(FiaTypeGroups, ";")))), by = StateClassId]
g2sc <- g2sc[!duplicated(fortyp_grp)]   # a group listed twice (240's pooled set) stays with its own class
x <- merge(x, g2sc, by = "fortyp_grp"); setnames(x, "StateClassId", "sc")
m <- merge(x, cc[, .(sc, ecodiv, stdage = Age, TotalLive, Foliage, Roots = CoarseRoots + FineRoots, Wood = Merchantable + Other, Merchantable)], by = c("sc", "ecodiv", "stdage"))
m[, band := cut(stdage, c(0, 5, 10, 20, 30, 50, 100, 400), labels = c("1-5", "6-10", "11-20", "21-30", "31-50", "51-100", ">100"))]
r <- m[, .(plots = .N, live_obs = mean(c_live), live_mod = mean(TotalLive), fol_obs = mean(c_fol), fol_mod = mean(Foliage),
           root_obs = mean(c_bg), root_mod = mean(Roots), wood_obs = mean(c_ag), wood_mod = mean(Wood), merch_share = mean(Merchantable) / mean(Wood)), by = band][order(band)]
r[, `:=`(live_bias_pct = round(100 * (live_mod / live_obs - 1), 1), fol_bias_pct = round(100 * (fol_mod / fol_obs - 1), 1),
         root_bias_pct = round(100 * (root_mod / root_obs - 1), 1), wood_bias_pct = round(100 * (wood_mod / wood_obs - 1), 1))]
options(width = 200); print(r[, .(band, plots, live_obs = round(live_obs, 1), live_bias_pct, fol_obs = round(fol_obs, 2), fol_bias_pct, root_obs = round(root_obs, 1), root_bias_pct,
                                 wood_obs = round(wood_obs, 1), wood_bias_pct, merch_share_of_wood = round(merch_share, 2))])
fwrite(r, "F:/lucasCore/dev/growth/out_exp13_pools.csv")
