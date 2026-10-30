# =============================================================================
# phaseZ16-auto-tiles.R - to-do 22 end to end: Build Options Spatial Tiles = 0 (automatic) in stage 1 (2026-10-29)
# =============================================================================
# On the phaseO library (lucasCore-suitability.ssim, Placer County at 1 km), stage 1 alone, three Build Options:
#   auto-secondary  Spatial Tiles 0, whole Secondary units (counties: Placer is one unit, so automatic must choose one job and warn)
#   auto-tertiary   Spatial Tiles 0, whole Tertiary units (several units: automatic chooses floor(1 / largest share))
#   fixed-3         Spatial Tiles 3, Tertiary: the typed number wins; the log says whether more could help
# Checks: the logged choice equals auto_tiles on the run's own strata maps; a tile mask exactly when more than one tile; every land
# cell in a tile; stage checks pass.
# Usage: Rscript tests/phaseZ16-auto-tiles.R      (REUSE=1 rechecks the last runs)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
pkg <- "F:/lucasCore"; f <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim"); L <- ssimLibrary(f); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
latest <- function(prefix) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & startsWith(Name, prefix)]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
ex <- parse(file.path(pkg, "src", "shared.R")); keep <- c("auto_tiles", "pack_tiles")
for (e in ex) { s <- deparse(e, width.cutoff = 500L)[1]; if (any(startsWith(s, paste0(keep, " <-")))) eval(e, globalenv()) }
CASES <- list(`auto-secondary` = c(tiles = 0L, level = 2L), `auto-tertiary` = c(tiles = 0L, level = 3L), `fixed-3` = c(tiles = 3L, level = 3L))
nm <- function(k) sprintf("Stage 1 test (auto tiles, %s)", k)
sm <- as.data.table(scenario(L, summary = TRUE))
if (Sys.getenv("REUSE") == "1") R <- lapply(setNames(names(CASES), names(CASES)), function(k) latest(nm(k))) else {
  for (id in sm[startsWith(Name, "Stage 1 test (auto tiles"), ScenarioId]) try(delete(L, scenario = id, force = TRUE), silent = TRUE)
  P1 <- rsyncrosim::project(L, 1)
  R <- lapply(setNames(names(CASES), names(CASES)), function(k) { S <- scenario(P1, nm(k), sourceScenario = 2)
    saveDatasheet(S, data.frame(StageNameId = "1 - Study Area and Strata", RunOrder = 1L), "core_Pipeline")
    bo <- as.data.table(datasheet(S, "lucasCore_BuildOptions", lookupsAsFactors = FALSE, optional = TRUE)); bo <- bo[, setdiff(names(bo), c("BuildOptionsId", "ScenarioId")), with = FALSE]
    bo[, `:=`(SpatialTiles = CASES[[k]][["tiles"]], SpatialTilesStrata = CASES[[k]][["level"]])]; saveDatasheet(S, as.data.frame(bo), "lucasCore_BuildOptions")
    t0 <- Sys.time(); r <- run(S); cat(sprintf("%s: %.1f min\n", k, as.numeric(Sys.time() - t0, units = "mins"))); r }) }

for (k in names(CASES)) { r <- R[[k]]; cat("\n----", k, "\n"); cat(logs(r, "Spatial (tiles|multiprocessing)"), sep = "\n")
  v <- as.data.table(datasheet(r, "lucasCore_OutputValidation")); expect(sprintf("%s: stage checks pass", k), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", Check], collapse = "; "))
  ic <- as.data.table(datasheet(r, "stsim_InitialConditionsSpatial", optional = TRUE))
  d <- file.path(paste0(f, ".data"), paste0("Scenario-", scenarioId(r)), "stsim_InitialConditionsSpatial")
  P <- values(rast(file.path(d, basename(ic$StratumFileName))), mat = FALSE)
  U <- values(rast(file.path(d, basename(c(NA, ic$SecondaryStratumFileName, ic$TertiaryStratumFileName)[CASES[[k]][["level"]]]))), mat = FALSE)
  a <- auto_tiles(U, !is.na(P)); want <- if (CASES[[k]][["tiles"]] == 0L) a$n else CASES[[k]][["tiles"]]
  mk <- as.data.table(datasheet(r, "core_SpatialMultiprocessing", optional = TRUE))
  if (CASES[[k]][["tiles"]] == 0L) expect(sprintf("%s: logged automatic choice = auto_tiles on the run's strata (%d)", k, a$n), length(logs(r, sprintf("automatic \\(Build Options\\) -> %d ", a$n))) == 1)
  expect(sprintf("%s: a tile mask exactly when more than one tile (%d)", k, want), (nrow(mk) > 0) == (want > 1))
  if (nrow(mk)) { m <- values(rast(file.path(paste0(f, ".data"), paste0("Scenario-", scenarioId(r)), "core_SpatialMultiprocessing", basename(mk$MaskFileName[1]))), mat = FALSE)
    expect(sprintf("%s: %d tiles in the mask, every land cell in one", k, want), length(unique(m[!is.na(P)])) == want && !anyNA(m[!is.na(P)])) }
  if (a$share > 0.5) expect(sprintf("%s: one unit dominates (%.0f%%): the finer-level warning", k, 100 * a$share), length(logs(r, "a finer Spatial Tiles Strata level")) == 1)
  if (CASES[[k]][["tiles"]] > a$n) expect(sprintf("%s: more tiles than help: said so", k), length(logs(r, "cannot make the run finish sooner")) == 1)
}
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
