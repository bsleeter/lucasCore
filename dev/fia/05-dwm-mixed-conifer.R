# =============================================================================
# 05-dwm-mixed-conifer.R - FIA's MEASURED dead carbon (down woody material plots) by stand age and by years since fire or harvest,
# against the modelled down dead and litter of the condition table - California, P26's forest types
# =============================================================================
# CA_COND_DWM_CALC (FIA DataMart; per condition, lb/acre -> Mg C/ha x 0.0011208), matched to CBM pools:
#   coarse woody debris (>= 3 in) + slash piles  -> AG Medium        fine woody debris (< 3 in; 3 size classes) -> AG Fast
#   litter                                        -> AG Very Fast     duff                                        -> AG Slow
# and standing dead trees (TREE, every plot; the DataMart cache) -> snags. Condition attributes (stand age, forest type group,
# disturbance and treatment codes and years) from CA_COND; ecodivision from the cache. Years since fire / harvest: the most recent
# fire (DSTRBCD 30-32) or cutting (TRTCD 10) year recorded at the plot location in any visit up to the DWM measurement.
# Writes dev/fia/out-dwm/ (figures, dwm-by-age.csv, dwm-counts.csv). Read-only.
# Usage: Rscript dev/fia/05-dwm-mixed-conifer.R [forest type group, default 370] [ecodivision, default M260]
# =============================================================================
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(TRUE); g0 <- if (length(a) >= 1) as.integer(a[1]) else 370L; eco <- if (length(a) >= 2) a[2] else "M260"
dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; out <- "F:/lucasCore/dev/fia/out-dwm"; dir.create(out, showWarnings = FALSE)
LB <- 0.000453592 * 2.471   # lb/acre -> Mg/ha
w <- fread(file.path(dm, "CA_COND_DWM_CALC.csv"), select = c("PLT_CN", "CONDID", "MEASYEAR", "INVYR", "CWD_CARBON_COND", "PILE_CARBON_COND", "FWD_SM_CARBON_COND",
           "FWD_MD_CARBON_COND", "FWD_LG_CARBON_COND", "DUFF_CARBON", "LITTER_CARBON", "CONDPROP_CWD", "CONDPROP_FWD_SM", "CONDPROP_DUFF"), colClasses = list(character = "PLT_CN"))
w <- unique(w, by = c("PLT_CN", "CONDID"))   # one row per condition visit (the table repeats rows across evaluations)
for (k in grep("CARBON", names(w), value = TRUE)) w[, (k) := as.numeric(get(k)) * LB]
w[, `:=`(cwd = CWD_CARBON_COND + fifelse(is.na(PILE_CARBON_COND), 0, PILE_CARBON_COND), fwd = FWD_SM_CARBON_COND + FWD_MD_CARBON_COND + FWD_LG_CARBON_COND,
         litter = LITTER_CARBON, duff = DUFF_CARBON)]
cd <- fread(file.path(dm, "CA_COND.csv"), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "STDAGE", "FORTYPCD", "DSTRBCD1", "DSTRBYR1", "DSTRBCD2", "DSTRBYR2", "DSTRBCD3", "DSTRBYR3",
            "TRTCD1", "TRTYR1", "TRTCD2", "TRTYR2", "TRTCD3", "TRTYR3", "CARBON_DOWN_DEAD", "CARBON_LITTER"), colClasses = list(character = "PLT_CN"))
pl <- fread(file.path(dm, "CA_PLOT.csv"), select = c("CN", "STATECD", "UNITCD", "COUNTYCD", "PLOT", "MEASYEAR"), colClasses = list(character = "CN"))
ft <- fread(file.path(dm, "REFERENCE", "REF_FOREST_TYPE.csv"), select = c("VALUE", "TYPGRPCD"))
cache <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[statecd == 6, .(plt_cn, condid, ecodiv, standing = c_ag_standing_dead_trees_short_tons_per_acre * 2.2417)]
pl[, loc := paste(STATECD, UNITCD, COUNTYCD, PLOT)]

# disturbance history at each plot location, from every visit: (location, year, kind)
h <- merge(cd, pl[, .(CN, loc)], by.x = "PLT_CN", by.y = "CN")
ev <- rbindlist(lapply(1:3, function(i) rbind(
  h[get(paste0("DSTRBCD", i)) %in% 30:32 & get(paste0("DSTRBYR", i)) %between% c(1900, 2030), .(loc, year = get(paste0("DSTRBYR", i)), kind = "fire")],
  h[get(paste0("TRTCD", i)) %in% 10 & get(paste0("TRTYR", i)) %between% c(1900, 2030), .(loc, year = get(paste0("TRTYR", i)), kind = "harvest")])))
ev <- unique(ev)

x <- merge(w, cd[COND_STATUS_CD == 1], by = c("PLT_CN", "CONDID"))
x <- merge(x, pl[, .(CN, loc)], by.x = "PLT_CN", by.y = "CN")
x <- merge(x, cache, by.x = c("PLT_CN", "CONDID"), by.y = c("plt_cn", "condid"), all.x = TRUE)
x[, `:=`(grp = ft$TYPGRPCD[match(FORTYPCD, ft$VALUE)], down_model = CARBON_DOWN_DEAD * 2.2417 * 0.70, litter_model = CARBON_LITTER * 2.2417)]   # CA field factor 0.70
since <- function(kd) { e <- ev[kind == kd]; m <- merge(x[, .(PLT_CN, CONDID, loc, MEASYEAR)], e, by = "loc", allow.cartesian = TRUE)[year <= MEASYEAR]
  m[, .(ys = min(MEASYEAR - year)), by = .(PLT_CN, CONDID)] }
x <- merge(x, setnames(since("fire"), "ys", "since_fire"), by = c("PLT_CN", "CONDID"), all.x = TRUE)
x <- merge(x, setnames(since("harvest"), "ys", "since_harvest"), by = c("PLT_CN", "CONDID"), all.x = TRUE)

# ---- sample sizes for P26's types -------------------------------------------------------------------------------------------
TYPES <- c(`370` = "California Mixed Conifer", `920` = "Western Oak", `260` = "Fir/Spruce/Mountain Hemlock", `220` = "Ponderosa Pine", `240` = "Lodgepole Pine")
cnt <- x[grp %in% as.integer(names(TYPES)), .(DWM_conditions = .N, with_age = sum(!is.na(STDAGE)), Mediterranean_Mtns = sum(ecodiv %in% "M260"),
         with_fire = sum(!is.na(since_fire)), fire_within_30yr = sum(since_fire <= 30, na.rm = TRUE), with_harvest = sum(!is.na(since_harvest)),
         harvest_within_30yr = sum(since_harvest <= 30, na.rm = TRUE), visits = paste(range(MEASYEAR), collapse = "-")), by = grp][, type := TYPES[as.character(grp)]]
cat("DWM plot-conditions in California by forest type:\n"); print(cnt[, .(type, DWM_conditions, Mediterranean_Mtns, with_age, with_fire, fire_within_30yr, with_harvest, harvest_within_30yr, visits)])
fwrite(cnt, file.path(out, "dwm-counts.csv"))

# ---- the chosen type x ecodivision ----------------------------------------------------------------------------------------------
z <- x[grp == g0 & ecodiv %in% eco & !is.na(cwd)]   # g0, not grp: inside [ ] grp is the column
cat(sprintf("\n%s, %s: %d DWM conditions (%d with a stand age)\n", TYPES[as.character(g0)], eco, nrow(z), sum(!is.na(z$STDAGE))))
B <- c(0, 20, 40, 60, 80, 100, 150, 300)
s <- z[!is.na(STDAGE) & STDAGE >= 1, .(n = .N, standing = mean(standing, na.rm = TRUE), cwd = mean(cwd), fwd = mean(fwd, na.rm = TRUE), litter = mean(litter, na.rm = TRUE), duff = mean(duff, na.rm = TRUE),
         down_model = mean(down_model, na.rm = TRUE), litter_model = mean(litter_model, na.rm = TRUE)), by = .(band = cut(STDAGE, B))][order(band)]
for (k in names(s)[-(1:2)]) s[, (k) := round(get(k), 1)]
cat("Mg C/ha by stand age (measured: standing, cwd = down logs + piles, fwd, litter, duff; modelled: down_model, litter_model):\n"); print(s)
fwrite(s, file.path(out, sprintf("dwm-by-age-%d-%s.csv", g0, eco)))
tb <- function(col, lab) z[!is.na(get(col)) & get(col) <= 60, .(n = .N, standing = mean(standing, na.rm = TRUE), cwd = mean(cwd), fwd = mean(fwd, na.rm = TRUE), floor = mean(litter + duff, na.rm = TRUE)),
                          by = .(years = cut(get(col), c(-1, 5, 10, 20, 30, 60)))][order(years)][, since := lab]
ts <- rbind(tb("since_fire", "fire"), tb("since_harvest", "harvest")); for (k in c("standing", "cwd", "fwd", "floor")) ts[, (k) := round(get(k), 1)]
cat("\nMg C/ha by years since the last recorded fire or harvest at the plot:\n"); print(ts)
fwrite(ts, file.path(out, sprintf("dwm-since-disturbance-%d-%s.csv", g0, eco)))

# ---- figure: measured pools by stand age, with the modelled ones the calibration uses today ---------------------------------------
INK <- "#2b2b2b"; MUTED <- "#6f6e69"; GRID <- "#e6e5e0"; C1 <- "#2a78d6"; C2 <- "#eb6834"
al <- function(h, a) grDevices::adjustcolor(h, alpha.f = a)
zz <- z[!is.na(STDAGE) & STDAGE >= 1 & STDAGE <= 300][, bin := pmin(floor(STDAGE / 20) * 20 + 10, 290)]
bs <- zz[, .(n = .N, standing = mean(standing, na.rm = TRUE), cwd = mean(cwd), fwd = mean(fwd, na.rm = TRUE), litter = mean(litter, na.rm = TRUE), duff = mean(duff, na.rm = TRUE),
             down_model = mean(down_model, na.rm = TRUE), litter_model = mean(litter_model, na.rm = TRUE)), by = bin][order(bin)][n >= 5]
png(file.path(out, sprintf("dwm-by-age-%d-%s.png", g0, eco)), width = 2600, height = 1500, res = 200, bg = "white")
par(mfrow = c(2, 3), oma = c(2.5, 0, 4.2, 0), mar = c(3.5, 4.5, 3, 1), family = "sans", col.axis = MUTED, col.lab = INK, las = 1, cex.axis = .85, tcl = -.25, mgp = c(2.6, .5, 0))
pan <- function(v, ttl, model = NULL, mlab = NULL, ymax = NULL) {
  yy <- zz[[v]]; ymax <- if (is.null(ymax)) quantile(yy, .97, na.rm = TRUE) else ymax
  plot(NA, xlim = c(0, 300), ylim = c(0, ymax), xlab = "Stand age (years)", ylab = "Mg C/ha", bty = "l"); abline(h = axTicks(2), col = GRID, lwd = .6)
  points(zz$STDAGE, pmin(yy, ymax), pch = 16, cex = .45, col = al(C1, .25)); lines(bs$bin, bs[[v]], lwd = 2.4, col = C1)
  if (!is.null(model)) { lines(bs$bin, bs[[model]], lwd = 2.4, col = C2, lty = 2); legend("topleft", c("measured (DWM)", mlab), col = c(C1, C2), lty = c(1, 2), lwd = 2.4, bty = "n", cex = .8, text.col = INK) }
  title(main = ttl, adj = 0, font.main = 2, cex.main = 1.0, col.main = INK) }
pan("standing", "Standing dead (snags)")
pan("cwd", "Coarse woody debris + piles (AG Medium)", "down_model", "condition table down dead (model)")
pan("fwd", "Fine woody debris < 3 in (AG Fast)")
pan("litter", "Litter (AG Very Fast)")
pan("duff", "Duff (AG Slow)")
zz[, floor := litter + duff]; bs[, floor := litter + duff]; pan("floor", "Forest floor: litter + duff", "litter_model", "condition table litter (model)")
mtext(sprintf("FIA measured dead carbon by stand age: %s, %s (California)", TYPES[as.character(g0)], eco), outer = TRUE, side = 3, line = 2.4, adj = 0.01, cex = 1.1, font = 2, col = INK)
mtext(sprintf("%d down woody material plot-conditions, visits %s. Points: each condition; line: mean per 20-year age bin (bins with >= 5 conditions).", nrow(zz), paste(range(zz$MEASYEAR), collapse = "-")),
      outer = TRUE, side = 3, line = 1, adj = 0.01, cex = .72, col = MUTED)
mtext("Measured: FIA COND_DWM_CALC (transects and duff/litter samples); standing dead from measured dead trees. Dashed: the modelled values stage 3 calibrates to today (down dead x CA field factor 0.70).",
      outer = TRUE, side = 1, line = 1, adj = 0.01, cex = .62, col = MUTED)
dev.off(); cat("written", out, "\n")
