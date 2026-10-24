# =============================================================================
# 01-isolate.R - why ST-Sim's multiprocessing job fails on lucasCore projections
# =============================================================================
# ST-Sim-only scenarios (3 projection years, 1 iteration) that depend on a finished projection result (all of stage 9's outputs) and
# on the same Build / Stock-Flow dependencies as its parent, each dropping one suspect sheet; all run with library multiprocessing
# on (EnableMultiprocessing, 2 jobs). Prints which variants run and the failure lines of those that don't.
# Usage: Rscript dev/mp/01-isolate.R [--result=<projection result id>]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions")
sc <- as.data.table(scenario(L, summary = TRUE))
rid <- as.integer(opt("result", max(sc[IsResult == "Yes" & ParentId == 68, ScenarioId])))
par <- sc[ScenarioId == rid, ParentId]; deps <- as.data.table(dependency(scenario(L, par)))$ScenarioId
cat(sprintf("base: result %d of scenario %d (dependencies %s)\n", rid, par, paste(deps, collapse = ", ")))
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
variants <- list(
  base = character(),
  no_size = c("stsim_TransitionSizeDistribution", "stsim_TransitionSizePrioritization"),
  no_init = "stsim_TransitionSpatialInitiationMultiplier",
  no_filter = "stsim_OutputFilterTransitionGroups",
  no_all = c("stsim_TransitionSizeDistribution", "stsim_TransitionSizePrioritization", "stsim_TransitionSpatialInitiationMultiplier", "stsim_OutputFilterTransitionGroups"))
saveDatasheet(L, data.frame(EnableMultiprocessing = TRUE, MaximumJobs = 2L, EnableMultiScenario = FALSE), "core_Multiprocessing")
on.exit(saveDatasheet(L, data.frame(EnableMultiprocessing = FALSE, MaximumJobs = 1L, EnableMultiScenario = FALSE), "core_Multiprocessing"))
res <- list()
for (v in names(variants)) {
  nm <- sprintf("MP test %s", v); for (i in sc[Name == nm & IsResult == "No", ScenarioId]) delete(L, scenario = i, force = TRUE)
  S <- rsyncrosim::scenario(P, nm); dependency(S) <- c(rid, deps)
  rc <- as.data.frame(datasheet(scenario(L, rid), "stsim_RunControl")); rc$MaximumTimestep <- rc$MinimumTimestep + 3L; rc$MaximumIteration <- 1L
  saveDatasheet(S, rc[, setdiff(names(rc), c("RunControlId", "ScenarioId")), drop = FALSE], "stsim_RunControl")
  st <- grep("ST-Sim|stsim", levels(datasheet(S, "core_Pipeline", lookupsAsFactors = TRUE, optional = TRUE)$StageNameId), value = TRUE, ignore.case = TRUE)[1]
  saveDatasheet(S, data.frame(StageNameId = st, RunOrder = 1L), "core_Pipeline")
  # dropping a sheet: an own, empty copy hides the dependency's rows
  for (k in variants[[v]]) { x <- datasheet(scenario(L, rid), k, optional = TRUE); x <- x[0, setdiff(names(x), c(paste0(sub("^stsim_", "", k), "Id"), "ScenarioId")), drop = FALSE]
    saveDatasheet(S, x, k) }
  t0 <- Sys.time(); R <- tryCatch(run(S), error = function(e) NULL)
  r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & ParentId == scenarioId(S)]; lg <- if (nrow(r)) logl(scenario(L, max(r$ScenarioId))) else character()
  ok <- !any(grepl("\\[Failure\\]", lg)) && nrow(r) > 0
  res[[v]] <- data.table(Variant = v, Dropped = paste(variants[[v]], collapse = ", "), OK = ok, Minutes = round(as.numeric(Sys.time() - t0, units = "mins"), 1))
  cat(sprintf("%-10s %s (%.1f min)\n", v, if (ok) "RUNS" else "FAILS", res[[v]]$Minutes))
  if (!ok) cat(unique(lg[grepl("Failure|rror|xception|at SyncroSim|at System", lg)])[1:8], sep = "\n") }
print(rbindlist(res))
