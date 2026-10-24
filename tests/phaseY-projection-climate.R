# =============================================================================
# phaseY-projection-climate.R - the projection chain with the climate split out: Build -> Climate (stage 11) -> Setup -> Projections
# =============================================================================
# On the library tests/phaseX-studio-library.R made (a Studio-style library, a Build of 1985-1990 and its historical run):
# 1. a Projection Climate scenario on the Build result (LOCA2 SSP2-4.5 ACCESS-CM2, to 2000): stage 11 writes 1991-2000 multipliers
# 2. a Projection Setup with the hand-over from the historical run and the end year in Run Settings (--end=2000; method None: quick)
# 3. two 5-year projections on the setup, with and without --climate: both run; the climate one depends on the climate result first,
#    gets its multipliers, and its growth flows differ from the normal-climate one
# Usage: Rscript tests/phaseY-projection-climate.R [--scenario=SSP2-4.5] [--model=ACCESS-CM2]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-studio-library.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
tool <- function(script, args) { out <- system2(RS, c(file.path("F:/lucasCore/tools", script), shQuote(f), shQuote(args)), stdout = TRUE, stderr = TRUE)
  out <- out[!grepl("Warning|undetermined|^In ssimLibrary|row names|short variable", out)]; cat(grep("created|note|scenario '", out, value = TRUE), sep = "\n")
  id <- as.integer(tail(out, 1)); if (is.na(id)) { cat(out, sep = "\n"); stop(script, " failed") }; id }
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
L <- ssimLibrary(f); sc <- as.data.table(scenario(L, summary = TRUE))
bid <- max(sc[IsResult == "Yes" & grepl("Build", Name, fixed = TRUE), ScenarioId]); hid <- max(sc[IsResult == "Yes" & grepl("Historical", Name), ScenarioId])
cat("Build result", bid, "; historical result", hid, "\n")

# ---- 1. Projection Climate ---------------------------------------------------------------------------------------------
cid <- tool("new-projection-climate.R", c(sprintf("--build=%d", bid), sprintf("--scenario=%s", opt("scenario", "SSP2-4.5")), sprintf("--model=%s", opt("model", "ACCESS-CM2")), "--last=2000", "--replace"))
t0 <- Sys.time(); RC <- run(scenario(L, cid)); cat(sprintf("climate took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- logl(RC); cat(unique(lg[grepl("Projection climate|Join|projection: mean|Failure|FAIL", lg)]), sep = "\n")
fsm <- as.data.table(datasheet(RC, "stsim_FlowSpatialMultiplier", lookupsAsFactors = FALSE))
cs <- as.data.table(datasheet(RC, "lucasCore_OutputClimateSummary", lookupsAsFactors = FALSE))
cat(sprintf("climate result: %d multiplier rows, years %d-%d; summary %d rows (%s)\n", nrow(fsm), min(fsm$Timestep), max(fsm$Timestep), nrow(cs), paste(unique(cs$Climate), collapse = ", ")))
v <- as.data.table(datasheet(RC, "lucasCore_OutputValidation")); clim_ok <- nrow(fsm) > 0 && min(fsm$Timestep) == 1991 && max(fsm$Timestep) == 2001 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))

# ---- 2. Projection Setup (end year in Run Settings) ---------------------------------------------------------------------
sid <- tool("new-projection-setup.R", c(sprintf("--build=%d", bid), sprintf("--historical=%d", hid), "--method=None", "--end=2000", "--name=Projection Setup (phaseY)", "--replace"))
saveDatasheet(scenario(L, sid), data.frame(ProjectionEndYear = 2000L, Iterations = 1L), "lucasCore_ProjectionOptions")
t0 <- Sys.time(); RS9 <- run(scenario(L, sid)); cat(sprintf("setup took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- logl(RS9); cat(unique(lg[grepl("^Projection [0-9]|Failure|FAIL", lg)]), sep = "\n")
ps <- as.data.table(datasheet(RS9, "lucasCore_OutputProjectionSchedule")); setup_ok <- nrow(ps) > 0 && max(ps$Timestep) == 2000 && !any(grepl("[Failure]", lg, fixed = TRUE))
cat(sprintf("setup: schedule %d rows, years %d-%d\n", nrow(ps), min(ps$Timestep), max(ps$Timestep)))

# ---- 3. projections with and without the climate result ------------------------------------------------------------------
p1 <- tool("new-projection.R", c(sprintf("--build=%d", scenarioId(RS9)), sprintf("--climate=%d", scenarioId(RC)), "--years=5", "--name=Projection climate (phaseY)", "--replace"))
p0 <- tool("new-projection.R", c(sprintf("--build=%d", scenarioId(RS9)), "--years=5", "--name=Projection normal climate (phaseY)", "--replace"))
print(dependency(scenario(L, p1))[, c("ScenarioId", "Name")])
R1 <- run(scenario(L, p1)); R0 <- run(scenario(L, p0))
flows <- function(R) { x <- as.data.table(datasheet(R, "stsim_OutputFlow", lookupsAsFactors = FALSE)); x[grepl("Growth", FlowGroupId), .(Amount = sum(Amount)), by = Timestep][order(Timestep)] }
g1 <- flows(R1); g0 <- flows(R0); cmp <- merge(g1, g0, by = "Timestep", suffixes = c(".climate", ".normal")); print(cmp)
m1 <- as.data.table(datasheet(R1, "stsim_FlowSpatialMultiplier", lookupsAsFactors = FALSE))
proj_ok <- nrow(g1) > 0 && nrow(g0) > 0 && nrow(m1) > 0 && min(m1$Timestep) == 1991 && any(abs(cmp$Amount.climate - cmp$Amount.normal) > 1e-6 * abs(cmp$Amount.normal)) &&
  !any(grepl("[Failure]", c(logl(R1), logl(R0)), fixed = TRUE))
cat(sprintf("climate %s, setup %s, projections %s\n", if (clim_ok) "OK" else "FAILED", if (setup_ok) "OK" else "FAILED", if (proj_ok) "OK" else "FAILED"))
cat(if (clim_ok && setup_ok && proj_ok) "PROJECTION CLIMATE OK\n" else "PROJECTION CLIMATE FAILED\n")
