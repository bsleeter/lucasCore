# =============================================================================
# 7-climate-multipliers.R - stage 7: annual climate flow spatial multipliers for the historical period (PRISM)
# =============================================================================
# Replaces the GrowthMultipliers, Q10Multipliers and FlowSpatialMultipliers chunks of "Build LUCAS Model CONUS Annual NLCD FIA
# Update.Rmd" (L905-1110). defaults/climate/flow-multipliers.csv lists the flow groups and their model:
#   MiamiForest     forest NPP = min(f(MAT), f(MAP)) of the Miami model (Lieth 1975); multiplier = year / 1991-2020 normal
#   MiamiNonForest  non-forest NPP = f(MAP); multiplier = year / normal
#   Q10             Q10 ^ ((T - T normal) / 10), Q10 read from the CBM DOM table for the listed pools (the same values stage 3 uses)
# Each multiplier is an anomaly against the cell's own 1991-2020 PRISM normal: the growth curves (stage 2) and decay rates (stage 3)
# describe the climate of that normal, and stage 4 spins up under it, so 1.0 means "as fitted".
# Changes from the CONUS 1km build:
#   * true multipliers (1.0 = normal climate) written as floats; the build stored integers x 100 and undid them with 0.01 "scalar"
#     flow multipliers, which made any run without the climate rasters grow and decay at 1% (removed from stage 3)
#   * computed on the PRISM 4 km grid and projected once (bilinear) to the model grid; the build went through a 4 km Albers grid first
#   * cells the PRISM grid misses (coast) take their nearest PRISM neighbours; the build set them to 1
#   * files are matched to years by the year in their names (the build paired a sorted file list with a year sequence)
#   * a constant 1.0 multiplier after the end year, so a projection does not inherit the last historical year
# Needs stage 1 (same pipeline, or a dependency on its result).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
suppressPackageStartupMessages({ library(terra) })
STAGE <- "7 Climate Multipliers"
progressBar(type = "begin", totalSteps = 5)

src <- read_data_sources(c("PrismFolder"))
opt <- read_ds("BuildOptions"); y0 <- opt$StartYear[1]; y1 <- opt$EndYear[1]; years <- y0:y1
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StratumFileName[1])) fail("no strata rasters: run stage 1 first (same pipeline, or depend on a stage 1 result)")
P <- rast(ic$StratumFileName[1]); land <- !is.na(values(P, mat = FALSE))

fm <- read_default("climate", "flow-multipliers.csv")
fg <- stsim_list("FlowGroup")$Name
check(STAGE, "every climate flow group exists", all(fm$FlowGroupId %in% fg), paste(setdiff(fm$FlowGroupId, fg), collapse = "; "))
check(STAGE, "every climate model is known", all(fm$Model %in% c("MiamiForest", "MiamiNonForest", "Q10")), paste(setdiff(fm$Model, c("MiamiForest", "MiamiNonForest", "Q10")), collapse = "; "))
dom <- fread(pkg_file("defaults", "cbm", "tblDOMParametersDefault.csv"))
q10 <- setNames(vapply(seq_len(nrow(fm)), function(i) { if (fm$Model[i] != "Q10") return(NA_real_)
  q <- unique(round(dom[SoilPoolID %in% as.integer(strsplit(fm$CbmPools[i], "|", fixed = TRUE)[[1]]), Q10], 4))
  if (length(q) != 1) { check(STAGE, sprintf("the CBM pools of %s share one Q10", fm$FlowGroupId[i]), FALSE, paste(q, collapse = ", ")); return(NA_real_) }
  q }, 0), fm$FlowGroupId)
finish_checks_if_failed <- function() if (any(vapply(.checks, function(x) x$Status != "Pass", TRUE))) finish_checks()
finish_checks_if_failed()
say("Climate flow groups: %s", paste(sprintf("%s (%s%s)", fm$FlowGroupId, fm$Model, ifelse(is.na(q10), "", sprintf(", Q10 %.2f", q10))), collapse = "; "))

# PRISM files by the year in their names
pf <- function(var, y) { f <- Sys.glob(file.path(src$PrismFolder, "annual", var, "*", sprintf("PRISM_*_%d_bil.bil", y)))
  if (!length(f)) f <- Sys.glob(file.path(src$PrismFolder, "annual", var, sprintf("PRISM_*_%d_bil.bil", y))); if (length(f)) f[1] else NA_character_ }
tf <- vapply(years, function(y) pf("tmean", y), ""); pp <- vapply(years, function(y) pf("precip", y), "")
miss <- years[is.na(tf) | is.na(pp)]
if (length(miss)) fail("PRISM annual tmean or precip missing for %s (%s/annual)", paste(miss, collapse = ", "), src$PrismFolder)
nt <- Sys.glob(file.path(src$PrismFolder, "normals", "PRISM_tmean_30yr_normal_*_annual_bil", "*.bil"))[1]
np <- Sys.glob(file.path(src$PrismFolder, "normals", "PRISM_ppt_30yr_normal_*_annual_bil", "*.bil"))[1]
if (is.na(nt) || is.na(np)) fail("PRISM annual tmean/ppt 30-year normals not found under %s/normals", src$PrismFolder)
say("PRISM: %d years (%s ... %s); normals %s", length(years), basename(tf[1]), basename(tf[length(tf)]), basename(dirname(nt)))
progressBar()

# ---- the models, on the PRISM grid ----------------------------------------------------------------------------------
# the PRISM window around the model grid (a few 4 km cells of margin for the gap fill and the bilinear interpolation)
win <- project(as.polygons(ext(P) + 20000, crs = crs(P)), crs(rast(nt)))
cut <- function(f) crop(rast(f), ext(win) + 0.5)
miami <- function(t, p, forest) { fp <- (0.551 * p^1.055) / exp(0.000306 * p)
  if (!forest) return(6116 * (1 - exp(-6.05e-5 * p)))
  min(2540 / (1 + exp(1.584 - 0.0622 * t)), fp) }
Tn <- cut(nt); Pn <- cut(np)
norm <- list(MiamiForest = miami(Tn, Pn, TRUE), MiamiNonForest = miami(Tn, Pn, FALSE))
# grow the PRISM field two cells into its no-data margin (coast), then interpolate to the model grid; anything still empty is 1
to_grid <- function(x) { for (k in 1:2) x <- focal(x, 3, "mean", na.policy = "only", na.rm = TRUE)
  r <- mask(project(x, P, method = "bilinear"), P); n <- global(is.na(r) & !is.na(P), "sum")[[1]]
  r <- mask(cover(r, init(P, 1)), P); attr(r, "unfilled") <- n; r }

one <- write_raster(mask(init(P, 1), P), "One.tif", "FLT4S")
rows <- list(); summ <- list(); unfilled <- 0
for (i in seq_along(years)) { y <- years[i]; Ty <- cut(tf[i]); Py <- cut(pp[i])
  for (j in seq_len(nrow(fm))) { g <- fm$FlowGroupId[j]; md <- fm$Model[j]
    x <- switch(md, MiamiForest = miami(Ty, Py, TRUE) / norm$MiamiForest, MiamiNonForest = miami(Ty, Py, FALSE) / norm$MiamiNonForest,
                Q10 = q10[[g]]^((Ty - Tn) / 10))
    r <- round(to_grid(x), 3); unfilled <- max(unfilled, attr(r, "unfilled"))
    f <- write_raster(r, sprintf("%s_%d.tif", gsub("[^A-Za-z0-9]+", "-", g), y), "FLT4S")
    v <- values(r, mat = FALSE)[land]
    rows[[length(rows) + 1]] <- data.table(Timestep = y, FlowGroupId = g, MultiplierFileName = f)
    summ[[length(summ) + 1]] <- data.table(Timestep = y, FlowGroup = g, Model = md, Mean = mean(v, na.rm = TRUE), Min = min(v, na.rm = TRUE),
                                           Max = max(v, na.rm = TRUE), NaCells = sum(is.na(v))) } }
progressBar()

# ---- checks ---------------------------------------------------------------------------------------------------------
summ <- rbindlist(summ); rows <- rbindlist(rows)
rows <- rbind(rows, data.table(Timestep = y1 + 1, FlowGroupId = fm$FlowGroupId, MultiplierFileName = one))
check(STAGE, "every land cell has a multiplier in every year", all(summ$NaCells == 0), sprintf("%d cell-years without one", sum(summ$NaCells)))
# (growth can reach 0: a desert cell's precipitation in a very dry year against a small normal)
check(STAGE, "multipliers are finite and not negative", all(is.finite(summ$Min) & summ$Min >= 0 & is.finite(summ$Max)), sprintf("range %.3f-%.3f", min(summ$Min), max(summ$Max)))
# the anomalies average about 1 over the normal's own years (1991-2020): a large departure means the normal and the annual series disagree
nm <- summ[Timestep %between% c(1991, 2020), .(Mean = mean(Mean)), by = FlowGroup]
if (nrow(nm)) check(STAGE, "mean multiplier over 1991-2020 is within 5% of 1", all(abs(nm$Mean - 1) < 0.05), paste(sprintf("%s %.3f", nm$FlowGroup, nm$Mean), collapse = "; "))
if (unfilled > 0) say("Cells beyond the PRISM gap fill (set to 1): %d", unfilled)
for (g in fm$FlowGroupId) with(summ[FlowGroup == g], say("%s: annual study-area mean %.3f-%.3f (driest/coldest to wettest/warmest year), cell range %.2f-%.2f",
                                                           g, min(Mean), max(Mean), min(Min), max(Max)))
mb <- sum(file.size(unique(rows$MultiplierFileName))) / 2^20
say("Rasters: %d files, %.0f MB (%.2f MB each)", uniqueN(rows$MultiplierFileName), mb, mb / uniqueN(rows$MultiplierFileName))
progressBar()

# ---- outputs ----------------------------------------------------------------------------------------------------------
write_stsim(rows, "FlowSpatialMultiplier")
write_ds(summ[, .(Timestep, FlowGroup, Model, Mean = round(Mean, 4), Min, Max)], "OutputClimateSummary")
progressBar()
finish_checks()
progressBar(type = "end")
