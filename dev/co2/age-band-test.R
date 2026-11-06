# =============================================================================
# age-band-test.R - does ST-Sim apply stage 11's CO2 flow multiplier rows by age band? (to-do 46)
# =============================================================================
# A synthetic non-spatial ST-Sim library (no lucasCore): five strata, each holding cells of one starting age (10, 25, 26, 100, 101: the
# band edges), three state classes, one growth flow (a state attribute of 10 per cell, Atmosphere -> Biomass) in flow group
# "Net Growth". Multipliers, as stage 11 writes them:
#   blank type        0.5 on every class (the Build's own stsim_FlowMultiplier rows)
#   CO2, class A      blank stratum, five age bands (stage 11's "age" case: forest with one ECM share)
#   CO2, class B      every stratum x band (the "all" case: forest with ecodivision ECM shares); stratum k adds 0.01 k
#   CO2, class C      one blank row (shrub, grass, wetland)
# with timestep 1 and timestep 2 values (1.1-1.5 then 2.1-2.5) to test the yearly rows. Expected growth per cell = 10 x 0.5 x m.
# Variants: the 0.5 row per class; the 0.5 row alone; the 0.5 row on one group and the CO2 rows on a second group holding the same
# flow (the Build's [Type] rows against stage 11's Total rows).
# Result 2026-11-06: every variant 30 of 30 rows exact. The year-t multiplier is the band of the cell's age at the start of year t
# (age0 + t - 1: a cell aged 25 takes band 1 in year 1 and band 2 in year 2); stratum rows, blank-stratum rows and the one blank row
# all match; the yearly rows take effect; the CO2 multiplier multiplies with the blank-type rows on the same group or another one.
# Note: stsim_OutputFlow lists a flow once per flow group it belongs to (here "Growth [Type]" and "Net Growth"): sum one group.
# Usage: Rscript dev/co2/age-band-test.R   (makes dev/libs/co2-age-test.ssim, replacing it)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/co2-age-test.ssim"; if (file.exists(f)) unlink(c(f, paste0(f, ".data"), paste0(f, ".temp")), recursive = TRUE)
L <- suppressWarnings(ssimLibrary(f, packages = "stsim")); P <- project(L, "Definitions")
ages <- c(10L, 25L, 26L, 100L, 101L); strata <- sprintf("S%03d", ages); classes <- c("Forest: A", "Forest: B", "Forest: C")
sv <- function(x, s, tgt = P) saveDatasheet(tgt, as.data.frame(x), s)
sv(data.table(Name = strata, Id = seq_along(strata)), "stsim_Stratum")
sv(data.table(Name = "Forest"), "stsim_StateLabelX"); sv(data.table(Name = c("A", "B", "C")), "stsim_StateLabelY")
sv(data.table(Name = classes, StateLabelXId = "Forest", StateLabelYId = c("A", "B", "C"), Id = 1:3), "stsim_StateClass")
sv(data.table(Name = c("Atmosphere", "Biomass")), "stsim_StockType")
sv(data.table(Name = "Growth"), "stsim_FlowType")
sv(data.table(Name = "Net Growth"), "stsim_FlowGroup")

sv(data.table(Name = "CO2"), "stsim_FlowMultiplierType")
sv(data.table(Name = "Net Growth"), "stsim_StateAttributeType")

S <- scenario(P, "CO2 age bands")
sv(data.table(FlowTypeId = "Growth", FlowGroupId = "Net Growth", Value = 1), "stsim_FlowTypeGroupMembership", S)
sv(data.table(MinimumTimestep = 0L, MaximumTimestep = 2L, MinimumIteration = 1L, MaximumIteration = 1L, IsSpatial = FALSE), "stsim_RunControl", S)
sv(data.table(StateClassIdSource = classes, StateClassIdDest = classes, Location = c("A1", "A2", "A3")), "stsim_DeterministicTransition", S)
sv(data.table(TotalAmount = 150, NumCells = 150, CalcFromDist = FALSE), "stsim_InitialConditionsNonSpatial", S)
sv(CJ(StratumId = strata, StateClassId = classes)[, `:=`(AgeMin = ages[match(StratumId, strata)], AgeMax = ages[match(StratumId, strata)], RelativeAmount = 10)],
   "stsim_InitialConditionsNonSpatialDistribution", S)
sv(data.table(StateClassId = classes, StateAttributeTypeId = "Net Growth", Value = 10), "stsim_StateAttributeValue", S)
sv(data.table(StockTypeId = c("Atmosphere", "Biomass"), Location = c("A1", "B1")), "stsim_FlowPathwayDiagram", S)
sv(data.table(FromStockTypeId = "Atmosphere", ToStockTypeId = "Biomass", StateAttributeTypeId = "Net Growth", FlowTypeId = "Growth", Multiplier = 1), "stsim_FlowPathway", S)
bands <- data.table(AgeMin = c(0L, 26L, 51L, 76L, 101L), AgeMax = c(25L, 50L, 75L, 100L, NA))
a <- rbindlist(lapply(1:2, function(t) cbind(Timestep = t, StateClassId = "Forest: A", StratumId = NA_character_, bands, Value = t + seq(0.1, 0.5, 0.1))))
b <- rbindlist(lapply(1:2, function(t) rbindlist(lapply(seq_along(strata), function(k)
  cbind(Timestep = t, StateClassId = "Forest: B", StratumId = strata[k], bands, Value = t + seq(0.1, 0.5, 0.1) + 0.01 * k)))))
cc <- data.table(Timestep = 1:2, StateClassId = "Forest: C", StratumId = NA_character_, AgeMin = NA_integer_, AgeMax = NA_integer_, Value = c(1.05, 2.05))
fm <- rbind(data.table(FlowGroupId = "Net Growth", Value = 0.5), rbind(a, b, cc)[, `:=`(FlowGroupId = "Net Growth", FlowMultiplierTypeId = "CO2")], fill = TRUE)
sv(fm, "stsim_FlowMultiplier", S)
sv(data.table(SummaryOutputFL = TRUE, SummaryOutputFLTimesteps = 1L, SummaryOutputST = TRUE, SummaryOutputSTTimesteps = 1L), "stsim_OutputOptionsStockFlow", S)
sv(data.table(SummaryOutputSC = TRUE, SummaryOutputSCTimesteps = 1L), "stsim_OutputOptions", S)
sv(data.table(StageNameId = "ST-Sim", RunOrder = 1L), "core_Pipeline", S)
R <- run(S)
of <- as.data.table(datasheet(R, "stsim_OutputFlow", lookupsAsFactors = FALSE))[FlowGroupId == "Growth [Type]"]   # each flow is listed once per group it belongs to
cat("output flow columns:", paste(names(of), collapse = ", "), "\n")
x <- of[, .(Amount = sum(Amount)), by = .(Timestep, Stratum = FromStratumId, Class = FromStateClassId)]
x[, age0 := ages[match(Stratum, strata)]][, per_cell := Amount / 10][, m := per_cell / (10 * 0.5)]
band_of <- function(age) findInterval(age, c(0, 26, 51, 76, 101))
x[, k := match(Stratum, strata)]
x[, exp_t0age := fcase(Class == "Forest: C", Timestep + 0.05, Class == "Forest: A", Timestep + band_of(age0) / 10, default = Timestep + band_of(age0) / 10 + 0.01 * k)]
x[, exp_age_plus := fcase(Class == "Forest: C", Timestep + 0.05, Class == "Forest: A", Timestep + band_of(age0 + Timestep) / 10, default = Timestep + band_of(age0 + Timestep) / 10 + 0.01 * k)]
setorder(x, Class, Timestep, age0); print(x[, .(Class, Timestep, age0, m = round(m, 4), if_start_age = exp_t0age, if_age_plus_t = exp_age_plus)])
fwrite(x, "F:/lucasCore/dev/co2/age-band-test-result.csv")
# cells per stratum x class (no transitions, so the same every year) from the state class output
sc <- as.data.table(datasheet(R, "stsim_OutputStratumState", lookupsAsFactors = FALSE))[Timestep == 1, .(cells = sum(Amount)), by = .(Stratum = StratumId, Class = StateClassId)]
x <- merge(x, sc, by = c("Stratum", "Class"))[, m := Amount / cells / (10 * 0.5)]
x[, `:=`(start = abs(m - exp_t0age) < 1e-6, plus = abs(m - exp_age_plus) < 1e-6)]
setorder(x, Class, Timestep, age0)
print(x[, .(Class, Timestep, age0, cells, m = round(m, 4), if_start_age = exp_t0age, if_age_plus_t = exp_age_plus, start, plus)])
cat(sprintf("rows matching the start-age band: %d of %d; matching age + timestep: %d of %d\n", sum(x$start), nrow(x), sum(x$plus), nrow(x)))
fwrite(x, "F:/lucasCore/dev/co2/age-band-test-result.csv")

# ---- variant: the 0.5 row written per class (as the Build writes its rows) -----------------------------------------------------
S2 <- scenario(P, "CO2 age bands, classed 0.5", sourceScenario = S)
fm2 <- rbind(data.table(FlowGroupId = "Net Growth", StateClassId = classes, Value = 0.5), rbind(a, b, cc)[, `:=`(FlowGroupId = "Net Growth", FlowMultiplierTypeId = "CO2")], fill = TRUE)
sv(fm2, "stsim_FlowMultiplier", S2)
R2 <- run(S2)
of2 <- as.data.table(datasheet(R2, "stsim_OutputFlow", lookupsAsFactors = FALSE))[FlowGroupId == "Growth [Type]"][, .(Amount = sum(Amount)), by = .(Timestep, Stratum = FromStratumId, Class = FromStateClassId)]
sc2 <- as.data.table(datasheet(R2, "stsim_OutputStratumState", lookupsAsFactors = FALSE))[Timestep == 1, .(cells = sum(Amount)), by = .(Stratum = StratumId, Class = StateClassId)]
y <- merge(merge(of2, sc2, by = c("Stratum", "Class")), x[, .(Stratum, Class, Timestep, age0, exp_t0age, exp_age_plus)], by = c("Stratum", "Class", "Timestep"))
y[, m := Amount / cells / (10 * 0.5)]
# the year-t multiplier is the band of the cell's age at the start of year t (age0 + t - 1)
y[, expected := fcase(Class == "Forest: C", Timestep + 0.05, Class == "Forest: A", Timestep + findInterval(age0 + Timestep - 1, c(0, 26, 51, 76, 101)) / 10,
                      default = Timestep + findInterval(age0 + Timestep - 1, c(0, 26, 51, 76, 101)) / 10 + 0.01 * match(Stratum, strata))]
x[, expected := fcase(Class == "Forest: C", Timestep + 0.05, Class == "Forest: A", Timestep + findInterval(age0 + Timestep - 1, c(0, 26, 51, 76, 101)) / 10,
                      default = Timestep + findInterval(age0 + Timestep - 1, c(0, 26, 51, 76, 101)) / 10 + 0.01 * match(Stratum, strata))]
cat(sprintf("blank-class 0.5 row:  %d of %d rows = 0.5 x band multiplier; %d of %d = band multiplier alone (0.5 not applied)\n",
            sum(abs(x$m - x$expected) < 1e-6), nrow(x), sum(abs(x$m / 2 - x$expected) < 1e-6), nrow(x)))
cat(sprintf("classed 0.5 rows:     %d of %d rows = 0.5 x band multiplier; %d of %d = band multiplier alone\n", sum(abs(y$m - y$expected) < 1e-6), nrow(y),
            sum(abs(y$m / 2 - y$expected) < 1e-6), nrow(y)))
print(head(y[order(Class, Timestep, age0), .(Class, Timestep, age0, cells, Amount, m = round(m, 4), expected)], 12))

# ---- variants 3 and 4: is a blank-type row dropped only when CO2 rows share its flow group? ----------------------------------
mult <- function(R) { o <- as.data.table(datasheet(R, "stsim_OutputFlow", lookupsAsFactors = FALSE))[FlowGroupId == "Growth [Type]"][, .(Amount = sum(Amount)), by = .(Timestep, Stratum = FromStratumId, Class = FromStateClassId)]
  s <- as.data.table(datasheet(R, "stsim_OutputStratumState", lookupsAsFactors = FALSE))[Timestep == 1, .(cells = sum(Amount)), by = .(Stratum = StratumId, Class = StateClassId)]
  z <- merge(o, s, by = c("Stratum", "Class"))[, m := Amount / cells / 10]; merge(z, x[, .(Stratum, Class, Timestep, expected)], by = c("Stratum", "Class", "Timestep")) }
S3 <- scenario(P, "0.5 alone", sourceScenario = S); sv(data.table(FlowGroupId = "Net Growth", Value = 0.5), "stsim_FlowMultiplier", S3)
z3 <- mult(run(S3)); cat(sprintf("0.5 alone:            %d of %d rows = 0.5\n", sum(abs(z3$m - 0.5) < 1e-6), nrow(z3)))
# a second group holding the same flow type: CO2 on it, 0.5 on the first (the Build's [Type] rows vs stage 11's Total rows)
S4 <- scenario(P, "0.5 and CO2 on two groups", sourceScenario = S)
sv(data.table(Name = c("Net Growth", "Net Growth: Total")), "stsim_FlowGroup")
sv(data.table(FlowTypeId = "Growth", FlowGroupId = c("Net Growth", "Net Growth: Total"), Value = 1), "stsim_FlowTypeGroupMembership", S4)
sv(rbind(data.table(FlowGroupId = "Net Growth", Value = 0.5), rbind(a, b, cc)[, `:=`(FlowGroupId = "Net Growth: Total", FlowMultiplierTypeId = "CO2")], fill = TRUE), "stsim_FlowMultiplier", S4)
z4 <- mult(run(S4)); cat(sprintf("two groups:           %d of %d rows = 0.5 x band multiplier; %d of %d = band multiplier alone\n",
                                 sum(abs(z4$m - 0.5 * z4$expected) < 1e-6), nrow(z4), sum(abs(z4$m - z4$expected) < 1e-6), nrow(z4)))
print(head(z3[order(Class, Timestep)], 4)); print(head(z4[order(Class, Timestep)], 4))
print(as.data.table(datasheet(S3, "stsim_FlowMultiplier", lookupsAsFactors = FALSE)))
