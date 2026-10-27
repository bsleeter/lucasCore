# =============================================================================
# 02-stratum-row-precedence.R - how ST-Sim combines transition-triggered flow pathway rows for a stratum, a state class, both, or
# neither (to-do 21 step 5: Disturbance Flows rows can name an ecodivision as well as a forest type)
# =============================================================================
# As 01-flow-row-precedence.R (plain stsim library, non-spatial, Fire at timestep 1, Live 100 at start, equal flow ranks applied
# simultaneously), with two strata S and T and classes A and B. Fire's rows:
#   run 1   blank Live -> Snag 0.5, blank Live -> Atm 0.3, class A Live -> Snag 0.2, stratum S + class A Live -> Snag 0.1
#           most specific row of a pair wins:   S-A Snag 10 Atm 30 | T-A Snag 20 Atm 30 | S-B 50 30 | T-B 50 30
#   run 2   run 1 + stratum S (blank class) Live -> Snag 0.4
#           if stratum + blank class ranks below class: S-A 10 | T-A 20 | S-B 40 | T-B 50
# Usage: Rscript dev/stsim/02-stratum-row-precedence.R   (writes dev/stsim/stratum-row-precedence.ssim, rebuilt each run)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim) })
f <- "F:/lucasCore/dev/stsim/stratum-row-precedence.ssim"; unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
L <- ssimLibrary(f, packages = "stsim"); P <- rsyncrosim::project(L, "Definitions"); S <- scenario(P, "Stratum precedence")
sv <- function(x, d) saveDatasheet(if (grepl("^stsim_(Stratum|StateLabel|StateClass|TransitionType|StockType|FlowType|StateAttributeType)$", d)) P else S, x, d)
sv(data.frame(Name = c("S", "T")), "stsim_Stratum")
sv(data.frame(Name = c("A", "B")), "stsim_StateLabelX"); sv(data.frame(Name = "All"), "stsim_StateLabelY")
sv(data.frame(Name = c("A:All", "B:All"), StateLabelXId = c("A", "B"), StateLabelYId = "All"), "stsim_StateClass")
sv(data.frame(Name = "Fire"), "stsim_TransitionType")
sv(data.frame(Name = c("Live", "Snag", "Atm")), "stsim_StockType"); sv(data.frame(Name = c("Mortality", "Emission")), "stsim_FlowType")
sv(data.frame(Name = "LiveInit"), "stsim_StateAttributeType")
sv(data.frame(MinimumTimestep = 0, MaximumTimestep = 1, MinimumIteration = 1, MaximumIteration = 1, IsSpatial = FALSE), "stsim_RunControl")
sv(data.frame(StateClassIdSource = c("A:All", "B:All"), Location = c("A1", "B1")), "stsim_DeterministicTransition")
sv(data.frame(StateClassIdSource = c("A:All", "B:All"), StateClassIdDest = c("A:All", "B:All"), TransitionTypeId = "Fire", Probability = 1), "stsim_Transition")
sv(data.frame(TotalAmount = 4000, NumCells = 4000, CalcFromDist = FALSE), "stsim_InitialConditionsNonSpatial")
sv(data.frame(StratumId = c("S", "S", "T", "T"), StateClassId = c("A:All", "B:All", "A:All", "B:All"), AgeMin = 50, AgeMax = 50, RelativeAmount = 1), "stsim_InitialConditionsNonSpatialDistribution")
sv(data.frame(StateAttributeTypeId = "LiveInit", Value = 100), "stsim_StateAttributeValue")
sv(data.frame(StockTypeId = "Live", StateAttributeTypeId = "LiveInit"), "stsim_InitialStockNonSpatial")
sv(data.frame(StockTypeId = c("Live", "Snag", "Atm"), Location = c("A1", "B1", "C1")), "stsim_FlowPathwayDiagram")
sv(data.frame(FlowTypeId = c("Mortality", "Emission"), Order = 1), "stsim_FlowOrder")
sv(data.frame(ApplyBeforeTransitions = FALSE, ApplyEquallyRankedSimultaneously = TRUE), "stsim_FlowOrderOptions")
sv(data.frame(SummaryOutputSC = TRUE, SummaryOutputSCTimesteps = 1, SummaryOutputTR = TRUE, SummaryOutputTRTimesteps = 1), "stsim_OutputOptions")
sv(data.frame(SummaryOutputST = TRUE, SummaryOutputSTTimesteps = 1, SummaryOutputFL = TRUE, SummaryOutputFLTimesteps = 1), "stsim_OutputOptionsStockFlow")
sv(data.frame(StageNameId = "ST-Sim", RunOrder = 1), "core_Pipeline")
rows1 <- data.frame(FromStratumId = c(NA, NA, NA, "S"), FromStateClassId = c(NA, NA, "A:All", "A:All"), FromStockTypeId = "Live", ToStockTypeId = c("Snag", "Atm", "Snag", "Snag"),
                    TransitionGroupId = "Fire [Type]", FlowTypeId = c("Mortality", "Emission", "Mortality", "Mortality"), Multiplier = c(0.5, 0.3, 0.2, 0.1))
per_area <- function(R) { st <- datasheet(R, "stsim_OutputStock"); sc <- datasheet(R, "stsim_OutputStratumState")
  st <- st[st$Timestep == 1, ]; sc <- sc[sc$Timestep == 1, ]; a <- aggregate(Amount ~ StratumId + StateClassId, sc, sum)
  st$PerArea <- round(st$Amount / a$Amount[match(paste(st$StratumId, st$StateClassId), paste(a$StratumId, a$StateClassId))], 2)
  st <- st[st$StockGroupId != "Live [Type]", ]; st[order(st$StratumId, st$StateClassId, st$StockGroupId), c("StratumId", "StateClassId", "StockGroupId", "PerArea")] }
saveDatasheet(S, rows1, "stsim_FlowPathway"); cat("\nRun 1 (blank, class A, stratum S + class A):\n"); print(per_area(run(S)), row.names = FALSE)
S2 <- scenario(P, "Stratum precedence, stratum-only row", sourceScenario = S)
saveDatasheet(S2, rbind(rows1, data.frame(FromStratumId = "S", FromStateClassId = NA, FromStockTypeId = "Live", ToStockTypeId = "Snag", TransitionGroupId = "Fire [Type]",
                                          FlowTypeId = "Mortality", Multiplier = 0.4)), "stsim_FlowPathway")
cat("\nRun 2 (+ stratum S, blank class):\n"); print(per_area(run(S2)), row.names = FALSE)
