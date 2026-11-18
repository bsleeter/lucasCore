# =============================================================================
# 14-compare-runs.R - stage 14: figures (PNG) and two summary tables that compare ST-Sim runs on one lucasCore Build
# =============================================================================
# Draws src/compare-figures.R's charts and maps of the runs listed in Compare Runs (result scenarios in this library: projections
# under different climate futures or management, a historical run and its projections) and saves one row per PNG to Compare Figures
# (Figure, Title, Caption, FileName), and one row per run to Compare Carbon Summary (stocks and mean fluxes) and Compare Land Change
# Summary (transition areas, forest and developed area change). Same format as the Build and run figures (stages 12, 13).
# Export > LUCAS Core > Compare Figures saves them all to a folder.
# Its own scenario: depends on the runs' Build result (the grid). A run that is another listed run's historical run (its Projection
# Setup's Projection Start) is drawn as the history in black, and a projection's historical run is added when it is not listed. The
# baseline is the run ticked Baseline, else the first projection listed; the others are differenced against it. Runs that stage 18
# (Wood Products) has followed get the wood products figure and summary columns (a history takes its projection's when it has none).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "figures.R")); source(pkg_file("src", "run-figures.R")); source(pkg_file("src", "compare-figures.R")); source(pkg_file("src", "capacity.R"))
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
w <- vapply(R, function(r) !is.null(r$X$wp), TRUE)
if (any(w)) say("Wood products (stage 18) on %s%s", paste(vapply(R[w], function(r) sprintf("%d (result %d)", r$rid, attr(r$X$wp, "scenario")), ""), collapse = ", "),
                if (all(w)) "" else sprintf("; none on %s: run stage 18 on it to add it", paste(vapply(R[!w], function(r) sprintf("%d", r$rid), ""), collapse = ", "))) else
  say("No Wood Products result on these runs: run stage 18 on them for the wood products figure and NBP with products")
check(STAGE, "the projections end in the same year", length(unique(vapply(Filter(function(r) !r$hist, R), function(r) r$X$years[2], 0))) == 1,
      paste(vapply(Filter(function(r) !r$hist, R), function(r) sprintf("%d: %d", r$rid, r$X$years[2]), ""), collapse = ", "))

ic <- tryCatch(as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE)), error = function(e) e)
gf <- figures_grid(ic, lib_file, vapply(R, function(r) as.integer(r$rid), 0L), say)   # the Build's state class map, else a run's own (src/run-figures.R)
if (is.na(gf)) fail("no state class map: this scenario must depend on the runs' Build result, and neither it nor the runs have their map in the library's data folder")
grid <- rast(gf)
sa <- read_ds("StudyArea"); label <- if (nrow(sa)) paste(sub("^[^:]*: ", "", sa$UnitId), collapse = ", ") else "CONUS"
dem <- tryCatch(read_data_sources("ElevationFile")$ElevationFile, error = function(e) { say("No hillshade: %s", conditionMessage(e)); NULL })
progressBar()

# the carbon carrying capacity (src/capacity.R): the Build result's Carbon Capacity maps, written by stage 8
cap <- tryCatch(capacity_maps(read_capacity_maps()), error = function(e) { say("Carbon capacity not readable: %s", conditionMessage(e)); NULL })
if (is.null(cap)) say("No Carbon Capacity maps in the Build result this scenario depends on: rerun the Build's stage 8 with this version of lucasCore to compare the runs against the carrying capacity")
res <- compare_figures(R, grid, dem, label, file.path(TD(), "CompareFigures"), cap = cap)
S <- attr(res, "carbon"); Ld <- attr(res, "land"); Cc <- attr(res, "capacity")
if (!is.null(Cc)) { for (i in seq_len(nrow(Cc))) say("%s: %.0f%% of the carrying capacity in %d, %.0f%% in %d (%.2f of %.2f Tg C; deficit %.2f)", Cc$Label[i], Cc$ShareStart[i], Cc$StartYear[i], Cc$ShareEnd[i], Cc$EndYear[i], Cc$StockEnd[i], Cc$Capacity[i], Cc$DeficitEnd[i])
  tryCatch(write_ds(Cc, "OutputCompareCapacity"), error = function(e) say("Compare Carbon Against Capacity not written (%s): reopen the library in SyncroSim Studio so it adds the table", conditionMessage(e))) }
say("%d figures drawn (%s)", nrow(res), paste(res$Title, collapse = "; "))
for (i in seq_len(nrow(S))) say("%s: %.1f to %.1f Tg C (%+.1f)%s", S$Label[i], S$CarbonStart[i], S$CarbonEnd[i], S$CarbonChange[i],
                                 if (is.na(S$VsBaseline[i])) "" else sprintf(", %+.1f against the baseline", S$VsBaseline[i]))
progressBar()
check(STAGE, "figures drawn", nrow(res) > 0, sprintf("%d PNG of %d runs", nrow(res), length(R)))
check(STAGE, "every figure file was written", nrow(res) > 0 && all(file.exists(res$FileName)), paste(basename(res$FileName[!file.exists(res$FileName)]), collapse = "; "))
write_ds(res[, .(Figure, Title, Caption, FileName)], "OutputCompareFigure")
write_ds(S, "OutputCompareCarbon")
write_ds(Ld, "OutputCompareLand")
# management cost-effectiveness (runs with Management Actions costs: Output Options > Transition attributes on)
Cs <- tryCatch(compare_cost(R, lib_file), error = function(e) { say("No cost summary: %s", conditionMessage(e)); NULL })
if (!is.null(Cs)) { write_ds(Cs, "OutputCompareCost")
  ratio <- function(v, lo, hi, g) if (is.na(g)) "no wood products result" else if (is.na(v)) sprintf("%.0f Mg C, no gain", g) else sprintf("%.0f Mg C, %.0f USD per Mg C (%.0f-%.0f)", g, v, lo, hi)
  for (i in which(Cs$Role == "Run")) say("%s: %s USD extra net cost (%d iterations); ecosystem: %s; with wood products: %s",
    Cs$Label[i], format(round(Cs$ExtraNetCost[i]), big.mark = ","), Cs$Iterations[i],
    ratio(Cs$UsdPerMgC[i], Cs$UsdPerMgCLow[i], Cs$UsdPerMgCHigh[i], Cs$CarbonGain[i]),
    ratio(Cs$UsdPerMgCWithProducts[i], Cs$UsdPerMgCWithProductsLow[i], Cs$UsdPerMgCWithProductsHigh[i], Cs$CarbonGainWithProducts[i]))
} else say("No management costs in these runs: no cost summary (Output Options > Transition attributes, with Management Actions)")
progressBar()
finish_checks()
progressBar(type = "end")
