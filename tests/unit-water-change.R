# Fast test of the water, wetland and barren change rule (no SyncroSim, no data). Run: Rscript tests/unit-water-change.R (from the package root)
source("src/water-change.R")
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
one <- function(open, nlcd, ...) { x <- water_change(matrix(as.integer(open), 1), matrix(as.integer(rep_len(nlcd, length(open))), 1), ...); x$change <- as.vector(x$change); x$water <- as.vector(x$water); x }
W <- WATER_CHANGE

# ---- away from wetland: two lines on each year's value ----
x <- one(c(0, 60, 65, 80, 50, 40, 20), c(31, 31, 31, 11, 11, 11, 31))
check("land turns to water at 70 or more, not at 60", identical(x$change, c(0L, 0L, 0L, W[["To Water"]], 0L, 0L, W[["Water to Barren"]])))
check("water holds between the lines and turns back at 30 or less", identical(x$water, c(FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE)))
check("a pixel hovering around 50 never changes", all(one(c(45, 55, 45, 55, 60, 40), 71)$change == 0L))
x <- one(c(100, 100, 10, 5, 90, 100, 20, 95), c(11, 11, 31, 31, 11, 11, 31, 11))
check("a reservoir bed changes the year it empties and the year it refills", identical(x$change, c(0L, 0L, 3L, 0L, 1L, 0L, 3L, 1L)))
check("an exposed bed away from wetland is barren when the NLCD reads barren", one(c(100, 100, 10, 10, 10), c(11, 11, 31, 31, 31))$change[3] == W[["Water to Barren"]])
check("... and when the NLCD reads grassland", one(c(100, 100, 10, 10, 10), c(11, 11, 71, 71, 71))$change[3] == W[["Water to Barren"]])
check("... but stays water while the NLCD still reads water", all(one(c(100, 100, 10, 10, 10), 11)$change == 0L))
x <- one(c(100, NA, NA, 100, NA, 10), c(11, 11, 11, 11, 11, 31))
check("a year with no clear look keeps the state", identical(x$water, c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE)))
check("no clear look in the first year: the NLCD sets the start", one(c(NA, NA, 10), 11)$water[1] && !one(c(NA, NA, 10), 31)$water[1])
check("the two lines can be set", one(c(0, 60, 60), c(31, 11, 11), hi = 60)$change[2] == W[["To Water"]])

# the annual NLCD must agree away from wetland (user 2026-11-26: "only changes if NLCD says so")
check("an alpine lake under ice reads as land in DSWE but stays water while the NLCD calls it water", all(one(c(90, 90, 10, 20, 90, 15, 90), 11)$change == 0L) && all(one(c(90, 90, 10, 20, 90, 15, 90), 11)$water))
check("barren ground that reads as water in DSWE stays land while the NLCD calls it barren", all(one(c(0, 80, 90, 0, 85), 31)$change == 0L) && !any(one(c(0, 80, 90, 0, 85), 31)$water))
x <- one(c(100, 100, 10, 10, 10, 90, 90), c(11, 11, 11, 31, 31, 31, 11))
check("when the two disagree the change waits for the year both say so", identical(x$change, c(0L, 0L, 0L, W[["Water to Barren"]], 0L, 0L, W[["To Water"]])))
check("away from wetland the NLCD sets the starting state", one(c(10, 10, 10), 11)$water[1] && !one(c(90, 90, 90), 31)$water[1])
check("a year with no NLCD class changes nothing", all(one(c(100, 100, 10, 10), c(11, 11, NA, NA))$change == 0L))
x <- one(c(0, 60, 65, 80, 50, 40, 20), 31, agree = FALSE)
check("with the agreement off DSWE alone decides, as before", identical(x$change, c(0L, 0L, 0L, W[["To Water"]], 0L, 0L, W[["Water to Barren"]])))
check("the wetland side does not need the NLCD to agree", one(c(10, 10, 60, 80, 90, 55, 70, 90, 90, 90), 95)$change[3] == W[["To Water"]])

# ---- the wetland side: a change must hold five years ----
check("marsh that floods three years and drains produces nothing", all(one(c(10, 60, 60, 60, 10, 10, 10, 10, 10, 10), 95)$change == 0L))
x <- one(c(10, 10, 60, 80, 90, 55, 70, 90, 90, 90), 95)
check("marsh on the water side five years running is lost, dated to the first year", identical(which(x$change != 0L), 3L) && x$change[3] == W[["To Water"]])
check("the water state is dated back to that year", identical(x$water, c(FALSE, FALSE, rep(TRUE, 8))))
check("the wetland side is any pixel the NLCD calls wetland in a year given", x$wetland_side && one(c(10, 10, 60, 80, 90, 55, 70, 90, 90, 90), c(71, 71, 71, 71, 90, 71, 71, 71, 71, 71))$wetland_side)
x <- one(c(10, 10, 10, 10, 10, 10, 10, 90, 90, 90), 95)
check("a change first seen in the last four years is not counted", all(x$change == 0L) && !any(x$water))
check("the last confirmed year is reported (year 6 of 10)", x$confirmed == 6L)
x <- one(c(10, 10, 60, NA, NA, 70, 80, NA, 90, 95, 95), 95)
check("years with no clear look do not break or lengthen the run", identical(which(x$change != 0L), 3L))
check("a shorter hold can be set", identical(which(one(c(10, 60, 60, 60, 10, 10, 10), 95, hold = 3L)$change != 0L), c(2L, 5L)))
x <- one(c(90, 90, 10, 10, 10, 10, 10, 10), c(11, 11, 95, 95, 95, 95, 95, 95))
check("water that stays land five years and reads as wetland is new wetland", identical(which(x$change != 0L), 3L) && x$change[3] == W[["Water to Wetland"]])
x <- one(c(90, 90, 10, 10, 10, 10, 10, 10), c(95, 11, 31, 31, 31, 31, 31, 31))
check("... and barren when the NLCD reads barren", x$change[3] == W[["Water to Barren"]])
check("... and wetland when the NLCD still reads water there", one(c(90, 90, 10, 10, 10, 10, 10, 10), c(95, 11, 11, 11, 11, 11, 11, 11))$change[3] == W[["Water to Wetland"]])
check("... and other land, on the wetland side only, when the NLCD reads neither", one(c(90, 90, 10, 10, 10, 10, 10, 10), c(95, 11, 71, 71, 71, 71, 71, 71))$change[3] == W[["Water to Other Land"]])
check("the same series away from wetland changes at once", identical(which(one(c(10, 60, 80, 80, 10, 10), c(31, 31, 11, 11, 31, 31))$change != 0L), c(3L, 5L)))

# ---- land both years: wetland and barren in the NLCD ----
x <- one(rep(0, 6), c(95, 95, 31, 31, 95, 95))
check("wetland to barren and back, each held two years", identical(x$change, c(0L, 0L, W[["Wetland to Barren"]], 0L, W[["Barren to Wetland"]], 0L)))
check("a one-year barren blip produces nothing", all(one(rep(0, 6), c(95, 95, 31, 95, 95, 95))$change == 0L))
check("a switch in the last year is not counted", all(one(rep(0, 5), c(95, 95, 95, 95, 31))$change == 0L))
x <- one(c(0, 0, 90, 90, 90, 90, 90, 90), c(95, 95, 31, 31, 31, 31, 31, 31))
check("a pixel that becomes water is not also a wetland to barren change", identical(which(x$change != 0L), 3L) && x$change[3] == W[["To Water"]])

# ---- several pixels at once, and bad input ----
o <- rbind(c(0, 60, 65, 80, 50, 40, 20, 20, 20, 20), c(10, 10, 60, 80, 90, 55, 70, 90, 90, 90), c(45, 55, 45, 55, 60, 40, 45, 55, 45, 55)); storage.mode(o) <- "integer"
l <- rbind(c(31L, 31L, 31L, 11L, 11L, 11L, 31L, 31L, 31L, 31L), rep(95L, 10), rep(71L, 10))
x <- water_change(o, l)
check("pixels are independent: a block gives the same answer as each pixel alone",
  identical(x$change[1, ], one(o[1, ], l[1, ])$change) && identical(x$change[2, ], one(o[2, ], 95)$change) && all(x$change[3, ] == 0L) && identical(x$wetland_side, c(FALSE, TRUE, FALSE)))
check("different shapes are refused", inherits(try(water_change(o, l[, 1:5]), silent = TRUE), "try-error"))
check("a single year is refused", inherits(try(water_change(o[, 1, drop = FALSE], l[, 1, drop = FALSE]), silent = TRUE), "try-error"))
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
