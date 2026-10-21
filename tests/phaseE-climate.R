# =============================================================================
# phaseE-climate.R - stages 1 and 7 for a study area in a new library: strata, then annual climate flow spatial multipliers
# =============================================================================
# Usage: Rscript tests/phaseE-climate.R [--units=California] [--dir=dev/libs]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
D <- opt("dir", "F:/lucasCore/dev/libs"); UNITS <- opt("units", "California"); dir.create(D, showWarnings = FALSE, recursive = TRUE)
f <- file.path(D, sprintf("lucasCore-climate-%s.ssim", gsub("[^A-Za-z0-9]+", "-", substr(UNITS, 1, 30))))
unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
if (system2(file.path(R.home("bin"), "Rscript.exe"), c("tools/new-library.R", shQuote(f)), stdout = FALSE)) stop("new-library.R failed")
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions")
S <- rsyncrosim::scenario(P, paste("Climate multipliers:", UNITS))
description(S) <- paste("Test of stages 1 and 7 (tests/phaseE-climate.R): study area", UNITS, "at the package default resolution and years;",
                        "strata, then PRISM growth (Miami NPP) and Q10 flow spatial multipliers against the 1991-2020 normal.")
saveDatasheet(S, data.frame(StudyAreaUnits = UNITS), "lucasCore_BuildOptions")
saveDatasheet(S, data.frame(StageNameId = c("1 - Study Area and Strata", "7 - Climate Multipliers"), RunOrder = 1:2), "core_Pipeline")
t0 <- Sys.time(); R <- run(S); cat(sprintf("run took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
cat(paste(unique(lg[grepl("^7 Clim|Climate flow|PRISM|annual study-area|Rasters:|gap fill|Failure|rror", lg)]), collapse = "\n"), "\n")
v <- datasheet(R, "lucasCore_OutputValidation"); ok <- nrow(v) > 0 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))
cs <- as.data.table(datasheet(R, "lucasCore_OutputClimateSummary")); fwrite(cs, paste0(tools::file_path_sans_ext(f), "-climate-summary.csv"))
print(dcast(cs[Timestep %in% c(1985, 2000, 2015, 2021, 2023)], Timestep ~ FlowGroup, value.var = "Mean"))
cat("stsim_FlowSpatialMultiplier", nrow(datasheet(R, "stsim_FlowSpatialMultiplier")), "rows\n")
cat("result scenario:", scenarioId(R), "\n"); cat(if (ok) "CLIMATE OK\n" else "CLIMATE FAILED\n")
