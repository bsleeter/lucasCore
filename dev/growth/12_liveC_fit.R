# Quick test: fit FIA live-tree carbon (incl. saplings) directly by age, Weibull without lag, for the experiment 11 cells
suppressPackageStartupMessages(library(data.table))
source("F:/lucasCore/src/growth.R")
o11 <- fread("F:/lucasCore/dev/growth/out_exp11_young_carbon.csv", colClasses = c(ecodiv = "character"))
D <- "F:/lucas-master/Data Sources/FIA/"
x <- as.data.table(readRDS(paste0(D, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds")))
x <- merge(x, as.data.table(readRDS(paste0(D, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds"))), by = c("plt_cn", "condid"))
x <- x[dstrbcd1 %in% 0 & trtcd1 %in% 0 & !is.na(stdage) & stdage >= 1 & stdage <= 400 & invyr >= 1997]
x[, pid := sprintf("%02d-%d-%03d-%05d", statecd, unitcd, countycd, plot)]; setorder(x, pid, condid, -invyr); x <- x[!duplicated(paste(pid, condid))]
x[, `:=`(c_live = c_total_all_live_trees_short_tons_per_acre * 2.2417, ecodiv = as.character(ecodiv))]
cw <- fread("F:/lucasCore/defaults/growth/forest-type-crosswalk.csv", colClasses = "character")
res <- rbindlist(lapply(unique(o11[, paste(type, ecodiv)]), function(k) { r <- o11[paste(type, ecodiv) == k]
  g <- as.integer(strsplit(cw[StateClassName == r$type[1], FiaTypeGroups], ";")[[1]]); d <- x[fortyp_grp %in% g & ecodiv == r$ecodiv[1]]
  d <- d[c_live <= quantile(c_live, .999)]
  p <- fit_single(d$stdage, d$c_live, 0)
  r[, .(type, ecodiv, age, plots, fia_liveC, lb_liveC, direct_liveC = round(wb_curve(age, p[["A"]], p[["k"]], p[["c"]], 0), 1))] }))
options(width = 200); print(res[age <= 30])
print(res[plots >= 20, .(lucasbuilder_ratio = round(median(lb_liveC / fia_liveC), 2), lb_range = sprintf("%.2f-%.2f", min(lb_liveC / fia_liveC), max(lb_liveC / fia_liveC)),
                         direct_ratio = round(median(direct_liveC / fia_liveC), 2), direct_range = sprintf("%.2f-%.2f", min(direct_liveC / fia_liveC), max(direct_liveC / fia_liveC))), by = age])
