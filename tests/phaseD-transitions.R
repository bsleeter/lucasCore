# =============================================================================
# phaseD-transitions.R - stages 1, 5 and 6 for a study area in a new library: strata, initial conditions, then historical
# transition pathways and spatial multipliers
# =============================================================================
# Usage: Rscript tests/phaseD-transitions.R [--units="County: Placer California"]  (Study Area units, comma-separated) [--dir=dev/libs]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
D <- opt("dir", "F:/lucasCore/dev/libs"); UNITS <- opt("units", "County: Placer California"); dir.create(D, showWarnings = FALSE, recursive = TRUE)
f <- file.path(D, sprintf("lucasCore-transitions-%s.ssim", gsub("[^A-Za-z0-9]+", "-", substr(UNITS, 1, 30))))
unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
if (system2(file.path(R.home("bin"), "Rscript.exe"), c("tools/new-library.R", shQuote(f)), stdout = FALSE)) stop("new-library.R failed")
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions")
S <- rsyncrosim::scenario(P, paste("Historical transitions:", UNITS))
description(S) <- paste("Test of stages 1, 5 and 6 (tests/phaseD-transitions.R): study area", UNITS, "at the package default resolution and years;",
                        "strata, state class and age maps, annual NLCD, then historical transition pathways and annual spatial multipliers.")
saveDatasheet(S, data.frame(UnitId = trimws(strsplit(UNITS, ",")[[1]])), "lucasCore_StudyArea")
saveDatasheet(S, data.frame(StageNameId = c("1 - Study Area and Strata", "5 - Initial Conditions", "6 - Historical Transitions"), RunOrder = 1:3), "core_Pipeline")
t0 <- Sys.time(); R <- run(S); cat(sprintf("run took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
cat(paste(unique(lg[grepl("^6 Hist|Grid:|Pathways|Land-use|30 m|Clearcut|Ag contraction|km2 over|MTBS|LANDFIRE|Sources|Error|Failure|failed", lg)]), collapse = "\n"), "\n")
v <- datasheet(R, "lucasCore_OutputValidation")
ok <- nrow(v) > 0 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))
ts <- as.data.table(datasheet(R, "lucasCore_OutputTransitionSummary")); fwrite(ts, paste0(tools::file_path_sans_ext(f), "-transition-summary.csv"))
print(ts[, .(km2 = round(sum(Area)), km2_per_yr = round(sum(Area) / uniqueN(Timestep), 1), inel_pct = round(100 * sum(IneligibleArea) / sum(Area), 1),
             blocked_pct = round(100 * sum(AgeBlockedArea, na.rm = TRUE) / sum(Area), 1)), by = .(Source, TransitionGroup)])
for (k in c("stsim_Transition", "stsim_DeterministicTransition", "stsim_TransitionSpatialMultiplier", "stsim_TransitionTarget"))
  cat(sprintf("%-36s %d rows\n", k, nrow(datasheet(R, k))))
cat("result scenario:", scenarioId(R), "\n")
cat(if (ok) "TRANSITIONS OK\n" else "TRANSITIONS FAILED\n")
