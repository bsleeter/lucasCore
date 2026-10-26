# =============================================================================
# 02-compare-conus.R - to-do item 9: the package's FIA DataMart tables (src/fia.R, all states in Data Sources/FIA/DataMart) against the
# USGS CONUS tables, condition by condition, and the fitting data stages 2 and 3 draw from each
# =============================================================================
# Writes dev/fia/compare-conus.csv (per field: conditions compared, share identical, median ratio, share within 1% and 5%) and
# dev/fia/compare-conus-states.csv (per state: USGS conditions, found in DataMart, live carbon within 1%). Read-only; builds or reads
# the DataMart cache (fia-conditions.rds in the DataMart folder).
# Usage: Rscript dev/fia/02-compare-conus.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
fia <- "F:/lucas-master/Data Sources/FIA"; dm <- file.path(fia, "DataMart"); out <- "F:/lucasCore/dev/fia"
say <- function(...) cat(sprintf(...), "\n"); fail <- function(...) stop(sprintf(...)); read_data_sources <- function(k) setNames(list(dm), k)
source("F:/lucasCore/src/fia.R"); source("F:/lucasCore/src/growth.R"); source("F:/lucasCore/src/carbon.R")
eco <- file.path(fia, "EcoDivision_map", "EcoDivisions_Dissolve.shp")
t0 <- Sys.time(); D <- fia_tables(list(FiaSource = 2L, DownDeadCarbon = 1L), eco)
U <- list(cond = as.data.table(readRDS(file.path(fia, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds"))),
          dist = as.data.table(readRDS(file.path(fia, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds"))))
U$cond[, plt_cn := as.character(plt_cn)]; U$dist[, plt_cn := as.character(plt_cn)]
m <- merge(U$cond, D$cond, by = c("plt_cn", "condid"), suffixes = c(".u", ".d"))
say("USGS %d conditions; DataMart %d (%d states); matched %d (%.2f%%)", nrow(U$cond), nrow(D$cond), length(D$states), nrow(m), 100 * nrow(m) / nrow(U$cond))
ids <- c("statecd", "unitcd", "countycd", "plot", "invyr", "ecodiv", "stdage", "fortyp_grp")
res <- rbindlist(lapply(setdiff(intersect(names(U$cond), names(D$cond)), c("plt_cn", "condid")), function(k) { a <- m[[paste0(k, ".u")]]; b <- m[[paste0(k, ".d")]]
  if (k %in% ids) return(data.table(field = k, n = sum(!is.na(a)), same = round(100 * mean(a == b, na.rm = TRUE), 2), median_ratio = NA_real_, within1 = NA_real_, within5 = NA_real_))
  ok <- !is.na(a) & !is.na(b); a <- a[ok]; b <- b[ok]; r <- ifelse(a == 0 & b == 0, 1, b / a); near <- function(p) round(100 * mean(abs(b - a) <= p * pmax(abs(a), 1e-9) | abs(b - a) < 1e-6), 2)
  data.table(field = k, n = length(a), same = round(100 * mean(abs(a - b) < 1e-6), 2), median_ratio = round(median(r[is.finite(r)]), 4), within1 = near(0.01), within5 = near(0.05)) }))
md <- merge(U$dist, D$dist, by = c("plt_cn", "condid"), suffixes = c(".u", ".d"))
res <- rbind(res, data.table(field = c("dstrbcd1", "trtcd1"), n = nrow(md), same = round(100 * c(mean(md$dstrbcd1.u == md$dstrbcd1.d, na.rm = TRUE), mean(md$trtcd1.u == md$trtcd1.d, na.rm = TRUE)), 2),
                             median_ratio = NA_real_, within1 = NA_real_, within5 = NA_real_))
print(res); fwrite(res, file.path(out, "compare-conus.csv"))
st <- U$cond[, .(usgs = .N), by = statecd][m[, .(found = .N, live_within1 = round(100 * mean(abs(c_total_all_live_trees_short_tons_per_acre.d - c_total_all_live_trees_short_tons_per_acre.u) <=
  0.01 * pmax(c_total_all_live_trees_short_tons_per_acre.u, 1e-9) | abs(c_total_all_live_trees_short_tons_per_acre.d - c_total_all_live_trees_short_tons_per_acre.u) < 1e-6), 1)), by = .(statecd = statecd.u)], on = "statecd"][order(statecd)]
print(st[is.na(found) | found < usgs | live_within1 < 99]); fwrite(st, file.path(out, "compare-conus-states.csv"))
# the fitting data stages 2 and 3 draw (Growth Curve Options defaults)
opt <- list(MinInventoryYear = 1997, VolumeCapQuantile = 0.999)
gu <- growth_data(U$cond, U$dist, opt); gd <- growth_data(D$cond, D$dist, opt); cu <- carbon_data(U$cond, U$dist, opt); cdd <- carbon_data(D$cond, D$dist, opt)
say("stage 2 growth data: USGS %d plot-conditions, DataMart %d; in both %d", nrow(gu), nrow(gd), nrow(merge(gu, gd, by = c("pid", "fortyp_grp", "stdage"))))
say("stage 2 carbon data: USGS %d, DataMart %d", nrow(cu), nrow(cdd))
say("%.1f min", as.numeric(Sys.time() - t0, units = "mins"))
