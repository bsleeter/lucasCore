# =============================================================================
# 01-flow-row-precedence.R - how ST-Sim combines a flow pathway row for a specific state class with a blank-class row for the same
# transition-triggered flow (to-do 19: per-forest-type high-severity fire snag shares need class rows beside the blank event rows)
# =============================================================================
# A throwaway plain stsim library (no lucasCore, so no package hooks), non-spatial, 1000 cells (allocated at random) in state classes A and B, a "Fire"
# transition with probability 1 at timestep 1, stocks Live (100 at start), Snag and Atm. Fire's flow rows:
#   blank class   Live -> Snag  Mortality  0.5
#   blank class   Live -> Atm   Emission   0.3
#   class A       Live -> Snag  Mortality  0.2
# If class rows are added to blank rows, cell A ends with Snag 70; if a class row replaces the blank row of the same pair, Snag 20 and
# Atm 30; if any class row hides every blank row of the event for that class, Snag 20 and Atm 0. Class B shows the blank rows alone. Stocks are reported per unit area of each class.
# Usage: Rscript dev/stsim/01-flow-row-precedence.R   (writes dev/stsim/flow-row-precedence.ssim, deleted and rebuilt each run)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim) })
f <- "F:/lucasCore/dev/stsim/flow-row-precedence.ssim"; unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
L <- ssimLibrary(f, packages = "stsim"); P <- rsyncrosim::project(L, "Definitions"); S <- scenario(P, "Precedence test")
sv <- function(x, d) saveDatasheet(if (grepl("^stsim_(Stratum|StateLabel|StateClass|TransitionType|StockType|FlowType|StateAttributeType)$", d)) P else S, x, d)
sv(data.frame(Name = "S"), "stsim_Stratum")
sv(data.frame(Name = c("A", "B")), "stsim_StateLabelX"); sv(data.frame(Name = "All"), "stsim_StateLabelY")
sv(data.frame(Name = c("A:All", "B:All"), StateLabelXId = c("A", "B"), StateLabelYId = "All"), "stsim_StateClass")
sv(data.frame(Name = "Fire"), "stsim_TransitionType")
sv(data.frame(Name = c("Live", "Snag", "Atm")), "stsim_StockType"); sv(data.frame(Name = c("Mortality", "Emission")), "stsim_FlowType")
sv(data.frame(Name = "LiveInit"), "stsim_StateAttributeType")
sv(data.frame(MinimumTimestep = 0, MaximumTimestep = 1, MinimumIteration = 1, MaximumIteration = 1, IsSpatial = FALSE), "stsim_RunControl")
sv(data.frame(StratumIdSource = "S", StateClassIdSource = c("A:All", "B:All"), Location = c("A1", "B1")), "stsim_DeterministicTransition")
sv(data.frame(StratumIdSource = "S", StateClassIdSource = c("A:All", "B:All"), StateClassIdDest = c("A:All", "B:All"), TransitionTypeId = "Fire", Probability = 1), "stsim_Transition")
sv(data.frame(TotalAmount = 1000, NumCells = 1000, CalcFromDist = FALSE), "stsim_InitialConditionsNonSpatial")
sv(data.frame(StratumId = "S", StateClassId = c("A:All", "B:All"), AgeMin = 50, AgeMax = 50, RelativeAmount = 1), "stsim_InitialConditionsNonSpatialDistribution")
sv(data.frame(StateAttributeTypeId = "LiveInit", Value = 100), "stsim_StateAttributeValue")
sv(data.frame(StockTypeId = "Live", StateAttributeTypeId = "LiveInit"), "stsim_InitialStockNonSpatial")
sv(data.frame(StockTypeId = c("Live", "Snag", "Atm"), Location = c("A1", "B1", "C1")), "stsim_FlowPathwayDiagram")
sv(data.frame(FromStateClassId = c(NA, NA, "A:All"), FromStockTypeId = "Live", ToStockTypeId = c("Snag", "Atm", "Snag"), TransitionGroupId = "Fire [Type]",
              FlowTypeId = c("Mortality", "Emission", "Mortality"), Multiplier = c(0.5, 0.3, 0.2)), "stsim_FlowPathway")
sv(data.frame(SummaryOutputSC = TRUE, SummaryOutputSCTimesteps = 1, SummaryOutputTR = TRUE, SummaryOutputTRTimesteps = 1), "stsim_OutputOptions")
sv(data.frame(SummaryOutputST = TRUE, SummaryOutputSTTimesteps = 1, SummaryOutputFL = TRUE, SummaryOutputFLTimesteps = 1), "stsim_OutputOptionsStockFlow")
sv(data.frame(StageNameId = "ST-Sim", RunOrder = 1), "core_Pipeline")
per_area <- function(R) { st <- datasheet(R, "stsim_OutputStock"); sc <- datasheet(R, "stsim_OutputStratumState")
  st <- st[st$Timestep == 1, ]; a <- aggregate(Amount ~ StateClassId, sc[sc$Timestep == 1, ], sum)
  st$PerArea <- round(st$Amount / a$Amount[match(st$StateClassId, a$StateClassId)], 2); st[order(st$StateClassId, st$StockGroupId), c("StateClassId", "StockGroupId", "PerArea")] }
R <- run(S); cat("\nStocks per unit area, default flow order:\n"); print(per_area(R))

# the same with lucasCore's flow order settings (equal ranks, applied simultaneously: src/0-stock-flow-definitions.R) - without them
# ST-Sim applies an event's flows from one stock one after another, each on what the previous ones left
S2 <- scenario(P, "Precedence test, simultaneous", sourceScenario = S)
saveDatasheet(S2, data.frame(FlowTypeId = c("Mortality", "Emission"), Order = 1), "stsim_FlowOrder")
saveDatasheet(S2, data.frame(ApplyBeforeTransitions = FALSE, ApplyEquallyRankedSimultaneously = TRUE), "stsim_FlowOrderOptions")
R2 <- run(S2); cat("\nStocks per unit area, equal ranks applied simultaneously:\n"); print(per_area(R2))

# age rows (lucasCore's fire rows differ for stands 0-10 and 11+): blank Live -> Snag 0.5 from age 0 and 0.6 from age 11, class A 0.2
# from age 11 only; stands of age 5 and 50. Expected if a class row replaces the blank row of the same pair and age: A-5 50, A-50 20,
# B-5 50, B-50 60.
for (age in c(5, 50)) {
  S3 <- scenario(P, sprintf("Precedence test, ages, stand age %d", age), sourceScenario = S2)
  saveDatasheet(S3, data.frame(StratumId = "S", StateClassId = c("A:All", "B:All"), AgeMin = age, AgeMax = age, RelativeAmount = 1), "stsim_InitialConditionsNonSpatialDistribution")
  saveDatasheet(S3, data.frame(FromStateClassId = c(NA, NA, NA, "A:All"), FromAgeMin = c(0, 11, NA, 11), FromStockTypeId = "Live", ToStockTypeId = c("Snag", "Snag", "Atm", "Snag"),
                               TransitionGroupId = "Fire [Type]", FlowTypeId = c("Mortality", "Mortality", "Emission", "Mortality"), Multiplier = c(0.5, 0.6, 0.3, 0.2)), "stsim_FlowPathway")
  cat(sprintf("\nStocks per unit area, age rows, stand age %d:\n", age)); print(per_area(run(S3)))
}
