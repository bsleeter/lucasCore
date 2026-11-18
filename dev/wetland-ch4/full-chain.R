# =============================================================================
# full-chain.R - a coarse Build, historical run, Projection Setup, Projection Climate and projection in one go, to check the wetland
# carbon and methane model through the whole chain (land change at this resolution is not the point)
# =============================================================================
# Usage: Rscript dev/wetland-ch4/full-chain.R <library.ssim> --units="A;B" [--resolution=300] [--tag=300m] [--scenario=SSP5-8.5] [--model=ACCESS-CM2]
#                                              [--from=build|historical|setup|climate|projection] [--build=<id>] [--historical=<id>] [--setup=<id>] [--climate=<id>]
# Run from the package root. Each step's result id is printed as "<step>: result <id>"; --from with the earlier ids resumes a chain.
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d = NA) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
lib <- normalizePath(a[!grepl("^--", a)][1], winslash = "/"); tag <- opt("tag", "300m"); res <- as.numeric(opt("resolution", 300))
steps <- c("build", "historical", "setup", "climate", "projection"); from <- match(opt("from", "build"), steps); if (is.na(from)) stop("--from: one of ", paste(steps, collapse = ", "))
to <- match(opt("to", "projection"), steps); if (is.na(to)) stop("--to: one of ", paste(steps, collapse = ", "))   # stop after this step
# --hist-years=N: only the first N historical years; --iterations=N: Monte Carlo iterations of the historical run;
# --wetland-test: the Build scenario sets Wetland Methane options and target ranges (5 uncertainty draws, CO2e 36), to exercise the page's settings
id <- list(build = as.integer(opt("build")), historical = as.integer(opt("historical")), setup = as.integer(opt("setup")), climate = as.integer(opt("climate")))
rs <- file.path(R.home("bin"), "Rscript"); t00 <- Sys.time()
tool <- function(script, ...) { out <- system2(rs, c(shQuote(file.path("tools", script)), shQuote(lib), ...), stdout = TRUE, stderr = TRUE)
  n <- suppressWarnings(as.integer(trimws(tail(out, 1)))); if (is.na(n)) { cat(tail(out, 25), sep = "\n"); stop(script, " did not make its scenario") }; n }
go <- function(step, sid) { L <- suppressWarnings(ssimLibrary(lib)); t0 <- Sys.time(); R <- tryCatch(run(scenario(L, sid)), error = function(e) e)
  sc <- as.data.table(scenario(suppressWarnings(ssimLibrary(lib)), summary = TRUE)); r <- sc[ParentId == sid & IsResult == "Yes", max(ScenarioId)]
  log <- tryCatch(unlist(strsplit(as.character(runLog(scenario(suppressWarnings(ssimLibrary(lib)), r))), "\n")), error = function(e) character())
  bad <- grep("\\[Failure\\]|^Error", trimws(log)); mins <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  if (inherits(R, "error") || length(bad) || !is.finite(r)) { cat(sprintf("%s FAILED after %.1f min (scenario %d, result %s)\n", step, mins, sid, r)); cat(tail(trimws(log[nzchar(trimws(log))]), 30), sep = "\n"); quit(status = 1) }
  cat(sprintf("%s: result %d (scenario %d, %.1f min)\n", step, r, sid, mins)); as.integer(r) }

if (from <= 1) {   # ---- Build: every stage, at the coarse resolution
  L <- suppressWarnings(ssimLibrary(lib)); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE)); nm <- sprintf("Build %s", tag)
  if (nm %in% sc[IsResult == "No", Name]) delete(L, scenario = sc[Name == nm & IsResult == "No", ScenarioId], force = TRUE)
  B <- rsyncrosim::scenario(P, nm); dep <- sc[Name %in% c("Stock-Flow Definitions", "Carbon Assumptions") & IsResult == "No", ScenarioId]
  if (length(dep)) dependency(B) <- dep   # a library made in Studio has neither: stage 0 writes the definitions and stage 3 uses the package's assumptions
  stages <- c("0 - Stock-Flow Definitions", "1 - Study Area and Strata", "5 - Initial Conditions", "2 - Fit Growth Curves", "3 - Carbon Flows", "4 - Spin-up and Initial Stocks",
              "6 - Historical Transitions", "7 - Climate Multipliers", "8 - Initial Stock Maps", "12 - Build Figures")
  saveDatasheet(B, data.frame(StageNameId = stages, RunOrder = seq_along(stages)), "core_Pipeline")
  saveDatasheet(B, data.frame(UnitId = trimws(strsplit(opt("units"), ";")[[1]])), "lucasCore_StudyArea")
  saveDatasheet(B, data.frame(Resolution = res, StartYear = 1985, EndYear = 2023), "lucasCore_BuildOptions")
  bo <- datasheet(B, "lucasCore_BuildOptions", optional = TRUE); lv <- levels(bo$TidalMarshProductivity); bo$TidalMarshProductivity <- factor(lv[2], levels = lv); saveDatasheet(B, bo, "lucasCore_BuildOptions")
  description(B) <- sprintf("Wetland carbon and methane chain test (dev/wetland-ch4/full-chain.R): %s at %g m, 1985-2023, package defaults.", opt("units"), res)
  if ("--wetland-test" %in% a) {
    saveDatasheet(B, data.frame(MethaneCO2e = 36, UncertaintyDraws = 5L), "lucasCore_WetlandOptions")
    saveDatasheet(B, data.frame(StateClassId = c("Wetland: Oak/Gum/Cypress Group", "Wetland: Palustrine Emergent", "Wetland: Estuarine Emergent"), Region = c(NA, "Coastal Plains", "Gulf and South Atlantic"),   # (both test areas' marsh is in the Gulf and South Atlantic region)
                                Target = c(0.27, 0.40, 0.111), TargetLow = c(0.09, 0.20, 0.05), TargetHigh = c(0.60, 0.90, 0.40)), "lucasCore_WetlandMethaneTarget")
    saveDatasheet(B, data.frame(Region = "Gulf and South Atlantic", Zone = c("oligohaline", "brackish", "salt"), Target = c(0.40, 0.111, 0.0135), TargetLow = c(0.16, 0.05, 0.005), TargetHigh = c(1.29, 0.30, 0.05)), "lucasCore_MarshSalinityTarget") }
  id$build <- go("build", scenarioId(B)) }
if (from <= 2 && to >= 2) id$historical <- go("historical", tool("new-historical.R", sprintf("--build=%d", id$build), "--historical-only", "--bookend-maps", "--replace", if (!is.na(opt("hist-years"))) sprintf("--years=%s", opt("hist-years")), if (!is.na(opt("iterations"))) sprintf("--iterations=%s", opt("iterations")), shQuote(sprintf("--name=Historical %s", tag))))
if (from <= 3 && to >= 3) id$setup <- go("setup", tool("new-projection-setup.R", sprintf("--build=%d", id$build), sprintf("--historical=%d", id$historical), "--end=2100", "--replace", shQuote(sprintf("--name=Projection Setup %s", tag))))
if (from <= 4 && to >= 4) id$climate <- go("climate", tool("new-projection-climate.R", sprintf("--build=%d", id$build), shQuote(sprintf("--scenario=%s", opt("scenario", "SSP5-8.5"))), sprintf("--model=%s", opt("model", "ACCESS-CM2")),
                                              "--replace", shQuote(sprintf("--name=Projection Climate %s", tag))))
if (from <= 5 && to >= 5) id$projection <- go("projection", tool("new-projection.R", sprintf("--build=%d", id$setup), sprintf("--climate=%d", id$climate), "--years=77", "--iterations=1", "--replace", shQuote(sprintf("--name=Projection %s", tag))))
cat(sprintf("chain done in %.0f min: %s\n", as.numeric(difftime(Sys.time(), t00, units = "mins")), paste(sprintf("%s %s", names(id), vapply(id, function(v) if (length(v) && !is.na(v)) as.character(v) else "-", "")), collapse = ", ")))
