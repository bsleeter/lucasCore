# =============================================================================
# 3-carbon-flows.R - stage 3: stock-flow parameters (net growth, growth split, turnover, DOM decay) and the full flow configuration
# =============================================================================
# Replaces lucasbuilder's "2 - Generate Flow Pathways" (2-flow-pathways.R) for forest state classes, driven by the stage 2 FIA carbon
# curves (src/flows.R explains each piece and which inputs are US and which are CBM). Non-forest classes (grassland, shrubland,
# wetland, developed) and the transition-triggered event flows are the LUCAS defaults in defaults/stockflow (from the CONUS 1km
# model). The fixed definitions (flow pathway diagram, flow order, groups, output options) come from the 'Stock-Flow Definitions'
# scenario that tools/new-library.R creates: a stage 3 scenario depends on it (and on a stage 2 result, or runs after stage 2).
# Carbon Options picks the dead organic matter decay: measured dead wood (default from 2026-10-27, to-do 19; docs/dom-calibration-
# proposal.md: FIA down woody material in mature stands, regional snag / down log / fine woody debris decay, litter and duff per forest
# type, snag fall from remeasured dead trees, fire as the spin-up's last disturbance), calibrated to FIA condition pools (snags, down
# wood, floor; the earlier default), FIA condition pools with CBM-default soil, or CBM defaults throughout (the CONUS 1km build's way).
# The measured and condition-pool calibrations fit soil to gSSURGO; every option logs spin-up soil against it. High-severity fire and
# clearcut flows come from Carbon Assumptions: Disturbance Flows, and fire's snag share per forest type from Fire Snag Share (else the
# package defaults), written as event rows whatever the option.
# Needs the Live-Tree Carbon Curves of stage 2 (same pipeline, or a dependency on a stage 2 result).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "growth.R")); source(pkg_file("src", "flows.R")); source(pkg_file("src", "dom.R")); source(pkg_file("src", "calibrate.R")); source(pkg_file("src", "fia.R"))
suppressPackageStartupMessages({ library(terra); library(sf) })
STAGE <- "3 Carbon Flows"
progressBar(type = "begin", totalSteps = 6)

src <- read_data_sources(c("EcodivisionFile", "PrismFolder"))
gopt <- as.list(read_ds("GrowthOptions"))
cbm <- pkg_file("defaults", "cbm")
if (!nrow(datasheet(scn, "stsim_FlowPathwayDiagram", optional = TRUE)))
  fail("no Flow Pathway Diagram: make this scenario depend on the 'Stock-Flow Definitions' scenario that tools/new-library.R creates")
cc <- as.data.table(datasheet(scn, ds("CarbonCurve"), optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(cc)) fail("Live-Tree Carbon Curves are empty: run stage 2 first (same pipeline, or depend on a stage 2 result)")
setnames(cc, c("StratumId", "StateClassId"), c("Stratum", "StateClass"))
gi <- read_growth_inputs(); cw <- gi$cw; dens <- gi$dens   # Carbon Assumptions: Growth Inputs over the package defaults
scl <- stsim_list("StateClass"); stl <- stsim_list("Stratum")
cw[, StateClass := scl$Name[match(StateClassId, scl$Id)]][, softwood := grepl("Softwood$", LagClass)]
cw[, deciduous := as.numeric(dens$DeciduousShare[match(StateClassId, dens$StateClassId)])]
if (anyNA(cw$deciduous)) fail("Growth Inputs / merch-carbon-density.csv has no DeciduousShare for some state classes")
say("Carbon curves: %d cells x %d ages", uniqueN(cc[, .(Stratum, StateClass)]), uniqueN(cc$Age))

# ecodivision mean annual temperature (PRISM normals) for DOM decay
clim <- ecodiv_climate(src$EcodivisionFile, src$PrismFolder)
eco <- unique(data.table(ecodiv = as.character(st_drop_geometry(read_sf(src$EcodivisionFile))$ecodiv),
                         StratumId = as.integer(st_drop_geometry(read_sf(src$EcodivisionFile))$StrtmId)))
eco[, Stratum := stl$Name[match(StratumId, as.integer(stl$Id))]][, temp := clim$mat[match(ecodiv, clim$ecodiv)]]
eco <- eco[!is.na(Stratum)]
say("Ecodivision mean annual temperature (PRISM): %s", paste(sprintf("%s %.1f C", eco$ecodiv, eco$temp), collapse = ", "))
progressBar()

# ---- 3b: calibrate DOM decay (src/calibrate.R): snags, down wood, forest floor to FIA; soil to gSSURGO ----------------------
# Carbon Assumptions - Decay Calibration Settings (to-do 18): each blank value = the default here
CAL <- list(mature_age = 60L, exclusion = 30L, min_dwm = 30L, min_snags = 200L, min_plots_cell = 200L, mult_min = 0.05, mult_max = 20, soil_min = 0.02, soil_max = 50)
CAL_COLS <- c(mature_age = "MatureAge", exclusion = "ExclusionYears", min_dwm = "MinPlotsOwnFit", min_snags = "MinSnagsOwnRate", min_plots_cell = "MinPlotsConditionPools",
              mult_min = "MultiplierMin", mult_max = "MultiplierMax", soil_min = "SoilMultiplierMin", soil_max = "SoilMultiplierMax")
cs <- as.data.table(datasheet(scn, ds("DecayCalibrationSetting"), optional = TRUE, lookupsAsFactors = FALSE)); cal_user <- character()
if (nrow(cs)) for (k in names(CAL_COLS)) { v <- if (CAL_COLS[[k]] %in% names(cs)) suppressWarnings(as.numeric(cs[[CAL_COLS[[k]]]][1])) else NA
  if (!is.na(v)) { CAL[[k]] <- if (is.integer(CAL[[k]])) as.integer(v) else v; cal_user <- c(cal_user, sprintf("%s %s", CAL_COLS[[k]], v)) } }
if (CAL$mult_min >= CAL$mult_max || CAL$soil_min >= CAL$soil_max) fail("Decay Calibration Settings: each multiplier minimum must be below its maximum (decay %g-%g, soil %g-%g)", CAL$mult_min, CAL$mult_max, CAL$soil_min, CAL$soil_max)
say("Decay Calibration Settings: %s", if (length(cal_user)) paste("from Carbon Assumptions:", paste(cal_user, collapse = ", ")) else "the defaults")
MIN_PLOTS_CELL <- CAL$min_plots_cell
MEAS_MIN_AGE <- CAL$mature_age; MIN_DWM_CELL <- CAL$min_dwm   # measured calibration: mature stand age; mature DWM conditions for an ecodivision's own fit
# Carbon Assumptions - Mature Age by Forest Type (to-do 28): per forest type (optionally one ecodivision) the mature age and disturbance-free
# window of the measured calibration's target plots; types without a row keep the single values above
ma <- as.data.table(datasheet(scn, ds("MatureAge"), optional = TRUE, lookupsAsFactors = FALSE)); MA_BY <- NULL
if (nrow(ma)) {
  ma[, `:=`(StratumId = as.character(StratumId), StateClassId = as.character(StateClassId), MatureAge = as.integer(MatureAge),
            ExclusionYears = if ("ExclusionYears" %in% names(ma)) as.integer(ExclusionYears) else NA_integer_)]
  if (anyDuplicated(ma[, .(StratumId, StateClassId)])) fail("Mature Age by Forest Type: more than one row for the same forest type and ecodivision")
  ma[, sc := cw$StateClassId[match(StateClassId, cw$StateClass)]][, ecodiv := eco$ecodiv[match(StratumId, eco$Stratum)]]
  bad <- ma[is.na(sc), unique(StateClassId)]; if (length(bad)) fail("Mature Age by Forest Type: %s is not a forest type with growth inputs", paste(bad, collapse = ", "))
  bad <- ma[!is.na(StratumId) & is.na(ecodiv), unique(StratumId)]; if (length(bad)) fail("Mature Age by Forest Type: ecodivision %s is not in this build", paste(bad, collapse = ", "))
  MA_BY <- ma[, .(sc, ecodiv, age = MatureAge, recent = data.table::fcoalesce(ExclusionYears, as.integer(CAL$exclusion)))]
  say("Mature Age by Forest Type: %d rows from Carbon Assumptions: %s; other types mature from %d yr, no fire or cutting within %d yr", nrow(ma),
      paste(sprintf("%s%s %d yr (no fire or cutting within %d)", ifelse(is.na(ma$StratumId), "", paste0(ma$StratumId, " / ")), sub("^Forest: ", "", ma$StateClassId), MA_BY$age, MA_BY$recent), collapse = "; "),
      CAL$mature_age, CAL$exclusion)
} else say("Mature Age by Forest Type: no rows - every forest type mature from %d yr", CAL$mature_age)
cells <- unique(cc[, .(Stratum, StateClass)])
miss <- setdiff(cells$StateClass, cw$StateClass); if (length(miss)) fail("carbon curves for state classes not in the forest crosswalk: %s", paste(miss, collapse = ", "))
cells[, sc := cw$StateClassId[match(StateClass, cw$StateClass)]][, ecodiv := eco$ecodiv[match(Stratum, eco$Stratum)]][, temp := eco$temp[match(Stratum, eco$Stratum)]]
# Carbon Assumptions - CBM Crosswalk (to-do 21): each cell's CBM ecozone and species type (live turnover and snag rates) and an optional
# mean temperature replacing PRISM's; a row for the cell's ecodivision overrides the forest type's blank-ecodivision row. An empty
# sheet (no Carbon Assumptions dependency) = the package default, defaults/cbm/species-crosswalk.csv.
cbx <- as.data.table(datasheet(scn, ds("CbmCrosswalk"), optional = TRUE, lookupsAsFactors = FALSE))
cbx_def <- read_default("cbm", "species-crosswalk.csv")[, .(StratumId = NA_character_, StateClassId, CbmEcozoneId = EcoBoundaryId, CbmSpeciesTypeId = SpeciesTypeId, MeanTemperature = NA_real_)]
if (!nrow(cbx)) { cbx <- cbx_def; say("CBM Crosswalk: none in this scenario (no Carbon Assumptions dependency) - the package default (%d forest types)", nrow(cbx))
} else {
  cbx <- cbx[, .(StratumId = as.character(StratumId), StateClassId, CbmEcozoneId, CbmSpeciesTypeId, MeanTemperature = as.numeric(MeanTemperature))]
  chg <- merge(cbx, cbx_def, by = c("StratumId", "StateClassId"), all.x = TRUE, suffixes = c("", "_def"))[
    is.na(CbmEcozoneId_def) | CbmEcozoneId != CbmEcozoneId_def | CbmSpeciesTypeId != CbmSpeciesTypeId_def | !is.na(MeanTemperature)]
  say("CBM Crosswalk: %d rows from Carbon Assumptions; %s", nrow(cbx), if (nrow(chg)) paste0("differing from the package default: ", paste(sprintf("%s%s -> %s, %s%s",
      ifelse(is.na(chg$StratumId), "", paste0(chg$StratumId, " / ")), sub("^Forest: ", "", chg$StateClassId), chg$CbmEcozoneId, chg$CbmSpeciesTypeId,
      ifelse(is.na(chg$MeanTemperature), "", sprintf(", %.1f C", chg$MeanTemperature))), collapse = "; ")) else "the package default") }
cbx_cell <- function(x) { own <- cbx[!is.na(StratumId)][x, on = .(StratumId = Stratum, StateClassId = StateClass), .(CbmEcozoneId, CbmSpeciesTypeId, MeanTemperature)]
  all <- cbx[is.na(StratumId)][x, on = .(StateClassId = StateClass), .(CbmEcozoneId, CbmSpeciesTypeId, MeanTemperature)]
  x[, `:=`(cbm_eco = data.table::fcoalesce(own$CbmEcozoneId, all$CbmEcozoneId), cbm_species = data.table::fcoalesce(own$CbmSpeciesTypeId, all$CbmSpeciesTypeId))]
  x[, temp_user := data.table::fifelse(!is.na(own$CbmEcozoneId), own$MeanTemperature, all$MeanTemperature)]   # the matched row's temperature
  x[!is.na(temp_user), temp := temp_user][, temp_user := NULL] }
cbx_cell(cells)
miss <- cells[is.na(cbm_eco) | is.na(cbm_species), unique(StateClass)]
if (length(miss)) fail("CBM Crosswalk (Carbon Assumptions) has no row for forest type(s) %s", paste(miss, collapse = ", "))
# Carbon Assumptions - Live Turnover (to-do 21): each value the user set, per cell - the ecodivision row's, else the forest type's
# all-ecodivisions row's (columns lt_<sheet column>; blank = the CBM Crosswalk's rates, src/flows.R turnover_rates)
lt <- as.data.table(datasheet(scn, ds("LiveTurnover"), optional = TRUE, lookupsAsFactors = FALSE)); LTC <- names(LIVE_TURNOVER_COLS)
if (nrow(lt)) {
  lt[, StratumId := as.character(StratumId)]; for (k in LTC) lt[, (k) := if (k %in% names(lt)) as.numeric(get(k)) else NA_real_]
  dup <- lt[duplicated(lt[, .(StratumId, StateClassId)])]; if (nrow(dup)) fail("Live Turnover: more than one row for %s", paste(unique(paste(dup$StratumId, dup$StateClassId)), collapse = "; "))
  own <- lt[!is.na(StratumId)][cells, on = .(StratumId = Stratum, StateClassId = StateClass), ..LTC]; all <- lt[is.na(StratumId)][cells, on = .(StateClassId = StateClass), ..LTC]
  for (k in LTC) cells[, (paste0("lt_", k)) := data.table::fcoalesce(own[[k]], all[[k]])]
  say("Live Turnover: %d rows from Carbon Assumptions: %s", nrow(lt), paste(sprintf("%s%s (%s)", ifelse(is.na(lt$StratumId), "", paste0(lt$StratumId, " / ")), sub("^Forest: ", "", lt$StateClassId),
      apply(lt[, ..LTC], 1, function(v) paste(sprintf("%s %s", LTC[!is.na(v)], v[!is.na(v)]), collapse = ", "))), collapse = "; "))
} else say("Live Turnover: no rows - every rate from the CBM Crosswalk (root turnover split 0.5 / 0.5)")
# return intervals and soil targets from stage 5 when this scenario has them (a stage 5 result upstream), else the provisional defaults
ri5 <- as.data.table(datasheet(scn, ds("OutputReturnInterval"), optional = TRUE, lookupsAsFactors = FALSE))
so5 <- as.data.table(datasheet(scn, ds("OutputSoilTarget"), optional = TRUE, lookupsAsFactors = FALSE))
ri_tab <- if (nrow(ri5)) ri5[, .(Stratum = StratumId, StateClass = StateClassId, ReturnInterval)] else read_default("spinup", "return-interval.csv")
soil_t <- if (nrow(so5)) so5[, .(Stratum = StratumId, StateClass = StateClassId, SoilTarget)] else read_default("spinup", "soil-targets.csv")
say("Return intervals: %s; soil targets: %s", if (nrow(ri5)) sprintf("stage 5 (%d cells)", nrow(ri5)) else "provisional defaults",
    if (nrow(so5)) sprintf("stage 5 (%d cells)", nrow(so5)) else "provisional defaults")
cells[, ri := as.numeric(ri_tab$ReturnInterval)[match(paste(Stratum, StateClass), paste(ri_tab$Stratum, ri_tab$StateClass))]]
cells[is.na(ri), ri := median(as.numeric(ri_tab[StateClass == .BY$StateClass, ReturnInterval])), by = StateClass]
cells[is.na(ri), ri := median(as.numeric(ri_tab$ReturnInterval))][, ri := as.integer(round(ri))]
cells[, ri_src := if (nrow(ri5)) "Stage 5 (LANDFIRE)" else "Provisional default"]
# Carbon Assumptions - Spin-up: return interval and the share of historical cycles ended by clearcut, per cell - the ecodivision row's
# value, else the forest type's all-ecodivisions row's (blank = the LANDFIRE interval above; share 0, all high-severity fire)
sp <- as.data.table(datasheet(scn, ds("Spinup"), optional = TRUE, lookupsAsFactors = FALSE)); SPC <- c("ReturnInterval", "HistoricalClearcutShare")
cells[, hist_cc := 0]
if (nrow(sp)) {
  sp[, StratumId := as.character(StratumId)]; for (k in SPC) sp[, (k) := if (k %in% names(sp)) as.numeric(get(k)) else NA_real_]
  dup <- sp[duplicated(sp[, .(StratumId, StateClassId)])]; if (nrow(dup)) fail("Spin-up: more than one row for %s", paste(unique(paste(dup$StratumId, dup$StateClassId)), collapse = "; "))
  own <- sp[!is.na(StratumId)][cells, on = .(StratumId = Stratum, StateClassId = StateClass), ..SPC]; all <- sp[is.na(StratumId)][cells, on = .(StateClassId = StateClass), ..SPC]
  u_ri <- data.table::fcoalesce(own$ReturnInterval, all$ReturnInterval); u_cc <- data.table::fcoalesce(own$HistoricalClearcutShare, all$HistoricalClearcutShare)
  cells[!is.na(u_ri), `:=`(ri = as.integer(round(u_ri[!is.na(u_ri)])), ri_src = "User (Carbon Assumptions: Spin-up)")]
  cells[!is.na(u_cc), hist_cc := u_cc[!is.na(u_cc)]]
  say("Spin-up: %d rows from Carbon Assumptions; return interval set for %d cells, historical clearcut share for %d cells", nrow(sp), sum(!is.na(u_ri)), sum(!is.na(u_cc)))
} else say("Spin-up: no rows - return intervals from %s, historical cycles all high-severity fire", cells$ri_src[1])
# Carbon Assumptions - Fixed Decay Multipliers (to-do 20): per cell and pool, the most specific row (ecodivision + forest type, ecodivision,
# forest type, blank) - columns fx_<pool>; forest floor fills fine woody debris, litter and duff where they are not set themselves
FX_POOLS <- c(snag = "Snags", cwd = "Down logs", fwd = "Fine woody debris", litter = "Litter", duff = "Duff", floor = "Forest floor", soil = "Soil")
fxd <- as.data.table(datasheet(scn, ds("FixedDecayMultiplier"), optional = TRUE, lookupsAsFactors = FALSE))
for (g in names(FX_POOLS)) cells[, (paste0("fx_", g)) := NA_real_]
if (nrow(fxd)) {
  fxd[, `:=`(StratumId = as.character(StratumId), StateClassId = as.character(StateClassId), Multiplier = as.numeric(Multiplier))]
  fxd[, g :=names(FX_POOLS)[ifelse(as.character(Pool) %in% FX_POOLS, match(as.character(Pool), FX_POOLS), suppressWarnings(as.integer(as.character(Pool))))]]
  if (anyNA(fxd$g)) fail("Fixed Decay Multipliers: unknown pool %s", paste(unique(fxd$Pool[is.na(fxd$g)]), collapse = ", "))
  if (anyDuplicated(fxd[, .(StratumId, StateClassId, g)])) fail("Fixed Decay Multipliers: more than one row for the same pool, ecodivision and forest type")
  fxd[, lvl := 2L * (!is.na(StratumId)) + (!is.na(StateClassId))]
  for (g0 in unique(fxd$g)) { x <- fxd[g == g0]
    v <- vapply(seq_len(nrow(cells)), function(i) { m <- x[(is.na(StratumId) | StratumId == cells$Stratum[i]) & (is.na(StateClassId) | StateClassId == cells$StateClass[i])]
      if (nrow(m)) m$Multiplier[which.max(m$lvl)] else NA_real_ }, numeric(1))
    cells[, (paste0("fx_", g0)) := v] }
  for (g in c("fwd", "litter", "duff")) cells[is.na(get(paste0("fx_", g))), (paste0("fx_", g)) := fx_floor]
  say("Fixed Decay Multipliers: %d rows from Carbon Assumptions; fixed in %s", nrow(fxd),
      paste(vapply(names(FX_POOLS), function(g) sprintf("%s %d cells", FX_POOLS[[g]], sum(!is.na(cells[[paste0("fx_", g)]]))), ""), collapse = ", "))
} else say("Fixed Decay Multipliers: no rows - every pool calibrated (or CBM default)")
cells[, soil_target := as.numeric(soil_t$SoilTarget)[match(paste(Stratum, StateClass), paste(soil_t$Stratum, soil_t$StateClass))]]
fx <- fia_tables(gopt, src$EcodivisionFile)   # Growth Curve Options: FIA Data (src/fia.R)
dat <- fia_dom_data(fx$cond, fx$dist, gopt, cw); rm(fx)
cells[, plots := dat$obs[, .(n = sum(n)), by = .(sc, ecodiv)][cells, on = c("sc", "ecodiv"), n]][is.na(plots), plots := 0L]
# the study area: calibrate and write flows only for its ecodivisions (every forest type in them, so a cell that changes type during a
# run still has flows). Each ecodivision x type is calibrated on its own FIA plots, so these values are the same as a CONUS build's;
# the forest-type fallback for cells with few plots stays pooled over every ecodivision of the type (all_cells). Only the soil
# multiplier of a cell with no gSSURGO target (a median over its type's cells) now comes from the study area's cells.
all_cells <- cells; study <- study_ecodivisions()
if (!is.null(study)) { cells <- cells[Stratum %in% study]
  say("Study area: %d of %d ecodivisions (%s): %d of %d ecodivision x forest type cells", length(study), uniqueN(all_cells$Stratum),
      paste(study, collapse = ", "), nrow(cells), nrow(all_cells)) }
say("Decay calibration: %d cells, %d with >= %d FIA plots (own fit), %d with a gSSURGO soil target; return intervals %d-%d yr",
    nrow(cells), cells[plots >= MIN_PLOTS_CELL, .N], MIN_PLOTS_CELL, cells[!is.na(soil_target), .N], min(cells$ri), max(cells$ri))
# Carbon Method (sheet CarbonOptions, on the Carbon Assumptions scenario): dead organic matter 4 = FIA measured dead wood (default from
# 2026-10-27, to-do 19; src/calibrate.R cal_fit_measured; needs the FIA DataMart Folder with the <ST>_COND_DWM_CALC tables), 3 = CBM
# defaults (no calibration - the CONUS 1km build's way); 1 and 2 (FIA condition pools, no longer offered, 2026-10-28) still run in older
# libraries. A pool that is not calibrated keeps multiplier 1. Soil organic carbon: 1 = soil decay calibrated to gSSURGO, 2 = CBM
# defaults; blank = gSSURGO with options 1 and 4, CBM with 2 and 3 (as before the choice existed).
copt <- read_ds("CarbonOptions"); dm <- copt$DeadOrganicMatterModel[1]
# (the sheet reads as its labels; option 2's label starts like option 1's, so it is tested first)
dom_mode <- if (is.null(dm) || is.na(dm)) 4L else if (is.numeric(dm)) as.integer(dm) else if (grepl("^(FIA measured|Measured)", dm)) 4L else
  if (grepl("^FIA (dead|condition) pools, CBM", dm)) 2L else if (grepl("^(Calibrated|FIA condition pools)", dm)) 1L else if (grepl("^CBM default", dm)) 3L else NA_integer_
if (is.na(dom_mode)) fail("Carbon Method: unrecognised Dead Organic Matter choice '%s'", dm)
sm0 <- if ("SoilCarbonModel" %in% names(copt)) copt$SoilCarbonModel[1] else NA
soil_mode <- if (is.null(sm0) || is.na(sm0)) (if (dom_mode %in% c(1L, 4L)) 1L else 2L) else if (is.numeric(sm0)) as.integer(sm0) else if (grepl("^gSSURGO", sm0)) 1L else if (grepl("^CBM", sm0)) 2L else NA_integer_
if (is.na(soil_mode)) fail("Carbon Method: unrecognised Soil Organic Carbon choice '%s'", sm0)
say("Carbon Method: dead organic matter = %s; soil organic carbon = %s", c("calibrated to FIA condition pools (snags, down wood, floor; older option)", "FIA condition pools (older option)",
    "CBM defaults (no calibration)", "FIA measured dead wood (down woody material and snags in mature stands; regional decay)")[dom_mode],
    c("soil decay calibrated to gSSURGO", "CBM defaults (from the spin-up)")[soil_mode])
# A Carbon Assumptions scenario nobody filled (made in Studio, the Fill button never pressed): CBM Crosswalk, Dead Organic Matter
# Parameters and Disturbance Flows all empty. Stage 3 then takes every sheet from the method's preset files (defaults/carbon-assumptions/
# <method>, tools/make_carbon_presets.R - the rows the Fill button writes). Once filled, an empty sheet means what it says (no fire snag
# shares, no fixed multipliers, no settings: defaults).
preset_dir <- pkg_file("defaults", "carbon-assumptions", if (dom_mode == 3L) "cbm-defaults" else "fia-measured")
preset <- function(sheet) fread(file.path(preset_dir, paste0(sheet, ".csv")), colClasses = "character", na.strings = "")
ca_filled <- any(vapply(c("CbmCrosswalk", "DomParameter", "DisturbanceFlow"), function(s) nrow(datasheet(scn, ds(s), optional = TRUE)) > 0, TRUE))
if (!ca_filled) say("Carbon Assumptions: the sheets are empty (never filled) - using the %s rows (%s)", c("", "", "CBM defaults", "FIA measured dead wood")[dom_mode], preset_dir)
# event flows: the LUCAS defaults (defaults/stockflow/event-pathways.csv), with high-severity fire and clearcut from Carbon Assumptions:
# Disturbance Flows when the scenario has rows (src/dom.R sheet_to_events: ecodivision rows expanded to every class, every specific row
# set given the younger age rows it hides), then each forest type's fire snag share (Carbon Assumptions: Fire Snag Share, else
# defaults/spinup/fire-snag-share.csv; src/dom.R fire_snag_rows). The spin-up uses the same table stage 3 writes to stsim_FlowPathway.
ev_def <- fread(pkg_file("defaults", "stockflow", "event-pathways.csv"), colClasses = "character", na.strings = "")[, FromStratumId := as.character(FromStratumId)]
dfl <- as.data.table(datasheet(scn, ds("DisturbanceFlow"), optional = TRUE, lookupsAsFactors = FALSE)); df_src <- "Carbon Assumptions"
if (!nrow(dfl)) { dfl <- preset("disturbance-flows"); df_src <- sprintf("the %s preset (the sheet is empty)", basename(preset_dir)) }
dfl[, `:=`(StratumId = as.character(StratumId), StateClassId = as.character(StateClassId), Disturbance = as.character(Disturbance),
           AgeMin = suppressWarnings(as.integer(AgeMin)), Share = as.numeric(Share))]
dfl[Disturbance %in% c("1", "2"), Disturbance := names(DF_GROUPS)[as.integer(Disturbance)]]
dup <- dfl[duplicated(dfl[, .(StratumId, StateClassId, Disturbance, AgeMin, FromStockTypeId, ToStockTypeId)])]
if (nrow(dup)) fail("Disturbance Flows: more than one row for %s", paste(unique(dup[, sprintf("%s %s -> %s%s", Disturbance, FromStockTypeId, ToStockTypeId,
                                                                                             ifelse(is.na(StateClassId), "", paste0(" (", StateClassId, ")")))]), collapse = "; "))
ev_all <- rbind(ev_def[!TransitionGroupId %in% DF_GROUPS], complete_ages(sheet_to_events(dfl, ev_def, scl$Name)), fill = TRUE)
# rows that differ from the method's preset (what the Fill button writes)
ky <- function(x) x[, paste(StratumId, StateClassId, Disturbance, AgeMin, FromStockTypeId, ToStockTypeId)]
d0 <- preset("disturbance-flows")[, `:=`(AgeMin = suppressWarnings(as.integer(AgeMin)), Share = as.numeric(Share))]; k0 <- ky(d0); k1 <- ky(dfl)
diff_row <- (!k1 %in% k0) | abs(dfl$Share - d0$Share[match(k1, k0)]) > 1e-9; diff_row[is.na(diff_row)] <- TRUE
lab <- dfl[diff_row, sprintf("%s%s%s%s %s -> %s %.4f", ifelse(k1[diff_row] %in% k0, "", "+ "), ifelse(is.na(StratumId), "", paste0(StratumId, " / ")),
                             ifelse(is.na(StateClassId), "", paste0(sub("^Forest: ", "", StateClassId), " ")), Disturbance, FromStockTypeId, ToStockTypeId, Share)]
say("Disturbance Flows: %d rows from %s; vs the %s preset %d changed or added (+), %d removed%s", nrow(dfl), df_src, basename(preset_dir), sum(diff_row), sum(!k0 %in% k1),
    if (length(lab)) paste0(": ", paste(head(lab, 12), collapse = "; "), if (length(lab) > 12) "; ..." else "") else "")
fsh <- as.data.table(datasheet(scn, ds("FireSnagShare"), optional = TRUE, lookupsAsFactors = FALSE))
if (!ca_filled) fsh <- preset("fire-snag-share")   # filled scenario: an empty sheet = no per-type shares
fss <- if (nrow(fsh)) fsh[, .(Stratum = if ("StratumId" %in% names(fsh)) as.character(StratumId) else NA_character_, StateClass = as.character(StateClassId), Share = as.numeric(Share))] else
  data.table(Stratum = character(), StateClass = character(), Share = numeric())
if (anyDuplicated(fss[, .(Stratum, StateClass)])) fail("Fire Snag Share: more than one row for a forest type and ecodivision")
ev_all <- fire_snag_rows(ev_all, fss)
say("High-severity fire snag share by forest type (%s): %s", if (ca_filled) "Carbon Assumptions" else paste("the", basename(preset_dir), "preset"),
    if (nrow(fss)) paste(sprintf("%s%s %.2f", ifelse(is.na(fss$Stratum), "", paste0(fss$Stratum, " / ")), sub("^Forest: ", "", fss$StateClass), fss$Share), collapse = ", ") else "none (the event table's rows for every type)")
eb <- event_balance(ev_all, cells)
check(STAGE, "high-severity fire and clearcut move at most each pool's whole stock", eb$v <= 1 + 1e-4, sprintf("largest share %.4f (%s)", eb$v, eb$what))
if (eb$v > 1 + 1e-4) finish_checks()   # rows are stored to 6 decimals
dpt <- read_dom_parameters()   # Carbon Assumptions: Dead Organic Matter Parameters (each cell resolves its ecodivision rows, src/flows.R dom_parameters)
ctx <- list(cc = cc, cw = cw, dens = dens, cbm = cbm, fo = fread(pkg_file("defaults", "stockflow", "stsim_FlowOrder.csv")), ev = ev_all, dpt = dpt, cal = CAL)
t0 <- Sys.time(); cl <- parallel::makeCluster(max(1, min(30, parallel::detectCores() - 1)))
parallel::clusterExport(cl, c("ctx", "dat", "cells", "all_cells"), envir = environment())
pkgdir <- env$PackageDirectory; parallel::clusterExport(cl, "pkgdir", envir = environment())
invisible(parallel::clusterEvalQ(cl, { library(data.table); for (f in c("flows.R", "dom.R", "calibrate.R")) source(file.path(pkgdir, "src", f)) }))
dw <- NULL
if (dom_mode == 4L) {
  dmf <- tryCatch(read_data_sources("FiaDataMartFolder")$FiaDataMartFolder, error = function(e) NA_character_)
  if (length(dmf) && !is.na(dmf) && nzchar(dmf) && dir.exists(dmf)) dw <- fia_dead_wood(dmf, fia_datamart(dmf, src$EcodivisionFile))
  if (is.null(dw)) fail("Carbon Method: FIA measured dead wood needs the FIA DataMart Folder (Data Sources) with the <ST>_COND_DWM_CALC.csv tables - set it, or choose CBM defaults")
}
fc <- ft <- list(); red <- numeric()
cells[, `:=`(snag_fall = NA_real_, SnagFallSource = NA_character_, mplots = NA_integer_, m_fwd = NA_real_, m_litter = NA_real_, m_duff = NA_real_)]
cells[, FireSnagShare := fss$Share[match(StateClass, fss$StateClass)]]
# a stem snag fall set in Live Turnover is used as given, ahead of the measured rate, in every option (fixed, not calibrated)
user_fall <- function(x) { if (!"lt_StemSnagFall" %in% names(x)) return(invisible(x))
  if (!"snag_fall" %in% names(x)) x[, `:=`(snag_fall = NA_real_, SnagFallSource = NA_character_)]
  x[!is.na(lt_StemSnagFall), `:=`(snag_fall = lt_StemSnagFall, SnagFallSource = "User (Carbon Assumptions: Live Turnover)")] }
user_fall(cells); user_fall(all_cells)
if (dom_mode == 4L) {
  # snag fall from remeasured standing dead trees: the cell's own rate with >= min_snags snags, else its forest type's, else all types'
  fr <- snag_fall_rates(dw, cw, CAL$min_snags)
  for (x in list(cells, all_cells)) {
    x[, c("own_n", "own_r") := fr$cell[x, on = c("sc", "ecodiv"), .(snags, rate)]][, c("typ_n", "typ_r") := fr$type[x, on = "sc", .(snags, rate)]]
    x[, `:=`(snag_fall = data.table::fcase(own_n >= fr$min_snags, own_r, typ_n >= fr$min_snags, typ_r, default = fr$all),
             SnagFallSource = data.table::fcase(own_n >= fr$min_snags, sprintf("Cell (%d snags)", own_n), typ_n >= fr$min_snags, sprintf("Forest type (%d snags)", typ_n), default = "All forest types"))]
    x[, c("own_n", "own_r", "typ_n", "typ_r") := NULL]; user_fall(x) }
  dat_m <- dwm_targets(dw, cw, MEAS_MIN_AGE, CAL$exclusion, MA_BY)
  for (x in list(cells, all_cells)) x[, mplots := dat_m$obs[x, on = c("sc", "ecodiv"), .(n = sum(n)), by = .EACHI]$n][is.na(mplots), mplots := 0L]
  say("Measured dead wood: %d down woody material conditions (%d states), %d mature (age >= %d, no fire or cutting in %d yr%s) in this build's types; snag fall from %d remeasured snags",
      nrow(dw$dwm), length(dw$states), sum(dat_m$obs$n), MEAS_MIN_AGE, CAL$exclusion, if (is.null(MA_BY)) "" else "; per forest type where set", nrow(dw$fall))
  # fits: each forest type pooled over its ecodivisions (the fallback), and each ecodivision over its types with enough plots (shared snag,
  # down log and fine woody debris multipliers; litter and duff per type)
  ecos <- unique(cells[mplots >= MIN_DWM_CELL, Stratum])   # the forest-type fallback only for types with a cell short of its own fit
  types <- unique(all_cells[sc %in% cells[!(Stratum %in% ecos & mplots >= MIN_DWM_CELL), sc] & mplots > 0, sc])
  parallel::clusterExport(cl, c("dat_m", "cells", "all_cells"), envir = environment())
  jobs <- c(lapply(types, function(s) list(kind = "type", rows = all_cells[sc == s & mplots > 0])), lapply(ecos, function(e) list(kind = "eco", rows = cells[Stratum == e & mplots >= MIN_DWM_CELL])))
  fits <- parallel::parLapply(cl, jobs, function(j) cal_fit_measured(j$rows, ctx, dat_m))
  ft <- stats::setNames(fits[seq_along(types)], types); fe <- stats::setNames(fits[length(types) + seq_along(ecos)], ecos)
  cells[, `:=`(Level = NA_character_, m_snag = NA_real_, m_cwd = NA_real_, m_floor = NA_real_, clearcut = NA_real_)]
  M5 <- c("snag", "cwd", "fwd", "litter", "duff"); setm <- function(i, v, lv) cells[i, `:=`(Level = lv, m_snag = v[["snag"]], m_cwd = v[["cwd"]], m_fwd = v[["fwd"]], m_litter = v[["litter"]], m_duff = v[["duff"]])]
  # a fit's value of pool g for a cell outside it: from a row where g was calibrated, not one the user fixed
  pick <- function(f, rows, gs) stats::setNames(lapply(gs, function(g) { j <- which(is.na(rows[[paste0("fx_", g)]]))[1]; f[[g]][if (is.na(j)) 1L else j] }), gs)
  for (i in seq_len(nrow(cells))) { e <- cells$Stratum[i]; s <- as.character(cells$sc[i]); tf <- if (s %in% names(ft)) pick(ft[[s]], jobs[[match(s, types)]]$rows, M5) else NULL
    if (e %in% names(fe)) { f <- fe[[e]]; rows <- jobs[[length(types) + match(e, ecos)]]$rows; j <- match(cells$sc[i], rows$sc)
      if (!is.na(j)) setm(i, as.list(f[j, ..M5]), "Ecodivision")
      else if (!is.null(tf)) setm(i, c(pick(f, rows, c("snag", "cwd", "fwd")), tf[c("litter", "duff")]), "Ecodivision; litter and duff by forest type")
    } else if (!is.null(tf)) setm(i, tf, "Forest type") }
  nod <- cells[is.na(Level), unique(StateClass)]
  if (length(nod)) say("No mature down woody material plots for %s: CBM-default decay", paste(nod, collapse = ", "))
  cells[is.na(Level), `:=`(Level = "CBM default (no FIA plots)", m_snag = 1, m_cwd = 1, m_fwd = 1, m_litter = 1, m_duff = 1)]
  # misfit reduction of every fit that calibrated something (a fit whose pools the user fixed throughout moves nothing)
  red <- unlist(lapply(seq_along(fits), function(j) { r <- jobs[[j]]$rows
    if (all(!is.na(as.matrix(r[, paste0("fx_", M5), with = FALSE])))) NULL else 1 - sum(fits[[j]]$loss1) / sum(fits[[j]]$loss0) }))
} else if (dom_mode %in% 1:2) {
  own <- which(cells$plots >= MIN_PLOTS_CELL); types <- intersect(unique(cells[plots < MIN_PLOTS_CELL, sc]), unique(all_cells[plots > 0, sc]))
  fc <- parallel::parLapply(cl, own, function(i) cal_fit(cells[i], ctx, dat))
  ft <- stats::setNames(parallel::parLapply(cl, types, function(s) cal_fit(all_cells[sc == s & plots > 0], ctx, dat)), types)
  cells[, `:=`(Level = NA_character_, m_snag = NA_real_, m_cwd = NA_real_, m_floor = NA_real_, clearcut = NA_real_)]
  for (j in seq_along(own)) cells[own[j], `:=`(Level = "Cell", m_snag = fc[[j]]$snag, m_cwd = fc[[j]]$cwd, m_floor = fc[[j]]$floor, clearcut = fc[[j]]$clearcut)]
  for (s in types) cells[is.na(Level) & sc == s, `:=`(Level = "Forest type", m_snag = ft[[s]]$snag, m_cwd = ft[[s]]$cwd, m_floor = ft[[s]]$floor, clearcut = ft[[s]]$clearcut)]
  if (anyNA(cells$Level)) fail("no FIA dead-carbon plots for state classes %s", paste(unique(cells[is.na(Level), StateClass]), collapse = ", "))
  red <- c(sapply(fc, function(f) 1 - f$loss1 / f$loss0), sapply(ft, function(f) 1 - f$loss1 / f$loss0))
} else cells[, `:=`(Level = "CBM default", m_snag = 1, m_cwd = 1, m_floor = 1, m_fwd = 1, m_litter = 1, m_duff = 1, clearcut = NA_real_)]
# Fixed Decay Multipliers: the user's values in place of the calibrated (or CBM default) ones. The measured fits already used them; the
# condition-pool fits (options 1, 2) fit snags, down wood and forest floor jointly, so there a fixed value replaces the fit afterwards.
fx_set <- function(g, col) { k <- !is.na(cells[[paste0("fx_", g)]]); if (any(k)) cells[k, (col) := cells[[paste0("fx_", g)]][k]] }
for (g in c("snag", "cwd")) fx_set(g, paste0("m_", g))
if (dom_mode %in% 3:4) { for (g in c("fwd", "litter", "duff")) fx_set(g, paste0("m_", g)) } else {
  fx_set("floor", "m_floor")
  if (any(!is.na(cells$fx_litter) & is.na(cells$fx_floor))) say("Fixed Decay Multipliers: fine woody debris, litter and duff rows are not used with the condition-pool calibration (one forest floor multiplier) - set Forest floor instead") }
if (dom_mode %in% 1:2 && any(!is.na(cells$fx_snag) | !is.na(cells$fx_cwd) | !is.na(cells$fx_floor))) say("Fixed Decay Multipliers: with the condition-pool calibration the other multipliers of a cell were fitted before its fixed values replaced the fitted ones")
FX_USED <- if (dom_mode %in% 3:4) c("snag", "cwd", "fwd", "litter", "duff", "soil") else c("snag", "cwd", "floor", "soil")
cells[, FixedMultipliers := apply(as.matrix(.SD), 1, function(v) { u <- FX_POOLS[FX_USED][!is.na(v)]; if (length(u)) paste(u, collapse = ", ") else NA_character_ }), .SDcols = paste0("fx_", FX_USED)]
mult_i <- function(i) if (dom_mode %in% 3:4) list(snag = cells$m_snag[i], cwd = cells$m_cwd[i], fwd = cells$m_fwd[i], litter = cells$m_litter[i], duff = cells$m_duff[i]) else
  list(snag = cells$m_snag[i], cwd = cells$m_cwd[i], floor = cells$m_floor[i])
w_i <- function(i) if (is.na(cells$clearcut[i])) 0 else cells$clearcut[i]     # uncalibrated or measured: cycles of high-severity fire only
parallel::clusterExport(cl, c("cells", "mult_i", "w_i", "dom_mode"), envir = environment())
if (soil_mode == 1L) {   # Soil Organic Carbon: gSSURGO
  free <- which(is.na(cells$fx_soil)); cells[, m_soil := NA_real_]
  if (length(free)) cells[free, m_soil := unlist(parallel::parLapply(cl, free, function(i) cal_soil(cells[i], ctx, mult_i(i), w_i(i))))]
  cells[, SoilSource := ifelse(is.na(m_soil), ifelse(is.na(soil_target), "Forest type median (no gSSURGO target)", "Forest type median (target unreachable)"), "gSSURGO target")]
  cells[is.na(m_soil), m_soil := median(cells[sc == .BY$sc, m_soil], na.rm = TRUE), by = sc]
  cells[is.na(m_soil), m_soil := median(cells$m_soil, na.rm = TRUE)]
} else cells[, `:=`(m_soil = 1, SoilSource = "CBM default")]
cells[!is.na(fx_soil), `:=`(m_soil = fx_soil, SoilSource = "User (Carbon Assumptions: Fixed Decay Multipliers)")]
parallel::clusterExport(cl, "cells", envir = environment())
# how far spin-up soil sits from gSSURGO: cycle-averaged belowground carbon (BG very fast + fast + slow) vs the cell's gSSURGO mean
cells[, eq_bg := unlist(parallel::parLapply(cl, seq_len(nrow(cells)), function(i) cal_bg(cells[i], ctx, c(mult_i(i), list(soil = cells$m_soil[i])), w_i(i))))]
parallel::stopCluster(cl)
gs <- cells[!is.na(soil_target)]
if (nrow(gs)) say("Soil vs gSSURGO: spin-up belowground carbon %.0f vs gSSURGO %.0f Mg C/ha (medians over %d cells; ratio median %.2f, range %.2f-%.2f)",
                  median(gs$eq_bg), median(gs$soil_target), nrow(gs), median(gs$eq_bg / gs$soil_target), min(gs$eq_bg / gs$soil_target), max(gs$eq_bg / gs$soil_target))
if (dom_mode == 4L) say("Decay calibration took %.1f min; median misfit reduction %.0f%%; median multipliers snag %.2f, down logs %.2f, fine woody debris %.2f, litter %.2f, duff %.2f, soil %.2f; stem snag fall %.3f /yr",
                        as.numeric(Sys.time() - t0, units = "mins"), 100 * median(red), median(cells$m_snag), median(cells$m_cwd), median(cells$m_fwd), median(cells$m_litter),
                        median(cells$m_duff), median(cells$m_soil), median(cells$snag_fall)) else
say("Decay calibration took %.1f min%s; median multipliers snag %.2f, down wood %.2f, forest floor %.2f, soil %.2f%s",
    as.numeric(Sys.time() - t0, units = "mins"), if (length(red)) sprintf("; median misfit reduction %.0f%%", 100 * median(red)) else "",
    median(cells$m_snag), median(cells$m_cwd), median(cells$m_floor), median(cells$m_soil),
    if (all(is.na(cells$clearcut))) "" else sprintf("; clearcut share %.2f", median(cells$clearcut, na.rm = TRUE)))
MP <- if (dom_mode %in% 3:4) c("snag", "cwd", "fwd", "litter", "duff") else c("snag", "cwd", "floor")
mm <- as.matrix(cells[, paste0("m_", MP), with = FALSE]); mf <- !is.na(as.matrix(cells[, paste0("fx_", MP), with = FALSE]))   # fixed by the user: any value
inb <- function(v, b) v >= b[1] - 1e-9 & v <= b[2] + 1e-9; sf <- !is.na(cells$fx_soil)
check(STAGE, sprintf("decay multipliers are finite and inside [%g, %g] (soil [%g, %g]), except those the user fixed", CAL$mult_min, CAL$mult_max, CAL$soil_min, CAL$soil_max),
      all(is.finite(mm)) && all(mf | inb(mm, c(CAL$mult_min, CAL$mult_max))) && all(is.finite(cells$m_soil)) && all(sf | inb(cells$m_soil, c(CAL$soil_min, CAL$soil_max))),
      sprintf("%d fixed values", sum(mf) + sum(sf)))
if (dom_mode == 4L) check(STAGE, "measured snag fall rates are between 0.005 and 0.5 per year", all(cells$snag_fall >= 0.005 & cells$snag_fall <= 0.5),
                          sprintf("range %.3f-%.3f", min(cells$snag_fall), max(cells$snag_fall)))
if (length(red)) check(STAGE, "calibration reduces the FIA dead-carbon misfit in every fit", all(red > 0), sprintf("smallest reduction %.0f%%", 100 * min(red)))
check(STAGE, "spin-up soil is finite and positive in every cell", all(is.finite(cells$eq_bg) & cells$eq_bg > 0), sprintf("range %.1f-%.1f Mg C/ha", min(cells$eq_bg), max(cells$eq_bg)))
write_ds(cells[, .(StratumId = Stratum, StateClassId = StateClass, Level, Plots = plots, ReturnInterval = ri, SnagDecayMultiplier = round(m_snag, 4),
                   DownWoodDecayMultiplier = round(m_cwd, 4), FineWoodyDecayMultiplier = round(m_fwd, 4), LitterDecayMultiplier = round(m_litter, 4),
                   DuffDecayMultiplier = round(m_duff, 4), ForestFloorDecayMultiplier = round(m_floor, 4), SoilDecayMultiplier = round(m_soil, 4),
                   ClearcutShare = round(clearcut, 3), SnagFallRate = round(snag_fall, 4), SnagFallSource, FireSnagShare, MeasuredPlots = mplots,
                   SoilTarget = round(soil_target, 2), SoilSource, ReturnIntervalSource = ri_src, HistoricalClearcutShare = hist_cc, FixedMultipliers)], "OutputDecayCalibration")
progressBar()

# ---- forest: net growth, growth split, turnover and decay per cell ----------------------------------------------------
# live turnover per cell, from its CBM Crosswalk row (Carbon Assumptions)
ng <- list(); fm_g <- list(); fm_d <- list(); rates <- list(); err <- 0; nneg <- 0
for (i in seq_len(nrow(cells))) { s <- cells$Stratum[i]; c0 <- cells$StateClass[i]; k <- cw[StateClass == c0]; r <- turnover_rates(c0, k$softwood, k$deciduous, cbm, cells$cbm_eco[i], cells$cbm_species[i], lt_user(cells[i]))
  p <- cc[Stratum == s & StateClass == c0][order(Age)]
  g <- net_growth(p, r)
  sh <- g[, lapply(.SD, function(v) ifelse(Total > 0, v / Total, 0.2)), .SDcols = names(LIVE_POOLS)]
  nneg <- nneg + sum(as.matrix(sh) < 0)
  # mass balance check: one year of turnover then growth reproduces the next year's pools
  tr <- pool_turnover(r)
  for (pl in names(LIVE_POOLS)) err <- max(err, max(abs(p[[pl]][-1] - ((1 - tr[[pl]]) * p[[pl]][-nrow(p)] + g$Total * sh[[pl]]))))
  amax <- c(g$Age[-nrow(g)], NA)                                            # the last age applies to every older age
  ng[[i]] <- data.table(StratumId = s, StateClassId = c0, StateAttributeTypeId = "Net Growth", AgeMin = g$Age, AgeMax = amax, Value = g$Total)
  fm_g[[i]] <- rbindlist(lapply(names(LIVE_POOLS), function(pl) data.table(StratumId = s, StateClassId = c0, AgeMin = g$Age, AgeMax = amax,
                                                                           FlowGroupId = paste(GROWTH_FLOW[[pl]], "[Type]"), Value = sh[[pl]])))
  cm <- cells[Stratum == s & StateClass == c0]
  dv <- dom_flow_values(r, k$softwood, cells$temp[i], cbm, dp = dom_parameters(dpt, s)); fixed <- character()
  if (!is.na(cm$snag_fall)) { dv <- set_snag_fall(dv, cm$snag_fall); fixed <- SNAG_FALL_FLOWS }
  dv <- scale_decay(dv, c(mult_i(which(cells$Stratum == s & cells$StateClass == c0)), list(soil = cm$m_soil)), fixed)
  # Carbon Rates read-out (to-do 30): the rates just built, with their sources
  fxg <- FX_USED[!is.na(unlist(cm[, paste0("fx_", FX_USED), with = FALSE]))]
  rates[[i]] <- cbind(data.table(StratumId = s, StateClassId = c0, MeanTemperature = cells$temp[i]),
                      rate_rows(dv, r, dom_parameters(dpt, s), cells$temp[i], c(mult_i(which(cells$Stratum == s & cells$StateClass == c0)), list(soil = cm$m_soil)), fxg,
                                cm$Level, cm$SoilSource, if (!is.na(cm$snag_fall)) cm$SnagFallSource else NA_character_))
  fm_d[[i]] <- data.table(StratumId = s, StateClassId = c0, AgeMin = NA_integer_, AgeMax = NA_integer_, FlowGroupId = paste(names(dv), "[Type]"), Value = unname(dv)) }
ng <- rbindlist(ng); fm_g <- rbindlist(fm_g); fm_d <- rbindlist(fm_d)
rates <- rbindlist(rates)
write_ds(rates[, .(StratumId, StateClassId, Process, FromStockTypeId, ToStockTypeId, Rate = signif(Rate, 6), BaseRate = signif(BaseRate, 6), TemperatureEffect = round(TemperatureEffect, 4),
                  Multiplier = round(Multiplier, 4), MeanTemperature = round(MeanTemperature, 2), Source)], "OutputCarbonRate")
say("Carbon Rates: %d rows (%d cells x their turnover and dead organic matter flows)", nrow(rates), uniqueN(rates[, .(StratumId, StateClassId)]))
say("Forest: %d net growth rows, %d growth-split rows (%d negative shares), %d turnover/decay rows", nrow(ng), nrow(fm_g), nneg, nrow(fm_d))
progressBar()

# ---- checks ---------------------------------------------------------------------------------------------------------
check(STAGE, "every forest cell has net growth at every age", nrow(ng) == nrow(cells) * (uniqueN(cc$Age) - 1) && all(is.finite(ng$Value)),
      sprintf("%d rows", nrow(ng)))
check(STAGE, "net growth is positive", all(ng$Value > 0), sprintf("smallest %.4f Mg C/ha/yr", min(ng$Value)))
check(STAGE, "growth shares add to 1", fm_g[, abs(sum(Value) - 1), by = .(StratumId, StateClassId, AgeMin)][, max(V1)] < 1e-9)
check(STAGE, "turnover then growth reproduces the stage 2 carbon curves", err < 1e-6, sprintf("max error %.2e Mg C/ha", err))
dsum <- fm_d[, .(Value = sum(Value)), by = .(StratumId, StateClassId, from = sub(" -> .*", "", sub("^[^:]+: ", "", sub(" \\[Type\\]$", "", FlowGroupId))))]
check(STAGE, "flows out of each pool take at most its whole stock each year", all(fm_d$Value >= 0) && max(dsum$Value) <= 1 + 1e-9, sprintf("largest total rate %.3f; pools at the 1.0 cap: %d cells", max(dsum$Value), dsum[Value > 1 - 1e-9, uniqueN(paste(StratumId, StateClassId))]))

# ---- assemble the stock-flow configuration (forest built here + LUCAS defaults) ---------------------------------------
rd <- function(f) { x <- fread(pkg_file("defaults", "stockflow", f), colClasses = "character", na.strings = "")
  x[, which(vapply(x, function(v) any(!is.na(v)), TRUE)), with = FALSE] }
fp_forest <- rbindlist(lapply(cw$StateClass, function(c0) FOREST_PATHWAYS[, .(FromStateClassId = c0, FromStockTypeId = From, ToStockTypeId = To,
                                                                                StateAttributeTypeId = Attribute, FlowTypeId = FlowType, Multiplier = 1)]))
fp <- rbind(fp_forest, rd("nonforest-pathways.csv"), ev_all[, which(vapply(ev_all, function(v) any(!is.na(v)), TRUE)), with = FALSE], fill = TRUE)   # events with the per-type fire rows
fm <- rbind(fm_g, fm_d, rd("nonforest-multipliers-grassland-shrubland.csv"), rd("nonforest-multipliers-wetland.csv"),
            rd("nonforest-multipliers-other.csv"), fill = TRUE)
# (the CONUS 1km build also had 0.01 "scalar" multipliers on the four climate flow groups, undoing climate rasters stored as
# integers x 100; stage 7 writes true multipliers, so there are none: a run without climate multipliers runs at normal climate)
sav <- rbind(ng, rd("nonforest-net-growth.csv"), fill = TRUE)
for (k in c("Iteration", "Timestep")) for (x in list(fp, fm, sav)) if (k %in% names(x)) x[, (k) := NULL]

# every flow type, flow group, stock type and state class named must exist in the library's definitions
ft <- stsim_list("FlowType")$Name; fg <- stsim_list("FlowGroup")$Name; stt <- stsim_list("StockType")$Name
bad <- unique(c(setdiff(fp$FlowTypeId, ft), setdiff(unique(fm$FlowGroupId), fg), setdiff(c(fp$FromStockTypeId, fp$ToStockTypeId), stt),
                setdiff(na.omit(c(fp$FromStateClassId, fm$StateClassId, sav$StateClassId)), scl$Name)))
check(STAGE, "every flow type, flow group, stock type and state class used is defined", !length(bad),
      if (length(bad)) paste("undefined:", paste(head(bad, 8), collapse = "; ")) else "")
progressBar()

say("Writing %d flow pathways, %d flow multipliers, %d state attribute values", nrow(fp), nrow(fm), nrow(sav))
saveDatasheet(scn, as.data.frame(fp), "stsim_FlowPathway")
saveDatasheet(scn, as.data.frame(int_cols(fm)), "stsim_FlowMultiplier")
saveDatasheet(scn, as.data.frame(int_cols(sav)), "stsim_StateAttributeValue")
progressBar()
finish_checks()
progressBar(type = "end")
