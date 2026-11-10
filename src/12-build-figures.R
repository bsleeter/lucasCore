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
fsm_all <- as.data.table(datasheet(scn, "stsim_FlowSpatialMultiplier", optional = TRUE, lookupsAsFactors = FALSE))
if (!"FlowMultiplierTypeId" %in% names(fsm_all)) fsm_all <- data.table(FlowMultiplierTypeId = character(), FlowGroupId = character(), Timestep = integer(), MultiplierFileName = character())
fsm <- fsm_all[FlowMultiplierTypeId %in% "Site Productivity"]
site_m <- if (nrow(fsm)) opt_rast(find_file(fsm$MultiplierFileName[1], "stsim_FlowSpatialMultiplier")) else NULL
# the non-forest attributes (user, 2026-11-09): stage 8's grass and shrub, cropland, crop harvest and tidal marsh maps; Crop Mix's yearly
# maps; the non-forest classes' Net Growth (stock-flow State Attribute Values); Crop Yield's yearly flow multipliers; stage 6's fire maps
nf_maps <- list()
for (t in c("Grass and Shrub Productivity", "Cropland Productivity", "Crop Harvest", "Tidal Marsh Productivity")) { r <- fsm_all[FlowMultiplierTypeId %in% t]
  if (nrow(r)) { x <- opt_rast(find_file(r$MultiplierFileName[1], "stsim_FlowSpatialMultiplier")); if (!is.null(x)) nf_maps[[t]] <- x } }
cm <- fsm_all[FlowMultiplierTypeId %in% "Crop Mix"]
crop_mix <- if (nrow(cm)) { cm[, File := vapply(MultiplierFileName, find_file, "", sheet = "stsim_FlowSpatialMultiplier")]
  cm[!is.na(File), .(Timestep = as.integer(Timestep), Kind = ifelse(grepl("^Harvest", FlowGroupId), "harvest", "growth"), File)] } else NULL
nonforest_cls <- present_cls[!grepl("^Forest:", present_cls) & !grepl("^Wetland: .*Forested", present_cls)]
sav <- tryCatch(as.data.table(datasheet(scn, "stsim_StateAttributeValue", optional = TRUE, lookupsAsFactors = FALSE)), error = function(e) data.table())
nf_growth <- if (nrow(sav) && all(c("StateAttributeTypeId", "StateClassId", "StratumId", "Value") %in% names(sav)))
  sav[StateAttributeTypeId %in% "Net Growth" & StateClassId %in% nonforest_cls & StratumId %in% present_eco, .(StratumId, StateClassId, AgeMin, Value)] else NULL
fmu <- tryCatch(as.data.table(datasheet(scn, "stsim_FlowMultiplier", optional = TRUE, lookupsAsFactors = FALSE)), error = function(e) data.table())
crop_yield <- if (nrow(fmu) && "FlowMultiplierTypeId" %in% names(fmu))
  fmu[FlowMultiplierTypeId %in% "Crop Yield" & StratumId %in% present_eco & StateClassId %in% present_cls, .(Timestep = as.integer(Timestep), StratumId, StateClassId, Value)] else NULL
tsm <- tryCatch(as.data.table(datasheet(scn, "stsim_TransitionSpatialMultiplier", optional = TRUE, lookupsAsFactors = FALSE)), error = function(e) data.table())
fire_maps <- if (nrow(tsm) && "TransitionGroupId" %in% names(tsm)) { f <- tsm[grepl("^Fire: .*Severity", TransitionGroupId) & !is.na(MultiplierFileName) & basename(MultiplierFileName) != "Off.tif"]
  if (nrow(f)) { f[, File := vapply(MultiplierFileName, find_file, "", sheet = "stsim_TransitionSpatialMultiplier")]; f[!is.na(File), .(Timestep = as.integer(Timestep), File)] } else NULL } else NULL
say("Non-forest figure inputs: %d productivity maps, %d Crop Mix maps, %d net growth rows, %d Crop Yield rows, %d fire maps", length(nf_maps),
    if (is.null(crop_mix)) 0L else nrow(crop_mix), if (is.null(nf_growth)) 0L else nrow(nf_growth), if (is.null(crop_yield)) 0L else nrow(crop_yield), if (is.null(fire_maps)) 0L else nrow(fire_maps))
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
          nf_maps = nf_maps, crop_mix = crop_mix, nf_growth = nf_growth, crop_yield = crop_yield, fire_maps = fire_maps,
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
