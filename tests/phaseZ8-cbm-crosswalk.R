# =============================================================================
# phaseZ8-cbm-crosswalk.R - stage 3 reads the CBM Crosswalk from a Carbon Assumptions dependency (to-do 21, 2026-10-27)
# =============================================================================
# On the phaseO library (synced: CBM lists and a Carbon Assumptions scenario): two stage 3 runs depending on Build result 47, with
# Carbon Options = CBM defaults (no calibration; quick, and the rates are the CBM crosswalk's alone):
#   base     depends on the package-default Carbon Assumptions
#   changed  depends on a copy with Loblolly/Shortleaf Pine moved from Mixedwood Plains to Taiga Plains (all ecodivisions), and a row for
#            Douglas-fir in Marine Mountains alone (same ecozone and species) with a mean temperature of 2.0 C
# Checks: Loblolly's foliage and stem turnover take Taiga Plains' rates everywhere; Douglas-fir's decay in Marine Mountains is CBM's at
# 2.0 C and elsewhere unchanged; every other cell's turnover and decay rates are identical; the run log lists the changed rows.
# Usage: Rscript tests/phaseZ8-cbm-crosswalk.R
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); ok <- TRUE
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
sm <- as.data.table(scenario(L, summary = TRUE)); for (id in sm[startsWith(Name, "Stage 3 test (CBM crosswalk") | startsWith(Name, "Carbon Assumptions (test"), ScenarioId]) delete(L, scenario = id, force = TRUE)
CA <- sm[Name == "Carbon Assumptions", ScenarioId][1]
CT <- scenario(rsyncrosim::project(L, 1), "Carbon Assumptions (test)", sourceScenario = CA)
x <- ds(CT, "lucasCore_CbmCrosswalk")
x[StateClassId == "Forest: Loblolly/Shortleaf Pine Group", CbmEcozoneId := "Taiga Plains"]
x <- rbind(x, data.table(StratumId = "Marine Mountains", StateClassId = "Forest: Douglas-fir Group", CbmEcozoneId = "Pacific Maritime", CbmSpeciesTypeId = "Douglas-fir - Genus type", MeanTemperature = 2.0), fill = TRUE)
saveDatasheet(CT, as.data.frame(x), "lucasCore_CbmCrosswalk")
run3 <- function(name, ca) { S <- scenario(rsyncrosim::project(L, 1), name, sourceScenario = 2)
  saveDatasheet(S, data.frame(StageNameId = "3 - Carbon Flows", RunOrder = 1), "core_Pipeline"); saveDatasheet(S, data.frame(DeadOrganicMatterModel = 3L), "lucasCore_CarbonOptions")
  d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, ca, d[d != CA])); t0 <- Sys.time(); R <- run(S)
  cat(sprintf("%s: %.1f min\n", name, as.numeric(Sys.time() - t0, units = "mins"))); R }
RB <- run3("Stage 3 test (CBM crosswalk, base)", CA); RC <- run3("Stage 3 test (CBM crosswalk, changed)", scenarioId(CT))
cat(logs(RC, "CBM Crosswalk"), sep = "\n")
expect("the run log lists the changed rows", any(grepl("Taiga Plains", logs(RC, "CBM Crosswalk"))) && any(grepl("Marine Mountains / Douglas-fir.*2.0 C", logs(RC, "CBM Crosswalk"))))
fm <- function(R) ds(R, "stsim_FlowMultiplier")[is.na(AgeMin) & grepl("^(Biomass Turnover|Decay|Emission|Transfer):", FlowGroupId) & grepl("^Forest:", StateClassId), .(StratumId, StateClassId, FlowGroupId, Value)]
m <- merge(fm(RB), fm(RC), by = c("StratumId", "StateClassId", "FlowGroupId"), suffixes = c("_base", "_changed"))
m[, diff := abs(Value_changed - Value_base) > 1e-9]
lob <- m[StateClassId == "Forest: Loblolly/Shortleaf Pine Group"]
fol <- lob[FlowGroupId == "Biomass Turnover: Foliage -> AG Very Fast [Type]"]; stem <- lob[FlowGroupId == "Biomass Turnover: Merchantable -> Snag Stems [Type]"]
expect("Loblolly foliage turnover is Taiga Plains' everywhere", nrow(fol) > 0 && all(fol$Value_changed < fol$Value_base), sprintf("%.3f -> %.3f (%d cells)", fol$Value_base[1], fol$Value_changed[1], nrow(fol)))
expect("Loblolly stem turnover is Taiga Plains' (0.006)", nrow(stem) > 0 && all(abs(stem$Value_changed - 0.006) < 1e-6), sprintf("%.4f -> %.4f", stem$Value_base[1], stem$Value_changed[1]))
df <- m[StateClassId == "Forest: Douglas-fir Group" & FlowGroupId == "Emission: AG Very Fast -> Atmosphere [Type]"]
par <- fread("F:/lucasCore/defaults/cbm/tblDOMParametersDefault.csv")[SoilPoolID == 0]
want <- min(1, par$OrganicMatterDecayRate * exp((2 - par$ReferenceTemp) * log(par$Q10) * 0.1)) * par$PropToAtmosphere
expect("Douglas-fir litter decay in Marine Mountains is CBM's at 2.0 C", isTRUE(all.equal(df[StratumId == "Marine Mountains", Value_changed], want, tolerance = 1e-6)),
       sprintf("%.4f -> %.4f (want %.4f)", df[StratumId == "Marine Mountains", Value_base], df[StratumId == "Marine Mountains", Value_changed], want))
expect("Douglas-fir elsewhere unchanged", !any(m[StateClassId == "Forest: Douglas-fir Group" & StratumId != "Marine Mountains", diff]))
other <- m[StateClassId != "Forest: Loblolly/Shortleaf Pine Group" & !(StateClassId == "Forest: Douglas-fir Group" & StratumId == "Marine Mountains")]
expect("every other cell's turnover and decay rates are identical", !any(other$diff), sprintf("%d rows compared, %d differ", nrow(other), sum(other$diff)))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
