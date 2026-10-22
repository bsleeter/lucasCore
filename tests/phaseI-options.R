# =============================================================================
# phaseI-options.R - Carbon Options (three dead organic matter choices) and the Land Cover Crosswalks sheet, on a starter copy
# =============================================================================
# A: the starter's Build scenario (crosswalk sheet prefilled, Carbon Options = calibrated) for the study area, stages 1, 5, 2, 3, 4, 8,
#    with growth curves copied from a library that has them. B, C: depend on A and rerun stages 3, 4, 8 with options 2 and 3.
# D: stages 1, 5 with one crosswalk row edited (EVT 2016 7030 -> California Mixed Conifer); compare its state classes with A.
# Usage: Rscript tests/phaseI-options.R [--curves=dev/libs/lucasCore-starter-County-Placer-California.ssim] [--units="County: Placer California"]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
D <- "F:/lucasCore/dev/libs"; UNITS <- opt("units", "County: Placer California")
CURVES <- normalizePath(opt("curves", file.path(D, "lucasCore-starter-County-Placer-California.ssim")), winslash = "/")
f <- file.path(D, "lucasCore-options.ssim"); unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
file.copy("F:/lucasCore/Starter/LUCAS Core (CONUS).ssim", f)
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE))
sfd <- sc[Name == "Stock-Flow Definitions", ScenarioId]
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
show <- function(R, name) { lg <- logl(R); cat(sprintf("\n==== %s\n", name))
  cat(paste(unique(lg[grepl("Carbon Options|Land Cover Crosswalks|  EVT|Soil vs gSSURGO|Decay calibration took|crosswalk row|Initial carbon|Total time: [0-9]|Failure|rror", lg) & !grepl("post processing|saving results", lg)]), collapse = "\n"), "\n")
  v <- as.data.table(datasheet(R, "lucasCore_OutputValidation")); ok <- nrow(v) > 0 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))
  if (!ok && nrow(v)) print(v[Status != "Pass"]); ok }
units <- data.frame(UnitId = trimws(strsplit(UNITS, ",")[[1]]))

B <- scenario(L, sc[Name == "Build", ScenarioId])
cat("starter Build scenario: crosswalk rows", nrow(datasheet(B, "lucasCore_LandCoverCrosswalk")), "; carbon option", datasheet(B, "lucasCore_CarbonOptions", lookupsAsFactors = FALSE)$DeadOrganicMatterModel, "\n")
saveDatasheet(B, units, "lucasCore_StudyArea")
go <- as.data.table(datasheet(B, "lucasCore_GrowthOptions", lookupsAsFactors = FALSE)); go[, `:=`(CurveSource = 2L, CurveLibrary = CURVES)]; saveDatasheet(B, as.data.frame(go), "lucasCore_GrowthOptions")
stA <- c("1 - Study Area and Strata", "5 - Initial Conditions", "2 - Fit Growth Curves", "3 - Carbon Flows", "4 - Spin-up and Initial Stocks", "8 - Initial Stock Maps")
saveDatasheet(B, data.frame(StageNameId = stA, RunOrder = seq_along(stA)), "core_Pipeline")
description(B) <- paste("tests/phaseI-options.R scenario A:", UNITS, "with the starter's defaults (crosswalk sheet prefilled, dead organic matter calibrated); curves copied from", CURVES)
RA <- run(B); okA <- show(RA, "A: defaults (calibrated)")

opt_run <- function(k, name) { S <- rsyncrosim::scenario(P, name); dependency(S) <- c(sfd, scenarioId(RA))
  description(S) <- sprintf("tests/phaseI-options.R: stages 3, 4, 8 on scenario A's result with Carbon Options dead organic matter = %d.", k)
  saveDatasheet(S, data.frame(DeadOrganicMatterModel = as.integer(k)), "lucasCore_CarbonOptions")
  saveDatasheet(S, data.frame(StageNameId = stA[4:6], RunOrder = 1:3), "core_Pipeline"); R <- run(S); list(R = R, ok = show(R, name)) }
rB <- opt_run(2, "B: FIA dead pools, CBM-default soil"); rC <- opt_run(3, "C: CBM defaults")

S <- rsyncrosim::scenario(P, "D: crosswalk edit")
xw <- fread("F:/lucasCore/defaults/landcover/land-cover-crosswalks.csv", na.strings = ""); xw[Source == "EVT 2016" & Code == 7030, StateClassId := "Forest: California Mixed Conifer Group"]
saveDatasheet(S, as.data.frame(xw[, .(Source, Code, Description, StateClassId, Note)]), "lucasCore_LandCoverCrosswalk")
saveDatasheet(S, units, "lucasCore_StudyArea"); saveDatasheet(S, data.frame(StageNameId = stA[1:2], RunOrder = 1:2), "core_Pipeline")
description(S) <- "tests/phaseI-options.R scenario D: stages 1, 5 with EVT 2016 7030 (Lower Montane Conifer) mapped to California Mixed Conifer instead of Western Oak."
RD <- run(S); okD <- show(RD, "D: crosswalk edit")

# comparisons
ss <- function(R) as.data.table(datasheet(R, "lucasCore_OutputInitialStockSummary", lookupsAsFactors = FALSE))
cmp <- merge(merge(ss(RA)[, .(StateClassId, Cells, Live, Soil_A = Soil)], ss(rB$R)[, .(StateClassId, Soil_B = Soil)], by = "StateClassId"),
             ss(rC$R)[, .(StateClassId, Soil_C = Soil, Dom_C = Dom)], by = "StateClassId")
cat("\nSoil (BG slow, Mg C/ha) by class: A calibrated, B CBM-default soil, C CBM defaults\n"); print(cmp[grepl("^Forest", StateClassId)][order(-Cells)])
sca <- as.data.table(datasheet(RA, "lucasCore_OutputStateClassSummary", lookupsAsFactors = FALSE)); scd <- as.data.table(datasheet(RD, "lucasCore_OutputStateClassSummary", lookupsAsFactors = FALSE))
cc <- merge(sca[, .(StateClassId, A = Cells)], scd[, .(StateClassId, D = Cells)], by = "StateClassId", all = TRUE)
cat("\nState classes changed by the crosswalk edit:\n"); print(cc[is.na(A) | is.na(D) | A != D])
moved <- cc[StateClassId == "Forest: Western Oak Group", A - D] > 0 && cc[StateClassId == "Forest: California Mixed Conifer Group", D - A] > 0
ok <- okA && rB$ok && rC$ok && okD && isTRUE(moved)
cat(sprintf("\nA %s, B %s, C %s, D %s; western oak -> mixed conifer moved: %s\n", okA, rB$ok, rC$ok, okD, moved)); cat(if (ok) "OPTIONS OK\n" else "OPTIONS FAILED\n")
