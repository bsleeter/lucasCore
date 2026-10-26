# =============================================================================
# 13-run-figures.R - stage 13: report figures (PNG) of an ST-Sim run on a lucasCore Build
# =============================================================================
# Draws src/run-figures.R's maps and charts of one run - a historical run or a projection, a result scenario in this library - and saves
# one row per PNG to Run Figures (Figure, Title, Caption, FileName, RunScenarioId): land cover change, fire, carbon change maps; land
# area, transitions (simulated against the Build's record), carbon stocks and fluxes, carbon by secondary stratum. Same format as the
# Build figures (stage 12). Export > LUCAS Core > Run Figures saves them all to a folder.
# Its own scenario: depends on the run's Build result (the grid, strata, state class colours and the transition record), with Run
# Figures naming the run (blank = the newest result scenario with ST-Sim output). A stand-alone projection gets its historical run (its
# Projection Setup's Projection Start) joined in front, checked on total ecosystem carbon in the year the projection starts from. The run's tables are read from the library by SQL
# and its maps from its data folder, so the run's own outputs set what can be drawn: a figure whose maps the run did not write is left
# out (state class maps for the land cover figure, Fire transition maps, Total Ecosystem average stock maps).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "figures.R")); source(pkg_file("src", "run-figures.R"))
STAGE <- "13 Run Figures"
progressBar(type = "begin", totalSteps = 3)

lib_file <- main_library()
opt <- read_ds("RunFigureOptions"); rid <- if (nrow(opt) && "RunScenarioId" %in% names(opt)) opt$RunScenarioId[1] else NA
if (is.na(rid)) { con <- DBI::dbConnect(RSQLite::SQLite(), lib_file, flags = RSQLite::SQLITE_RO)
  rid <- DBI::dbGetQuery(con, "SELECT MAX(ScenarioId) id FROM stsim_OutputStratumState")$id; DBI::dbDisconnect(con)
  if (is.na(rid)) fail("Run Figures: no ST-Sim result in this library yet: run a historical run or projection first, or name one in Run Figures")
  say("Run Figures: no run named; drawing the newest ST-Sim result, scenario %d", rid) }
X <- tryCatch(load_run(lib_file, rid), error = function(e) fail("Run Figures: %s", conditionMessage(e)))
con <- DBI::dbConnect(RSQLite::SQLite(), lib_file, flags = RSQLite::SQLITE_RO)
rn <- DBI::dbGetQuery(con, sprintf("SELECT Name FROM core_Scenario WHERE ScenarioId = %d", rid))$Name; DBI::dbDisconnect(con)
rn <- if (length(rn)) sub(" \\(\\[.*$", "", rn) else sprintf("result %d", rid)
say("Run %d (%s): %d-%d, %d iteration(s)", rid, rn, X$years[1], X$years[2], X$nit)
# a stand-alone projection: its historical run (the setup's Projection Start) goes in front, so the figures run from the start of the
# history to the end of the projection; the hand-over is checked on total ecosystem carbon in the year the projection starts from
hid <- find_history(lib_file, rid)
if (!is.na(hid)) {
  H <- tryCatch(load_run(lib_file, hid), error = function(e) { say("Historical run %d not readable (%s): the projection alone is drawn", hid, conditionMessage(e)); NULL })
  if (!is.null(H) && H$years[2] == X$years[1]) {
    X <- join_runs(H, X); d <- unname(X$join["projection"] - X$join["history"])
    say("Projection joined to historical run %d: %d-%d; total ecosystem carbon in %d %.2f Tg C at the end of the history, %.2f at the projection's start (%+.2f%%)",
        hid, X$years[1], X$years[2], X$proj_start, X$join["history"], X$join["projection"], 100 * d / X$join["history"])
    check(STAGE, "the projection starts from its historical run's final carbon (within 0.5%)", !anyNA(X$join) && abs(d) <= 0.005 * X$join["history"],
          sprintf("%.2f vs %.2f Tg C in %d", X$join["history"], X$join["projection"], X$proj_start))
  } else if (!is.null(H)) say("Historical run %d ends in %d, not in %d where the projection starts: the projection alone is drawn", hid, H$years[2], X$years[1])
}

ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StateClassFileName[1])) fail("no state class map: this scenario must depend on the run's Build result")
grid <- rast(ic$StateClassFileName[1])
scl <- stsim_list("StateClass"); cols <- setNames(argb(scl$Color), scl$Name)
sa <- read_ds("StudyArea"); label <- if (nrow(sa)) paste(sub("^[^:]*: ", "", sa$UnitId), collapse = ", ") else "CONUS"
obs <- read_ds("OutputTransitionSummary"); if (!nrow(obs)) obs <- NULL
dem <- tryCatch(read_data_sources("ElevationFile")$ElevationFile, error = function(e) { say("No hillshade: %s", conditionMessage(e)); NULL })
progressBar()

res <- run_figures(X, grid, cols, dem, label, obs, file.path(TD(), "RunFigures"), run_name = rn)
say("%d figures drawn (%s)", nrow(res), paste(res$Title, collapse = "; "))
progressBar()
check(STAGE, "figures drawn", nrow(res) > 0, sprintf("%d PNG of run %d", nrow(res), rid))
check(STAGE, "every figure file was written", nrow(res) > 0 && all(file.exists(res$FileName)), paste(basename(res$FileName[!file.exists(res$FileName)]), collapse = "; "))
write_ds(res[, .(Figure, Title, Caption, FileName, RunScenarioId = rid)], "OutputRunFigure")
progressBar()
finish_checks()
progressBar(type = "end")
