# =============================================================================
# 08-event-shares.R - what high-severity fire and clearcut leave behind, as shares of the stand before the event, from FIA remeasurement
# =============================================================================
# California, Mediterranean Mountains, P26's main types. Pairs: a down woody material visit 0-5 years after a stand-replacing event
# (07's definitions: crown fire or fire with stand age reset; cutting with stand age reset) and the same condition at the plot's previous
# visit, before the event (PLOT.PREV_PLT_CN). Stand-replacing in the data: live aboveground carbon after <= 20% of before. Shares of the
# live aboveground wood before (W = CARBON_AG: stem, bark, branches, no foliage):
#   fire      snags after / W (model: the event's live -> snag flows), down logs and fine woody debris gained / W, live left / W,
#             forest floor after / before (consumption)
#   clearcut  snags after / W, slash (fine woody debris + down logs gained) / W, live left / W, forest floor after / before
# and the same shares in the model's events (defaults/stockflow/event-pathways.csv applied to a stand of the same mix of pools). Writes
# dev/fia/out-cal/event-shares.csv. Read-only.
# Usage: Rscript dev/fia/08-event-shares.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- "F:/lucasCore"; dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; out <- file.path(pkg, "dev/fia/out-cal"); ECODIV <- "M260"
TYPES <- c(`370` = "California Mixed Conifer", `260` = "Fir/Spruce/Mountain Hemlock", `220` = "Ponderosa Pine", `920` = "Western Oak")
LB <- 0.000453592 * 2.471; K <- 2.2417
w <- unique(fread(file.path(dm, "CA_COND_DWM_CALC.csv"), select = c("PLT_CN", "CONDID", "MEASYEAR", "CWD_CARBON_COND", "PILE_CARBON_COND", "FWD_SM_CARBON_COND",
            "FWD_MD_CARBON_COND", "FWD_LG_CARBON_COND", "DUFF_CARBON", "LITTER_CARBON"), colClasses = list(character = "PLT_CN")), by = c("PLT_CN", "CONDID"))
for (k in grep("CARBON", names(w), value = TRUE)) w[, (k) := as.numeric(get(k)) * LB]
w[, `:=`(cwd = CWD_CARBON_COND + fifelse(is.na(PILE_CARBON_COND), 0, PILE_CARBON_COND), fwd = FWD_SM_CARBON_COND + FWD_MD_CARBON_COND + FWD_LG_CARBON_COND, floor = LITTER_CARBON + DUFF_CARBON)]
w <- w[, .(PLT_CN, CONDID, MEASYEAR, cwd, fwd, floor)]
cd <- fread(file.path(dm, "CA_COND.csv"), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "STDAGE", "FORTYPCD", paste0("DSTRBCD", 1:3), paste0("DSTRBYR", 1:3), paste0("TRTCD", 1:3), paste0("TRTYR", 1:3)),
            colClasses = list(character = "PLT_CN"))
pl <- fread(file.path(dm, "CA_PLOT.csv"), select = c("CN", "PREV_PLT_CN", "STATECD", "UNITCD", "COUNTYCD", "PLOT", "MEASYEAR"), colClasses = list(character = c("CN", "PREV_PLT_CN")))
pl[, loc := paste(STATECD, UNITCD, COUNTYCD, PLOT)]
ft <- fread(file.path(dm, "REFERENCE", "REF_FOREST_TYPE.csv"), select = c("VALUE", "TYPGRPCD"))
cache <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[statecd == 6, .(plt_cn, condid, ecodiv, W = c_ag_all_live_trees_short_tons_per_acre * K, fol = c_foliage_all_live_trees_short_tons_per_acre * K,
          root = c_bg_all_live_trees_short_tons_per_acre * K, standing = c_ag_standing_dead_trees_short_tons_per_acre * K)]
h <- merge(cd, pl[, .(CN, loc)], by.x = "PLT_CN", by.y = "CN")
ev <- unique(rbindlist(lapply(1:3, function(i) rbind(
  h[get(paste0("DSTRBCD", i)) %in% 30:32 & get(paste0("DSTRBYR", i)) %between% c(1900, 2030), .(loc, year = get(paste0("DSTRBYR", i)), kind = "fire", crown = get(paste0("DSTRBCD", i)) == 32)],
  h[get(paste0("TRTCD", i)) %in% 10 & get(paste0("TRTYR", i)) %between% c(1900, 2030), .(loc, year = get(paste0("TRTYR", i)), kind = "harvest", crown = FALSE)]))))

# after: DWM visits of P26's types in M260; the most recent event of each kind before the visit
a <- merge(merge(merge(w, cd[COND_STATUS_CD == 1], by = c("PLT_CN", "CONDID")), pl[, .(CN, PREV_PLT_CN, loc)], by.x = "PLT_CN", by.y = "CN"), cache, by.x = c("PLT_CN", "CONDID"), by.y = c("plt_cn", "condid"))
a[, grp := ft$TYPGRPCD[match(FORTYPCD, ft$VALUE)]]; a <- a[ecodiv == ECODIV & grp %in% as.integer(names(TYPES))]
lastev <- function(kd) { m <- merge(a[, .(PLT_CN, CONDID, loc, MEASYEAR)], ev[kind == kd], by = "loc", allow.cartesian = TRUE)[year <= MEASYEAR]
  m[, ys := MEASYEAR - year][, .SD[ys == min(ys)][, .(ys = ys[1], year = year[1], crown = any(crown))], by = .(PLT_CN, CONDID)] }
lf <- lastev("fire"); lh <- lastev("harvest")
a <- merge(a, lf[, .(PLT_CN, CONDID, since_fire = ys, fire_year = year, crown)], by = c("PLT_CN", "CONDID"), all.x = TRUE)
a <- merge(a, lh[, .(PLT_CN, CONDID, since_cut = ys, cut_year = year)], by = c("PLT_CN", "CONDID"), all.x = TRUE)
a[, event := fifelse(!is.na(since_fire) & since_fire <= 5 & (crown %in% TRUE | (!is.na(STDAGE) & STDAGE <= since_fire + 5)), "fire",
             fifelse(!is.na(since_cut) & since_cut <= 5 & !is.na(STDAGE) & STDAGE <= since_cut + 5, "clearcut", NA_character_))]
a <- a[!is.na(event)][, ev_year := fifelse(event == "fire", fire_year, cut_year)]

# before: the same condition at the previous visit, measured before the event
pv <- pl[, .(CN, prev_year = MEASYEAR)]
b <- merge(a[, .(PLT_CN, CONDID, PREV_PLT_CN, ev_year)], pv, by.x = "PREV_PLT_CN", by.y = "CN")[prev_year < ev_year]
b <- merge(b, cache[, .(plt_cn, condid, W_b = W, standing_b = standing)], by.x = c("PREV_PLT_CN", "CONDID"), by.y = c("plt_cn", "condid"))
b <- merge(b, w[, .(PLT_CN, CONDID, cwd_b = cwd, fwd_b = fwd, floor_b = floor)], by.x = c("PREV_PLT_CN", "CONDID"), by.y = c("PLT_CN", "CONDID"), all.x = TRUE)
p <- merge(a, b[, .(PLT_CN, CONDID, prev_year, W_b, standing_b, cwd_b, fwd_b, floor_b)], by = c("PLT_CN", "CONDID"))[W_b > 5]
p[, live_left := W / W_b]
cat("Pairs (event 0-5 yr before a DWM visit, previous visit before the event, live wood before > 5 Mg C/ha):\n")
print(p[, .(pairs = .N, stand_replacing = sum(live_left <= 0.2), with_DWM_before = sum(live_left <= 0.2 & !is.na(cwd_b))), by = .(type = TYPES[as.character(grp)], event)][order(event, type)])
q <- p[live_left <= 0.2]
sh <- q[, .(pairs = .N, W_before = mean(W_b), live_left = sum(W) / sum(W_b), snags = sum(standing - standing_b) / sum(W_b), snags_total = sum(standing) / sum(W_b),
            downlogs = sum(cwd - fifelse(is.na(cwd_b), 0, cwd_b)) / sum(W_b), fwd = sum(fwd - fifelse(is.na(fwd_b), 0, fwd_b)) / sum(W_b),
            floor_kept = if (any(!is.na(floor_b))) sum(floor[!is.na(floor_b)]) / sum(floor_b[!is.na(floor_b)]) else NA_real_,
            downlogs_withprior = if (any(!is.na(cwd_b))) sum(cwd[!is.na(cwd_b)] - cwd_b[!is.na(cwd_b)]) / sum(W_b[!is.na(cwd_b)]) else NA_real_), by = .(event, sc = grp)]
sh[, type := TYPES[as.character(sc)]]
pooled <- q[, .(sc = 0L, type = "All four types", pairs = .N, W_before = mean(W_b), live_left = sum(W) / sum(W_b), snags = sum(standing - standing_b) / sum(W_b), snags_total = sum(standing) / sum(W_b),
                downlogs = sum(cwd - fifelse(is.na(cwd_b), 0, cwd_b)) / sum(W_b), fwd = sum(fwd - fifelse(is.na(fwd_b), 0, fwd_b)) / sum(W_b),
                floor_kept = if (any(!is.na(floor_b))) sum(floor[!is.na(floor_b)]) / sum(floor_b[!is.na(floor_b)]) else NA_real_,
                downlogs_withprior = if (any(!is.na(cwd_b))) sum(cwd[!is.na(cwd_b)] - cwd_b[!is.na(cwd_b)]) / sum(W_b[!is.na(cwd_b)]) else NA_real_), by = event]
sh <- rbind(sh, pooled, fill = TRUE)
cat("\nWhat the event leaves, as shares of the live aboveground wood before (stand-replacing pairs; ratio of sums):\n")
print(sh[order(event, -pairs), .(event, type, pairs, W_before = round(W_before), live_left = round(live_left, 2), snags_gained = round(snags, 2), snags_after = round(snags_total, 2),
                                 downlogs_gained = round(downlogs, 2), fwd_gained = round(fwd, 2), floor_kept = round(floor_kept, 2))])
fwrite(sh, file.path(out, "event-shares.csv")); saveRDS(q, file.path(out, "event-pairs.rds"))

# the model's events: shares of live aboveground wood that go to snags / down logs / fine woody debris / removed or emitted
evp <- fread(file.path(pkg, "defaults/stockflow/event-pathways.csv"), na.strings = "")[is.na(FromAgeMin) | FromAgeMin %in% c("11", 11)]
mshare <- function(g, merch_share) { e <- evp[TransitionGroupId == g]; v <- function(fr, to) sum(as.numeric(e[FromStockTypeId == fr & ToStockTypeId == to, Multiplier]))
  wm <- merch_share; wo <- 1 - merch_share   # live aboveground wood = merchantable + other wood
  data.table(event = g, snags = wm * v("Biomass: Merchantable", "DOM: Snag Stem") + wo * v("Biomass: Other Wood", "DOM: Snag Branch"),
             downlogs = wm * v("Biomass: Merchantable", "DOM: Aboveground Medium"), fwd = wm * v("Biomass: Merchantable", "DOM: Aboveground Fast") + wo * v("Biomass: Other Wood", "DOM: Aboveground Fast"),
             removed = wm * v("Biomass: Merchantable", "Forestry Sector") + wo * v("Biomass: Other Wood", "Forestry Sector"),
             floor_kept = 1 - mean(c(sum(as.numeric(e[FromStockTypeId == "DOM: Aboveground Very Fast" & grepl("^Atmosphere", ToStockTypeId), Multiplier])),
                                     sum(as.numeric(e[FromStockTypeId == "DOM: Aboveground Slow" & grepl("^Atmosphere", ToStockTypeId), Multiplier]))))) }
cat("\nThe model's events (stands >= 11 yr), for a stand that is 70% merchantable wood by carbon:\n")
print(rbind(mshare("Fire: High Severity [Type]", 0.7), mshare("Forest Harvest: Forest Clearcut [Type]", 0.7))[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 2) else z)])
