# =============================================================================
# phaseZ28-stage8-deep-soil.R - stage 8 with Deep Soil and emergent wetland starting pools by ecodivision (to-do 39 step 1, 2026-11-06)
# =============================================================================
# On the test library lucasCore-suitability.ssim (Placer County, 1 km; it has no emergent wetland cells): stage 8 alone on Build
# result 47. Checks: stage 8's checks pass; it writes a Deep Soil map, zero on every land cell (forest has no Deep Soil curve column
# and no emergent cell is there); every other pool's map is the Build's own stage 8 map, cell for cell. The emergent values
# themselves are checked in real ST-Sim by dev/nonforest/02-emergent-stsim-check.R.
# Usage: Rscript tests/phaseZ28-stage8-deep-soil.R      (REUSE=1 reuses the run when it exists)
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
f <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim"); L <- suppressWarnings(ssimLibrary(f)); P1 <- rsyncrosim::project(L, 1); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
nm <- "Stage 8 test (Deep Soil)"
s <- as.data.table(scenario(L, summary = TRUE))
R <- if (Sys.getenv("REUSE") == "1" && nrow(s[IsResult == "Yes" & startsWith(Name, paste0(nm, " ([")) ])) scenario(L, max(s[IsResult == "Yes" & startsWith(Name, paste0(nm, " ([")), ScenarioId])) else {
  for (id in s[IsResult == "No" & Name == nm, ScenarioId]) delete(L, scenario = id, force = TRUE)
  S <- scenario(P1, nm, sourceScenario = 2); saveDatasheet(S, data.frame(StageNameId = "8 - Initial Stock Maps", RunOrder = 1L), "core_Pipeline")
  d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, d))
  t0 <- Sys.time(); r <- run(S); cat(sprintf("stage 8: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))); r }
v <- as.data.table(datasheet(R, "lucasCore_OutputValidation")); expect("stage 8 checks pass", nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", paste(Check, Detail)], collapse = "; "))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); cat(unique(lg[grepl("^Initial carbon|^Soil:", lg)]), sep = "\n")
new <- as.data.table(datasheet(R, "stsim_InitialStockSpatial", lookupsAsFactors = FALSE)); old <- as.data.table(datasheet(scenario(L, 47), "stsim_InitialStockSpatial", lookupsAsFactors = FALSE))
expect("a map for every stock type of stage 8's list, Deep Soil included", setequal(new$StockTypeId, fread(file.path(pkg, "defaults/initialstocks/stock-types.csv"))$StockTypeId) && "Deep Soil" %in% new$StockTypeId)
val <- function(fn) values(rast(fn), mat = FALSE)
ds <- val(new[StockTypeId == "Deep Soil", RasterFileName]); land <- !is.na(ds)
expect("Deep Soil is 0 on every land cell (no emergent cells; forest starts with none)", any(land) && all(ds[land] == 0), sprintf("%d land cells, max %.3g", sum(land), max(ds[land])))
gap <- vapply(intersect(old$StockTypeId, new$StockTypeId), function(k) max(abs(val(new[StockTypeId == k, RasterFileName]) - val(old[StockTypeId == k, RasterFileName])), na.rm = TRUE), 1)
expect("every other pool's map is the Build's own stage 8 map", all(gap < 1e-4), paste(sprintf("%s %.2g", names(gap)[gap >= 1e-4], gap[gap >= 1e-4]), collapse = "; "))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
