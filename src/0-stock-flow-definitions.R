# =============================================================================
# 0-stock-flow-definitions.R - stage 0: the fixed LUCAS stock-flow definitions, written into the Build result
# =============================================================================
# Flow pathway diagram, flow order and its options, flow and stock type group memberships, stock-flow output options and output filters,
# from defaults/stockflow (the same tables tools/new-library.R puts in the Stock-Flow Definitions scenario). A library made in Studio
# (File > New > Empty Library, then add lucasCore) has no such scenario, so the Build writes them itself and every run that depends on
# the Build result gets them. Its own stage: SyncroSim imports one stage's outputs in alphabetical order, so stage 3's flow pathways
# need the diagram imported by an earlier stage (or supplied by a dependency).
# When the scenario already has a flow pathway diagram (a Stock-Flow Definitions dependency), the stage writes none of these.
# package.xml declares every one of these sheets "Both": the stage reads the dependency's rows (the guard below) and the Build result
# carries them whole. Declare them all the same way: a result holding only some of them hides the dependency's others from every run
# that depends on it (no stock group totals, no flow order options; found 2026-11-17).
# It also writes the transition group output filter (src/transition-filter.R: summaries for every group, maps only for the main groups
# of defaults/stockflow/main-transition-groups.csv) and the spatial output options (state class, age and transition maps every year)
# and the tabular output options (state class, transition and transition attribute summaries every year) whenever the scenario has none, dependency or not.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
STAGE <- "0 Stock-Flow Definitions"
SHEETS <- c("stsim_FlowPathwayDiagram", "stsim_FlowOrder", "stsim_FlowTypeGroupMembership", "stsim_StockTypeGroupMembership",
            "stsim_OutputOptionsStockFlow", "stsim_OutputFilterFlows", "stsim_OutputFilterStocks")
progressBar(type = "begin", totalSteps = length(SHEETS) + 1)

wopt <- wetland_settings()   # Carbon Assumptions: Wetland Methane (src/wetland-params.R)
have <- as.data.table(datasheet(scn, "stsim_FlowPathwayDiagram", optional = TRUE, lookupsAsFactors = FALSE))
if (nrow(have)) {
  if ("MethaneCO2e" %in% wopt$changed) updateRunLog(sprintf("%s: Wetland Methane sets the CO2 equivalent of methane to %s, but the stock-flow definitions come from a dependency, whose value stands", STAGE, format(wopt$MethaneCO2e)))
  updateRunLog(sprintf("%s: the scenario already has the stock-flow definitions (%d diagram boxes, from a dependency); nothing written", STAGE, nrow(have)))
  check(STAGE, "flow pathway diagram present", TRUE, sprintf("%d boxes from a dependency", nrow(have)))
  # the dependency's definitions must cover every flow type the package's pathways use: a flow with a pathway and no group
  # membership moves carbon that net biome productivity never counts (definition_gaps, src/wetland-params.R)
  sheets <- c(order = "stsim_FlowOrder", members = "stsim_FlowTypeGroupMembership", filters = "stsim_OutputFilterFlows")
  gaps <- definition_gaps(lapply(sheets, function(sh) read_default("stockflow", paste0(sh, ".csv"))),
                          lapply(sheets, function(sh) as.data.table(datasheet(scn, sh, optional = TRUE, lookupsAsFactors = FALSE))))
  check(STAGE, "the dependency's stock-flow definitions cover the package's flow types", !length(gaps),
        if (length(gaps)) paste0(paste(gaps, collapse = "; "), ". The Stock-Flow Definitions scenario was made with an earlier lucasCore: run tools/sync-library.R on the library, ",
                                 "or remove that dependency so this stage writes the current definitions") else "flow order, group memberships and output filters complete")
} else {
  for (sh in SHEETS) {
    x <- read_default("stockflow", paste0(sh, ".csv")); x <- x[, setdiff(names(x), c("Iteration", "Timestep")), with = FALSE]
    # Wetland Methane: the CO2 equivalent of methane carbon (every CH4 flow, fire included), when the scenario sets its own
    if (sh == "stsim_FlowTypeGroupMembership" && "MethaneCO2e" %in% wopt$changed) { x <- ch4_co2e_memberships(x, wopt$MethaneCO2e)
      updateRunLog(sprintf("%s: CO2 equivalent of methane = %s Mg CO2e per Mg C (Wetland Methane; the package value is %s)", STAGE, format(wopt$MethaneCO2e), format(WETLAND_OPTION_DEFAULTS$MethaneCO2e))) }
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
# the spatial output options, written whenever the scenario has none: state class, age and transition maps every year
# (defaults/stockflow/stsim_OutputOptionsSpatial.csv). A Projection Setup starts from a historical run's final state class AND age
# maps (stage 9's Projection Start), so a run without age maps cannot be projected from. A run scenario that sets its own Spatial
# output replaces these whole, so it must keep Age on itself.
if (!nrow(as.data.table(datasheet(scn, "stsim_OutputOptionsSpatial", optional = TRUE, lookupsAsFactors = FALSE)))) {
  o <- read_default("stockflow", "stsim_OutputOptionsSpatial.csv")
  saveDatasheet(scn, as.data.frame(o), "stsim_OutputOptionsSpatial")
  check(STAGE, "spatial output options written (age maps on)", identical(o$RasterOutputAge[1], "Yes"),
        sprintf("state class every %s yr, age every %s yr, transitions every %s yr", o$RasterOutputSCTimesteps, o$RasterOutputAgeTimesteps, o$RasterOutputTRTimesteps))
}
# the tabular output options, written whenever the scenario has none: state class, transition and transition attribute (management cost) summaries every year
# (defaults/stockflow/stsim_OutputOptions.csv). User 2026-11-15: a Historical scenario made in Studio on a Build result had stocks,
# flows, maps and the filters on, and no tabular state classes or transitions. A run scenario that sets its own replaces these whole.
if (!nrow(as.data.table(datasheet(scn, "stsim_OutputOptions", optional = TRUE, lookupsAsFactors = FALSE)))) {
  o <- read_default("stockflow", "stsim_OutputOptions.csv")
  saveDatasheet(scn, as.data.frame(o), "stsim_OutputOptions")
  check(STAGE, "tabular output options written (state classes, transitions and transition attributes)", all(c(o$SummaryOutputSC[1], o$SummaryOutputTR[1], o$SummaryOutputTA[1]) == "Yes"),
        sprintf("state classes every %s yr, transitions every %s yr, transition attributes every %s yr", o$SummaryOutputSCTimesteps, o$SummaryOutputTRTimesteps, o$SummaryOutputTATimesteps))
}
progressBar()
finish_checks()
progressBar(type = "end")
