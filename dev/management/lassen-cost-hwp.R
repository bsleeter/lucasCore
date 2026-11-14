# The cost summary's two carbon bases (user 2026-11-13: "The two comparisons are a good approach (against ecosystem carbon and
# ecosystem + HWP)"): stage 18 (Wood Products) on a baseline projection and a Management Actions projection, then compare_cost.
# Plumbing test: the two runs need not share iterations or fire draws (then the carbon difference is mostly fire noise).
# Usage: Rscript dev/management/lassen-cost-hwp.R <Build result> <baseline projection result> <management projection result> [draws = 20]
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); B <- as.integer(a[1]); P0 <- as.integer(a[2]); P1 <- as.integer(a[3]); DR <- if (length(a) > 3) as.integer(a[4]) else 20L
LIB <- "F:/lucasCore/dev/libs/lassen/Lassen.ssim"
L <- suppressWarnings(ssimLibrary(LIB, summary = FALSE)); P <- project(L, 1)
for (rid in c(P0, P1)) {
  nm <- sprintf("EXP Wood Products on %d", rid)
  old <- as.data.table(scenario(L, summary = TRUE))[Name == nm & IsResult == "No", ScenarioId]; for (o in old) delete(L, scenario = o, force = TRUE)
  S <- scenario(P, nm); dependency(S) <- B
  saveDatasheet(S, data.frame(StageNameId = "18 - Wood Products", RunOrder = 1L), "core_Pipeline")
  saveDatasheet(S, data.frame(RunScenarioId = rid, Draws = DR), "lucasCore_WoodProductsOptions")
  r <- run(S); cat(sprintf("Wood Products on %d: result %d\n", rid, scenarioId(r)))
  x <- capture.output(runLog(r)); cat(grep("\\[Warning\\]|stored|Stored|failed", x, value = TRUE), sep = "\n") }
suppressPackageStartupMessages({ library(terra); library(sf); library(DBI); library(RSQLite) })
source("src/figures.R"); source("src/run-figures.R"); source("src/compare-figures.R")
Rr <- compare_runs(LIB, data.table(RunScenarioId = c(P0, P1), Baseline = c(TRUE, FALSE)))
cat("wood products stored at the end (Tg C):", paste(vapply(Rr, function(r) if (is.null(r$X$wp)) "none" else sprintf("%d: %.4f", r$rid, at_year(wp_tg(r$X, "Stored"), r$X$years[2])), ""), collapse = "; "), "\n")
cs <- compare_cost(Rr, LIB); print(cs[, .(RunScenarioId, Role, Iterations, NetCost, ExtraNetCost, CarbonGain, UsdPerMgC, CarbonGainWithProducts, UsdPerMgCWithProducts)])
