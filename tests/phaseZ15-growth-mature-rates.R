# =============================================================================
# phaseZ15-growth-mature-rates.R - to-dos 28-30 end to end: Mature Age by Forest Type, Growth Inputs, Carbon Rates (2026-10-29)
# =============================================================================
# On the phaseO library (lucasCore-suitability.ssim), measured dead wood, depending on Build result 47:
#   base     stage 3 with the package-default Carbon Assumptions (no Growth Inputs or Mature Age rows) - must reproduce the last
#            phaseZ14 run (carbon method, fia-empty) exactly, and its Carbon Rates must be the flow multipliers it writes
#   changed  stage 3 with a Carbon Assumptions copy: Mature Age 80 yr for California Mixed Conifer; Growth Inputs filled with the
#            package rows, mixed conifer's deciduous share set to 0.3
#   growth   stage 2 fitting the curves (Growth Curve Options: fit new curves) with that copy, plus a fixed fine root share 0.2 for
#            mixed conifer
# Checks: base = phaseZ14 and rates = flow multipliers; changed: mixed conifer has fewer mature plots and the other types the same,
# mixed conifer's foliage turnover moves by (0.3 - package share) x (hardwood - softwood rate) and no other type's turnover changes;
# growth: mixed conifer's fine roots are 0.2 of its roots at every age, the other types follow Li et al. (2003); stage checks pass.
# Usage: Rscript tests/phaseZ15-growth-mature-rates.R      (REUSE=1 rechecks the last runs)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
pkg <- "F:/lucasCore"; f <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim"); L <- ssimLibrary(f); ok <- TRUE
source(file.path(pkg, "src", "flows.R")); source(file.path(pkg, "src", "dom.R"))
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
latest <- function(prefix) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & startsWith(Name, prefix)]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
MC <- "Forest: California Mixed Conifer Group"
BASE <- "Stage 3 test (growth-mature-rates, base)"; CHG <- "Stage 3 test (growth-mature-rates, changed)"; GRO <- "Stage 2 test (growth inputs)"
Z14 <- latest("Stage 3-4 test (carbon method, fia-empty)"); if (is.null(Z14)) stop("run tests/phaseZ14-carbon-method.R first (its fia-empty run is the comparison)")
sm <- as.data.table(scenario(L, summary = TRUE)); CA <- sm[Name == "Carbon Assumptions", ScenarioId][1]
if (Sys.getenv("REUSE") == "1") { RB <- latest(BASE); RC <- latest(CHG); RG <- latest(GRO) } else {
  for (id in sm[startsWith(Name, "Stage 3 test (growth-mature-rates") | startsWith(Name, "Stage 2 test (growth inputs") | startsWith(Name, "Carbon Assumptions (growth-mature-rates"), ScenarioId])
    try(delete(L, scenario = id, force = TRUE), silent = TRUE)
  P1 <- rsyncrosim::project(L, 1)
  CT <- scenario(P1, "Carbon Assumptions (growth-mature-rates test)", sourceScenario = CA)
  gi <- fread(file.path(pkg, "defaults/carbon-assumptions/fia-measured/growth-inputs.csv"), na.strings = "")
  gi[, `:=`(GrowthClass = match(GrowthClass, c("East Softwood", "East Hardwood", "West Softwood", "West Hardwood")), FineRootShare = as.numeric(FineRootShare))][StateClassId == MC, DeciduousShare := 0.3]
  CG <- scenario(P1, "Carbon Assumptions (growth-mature-rates growth test)", sourceScenario = CA)
  saveDatasheet(CT, as.data.frame(gi), "lucasCore_GrowthInput")
  saveDatasheet(CT, data.frame(StateClassId = MC, MatureAge = 80L), "lucasCore_MatureAge")
  saveDatasheet(CG, as.data.frame(copy(gi)[StateClassId == MC, FineRootShare := 0.2]), "lucasCore_GrowthInput")
  mk <- function(name, ca, stage) { S <- scenario(P1, name, sourceScenario = 2)
    saveDatasheet(S, data.frame(StageNameId = stage, RunOrder = 1L), "core_Pipeline")
    saveDatasheet(S, data.frame(DeadOrganicMatterModel = 4L), "lucasCore_CarbonOptions")
    d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, ca, d[d != CA])); S }
  SB <- mk(BASE, CA, "3 - Carbon Flows"); SC <- mk(CHG, scenarioId(CT), "3 - Carbon Flows"); SG <- mk(GRO, scenarioId(CG), "2 - Fit Growth Curves")
  go <- as.data.table(datasheet(SG, "lucasCore_GrowthOptions", lookupsAsFactors = FALSE, optional = TRUE)); go <- go[, setdiff(names(go), c("GrowthOptionsId", "ScenarioId")), with = FALSE]
  go[, CurveSource := 1L]; saveDatasheet(SG, as.data.frame(go), "lucasCore_GrowthOptions")   # fit the curves (Build 2 copies them)
  t0 <- Sys.time(); RB <- run(SB); RC <- run(SC); RG <- run(SG)
  cat(sprintf("three runs: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))) }
cat(logs(RC, "Growth Inputs|Mature Age|Measured dead wood|Carbon Rates"), sep = "\n"); cat(logs(RG, "Growth Inputs|Failure|fail"), sep = "\n")
for (R in list(RB, RC, RG)) { v <- ds(R, "lucasCore_OutputValidation"); expect(sprintf("checks pass (%s)", name(R)), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", Check], collapse = "; ")) }

# ---- base = phaseZ14, rates = flow multipliers --------------------------------------------------------------------------------
fmk <- function(R) ds(R, "stsim_FlowMultiplier")[is.na(AgeMin) & grepl("^Forest:", StateClassId), .(k = paste(StratumId, StateClassId, FlowGroupId), Value)][order(k)]
x <- fmk(Z14); y <- fmk(RB)
expect("base flow multipliers equal phaseZ14's (fia-empty)", identical(x$k, y$k) && max(abs(x$Value - y$Value)) < 1e-9, sprintf("%d rows", nrow(y)))
rt <- ds(RB, "lucasCore_OutputCarbonRate")
rt[, FlowGroupId := paste(FOREST_PATHWAYS$FlowType[match(paste(FromStockTypeId, ToStockTypeId), paste(FOREST_PATHWAYS$From, FOREST_PATHWAYS$To))], "[Type]")]
m <- merge(rt, ds(RB, "stsim_FlowMultiplier")[is.na(AgeMin) & grepl("^Forest:", StateClassId)], by = c("StratumId", "StateClassId", "FlowGroupId"))
expect("Carbon Rates: one row per forest turnover and decay flow multiplier", nrow(m) == nrow(rt) && nrow(rt) == nrow(y), sprintf("%d rates, %d multipliers", nrow(rt), nrow(y)))
expect("Carbon Rates: every rate equals the flow multiplier the run uses", max(abs(m$Rate - m$Value) / pmax(m$Value, 1e-12)) < 1e-5, sprintf("largest relative difference %.2e", max(abs(m$Rate - m$Value) / pmax(m$Value, 1e-12))))
expect("Carbon Rates: every row has a source", all(!is.na(rt$Source) & nzchar(rt$Source)), paste(head(unique(rt$Source), 6), collapse = " | "))

# ---- changed: mature age and deciduous share ----------------------------------------------------------------------------------
db <- ds(RB, "lucasCore_OutputDecayCalibration"); dc <- ds(RC, "lucasCore_OutputDecayCalibration")
pl <- merge(db[, .(StratumId, StateClassId, b = MeasuredPlots)], dc[, .(StratumId, StateClassId, c = MeasuredPlots)], by = c("StratumId", "StateClassId"))
expect("mixed conifer: fewer mature plots at 80 yr", pl[StateClassId == MC, sum(c) < sum(b)], pl[StateClassId == MC, sprintf("%d -> %d", sum(b), sum(c))])
expect("other forest types: the same mature plots", pl[StateClassId != MC, all(b == c)], sprintf("%d cells", pl[StateClassId != MC, .N]))
fol <- function(R) ds(R, "lucasCore_OutputCarbonRate")[FromStockTypeId == "Biomass: Foliage", .(StratumId, StateClassId, Rate)]
fl <- merge(fol(RB), fol(RC), by = c("StratumId", "StateClassId"))
den <- fread(file.path(pkg, "defaults/growth/merch-carbon-density.csv")); d0 <- den[StateClassName == sub("^Forest: ", "", MC), DeciduousShare]
cbm <- fread(file.path(pkg, "defaults/cbm/species-crosswalk.csv"))[StateClassId == MC]; eco <- fread(file.path(pkg, "defaults/cbm/tblEcoBoundaryDefault.csv"))[EcoBoundaryName == cbm$EcoBoundaryId]
want <- (0.3 - d0) * (eco$HardwoodFoliageFallRate - eco$SoftwoodFoliageFallRate)
expect("mixed conifer foliage turnover moves by (0.3 - package share) x (hardwood - softwood)", fl[StateClassId == MC, max(abs(Rate.y - Rate.x - want))] < 1e-5,   # rates are stored to 6 significant digits
       sprintf("expected %+.5f, got %s (%d cells)", want, paste(unique(round(fl[StateClassId == MC, Rate.y - Rate.x], 5)), collapse = "/"), fl[StateClassId == MC, .N]))
expect("no other type's foliage turnover changes", fl[StateClassId != MC, max(abs(Rate.y - Rate.x))] < 1e-12)

# ---- growth: fixed fine root share ---------------------------------------------------------------------------------------------
cc <- ds(RG, "lucasCore_CarbonCurve")
mcs <- cc[StateClassId == MC & FineRoots + CoarseRoots > 0, max(abs(FineRoots / (FineRoots + CoarseRoots) - 0.2))]
expect("mixed conifer fine roots are 0.2 of its roots at every age", mcs < 1e-3, sprintf("largest difference %.2e (4-decimal output)", mcs))
li <- cc[StateClassId != MC & FineRoots + CoarseRoots > 0.05, .(d = abs(FineRoots / (FineRoots + CoarseRoots) - (0.072 + 0.354 * exp(-0.060 * ((FineRoots + CoarseRoots) / 0.5)))))]
expect("the other types follow Li et al. (2003)", max(li$d) < 1e-2, sprintf("largest difference %.2e (4-decimal output)", max(li$d)))
expect("stage 2 logged the Growth Inputs change", length(logs(RG, "Growth Inputs: .*fine root share 0.2")) > 0)
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
