# =============================================================================
# 03-carbon-effect.R - to-do item 8: what a resampling method's extra developed land would do to P26's initial carbon
# =============================================================================
# A first-order estimate, not a model run: cells a method makes developed in 1985 that the modal map does not would start with the
# carbon density of developed land instead of their own. Densities come from the P26 historical run (result 9) Total Ecosystem map of
# 1985: each such cell's own density, against the mean density of the cells the modal map already calls developed. Also reports which
# classes those cells come from.
# Usage: Rscript dev/resampling/03-carbon-effect.R [method]   (default thresh_0.3; any method of 02-compare-methods.R)
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
pkg <- "F:/lucasCore"; cache <- file.path(pkg, "dev/resampling/cache"); km2 <- 0.0225
a <- commandArgs(TRUE); want <- if (length(a)) a[1] else "thresh_0.3"
te <- values(rast(file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim.data/Scenario-9/stsim_OutputAverageSpatialStockGroup/avgstkg_628.it0.ts1985.tif")), mat = FALSE)
s <- rast(file.path(cache, "shares_1985.tif")); m <- values(s[["modal"]], mat = FALSE); d <- values(s[["dev"]], mat = FALSE)
dm <- values(s[["devmode"]], mat = FALSE); nd <- values(s[["nondev"]], mat = FALSE); ok <- !is.na(m)
isdev <- function(x) !is.na(x) & x >= 21 & x <= 24
if (startsWith(want, "areamatch")) {   # every areamatch variant has the same 1985 map
  county <- values(rast(file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim.data/Scenario-2/stsim_InitialConditionsSpatial/SecondaryStrata.tif")), mat = FALSE)
  dd <- d; dd[is.na(dd)] <- 0; take <- logical(length(m)); sel <- ok & !is.na(county)
  dt <- data.table(i = which(sel), c = county[sel], d = dd[sel]); dt[, k := round(sum(d)), by = c]; setorder(dt, c, -d); dt[, r := seq_len(.N), by = c]
  take[dt[r <= k & d > 0, i]] <- TRUE; x <- m; x[take] <- dm[take]; lo <- ok & isdev(m) & !take; x[lo] <- nd[lo]
} else {
  t <- as.numeric(sub("^thresh_([0-9.]+).*", "\\1", want)); if (is.na(t)) stop("methods: thresh_<t> or areamatch*")
  x <- m; hi <- ok & !is.na(d) & d >= t; x[hi] <- dm[hi]; lo <- ok & isdev(m) & !hi; x[lo] <- nd[lo] }
gain <- ok & isdev(x) & !isdev(m); lose <- ok & isdev(m) & !isdev(x)
dev_density <- mean(te[ok & isdev(m)], na.rm = TRUE)
grp <- function(v) ifelse(v %in% 41:43, "Forest", ifelse(v %in% 51:52, "Shrubland", ifelse(v %in% 71:74, "Grassland", ifelse(v %in% 81:82, "Agriculture",
          ifelse(v %in% 90:95, "Wetland", ifelse(v %in% 11:12, "Water/ice", "Other"))))))
from <- data.table(cls = grp(m[gain]), te = te[gain])[, .(km2 = .N * km2, mean_MgC_ha = round(mean(te, na.rm = TRUE))), by = cls][order(-km2)]
dC <- (sum(dev_density - te[gain], na.rm = TRUE) + sum(te[lose] - dev_density, na.rm = TRUE)) * km2 * 100 / 1e6   # Mg C/ha * ha -> Tg
cat(sprintf("%s, 1985: %.0f km2 become developed (%.0f km2 leave developed); developed land holds %.0f Mg C/ha on average\n",
            want, sum(gain) * km2, sum(lose) * km2, dev_density))
print(from)
cat(sprintf("Initial total ecosystem carbon change: %+.2f Tg C, against %.1f Tg C in P26 (%+.2f%%)\n", dC, sum(te[ok], na.rm = TRUE) * km2 * 100 / 1e6,
            100 * dC / (sum(te[ok], na.rm = TRUE) * km2 * 100 / 1e6)))
