# =============================================================================
# phaseO-suitability.R - stage 10: Projection Setup with Fitted and Rules surfaces, and short projections from a historical run
# =============================================================================
# A fresh starter copy (dev/libs/lucasCore-suitability.ssim): the Build for Placer County at 1 km with a projection to 2050 (curves
# copied from the phaseJ library), a historical-only run, then two Projection Setups - Fitted on the P26 pyrome at 30 m (the small
# study area / larger fitting region case) and Rules (the old WUI x PAD weights) - and a --years projection from each. Compares where
# projected urbanization lands: the share on each 1985 land cover group and the mean surface value of the cells developed.
# Usage: Rscript tests/phaseO-suitability.R [--years=10] [--resolution=30] [--build=<id> --historical=<id>]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
YRS <- opt("years", "10"); RES <- opt("resolution", "30"); bid <- as.integer(opt("build", NA)); hid <- as.integer(opt("historical", NA))
if (is.na(bid)) { unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE); file.copy("F:/lucasCore/Starter/LUCAS Core (CONUS).ssim", f) }
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE))
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
mins <- function(t0) as.numeric(Sys.time() - t0, units = "mins")
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
runit <- function(id) { t0 <- Sys.time(); R <- tryCatch(run(scenario(L, id)), error = function(e) NULL)
  if (is.null(R)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & ParentId == id]; if (nrow(r)) cat(tail(logl(scenario(L, max(r$ScenarioId))), 50), sep = "\n"); stop("run failed: ", id) }
  cat(sprintf("%s took %.1f min (result %d)\n", name(scenario(L, id)), mins(t0), scenarioId(R))); R }
tool <- function(script, args) { out <- system2(RS, c(file.path("F:/lucasCore/tools", script), shQuote(f), shQuote(args)), stdout = TRUE, stderr = TRUE)
  out <- out[!grepl("Warning|undetermined|^In ssimLibrary", out)]; cat(out, sep = "\n"); id <- as.integer(tail(out, 1)); if (is.na(id)) stop(script, " failed"); id }

if (is.na(bid)) {
  B <- scenario(L, sc[Name == "Build", ScenarioId])
  g <- as.data.frame(datasheet(B, "lucasCore_GrowthOptions")); g$CurveSource <- "Copy from another library"; g$CurveLibrary <- "F:/lucasCore/dev/libs/lucasCore-forest-map.ssim"; g$CurveScenarioId <- 4L
  saveDatasheet(B, g, "lucasCore_GrowthOptions"); saveDatasheet(B, data.frame(UnitId = "County: Placer California"), "lucasCore_StudyArea")
  bo <- as.data.frame(datasheet(B, "lucasCore_BuildOptions")); bo$ProjectionEndYear <- 2050L; saveDatasheet(B, bo, "lucasCore_BuildOptions")
  cs <- as.data.table(datasheet(P, "lucasCore_ClimateScenario", includeKey = TRUE)); cm <- as.data.table(datasheet(P, "lucasCore_ClimateModel", includeKey = TRUE))
  co <- as.data.frame(datasheet(B, "lucasCore_ClimateOptions")); co$ClimateScenarioId <- cs[Name == "SSP2-4.5", ClimateScenarioId]; co$ClimateModelId <- cm[Name == "CanESM5", ClimateModelId]
  saveDatasheet(B, co, "lucasCore_ClimateOptions"); saveDatasheet(B, data.frame(Iterations = 2L), "lucasCore_ProjectionOptions")
  description(B) <- paste(description(B), "[tests/phaseO-suitability.R: Placer County, 1 km, projection to 2050, LOCA2 SSP2-4.5 CanESM5, 2 iterations; curves copied from lucasCore-forest-map.ssim result 4.]")
  bid <- scenarioId(runit(sc[Name == "Build", ScenarioId]))
}
if (is.na(hid)) hid <- scenarioId(runit(tool("new-historical.R", c(sprintf("--build=%d", bid), "--historical-only", "--bookend-maps", "--iterations=1", "--replace"))))

res <- list()
for (me in c("Fitted", "Rules")) {
  args <- c(sprintf("--build=%d", bid), sprintf("--method=%s", me), sprintf("--name=Projection Setup (%s)", me), "--replace", sprintf("--resolution=%s", RES))
  if (me == "Fitted") args <- c(args, "--region=Pyrome: P26 Northern Sierra Nevada")
  RS1 <- runit(tool("new-projection-setup.R", args)); lg <- logl(RS1)
  cat(unique(lg[grepl("^Fitting|Covariates|events|out of sample|Adjacency|Projection Allocation|rror|FAIL", lg)]), sep = "\n")
  print(ds(RS1, "lucasCore_OutputSuitability")[, .(Surface, Item, Value = round(Value, 3))])
  RP <- runit(tool("new-projection.R", c(sprintf("--historical=%d", hid), "--stage9", sprintf("--build=%d", scenarioId(RS1)), sprintf("--years=%s", YRS), "--replace", sprintf("--name=Projection from setup (%s)", me))))
  # where projected urbanization (Low-High) went: the 1985 land cover of the cells and their surface value
  D <- file.path(paste0(f, ".data"), sprintf("Scenario-%d", scenarioId(RP)))
  y0 <- max(ds(RH <- scenario(L, hid), "stsim_OutputStock")$Timestep); y9 <- max(ds(RP, "stsim_OutputStock")$Timestep)
  s0 <- rast(file.path(D, "stsim_OutputSpatialState", sprintf("sc.it1.ts%d.tif", y0))); s9 <- rast(file.path(D, "stsim_OutputSpatialState", sprintf("sc.it1.ts%d.tif", y9)))
  scl <- as.data.table(datasheet(P, "stsim_StateClass", includeKey = TRUE)); devid <- scl[grepl("^Developed", Name), StateClassId]
  newdev <- !(values(s0, mat = FALSE) %in% devid) & values(s9, mat = FALSE) %in% devid
  grp <- sub(":.*", "", scl$Name[match(values(s0, mat = FALSE)[which(newdev)], scl$StateClassId)])
  surf <- ds(RS1, "lucasCore_OutputSuitabilityMap"); sv <- values(rast(surf$FileName[surf$Surface == "Urbanization"]), mat = FALSE)
  res[[me]] <- data.table(Method = me, NewDeveloped_km2 = sum(newdev), Forest = mean(grp == "Forest"), Grassland = mean(grp == "Grassland"), Shrubland = mean(grp == "Shrubland"),
                          Agriculture = mean(grp == "Agriculture"), MeanSurfaceOfNew = mean(sv[newdev], na.rm = TRUE), MeanSurfaceOfLand = mean(sv[!is.na(sv) & sv > 0]))
}
cat(sprintf("\nwhere projected development went (%s years, iteration 1; shares of newly developed 1 km cells by their %d class):\n", YRS, y0)); print(rbindlist(res), digits = 3)
saveRDS(list(res = res, build = bid, historical = hid), "F:/lucasCore/dev/libs/test-suitability.rds")
cat("SUITABILITY DONE build", bid, "historical", hid, "\n")
