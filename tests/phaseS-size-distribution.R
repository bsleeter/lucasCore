# =============================================================================
# phaseS-size-distribution.R - a Transition Size Distribution through ST-Sim: Clearcut forced On, a short projection
# =============================================================================
# On the phaseO library (Build result 47 with LCMS harvest, historical run 49): a Fitted Projection Setup (P26 at 30 m, agriculture on
# Placer and its valley neighbours) whose Clearcut row has Size Distribution On, then a --years projection. Checks that Historical
# Patch Sizes is written for every group, that the size distribution and prioritization reach ST-Sim for Clearcut only, and that the
# projected clearcut area still meets its target.
# Usage: Rscript tests/phaseS-size-distribution.R [--build=47] [--historical=49] [--years=3]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
bid <- as.integer(opt("build", 47)); hid <- as.integer(opt("historical", 49)); YRS <- opt("years", "3")
L <- ssimLibrary(f)
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
runit <- function(id) { t0 <- Sys.time(); R <- tryCatch(run(scenario(L, id)), error = function(e) NULL)
  if (is.null(R)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & ParentId == id]; if (nrow(r)) cat(tail(logl(scenario(L, max(r$ScenarioId))), 60), sep = "\n"); stop("run failed: ", id) }
  cat(sprintf("%s took %.1f min (result %d)\n", name(scenario(L, id)), as.numeric(Sys.time() - t0, units = "mins"), scenarioId(R))); R }
tool <- function(script, args) { out <- system2(RS, c(file.path("F:/lucasCore/tools", script), shQuote(f), shQuote(args)), stdout = TRUE, stderr = TRUE)
  out <- out[!grepl("Warning|undetermined|^In ssimLibrary|row names|short variable", out)]; cat(out, sep = "\n"); id <- as.integer(tail(out, 1)); if (is.na(id)) stop(script, " failed"); id }

sid <- tool("new-projection-setup.R", c(sprintf("--build=%d", bid), "--method=Fitted", "--name=Projection Setup (size distribution)", "--replace", "--region=Pyrome: P26 Northern Sierra Nevada", "--resolution=30"))
S <- scenario(L, sid); saveDatasheet(S, data.frame(Iterations = 1L), "lucasCore_ProjectionOptions")
AGR <- c("County: Placer California", "County: Sutter California", "County: Yuba California", "County: Sacramento California")
saveDatasheet(S, data.frame(UnitId = c("Pyrome: P26 Northern Sierra Nevada", rep(AGR, 2)), Surface = c(NA, rep(c("Ag Expansion", "Ag Contraction"), each = length(AGR)))), "lucasCore_SuitabilityRegion")
al <- as.data.frame(datasheet(S, "lucasCore_ProjectionAllocation", lookupsAsFactors = TRUE)); for (k in names(al)) if (is.factor(al[[k]])) al[[k]] <- as.character(al[[k]])
al <- al[, setdiff(names(al), c("ProjectionAllocationId", "ScenarioId"))]; al$SizeDistribution <- ifelse(al$Surface == "Clearcut", "On", "Auto")
saveDatasheet(S, al, "lucasCore_ProjectionAllocation")
RS1 <- runit(sid)
cat(unique(logl(RS1)[grepl("size distribution|rror", logl(RS1))]), sep = "\n")
cat("\nHistorical Patch Sizes:\n"); print(ds(RS1, "lucasCore_OutputPatchSize"), nrows = 100)
cat("\nST-Sim size distribution / prioritization:\n"); print(ds(RS1, "stsim_TransitionSizeDistribution")); print(ds(RS1, "stsim_TransitionSizePrioritization"))
pid <- tool("new-projection.R", c(sprintf("--historical=%d", hid), "--stage9", sprintf("--build=%d", scenarioId(RS1)), sprintf("--years=%s", YRS), "--replace", "--name=Projection (size distribution)"))
RP <- runit(pid)
y0 <- max(ds(RP, "stsim_OutputStock")$Timestep) - as.integer(YRS)
tt <- ds(RP, "stsim_TransitionTarget")[Timestep > y0 & grepl("^Forest Harvest", TransitionGroupId), .(Target = sum(Amount)), by = .(Timestep, TransitionGroupId)]
tr <- ds(RP, "stsim_OutputStratumTransition")[Timestep > y0 & grepl("^Forest Harvest", TransitionGroupId) & grepl("[Type]", TransitionGroupId, fixed = TRUE), .(Done = sum(Amount)), by = .(Timestep, TransitionGroupId)]
cat("\nharvest target vs done (ha):\n"); print(merge(tt, tr, all = TRUE, by = c("Timestep", "TransitionGroupId")))
cat(sprintf("PHASE S DONE setup %d projection %d\n", scenarioId(RS1), scenarioId(RP)))
