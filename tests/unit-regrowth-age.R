# Unit test: src/regrowth-age.R, the starting age of forest that NLCD shows regrowing (stage 5; to-do 57).
# Usage: Rscript tests/unit-regrowth-age.R   (from the package folder)
suppressPackageStartupMessages(library(data.table))
source(file.path("src", "regrowth-age.R"))
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
yrs <- 1985:2004; row <- function(...) { v <- c(...); stopifnot(length(v) == length(yrs)); v }
S <- 52L; G <- 71L; F <- 42L
nl <- rbind(
  clearcut  = row(rep(S, 8), rep(F, 12)),                  # forest from 1993, stays: 20 - 8 = 12 years old in 1985
  late      = row(rep(S, 19), F),                          # forest only in the last year: never two years running
  quick     = row(S, S, F, F, rep(F, 16)),                 # forest from 1987: 20 - 2 = 18
  flicker   = row(S, S, F, F, S, G, S, F, S, S, rep(S, 10)), # forest two years running, then mostly not: keeps its source age
  slow      = row(rep(G, 4), rep(F, 16)),                  # grass, forest from 1989: 16
  forest85  = row(F, F, rep(F, 18)),                       # forest at the start: not this rule's
  one_yr    = row(S, F, F, rep(F, 17)),                    # forest in the second year: the first two years must not be forest
  very_slow = row(rep(S, 15), rep(F, 5)))                  # forest from 2000, 15 years on: 20 - 15 = 5
a <- setNames(regrowth_age(nl, yrs), rownames(nl))
check("a clearcut forest from the ninth year starts at 20 - 8 = 12", identical(a[["clearcut"]], 12L))
check("forest only in the last year is not regrowth", is.na(a[["late"]]))
check("forest from the third year starts at 18", identical(a[["quick"]], 18L))
check("a cell that flickers keeps its source age", is.na(a[["flicker"]]))
check("grass that becomes forest counts too", identical(a[["slow"]], 16L))
check("forest at the start is left alone", is.na(a[["forest85"]]))
check("forest in the second year is left alone", is.na(a[["one_yr"]]))
check("forest 15 years on starts at 5; every age is 1 to the lag", identical(a[["very_slow"]], 5L) && all(a[!is.na(a)] >= 1 & a[!is.na(a)] <= 20))
v <- row(rep(S, 2), rep(F, 18)); b <- regrowth_age(rbind(v), yrs, lag = 10)
check("the age is the lag less the years to forest, and forest that first shows the lag or more after the start keeps its source age", identical(b, 8L) && is.na(regrowth_age(rbind(row(rep(S, 14), rep(F, 6))), yrs, lag = 10)) && identical(regrowth_age(rbind(row(rep(S, 9), rep(F, 11))), yrs, lag = 10), 1L))
s <- regrowth_settings(fread(file.path("defaults", "landcover", "regrowth-age.csv")))
check("defaults: lag 20, share about 2/3, two non-forest years", s$lag == 20 && abs(s$share - 2 / 3) < 0.01 && s$nonforest_years == 2L)
check("defaults: only fire-dated regrowing cells start disturbed (DisturbedStart Fire); a bad value stops", s$disturbed_start == "Fire" &&
      inherits(try(regrowth_settings(data.table(Parameter = c("RegrowthLag", "ForestShare", "NonForestYears", "DisturbedStart"), Value = c("20", "0.667", "2", "Some"))), silent = TRUE), "try-error"))
# disturbed_start: regrowth ages 12 (return 1993), 18 (1987), 5 (2000), 12; fires 1980, 1950, 1983, none; start 1985, window 30
ds <- disturbed_start(c(12L, 18L, 5L, 12L), c(1980L, 1950L, 1983L, NA), 1985L, 20, 30, "All")
check("a fire dates the disturbance when the return comes within the window after it (age = years since the fire), else the regrowth age",
      identical(ds$dated, c(TRUE, FALSE, TRUE, FALSE)) && identical(ds$age, c(5L, 18L, 2L, 12L)) && all(ds$use))
check("Fire starts only the dated cells disturbed, None none", identical(disturbed_start(c(12L, 18L, 5L, 12L), c(1980L, 1950L, 1983L, NA), 1985L, 20, 30, "Fire")$use, c(TRUE, FALSE, TRUE, FALSE)) &&
      !any(disturbed_start(c(12L, 18L), c(1980L, NA), 1985L, 20, 30, "None")$use))
check("a fire in the start year gives age 1, and a cell returns before its window ends at any dating", identical(disturbed_start(10L, 1985L, 1985L, 20, 30)$age, 1L) &&
      all(1985L + 20 - c(12L, 18L, 5L, 12L) - (1985L - ds$age) < 30))
check("an empty matrix gives an empty result", length(regrowth_age(nl[0, , drop = FALSE], yrs)) == 0)
# a per-cell cutoff (to-do 57 step 3: the fitted reforestation cutoff by ecodivision)
yl <- 1985:2015; rl <- function(k) c(rep(S, k), rep(F, length(yl) - k))   # first forest k years after the start
nl2 <- rbind(rl(8), rl(15), rl(22), rl(22))
check("the default cutoff is the lag: forest 22 years on is not regrowth", is.na(regrowth_age(nl2[3, , drop = FALSE], yl)))
a2 <- regrowth_age(nl2, yl, cutoff = c(11, 11, 24, 20))
check("a cutoff of 11: forest after 8 years regrows (age 12), after 15 does not", identical(a2[1], 12L) && is.na(a2[2]))
check("a cutoff of 24: forest after 22 years regrows at age 1 (the age stays lag-based); a cutoff of 20 leaves it alone", identical(a2[3], 1L) && is.na(a2[4]))
check("one cutoff for all rows works as before", identical(regrowth_age(nl2, yl, cutoff = 20), regrowth_age(nl2, yl)))
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
