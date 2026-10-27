# =============================================================================
# 07-young-stand-replacing.R - the young-stand check of 06-calibrate-measured.R restricted to stand-replacing events: high-severity
# fire and clearcut - FIA's measured dead pools by years since the event against the model's fire-last and clearcut-last curves
# =============================================================================
# FIA has a crown fire code (DSTRBCD 32) but no clearcut code (TRTCD 10 is any cutting). Stand-replacing is taken as:
#   high-severity fire  a recorded crown fire (32), or any recorded fire (30-32) after which the stand age was reset (STDAGE <= years
#                       since the fire + 5)
#   clearcut            a recorded cutting (10) after which the stand age was reset (STDAGE <= years since the cut + 5)
# Uses 06's calibration (out-cal/calibration.rds: the mature-stand multipliers and the model's young-stand curves). California,
# Mediterranean Mountains, P26's four main types. Writes dev/fia/out-cal/young-stand-replacing.csv and a figure. Read-only.
# Usage: Rscript dev/fia/07-young-stand-replacing.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- "F:/lucasCore"; dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; out <- Sys.getenv("LUCAS_CAL_OUT", file.path(pkg, "dev/fia/out-cal"))
r <- readRDS(file.path(out, "calibration.rds")); ECODIV <- "M260"
TYPES <- c(`370` = "California Mixed Conifer", `260` = "Fir/Spruce/Mountain Hemlock", `220` = "Ponderosa Pine", `920` = "Western Oak")
LB <- 0.000453592 * 2.471
w <- unique(fread(file.path(dm, "CA_COND_DWM_CALC.csv"), select = c("PLT_CN", "CONDID", "MEASYEAR", "CWD_CARBON_COND", "PILE_CARBON_COND", "FWD_SM_CARBON_COND",
            "FWD_MD_CARBON_COND", "FWD_LG_CARBON_COND", "DUFF_CARBON", "LITTER_CARBON"), colClasses = list(character = "PLT_CN")), by = c("PLT_CN", "CONDID"))
for (k in grep("CARBON", names(w), value = TRUE)) w[, (k) := as.numeric(get(k)) * LB]
w[, `:=`(cwd = CWD_CARBON_COND + fifelse(is.na(PILE_CARBON_COND), 0, PILE_CARBON_COND), fwd = FWD_SM_CARBON_COND + FWD_MD_CARBON_COND + FWD_LG_CARBON_COND, floor = LITTER_CARBON + DUFF_CARBON)]
cd <- fread(file.path(dm, "CA_COND.csv"), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "STDAGE", "FORTYPCD", paste0("DSTRBCD", 1:3), paste0("DSTRBYR", 1:3), paste0("TRTCD", 1:3), paste0("TRTYR", 1:3)),
            colClasses = list(character = "PLT_CN"))
pl <- fread(file.path(dm, "CA_PLOT.csv"), select = c("CN", "STATECD", "UNITCD", "COUNTYCD", "PLOT"), colClasses = list(character = "CN"))[, loc := paste(STATECD, UNITCD, COUNTYCD, PLOT)]
ft <- fread(file.path(dm, "REFERENCE", "REF_FOREST_TYPE.csv"), select = c("VALUE", "TYPGRPCD"))
cache <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[statecd == 6, .(plt_cn, condid, ecodiv, standing = c_ag_standing_dead_trees_short_tons_per_acre * 2.2417)]
h <- merge(cd, pl[, .(CN, loc)], by.x = "PLT_CN", by.y = "CN")
ev <- unique(rbindlist(lapply(1:3, function(i) rbind(
  h[get(paste0("DSTRBCD", i)) %in% 30:32 & get(paste0("DSTRBYR", i)) %between% c(1900, 2030), .(loc, year = get(paste0("DSTRBYR", i)), kind = "fire", crown = get(paste0("DSTRBCD", i)) == 32)],
  h[get(paste0("TRTCD", i)) %in% 10 & get(paste0("TRTYR", i)) %between% c(1900, 2030), .(loc, year = get(paste0("TRTYR", i)), kind = "harvest", crown = FALSE)]))))
x <- merge(merge(merge(w, cd[COND_STATUS_CD == 1], by = c("PLT_CN", "CONDID")), pl[, .(CN, loc)], by.x = "PLT_CN", by.y = "CN"), cache, by.x = c("PLT_CN", "CONDID"), by.y = c("plt_cn", "condid"))
x[, grp := ft$TYPGRPCD[match(FORTYPCD, ft$VALUE)]]; x <- x[ecodiv == ECODIV & grp %in% as.integer(names(TYPES))]
# the most recent event of each kind before the measurement, with whether any such event at that year was a crown fire
last <- function(kd) { m <- merge(x[, .(PLT_CN, CONDID, loc, MEASYEAR)], ev[kind == kd], by = "loc", allow.cartesian = TRUE)[year <= MEASYEAR]
  m[, ys := MEASYEAR - year][, .SD[ys == min(ys)][, .(ys = ys[1], crown = any(crown))], by = .(PLT_CN, CONDID)] }
lf <- last("fire"); lh <- last("harvest")
x <- merge(x, lf[, .(PLT_CN, CONDID, since_fire = ys, crown)], by = c("PLT_CN", "CONDID"), all.x = TRUE)
x <- merge(x, lh[, .(PLT_CN, CONDID, since_harvest = ys)], by = c("PLT_CN", "CONDID"), all.x = TRUE)
x[, `:=`(reset_fire = !is.na(since_fire) & !is.na(STDAGE) & STDAGE <= since_fire + 5, reset_cut = !is.na(since_harvest) & !is.na(STDAGE) & STDAGE <= since_harvest + 5)]
x[, hsfire := !is.na(since_fire) & since_fire <= 30 & (crown %in% TRUE | reset_fire)]
x[, clearcut := !is.na(since_harvest) & since_harvest <= 30 & reset_cut & !(hsfire & since_fire <= since_harvest)]

cnt <- x[, .(any_fire_30yr = sum(since_fire <= 30, na.rm = TRUE), crown_fire = sum(since_fire <= 30 & crown %in% TRUE, na.rm = TRUE), fire_age_reset = sum(since_fire <= 30 & reset_fire, na.rm = TRUE),
             high_severity = sum(hsfire), any_cut_30yr = sum(since_harvest <= 30, na.rm = TRUE), clearcut = sum(clearcut)), by = .(type = TYPES[as.character(grp)])]
cat("DWM conditions within 30 years of an event, Mediterranean Mountains:\n"); print(cnt)

YB <- c(-1, 5, 10, 20, 30); P <- c("standing", "cwd", "fwd", "floor")
obs <- rbind(x[hsfire == TRUE, .(sc = grp, kind = "fire", years = cut(since_fire, YB), standing, cwd, fwd, floor)],
             x[clearcut == TRUE, .(sc = grp, kind = "harvest", years = cut(since_harvest, YB), standing, cwd, fwd, floor)])
ob <- obs[, c(list(n = .N), lapply(.SD, mean, na.rm = TRUE)), by = .(sc, kind, years), .SDcols = P]
mod <- copy(r$young)[, years := cut(age, YB)][, lapply(.SD, mean), by = .(sc, kind, years), .SDcols = P]
yy <- merge(ob, mod, by = c("sc", "kind", "years"), suffixes = c("", "_model"))[order(sc, kind, years)]
yy[, type := TYPES[as.character(sc)]][, event := ifelse(kind == "fire", "high-severity fire", "clearcut")]
cat("\nMeasured / model (mature-stand calibration), Mg C/ha, by years since a stand-replacing event:\n")
print(yy[n >= 3, .(type = substr(type, 1, 18), event, years, n, standing = sprintf("%.1f / %.1f", standing, standing_model), downlogs = sprintf("%.1f / %.1f", cwd, cwd_model),
              fwd = sprintf("%.1f / %.1f", fwd, fwd_model), floor = sprintf("%.1f / %.1f", floor, floor_model))])
fwrite(yy, file.path(out, "young-stand-replacing.csv"))

# figure: Mixed Conifer and Western Oak (the two with the most events), measured points and bin means vs the model curve, per pool
INK <- "#2b2b2b"; MUTED <- "#6f6e69"; GRID <- "#e6e5e0"; C1 <- "#2a78d6"; C2 <- "#eb6834"
al <- function(h, a) grDevices::adjustcolor(h, alpha.f = a)
png(file.path(out, "young-stand-replacing.png"), width = 2800, height = 1700, res = 200, bg = "white")
par(mfrow = c(2, 4), oma = c(2.5, 0, 4.2, 0), mar = c(3.5, 4.5, 3, 1), family = "sans", col.axis = MUTED, col.lab = INK, las = 1, cex.axis = .8, tcl = -.25, mgp = c(2.5, .5, 0))
lab <- c(standing = "Standing dead", cwd = "Down logs (AG Medium)", fwd = "Fine woody debris (AG Fast)", floor = "Forest floor (AG VF + AG Slow)")
for (s in c(370L, 920L)) for (p in P) {
  of <- x[grp == s & hsfire == TRUE, .(t = since_fire, v = get(p))]; oc <- x[grp == s & clearcut == TRUE, .(t = since_harvest, v = get(p))]
  mf <- r$young[sc == s & kind == "fire"]; mc <- r$young[sc == s & kind == "harvest"]
  ymax <- max(quantile(c(of$v, oc$v), .97, na.rm = TRUE), mf[[p]], mc[[p]], 1)
  plot(NA, xlim = c(0, 30), ylim = c(0, ymax), xlab = "Years since the event", ylab = "Mg C/ha", bty = "l"); abline(h = axTicks(2), col = GRID, lwd = .6)
  points(jitter(of$t, .6), pmin(of$v, ymax), pch = 16, cex = .5, col = al(C2, .35)); points(jitter(oc$t, .6), pmin(oc$v, ymax), pch = 17, cex = .5, col = al(C1, .35))
  lines(mf$age, mf[[p]], col = C2, lwd = 2.4); lines(mc$age, mc[[p]], col = C1, lwd = 2.4)
  title(main = sprintf("%s: %s", if (s == 370) "Mixed Conifer" else "Western Oak", lab[[p]]), adj = 0, font.main = 2, cex.main = .9, col.main = INK)
  if (p == "standing") legend("topright", c("high-severity fire: plots", "model, fire last", "clearcut: plots", "model, clearcut last"), pch = c(16, NA, 17, NA), lty = c(NA, 1, NA, 1),
                              lwd = c(NA, 2.4, NA, 2.4), col = c(C2, C2, C1, C1), bty = "n", cex = .7, text.col = INK) }
mtext("After stand-replacing fire and clearcut: FIA measured dead carbon vs the model (decay calibrated to mature stands)", outer = TRUE, side = 3, line = 2.4, adj = 0.01, cex = 1.05, font = 2, col = INK)
mtext("California, Mediterranean Mountains. High-severity fire: recorded crown fire, or a recorded fire after which the stand age reset; clearcut: recorded cutting after which the stand age reset.",
      outer = TRUE, side = 3, line = 1, adj = 0.01, cex = .7, col = MUTED)
mtext("Points: FIA down woody material plot-conditions (DWM) and measured standing dead; lines: the spin-up's dead pools by age after a fire-last or clearcut-last disturbance (06-calibrate-measured.R).",
      outer = TRUE, side = 1, line = 1, adj = 0.01, cex = .62, col = MUTED)
dev.off(); cat("written", out, "\n")
