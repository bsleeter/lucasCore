# =============================================================================
# phaseZ18-site-productivity-stage2.R - to-do 35 step 3: stage 2 writes Site Productivity when Build Options asks for it (2026-10-30)
# =============================================================================
# On the test library lucasCore-suitability.ssim (synced), stage 2 alone, Build Options: Site Productivity = TreeMap site class:
#   copy  Growth Curve Options as the library's Build (copy the curves from another library), so the multipliers use the copied curves
#   fit   Growth Curve Options: fit new curves (about 13 minutes), the multipliers on the fitted curves
#   off   Site Productivity = None, copying: no Site Productivity rows (results as before)
# Checks: stage checks pass; 532 cells x 7 classes; the log line; the plot-weighted mean 1; California mixed conifer M260 near phase
# 0 (1.59 at site class 2, 0.52 at 6) on the fitted curves; none written when off.
# Usage: Rscript tests/phaseZ18-site-productivity-stage2.R      (REUSE=1 rechecks the last runs)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
pkg <- "F:/lucasCore"; f <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim"); L <- suppressWarnings(ssimLibrary(f)); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
latest <- function(prefix) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & startsWith(Name, prefix)]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
CASES <- list(copy = c(site = 2L, fit = 0L), fit = c(site = 2L, fit = 1L), off = c(site = 1L, fit = 0L)); nm <- function(k) sprintf("Stage 2 test (site productivity, %s)", k)
if (Sys.getenv("REUSE") == "1") R <- lapply(setNames(names(CASES), names(CASES)), function(k) latest(nm(k))) else {
  sm <- as.data.table(scenario(L, summary = TRUE)); for (id in sm[startsWith(Name, "Stage 2 test (site productivity"), ScenarioId]) try(delete(L, scenario = id, force = TRUE), silent = TRUE)
  P1 <- rsyncrosim::project(L, 1)
  R <- lapply(setNames(names(CASES), names(CASES)), function(k) { S <- scenario(P1, nm(k), sourceScenario = 2)
    saveDatasheet(S, data.frame(StageNameId = "2 - Fit Growth Curves", RunOrder = 1L), "core_Pipeline")
    bo <- as.data.table(datasheet(S, "lucasCore_BuildOptions", lookupsAsFactors = FALSE, optional = TRUE)); bo <- bo[, setdiff(names(bo), c("BuildOptionsId", "ScenarioId")), with = FALSE]
    bo[, SiteProductivity := CASES[[k]][["site"]]]; saveDatasheet(S, as.data.frame(bo), "lucasCore_BuildOptions")
    if (CASES[[k]][["fit"]] == 1L) { go <- as.data.table(datasheet(S, "lucasCore_GrowthOptions", lookupsAsFactors = FALSE, optional = TRUE)); go <- go[, setdiff(names(go), c("GrowthOptionsId", "ScenarioId")), with = FALSE]
      go[, CurveSource := 1L]; saveDatasheet(S, as.data.frame(go), "lucasCore_GrowthOptions") }
    t0 <- Sys.time(); r <- run(S); cat(sprintf("%s: %.1f min\n", k, as.numeric(Sys.time() - t0, units = "mins"))); r }) }

for (k in names(CASES)) { r <- R[[k]]; v <- as.data.table(datasheet(r, "lucasCore_OutputValidation"))
  expect(sprintf("%s: stage checks pass", k), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", paste(Check, Detail)], collapse = "; "))
  sp <- as.data.table(datasheet(r, "lucasCore_OutputSiteProductivity", lookupsAsFactors = FALSE, optional = TRUE))
  if (CASES[[k]][["site"]] == 1L) { expect(sprintf("%s: no Site Productivity rows when off", k), nrow(sp) == 0); next }
  cat(logs(r, "^Site productivity"), sep = "\n")
  expect(sprintf("%s: 7 classes for every forest type x ecodivision", k), nrow(sp) > 0 && sp[, .N, by = .(StratumId, StateClassId)][, all(N == 7)], sprintf("%d rows", nrow(sp)))
  wm <- sp[, .(n = sum(Plots), m = sum(Plots * Multiplier) / sum(Plots)), by = .(StratumId, StateClassId)][n > 0]
  expect(sprintf("%s: plot-weighted mean 1 (within 2%%)", k), all(abs(wm$m - 1) <= 0.02))
  mc <- sp[StateClassId == "Forest: California Mixed Conifer Group" & StratumId == "Mediterranean Mountains"][order(SiteClass)]
  cat(sprintf("%s: mixed conifer, Mediterranean Mountains: %s (%s)\n", k, paste(round(mc$Multiplier, 2), collapse = " "), mc$Basis[1]))
  if (k == "fit") expect("fit: mixed conifer M260 near phase 0 (1.59 at 2, 0.52 at 6)", abs(mc[SiteClass == 2, Multiplier] - 1.59) < 0.15 && abs(mc[SiteClass == 6, Multiplier] - 0.52) < 0.1) }
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
