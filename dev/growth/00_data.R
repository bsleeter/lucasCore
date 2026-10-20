# Prepare FIA condition data for growth-curve experiments: one row per plot-condition visit, with candidate filters as flags
suppressPackageStartupMessages({ library(data.table) })
D <- "F:/lucas-master/Data Sources/FIA/"
x <- as.data.table(readRDS(paste0(D, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds")))
d <- as.data.table(readRDS(paste0(D, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds")))
x <- merge(x, d, by = c("plt_cn", "condid"), all.x = TRUE)
cw <- fread("F:/lucasCore/defaults/growth/forest-type-crosswalk.csv")
x[, pid := sprintf("%02d-%d-%03d-%05d", statecd, unitcd, countycd, plot)]            # unique plot (plot numbers repeat across counties)
x[, vol := net_merchantable_bole_wood_vol_live_trees_cuft_per_acre * 0.0699725]       # ft3/ac -> m3/ha
x[, sc := cw$StateClassId[match(fortyp_grp, cw$FiaTypeGroups)]]                       # 201 shares 200's data; set below
x <- x[!is.na(sc) & !is.na(stdage) & !is.na(vol) & invyr >= 1997 & invyr <= 2025]
x[, `:=`(undisturbed = dstrbcd1 %in% 0, untreated = trtcd1 %in% 0, cond1 = condid == 1,
         age_ok = stdage >= 1 & stdage <= 400)]
# volume outliers: above the 99.9th percentile of the type group (robust to the 482,254 m3/ha record)
x[, vcap := quantile(vol, 0.999), by = fortyp_grp][, vol_ok := vol <= vcap]
# latest visit of each plot-condition (remeasurements are correlated; keep one for fitting, all for growth checks)
setorder(x, pid, condid, -invyr); x[, latest := !duplicated(paste(pid, condid))]
x[, ecodiv := as.character(ecodiv)]
keep <- c("pid", "condid", "invyr", "statecd", "ecodiv", "fortyp_grp", "sc", "stdage", "vol", "undisturbed", "untreated", "cond1", "age_ok", "vol_ok", "latest")
x <- x[, ..keep]
saveRDS(x, "F:/lucasCore/dev/growth/fia_prepared.rds")
cat("rows", nrow(x), " plots", uniqueN(x$pid), "\n")
base <- x[undisturbed & age_ok & vol_ok]
cat("undisturbed, age 1-400, vol cap:", nrow(base), "; + untreated:", base[untreated == TRUE, .N], "; + latest visit:", base[untreated & latest, .N], "; + condid 1 only:", base[untreated & latest & cond1, .N], "\n")
cat("unique pid with old key (plot only) vs new:", uniqueN(x$pid), "\n")
