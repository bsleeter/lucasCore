# =============================================================================
# 04-multiplier-types.R - to-do 35 phase 0 (b): do two Flow Multiplier Types multiply on the same growth flow in ST-Sim?
# =============================================================================
# On the test library lucasCore-suitability.ssim (Placer at 1 km), from its historical run "Historical (LCMS harvest)" (scenario 48,
# on Build 47), 1985-1987, one iteration:
#   A  as it is: the Build's climate flow spatial multipliers (no type)
#   B  own rows: the Build's climate rows, still untyped (an old Build), plus a Site Productivity row of 2 on the forest growth group
#   C  own rows: the climate rows typed Climate, plus the same Site Productivity row
# (a scenario's own rows replace its dependency's, so B and C carry the climate rows themselves). Adds the project Flow Multiplier
# Types Climate and Site Productivity to this library. Expect forest growth in B and C = 2 x A in every year, other flows the same.
# Usage: Rscript dev/treemap/04-multiplier-types.R      (REUSE=1 rechecks the last runs)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- suppressWarnings(ssimLibrary(f)); P1 <- rsyncrosim::project(L, 1); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
latest <- function(nm) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & startsWith(Name, nm)]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
NM <- c(A = "Multiplier types test A (climate only)", B = "Multiplier types test B (untyped climate + productivity 2)", C = "Multiplier types test C (typed climate + productivity 2)")

mt <- as.data.table(datasheet(P1, "stsim_FlowMultiplierType"))
need <- setdiff(c("Climate", "Site Productivity"), mt$Name)
if (length(need)) { saveDatasheet(P1, data.frame(Name = c(mt$Name, need)), "stsim_FlowMultiplierType"); cat("added Flow Multiplier Types:", paste(need, collapse = ", "), "\n") }

B47 <- scenario(L, 47)
fsm <- as.data.table(datasheet(B47, "stsim_FlowSpatialMultiplier", lookupsAsFactors = FALSE, optional = TRUE))
cat(sprintf("Build 47 climate rows: %d, groups: %s\n", nrow(fsm), paste(unique(fsm$FlowGroupId), collapse = "; ")))
fg <- grep("^Net Growth Forest", unique(fsm$FlowGroupId), value = TRUE)[1]
if (is.na(fg)) fg <- grep("(?i)forest", unique(fsm$FlowGroupId), value = TRUE, perl = TRUE)[1]
cat("Forest growth group:", fg, "\n")
dd <- file.path(paste0(f, ".data"), "Scenario-47", "stsim_FlowSpatialMultiplier")
fsm[, MultiplierFileName := file.path(dd, basename(MultiplierFileName))]
ic <- as.data.table(datasheet(B47, "stsim_InitialConditionsSpatial", optional = TRUE))
P <- rast(file.path(paste0(f, ".data"), "Scenario-47", "stsim_InitialConditionsSpatial", basename(ic$StratumFileName[1])))
two <- file.path(tempdir(), "SiteProductivity-2.tif"); writeRaster(ifel(is.na(P), NA, 2), two, overwrite = TRUE, datatype = "FLT4S")
prod <- data.table(FlowGroupId = fg, FlowMultiplierTypeId = "Site Productivity", MultiplierFileName = two)

if (Sys.getenv("REUSE") == "1") R <- lapply(NM, latest) else {
  sm <- as.data.table(scenario(L, summary = TRUE)); for (id in sm[startsWith(Name, "Multiplier types test"), ScenarioId]) try(delete(L, scenario = id, force = TRUE), silent = TRUE)
  mk <- function(k, rows) { S <- scenario(P1, NM[[k]], sourceScenario = 48)
    rc <- datasheet(S, "stsim_RunControl"); rc$MaximumTimestep <- 1987; saveDatasheet(S, rc, "stsim_RunControl")
    if (!is.null(rows)) saveDatasheet(S, as.data.frame(rows), "stsim_FlowSpatialMultiplier"); S }
  keep <- intersect(c("Timestep", "FlowGroupId", "MultiplierFileName"), names(fsm))
  S <- list(A = mk("A", NULL),
            B = mk("B", rbind(fsm[, ..keep], prod, fill = TRUE)),
            C = mk("C", rbind(fsm[, ..keep][, FlowMultiplierTypeId := "Climate"], prod, fill = TRUE)))
  R <- lapply(names(S), function(k) { t0 <- Sys.time(); r <- run(S[[k]]); cat(sprintf("%s: %.1f min\n", k, as.numeric(Sys.time() - t0, units = "mins"))); r }); names(R) <- names(S) }

fl <- function(r) { x <- as.data.table(datasheet(r, "stsim_OutputFlow", lookupsAsFactors = FALSE)); x[, .(Amount = sum(Amount)), by = .(Timestep, FlowGroupId)] }
X <- lapply(R, fl)
cat("flow groups in the output:", paste(head(unique(X$A$FlowGroupId), 12), collapse = "; "), "\n")
g <- unique(X$A$FlowGroupId); gg <- g[grepl("^Net Growth Forest", g)][1]; if (is.na(gg)) gg <- g[grepl("(?i)growth", g, perl = TRUE)][1]
cmp <- function(k) merge(X$A, X[[k]], by = c("Timestep", "FlowGroupId"), suffixes = c("_A", "_k"))[, ratio := Amount_k / Amount_A]
for (k in c("B", "C")) { m <- cmp(k); cat(sprintf("\n%s / A, %s by year:\n", k, gg)); print(m[FlowGroupId == gg, .(Timestep, Amount_A, Amount_k, ratio = round(ratio, 4))])
  expect(sprintf("%s: forest growth = 2 x A in every year", k), m[FlowGroupId == gg, all(abs(ratio - 2) < 0.01)])   # the runs draw fire and harvest at random (no seed): about 0.5% between runs
  ot <- m[FlowGroupId != gg & !grepl("(?i)growth|npp|primary|turnover|litterfall|total", FlowGroupId, perl = TRUE) & Timestep == min(Timestep) & Amount_A > 0]
  cat(sprintf("%s: first-year ratio of other flow groups: %s\n", k, paste(sprintf("%s %.3f", ot$FlowGroupId, ot$ratio)[1:min(6, nrow(ot))], collapse = "; "))) }
m <- merge(cmp("B")[FlowGroupId == gg, .(Timestep, B = Amount_k)], cmp("C")[FlowGroupId == gg, .(Timestep, C = Amount_k)], by = "Timestep")
expect("B = C within the run-to-run noise (an untyped climate row and a Climate-typed one act the same)", m[, all(abs(B / C - 1) < 0.005)])
# the test only shows climate was kept if the climate multipliers are not about 1: if B or C had dropped them, growth would be 2 / their mean
cm <- fsm[FlowGroupId == fg & Timestep %in% c(1986, 1987)][order(Timestep)]
v <- vapply(cm$MultiplierFileName, function(p) global(mask(rast(p), P), "mean", na.rm = TRUE)[[1]], 0)
cat(sprintf("Mean climate multiplier on forest growth: %s -> growth would be %s x A had climate been dropped\n", paste(sprintf("%d %.3f", cm$Timestep, v), collapse = ", "), paste(sprintf("%.3f", 2 / v), collapse = " / ")))
expect("the climate multipliers differ from 1 by more than the noise, so the test can tell", any(abs(v - 1) > 0.02))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
