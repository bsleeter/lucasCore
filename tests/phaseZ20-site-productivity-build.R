# =============================================================================
# phaseZ20-site-productivity-build.R - to-do 35 steps 4-6 end to end: Site Productivity = TreeMap site class in a Build (2026-10-30)
# =============================================================================
# On the test library lucasCore-suitability.ssim (Placer, 1 km): two Builds running stages 5, 2, 3, 4, 7, 8 on Build 47's stage 1 with
# the same options (LANDFIRE EVT types, NASA CMS ages, copied curves) except Site Productivity (off / on), then 1985-1987 historical runs
# from "Historical (LCMS harvest)" (scenario 48) on each (dependencies: the test Build first, then Build 47 for stages 1 and 6).
# Checks: stage checks pass; on: the climate rows typed Climate and one Site Productivity row; every forest cell's starting live and dead
# carbon = its multiplier x the off Build's, soil unchanged; non-forest cells 1; the historical forest growth changes by about the
# live-carbon-weighted mean multiplier.
# Usage: Rscript tests/phaseZ20-site-productivity-build.R      (REUSE=1 reuses each run that already exists)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
pkg <- "F:/lucasCore"; f <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim"); L <- suppressWarnings(ssimLibrary(f)); P1 <- rsyncrosim::project(L, 1); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
reuse <- Sys.getenv("REUSE") == "1"
latest <- function(nm) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & Name == nm | IsResult == "Yes" & startsWith(Name, paste0(nm, " (["))]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
fresh <- function(nm, src) { s <- as.data.table(scenario(L, summary = TRUE)); for (id in s[IsResult == "No" & Name == nm, ScenarioId]) delete(L, scenario = id, force = TRUE); scenario(P1, nm, sourceScenario = src) }
mt <- as.data.table(datasheet(P1, "stsim_FlowMultiplierType")); need <- setdiff(c("Climate", "Site Productivity"), mt$Name)
if (length(need)) saveDatasheet(P1, data.frame(Name = c(mt$Name, need)), "stsim_FlowMultiplierType")
NB <- c(off = "Build test (site productivity off)", on = "Build test (site productivity)")
NH <- c(off = "Historical test (site productivity off)", on = "Historical test (site productivity, new Build)")
build <- function(k) { if (reuse && !is.null(r <- latest(NB[[k]]))) return(r)
  S <- fresh(NB[[k]], 2)
  saveDatasheet(S, data.frame(StageNameId = c("5 - Initial Conditions", "2 - Fit Growth Curves", "3 - Carbon Flows", "4 - Spin-up and Initial Stocks", "7 - Climate Multipliers", "8 - Initial Stock Maps"), RunOrder = 1:6), "core_Pipeline")
  bo <- as.data.table(datasheet(S, "lucasCore_BuildOptions", lookupsAsFactors = FALSE, optional = TRUE)); bo <- bo[, setdiff(names(bo), c("BuildOptionsId", "ScenarioId")), with = FALSE]
  bo[, `:=`(ForestTypeMap = 1L, StandAgeSource = 1L, SiteProductivity = if (k == "on") 2L else 1L)]; saveDatasheet(S, as.data.frame(bo), "lucasCore_BuildOptions")
  d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, d))
  t0 <- Sys.time(); r <- run(S); cat(sprintf("Build %s: %.1f min\n", k, as.numeric(Sys.time() - t0, units = "mins"))); r }
hist <- function(k, b) { if (reuse && !is.null(r <- latest(NH[[k]]))) return(r)
  H <- fresh(NH[[k]], 48); rc <- datasheet(H, "stsim_RunControl"); rc$MaximumTimestep <- 1987; saveDatasheet(H, rc, "stsim_RunControl")
  d <- as.integer(dependency(H)$ScenarioId); dependency(H) <- unique(c(scenarioId(b), 47L, d))   # the test Build first (its sheets win), Build 47 for stages 1 and 6
  t0 <- Sys.time(); r <- run(H); cat(sprintf("historical %s: %.1f min\n", k, as.numeric(Sys.time() - t0, units = "mins"))); r }
RB <- lapply(c(off = "off", on = "on"), build); RH <- lapply(c(off = "off", on = "on"), function(k) hist(k, RB[[k]]))

for (k in names(RB)) { v <- as.data.table(datasheet(RB[[k]], "lucasCore_OutputValidation")); expect(sprintf("Build %s: stage checks pass", k), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", paste(Check, Detail)], collapse = "; ")) }
cat(logs(RB$on, "^Site productivity: forest"), sep = "\n")
fsm <- as.data.table(datasheet(RB$on, "stsim_FlowSpatialMultiplier", lookupsAsFactors = FALSE, optional = TRUE))
expect("on: climate rows typed Climate, one Site Productivity row", fsm[FlowMultiplierTypeId == "Site Productivity", .N] == 1 && fsm[FlowMultiplierTypeId != "Site Productivity", all(FlowMultiplierTypeId == "Climate")])
expect("off: no Site Productivity row", !nrow(as.data.table(datasheet(RB$off, "stsim_FlowSpatialMultiplier", lookupsAsFactors = FALSE, optional = TRUE))[FlowMultiplierTypeId %in% "Site Productivity"]))
dd <- function(r, sh) file.path(paste0(f, ".data"), paste0("Scenario-", scenarioId(r)), sh)
mult <- values(rast(file.path(dd(RB$on, "stsim_FlowSpatialMultiplier"), basename(fsm[FlowMultiplierTypeId == "Site Productivity", MultiplierFileName]))), mat = FALSE)
isv <- function(r) { x <- as.data.table(datasheet(r, "stsim_InitialStockSpatial", lookupsAsFactors = FALSE)); setNames(lapply(x$RasterFileName, function(p) values(rast(file.path(dd(r, "stsim_InitialStockSpatial"), basename(p))), mat = FALSE)), x$StockTypeId) }
s0 <- isv(RB$off); s1 <- isv(RB$on)
ic <- as.data.table(datasheet(RB$on, "stsim_InitialConditionsSpatial", optional = TRUE)); Sv <- values(rast(file.path(dd(RB$on, "stsim_InitialConditionsSpatial"), basename(ic$StateClassFileName[1]))), mat = FALSE)
fc <- which(Sv >= 100); live <- grep("^Biomass", names(s0), value = TRUE); dom <- setdiff(grep("^DOM", names(s0), value = TRUE), "DOM: Belowground Slow")
L0 <- Reduce(`+`, s0[live]); L1 <- Reduce(`+`, s1[live]); D0 <- Reduce(`+`, s0[dom]); D1 <- Reduce(`+`, s1[dom]); ok_l <- fc[L0[fc] > 0.01]
expect("every forest cell's starting live carbon = its multiplier x the off Build's", max(abs(L1[ok_l] / L0[ok_l] - mult[ok_l])) < 1e-3, sprintf("%d cells, largest difference %.2e", length(ok_l), max(abs(L1[ok_l] / L0[ok_l] - mult[ok_l]))))
expect("dead organic matter scaled the same way; soil unchanged", max(abs(D1[ok_l] - D0[ok_l] * mult[ok_l]) / pmax(D0[ok_l], 1e-6)) < 1e-3 && max(abs(s1[["DOM: Belowground Slow"]][fc] - s0[["DOM: Belowground Slow"]][fc])) < 1e-6)
expect("non-forest cells keep multiplier 1", all(mult[setdiff(which(!is.na(Sv)), fc)] == 1))
cat(sprintf("starting forest live carbon: %.0f -> %.0f Mg C (x %.3f)\n", sum(L0[fc]), sum(L1[fc]), sum(L1[fc]) / sum(L0[fc])))
gr <- function(r) as.data.table(datasheet(r, "stsim_OutputFlow", lookupsAsFactors = FALSE))[FlowGroupId == "Net Growth Forest: Total", .(g = sum(Amount)), by = Timestep]
g <- merge(gr(RH$off), gr(RH$on), by = "Timestep", suffixes = c("_off", "_on")); g[, ratio := g_on / g_off]; print(g)
wm <- sum(L0[fc] * mult[fc]) / sum(L0[fc])
expect("historical forest growth changes by about the live-carbon-weighted mean multiplier (within 5%; the runs draw disturbance at random)", g[, all(abs(ratio / wm - 1) < 0.05)], sprintf("weighted mean multiplier %.3f", wm))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
