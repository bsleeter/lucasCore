# =============================================================================
# 03-down-dead-by-state.R - to-do item 9: current FIADB (DataMart, 9.5) CARBON_DOWN_DEAD, CARBON_LITTER and CARBON_SOIL_ORG against the USGS
# table (Feb 2024), state by state: the down dead ratio is one constant per state; litter and soil were revised in some states. Read-only.
# Usage: Rscript dev/fia/03-down-dead-by-state.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; sts <- c("ME", "GA", "MN", "CO", "AZ", "MT", "NY", "CA")
u <- as.data.table(readRDS("F:/lucas-master/Data Sources/FIA/USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds"))[, plt_cn := as.character(plt_cn)]
r <- rbindlist(lapply(sts, function(s) { f <- file.path(dm, paste0(s, "_COND.csv")); if (!file.exists(f)) return(NULL)
  d <- fread(f, select = c("PLT_CN", "CONDID", "CARBON_DOWN_DEAD", "CARBON_LITTER", "CARBON_SOIL_ORG", "FORTYPCD"), colClasses = list(character = "PLT_CN"))
  m <- merge(u[, .(plt_cn, condid, dd = c_down_dead_tons_per_acre, lt = c_litter_tons_per_acre, so = c_soil_org_tons_per_acre, fortyp_grp)], d, by.x = c("plt_cn", "condid"), by.y = c("PLT_CN", "CONDID"))[dd > 0]
  m[, ratio := CARBON_DOWN_DEAD / dd]
  data.table(state = s, n = nrow(m), down_ratio_median = round(median(m$ratio), 4), down_ratio_p05 = round(quantile(m$ratio, .05), 4), down_ratio_p95 = round(quantile(m$ratio, .95), 4),
             types_with_other_ratio = m[abs(ratio - 1/0.7) > 0.01, uniqueN(fortyp_grp)], litter_same = round(100 * mean(abs(m$CARBON_LITTER - m$lt) < 1e-4), 1), soil_same = round(100 * mean(abs(m$CARBON_SOIL_ORG - m$so) < 1e-4), 1)) }))
print(r)
