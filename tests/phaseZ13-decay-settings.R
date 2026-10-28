# =============================================================================
# phaseZ13-decay-settings.R - stage 3 reads Decay Calibration Settings and Fixed Decay Multipliers from Carbon Assumptions
# (to-do 21 step 6 = to-dos 18 and 20, 2026-10-28)
# =============================================================================
# On the phaseO library, stages 3 and 4 with Carbon Options = measured dead wood, depending on Build result 47:
#   base     the package-default Carbon Assumptions - must reproduce phaseZ7's last run exactly
#   changed  a copy with settings Mature Age 80, exclusion 20 yr, Min Snags 500, Multiplier Max 10, and fixed multipliers:
#              snags = 1 for California Mixed Conifer (every ecodivision); soil = 0.5 for mixed conifer in the ecodivision with the
#              most mixed conifer plots; duff = 2 for every forest type in that ecodivision
#   invalid  a copy with Multiplier Min 5 above Multiplier Max 1 - stage 3 must stop
# Checks: base = phaseZ7 (Decay Calibration multipliers, flow multipliers); the settings reach the fit (fewer mature plots, fewer own snag
# fall rates, every calibrated multiplier <= 10); the fixed values are used as given and recorded; mixed conifer's snag decay flows
# are the CBM rates (phaseZ11's CBM-default base); stage checks pass; the invalid run fails.
# Usage: Rscript tests/phaseZ13-decay-settings.R      (REUSE=1 rechecks the last runs)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); ok <- TRUE
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
latest <- function(prefix) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & startsWith(Name, prefix)]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
MC <- "Forest: California Mixed Conifer Group"
BASE <- "Stage 3-4 test (decay settings, base)"; CHG <- "Stage 3-4 test (decay settings, changed)"; BAD <- "Stage 3-4 test (decay settings, invalid)"
Z7 <- latest("Stage 3-4 test (measured dead wood)"); Z11 <- latest("Stage 3-4-8 test (spin-up, base)")
if (is.null(Z7) || is.null(Z11)) stop("run tests/phaseZ7-measured-dom.R and tests/phaseZ11-spinup.R first (their runs are the comparisons)")
sm <- as.data.table(scenario(L, summary = TRUE)); CA <- sm[Name == "Carbon Assumptions", ScenarioId][1]
e1 <- { s <- ds(scenario(L, 47), "lucasCore_OutputDecayCalibration")[StateClassId == MC]; s$StratumId[which.max(s$Plots)] }
if (Sys.getenv("REUSE") == "1") { RB <- latest(BASE); RC <- latest(CHG); RX <- latest(BAD) } else {
  for (id in sm[startsWith(Name, "Stage 3-4 test (decay settings") | startsWith(Name, "Carbon Assumptions (decay settings"), ScenarioId]) try(delete(L, scenario = id, force = TRUE), silent = TRUE)
  P1 <- rsyncrosim::project(L, 1)
  CT <- scenario(P1, "Carbon Assumptions (decay settings test)", sourceScenario = CA)
  saveDatasheet(CT, data.frame(MatureAge = 80L, ExclusionYears = 20L, MinSnagsOwnRate = 500L, MultiplierMax = 10), "lucasCore_DecayCalibrationSetting")
  saveDatasheet(CT, data.frame(StratumId = c(NA, e1, e1), StateClassId = c(MC, MC, NA), Pool = c(1L, 7L, 5L), Multiplier = c(1, 0.5, 2)), "lucasCore_FixedDecayMultiplier")
  CX <- scenario(P1, "Carbon Assumptions (decay settings invalid test)", sourceScenario = CA)
  saveDatasheet(CX, data.frame(MultiplierMin = 5, MultiplierMax = 1), "lucasCore_DecayCalibrationSetting")
  mk <- function(name, ca) { S <- scenario(P1, name, sourceScenario = 2)
    saveDatasheet(S, data.frame(StageNameId = c("3 - Carbon Flows", "4 - Spin-up and Initial Stocks"), RunOrder = 1:2), "core_Pipeline")
    saveDatasheet(S, data.frame(DeadOrganicMatterModel = 4L), "lucasCore_CarbonOptions")
    d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, ca, d[d != CA])); S }
  SB <- mk(BASE, CA); SC <- mk(CHG, scenarioId(CT)); SX <- mk(BAD, scenarioId(CX))
  t0 <- Sys.time(); RB <- run(SB); RC <- run(SC); RX <- tryCatch(run(SX), error = function(e) latest(BAD))
  cat(sprintf("three runs of stages 3-4: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))) }
cat(logs(RC, "Decay Calibration Settings|Fixed Decay Multipliers|Measured dead wood|Decay calibration took"), sep = "\n")
for (R in list(RB, RC)) { v <- ds(R, "lucasCore_OutputValidation"); expect(sprintf("checks pass (%s)", name(R)), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", Check], collapse = "; ")) }

# ---- base = phaseZ7 ---------------------------------------------------------------------------------------------------------
M <- c("SnagDecayMultiplier", "DownWoodDecayMultiplier", "FineWoodyDecayMultiplier", "LitterDecayMultiplier", "DuffDecayMultiplier", "SoilDecayMultiplier", "SnagFallRate")
dk <- function(R) { d <- ds(R, "lucasCore_OutputDecayCalibration"); d[order(StratumId, StateClassId)] }
a <- dk(Z7); b <- dk(RB)
expect("base Decay Calibration equals phaseZ7's", nrow(a) == nrow(b) && identical(a$StateClassId, b$StateClassId) && max(abs(as.matrix(a[, ..M]) - as.matrix(b[, ..M]))) < 1e-9, sprintf("%d cells", nrow(b)))
fmk <- function(R) ds(R, "stsim_FlowMultiplier")[is.na(AgeMin) & grepl("^Forest:", StateClassId), .(k = paste(StratumId, StateClassId, FlowGroupId), Value)][order(k)]
x <- fmk(Z7); y <- fmk(RB)
expect("base flow multipliers equal phaseZ7's", identical(x$k, y$k) && max(abs(x$Value - y$Value)) < 1e-9, sprintf("%d rows", nrow(y)))

# ---- the settings reach the fit ---------------------------------------------------------------------------------------------
c1 <- dk(RC)
expect("fewer mature plots at age 80 than at 60 (exclusion 20 yr)", sum(c1$MeasuredPlots) < sum(b$MeasuredPlots), sprintf("%d vs %d", sum(c1$MeasuredPlots), sum(b$MeasuredPlots)))
expect("fewer cells with their own snag fall rate at 500 snags", sum(startsWith(c1$SnagFallSource, "Cell")) < sum(startsWith(b$SnagFallSource, "Cell")),
       sprintf("%d vs %d", sum(startsWith(c1$SnagFallSource, "Cell")), sum(startsWith(b$SnagFallSource, "Cell"))))
fixedcell <- function(d, col) switch(col, SnagDecayMultiplier = d$StateClassId == MC, DuffDecayMultiplier = d$StratumId == e1, SoilDecayMultiplier = d$StateClassId == MC & d$StratumId == e1, rep(FALSE, nrow(d)))
free_max <- max(sapply(M[1:5], function(col) max(c1[[col]][!fixedcell(c1, col)])))
expect("every calibrated decay multiplier is <= 10", free_max <= 10 + 1e-6, sprintf("largest %.3f (base %.3f)", free_max, max(as.matrix(b[, M[1:5], with = FALSE]))))

# ---- the fixed values -------------------------------------------------------------------------------------------------------
m <- c1[StateClassId == MC]
expect("mixed conifer snag multiplier 1 in every ecodivision", all(abs(m$SnagDecayMultiplier - 1) < 1e-9), sprintf("%d cells", nrow(m)))
expect(sprintf("mixed conifer soil multiplier 0.5 in %s, from the user", e1), abs(m[StratumId == e1, SoilDecayMultiplier] - 0.5) < 1e-9 && startsWith(m[StratumId == e1, SoilSource], "User"))
expect(sprintf("duff multiplier 2 for every forest type in %s", e1), all(abs(c1[StratumId == e1, DuffDecayMultiplier] - 2) < 1e-9), sprintf("%d cells", c1[StratumId == e1, .N]))
expect("the fixed pools are recorded per cell", m[StratumId == e1, FixedMultipliers] == "Snags, Duff, Soil" && all(grepl("Duff", c1[StratumId == e1, FixedMultipliers])) &&
       all(is.na(c1[StateClassId != MC & StratumId != e1, FixedMultipliers])), m[StratumId == e1, FixedMultipliers])
fz <- ds(Z11, "stsim_FlowMultiplier"); fc <- ds(RC, "stsim_FlowMultiplier")
sk <- function(x) x[is.na(AgeMin) & StateClassId == MC & FlowGroupId %in% c("Decay: Snag Stem -> AG Slow [Type]", "Emission: Snag Stem -> Atmosphere [Type]")][order(StratumId, FlowGroupId), .(StratumId, FlowGroupId, Value)]
s1 <- merge(sk(fz), sk(fc), by = c("StratumId", "FlowGroupId"))
expect("mixed conifer snag decay flows are the CBM rates (phaseZ11's CBM-default run)", nrow(s1) > 0 && max(abs(s1$Value.x - s1$Value.y)) < 1e-9, sprintf("%d rows", nrow(s1)))

# ---- the invalid settings stop stage 3 --------------------------------------------------------------------------------------
lx <- if (is.null(RX)) character() else logs(RX, "Decay Calibration Settings: each multiplier minimum")
expect("a minimum above its maximum stops stage 3", length(lx) > 0, paste(lx, collapse = " | "))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
