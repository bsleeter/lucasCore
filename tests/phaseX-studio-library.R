# =============================================================================
# phaseX-studio-library.R - a library made the way Studio makes one: Empty Library, add ST-Sim, add lucasCore; then a Build and a run
# =============================================================================
# 1. A new library with stsim, then lucasCore added (Studio: File > New > Empty Library, Library Properties > Packages > Add).
#    ui/LibrarySetup.cs fills the project: every project sheet the starter has must be identical to the starter's.
# 2. A Build scenario made from nothing (no Stock-Flow Definitions scenario exists): study area, Build Options, growth curves copied
#    from a fitted library, pipeline 0, 1, 5, 2, 3, 4, 6, 7, 8. Stage 0 writes the stock-flow definitions into the result.
# 3. A historical ST-Sim run on the Build result alone (tools/new-historical.R finds no Stock-Flow Definitions scenario and uses none).
# Usage: Rscript tests/phaseX-studio-library.R [--units="County: Placer California"] [--resolution=1000] [--end=1990]
#                                              [--curves="F:/lucasCore/dev/libs/lucasCore-forest-map.ssim"]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
UNITS <- opt("units", "County: Placer California"); RES <- as.integer(opt("resolution", 1000)); Y1 <- as.integer(opt("end", 1990))
CURVES <- opt("curves", "F:/lucasCore/dev/libs/lucasCore-forest-map.ssim")
RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"; starter <- "F:/lucasCore/Starter/LUCAS Core (CONUS).ssim"
f <- "F:/lucasCore/dev/libs/lucasCore-studio-library.ssim"; unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])

# ---- 1. the library -------------------------------------------------------------------------------------------------------
L <- ssimLibrary(f, packages = "stsim"); addPackage(L, "lucasCore")
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions")
st <- as.data.table(datasheet(P, "lucasCore_LibrarySetup")); cat("Library Setup:", st$Status, "\n")
S0 <- rsyncrosim::project(ssimLibrary(starter), "Definitions")
norm <- function(x) { x <- as.data.table(lapply(as.data.frame(x), function(v) { v <- as.character(v); v[is.na(v) | v == ""] <- "<NA>"; v })); if (ncol(x)) setorderv(x, names(x)); x }
man <- rbind(fread("F:/lucasCore/defaults/stsim/manifest.csv"), fread("F:/lucasCore/defaults/library/project/manifest.csv"), fill = TRUE)[Scope == "Project" & Datasheet != "lucasCore_DataSource"]   # the starter leaves Data Sources blank
same <- vapply(man$Datasheet, function(sh) isTRUE(all.equal(norm(suppressWarnings(datasheet(P, sh, lookupsAsFactors = FALSE))),
                                                            norm(suppressWarnings(datasheet(S0, sh, lookupsAsFactors = FALSE))), check.attributes = FALSE)), TRUE)
cat(sprintf("project sheets identical to the starter: %d of %d%s\n", sum(same), length(same), if (all(same)) "" else paste(":", paste(names(same)[!same], collapse = ", "))))
lib_ok <- identical(st$Status, "Filled") && all(same)

# ---- 2. the Build ------------------------------------------------------------------------------------------------------------
B <- rsyncrosim::scenario(P, "Build")
saveDatasheet(B, data.frame(UnitId = trimws(strsplit(UNITS, ",")[[1]])), "lucasCore_StudyArea")
saveDatasheet(B, data.frame(Resolution = RES, StartYear = 1985L, EndYear = Y1), "lucasCore_BuildOptions")
saveDatasheet(B, data.frame(CurveSource = 2L, CurveLibrary = CURVES), "lucasCore_GrowthOptions")
stages <- c("0 - Stock-Flow Definitions", "1 - Study Area and Strata", "5 - Initial Conditions", "2 - Fit Growth Curves", "3 - Carbon Flows",
            "4 - Spin-up and Initial Stocks", "6 - Historical Transitions", "7 - Climate Multipliers", "8 - Initial Stock Maps")
saveDatasheet(B, data.frame(StageNameId = stages, RunOrder = seq_along(stages)), "core_Pipeline")
description(B) <- sprintf("tests/phaseX-studio-library.R: Build of %s at %d m, 1985-%d, in a library made like Studio makes one (no Stock-Flow Definitions scenario); growth curves copied from %s; pipeline 0, 1, 5, 2, 3, 4, 6, 7, 8.", UNITS, RES, Y1, CURVES)
t0 <- Sys.time(); RB <- run(B); cat(sprintf("Build took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- logl(RB); cat(paste(unique(lg[grepl("Stock-Flow Definitions|FAIL|Failure|rror", lg)]), collapse = "\n"), "\n")
v <- as.data.table(datasheet(RB, "lucasCore_OutputValidation")); print(v[, .(checks = .N, failed = sum(Status != "Pass")), by = Stage])
sf <- vapply(c("stsim_FlowPathwayDiagram", "stsim_FlowPathway", "stsim_FlowOrder", "stsim_FlowTypeGroupMembership", "stsim_OutputOptionsStockFlow"),
             function(s) nrow(suppressWarnings(datasheet(RB, s, optional = TRUE))), 1L); print(sf)
build_ok <- nrow(v) > 0 && all(v$Status == "Pass") && all(sf > 0) && !any(grepl("[Failure]", lg, fixed = TRUE))

# ---- 3. the historical run -------------------------------------------------------------------------------------------------
out <- system2(RS, c("F:/lucasCore/tools/new-historical.R", shQuote(f), sprintf("--build=%d", scenarioId(RB))), stdout = TRUE, stderr = TRUE)
cat(grep("created|error|Error", out, value = TRUE), sep = "\n"); hid <- as.integer(tail(out, 1))
H <- scenario(ssimLibrary(f), hid); print(dependency(H)[, c("ScenarioId", "Name")])
t0 <- Sys.time(); RH <- run(H); cat(sprintf("historical run took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
fl <- as.data.table(datasheet(RH, "stsim_OutputFlow")); stk <- as.data.table(datasheet(RH, "stsim_OutputStock"))
cat(sprintf("output: %d flow rows, %d stock rows, %d years\n", nrow(fl), nrow(stk), uniqueN(stk$Timestep)))
run_ok <- nrow(fl) > 0 && nrow(stk) > 0 && !any(grepl("[Failure]", logl(RH), fixed = TRUE))
cat(sprintf("library %s, build %s, run %s\n", if (lib_ok) "OK" else "FAILED", if (build_ok) "OK" else "FAILED", if (run_ok) "OK" else "FAILED"))
cat(if (lib_ok && build_ok && run_ok) "STUDIO LIBRARY OK\n" else "STUDIO LIBRARY FAILED\n")
