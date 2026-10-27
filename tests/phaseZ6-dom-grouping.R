# =============================================================================
# phaseZ6-dom-grouping.R - stage 3's decay calibration with the FIA-consistent dead pools (src/dom.R FIA_DOM, 2026-10-26)
# =============================================================================
# On the phaseO library: a copy of the Build scenario (2) running stages 3 and 4 only, depending on Build result 47 (stage 2's curves,
# stage 5's return intervals and soil targets). Compares with result 47 (calibrated with the old grouping: AG Fast as down wood, BG
# Fast as soil): the decay multipliers and clearcut share per cell, and the spin-up's dead pools by stand age band (InitialStockCurve,
# fire and clearcut curves mixed by the clearcut share), grouped as FIADB defines its pools, against FIA (the USGS table) - for the
# cells with the most plots. Writes dev/nfcms/out/grouping-test.csv.
# Usage: Rscript tests/phaseZ6-dom-grouping.R
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); ok <- TRUE
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
name <- "Stage 3-4 test (FIA-consistent DOM groups)"
old <- scenario(L, summary = TRUE); for (id in old$ScenarioId[old$Name == name]) delete(L, scenario = id, force = TRUE)
S <- scenario(L, name, sourceScenario = 2)
saveDatasheet(S, data.frame(StageNameId = c("3 - Carbon Flows", "4 - Spin-up and Initial Stocks"), RunOrder = 1:2), "core_Pipeline")
dependency(S) <- c(47L, as.integer(dependency(S)$ScenarioId))   # Build result 47 first (stage 2 curves, stage 5 return intervals and soil targets)
t0 <- Sys.time(); R <- run(S); cat(sprintf("stages 3-4: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
cat(logs(R, "Decay calibration took|median multipliers|Failure|fail"), sep = "\n")
dn <- ds(R, "lucasCore_OutputDecayCalibration"); d0 <- ds(scenario(L, 47), "lucasCore_OutputDecayCalibration")
expect("calibration rows for every cell of result 47", nrow(dn) > 0 && all(paste(d0$StratumId, d0$StateClassId) %in% paste(dn$StratumId, dn$StateClassId)), sprintf("%d new rows cover result 47's %d", nrow(dn), nrow(d0)))
cols <- c("Plots", "SnagDecayMultiplier", "DownWoodDecayMultiplier", "ForestFloorDecayMultiplier", "SoilDecayMultiplier", "ClearcutShare")
m <- merge(d0[, c("StratumId", "StateClassId", cols), with = FALSE], dn[, c("StratumId", "StateClassId", cols[-1]), with = FALSE], by = c("StratumId", "StateClassId"), suffixes = c("_old", "_new"))
top <- m[order(-Plots)][1:8]
cat("\nDecay multipliers, cells with the most plots (old grouping -> FIA-consistent):\n")
print(top[, .(cell = paste(sub("Forest: ", "", StateClassId), "/", StratumId), Plots, snag = sprintf("%.2f -> %.2f", SnagDecayMultiplier_old, SnagDecayMultiplier_new),
              down = sprintf("%.2f -> %.2f", DownWoodDecayMultiplier_old, DownWoodDecayMultiplier_new), floor = sprintf("%.2f -> %.2f", ForestFloorDecayMultiplier_old, ForestFloorDecayMultiplier_new),
              soil = sprintf("%.2f -> %.2f", SoilDecayMultiplier_old, SoilDecayMultiplier_new), clearcut = sprintf("%.2f -> %.2f", ClearcutShare_old, ClearcutShare_new))])
cat(sprintf("\nMultipliers at a bound (0.05 or 20): old %d, new %d of %d x 3\n", sum(as.matrix(m[, .(SnagDecayMultiplier_old, DownWoodDecayMultiplier_old, ForestFloorDecayMultiplier_old)]) %in% c(0.05, 20)),
            sum(as.matrix(m[, .(SnagDecayMultiplier_new, DownWoodDecayMultiplier_new, ForestFloorDecayMultiplier_new)]) %in% c(0.05, 20)), nrow(m)))

# ---- spin-up dead pools by age band vs FIA, FIA-consistent grouping -------------------------------------------------------------
B <- c(0, 10, 20, 40, 60, 80, 100, 150, 300)
pools <- function(R, dc) { x <- ds(R, "lucasCore_InitialStockCurve"); x[, cut := grepl("Clearcut", TransitionGroupId)]
  x <- merge(x, dc[, .(StratumId, StateClassId, w = ClearcutShare)], by = c("StratumId", "StateClassId"))
  x[, wt := ifelse(cut, w, 1 - w)][, band := cut(Age, B)]
  x[!is.na(band), .(standing = sum(wt * (SnagStem + SnagBranch)) / sum(wt), down = sum(wt * (AGM + BGF)) / sum(wt), floor = sum(wt * (AGVF + AGF + AGS)) / sum(wt)), by = .(StratumId, StateClassId, band)] }
pn <- pools(R, dn); po <- pools(scenario(L, 47), d0)
eco <- as.data.table(sf::st_drop_geometry(sf::read_sf("F:/lucas-master/Data Sources/FIA/EcoDivision_map/EcoDivisions_Dissolve.shp")))[, .(ecodiv = as.character(ecodiv), StrtmId)]
stl <- ds(rsyncrosim::project(L, 1), "stsim_Stratum"); scl <- ds(rsyncrosim::project(L, 1), "stsim_StateClass")
u <- as.data.table(readRDS("F:/lucas-master/Data Sources/FIA/USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds"))
dd <- as.data.table(readRDS("F:/lucas-master/Data Sources/FIA/USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds"))
u <- merge(u, dd, by = c("plt_cn", "condid"))[dstrbcd1 %in% 0 & trtcd1 %in% 0 & !is.na(stdage) & stdage >= 1 & invyr >= 1997 & invyr < 9999]
u[, pid := paste(statecd, unitcd, countycd, plot)]; setorder(u, pid, condid, -invyr); u <- u[!duplicated(paste(pid, condid))]
k <- 2.2417; u[, band := cut(stdage, B)][, StratumId := stl$Name[match(eco$StrtmId[match(as.character(ecodiv), eco$ecodiv)], as.integer(stl$Id))]]
u[, StateClassId := scl$Name[match(fortyp_grp, as.integer(scl$Id))]]
fia <- u[!is.na(band) & !is.na(StateClassId), .(n = .N, standing = mean(c_ag_standing_dead_trees_short_tons_per_acre * k), down = mean(c_down_dead_tons_per_acre * k), floor = mean(c_litter_tons_per_acre * k)), by = .(StratumId, StateClassId, band)]
cmp <- Reduce(function(a, b) merge(a, b, by = c("StratumId", "StateClassId", "band")), list(fia, setnames(copy(po), c("standing", "down", "floor"), paste0(c("standing", "down", "floor"), "_old")),
                                                                                          setnames(copy(pn), c("standing", "down", "floor"), paste0(c("standing", "down", "floor"), "_new"))))
cells <- top[, paste(StratumId, StateClassId)]
for (cl in cells[1:4]) { z <- cmp[paste(StratumId, StateClassId) == cl & n >= 10][order(band)]; if (!nrow(z)) next
  cat(sprintf("\n%s (Mg C/ha; FIA / old grouping / FIA-consistent):\n", cl))
  print(z[, .(band, n, down = sprintf("%5.1f %5.1f %5.1f", down, down_old, down_new), floor = sprintf("%5.1f %5.1f %5.1f", floor, floor_old, floor_new), standing = sprintf("%5.1f %5.1f %5.1f", standing, standing_old, standing_new))]) }
err <- function(a, b, w) sqrt(sum(w * (a - b)^2) / sum(w))
cat(sprintf("\nPlot-weighted RMSE against FIA over every cell x band with >= 10 plots (Mg C/ha), FIA-consistent pools: down %.1f -> %.1f, floor %.1f -> %.1f, standing %.1f -> %.1f\n",
            cmp[n >= 10, err(down_old, down, n)], cmp[n >= 10, err(down_new, down, n)], cmp[n >= 10, err(floor_old, floor, n)], cmp[n >= 10, err(floor_new, floor, n)],
            cmp[n >= 10, err(standing_old, standing, n)], cmp[n >= 10, err(standing_new, standing, n)]))
fwrite(cmp, "F:/lucasCore/dev/nfcms/out/grouping-test.csv")
cat(if (ok) "phaseZ6: all checks pass\n" else "phaseZ6: FAILURES\n")
