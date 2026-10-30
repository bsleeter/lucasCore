# =============================================================================
# 12-build-figures.R - stage 12: publication figures (PNG) of a Build result
# =============================================================================
# Draws src/figures.R's report figures (lucasFireC2F's format: "Figure N" headers, lettered panels) from the Build's own outputs and saves
# one row per PNG to Build Figures (Figure, Title, Caption, FileName): maps of the strata, the initial land cover (state class, forest
# type, stand age) and the initial carbon (on shaded relief of Data Sources' ElevationFile when it is set), and charts of area and carbon
# by class, growth curves, decay calibration, land-use change, disturbance, climate multipliers and the build's checks. Each figure is
# drawn only when its inputs are present, so it can run after any part of the Build. Export > LUCAS Core > Build Figures saves them all
# to a folder.
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
source_name <- function(v, blank) if (length(v) && !is.na(v) && nzchar(v)) as.character(v) else blank   # Build Options: blank = the default source
prim <- rast(ic$StratumFileName[1]); scr <- rast(ic$StateClassFileName[1])
scl <- stsim_list("StateClass"); stl <- named("Stratum")
present_eco <- stl$Name[stl$Id %in% unique(values(prim, mat = FALSE))]
present_cls <- scl$Name[as.numeric(scl$Id) %in% unique(values(scr, mat = FALSE))]
in_study <- function(x) if (nrow(x) && all(c("StratumId", "StateClassId") %in% names(x))) x[StratumId %in% present_eco & StateClassId %in% present_cls] else x
st <- as.data.table(datasheet(scn, "stsim_InitialStockSpatial", optional = TRUE, lookupsAsFactors = FALSE))
st <- st[!is.na(RasterFileName) & file.exists(RasterFileName)]
sa <- sheet("StudyArea")
# site productivity (to-do 35): stage 8's multiplier map and stage 5's site class shares, when the Build has them. A file path that is
# not there is looked up by name in this scenario's and its dependencies' folders (stage 12 may be its own scenario on a Build result)
find_file <- function(fn, sheet) { if (!length(fn) || is.na(fn) || file.exists(fn)) return(as.character(fn)[1])
  ids <- c(rsyncrosim::scenarioId(scn), run_dependencies())
  p <- file.path(paste0(main_library(), ".data"), sprintf("Scenario-%d", ids), sheet, basename(fn)); p <- p[file.exists(p)]; if (length(p)) p[1] else NA_character_ }
fsm <- as.data.table(datasheet(scn, "stsim_FlowSpatialMultiplier", optional = TRUE, lookupsAsFactors = FALSE))
fsm <- if (nrow(fsm) && "FlowMultiplierTypeId" %in% names(fsm)) fsm[FlowMultiplierTypeId %in% "Site Productivity"] else fsm[0]
site_m <- if (nrow(fsm)) opt_rast(find_file(fsm$MultiplierFileName[1], "stsim_FlowSpatialMultiplier")) else NULL
shs <- as.data.table(datasheet(scn, ds("OutputSiteClassMap"), optional = TRUE))
shf <- if (nrow(shs) == 7) vapply(shs[order(SiteClass), FileName], find_file, "", sheet = ds("OutputSiteClassMap")) else NA
site_class <- if (!anyNA(shf)) { X <- rast(shf); X[is.na(X)] <- 0; m <- Reduce(`+`, lapply(1:7, function(k) X[[k]] * k)); m[sum(X) == 0] <- NA; m } else NULL   # each cell's share-weighted mean class
if (!is.null(site_m)) say("Site productivity: multiplier map %s%s", basename(sources(site_m)), if (is.null(site_class)) ", no site class shares" else "")
dem <- tryCatch(read_data_sources("ElevationFile")$ElevationFile, error = function(e) { say("No hillshade: %s", conditionMessage(e)); NULL })
I <- list(strata = list(prim, opt_rast(ic$SecondaryStratumFileName[1]), opt_rast(ic$TertiaryStratumFileName[1])),
          strata_names = list(stl, named("SecondaryStratum"), named("TertiaryStratum")),
          strata_sources = c(source_name(opt$SecondarySourceId[1], "States"), source_name(opt$TertiarySourceId[1], "Federal Lands")),
          sc = scr, sc_list = scl, age = opt_rast(ic$AgeFileName[1]),
          carbon_curves = in_study(sheet("CarbonCurve")), volume_curves = in_study(sheet("MerchantableVolumeCurve")),
          decay = in_study(sheet("OutputDecayCalibration")),
          stocks = if (nrow(st)) setNames(lapply(st$RasterFileName, rast), st$StockTypeId) else NULL,
          stock_summary = sheet("OutputInitialStockSummary"), trans = sheet("OutputTransitionSummary"),
          climate = sheet("OutputClimateSummary"), site = site_m, site_class = site_class, validation = sheet("OutputValidation"), dem = dem,
          label = if (nrow(sa)) paste(sub("^[^:]*: ", "", sa$UnitId), collapse = ", ") else "CONUS", years = c(opt$StartYear[1], opt$EndYear[1]),
          result = rsyncrosim::scenarioId(scn))
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
