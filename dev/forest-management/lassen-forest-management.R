# Forest Management plumbing test (user 2026-11-13: "I would prefer to just use Lassen and impose an artificial amount of harvest -
# this is for testing the plumbing only and not a real application"). Lassen's drawn harvest is under a cell a year (clearcut ~1.7 ha,
# selection ~6.2), so both runs scale it x50 (HarvestScale). Two Projection Setups on one Build and historical run, the same seeded
# draws: a baseline (the drawn harvest x50) and improved forest management (x50, half the clearcut moved to selection by volume, 30%
# of selection to light selection, clearcut only from age 80, no harvest above 200). Each gets a 2024-2036 projection (3
# iterations) and stage 18; then the Compare Cost Summary: timber revenue given up against the carbon gained.
# Usage: Rscript dev/forest-management/lassen-forest-management.R <Build result> <historical result> [years = 13] [iterations = 3] [draws = 20]
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); B <- as.integer(a[1]); H <- as.integer(a[2])
YRS <- if (length(a) > 2) as.integer(a[3]) else 13L; IT <- if (length(a) > 3) as.integer(a[4]) else 3L; DR <- if (length(a) > 4) as.integer(a[5]) else 20L
LIB <- "F:/lucasCore/dev/libs/lassen/Lassen.ssim"; R <- file.path(R.home("bin"), "Rscript.exe")
sh <- function(...) { o <- system2(R, c(...), stdout = TRUE, stderr = TRUE); tail(grep("^[0-9]+$", trimws(o), value = TRUE), 1) }
L <- suppressWarnings(ssimLibrary(LIB, summary = FALSE))
one <- function(label, fm) {
  SS <- as.integer(sh("tools/new-projection-setup.R", LIB, sprintf("--build=%d", B), sprintf("--historical=%d", H), "--resolution=150", "--end=2050",
                      sprintf("--name=\"Projection Setup FM %s\"", label), "--replace"))
  invisible(system2(R, c("dev/reforestation/lassen-setup-options.R", SS), stdout = TRUE, stderr = TRUE))
  S <- scenario(L, SS); po <- datasheet(S, "lucasCore_ProjectionOptions", empty = FALSE); po$Iterations <- IT; saveDatasheet(S, po, "lucasCore_ProjectionOptions")
  saveDatasheet(S, fm, "lucasCore_ForestManagement")
  # Lassen is a national park (GAP 1-2), where projection harvest is excluded by default: the test lets harvest go anywhere
  # (the package rules, with the harvest groups' GAP exclusion blank, as the sheet's list labels)
  pt <- fread("defaults/projection/transitions.csv", na.strings = "", colClasses = "character"); pt[grepl("^Forest Harvest", TransitionGroupId), ExcludeGap := NA]
  pt[, Method := c(Target = "Target (area by strata)", Probability = "Probability (rate map by unit)", None = "None (off in the projection)")[Method]]
  saveDatasheet(S, as.data.frame(pt[, .(TransitionGroupId, Method, StrataLevel, UnitSourceId = UnitSource, SamplingSet, ExcludeGap)]), "lucasCore_ProjectionTransition")
  r <- run(S); cat(sprintf("%s: SETUP RESULT %d\n", label, scenarioId(r)))
  x <- capture.output(runLog(r)); cat(grep("Forest Management|Timber revenue|\\[Warning\\]|FAIL", x, value = TRUE), sep = "\n")
  print(datasheet(r, "lucasCore_OutputForestManagement"))
  PS <- as.integer(sh("tools/new-projection.R", LIB, sprintf("--build=%d", scenarioId(r)), sprintf("--years=%d", YRS), sprintf("--iterations=%d", IT),
                      sprintf("--name=\"Projection FM %s\"", label), "--replace"))
  list(label = label, setup = scenarioId(r), projection = PS) }
base <- one("baseline x50", data.frame(HarvestScale = 50))
ifm <- one("IFM x50", data.frame(HarvestScale = 50, ClearcutToSelection = 0.5, ShiftBasis = "Volume (the same wood removed)", LightSelection = 0.3,
                                 ClearcutMinAge = 80L, ClearcutMaxAge = 200L, SelectionMaxAge = 200L))
# the two projections at once (user 2026-11-13: "st-sim scenarios ... can run at the same time if you set the multiprocessing options
# accordingly": Lassen's library multiprocessing has multi-scenario on, 3 jobs); the setups run R stages, so one at a time above
# rsyncrosim's run() runs a list of scenarios one at a time; the console runs them at once given together (--sids)
t0 <- Sys.time(); before <- as.data.table(scenario(L, summary = TRUE))$ScenarioId
tt <- command(list(run = NULL, lib = filepath(L), sids = paste(c(base$projection, ifm$projection), collapse = ",")), session(L))
if (!identical(tt[1], "saved")) cat(tt, sep = "\n")
sc <- as.data.table(scenario(L, summary = TRUE)); new <- sc[!ScenarioId %in% before & IsResult == "Yes"]
cat(sprintf("PROJECTION RESULTS %s (together, %.1f min)\n", paste(new$ScenarioId, collapse = ", "), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
for (p in new$ScenarioId) { x <- capture.output(runLog(scenario(L, p))); cat(grep("\\[Warning\\]", x, value = TRUE), sep = "\n") }
pick <- function(ps) new[ParentId == ps, ScenarioId][1]
base$run <- pick(base$projection); ifm$run <- pick(ifm$projection)
for (x in list(base, ifm)) {
  W <- scenario(project(L, 1), sprintf("EXP Wood Products on FM %s", x$label)); dependency(W) <- B
  saveDatasheet(W, data.frame(StageNameId = "18 - Wood Products", RunOrder = 1L), "core_Pipeline")
  saveDatasheet(W, data.frame(RunScenarioId = x$run, Draws = DR), "lucasCore_WoodProductsOptions")
  w <- run(W); cat(sprintf("%s: WOOD PRODUCTS RESULT %d\n", x$label, scenarioId(w))) }
# harvest realized, per iteration (ha), and the timber revenue (USD) and ha harvested per type
con <- DBI::dbConnect(RSQLite::SQLite(), LIB, flags = RSQLite::SQLITE_RO)
hv <- function(id) as.data.table(DBI::dbGetQuery(con, sprintf("SELECT o.Iteration, g.Name AS g, SUM(o.Amount) ha FROM stsim_OutputStratumTransition o JOIN stsim_TransitionGroup g ON g.TransitionGroupId = o.TransitionGroupId
  WHERE o.ScenarioId = %d AND g.Name LIKE 'Forest Harvest: Forest %%[Type]' GROUP BY o.Iteration, g.Name", id)))
tg <- function(id) as.data.table(DBI::dbGetQuery(con, sprintf("SELECT g.Name AS g, SUM(t.Amount) / COUNT(DISTINCT t.Iteration) target FROM stsim_TransitionTarget t JOIN stsim_TransitionGroup g ON g.TransitionGroupId = t.TransitionGroupId
  WHERE t.ScenarioId = %d AND t.Timestep > 2023 AND t.Timestep <= %d AND g.Name LIKE 'Forest Harvest: Forest %%[Type]' GROUP BY g.Name", id, 2023 + YRS)))
rv <- function(id) as.data.table(DBI::dbGetQuery(con, sprintf("SELECT o.Iteration, SUM(o.Amount) USD FROM stsim_OutputTransitionAttribute o JOIN stsim_TransitionAttributeType a ON a.TransitionAttributeTypeId = o.TransitionAttributeTypeId
  WHERE o.ScenarioId = %d AND a.Name = 'Management Revenue: Harvest Timber' GROUP BY o.Iteration", id)))
for (x in list(base, ifm)) { id <- as.integer(x$run); sid <- as.integer(x$setup)
  cat(sprintf("\n== %s (setup %d, run %d)\ntargets over the run, per iteration (ha):\n", x$label, sid, id)); print(tg(sid))
  cat("realized (ha):\n"); print(dcast(hv(id), Iteration ~ g, value.var = "ha")); cat("timber revenue (USD):\n"); print(rv(id)) }
DBI::dbDisconnect(con)
suppressPackageStartupMessages({ library(terra); library(sf); library(DBI); library(RSQLite) })
source("src/figures.R"); source("src/run-figures.R"); source("src/compare-figures.R")
Rr <- compare_runs(LIB, data.table(RunScenarioId = c(base$run, ifm$run), Baseline = c(TRUE, FALSE)))
cc <- compare_cost(Rr, LIB)
if (is.null(cc)) cat("no costs or revenue in these runs\n") else print(cc[, .(RunScenarioId, Role, Iterations, Revenue, NetCost, ExtraNetCost, CarbonGain, UsdPerMgC, UsdPerMgCLow, UsdPerMgCHigh, CarbonGainWithProducts, UsdPerMgCWithProducts)])
