# =============================================================================
# 09-placement.R - to-do 3, phase 0: does a rule put the die-off where FIA plots found it? (canopy-only against combined)
# =============================================================================
# 08-rule-combined.R --write=<line> leaves rule-<tag>-300m.tif: per 300 m cell, forest pixels and the pixels flagged in each year
# at the line that matches FIA's area. Matching the area says nothing about placement, so: per clean remeasured FIA plot (the
# table 07-rap-signal.R wrote: public point, visit years y0 and y1, share of carbon killed), the share of the forest within
# --radius (1000 m) of the point that the rule flagged in the years after the first visit up to the second, against the plot's
# share killed. Printed for each rule file given. Read-only.
# Usage: Rscript dev/mortality/09-placement.R <rap-signal-pNN.csv> <rule-...-300m.tif> [<rule-...-300m.tif> ...] [--radius=1000]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; RAD <- as.numeric(opt("radius", 1000)); options(width = 220); terraOptions(progress = 0)
p <- fread(pos[1])
for (f in pos[-1]) { r <- rast(f); yrs <- as.integer(names(r)[-1])
  v <- buffer(project(vect(as.matrix(p[, .(LON, LAT)]), crs = "EPSG:4269"), crs(r)), RAD)
  x <- as.matrix(extract(r, v, fun = sum, na.rm = TRUE)[, -1]); forest <- x[, 1]; fl <- x[, -1, drop = FALSE]
  d <- copy(p)[, forest := forest][, flagged := vapply(seq_len(.N), function(i) sum(fl[i, yrs > y0[i] & yrs <= y1[i]]), 0)][forest >= 300 & y0 >= min(yrs) - 1][, share := flagged / forest]
  cat(sprintf("\n===== %s: %d plots, %d over the 70%% line; mean share of nearby forest flagged between visits %.2f%% =====\n", basename(f), nrow(d), sum(d$frac >= 0.7), 100 * sum(d$flagged) / sum(d$forest)))
  cat(sprintf("correlation of the flagged share around a plot with the plot's share killed: %.2f (Spearman %.2f)\n", cor(d$share, d$frac), cor(d$share, d$frac, method = "spearman")))
  print(d[, .(plots = .N, plot_killed = round(sum(dead) / sum(live0), 3), flagged_around_pct = round(100 * sum(flagged) / sum(forest), 2)), by = .(killed = cut(frac, c(-0.001, 0.1, 0.3, 0.5, 0.7, 1)))][order(killed)])
  top <- d$share >= quantile(d$share, 0.9)
  cat(sprintf("the tenth of plots with the most flagged around them: %.1f%% are over the 70%% line (base rate %.1f%%); they hold %.0f%% of the plots over the line\n",
              100 * mean(d$frac[top] >= 0.7), 100 * mean(d$frac >= 0.7), 100 * sum(top & d$frac >= 0.7) / sum(d$frac >= 0.7))) }
