# =============================================================================
# 25-event-shares-national.R - to-do 32 (3): do the California-fitted fire and clearcut event shares hold elsewhere?
# =============================================================================
# The model's high-severity fire snag shares (defaults/spinup/fire-snag-share.csv, 4 types) and clearcut event flows
# (defaults/stockflow/event-pathways.csv) were fitted to Mediterranean Mountains (M260) plots (dev/fia/08, 14, 15) and are used
# everywhere. This repeats 08's direct measure for every ecodivision, all 48 states: down woody material visits 0-5 years after a
# stand-replacing event (fire, or cutting, with the stand age reset: stand age <= years since + 5; the cached since_fire / since_cut
# of src/fia.R fia_dead_wood), paired with the same condition at the plot's previous visit (PLOT.PREV_PLT_CN), measured before the
# event; stand-replacing pairs keep <= 20% of the live aboveground carbon (W) before. Per ecodivision and event: pairs, live left / W,
# snags after / W, down logs and fine woody debris gained / W (before = 0 where the previous visit had no DWM), forest floor after /
# before. M260 is the California reference the model was fitted to. Writes dev/fia/out-z7/event-shares-national.csv. Read-only.
# Usage: Rscript dev/fia/25-event-shares-national.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; out <- "F:/lucasCore/dev/fia/out-z7"; K <- 2.2417   # short tons/acre -> Mg/ha
dw <- readRDS(file.path(dm, "fia-deadwood.rds"))$dwm
cc <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[, .(plt_cn, condid, W = c_ag_all_live_trees_short_tons_per_acre * K, standing0 = c_ag_standing_dead_trees_short_tons_per_acre * K)]
pl <- rbindlist(lapply(list.files(dm, "^[A-Z]{2}_PLOT[.]csv$", full.names = TRUE), function(f) fread(f, select = c("CN", "PREV_PLT_CN", "MEASYEAR"), colClasses = list(character = c("CN", "PREV_PLT_CN")))))
a <- dw[(!is.na(since_fire) & since_fire <= 5) | (!is.na(since_cut) & since_cut <= 5)]
a[, event := fifelse(!is.na(since_fire) & since_fire <= 5 & !is.na(stdage) & stdage <= since_fire + 5, "fire",
             fifelse(!is.na(since_cut) & since_cut <= 5 & !is.na(stdage) & stdage <= since_cut + 5, "clearcut", NA_character_))]
a <- a[!is.na(event)][, ev_year := measyear - fifelse(event == "fire", since_fire, since_cut)]
a <- merge(a, pl[, .(plt_cn = CN, prev = PREV_PLT_CN)], by = "plt_cn")[!is.na(prev) & nzchar(prev)]
a <- merge(a, pl[, .(prev = CN, prev_year = MEASYEAR)], by = "prev")[prev_year < ev_year]
a <- merge(a, cc[, .(plt_cn, condid, W)], by = c("plt_cn", "condid"))                                  # after
a <- merge(a, cc[, .(prev = plt_cn, condid, W_b = W, standing_b = standing0)], by = c("prev", "condid"))  # before
a <- merge(a, dw[, .(prev = plt_cn, condid, cwd_b = cwd, fwd_b = fwd, floor_b = litter + duff)], by = c("prev", "condid"), all.x = TRUE)
p <- a[W_b > 5][, live_left := W / W_b][live_left <= 0.2]
nz <- function(v) fifelse(is.na(v), 0, v)
shares <- function(d) d[, .(pairs = .N, W_before = round(mean(W_b)), live_left = sum(W) / sum(W_b), snags_after = sum(standing) / sum(W_b),
                            snags_gained = sum(standing - standing_b) / sum(W_b), downlogs_gained = { k <- !is.na(cwd); sum((cwd - nz(cwd_b))[k]) / sum(W_b[k]) },
                            fwd_gained = { k <- !is.na(fwd); sum((fwd - nz(fwd_b))[k]) / sum(W_b[k]) }, downlogs_gained_med = median(((cwd - nz(cwd_b)) / W_b)[!is.na(cwd)]),
                            floor_kept = { k <- !is.na(floor_b) & !is.na(litter + duff); if (any(k)) sum((litter + duff)[k]) / sum(floor_b[k]) else NA_real_ },
                            with_dwm_before = sum(!is.na(cwd_b)))]
r <- rbind(p[, shares(.SD), by = .(event, ecodiv)], p[, shares(.SD), by = event][, ecodiv := "All"], fill = TRUE)
fwrite(r, file.path(out, "event-shares-national.csv"))
options(width = 220)
for (e in c("fire", "clearcut")) { cat(sprintf("\n%s, stand-replacing (live left <= 0.2), shares of the live aboveground carbon before; M260 = the California fit's region\n", toupper(e)))
  print(r[event == e & pairs >= 10][order(-pairs), .(ecodiv, pairs, W_before, live_left = round(live_left, 2), snags_after = round(snags_after, 2), snags_gained = round(snags_gained, 2),
                                                     downlogs_gained = round(downlogs_gained, 2), dl_median = round(downlogs_gained_med, 2), fwd_gained = round(fwd_gained, 2), floor_kept = round(floor_kept, 2), with_dwm_before)]) }
# the model's clearcut and fire, for a stand 70% merchantable wood by carbon (as 08), and its fire snag shares
evp <- fread("F:/lucasCore/defaults/stockflow/event-pathways.csv", na.strings = "")[is.na(FromAgeMin) | FromAgeMin %in% c("11", 11)][is.na(FromStateClassId)]
v <- function(g, fr, to) sum(as.numeric(evp[TransitionGroupId == g & FromStockTypeId == fr & ToStockTypeId == to, Multiplier]))
for (g in c("Fire: High Severity [Type]", "Forest Harvest: Forest Clearcut [Type]"))
  cat(sprintf("model %s (default rows): snags %.2f, down logs %.2f, fine woody debris %.2f of live wood\n", g,
              0.7 * v(g, "Biomass: Merchantable", "DOM: Snag Stem") + 0.3 * v(g, "Biomass: Other Wood", "DOM: Snag Branch"),
              0.7 * v(g, "Biomass: Merchantable", "DOM: Aboveground Medium"), 0.7 * v(g, "Biomass: Merchantable", "DOM: Aboveground Fast") + 0.3 * v(g, "Biomass: Other Wood", "DOM: Aboveground Fast")))
print(fread("F:/lucasCore/defaults/spinup/fire-snag-share.csv")[, .(StateClassId, Share, Plots)])
