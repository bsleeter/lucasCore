# =============================================================================
# phaseR-lcms-projection.R - the Placer test chain with LCMS harvest: Build, historical run, Projection Setup, 10-year projection
# =============================================================================
# On the phaseO library (dev/libs/lucasCore-suitability.ssim): reruns its Build scenario (stage 6 now takes clearcut and selection from
# LCMS Tree Removal), makes a historical-only run on the new result, a Fitted Projection Setup (P26 pyrome, 30 m, default allocation)
# and a --years projection from it. Compares harvest per year: historical (old build 5 vs new), and projected (old projection 46 vs new).
# Usage: Rscript tests/phaseR-lcms-projection.R [--years=10] [--old-build=5] [--old-projection=46]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
YRS <- opt("years", "10"); ob <- as.integer(opt("old-build", 5)); op <- as.integer(opt("old-projection", 46))
L <- ssimLibrary(f); sc <- as.data.table(scenario(L, summary = TRUE))
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
runit <- function(id) { t0 <- Sys.time(); R <- tryCatch(run(scenario(L, id)), error = function(e) NULL)
  if (is.null(R)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & ParentId == id]; if (nrow(r)) cat(tail(logl(scenario(L, max(r$ScenarioId))), 60), sep = "\n"); stop("run failed: ", id) }
  cat(sprintf("%s took %.1f min (result %d)\n", name(scenario(L, id)), as.numeric(Sys.time() - t0, units = "mins"), scenarioId(R))); R }
tool <- function(script, args) { out <- system2(RS, c(file.path("F:/lucasCore/tools", script), shQuote(f), shQuote(args)), stdout = TRUE, stderr = TRUE)
  out <- out[!grepl("Warning|undetermined|^In ssimLibrary|row names|short variable", out)]; cat(out, sep = "\n"); id <- as.integer(tail(out, 1)); if (is.na(id)) stop(script, " failed"); id }

# 1. the Build again (same settings), now with LCMS harvest in stage 6 (--build=<id> --historical=<id> resume after steps 1-2)
bid <- as.integer(opt("build", NA)); hid <- as.integer(opt("historical", NA))
if (is.na(bid)) { B <- runit(sc[Name == "Build" & IsResult == "No", ScenarioId]); bid <- scenarioId(B)
  cat(unique(logl(B)[grepl("Forest Harvest|Clearcut minimum|LCMS", logl(B))]), sep = "\n") }
# 2. historical run, 3. setup, 4. projection
if (is.na(hid)) hid <- scenarioId(runit(tool("new-historical.R", c(sprintf("--build=%d", bid), "--historical-only", "--bookend-maps", "--iterations=1", "--replace", "--name=Historical (LCMS harvest)"))))
sid <- tool("new-projection-setup.R", c(sprintf("--build=%d", bid), "--method=Fitted", "--name=Projection Setup (LCMS harvest)", "--replace", "--region=Pyrome: P26 Northern Sierra Nevada", "--resolution=30"))
saveDatasheet(scenario(L, sid), data.frame(Iterations = 2L), "lucasCore_ProjectionOptions")
# the agriculture surfaces fit where there is agriculture: Placer and its valley neighbours (P26 holds 54 km2 of agriculture)
AGR <- c("County: Placer California", "County: Sutter California", "County: Yuba California", "County: Sacramento California")
saveDatasheet(scenario(L, sid), data.frame(UnitId = c("Pyrome: P26 Northern Sierra Nevada", rep(AGR, 2)), Surface = c(NA, rep(c("Ag Expansion", "Ag Contraction"), each = length(AGR)))),
              "lucasCore_SuitabilityRegion")
RS1 <- runit(sid)
cat(unique(logl(RS1)[grepl("Fitting region of|events \\(|out of sample|flicker|size distribution|one model cell|rror", logl(RS1))]), sep = "\n")
pid <- tool("new-projection.R", c(sprintf("--historical=%d", hid), sprintf("--build=%d", scenarioId(RS1)), sprintf("--years=%s", YRS), "--replace", "--name=Projection (LCMS harvest)"))
RP <- runit(pid)

# harvest per year (km2): historical runs and projections, old vs new
km2 <- function(R, yrs) { x <- ds(R, "stsim_OutputStratumTransition")[Timestep %in% yrs & grepl("^Forest Harvest", TransitionGroupId) & grepl("\\[Type\\]", TransitionGroupId)]
  x[, .(km2_per_yr = round(sum(Amount) / 100 / length(yrs) / uniqueN(Iteration), 2)), by = TransitionGroupId] }
old_h <- as.data.table(dependency(scenario(L, op)))
cat("\nhistorical harvest (km2/yr, 1986-2023): stage 6 maps of the builds\n")
st6 <- function(id) ds(scenario(L, id), "lucasCore_OutputTransitionSummary")[grepl("^Forest Harvest", TransitionGroup), .(km2_per_yr = round(sum(Area) / 38, 2)), by = .(TransitionGroup, Source)]
print(rbind(cbind(Build = ob, st6(ob)), cbind(Build = bid, st6(bid))))
y0 <- max(ds(RP, "stsim_OutputStock")$Timestep) - as.integer(YRS)
cat(sprintf("\nprojected harvest (km2/yr, %d-%d, both iterations): old projection %d vs new %d\n", y0 + 1, y0 + as.integer(YRS), op, scenarioId(RP)))
print(merge(km2(scenario(L, op), (y0 + 1):(y0 + as.integer(YRS))), km2(RP, (y0 + 1):(y0 + as.integer(YRS))), by = "TransitionGroupId", suffixes = c("_old", "_new"), all = TRUE))
cat("\nhistorical run harvest (km2/yr, 1986-2023, ST-Sim):\n"); print(km2(scenario(L, hid), 1986:2023))
cat(sprintf("PHASE R DONE build %d historical %d setup %d projection %d\n", bid, hid, scenarioId(RS1), scenarioId(RP)))
ag <- function(R, yrs) { x <- ds(R, "stsim_OutputStratumTransition")[Timestep %in% yrs & grepl("^Ag (Expansion|Contraction)", TransitionGroupId) & grepl("[Type]", TransitionGroupId, fixed = TRUE)]
  x[, .(km2_per_yr = round(sum(Amount) / 100 / length(yrs) / uniqueN(Iteration), 2)), by = .(Group = sub(":.*| Cropland.*| Pasture.*", "", TransitionGroupId))] }
cat("\nagriculture change (km2/yr): historical run vs projection\n"); print(merge(ag(scenario(L, hid), 1986:2023), ag(RP, (y0 + 1):(y0 + as.integer(YRS))), by = "Group", suffixes = c("_hist", "_proj"), all = TRUE))
