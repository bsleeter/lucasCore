# =============================================================================
# phaseZ22-site-productivity-projection.R - to-do 35: stage 11 carries the Build's Site Productivity multiplier into projections (2026-10-30)
# =============================================================================
# On the test library lucasCore-suitability.ssim, after tests/phaseZ20-site-productivity-build.R (its on and off test Builds):
# 1. a Projection Climate scenario on each test Build (tools/new-projection-climate.R, LOCA2 SSP2-4.5 ACCESS-CM2, to 2030; dependencies
#    the test Build, then Build 47 for stage 1)
# 2. a 3-year projection on each (tools/new-projection.R on Projection Setup (hand-over test), result 122 on Build 47, with --climate), so the two
#    differ only in the climate result they depend on
# Checks: stage 11's checks pass; on: its climate rows typed Climate and one Site Productivity row whose map is in the climate result's
# own folder and equals the Build's; off: no Site Productivity row; the on projection's forest growth / the off one's is about the
# Build's forest-area mean multiplier.
# Usage: Rscript tests/phaseZ22-site-productivity-projection.R      (REUSE=1 reuses each run that already exists)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"; SETUP <- 122L
L <- suppressWarnings(ssimLibrary(f)); ok <- TRUE; reuse <- Sys.getenv("REUSE") == "1"
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
tool <- function(script, args) { out <- system2(RS, c(file.path("F:/lucasCore/tools", script), shQuote(f), shQuote(args)), stdout = TRUE, stderr = TRUE)
  id <- suppressWarnings(as.integer(tail(out, 1))); if (is.na(id)) { cat(out, sep = "\n"); stop(script, " failed") }; id }
sc <- function() as.data.table(scenario(L, summary = TRUE))
newest <- function(nm) { s <- sc()[IsResult == "Yes" & (Name == nm | startsWith(Name, paste0(nm, " ([")))]; if (nrow(s)) max(s$ScenarioId) else NA_integer_ }
dd <- function(id, sh) file.path(paste0(f, ".data"), paste0("Scenario-", id), sh)
B <- c(on = newest("Build test (site productivity)"), off = newest("Build test (site productivity off)")); print(B)

climate <- function(k) { nm <- sprintf("Projection Climate test (site productivity %s)", k)
  if (reuse && !is.na(id <- newest(nm))) return(scenario(L, id))
  id <- tool("new-projection-climate.R", c(sprintf("--build=%d", B[[k]]), "--scenario=SSP2-4.5", "--model=ACCESS-CM2", "--last=2030", sprintf("--name=%s", nm), "--replace"))
  S <- scenario(L, id); dependency(S) <- unique(c(B[[k]], 47L))
  t0 <- Sys.time(); r <- run(S); cat(sprintf("climate %s: %.1f min\n", k, as.numeric(Sys.time() - t0, units = "mins"))); r }
projection <- function(k, C) { nm <- sprintf("Projection test (site productivity %s)", k)
  if (reuse && !is.na(id <- newest(nm))) return(scenario(L, id))
  id <- tool("new-projection.R", c(sprintf("--build=%d", SETUP), sprintf("--climate=%d", scenarioId(C)), "--years=3", "--iterations=1", sprintf("--name=%s", nm), "--replace"))
  print(dependency(scenario(L, id))[, c("ScenarioId", "Name")])
  t0 <- Sys.time(); r <- run(scenario(L, id)); cat(sprintf("projection %s: %.1f min\n", k, as.numeric(Sys.time() - t0, units = "mins"))); r }
RC <- lapply(c(on = "on", off = "off"), climate)
for (k in names(RC)) { v <- as.data.table(datasheet(RC[[k]], "lucasCore_OutputValidation")); expect(sprintf("climate %s: stage 11 checks pass", k), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", paste(Check, Detail)], collapse = "; ")) }
cat(logs(RC$on, "^Site Productivity|^Projection climate"), sep = "\n")
fsm <- function(id) as.data.table(datasheet(scenario(L, id), "stsim_FlowSpatialMultiplier", lookupsAsFactors = FALSE, optional = TRUE))
m1 <- fsm(scenarioId(RC$on)); m0 <- fsm(scenarioId(RC$off))
expect("on: climate rows typed Climate, one Site Productivity row", m1[FlowMultiplierTypeId == "Site Productivity", .N] == 1 && m1[FlowMultiplierTypeId != "Site Productivity", .N > 0 && all(FlowMultiplierTypeId == "Climate")])
expect("off: no Site Productivity row", !nrow(m0[FlowMultiplierTypeId %in% "Site Productivity"]))
sp <- file.path(dd(scenarioId(RC$on), "stsim_FlowSpatialMultiplier"), basename(m1[FlowMultiplierTypeId == "Site Productivity", MultiplierFileName]))
bm <- fsm(B[["on"]]); bp <- file.path(dd(B[["on"]], "stsim_FlowSpatialMultiplier"), basename(bm[FlowMultiplierTypeId == "Site Productivity", MultiplierFileName]))
a <- values(rast(sp), mat = FALSE); b <- values(rast(bp), mat = FALSE)
expect("on: the Site Productivity map is in the climate result's own folder and equals the Build's", file.exists(sp) && identical(is.na(a), is.na(b)) && max(abs(a - b), na.rm = TRUE) < 1e-6, sp)

RP <- lapply(c(on = "on", off = "off"), function(k) projection(k, RC[[k]]))
pm <- as.data.table(datasheet(RP$on, "stsim_FlowSpatialMultiplier", lookupsAsFactors = FALSE, optional = TRUE))
expect("on projection: its flow multipliers include Site Productivity", nrow(pm) && "Site Productivity" %in% pm$FlowMultiplierTypeId, sprintf("%d rows", nrow(pm)))
gr <- function(r) as.data.table(datasheet(r, "stsim_OutputFlow", lookupsAsFactors = FALSE))[FlowGroupId == "Net Growth Forest: Total", .(g = sum(Amount)), by = Timestep]
g <- merge(gr(RP$off), gr(RP$on), by = "Timestep", suffixes = c("_off", "_on")); g[, ratio := g_on / g_off]; print(g)
ic <- as.data.table(datasheet(scenario(L, B[["on"]]), "stsim_InitialConditionsSpatial", optional = TRUE)); Sv <- values(rast(file.path(dd(B[["on"]], "stsim_InitialConditionsSpatial"), basename(ic$StateClassFileName[1]))), mat = FALSE)
mf <- mean(b[Sv >= 100 & Sv < 1000 & !is.na(b)])
expect("projection forest growth on / off is about the forest mean multiplier (within 5%; disturbance is drawn at random)", nrow(g) > 0 && g[, all(abs(ratio / mf - 1) < 0.05)], sprintf("forest mean multiplier %.3f", mf))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
