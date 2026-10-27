# =============================================================================
# 12-snag-fall.R - how fast snags fall, from FIA's remeasured dead trees: fire-killed snags by years since the fire vs other snags,
# against the model's stem snag fall and decay rates. California, Mediterranean Mountains, P26's main types
# =============================================================================
# A snag: a tree record with STATUSCD 2 (dead) and STANDING_DEAD_CD 1 (standing). Its next record (PREV_TRE_CN) at the following visit:
# still standing (STATUSCD 2, STANDING_DEAD_CD 1), fallen (STATUSCD 2, STANDING_DEAD_CD 0), or gone (STATUSCD 3 cut, or no longer
# tallied); trees cut or not remeasured are left out. Carbon-weighted (CARBON_AG x TPA_UNADJ at the first visit): the share fallen over
# the remeasurement period (PLOT.REMPER) gives an annual rate, k = -ln(1 - share) / REMPER. Fire-killed: AGENTCD 30 (fire) or a fire
# recorded at the plot location in the 10 years before the first visit; years since the fire = first visit - fire year.
# Model: the stem snag pool's annual transfer to down logs (CBM's snag fall, times the fitted snag multiplier) and its decay plus
# emission (out-cal-events: the mature-stand calibration with the fitted event table). Writes dev/fia/out-cal-events/snag-fall.csv.
# Usage: Rscript dev/fia/12-snag-fall.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(DBI) })
pkg <- "F:/lucasCore"; dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; ECODIV <- "M260"
TYPES <- c(`370` = "California Mixed Conifer", `260` = "Fir/Spruce/Mountain Hemlock", `220` = "Ponderosa Pine", `920` = "Western Oak")
tr <- fread(file.path(dm, "CA_TREE.csv"), select = c("CN", "PREV_TRE_CN", "PLT_CN", "CONDID", "STATUSCD", "STANDING_DEAD_CD", "AGENTCD", "DECAYCD", "DIA", "TPA_UNADJ", "CARBON_AG", "RECONCILECD"),
            colClasses = list(character = c("CN", "PREV_TRE_CN", "PLT_CN")))
pl <- fread(file.path(dm, "CA_PLOT.csv"), select = c("CN", "MEASYEAR", "REMPER", "STATECD", "UNITCD", "COUNTYCD", "PLOT"), colClasses = list(character = "CN"))[, loc := paste(STATECD, UNITCD, COUNTYCD, PLOT)]
cd <- fread(file.path(dm, "CA_COND.csv"), select = c("PLT_CN", "CONDID", "FORTYPCD", "STDAGE", paste0("DSTRBCD", 1:3), paste0("DSTRBYR", 1:3)), colClasses = list(character = "PLT_CN"))
ft <- fread(file.path(dm, "REFERENCE", "REF_FOREST_TYPE.csv"), select = c("VALUE", "TYPGRPCD"))
eco <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[statecd == 6, .(plt_cn, condid, ecodiv)]
h <- merge(cd, pl[, .(CN, loc)], by.x = "PLT_CN", by.y = "CN")
fires <- unique(rbindlist(lapply(1:3, function(i) h[get(paste0("DSTRBCD", i)) %in% 30:32 & get(paste0("DSTRBYR", i)) %between% c(1900, 2030), .(loc, year = get(paste0("DSTRBYR", i)))])))

s1 <- tr[STATUSCD == 2 & STANDING_DEAD_CD %in% 1 & !is.na(CARBON_AG) & !is.na(TPA_UNADJ)]
s1 <- merge(s1, pl[, .(CN, y1 = MEASYEAR, loc)], by.x = "PLT_CN", by.y = "CN")
s1 <- merge(s1, cd[, .(PLT_CN, CONDID, FORTYPCD)], by = c("PLT_CN", "CONDID"))
s1 <- merge(s1, eco, by.x = c("PLT_CN", "CONDID"), by.y = c("plt_cn", "condid"))[ecodiv == ECODIV][, grp := ft$TYPGRPCD[match(FORTYPCD, ft$VALUE)]][grp %in% as.integer(names(TYPES))]
s2 <- merge(tr[!is.na(PREV_TRE_CN), .(PREV_TRE_CN, PLT_CN2 = PLT_CN, status2 = STATUSCD, standing2 = STANDING_DEAD_CD, reconcile = RECONCILECD)], pl[, .(CN, y2 = MEASYEAR, remper = REMPER)],
            by.x = "PLT_CN2", by.y = "CN")
p <- merge(s1, s2, by.x = "CN", by.y = "PREV_TRE_CN")
p <- p[status2 %in% 2 | (status2 %in% 0 & reconcile %in% c(5, 6))]   # dead at both visits (or no longer tallied for a reason meaning it fell / is gone)
p[, fell := !(status2 %in% 2 & standing2 %in% 1)][, yrs := fifelse(!is.na(remper) & remper > 0, remper, y2 - y1)][, wC := CARBON_AG * TPA_UNADJ / 2000 * 2.2417]
p <- p[yrs > 0]
# fire-killed: fire agent, or a fire at the location in the 10 years before the first visit
lf <- merge(p[, .(CN, loc, y1)], fires, by = "loc", allow.cartesian = TRUE)[year <= y1 & y1 - year <= 10][, .(since_fire = min(y1 - year)), by = CN]
p <- merge(p, lf, by = "CN", all.x = TRUE)
p[, class := fifelse(!is.na(since_fire) | AGENTCD %in% 30:39, "fire-killed", "other snags")]
p[class == "fire-killed" & is.na(since_fire), since_fire := NA_real_]
rate <- function(d) { sh <- sum(d$wC[d$fell]) / sum(d$wC); yr <- weighted.mean(d$yrs, d$wC); list(trees = nrow(d), share_fallen = sh, years = yr, annual_rate = -log(1 - min(sh, 0.999)) / yr) }
res <- rbind(p[, rate(.SD), by = .(type = TYPES[as.character(grp)], class)],
             p[class == "fire-killed" & !is.na(since_fire), rate(.SD), by = .(type = TYPES[as.character(grp)], class = paste0("fire-killed, ", cut(since_fire, c(-1, 3, 10), labels = c("0-3 yr after", "4-10 yr after"))))],
             p[, rate(.SD), by = class][, type := "All four types"])
setorder(res, type, class)
cat(sprintf("Remeasured snags: %d trees (%d fire-killed)\n", nrow(p), p[class == "fire-killed", .N]))
options(width = 200); print(res[, .(type, class, trees, share_fallen = round(share_fallen, 2), years = round(years, 1), annual_fall_rate = round(annual_rate, 3), half_life_yr = round(log(2) / annual_rate, 1))])

# the model's stem snag pool: annual fall to down logs and decay + emission (CBM rates x the fitted snag multiplier), at M260's temperature
for (f in c("flows.R", "dom.R")) source(file.path(pkg, "src", f))
r <- readRDS(file.path(pkg, "dev/fia/out-cal-events/calibration.rds"))
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv")); dens <- fread(file.path(pkg, "defaults/growth/merch-carbon-density.csv"))
DECAY_GROUPS <- list(snag = c("SnagStem", "SnagBranch"), cwd = c("AGM", "BGF"), fwd = "AGF", litter = "AGVF", duff = "AGS", soil = c("BGVF", "BGS"))
mod <- rbindlist(lapply(seq_len(nrow(r$cells)), function(i) { k <- r$cells[i]; w <- cw[StateClassId == k$sc]; sw <- grepl("Softwood$", w$LagClass)
  rr <- turnover_rates(k$StateClass, sw, as.numeric(dens[StateClassId == k$sc, DeciduousShare]), file.path(pkg, "defaults/cbm"))
  v <- scale_decay(dom_flow_values(rr, sw, k$temp, file.path(pkg, "defaults/cbm")), as.list(r$M[[as.character(k$sc)]]$mult))
  fall <- v[["Transfer: Snag Stem -> AG Medium"]]; dec <- v[["Decay: Snag Stem -> AG Slow"]] + v[["Emission: Snag Stem -> Atmosphere"]]
  data.table(type = TYPES[as.character(k$sc)], model_fall_rate = fall, model_decay_rate = dec, model_total_loss = fall + dec, snag_multiplier = r$M[[as.character(k$sc)]]$mult[["snag"]]) }))
cat("\nThe model's stem snags (per year): fall to down logs, decay + emission, total loss; and half-life of standing:\n")
print(mod[, .(type, snag_multiplier = round(snag_multiplier, 2), fall = round(model_fall_rate, 3), decay = round(model_decay_rate, 3), total = round(model_total_loss, 3), fall_half_life_yr = round(log(2) / model_fall_rate, 1))])
fwrite(merge(res, mod, by = "type", all.x = TRUE), file.path(pkg, "dev/fia/out-cal-events/snag-fall.csv"))
