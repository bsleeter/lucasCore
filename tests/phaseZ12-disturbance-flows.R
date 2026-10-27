# =============================================================================
# phaseZ12-disturbance-flows.R - stage 3 reads Disturbance Flows and Fire Snag Share from Carbon Assumptions (to-do 21, step 5, 2026-10-28)
# =============================================================================
# On the phaseO library, stages 3 and 4 (Carbon Options = CBM defaults) depending on Build result 47:
#   base     the package-default Carbon Assumptions (sheets filled from the defaults) - must reproduce phaseZ11's base run exactly
#   changed  a copy with: clearcut Merchantable -> Forestry Sector 0.85 and -> AG Medium 0.15 (were 0.97 / 0.03), all types;
#            high-severity fire AG Slow -> Atmosphere 0.5 (was 0.80) for California Mixed Conifer in the ecodivision with the most
#            mixed conifer plots only; Western Oak fire snag share 0.20 (was 0.40)
#   invalid  a copy with a second clearcut Merchantable row (-> AG Fast 0.5): Merchantable would lose 1.47 of its stock - stage 3 must stop
# Checks: base flow pathways and spin-up curves equal phaseZ11's base; the changed rows reach stsim_FlowPathway (gas split 90/9/1,
# the ecodivision rows only for that cell, Western Oak's class rows); the spin-up uses them (AG Slow kept by fire 0.5 in that cell,
# 0.20 elsewhere); fire-last curves of the untouched types unchanged, clearcut-last curves carry more AG Medium; the invalid run fails
# on the balance check.
# Usage: Rscript tests/phaseZ12-disturbance-flows.R      (REUSE=1 rechecks the last runs)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); ok <- TRUE
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
latest <- function(prefix) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & startsWith(Name, prefix)]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
MC <- "Forest: California Mixed Conifer Group"; WO <- "Forest: Western Oak Group"
FIRE <- "Fire: High Severity [Type]"; CUT <- "Forest Harvest: Forest Clearcut [Type]"; MER <- "Biomass: Merchantable"
BASE <- "Stage 3-4 test (disturbance flows, base)"; CHG <- "Stage 3-4 test (disturbance flows, changed)"; BAD <- "Stage 3-4 test (disturbance flows, invalid)"
Z11 <- latest("Stage 3-4-8 test (spin-up, base)"); if (is.null(Z11)) stop("run tests/phaseZ11-spinup.R first (its base run is the comparison)")
sm <- as.data.table(scenario(L, summary = TRUE)); CA <- sm[Name == "Carbon Assumptions", ScenarioId][1]
e1 <- { s <- ds(scenario(L, 47), "lucasCore_OutputDecayCalibration")[StateClassId == MC]; s$StratumId[which.max(s$Plots)] }
if (Sys.getenv("REUSE") == "1") { RB <- latest(BASE); RC <- latest(CHG); RX <- latest(BAD) } else {
  for (id in sm[startsWith(Name, "Stage 3-4 test (disturbance flows") | startsWith(Name, "Carbon Assumptions (disturbance"), ScenarioId]) try(delete(L, scenario = id, force = TRUE), silent = TRUE)
  P1 <- rsyncrosim::project(L, 1)
  d0 <- ds(scenario(L, CA), "lucasCore_DisturbanceFlow"); f0 <- ds(scenario(L, CA), "lucasCore_FireSnagShare")
  if (!nrow(d0) || !nrow(f0)) stop("the library's Carbon Assumptions has no Disturbance Flows or Fire Snag Share rows: run tools/sync-library.R")
  cut_mer <- function(d, to) d$Disturbance == "Clearcut" & d$FromStockTypeId == MER & d$ToStockTypeId == to
  d1 <- copy(d0); d1[cut_mer(d1, "Forestry Sector"), Share := 0.85]; d1[cut_mer(d1, "DOM: Aboveground Medium"), Share := 0.15]
  d1 <- rbind(d1, data.table(StratumId = e1, StateClassId = MC, Disturbance = "High-severity fire", FromStockTypeId = "DOM: Aboveground Slow", ToStockTypeId = "Atmosphere", Share = 0.5), fill = TRUE)
  f1 <- copy(f0)[StateClassId == WO, Share := 0.20]
  code <- function(d) { d <- copy(d); d[, Disturbance := match(Disturbance, c("High-severity fire", "Clearcut"))]; as.data.frame(d[, !"DisturbanceFlowId"]) }   # a list column reads as its label
  CT <- scenario(P1, "Carbon Assumptions (disturbance test)", sourceScenario = CA)
  saveDatasheet(CT, code(d1), "lucasCore_DisturbanceFlow"); saveDatasheet(CT, as.data.frame(f1[, !"FireSnagShareId"]), "lucasCore_FireSnagShare")
  CX <- scenario(P1, "Carbon Assumptions (disturbance invalid test)", sourceScenario = CA)
  saveDatasheet(CX, code(rbind(d0, data.table(Disturbance = "Clearcut", FromStockTypeId = MER, ToStockTypeId = "DOM: Aboveground Fast", Share = 0.5), fill = TRUE)), "lucasCore_DisturbanceFlow")
  mk <- function(name, ca) { S <- scenario(P1, name, sourceScenario = 2)
    saveDatasheet(S, data.frame(StageNameId = c("3 - Carbon Flows", "4 - Spin-up and Initial Stocks"), RunOrder = 1:2), "core_Pipeline")
    saveDatasheet(S, data.frame(DeadOrganicMatterModel = 3L), "lucasCore_CarbonOptions")
    d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, ca, d[d != CA])); S }
  SB <- mk(BASE, CA); SC <- mk(CHG, scenarioId(CT)); SX <- mk(BAD, scenarioId(CX))
  t0 <- Sys.time(); RB <- run(SB); RC <- run(SC); RX <- tryCatch(run(SX), error = function(e) latest(BAD))
  cat(sprintf("three runs of stages 3-4: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))) }
cat(logs(RC, "Disturbance Flows|snag share"), sep = "\n")
for (R in list(RB, RC)) { v <- ds(R, "lucasCore_OutputValidation"); expect(sprintf("checks pass (%s)", name(R)), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", Check], collapse = "; ")) }

# ---- base = phaseZ11's base (the filled sheets reproduce the package defaults) ---------------------------------------------
fpk <- function(R) { x <- ds(R, "stsim_FlowPathway")[!is.na(TransitionGroupId)]
  x[, .(k = paste(FromStratumId, FromStateClassId, FromAgeMin, FromStockTypeId, ToStockTypeId, TransitionGroupId, FlowTypeId), v = as.numeric(Multiplier))][order(k)] }
a <- fpk(Z11); b <- fpk(RB)
expect("base event flow pathways equal phaseZ11's base", identical(a$k, b$k) && max(abs(a$v - b$v)) < 1e-9, sprintf("%d rows", nrow(b)))
k <- c("StratumId", "StateClassId", "TransitionGroupId", "Age"); ic <- function(R) ds(R, "lucasCore_InitialStockCurve")
POOLS <- setdiff(names(ic(RB)), c("InitialStockCurveId", k))
mx <- function(x, y) { m <- merge(x, y, by = k); max(abs(as.matrix(m[, paste0(POOLS, ".x"), with = FALSE]) - as.matrix(m[, paste0(POOLS, ".y"), with = FALSE]))) }
expect("base spin-up curves equal phaseZ11's base", mx(ic(Z11), ic(RB)) < 1e-6)

# ---- the changed rows in stsim_FlowPathway --------------------------------------------------------------------------------
fp <- ds(RC, "stsim_FlowPathway")[!is.na(TransitionGroupId)]
cm <- fp[TransitionGroupId == CUT & FromStockTypeId == MER & is.na(FromStateClassId)]
expect("clearcut Merchantable -> Forestry Sector 0.85, -> AG Medium 0.15", abs(cm[ToStockTypeId == "Forestry Sector", Multiplier] - 0.85) < 1e-9 && abs(cm[ToStockTypeId == "DOM: Aboveground Medium", Multiplier] - 0.15) < 1e-9)
ags <- fp[TransitionGroupId == FIRE & FromStockTypeId == "DOM: Aboveground Slow" & FromStratumId %in% e1]
expect(sprintf("fire AG Slow rows for mixed conifer in %s only, split 90/9/1", e1), nrow(ags) == 3 && all(ags$FromStateClassId == MC) &&
       all(abs(sort(ags$Multiplier) - sort(0.5 * c(0.9, 0.09, 0.01))) < 1e-9), sprintf("%d rows", nrow(ags)))
wo <- fp[TransitionGroupId == FIRE & FromStateClassId == WO & FromStockTypeId == MER & ToStockTypeId == "DOM: Snag Stem" & FromAgeMin >= 11]
expect("Western Oak fire stem snags 0.20 x 0.65 / 0.545 for stands 11+", nrow(wo) == 1 && abs(wo$Multiplier - round(0.2 * 0.65 / 0.545, 6)) < 1e-9)

# ---- the spin-up uses them -------------------------------------------------------------------------------------------------
say <- function(...) invisible(); for (s in c("flows.R", "dom.R")) source(file.path("F:/lucasCore/src", s))
ev <- ds(RC, "stsim_FlowPathway")[!is.na(TransitionGroupId)]
other <- setdiff(unique(ds(RC, "lucasCore_OutputDecayCalibration")$StratumId), e1)[1]
k1 <- disturbance_matrices(ev, FIRE, MC, 50, e1)$Dd["AGS", "AGS"]; k2 <- disturbance_matrices(ev, FIRE, MC, 50, other)$Dd["AGS", "AGS"]
expect("fire keeps half of AG Slow in that cell and 0.20 elsewhere", abs(k1 - 0.5) < 1e-9 && abs(k2 - 0.20) < 1e-9, sprintf("%.3f / %.3f (%s)", k1, k2, other))
cb <- ic(RB); cc <- ic(RC); untouched <- function(x) x[TransitionGroupId == FIRE & StateClassId != WO & !(StateClassId == MC & StratumId == e1)]
expect("fire-last curves of the untouched cells unchanged", mx(untouched(cb), untouched(cc)) < 1e-6)
m0 <- merge(cb[TransitionGroupId == CUT & Age == 0, .(StratumId, StateClassId, AGM)], cc[TransitionGroupId == CUT & Age == 0, .(StratumId, StateClassId, AGM)], by = c("StratumId", "StateClassId"))
expect("clearcut leaves more AG Medium at age 0 in every cell", all(m0$AGM.y > m0$AGM.x), sprintf("median %.1f -> %.1f Mg C/ha", median(m0$AGM.x), median(m0$AGM.y)))
mc <- merge(cb[StateClassId == MC & StratumId == e1 & TransitionGroupId == FIRE & Age == 100], cc[StateClassId == MC & StratumId == e1 & TransitionGroupId == FIRE & Age == 100], by = k)
cat(sprintf("mixed conifer in %s, age 100 after fire: AG Slow %.1f -> %.1f, total DOM %.1f -> %.1f Mg C/ha\n", e1, mc$AGS.x, mc$AGS.y, mc$TotalDOM.x, mc$TotalDOM.y))

# ---- the invalid table stops stage 3 ---------------------------------------------------------------------------------------
vx <- if (is.null(RX)) data.table() else tryCatch(ds(RX, "lucasCore_OutputValidation"), error = function(e) data.table())
bx <- if (nrow(vx)) vx[grepl("move at most each pool", Check)] else data.table()
lx <- if (is.null(RX)) character() else logs(RX, "move at most each pool")   # a failed run may keep no output sheets: its log has the check
expect("an over-full clearcut row fails the balance check", (nrow(bx) == 1 && bx$Status != "Pass") || any(grepl("fail", lx, ignore.case = TRUE)),
       if (nrow(bx)) bx$Detail else paste(lx, collapse = " | "))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
