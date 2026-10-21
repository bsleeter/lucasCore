# =============================================================================
# 7-climate-multipliers.R - stage 7: annual climate flow spatial multipliers for the historical period (PRISM)
# =============================================================================
# Replaces the GrowthMultipliers, Q10Multipliers and FlowSpatialMultipliers chunks of "Build LUCAS Model CONUS Annual NLCD FIA
# Update.Rmd" (L905-1110). Climate Options picks the model of each effect (user decision 2026-10-20); defaults/climate/
# flow-multipliers.csv lists the flow groups of each:
#   Forest growth      None | Miami NPP | Tree ring (default)
#   Non-forest growth  None | Miami NPP (default)
#   Decomposition      None | Q10 (default)
#   Miami NPP   forest NPP = min(f(MAT), f(MAP)), non-forest NPP = f(MAP) (Lieth 1975); multiplier = year / normal
#   Tree ring   1 + PrecipCoef (P/Pn - 1) + PrecipLagCoef (P last year/Pn - 1) + TempCoef (T - Tn), coefficients by ecodivision
#               (defaults/climate/tree-ring-coefficients.csv, tools/make_tree_ring_coefficients.R: 1,288 ITRDB chronologies on PRISM
#               1895-2023). Out of sample it predicts annual ring growth better than Miami, which predicts it worse than a constant
#   Q10         Q10 ^ ((T - Tn) / 10), Q10 read from the CBM DOM table for the listed pools (the same values stage 3 uses)
#   None        no multiplier: the flow runs at normal climate every year
# Each multiplier is an anomaly against the cell's own 1991-2020 mean of the same PRISM files: the growth curves (stage 2) and decay
# rates (stage 3) describe the climate of that normal, and stage 4 spins up under it, so 1.0 means "as fitted".
# Changes from the CONUS 1km build: true multipliers written as floats (the build stored integers x 100 and undid them with 0.01
# "scalar" flow multipliers, removed from stage 3); PRISM projected once (bilinear) to the model grid; coastal gaps filled from
# neighbouring PRISM cells (the build set them to 1); files matched to years by name; a constant 1.0 after the end year.
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

# ---- Climate Options --------------------------------------------------------------------------------------------------
co <- read_ds("ClimateOptions")
choice <- function(v, labels) { v <- v[1]; if (is.null(v) || is.na(v)) return(NA_character_)
  if (is.numeric(v)) labels[v] else labels[match(tolower(v), tolower(labels))] }
model <- c(ForestGrowth = choice(co$ForestGrowthModel, c("None", "Miami NPP", "Tree ring")),
           NonForestGrowth = choice(co$NonForestGrowthModel, c("None", "Miami NPP")),
           Decomposition = choice(co$DecompositionModel, c("None", "Q10")))
if (anyNA(model)) fail("Climate Options: unrecognised choice for %s", paste(names(model)[is.na(model)], collapse = ", "))
fm <- read_default("climate", "flow-multipliers.csv")
fg <- stsim_list("FlowGroup")$Name
check(STAGE, "every climate flow group exists", all(fm$FlowGroupId %in% fg), paste(setdiff(fm$FlowGroupId, fg), collapse = "; "))
fm[, Model := model[Role]]
say("Climate Options: forest growth = %s; non-forest growth = %s; decomposition = %s", model[["ForestGrowth"]], model[["NonForestGrowth"]], model[["Decomposition"]])
fm <- fm[Model != "None"]
if (!nrow(fm)) { say("Every climate effect is None: no climate multipliers written (every flow runs at normal climate)"); finish_checks(); progressBar(type = "end"); quit(save = "no") }

dom <- fread(pkg_file("defaults", "cbm", "tblDOMParametersDefault.csv"))
q10 <- setNames(vapply(seq_len(nrow(fm)), function(i) { if (fm$Model[i] != "Q10") return(NA_real_)
  q <- unique(round(dom[SoilPoolID %in% as.integer(strsplit(fm$CbmPools[i], "|", fixed = TRUE)[[1]]), Q10], 4))
  if (length(q) != 1) { check(STAGE, sprintf("the CBM pools of %s share one Q10", fm$FlowGroupId[i]), FALSE, paste(q, collapse = ", ")); return(NA_real_) }
  q }, 0), fm$FlowGroupId)

# tree-ring coefficients on the model grid, by primary stratum (FIA ecodivision) Id
coef_r <- NULL
if ("Tree ring" %in% fm$Model) {
  tc <- read_default("climate", "tree-ring-coefficients.csv")
  ids <- as.integer(terra::unique(P)[[1]]); miss <- setdiff(ids, as.integer(tc$Id))
  check(STAGE, "every ecodivision has tree-ring coefficients", !length(miss), paste("strata without:", paste(miss, collapse = ", ")))
  coef_r <- lapply(c(bp = "PrecipCoef", bl = "PrecipLagCoef", bt = "TempCoef"), function(k) classify(P, cbind(as.integer(tc$Id), as.numeric(tc[[k]])), others = NA))
  used <- tc[as.integer(Id) %in% ids]
  say("Tree-ring coefficients (precip, last year's precip, temperature): %s",
      paste(sprintf("%s %s/%s/%s (%s)", used$StratumId, used$PrecipCoef, used$PrecipLagCoef, used$TempCoef, used$Source), collapse = "; "))
}
if (any(vapply(.checks, function(x) x$Status != "Pass", TRUE))) finish_checks()

# ---- PRISM (current release, annual us_25m GeoTIFFs), one release for the years and the normal ---------------------------
pf <- function(var, y) file.path(src$PrismFolder, "annual-us25m", var, sprintf("prism_%s_us_25m_%d.tif", var, y))
need <- unique(c(y0 - 1, years, 1991:2020))
miss <- need[!file.exists(pf("tmean", need)) | !file.exists(pf("ppt", need))]
if (length(miss)) fail("PRISM annual tmean or ppt missing under %s/annual-us25m for %s", src$PrismFolder, paste(miss, collapse = ", "))
win <- project(as.polygons(ext(P) + 20000, crs = crs(P)), crs(rast(pf("tmean", y0))))
cut <- function(f) crop(rast(f), ext(win) + 0.5)
Tn <- mean(rast(lapply(1991:2020, function(y) cut(pf("tmean", y))))); Pn <- mean(rast(lapply(1991:2020, function(y) cut(pf("ppt", y)))))
say("PRISM: annual-us25m %d-%d; normal = mean of 1991-2020 of the same files", y0 - 1, y1)
progressBar()

miami <- function(t, p, forest) { if (!forest) return(6116 * (1 - exp(-6.05e-5 * p)))
  min(2540 / (1 + exp(1.584 - 0.0622 * t)), (0.551 * p^1.055) / exp(0.000306 * p)) }
norm <- list(forest = miami(Tn, Pn, TRUE), nonforest = miami(Tn, Pn, FALSE))
# grow the PRISM field two cells into its no-data margin (coast), then interpolate to the model grid; anything still empty is 1
to_grid <- function(x, fill = 1) { for (k in 1:2) x <- focal(x, 3, "mean", na.policy = "only", na.rm = TRUE)
  r <- mask(project(x, P, method = "bilinear"), P); n <- global(is.na(r) & !is.na(P), "sum")[[1]]
  r <- mask(cover(r, init(P, fill)), P); attr(r, "unfilled") <- n; r }

one <- write_raster(mask(init(P, 1), P), "One.tif", "FLT4S")
rows <- list(); summ <- list(); unfilled <- 0
Pl <- cut(pf("ppt", y0 - 1))
for (y in years) { Ty <- cut(pf("tmean", y)); Py <- cut(pf("ppt", y))
  tr_terms <- NULL
  for (j in seq_len(nrow(fm))) { g <- fm$FlowGroupId[j]; md <- fm$Model[j]
    r <- if (md == "Tree ring") {
      if (is.null(tr_terms)) tr_terms <- list(pr = to_grid(Py / Pn), pl = to_grid(Pl / Pn), ta = to_grid(Ty - Tn, fill = 0))
      max(1 + coef_r$bp * (tr_terms$pr - 1) + coef_r$bl * (tr_terms$pl - 1) + coef_r$bt * tr_terms$ta, 0)
    } else if (md == "Miami NPP") { forest <- fm$Role[j] == "ForestGrowth"; to_grid(miami(Ty, Py, forest) / norm[[if (forest) "forest" else "nonforest"]])
    } else to_grid(q10[[g]]^((Ty - Tn) / 10))
    if (!is.null(attr(r, "unfilled"))) unfilled <- max(unfilled, attr(r, "unfilled"))
    r <- round(r, 3)
    f <- write_raster(r, sprintf("%s_%d.tif", gsub("[^A-Za-z0-9]+", "-", g), y), "FLT4S")
    v <- values(r, mat = FALSE)[land]
    rows[[length(rows) + 1]] <- data.table(Timestep = y, FlowGroupId = g, MultiplierFileName = f)
    summ[[length(summ) + 1]] <- data.table(Timestep = y, FlowGroup = g, Model = md, Mean = mean(v, na.rm = TRUE), Min = min(v, na.rm = TRUE),
                                           Max = max(v, na.rm = TRUE), SD = sd(v, na.rm = TRUE), NaCells = sum(is.na(v))) }
  Pl <- Py }
progressBar()

# ---- checks ---------------------------------------------------------------------------------------------------------
summ <- rbindlist(summ); rows <- rbindlist(rows)
rows <- rbind(rows, data.table(Timestep = y1 + 1, FlowGroupId = fm$FlowGroupId, MultiplierFileName = one))
check(STAGE, "every land cell has a multiplier in every year", all(summ$NaCells == 0), sprintf("%d cell-years without one", sum(summ$NaCells)))
# (growth can reach 0: a desert cell's precipitation in a very dry year against a small normal; tree ring is floored at 0)
check(STAGE, "multipliers are finite and not negative", all(is.finite(summ$Min) & summ$Min >= 0 & is.finite(summ$Max)), sprintf("range %.3f-%.3f", min(summ$Min), max(summ$Max)))
# the anomalies average about 1 over the normal's own years (1991-2020): a large departure means the normal and the series disagree
nm <- summ[Timestep %between% c(1991, 2020), .(Mean = mean(Mean)), by = FlowGroup]
if (nrow(nm)) check(STAGE, "mean multiplier over 1991-2020 is within 5% of 1", all(abs(nm$Mean - 1) < 0.05), paste(sprintf("%s %.3f", nm$FlowGroup, nm$Mean), collapse = "; "))
if (unfilled > 0) say("Cells beyond the PRISM gap fill (set to normal): %d", unfilled)
for (g in fm$FlowGroupId) with(summ[FlowGroup == g], say("%s (%s): study-area mean by year %.3f-%.3f; cell range %.2f-%.2f", g, Model[1], min(Mean), max(Mean), min(Min), max(Max)))
mb <- sum(file.size(unique(rows$MultiplierFileName))) / 2^20
say("Rasters: %d files, %.0f MB (%.2f MB each)", uniqueN(rows$MultiplierFileName), mb, mb / uniqueN(rows$MultiplierFileName))
progressBar()

# ---- outputs ----------------------------------------------------------------------------------------------------------
write_stsim(rows, "FlowSpatialMultiplier")
write_ds(summ[, .(Timestep, FlowGroup, Model, Mean = round(Mean, 4), Min, Max)], "OutputClimateSummary")
progressBar()
finish_checks()
progressBar(type = "end")
