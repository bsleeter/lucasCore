# Fuel Treatments plumbing test (user 2026-11-13: "Next is Fuel Treatments"; "Lets go with the severity shift"): two Projection Setups
# on one Lassen Build and historical run (made after tools/make_fuel_treatments.R, so the Build has the treatment pathways and
# flows), the same seeded draws: a baseline (no treatments) and treatments (thin and burn 400 ha a year where wildfire burned more
# often, prescribed burn 600 ha a year at random). Both projections run at once (multi-scenario multiprocessing), 2024-2036, 3
# iterations; then stage 18 on each and the Compare Cost Summary. Reports: the area treated, the high-severity area burned (baseline
# against treatments, per iteration), the multipliers stage 9 wrote, carbon, cost and USD per Mg C.
# Usage: Rscript dev/fuel-treatments/lassen-fuel-treatments.R <Build result> <historical result> [years = 13] [iterations = 3] [draws = 20]
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); B <- as.integer(a[1]); H <- as.integer(a[2])
YRS <- if (length(a) > 2) as.integer(a[3]) else 13L; IT <- if (length(a) > 3) as.integer(a[4]) else 3L; DR <- if (length(a) > 4) as.integer(a[5]) else 20L
LIB <- "F:/lucasCore/dev/libs/lassen/Lassen.ssim"; R <- file.path(R.home("bin"), "Rscript.exe")
sh <- function(...) { o <- system2(R, c(...), stdout = TRUE, stderr = TRUE); tail(grep("^[0-9]+$", trimws(o), value = TRUE), 1) }
L <- suppressWarnings(ssimLibrary(LIB, summary = FALSE))
one <- function(label, ft) {
  SS <- as.integer(sh("tools/new-projection-setup.R", LIB, sprintf("--build=%d", B), sprintf("--historical=%d", H), "--resolution=150", "--end=2050",
                      sprintf("--name=\"Projection Setup FT %s\"", label), "--replace"))
  invisible(system2(R, c("dev/reforestation/lassen-setup-options.R", SS), stdout = TRUE, stderr = TRUE))
  S <- scenario(L, SS); po <- datasheet(S, "lucasCore_ProjectionOptions", empty = FALSE); po$Iterations <- IT; saveDatasheet(S, po, "lucasCore_ProjectionOptions")
  if (!is.null(ft)) saveDatasheet(S, ft, "lucasCore_FuelTreatment")
  r <- run(S); cat(sprintf("%s: SETUP RESULT %d\n", label, scenarioId(r)))
  x <- capture.output(runLog(r)); cat(grep("Fuel Treatments|Timber revenue|\\[Warning\\]|FAIL", x, value = TRUE), sep = "\n")
  if (!is.null(ft)) print(datasheet(r, "lucasCore_OutputFuelTreatment"))
  PS <- as.integer(sh("tools/new-projection.R", LIB, sprintf("--build=%d", scenarioId(r)), sprintf("--years=%d", YRS), sprintf("--iterations=%d", IT),
                      sprintf("--name=\"Projection FT %s\"", label), "--replace"))
  list(label = label, setup = scenarioId(r), projection = PS) }
base <- one("baseline", NULL)
trt <- one("treatments", data.frame(TreatmentId = c("Thin and burn", "Prescribed burn"), Amount = c(400, 600), StartYear = 2024L, EndYear = 2050L,
                                    Priority = c("Fire likelihood (where wildfire burned more often)", "Random among eligible cells")))
# rsyncrosim's run() runs a list of scenarios one at a time; the console runs them at once given together (--sids)
t0 <- Sys.time(); before <- as.data.table(scenario(L, summary = TRUE))$ScenarioId
tt <- command(list(run = NULL, lib = filepath(L), sids = paste(c(base$projection, trt$projection), collapse = ",")), session(L))
if (!identical(tt[1], "saved")) cat(tt, sep = "\n")
sc <- as.data.table(scenario(L, summary = TRUE)); new <- sc[!ScenarioId %in% before & IsResult == "Yes"]
cat(sprintf("PROJECTION RESULTS %s (together, %.1f min)\n", paste(new$ScenarioId, collapse = ", "), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
for (p in new$ScenarioId) { x <- capture.output(runLog(scenario(L, p))); cat(grep("\\[Warning\\]|\\[Failure\\]", x, value = TRUE), sep = "\n") }
pick <- function(ps) new[ParentId == ps, ScenarioId][1]
base$run <- pick(base$projection); trt$run <- pick(trt$projection)
if (is.na(base$run) || is.na(trt$run)) stop("a projection did not run: see the run logs")
for (x in list(base, trt)) {
  W <- scenario(project(L, 1), sprintf("EXP Wood Products on FT %s", x$label)); dependency(W) <- B
  saveDatasheet(W, data.frame(StageNameId = "18 - Wood Products", RunOrder = 1L), "core_Pipeline")
  saveDatasheet(W, data.frame(RunScenarioId = x$run, Draws = DR), "lucasCore_WoodProductsOptions")
  w <- run(W); cat(sprintf("%s: WOOD PRODUCTS RESULT %d\n", x$label, scenarioId(w))) }
con <- DBI::dbConnect(RSQLite::SQLite(), LIB, flags = RSQLite::SQLITE_RO)
q <- function(s, ...) as.data.table(DBI::dbGetQuery(con, sprintf(s, ...)))
tr <- function(id, pat) q("SELECT o.Iteration, g.Name AS g, SUM(o.Amount) ha FROM stsim_OutputStratumTransition o JOIN stsim_TransitionGroup g ON g.TransitionGroupId = o.TransitionGroupId
  WHERE o.ScenarioId = %d AND g.Name LIKE '%s' GROUP BY o.Iteration, g.Name", id, pat)
cat("\nmultipliers stage 9 wrote (treatment setup), severity rows:\n")
print(q("SELECT g.Name AS grp, t.Name AS since, m.TSTMin, m.TSTMax, m.Amount FROM stsim_TransitionMultiplierValue m JOIN stsim_TransitionGroup g ON g.TransitionGroupId = m.TransitionGroupId
  LEFT JOIN stsim_TransitionGroup t ON t.TransitionGroupId = m.TSTGroupId WHERE m.ScenarioId = %d AND m.TSTGroupId IS NOT NULL ORDER BY m.TransitionMultiplierValueId", trt$setup))
cat("time since transition groups:\n"); print(q("SELECT y.Name AS type, g.Name AS grp FROM stsim_TimeSinceTransitionGroup s JOIN stsim_TransitionType y ON y.TransitionTypeId = s.TransitionTypeId
  JOIN stsim_TransitionGroup g ON g.TransitionGroupId = s.TransitionGroupId WHERE s.ScenarioId = %d", trt$setup))
cat("\narea treated (ha over the run):\n"); print(dcast(tr(trt$run, "Fuel Treatment: %%[Type]"), Iteration ~ g, value.var = "ha"))
fire <- merge(tr(base$run, "Fire: %% Severity [Type]")[, .(Iteration, g, base = ha)], tr(trt$run, "Fire: %% Severity [Type]")[, .(Iteration, g, treat = ha)], by = c("Iteration", "g"), all = TRUE)
cat("burned by severity (ha over the run), baseline against treatments:\n"); print(fire[order(g, Iteration)])
# beyond the severity shift (user 2026-11-13: "Because LUCAS also includes the pathway to a Disturbed forest state, which can result
# in permanent conversion, it is possible we could see the added benefit of treatment beyond just severity reduction"): less
# high-severity fire means less forest entering the disturbed classes, so less of it waiting, reburning and converting
pd <- merge(tr(base$run, "Post-disturbance: %%[Type]")[, .(Iteration, g, base = ha)], tr(trt$run, "Post-disturbance: %%[Type]")[, .(Iteration, g, treat = ha)], by = c("Iteration", "g"), all = TRUE)
cat("post-disturbance return and conversion (ha over the run), baseline against treatments:\n"); print(pd[order(g, Iteration)])
cover <- function(id) { y <- q("SELECT MAX(Timestep) y FROM stsim_OutputStratumState WHERE ScenarioId = %d", id)$y
  d <- q("SELECT s.Iteration, c.Name AS cls, SUM(s.Amount) ha FROM stsim_OutputStratumState s JOIN stsim_StateClass c ON c.StateClassId = s.StateClassId
          WHERE s.ScenarioId = %d AND s.Timestep = %d GROUP BY s.Iteration, c.Name", id, y)
  d[, .(forest = sum(ha[grepl("^Forest:", cls)]), disturbed_forest = sum(ha[grepl("^Disturbed:", cls) & grepl("Group$", cls)]),
        shrub_grass = sum(ha[grepl("^(Shrubland|Grassland|Herbaceous)", cls)])), by = Iteration][, Year := y][] }
cv <- merge(cover(base$run), cover(trt$run), by = c("Iteration", "Year"), suffixes = c(".base", ".treat"))
cat("at the end (ha): forest, disturbed forest, shrub and grass, baseline against treatments:\n"); print(cv)
DBI::dbDisconnect(con)
suppressPackageStartupMessages({ library(terra); library(sf); library(DBI); library(RSQLite) })
source("src/figures.R"); source("src/run-figures.R"); source("src/compare-figures.R")
Rr <- compare_runs(LIB, data.table(RunScenarioId = c(base$run, trt$run), Baseline = c(TRUE, FALSE)))
print(compare_carbon(Rr)[, .(RunScenarioId, Role, CarbonStart, CarbonEnd, VsBaseline, HwpStored)])
cc <- compare_cost(Rr, LIB)
if (is.null(cc)) cat("no costs in these runs\n") else print(cc[, .(RunScenarioId, Role, Cost, Revenue, ExtraNetCost, CarbonGain, UsdPerMgC, UsdPerMgCLow, UsdPerMgCHigh, CarbonGainWithProducts, UsdPerMgCWithProducts)])
