# =============================================================================
# 03-p26-coverage.R - to-do 35 phase 0 (c): how much of P26's forest TreeMap can give a site class, with all states' COND
# =============================================================================
# TreeMap 2016 over the P26 study area (the latest P26 Build result's primary strata as the mask), each pixel's plot (CN = PLT_CN) ->
# the forested condition matching TreeMap's FORTYPCD, else the largest (as dev/treemap/01), from every state's DataMart COND ->
# SITECLCD. Reports the share of TreeMap forest pixels that join a condition and have a site class, the site class mix, and the
# states the plots come from. Read only.
# Usage: Rscript dev/treemap/03-p26-coverage.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
ds <- "F:/lucas-master/Data Sources"; lib <- "F:/lucasCore/dev/libs/LUCAS P26 Northern Sierra Nevada.ssim"
con <- DBI::dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO)
ic <- DBI::dbGetQuery(con, "SELECT ScenarioId, StratumFileName FROM stsim_InitialConditionsSpatial WHERE StratumFileName IS NOT NULL ORDER BY ScenarioId DESC LIMIT 1"); DBI::dbDisconnect(con)
P <- rast(file.path(paste0(lib, ".data"), paste0("Scenario-", ic$ScenarioId), "stsim_InitialConditionsSpatial", ic$StratumFileName))
tm <- rast(file.path(ds, "TreeMap", "Data", "TreeMap2016.tif"))
tmc <- crop(tm, project(as.polygons(ext(P), crs = crs(P)), crs(tm))); levels(tmc) <- NULL
Pm <- project(P, tmc, method = "near"); tmc <- mask(tmc, Pm)
cat(sprintf("P26 strata (Build result %d) on TreeMap's 30 m grid\n", ic$ScenarioId))
px <- as.data.table(freq(tmc))[, .(Value = as.integer(value), npx = count)]
cat(sprintf("TreeMap forest pixels in P26: %.1f M (%.0f km2)\n", sum(px$npx) / 1e6, sum(px$npx) * 900 / 1e6))
rat <- as.data.table(foreign::read.dbf(file.path(ds, "TreeMap", "Data", "TreeMap2016.tif.vat.dbf"), as.is = TRUE))[, .(Value, CN = as.character(CN), FORTYPCD)]
px <- merge(px, rat, by = "Value", all.x = TRUE)
cf <- list.files(file.path(ds, "FIA", "DataMart"), "^[A-Z]{2}_COND[.]csv$", full.names = TRUE)
cd <- rbindlist(lapply(cf, function(f) fread(f, select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "CONDPROP_UNADJ", "FORTYPCD", "STDAGE", "SITECLCD"),
                                          colClasses = list(character = "PLT_CN"), showProgress = FALSE)[PLT_CN %in% px$CN][, st := substr(basename(f), 1, 2)]))
cd <- cd[COND_STATUS_CD == 1]
# the condition matching TreeMap's type, else the largest forested one
m <- merge(px[, .(CN, FORTYPCD)], cd, by.x = "CN", by.y = "PLT_CN", allow.cartesian = TRUE, suffixes = c("_tm", ""))
m[, pick := FORTYPCD == FORTYPCD_tm]
m <- m[order(CN, -pick, -CONDPROP_UNADJ)][!duplicated(CN)]
px <- merge(px, m[, .(CN, SITECLCD, STDAGE, st, pick)], by = "CN", all.x = TRUE)
tot <- sum(px$npx)
cat(sprintf("Pixels whose plot joins a forested condition: %.1f%% (type matches TreeMap's: %.1f%%)\n", 100 * px[!is.na(st), sum(npx)] / tot, 100 * px[pick %in% TRUE, sum(npx)] / tot))
cat(sprintf("Pixels with a site class: %.1f%%; with a stand age: %.1f%%\n", 100 * px[!is.na(SITECLCD), sum(npx)] / tot, 100 * px[!is.na(STDAGE), sum(npx)] / tot))
cat("Site class mix (share of pixels with one):\n"); print(px[!is.na(SITECLCD), .(share = round(sum(npx) / tot, 3)), by = SITECLCD][order(SITECLCD)])
cat("States the plots come from (share of joined pixels):\n"); print(px[!is.na(st), .(share = round(sum(npx) / tot, 3)), by = st][order(-share)][1:10])
cat(sprintf("Distinct plots used: %d\n", px[!is.na(st), uniqueN(CN)]))
cat(sprintf("Pixels from CA/NV/OR plots: %.1f%%; TreeMap type of the pixels from other states (top 5):\n", 100 * px[st %in% c('CA','NV','OR'), sum(npx)] / tot)); print(px[!st %in% c('CA','NV','OR'), .(share = round(sum(npx) / tot, 4)), by = FORTYPCD][order(-share)][1:5])
