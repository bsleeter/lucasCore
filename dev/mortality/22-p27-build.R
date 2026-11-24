# =============================================================================
# 22-p27-build.R - to-do 3, Build phase 1: a Build of the Southern Sierra Nevada pyrome with drought and insect mortality
# =============================================================================
# Makes the "Build" scenario in a library made by tools/new-library.R (as tools/build_starter.R does) for Pyrome P27 at --resolution,
# 1985-2023, and runs it. The library must record a lucasCore version that has the Mortality type (2.0).
# Usage: Rscript dev/mortality/22-p27-build.R <library.ssim> [--resolution=300] [--no-run]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
L <- ssimLibrary(normalizePath(a[!grepl("^--", a)][1], winslash = "/")); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE))
B <- rsyncrosim::scenario(P, "Build"); dependency(B) <- sc[Name %in% c("Stock-Flow Definitions", "Carbon Assumptions"), ScenarioId]
stages <- c("0 - Stock-Flow Definitions", "1 - Study Area and Strata", "5 - Initial Conditions", "2 - Fit Growth Curves", "3 - Carbon Flows",
            "4 - Spin-up and Initial Stocks", "6 - Historical Transitions", "7 - Climate Multipliers", "8 - Initial Stock Maps", "12 - Build Figures")
saveDatasheet(B, data.frame(StageNameId = stages, RunOrder = seq_along(stages)), "core_Pipeline")
saveDatasheet(B, data.frame(UnitId = "Pyrome: P27 Southern Sierra Nevada"), "lucasCore_StudyArea")
saveDatasheet(B, data.frame(Resolution = as.integer(opt("resolution", 300)), SecondarySourceId = "Counties", TertiarySourceId = "Pyromes", StartYear = 1985L, EndYear = 2023L,
                          SpatialTiles = 0L, SpatialTilesStrata = "Grid"), "lucasCore_BuildOptions")   # grid tiles, automatic count (user 2026-11-24: so the runs are quick)
cat(sprintf("scenario %d: %s\n", scenarioId(B), name(B)))
if (!"--no-run" %in% a) { t0 <- Sys.time(); r <- run(B); cat(sprintf("result %d in %.1f min\n", scenarioId(r), as.numeric(Sys.time() - t0, units = "mins"))) }
