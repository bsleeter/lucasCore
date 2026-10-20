# FIA dead-carbon pools by age band (Mg C/ha): what the decay calibration fits to
suppressPackageStartupMessages(library(data.table))
D <- "F:/lucas-master/Data Sources/FIA/"
x <- as.data.table(readRDS(paste0(D, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds")))
x <- merge(x, as.data.table(readRDS(paste0(D, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds"))), by = c("plt_cn", "condid"))
x <- x[dstrbcd1 %in% 0 & trtcd1 %in% 0 & !is.na(stdage) & stdage >= 1 & stdage <= 400 & invyr >= 1997]
x[, pid := sprintf("%02d-%d-%03d-%05d", statecd, unitcd, countycd, plot)]; setorder(x, pid, condid, -invyr); x <- x[!duplicated(paste(pid, condid))]
f <- 2.2417
x[, `:=`(snag_ag = c_ag_standing_dead_trees_short_tons_per_acre * f, snag_bg = c_bg_standing_dead_trees_short_tons_per_acre * f, down = c_down_dead_tons_per_acre * f,
         litter = c_litter_tons_per_acre * f, soil = c_soil_org_tons_per_acre * f, under = c_understory_total_tons_per_acre * f, live = c_total_all_live_trees_short_tons_per_acre * f)]
x[, band := cut(stdage, c(0, 10, 20, 40, 60, 80, 100, 150, 400))]
print(x[, .(plots = .N, live = round(mean(live), 1), snag_ag = round(mean(snag_ag), 2), snag_bg = round(mean(snag_bg), 2), down = round(mean(down), 1),
            litter = round(mean(litter), 1), soil = round(mean(soil), 1), understory = round(mean(under), 2)), by = band][order(band)])
cat("\nshare of plots with zero values: snag", round(mean(x$snag_ag == 0), 3), " down", round(mean(x$down == 0), 3), " litter", round(mean(x$litter == 0), 3), " soil", round(mean(x$soil == 0), 3), "\n")
cat("\nby forest type group (all ages):\n"); print(x[, .(plots = .N, snag = round(mean(snag_ag), 1), down = round(mean(down), 1), litter = round(mean(litter), 1), soil = round(mean(soil), 1)), by = fortyp_grp][order(-plots)][1:12])
