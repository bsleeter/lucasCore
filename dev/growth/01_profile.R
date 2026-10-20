# Profile the FIA condition data the growth curves are fitted on
suppressPackageStartupMessages({ library(data.table) })
D <- "F:/lucas-master/Data Sources/FIA/"
x <- as.data.table(readRDS(paste0(D, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds")))
d <- as.data.table(readRDS(paste0(D, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds")))
cat("conditions:", nrow(x), " cols:", ncol(x), "\n"); print(names(x)); cat("\ndist file cols:", names(d), " rows:", nrow(d), "\n")
key <- intersect(names(x), names(d)); cat("join keys:", key, "\n")
x <- merge(x, d, by = key, all.x = TRUE)
str(x[, .SD, .SDcols = intersect(c("plot","condid","invyr","statecd","stdage","fortyp","fortyp_grp","ecodiv","condprop_unadj","dstrbcd1","dstrbcd2","trtcd1","stdorgcd","owngrpcd","siteclcd","net_merchantable_bole_wood_vol_live_trees_cuft_per_acre"), names(x))])
cat("\ninvyr range:", range(x$invyr), "\n"); print(table(cut(x$invyr, c(1960,1990,1997,2005,2010,2015,2025))))
cat("\ncondid:\n"); print(table(x$condid)); cat("dstrbcd1 == 0 share:", mean(x$dstrbcd1 == 0, na.rm = TRUE), "\n")
if ("trtcd1" %in% names(x)) { cat("trtcd1:\n"); print(table(x$trtcd1, useNA = "ifany")) }
cat("\nstdage summary:\n"); print(summary(x$stdage)); cat("stdage NA or 0:", sum(is.na(x$stdage)), sum(x$stdage == 0, na.rm = TRUE), "\n")
cat("stdage 999 / >500:", sum(x$stdage >= 500, na.rm = TRUE), "\n")
v <- x$net_merchantable_bole_wood_vol_live_trees_cuft_per_acre * 0.0699725
cat("merch vol m3/ha:\n"); print(quantile(v, c(0, .01, .25, .5, .75, .95, .99, .999, 1), na.rm = TRUE))
cat("plots with repeated visits:", x[, .N, by = plot][N > 1, .N], " of", uniqueN(x$plot), "\n")
f <- x[dstrbcd1 == 0 & invyr >= 1997 & !is.na(stdage)]
cat("\nafter dstrbcd1==0, invyr>=1997, stdage present:", nrow(f), " (condid==1:", f[condid == 1, .N], ")\n")
tab <- dcast(f[, .N, by = .(fortyp_grp, ecodiv)], fortyp_grp ~ ecodiv, value.var = "N", fill = 0)
fwrite(tab, "F:/lucasCore/dev/growth/out_counts_ftg_ecodiv.csv"); print(tab)
