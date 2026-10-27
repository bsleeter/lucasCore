# =============================================================================
# phaseZ5-fia-datamart.R - Growth Curve Options: FIA Data = USGS condition tables vs FIA DataMart (to-do item 9), stage 2 both ways
# =============================================================================
# On the phaseO library: two copies of the Build scenario (2) running stage 2 only, one per FIA source (DataMart: all 48 states in Data
# Sources: FIA DataMart Folder, current inventories, down dead adjusted by state). Checks: both fit every cell; the DataMart run logs
# 48 states. Compares the fitted curves: merchantable volume and total live carbon at ages 50, 100 and 200 per cell, for all cells and
# for the cells P26 uses. Writes dev/fia/stage2-compare.csv.
# Usage: Rscript tests/phaseZ5-fia-datamart.R [--reuse-usgs]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); ok <- TRUE
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
make <- function(name, src) {
  old <- scenario(L, summary = TRUE); for (id in old$ScenarioId[old$Name == name]) delete(L, scenario = id, force = TRUE)
  s <- scenario(L, name, sourceScenario = 2)
  saveDatasheet(s, data.frame(StageNameId = "2 - Fit Growth Curves", RunOrder = 1L), "core_Pipeline")
  g <- ds(s, "lucasCore_GrowthOptions"); if (!nrow(g)) g <- data.table(CurveSource = 1L)
  g$CurveSource <- 1L; g$FiaSource <- src; g$DownDeadCarbon <- 1L
  keep <- setdiff(names(g), c("GrowthOptionsId", "ScenarioId")); saveDatasheet(s, as.data.frame(g[, ..keep]), "lucasCore_GrowthOptions"); s }
# --reuse-usgs: take the newest existing USGS result instead of fitting again (25 min)
sm <- scenario(L, summary = TRUE); prev <- sm$ScenarioId[sm$ParentId %in% sm$ScenarioId[sm$Name == "Stage 2 test (USGS tables)"]]
if ("--reuse-usgs" %in% commandArgs(TRUE) && length(prev)) { RU <- scenario(L, max(prev)); cat("USGS: reusing result", max(prev), "\n")
} else { t0 <- Sys.time(); RU <- run(make("Stage 2 test (USGS tables)", 1L)); cat(sprintf("USGS run %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))) }
t0 <- Sys.time(); RD <- run(make("Stage 2 test (FIA DataMart)", 2L)); cat(sprintf("DataMart run %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
cat(logs(RU, "FIA data|FIA:|Failure"), logs(RD, "FIA data|FIA:|FIA DataMart|Failure"), sep = "\n")
expect("DataMart run read 48 states", any(grepl("FIA DataMart, 48 states", logs(RD, "FIA data"))))
pu <- ds(RU, "lucasCore_OutputGrowthParameter"); pd <- ds(RD, "lucasCore_OutputGrowthParameter")
expect("both runs fitted every cell", nrow(pu) > 0 && nrow(pu) == nrow(pd), sprintf("%d / %d", nrow(pu), nrow(pd)))
vu <- ds(RU, "lucasCore_MerchantableVolumeCurve"); vd <- ds(RD, "lucasCore_MerchantableVolumeCurve")
cu <- ds(RU, "lucasCore_CarbonCurve"); cd <- ds(RD, "lucasCore_CarbonCurve")
live <- function(x) x[, .(StratumId, StateClassId, Age, live = Merchantable + Foliage + Other + CoarseRoots + FineRoots)]
v <- merge(vu[Age %in% c(50, 100, 200)], vd[Age %in% c(50, 100, 200)], by = c("StratumId", "StateClassId", "Age"), suffixes = c("_u", "_d"))
cc <- merge(live(cu)[Age %in% c(50, 100, 200)], live(cd)[Age %in% c(50, 100, 200)], by = c("StratumId", "StateClassId", "Age"), suffixes = c("_u", "_d"))
m <- merge(v, cc, by = c("StratumId", "StateClassId", "Age"))
m[, `:=`(vol_ratio = MerchantableVolume_d / pmax(MerchantableVolume_u, 1e-9), live_ratio = live_d / pmax(live_u, 1e-9))]
p26 <- c("Mediterranean Mountains", "Temperate Desert")
s <- function(d) d[, .(cells = uniqueN(paste(StratumId, StateClassId)), vol_ratio_median = round(median(vol_ratio), 3), vol_within5 = round(100 * mean(abs(vol_ratio - 1) <= 0.05), 1),
                       live_ratio_median = round(median(live_ratio), 3), live_within5 = round(100 * mean(abs(live_ratio - 1) <= 0.05), 1)), by = Age]
cat("\nAll cells:\n"); print(s(m)); cat("\nP26's ecodivisions:\n"); print(s(m[StratumId %in% p26]))
cat("\nP26's main forest types, Mediterranean Mountains (volume m3/ha; live carbon Mg C/ha):\n")
print(m[StratumId == "Mediterranean Mountains" & grepl("Mixed Conifer|Western Oak|Fir/Spruce|Ponderosa|Lodgepole", StateClassId),
        .(StateClassId = sub("Forest: ", "", StateClassId), Age, vol_u = round(MerchantableVolume_u), vol_d = round(MerchantableVolume_d), live_u = round(live_u, 1), live_d = round(live_d, 1))][order(StateClassId, Age)])
fwrite(m, "F:/lucasCore/dev/fia/stage2-compare.csv")
cat(if (ok) "phaseZ5: all checks pass\n" else "phaseZ5: FAILURES\n")
