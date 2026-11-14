# A baseline matched to dev/management/lassen-cost-ranges.R (user 2026-11-13: "Run a matched baseline for Lassen next?" - "Yes, run
# it"): the same Projection Setup (Build, historical run, options, iterations; stage 9's seeded draws give the same historical-year
# schedule, fire included) with no Management Actions, the same projection years and iterations; then stage 18 (Wood Products) on it
# and the Compare Cost Summary of the management run against it, on both carbon bases.
# Usage: Rscript dev/management/lassen-matched-baseline.R <Build result> <historical result> <management projection result> [years = 13] [iterations = 3] [draws = 20] [management setup result]
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); B <- as.integer(a[1]); H <- as.integer(a[2]); PM <- as.integer(a[3])
YRS <- if (length(a) > 3) as.integer(a[4]) else 13L; IT <- if (length(a) > 4) as.integer(a[5]) else 3L; DR <- if (length(a) > 5) as.integer(a[6]) else 20L
LIB <- "F:/lucasCore/dev/libs/lassen/Lassen.ssim"; R <- file.path(R.home("bin"), "Rscript.exe")
sh <- function(...) { o <- system2(R, c(...), stdout = TRUE, stderr = TRUE); tail(grep("^[0-9]+$", trimws(o), value = TRUE), 1) }
SS <- as.integer(sh("tools/new-projection-setup.R", LIB, sprintf("--build=%d", B), sprintf("--historical=%d", H), "--resolution=150", "--end=2050",
                    "--name=\"Projection Setup matched baseline\"", "--replace"))
invisible(system2(R, c("dev/reforestation/lassen-setup-options.R", SS), stdout = TRUE, stderr = TRUE))
L <- suppressWarnings(ssimLibrary(LIB, summary = FALSE)); S <- scenario(L, SS)
po <- datasheet(S, "lucasCore_ProjectionOptions", empty = FALSE); po$Iterations <- IT; saveDatasheet(S, po, "lucasCore_ProjectionOptions")
r <- run(S); cat("SETUP RESULT", scenarioId(r), "\n")
# the same draws as the management run's setup?
sched <- function(id) as.data.table(datasheet(scenario(L, id), "lucasCore_OutputProjectionSchedule", lookupsAsFactors = FALSE, empty = FALSE))
ms <- if (length(a) > 6) as.integer(a[7]) else NA_integer_   # the management run's setup result, to compare draw schedules
s1 <- sched(scenarioId(r)); s0 <- if (!is.na(ms)) sched(ms) else data.table()
k <- intersect(names(s1), c("Iteration", "Timestep", "SamplingSet", "HistoricalYear"))
cat(sprintf("draw schedule: baseline %d rows, management setup %s %d rows, identical: %s\n", nrow(s1), ms, nrow(s0),
            nrow(s0) > 0 && isTRUE(all.equal(s1[, ..k][do.call(order, s1[, ..k])], s0[, ..k][do.call(order, s0[, ..k])], check.attributes = FALSE))))
PS <- as.integer(sh("tools/new-projection.R", LIB, sprintf("--build=%d", scenarioId(r)), sprintf("--years=%d", YRS), sprintf("--iterations=%d", IT),
                    "--name=\"Projection matched baseline\"", "--replace"))
p <- run(scenario(L, PS)); cat("PROJECTION RESULT", scenarioId(p), "\n")
x <- capture.output(runLog(p)); cat(grep("\\[Warning\\]", x, value = TRUE), sep = "\n")
# stage 18 on the baseline (the management run already has one: dev/management/lassen-cost-hwp.R)
W <- scenario(project(L, 1), "EXP Wood Products on matched baseline"); dependency(W) <- B
saveDatasheet(W, data.frame(StageNameId = "18 - Wood Products", RunOrder = 1L), "core_Pipeline")
saveDatasheet(W, data.frame(RunScenarioId = scenarioId(p), Draws = DR), "lucasCore_WoodProductsOptions")
w <- run(W); cat("WOOD PRODUCTS RESULT", scenarioId(w), "\n")
suppressPackageStartupMessages({ library(terra); library(sf); library(DBI); library(RSQLite) })
source("src/figures.R"); source("src/run-figures.R"); source("src/compare-figures.R")
Rr <- compare_runs(LIB, data.table(RunScenarioId = c(scenarioId(p), PM), Baseline = c(TRUE, FALSE)))
cb <- compare_carbon(Rr); print(cb[, .(RunScenarioId, Role, CarbonStart, CarbonEnd, VsBaseline, HwpStored)])
cs <- compare_cost(Rr, LIB)
print(cs[, .(RunScenarioId, Role, Iterations, NetCost, NetCostLow, NetCostHigh, CarbonGain, UsdPerMgC, UsdPerMgCLow, UsdPerMgCHigh,
             CarbonGainWithProducts, UsdPerMgCWithProducts, UsdPerMgCWithProductsLow, UsdPerMgCWithProductsHigh)])
# carbon by pool group at the end, management minus baseline (Tg C)
pool <- function(id) { d <- as.data.table(datasheet(scenario(L, id), "stsim_OutputStock", lookupsAsFactors = FALSE)); y <- max(d$Timestep)
  d[Timestep == y, .(Tg = sum(Amount) / 1e6 / uniqueN(d$Iteration)), by = .(g = sub(":.*| \\[Type\\]", "", StockGroupId))] }
d <- merge(pool(scenarioId(p)), pool(PM), by = "g", suffixes = c(".base", ".mgmt")); d[, diff := round(Tg.mgmt - Tg.base, 4)]; print(d[order(-abs(diff))])
