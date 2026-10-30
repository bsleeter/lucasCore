# =============================================================================
# phaseZ19-site-class-shares.R - to-do 35 step 4: stage 5 writes the site class share maps (2026-10-30)
# =============================================================================
# On the test library lucasCore-suitability.ssim, stage 5 alone on Build 47's stage 1, Site Productivity = TreeMap site class with the
# default forest type map (LANDFIRE EVT) and stand age (NASA CMS): the shares do not need TreeMap types or ages.
# Checks: stage checks pass; 7 Site Class Shares rows; in every cell with TreeMap pixels the shares add to 1; most forest cells
# covered; the class mix near the study area's pixel mix.
# Usage: Rscript tests/phaseZ19-site-class-shares.R      (REUSE=1 rechecks the last run)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
pkg <- "F:/lucasCore"; f <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim"); L <- suppressWarnings(ssimLibrary(f)); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
NM <- "Stage 5 test (site class shares)"
if (Sys.getenv("REUSE") == "1") { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & startsWith(Name, NM)]; r <- scenario(L, max(s$ScenarioId)) } else {
  sm <- as.data.table(scenario(L, summary = TRUE)); for (id in sm[startsWith(Name, NM), ScenarioId]) try(delete(L, scenario = id, force = TRUE), silent = TRUE)
  S <- scenario(rsyncrosim::project(L, 1), NM, sourceScenario = 2)
  saveDatasheet(S, data.frame(StageNameId = "5 - Initial Conditions", RunOrder = 1L), "core_Pipeline")
  bo <- as.data.table(datasheet(S, "lucasCore_BuildOptions", lookupsAsFactors = FALSE, optional = TRUE)); bo <- bo[, setdiff(names(bo), c("BuildOptionsId", "ScenarioId")), with = FALSE]
  bo[, `:=`(ForestTypeMap = 1L, StandAgeSource = 1L, SiteProductivity = 2L)]; saveDatasheet(S, as.data.frame(bo), "lucasCore_BuildOptions")
  d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, d))
  t0 <- Sys.time(); r <- run(S); cat(sprintf("%.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))) }
v <- as.data.table(datasheet(r, "lucasCore_OutputValidation")); expect("stage checks pass", nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", paste(Check, Detail)], collapse = "; "))
cat(logs(r, "^Site class shares|^TreeMap"), sep = "\n")
sm <- as.data.table(datasheet(r, "lucasCore_OutputSiteClassMap", optional = TRUE)); expect("7 Site Class Shares rows", nrow(sm) == 7 && identical(sort(as.integer(sm$SiteClass)), 1:7))
dd <- file.path(paste0(f, ".data"), paste0("Scenario-", scenarioId(r)), "lucasCore_OutputSiteClassMap")
X <- rast(file.path(dd, basename(sm[order(SiteClass), FileName]))); tot <- values(sum(X, na.rm = TRUE), mat = FALSE); any <- values(any(!is.na(X)), mat = FALSE)
expect("shares add to 1 in every cell with TreeMap pixels", all(abs(tot[any %in% TRUE] - 1) < 1e-4), sprintf("%d cells", sum(any %in% TRUE, na.rm = TRUE)))
ic <- as.data.table(datasheet(r, "stsim_InitialConditionsSpatial", optional = TRUE))
Sv <- values(rast(file.path(paste0(f, ".data"), paste0("Scenario-", scenarioId(r)), "stsim_InitialConditionsSpatial", basename(ic$StateClassFileName[1]))), mat = FALSE)
fc <- which(Sv >= 100); cov <- mean(any[fc] %in% TRUE)
expect("at least 90% of forest cells have site class shares", cov >= 0.9, sprintf("%.1f%%", 100 * cov))
mix <- colMeans(values(X, mat = TRUE)[fc[any[fc] %in% TRUE], ], na.rm = FALSE); mix[is.na(mix)] <- 0
cat(sprintf("mean share over forest cells, site class 1-7: %s\n", paste(sprintf("%.2f", colMeans(replace(values(X, mat = TRUE)[fc[any[fc] %in% TRUE], ], is.na(values(X, mat = TRUE)[fc[any[fc] %in% TRUE], ]), 0))), collapse = " ")))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
