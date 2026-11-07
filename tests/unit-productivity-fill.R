# =============================================================================
# unit-productivity-fill.R - the neighbourhood fill of the productivity multipliers (src/productivity-fill.R; stage 8)
# =============================================================================
# Plain R, a made-up grid, no SyncroSim. Checks that a filled cell takes the inverse-distance weighted mean of nearby source cells of
# its own ecodivision, that sources keep their values, that another ecodivision's sources are never used, that far cells (beyond
# near_km, within far_km) are filled on the coarse pass, and that cells beyond far_km keep their value.
# Usage: Rscript tests/unit-productivity-fill.R
# =============================================================================
suppressPackageStartupMessages(library(terra))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "productivity-fill.R"))
ok <- 0; bad <- 0
expect <- function(what, cond) { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, "\n") } }

# 120 x 120 cells of 250 m (30 km); ecodivision 1 on the left half, 2 on the right
P <- rast(nrows = 120, ncols = 120, xmin = 0, xmax = 30000, ymin = 0, ymax = 30000, crs = "EPSG:5070")
cc <- rowColFromCell(P, 1:ncell(P)); eco <- ifelse(cc[, 2] <= 60, 1, 2); P <- setValues(P, eco)
cell <- function(r, c) cellFromRowCol(P, r, c)
mult <- rep(1, ncell(P)); src <- rep(FALSE, ncell(P))
# two sources in ecodivision 1, one in ecodivision 2 right across the border
a <- cell(30, 20); b <- cell(30, 24); z <- cell(30, 62)
mult[c(a, b, z)] <- c(0.6, 1.4, 2.4); src[c(a, b, z)] <- TRUE
fill <- !src
f <- fill_multiplier(P, mult, src, fill)
m <- f$mult
expect("sources keep their own values", all(m[c(a, b, z)] == c(0.6, 1.4, 2.4)))
expect("a cell midway between two equal-distance sources takes their mean", abs(m[cell(30, 22)] - 1.0) < 1e-9)
# one cell from a, three from b: weights 1 and 1/9
expect("inverse-distance squared weights", abs(m[cell(30, 21)] - (0.6 * 1 + 1.4 / 9) / (1 + 1 / 9)) < 1e-9)
expect("a cell next to the border takes nothing from the other ecodivision", m[cell(30, 60)] <= 1.4 + 1e-9)
expect("the other ecodivision's cells near z take z's value", abs(m[cell(30, 64)] - 2.4) < 1e-9)
# 6 km away (24 cells): beyond near_km (2 km), within far_km (10 km): filled on the 1 km pass, between the sources' values
far <- cell(54, 22)
expect("a cell 6 km away is filled on the coarse pass", f$filled[far] && m[far] > 0.6 && m[far] < 1.4)
# 25 km away from every ecodivision 1 source: keeps 1
expect("a cell beyond far_km keeps its value", !f$filled[cell(120, 1)] && m[cell(120, 1)] == 1)
expect("no source cell is marked filled", !any(f$filled[src]))
# an ecodivision with no source: nothing filled there
src2 <- src; src2[z] <- FALSE; f2 <- fill_multiplier(P, mult, src2, !src2)
expect("an ecodivision without sources is left as it was", !any(f2$filled[eco == 2]))
cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
