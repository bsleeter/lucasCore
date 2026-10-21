# =============================================================================
# phaseF-pipeline.R - the whole build pipeline for a study area in a new library: stages 1, 5, 2, 3, 4, 6, 7, 8
# =============================================================================
# Strata and initial conditions first (so stage 3 calibrates with stage 5's return intervals and gSSURGO targets), then growth curves,
# carbon flows, spin-up, historical transitions, climate multipliers and initial stock maps. The result scenario holds every input an
# ST-Sim historical run needs except Run Control.
# Usage: Rscript tests/phaseF-pipeline.R [--units="County: Placer California"]  (Study Area units, comma-separated) [--dir=dev/libs]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
D <- opt("dir", "F:/lucasCore/dev/libs"); UNITS <- opt("units", "County: Placer California"); dir.create(D, showWarnings = FALSE, recursive = TRUE)
f <- file.path(D, sprintf("lucasCore-pipeline-%s.ssim", gsub("[^A-Za-z0-9]+", "-", substr(UNITS, 1, 30))))
unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
if (system2(file.path(R.home("bin"), "Rscript.exe"), c("tools/new-library.R", shQuote(f)), stdout = FALSE)) stop("new-library.R failed")
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- scenario(L, summary = TRUE)
S <- rsyncrosim::scenario(P, paste("Build:", UNITS)); dependency(S) <- sc$ScenarioId[sc$Name == "Stock-Flow Definitions"]
description(S) <- paste("Full build pipeline (tests/phaseF-pipeline.R) for", UNITS, "with package defaults: stages 1 (strata), 5 (initial conditions),",
                        "2 (growth curves), 3 (carbon flows, calibrated with stage 5's return intervals and gSSURGO targets), 4 (spin-up), 6 (historical",
                        "transitions), 7 (climate multipliers, historical PRISM, tree-ring forest growth) and 8 (initial stock maps). Depends on Stock-Flow Definitions.")
saveDatasheet(S, data.frame(UnitId = trimws(strsplit(UNITS, ",")[[1]])), "lucasCore_StudyArea")
stages <- c("1 - Study Area and Strata", "5 - Initial Conditions", "2 - Fit Growth Curves", "3 - Carbon Flows", "4 - Spin-up and Initial Stocks",
            "6 - Historical Transitions", "7 - Climate Multipliers", "8 - Initial Stock Maps")
saveDatasheet(S, data.frame(StageNameId = stages, RunOrder = seq_along(stages)), "core_Pipeline")
t0 <- Sys.time(); R <- run(S); cat(sprintf("run took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
cat(paste(unique(lg[grepl("Total time: [0-9]|^8 Initial|Last disturbance|Soil:|Initial carbon|FAIL|Failure|rror", lg) & !grepl("post processing|saving results", lg)]), collapse = "\n"), "\n")
v <- as.data.table(datasheet(R, "lucasCore_OutputValidation")); print(v[, .(checks = .N, failed = sum(Status != "Pass")), by = Stage])
ok <- nrow(v) > 0 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))
print(as.data.table(datasheet(R, "lucasCore_OutputInitialStockSummary", lookupsAsFactors = FALSE))[order(-TotalTg)][1:12])
for (sh in c("stsim_InitialConditionsSpatial", "stsim_InitialStockSpatial", "stsim_FlowPathway", "stsim_FlowMultiplier", "stsim_FlowSpatialMultiplier",
             "stsim_StateAttributeValue", "stsim_Transition", "stsim_TransitionSpatialMultiplier", "stsim_TransitionTarget"))
  cat(sprintf("%-36s %8d rows\n", sh, nrow(datasheet(R, sh))))
cat("result scenario:", scenarioId(R), "\n"); cat(if (ok) "PIPELINE OK\n" else "PIPELINE FAILED\n")
