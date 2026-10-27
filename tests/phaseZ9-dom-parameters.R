# =============================================================================
# phaseZ9-dom-parameters.R - stages 3 and 7 read the Dead Organic Matter Parameters from a Carbon Assumptions dependency (to-do 21)
# =============================================================================
# On the phaseO library (synced: Carbon Assumptions with the DOM Parameters): two stage 3 runs depending on Build result 47, Carbon
# Options = CBM defaults (no calibration), so the decay rates are the parameters' alone:
#   base     the package-default Carbon Assumptions
#   changed  a copy with AG Very Fast's base decay rate 0.5 (all ecodivisions) and a Marine Mountains row for AG Medium with Q10 3.0
# Checks: the base run reproduces the previous code's rates (phaseZ8's base run, CBM's float values: within 1e-6); AG Very Fast decay
# and emission follow the new base rate in every cell; AG Medium changes in Marine Mountains only, to CBM's rate at Q10 3.0; nothing
# else changes; the run log lists the changed rows. Then the climate multipliers' Q10s (src/climate.R climate_params) on a small grid:
# a group's Q10 is one number by default, a raster by ecodivision when an ecodivision row changes it, and a group whose pools disagree
# fails its check.
# Usage: Rscript tests/phaseZ9-dom-parameters.R
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); ok <- TRUE
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
sm <- as.data.table(scenario(L, summary = TRUE))
# REUSE=1: check the latest results of an earlier run instead of running stage 3 again
latest <- function(prefix) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & startsWith(Name, prefix)]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
if (Sys.getenv("REUSE") == "1") { RB <- latest("Stage 3 test (DOM parameters, base)"); RC <- latest("Stage 3 test (DOM parameters, changed)")
} else {
  for (id in sm[startsWith(Name, "Stage 3 test (DOM parameters") | startsWith(Name, "Carbon Assumptions (DOM test"), ScenarioId]) try(delete(L, scenario = id, force = TRUE), silent = TRUE)   # a parent's deletion takes its results
  CA <- sm[Name == "Carbon Assumptions", ScenarioId][1]; P1 <- rsyncrosim::project(L, 1)
  CT <- scenario(P1, "Carbon Assumptions (DOM test)", sourceScenario = CA)
  x <- ds(CT, "lucasCore_DomParameter"); pools <- c("AG Very Fast", "BG Very Fast", "AG Fast", "BG Fast", "AG Medium", "AG Slow", "BG Slow", "Snag Stem", "Snag Branch")
  if (is.numeric(x$Pool)) x[, Pool := pools[Pool]]
  x[Pool == "AG Very Fast", BaseDecayRate := 0.5]
  x <- rbind(x, cbind(data.table(StratumId = "Marine Mountains"), x[Pool == "AG Medium", -"StratumId"])[, Q10 := 3.0], fill = TRUE)
  x[, Pool := match(Pool, pools)]; saveDatasheet(CT, as.data.frame(x), "lucasCore_DomParameter")
  run3 <- function(name, ca) { S <- scenario(P1, name, sourceScenario = 2)
    saveDatasheet(S, data.frame(StageNameId = "3 - Carbon Flows", RunOrder = 1), "core_Pipeline"); saveDatasheet(S, data.frame(DeadOrganicMatterModel = 3L), "lucasCore_CarbonOptions")
    d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, ca, d[d != CA])); t0 <- Sys.time(); R <- run(S)
    cat(sprintf("%s: %.1f min\n", name, as.numeric(Sys.time() - t0, units = "mins"))); R }
  RB <- run3("Stage 3 test (DOM parameters, base)", CA); RC <- run3("Stage 3 test (DOM parameters, changed)", scenarioId(CT))
}
cat(logs(RC, "Dead Organic Matter Parameters"), sep = "\n")
expect("the run log lists the changed rows", any(grepl("AG Very Fast \\(rate 0.5", logs(RC, "Dead Organic"))) && any(grepl("Marine Mountains / AG Medium.*Q10 3", logs(RC, "Dead Organic"))))
fm <- function(R) ds(R, "stsim_FlowMultiplier")[is.na(AgeMin) & grepl("^(Biomass Turnover|Decay|Emission|Transfer):", FlowGroupId) & grepl("^Forest:", StateClassId), .(StratumId, StateClassId, FlowGroupId, Value)]
old <- latest("Stage 3 test (CBM crosswalk, base)")
if (!is.null(old)) { mo <- merge(fm(RB), fm(old), by = c("StratumId", "StateClassId", "FlowGroupId"))
  expect("the default parameters reproduce the previous code's rates", nrow(mo) > 0 && max(abs(mo$Value.x - mo$Value.y)) < 1e-6, sprintf("%d rows, max difference %.2e", nrow(mo), max(abs(mo$Value.x - mo$Value.y)))) }
m <- merge(fm(RB), fm(RC), by = c("StratumId", "StateClassId", "FlowGroupId"), suffixes = c("_base", "_changed")); m[, diff := abs(Value_changed - Value_base) > 1e-9]
agvf <- m[FlowGroupId %in% c("Decay: AG Very Fast -> AG Slow [Type]", "Emission: AG Very Fast -> Atmosphere [Type]")]
cap0 <- agvf[, .(s0 = sum(Value_base), s1 = sum(Value_changed)), by = .(StratumId, StateClassId)]; agvf <- merge(agvf, cap0, by = c("StratumId", "StateClassId"))   # s0 >= 1: at the 1.0 cap already
expect("AG Very Fast decay and emission scale by 0.5 / 0.355 in every cell below the 1.0 loss cap (or reach it); cells at the cap unchanged", all(ifelse(agvf$s0 >= 1 - 1e-9, !agvf$diff, abs(agvf$Value_changed / agvf$Value_base - 0.5 / 0.355) < 1e-6 | agvf$s1 >= 1 - 1e-9)),
       sprintf("%d rows (%d at the cap already); ratio %.4f-%.4f", nrow(agvf), sum(agvf$s0 >= 1 - 1e-9), min(agvf$Value_changed / agvf$Value_base), max(agvf$Value_changed / agvf$Value_base)))
agm <- m[grepl("^(Decay|Emission): AG Medium", FlowGroupId)]
dp <- fread("F:/lucasCore/defaults/cbm/dom-parameters.csv")[Pool == "AG Medium"]
expect("AG Medium changes in Marine Mountains only", all(agm[StratumId == "Marine Mountains", diff]) && !any(agm[StratumId != "Marine Mountains", diff]))
k <- agm[StratumId == "Marine Mountains" & grepl("^Decay", FlowGroupId)][1]
tmp <- log(k$Value_base / ((1 - dp$ShareEmitted) * dp$BaseDecayRate)) / (log(dp$Q10) * 0.1) + dp$ReferenceTemperature     # the cell's temperature, from the base rate
want <- (1 - dp$ShareEmitted) * dp$BaseDecayRate * exp((tmp - dp$ReferenceTemperature) * log(3) * 0.1)
expect("Marine Mountains AG Medium decay is CBM's at Q10 3.0", abs(k$Value_changed - want) < 1e-6, sprintf("%.5f -> %.5f (want %.5f at %.1f C)", k$Value_base, k$Value_changed, want, tmp))
other <- m[!FlowGroupId %in% agvf$FlowGroupId & !(grepl("AG Medium", FlowGroupId) & StratumId == "Marine Mountains")]
expect("nothing else changes", !any(other$diff), sprintf("%d rows compared, %d differ", nrow(other), sum(other$diff)))

# ---- climate multipliers: climate_params on a 2-stratum grid, with stubs for the SyncroSim helpers ------------------------------
local({
  env <- new.env(); env$say <- function(...) cat("  say:", sprintf(...), "\n"); rs <- new.env(); rs$res <- list()
  env$check <- function(stage, what, cond, detail = "") rs$res[[length(rs$res) + 1]] <- list(what = what, cond = cond, detail = detail)
  env$stsim_list <- function(x) data.table(Name = c("Marine", "Marine Mountains"), Id = c(1L, 2L))
  env$pkg_file <- function(...) file.path("F:/lucasCore", ...)
  sys.source("F:/lucasCore/src/climate.R", envir = env)
  fm <- fread("F:/lucasCore/defaults/climate/flow-multipliers.csv")[Role == "Decomposition"][, Model := "Q10"]
  Pg <- rast(nrows = 1, ncols = 2, vals = c(1L, 2L))
  base <- fread("F:/lucasCore/defaults/cbm/dom-parameters.csv", na.strings = "")[, .(StratumId = NA_character_, Pool, BaseDecayRate, ReferenceTemperature, Q10, ShareEmitted, TransferToBGSlow)]
  env$read_dom_parameters <- function() base; p0 <- env$climate_params(fm, Pg, "t")
  expect("climate Q10s by default: 2.65 fast, 2.0 slow, single numbers", identical(unname(unlist(p0$q10)), c(2.65, 2)))
  mm <- rbind(base, base[Pool %in% c("AG Very Fast", "AG Slow")][, `:=`(StratumId = "Marine Mountains", Q10 = 3.0)])
  env$read_dom_parameters <- function() mm; p1 <- env$climate_params(fm, Pg, "t")
  q <- p1$q10[["Q10 Fast Flows"]]
  expect("an ecodivision's Q10 makes the group a raster: 2.65 / 3.0", inherits(q, "SpatRaster") && identical(as.numeric(values(q)), c(2.65, 3.0)))
  bad <- copy(base)[Pool == "AG Very Fast", Q10 := 3.0]; env$read_dom_parameters <- function() bad; rs$res <- list(); p2 <- env$climate_params(fm, Pg, "t")
  expect("pools of one climate group with different Q10s fail their check", length(rs$res) == 1 && !rs$res[[1]]$cond, if (length(rs$res)) paste(rs$res[[1]]$what, rs$res[[1]]$detail) else "")
})
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
