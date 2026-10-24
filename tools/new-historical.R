# =============================================================================
# new-historical.R - add an ST-Sim run scenario on top of a Build result: historical, or historical + projection when the build ran stage 9
# =============================================================================
# The Build result holds everything the run needs: initial conditions and strata maps (stages 1, 5, 6), transition pathways and annual
# spatial multipliers (6), flow pathways and multipliers (3), climate flow multipliers (7) and initial stock maps (8). The new scenario
# depends on that result and on the Stock-Flow Definitions scenario (flow order, group memberships, stock-flow output options), and adds
# only Run Control (StartYear-EndYear of the build's Build Options; transitions run from StartYear + 1) and the ST-Sim output options.
# In Studio the same scenario is: New Scenario, Dependencies = the Build result (top) + Stock-Flow Definitions, Run Control as
# below, Pipeline = ST-Sim. The order matters (see below).
# Usage: Rscript tools/new-historical.R <library.ssim> [--build=<result scenario id>] [--iterations=1] [--raster-every=1]
#                                       [--name="Historical 1985-2023"] [--replace]
#   --build         the Build result to run from (default: the newest result scenario whose name starts with "Build")
#   --iterations    Monte Carlo iterations (transitions are probabilistic where a multiplier is a fraction of the cell)
#   --raster-every  state class, age and transition maps every n years (0 = none); stock maps follow Stock-Flow Definitions
#   --bookend-maps  all maps (state class, age, transitions, stock groups) in the first and last year only, no flow maps: for fine
#                   resolutions, where yearly maps of every group run to many GB
#   --replace       delete an existing scenario of the same name first
#   --historical-only  stop at the historical end even when the build has a projection (the run that seeds stand-alone projections;
#                   with --bookend-maps it maps the historical end year, which tools/new-projection.R starts from)
# Prints the new scenario id on the last line.
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tools/new-historical.R <library.ssim> [--build=<id>] [--iterations=1]")
L <- ssimLibrary(normalizePath(pos[1], winslash = "/")); P <- rsyncrosim::project(L, "Definitions")
sc <- as.data.table(scenario(L, summary = TRUE))
bid <- as.integer(opt("build", NA))
if (is.na(bid)) { b <- sc[IsResult == "Yes" & grepl("^Build", Name)]; if (!nrow(b)) stop("no Build result in the library: run a Build scenario first"); bid <- max(b$ScenarioId) }
if (!bid %in% sc[IsResult == "Yes", ScenarioId]) stop(sprintf("scenario %d is not a result scenario", bid))
B <- scenario(L, bid); n <- function(s) nrow(suppressWarnings(datasheet(B, s, optional = TRUE)))
# the stock-flow definitions: in the Build result when its pipeline ran stage 0 (a library made in Studio), else the Stock-Flow
# Definitions scenario of a starter copy or new-library.R library, as a second dependency
sfd <- sc[Name == "Stock-Flow Definitions" & IsResult == "No", ScenarioId][1]
if (n("stsim_FlowOrder") > 0) sfd <- integer(0) else if (is.na(sfd)) stop(sprintf("Build result %d has no stock-flow definitions and the library has no Stock-Flow Definitions scenario: put stage 0 first in the Build's pipeline", bid))
dep_txt <- if (length(sfd)) sprintf("Stock-Flow Definitions (%d) and ", sfd) else ""

# the build must have run the stages the run needs; climate multipliers are optional (all-None Climate Options writes none)
need <- c(stsim_InitialConditionsSpatial = "1 and 5", stsim_Transition = "6", stsim_TransitionSpatialMultiplier = "6",
          stsim_FlowPathway = "3", stsim_InitialStockSpatial = "8")
miss <- names(need)[vapply(names(need), n, 1L) == 0]
if (length(miss)) stop(sprintf("Build result %d lacks %s: run stages %s in it", bid, paste(miss, collapse = ", "), paste(unique(need[miss]), collapse = ", ")))
if (!n("stsim_FlowSpatialMultiplier")) cat("note: the build has no climate flow multipliers (stage 7 not run, or Climate Options all None): the run uses normal climate\n")
# the years the build used (a blank Build Options sheet means the package defaults): stage 5's annual NLCD covers StartYear-EndYear
ny <- as.data.table(datasheet(B, "lucasCore_OutputNlcdAnnual"))$Year
if (!length(ny)) stop(sprintf("Build result %d has no annual NLCD table: run stage 5 in it", bid)); y0 <- min(ny); y1 <- max(ny)
# mode 1: when the build ran stage 9 (a projection), the run continues through the projection end with the schedule's iterations
ps <- suppressWarnings(as.data.table(datasheet(B, "lucasCore_OutputProjectionSchedule", optional = TRUE)))
yh <- y1; pit <- NA_integer_
if ("--historical-only" %in% a) ps <- ps[0]   # mode 2: only the historical years, to seed stand-alone projections (tools/new-projection.R)
if (nrow(ps)) { y1 <- max(ps$Timestep); pit <- max(ps$Iteration) }
kind <- if (nrow(ps)) "Historical and Projection" else "Historical"

nm <- opt("name", sprintf("%s %d-%d", kind, y0, y1))
if (nrow(sc[Name == nm & IsResult == "No"])) { if (!"--replace" %in% a) stop(sprintf("scenario '%s' exists (use --replace)", nm))
  for (i in sc[Name == nm & IsResult == "No", ScenarioId]) delete(L, scenario = i, force = TRUE) }
# the build first: a dependency supplies whole data feeds, and Flow Pathways (diagram + pathways) is one feed that both scenarios hold;
# with Stock-Flow Definitions first, its diagram-only feed wins and the run has no flow pathways (no flows at all; found 2026-10-21)
S <- rsyncrosim::scenario(P, nm); dependency(S) <- c(bid, sfd)
it <- as.integer(opt("iterations", if (is.na(pit)) 1L else pit))
if (!is.na(pit) && it > pit) stop(sprintf("the build's projection schedule has %d iterations: run at most that many (Projection Options sets it)", pit))
 ev <- as.integer(opt("raster-every", 1))
bookends <- "--bookend-maps" %in% a; if (bookends) ev <- y1 - y0
saveDatasheet(S, data.frame(MinimumTimestep = y0, MaximumTimestep = y1, MinimumIteration = 1L, MaximumIteration = it, IsSpatial = TRUE), "stsim_RunControl")
# yearly state class and transition tables (by stratum); maps every --raster-every years
saveDatasheet(S, data.frame(SummaryOutputSC = TRUE, SummaryOutputSCTimesteps = 1L, SummaryOutputSCZeroValues = FALSE,
                            SummaryOutputTR = TRUE, SummaryOutputTRTimesteps = 1L, SummaryOutputTRIntervalMean = FALSE), "stsim_OutputOptions")
if (ev > 0) saveDatasheet(S, data.frame(RasterOutputSC = TRUE, RasterOutputSCTimesteps = ev, RasterOutputAge = TRUE, RasterOutputAgeTimesteps = ev,
                                        RasterOutputTR = TRUE, RasterOutputTRTimesteps = ev), "stsim_OutputOptionsSpatial")
# bookend maps: stock group maps (the groups Stock-Flow Definitions' filter maps) only in the first and last year, no flow maps; the
# yearly stock and flow tables stay. A scenario's own Stock-Flow Output sheet replaces the dependency's (it is a feed of its own).
if (bookends) saveDatasheet(S, data.frame(SummaryOutputST = TRUE, SummaryOutputSTTimesteps = 1L, SummaryOutputFL = TRUE, SummaryOutputFLTimesteps = 1L,
                                          AvgSpatialOutputST = TRUE, AvgSpatialOutputSTTimesteps = ev, AvgSpatialOutputFL = FALSE), "stsim_OutputOptionsStockFlow")
stages <- levels(datasheet(S, "core_Pipeline", lookupsAsFactors = TRUE, optional = TRUE)$StageNameId)
st <- grep("ST-Sim|stsim", stages, value = TRUE, ignore.case = TRUE)[1]; if (is.na(st)) stop("no ST-Sim stage among: ", paste(stages, collapse = "; "))
saveDatasheet(S, data.frame(StageNameId = st, RunOrder = 1L), "core_Pipeline")
description(S) <- paste0(if (kind == "Historical") sprintf("Historical ST-Sim run %d-%d (transitions from %d), %d iteration(s), spatial. ", y0, y1, y0 + 1, it) else sprintf("Historical (%d-%d) and projection (%d-%d) ST-Sim run, %d iteration(s), spatial; projection transitions from stage 9 (whole historical years drawn per Projection Transitions). ", y0 + 1, yh, yh + 1, y1, it),
  sprintf("Depends on %sthe Build result '%s' (%d), which holds the initial conditions, transition pathways and ", dep_txt, sc[ScenarioId == bid, Name], bid),
  "annual spatial multipliers, flow pathways, climate flow multipliers and initial stock maps. ",
  sprintf("Adds Run Control and ST-Sim output options (yearly state class and transition tables%s). Made by tools/new-historical.R.",
          if (ev > 0) sprintf("; state class, age and transition maps every %d year(s)", ev) else ""))
cat(sprintf("scenario '%s' created: depends on %sBuild result %d; %d-%d, %d iteration(s); stage '%s'\n", nm, dep_txt, bid, y0, y1, it, st))
cat(scenarioId(S), "\n")
