# =============================================================================
# test_figures.R - draw the Build figures (dev/figures/figures.R) from a Build result, outside a SyncroSim run
# =============================================================================
# Usage: Rscript dev/figures/test_figures.R [library.ssim] [result id] [out dir]
#   defaults: the Studio-style test library (tests/phaseX-studio-library.R), its newest Build result, dev/figures/out
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
a <- commandArgs(TRUE)
f <- if (length(a) >= 1) a[1] else "F:/lucasCore/dev/libs/lucasCore-studio-library.ssim"
out <- if (length(a) >= 3) a[3] else "F:/lucasCore/dev/figures/out"
source("F:/lucasCore/dev/figures/figures.R")
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(rsyncrosim::scenario(L, summary = TRUE))
rid <- if (length(a) >= 2) as.integer(a[2]) else max(sc[IsResult == "Yes" & grepl("Build", Name, fixed = TRUE), ScenarioId])
R <- rsyncrosim::scenario(L, rid); ds <- function(s, sc = R) suppressWarnings(as.data.table(datasheet(sc, s, lookupsAsFactors = FALSE, optional = TRUE)))
ic <- ds("stsim_InitialConditionsSpatial"); bo <- ds("lucasCore_BuildOptions"); sa <- ds("lucasCore_StudyArea")
scr <- rast(ic$StateClassFileName[1]); prim <- rast(ic$StratumFileName[1])
lst <- function(s) ds(s, P)[, .(Id = as.numeric(Id), Name)]
eco <- lst("stsim_Stratum"); classes <- lst("stsim_StateClass")
present_eco <- eco$Name[eco$Id %in% unique(values(prim, mat = FALSE))]
present_cls <- classes$Name[classes$Id %in% unique(values(scr, mat = FALSE))]
cc <- ds("lucasCore_CarbonCurve")[StratumId %in% present_eco & StateClassId %in% present_cls]
vc <- ds("lucasCore_MerchantableVolumeCurve")[StratumId %in% present_eco & StateClassId %in% present_cls]
dc <- ds("lucasCore_OutputDecayCalibration")[StratumId %in% present_eco & StateClassId %in% present_cls]
st <- ds("stsim_InitialStockSpatial"); stocks <- setNames(lapply(st$RasterFileName, rast), st$StockTypeId)
I <- list(strata = list(prim, rast(ic$SecondaryStratumFileName[1]), rast(ic$TertiaryStratumFileName[1])),
          strata_names = list(eco, lst("stsim_SecondaryStratum"), lst("stsim_TertiaryStratum")),
          sc = scr, sc_list = ds("stsim_StateClass", P), age = rast(ic$AgeFileName[1]),
          carbon_curves = cc, volume_curves = vc, decay = dc, stocks = stocks,
          stock_summary = ds("lucasCore_OutputInitialStockSummary"), trans = ds("lucasCore_OutputTransitionSummary"),
          climate = ds("lucasCore_OutputClimateSummary"), validation = ds("lucasCore_OutputValidation"),
          label = if (nrow(sa)) paste(sub("^[^:]*: ", "", sa$UnitId), collapse = ", ") else "CONUS", years = c(bo$StartYear[1], bo$EndYear[1]))
t0 <- Sys.time(); res <- build_figures(I, out)
print(res[, .(Figure, Title, File = basename(FileName))]); cat(sprintf("%.1f s\n", as.numeric(Sys.time() - t0, units = "secs")))
