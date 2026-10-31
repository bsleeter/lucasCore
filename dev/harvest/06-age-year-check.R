# =============================================================================
# 06-age-year-check.R - stage 6's study-area minimum harvest ages counting only cuts after the age map's year (1990 for NASA CMS),
# against the previous run that counted every cut (Placer test library; 2026-10-30). Read: the previous "Build test (harvest age)" result.
# Usage: Rscript dev/harvest/06-age-year-check.R
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- suppressWarnings(ssimLibrary(f)); P1 <- rsyncrosim::project(L, 1)
sc <- as.data.table(scenario(L, summary = TRUE))
old <- max(sc[IsResult == "Yes" & startsWith(Name, "Build test (harvest age) ("), ScenarioId]); S5 <- max(sc[IsResult == "Yes" & startsWith(Name, "Stage 5 test (site class shares)"), ScenarioId])
nm <- "Build test (harvest age, cuts after the age map)"; for (id in sc[IsResult == "No" & Name == nm, ScenarioId]) delete(L, scenario = id, force = TRUE)
S <- scenario(P1, nm, sourceScenario = 2); saveDatasheet(S, data.frame(StageNameId = "6 - Historical Transitions", RunOrder = 1L), "core_Pipeline")
bo <- as.data.table(datasheet(S, "lucasCore_BuildOptions", lookupsAsFactors = FALSE, optional = TRUE)); bo <- bo[, setdiff(names(bo), c("BuildOptionsId", "ScenarioId")), with = FALSE]
bo[, `:=`(ForestTypeMap = 1L, StandAgeSource = 1L, SiteProductivity = 1L)]; saveDatasheet(S, as.data.frame(bo), "lucasCore_BuildOptions")
dependency(S) <- unique(c(S5, 47L, as.integer(dependency(S)$ScenarioId)))
t0 <- Sys.time(); R <- run(S); cat(sprintf("stage 6: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
v <- as.data.table(datasheet(R, "lucasCore_OutputValidation")); cat(sprintf("checks: %d, not Pass %d\n", nrow(v), sum(v$Status != "Pass")))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); cat(unique(lg[grepl("^Minimum harvest ages|^Harvest minimum age", lg)]), sep = "\n")
h <- function(id) as.data.table(datasheet(scenario(L, id), "lucasCore_OutputHarvestAge", lookupsAsFactors = FALSE))[, .(StratumId, Type = sub("Forest: ", "", StateClassId), Harvest = sub("^.*: Forest ", "", TransitionTypeId), FiaAge, StudyAreaAge, StudyAreaKm2, AgeMin)]
print(merge(h(old), h(scenarioId(R)), by = c("StratumId", "Type", "Harvest", "FiaAge"), suffixes = c(".all", ".after1990"), all = TRUE))
