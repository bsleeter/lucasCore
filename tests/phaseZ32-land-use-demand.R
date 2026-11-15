# =============================================================================
# phaseZ32-land-use-demand.R - stage 9 with every Land Use Demand method, on a library that has a Build scenario
# =============================================================================
# Land Use Demand (src/land-use-demand.R) multiplies the drawn targets of Urbanization, Intensification, Ag Expansion, Ag Contraction and
# Forest Harvest. This runs stage 9 alone, once per variant, on a Build result and checks each run's validation, its Land Use Demand
# Ratios and what happened to the targets against the baseline (no ratio).
#   1. no --build: a coarse Build of the library's Build scenario is made first (a copy: stages 1, 5 and 6 only, which is all stage 9
#      reads; cell size --resolution, default 990 m; one job)
#   2. per variant: a scenario depending on that result, pipeline = stage 9, 2 iterations to 2100
# The library needs the Land Use Demand data in its Data Sources Home (RPA land use and forest products, ICLUS county table, Hauer and
# Census population). Usage: Rscript tests/phaseZ32-land-use-demand.R <library.ssim> [--build=<result id>] [--resolution=990] [--only=<variant,...>]
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tests/phaseZ32-land-use-demand.R <library.ssim> [--build=<id>]")
f <- normalizePath(pos[1], winslash = "/"); L <- suppressWarnings(ssimLibrary(f)); P <- rsyncrosim::project(L, "Definitions")
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); mins <- function(t0) as.numeric(Sys.time() - t0, units = "mins")
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE, optional = TRUE))
sc <- function() as.data.table(scenario(L, summary = TRUE))
last_log <- function() { r <- sc()[IsResult == "Yes"]; if (nrow(r)) tail(logl(scenario(L, max(r$ScenarioId))), 25) else "no result" }
bid <- as.integer(opt("build", NA))
if (is.na(bid)) { src <- sc()[Name == "Build" & IsResult == "No", ScenarioId]; if (length(src) != 1) stop("the library needs one Build scenario")
  nm <- "Demand test: Build (stages 1, 5, 6)"; for (i in sc()[Name == nm, ScenarioId]) delete(L, scenario = i, force = TRUE)
  S <- rsyncrosim::scenario(P, nm, sourceScenario = src)
  description(S) <- "tests/phaseZ32-land-use-demand.R: a coarse copy of the Build with only the stages stage 9 reads (1, 5, 6)."
  bo <- as.data.frame(datasheet(S, "lucasCore_BuildOptions", lookupsAsFactors = FALSE)); bo$Resolution <- as.integer(opt("resolution", 990)); bo$SpatialTiles <- 1L; saveDatasheet(S, bo, "lucasCore_BuildOptions")
  saveDatasheet(S, data.frame(StageNameId = c("1 - Study Area and Strata", "5 - Initial Conditions", "6 - Historical Transitions"), RunOrder = 1:3), "core_Pipeline")
  t0 <- Sys.time(); RB <- tryCatch(run(S), error = function(e) { cat("BUILD FAILED:", conditionMessage(e), "\n"); NULL }); cat(sprintf("build took %.1f min\n", mins(t0)))
  if (is.null(RB)) { cat(last_log(), sep = "\n"); stop("build failed") }
  v <- ds(RB, "lucasCore_OutputValidation"); print(v[, .(checks = .N, failed = sum(Status != "Pass")), by = Stage]); if (any(v$Status != "Pass")) print(v[Status != "Pass", .(Stage, Check, Detail)])
  bid <- scenarioId(RB); cat("build result:", bid, "\n") }

RPA <- "RPA 2020 Assessment ratio"; POP <- "Population (SSP) x land per new resident"; HI <- "Historical high years (each unit's highest third)"; LO <- "Historical low years (each unit's lowest third)"; CU <- "Custom ratio table"
VAR <- list(
  baseline = list(d = NULL),
  high = list(d = data.frame(UrbanMethod = HI, AgExpansionMethod = HI, AgContractionMethod = HI, HarvestMethod = HI)),
  low = list(d = data.frame(UrbanMethod = LO, AgExpansionMethod = LO, AgContractionMethod = LO, HarvestMethod = LO)),
  rpa_ssp5_metro = list(d = data.frame(UrbanMethod = RPA, UrbanScenario = "RCP8.5-SSP5 (high emissions, high growth)")),
  rpa_ssp3_state = list(d = data.frame(UrbanMethod = RPA, UrbanScenario = "RCP8.5-SSP3 (high emissions, low growth)", UrbanPooling = "State")),
  iclus_ssp2 = list(d = data.frame(UrbanMethod = "ICLUS v2.1.1 (EPA) ratio", UrbanIclus = "SSP2-RCP4.5")),
  iclus_ssp5_county = list(d = data.frame(UrbanMethod = "ICLUS v2.1.1 (EPA) ratio", UrbanIclus = "SSP5-RCP8.5", UrbanPooling = "County")),
  pop_ssp5_sprawl = list(d = data.frame(UrbanMethod = POP, UrbanSsp = "SSP5", LandPerNewResident = 1.5, IntensificationFollows = TRUE)),
  pop_ssp3_compact = list(d = data.frame(UrbanMethod = POP, UrbanSsp = "SSP3", LandPerNewResident = 0.5, IntensificationFollows = TRUE)),
  pop_ssp2_metro = list(d = data.frame(UrbanMethod = POP, UrbanSsp = "SSP2", UrbanPooling = "Metropolitan area (other counties by state)")),
  custom = list(d = data.frame(UrbanMethod = CU, AgExpansionMethod = CU, HarvestMethod = CU),
                r = data.frame(AppliesTo = c(NA, NA, "Urbanization", "Ag Expansion", "Forest Harvest"), UnitId = c(NA, NA, "County: King Washington", NA, "State: Washington"),
                               Year = c(2030L, 2050L, 2040L, 2030L, 2050L), Ratio = c(1.5, 2, 0.5, 2, 0.5))),
  harvest_rpa = list(d = data.frame(HarvestMethod = "RPA 2020 Assessment (forest products) ratio", HarvestScenario = "RCP4.5-SSP1 (lower emissions, medium growth)", AgContractionMethod = LO)),
  primary_strata = list(d = data.frame(UrbanMethod = RPA, UrbanScenario = "RCP8.5-SSP5 (high emissions, high growth)"), primary = TRUE))
only <- opt("only", NA); if (!is.na(only)) VAR <- VAR[intersect(strsplit(only, ",")[[1]], names(VAR))]
KINDS <- c("Urbanization", "Intensification", "Ag Expansion", "Ag Contraction", "Forest Harvest")
kind <- function(g) { k <- KINDS[vapply(KINDS, function(n) startsWith(g, n), TRUE)]; if (length(k)) k[1] else NA_character_ }
res <- list(); base <- NULL; fails <- character()
for (nm in names(VAR)) { v <- VAR[[nm]]; sn <- paste("Demand test:", nm); for (i in sc()[Name == sn, ScenarioId]) delete(L, scenario = i, force = TRUE)
  S <- rsyncrosim::scenario(P, sn); dependency(S) <- bid
  description(S) <- sprintf("tests/phaseZ32-land-use-demand.R: stage 9 alone on build result %d, Land Use Demand variant %s.", bid, nm)
  saveDatasheet(S, data.frame(StageNameId = "9 - Projection Transitions", RunOrder = 1L), "core_Pipeline")
  saveDatasheet(S, data.frame(Iterations = 2L, SpatialTiles = 1L), "lucasCore_ProjectionOptions")
  if (!is.null(v$d)) saveDatasheet(S, v$d, "lucasCore_LandUseDemand"); if (!is.null(v$r)) saveDatasheet(S, v$r, "lucasCore_LandUseDemandRatio")
  if (isTRUE(v$primary)) { pt <- fread(file.path(pkg, "defaults/projection/transitions.csv"), na.strings = ""); pt[Method == "Target", StrataLevel := "Primary"]
    saveDatasheet(S, data.frame(TransitionGroupId = pt$TransitionGroupId, Method = c(Target = "Target (area by strata)", Probability = "Probability (rate map by unit)", None = "None (off in the projection)")[pt$Method],
                                StrataLevel = pt$StrataLevel, UnitSourceId = pt$UnitSource, SamplingSet = pt$SamplingSet, ExcludeGap = pt$ExcludeGap), "lucasCore_ProjectionTransition") }
  t0 <- Sys.time(); R <- tryCatch(run(S), error = function(e) { cat(nm, "RUN FAILED:", conditionMessage(e), "\n"); NULL })
  cat(sprintf("\n===== %s (%.1f min) =====\n", nm, mins(t0)))
  if (is.null(R)) { cat(grep("rror|Land Use Demand|ailure", last_log(), value = TRUE), sep = "\n"); fails <- c(fails, nm); next }
  lg <- logl(R); cat(unique(lg[grepl("Land Use Demand|ratio by|no ratio for|span several|rror|\\[Failure\\]", lg)]), sep = "\n")
  val <- ds(R, "lucasCore_OutputValidation"); bad <- val[Status != "Pass"]; if (nrow(bad)) { print(bad[, .(Check, Detail)]); fails <- c(fails, nm) }
  tt <- ds(R, "stsim_TransitionTarget"); tt <- tt[!is.na(Timestep) & Timestep > 2023]; tt[, Kind := vapply(TransitionGroupId, kind, "")]
  tot <- tt[!is.na(Kind), .(Amount = sum(Amount) / 2), by = .(Kind, Decade = 10 * (Timestep %/% 10))]
  if (nm == "baseline" || is.null(base)) { if (nm == "baseline") base <- tot }
  od <- ds(R, "lucasCore_OutputLandUseDemand")
  if (nrow(od)) { od[, Kind := vapply(TransitionGroup, kind, "")]
    print(dcast(od[Timestep %in% c(2024, 2035, 2050, 2070, 2100), .(r = sprintf("%.2f (%.2f-%.2f)", median(Ratio), min(Ratio), max(Ratio))), by = .(Kind, Timestep)], Kind ~ Timestep, value.var = "r")) }
  if (!is.null(base) && nm != "baseline") { m <- merge(tot, base, by = c("Kind", "Decade"), suffixes = c("", ".base")); m[, Rel := ifelse(Amount.base > 0, Amount / Amount.base, NA_real_)]
    cat("targets relative to the baseline (same draws), by decade:\n"); print(dcast(m[Decade %in% c(2020, 2040, 2060, 2090)], Kind ~ Decade, value.var = "Rel")[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)])
    # a kind with no setting must keep the baseline's targets exactly
    touched <- if (nrow(od)) unique(od$Kind) else character(); same <- m[!Kind %in% touched, all(abs(Amount - Amount.base) <= 1e-6 * pmax(1, Amount.base))]
    if (!isTRUE(same)) { cat("FAIL: a kind without a demand setting changed\n"); fails <- c(fails, nm) }
    if (nrow(od) == 0) { cat("FAIL: no Land Use Demand Ratios output\n"); fails <- c(fails, nm) } }
  res[[nm]] <- scenarioId(R) }
cat("\nresult scenarios:", paste(sprintf("%s=%d", names(res), unlist(res)), collapse = ", "), "\n")
cat(if (length(fails)) sprintf("LAND USE DEMAND FAILED: %s\n", paste(unique(fails), collapse = ", ")) else "LAND USE DEMAND OK\n")
