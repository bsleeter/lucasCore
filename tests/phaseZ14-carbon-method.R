# =============================================================================
# phaseZ14-carbon-method.R - the Carbon Method on the Carbon Assumptions scenario, its presets, and the soil organic carbon choice
# (user, 2026-10-28)
# =============================================================================
# On the phaseO library, stages 3 and 4 depending on Build result 47 and on a Carbon Assumptions copy:
#   fia-empty   empty sheets, method FIA measured dead wood       = phaseZ13's base (filled with the package defaults), exactly
#   cbm-empty   empty sheets, method CBM defaults on the Carbon Assumptions; the Builds have no Carbon Method of their own (a
#               scenario's own row wins over a dependency's, measured 2026-10-28)
#   cbm-filled  filled with the cbm-defaults preset (tools/carbon-assumptions.R)  = cbm-empty, exactly
#   cbm-soil    cbm-filled + Soil Organic Carbon = gSSURGO: soil multipliers calibrated, every other multiplier still 1
# Checks also: cbm runs write the LUCAS fire and clearcut rows of the CONUS 1 km build (defaults/stockflow/event-pathways-lucas.csv),
# no per-type fire snag rows, every decay multiplier 1 and soil from CBM.
# Usage: Rscript tests/phaseZ14-carbon-method.R      (REUSE=1 rechecks the last runs)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); ok <- TRUE; pkg <- "F:/lucasCore"
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
latest <- function(prefix) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & startsWith(Name, prefix)]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
CASES <- c("fia-empty", "cbm-empty", "cbm-filled", "cbm-soil"); nm <- function(k) sprintf("Stage 3-4 test (carbon method, %s)", k)
Z13 <- latest("Stage 3-4 test (decay settings, base)"); if (is.null(Z13)) stop("run tests/phaseZ13-decay-settings.R first (its base run is the comparison)")
sm <- as.data.table(scenario(L, summary = TRUE)); CA <- sm[Name == "Carbon Assumptions", ScenarioId][1]
if (Sys.getenv("REUSE") == "1") R <- setNames(lapply(CASES, function(k) latest(nm(k))), CASES) else {
  for (id in sm[startsWith(Name, "Stage 3-4 test (carbon method") | startsWith(Name, "Carbon Assumptions (method test"), ScenarioId]) try(delete(L, scenario = id, force = TRUE), silent = TRUE)
  P1 <- rsyncrosim::project(L, 1); source(file.path(pkg, "tools", "carbon-assumptions.R"))
  mkca <- function(k, method, fill = FALSE, soil = NA) { C <- scenario(P1, sprintf("Carbon Assumptions (method test, %s)", k))   # a new, empty scenario
    if (fill) print(fill_carbon_assumptions(C, pkg, if (method == 3L) "cbm-defaults" else "fia-measured"))
    saveDatasheet(C, data.frame(DeadOrganicMatterModel = method, SoilCarbonModel = soil), "lucasCore_CarbonOptions"); C }
  C <- list(`fia-empty` = mkca("fia-empty", 4L), `cbm-empty` = mkca("cbm-empty", 3L), `cbm-filled` = mkca("cbm-filled", 3L, TRUE), `cbm-soil` = mkca("cbm-soil", 3L, TRUE, 1L))
  mk <- function(k) { S <- scenario(P1, nm(k), sourceScenario = 2)
    saveDatasheet(S, data.frame(StageNameId = c("3 - Carbon Flows", "4 - Spin-up and Initial Stocks"), RunOrder = 1:2), "core_Pipeline")
    # a scenario's own row wins over a dependency's (measured 2026-10-28): the Build must have no Carbon Method of its own
    delete(S, datasheet = "lucasCore_CarbonOptions", force = TRUE)
    d <- as.integer(dependency(S)$ScenarioId)   # Carbon Assumptions first: the first dependency with Carbon Method rows supplies them (result 47 has its own)
    dependency(S) <- unique(c(as.integer(scenarioId(C[[k]])), 47L, d[d != CA])); S }
  # one after another, each through the console (running the scenarios of one library at once, from separate R processes or one
  # multi-scenario console call, failed on 2026-10-28: database locked / exit 65535 - a follow-up)
  ids <- vapply(CASES, function(k) as.integer(scenarioId(mk(k))), 1L); t0 <- Sys.time()
  for (i in seq_along(ids)) { t1 <- Sys.time(); r <- tryCatch({ run(scenario(L, ids[i])); "" }, error = function(e) paste(" -", conditionMessage(e)))
    cat(sprintf("%s: %.1f min%s\n", CASES[i], as.numeric(Sys.time() - t1, units = "mins"), r)) }
  R <- setNames(lapply(CASES, function(k) latest(nm(k))), CASES)
  cat(sprintf("four runs of stages 3-4: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))) }
if (any(vapply(R, is.null, TRUE))) stop("no result for: ", paste(CASES[vapply(R, is.null, TRUE)], collapse = ", "))
for (k in CASES) { cat(sprintf("-- %s\n", k)); cat(logs(R[[k]], "Carbon Method|Carbon Assumptions: the sheets|Disturbance Flows:|snag share"), sep = "\n") }
for (k in CASES) { v <- ds(R[[k]], "lucasCore_OutputValidation"); expect(sprintf("checks pass (%s)", k), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", Check], collapse = "; ")) }

fmk <- function(x) ds(x, "stsim_FlowMultiplier")[is.na(AgeMin) & grepl("^Forest:", StateClassId), .(k = paste(StratumId, StateClassId, FlowGroupId), Value)][order(k)]
fpk <- function(x) ds(x, "stsim_FlowPathway")[!is.na(TransitionGroupId), .(k = paste(FromStratumId, FromStateClassId, FromAgeMin, FromStockTypeId, ToStockTypeId, TransitionGroupId, FlowTypeId), v = as.numeric(Multiplier))][order(k)]
same <- function(a, b, col) identical(a$k, b$k) && max(abs(a[[col]] - b[[col]])) < 1e-9
ic <- function(x) { d <- ds(x, "lucasCore_InitialStockCurve"); d[order(StratumId, StateClassId, TransitionGroupId, Age)] }
POOLS <- c("SnagStem", "SnagBranch", "AGVF", "AGF", "AGM", "AGS", "BGVF", "BGF", "BGS")
mx <- function(a, b) max(abs(as.matrix(a[, ..POOLS]) - as.matrix(b[, ..POOLS])))
expect("fia-empty = phaseZ13's base (flow multipliers, flow pathways, spin-up curves)", same(fmk(Z13), fmk(R[["fia-empty"]]), "Value") && same(fpk(Z13), fpk(R[["fia-empty"]]), "v") &&
       mx(ic(Z13), ic(R[["fia-empty"]])) < 1e-6)
expect("a Build with no Carbon Method of its own takes the Carbon Assumptions' (cbm-empty ran CBM defaults)", any(grepl("dead organic matter = CBM defaults", logs(R[["cbm-empty"]], "Carbon Method"))))
expect("cbm-filled = cbm-empty (the preset rows are the empty scenario's rows)", same(fmk(R[["cbm-empty"]]), fmk(R[["cbm-filled"]]), "Value") && same(fpk(R[["cbm-empty"]]), fpk(R[["cbm-filled"]]), "v") &&
       mx(ic(R[["cbm-empty"]]), ic(R[["cbm-filled"]])) < 1e-6)
lucas <- fread(file.path(pkg, "defaults", "stockflow", "event-pathways-lucas.csv"), colClasses = "character", na.strings = "")[TransitionGroupId %in% c("Fire: High Severity [Type]", "Forest Harvest: Forest Clearcut [Type]")]
lk <- lucas[, .(k = paste(FromStockTypeId, ToStockTypeId, TransitionGroupId, FlowTypeId, FromAgeMin), v = as.numeric(Multiplier))][order(k)]
cb <- ds(R[["cbm-filled"]], "stsim_FlowPathway")[TransitionGroupId %in% c("Fire: High Severity [Type]", "Forest Harvest: Forest Clearcut [Type]")]
ck <- cb[, .(k = paste(FromStockTypeId, ToStockTypeId, TransitionGroupId, FlowTypeId, FromAgeMin), v = as.numeric(Multiplier))][order(k)]
expect("cbm runs write the LUCAS fire and clearcut rows, no class rows", identical(lk$k, ck$k) && max(abs(lk$v - ck$v)) < 1e-6 && all(is.na(cb$FromStateClassId)), sprintf("%d rows", nrow(ck)))
dc <- ds(R[["cbm-filled"]], "lucasCore_OutputDecayCalibration"); M5 <- c("SnagDecayMultiplier", "DownWoodDecayMultiplier", "FineWoodyDecayMultiplier", "LitterDecayMultiplier", "DuffDecayMultiplier")
expect("cbm-filled: every decay multiplier 1, soil CBM", all(as.matrix(dc[, ..M5]) == 1) && all(dc$SoilDecayMultiplier == 1) && all(dc$SoilSource == "CBM default"))
ds4 <- ds(R[["cbm-soil"]], "lucasCore_OutputDecayCalibration")
expect("cbm-soil: soil calibrated to gSSURGO, the other multipliers still 1", all(as.matrix(ds4[, ..M5]) == 1) && any(ds4$SoilDecayMultiplier != 1) && any(ds4$SoilSource == "gSSURGO target"),
       sprintf("soil multiplier median %.2f", median(ds4$SoilDecayMultiplier)))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
