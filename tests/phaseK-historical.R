# =============================================================================
# phaseK-historical.R - a full build and the historical ST-Sim run on top of it (tools/new-historical.R)
# =============================================================================
# In the phaseJ library (dev/libs/lucasCore-forest-map.ssim, which has a Growth Curves result): a build with stages 1, 5, 3, 4, 6, 7, 8
# for the study area, then the historical scenario on that result, run 1985-2023. Compares the run with the build: carbon in the first
# year vs the initial stock maps, transition area vs stage 6's expected area, state class change, and the carbon trajectory.
# Usage: Rscript tests/phaseK-historical.R [--units="County: Placer California"] [--iterations=1] [--build=<existing result id>]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
UNITS <- opt("units", "County: Placer California"); IT <- opt("iterations", "1")
f <- "F:/lucasCore/dev/libs/lucasCore-forest-map.ssim"; if (!file.exists(f)) stop("run tests/phaseJ-forest-map.R first")
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE))
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
mins <- function(t0) as.numeric(Sys.time() - t0, units = "mins")

bid <- as.integer(opt("build", NA))
if (is.na(bid)) {
  sfd <- sc[Name == "Stock-Flow Definitions", ScenarioId]; gid <- sc[IsResult == "Yes" & grepl("^Growth Curves", Name), max(ScenarioId)]
  nm <- "Build: full pipeline"; for (i in sc[Name == nm, ScenarioId]) delete(L, scenario = i, force = TRUE)
  S <- rsyncrosim::scenario(P, nm); dependency(S) <- c(sfd, gid)
  description(S) <- sprintf("tests/phaseK-historical.R: stages 1, 5, 3, 4, 6, 7, 8 for %s (Forest Type Map LANDFIRE EVT, default options); curves from Growth Curves result %d.", UNITS, gid)
  saveDatasheet(S, data.frame(UnitId = trimws(strsplit(UNITS, ",")[[1]])), "lucasCore_StudyArea")
  st <- c("1 - Study Area and Strata", "5 - Initial Conditions", "3 - Carbon Flows", "4 - Spin-up and Initial Stocks", "6 - Historical Transitions",
          "7 - Climate Multipliers", "8 - Initial Stock Maps")
  saveDatasheet(S, data.frame(StageNameId = st, RunOrder = seq_along(st)), "core_Pipeline")
  t0 <- Sys.time(); RB <- run(S); cat(sprintf("build took %.1f min\n", mins(t0)))
  v <- as.data.table(datasheet(RB, "lucasCore_OutputValidation")); print(v[, .(checks = .N, failed = sum(Status != "Pass")), by = Stage])
  if (!nrow(v) || any(v$Status != "Pass")) { print(v[Status != "Pass"]); stop("build failed its checks") }
  bid <- scenarioId(RB)
}
RB <- scenario(L, bid)

# ---- the historical scenario -------------------------------------------------------------------------------------------
out <- system2("C:/Program Files/R/R-4.6.1/bin/Rscript.exe", c("F:/lucasCore/tools/new-historical.R", shQuote(f), sprintf("--build=%d", bid),
               sprintf("--iterations=%s", IT), "--replace"), stdout = TRUE, stderr = TRUE)
out <- out[!grepl("Warning|undetermined|^In ssimLibrary", out)]; cat(out, sep = "\n")
hid <- as.integer(tail(out, 1)); if (is.na(hid)) stop("tools/new-historical.R did not create the scenario")
H <- scenario(L, hid); t0 <- Sys.time()
RH <- tryCatch(run(H), error = function(e) { cat("RUN FAILED:", conditionMessage(e), "\n"); NULL })
if (is.null(RH)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & ParentId == hid]
  if (nrow(r)) cat(tail(logl(scenario(L, max(r$ScenarioId))), 60), sep = "\n"); stop("historical run failed") }
cat(sprintf("historical run took %.1f min (result scenario %d)\n", mins(t0), scenarioId(RH)))
lg <- logl(RH); cat(unique(lg[grepl("rror|arning|Failure|Total time", lg)]), sep = "\n")

# ---- comparisons -----------------------------------------------------------------------------------------------------------
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
ip <- ds(RB, "stsim_InitialConditionsSpatialProperties"); cell_km2 <- ip$CellArea[1]; cat("cell area", cell_km2, ip$CellAreaUnits[1], "\n")

stk <- ds(RH, "stsim_OutputStock"); st_tot <- stk[, .(Amount = sum(Amount) / max(Iteration)), by = .(Timestep, StockGroupId)]
cat("\nstock groups, first and last year (total over the study area, run's mass units x area units):\n")
print(dcast(st_tot[Timestep %in% range(Timestep)], StockGroupId ~ Timestep, value.var = "Amount"))
iss <- ds(RB, "lucasCore_OutputInitialStockSummary"); cat("\nbuild initial stock summary, all classes: total", round(sum(iss$TotalTg), 3), "Tg\n")

tr <- ds(RH, "stsim_OutputStratumTransition")[, .(Run = sum(Amount) / max(Iteration)), by = .(TransitionGroupId)]
ex <- ds(RB, "lucasCore_OutputTransitionSummary")[, .(Expected = sum(Area)), by = .(TransitionGroupId = TransitionGroup, Source)]
cmp <- merge(ex, tr, by = "TransitionGroupId", all = TRUE)[order(-pmax(Expected, Run, na.rm = TRUE))]
cat("\ntransition area 1986-2023: stage 6 expected (km2) vs the run (area units):\n"); print(cmp)

ss <- ds(RH, "stsim_OutputStratumState"); cls <- ss[Timestep %in% range(Timestep), .(Amount = sum(Amount) / max(Iteration)), by = .(Timestep, StateClassId)]
cw <- dcast(cls, StateClassId ~ Timestep, value.var = "Amount", fill = 0); setnames(cw, c("StateClassId", "First", "Last"))
cat("\nstate classes, first vs last year:\n"); print(cw[, Change := Last - First][order(-abs(Change))][1:min(.N, 20)])
saveRDS(list(stock = st_tot, transitions = cmp, classes = cw, build = bid, run = scenarioId(RH)), "F:/lucasCore/dev/libs/test-historical.rds")
cat("HISTORICAL RUN DONE\n")
