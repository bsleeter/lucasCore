# =============================================================================
# phaseG-starter.R - the starter library end to end, with the growth curves as a shared dependency
# =============================================================================
# Copies Starter/LUCAS Core (CONUS).ssim (built by tools/build_starter.R) to dev/libs, runs its Growth Curves scenario (stage 2), then
# its Build scenario for the study area with a dependency on that result and stage 2 removed from the pipeline (1, 5, 3, 4, 6, 7, 8).
# Stages 3 and 4 work only on the study area's ecodivisions.
# Usage: Rscript tests/phaseG-starter.R [--units="County: Placer California"] [--dir=dev/libs]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
D <- opt("dir", "F:/lucasCore/dev/libs"); UNITS <- opt("units", "County: Placer California")
src <- "F:/lucasCore/Starter/LUCAS Core (CONUS).ssim"; if (!file.exists(src)) stop("build the starter first: Rscript tools/build_starter.R")
f <- file.path(D, sprintf("lucasCore-starter-%s.ssim", gsub("[^A-Za-z0-9]+", "-", substr(UNITS, 1, 30))))
unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE); file.copy(src, f)
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE))
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])

G <- scenario(L, sc[Name == "Growth Curves", ScenarioId])
t0 <- Sys.time(); RG <- run(G); cat(sprintf("Growth Curves took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
B <- scenario(L, sc[Name == "Build", ScenarioId])
dependency(B) <- c(sc[Name == "Stock-Flow Definitions", ScenarioId], scenarioId(RG))
pl <- as.data.table(datasheet(B, "core_Pipeline", lookupsAsFactors = FALSE))[!grepl("^2 ", StageNameId)][order(RunOrder)][, RunOrder := .I]
saveDatasheet(B, as.data.frame(pl), "core_Pipeline")
saveDatasheet(B, data.frame(UnitId = trimws(strsplit(UNITS, ",")[[1]])), "lucasCore_StudyArea")
description(B) <- paste(description(B), sprintf("[tests/phaseG-starter.R: study area %s; growth curves from the Growth Curves result %d; stage 2 removed.]", UNITS, scenarioId(RG)))
t0 <- Sys.time(); RB <- run(B); cat(sprintf("Build took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- logl(RB)
cat(paste(unique(lg[grepl("Total time: [0-9]|Study area|Decay calibration|Spin-up|Initial carbon|FAIL|Failure|rror", lg) & !grepl("post processing|saving results", lg)]), collapse = "\n"), "\n")
v <- as.data.table(datasheet(RB, "lucasCore_OutputValidation")); print(v[, .(checks = .N, failed = sum(Status != "Pass")), by = Stage])
ok <- nrow(v) > 0 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))
dc <- as.data.table(datasheet(RB, "lucasCore_OutputDecayCalibration", lookupsAsFactors = FALSE)); cat("decay-calibrated cells:", nrow(dc), "in", uniqueN(dc$StratumId), "ecodivisions\n")
cat("result scenarios: growth curves", scenarioId(RG), ", build", scenarioId(RB), "\n"); cat(if (ok) "STARTER OK\n" else "STARTER FAILED\n")
