# =============================================================================
# phaseM-projection.R - mode 1: one continuous historical + projection run (stage 9 projection transitions)
# =============================================================================
# In a fresh starter copy (dev/libs/lucasCore-projection.ssim): the Build scenario with a projection to 2050 (stages 1, 5, 2, 3, 4, 6, 7, 8,
# 9; growth curves copied from the phaseJ library's Growth Curves result 4; LOCA2 SSP2-4.5 CanESM5; 2 iterations), then tools/new-historical.R makes the 1985-2050 run scenario and runs it.
# Compares projected transition areas with the historical years drawn (OutputProjectionSchedule) and reports the carbon trajectory.
# Usage: Rscript tests/phaseM-projection.R [--units="County: Placer California"] [--end=2050] [--build=<existing result id> [--stage9-again]]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
UNITS <- opt("units", "County: Placer California"); PEND <- as.integer(opt("end", 2050))
f <- "F:/lucasCore/dev/libs/lucasCore-projection.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
bid0 <- as.integer(opt("build", NA))
if (is.na(bid0)) { unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE); file.copy("F:/lucasCore/Starter/LUCAS Core (CONUS).ssim", f) }
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE))
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
mins <- function(t0) as.numeric(Sys.time() - t0, units = "mins")
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))

bid <- bid0
if (is.na(bid)) {
  S <- scenario(L, sc[Name == "Build", ScenarioId])
  g <- as.data.frame(datasheet(S, "lucasCore_GrowthOptions")); g$CurveSource <- "Copy from another library"; g$CurveLibrary <- "F:/lucasCore/dev/libs/lucasCore-forest-map.ssim"; g$CurveScenarioId <- 4L
  saveDatasheet(S, g, "lucasCore_GrowthOptions")
  description(S) <- paste(description(S), sprintf("[tests/phaseM-projection.R: %s with a projection to %d (LOCA2 SSP2-4.5 CanESM5, 2 iterations, default Projection Transitions); curves copied from lucasCore-forest-map.ssim result 4.]", UNITS, PEND))
  saveDatasheet(S, data.frame(UnitId = trimws(strsplit(UNITS, ",")[[1]])), "lucasCore_StudyArea")
  bo <- as.data.frame(datasheet(S, "lucasCore_BuildOptions")); bo$ProjectionEndYear <- PEND; saveDatasheet(S, bo, "lucasCore_BuildOptions")
  cs <- as.data.table(datasheet(P, "lucasCore_ClimateScenario", includeKey = TRUE)); cm <- as.data.table(datasheet(P, "lucasCore_ClimateModel", includeKey = TRUE))
  saveDatasheet(S, data.frame(ClimateScenarioId = cs[Name == "SSP2-4.5", ClimateScenarioId], ClimateModelId = cm[Name == "CanESM5", ClimateModelId]), "lucasCore_ClimateOptions")
  saveDatasheet(S, data.frame(Iterations = 2L), "lucasCore_ProjectionOptions")
  t0 <- Sys.time(); RB <- tryCatch(run(S), error = function(e) NULL); cat(sprintf("build took %.1f min\n", mins(t0)))
  if (is.null(RB)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes"]; cat(tail(logl(scenario(L, max(r$ScenarioId))), 40), sep = "\n"); stop("build failed") }
  lg <- logl(RB); cat(unique(lg[grepl("^9 |Projection|Rules from|Sampling sets|target by|rate by|Spatial tiles|Projection inputs|Climate|LOCA2|rror", lg)]), sep = "\n")
  v <- ds(RB, "lucasCore_OutputValidation"); print(v[, .(checks = .N, failed = sum(Status != "Pass")), by = Stage])
  if (!nrow(v) || any(v$Status != "Pass")) { print(v[Status != "Pass"]); stop("build failed its checks") }
  bid <- scenarioId(RB)
}
# --stage9-again: rerun only stage 9 on that build (a scenario that depends on the build result, pipeline = stage 9)
if ("--stage9-again" %in% a) {
  nm <- "Build: stage 9 again"; for (i in sc[Name == nm, ScenarioId]) delete(L, scenario = i, force = TRUE)
  S9 <- rsyncrosim::scenario(P, nm); dependency(S9) <- bid
  description(S9) <- sprintf("tests/phaseM-projection.R: stage 9 alone on build result %d (after a stage 9 change).", bid)
  saveDatasheet(S9, data.frame(StageNameId = "9 - Projection Transitions", RunOrder = 1L), "core_Pipeline")
  R9 <- run(S9); lg <- logl(R9); cat(unique(lg[grepl("target by|rate by|Projection inputs|rror", lg)]), sep = "
"); bid <- scenarioId(R9) }
RB <- scenario(L, bid)

out <- system2(RS, c("F:/lucasCore/tools/new-historical.R", shQuote(f), sprintf("--build=%d", bid), "--bookend-maps", "--replace"), stdout = TRUE, stderr = TRUE)
out <- out[!grepl("Warning|undetermined|^In ssimLibrary", out)]; cat(out, sep = "\n")
hid <- as.integer(tail(out, 1)); if (is.na(hid)) stop("tools/new-historical.R did not create the scenario")
t0 <- Sys.time(); RH <- tryCatch(run(scenario(L, hid)), error = function(e) { cat("RUN FAILED:", conditionMessage(e), "\n"); NULL })
if (is.null(RH)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & ParentId == hid]; if (nrow(r)) cat(tail(logl(scenario(L, max(r$ScenarioId))), 60), sep = "\n"); stop("run failed") }
cat(sprintf("run took %.1f min (result %d)\n", mins(t0), scenarioId(RH)))

# projected transition area per group and year vs the area of the historical year drawn (stage 9's rates)
yh <- max(ds(RB, "lucasCore_OutputNlcdAnnual")$Year)
tr <- ds(RH, "stsim_OutputStratumTransition")[, .(Run = sum(Amount) / 100), by = .(Iteration, Timestep, TransitionGroupId)]   # ha -> km2
sch <- ds(RB, "lucasCore_OutputProjectionSchedule"); rate <- ds(RB, "lucasCore_OutputProjectionRate")
hist <- ds(RB, "lucasCore_OutputTransitionSummary")[, .(Hist = sum(Area)), by = .(HistoricalYear = Timestep, TransitionGroupId = TransitionGroup)]
rules <- unique(rate[, .(TransitionGroupId = TransitionGroup, Method)])
set_of <- fread("F:/lucasCore/defaults/projection/transitions.csv")[, .(TransitionGroupId, SamplingSet)]
pj <- merge(tr[Timestep > yh], set_of, by = "TransitionGroupId")
pj <- merge(pj, sch, by = c("Iteration", "Timestep", "SamplingSet"))
pj <- merge(pj, hist, by = c("HistoricalYear", "TransitionGroupId"), all.x = TRUE)[is.na(Hist), Hist := 0]
cat(sprintf("\nprojected vs drawn historical area, %d-%d (km2, summed over years, mean of iterations):\n", yh + 1, max(tr$Timestep)))
print(merge(pj[, .(Projected = sum(Run) / uniqueN(Iteration), DrawnHistorical = sum(Hist) / uniqueN(Iteration)), by = TransitionGroupId], rules, by = "TransitionGroupId")[order(-DrawnHistorical)])
# the check that matters: each group's mean annual area in the projection vs in the historical years of the same run
yrs_all <- CJ(Iteration = unique(tr$Iteration), Timestep = 1986:max(tr$Timestep), TransitionGroupId = unique(tr$TransitionGroupId))
ta <- tr[yrs_all, on = .(Iteration, Timestep, TransitionGroupId)][is.na(Run), Run := 0]
cmp <- ta[, .(Historical = mean(Run[Timestep <= yh]), Projected = mean(Run[Timestep > yh])), by = TransitionGroupId][Historical + Projected > 0][, Ratio := round(Projected / Historical, 2)]
cat("
mean annual area in the same run, historical years vs projection (km2/yr):
"); print(cmp[order(-Historical)])
cat("\nfire by iteration (km2/yr, projection):\n"); print(pj[grepl("^Fire", TransitionGroupId), .(Projected = sum(Run) / uniqueN(Timestep), Drawn = sum(Hist) / uniqueN(Timestep)), by = Iteration])
stk <- ds(RH, "stsim_OutputStock")[StockGroupId == "Total Ecosystem", .(Tg = sum(Amount) / 1e6), by = .(Iteration, Timestep)]
cat("\nTotal Ecosystem carbon (Tg):\n"); print(dcast(stk[Timestep %in% c(1985, yh, 2035, max(Timestep))], Timestep ~ Iteration, value.var = "Tg"))
saveRDS(list(pj = pj, stk = stk, build = bid, run = scenarioId(RH)), "F:/lucasCore/dev/libs/test-projection.rds")
cat("PROJECTION RUN DONE build", bid, "run", scenarioId(RH), "\n")
