# Unit test: forest management (src/forest-management.R). The page's rows reshape and rescale the harvest targets stage 9 drew, split
# them by place where a row names another strata level, narrow the harvest ages, and price the harvest (timber revenue).
# Usage: Rscript tests/unit-forest-management.R   (from the package folder)
suppressPackageStartupMessages(library(data.table))
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
source(file.path("src", "management.R")); source(file.path("src", "forest-management.R"))
say <- function(...) invisible(NULL); fail <- function(...) stop(sprintf(...), call. = FALSE)
lev_col <- c(Primary = "StratumId", Secondary = "SecondaryStratumId", Tertiary = "TertiaryStratumId")

# defaults: light selection, the 85% type gone
tt_names <- fread(file.path("defaults", "stsim", "stsim_TransitionType.csv"))$Name
check("Selection 85% is gone, light selection (Selection 20%) is there", !"Forest Harvest: Forest Selection 85%" %in% tt_names && FM_TYPES[["LIGHT"]] %in% tt_names)
ev <- fread(file.path("defaults", "stockflow", "event-pathways.csv"), na.strings = "")
rem <- function(k) ev[TransitionGroupId == FM_GROUPS[[k]] & FromStockTypeId == "Biomass: Merchantable" & ToStockTypeId == "Forestry Sector", sum(Multiplier)]
check("the removal shares match the harvest flows (0.97, 0.5, 0.2)", all(abs(c(rem("CC"), rem("SEL"), rem("LIGHT")) - FM_REMOVAL) < 1e-9))
check("no flow refers to Selection 85%", !any(grepl("85%", ev$TransitionGroupId)) && !any(grepl("85%", fread(file.path("defaults", "transitions", "pathways", "harvest.csv"))$TransitionTypeId)))
wd <- fread(file.path("defaults", "forest-management", "forest-type-wood.csv"))
fx <- unique(sub("^[^:]*: ", "", grep("Group$", grep("^(Forest|Wetland): ", fread(file.path("defaults", "stsim", "stsim_StateClass.csv"))$Name, value = TRUE), value = TRUE)))
check("every forest type group is softwood, hardwood or mixed", setequal(fx, wd$ForestType) && all(wd$Wood %in% c("Softwood", "Hardwood", "Mixed")))

# 6 land cells: secondary S1 (cells 1-3), S2 (4-6); tertiary A (1, 2, 4), B (3, 5, 6); historical clearcut 1,1,2,0,1,1 and selection 1 each
cells <- data.table(Primary = "Eco", Secondary = c("S1", "S1", "S1", "S2", "S2", "S2"), Tertiary = c("A", "A", "B", "A", "B", "B"), w_forest = 1)
cells[, (FM_GROUPS[["CC"]]) := c(1, 1, 2, 0, 1, 1)][, (FM_GROUPS[["SEL"]]) := 1]
tt <- rbind(CJ(Iteration = 1:2, Timestep = 2024:2026, SecondaryStratumId = c("S1", "S2"))[, `:=`(TransitionGroupId = FM_GROUPS[["CC"]], Amount = ifelse(SecondaryStratumId == "S1", 10, 20))],
            CJ(Iteration = 1:2, Timestep = 2024:2026, SecondaryStratumId = c("S1", "S2"))[, `:=`(TransitionGroupId = FM_GROUPS[["SEL"]], Amount = ifelse(SecondaryStratumId == "S1", 4, 6))],
            data.table(Iteration = NA_integer_, Timestep = 1985L, SecondaryStratumId = NA_character_, TransitionGroupId = FM_GROUPS[["LIGHT"]], Amount = 0))
run <- function(fm, tile = NA_character_) { r <- forest_management_rows(fm, 2023L, 2026L, say, fail); forest_management_targets(tt, r, 2023L, cells, lev_col, tile, say, fail) }
amt <- function(x, k, s = NULL, t = NULL, y = 2025L, it = 1L) { d <- x$targets[TransitionGroupId == FM_GROUPS[[k]] & Timestep == y & Iteration == it]
  if (!is.null(s)) d <- d[SecondaryStratumId == s]; if (!is.null(t)) d <- d[TertiaryStratumId == t]; sum(d$Amount) }
a1 <- run(data.table(ClearcutToSelection = 0.5))
check("half of clearcut to selection, by area: clearcut 5 / 10, selection 9 / 16", amt(a1, "CC", "S1") == 5 && amt(a1, "CC", "S2") == 10 && amt(a1, "SEL", "S1") == 9 && amt(a1, "SEL", "S2") == 16)
check("the targets keep their own keys (secondary), every type every year", identical(a1$keys, "Secondary") && all(a1$targets[, uniqueN(Timestep), by = TransitionGroupId]$V1 == 3))
a2 <- run(data.table(ClearcutToSelection = 0.5, ShiftBasis = "Volume (the same wood removed)"))
check("by volume: a clearcut hectare becomes 0.97 / 0.5 selection hectares (the same wood)", abs(amt(a2, "SEL", "S1") - (4 + 5 * 0.97 / 0.5)) < 1e-9 &&
      abs((amt(a2, "CC", "S1") * 0.97 + amt(a2, "SEL", "S1") * 0.5) - (10 * 0.97 + 4 * 0.5)) < 1e-9)
a3 <- run(data.table(LightSelection = 0.5, HarvestScale = 0.8))
check("half of selection to light selection, then x 0.8: selection 1.6, light 1.6 in S1; clearcut 8", abs(amt(a3, "SEL", "S1") - 1.6) < 1e-9 && abs(amt(a3, "LIGHT", "S1") - 1.6) < 1e-9 && abs(amt(a3, "CC", "S1") - 8) < 1e-9)
a3v <- run(data.table(LightSelection = 0.5, ShiftBasis = 2))
check("light selection by volume: a selection hectare becomes 2.5 light hectares", abs(amt(a3v, "LIGHT", "S1") - 2 * 2.5) < 1e-9)
a4 <- run(data.table(StartYear = 2026L, HarvestScale = 0))
check("a row's years only: 2025 as drawn, no harvest in 2026", amt(a4, "CC", "S1", y = 2025L) == 10 && amt(a4, "CC", y = 2026L) == 0 && amt(a4, "SEL", y = 2026L) == 0)
a5 <- run(data.table(TertiaryStratumId = "A", HarvestScale = 0))
check("a row by tertiary unit: targets on secondary x tertiary, split by the historical harvest (S1: A half, B half; S2: all B)",
      setequal(a5$keys, c("Secondary", "Tertiary")) && amt(a5, "CC", "S1", "A") == 0 && amt(a5, "CC", "S1", "B") == 5 && amt(a5, "CC", "S2", "B") == 20 && amt(a5, "CC", "S2", "A") == 0)
a6 <- run(data.table(TertiaryStratumId = "A", HarvestScale = 1))
check("split without change: each secondary unit's total stays the drawn one", amt(a6, "CC", "S1") == 10 && amt(a6, "CC", "S2") == 20 && abs(amt(a6, "SEL", "S1") - 4) < 1e-9)
check("the summary: drawn and managed area a year over the row's place", a5$summary$ClearcutBefore == 5 && a5$summary$ClearcutAfter == 0)
check("two rows on the same place and year stop", inherits(try(run(data.table(HarvestScale = c(0.5, 0.8))), silent = TRUE), "try-error"))
check("rows on different years are fine", !inherits(try(run(data.table(HarvestScale = c(0.5, 0.8), StartYear = c(2024L, 2026L), EndYear = c(2025L, 2026L))), silent = TRUE), "try-error"))
check("with spatial tiles a row without a tile unit stops", inherits(try(run(data.table(HarvestScale = 0.5), tile = "Secondary"), silent = TRUE), "try-error"))
check("ages that run backwards stop", inherits(try(forest_management_rows(data.table(ClearcutMinAge = 80, ClearcutMaxAge = 40), 2023L, 2026L, say, fail), silent = TRUE), "try-error"))

# age windows
r7 <- forest_management_rows(data.table(EndYear = 2025L, ClearcutMinAge = 60, ClearcutMaxAge = 120, SelectionMaxAge = 150, LightSelection = 0.3, SecondaryStratumId = "S1"), 2023L, 2026L, say, fail)
sm <- data.table(StratumId = NA_character_, StateClassId = c("Forest: Douglas-fir Group", "Forest: Ponderosa Pine Group"), AgeMin = c(40, 55))
m7 <- forest_management_ages(r7, 2023L, 2026L, sm, lev_col)
cc <- m7[TransitionGroupId == FM_GROUPS[["CC"]] & Timestep == 2024]
check("clearcut window 60-120: 0 below, 1 within, 0 above, in the row's unit", nrow(cc) == 3 && identical(cc$Amount, c(0, 1, 0)) && cc$AgeMin[2] == 60 && cc$AgeMax[2] == 120 && all(cc$SecondaryStratumId == "S1"))
check("back to 1 after the row's end (2026)", nrow(m7[TransitionGroupId == FM_GROUPS[["CC"]] & Timestep == 2026]) == 1 && m7[TransitionGroupId == FM_GROUPS[["CC"]] & Timestep == 2026, Amount] == 1)
lt <- m7[TransitionGroupId == FM_GROUPS[["LIGHT"]] & Timestep == 2024 & Amount == 1]
check("light selection: per forest type, from Forest Selection's minimum age, to the selection maximum", setequal(lt$StateClassId, sm$StateClassId) &&
      lt[StateClassId == "Forest: Ponderosa Pine Group", AgeMin] == 55 && all(lt$AgeMax == 150))
check("selection: only a maximum (old forest), 1 below it", identical(m7[TransitionGroupId == FM_GROUPS[["SEL"]] & Timestep == 2024, Amount], c(1, 0)) &&
      m7[TransitionGroupId == FM_GROUPS[["SEL"]] & Timestep == 2024 & Amount == 1, AgeMin] == 0)

# timber revenue
td <- tempfile(); dir.create(td)
fwrite(data.table(Region = c("All", "All", "California", "California"), Wood = c("Softwood", "Hardwood", "Softwood", "Hardwood"),
                  Central = c(40, 30, 50, 20), Low = c(20, 15, 30, 10), High = c(80, 60, 90, 40)), file.path(td, "stumpage.csv"))
invisible(file.copy(file.path("defaults", "forest-management", "forest-type-wood.csv"), td))
rv <- forest_management_revenue_defaults(td); cd <- management_cost_defaults(file.path("defaults", "management", "costs.csv"))
vc <- rbind(data.table(StratumId = "Mediterranean", StateClassId = "Forest: Douglas-fir Group", Age = c(0, 50, 100, 200), MerchantableVolume = c(0, 200, 400, 500)),
            data.table(StratumId = "Prairie", StateClassId = "Forest: Oak/Pine Group", Age = c(0, 100), MerchantableVolume = c(0, 100)))
rr <- forest_management_revenue(vc, rv, cd, c("Mediterranean", "Prairie"), 2023L)
v55 <- rr[StateClassId == "Forest: Douglas-fir Group" & TransitionGroupId == FM_GROUPS[["CC"]] & AgeMin == 50, Value]
check("clearcut revenue = volume at the band's middle (55: 220 m3) x 0.97 x California softwood (50)", abs(v55 - 220 * 0.97 * 50) < 0.01)
check("selection 0.5 and light selection 0.2 of the same", abs(rr[StateClassId == "Forest: Douglas-fir Group" & TransitionGroupId == FM_GROUPS[["SEL"]] & AgeMin == 50, Value] - 220 * 0.5 * 50) < 0.01 &&
      abs(rr[StateClassId == "Forest: Douglas-fir Group" & TransitionGroupId == FM_GROUPS[["LIGHT"]] & AgeMin == 50, Value] - 220 * 0.2 * 50) < 0.01)
check("mixed wood (Oak/Pine) outside a priced region: the mean of the national softwood and hardwood (35)", abs(rr[StateClassId == "Forest: Oak/Pine Group" & TransitionGroupId == FM_GROUPS[["CC"]] & AgeMin == 50, Value] - 55 * 0.97 * 35) < 0.01)
check("a Beta per value, sampled per iteration, its range the price's scaled", all(rr$DistributionType == "Beta") && all(rr$DistributionFrequencyId == "Iteration Only") &&
      abs(rr[StateClassId == "Forest: Douglas-fir Group" & TransitionGroupId == FM_GROUPS[["CC"]] & AgeMin == 50, DistributionMin] - v55 * 30 / 50) < 0.01)
check("bands 0-9 to 150+, the last open; per ecodivision; a band with no volume left out", max(rr$AgeMin) == 150 && is.na(rr[AgeMin == 150, AgeMax][1]) && setequal(rr$StratumId, c("Mediterranean", "Prairie")) && !any(rr$AgeMin == 0 & rr$Value <= 0))
check("per library unit (acres: / 2.471)", abs(forest_management_revenue(vc, forest_management_revenue_defaults(td, 2.471), cd, "Mediterranean", 2023L)[TransitionGroupId == FM_GROUPS[["CC"]] & AgeMin == 50, Value] - v55 / 2.471) < 0.01)

pd <- forest_management_revenue_defaults(file.path("defaults", "forest-management"))$price
check("stumpage defaults: softwood and hardwood for national and every cost region, Low <= Central <= High",
      setequal(unique(pd$Region), c("All", unique(cd$regions$Region))) && all(pd[, .N, by = Region]$N == 2) && all(pd[, Low <= Central & Central <= High]))

cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
