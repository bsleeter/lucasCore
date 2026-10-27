# =============================================================================
# phaseZ10-live-turnover.R - stage 3 reads Live Turnover from a Carbon Assumptions dependency (to-do 21, 2026-10-27)
# =============================================================================
# On the phaseO library: a stage 3 run (Carbon Options = CBM defaults) depending on Build result 47 and a copy of Carbon Assumptions with
#   Douglas-fir, all ecodivisions:   foliage turnover 0.2, fine roots 30% to AG Very Fast
#   Douglas-fir, Marine Mountains:   stem turnover 0.01, stem snag fall 0.06 (foliage and fine roots blank: taken from the row above)
# compared with phaseZ9's base run (package-default Carbon Assumptions). Checks: Douglas-fir foliage 0.2 and the fine root split 0.3 / 0.7
# in every ecodivision; stem turnover 0.01 and stem snag fall 0.06 in Marine Mountains only, branch snag fall in proportion; every other
# forest type unchanged; stage 3's checks pass (net growth still reproduces the carbon curves with the new turnover).
# Usage: Rscript tests/phaseZ10-live-turnover.R      (REUSE=1 rechecks the last run)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); ok <- TRUE
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
latest <- function(prefix) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & startsWith(Name, prefix)]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
RB <- latest("Stage 3 test (DOM parameters, base)"); if (is.null(RB)) stop("run tests/phaseZ9-dom-parameters.R first (its base run is the comparison)")
DF <- "Forest: Douglas-fir Group"; MM <- "Marine Mountains"
if (Sys.getenv("REUSE") == "1") RC <- latest("Stage 3 test (live turnover)") else {
  sm <- as.data.table(scenario(L, summary = TRUE))
  for (id in sm[startsWith(Name, "Stage 3 test (live turnover") | startsWith(Name, "Carbon Assumptions (turnover test"), ScenarioId]) try(delete(L, scenario = id, force = TRUE), silent = TRUE)
  CA <- sm[Name == "Carbon Assumptions", ScenarioId][1]; P1 <- rsyncrosim::project(L, 1)
  CT <- scenario(P1, "Carbon Assumptions (turnover test)", sourceScenario = CA)
  saveDatasheet(CT, data.frame(StratumId = c(NA, MM), StateClassId = DF, FoliageTurnover = c(0.2, NA), FineRootToAG = c(0.3, NA), StemTurnover = c(NA, 0.01), StemSnagFall = c(NA, 0.06)), "lucasCore_LiveTurnover")
  S <- scenario(P1, "Stage 3 test (live turnover)", sourceScenario = 2)
  saveDatasheet(S, data.frame(StageNameId = "3 - Carbon Flows", RunOrder = 1), "core_Pipeline"); saveDatasheet(S, data.frame(DeadOrganicMatterModel = 3L), "lucasCore_CarbonOptions")
  d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, scenarioId(CT), d[d != CA])); t0 <- Sys.time(); RC <- run(S)
  cat(sprintf("stage 3: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))) }
cat(logs(RC, "Live Turnover"), sep = "\n")
v <- ds(RC, "lucasCore_OutputValidation"); expect("stage 3 checks pass", nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", Check], collapse = "; "))
fm <- function(R) ds(R, "stsim_FlowMultiplier")[is.na(AgeMin) & grepl("^(Biomass Turnover|Decay|Emission|Transfer):", FlowGroupId) & grepl("^Forest:", StateClassId), .(StratumId, StateClassId, FlowGroupId, Value)]
m <- merge(fm(RB), fm(RC), by = c("StratumId", "StateClassId", "FlowGroupId"), suffixes = c("_base", "_changed")); m[, diff := abs(Value_changed - Value_base) > 1e-9]
g <- function(fg, st = NULL) { x <- m[StateClassId == DF & FlowGroupId == paste(fg, "[Type]")]; if (!is.null(st)) x <- x[StratumId %in% st]; x }
fol <- g("Biomass Turnover: Foliage -> AG Very Fast"); expect("Douglas-fir foliage turnover 0.2 in every ecodivision", nrow(fol) > 0 && all(abs(fol$Value_changed - 0.2) < 1e-9), sprintf("%d cells", nrow(fol)))
fa <- g("Biomass Turnover: Fine Roots -> AG Very Fast"); fb <- g("Biomass Turnover: Fine Roots -> BG Very Fast")
expect("Douglas-fir fine roots split 0.3 / 0.7 everywhere", all(abs(fa$Value_changed / (fa$Value_changed + fb$Value_changed[match(fa$StratumId, fb$StratumId)]) - 0.3) < 1e-9) &&
       all(abs(fa$Value_changed + fb$Value_changed[match(fa$StratumId, fb$StratumId)] - (fa$Value_base + fb$Value_base[match(fa$StratumId, fb$StratumId)])) < 1e-9))
st <- g("Biomass Turnover: Merchantable -> Snag Stems")
expect("Douglas-fir stem turnover 0.01 in Marine Mountains only", abs(st[StratumId == MM, Value_changed] - 0.01) < 1e-9 && !any(st[StratumId != MM, diff]))
sf <- g("Transfer: Snag Stem -> AG Medium"); bf <- g("Transfer: Snag Branch -> AG Fast")
expect("stem snag fall 0.06 in Marine Mountains only", abs(sf[StratumId == MM, Value_changed] - 0.06) < 1e-9 && !any(sf[StratumId != MM, diff]),
       sprintf("%.4f -> %.4f", sf[StratumId == MM, Value_base], sf[StratumId == MM, Value_changed]))
expect("branch snag fall scaled in proportion there", abs(bf[StratumId == MM, Value_changed] / bf[StratumId == MM, Value_base] - 0.06 / sf[StratumId == MM, Value_base]) < 1e-6)
expect("every other forest type unchanged", !any(m[StateClassId != DF, diff]), sprintf("%d rows", m[StateClassId != DF, .N]))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
