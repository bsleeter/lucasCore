# =============================================================================
# 8-initial-stocks-spatial.R - stage 8: initial carbon stock rasters (ST-Sim Initial Stocks, spatial)
# =============================================================================
# Replaces the initialStocks chunk of "Build LUCAS Model CONUS Annual NLCD FIA Update.Rmd" (L2434-2890). Every land cell gets the 14
# carbon pools (Mg C/ha) of its start-year state:
#   forest classes          stage 4's Initial Stock Curves: ecodivision x forest class x last disturbance x stand age (age capped at the
#                           curves' maximum)
#   forested wetland        defaults/initialstocks/wetland-forested-{fire,harvest}.csv, by class x age (the CONUS 1km build's tables)
#   grass/shrub             defaults/initialstocks/grassland-shrubland.csv, by ecodivision and class: the steady state of stage 3's
#                           rates (tools/make_grass_shrub.R); chaparral from initialstocks/chaparral.csv by ecodivision and age since fire
#   emergent wetland        defaults/initialstocks/emergent-wetland.csv, by ecodivision and class: the steady state of stage 3's
#                           regional rates, and Deep Soil = the soil 30-100 cm (tools/make_emergent_wetland.R; to-do 39 step 1)
#   cropland, pasture       defaults/initialstocks/agriculture.csv, by ecodivision and class: the steady state of stage 3's rates
#                           (tools/make_agriculture.R; to-do 39 step 6), soil the class's gNATSGO mean
#   everything else         0 (developed, barren, water, ice)
#   last disturbance        high-severity fire where an interagency fire perimeter of 1900 to the start year covers the cell, otherwise
#                           clearcut (the build's rule; with few early perimeters in the East, eastern forest is mostly post-harvest), or
#                           high-severity fire for the forest types Carbon Assumptions: Spin-up sets so
#   soil (BG slow)          gNATSGO wherever the class's value is 0 (the build's rule). Forest keeps its spin-up value: stage 3
#                           calibrated soil decay to each ecodivision x class's mean gNATSGO, so forest cells start at the class's
#                           gNATSGO mean and in balance with their decay rates
# Stand age is the stage 6 map when it ran (clearcut minimum age applied), else stage 5's.
# Needs stages 4 and 5 (6 recommended): same pipeline, or dependencies on their results.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
suppressPackageStartupMessages({ library(terra); library(sf) })
STAGE <- "8 Initial Stocks Spatial"
progressBar(type = "begin", totalSteps = 5)
src <- read_data_sources(c("FirePerimeterHistoryFile", "SoilCarbonFile"))
opt <- read_ds("BuildOptions"); y0 <- opt$StartYear[1]
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StateClassFileName[1]) || is.na(ic$AgeFileName[1])) fail("no state class or age map: run stage 5 first (same pipeline, or depend on a stage 5 result)")
cv <- as.data.table(datasheet(scn, ds("InitialStockCurve"), optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(cv)) fail("Initial Stock Curves are empty: run stage 4 first (same pipeline, or depend on a stage 4 result)")
P <- rast(ic$StratumFileName[1]); S <- rast(ic$StateClassFileName[1]); A <- rast(ic$AgeFileName[1])
home_coverage(P)   # Data Sources read from the home folder must hold the study area (shared.R)
scl <- stsim_list("StateClass"); stl <- stsim_list("Stratum"); stt <- stsim_list("StockType")$Name
st <- read_default("initialstocks", "stock-types.csv")
check(STAGE, "every stock type exists", all(st$StockTypeId %in% stt), paste(setdiff(st$StockTypeId, stt), collapse = "; "))
if (any(vapply(.checks, function(x) x$Status != "Pass", TRUE))) finish_checks()
land <- !is.na(values(P, mat = FALSE)); vP <- values(P, mat = FALSE); vS <- values(S, mat = FALSE); vA <- values(A, mat = FALSE)
cname <- scl$Name[match(vS, as.integer(scl$Id))]; sname <- stl$Name[match(vP, as.integer(stl$Id))]
cell_ha <- (res(P)[1] / 100)^2
progressBar()
# ---- last disturbance: interagency fire perimeters, 1900 to the start year --------------------------------------------------
fp <- read_fire_perimeters(src$FirePerimeterHistoryFile, 1900, y0)
fp <- st_make_valid(st_transform(fp, crs(P)))
bb <- st_as_sfc(st_bbox(c(xmin = xmin(P), ymin = ymin(P), xmax = xmax(P), ymax = ymax(P)), crs = st_crs(crs(P))))
fp <- fp[lengths(st_intersects(fp, bb)) > 0, ]
burned <- if (nrow(fp)) !is.na(values(rasterize(vect(fp), P, field = 1), mat = FALSE)) else rep(FALSE, ncell(P))
say("Last disturbance: %d fire perimeters of 1900-%d intersect the study area; %.1f%% of land cells inside one",
    nrow(fp), y0, 100 * mean(burned[land]))
# outside the perimeters: clearcut, unless Carbon Assumptions: Spin-up sets high-severity fire for the cell's forest type (the
# ecodivision row's choice, else the type's all-ecodivisions row's)
postfire <- burned
sp <- as.data.table(datasheet(scn, ds("Spinup"), optional = TRUE, lookupsAsFactors = FALSE))
if (nrow(sp) && "LastDisturbanceUnburned" %in% names(sp) && any(!is.na(sp$LastDisturbanceUnburned))) {
  sp <- sp[!is.na(LastDisturbanceUnburned)][, `:=`(StratumId = as.character(StratumId), fire = LastDisturbanceUnburned %in% c(2L, "2", "High-severity fire"))]   # a list column reads as its label
  ch <- data.table(sname, cname)
  own <- sp[!is.na(StratumId)][ch, on = .(StratumId = sname, StateClassId = cname), fire, mult = "first"]
  all <- sp[is.na(StratumId)][ch, on = .(StateClassId = cname), fire, mult = "first"]
  uf <- data.table::fcoalesce(own, all); postfire <- burned | (!is.na(uf) & uf)
  say("Spin-up (Carbon Assumptions): high-severity fire as the last disturbance outside the perimeters for %d land cells of %s", sum(land & postfire & !burned),
      paste(sub("^Forest: ", "", unique(sp[fire == TRUE, paste0(ifelse(is.na(StratumId), "", paste0(StratumId, " / ")), StateClassId)])), collapse = ", "))
}
last <- ifelse(postfire, "Fire: High Severity [Type]", "Forest Harvest: Forest Clearcut [Type]")
say("Last disturbance: %.1f%% of land cells post-fire, the rest post-clearcut", 100 * mean(postfire[land]))
progressBar()
# ---- pools by class -----------------------------------------------------------------------------------------------------
out <- matrix(0, ncell(P), nrow(st), dimnames = list(NULL, st$StockTypeId)); src_of <- rep(NA_character_, ncell(P))
# forest: stage 4 curves
amax <- max(cv$Age); fk <- paste(cv$StratumId, cv$StateClassId, cv$TransitionGroupId, cv$Age)
isF <- land & !is.na(vS) & vS >= 100
key <- paste(sname, cname, last, pmin(pmax(round(vA), 0), amax))
m <- match(key[isF], fk)
check(STAGE, "every forest cell finds its ecodivision x class x last disturbance x age in the stock curves", !anyNA(m),
      sprintf("%d of %d forest cells unmatched (e.g. %s)", sum(is.na(m)), sum(isF), paste(head(unique(key[isF][is.na(m)]), 3), collapse = "; ")))
cc <- which(!is.na(st$CurveColumn))   # Deep Soil has no curve column: forest starts with none
out[which(isF)[!is.na(m)], cc] <- as.matrix(cv[m[!is.na(m)], st$CurveColumn[cc], with = FALSE]); src_of[isF] <- "stock curves (stage 4)"
source(pkg_file("src", "productivity-fill.R"))
# the productivity multipliers' Flow Spatial Multiplier rows, saved once at the end of the stage (put_multipliers_save): each type's
# row replaces the type's row the sheet already holds, every other row kept. When stage 8 is rerun on its own on a Build result
# (tools/quick-test.R) the result already holds the Build's rows, and a second row of one flow group and type stops ST-Sim ("Object
# reference not set", 2026-11-07); in a Build the sheet holds stage 7's Climate rows. One save: a stage's second save of a sheet is not
# kept (2026-11-07: Cropland Productivity, saved after Grass and Shrub Productivity, never reached ST-Sim)
.fsm_new <- list()
# (a type with yearly maps passes its rows: Timestep, FlowGroupId, FlowMultiplierTypeId, MultiplierFileName)
put_multiplier <- function(type, fg = NULL, file = NULL, rows = NULL) .fsm_new[[type]] <<- if (is.null(rows)) data.table(FlowGroupId = fg, FlowMultiplierTypeId = type, MultiplierFileName = file) else rows
put_multipliers_save <- function() {
  if (!length(.fsm_new)) return(invisible())
  new <- rbindlist(.fsm_new, fill = TRUE); x <- as.data.table(datasheet(scn, "stsim_FlowSpatialMultiplier", optional = TRUE, lookupsAsFactors = FALSE))
  # stage 8 writes the sheet as an output only (package.xml): declared as an input too, a rerun's saves were not kept when a
  # dependency held the sheet (2026-11-08). In a Build the sheet holds stage 7's rows; rerun on its own, the dependency's rows are
  # carried over (with their files' full paths), as stage 7 and stage 11 do
  if (!nrow(x)) { d <- dependency_multipliers(stsim_list("FlowMultiplierType")$Name); if (!is.null(d)) { x <- d; say("Flow Spatial Multipliers: %d rows carried over from the dependency", nrow(d)) } }
  if (nrow(x)) x <- x[if ("FlowMultiplierTypeId" %in% names(x)) !FlowMultiplierTypeId %in% new$FlowMultiplierTypeId else TRUE,
                     intersect(names(x), c("Timestep", "FlowGroupId", "FlowMultiplierTypeId", "MultiplierFileName")), with = FALSE]
  write_stsim(rbind(x, new, fill = TRUE), "FlowSpatialMultiplier")
  say("Flow Spatial Multipliers: %s written (%d other rows kept)", paste(new$FlowMultiplierTypeId, collapse = ", "), nrow(x))
  # (an output sheet reads back empty until the stage ends, so the rows cannot be checked here; tests/unit-agriculture.R checks the
  # code path, and a run's result holds them)
  check(STAGE, "each productivity multiplier has one Flow Spatial Multiplier row a year and flow group", !anyDuplicated(new[, .(if ("Timestep" %in% names(new)) Timestep else NA, FlowGroupId, FlowMultiplierTypeId)]) && all(file.exists(new$MultiplierFileName))) }
# ---- Site Productivity (Build Options; to-do 35, docs/treemap-plan.md) ------------------------------------------------------
# A forest cell's growth multiplier = sum over FIA site classes of the share of its TreeMap pixels in the class (stage 5) x its forest
# type x ecodivision's multiplier for the class (stage 2). It becomes the Site Productivity flow spatial multiplier on forest growth,
# which multiplies with the Climate one in each cell, so the cell's live carbon follows m x its curve. Its starting live and dead
# carbon are scaled by m too (their inputs all come from live carbon and decay is first order); the deep soil (belowground slow,
# calibrated to gNATSGO) is not. Every other land cell, forest without TreeMap pixels included, takes the multiplier of the forest
# cells near it (src/productivity-fill.R; 2026-11-07), so a cell that becomes forest during a run grows like the forest around it.
spv <- opt$SiteProductivity[1]
site_on <- !is.null(spv) && !is.na(spv) && (identical(suppressWarnings(as.integer(spv)), 2L) || startsWith(as.character(spv), "TreeMap"))
if (site_on) {
  shs <- as.data.table(datasheet(scn, ds("OutputSiteClassMap"), optional = TRUE))
  spm <- as.data.table(datasheet(scn, ds("OutputSiteProductivity"), optional = TRUE, lookupsAsFactors = FALSE))
  if (nrow(shs) != 7) fail("Site Productivity: no site class shares - run stage 5 with Site Productivity on (same pipeline)")
  if (!nrow(spm)) fail("Site Productivity: no multipliers - run stage 2 with Site Productivity on (same pipeline)")
  if (!"Site Productivity" %in% stsim_list("FlowMultiplierType")$Name) fail("Site Productivity: the library has no Flow Multiplier Type 'Site Productivity' - run tools/sync-library.R on it")
  # the share maps sit in this result's folder, or in a dependency's when only stage 8 is rerun
  fpath <- function(fn) { if (file.exists(fn)) return(fn)
    p <- file.path(paste0(main_library(), ".data"), sprintf("Scenario-%d", c(scenarioId(scn), run_dependencies())), ds("OutputSiteClassMap"), basename(fn))
    if (any(file.exists(p))) p[file.exists(p)][1] else fail("Site Productivity: site class share map %s not found", basename(fn)) }
  X <- values(rast(vapply(shs[order(SiteClass), FileName], fpath, "")), mat = TRUE)
  wk <- dcast(spm, StratumId + StateClassId ~ SiteClass, value.var = "Multiplier")
  M <- as.matrix(wk[match(paste(sname, cname), paste(wk$StratumId, wk$StateClassId)), as.character(1:7), with = FALSE])
  has <- rowSums(!is.na(X)) > 0 & !is.na(M[, 1])
  mult <- rep(1, ncell(P)); use <- isF & has; mult[use] <- rowSums(X[use, , drop = FALSE] * M[use, , drop = FALSE], na.rm = TRUE)
  fl <- fill_multiplier(P, mult, use, land & !use); mult <- fl$mult
  check(STAGE, "site productivity: every land cell's multiplier is finite and within 0.3-2.5", all(is.finite(mult[land]) & mult[land] >= 0.3 - 1e-9 & mult[land] <= 2.5 + 1e-9))
  bgs0 <- which(st$StockTypeId == "DOM: Belowground Slow")
  out[isF, -bgs0] <- out[isF, -bgs0] * mult[isF]
  qs <- stats::quantile(mult[isF], c(0.1, 0.5, 0.9))
  say("Site productivity: forest cells' growth multiplier mean %.2f (10%% %.2f, median %.2f, 90%% %.2f); %.1f%% of forest cells have no TreeMap pixels (%.1f%% of them filled from nearby forest); their starting live and dead carbon scaled the same way",
      mean(mult[isF]), qs[1], qs[2], qs[3], 100 * mean(!has[isF]), if (any(isF & !has)) 100 * mean(fl$filled[isF & !has]) else 0)
  say("Site productivity: %.1f%% of the other land cells filled from forest within 10 km of the same ecodivision (mean %.2f); the rest keep 1",
      100 * mean(fl$filled[land & !isF]), if (any(fl$filled[land & !isF])) mean(mult[land & !isF & fl$filled]) else 1)
  fg <- "Net Growth Forest: Total"; if (!fg %in% stsim_list("FlowGroup")$Name) fail("Site Productivity: flow group '%s' not found", fg)
  put_multiplier("Site Productivity", fg, write_raster(setValues(rast(P), ifelse(land, mult, NA)), "SiteProductivity.tif", "FLT4S"))
}
# class tables: by class (and age for forested wetland, and ecodivision where the table has a StratumID column)
lt <- function(f) { x <- read_default("initialstocks", f); setnames(x, gsub("ID$", "Id", names(x)))
  x[, `:=`(Value = as.numeric(Value), AgeMin = suppressWarnings(as.integer(AgeMin)))][StateAttributeTypeId %in% st$Attribute] }
fill_class <- function(tab, cells, by_age = FALSE, label) {
  if (!any(cells)) return(invisible())
  by_eco <- "StratumId" %in% names(tab)
  w <- dcast(tab, as.formula(paste(paste(c(if (by_eco) "StratumId", "StateClassId", if (by_age) "AgeMin"), collapse = " + "), "~ StateAttributeTypeId")), value.var = "Value", fun.aggregate = sum)
  k <- paste(if (by_eco) sname[cells] else "", cname[cells], if (by_age) pmin(pmax(round(vA[cells]), 0), max(w$AgeMin)) else "")
  mm <- match(k, paste(if (by_eco) w$StratumId else "", w$StateClassId, if (by_age) w$AgeMin else ""))
  check(STAGE, sprintf("every %s cell finds its class in the table", label), !anyNA(mm), sprintf("%d unmatched (%s)", sum(is.na(mm)), paste(head(unique(k[is.na(mm)]), 3), collapse = "; ")))
  for (j in seq_len(nrow(st))) if (st$Attribute[j] %in% names(w)) out[which(cells)[!is.na(mm)], j] <<- w[[st$Attribute[j]]][mm[!is.na(mm)]]
  src_of[cells] <<- label }
wf_cls <- unique(lt("wetland-forested-fire.csv")$StateClassId)
isWF <- land & cname %in% wf_cls
fill_class(lt("wetland-forested-fire.csv"), isWF & postfire, TRUE, "forested wetland (post-fire)")
fill_class(lt("wetland-forested-harvest.csv"), isWF & !postfire, TRUE, "forested wetland (post-harvest)")
gs <- lt("grassland-shrubland.csv"); fill_class(gs, land & cname %in% unique(gs$StateClassId), FALSE, "grassland/shrubland")
# chaparral by ecodivision and age (years since fire, from stage 5; to-do 39): the pools after a high-severity fire grown on that long
cp <- lt("chaparral.csv"); fill_class(cp, land & cname %in% unique(cp$StateClassId), TRUE, "chaparral (by age since fire)")
ew <- lt("emergent-wetland.csv"); fill_class(ew, land & cname %in% unique(ew$StateClassId), FALSE, "emergent wetland")
# cropland and pasture by ecodivision (to-do 39 step 6): the steady state of stage 3's rates (tools/make_agriculture.R); soil the class
# mean under the class (gNATSGO), as grass and shrub
ag <- lt("agriculture.csv"); fill_class(ag, land & cname %in% unique(ag$StateClassId), FALSE, "agriculture")
src_of[land & is.na(src_of)] <- "zero (developed, barren, water, ice)"
# ---- Grass and Shrub Productivity (Build Options; to-do 39 step 5) ---------------------------------------------------------
# The grass and shrub counterpart of Site Productivity: a cell's growth multiplier = its RAP herbaceous + shrub NPP (mean of
# RAP_YEARS, the years the class targets were sampled from) / its ecodivision x class target NPP (defaults/stockflow/
# grass-shrub-targets.csv, the NPP its growth rows hold; tools/make_grass_shrub.R). As in the targets, 30 m pixels RAP sees as mostly
# trees (tree NPP > herb + shrub) are left out; a cell with none left keeps 1, and the multiplier is capped at 0.3-2.5 as forest's
# is. It becomes the Grass and Shrub Productivity flow spatial multiplier on Net Growth Non Forest: Total (it multiplies with the
# Climate one), and the cell's starting live and dead carbon are scaled by it (inputs all come from growth, decay is first order);
# its soil (BG Slow and Deep Soil) keeps the class mean, as forest's does (user, 2026-11-07). Every other land cell, and a grass or
# shrub cell without RAP pixels, takes the multiplier of the grass and shrub cells near it (src/productivity-fill.R), cells at the
# 0.3 floor (RAP sees them nearly bare: fallow or graded land mapped as grass) not passed on.
gpv <- opt$GrassShrubProductivity[1]
gs_on <- !is.null(gpv) && !is.na(gpv) && (identical(suppressWarnings(as.integer(gpv)), 2L) || startsWith(as.character(gpv), "RAP"))
if (gs_on) {
  RAP_YEARS <- 2014:2023; CAP <- c(0.3, 2.5)
  if (!"Grass and Shrub Productivity" %in% stsim_list("FlowMultiplierType")$Name) fail("Grass and Shrub Productivity: the library has no Flow Multiplier Type 'Grass and Shrub Productivity' - run tools/sync-library.R on it")
  rap <- read_data_sources("RapNppFolder")$RapNppFolder
  rf <- file.path(rap, sprintf("rap-npp-v3-%d.tif", RAP_YEARS)); miss <- RAP_YEARS[!file.exists(rf)]
  if (length(miss)) fail("Grass and Shrub Productivity: RAP NPP Folder (%s) lacks %s; run a Data Download with RapNppFolder for years %d-%d", rap, paste(miss, collapse = ", "), min(RAP_YEARS), max(RAP_YEARS))
  tg <- read_default("stockflow", "grass-shrub-targets.csv")[, NPP := as.numeric(NPP)]
  isGS <- land & cname %in% unique(tg$StateClassId)
  # the 30 m mean over the years, herb + shrub, treed pixels out, then each cell's mean of the pixels left
  r0 <- rast(rf[1]); win <- project(as.polygons(ext(P) + 1000, crs = crs(P)), crs(r0))
  acc <- NULL; for (f in rf) { r <- classify(crop(rast(f), win, snap = "out"), cbind(65535, NA)); acc <- if (is.null(acc)) r else acc + r }
  acc <- acc / length(rf) / 1000   # Mg C/ha/yr
  herb <- acc[[1]] + acc[[2]] + acc[[3]]; herb <- mask(herb, acc[[4]] > herb, maskvalues = 1)
  vN <- values(project(herb, P, method = "average"), mat = FALSE)
  tnpp <- tg$NPP[match(paste(sname, cname), paste(tg$StratumId, tg$StateClassId))]
  gmult <- rep(1, ncell(P)); use <- isGS & !is.na(vN) & !is.na(tnpp) & tnpp > 0
  gmult[use] <- pmin(pmax(vN[use] / tnpp[use], CAP[1]), CAP[2])
  gfl <- fill_multiplier(P, gmult, use & gmult > CAP[1] + 1e-9, land & !use); gmult <- gfl$mult
  check(STAGE, "grass and shrub productivity: every land cell's multiplier is finite and within 0.3-2.5", all(is.finite(gmult[land]) & gmult[land] >= CAP[1] - 1e-9 & gmult[land] <= CAP[2] + 1e-9))
  soilj <- which(st$StockTypeId %in% c("DOM: Belowground Slow", "Deep Soil"))
  out[isGS, -soilj] <- out[isGS, -soilj] * gmult[isGS]
  gsum <- data.table(cls = cname[isGS], m = gmult[isGS], has = use[isGS])[, .(Cells = .N, NoRap = round(100 * mean(!has), 1), Mean = round(mean(m), 2),
            P10 = round(quantile(m, 0.1), 2), P90 = round(quantile(m, 0.9), 2), Capped = round(100 * mean(m <= CAP[1] + 1e-9 | m >= CAP[2] - 1e-9), 1)), by = cls][order(-Cells)]
  say("Grass and shrub productivity (RAP NPP %d-%d): %d cells, multiplier mean %.2f; %.1f%% have no RAP pixels left (filled from nearby grass and shrub); their starting live and dead carbon scaled the same way",
      min(RAP_YEARS), max(RAP_YEARS), sum(isGS), mean(gmult[isGS]), 100 * mean(!use[isGS]))
  for (i in seq_len(nrow(gsum))) with(gsum[i], say("  %s: %d cells, mean %.2f (10%% %.2f, 90%% %.2f), %.1f%% without RAP, %.1f%% at the cap", cls, Cells, Mean, P10, P90, NoRap, Capped))
  say("Grass and shrub productivity: %.1f%% of the other land cells filled from grass and shrub within 10 km of the same ecodivision (mean %.2f); the rest keep 1",
      100 * mean(gfl$filled[land & !isGS]), if (any(gfl$filled[land & !isGS])) mean(gmult[land & !isGS & gfl$filled]) else 1)
  fg <- "Net Growth Non Forest: Total"; if (!fg %in% stsim_list("FlowGroup")$Name) fail("Grass and Shrub Productivity: flow group '%s' not found", fg)
  put_multiplier("Grass and Shrub Productivity", fg, write_raster(setValues(rast(P), ifelse(land, gmult, NA)), "GrassShrubProductivity.tif", "FLT4S"))
}
# ---- Cropland Productivity (Build Options; to-do 39 step 6, user 2026-11-07) -------------------------------------------------
# The agriculture counterpart: each 30 m Cropland Data Layer pixel of CDL_YEARS takes its county's NASS growth of its crop group
# (defaults/stockflow/ag-county-crop-npp.csv: the 1985-2023 mean, yields converted with USDA Tech. Bull. 1939 coefficients;
# tools/make_agriculture.R), else the county's ecodivision's (ag-ecodivision-crop-npp.csv), else the group's CONUS mean; a double
# crop takes both crops' growth; fallow and idle cropland counts 0 (NASS yields are per harvested acre, NLCD cropland includes
# fallow); classes NASS does not survey (vegetables, fruit and nuts, vineyards, grassland/pasture, non-crop land) are left out
# (defaults/stockflow/cdl-crops.csv; user 2026-11-07); in California, tomatoes, vegetables, tree fruit, tree nuts and grapes take the
# county's growth from the County Agricultural Commissioners' reports (ag-cac-county-crop-npp.csv; user 2026-11-08). A cell's growth is
# the mean over its pixels and years; its multiplier = that / the ecodivision x class growth the rows hold (ag-targets.csv NPP; user
# 2026-11-08: county scale, so each cell grows at its own crops' county rates; it was the CDL estimate's ecodivision mean, which
# raised Solano's cropland by 1.46), capped at 0.3-2.5 as the other productivity multipliers. It becomes the Cropland Productivity flow spatial multiplier on Net Growth Agriculture: Total (it multiplies with
# Crop Yield and CO2), and the cell's starting litter is scaled by it (soil keeps the class mean). Cropland and pasture cells
# without surveyed crops, and every other land cell (for land that becomes agriculture), take the multiplier of the agriculture
# cells near it (src/productivity-fill.R).
# Crop Harvest (user 2026-11-08), on Harvest: Agriculture: the cell's harvested share of aboveground growth (the sum over its pixels
# and years of each crop's county harvest / its aboveground growth) / the ecodivision x class harvest rate the rows hold
# (nonforest-multipliers-agriculture.csv), capped at 0.3-2.5 and so the rate stays <= 1; filled as Cropland Productivity.
cpv <- opt$CropProductivity[1]
cp_on <- !is.null(cpv) && !is.na(cpv) && (identical(suppressWarnings(as.integer(cpv)), 2L) || startsWith(as.character(cpv), "CDL"))
if (cp_on) {
  CDL_YEARS <- 2014:2025; CAP <- c(0.3, 2.5); AGC <- c("Agriculture: Cropland", "Agriculture: Pasture")
  if (!"Cropland Productivity" %in% stsim_list("FlowMultiplierType")$Name) fail("Cropland Productivity: the library has no Flow Multiplier Type 'Cropland Productivity' - run tools/sync-library.R on it")
  cs <- read_data_sources(c("CdlFolder", "CountiesFile"))
  cf <- file.path(cs$CdlFolder, sprintf("%d_30m_cdls.tif", CDL_YEARS)); miss <- CDL_YEARS[!file.exists(cf)]
  # a year the folder lacks is left out of the mean, with a warning (2026-11-07: the 2022 national zip would not download; 2026-11-08: the
  # user placed 2022, 2024 and 2025 in the folder - 2025 is NASS's nearest-neighbour 30 m version of its 10 m layer); none is an error
  if (length(miss) == length(CDL_YEARS)) fail("Cropland Productivity: Cropland Data Layer Folder (%s) has none of %d-%d; run a Data Download with CdlFolder", cs$CdlFolder, min(CDL_YEARS), max(CDL_YEARS))
  if (length(miss)) { say("Cropland Productivity: WARNING - the Cropland Data Layer Folder lacks %s; the map averages the other %d years", paste(miss, collapse = ", "), length(CDL_YEARS) - length(miss)); cf <- cf[file.exists(cf)] }
  source(pkg_file("src", "cropland.R"))
  xw <- read_default("stockflow", "cdl-crops.csv"); cg <- read_default("stockflow", "ag-county-crop-npp.csv"); eg <- read_default("stockflow", "ag-ecodivision-crop-npp.csv")
  rg <- read_default("stockflow", "ag-cac-county-crop-npp.csv")
  if (!"Crop Harvest" %in% stsim_list("FlowMultiplierType")$Name) fail("Cropland Productivity: the library has no Flow Multiplier Type 'Crop Harvest' - run tools/sync-library.R on it")
  # the divisors: the ecodivision x class growth and harvest rate the agriculture rows hold
  cn <- read_default("stockflow", "ag-targets.csv")[, NPP := as.numeric(NPP)]
  hr <- read_default("stockflow", "nonforest-multipliers-agriculture.csv")[FlowGroupId == "Harvest: Foliage -> Agriculture Sector [Type]", .(StratumId, StateClassId, Rate = as.numeric(Value))]
  isAG <- land & cname %in% AGC
  r0 <- rast(cf[1]); win <- project(as.polygons(ext(P) + 1000, crs = crs(P)), crs(r0)); g30 <- crop(r0, win, snap = "out")
  # counties on the 30 m window, and each county's ecodivision (its most common one on the model grid) for the fallback
  co <- vect(cs$CountiesFile); co <- crop(project(co, crs(r0)), win); co$k <- seq_len(nrow(co))
  ck <- rasterize(co, g30, "k"); vC <- values(project(rasterize(co, P, "k"), P, method = "near"), mat = FALSE)
  ce <- data.table(k = vC, e = sname)[!is.na(k) & !is.na(e), .N, by = .(k, e)][order(-N)][, .SD[1], by = k]
  # every (county, CDL code) pair's growth (src/cropland.R), then each year's pixels averaged onto the model grid
  lk <- tryCatch(cdl_lookup(co$GEOID, ce$e[match(co$k, ce$k)], xw, cg, eg, rg), error = function(e) fail("Cropland Productivity: %s", conditionMessage(e)))
  acc <- matrix(0, ncell(P), 3); nyr <- rep(0, ncell(P))
  for (f in cf) { r30 <- crop(rast(f), win, snap = "out")
    vm <- values(project(c(cdl_npp(r30, ck, lk, "NPP"), cdl_npp(r30, ck, lk, "AG"), cdl_npp(r30, ck, lk, "Harvest")), P, method = "average"))
    ok <- !is.na(vm[, 1]); acc[ok, ] <- acc[ok, ] + vm[ok, ]; nyr <- nyr + ok }
  vN <- ifelse(nyr > 0, acc[, 1] / nyr, NA); vR <- ifelse(nyr > 0 & acc[, 2] > 0, acc[, 3] / acc[, 2], NA)
  tnpp <- cn$NPP[match(paste(sname, cname), paste(cn$StratumId, cn$StateClassId))]
  trate <- hr$Rate[match(paste(sname, cname), paste(hr$StratumId, hr$StateClassId))]
  cmult <- rep(1, ncell(P)); use <- isAG & !is.na(vN) & !is.na(tnpp) & tnpp > 0
  cmult[use] <- pmin(pmax(vN[use] / tnpp[use], CAP[1]), CAP[2])
  cfl <- fill_multiplier(P, cmult, use & cmult > CAP[1] + 1e-9, land & !use); cmult <- cfl$mult
  check(STAGE, "cropland productivity: every land cell's multiplier is finite and within 0.3-2.5", all(is.finite(cmult[land]) & cmult[land] >= CAP[1] - 1e-9 & cmult[land] <= CAP[2] + 1e-9))
  soilj <- which(st$StockTypeId %in% c("DOM: Belowground Slow", "Deep Soil"))
  out[isAG, -soilj] <- out[isAG, -soilj] * cmult[isAG]
  csum <- data.table(cls = cname[isAG], m = cmult[isAG], has = use[isAG])[, .(Cells = .N, NoCdl = round(100 * mean(!has), 1), Mean = round(mean(m), 2),
            P10 = round(quantile(m, 0.1), 2), P90 = round(quantile(m, 0.9), 2), Capped = round(100 * mean(m <= CAP[1] + 1e-9 | m >= CAP[2] - 1e-9), 1)), by = cls][order(-Cells)]
  say("Cropland productivity (CDL %d-%d x NASS county growth): %d cells, multiplier mean %.2f; %.1f%% have no surveyed crop pixels (filled from nearby cropland and pasture)",
      min(CDL_YEARS), max(CDL_YEARS), sum(isAG), mean(cmult[isAG]), 100 * mean(!use[isAG]))
  for (i in seq_len(nrow(csum))) with(csum[i], say("  %s: %d cells, mean %.2f (10%% %.2f, 90%% %.2f), %.1f%% without surveyed crops, %.1f%% at the cap", cls, Cells, Mean, P10, P90, NoCdl, Capped))
  say("Cropland productivity: %.1f%% of the other land cells filled from cropland and pasture within 10 km of the same ecodivision (mean %.2f); the rest keep 1",
      100 * mean(cfl$filled[land & !isAG]), if (any(cfl$filled[land & !isAG])) mean(cmult[land & !isAG & cfl$filled]) else 1)
  fg <- "Net Growth Agriculture: Total"; if (!fg %in% stsim_list("FlowGroup")$Name) fail("Cropland Productivity: flow group '%s' not found - run tools/sync-library.R", fg)
  put_multiplier("Cropland Productivity", fg, write_raster(setValues(rast(P), ifelse(land, cmult, NA)), "CroplandProductivity.tif", "FLT4S"))
  # Crop Harvest: the cell's harvested share of aboveground growth over the rate the rows hold
  hmult <- rep(1, ncell(P)); huse <- isAG & !is.na(vR) & !is.na(trate) & trate > 0
  hmult[huse] <- pmin(pmax(vR[huse] / trate[huse], CAP[1]), CAP[2], 1 / trate[huse])
  hfl <- fill_multiplier(P, hmult, huse, land & !huse); hmult <- hfl$mult
  check(STAGE, "crop harvest: every land cell's multiplier is finite and positive, and no agriculture cell harvests more than its foliage",
        all(is.finite(hmult[land]) & hmult[land] > 0) && all(is.na(trate[isAG]) | hmult[isAG] * trate[isAG] <= 1 + 1e-9))
  hsum <- data.table(cls = cname[isAG], m = hmult[isAG], r = hmult[isAG] * trate[isAG])[, .(Cells = .N, Mean = round(mean(m), 2), Rate = round(mean(r, na.rm = TRUE), 3),
            P10 = round(quantile(m, 0.1), 2), P90 = round(quantile(m, 0.9), 2)), by = cls][order(-Cells)]
  say("Crop harvest (CDL x county harvested share): %d cells, multiplier mean %.2f", sum(isAG), mean(hmult[isAG]))
  for (i in seq_len(nrow(hsum))) with(hsum[i], say("  %s: %d cells, mean %.2f (10%% %.2f, 90%% %.2f), harvested share of foliage %.3f", cls, Cells, Mean, P10, P90, Rate))
  hg <- "Harvest: Agriculture"; if (!hg %in% stsim_list("FlowGroup")$Name) fail("Crop Harvest: flow group '%s' not found - run tools/sync-library.R", hg)
  put_multiplier("Crop Harvest", hg, write_raster(setValues(rast(P), ifelse(land, hmult, NA)), "CropHarvest.tif", "FLT4S"))
  # Crop Mix (user 2026-11-08: vary the crop mix through time). The two maps above hold the crops of the CDL years; a California
  # county's yearly crop mix comes from the County Agricultural Commissioners' reports (ag-cac-county-crop-mix.csv: every crop at its
  # fixed county rate, so only the mix and harvested area change; dev/agriculture/06-cac-county-crop-mix.R). Growth multiplier of year y
  # = (the county's NPP / its cropland on the model's annual NLCD in y) / the same over CDL_YEARS; harvest multiplier = (harvest / AG in
  # y) / the same over CDL_YEARS. A year outside the reports takes the nearest one's; the year after the reports end is 1 (the maps'
  # mix). On every land cell of the county except NLCD pasture (81), which keeps 1, as does every cell outside California; the harvest
  # one is capped so the cell's rate stays <= 1. One map a year on Net Growth Agriculture: Total and on Harvest: Agriculture.
  mx <- read_default("stockflow", "ag-cac-county-crop-mix.csv")
  if (!"Crop Mix" %in% stsim_list("FlowMultiplierType")$Name) fail("Crop Mix: the library has no Flow Multiplier Type 'Crop Mix' - run tools/sync-library.R on it")
  nl <- read_ds("OutputNlcdAnnual"); vK <- vC   # the county (co row) of each model cell
  mx <- mx[GEOID %in% co$GEOID][, k := co$k[match(GEOID, co$GEOID)]][, c("NPP", "AG", "Harvest") := lapply(.SD, as.numeric), .SDcols = c("NPP", "AG", "Harvest")][, Year := as.integer(Year)]
  if (nrow(mx) && nrow(nl)) {
    y1 <- opt$EndYear[1]; yrs <- y0:y1; ny <- nl$Year[nl$Year %in% yrs]
    # each county's cropland area (cells) on the model's annual NLCD, years without a map taking the nearest year's
    ca <- rbindlist(lapply(ny, function(y) { v <- values(rast(nl$FileName[match(y, nl$Year)]), mat = FALSE)
      data.table(k = vK, v = v)[land & !is.na(k), .(crop = sum(v == 82, na.rm = TRUE)), by = k][, Year := y] }))
    near <- function(y, have) have[pmax(1, findInterval(y, have))]   # the nearest earlier year (the first year for earlier ones)
    grid <- CJ(k = unique(mx$k), Year = sort(unique(c(yrs, CDL_YEARS))))
    grid[, ry := { h <- sort(unique(mx$Year)); h[pmin(length(h), pmax(1, findInterval(Year, h)))] }]
    grid[, ny := near(Year, sort(ny))]
    grid <- merge(mx[, .(k, ry = Year, NPP, AG, Harvest)][grid, on = .(k, ry)], ca[, .(k, ny = Year, crop)], by = c("k", "ny"))
    grid <- grid[!is.na(NPP) & crop > 0][, `:=`(G = NPP / crop, S = Harvest / AG)]
    base <- grid[Year %in% CDL_YEARS & ry %in% CDL_YEARS, .(bG = mean(G), bS = sum(Harvest) / sum(AG)), by = k]
    grid <- base[grid, on = "k", nomatch = 0][, `:=`(iG = pmin(pmax(G / bG, CAP[1]), CAP[2]), iH = pmin(pmax(S / bS, CAP[1]), CAP[2]))]
    last <- max(mx$Year); myrs <- yrs[yrs <= last]
    rows <- list(); ones <- write_raster(setValues(rast(P), ifelse(land, 1, NA)), "CropMix_1.tif", "FLT4S")
    for (y in myrs) { g <- grid[Year == y]; if (!nrow(g)) next
      v <- values(rast(nl$FileName[match(near(y, sort(ny)), nl$Year)]), mat = FALSE)
      on <- land & !is.na(vK) & vK %in% g$k & !(v %in% 81)
      mG <- rep(1, ncell(P)); mH <- rep(1, ncell(P)); j <- match(vK[on], g$k)
      mG[on] <- g$iG[j]; hr1 <- hmult[on] * fifelse(is.na(trate[on]), 0, trate[on]); mH[on] <- pmin(g$iH[j], fifelse(hr1 > 0, 1 / hr1, Inf))
      rows[[length(rows) + 1]] <- data.table(Timestep = y, FlowGroupId = c(fg, hg), FlowMultiplierTypeId = "Crop Mix",
        MultiplierFileName = c(write_raster(setValues(rast(P), ifelse(land, mG, NA)), sprintf("CropMixGrowth_%d.tif", y), "FLT4S"),
                               write_raster(setValues(rast(P), ifelse(land, mH, NA)), sprintf("CropMixHarvest_%d.tif", y), "FLT4S"))) }
    if (length(rows)) {
      rows <- rbindlist(rows); rows <- rbind(rows, data.table(Timestep = last + 1, FlowGroupId = c(fg, hg), FlowMultiplierTypeId = "Crop Mix", MultiplierFileName = ones))
      put_multiplier("Crop Mix", rows = rows)
      s <- grid[Year %in% myrs, .(G = mean(iG), H = mean(iH)), by = .(p = fifelse(Year < min(CDL_YEARS), "before", "CDL years"))]
      say("Crop mix (County Agricultural Commissioners' reports, %d counties): %d-%d, growth multiplier mean %.2f before %d and %.2f in the CDL years, harvest %.2f and %.2f",
          uniqueN(grid$k), min(myrs), max(myrs), s[p == "before", G], min(CDL_YEARS), s[p == "CDL years", G], s[p == "before", H], s[p == "CDL years", H])
      check(STAGE, "crop mix: every map is finite and positive", all(is.finite(grid$iG) & grid$iG > 0 & is.finite(grid$iH) & grid$iH > 0))
    }
  } else say("Crop mix: no California county in the study area (or no annual NLCD table); no Crop Mix multiplier")
}
progressBar()
# ---- soil: gNATSGO where the class's belowground slow is 0 -----------------------------------------------------------------
So <- crop(rast(src$SoilCarbonFile), project(as.polygons(ext(P) + 3000, crs = crs(P)), crs(rast(src$SoilCarbonFile))))
So <- classify(So, cbind(-Inf, 0, NA), include.lowest = TRUE)   # 0 and the undeclared -1920 no-data value are missing (as stage 5)
vSo <- values(project(So, P, method = "average") * 0.01, mat = FALSE)
bgs <- which(st$StockTypeId == "DOM: Belowground Slow"); sub_ <- land & out[, bgs] == 0 & !is.na(vSo)
out[sub_, bgs] <- vSo[sub_]
say("Soil: gNATSGO used for %d cells whose class has no belowground slow carbon (%s)", sum(sub_), paste(names(table(src_of[sub_])), collapse = ", "))
out[!land, ] <- NA
progressBar()
# ---- checks, summary, outputs -----------------------------------------------------------------------------------------
check(STAGE, "every land cell has every pool, none negative", !anyNA(out[land, ]) && all(out[land, ] >= 0), sprintf("%d NA, %d negative", sum(is.na(out[land, ])), sum(out[land, ] < 0, na.rm = TRUE)))
soil_j <- which(st$StockTypeId %in% c("DOM: Belowground Slow", "Deep Soil"))   # soil = BG Slow + Deep Soil
live <- grep("^Biomass", st$StockTypeId); dom <- setdiff(seq_len(nrow(st)), c(live, soil_j))
d <- data.table(S = vS, src = src_of, fire = postfire, live = rowSums(out[, live]), dom = rowSums(out[, dom]), soil = rowSums(out[, soil_j, drop = FALSE]))[land]
summ <- d[, .(Cells = .N, PostFire = round(mean(fire), 3), Live = round(mean(live), 1), Dom = round(mean(dom), 1), Soil = round(mean(soil), 1),
              TotalTg = round(sum(live + dom + soil) * cell_ha / 1e6, 2), Source = src[1]), by = S][order(-TotalTg)]
summ[, StateClassId := scl$Name[match(S, as.integer(scl$Id))]]
tot <- d[, sum(live + dom + soil)] * cell_ha / 1e9
say("Initial carbon: %.2f Pg C (live %.2f, dead organic matter %.2f, soil %.2f); forest mean live %.0f, DOM %.0f, soil %.0f Mg C/ha",
    tot, sum(d$live) * cell_ha / 1e9, sum(d$dom) * cell_ha / 1e9, sum(d$soil) * cell_ha / 1e9,
    mean(d[!is.na(S) & S >= 100, live]), mean(d[!is.na(S) & S >= 100, dom]), mean(d[!is.na(S) & S >= 100, soil]))
files <- vapply(seq_len(nrow(st)), function(j) write_raster(setValues(rast(P), out[, j]), sprintf("%s.tif", gsub("[^A-Za-z0-9]+", "-", st$StockTypeId[j])), "FLT4S"), "")
write_stsim(data.table(StockTypeId = st$StockTypeId, RasterFileName = files), "InitialStockSpatial")
put_multipliers_save()
keep_ic_properties(scn, ic, 8)
write_ds(summ[, .(StateClassId, Cells, PostFire, Live, Dom, Soil, TotalTg, Source)], "OutputInitialStockSummary")
progressBar()
finish_checks()
progressBar(type = "end")
