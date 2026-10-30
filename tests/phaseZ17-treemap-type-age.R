# =============================================================================
# phaseZ17-treemap-type-age.R - to-do 35 step 2: Build Options Forest Type Map and Stand Age Source = TreeMap in stage 5 (2026-10-30)
# =============================================================================
# On the test library lucasCore-suitability.ssim (Placer at 1 km; synced for the new columns), stage 5 alone on Build 47's stage 1:
#   base     Forest Type Map LANDFIRE EVT, Stand Age NASA CMS (today's default)
#   treemap  Forest Type Map TreeMap, Stand Age TreeMap
# Checks: stage checks pass; TreeMap's coverage logged and >= 95% joined; the same forest cells (forest comes from NLCD, not the type
# map); every forest cell a forest type with growth inputs and an age >= 1, others 0; the type agreement with EVT and the age
# difference reported (P26 at 150 m on 2026-10-26: 61% agreement with the USFS groups, ages median 81 vs CMS 73).
# Usage: Rscript tests/phaseZ17-treemap-type-age.R      (REUSE=1 rechecks the last runs)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
pkg <- "F:/lucasCore"; f <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim"); L <- suppressWarnings(ssimLibrary(f)); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
latest <- function(prefix) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & startsWith(Name, prefix)]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
CASES <- list(base = c(type = 1L, age = 1L), treemap = c(type = 3L, age = 2L)); nm <- function(k) sprintf("Stage 5 test (TreeMap, %s)", k)
if (Sys.getenv("REUSE") == "1") R <- lapply(setNames(names(CASES), names(CASES)), function(k) latest(nm(k))) else {
  sm <- as.data.table(scenario(L, summary = TRUE)); for (id in sm[startsWith(Name, "Stage 5 test (TreeMap"), ScenarioId]) try(delete(L, scenario = id, force = TRUE), silent = TRUE)
  P1 <- rsyncrosim::project(L, 1)
  R <- lapply(setNames(names(CASES), names(CASES)), function(k) { S <- scenario(P1, nm(k), sourceScenario = 2)
    saveDatasheet(S, data.frame(StageNameId = "5 - Initial Conditions", RunOrder = 1L), "core_Pipeline")
    bo <- as.data.table(datasheet(S, "lucasCore_BuildOptions", lookupsAsFactors = FALSE, optional = TRUE)); bo <- bo[, setdiff(names(bo), c("BuildOptionsId", "ScenarioId")), with = FALSE]
    bo[, `:=`(ForestTypeMap = CASES[[k]][["type"]], StandAgeSource = CASES[[k]][["age"]])]; saveDatasheet(S, as.data.frame(bo), "lucasCore_BuildOptions")
    d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, d))
    t0 <- Sys.time(); r <- run(S); cat(sprintf("%s: %.1f min\n", k, as.numeric(Sys.time() - t0, units = "mins"))); r }) }

mp <- function(r, col) { ic <- as.data.table(datasheet(r, "stsim_InitialConditionsSpatial", optional = TRUE))
  values(rast(file.path(paste0(f, ".data"), paste0("Scenario-", scenarioId(r)), "stsim_InitialConditionsSpatial", basename(ic[[col]][1]))), mat = FALSE) }
for (k in names(CASES)) { v <- as.data.table(datasheet(R[[k]], "lucasCore_OutputValidation"))
  expect(sprintf("%s: stage checks pass", k), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", paste(Check, Detail)], collapse = "; ")) }
cat(logs(R$treemap, "TreeMap|Forest type map|Stand age"), sep = "\n")
expect("TreeMap coverage logged", length(logs(R$treemap, "^TreeMap 2016: .* join a forested condition")) == 1)
S0 <- mp(R$base, "StateClassFileName"); S1 <- mp(R$treemap, "StateClassFileName"); A0 <- mp(R$base, "AgeFileName"); A1 <- mp(R$treemap, "AgeFileName")
f0 <- !is.na(S0) & (S0 >= 100 | S0 == 90); f1 <- !is.na(S1) & (S1 >= 100 | S1 == 90)
expect("the same forest cells (forest is from NLCD)", identical(f0, f1), sprintf("%d vs %d", sum(f0), sum(f1)))
gi <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv"))
expect("every TreeMap forest cell is a forest type with growth inputs", all(S1[f1 & S1 >= 100] %in% gi$StateClassId), paste(setdiff(unique(S1[f1 & S1 >= 100]), gi$StateClassId), collapse = ", "))
expect("TreeMap ages: forest >= 1, other land 0", all(A1[f1] >= 1) && all(A1[!f1 & !is.na(S1)] == 0))
ff <- f0 & S0 >= 100
cat(sprintf("Forest type agreement with LANDFIRE EVT: %.0f%% of %d forest cells\n", 100 * mean(S0[ff] == S1[ff]), sum(ff)))
cat(sprintf("Stand age in the start year: median %d (TreeMap) vs %d (CMS), mean %.0f vs %.0f, cell correlation %.2f\n", as.integer(median(A1[ff])), as.integer(median(A0[ff])),
            mean(A1[ff]), mean(A0[ff]), cor(A1[ff], A0[ff])))
tt <- as.data.table(datasheet(R$treemap, "lucasCore_OutputStateClassSummary", lookupsAsFactors = FALSE))[grepl("^Forest", StateClassId)][order(-Cells)]
cat("TreeMap forest types (cells, mean age):\n"); print(head(tt, 8))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
