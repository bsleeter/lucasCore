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
# out (state class maps for the land cover figure, Fire transition maps, Total Ecosystem average stock maps). The wood products figure
# (carbon stored in products, NBP with products) is drawn when stage 18 has been run on the run (its newest Wood Products result).
# The figures of carbon against the carrying capacity (src/capacity.R) are drawn when the Build result holds stage 8's Carbon
# Capacity maps; the run's stock, share of the capacity and deficit by year go to Run Carbon Against Capacity.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "figures.R")); source(pkg_file("src", "run-figures.R")); source(pkg_file("src", "capacity.R"))
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
    # stage 9 hands every pool the historical run mapped to the projection, so the two totals are equal (1e-6 allows for rounding)
    check(STAGE, "the projection starts from its historical run's final carbon (exactly)", !anyNA(X$join) && abs(d) <= 1e-6 * X$join["history"],
          sprintf("%.4f vs %.4f Tg C in %d (%+.4f)", X$join["history"], X$join["projection"], X$proj_start, d))
  } else if (!is.null(H)) say("Historical run %d ends in %d, not in %d where the projection starts: the projection alone is drawn", hid, H$years[2], X$years[1])
}
# harvested wood products: stage 18's newest result on this run (for a projection it holds the history's years too)
X$wp <- tryCatch(wp_of_run(lib_file, rid), error = function(e) { say("Wood products not readable: %s", conditionMessage(e)); NULL })
if (is.null(X$wp)) say("No Wood Products result on run %d: run stage 18 on it for the wood products figure and NBP with products", rid) else {
  wy <- range(X$wp$Year[X$wp$Variable == "StockChange"])
  say("Wood products from result %d: %d-%d", attr(X$wp, "scenario"), wy[1], wy[2])
  check(STAGE, "the wood products result covers the run's years", wy[1] <= X$years[1] + 1 && wy[2] >= X$years[2], sprintf("wood products %d-%d, run %d-%d", wy[1], wy[2], X$years[1], X$years[2])) }

# the carbon carrying capacity (src/capacity.R): the Build result's Carbon Capacity maps, written by stage 8
X$cap <- tryCatch(capacity_maps(read_capacity_maps()), error = function(e) { say("Carbon capacity not readable: %s", conditionMessage(e)); NULL })
cser <- if (is.null(X$cap)) NULL else capacity_series(X$stocks, X$cap$total, X$cap$upper_total)
if (is.null(X$cap)) say("No Carbon Capacity maps in the Build result this scenario depends on: rerun the Build's stage 8 with this version of lucasCore for the figures of carbon against the carrying capacity") else
  if (is.null(cser)) say("Carbon capacity: the run has no stock output for Biomass: Total, DOM: Deadwood and DOM: Litter; no capacity figure") else {
    n1 <- nrow(cser); say("Carbon against the carrying capacity (live biomass, dead wood and litter): %.2f Tg C of %.2f in %d (%.0f%%), %.2f in %d (%.0f%%); upper bound %.2f",
                         cser$Stock[1], X$cap$total, cser$Timestep[1], cser$RealisedShare[1], cser$Stock[n1], cser$Timestep[n1], cser$RealisedShare[n1], X$cap$upper_total)
    if (!is.na(X$cap$start_total)) say("  the Build's starting stock of those pools is %.2f Tg C; the run's first year holds %.2f", X$cap$start_total, cser$Stock[1]) }

ic <- tryCatch(as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE)), error = function(e) e)
gf <- figures_grid(ic, lib_file, c(rid, hid), say)   # the Build's state class map, else the run's own (src/run-figures.R)
if (is.na(gf)) fail("no state class map: this scenario must depend on the run's Build result, and neither it nor the run has its map in the library's data folder")
grid <- rast(gf)
scl <- stsim_list("StateClass"); cols <- setNames(argb(scl$Color), scl$Name)
sa <- read_ds("StudyArea"); label <- study_label(sa)
obs <- read_ds("OutputTransitionSummary"); if (!nrow(obs)) obs <- NULL
dem <- tryCatch(read_data_sources("ElevationFile")$ElevationFile, error = function(e) { say("No hillshade: %s", conditionMessage(e)); NULL })
progressBar()

res <- run_figures(X, grid, cols, dem, label, obs, file.path(TD(), "RunFigures"), run_name = rn)
say("%d figures drawn (%s)", nrow(res), paste(res$Title, collapse = "; "))
progressBar()
check(STAGE, "figures drawn", nrow(res) > 0, sprintf("%d PNG of run %d", nrow(res), rid))
check(STAGE, "every figure file was written", nrow(res) > 0 && all(file.exists(res$FileName)), paste(basename(res$FileName[!file.exists(res$FileName)]), collapse = "; "))
write_ds(res[, .(Figure, Title, Caption, FileName, RunScenarioId = rid)], "OutputRunFigure")
# the run against the carbon capacity, year by year, with the deficit by cause in the first and last year (where the run wrote its maps)
if (!is.null(cser)) { cser[, (CAPACITY_CAUSE_COLS) := NA_real_]
  for (e in list(list(X$years[1], X$sc0, X$hl0), list(X$years[2], X$sc1, X$hl1))) { cy <- capacity_year(X$cap, e[[2]], e[[3]], X$sc_list)
    if (!is.null(cy)) cser[Timestep == e[[1]], (CAPACITY_CAUSE_COLS) := as.list(unname(cy$split))] }
  tryCatch(write_ds(cser[, .(RunScenarioId = rid, Year = Timestep, Stock, Capacity, UpperBound, RealisedShare, Deficit, DeficitLandUse, DeficitCover, DeficitDisturbed, DeficitLive, DeficitDead)], "OutputRunCapacity"),
           error = function(e) say("Run Carbon Against Capacity not written (%s): reopen the library in SyncroSim Studio so it adds the table", conditionMessage(e))) }
progressBar()
finish_checks()
progressBar(type = "end")
