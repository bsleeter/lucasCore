# =============================================================================
# unit-site-productivity.R - fast checks of src/siteproductivity.R (to-do 35 step 3), no SyncroSim run
# =============================================================================
#   1. a made-up type whose plots carry known class effects: the multipliers recover them (after normalising), the plot-weighted
#      mean is 1 in every cell, a cell with few plots takes the type's values, a class without plots lies between its neighbours,
#      the cap holds, a type without plots is 1
#   2. a plot goes to its own group's type before a pooled type
#   3. real data: the FIA fitting plots (as stage 2 filters them) on the latest P26 Build's carbon curves reproduce phase 0 for
#      California mixed conifer in M260 (about 1.59 at site class 2 and 0.52 at 6, before shrinkage)
# Usage: Rscript tests/unit-site-productivity.R
# =============================================================================
suppressPackageStartupMessages(library(data.table)); pkg <- "F:/lucasCore"; ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
source(file.path(pkg, "src", "siteproductivity.R"))

# 1. made-up plots: type 370, cells (370, 1) with many plots and (370, 2) with few; true effect by class; no plots in class 1 or 7
set.seed(4); truth <- c(NA, 1.6, 1.3, 1.0, 0.7, 0.5, NA)
mk <- function(n, s) { sc <- sample(2:6, n, TRUE, prob = c(.1, .25, .3, .25, .1)); data.table(StateClassId = 370L, StratumId = s, SiteClass = sc, r = truth[sc] * exp(rnorm(n, 0, 0.05))) }
p <- rbind(mk(3000, 1L), mk(10, 2L))
cells <- data.table(StateClassId = c(370L, 370L, 200L), StratumId = c(1L, 2L, 1L))
m <- site_multipliers(p, cells)
w <- p[StratumId == 1, .N, by = SiteClass]; tm <- sum(truth[w$SiteClass] * w$N) / sum(w$N)
m1 <- m[StateClassId == 370 & StratumId == 1][order(SiteClass)]
expect("recovers the class effects (truth / its plot-weighted mean)", max(abs(m1$Multiplier[2:6] - truth[2:6] / tm)) < 0.02,
       paste(round(m1$Multiplier, 2), collapse = " "))
wm <- merge(m, rbind(p[StratumId == 1, .N, by = .(StratumId, SiteClass)], p[, .N, by = SiteClass][, StratumId := 2L]), by = c("StratumId", "SiteClass"))[StateClassId == 370]
expect("plot-weighted mean 1 in each cell", wm[, abs(sum(N * Multiplier) / sum(N) - 1), by = StratumId][, max(V1)] < 1e-9)
expect("a cell with 10 plots takes the type's values", m[StateClassId == 370 & StratumId == 2, all(startsWith(Basis, "forest type, all ecodivisions"))])
expect("classes without plots follow the trend (1 above 2, 7 below 6)", m1[SiteClass == 1, Multiplier] > m1[SiteClass == 2, Multiplier] && m1[SiteClass == 7, Multiplier] < m1[SiteClass == 6, Multiplier], paste(round(m1$Multiplier, 2), collapse = " "))
expect("a type without plots is 1", m[StateClassId == 200, all(Multiplier == 1)])
mc <- site_multipliers(data.table(StateClassId = 1L, StratumId = 1L, SiteClass = rep(c(2L, 6L), c(500, 500)), r = rep(c(5, 0.1), c(500, 500))), data.table(StateClassId = 1L, StratumId = 1L))
expect("the cap holds (0.3-2.5)", all(mc$Multiplier >= 0.3 & mc$Multiplier <= 2.5), paste(round(mc[SiteClass %in% c(2, 6), Multiplier], 2), collapse = " / "))

# 2. own group first
cw <- data.table(StateClassId = c(240L, 370L), FiaTypeGroups = c("200;220;370", "370"))
expect("group 370 goes to its own type, 220 to the pooled one", identical(site_type_of(cw)[order(g), id], c(240L, 240L, 370L)))

# 3. real data on the P26 Build's curves
lib <- file.path(pkg, "dev/libs/LUCAS P26 Northern Sierra Nevada.ssim"); dm <- "F:/lucas-master/Data Sources/FIA/DataMart"
if (file.exists(lib) && file.exists(file.path(dm, "fia-conditions.rds"))) {
  source(file.path(pkg, "src", "carbon.R")); source(file.path(pkg, "src", "treemap.R"))
  con <- DBI::dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO)
  bid <- DBI::dbGetQuery(con, "SELECT MAX(ScenarioId) id FROM lucasCore_CarbonCurve")$id
  cc <- as.data.table(DBI::dbGetQuery(con, sprintf("SELECT StratumId, StateClassId, Age, TotalLive FROM lucasCore_CarbonCurve WHERE ScenarioId = %d", bid)))
  st <- as.data.table(DBI::dbGetQuery(con, "SELECT StratumId, Id FROM stsim_Stratum")); sc <- as.data.table(DBI::dbGetQuery(con, "SELECT StateClassId, Id FROM stsim_StateClass"))
  DBI::dbDisconnect(con)
  cc[, `:=`(StratumId = as.integer(st$Id[match(StratumId, st$StratumId)]), StateClassId = as.integer(sc$Id[match(StateClassId, sc$StateClassId)]))]   # library keys -> stsim ids
  eco <- data.table(ecodiv = ifelse(unique(cc$StratumId) >= 1000, paste0("M", unique(cc$StratumId) %/% 10), as.character(unique(cc$StratumId))), StratumId = unique(cc$StratumId))
  x <- readRDS(file.path(dm, "fia-conditions.rds")); xc <- carbon_data(x$cond, x$dist, list(MinInventoryYear = 1997, VolumeCapQuantile = 0.999))
  cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv"))
  pp <- site_plots(xc, fia_sites(dm), cw, cc, eco)
  mm <- site_multipliers(pp, unique(cc[, .(StateClassId, StratumId)]))
  mc <- mm[StateClassId == 370 & StratumId == 2601][order(SiteClass)]; print(mc)
  expect("real data: mixed conifer M260 near phase 0 (1.59 at class 2, 0.52 at 6)", abs(mc[SiteClass == 2, Multiplier] - 1.59) < 0.15 && abs(mc[SiteClass == 6, Multiplier] - 0.52) < 0.1,
         sprintf("%.2f / %.2f, basis %s", mc[SiteClass == 2, Multiplier], mc[SiteClass == 6, Multiplier], mc$Basis[1]))
  expect("real data: mixed conifer M260 falls from class 1 to 7 (rises of up to 0.05 allowed: class 1 has 9 plots)", all(diff(mc$Multiplier) < 0.05), paste(round(mc$Multiplier, 2), collapse = " "))
  expect("real data: every cell has 7 classes, finite and within the cap", mm[, .N, by = .(StateClassId, StratumId)][, all(N == 7)] && all(is.finite(mm$Multiplier) & mm$Multiplier >= 0.3 & mm$Multiplier <= 2.5))
  cat(sprintf("%d plots; %d cells, %d with their own values\n", nrow(pp), mm[, uniqueN(paste(StateClassId, StratumId))], mm[Basis == "forest type x ecodivision", uniqueN(paste(StateClassId, StratumId))]))
} else cat("SKIP  real-data check\n")
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
