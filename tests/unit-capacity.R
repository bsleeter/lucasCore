# =============================================================================
# unit-capacity.R - the carbon carrying capacity (src/capacity.R; stage 8, and the run side of stages 13 and 14)
# =============================================================================
# Plain R, made-up curves and cells, no SyncroSim. Checks the regime weights (sum to 1, mean age), the natural-regime mean against
# hand values and its limits (a very long return interval gives the last age's stock, a return interval of 1 the age-0 stock), the
# table by type, the BpS cover lookup, the cell rules of the hybrid choice, and the run side (series, deficit by cause).
# Usage: Rscript tests/unit-capacity.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "capacity.R"))
ok <- 0; bad <- 0
expect <- function(what, cond) { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, "\n") } }
near <- function(a, b, tol = 1e-9) all(abs(a - b) < tol)

# ---- regime weights -------------------------------------------------------------------------------------------------------
w <- regime_weights(100, 300)
expect("weights: one per age 0..300, summing to 1", length(w) == 301 && near(sum(w), 1))
expect("weights: age 0 holds 1 / RI of the landscape", near(w[1], 0.01))
expect("weights: the last age holds every older stand", near(w[301], 0.99^300))
expect("weights: with a long curve the mean age is RI - 1", near(sum(regime_weights(50, 5000) * 0:5000), 49, 1e-6))
expect("weights: a return interval of 1 puts the whole landscape at age 0", near(regime_weights(1, 10), c(1, rep(0, 10))))
expect("weights: a return interval below 1 is read as 1", near(regime_weights(0.2, 3), c(1, 0, 0, 0)))

# ---- the natural-regime mean ------------------------------------------------------------------------------------------------
# two ages, RI 2: half the landscape at age 0, half at age 1 or older (counted at age 1)
expect("regime mean: two ages at RI 2 is the plain mean", near(regime_mean(c(10, 30), 0:1, 2), 20))
# a straight line to age 300: the mean is the stock at the mean age
lin <- 0:300 * 1.0
expect("regime mean: of a straight line, the stock at the mean age", near(regime_mean(lin, 0:300, 100), sum(regime_weights(100, 300) * 0:300)))
expect("regime mean: a very long return interval gives the last age's stock", abs(regime_mean(lin, 0:300, 1e9) - 300) < 1e-3)
expect("regime mean: a return interval of 1 gives the age-0 stock", near(regime_mean(lin + 5, 0:300, 1), 5))
expect("regime mean: a shorter return interval holds less of a rising curve", regime_mean(lin, 0:300, 50) < regime_mean(lin, 0:300, 200))
# age bins (0, 10, 40): ages 0-9 take the first row, 10-39 the second, 40 the third
wb <- regime_weights(20, 40)
expect("regime mean: age bins take the row at or below each age", near(regime_mean(c(1, 2, 3), c(0, 10, 40), 20), sum(wb[1:10]) * 1 + sum(wb[11:40]) * 2 + wb[41] * 3))
expect("regime mean: rows in any order", near(regime_mean(c(3, 1, 2), c(40, 0, 10), 20), regime_mean(c(1, 2, 3), c(0, 10, 40), 20)))
expect("regime mean: one value per pool column", near(regime_mean(cbind(lin, 2 * lin), 0:300, 100), regime_mean(lin, 0:300, 100) * 1:2))
expect("regime mean: ages that do not start at 0 are an error", inherits(try(regime_mean(1:3, 1:3, 10), silent = TRUE), "try-error"))

# ---- the table by type ------------------------------------------------------------------------------------------------------
ages <- 0:300; live <- 150 * (1 - exp(-0.02 * ages)); dead <- 40 * exp(-0.03 * ages) + 10; lit <- rep(8, 301)
cv <- rbind(data.table(StratumId = "Marine", StateClassId = "Forest: A Group", TransitionGroupId = CAPACITY_FIRE, Age = ages, Merchantable = live * .6, Other = live * .4, SnagStem = dead, AGVF = lit, BGS = 90),
            data.table(StratumId = "Marine", StateClassId = "Forest: A Group", TransitionGroupId = "Forest Harvest: Forest Clearcut [Type]", Age = ages, Merchantable = 0, Other = 0, SnagStem = 0, AGVF = 0, BGS = 90),
            data.table(StratumId = "Marine", StateClassId = "Forest: B Group", TransitionGroupId = CAPACITY_FIRE, Age = ages, Merchantable = live * .3, Other = live * .2, SnagStem = dead, AGVF = lit, BGS = 90))
cols <- list(Live = c("Merchantable", "Other"), DeadWood = "SnagStem", Litter = "AGVF")
ri <- data.table(StratumId = "Marine", StateClassId = c("Forest: A Group", "Forest: B Group"), ReturnInterval = c(100, 400))
ct <- capacity_by_type(cv, ri, cols)
expect("by type: one row per ecodivision x class with a return interval", nrow(ct) == 2)
a <- ct[StateClassId == "Forest: A Group"]; wa <- regime_weights(100, 300)
expect("by type: live, dead wood and litter are each the regime mean of their columns (the fire curve)", near(a$Live, sum(wa * live)) && near(a$DeadWood, sum(wa * dead)) && near(a$Litter, 8))
expect("by type: the capacity is their sum, soil left out", near(a$Capacity, a$Live + a$DeadWood + a$Litter))
expect("by type: the upper bound is the last age's stock", near(a$UpperBound, live[301] + dead[301] + 8))
expect("by type: the capacity is below the old-growth upper bound for a rising curve", a$Capacity < a$UpperBound)
expect("by type: a class without a return interval has no row", nrow(capacity_by_type(cv, ri[1], cols)) == 1)
expect("by type: a missing pool group is an error", inherits(try(capacity_by_type(cv, ri, cols[1:2]), silent = TRUE), "try-error"))

# ---- BpS cover ----------------------------------------------------------------------------------------------------------------
lk <- data.table(VALUE = 1:6, GROUPVEG = c("Conifer", "Riparian", "Grassland", "Shrubland", "Sparse", "Open Water"), Potential = c("forest", "riparian or savanna", "non-forest", "non-forest", "non-forest", "other"))
grp <- fread(file.path(pkg, "defaults", "landcover", "bps-groups.csv"), na.strings = "")
expect("bps cover: forest, riparian as forest, grass, shrub, bare, none", identical(bps_capacity_cover(lk, grp), c("forest", "forest", "grass", "shrub", "bare", "none")))
expect("bps cover: riparian read as non-forest is shrub", bps_capacity_cover(lk, grp, "non-forest")[2] == "shrub")
real <- fread(file.path(pkg, "defaults", "landcover", "LF20_BPS_220.csv"), na.strings = "")
expect("bps-groups.csv: every GROUPVEG of the BpS table has a row", all(unique(real$GROUPVEG[!is.na(real$GROUPVEG)]) %in% grp$GROUPVEG))
expect("bps-groups.csv: every non-forest and riparian or savanna group has a cover", all(!is.na(grp[Potential %in% c("non-forest", "riparian or savanna"), NonForestCover])))

# ---- the cell rules -------------------------------------------------------------------------------------------------------------
cls <- c("Forest: A Group", "Disturbed: A Group", "Developed: Low Intensity", "Agriculture: Cropland", "Grassland: Annual", "Shrubland: Sage", "Wetland: Palustrine Emergent", "Water: All", "Developed: Open Space", "Barren: All")
start <- c(120, 20, 5, 3, 4, 6, 9, 0, 7, 0)
own <- c(100, 100, NA, NA, NA, 12, NA, NA, NA, NA)
x <- capacity_cells(cls, start, own, upper_own = own * 1.5, forest = rep(100, 10), upper_forest = rep(150, 10), grass = rep(4, 10), shrub = rep(12, 10),
                    f_forest = c(1, 1, .5, 0, .25, 0, 0, 0, 0, 1), f_grass = c(0, 0, .5, .5, .75, 0, 0, 0, 0, 0), f_shrub = c(0, 0, 0, 0, 0, 1, 0, 0, 0, 0), f_bare = c(0, 0, 0, .5, 0, 0, 0, 0, 0, 0), natural = "bps")
expect("cells: forest keeps its own type's capacity (below its start stock: above its capacity)", x$capacity[1] == 100 && x$forest_share[1] == 1)
expect("cells: disturbed forest counts at its forest type's capacity", x$capacity[2] == 100 && x$forest_share[2] == 1)
expect("cells: developed land takes the BpS mix (half forest, half grass)", near(x$capacity[3], 52) && near(x$forest_share[3], .5))
expect("cells: farmed land on grass and bare BpS (half each)", near(x$capacity[4], 2) && x$forest_share[4] == 0)
expect("cells (natural = bps): grassland takes forest on its BpS forest share and its start stock on the rest", near(x$capacity[5], .25 * 100 + .75 * 4))
expect("cells: a shrub class with a mature stock takes it", x$capacity[6] == 12 && x$basis[6] == "own class")
expect("cells: emergent wetland and water keep their start stock", x$capacity[7] == 9 && x$capacity[8] == 0)
expect("cells: developed land with no mapped BpS keeps its start stock", x$capacity[9] == 7 && x$basis[9] == "start stock")
expect("cells (natural = bps): barren land on forest BpS counts as forest", x$capacity[10] == 100 && x$forest_share[10] == 1)
expect("cells: the upper bound uses the old-growth values", x$upper[1] == 150 && near(x$upper[3], .5 * 150 + .5 * 4))
# the default: natural grassland, shrubland and barren land keeps its own class whatever BpS says (the annual NLCD over BpS)
xo <- capacity_cells(cls, start, own, upper_own = own * 1.5, forest = rep(100, 10), upper_forest = rep(150, 10), grass = rep(4, 10), shrub = rep(12, 10),
                     f_forest = c(1, 1, .5, 0, .25, 0, 0, 0, 0, 1), f_grass = c(0, 0, .5, .5, .75, 0, 0, 0, 0, 0), f_shrub = c(0, 0, 0, 0, 0, 1, 0, 0, 0, 0), f_bare = c(0, 0, 0, .5, 0, 0, 0, 0, 0, 0))
expect("cells (default): grassland and barren land on forest BpS keep their own class, no forest share", xo$capacity[5] == 4 && xo$capacity[10] == 0 && all(xo$forest_share[c(5, 10)] == 0) && all(xo$basis[c(5, 10)] == "own class"))
expect("cells (default): every other cell as with natural = bps", all(xo$capacity[-c(5, 10)] == x$capacity[-c(5, 10)]) && near(xo$capacity[3], 52))
expect("cells: an unknown natural setting is an error", inherits(try(capacity_cells(cls, start, own, own, 100, 150, 4, 12, 0, 0, 0, 0, natural = "nlcd"), silent = TRUE), "try-error"))
expect("options: blank, 1 and the label are own; 2 and its label bps; anything else an error", capacity_natural(data.table()) == "own" && capacity_natural(data.table(NaturalNonForest = NA)) == "own" && capacity_natural(data.table(NaturalNonForest = 1L)) == "own" &&
       capacity_natural(data.table(NaturalNonForest = "Its own class (annual NLCD)")) == "own" && capacity_natural(data.table(NaturalNonForest = 2L)) == "bps" && capacity_natural(data.table(NaturalNonForest = "LANDFIRE BpS potential")) == "bps" &&
       inherits(try(capacity_natural(data.table(NaturalNonForest = 3L)), silent = TRUE), "try-error"))
pk <- xml2::read_xml(file.path(pkg, "package.xml")); f1 <- xml2::xml_attr(xml2::xml_find_first(pk, "//dataSheet[@name='CarbonCapacityOptions']/column[@name='NaturalNonForest']"), "formula1")
expect("package.xml: the option's list labels are the ones the code reads", identical(f1, paste0("1:", CAPACITY_NATURAL[["own"]], "|2:", CAPACITY_NATURAL[["bps"]])))
nb <- capacity_cells(cls, start, own, own, rep(100, 10), rep(150, 10), rep(4, 10), rep(12, 10), NA, NA, NA, NA)
expect("cells: without BpS, developed and farmed land keep their start stock and natural land its own class", all(nb$capacity[c(3, 4, 5, 9)] == start[c(3, 4, 5, 9)]) && nb$capacity[6] == 12 && nb$capacity[1] == 100)
nf <- capacity_cells(cls, start, own, own, rep(NA_real_, 10), rep(NA_real_, 10), rep(4, 10), rep(12, 10), c(1, 1, .5, 0, .25, 0, 0, 0, 0, 1), c(0, 0, .5, .5, .75, 0, 0, 0, 0, 0), 0, 0, natural = "bps")
expect("cells: an unknown forest capacity counts at the start stock (no deficit there)", near(nf$capacity[3], .5 * 5 + .5 * 4) && nf$forest_share[3] == 0 && nf$capacity[10] == 0)
expect("cells: a disturbed shrub class is not counted as forest", capacity_cells("Disturbed: Sage", 2, 12, 12, 100, 150, 4, 12, 0, 0, 1, 0, own_is_forest = is_forest_like("Disturbed: Sage"))$forest_share == 0)
expect("is_forest_like: forest, forested wetland and disturbed forest, not shrub or its disturbed class", identical(is_forest_like(c("Forest: A Group", "Wetland: Spruce/Fir Group", "Disturbed: A Group", "Disturbed: Chaparral", "Shrubland: Sage", NA)), c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE)))

# ---- the run side ---------------------------------------------------------------------------------------------------------------
stocks <- rbind(data.table(Timestep = rep(2000:2002, each = 3), StockGroup = rep(CAPACITY_GROUPS, 3), Mg = c(60, 20, 10, 62, 20, 10, 50, 25, 9) * 1e6),
                data.table(Timestep = 2000:2002, StockGroup = "DOM: Soil", Mg = 500e6))
s <- capacity_series(stocks, 120, 180)
expect("series: the stock is the three pools, soil left out", near(s$Stock, c(90, 92, 84)))
expect("series: share and deficit", near(s$RealisedShare, 100 * c(90, 92, 84) / 120) && near(s$Deficit, 120 - c(90, 92, 84)) && all(s$UpperBound == 180))
expect("series: NULL without the capacity or with a pool missing", is.null(capacity_series(stocks, NA)) && is.null(capacity_series(stocks[StockGroup != "DOM: Litter"], 120)))
# cells: developed; grass on forest potential; grass on its own; forest below; forest above; disturbed forest; no class
sp <- capacity_split(cls = c("Developed: Low Intensity", "Grassland: Annual", "Grassland: Annual", "Forest: A Group", "Forest: A Group", "Disturbed: A Group", NA),
                     stock = c(5, 4, 4, 60, 130, 30, 1), capacity = c(52, 80, 5, 100, 100, 100, 1), forest_share = c(.5, .9, .1, 1, 1, 1, 0), ha = 1e6,
                     stock_live = c(1, 3, 3, 50, 90, 2, 0), capacity_live = c(40, 60, 3.5, 70, 70, 70, 0))
expect("split: the five causes, in order", identical(names(sp), CAPACITY_CAUSES) && length(CAPACITY_CAUSE_COLS) == length(CAPACITY_CAUSES))
expect("split: land use, non-forest cover and disturbed land take the whole deficit of their cells", near(sp[1:3], c(47, 76, 70)))
expect("split: the other cells' live biomass against the capacity's live part, net of cells above it", near(sp[["Live biomass"]], 0.5 + 20 - 20))
expect("split: their dead wood and litter is the rest", near(sp[["Dead wood and litter"]], (1 - 0.5) + (40 - 20) + (-30 + 20)))
expect("split: the causes add up to the deficit of the cells with every value", near(sum(sp), sum(c(52, 80, 5, 100, 100, 100) - c(5, 4, 4, 60, 130, 30))))

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
