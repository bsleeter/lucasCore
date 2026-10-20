# =============================================================================
# spike.R - Phase A spike driver: result-to-input mechanisms (run after tests/phaseA-smoke.R)
# =============================================================================
# A1  a scenario whose dependency is a RESULT scenario (the stage 1 run) - is it allowed, and does a run see the data?
# A2  "promote": copy the result's datasheets (and files) into an ordinary input scenario from outside a run, then depend on it
# B   a stage saving into another scenario during its run - does it persist?
# =============================================================================
suppressPackageStartupMessages(library(rsyncrosim))
f <- "F:/lucasCore/dev/libs/lucasCore-smoke.ssim"
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions")
sc <- scenario(L, summary = TRUE); res <- sc[sc$IsResult == "Yes" & grepl("^Build", sc$Name), ]
rid <- max(res$ScenarioId); R <- rsyncrosim::scenario(L, rid); cat("stage 1 result scenario:", rid, "\n")
tgt <- rsyncrosim::scenario(P, "Spike Target")
logline <- function(S, pat) { lg <- trimws(strsplit(paste(runLog(S), collapse = "\n"), "\n")[[1]]); lg[grepl(pat, lg)] }
spike_run <- function(S) { saveDatasheet(S, data.frame(StageNameId = "U - Spike (development)", RunOrder = 1), "core_Pipeline")
  out <- tryCatch(run(S), error = function(e) e); if (inherits(out, "error")) { cat("run error:", conditionMessage(out), "\n"); return(NULL) }
  for (p in c("library file", "^A\\.", "^B\\.")) cat("  ", logline(out, p), sep = "\n  "); out }

cat("\n== A1: dependency on a result scenario\n")
s1 <- rsyncrosim::scenario(P, "Spike A1 - depends on result")
d1 <- tryCatch({ dependency(s1) <- rid; "set" }, error = function(e) conditionMessage(e)); cat("dependency(", rid, "):", d1, "\n")
print(tryCatch(dependency(s1), error = function(e) conditionMessage(e)))
if (identical(d1, "set")) spike_run(s1)

cat("\n== A2: promote result -> input scenario, then depend on it\n")
s2 <- rsyncrosim::scenario(P, "Strata [promoted from result]")
ic <- datasheet(R, "stsim_InitialConditionsSpatial"); print(ic[, c("StratumFileName", "TertiaryStratumFileName")])
saveDatasheet(s2, ic, "stsim_InitialConditionsSpatial")
ic2 <- datasheet(s2, "stsim_InitialConditionsSpatial"); cat("promoted copy:", ic2$StratumFileName, " exists:", file.exists(ic2$StratumFileName), "\n")
s3 <- rsyncrosim::scenario(P, "Spike A2 - depends on promoted")
dependency(s3) <- scenarioId(s2); spike_run(s3)

cat("\n== B: did the in-run save into 'Spike Target' persist?\n")
print(datasheet(rsyncrosim::scenario(L, scenarioId(tgt)), "lucasCore_BuildOptions"))
