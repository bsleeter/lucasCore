# =============================================================================
# phaseE-climate.R - stages 1 and 7 for a study area in a new library: strata, then annual climate flow spatial multipliers with the
# default Climate Options (tree ring, Miami non-forest, Q10); then stage 7 alone on that result with Miami forest growth, and with
# every effect None
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
report <- function(R, label) {
  lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
  cat(sprintf("\n==== %s\n", label)); cat(paste(unique(lg[grepl("^7 Clim|Climate Options|Tree-ring coef|PRISM:|study-area mean|Rasters:|gap fill|every climate effect|Failure|rror", lg)]), collapse = "\n"), "\n")
  v <- datasheet(R, "lucasCore_OutputValidation"); ok <- nrow(v) > 0 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))
  n <- nrow(datasheet(R, "stsim_FlowSpatialMultiplier")); cat("stsim_FlowSpatialMultiplier", n, "rows\n")
  cs <- as.data.table(datasheet(R, "lucasCore_OutputClimateSummary"))
  if (nrow(cs)) { fwrite(cs, paste0(tools::file_path_sans_ext(f), "-climate-summary-", gsub("[^a-z]+", "-", tolower(label)), ".csv"))
    print(dcast(cs[Timestep %in% c(1985, 2000, 2015, 2021, 2023)], Timestep ~ FlowGroup, value.var = "Mean")) }
  list(ok = ok, rows = n) }

S <- rsyncrosim::scenario(P, paste("Climate multipliers:", UNITS))
description(S) <- paste("Test of stages 1 and 7 (tests/phaseE-climate.R): study area", UNITS, "with the default Climate Options",
                        "(forest growth tree ring, non-forest growth Miami NPP, decomposition Q10), PRISM current release, 1991-2020 normal.")
saveDatasheet(S, data.frame(StudyAreaUnits = UNITS), "lucasCore_BuildOptions")
saveDatasheet(S, data.frame(StageNameId = c("1 - Study Area and Strata", "7 - Climate Multipliers"), RunOrder = 1:2), "core_Pipeline")
t0 <- Sys.time(); R1 <- run(S); cat(sprintf("run took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
r1 <- report(R1, "Defaults (tree ring)")

variant <- function(name, opts, desc) { V <- rsyncrosim::scenario(P, paste("Climate multipliers:", name)); dependency(V) <- scenarioId(R1)
  description(V) <- desc; saveDatasheet(V, opts, "lucasCore_ClimateOptions")
  saveDatasheet(V, data.frame(StageNameId = "7 - Climate Multipliers", RunOrder = 1), "core_Pipeline"); report(run(V), name) }
r2 <- variant("Miami forest growth", data.frame(ForestGrowthModel = 2L),
              "Stage 7 alone (tests/phaseE-climate.R) on the defaults result, with forest growth = Miami NPP (the CONUS 1km build's model).")
r3 <- variant("No climate effects", data.frame(ForestGrowthModel = 1L, NonForestGrowthModel = 1L, DecompositionModel = 1L),
              "Stage 7 alone (tests/phaseE-climate.R) on the defaults result, with every climate effect None: no climate multipliers.")
ok <- r1$ok && r2$ok && r3$rows == 0 && r1$rows == 160
cat(sprintf("\nrows: defaults %d (expect 160), Miami %d, None %d (expect 0)\n", r1$rows, r2$rows, r3$rows))
cat(if (ok) "CLIMATE OK\n" else "CLIMATE FAILED\n")
