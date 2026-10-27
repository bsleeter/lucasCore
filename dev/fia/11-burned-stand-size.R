# =============================================================================
# 11-burned-stand-size.R - the stand the model burns vs the stands FIA saw burn: live aboveground wood and stand age before a
# high-severity fire, California, Mediterranean Mountains, P26's main types
# =============================================================================
# FIA: high-severity fires (07's definition) recorded at a plot with a visit before the fire (PREV_PLT_CN chain, any number of visits
# back, the last one before the fire year); that visit's live aboveground wood (CARBON_AG) and stand age; and, for every high-severity
# plot measured 0-5 years after, the snags after divided by 0.54 (the share 08 found) as an estimate of the wood that burned. Model: the
# spin-up stand at the return interval (live aboveground wood = merchantable + other wood from P26's carbon curves) and the stand at
# other ages. Also FIA's unburned live wood by stand age for scale. Read-only.
# Usage: Rscript dev/fia/11-burned-stand-size.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(DBI) })
pkg <- "F:/lucasCore"; dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; ECODIV <- "M260"; K <- 2.2417
TYPES <- c(`370` = "California Mixed Conifer", `260` = "Fir/Spruce/Mountain Hemlock", `220` = "Ponderosa Pine", `920` = "Western Oak")
cd <- fread(file.path(dm, "CA_COND.csv"), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "STDAGE", "FORTYPCD", paste0("DSTRBCD", 1:3), paste0("DSTRBYR", 1:3)), colClasses = list(character = "PLT_CN"))
pl <- fread(file.path(dm, "CA_PLOT.csv"), select = c("CN", "PREV_PLT_CN", "STATECD", "UNITCD", "COUNTYCD", "PLOT", "MEASYEAR"), colClasses = list(character = c("CN", "PREV_PLT_CN")))
pl[, loc := paste(STATECD, UNITCD, COUNTYCD, PLOT)]
ft <- fread(file.path(dm, "REFERENCE", "REF_FOREST_TYPE.csv"), select = c("VALUE", "TYPGRPCD"))
cache <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[statecd == 6, .(plt_cn, condid, ecodiv, W = c_ag_all_live_trees_short_tons_per_acre * K, standing = c_ag_standing_dead_trees_short_tons_per_acre * K)]
x <- merge(merge(cd[COND_STATUS_CD == 1], pl[, .(CN, loc, MEASYEAR)], by.x = "PLT_CN", by.y = "CN"), cache, by.x = c("PLT_CN", "CONDID"), by.y = c("plt_cn", "condid"))
x[, grp := ft$TYPGRPCD[match(FORTYPCD, ft$VALUE)]]; x <- x[ecodiv == ECODIV & grp %in% as.integer(names(TYPES))]
# fires recorded at each location (year, crown)
ev <- unique(rbindlist(lapply(1:3, function(i) x[get(paste0("DSTRBCD", i)) %in% 30:32 & get(paste0("DSTRBYR", i)) %between% c(1900, 2030), .(loc, year = get(paste0("DSTRBYR", i)), crown = get(paste0("DSTRBCD", i)) == 32)])))
# visits after a fire (0-5 yr) that are high severity (crown fire, or stand age reset)
af <- merge(x, ev, by = "loc", allow.cartesian = TRUE)[year <= MEASYEAR & MEASYEAR - year <= 5]
af <- af[crown | (!is.na(STDAGE) & STDAGE <= MEASYEAR - year + 5)][, .SD[which.max(year)], by = .(PLT_CN, CONDID)]
# the visit before: the latest visit of the same location and condition before the fire year
bf <- merge(af[, .(PLT_CN, CONDID, loc, year, grp)], x[, .(loc, CONDID, prev_year = MEASYEAR, W_b = W, age_b = STDAGE)], by = c("loc", "CONDID"), allow.cartesian = TRUE)[prev_year < year]
bf <- bf[, .SD[which.max(prev_year)], by = .(PLT_CN, CONDID)]
cat(sprintf("High-severity fire visits 0-5 yr after: %d; with a visit before the fire: %d\n", nrow(af), nrow(bf)))
fia <- merge(af[, .(n_after = .N, snags_after = mean(standing), W_implied = mean(standing) / 0.54), by = grp],
             bf[, .(n_before = .N, W_before = mean(W_b), W_before_median = median(W_b), age_before = mean(age_b, na.rm = TRUE), age_before_median = as.numeric(median(age_b, na.rm = TRUE))), by = grp], by = "grp", all = TRUE)
unb <- x[!loc %in% ev$loc & !is.na(STDAGE) & STDAGE >= 1, .(W_unburned_all_ages = mean(W), W_unburned_80_200 = mean(W[STDAGE >= 80 & STDAGE <= 200])), by = grp]
fia <- merge(fia, unb, by = "grp")
# the model's stand: live aboveground wood at the return interval and at other ages (P26 Build carbon curves)
con <- dbConnect(RSQLite::SQLite(), file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim"), flags = RSQLite::SQLITE_RO)
scl <- as.data.table(dbGetQuery(con, "SELECT StateClassId, Name, Id FROM stsim_StateClass")); stl <- as.data.table(dbGetQuery(con, "SELECT StratumId, Name FROM stsim_Stratum"))
cc <- as.data.table(dbGetQuery(con, "SELECT * FROM lucasCore_CarbonCurve WHERE ScenarioId = 2")); ri5 <- as.data.table(dbGetQuery(con, "SELECT * FROM lucasCore_OutputReturnInterval WHERE ScenarioId = 2")); dbDisconnect(con)
cc <- cc[StratumId == stl[Name == "Mediterranean Mountains", StratumId]][, grp := as.integer(scl$Id[match(StateClassId, scl$StateClassId)])][grp %in% fia$grp]
ri5 <- ri5[StratumId == stl[Name == "Mediterranean Mountains", StratumId]][, grp := as.integer(scl$Id[match(StateClassId, scl$StateClassId)])]
mod <- cc[, .(W_age50 = sum((Merchantable + Other)[Age == 50]), W_age100 = sum((Merchantable + Other)[Age == 100])), by = grp]
mod <- merge(mod, ri5[, .(grp, RI = as.integer(round(ReturnInterval)))], by = "grp")
mod[, W_at_RI := mapply(function(g, r) cc[grp == g & Age == r, Merchantable + Other], grp, RI)]
res <- merge(fia, mod, by = "grp")[, type := TYPES[as.character(grp)]]
options(width = 220)
cat("\nLive aboveground wood (Mg C/ha) and stand age before high-severity fire, FIA vs the model's spin-up stand:\n")
print(res[, .(type, n_before, W_before = round(W_before), W_before_median = round(W_before_median), age_before = round(age_before), age_median = age_before_median,
              n_after, W_implied_from_snags = round(W_implied), model_RI = RI, model_W_at_RI = round(W_at_RI), model_W_age50 = round(W_age50), model_W_age100 = round(W_age100),
              FIA_unburned_80_200 = round(W_unburned_80_200), FIA_unburned_all = round(W_unburned_all_ages))])
fwrite(res, file.path(pkg, "dev/fia/out-cal-events/burned-stand-size.csv"))
