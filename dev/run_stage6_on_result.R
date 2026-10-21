# Run stage 6 alone on the latest stage 5 result of a library (tests/phaseD-transitions.R builds one)
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); f <- if (length(a)) a[1] else "F:/lucasCore/dev/libs/lucasCore-transitions-California.ssim"
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE))
r5 <- max(sc[IsResult == "Yes", ScenarioId])
S <- rsyncrosim::scenario(P, sprintf("Historical transitions on result %d", r5)); dependency(S) <- r5
description(S) <- sprintf("Stage 6 alone (dev/run_stage6_on_result.R) on the stage 1 + 5 result %d: historical transition pathways and annual spatial multipliers.", r5)
saveDatasheet(S, data.frame(StageNameId = "6 - Historical Transitions", RunOrder = 1), "core_Pipeline")
t0 <- Sys.time(); R <- run(S); cat(sprintf("run took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
cat(paste(unique(lg[grepl("^6 Hist|Pathways|Land-use|30 m|Clearcut|Ag contraction|km2 over|MTBS|LANDFIRE|Sources|Failure|rror", lg)]), collapse = "\n"), "\n")
v <- datasheet(R, "lucasCore_OutputValidation"); ok <- nrow(v) > 0 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))
ts <- as.data.table(datasheet(R, "lucasCore_OutputTransitionSummary")); fwrite(ts, paste0(tools::file_path_sans_ext(f), "-transition-summary.csv"))
print(ts[, .(km2 = round(sum(Area)), km2_per_yr = round(sum(Area) / uniqueN(Timestep), 1), inel_pct = round(100 * sum(IneligibleArea) / sum(Area), 1),
             blocked_pct = round(100 * sum(AgeBlockedArea, na.rm = TRUE) / sum(Area), 1)), by = .(Source, TransitionGroup)])
for (k in c("stsim_Transition", "stsim_DeterministicTransition", "stsim_TransitionSpatialMultiplier", "stsim_TransitionTarget"))
  cat(sprintf("%-36s %d rows\n", k, nrow(datasheet(R, k))))
cat("result scenario:", scenarioId(R), "\n"); cat(if (ok) "TRANSITIONS OK\n" else "TRANSITIONS FAILED\n")
