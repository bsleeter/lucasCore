# =============================================================================
# phaseZ28-targets-from-run.R - stage 9 takes every Target group's area from what a historical run realized (2026-11-05)
# =============================================================================
# On the test library lucasCore-suitability.ssim (Placer, 1 km; tools/sync-library.R --columns-only first): two Projection Setups (stage 9 only)
# on the stage 6 result of tests/phaseZ27 (477, with stage 5 386 and Build 47 below it), one from the maps, one from historical run 479.
# No ST-Sim run. Checks: stage checks pass; with the run, each Target group's mean target equals the run's mean realized area over the
# reference years; the targets from the run are not above those from the maps for harvest.
# Usage: Rscript tests/phaseZ28-targets-from-run.R
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim"); L <- suppressWarnings(ssimLibrary(f)); P1 <- rsyncrosim::project(L, 1); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
HR <- 479L
# stage 6 alone on the stage 5 result (as tests/phaseZ27; no ST-Sim run): the Build the setups sit on
nm6 <- "Build test (targets from run)"; s0 <- as.data.table(scenario(L, summary = TRUE)); for (id in s0[IsResult == "No" & Name == nm6, ScenarioId]) delete(L, scenario = id, force = TRUE)
S6 <- rsyncrosim::scenario(P1, nm6, sourceScenario = 2); saveDatasheet(S6, data.frame(StageNameId = "6 - Historical Transitions", RunOrder = 1L), "core_Pipeline")
bo <- as.data.table(datasheet(S6, "lucasCore_BuildOptions", lookupsAsFactors = FALSE, optional = TRUE)); bo <- bo[, setdiff(names(bo), c("BuildOptionsId", "ScenarioId")), with = FALSE]
bo[, `:=`(ForestTypeMap = 1L, StandAgeSource = 1L, SiteProductivity = 1L)]; saveDatasheet(S6, as.data.frame(bo), "lucasCore_BuildOptions")
dependency(S6) <- unique(c(386L, 47L, as.integer(dependency(S6)$ScenarioId))); R6 <- run(S6)
v6 <- as.data.table(datasheet(R6, "lucasCore_OutputValidation")); expect("stage 6: checks pass", nrow(v6) > 0 && all(v6$Status == "Pass"), paste(v6[Status != "Pass", paste(Check, Detail)], collapse = "; "))
cat(logs(R6, "^Land-use change|on cells with no pathway|^Placed within"), sep = "\n")
deps <- c(scenarioId(R6), 386L, 47L)
setup <- function(nm, run_id) { s <- as.data.table(scenario(L, summary = TRUE)); for (id in s[IsResult == "No" & Name == nm, ScenarioId]) delete(L, scenario = id, force = TRUE)
  S <- rsyncrosim::scenario(P1, nm); dependency(S) <- deps
  saveDatasheet(S, data.frame(StageNameId = "9 - Projection Transitions", RunOrder = 1L), "core_Pipeline")
  po <- data.frame(ProjectionEndYear = 2030L, Iterations = 1L, RandomSeed = 1L, SpatialTiles = 1L); if (!is.na(run_id)) po$TargetsScenarioId <- run_id
  saveDatasheet(S, po, "lucasCore_ProjectionOptions")
  t0 <- Sys.time(); r <- run(S); cat(sprintf("%s: %.1f min\n", nm, as.numeric(Sys.time() - t0, units = "mins"))); r }
RM <- setup("Setup test (targets from maps)", NA); RR <- setup("Setup test (targets from run)", HR)
for (r in list(RM, RR)) { v <- as.data.table(datasheet(r, "lucasCore_OutputValidation")); expect(sprintf("%s: stage checks pass", name(r)), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", do.call(paste, .SD)], collapse = "; ")) }
cat(logs(RR, "^Targets from historical run|target by"), sep = "\n")
rate <- function(r) as.data.table(datasheet(r, "lucasCore_OutputProjectionRate", lookupsAsFactors = FALSE))[Method == "Target", .(km2 = sum(MeanArea)), by = TransitionGroup]
x <- merge(rate(RM), rate(RR), by = "TransitionGroup", suffixes = c(".maps", ".run"))
# what the run realized: the mean per reference year, by family of each Target group's members
out <- as.data.table(datasheet(scenario(L, HR), "stsim_OutputStratumTransition", lookupsAsFactors = FALSE)); ry <- 1986:2023
fam <- function(g) sub(":.*", "", sub(" [Type]", "", g, fixed = TRUE))
real <- out[Timestep %in% ry & (endsWith(TransitionGroupId, "[Type]") | startsWith(TransitionGroupId, "Ag Contraction: ")), .(real = sum(Amount) / 100 / length(ry)), by = .(f = fam(TransitionGroupId))]
x[, f := fam(TransitionGroup)]; x <- merge(x, real, by = "f", all.x = TRUE); print(x, digits = 5)
expect("targets from the run equal what it realized (km2/yr, each Target group)", x[!is.na(real), all(abs(km2.run - real) < 1e-6 + 1e-6 * real)])
expect("harvest targets from the run are not above the maps'", x[f == "Forest Harvest", all(km2.run <= km2.maps + 1e-9)])
cat(if (ok) "TARGETS FROM RUN OK\n" else "TARGETS FROM RUN FAILED\n"); if (!ok) quit(status = 1)
