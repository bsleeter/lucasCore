# =============================================================================
# new-projection.R - add a stand-alone projection scenario that starts from a historical run (mode 2)
# =============================================================================
# The historical run is made once (tools/new-historical.R --historical-only --bookend-maps); each projection continues from its
# historical end year. The new scenario depends on the Build result (with stage 9's projection rules) and Stock-Flow Definitions,
# names the historical run in Projection Start, and runs stage 9 (which writes the starting maps and the draws) then ST-Sim from the
# historical end for --years years. Climate multipliers for the projection years come from the build's stage 7.
# Usage: Rscript tools/new-projection.R <library.ssim> --historical=<result id> [--build=<result id>] [--years=10] [--iterations=<n>]
#                                       [--name="..."] [--replace]
#   --build       the Build result (default: the one the historical run depends on)
#   --years       projection years to run (default 10; at most to the build's projection end)
#   --iterations  Monte Carlo iterations (default: Projection Options' iterations, the draws stage 9 makes)
# Prints the new scenario id on the last line.
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tools/new-projection.R <library.ssim> --historical=<result id> [--years=10]")
L <- ssimLibrary(normalizePath(pos[1], winslash = "/")); P <- rsyncrosim::project(L, "Definitions")
sc <- as.data.table(scenario(L, summary = TRUE))
hid <- as.integer(opt("historical", NA)); if (is.na(hid) || !hid %in% sc[IsResult == "Yes", ScenarioId]) stop("--historical must be a result scenario id")
H <- scenario(L, hid)
bid <- as.integer(opt("build", NA))
if (is.na(bid)) { d <- as.data.table(dependency(H)); b <- d[grepl("^Build", Name), ScenarioId]; if (!length(b)) stop("pass --build: the historical run has no Build dependency"); bid <- b[1] }
sfd <- sc[Name == "Stock-Flow Definitions" & IsResult == "No", ScenarioId]
B <- scenario(L, bid)
yh <- max(as.data.table(datasheet(B, "lucasCore_OutputNlcdAnnual"))$Year)
ps <- suppressWarnings(as.data.table(datasheet(B, "lucasCore_OutputProjectionSchedule", optional = TRUE)))
if (!nrow(ps)) stop(sprintf("Build result %d has no projection (tick Run a projection in Build Options and run stage 9)", bid))
pend <- max(ps$Timestep); pit <- max(ps$Iteration)
ye <- min(pend, yh + as.integer(opt("years", 10))); it <- as.integer(opt("iterations", pit))
if (it > pit) stop(sprintf("the build's projection schedule has %d iterations", pit))
nm <- opt("name", sprintf("Projection %d-%d from %s", yh + 1, ye, sc[ScenarioId == hid, sub(" \\(\\[.*", "", Name)]))
if (nrow(sc[Name == nm & IsResult == "No"])) { if (!"--replace" %in% a) stop(sprintf("scenario '%s' exists (use --replace)", nm))
  for (i in sc[Name == nm & IsResult == "No", ScenarioId]) delete(L, scenario = i, force = TRUE) }
S <- rsyncrosim::scenario(P, nm); dependency(S) <- c(bid, sfd)   # the build first: it supplies the whole Flow Pathways feed
saveDatasheet(S, data.frame(HistoricalScenarioId = hid), "lucasCore_ProjectionStart")
saveDatasheet(S, data.frame(MinimumTimestep = yh, MaximumTimestep = ye, MinimumIteration = 1L, MaximumIteration = it, IsSpatial = TRUE), "stsim_RunControl")
saveDatasheet(S, data.frame(SummaryOutputSC = TRUE, SummaryOutputSCTimesteps = 1L, SummaryOutputSCZeroValues = FALSE,
                            SummaryOutputTR = TRUE, SummaryOutputTRTimesteps = 1L, SummaryOutputTRIntervalMean = FALSE), "stsim_OutputOptions")
ev <- ye - yh
saveDatasheet(S, data.frame(RasterOutputSC = TRUE, RasterOutputSCTimesteps = ev, RasterOutputAge = TRUE, RasterOutputAgeTimesteps = ev), "stsim_OutputOptionsSpatial")
saveDatasheet(S, data.frame(SummaryOutputST = TRUE, SummaryOutputSTTimesteps = 1L, SummaryOutputFL = TRUE, SummaryOutputFLTimesteps = 1L,
                            AvgSpatialOutputST = TRUE, AvgSpatialOutputSTTimesteps = ev, AvgSpatialOutputFL = FALSE), "stsim_OutputOptionsStockFlow")
stages <- levels(datasheet(S, "core_Pipeline", lookupsAsFactors = TRUE, optional = TRUE)$StageNameId)
st <- grep("ST-Sim|stsim", stages, value = TRUE, ignore.case = TRUE)[1]
if (!"9 - Projection Transitions" %in% stages) stop("this library has no stage 9 (made before it existed): make the library from a current starter")
saveDatasheet(S, data.frame(StageNameId = c("9 - Projection Transitions", st), RunOrder = 1:2), "core_Pipeline")
description(S) <- sprintf(paste0("Stand-alone projection %d-%d, %d iteration(s), spatial (made by tools/new-projection.R). Starts from historical run %d's %d state class, ",
  "age and stock maps (Projection Start; stage 9 writes them), with stage 9's projection transitions and the climate multipliers of Build result %d. ",
  "Depends on the Build result (first) and Stock-Flow Definitions (%d). Maps in %d and %d."), yh + 1, ye, it, hid, yh, bid, sfd, yh, ye)
cat(sprintf("scenario '%s': from historical run %d (%d), build %d, %d-%d, %d iteration(s)\n", nm, hid, yh, bid, yh + 1, ye, it))
cat(scenarioId(S), "\n")
