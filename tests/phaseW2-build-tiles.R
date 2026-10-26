# =============================================================================
# phaseW2-build-tiles.R - spatial multiprocessing chosen in the Build (to-do 7): stage 1 writes the tile mask, stage 9 follows it
# =============================================================================
# On the phaseO library (Build source scenario 2, result 47; historical run result 49):
#   A  a copy of the Build scenario running stage 1 only, Build Options 2 tiles of Tertiary units: its result has a tile mask of whole
#      tertiary units covering every land cell
#   B  a Projection Setup whose Build Options (Build 47's, plus the same tiles) set tiles and whose Run Settings set none: stage 9
#      follows the Build - the same mask, and every Target group on Tertiary
#   C  the same setup with Run Settings tiles = 1: a one-tile mask, so the Build's tiles are not inherited
# Usage: Rscript tests/phaseW2-build-tiles.R
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
L <- ssimLibrary(f); ok <- TRUE
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
mask <- function(R) { m <- ds(R, "core_SpatialMultiprocessing"); if (!nrow(m)) return(NULL); values(rast(m$MaskFileName[1]), mat = FALSE) }
ic47 <- ds(scenario(L, 47), "stsim_InitialConditionsSpatial"); Tr <- values(rast(ic47$TertiaryStratumFileName[1]), mat = FALSE); land <- !is.na(Tr)

# ---- A: stage 1 writes the Build's tiles -------------------------------------------------------------------------------------
old <- scenario(L, summary = TRUE); for (id in old$ScenarioId[old$Name %in% c("Build tiles test (stage 1)")]) delete(L, scenario = id, force = TRUE)
A <- scenario(L, "Build tiles test (stage 1)", sourceScenario = 2)
saveDatasheet(A, data.frame(StageNameId = "1 - Study Area and Strata", RunOrder = 1L), "core_Pipeline")
bo <- ds(A, "lucasCore_BuildOptions"); bo$SpatialTiles <- 2L; bo$SpatialTilesStrata <- "Tertiary"
saveDatasheet(A, as.data.frame(bo[, intersect(names(bo), c("Resolution", "SecondarySourceId", "TertiarySourceId", "StartYear", "EndYear", "ForestTypeMap", "SpatialTiles", "SpatialTilesStrata")), with = FALSE]), "lucasCore_BuildOptions")
RA <- run(A); cat(logs(RA, "Spatial multiprocessing|Failure|tile"), sep = "\n")
mA <- mask(RA)
expect("A: the Build result has a tile mask", !is.null(mA))
if (!is.null(mA)) {
  expect("A: two tiles", identical(sort(unique(mA[!is.na(mA)])), 1:2), paste(sort(unique(mA[!is.na(mA)])), collapse = ","))
  expect("A: every land cell is in a tile", all(!is.na(mA[land])) && all(is.na(mA[!land])))
  expect("A: no tertiary unit is split between tiles", data.table(t = Tr[land], k = mA[land])[, uniqueN(k), by = t][, all(V1 == 1)]) }

# ---- B and C: stage 9 follows the Build, or runs one job --------------------------------------------------------------------
tool <- function(script, args) { out <- system2(RS, c(file.path("F:/lucasCore/tools", script), shQuote(f), shQuote(args)), stdout = TRUE, stderr = TRUE)
  out <- out[!grepl("Warning|undetermined|^In ssimLibrary|row names|short variable", out)]; id <- as.integer(tail(out, 1)); if (is.na(id)) { cat(out, sep = "\n"); stop(script, " failed") }; id }
sid <- tool("new-projection-setup.R", c("--build=47", "--historical=49", "--method=None", "--name=Projection Setup (Build tiles test)", "--replace"))
S <- scenario(L, sid)
b47 <- ds(scenario(L, 47), "lucasCore_BuildOptions"); b47$SpatialTiles <- 2L; b47$SpatialTilesStrata <- "Tertiary"
saveDatasheet(S, as.data.frame(b47[, intersect(names(b47), c("Resolution", "SecondarySourceId", "TertiarySourceId", "StartYear", "EndYear", "ForestTypeMap", "SpatialTiles", "SpatialTilesStrata")), with = FALSE]), "lucasCore_BuildOptions")
saveDatasheet(S, data.frame(Iterations = 1L), "lucasCore_ProjectionOptions")
RB <- run(S); cat(logs(RB, "Spatial tiles|tile strata|Failure"), sep = "\n")
mB <- mask(RB)
expect("B: the setup follows the Build's tiles", any(grepl("from the Build", logs(RB, "Spatial tiles"))))
expect("B: same mask as the Build's", !is.null(mB) && !is.null(mA) && identical(as.integer(mB), as.integer(mA)))
tt <- ds(RB, "stsim_TransitionTarget")[Timestep > 2023]
expect("B: targets are by tertiary unit", nrow(tt) > 0 && all(!is.na(tt$TertiaryStratumId)), sprintf("%d target rows", nrow(tt)))

saveDatasheet(S, data.frame(Iterations = 1L, SpatialTiles = 1L), "lucasCore_ProjectionOptions")
RC <- run(S); cat(logs(RC, "Spatial tiles|Failure"), sep = "\n")
mC <- mask(RC)
expect("C: one-tile mask replaces the Build's", !is.null(mC) && identical(sort(unique(mC[!is.na(mC)])), 1L) && all(!is.na(mC[land])))
cat(if (ok) "phaseW2: all checks pass\n" else "phaseW2: FAILURES\n")
