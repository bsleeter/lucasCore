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
check("an empty matrix gives an empty result", length(regrowth_age(nl[0, , drop = FALSE], yrs)) == 0)
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
