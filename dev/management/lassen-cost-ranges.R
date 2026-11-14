# Cost ranges test (user 2026-11-13: "Transition Attribute Values ... can also hold a distribution of cost values to give us a built
# in range in estimated cost"): the management setup of dev/management/lassen-management.R (replanting 300 ha a year with pile and
# burn, salvage 200 ha a year) on a Lassen Build and historical run, then a short projection with several iterations. Checks, per
# iteration: each cost per hectare (ST-Sim's total / hectares treated) lies in its default range and differs between iterations;
# salvage revenue per hectare falls 25% a year with the disturbed cell's age.
# Usage: Rscript dev/management/lassen-cost-ranges.R <Build result> <historical result> [years = 13] [iterations = 3]
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); B <- as.integer(a[1]); H <- as.integer(a[2]); YRS <- if (length(a) > 2) as.integer(a[3]) else 13L; IT <- if (length(a) > 3) as.integer(a[4]) else 3L
LIB <- "F:/lucasCore/dev/libs/lassen/Lassen.ssim"; R <- file.path(R.home("bin"), "Rscript.exe")
sh <- function(...) { o <- system2(R, c(...), stdout = TRUE, stderr = TRUE); tail(grep("^[0-9]+$", trimws(o), value = TRUE), 1) }
SS <- as.integer(sh("tools/new-projection-setup.R", LIB, sprintf("--build=%d", B), sprintf("--historical=%d", H), "--resolution=150", "--end=2050",
                    "--name=\"Projection Setup cost ranges test\"", "--replace"))
invisible(system2(R, c("dev/reforestation/lassen-setup-options.R", SS), stdout = TRUE, stderr = TRUE))
L <- ssimLibrary(LIB, summary = FALSE); S <- scenario(L, SS)
po <- datasheet(S, "lucasCore_ProjectionOptions", empty = FALSE); po$Iterations <- IT; saveDatasheet(S, po, "lucasCore_ProjectionOptions")   # (lassen-setup-options.R sets 1)
saveDatasheet(S, data.frame(ActionId = c("Replanting", "Salvage logging", "Replanting"), Amount = c(300, 200, NA), Budget = c(NA, NA, 500000),
                            StartYear = c(2024L, 2024L, 2030L), EndYear = 2050L, Priority = c(rep("Far from live forest (least likely to return on its own)", 1), NA, "Far from live forest (least likely to return on its own)"),
                            Survival = c(0.8, NA, 0.8), SitePreparation = c("Pile and burn", NA, "Pile and burn")), "lucasCore_ManagementAction")
r <- run(S); cat("SETUP RESULT", scenarioId(r), "\n")
x <- capture.output(runLog(r)); cat(grep("Management Actions", x, value = TRUE), sep = "\n")
print(datasheet(r, "lucasCore_OutputManagementAction"))
av <- as.data.table(datasheet(r, "stsim_TransitionAttributeValue", lookupsAsFactors = FALSE, empty = FALSE)); print(av)
PS <- as.integer(sh("tools/new-projection.R", LIB, sprintf("--build=%d", scenarioId(r)), sprintf("--years=%d", YRS), sprintf("--iterations=%d", IT),
                    "--name=\"Projection cost ranges test\"", "--replace"))
p <- run(scenario(L, PS)); cat("PROJECTION RESULT", scenarioId(p), "\n")
x <- capture.output(runLog(p)); cat(grep("\\[Warning\\]", x, value = TRUE), sep = "\n")
ta <- as.data.table(datasheet(p, "stsim_OutputTransitionAttribute", lookupsAsFactors = FALSE, empty = FALSE))
tr <- as.data.table(datasheet(p, "stsim_OutputStratumTransition", lookupsAsFactors = FALSE))[grepl("(Replanting|Salvage).*\\[Type\\]", TransitionGroupId)]
ha <- tr[, .(rep = sum(Amount[grepl("Replanting", TransitionGroupId)]), sal = sum(Amount[grepl("Salvage", TransitionGroupId)])), by = .(Iteration)]
usd <- dcast(ta[, .(USD = sum(Amount)), by = .(Iteration, a = sub("^Management (Cost|Revenue): ", "", TransitionAttributeTypeId))], Iteration ~ a, value.var = "USD", fill = 0)
k <- merge(ha, usd, by = "Iteration")
k[, `:=`(planting_per_ha = Planting / rep, prep_per_ha = `Site Preparation` / rep, logging_per_ha = if ("Salvage Logging" %in% names(k)) `Salvage Logging` / sal else NA_real_,
         revenue_per_ha = if ("Salvage Timber" %in% names(k)) `Salvage Timber` / sal else NA_real_)]
cat("per iteration: hectares treated, USD, USD per hectare\n"); print(k)
# the cost summary (stage 14 compare_cost) against the baseline projection 99 (27 years, 1 iteration; read at this run's end year)
suppressPackageStartupMessages({ library(terra); library(sf); library(DBI); library(RSQLite) }); source("src/figures.R"); source("src/run-figures.R"); source("src/compare-figures.R")
Rr <- compare_runs(LIB, data.table(RunScenarioId = c(99L, scenarioId(p)), Baseline = c(TRUE, FALSE))); print(compare_cost(Rr, LIB))
