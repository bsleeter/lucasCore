# =============================================================================
# new-projection.R - add a stand-alone projection scenario: ST-Sim alone, its inputs from a Projection Setup result (mode 2)
# =============================================================================
# Real runs stand alone (user decision 2026-10-23): a projection is an ST-Sim-only scenario whose dependencies supply every input -
# the Projection Setup result (stage 9's draws, targets and fire maps, stage 10's surfaces, and the hand-over: the historical run's
# final state class, age and stock maps as initial conditions; tools/new-projection-setup.R --historical=<id>), then the Build result
# it was made on (flow pathways, climate multipliers, ...), then Stock-Flow Definitions. ST-Sim runs from the historical end for
# --years years. ST-Sim-only scenarios can also run side by side (library multiprocessing, multi-scenario).
# A setup made without the hand-over still works with --stage9: the projection then runs stage 9 itself (names the historical run in
# Projection Start) before ST-Sim, as before - but such scenarios cannot run under multi-scenario multiprocessing.
# Usage: Rscript tools/new-projection.R <library.ssim> --build=<Projection Setup result> [--years=10] [--iterations=<n>] [--name="..."] [--replace]
#        Rscript tools/new-projection.R <library.ssim> --build=<result> --historical=<result id> --stage9 [...]   (legacy)
#   --years       projection years to run (default 10; at most to the projection end)
#   --iterations  Monte Carlo iterations (default: the setup's, the draws stage 9 made)
# Prints the new scenario id on the last line.
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tools/new-projection.R <library.ssim> --build=<Projection Setup result> [--years=10]")
L <- ssimLibrary(normalizePath(pos[1], winslash = "/")); P <- rsyncrosim::project(L, "Definitions")
sc <- as.data.table(scenario(L, summary = TRUE)); legacy <- "--stage9" %in% a
bid <- as.integer(opt("build", NA)); if (is.na(bid) || !bid %in% sc[IsResult == "Yes", ScenarioId]) stop("--build must be a result scenario id (a Projection Setup result)")
B <- scenario(L, bid)
sfd <- sc[Name == "Stock-Flow Definitions" & IsResult == "No", ScenarioId]
# a Projection Setup result keeps only the sheets of its own stages: the projection also needs the Build result its setup was made on
setup <- nrow(suppressWarnings(as.data.table(datasheet(B, "lucasCore_OutputSuitability", optional = TRUE)))) > 0 || grepl("^Projection Setup", sc[ScenarioId == bid, Name])
build_of <- NA_integer_
if (setup) { par <- sc[ScenarioId == bid, ParentId]; d <- as.data.table(dependency(scenario(L, if (is.na(par)) bid else par)))
  build_of <- d[grepl("^Build", Name), ScenarioId][1]; if (is.na(build_of)) stop("cannot find the Build result the Projection Setup was made on") }
# the hand-over the setup made (its Projection Start)
pst <- suppressWarnings(as.data.table(datasheet(B, "lucasCore_ProjectionStart", optional = TRUE)))
hid_setup <- if (nrow(pst) && "HistoricalScenarioId" %in% names(pst)) pst$HistoricalScenarioId[1] else NA
hid <- as.integer(opt("historical", NA))
if (!legacy) {
  if (is.na(hid_setup)) stop(sprintf("result %d has no hand-over: make the Projection Setup with --historical=<historical run> (tools/new-projection-setup.R), or pass --historical=<id> --stage9", bid))
  if (!is.na(hid) && hid != hid_setup) stop(sprintf("the setup starts from historical run %d, not %d", hid_setup, hid))
  hid <- hid_setup
} else if (is.na(hid) || !hid %in% sc[IsResult == "Yes", ScenarioId]) stop("--stage9 needs --historical=<result id>")
yh <- max(as.data.table(datasheet(B, "lucasCore_OutputNlcdAnnual"))$Year)
ps <- suppressWarnings(as.data.table(datasheet(B, "lucasCore_OutputProjectionSchedule", optional = TRUE)))
if (!nrow(ps)) stop(sprintf("result %d has no projection schedule (tick Run a projection in Build Options and run stage 9)", bid))
pend <- max(ps$Timestep); pit <- max(ps$Iteration)
ye <- min(pend, yh + as.integer(opt("years", 10))); it <- as.integer(opt("iterations", pit))
if (it > pit) stop(sprintf("the projection schedule has %d iterations", pit))
nm <- opt("name", sprintf("Projection %d-%d from %s", yh + 1, ye, sc[ScenarioId == hid, sub(" \\(\\[.*", "", Name)]))
if (nrow(sc[Name == nm & IsResult == "No"])) { if (!"--replace" %in% a) stop(sprintf("scenario '%s' exists (use --replace)", nm))
  for (i in sc[Name == nm & IsResult == "No", ScenarioId]) delete(L, scenario = i, force = TRUE) }
S <- rsyncrosim::scenario(P, nm)
# the setup (its multipliers, adjacency, state attributes and initial conditions win), then the build (it supplies the whole Flow
# Pathways feed), then the definitions
dependency(S) <- if (setup) c(bid, build_of, sfd) else c(bid, sfd)
if (legacy) { saveDatasheet(S, data.frame(HistoricalScenarioId = hid), "lucasCore_ProjectionStart")
  # Projection Start shares a feed with Projection Options, and a dependency supplies whole feeds: copy the options
  po <- suppressWarnings(as.data.frame(datasheet(B, "lucasCore_ProjectionOptions", lookupsAsFactors = FALSE)))
  po <- po[, setdiff(names(po), c("ProjectionOptionsId", "ScenarioId")), drop = FALSE]
  if (nrow(po)) saveDatasheet(S, po, "lucasCore_ProjectionOptions") }
saveDatasheet(S, data.frame(MinimumTimestep = yh, MaximumTimestep = ye, MinimumIteration = 1L, MaximumIteration = it, IsSpatial = TRUE), "stsim_RunControl")
saveDatasheet(S, data.frame(SummaryOutputSC = TRUE, SummaryOutputSCTimesteps = 1L, SummaryOutputSCZeroValues = FALSE,
                            SummaryOutputTR = TRUE, SummaryOutputTRTimesteps = 1L, SummaryOutputTRIntervalMean = FALSE), "stsim_OutputOptions")
ev <- ye - yh
saveDatasheet(S, data.frame(RasterOutputSC = TRUE, RasterOutputSCTimesteps = ev, RasterOutputAge = TRUE, RasterOutputAgeTimesteps = ev), "stsim_OutputOptionsSpatial")
saveDatasheet(S, data.frame(SummaryOutputST = TRUE, SummaryOutputSTTimesteps = 1L, SummaryOutputFL = TRUE, SummaryOutputFLTimesteps = 1L,
                            AvgSpatialOutputST = TRUE, AvgSpatialOutputSTTimesteps = ev, AvgSpatialOutputFL = FALSE), "stsim_OutputOptionsStockFlow")
stages <- levels(datasheet(S, "core_Pipeline", lookupsAsFactors = TRUE, optional = TRUE)$StageNameId)
st <- grep("ST-Sim|stsim", stages, value = TRUE, ignore.case = TRUE)[1]
if (legacy && !"9 - Projection Transitions" %in% stages) stop("this library has no stage 9 (made before it existed): make the library from a current starter")
saveDatasheet(S, data.frame(StageNameId = if (legacy) c("9 - Projection Transitions", st) else st, RunOrder = if (legacy) 1:2 else 1L), "core_Pipeline")
description(S) <- sprintf(paste0("Stand-alone projection %d-%d, %d iteration(s), spatial (made by tools/new-projection.R). Starts from historical run %d's %d state class, ",
  "age and stock maps. %s Depends on result %d%s and Stock-Flow Definitions (%d). Maps in %d and %d."), yh + 1, ye, it, hid, yh,
  if (legacy) "Pipeline: stage 9 (writes the starting maps and the draws) then ST-Sim." else "Pipeline: ST-Sim alone; the Projection Setup made the hand-over, the draws and the surfaces.",
  bid, if (setup) sprintf(", its Build result %d", build_of) else "", sfd, yh, ye)
cat(sprintf("scenario '%s': from historical run %d (%d), %s %d, %d-%d, %d iteration(s), %s\n", nm, hid, yh, if (setup) "setup" else "build", bid, yh + 1, ye, it,
            if (legacy) "stage 9 + ST-Sim" else "ST-Sim only"))
cat(scenarioId(S), "\n")
