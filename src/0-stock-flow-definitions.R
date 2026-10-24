# =============================================================================
# 0-stock-flow-definitions.R - stage 0: the fixed LUCAS stock-flow definitions, written into the Build result
# =============================================================================
# Flow pathway diagram, flow order and its options, flow and stock type group memberships, stock-flow output options and output filters,
# from defaults/stockflow (the same tables tools/new-library.R puts in the Stock-Flow Definitions scenario). A library made in Studio
# (File > New > Empty Library, then add lucasCore) has no such scenario, so the Build writes them itself and every run that depends on
# the Build result gets them. Its own stage: SyncroSim imports one stage's outputs in alphabetical order, so stage 3's flow pathways
# need the diagram imported by an earlier stage (or supplied by a dependency).
# When the scenario already has a flow pathway diagram (a Stock-Flow Definitions dependency), the stage writes none of these.
# It also writes the transition group output filter (src/transition-filter.R: summaries for every group, maps only for the main groups
# of defaults/stockflow/main-transition-groups.csv) whenever the scenario has no filter, dependency or not.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
STAGE <- "0 Stock-Flow Definitions"
SHEETS <- c("stsim_FlowPathwayDiagram", "stsim_FlowOrder", "stsim_FlowTypeGroupMembership", "stsim_StockTypeGroupMembership",
            "stsim_OutputOptionsStockFlow", "stsim_OutputFilterFlows", "stsim_OutputFilterStocks")
progressBar(type = "begin", totalSteps = length(SHEETS) + 1)

have <- as.data.table(datasheet(scn, "stsim_FlowPathwayDiagram", optional = TRUE, lookupsAsFactors = FALSE))
if (nrow(have)) {
  updateRunLog(sprintf("%s: the scenario already has the stock-flow definitions (%d diagram boxes, from a dependency); nothing written", STAGE, nrow(have)))
  check(STAGE, "flow pathway diagram present", TRUE, sprintf("%d boxes from a dependency", nrow(have)))
} else {
  for (sh in SHEETS) {
    x <- read_default("stockflow", paste0(sh, ".csv")); x <- x[, setdiff(names(x), c("Iteration", "Timestep")), with = FALSE]
    x <- x[, which(vapply(x, function(v) any(!is.na(v) & nzchar(v)), TRUE)), with = FALSE]
    saveDatasheet(scn, as.data.frame(x), sh)
    check(STAGE, paste(sh, "has rows"), nrow(x) > 0, sprintf("%d rows", nrow(x)))
    progressBar()
  }
  saveDatasheet(scn, data.frame(ApplyBeforeTransitions = FALSE, ApplyEquallyRankedSimultaneously = TRUE), "stsim_FlowOrderOptions")
  updateRunLog(sprintf("%s: wrote %s", STAGE, paste(SHEETS, collapse = ", ")))
}
# the transition group output filter, written whenever the scenario has none (a Stock-Flow Definitions dependency made before
# 2026-10-24 has none): summaries for every group, maps for the main groups only (src/transition-filter.R)
if (!nrow(as.data.table(datasheet(scn, "stsim_OutputFilterTransitionGroups", optional = TRUE, lookupsAsFactors = FALSE)))) {
  source(pkg_file("src", "transition-filter.R"))
  f <- transition_filter(stsim_list("TransitionGroup")$Name, read_default("stockflow", "main-transition-groups.csv"))
  saveDatasheet(scn, f, "stsim_OutputFilterTransitionGroups")
  check(STAGE, "transition group output filter written", nrow(f) > 0 && any(f$Spatial == "Yes"),
        sprintf("%d groups; maps for %s", nrow(f), paste(f$TransitionGroupId[f$Spatial == "Yes"], collapse = ", ")))
}
progressBar()
finish_checks()
progressBar(type = "end")
