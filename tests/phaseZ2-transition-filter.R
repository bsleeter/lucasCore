# =============================================================================
# phaseZ2-transition-filter.R - stage 0 writes the transition group output filter: every group summarised, maps for the main groups only
# =============================================================================
# On the library tests/phaseX-studio-library.R made: a scenario with stage 0 alone and no dependencies (so it writes the stock-flow
# definitions and the filter). Passes when the filter lists every transition group of the project, all with Summary, and Spatial and
# Spatial Probability are on for exactly the groups of defaults/stockflow/main-transition-groups.csv.
# Usage: Rscript tests/phaseZ2-transition-filter.R
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
L <- ssimLibrary("F:/lucasCore/dev/libs/lucasCore-studio-library.ssim"); P <- rsyncrosim::project(L, "Definitions")
sc <- as.data.table(rsyncrosim::scenario(L, summary = TRUE))
for (i in sc[IsResult == "No" & Name == "Transition filter (phaseZ2)", ScenarioId]) delete(L, scenario = i, force = TRUE)
S <- rsyncrosim::scenario(P, "Transition filter (phaseZ2)")
saveDatasheet(S, data.frame(StageNameId = "0 - Stock-Flow Definitions", RunOrder = 1L), "core_Pipeline")
R <- run(S)
f <- as.data.table(datasheet(R, "stsim_OutputFilterTransitionGroups", lookupsAsFactors = FALSE))
g <- as.data.table(datasheet(P, "stsim_TransitionGroup", lookupsAsFactors = FALSE))$Name
main <- fread("F:/lucasCore/defaults/stockflow/main-transition-groups.csv")$TransitionGroupId
yes <- function(v) !is.na(v) & v %in% c(TRUE, -1, 1, "Yes")
mapped <- f[yes(Spatial), TransitionGroupId]
cat(sprintf("%d of %d groups listed, %d summarised; maps for: %s\n", nrow(f), length(g), sum(yes(f$Summary)), paste(mapped, collapse = ", ")))
ok <- setequal(f$TransitionGroupId, g) && all(yes(f$Summary)) && setequal(mapped, intersect(main, g)) &&
  setequal(f[yes(SpatialProbability), TransitionGroupId], intersect(main, g)) && !any(yes(f$SpatialEvents) | yes(f$TimeSinceTransition))
cat(if (ok) "TRANSITION FILTER OK\n" else "TRANSITION FILTER FAILED\n")
delete(L, scenario = scenarioId(S), force = TRUE)
