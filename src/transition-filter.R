# =============================================================================
# transition-filter.R - the default ST-Sim transition group output filter (stsim_OutputFilterTransitionGroups); sourced by stage 0 and
# tools/new-library.R, no SyncroSim calls
# =============================================================================
# Every transition group of the project is listed with its yearly summary on and every other output off, except the main groups of
# defaults/stockflow/main-transition-groups.csv (the land-use and disturbance families the Build fits), which also get maps (Spatial)
# and average probability maps (Spatial Probability, the Spatial Average output). Without a filter, ST-Sim maps every group, the
# automatic [Type] group of each of the ~140 transition types included, every year it is asked for maps. A family's map still holds the
# transition type of each cell, so the severity or intensity classes stay readable.
# groups: the project's stsim_TransitionGroup names; main: the main-groups table. Returns the filter rows by name.
transition_filter <- function(groups, main) {
  f <- data.frame(TransitionGroupId = groups, Summary = "Yes", SummaryByStateClass = "No", TimeSinceTransition = "No", Spatial = "No",
                  SpatialEvents = "No", SpatialTimeSinceTransition = "No", SpatialProbability = "No", AvgSpatialTimeSinceTransition = "No",
                  stringsAsFactors = FALSE)
  m <- match(f$TransitionGroupId, main$TransitionGroupId); k <- !is.na(m)
  f$Spatial[k] <- main$Spatial[m[k]]; f$SpatialProbability[k] <- main$SpatialProbability[m[k]]
  f }
