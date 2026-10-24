# =============================================================================
# 0-stock-flow-definitions.R - stage 0: the fixed LUCAS stock-flow definitions, written into the Build result
# =============================================================================
# Flow pathway diagram, flow order and its options, flow and stock type group memberships, stock-flow output options and output filters,
# from defaults/stockflow (the same tables tools/new-library.R puts in the Stock-Flow Definitions scenario). A library made in Studio
# (File > New > Empty Library, then add lucasCore) has no such scenario, so the Build writes them itself and every run that depends on
# the Build result gets them. Its own stage: SyncroSim imports one stage's outputs in alphabetical order, so stage 3's flow pathways
# need the diagram imported by an earlier stage (or supplied by a dependency).
# When the scenario already has a flow pathway diagram (a Stock-Flow Definitions dependency), the stage writes nothing.
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
progressBar()
finish_checks()
progressBar(type = "end")
