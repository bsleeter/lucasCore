# =============================================================================
# phaseV-standalone-projections.R - projections as ST-Sim-only scenarios on a Projection Setup that made the hand-over
# =============================================================================
# On the phaseO library: a Projection Setup on Build result 47 with --historical=49 (the hand-over) and --method=None (no stage 10 fit,
# so the setup is quick), then two ST-Sim-only projections from it run side by side (library multiprocessing, multi-scenario on).
# Checks: the setup's initial conditions are the historical run's 2023 maps, each projection's pipeline is ST-Sim alone, both run, and
# the first projection year's carbon starts where the historical run ended.
# Usage: Rscript tests/phaseV-standalone-projections.R [--build=47] [--historical=49] [--years=3]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"; CON <- "C:/Program Files/SyncroSim/SyncroSim.Console.exe"
bid <- as.integer(opt("build", 47)); hid <- as.integer(opt("historical", 49)); YRS <- opt("years", "3")
L <- ssimLibrary(f)
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
tool <- function(script, args) { out <- system2(RS, c(file.path("F:/lucasCore/tools", script), shQuote(f), shQuote(args)), stdout = TRUE, stderr = TRUE)
  out <- out[!grepl("Warning|undetermined|^In ssimLibrary|row names|short variable", out)]; cat(out, sep = "\n"); id <- as.integer(tail(out, 1)); if (is.na(id)) stop(script, " failed"); id }
latest <- function(p) { s <- as.data.table(scenario(L, summary = TRUE)); r <- s[IsResult == "Yes" & ParentId == p, ScenarioId]; if (length(r)) max(r) else NA_integer_ }
failed <- function(r) any(grepl("\\[Failure\\]", runLog(scenario(L, r))))

sid <- tool("new-projection-setup.R", c(sprintf("--build=%d", bid), sprintf("--historical=%d", hid), "--method=None", "--name=Projection Setup (hand-over test)", "--replace"))
saveDatasheet(scenario(L, sid), data.frame(Iterations = 2L, HistoricalTypeShares = TRUE), "lucasCore_ProjectionOptions")
t0 <- Sys.time(); R1 <- run(scenario(L, sid)); cat(sprintf("setup took %.1f min (result %d)\n", as.numeric(Sys.time() - t0, units = "mins"), scenarioId(R1)))
ic <- ds(R1, "stsim_InitialConditionsSpatial"); cat("setup initial conditions:", ic$StateClassFileName, ic$AgeFileName, "\n")
p1 <- tool("new-projection.R", c(sprintf("--build=%d", scenarioId(R1)), sprintf("--years=%s", YRS), "--replace", "--name=Stand-alone projection A"))
p2 <- tool("new-projection.R", c(sprintf("--build=%d", scenarioId(R1)), sprintf("--years=%s", YRS), "--iterations=1", "--replace", "--name=Stand-alone projection B"))
for (p in c(p1, p2)) cat(p, "pipeline:", paste(levels(datasheet(scenario(L, p), "core_Pipeline", lookupsAsFactors = TRUE)$StageNameId)[datasheet(scenario(L, p), "core_Pipeline")$StageNameId], collapse = " > "), "\n")
# both at once: multi-scenario multiprocessing
saveDatasheet(L, data.frame(EnableMultiprocessing = TRUE, MaximumJobs = 3L, EnableMultiScenario = TRUE), "core_Multiprocessing")
t0 <- Sys.time(); system(sprintf('"%s" --run --lib="%s" --sids=%d,%d', CON, f, p1, p2), intern = FALSE, ignore.stdout = TRUE)
saveDatasheet(L, data.frame(EnableMultiprocessing = FALSE, MaximumJobs = 1L, EnableMultiScenario = FALSE), "core_Multiprocessing")
cat(sprintf("two projections at once took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
y1 <- max(ds(scenario(L, hid), "stsim_OutputStock")$Timestep)
h_end <- ds(scenario(L, hid), "stsim_OutputStock")[Timestep == y1, sum(Amount)]
for (p in c(p1, p2)) { r <- latest(p); if (is.na(r)) { cat(p, ": no result\n"); next }
  st <- ds(scenario(L, r), "stsim_OutputStock")
  cat(sprintf("projection %d -> result %d: %s; iterations %d; carbon %d %.2f Tg (historical run %.2f Tg)\n", p, r, if (failed(r)) "FAILS" else "RUNS",
              uniqueN(st$Iteration), y1, st[Timestep == y1 & Iteration == 1, sum(Amount)] / 1e6 * 100 / 100, h_end / 1e6)) }
cat("PHASE V DONE\n")
