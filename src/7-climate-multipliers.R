# =============================================================================
# 7-climate-multipliers.R - stage 7: annual climate flow spatial multipliers for the historical years (PRISM)
# =============================================================================
# Replaces the GrowthMultipliers, Q10Multipliers and FlowSpatialMultipliers chunks of "Build LUCAS Model CONUS Annual NLCD FIA
# Update.Rmd" (L905-1110). Climate Options picks the model of each effect (user decision 2026-10-20); the models are in src/climate.R.
# Historical years (start-end year): PRISM, current release (annual-us25m), each year an anomaly against PRISM's own 1991-2020 normal.
# Projection years are not here (user decision 2026-10-24): a Projection Climate scenario (stage 11) computes them from a LOCA2 run on
# this Build's result, so one Build serves any number of climate futures.
# Changes from the CONUS 1km build: true multipliers written as floats (the build stored integers x 100 and undid them with 0.01
# "scalar" flow multipliers, removed from stage 3); PRISM projected once (bilinear) to the model grid; coastal gaps filled from
# neighbouring cells (the build set them to 1); files matched to years by name; a constant 1.0 after the last year.
# Needs stage 1 (same pipeline, or a dependency on its result).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "climate.R"))
suppressPackageStartupMessages({ library(terra) })
STAGE <- "7 Climate Multipliers"
progressBar(type = "begin", totalSteps = 5)

src <- read_data_sources(c("PrismFolder"))
opt <- read_ds("BuildOptions"); y0 <- opt$StartYear[1]; y1 <- opt$EndYear[1]; years <- y0:y1
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StratumFileName[1])) fail("no strata rasters: run stage 1 first (same pipeline, or depend on a stage 1 result)")
P <- rast(ic$StratumFileName[1])

fm <- climate_flows(read_ds("ClimateOptions"), STAGE)
if (!nrow(fm)) { say("Every climate effect is None: no climate multipliers written (every flow runs at normal climate)"); finish_checks(); progressBar(type = "end"); quit(save = "no") }
prm <- climate_params(fm, P, STAGE)
if (any(vapply(.checks, function(x) x$Status != "Pass", TRUE))) finish_checks()
progressBar()

# ---- historical: PRISM (current release, annual us_25m GeoTIFFs), one release for the years and the normal ------------------
pf <- function(var, y) file.path(src$PrismFolder, "annual-us25m", var, sprintf("prism_%s_us_25m_%d.tif", var, y))
need <- unique(c(y0 - 1, years, 1991:2020))
miss <- need[!file.exists(pf("tmean", need)) | !file.exists(pf("ppt", need))]
if (length(miss)) fail("PRISM annual tmean or ppt missing under %s/annual-us25m for %s", src$PrismFolder, paste(miss, collapse = ", "))
win <- climate_window(P)
cut <- function(f) crop(rast(f), win)
Tn <- mean(rast(lapply(1991:2020, function(y) cut(pf("tmean", y))))); Pn <- mean(rast(lapply(1991:2020, function(y) cut(pf("ppt", y)))))
say("PRISM: annual-us25m %d-%d; normal = mean of 1991-2020 of the same files", y0 - 1, y1)
em <- climate_emitter(fm, P, prm)
nrm <- climate_normals(Tn, Pn); Pl <- cut(pf("ppt", y0 - 1))
for (y in years) { Ty <- cut(pf("tmean", y)); Py <- cut(pf("ppt", y)); em$emit(y, Ty, Py, Pl, Tn, Pn, nrm, "PRISM"); Pl <- Py }
progressBar()

# ---- checks ---------------------------------------------------------------------------------------------------------
out <- climate_finish(em, fm, P, STAGE); summ <- out$summ
# the PRISM anomalies average about 1 over the normal's own years (1991-2020): a large departure means the normal and the series disagree
nm <- summ[Timestep %between% c(1991, 2020), .(Mean = mean(Mean)), by = FlowGroup]
if (nrow(nm)) check(STAGE, "mean PRISM multiplier over 1991-2020 is within 5% of 1", all(abs(nm$Mean - 1) < 0.05), paste(sprintf("%s %.3f", nm$FlowGroup, nm$Mean), collapse = "; "))
for (g in fm$FlowGroupId) with(summ[FlowGroup == g], say("%s (%s): PRISM study-area mean by year %.3f-%.3f; cell range %.2f-%.2f", g, Model[1], min(Mean), max(Mean), min(Min), max(Max)))
progressBar()

# ---- outputs ----------------------------------------------------------------------------------------------------------
write_stsim(out$rows, "FlowSpatialMultiplier")
write_ds(summ[, .(Timestep, FlowGroup, Model, Climate, Mean = round(Mean, 4), Min, Max)], "OutputClimateSummary")
progressBar()
finish_checks()
progressBar(type = "end")
