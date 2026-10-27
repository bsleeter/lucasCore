# =============================================================================
# 04-fia-mixed-conifer.R - FIA's dead carbon pools by stand age for California Mixed Conifer: standing dead, down dead, forest floor
# =============================================================================
# The USGS condition table (stage 3's calibration target; down dead with the state field adjustment), forest type group 370 in the
# Mediterranean Mountains ecodivision (M260, the P26 cell), conditions with no recorded disturbance or treatment (stage 3's filter),
# latest visit per plot-condition from 1997. One panel per pool: every plot-condition, and the mean and interquartile range in 10-year
# stand age bins. Writes dev/nfcms/out/fia-mixed-conifer-dead-by-age.png. Read-only.
# Usage: Rscript dev/nfcms/04-fia-mixed-conifer.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
fia <- "F:/lucas-master/Data Sources/FIA"; out <- "F:/lucasCore/dev/nfcms/out"
u <- as.data.table(readRDS(file.path(fia, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds")))
d <- as.data.table(readRDS(file.path(fia, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds")))
x <- merge(u, d, by = c("plt_cn", "condid"))[fortyp_grp == 370 & ecodiv == "M260" & dstrbcd1 %in% 0 & trtcd1 %in% 0 & !is.na(stdage) & stdage >= 1 & invyr >= 1997 & invyr < 9999]
x[, pid := paste(statecd, unitcd, countycd, plot)]; setorder(x, pid, condid, -invyr); x <- x[!duplicated(paste(pid, condid))]
k <- 2.2417   # short tons per acre -> Mg C/ha
x[, `:=`(standing = c_ag_standing_dead_trees_short_tons_per_acre * k, down = c_down_dead_tons_per_acre * k, floor = c_litter_tons_per_acre * k)]
x <- x[stdage <= 300]
x[, bin := pmin(floor(stdage / 10) * 10 + 5, 295)]
s <- x[, .(n = .N, standing = mean(standing), down = mean(down), floor = mean(floor),
           st_q1 = quantile(standing, .25), st_q3 = quantile(standing, .75), dn_q1 = quantile(down, .25), dn_q3 = quantile(down, .75),
           fl_q1 = quantile(floor, .25), fl_q3 = quantile(floor, .75)), by = bin][order(bin)][n >= 5]
cat(sprintf("%d plot-conditions (%d plots), ages %d-%d\n", nrow(x), uniqueN(x$pid), min(x$stdage), max(x$stdage)))
print(s[, .(bin, n, standing = round(standing, 1), down = round(down, 1), floor = round(floor, 1))])

INK <- "#2b2b2b"; MUTED <- "#6f6e69"; GRID <- "#e6e5e0"
cols <- c(standing = "#2a78d6", down = "#eb6834", floor = "#1baf7a")   # categorical slots 1-3 of the reference palette
alpha <- function(h, a) grDevices::adjustcolor(h, alpha.f = a)
png(file.path(out, "fia-mixed-conifer-dead-by-age.png"), width = 2400, height = 900, res = 200, bg = "white")
par(mfrow = c(1, 3), oma = c(2.5, 0, 4.2, 0), mar = c(3.5, 4.5, 3, 1), family = "sans", col.axis = MUTED, col.lab = INK, las = 1, cex.axis = .85, tcl = -.25, mgp = c(2.6, .5, 0))
yl <- c(0, max(quantile(x$standing, .98), quantile(x$down, .98), quantile(x$floor, .98)))
panel <- function(p, q1, q3, ttl) {
  plot(NA, xlim = c(0, 300), ylim = yl, xlab = "Stand age (years)", ylab = "Mg C/ha", bty = "l")
  abline(h = axTicks(2), col = GRID, lwd = .6)
  points(x$stdage, pmin(x[[p]], yl[2]), pch = 16, cex = .35, col = alpha(cols[[p]], .18))
  polygon(c(s$bin, rev(s$bin)), c(s[[q1]], rev(s[[q3]])), col = alpha(cols[[p]], .22), border = NA)
  lines(s$bin, s[[p]], lwd = 2.4, col = cols[[p]])
  title(main = ttl, adj = 0, font.main = 2, cex.main = 1.05, col.main = INK) }
panel("standing", "st_q1", "st_q3", "Standing dead (measured)")
panel("down", "dn_q1", "dn_q3", "Down dead (modelled, field-adjusted)")
panel("floor", "fl_q1", "fl_q3", "Forest floor / litter (modelled)")
mtext("FIA dead carbon by stand age: California Mixed Conifer, Mediterranean Mountains", outer = TRUE, side = 3, line = 2.4, adj = 0.01, cex = 1.1, font = 2, col = INK)
mtext(sprintf("%s plot-conditions (no recorded disturbance or treatment, latest visit since 1997). Points: each condition; line: mean per 10-year age bin; band: interquartile range.",
              format(nrow(x), big.mark = ",")), outer = TRUE, side = 3, line = 1, adj = 0.01, cex = .72, col = MUTED)
mtext("Standing dead: measured dead trees. Down dead: Smith and Heath (2008) model of live tree carbon x the state field factor. Forest floor: Domke et al. (2016) model. Points above the 98th percentile drawn at the top.",
      outer = TRUE, side = 1, line = 1, adj = 0.01, cex = .62, col = MUTED)
dev.off(); cat("written", file.path(out, "fia-mixed-conifer-dead-by-age.png"), "\n")
