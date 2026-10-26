# =============================================================================
# 01-datamart-ca.R - to-do item 9: derive the USGS condition tables from FIA DataMart CSVs (California) and compare, condition by
# condition, with the .Rds tables stages 2-4 read today
# =============================================================================
# DataMart (apps.fs.usda.gov/fia/datamart/CSV): CA_PLOT, CA_COND, CA_TREE and FIADB_REFERENCE (REF_FOREST_TYPE, REF_SPECIES), in
# Data Sources/FIA/DataMart. Per forest condition:
#   PLOT   plot id fields, INVYR; ecodiv from the plot's (fuzzed) LAT/LON in the ecodivision map (PLOT has no ECOSUBCD)
#   COND   STDAGE, FORTYPCD -> forest type group (REF_FOREST_TYPE.TYPGRPCD), DSTRBCD1, TRTCD1, and the condition-level carbon pools
#          (CARBON_LITTER, _SOIL_ORG, _DOWN_DEAD, _UNDERSTORY_AG/_BG: short tons per acre of the condition)
#   TREE   live trees (STATUSCD 1): CARBON_AG, CARBON_BG, foliage = DRYBIO_FOLIAGE x REF_SPECIES.CARBON_RATIO_LIVE (total = all three),
#          net merchantable volume VOLCFNET; standing dead (STATUSCD 2, STANDING_DEAD_CD 1): CARBON_AG, CARBON_BG. Each tree x TPA_UNADJ
#          / the condition's share of the plot size it was measured on (MICR/SUBP/MACRPROP_UNADJ); lb -> short tons /2000
# Writes dev/fia/compare-ca.csv (per field: conditions compared, median ratio, share within 1% and 5%). Read-only.
# Usage: Rscript dev/fia/01-datamart-ca.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(sf) })
dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; fia <- "F:/lucas-master/Data Sources/FIA"; out <- "F:/lucasCore/dev/fia"
t0 <- Sys.time()
pl <- fread(file.path(dm, "CA_PLOT.csv"), select = c("CN", "INVYR", "STATECD", "UNITCD", "COUNTYCD", "PLOT", "LAT", "LON", "MACRO_BREAKPOINT_DIA"), colClasses = list(character = "CN"))
cd <- fread(file.path(dm, "CA_COND.csv"), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "STDAGE", "FORTYPCD", "CONDPROP_UNADJ", "MICRPROP_UNADJ", "SUBPPROP_UNADJ", "MACRPROP_UNADJ", "DSTRBCD1", "TRTCD1",
                                                     "CARBON_DOWN_DEAD", "CARBON_LITTER", "CARBON_SOIL_ORG", "CARBON_UNDERSTORY_AG", "CARBON_UNDERSTORY_BG"),
            colClasses = list(character = "PLT_CN"))
tr <- fread(file.path(dm, "CA_TREE.csv"), select = c("PLT_CN", "CONDID", "SPCD", "STATUSCD", "DIA", "STANDING_DEAD_CD", "TPA_UNADJ", "CARBON_AG", "CARBON_BG", "DRYBIO_FOLIAGE", "VOLCFNET"),
            colClasses = list(character = "PLT_CN"))
ft <- fread(file.path(dm, "REFERENCE", "REF_FOREST_TYPE.csv"), select = c("VALUE", "TYPGRPCD"))
sp <- fread(file.path(dm, "REFERENCE", "REF_SPECIES.csv"), select = c("SPCD", "CARBON_RATIO_LIVE"))
cat(sprintf("read: %d plots, %d conditions, %d trees (%.1f min)\n", nrow(pl), nrow(cd), nrow(tr), as.numeric(Sys.time() - t0, units = "mins")))

# ecodivision of each plot from its coordinates
eco <- read_sf(file.path(fia, "EcoDivision_map", "EcoDivisions_Dissolve.shp"))
pts <- st_as_sf(pl[!is.na(LAT) & !is.na(LON)], coords = c("LON", "LAT"), crs = 4269)
pl[!is.na(LAT) & !is.na(LON), ecodiv := as.character(st_join(st_transform(pts, st_crs(eco)), eco["ecodiv"])$ecodiv)]

# trees -> condition sums, each tree divided by the condition's share of the plot size it was measured on (microplot below 5 in,
# macroplot from the plot's breakpoint diameter, else subplot): per acre of the condition, as the USGS tables (dividing by CONDPROP_UNADJ
# instead missed 28% of California's conditions, all on multi-condition plots)
tr <- merge(tr, sp, by = "SPCD", all.x = TRUE)
tr <- merge(merge(tr, pl[, .(CN, MACRO_BREAKPOINT_DIA)], by.x = "PLT_CN", by.y = "CN"), cd[, .(PLT_CN, CONDID, MICRPROP_UNADJ, SUBPPROP_UNADJ, MACRPROP_UNADJ)], by = c("PLT_CN", "CONDID"))
tr[, w := TPA_UNADJ / fifelse(DIA < 5, MICRPROP_UNADJ, fifelse(!is.na(MACRO_BREAKPOINT_DIA) & DIA >= MACRO_BREAKPOINT_DIA, MACRPROP_UNADJ, SUBPPROP_UNADJ))]
tr <- tr[is.finite(w)]
live <- tr[STATUSCD == 1, .(c_ag_live = sum(w * CARBON_AG, na.rm = TRUE) / 2000, c_bg_live = sum(w * CARBON_BG, na.rm = TRUE) / 2000,
                            c_fol_live = sum(w * DRYBIO_FOLIAGE * CARBON_RATIO_LIVE, na.rm = TRUE) / 2000, vol = sum(w * VOLCFNET, na.rm = TRUE)), by = .(PLT_CN, CONDID)]
dead <- tr[STATUSCD == 2 & STANDING_DEAD_CD %in% 1, .(c_ag_dead = sum(w * CARBON_AG, na.rm = TRUE) / 2000, c_bg_dead = sum(w * CARBON_BG, na.rm = TRUE) / 2000), by = .(PLT_CN, CONDID)]

x <- merge(cd[COND_STATUS_CD == 1], pl, by.x = "PLT_CN", by.y = "CN")
x <- merge(merge(x, live, by = c("PLT_CN", "CONDID"), all.x = TRUE), dead, by = c("PLT_CN", "CONDID"), all.x = TRUE)
for (k in c("c_ag_live", "c_bg_live", "c_fol_live", "vol", "c_ag_dead", "c_bg_dead")) x[is.na(get(k)), (k) := 0]
x[, fortyp_grp := ft$TYPGRPCD[match(FORTYPCD, ft$VALUE)]]
pp <- function(v) v   # already per acre of the condition
dm_cond <- x[, .(plt_cn = PLT_CN, condid = CONDID, statecd = STATECD, unitcd = UNITCD, countycd = COUNTYCD, plot = PLOT, invyr = INVYR, ecodiv, stdage = STDAGE, fortyp_grp,
                 c_understory_ag_tons_per_acre = CARBON_UNDERSTORY_AG, c_understory_bg_tons_per_acre = CARBON_UNDERSTORY_BG,
                 c_understory_total_tons_per_acre = CARBON_UNDERSTORY_AG + CARBON_UNDERSTORY_BG, c_litter_tons_per_acre = CARBON_LITTER,
                 c_soil_org_tons_per_acre = CARBON_SOIL_ORG, c_down_dead_tons_per_acre = CARBON_DOWN_DEAD,
                 net_merchantable_bole_wood_vol_live_trees_cuft_per_acre = pp(vol),
                 c_ag_all_live_trees_short_tons_per_acre = pp(c_ag_live), c_foliage_all_live_trees_short_tons_per_acre = pp(c_fol_live),
                 c_bg_all_live_trees_short_tons_per_acre = pp(c_bg_live), c_total_all_live_trees_short_tons_per_acre = pp(c_ag_live + c_bg_live + c_fol_live),
                 c_ag_standing_dead_trees_short_tons_per_acre = pp(c_ag_dead), c_bg_standing_dead_trees_short_tons_per_acre = pp(c_bg_dead),
                 c_total_standing_dead_trees_short_tons_per_acre = pp(c_ag_dead + c_bg_dead))]
dm_dist <- x[, .(plt_cn = PLT_CN, condid = CONDID, dstrbcd1 = DSTRBCD1, trtcd1 = TRTCD1)]
saveRDS(dm_cond, file.path(out, "datamart-ca-cond.rds")); saveRDS(dm_dist, file.path(out, "datamart-ca-dist.rds"))

# ---- compare with the USGS tables ----------------------------------------------------------------------------------------
u <- as.data.table(readRDS(file.path(fia, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds")))[statecd == 6]
ud <- as.data.table(readRDS(file.path(fia, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds")))
u[, plt_cn := as.character(plt_cn)]; ud[, plt_cn := as.character(plt_cn)]
cat(sprintf("USGS California: %d conditions, invyr %d-%d; DataMart forest conditions: %d, invyr %d-%d\n", nrow(u), min(u$invyr), max(u$invyr[u$invyr < 9999]),
            nrow(dm_cond), min(dm_cond$invyr), max(dm_cond$invyr)))
m <- merge(u, dm_cond, by = c("plt_cn", "condid"), suffixes = c(".u", ".d"))
cat(sprintf("matched on plt_cn + condid: %d of %d USGS conditions (%.1f%%); USGS-only %d; DataMart-only %d (of which invyr after %d: %d)\n",
            nrow(m), nrow(u), 100 * nrow(m) / nrow(u), nrow(u) - nrow(m), nrow(dm_cond) - nrow(m), max(u$invyr[u$invyr < 9999]),
            dm_cond[!paste(plt_cn, condid) %in% paste(m$plt_cn, m$condid) & invyr > max(u$invyr[u$invyr < 9999]), .N]))
f <- setdiff(intersect(names(u), names(dm_cond)), c("plt_cn", "condid"))
res <- rbindlist(lapply(f, function(k) { a <- m[[paste0(k, ".u")]]; b <- m[[paste0(k, ".d")]]
  if (is.character(a) || k %in% c("statecd", "unitcd", "countycd", "plot", "invyr", "stdage", "fortyp_grp"))
    return(data.table(field = k, n = sum(!is.na(a)), same = round(100 * mean(a == b, na.rm = TRUE), 1), median_ratio = NA, within1 = NA, within5 = NA))
  ok <- !is.na(a) & !is.na(b); a <- a[ok]; b <- b[ok]; r <- ifelse(a == 0 & b == 0, 1, b / a)
  data.table(field = k, n = length(a), same = round(100 * mean(abs(a - b) < 1e-6), 1), median_ratio = round(median(r[is.finite(r)]), 4),
             within1 = round(100 * mean(abs(b - a) <= 0.01 * pmax(abs(a), 1e-9) | abs(b - a) < 1e-6), 1), within5 = round(100 * mean(abs(b - a) <= 0.05 * pmax(abs(a), 1e-9) | abs(b - a) < 1e-6), 1)) }))
md <- merge(ud, dm_dist, by = c("plt_cn", "condid"), suffixes = c(".u", ".d"))
res <- rbind(res, data.table(field = c("dstrbcd1", "trtcd1"), n = nrow(md), same = round(100 * c(mean(md$dstrbcd1.u == md$dstrbcd1.d, na.rm = TRUE), mean(md$trtcd1.u == md$trtcd1.d, na.rm = TRUE)), 1),
                             median_ratio = NA, within1 = NA, within5 = NA))
print(res); fwrite(res, file.path(out, "compare-ca.csv"))
cat(sprintf("%.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
