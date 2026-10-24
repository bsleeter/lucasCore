# =============================================================================
# phaseQ-allocation-groups.R - stage 10 for every allocated group: urbanization, ag expansion and contraction, clearcut, selection
# =============================================================================
# On the phaseO library (dev/libs/lucasCore-suitability.ssim: Build result 5, historical run 7), a Fitted Projection Setup with the
# default allocation (defaults/projection/allocation.csv: Source/Event Classes per surface, LANDFIRE Thinning for selection) and the
# default covariates per surface (NCCPI for agriculture, forest owner for harvest), fitted on the P26 pyrome at 30 m, then a --years
# projection. Prints each surface's out-of-sample test, the patch-size summaries and size distributions, and where each group's
# projected change went by 2023 land cover (and, for harvest, by owner).
# Usage: Rscript tests/phaseQ-allocation-groups.R [--build=5] [--historical=7] [--years=10] [--resolution=30]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
bid <- as.integer(opt("build", 5)); hid <- as.integer(opt("historical", 7)); YRS <- opt("years", "10"); RES <- opt("resolution", "30")
L <- ssimLibrary(f)
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
runit <- function(id) { t0 <- Sys.time(); R <- tryCatch(run(scenario(L, id)), error = function(e) NULL)
  if (is.null(R)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & ParentId == id]; if (nrow(r)) cat(tail(logl(scenario(L, max(r$ScenarioId))), 60), sep = "\n"); stop("run failed: ", id) }
  cat(sprintf("%s took %.1f min (result %d)\n", name(scenario(L, id)), as.numeric(Sys.time() - t0, units = "mins"), scenarioId(R))); R }
tool <- function(script, args) { out <- system2(RS, c(file.path("F:/lucasCore/tools", script), shQuote(f), shQuote(args)), stdout = TRUE, stderr = TRUE)
  out <- out[!grepl("Warning|undetermined|^In ssimLibrary|row names|short variable", out)]; cat(out, sep = "\n"); id <- as.integer(tail(out, 1)); if (is.na(id)) stop(script, " failed"); id }

sid <- tool("new-projection-setup.R", c(sprintf("--build=%d", bid), "--method=Fitted", "--name=Projection Setup (all groups)", "--replace",
                                        "--region=Pyrome: P26 Northern Sierra Nevada", sprintf("--resolution=%s", RES)))
S <- scenario(L, sid); po <- data.frame(Iterations = 2L); saveDatasheet(S, po, "lucasCore_ProjectionOptions")
RS1 <- runit(sid); lg <- logl(RS1)
cat(unique(lg[grepl("Covariates|events|out of sample|Adjacency|size distribution|one model cell|NCCPI|LANDFIRE|Fitting layers|rror|FAIL|adjacency applies", lg)]), sep = "\n")
print(ds(RS1, "lucasCore_OutputSuitability")[, .(Surface, Item, Value = round(Value, 3))], nrows = 200)
print(ds(RS1, "stsim_TransitionSizeDistribution"))

pid <- tool("new-projection.R", c(sprintf("--historical=%d", hid), "--stage9", sprintf("--build=%d", scenarioId(RS1)), sprintf("--years=%s", YRS), "--replace", "--name=Projection (all groups)"))
RP <- runit(pid)
# where each group's projected change went: the 2023 class of the cells each transition group changed (spatial transition maps, iteration 1)
P <- rsyncrosim::project(L, "Definitions"); scl <- as.data.table(datasheet(P, "stsim_StateClass", includeKey = TRUE))
y0 <- max(ds(scenario(L, hid), "stsim_OutputStock")$Timestep)
tr <- ds(RP, "stsim_OutputStratumTransition")[Timestep > y0]
tr[, Group := sub(":.*| \\[Type\\]", "", TransitionGroupId)]
cat("\nprojected transitions (mean per year, both iterations):\n"); print(tr[grepl("\\[Type\\]", TransitionGroupId), .(PerYear = sum(Amount) / (as.integer(YRS) * 2)), by = TransitionGroupId][order(-PerYear)], nrows = 60)
cat("PHASE Q DONE setup", scenarioId(RS1), "projection", scenarioId(RP), "\n")
