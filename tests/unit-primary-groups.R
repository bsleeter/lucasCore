# Unit test: every transition target lucasCore writes is on a primary transition group, by ST-Sim's rule
# (STSimTransformer.Collections.cs, FillGroupsForTransitionTypes): a type's primary groups are the user groups it belongs to that are
# transition simulation groups; with none, its automatic "[Type]" group. ST-Sim's spatial allocation uses only the primary group's
# target, so a target on another group is ignored (and warned: "At least one Transition Target has been defined with a non-primary
# Transition Group"). Found 2026-11-13: Ag Change was a simulation group while its targets were on its two types' [Type] groups.
# Usage: Rscript tests/unit-primary-groups.R   (from the package folder)
suppressPackageStartupMessages(library(data.table))
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
rd <- function(...) fread(file.path("defaults", ...), colClasses = "character", na.strings = "", sep = ",")
sim <- rd("stsim", "stsim_TransitionSimulationGroup.csv")$TransitionGroupId
sim_types <- rd("stsim", "stsim_TransitionSimulationGroup-types.csv")$TransitionGroupId
ttg <- rd("stsim", "stsim_TransitionTypeGroup.csv")
types <- rd("stsim", "stsim_TransitionType.csv")$Name
check("[Type] simulation groups name real types", all(sub(" \\[Type\\]$", "", sim_types) %in% types) && all(endsWith(sim_types, " [Type]")))
user_prim <- ttg[TransitionGroupId %in% sim]                       # types whose primary group is a user group
primary <- unique(c(user_prim$TransitionGroupId, paste0(setdiff(types, user_prim$TransitionTypeId), " [Type]")))
pt <- rd("projection", "transitions.csv")[Method != "None"]
bad <- setdiff(pt[Method == "Target", TransitionGroupId], primary)
check(sprintf("projection targets on primary groups%s", if (length(bad)) paste0(" (not: ", paste(bad, collapse = "; "), ")") else ""), !length(bad))
# management targets (src/management.R) go on the replanting and salvage types' [Type] groups
source(file.path("src", "management.R"))
mg <- paste0(c(unname(MG_REPLANT), paste(unname(MG_REPLANT), "(failed)"), MG_SALVAGE), " [Type]")
bad <- setdiff(mg, primary)
check(sprintf("management targets on primary groups%s", if (length(bad)) paste0(" (not: ", paste(bad, collapse = "; "), ")") else ""), !length(bad))
check("Ag Change is not a simulation group (its two types are targeted separately)", !"Ag Change" %in% sim)
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
