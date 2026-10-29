# =============================================================================
# 14-compare-runs.R - stage 14: figures (PNG) and a summary table that compare ST-Sim runs on one lucasCore Build
# =============================================================================
# Draws src/compare-figures.R's charts and maps of the runs listed in Compare Runs (result scenarios in this library: projections
# under different climate futures or management, a historical run and its projections) and saves one row per PNG to Compare Figures
# (Figure, Title, Caption, FileName) and one row per run to Compare Summary. Same format as the Build and run figures (stages 12, 13).
# Export > LUCAS Core > Compare Figures saves them all to a folder.
# Its own scenario: depends on the runs' Build result (the grid). A run that is another listed run's historical run (its Projection
# Setup's Projection Start) is drawn as the history in black, and a projection's historical run is added when it is not listed. The
# baseline is the run ticked Baseline, else the first projection listed; the others are differenced against it.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "figures.R")); source(pkg_file("src", "run-figures.R")); source(pkg_file("src", "compare-figures.R"))
STAGE <- "14 Compare Runs"
progressBar(type = "begin", totalSteps = 3)

lib_file <- main_library()
runs <- read_ds("CompareRunOptions")
if (!nrow(runs) || all(is.na(runs$RunScenarioId))) fail("Compare Runs: list the runs to compare (their result scenario Ids) in Compare Runs")
con <- DBI::dbConnect(RSQLite::SQLite(), lib_file, flags = RSQLite::SQLITE_RO)
have <- DBI::dbGetQuery(con, "SELECT DISTINCT ScenarioId FROM stsim_OutputStratumState")$ScenarioId; DBI::dbDisconnect(con)
bad <- setdiff(runs$RunScenarioId, have)
if (length(bad)) fail("Compare Runs: result %s has no ST-Sim output: list result scenarios of historical runs or projections", paste(bad, collapse = ", "))
R <- tryCatch(compare_runs(lib_file, runs), error = function(e) fail("Compare Runs: %s", conditionMessage(e)))
for (r in R) say("Run %d (%s): %d-%d, %d iteration(s)%s", r$rid, r$label, r$X$years[1], r$X$years[2], r$X$nit,
                 if (r$hist) ", the history" else if (r$base) ", the baseline" else "")
check(STAGE, "the projections end in the same year", length(unique(vapply(Filter(function(r) !r$hist, R), function(r) r$X$years[2], 0))) == 1,
      paste(vapply(Filter(function(r) !r$hist, R), function(r) sprintf("%d: %d", r$rid, r$X$years[2]), ""), collapse = ", "))

ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StateClassFileName[1])) fail("no state class map: this scenario must depend on the runs' Build result")
grid <- rast(ic$StateClassFileName[1])
sa <- read_ds("StudyArea"); label <- if (nrow(sa)) paste(sub("^[^:]*: ", "", sa$UnitId), collapse = ", ") else "CONUS"
dem <- tryCatch(read_data_sources("ElevationFile")$ElevationFile, error = function(e) { say("No hillshade: %s", conditionMessage(e)); NULL })
progressBar()

res <- compare_figures(R, grid, dem, label, file.path(TD(), "CompareFigures"))
S <- attr(res, "summary")
say("%d figures drawn (%s)", nrow(res), paste(res$Title, collapse = "; "))
for (i in seq_len(nrow(S))) say("%s: %.1f to %.1f Tg C (%+.1f)%s", S$Label[i], S$CarbonStart[i], S$CarbonEnd[i], S$CarbonChange[i],
                                 if (is.na(S$VsBaseline[i])) "" else sprintf(", %+.1f against the baseline", S$VsBaseline[i]))
progressBar()
check(STAGE, "figures drawn", nrow(res) > 0, sprintf("%d PNG of %d runs", nrow(res), length(R)))
check(STAGE, "every figure file was written", nrow(res) > 0 && all(file.exists(res$FileName)), paste(basename(res$FileName[!file.exists(res$FileName)]), collapse = "; "))
write_ds(res[, .(Figure, Title, Caption, FileName)], "OutputCompareFigure")
write_ds(S, "OutputCompareSummary")
progressBar()
finish_checks()
progressBar(type = "end")
