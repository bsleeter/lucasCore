# =============================================================================
# phaseT-fire-bp.R - fire method 2 (burn probability) through ST-Sim: a short projection from an existing Projection Setup
# =============================================================================
# On the phaseO library: a --years projection from Projection Setup result 58 (build 47, historical 49) with Fire Options set to
# method 2, ignitions from the burn probability or FPA-FOD density. Prints the stage 9 fire lines, the initiation multiplier row and
# the burned area by year against the historical run's drawn years.
# Usage: Rscript tests/phaseT-fire-bp.R [--setup=58] [--historical=49] [--years=3] [--ignitions=FPA-FOD|Burn]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
sid <- as.integer(opt("setup", 58)); hid <- as.integer(opt("historical", 49)); YRS <- opt("years", "3"); ign <- opt("ignitions", "FPA-FOD")
L <- ssimLibrary(f)
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
out <- system2(RS, c("F:/lucasCore/tools/new-projection.R", shQuote(f), shQuote(c(sprintf("--historical=%d", hid), "--stage9", sprintf("--build=%d", sid), sprintf("--years=%s", YRS),
               "--replace", sprintf("--name=Projection (fire BP, %s ignitions)", ign)))), stdout = TRUE, stderr = TRUE)
pid <- as.integer(tail(out[!grepl("Warning|undetermined|^In ssimLibrary", out)], 1)); if (is.na(pid)) { cat(out, sep = "\n"); stop("new-projection.R failed") }
S <- scenario(L, pid)
saveDatasheet(S, data.frame(FireMethod = "Burn probability", IgnitionSource = if (ign == "Burn") "Burn probability" else "FPA-FOD ignition density"), "lucasCore_FireOptions")
t0 <- Sys.time(); R <- tryCatch(run(S), error = function(e) NULL)
if (is.null(R)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & ParentId == pid]; cat(tail(logl(scenario(L, max(r$ScenarioId))), 40), sep = "\n"); stop("run failed") }
cat(sprintf("projection took %.1f min (result %d)\n", as.numeric(Sys.time() - t0, units = "mins"), scenarioId(R)))
lg <- logl(R); cat(unique(lg[grepl("^Fire|fire|rror", lg)]), sep = "\n")
print(ds(R, "stsim_TransitionSpatialInitiationMultiplier"))
y0 <- max(ds(R, "stsim_OutputStock")$Timestep) - as.integer(YRS)
tr <- ds(R, "stsim_OutputStratumTransition")[Timestep > y0 & grepl("^Fire", TransitionGroupId) & grepl("[Type]", TransitionGroupId, fixed = TRUE), .(ha = sum(Amount)), by = Timestep]
sch <- ds(R, "lucasCore_OutputProjectionSchedule")[SamplingSet == "Fire" & Iteration == 1 & Timestep > y0]
h <- ds(scenario(L, hid), "stsim_OutputStratumTransition")[grepl("^Fire", TransitionGroupId) & grepl("[Type]", TransitionGroupId, fixed = TRUE), .(hist_ha = sum(Amount)), by = .(HistoricalYear = Timestep)]
cat("\nburned (ha): projection vs the historical run in the drawn year\n"); print(merge(merge(sch[, .(Timestep, HistoricalYear)], tr, all.x = TRUE), h, by = "HistoricalYear", all.x = TRUE)[order(Timestep)])
cat(sprintf("PHASE T DONE projection %d\n", scenarioId(R)))
