# =============================================================================
# phaseU-fire-c2f.R - fire method 3 (lucasFireC2F seasons, one-way) through ST-Sim: a short projection from a Projection Setup
# =============================================================================
# On the phaseO library: a --years projection from Projection Setup result 58 with Fire Options method 3 drawing seasons of the
# Sierra Nevada & Foothills four-zone merge (result 82: 2,500 seasons, 150 m). Prints the stage 9 fire lines, the drawn seasons and
# the burned area by severity and year; checks that the fire group's size distribution is gone.
# Usage: Rscript tests/phaseU-fire-c2f.R [--setup=58] [--historical=49] [--years=5]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
sid <- as.integer(opt("setup", 58)); hid <- as.integer(opt("historical", 49)); YRS <- opt("years", "5")
C2F <- "F:/lucas-master/Models/lucasFireC2F Dev/lucasFireC2F Sierra Nevada & Foothills.ssim"
L <- ssimLibrary(f)
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
out <- system2(RS, c("F:/lucasCore/tools/new-projection.R", shQuote(f), shQuote(c(sprintf("--historical=%d", hid), sprintf("--build=%d", sid), sprintf("--years=%s", YRS),
               "--replace", "--name=Projection (fire C2F seasons)"))), stdout = TRUE, stderr = TRUE)
pid <- as.integer(tail(out[!grepl("Warning|undetermined|^In ssimLibrary", out)], 1)); if (is.na(pid)) { cat(out, sep = "\n"); stop("new-projection.R failed") }
S <- scenario(L, pid)
saveDatasheet(S, data.frame(FireMethod = "lucasFireC2F seasons", C2FLibrary = C2F, C2FScenarioId = 82L), "lucasCore_FireOptions")
t0 <- Sys.time(); R <- tryCatch(run(S), error = function(e) NULL)
if (is.null(R)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & ParentId == pid]; cat(tail(logl(scenario(L, max(r$ScenarioId))), 40), sep = "\n"); stop("run failed") }
cat(sprintf("projection took %.1f min (result %d)\n", as.numeric(Sys.time() - t0, units = "mins"), scenarioId(R)))
lg <- logl(R); cat(unique(lg[grepl("^Fire|C2F|rror", lg)]), sep = "\n")
print(ds(R, "stsim_TransitionSizeDistribution")[, .N, by = TransitionGroupId])
y0 <- max(ds(R, "stsim_OutputStock")$Timestep) - as.integer(YRS)
sch <- ds(R, "lucasCore_OutputProjectionSchedule")[SamplingSet == "Fire" & Iteration == 1 & Timestep > y0, .(Timestep, Season = HistoricalYear)]
tr <- ds(R, "stsim_OutputStratumTransition")[Timestep > y0 & grepl("^Fire", TransitionGroupId) & grepl("[Type]", TransitionGroupId, fixed = TRUE), .(ha = sum(Amount)), by = .(Timestep, TransitionGroupId)]
cat("\nburned (ha) by severity and year, with the C2F season drawn:\n"); print(merge(sch, dcast(tr, Timestep ~ TransitionGroupId, value.var = "ha"), by = "Timestep", all.x = TRUE))
cat(sprintf("PHASE U DONE projection %d\n", scenarioId(R)))
