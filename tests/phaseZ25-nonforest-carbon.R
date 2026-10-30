# =============================================================================
# phaseZ25-nonforest-carbon.R - to-do 39: Carbon Assumptions > Grassland, Shrubland and Wetland Carbon in stage 3 (2026-10-30)
# =============================================================================
# On the test library lucasCore-suitability.ssim (synced): stage 3 alone on Build result 47, twice -
#   empty  no rows: every grass, shrub and wetland flow multiplier and net growth is the package's, row for row
#   rows   Net Growth of Grassland: Natural Perennial 3.0 (all ecodivisions and ages); "Decay: AG Fast -> AG Slow [Type]" of Shrubland:
#          Sage 0.05 in Temperate Steppe only; "BG Slow ->" (total loss) of Wetland: Palustrine Emergent 0.03 everywhere; Net Growth of
#          Wetland: Palustrine Forested 2.0 at age 50 only: those values land where they should and nowhere else
# Usage: Rscript tests/phaseZ25-nonforest-carbon.R      (REUSE=1 reuses each run that already exists)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- suppressWarnings(ssimLibrary(f)); P1 <- rsyncrosim::project(L, 1); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
reuse <- Sys.getenv("REUSE") == "1"
latest <- function(nm) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & (Name == nm | startsWith(Name, paste0(nm, " ([")))]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
fresh <- function(nm, src) { s <- as.data.table(scenario(L, summary = TRUE)); for (id in s[IsResult == "No" & Name == nm, ScenarioId]) delete(L, scenario = id, force = TRUE); scenario(P1, nm, sourceScenario = src) }
NG <- "Grassland: Natural Perennial"; SG <- "Shrubland: Sage"; FG <- "Decay: AG Fast -> AG Slow [Type]"; ECO <- "Temperate Steppe"
PE <- "Wetland: Palustrine Emergent"; PF <- "Wetland: Palustrine Forested"; BGS <- "BG Slow ->"
run3 <- function(k) { nm <- sprintf("Stage 3 test (non-forest carbon, %s)", k); if (reuse && !is.null(r <- latest(nm))) return(r)
  S <- fresh(nm, 2); saveDatasheet(S, data.frame(StageNameId = "3 - Carbon Flows", RunOrder = 1L), "core_Pipeline")
  saveDatasheet(S, data.frame(DeadOrganicMatterModel = 4L), "lucasCore_CarbonOptions")
  if (k == "rows") {
    saveDatasheet(S, data.frame(StateClassId = c(NG, PF), AgeMin = c(NA, 50L), NetGrowth = c(3.0, 2.0)), "lucasCore_NonForestGrowth")
    saveDatasheet(S, data.frame(StratumId = c(ECO, NA), StateClassId = c(SG, PE), FlowGroupId = c(FG, BGS), Value = c(0.05, 0.03)), "lucasCore_NonForestRate") }
  d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, d))
  t0 <- Sys.time(); r <- run(S); cat(sprintf("stage 3 %s: %.1f min\n", k, as.numeric(Sys.time() - t0, units = "mins"))); r }
R <- lapply(c(empty = "empty", rows = "rows"), run3)
for (k in names(R)) { v <- as.data.table(datasheet(R[[k]], "lucasCore_OutputValidation")); expect(sprintf("%s: stage 3 checks pass", k), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", paste(Check, Detail)], collapse = "; "))
  cat(logs(R[[k]], "^Grassland, Shrubland and Wetland Carbon"), sep = "\n") }
pk <- rbind(fread("F:/lucasCore/defaults/stockflow/nonforest-multipliers-grassland-shrubland.csv"), fread("F:/lucasCore/defaults/stockflow/nonforest-multipliers-wetland.csv"), fill = TRUE)
pg <- fread("F:/lucasCore/defaults/stockflow/nonforest-net-growth.csv")[StateClassId %in% unique(pk$StateClassId)]
K <- c("StratumId", "StateClassId", "AgeMin", "FlowGroupId")
fm <- function(r) { x <- as.data.table(datasheet(r, "stsim_FlowMultiplier", lookupsAsFactors = FALSE))[StateClassId %in% unique(pk$StateClassId)]; x[, AgeMin := as.integer(AgeMin)][, c(K, "Value"), with = FALSE] }
sv <- function(r) { x <- as.data.table(datasheet(r, "stsim_StateAttributeValue", lookupsAsFactors = FALSE))[StateClassId %in% unique(pk$StateClassId) & StateAttributeTypeId == "Net Growth"]
  x[, AgeMin := as.integer(AgeMin)][, .(StratumId, StateClassId, AgeMin, Value)] }
m0 <- fm(R$empty); m1 <- fm(R$rows); g0 <- sv(R$empty); g1 <- sv(R$rows)
k0 <- merge(m0, pk[, .(StratumId, StateClassId, AgeMin = as.integer(AgeMin), FlowGroupId, P = Value)], by = K)
expect("empty: every grass, shrub and wetland flow multiplier is the package's", nrow(k0) == nrow(pk) && max(abs(k0$Value - k0$P)) < 1e-9, sprintf("%d of %d rows", nrow(k0), nrow(pk)))
kg <- merge(g0, pg[, .(StratumId, StateClassId, AgeMin = as.integer(AgeMin), P = Value)], by = c("StratumId", "StateClassId", "AgeMin"))
expect("empty: grass, shrub and wetland net growth is the package's", nrow(kg) == nrow(pg) && max(abs(kg$Value - kg$P)) < 1e-9, sprintf("%d of %d rows", nrow(kg), nrow(pg)))
d <- merge(m0, m1, by = K, suffixes = c("0", "1"))[abs(Value0 - Value1) > 1e-12]
expect("rows: Sage's AG Fast decay changed in Temperate Steppe only, to 0.05", d[StateClassId == SG, .N == 1 && StratumId == ECO && FlowGroupId == FG && abs(Value1 - 0.05) < 1e-12])
expect("rows: Palustrine Emergent's BG Slow total loss 0.03 in every ecodivision", d[StateClassId == PE, .N == uniqueN(pk$StratumId) && all(FlowGroupId == BGS) && all(abs(Value1 - 0.03) < 1e-12)])
expect("rows: no other rate changed", nrow(d[!StateClassId %in% c(SG, PE)]) == 0, sprintf("%d rate rows changed in all", nrow(d)))
dg <- merge(g0, g1, by = c("StratumId", "StateClassId", "AgeMin"), suffixes = c("0", "1"))[abs(Value0 - Value1) > 1e-12]
expect("rows: Natural Perennial net growth 3.0 in every ecodivision", dg[StateClassId == NG, .N == uniqueN(pg$StratumId) && all(abs(Value1 - 3) < 1e-12)])
expect("rows: Palustrine Forested net growth 2.0 at age 50 only, in every ecodivision", dg[StateClassId == PF, .N == uniqueN(pg$StratumId) && all(AgeMin == 50) && all(abs(Value1 - 2) < 1e-12)])
expect("rows: no other net growth changed", nrow(dg[!StateClassId %in% c(NG, PF)]) == 0, sprintf("%d net growth values changed in all", nrow(dg)))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
