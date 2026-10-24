# =============================================================================
# 12-build-figures.R - stage 12: publication figures (PNG) of a Build result
# =============================================================================
# Draws src/figures.R's maps and charts from the Build's own outputs and saves one row per PNG to Build Figures (Figure, Title, Caption,
# FileName): strata, initial state class, stand age, forest types, initial carbon maps (over a hillshade of Data Sources' ElevationFile
# when it is set), and charts of area by class, growth curves, decay calibration, carbon by class, land-use change, disturbance,
# climate multipliers and the build's checks. Each figure is drawn only when its inputs are present, so it can run after any part of
# the Build. Export > LUCAS Core > Build Figures saves them all to a folder.
# Needs stage 5 (state classes); the rest is optional: last in the Build pipeline, or its own scenario depending on a Build result.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "figures.R"))
STAGE <- "12 Build Figures"
progressBar(type = "begin", totalSteps = 3)

opt <- read_ds("BuildOptions")
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StateClassFileName[1])) fail("no state class map: run stage 5 first (same pipeline, or depend on a Build result)")
opt_rast <- function(f) if (length(f) && !is.na(f) && nzchar(f) && file.exists(f)) rast(f) else NULL
named <- function(name) stsim_list(name)[, .(Id = as.numeric(Id), Name)]
sheet <- function(name) read_ds(name)
prim <- rast(ic$StratumFileName[1]); scr <- rast(ic$StateClassFileName[1])
scl <- stsim_list("StateClass"); stl <- named("Stratum")
present_eco <- stl$Name[stl$Id %in% unique(values(prim, mat = FALSE))]
present_cls <- scl$Name[as.numeric(scl$Id) %in% unique(values(scr, mat = FALSE))]
in_study <- function(x) if (nrow(x) && all(c("StratumId", "StateClassId") %in% names(x))) x[StratumId %in% present_eco & StateClassId %in% present_cls] else x
st <- as.data.table(datasheet(scn, "stsim_InitialStockSpatial", optional = TRUE, lookupsAsFactors = FALSE))
st <- st[!is.na(RasterFileName) & file.exists(RasterFileName)]
sa <- sheet("StudyArea")
dem <- tryCatch(read_data_sources("ElevationFile")$ElevationFile, error = function(e) { say("No hillshade: %s", conditionMessage(e)); NULL })
I <- list(strata = list(prim, opt_rast(ic$SecondaryStratumFileName[1]), opt_rast(ic$TertiaryStratumFileName[1])),
          strata_names = list(stl, named("SecondaryStratum"), named("TertiaryStratum")),
          sc = scr, sc_list = scl, age = opt_rast(ic$AgeFileName[1]),
          carbon_curves = in_study(sheet("CarbonCurve")), volume_curves = in_study(sheet("MerchantableVolumeCurve")),
          decay = in_study(sheet("OutputDecayCalibration")),
          stocks = if (nrow(st)) setNames(lapply(st$RasterFileName, rast), st$StockTypeId) else NULL,
          stock_summary = sheet("OutputInitialStockSummary"), trans = sheet("OutputTransitionSummary"),
          climate = sheet("OutputClimateSummary"), validation = sheet("OutputValidation"), dem = dem,
          label = if (nrow(sa)) paste(sub("^[^:]*: ", "", sa$UnitId), collapse = ", ") else "CONUS", years = c(opt$StartYear[1], opt$EndYear[1]))
progressBar()

out <- file.path(TD(), "BuildFigures")
res <- build_figures(I, out)
say("%d figures drawn (%s)", nrow(res), paste(res$Title, collapse = "; "))
progressBar()

check(STAGE, "figures drawn", nrow(res) > 0, sprintf("%d PNG", nrow(res)))
check(STAGE, "every figure file was written", nrow(res) > 0 && all(file.exists(res$FileName)), paste(basename(res$FileName[!file.exists(res$FileName)]), collapse = "; "))
write_ds(res[, .(Figure, Title, Caption, FileName)], "OutputBuildFigure")
progressBar()
finish_checks()
progressBar(type = "end")
