# Rangeland restoration plumbing test on Hart Mountain (mitigation measure 5; user 2026-11-14: "keep it straight to native sage
# steppe but with a corresponding failure rate"; "Lets switch to Hart Mountain ... 300m"): two Projection Setups on one Build and
# historical run, the same seeded draws: a baseline (no management) and restoration (aerial seeding 300 ha a year, drill seeding
# 200, sagebrush planting 50, herbicide and seeding 200, each at its default success, window and regional cost). Every allocation
# surface None (no fitting: a plumbing test). Both projections run at once (multi-scenario multiprocessing, 20 jobs: 10 iterations each), then stage 18 and
# the Compare Cost Summary. Reports: the area treated by type, the classes at the end (Native Sage Steppe, the burned sage
# family, annual grass), post-disturbance return and conversion, carbon, cost and USD per Mg C.
# Usage: Rscript dev/rangeland-restoration/hart-restoration.R <Build result> <historical result> [years = 27] [iterations = 10] [draws = 20]
#   resume after the projections: ... <draws> <baseline run> <restoration run> <baseline setup> <restoration setup>
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); B <- as.integer(a[1]); H <- as.integer(a[2])
YRS <- if (length(a) > 2) as.integer(a[3]) else 27L; IT <- if (length(a) > 3) as.integer(a[4]) else 10L; DR <- if (length(a) > 4) as.integer(a[5]) else 20L
LIB <- "F:/lucasCore/dev/libs/hart-mountain/HartMountain.ssim"; R <- file.path(R.home("bin"), "Rscript.exe")
sh <- function(...) { o <- system2(R, c(...), stdout = TRUE, stderr = TRUE); tail(grep("^[0-9]+$", trimws(o), value = TRUE), 1) }
L <- suppressWarnings(ssimLibrary(LIB, summary = FALSE))
# a plumbing test: no fitted surfaces (every allocation None), as the Lassen tests' setups but without their fitted reforestation
LS <- suppressWarnings(ssimLibrary("F:/lucasCore/dev/libs/lassen/Lassen.ssim", summary = FALSE))
alloc <- as.data.table(datasheet(scenario(LS, 16L), "lucasCore_ProjectionAllocation", empty = FALSE, lookupsAsFactors = FALSE))
alloc[, Method := "None (random within its strata)"]
so <- datasheet(scenario(LS, 16L), "lucasCore_SuitabilityOptions", empty = FALSE); so$FitResolution <- 300L
one <- function(label, ma) {
  SS <- as.integer(sh("tools/new-projection-setup.R", LIB, sprintf("--build=%d", B), sprintf("--historical=%d", H), "--resolution=300", sprintf("--end=%d", 2023 + YRS),
                      sprintf("--name=\"Projection Setup RR %s\"", label), "--replace"))
  S <- scenario(L, SS)
  saveDatasheet(S, as.data.frame(alloc), "lucasCore_ProjectionAllocation"); saveDatasheet(S, so, "lucasCore_SuitabilityOptions")
  po <- datasheet(S, "lucasCore_ProjectionOptions", empty = FALSE); po$Iterations <- IT; saveDatasheet(S, po, "lucasCore_ProjectionOptions")
  if (!is.null(ma)) saveDatasheet(S, ma, "lucasCore_ManagementAction")
  r <- run(S); cat(sprintf("%s: SETUP RESULT %d\n", label, scenarioId(r)))
  x <- capture.output(runLog(r)); cat(grep("Management Actions|\\[Warning\\]|FAIL", x, value = TRUE), sep = "\n")
  if (!is.null(ma)) print(datasheet(r, "lucasCore_OutputManagementAction"))
  PS <- as.integer(sh("tools/new-projection.R", LIB, sprintf("--build=%d", scenarioId(r)), sprintf("--years=%d", YRS), sprintf("--iterations=%d", IT),
                      sprintf("--name=\"Projection RR %s\"", label), "--replace"))
  list(label = label, setup = scenarioId(r), projection = PS) }
RES <- length(a) >= 9
if (RES) { base <- list(label = "baseline", run = as.integer(a[6]), setup = as.integer(a[8])); trt <- list(label = "restoration", run = as.integer(a[7]), setup = as.integer(a[9])) } else {
base <- one("baseline", NULL)
trt <- one("restoration", data.frame(ActionId = c("Aerial seeding", "Drill seeding", "Sagebrush planting", "Herbicide and seeding"), Amount = c(300, 200, 50, 200),
                                     StartYear = 2024L, EndYear = 2023L + YRS))
# multi-scenario multiprocessing (user 2026-11-13: "st-sim scenarios ... can run at the same time"): both at once, 20 jobs (user
# 2026-11-14: "make sure multiprocessing is turned on with 20 cores at least"). Hart Mountain has too few strata units for spatial tiles
# to use them, so the jobs are iterations: 10 per projection, two projections
mp <- datasheet(L, "core_Multiprocessing"); mp$EnableMultiprocessing <- TRUE; mp$MaximumJobs <- 20L
if ("EnableMultiScenario" %in% names(mp)) mp$EnableMultiScenario <- TRUE
saveDatasheet(L, mp, "core_Multiprocessing")
t0 <- Sys.time(); before <- as.data.table(scenario(L, summary = TRUE))$ScenarioId
tt <- command(list(run = NULL, lib = filepath(L), sids = paste(c(base$projection, trt$projection), collapse = ",")), session(L))
if (!identical(tt[1], "saved")) cat(tt, sep = "\n")
sc <- as.data.table(scenario(L, summary = TRUE)); new <- sc[!ScenarioId %in% before & IsResult == "Yes"]
cat(sprintf("PROJECTION RESULTS %s (together, %.1f min)\n", paste(new$ScenarioId, collapse = ", "), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
for (p in new$ScenarioId) { x <- capture.output(runLog(scenario(L, p))); cat(grep("\\[Warning\\]|\\[Failure\\]", x, value = TRUE), sep = "\n") }
pick <- function(ps) new[ParentId == ps, ScenarioId][1]
base$run <- pick(base$projection); trt$run <- pick(trt$projection)
if (is.na(base$run) || is.na(trt$run)) stop("a projection did not run: see the run logs") }
for (x in list(base, trt)) {
  W <- scenario(project(L, 1), sprintf("EXP Wood Products on RR %s", x$label)); dependency(W) <- B
  saveDatasheet(W, data.frame(StageNameId = "18 - Wood Products", RunOrder = 1L), "core_Pipeline")
  saveDatasheet(W, data.frame(RunScenarioId = x$run, Draws = DR), "lucasCore_WoodProductsOptions")
  w <- run(W); cat(sprintf("%s: WOOD PRODUCTS RESULT %d\n", x$label, scenarioId(w))) }
con <- DBI::dbConnect(RSQLite::SQLite(), LIB, flags = RSQLite::SQLITE_RO)
q <- function(s, ...) as.data.table(DBI::dbGetQuery(con, sprintf(s, ...)))
tr <- function(id, pat) q("SELECT o.Iteration, g.Name AS g, SUM(o.Amount) ha FROM stsim_OutputStratumTransition o JOIN stsim_TransitionGroup g ON g.TransitionGroupId = o.TransitionGroupId
  WHERE o.ScenarioId = %d AND g.Name LIKE '%s' GROUP BY o.Iteration, g.Name", id, pat)
cat("\nstart (ha, iteration 1): sage family, burned sage family, annual grass\n")
print(q("SELECT c.Name AS cls, SUM(s.Amount) ha FROM stsim_OutputStratumState s JOIN stsim_StateClass c ON c.StateClassId = s.StateClassId
  WHERE s.ScenarioId = %d AND s.Iteration = 1 AND s.Timestep = 2024 AND (c.Name LIKE '%%Sage%%' OR c.Name LIKE 'Grassland%%' OR c.Name LIKE '%%Non-sage%%') GROUP BY c.Name", base$run))
cat("\narea treated (ha over the run), by type:\n"); print(dcast(tr(trt$run, "Management: % [Type]"), Iteration ~ g, value.var = "ha"))
fire <- merge(tr(base$run, "Fire: %% Severity [Type]")[, .(Iteration, g, base = ha)], tr(trt$run, "Fire: %% Severity [Type]")[, .(Iteration, g, treat = ha)], by = c("Iteration", "g"), all = TRUE)
cat("burned by severity (ha over the run):\n"); print(fire[order(g, Iteration)])
pd <- merge(tr(base$run, "Post-disturbance: %%[Type]")[, .(Iteration, g, base = ha)], tr(trt$run, "Post-disturbance: %%[Type]")[, .(Iteration, g, treat = ha)], by = c("Iteration", "g"), all = TRUE)
cat("post-disturbance return and conversion (ha over the run):\n"); print(pd[order(g, Iteration)])
cover <- function(id) { y <- q("SELECT MAX(Timestep) y FROM stsim_OutputStratumState WHERE ScenarioId = %d", id)$y
  d <- q("SELECT s.Iteration, c.Name AS cls, SUM(s.Amount) ha FROM stsim_OutputStratumState s JOIN stsim_StateClass c ON c.StateClassId = s.StateClassId
          WHERE s.ScenarioId = %d AND s.Timestep = %d GROUP BY s.Iteration, c.Name", id, y)
  d[, .(native = sum(ha[cls == "Shrubland: Native Sage Steppe"]), sage = sum(ha[cls %in% c("Shrubland: Sage", "Shrubland: Invaded Sage Steppe")]),
        burned_sage = sum(ha[cls %in% c("Disturbed: Sage", "Disturbed: Native Sage Steppe", "Disturbed: Invaded Sage Steppe")]),
        annual = sum(ha[cls == "Grassland: Annual"])), by = Iteration][, Year := y][] }
cv <- merge(cover(base$run), cover(trt$run), by = c("Iteration", "Year"), suffixes = c(".base", ".treat"))
cat("at the end (ha): Native Sage Steppe, other sage, burned sage, annual grass; baseline against restoration:\n"); print(cv)
DBI::dbDisconnect(con)
suppressPackageStartupMessages({ library(terra); library(sf); library(DBI); library(RSQLite) })
source("src/figures.R"); source("src/run-figures.R"); source("src/compare-figures.R")
Rr <- compare_runs(LIB, data.table(RunScenarioId = c(base$run, trt$run), Baseline = c(TRUE, FALSE)))
print(compare_carbon(Rr)[, .(RunScenarioId, Role, CarbonStart, CarbonEnd, VsBaseline, HwpStored)])
cc <- compare_cost(Rr, LIB)
if (is.null(cc)) cat("no costs in these runs\n") else print(cc[, .(RunScenarioId, Role, Cost, Revenue, ExtraNetCost, CarbonGain, UsdPerMgC, UsdPerMgCLow, UsdPerMgCHigh, CarbonGainWithProducts, UsdPerMgCWithProducts)])
