# =============================================================================
# phaseJ-forest-map.R - Forest Type Map option (LANDFIRE EVT vs USFS forest type groups) with the merged Douglas-fir class
# =============================================================================
# On a starter copy: the Growth Curves scenario (stage 2: curves for the one Douglas-fir class), then two builds that depend on it,
# stages 1, 5, 3, 4, 8 for the study area, one per Forest Type Map. Compares forest type areas and initial carbon.
# Usage: Rscript tests/phaseJ-forest-map.R [--units="County: Placer California"]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
D <- "F:/lucasCore/dev/libs"; UNITS <- opt("units", "County: Placer California")
f <- file.path(D, "lucasCore-forest-map.ssim"); unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
file.copy("F:/lucasCore/Starter/LUCAS Core (CONUS).ssim", f)
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE))
sfd <- sc[Name == "Stock-Flow Definitions", ScenarioId]
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
show <- function(R, name) { lg <- logl(R); cat(sprintf("\n==== %s\n", name))
  cat(paste(unique(lg[grepl("Forest type map|Forest type:|crosswalk row|Forest cells|Cells:|Douglas|Initial carbon|Total time: [0-9]|Failure|rror", lg) & !grepl("post processing|saving results", lg)]), collapse = "\n"), "\n")
  v <- as.data.table(datasheet(R, "lucasCore_OutputValidation")); ok <- nrow(v) > 0 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))
  if (!ok && nrow(v)) print(v[Status != "Pass"]); ok }

G <- scenario(L, sc[Name == "Growth Curves", ScenarioId]); RG <- run(G); okG <- show(RG, "Growth Curves")
gp <- as.data.table(datasheet(RG, "lucasCore_OutputGrowthParameter", lookupsAsFactors = FALSE))
cat("curves:", nrow(gp), "; Douglas-fir classes:", paste(unique(grep("Douglas", gp$StateClassId, value = TRUE)), collapse = ", "), "\n")
build <- function(map, name) { S <- rsyncrosim::scenario(P, name); dependency(S) <- c(sfd, scenarioId(RG))
  description(S) <- sprintf("tests/phaseJ-forest-map.R: stages 1, 5, 3, 4, 8 for %s with Forest Type Map = %s; curves from the Growth Curves result.", UNITS, map)
  saveDatasheet(S, data.frame(ForestTypeMap = map), "lucasCore_BuildOptions")
  saveDatasheet(S, data.frame(UnitId = trimws(strsplit(UNITS, ",")[[1]])), "lucasCore_StudyArea")
  st <- c("1 - Study Area and Strata", "5 - Initial Conditions", "3 - Carbon Flows", "4 - Spin-up and Initial Stocks", "8 - Initial Stock Maps")
  saveDatasheet(S, data.frame(StageNameId = st, RunOrder = seq_along(st)), "core_Pipeline"); R <- run(S); list(R = R, ok = show(R, name)) }
rE <- build("LANDFIRE EVT", "Build: LANDFIRE EVT"); rU <- build("USFS forest type groups", "Build: USFS forest type groups")
ss <- function(R) as.data.table(datasheet(R, "lucasCore_OutputInitialStockSummary", lookupsAsFactors = FALSE))[grepl("^Forest", StateClassId)]
cmp <- merge(ss(rE$R)[, .(StateClassId, EVT_cells = Cells, EVT_live = Live)], ss(rU$R)[, .(StateClassId, USFS_cells = Cells, USFS_live = Live)], by = "StateClassId", all = TRUE)
cat("\nForest classes: cells and mean live carbon by map\n"); print(cmp[order(-pmax(EVT_cells, USFS_cells, na.rm = TRUE))])
tot <- function(R) sum(ss(R)$TotalTg); cat(sprintf("\nforest carbon: EVT %.2f Tg, USFS %.2f Tg\n", tot(rE$R), tot(rU$R)))
ok <- okG && rE$ok && rU$ok && !any(grepl("Inland|Coastal", gp$StateClassId))
cat(if (ok) "FOREST MAP OK\n" else "FOREST MAP FAILED\n")
