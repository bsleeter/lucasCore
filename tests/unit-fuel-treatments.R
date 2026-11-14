# Unit test: fuel treatments (tools/make_fuel_treatments.R, src/fuel-treatments.R). Three treatment types on upland forest that keep
# the forest type and age; the Fuel Treatments rows become area targets on one set of strata keys; the severity shift and the
# retreatment interval read each type's own time since treatment; the age window applies to the rest; costs as transition attributes.
# Usage: Rscript tests/unit-fuel-treatments.R   (from the package folder)
suppressPackageStartupMessages(library(data.table))
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
source(file.path("src", "management.R")); source(file.path("src", "fuel-treatments.R"))
say <- function(...) invisible(NULL); fail <- function(...) stop(sprintf(...), call. = FALSE)
lev_col <- c(Primary = "StratumId", Secondary = "SecondaryStratumId", Tertiary = "TertiaryStratumId")

# defaults
ty <- fread(file.path("defaults", "stsim", "stsim_TransitionType.csv")); tg <- fread(file.path("defaults", "stsim", "stsim_TransitionTypeGroup.csv"))
check("three treatment types, Ids 1300-1302, in group Fuel Treatment", all(FT_TYPES %in% ty$Name) && setequal(ty[Name %in% FT_TYPES, Id], 1300:1302) &&
      all(tg[TransitionTypeId %in% FT_TYPES, TransitionGroupId] == "Fuel Treatment"))
pw <- fread(file.path("defaults", "transitions", "pathways", "fuel-treatments.csv"), na.strings = "")
up <- grep("^Forest: ", fread(file.path("defaults", "stsim", "stsim_StateClass.csv"))$Name, value = TRUE)
check("from every upland forest class to itself, no age reset, for each type", nrow(pw) == length(up) * 3 && all(pw$StateClassIdDest == pw$StateClassIdSource) &&
      setequal(pw$StateClassIdSource, up) && all(pw$AgeReset == "No") && all(is.na(pw$TSTRelative)))

check("treatment names, labels and codes map to one key each", identical(unname(ft_key(c(FT_TYPES, "Mechanical thinning", "Prescribed burn", "Thin and burn", "1", "2", "3"))),
      c("Thin", "Burn", "ThinBurn", "Thin", "Burn", "ThinBurn", "Thin", "Burn", "ThinBurn")))
fl <- fread(file.path("defaults", "fuel-treatments", "flows.csv"))
check("treatment flows: no pool loses more than its stock", all(fl[, sum(Multiplier), by = .(Treatment, FromStockTypeId)]$V1 <= 1 + 1e-9))
evf <- fread(file.path("defaults", "stockflow", "event-pathways.csv"), na.strings = "")[grepl("^Fuel Treatment", TransitionGroupId)]
check("the flows are in the event pathways, on the types' [Type] groups", nrow(evf) == nrow(fl) && setequal(unique(evf$TransitionGroupId), FT_GROUPS))
check("thinning's merchantable wood to the forestry sector (the timber revenue's share): 0.2 thinning, 0.2 thin and burn", all(abs(ft_removal(file.path("defaults", "fuel-treatments", "flows.csv")) - 0.2) < 1e-9))
fe <- fread(file.path("defaults", "fuel-treatments", "effects.csv")); fe[, k := ft_key(Treatment)]
check("effects: every treatment, windows that do not overlap, multipliers 0-1, thin and burn the strongest at first",
      setequal(unique(fe$k), names(FT_TYPES)) && all(fe[, all(diff(TSTMin) > 0 & TSTMin[-1] > TSTMax[-.N]), by = k]$V1) && all(fe$High > 0 & fe$High <= 1 & fe$Medium > 0 & fe$Medium <= 1) &&
      fe[k == "ThinBurn" & TSTMin == 0, High] < fe[k == "Burn" & TSTMin == 0, High] && fe[k == "Burn" & TSTMin == 0, High] < fe[k == "Thin" & TSTMin == 0, High])
fc <- fread(file.path("defaults", "fuel-treatments", "costs.csv")); cdm <- management_cost_defaults(file.path("defaults", "management", "costs.csv"))
check("costs: national rows for each treatment, regions among the cost regions, Low <= Central <= High", setequal(fc[Region == "All", ft_key(Treatment)], names(FT_TYPES)) &&
      all(setdiff(fc$Region, "All") %in% cdm$regions$Region) && all(fc[, Low <= Central & Central <= High]))
st <- fread(file.path("defaults", "fuel-treatments", "settings.csv")); check("settings for every treatment", setequal(ft_key(st$Treatment), names(FT_TYPES)))

# 6 land cells: secondary S1 (1-3), S2 (4-6); upland forest on all but cell 6
cells <- data.table(Primary = "Eco", Secondary = c("S1", "S1", "S1", "S2", "S2", "S2"), Tertiary = c("A", "A", "B", "A", "B", "B"), w = c(1, 1, 1, 1, 1, 0))
eff <- data.table(TreatmentKey = rep(c("Thin", "Burn", "ThinBurn"), each = 2), TSTMin = rep(c(0L, 11L), 3), TSTMax = rep(c(10L, 20L), 3),
                  High = c(0.6, 0.8, 0.5, 0.9, 0.3, 0.6), Medium = c(0.8, 0.9, 0.7, 0.95, 0.5, 0.8))
shares <- c(High = 0.3, Medium = 0.2, Low = 0.5)
run <- function(ft, tile = NA_character_, costs = NULL) { r <- fuel_treatment_rows(ft, 2023L, 2030L, say, fail)
  fuel_treatment_targets(r, 1985L, 2023L, 2030L, cells, lev_col, tile, eff, shares, say, fail, costs) }
r1 <- run(data.table(TreatmentId = "Thin and burn", Amount = 50))
t1 <- r1$targets[Timestep == 2024]
check("thin and burn 50 a year over the study area; the other types zero; a zero row at the historical start", sum(t1[TransitionGroupId == FT_GROUPS[["ThinBurn"]], Amount]) == 50 &&
      all(t1[TransitionGroupId != FT_GROUPS[["ThinBurn"]], Amount] == 0) && all(r1$targets[Timestep == 1985, Amount] == 0) && nrow(r1$targets[Timestep == 2024]) == 3)
sv <- r1$multipliers[!is.na(TSTGroupId) & TSTGroupId == FT_GROUPS[["ThinBurn"]] & TransitionGroupId %in% FT_SEV]
check("the severity shift on the three fire severity types, by years since thin and burn", nrow(sv) == 6 &&
      sv[TransitionGroupId == FT_SEV[["High"]] & TSTMin == 0, Amount] == 0.3 && sv[TransitionGroupId == FT_SEV[["Medium"]] & TSTMin == 11, Amount] == 0.8)
lo <- sv[TransitionGroupId == FT_SEV[["Low"]] & TSTMin == 0, Amount]
check("low severity rises so the expected burned area holds: shares 0.3 / 0.2 / 0.5 x 0.3 / 0.5 / lo sum to 1", abs(0.3 * 0.3 + 0.2 * 0.5 + 0.5 * lo - 1) < 1e-3)
ow <- r1$multipliers[TransitionGroupId == FT_GROUPS[["ThinBurn"]]]
check("retreatment first: 0 while its own clock is under 10 years, then the age window from 20", !is.na(ow$TSTGroupId[1]) && ow$TSTMax[1] == 9 && ow$Amount[1] == 0 &&
      identical(ow[is.na(TSTGroupId), Amount], c(0, 1)) && ow[is.na(TSTGroupId) & Amount == 1, AgeMin] == 20)
check("its own TST group: each treatment type tracks its [Type] group", identical(r1$tst$TransitionTypeId, unname(FT_TYPES["ThinBurn"])) && identical(r1$tst$TransitionGroupId, unname(FT_GROUPS["ThinBurn"])))
r2 <- run(data.table(TreatmentId = c("Mechanical thinning", "Prescribed burn", "Thin and burn"), Amount = 10))
check("the most effective treatment's severity rows first: thin and burn, burn, thinning", identical(unique(r2$multipliers[TransitionGroupId %in% FT_SEV, TSTGroupId]), unname(FT_GROUPS[FT_ORDER])))
r3 <- run(data.table(TreatmentId = "Prescribed burn", Amount = 30, SecondaryStratumId = "S2", StartYear = 2026L))
t3 <- r3$targets[TransitionGroupId == FT_GROUPS[["Burn"]]]
check("by secondary unit: S2 gets 30 a year from 2026, S1 none, none before", all(t3[Timestep >= 2026 & SecondaryStratumId == "S2", Amount] == 30) &&
      all(t3[SecondaryStratumId == "S1", Amount] == 0) && all(t3[Timestep %in% 2024:2025, Amount] == 0))
r4 <- run(data.table(TreatmentId = "Prescribed burn", Amount = 30, TertiaryStratumId = "B"))
t4 <- r4$targets[TransitionGroupId == FT_GROUPS[["Burn"]] & Timestep == 2024]
check("by tertiary unit B: keys on tertiary units only, B 30, A 0", !"SecondaryStratumId" %in% names(t4) && t4[TertiaryStratumId == "B", Amount] == 30 && t4[TertiaryStratumId == "A", Amount] == 0)
r5 <- run(data.table(TreatmentId = "Prescribed burn", Amount = c(30, 10), TertiaryStratumId = c("B", NA), SecondaryStratumId = c(NA, "S1")))
t5 <- r5$targets[TransitionGroupId == FT_GROUPS[["Burn"]] & Timestep == 2024]
check("two levels named: secondary x tertiary keys; B's 30 by upland forest (S1-B 1 cell, S2-B 1: 15 each), S1's 10 over its 3 forest cells", setequal(r5$keys, c("Secondary", "Tertiary")) &&
      abs(t5[SecondaryStratumId == "S1" & TertiaryStratumId == "B", Amount] - (15 + 10 / 3)) < 1e-9 && abs(t5[SecondaryStratumId == "S2" & TertiaryStratumId == "B", Amount] - 15) < 1e-9 &&
      abs(t5[SecondaryStratumId == "S1" & TertiaryStratumId == "A", Amount] - 20 / 3) < 1e-9)
check("with tiles a row without the tile unit stops", inherits(try(run(data.table(TreatmentId = "Prescribed burn", Amount = 5), tile = "Secondary"), silent = TRUE), "try-error"))
check("two rows of one treatment with different stand ages stop", inherits(try(run(data.table(TreatmentId = "Prescribed burn", Amount = 5, MinAge = c(20, 30))), silent = TRUE), "try-error"))
check("no treatment named stops", inherits(try(run(data.table(Amount = 5)), silent = TRUE), "try-error"))
check("the summary: one row per page row", nrow(r2$summary) == 3 && all(r2$summary$AreaPerYear == 10))

# costs and budget
cd <- management_cost_defaults(file.path("defaults", "management", "costs.csv"))
ftc <- data.table(Region = c("All", "All", "All", "California"), Treatment = c("Thin", "Burn", "ThinBurn", "Burn"), Central = c(2000, 300, 2500, 500), Low = c(1000, 100, 1500, 200), High = c(4000, 800, 5000, 1200))
rb <- fuel_treatment_rows(data.table(TreatmentId = "Prescribed burn", Budget = 15000), 2023L, 2030L, say, fail)
cc <- fuel_treatment_costs(rb, ftc, cd, "Mediterranean", fail)
check("cost: the region's default (California burn 500), a Beta per iteration", cc$per_area == 500 && cc$values$Value == 500 && cc$values$DistributionType == "Beta" && cc$values$TransitionGroupId == FT_GROUPS[["Burn"]])
rbt <- fuel_treatment_targets(rb, 1985L, 2023L, 2030L, cells, lev_col, NA_character_, eff, shares, say, fail, cc)
check("budget: 15,000 USD a year at 500 = 30 a year", abs(sum(rbt$targets[TransitionGroupId == FT_GROUPS[["Burn"]] & Timestep == 2024, Amount]) - 30) < 1e-9)
c2 <- fuel_treatment_costs(fuel_treatment_rows(data.table(TreatmentId = "Mechanical thinning", Amount = 5), 2023L, 2030L, say, fail), ftc, cd, "Prairie", fail)
check("a region without its own row takes the national (thinning 2000)", c2$per_area == 2000)

cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
