# Fast test of projected fire that follows climate (src/fire-climate.R; no SyncroSim, no data). to-do 9, lucasCore 2.2.
# Run: Rscript tests/unit-fire-climate.R (from the package root)
suppressPackageStartupMessages({ library(data.table) }); source("src/fire-climate.R")
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
near <- function(a, b, tol = 1e-9) isTRUE(all.equal(a, b, tolerance = tol, check.attributes = FALSE))

# ---- names and options -----------------------------------------------------------------------------------------------------
ms <- c("Fire: High Severity [Type]", "Fire: Medium Severity [Type]", "Fire: Low Severity [Type]")
check("a severity group's distribution type", identical(fire_severity_type(ms), c("Fire Severity: High", "Fire Severity: Medium", "Fire Severity: Low")))
check("the Fire page: blank and 1 = as the setup draws them, 2 = from the Projection Climate result",
      !fire_years_from_climate(data.table()) && !fire_years_from_climate(data.table(FireYears = NA)) && !fire_years_from_climate(data.table(FireYears = 1L)) &&
        fire_years_from_climate(data.table(FireYears = 2L)) && fire_years_from_climate(data.table(FireYears = "From the Projection Climate result (climate analog years)")))
o <- fire_climate_options(data.table())
check("the Fire and Climate page: blank = the analog draw of 10 years", o$analog && o$k == 10L)
check("... the setup's own draws, and another number of years", !fire_climate_options(data.table(FireYears = 2L))$analog && fire_climate_options(data.table(AnalogYears = 3))$k == 3L &&
        !fire_climate_options(data.table(FireYears = "As the Projection Setup drew them (no climate)"))$analog)
check("... a number of years below 1 or not whole is refused", inherits(try(fire_climate_options(data.table(AnalogYears = 0)), silent = TRUE), "try-error") &&
        inherits(try(fire_climate_options(data.table(AnalogYears = 2.5)), silent = TRUE), "try-error"))

# ---- the setup's lookup ------------------------------------------------------------------------------------------------------
ratio <- setNames(c(0, 0.5, 2.5), 2001:2003); sh <- matrix(c(0.2, 0.3, 0.5, 0.1, 0.4, 0.5, 0.6, 0.3, 0.1), nrow = 3)
lk <- fire_lookup(ratio, sh, ms, "Fire", 2024L)
check("a multiplier row of type Fire: Climate on the fire group and each severity group, read by its distribution", nrow(lk$tmv) == 4L && all(lk$tmv$TransitionMultiplierTypeId == FIRE_CLIMATE) &&
        identical(lk$tmv$TransitionGroupId, c("Fire", ms)) && identical(lk$tmv$DistributionType, c(FIRE_RATE_ALL, fire_severity_type(ms))) && all(lk$tmv$Timestep == 2024L) && all(lk$tmv$DistributionFrequencyId == FIRE_FREQ))
check("a distribution row per reference year for each, keyed by the drawn year", nrow(lk$dv) == 12L && all(lk$dv$ExternalVariableTypeId == FIRE_EV_YEAR) && all(lk$dv$ExternalVariableMin == lk$dv$ExternalVariableMax) &&
        near(lk$dv[DistributionTypeId == FIRE_RATE_ALL, Value], c(0, 0.5, 2.5)) && near(lk$dv[DistributionTypeId == "Fire Severity: High", Value], c(0.2, 0.1, 0.6)))
check("a year's severity shares sum to 1", near(lk$dv[DistributionTypeId != FIRE_RATE_ALL, sum(Value), by = ExternalVariableMin]$V1, rep(1, 3)))
check("shapes that do not match are refused", inherits(try(fire_lookup(ratio, sh[, 1:2], ms, "Fire", 2024L), silent = TRUE), "try-error"))

# ---- seasons and the index -------------------------------------------------------------------------------------------------
set.seed(3); mo <- CJ(y = 1981:2020, m = 1:12); mo[, `:=`(TX = 20 + 5 * sin(m / 2) + rnorm(.N), P = pmax(0, 50 + rnorm(.N, 0, 20)))]
s <- fire_season(mo$y, mo$m, mo$TX, mo$P)
check("fire seasons: May-September, mean maximum temperature and summed precipitation", nrow(s) == 40L && near(s[y == 1990, Tmax], mo[y == 1990 & m %in% 5:9, mean(TX)]) && near(s[y == 1990, Precip], mo[y == 1990 & m %in% 5:9, sum(P)]))
check("a year missing a season month is left out", !2020 %in% fire_season(mo[!(y == 2020 & m == 7)]$y, mo[!(y == 2020 & m == 7)]$m, mo[!(y == 2020 & m == 7)]$TX, mo[!(y == 2020 & m == 7)]$P)$y)
b <- s[y %in% FIREK$base]; ix <- fire_index(s, b)
check("the index: mean 0 and SD 1 over the base years", near(mean(ix[as.character(b$y)]), 0, 1e-9) && near(sd(ix[as.character(b$y)]), 1, 1e-9))
s2 <- copy(s); s2[y == 1990, Tmax := Tmax + 2]; s3 <- copy(s); s3[y == 1990, Precip := Precip + 50]
check("hotter is higher, wetter is lower", fire_index(s2, b)[["1990"]] > ix[["1990"]] && fire_index(s3, b)[["1990"]] < ix[["1990"]])
check("a base with no spread is refused", inherits(try(fire_index(s, b[, Tmax := 20]), silent = TRUE), "try-error"))
b <- s[y %in% FIREK$base]

# ---- the delta method ------------------------------------------------------------------------------------------------------
run <- copy(s); run[, `:=`(Tmax = Tmax + 3, Precip = Precip * 0.5)]   # a model 3 C too warm and half as wet, with no change of its own
d <- fire_delta(run, s)
check("a model's bias drops out: the run on the observed scale matches the record over the base years", near(mean(d[y %in% FIREK$base, Tmax]), mean(b$Tmax)) && near(mean(d[y %in% FIREK$base, Precip]), mean(b$Precip)))
fut <- rbind(run, data.table(y = 2050L, Tmax = mean(run[y %in% FIREK$base, Tmax]) + 2, Precip = mean(run[y %in% FIREK$base, Precip])))
check("a future 2 C above the run's own base is 2 C above the observed base", near(fire_delta(fut, s)[y == 2050, Tmax], mean(b$Tmax) + 2))
check("too few base years is refused", inherits(try(fire_delta(run[y > 2010], s), silent = TRUE), "try-error"))

# ---- the analog draw ------------------------------------------------------------------------------------------------------------
ih <- setNames(c(-2, -1, 0, 0.5, 1, 1.5, 2.5, 3), 2001:2008); ip <- setNames(c(-1.9, 0.1, 9), 2031:2033)
dr <- fire_analog_draw(ip, ih, 50L, 2L, 7L); an <- attr(dr, "analogs")
check("one drawn year for every iteration and projection year", nrow(dr) == 150L && identical(dr[, .N, by = Timestep]$N, rep(50L, 3)))
check("a projection year's analogs are its nearest reference years", setequal(an[["2031"]], c(2001, 2002)) && setequal(an[["2032"]], c(2003, 2004)) && setequal(an[["2033"]], c(2007, 2008)))
check("each draw is one of its year's analogs, and both are drawn", all(dr[, all(HistoricalYear %in% an[[as.character(Timestep[1])]]), by = Timestep]$V1) && dr[Timestep == 2033, uniqueN(HistoricalYear)] == 2L)
check("a future hotter than every reference year draws among the hottest", all(dr[Timestep == 2033, HistoricalYear] %in% c(2007, 2008)))
check("the same seed gives the same draw", identical(fire_analog_draw(ip, ih, 50L, 2L, 7L)$HistoricalYear, dr$HistoricalYear))
check("more analog years than reference years: all of them", length(attr(fire_analog_draw(ip, ih, 3L, 20L, 1L), "analogs")[["2031"]]) == 8L)
check("one analog year: the nearest, every time", all(fire_analog_draw(ip, ih, 5L, 1L, 1L)[Timestep == 2032, HistoricalYear] == 2003L))
cr <- fire_climate_rows(dr)
check("a climate result's rows: the drawn year of every iteration and year as Fire: Drawn Year", nrow(cr) == 150L && all(cr$ExternalVariableTypeId == FIRE_EV_YEAR) && identical(cr$ExternalVariableValue, as.numeric(dr$HistoricalYear)))

# ---- the names ship with the package, the 2.2 update adds them, and the pages are in the package -------------------------------------
dtn <- fread("defaults/stsim/core_DistributionType.csv")$Name; evn <- fread("defaults/stsim/core_ExternalVariableType.csv")$Name; tmt <- fread("defaults/stsim/stsim_TransitionMultiplierType.csv")$Name
check("the lookup's names ship in defaults/stsim", all(c(FIRE_RATE_ALL, fire_severity_type(ms)) %in% dtn) && FIRE_EV_YEAR %in% evn && FIRE_CLIMATE %in% tmt && !anyDuplicated(dtn) && !anyDuplicated(evn) && !anyDuplicated(tmt))
cs <- paste(readLines("ui/LucasCoreUpdates.cs", warn = FALSE), collapse = "\n"); u22 <- regmatches(cs, regexpr("Update_2_200[\\s\\S]*?\n        \\}", cs, perl = TRUE))
check("the 2.2 update adds the FireYears column and every name", length(u22) == 1L && grepl('"lucasCore_FireOptions", "FireYears"', u22, fixed = TRUE) && all(vapply(c(FIRE_RATE_ALL, "Fire Severity: ", FIRE_EV_YEAR, FIRE_CLIMATE), function(k) grepl(k, u22, fixed = TRUE), TRUE)) &&
        all(c("High", "Medium", "Low") %in% sub("Fire Severity: ", "", fire_severity_type(ms))) && grepl('"High", "Medium", "Low"', u22, fixed = TRUE) && !grepl("'", regmatches(u22, regexpr("\\[Update\\(2\\.2,[^]]*\\]", cs))))
px <- xml2::read_xml("package.xml")
check("package.xml: the Fire page's column, the Fire and Climate page and output on stage 11, and version 2.2",
      length(xml2::xml_find_all(px, "//dataSheet[@name='FireOptions']/column[@name='FireYears']")) == 1 && length(xml2::xml_find_all(px, "//dataSheet[@name='FireClimate']/column")) == 2 &&
        length(xml2::xml_find_all(px, "//transformer[@name='ProjectionClimate']/dataSheet[@name='FireClimate']")) == 1 && length(xml2::xml_find_all(px, "//transformer[@name='ProjectionClimate']/dataSheet[@name='OutputFireClimate']")) == 1 &&
        startsWith(xml2::xml_attr(px, "version"), "2.2"))
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
