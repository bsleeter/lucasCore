# Fast test of Land Use Demand (src/land-use-demand.R; no SyncroSim): the ratios computed from an RPA-shaped table made here, the
# Data Source's rows, and - when the published table is in the Data Sources folder (LUCAS_DATA_HOME, land-use/rpa-2020) - its ratios.
# Run: Rscript tests/unit-land-use-demand.R (from the package root)
suppressPackageStartupMessages(library(data.table))
source("src/land-use-demand.R")
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
cw <- fread("defaults/strata/msa-crosswalk.csv", colClasses = "character")

# ---- an RPA-shaped table: 2 climate models x 2 pairs, 6 steps, 5 counties -----------------------------------------------------
# Placer 06061 and Sacramento 06067 (both Sacramento metropolitan area 40900), Alpine 06003 (rest of California), Travis 48453
# (Austin 12420), Napa 06055 (Napa 34900, made tiny). Urbanization a year in 2012-2020: Placer 10, Sacramento 30, Alpine 5, Travis 20
USE <- c("cr", "ps", "rg", "fr", "ur")
mat <- function(km2_per_year, years) { m <- matrix(0, 6, 6, dimnames = list(c(USE, "t2"), c(USE, "t1"))); m["fr", "ur"] <- km2_per_year * years / DEMAND_KM2 * 0.75; m["cr", "ur"] <- km2_per_year * years / DEMAND_KM2 * 0.25
  m["ur", "ur"] <- 999; m }   # (urban staying urban is not urbanization)
base <- c(`06061` = 10, `06067` = 30, `06003` = 5, `48453` = 20, `06055` = 0.2)
grow <- list(rcp85_ssp5 = c(`06061` = 2, `06067` = 1, `06003` = 1.5, `48453` = 4, `06055` = 9), rcp85_ssp3 = c(`06061` = 1, `06067` = 1, `06003` = 0.8, `48453` = 1, `06055` = 1))
steps <- c(DEMAND_CAL, DEMAND_STEPS)
fut <- function(pair, shift) setNames(lapply(seq_along(steps), function(i) { yrs <- if (i == 1) 8 else 10
  lapply(setNames(names(base), names(base)), function(k) mat((base[[k]] + shift) * (if (i == 1) 1 else 1 + (grow[[pair]][[k]] - 1) * (i - 1) / 5), yrs)) }), steps)
# two climate models whose areas differ by +/- 1 km2 a year: their mean is the base
x <- list(A_rcp85_ssp5 = fut("rcp85_ssp5", 1), B_rcp85_ssp5 = fut("rcp85_ssp5", -1), A_rcp85_ssp3 = fut("rcp85_ssp3", 0))
a <- demand_rpa_areas(x, "rcp85_ssp5")
check("areas: km2 a year by county and step, crop and forest to urban summed, urban to urban left out", isTRUE(all.equal(a[Fips == "06061" & Step == DEMAND_CAL, PerYear], 10)) && isTRUE(all.equal(a[Fips == "48453" & Step == DEMAND_CAL, PerYear], 20)))
check("areas: the mean of the pair's climate models, other pairs left out", attr(a, "models") == 2 && nrow(a) == 5 * 6)
check("areas: 2012-2020 is 8 years, the decades 10", isTRUE(all.equal(a[Fips == "06003" & Step == "2060-2070", PerYear], 5 * 1.5)))
check("a pair the table lacks stops", inherits(tryCatch(demand_rpa_areas(x, "rcp45_ssp1"), error = function(e) e), "error"))
check("a table that is not the published layout stops", inherits(tryCatch(demand_rpa_areas(list(A_rcp85_ssp5 = setNames(rep(list(list(`06061` = matrix(1, 2, 2))), 6), steps)), "rcp85_ssp5"), error = function(e) e), "error"))

# ---- counties to pooled units ----
check("Placer (06061) is in the Sacramento metropolitan area (40900); Alpine (06003) is in the rest of California", identical(demand_unit(c(6061L, 6003L, NA), cw, "Metro"), c("40900", "rest-06", NA)))
check("state pooling: the state FIPS, two digits", identical(demand_unit(c(6061L, 48453L), cw, "State"), c("06", "48")))

# ---- pooled ratios ----
R <- demand_ratios(a, cw, "Metro", cap = 3)
# Sacramento metro 2060-2070: (10 x 2 + 30 x 1) / 40 = 1.25
check("metropolitan pooling: the ratio of pooled areas, not the mean of county ratios", isTRUE(all.equal(unname(R["40900", 5]), 1.25)))
check("counties outside a metropolitan area are pooled by state", isTRUE(all.equal(unname(R["rest-06", 5]), 1.5)))
check("the cap holds (Austin 4 -> 3)", R["12420", 5] == 3 && demand_ratios(a, cw, "Metro", cap = 99)["12420", 5] == 4)
Rs <- demand_ratios(a, cw, "State", cap = 99)
ca <- (10 * 2 + 30 * 1 + 5 * 1.5 + 0.2 * 9) / 45.2
check("state pooling: California's ratio over all its counties", isTRUE(all.equal(unname(Rs["06", 5]), ca)) && identical(rownames(Rs), c("06", "48")))
check("a metropolitan unit under 1 km2 a year in 2012-2020 takes its state's ratio and is named (Napa, own ratio 9)", isTRUE(all.equal(unname(R["34900", 5]), ca)) && identical(attr(R, "fallback"), "34900"))
check("with no minimum it keeps its own", isTRUE(all.equal(unname(demand_ratios(a, cw, "Metro", cap = 99, min_cal = 0)["34900", 5]), 9)))
z <- copy(a); z[Fips == "06003" & Step == DEMAND_CAL, PerYear := 0]
check("a unit with no urbanization in 2012-2020 is 1", all(demand_ratios(z, cw, "Metro", min_cal = 0)["rest-06", ] == 1))
check("the calibration areas come with the ratios", isTRUE(all.equal(unname(attr(R, "calibration")["40900"]), 40)))
check("the low-growth pair stays at or below 1", max(demand_ratios(demand_rpa_areas(x, "rcp85_ssp3"), cw, "State")) <= 1 + 1e-9)

# ---- by year ----
y <- demand_by_year(c(1.1, 1.2, 1.3, 1.4, 1.5), c(2010, 2016, 2025, 2030, 2065, 2070, 2100))
check("by year: 1 up to 2016, the decade's ratio at its midpoint, halfway between midpoints, the last value kept after 2065", isTRUE(all.equal(y, c(1, 1, 1.1, 1.15, 1.5, 1.5, 1.5))))
check("2024 lies between 2016 (1) and 2025", { v <- demand_by_year(c(1.9, 2, 2, 2, 2), 2024); v > 1.7 && v < 1.9 })

# ---- target units of any strata ----
rr <- matrix(c(1, 1, 2, 2), nrow = 2, byrow = TRUE, dimnames = list(c("A", "B"), c(2025, 2065)))
M <- demand_unit_ratio(unit_of_cell = c(1L, 1L, 2L, 2L, 2L, NA), pooled_of_cell = c("A", "A", "A", "B", "B", "B"), weight = c(1, 1, 3, 1, 0, 9), ratios = rr)
check("a target unit inside one pooled unit (a county) takes its ratio", all(M["1", ] == 1) && attr(M, "span")[1] == 1)
check("a target unit over two pooled units (a state): the mean weighted by historical area (3 x 1 + 1 x 2) / 4, and its span is reported", isTRUE(all.equal(unname(M["2", ]), c(1.25, 1.25))) && attr(M, "span")[2] == 2)
check("cells outside the study area are left out", identical(rownames(M), c("1", "2")))
M0 <- demand_unit_ratio(c(1L, 1L, 1L), c("A", "B", "B"), c(0, 0, 0), rr[, 2, drop = FALSE])
check("a target unit with no historical area: the plain mean of its cells", isTRUE(all.equal(unname(M0[1, 1]), 5 / 3)))
M1 <- demand_unit_ratio(c(1L, 1L, 1L), c("A", "Z", NA), c(1, 2, 1), rr[, 2, drop = FALSE])
check("a pooled unit without a ratio (outside RPA) counts as 1, is named, and the covered share is reported", isTRUE(all.equal(unname(M1[1, 1]), 1)) && identical(attr(M1, "missing"), "Z") && isTRUE(all.equal(attr(M1, "covered"), 0.25)))
# a target unit smaller than a county (two units inside one county) gets the county's ratio in both
M2 <- demand_unit_ratio(c(1L, 2L), c("B", "B"), c(1, 5), rr[, 2, drop = FALSE])
check("target units smaller than a county each take its ratio", all(M2[, 1] == 2))

# ---- options ----
o <- demand_options(data.table())
check("an empty sheet: the drawn years as they are", o$method == "Historical" && !o$rpa && o$cap == 3 && o$land == 1 && o$weight == DEMAND_L)
o <- demand_options(data.table(UrbanMethod = "RPA 2020 Assessment ratio", UrbanScenario = "RCP8.5-SSP5 (high emissions, high growth)", UrbanPooling = "State", UrbanMaxRatio = 2))
check("the sheet's choices are read", o$rpa && o$pair == "rcp85_ssp5" && o$pooling == "State" && o$cap == 2)
check("every scenario of the list maps to its pair", identical(vapply(c("RCP4.5-SSP1 (x)", "RCP8.5-SSP2 (x)", "RCP8.5-SSP3 (x)", "RCP8.5-SSP5 (x)"), function(s) demand_options(data.table(UrbanMethod = "RPA 2020 Assessment ratio", UrbanScenario = s))$pair, "", USE.NAMES = FALSE), DEMAND_PAIRS))
check("an unknown scenario gives no pair", is.na(demand_options(data.table(UrbanMethod = "RPA", UrbanScenario = "SSP9"))$pair))

o <- demand_options(data.table(UrbanMethod = "Population (SSP) x land per new resident", UrbanSsp = "SSP5", LandPerNewResident = 0.5))
check("Population: SSP, land factor, the default weight and county pooling", o$method == "Population" && o$ssp == "SSP5" && o$land == 0.5 && o$weight == DEMAND_L && o$pooling == "County")
check("the other methods are read; RPA pools by metropolitan area unless told", demand_options(data.table(UrbanMethod = "Historical high years (each unit's highest third)"))$method == "High" &&
  demand_options(data.table(UrbanMethod = "Historical low years (each unit's lowest third)"))$method == "Low" && demand_options(data.table(UrbanMethod = "Custom ratio table"))$method == "Custom" &&
  demand_options(data.table(UrbanMethod = "RPA 2020 Assessment ratio"))$pooling == "Metro")

o <- demand_options(data.table(UrbanMethod = "Historical years as drawn", AgExpansionMethod = "Historical high years (each unit's highest third)", AgContractionMethod = "Custom ratio table"))
check("agriculture has its own settings, apart from urbanization's; blank = as drawn", o$method == "Historical" && o$ag[["Ag Expansion"]] == "High" && o$ag[["Ag Contraction"]] == "Custom" &&
  all(unlist(demand_options(data.table())$ag) == "Historical") && demand_options(data.table(AgExpansionMethod = "Historical low years (each unit's lowest third)"))$ag[["Ag Expansion"]] == "Low")
x9a <- paste(readLines("package.xml", warn = FALSE), collapse = "\n"); s9 <- paste(readLines("src/9-projection-transitions.R", warn = FALSE), collapse = "\n")
check("package.xml has the agriculture settings and the table's Applies To; every agriculture choice is one the stage knows", grepl('<column name="AgExpansionMethod"', x9a, fixed = TRUE) && grepl('<column name="AgContractionMethod"', x9a, fixed = TRUE) &&
  grepl('<column name="AppliesTo"[^>]*formula1="1:Urbanization\\|2:Ag Expansion\\|3:Ag Contraction\\|4:Forest Harvest\\|5:Cropland to Pasture\\|6:Pasture to Cropland"', x9a) && grepl('<column name="HarvestMethod"', x9a, fixed = TRUE) &&
  { it <- strsplit(sub('.*name="AgExpansionMethod"[^>]*formula1="([^"]*)".*', "\\1", x9a), "|", fixed = TRUE)[[1]]
    setequal(vapply(sub("^[0-9]+:", "", it), function(s) demand_options(data.table(AgExpansionMethod = s))$ag[[1]], ""), c("Historical", "High", "Low", "Custom")) })
o <- demand_options(data.table(AgChangeMethod = "Historical high years (each unit's highest third)", AgChangeBalance = 2))
check("cropland and pasture exchange has a method and a balance; blank = as drawn and 1; a balance of 0 or less is 1", o$change$method == "High" && o$change$balance == 2 &&
  demand_options(data.table())$change$method == "Historical" && demand_options(data.table())$change$balance == 1 && demand_options(data.table(AgChangeBalance = 0))$change$balance == 1 &&
  demand_options(data.table(AgChangeMethod = "Custom ratio table"))$change$method == "Custom" && grepl('<column name="AgChangeMethod"', x9a, fixed = TRUE) && grepl('<column name="AgChangeBalance"', x9a, fixed = TRUE) &&
  grepl("factor = if (j == 2) b else 1 / b", s9, fixed = TRUE) && grepl("pmin(RU * sp$factor, sp$cap)", s9, fixed = TRUE))
check("stage 9 gives each kind of group its own specification, and the custom table is read per kind", grepl('for (k in c("Ag Expansion", "Ag Contraction", "Forest Harvest"))', s9, fixed = TRUE) && grepl('dm_custom("Urbanization")', s9, fixed = TRUE) &&
  grepl("sp <- dm_kind(g)", s9, fixed = TRUE) && !grepl("dm_on", s9, fixed = TRUE))

# ---- ratios at anchor years to ratios by year ----
Y <- demand_years(matrix(c(2, 3), nrow = 1, dimnames = list("A", NULL)), mid = c(2015, 2025, 2035), years = c(2010L, 2015L, 2020L, 2025L, 2030L, 2040L))
check("anchors: 1 at the base midpoint and before, linear between, the last value kept", isTRUE(all.equal(unname(Y[1, ]), c(1, 1, 1.5, 2, 2.5, 3))) && identical(colnames(Y), c("2010", "2015", "2020", "2025", "2030", "2040")))

# ---- Historical high and low years ----
A <- matrix(c(1, 2, 3, 4, 5, 6,   0, 0, 0, 0, 0, 0,   5, 5, 5, 5, 5, 5), nrow = 3, byrow = TRUE, dimnames = list(c("11", "12", "13"), 2001:2006))
hi <- demand_history_ratio(A, "High"); lo <- demand_history_ratio(A, "Low")
check("high years: the mean of a unit's highest third over its mean (5.5 / 3.5); low years the lowest (1.5 / 3.5)", isTRUE(all.equal(unname(hi[1]), 5.5 / 3.5)) && isTRUE(all.equal(unname(lo[1]), 1.5 / 3.5)))
check("a unit with no history is 1, and one with the same area every year is 1", hi[2] == 1 && lo[2] == 1 && hi[3] == 1 && lo[3] == 1)
check("the cap holds for the history ratio", demand_history_ratio(matrix(c(0, 0, 0, 0, 0, 12), nrow = 1), "High", cap = 3) == 3)

# ---- Population: how many people x how much land each new one takes ----
# three counties: Placer 06061 grows fast, Sacramento 06067 slowly, Alpine 06003 shrinks; Hauer's 2020 is off from the Census 2020 on
# purpose (only its change from 2020 counts). 2010-2020: Placer 350 -> 400 thousand, Sacramento 1,400 -> 1,500, Alpine 1.2 -> 1.1
census <- data.table(SUMLEV = c(40L, 50L, 50L, 50L), STATE = c(6L, 6L, 6L, 6L), COUNTY = c(0L, 61L, 67L, 3L), POPESTIMATE2010 = c(9e6, 350e3, 1400e3, 1200), POPESTIMATE2020 = c(1e7, 400e3, 1500e3, 1100))
hauer <- rbind(data.table(GEOID = 6061L, YEAR = c(2020L, 2025L, 2030L), SSP2 = c(380e3, 418e3, 456e3), SSP3 = c(380e3, 380e3, 361e3)),
               data.table(GEOID = 6067L, YEAR = c(2020L, 2025L, 2030L), SSP2 = c(1600e3, 1616e3, 1632e3), SSP3 = c(1600e3, 1600e3, 1600e3)),
               data.table(GEOID = 6003L, YEAR = c(2020L, 2025L, 2030L), SSP2 = c(1000, 950, 900), SSP3 = c(1000, 950, 900)))
pop <- demand_population(hauer, census, "SSP2")
pl <- pop[Fips == "06061"]
check("population: Hauer's change from 2020 on the Census 2020 population (Placer 400 -> 440 thousand by 2025), gain a year, step midpoints", isTRUE(all.equal(pl$Pm[1], 420e3)) && isTRUE(all.equal(pl$G[1], 8e3)) && identical(pl$Mid, c(2022.5, 2027.5)))
check("population: the base is 2010-2020 (mean population, gain a year), the state row is left out", isTRUE(all.equal(pl$Pb[1], 375e3)) && isTRUE(all.equal(pl$Gb[1], 5e3)) && uniqueN(pop$Fips) == 3 && identical(attr(pop, "mid"), c(2015, 2022.5, 2027.5)))
check("population: a county that loses people has no gain, not a negative one", all(pop[Fips == "06003", G] == 0) && pop[Fips == "06003", Gb][1] == 0)
PR <- demand_population_ratios(pop, cw, "County", land = 1, L = 100, cap = 99)
check("county ratio: (P + L x gain) / (P_base + L x gain_base)", isTRUE(all.equal(unname(PR["06061", 1]), (420e3 + 100 * 8e3) / (375e3 + 100 * 5e3))))
check("a shrinking county's ratio is its population's (below 1, never negative)", PR["06003", 2] > 0 && PR["06003", 2] < 1)
PC <- demand_population_ratios(pop, cw, "County", land = 0.5, L = 100, cap = 99)
check("the land factor scales only the future gain: compact growth lowers the ratio", isTRUE(all.equal(unname(PC["06061", 1]), (420e3 + 0.5 * 100 * 8e3) / (375e3 + 100 * 5e3))) && all(PC <= PR + 1e-12))
check("with no weight on new residents the ratio is the population's alone", isTRUE(all.equal(unname(demand_population_ratios(pop, cw, "County", L = 0)["06061", 1]), 420 / 375)))
PM <- demand_population_ratios(pop, cw, "Metro", land = 1, L = 100, cap = 99)
check("metropolitan pooling sums people and gains first (Sacramento metro = Placer + Sacramento)", isTRUE(all.equal(unname(PM["40900", 1]),
  (420e3 + 1507.5e3 + 100 * (8e3 + 3e3)) / (375e3 + 1450e3 + 100 * (5e3 + 10e3)))) && "rest-06" %in% rownames(PM))
check("the low-growth scenario gives lower ratios, and the cap holds", all(demand_population_ratios(demand_population(hauer, census, "SSP3"), cw, "County", L = 100) <= PR + 1e-12) && max(demand_population_ratios(pop, cw, "County", L = 1e6, cap = 1.2)) <= 1.2)
check("a scenario the table lacks, or a table without 2020, stops", inherits(tryCatch(demand_population(hauer, census, "SSP9"), error = function(e) e), "error") &&
  inherits(tryCatch(demand_population(hauer[YEAR != 2020], census, "SSP2"), error = function(e) e), "error"))
# a county the tables lack (Connecticut's planning regions) takes its state's ratio
PS <- demand_population_ratios(pop, cw, "State", L = 100, cap = 99); PF <- demand_fill(PR, c("06061", "06999", "09110", NA), PS)
check("a county the tables lack takes its state's ratio and is named; one of a state they lack stays missing", isTRUE(all.equal(unname(PF["06999", ]), unname(PS["06", ]))) && identical(attr(PF, "filled"), "06999") &&
  !"09110" %in% rownames(PF) && identical(attr(PF, "mid"), attr(PR, "mid")))

# ---- ICLUS ----
# two climate models of SSP5 (their mean counts), one of SSP2; Placer and Sacramento (metro 40900), Alpine with no new land in the base
ic <- rbind(data.table(Fips = "06061", Run = "ssp5_rcp85_hadgem2_es", Year = c(2010L, 2020L, 2030L), Km2 = c(20, 30, 50)), data.table(Fips = "06061", Run = "ssp5_rcp85_giss_e2_r", Year = c(2010L, 2020L, 2030L), Km2 = c(20, 50, 50)),
            data.table(Fips = "06067", Run = "ssp5_rcp85_hadgem2_es", Year = c(2010L, 2020L, 2030L), Km2 = c(60, 60, 30)), data.table(Fips = "06067", Run = "ssp5_rcp85_giss_e2_r", Year = c(2010L, 2020L, 2030L), Km2 = c(60, 60, 30)),
            data.table(Fips = "06003", Run = "ssp5_rcp85_hadgem2_es", Year = c(2010L, 2020L, 2030L), Km2 = c(0, 1, 1)), data.table(Fips = "06003", Run = "ssp5_rcp85_giss_e2_r", Year = c(2010L, 2020L, 2030L), Km2 = c(0, 1, 1)),
            data.table(Fips = "06061", Run = "ssp2_rcp45_hadgem2_es", Year = c(2010L, 2020L, 2030L), Km2 = c(20, 10, 5)))
ia <- demand_iclus_areas(ic, "SSP5")
check("ICLUS: km2 a year by county and decade, the mean of the scenario's climate models; 2010-2020 is the base", isTRUE(all.equal(ia[Fips == "06061" & Step == "2020-2030", PerYear], 4)) && attr(ia, "models") == 2 &&
  identical(attr(ia, "steps"), c("2020-2030", "2030-2040")) && identical(attr(ia, "mid"), c(2015, 2025, 2035)))
IR <- demand_ratios(ia, cw, "Metro", cap = 99, min_cal = DEMAND_ICLUS_MIN_CAL, cal_step = DEMAND_ICLUS_CAL, steps = attr(ia, "steps"))
check("ICLUS: pooled by metropolitan area against its own 2010-2020 ((40 + 60) / 80, (50 + 30) / 80)", isTRUE(all.equal(unname(IR["40900", ]), c(1.25, 1))))
check("ICLUS: a unit with no new land in the base decade takes its state's ratio ((40 + 60 + 1) / 80)", isTRUE(all.equal(unname(IR["rest-06", 1]), 101 / 80)) && "rest-06" %in% attr(IR, "fallback"))
ICo <- demand_ratios(ia, cw, "County", cap = 99, min_cal = DEMAND_ICLUS_MIN_CAL, cal_step = DEMAND_ICLUS_CAL, steps = attr(ia, "steps"))
check("ICLUS by county: a county keeps its own ratio, one with no base takes the state's", isTRUE(all.equal(unname(ICo["06061", ]), c(2, 2.5))) && isTRUE(all.equal(unname(ICo["06003", 1]), 101 / 80)))
check("ICLUS: SSP2 is its own table; a scenario ICLUS lacks, or a table without the base decade, stops", isTRUE(all.equal(demand_iclus_areas(ic, "SSP2")[Step == "2030-2040", PerYear], 0.5)) &&
  inherits(tryCatch(demand_iclus_areas(ic, "SSP3"), error = function(e) e), "error") && inherits(tryCatch(demand_iclus_areas(ic[Year > 2010], "SSP5"), error = function(e) e), "error"))
o <- demand_options(data.table(UrbanMethod = "ICLUS v2.1.1 (EPA) ratio", UrbanIclus = "SSP5-RCP8.5"))
check("ICLUS options: the scenario, pooled by metropolitan area unless told", o$method == "ICLUS" && o$iclus == "SSP5" && o$pooling == "Metro" && demand_options(data.table(UrbanMethod = "ICLUS v2.1.1 (EPA) ratio"))$iclus == "SSP2")
# the map lists of the tabulation (src/iclus.R), on folders made here: a GeoTIFF run with 2000 and 2010, the decades in order
td <- file.path(tempdir(), "iclus-test"); dir.create(file.path(td, "ICLUS_v2_1_1_land_use_conus_ssp2_rcp45_giss_e2_r"), recursive = TRUE, showWarnings = FALSE)
for (y in c(2000, 2010)) file.create(file.path(td, "ICLUS_v2_1_1_land_use_conus_ssp2_rcp45_giss_e2_r", sprintf("ICLUS_v2_1_1_land_use_conus_%d.tif", y)))
for (y in c(2030, 2020)) file.create(file.path(td, "ICLUS_v2_1_1_land_use_conus_ssp2_rcp45_giss_e2_r", sprintf("ICLUS_v2_1_1_land_use_conus_%d_ssp2_rcp45_giss_e2_r.tif", y)))
source("src/iclus.R"); mm <- iclus_all_maps(td, "ssp2_rcp45_giss_e2_r")[[1]]
check("ICLUS maps: the decades from 2010 on, in order (2000 left out), sidecar files ignored", identical(names(mm), c("2010", "2020", "2030")) && all(grepl("[.]tif$", mm)))
check("ICLUS maps: a run that is not there stops", inherits(tryCatch(iclus_maps(td, "ssp5_rcp85_giss_e2_r"), error = function(e) e), "error"))

# ---- Forest harvest: the RPA forest products table ----
ft <- rbindlist(lapply(names(DEMAND_HARVEST_REGIONS), function(r) data.table(Measurement = "Timber harvest level", Product = c("total timber", "coniferous timber"), Units = "1000CM", Location = r,
  `2015` = NA_real_, `2020` = c(100, 60), `2025` = c(110, 66), `2030` = c(if (r == "Pacific Coast") 150 else 120, 70))))
ft <- rbind(ft, data.table(Measurement = c("Timber harvest level", "Production level"), Product = c("total timber", "plywood"), Units = "1000CM", Location = c("United States", "Pacific Coast"), `2015` = c(500, 9), `2020` = c(600, 9), `2025` = c(700, 9), `2030` = c(800, 9)))
HR <- demand_harvest_ratios(ft, cap = 99)
check("harvest: the six regions' total timber harvest relative to 2020, the years after it as columns", identical(sort(rownames(HR)), sort(names(DEMAND_HARVEST_REGIONS))) && identical(colnames(HR), c("2025", "2030")) &&
  isTRUE(all.equal(unname(HR["Pacific Coast", ]), c(1.1, 1.5))) && isTRUE(all.equal(unname(HR["South East", ]), c(1.1, 1.2))) && identical(attr(HR, "mid"), c(2020, 2025, 2030)))
check("harvest: capped; other products, measurements and the national row are not read", max(demand_harvest_ratios(ft, cap = 1.3)) == 1.3 && !"United States" %in% rownames(HR))
HY <- demand_years(HR, attr(HR, "mid"), c(2015L, 2020L, 2024L, 2030L, 2060L))
check("harvest by year: 1 up to 2020, then toward each projected year, the last value kept", isTRUE(all.equal(unname(HY["Pacific Coast", ]), c(1, 1, 1.08, 1.5, 1.5))))
check("harvest: a table without a region, or without 2020, stops", inherits(tryCatch(demand_harvest_ratios(ft[Location != "North East"]), error = function(e) e), "error") &&
  inherits(tryCatch(demand_harvest_ratios(ft[, !"2020"]), error = function(e) e), "error"))
check("harvest: each county's RPA region by its state (Placer Pacific Coast, Travis South Central, a Kansas county Rocky Mountain); Alaska and no county have none",
  identical(demand_harvest_region(c(6061L, 48453L, 20001L, 2020L, NA)), c("Pacific Coast", "South Central", "Rocky Mountain", NA, NA)))
check("harvest: every conterminous state and DC is in one region only", { s <- unlist(DEMAND_HARVEST_REGIONS); length(s) == 49 && !anyDuplicated(s) && !any(c("02", "15") %in% s) })
o <- demand_options(data.table(HarvestMethod = "RPA 2020 Assessment (forest products) ratio", HarvestScenario = "RCP4.5-SSP1 (lower emissions, medium growth)"))
check("harvest options: its own method and scenario, apart from urbanization's; blank = as drawn, RCP8.5-SSP2", o$ag[["Forest Harvest"]] == "RPA" && o$harvest_pair == "rcp45_ssp1" && o$method == "Historical" &&
  demand_options(data.table())$ag[["Forest Harvest"]] == "Historical" && demand_options(data.table(HarvestMethod = "Custom ratio table"))$ag[["Forest Harvest"]] == "Custom" && demand_options(data.table())$harvest_pair == "rcp85_ssp2")
check("harvest: a scenario file for each of the four RPA pairs", setequal(names(DEMAND_HARVEST_FILE), DEMAND_PAIRS))

# ---- Custom table ----
cu <- demand_custom(data.table(Key = c(NA, NA, "State: California", "County: Placer California"), Year = c(2030L, 2050L, 2040L, 2030L), Ratio = c(1.5, 2, 0.5, 3)), years = 2024:2060, y_end = 2023L)
check("custom: a key per unit, blank = everywhere", setequal(rownames(cu), c(DEMAND_EVERYWHERE, "State: California", "County: Placer California")) && ncol(cu) == 37)
check("custom: from 1 in the historical end year to the first row, linear between rows, the last value kept", isTRUE(all.equal(unname(cu[DEMAND_EVERYWHERE, c("2024", "2030", "2040", "2050", "2060")]), c(1 + 0.5 / 7, 1.5, 1.75, 2, 2))))
check("custom: a single row ramps from 1 and then holds", isTRUE(all.equal(unname(cu["State: California", c("2040", "2060")]), c(0.5, 0.5))) && cu["State: California", "2030"] > 0.5 && cu["State: California", "2030"] < 1)
check("custom: a row in the historical end year starts there, with no ramp", all(demand_custom(data.table(Key = NA, Year = 2023L, Ratio = 2), 2024:2026, 2023L) == 2))
check("custom: a ratio of 0 is allowed (no urbanization), below 0 and duplicate rows stop", all(demand_custom(data.table(Key = NA, Year = 2023L, Ratio = 0), 2024:2025, 2023L) == 0) &&
  inherits(tryCatch(demand_custom(data.table(Key = NA, Year = 2030L, Ratio = -1), 2024:2025, 2023L), error = function(e) e), "error") &&
  inherits(tryCatch(demand_custom(data.table(Key = c(NA, NA), Year = c(2030L, 2030L), Ratio = c(1, 2)), 2024:2025, 2023L), error = function(e) e), "error"))
# the custom rows through the cell weighting: a county row decides inside it, the state row elsewhere
MC <- demand_unit_ratio(c(1L, 1L, 2L), c("County: Placer California", "State: California", "State: California"), c(1, 1, 1), cu[, c("2030", "2040")])
check("custom: a target unit over a county row and the state row blends them; one in the state alone takes the state's", isTRUE(all.equal(unname(MC["2", "2040"]), 0.5)) && isTRUE(all.equal(unname(MC["1", "2040"]), (3 + 0.5) / 2)))

# ---- the Data Source's rows ----
x9 <- paste(readLines("package.xml", warn = FALSE), collapse = "\n")
check("package.xml declares the sheets and stage 9 reads and writes them", grepl('<dataSheet name="LandUseDemand"', x9, fixed = TRUE) && grepl('<dataSheet name="OutputLandUseDemand"', x9, fixed = TRUE) &&
  grepl('<dataSheet name="LandUseDemand" type="Input"/>', x9, fixed = TRUE) && grepl('<dataSheet name="OutputLandUseDemand" type="Output"/>', x9, fixed = TRUE))
check("Data Sources has the RpaLandUseFile column, and the update adds it to existing libraries", grepl('<column name="RpaLandUseFile"', x9, fixed = TRUE) &&
  any(grepl('AddColumn(store, "lucasCore_DataSource", "RpaLandUseFile"', readLines("ui/LucasCoreUpdates.cs", warn = FALSE), fixed = TRUE)))
lay <- fread("defaults/library/data-sources.csv", colClasses = "character")[Column == "RpaLandUseFile"]
check("data-sources.csv gives it a home place for one .rds file", nrow(lay) == 1 && lay$HomePath == "land-use/rpa-2020/*.rds")
check("endpoints.csv and citations.csv have its rows", nrow(fread("defaults/download/endpoints.csv")[Column == "RpaLandUseFile" & Fetched == "yes"]) == 1 && nrow(fread("defaults/metadata/citations.csv")[Column == "RpaLandUseFile"]) == 1)
env <- list(PackageDirectory = "."); source("src/datahome.R"); source("src/download.R"); source("src/iclus.R"); source("src/download-sources.R")
check("the Data Download stage loads the ICLUS tabulation its handler uses", any(grepl('pkg_file("src", "iclus.R")', readLines("src/15-data-download.R", warn = FALSE), fixed = TRUE)) &&
  nrow(download_handlers()$IclusCountyFile$plan(list())) == 4)
h <- download_handlers()$RpaLandUseFile
check("the download handler fetches the release's zip, keeps the table whole (national) and writes the file the home place names", !is.null(h) && isTRUE(h$national) &&
  grepl("RDS-2023-0026[.]zip$", h$plan(list())$url) && grepl("[.]rds$", lay$HomePath))
check("no pre-computed ratios ship with the package", !file.exists("defaults/projection/rpa-urban-ratios.csv"))
for (k in c("RpaForestProductsFolder", "IclusCountyFile", "PopulationProjectionFile", "CensusPopulationFile")) check(sprintf("%s: a Data Sources column, the update, a home place, an endpoint, a citation and a national download handler", k),
  grepl(sprintf('<column name="%s"', k), x9, fixed = TRUE) && any(grepl(sprintf('"lucasCore_DataSource", "%s"', k), readLines("ui/LucasCoreUpdates.cs", warn = FALSE), fixed = TRUE)) &&
  nrow(fread("defaults/library/data-sources.csv", colClasses = "character")[Column == k & grepl("^land-use/", HomePath)]) == 1 &&
  nrow(fread("defaults/download/endpoints.csv")[Column == k & Fetched == "yes"]) == 1 && nrow(fread("defaults/metadata/citations.csv")[Column == k]) == 1 && isTRUE(download_handlers()[[k]]$national))
check("package.xml declares the custom table and stage 9 reads it", grepl('<dataSheet name="LandUseDemandRatio"', x9, fixed = TRUE) && grepl('<dataSheet name="LandUseDemandRatio" type="Input"/>', x9, fixed = TRUE))
check("every method of the sheet's list is one the stage knows", { m <- regmatches(x9, regexpr('name="UrbanMethod"[^>]*formula1="[^"]*"', x9)); it <- strsplit(sub('.*formula1="([^"]*)"', "\\1", m), "|", fixed = TRUE)[[1]]
  setequal(vapply(sub("^[0-9]+:", "", it), function(s) demand_options(data.table(UrbanMethod = s))$method, ""), DEMAND_METHODS) })

# ---- the published table, when it is in the Data Sources folder ----
f <- file.path(Sys.getenv("LUCAS_DATA_HOME", "E:/lucasData"), "land-use/rpa-2020/county_landuse_projections_RPA.rds")
if (file.exists(f)) { X <- readRDS(f)
  A5 <- demand_rpa_areas(X, "rcp85_ssp5"); S5 <- demand_ratios(A5, cw, "State", cap = 99); S3 <- demand_ratios(demand_rpa_areas(X, "rcp85_ssp3"), cw, "State", cap = 99)
  check("published table: five climate models a pair, 3,075 counties", attr(A5, "models") == 5 && uniqueN(A5$Fips) == 3075)
  check("published table: national urbanization in 2012-2020 is about 3,600 km2 a year", abs(A5[Step == DEMAND_CAL, sum(PerYear)] - 3600) < 150)
  check("published table: California rises to about 1.48 under SSP5 and falls to about 0.88 under SSP3", abs(S5["06", 5] - 1.48) < 0.02 && abs(S3["06", 5] - 0.88) < 0.02)
  M5 <- demand_ratios(A5, cw, "Metro", cap = 3)
  check("published table: 428 metropolitan units, Sacramento about 1.49, none above the cap", nrow(M5) == 428 && abs(M5["40900", 5] - 1.49) < 0.02 && max(M5) <= 3)
  P <- demand_unit_ratio(rep(1L, 4), rep("06", 4), rep(1, 4), demand_years(S5, DEMAND_MID, c(2035L, 2065L, 2100L)))
  check("published table: California by year, SSP5: about 1.04 in 2035, 1.48 in 2065 and after", abs(P[1, 1] - 1.04) < 0.02 && abs(P[1, 2] - 1.48) < 0.02 && P[1, 3] == P[1, 2])
} else cat("skip: the RPA county projections are not in the Data Sources folder (", f, ")\n", sep = "")
hf <- file.path(Sys.getenv("LUCAS_DATA_HOME", "E:/lucasData"), "land-use/hauer-2019/hauer_county_ssp_totals.csv"); cf <- file.path(Sys.getenv("LUCAS_DATA_HOME", "E:/lucasData"), "land-use/census-population/co-est2020-alldata.csv")
if (file.exists(hf) && file.exists(cf)) { H <- fread(hf); C <- fread(cf, encoding = "Latin-1")
  rat <- function(ssp, pooling = "County", land = 1) { p <- demand_population(H, C, ssp); r <- demand_population_ratios(p, cw, pooling, land, cap = 99); demand_years(r, attr(r, "mid"), c(2030L, 2050L, 2070L, 2100L)) }
  n2 <- rat("SSP2", "State"); n3 <- rat("SSP3", "State"); n5 <- rat("SSP5", "State")
  check("published tables: 49 states; in 2070 most states are below 1 under SSP3 and above 1 under SSP5", nrow(n2) >= 49 && median(n3[, "2070"]) < 0.8 && median(n5[, "2070"]) > 1.3)
  c5 <- rat("SSP5"); check("published tables: over 3,000 counties, every ratio above 0", nrow(c5) > 3000 && all(is.finite(c5)) && min(c5) > 0)
  check("published tables: compact growth (0.5) lowers and sprawl (1.5) raises California's 2050 ratio", rat("SSP2", "State", 0.5)["06", "2050"] < n2["06", "2050"] && rat("SSP2", "State", 1.5)["06", "2050"] > n2["06", "2050"])
  cat(sprintf("  California 2050, SSP2: compact %.2f, as 2010-2020 %.2f, sprawl %.2f; SSP3 %.2f, SSP5 %.2f\n", rat("SSP2", "State", 0.5)["06", "2050"], n2["06", "2050"], rat("SSP2", "State", 1.5)["06", "2050"], n3["06", "2050"], n5["06", "2050"]))
} else cat("skip: the population tables are not in the Data Sources folder\n")
icf <- file.path(Sys.getenv("LUCAS_DATA_HOME", "E:/lucasData"), "land-use/iclus/iclus_v211_county_new_developed.csv")
if (file.exists(icf)) { T <- fread(icf, colClasses = list(character = "Fips"))
  ir <- function(ssp, pl) { a <- demand_iclus_areas(T, ssp); r <- demand_ratios(a, cw, pl, 99, DEMAND_ICLUS_MIN_CAL, DEMAND_ICLUS_CAL, attr(a, "steps")); demand_years(r, attr(a, "mid"), c(2055L, 2095L)) }
  s2 <- ir("SSP2", "State"); s5 <- ir("SSP5", "State")
  check("ICLUS table: two climate models a scenario, 49 states, every ratio a number", attr(demand_iclus_areas(T, "SSP2"), "models") == 2 && nrow(s2) == 49 && all(is.finite(s2)) && all(is.finite(s5)))
  check("ICLUS table: by the 2090s most states are far below 1 under SSP2 and above it under SSP5", median(s2[, "2095"]) < 0.5 && median(s5[, "2095"]) > 1)
  cat(sprintf("  California, ICLUS 2055 / 2095: SSP2 %.2f / %.2f, SSP5 %.2f / %.2f\n", s2["06", 1], s2["06", 2], s5["06", 1], s5["06", 2]))
} else cat("skip: the ICLUS county table is not in the Data Sources folder\n")
fd <- file.path(Sys.getenv("LUCAS_DATA_HOME", "E:/lucasData"), "land-use/rpa-forest-products")
if (all(file.exists(file.path(fd, DEMAND_HARVEST_FILE)))) { hr <- lapply(DEMAND_HARVEST_FILE, function(f) demand_harvest_ratios(fread(file.path(fd, f), header = TRUE), cap = 99))
  check("RPA forest products: every scenario has the six regions to 2070, harvest rising in each", all(vapply(hr, function(r) nrow(r) == 6 && "2070" %in% colnames(r) && all(r[, "2070"] > 1), TRUE)))
  check("RPA forest products: low growth (SSP3) the least and high growth (SSP5) the most in 2070", all(hr$rcp85_ssp3[, "2070"] < hr$rcp85_ssp2[, "2070"]) && all(hr$rcp85_ssp2[, "2070"] < hr$rcp85_ssp5[names(DEMAND_HARVEST_REGIONS), "2070"][rownames(hr$rcp85_ssp2)]))
  cat(sprintf("  Pacific Coast harvest in 2070 against 2020: SSP3 %.2f, SSP2 %.2f, SSP1 %.2f, SSP5 %.2f\n", hr$rcp85_ssp3["Pacific Coast", "2070"], hr$rcp85_ssp2["Pacific Coast", "2070"], hr$rcp45_ssp1["Pacific Coast", "2070"], hr$rcp85_ssp5["Pacific Coast", "2070"]))
} else cat("skip: the RPA forest products tables are not in the Data Sources folder\n")
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
