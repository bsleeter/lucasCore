# =============================================================================
# build_starter.R - the starter library: Starter/LUCAS Core (CONUS).ssim
# =============================================================================
# SyncroSim 3 has no local templates (File > New offers Empty Library and the online templates of the central package index), so
# lucasCore ships a starter library to copy and open instead. Made by tools/new-library.R, it holds the stsim definitions, every
# Stratum Source with the universal unit lists, the LOCA2 lists of this machine's LOCA2 folder and the Stock-Flow Definitions
# scenario, plus a ready "Build" scenario: depends on Stock-Flow Definitions, pipeline stages 1, 5, 2, 3, 4, 6, 7, 8. A user copies
# the file, opens it (File > Open), fills in the Build scenario's Build Options, Study Area and Climate Options, and runs it.
# Rebuild after changing defaults/ or package.xml.
# Usage: Rscript tools/build_starter.R
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
pkg <- normalizePath(file.path(here, ".."), winslash = "/"); sd <- file.path(pkg, "Starter"); dir.create(sd, showWarnings = FALSE)
f <- file.path(sd, "LUCAS Core (CONUS).ssim")
unlink(c(f, paste0(f, c(".data", ".temp", ".backup", ".input"))), recursive = TRUE)
if (system2(file.path(R.home("bin"), "Rscript.exe"), c(shQuote(file.path(pkg, "tools", "new-library.R")), shQuote(f)))) stop("new-library.R failed")

L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE))
B <- rsyncrosim::scenario(P, "Build"); dependency(B) <- sc[Name == "Stock-Flow Definitions", ScenarioId]
description(B) <- paste(
  "Builds a LUCAS model. Before running, set: (1) Build Options - cell size, secondary and tertiary strata (blank = States, Federal Lands),",
  "historical start and end years, projection end year (blank = no projection); (2) Study Area - one row per unit of any source (blank = all",
  "of CONUS); (3) Climate Options - climate methods, and the projection scenario, climate model and replicate when projecting.",
  "Depends on Stock-Flow Definitions. Pipeline: 1 Study Area and Strata, 5 Initial Conditions, 2 Growth Curves, 3 Carbon Flows,",
  "4 Spin-up, 6 Historical Transitions, 7 Climate Multipliers, 8 Initial Stock Maps. California at 1 km takes about 50 minutes.")
stages <- c("1 - Study Area and Strata", "5 - Initial Conditions", "2 - Fit Growth Curves", "3 - Carbon Flows", "4 - Spin-up and Initial Stocks",
            "6 - Historical Transitions", "7 - Climate Multipliers", "8 - Initial Stock Maps")
saveDatasheet(B, data.frame(StageNameId = stages, RunOrder = seq_along(stages)), "core_Pipeline")
unlink(paste0(f, c(".temp", ".backup")), recursive = TRUE)
cat("starter:", f, "\n"); print(as.data.table(scenario(L, summary = TRUE))[, .(ScenarioId, Name, IsResult)])
print(datasheet(B, "core_Pipeline"))
