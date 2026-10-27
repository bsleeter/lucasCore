# =============================================================================
# phaseZ11-spinup.R - stages 3, 4 and 8 read Spin-up from a Carbon Assumptions dependency (to-do 21, step 4, 2026-10-28)
# =============================================================================
# On the phaseO library: two runs of stages 3, 4 and 8 (Carbon Options = CBM defaults) depending on Build result 47, one on the
# package-default Carbon Assumptions (base) and one on a copy with
#   California Mixed Conifer, all ecodivisions:      return interval 300 yr, historical cycles half ended by clearcut
#   California Mixed Conifer, the ecodivision with
#     the most FIA plots:                            return interval 60 yr (share blank: 0.5 from the row above)
#   Western Oak, all ecodivisions:                   last disturbance where no fire perimeter = high-severity fire
# Checks: every stage's checks pass; Decay Calibration carries the user return intervals (source "User") and the 0.5 share for mixed
# conifer only; every other forest type's spin-up curves are unchanged; stage 4's age-0 dead pools for the 60-yr cell equal the averaged
# cycle and match a Monte Carlo of 20,000 cycles ended at random by fire or clearcut; stage 8 puts every Western Oak cell on the
# post-fire curves and leaves the other classes' post-fire shares as they were.
# Usage: Rscript tests/phaseZ11-spinup.R      (REUSE=1 rechecks the last runs)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); ok <- TRUE
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
latest <- function(prefix) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & startsWith(Name, prefix)]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
MC <- "Forest: California Mixed Conifer Group"; WO <- "Forest: Western Oak Group"
FIRE <- "Fire: High Severity [Type]"; CUT <- "Forest Harvest: Forest Clearcut [Type]"
BASE <- "Stage 3-4-8 test (spin-up, base)"; CHG <- "Stage 3-4-8 test (spin-up, changed)"
sm <- as.data.table(scenario(L, summary = TRUE)); CA <- sm[Name == "Carbon Assumptions", ScenarioId][1]
# the ecodivision with the most mixed conifer FIA plots in the Build
e1 <- { s <- ds(scenario(L, 47), "lucasCore_OutputDecayCalibration")[StateClassId == MC]; if (!nrow(s)) stop("no mixed conifer cells in Build result 47"); s$StratumId[which.max(s$Plots)] }
if (Sys.getenv("REUSE") == "1") { RB <- latest(BASE); RC <- latest(CHG) } else {
  for (id in sm[startsWith(Name, "Stage 3-4-8 test (spin-up") | startsWith(Name, "Carbon Assumptions (spin-up test"), ScenarioId]) try(delete(L, scenario = id, force = TRUE), silent = TRUE)
  P1 <- rsyncrosim::project(L, 1)
  CT <- scenario(P1, "Carbon Assumptions (spin-up test)", sourceScenario = CA)
  saveDatasheet(CT, data.frame(StratumId = c(NA, e1, NA), StateClassId = c(MC, MC, WO), ReturnInterval = c(300L, 60L, NA), HistoricalClearcutShare = c(0.5, NA, NA),
                               LastDisturbanceUnburned = c(NA, NA, 2L)), "lucasCore_Spinup")
  mk <- function(name, ca) { S <- scenario(P1, name, sourceScenario = 2)
    saveDatasheet(S, data.frame(StageNameId = c("3 - Carbon Flows", "4 - Spin-up and Initial Stocks", "8 - Initial Stock Maps"), RunOrder = 1:3), "core_Pipeline")
    saveDatasheet(S, data.frame(DeadOrganicMatterModel = 3L), "lucasCore_CarbonOptions")
    d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, ca, d[d != CA])); S }
  SB <- mk(BASE, CA); SC <- mk(CHG, scenarioId(CT))
  t0 <- Sys.time(); RB <- run(SB); RC <- run(SC); cat(sprintf("two runs of stages 3, 4, 8: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))) }
cat(logs(RC, "Spin-up|Return intervals|Last disturbance"), sep = "\n")
for (R in list(RB, RC)) { v <- ds(R, "lucasCore_OutputValidation"); expect(sprintf("checks pass (%s)", name(R)), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", Check], collapse = "; ")) }

# ---- stage 3: Decay Calibration ---------------------------------------------------------------------------------------
db <- ds(RB, "lucasCore_OutputDecayCalibration"); dc <- ds(RC, "lucasCore_OutputDecayCalibration")
x <- dc[StateClassId == MC]
expect(sprintf("mixed conifer return interval 60 yr in %s, 300 elsewhere, from the user", e1), x[StratumId == e1, ReturnInterval] == 60 && all(x[StratumId != e1, ReturnInterval] == 300) &&
       all(x$ReturnIntervalSource == "User (Carbon Assumptions: Spin-up)"), sprintf("%d cells", nrow(x)))
expect("mixed conifer historical clearcut share 0.5 in every ecodivision", all(abs(x$HistoricalClearcutShare - 0.5) < 1e-9))
o <- merge(db[StateClassId != MC, .(StratumId, StateClassId, ReturnInterval, ReturnIntervalSource, HistoricalClearcutShare)],
           dc[StateClassId != MC, .(StratumId, StateClassId, ReturnInterval, ReturnIntervalSource, HistoricalClearcutShare)], by = c("StratumId", "StateClassId"))
expect("other forest types keep the LANDFIRE interval and all-fire cycles", nrow(o) > 0 && all(o$ReturnInterval.x == o$ReturnInterval.y) && all(o$ReturnIntervalSource.y != "User (Carbon Assumptions: Spin-up)") &&
       all(o$HistoricalClearcutShare.y == 0), sprintf("%d cells", nrow(o)))

# ---- stage 4: spin-up curves ------------------------------------------------------------------------------------------
cb <- ds(RB, "lucasCore_InitialStockCurve"); cv <- ds(RC, "lucasCore_InitialStockCurve")
POOLS <- setdiff(names(cv), c("InitialStockCurveId", "StratumId", "StateClassId", "TransitionGroupId", "Age"))
k <- c("StratumId", "StateClassId", "TransitionGroupId", "Age"); m <- merge(cb[StateClassId != MC], cv[StateClassId != MC], by = k)
dmax <- max(abs(as.matrix(m[, paste0(POOLS, ".x"), with = FALSE]) - as.matrix(m[, paste0(POOLS, ".y"), with = FALSE])))
expect("other forest types' spin-up curves unchanged", nrow(m) == cb[StateClassId != MC, .N] && dmax < 1e-6, sprintf("%d rows, max difference %.1e", nrow(m), dmax))
chg <- merge(cb[StateClassId == MC & Age == 100], cv[StateClassId == MC & Age == 100], by = k)
cat(sprintf("mixed conifer at age 100, DOM after fire (base -> changed): %s\n", paste(sprintf("%s %.1f -> %.1f", chg$StratumId, chg$TotalDOM.x, chg$TotalDOM.y)[chg$TransitionGroupId == FIRE], collapse = "; ")))

# the averaged cycle against a Monte Carlo of random fire / clearcut cycles, for the 60-yr cell (stage 4's own pieces)
pkg <- "F:/lucasCore"; say <- function(...) invisible(); fail <- function(...) stop(sprintf(...))
for (s in c("flows.R", "dom.R")) source(file.path(pkg, "src", s))
fm <- ds(RC, "stsim_FlowMultiplier")[is.na(AgeMin) & grepl("^(Biomass Turnover|Decay|Emission|Transfer):", FlowGroupId) & StratumId == e1 & StateClassId == MC]
vals <- setNames(as.numeric(fm$Value), sub(" \\[Type\\]$", "", fm$FlowGroupId)); M <- dom_matrices(vals, fread(file.path(pkg, "defaults", "stockflow", "stsim_FlowOrder.csv")))
cc <- ds(RC, "lucasCore_CarbonCurve")[StratumId == e1 & StateClassId == MC][order(Age)]; live <- as.matrix(cc[, names(LIVE_POOLS), with = FALSE])
ev <- ds(RC, "stsim_FlowPathway")[!is.na(TransitionGroupId)]; ri <- 60L
Fm <- disturbance_matrices(ev, FIRE, MC, ri); Hm <- disturbance_matrices(ev, CUT, MC, ri)
fixed <- dom_by_age(M, live, ri, spinup_history(ev, MC, ri, 0.5), Fm)[1, ]
st4 <- unlist(cv[StratumId == e1 & StateClassId == MC & TransitionGroupId == FIRE & Age == 0, names(DOM_POOLS), with = FALSE])
expect("stage 4's age-0 dead pools are the averaged cycle's", max(abs(st4 - fixed)) < 1e-3, sprintf("max difference %.1e Mg C/ha", max(abs(st4 - fixed))))
la <- function(a) live[min(a, nrow(live) - 1) + 1, ]; n <- nrow(M$A); Ari <- diag(n); c0 <- numeric(n)
for (a in 0:(ri - 1)) { c0 <- M$A %*% c0 + M$Apost %*% (M$Tm %*% la(a)); Ari <- M$A %*% Ari }
set.seed(1); xx <- numeric(n); acc <- numeric(n); N <- 20000; burn <- 200
for (j in 1:(N + burn)) { xe <- Ari %*% xx + c0
  if (j > burn) acc <- acc + Fm$Dd %*% xe + Fm$Dl %*% la(ri)
  D <- if (runif(1) < 0.5) Hm else Fm; xx <- D$Dd %*% xe + D$Dl %*% la(ri) }
mc <- as.numeric(acc / N); rel <- abs(sum(mc) - sum(fixed)) / sum(fixed)
expect("Monte Carlo of 20,000 random cycles matches the averaged cycle (total dead carbon within 1%)", rel < 0.01, sprintf("%.1f vs %.1f Mg C/ha", sum(mc), sum(fixed)))
nf <- dom_by_age(M, live, ri, Fm, Fm)[1, ]; cat(sprintf("age-0 dead carbon in that cell: all-fire cycles %.1f, half clearcut %.1f Mg C/ha\n", sum(nf), sum(fixed)))

# ---- stage 8: last disturbance ----------------------------------------------------------------------------------------
sb <- ds(RB, "lucasCore_OutputInitialStockSummary"); sc <- ds(RC, "lucasCore_OutputInitialStockSummary")
expect("every Western Oak cell starts post-fire", sc[StateClassId == WO, PostFire] == 1, sprintf("base %.3f", sb[StateClassId == WO, PostFire]))
p <- merge(sb[, .(StateClassId, PostFire)], sc[, .(StateClassId, PostFire)], by = "StateClassId")[StateClassId != WO]
expect("other classes' post-fire shares unchanged", all(abs(p$PostFire.x - p$PostFire.y) < 1e-9), sprintf("%d classes", nrow(p)))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
