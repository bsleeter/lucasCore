# =============================================================================
# new-historical.R - add a historical ST-Sim run scenario on top of a Build result (Option B: the run is its own scenario)
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
#   --replace       delete an existing scenario of the same name first
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
sfd <- sc[Name == "Stock-Flow Definitions" & IsResult == "No", ScenarioId]; if (length(sfd) != 1) stop("no Stock-Flow Definitions scenario (tools/new-library.R makes it)")
B <- scenario(L, bid); n <- function(s) nrow(suppressWarnings(datasheet(B, s, optional = TRUE)))

# the build must have run the stages the run needs; climate multipliers are optional (all-None Climate Options writes none)
need <- c(stsim_InitialConditionsSpatial = "1 and 5", stsim_Transition = "6", stsim_TransitionSpatialMultiplier = "6",
          stsim_FlowPathway = "3", stsim_InitialStockSpatial = "8")
miss <- names(need)[vapply(names(need), n, 1L) == 0]
if (length(miss)) stop(sprintf("Build result %d lacks %s: run stages %s in it", bid, paste(miss, collapse = ", "), paste(unique(need[miss]), collapse = ", ")))
if (!n("stsim_FlowSpatialMultiplier")) cat("note: the build has no climate flow multipliers (stage 7 not run, or Climate Options all None): the run uses normal climate\n")
# the years the build used (a blank Build Options sheet means the package defaults): stage 5's annual NLCD covers StartYear-EndYear
ny <- as.data.table(datasheet(B, "lucasCore_OutputNlcdAnnual"))$Year
if (!length(ny)) stop(sprintf("Build result %d has no annual NLCD table: run stage 5 in it", bid)); y0 <- min(ny); y1 <- max(ny)

nm <- opt("name", sprintf("Historical %d-%d", y0, y1))
if (nrow(sc[Name == nm & IsResult == "No"])) { if (!"--replace" %in% a) stop(sprintf("scenario '%s' exists (use --replace)", nm))
  for (i in sc[Name == nm & IsResult == "No", ScenarioId]) delete(L, scenario = i, force = TRUE) }
# the build first: a dependency supplies whole data feeds, and Flow Pathways (diagram + pathways) is one feed that both scenarios hold;
# with Stock-Flow Definitions first, its diagram-only feed wins and the run has no flow pathways (no flows at all; found 2026-10-21)
S <- rsyncrosim::scenario(P, nm); dependency(S) <- c(bid, sfd)
it <- as.integer(opt("iterations", 1)); ev <- as.integer(opt("raster-every", 1))
saveDatasheet(S, data.frame(MinimumTimestep = y0, MaximumTimestep = y1, MinimumIteration = 1L, MaximumIteration = it, IsSpatial = TRUE), "stsim_RunControl")
# yearly state class and transition tables (by stratum); maps every --raster-every years
saveDatasheet(S, data.frame(SummaryOutputSC = TRUE, SummaryOutputSCTimesteps = 1L, SummaryOutputSCZeroValues = FALSE,
                            SummaryOutputTR = TRUE, SummaryOutputTRTimesteps = 1L, SummaryOutputTRIntervalMean = FALSE), "stsim_OutputOptions")
if (ev > 0) saveDatasheet(S, data.frame(RasterOutputSC = TRUE, RasterOutputSCTimesteps = ev, RasterOutputAge = TRUE, RasterOutputAgeTimesteps = ev,
                                        RasterOutputTR = TRUE, RasterOutputTRTimesteps = ev), "stsim_OutputOptionsSpatial")
stages <- levels(datasheet(S, "core_Pipeline", lookupsAsFactors = TRUE, optional = TRUE)$StageNameId)
st <- grep("ST-Sim|stsim", stages, value = TRUE, ignore.case = TRUE)[1]; if (is.na(st)) stop("no ST-Sim stage among: ", paste(stages, collapse = "; "))
saveDatasheet(S, data.frame(StageNameId = st, RunOrder = 1L), "core_Pipeline")
description(S) <- paste0(sprintf("Historical ST-Sim run %d-%d (transitions from %d), %d iteration(s), spatial. ", y0, y1, y0 + 1, it),
  sprintf("Depends on Stock-Flow Definitions (%d) and the Build result '%s' (%d), which holds the initial conditions, transition pathways and ", sfd, sc[ScenarioId == bid, Name], bid),
  "annual spatial multipliers, flow pathways, climate flow multipliers and initial stock maps. ",
  sprintf("Adds Run Control and ST-Sim output options (yearly state class and transition tables%s). Made by tools/new-historical.R.",
          if (ev > 0) sprintf("; state class, age and transition maps every %d year(s)", ev) else ""))
cat(sprintf("scenario '%s' created: depends on Stock-Flow Definitions (%d) and Build result %d; %d-%d, %d iteration(s); stage '%s'\n", nm, sfd, bid, y0, y1, it, st))
cat(scenarioId(S), "\n")
