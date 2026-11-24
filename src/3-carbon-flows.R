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
# The measured and condition-pool calibrations fit soil to gNATSGO; every option logs spin-up soil against it. High-severity fire and
# clearcut flows come from Carbon Assumptions: Disturbance Flows, and fire's snag share per forest type from Fire Snag Share (else the
# package defaults), written as event rows whatever the option.
# Needs the Live-Tree Carbon Curves of stage 2 (same pipeline, or a dependency on a stage 2 result).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "growth.R")); source(pkg_file("src", "prism.R")); source(pkg_file("src", "flows.R")); source(pkg_file("src", "dom.R")); source(pkg_file("src", "calibrate.R")); source(pkg_file("src", "fia.R")); source(pkg_file("src", "disturbed-carbon.R"))
suppressPackageStartupMessages({ library(terra); library(sf) })
STAGE <- "3 Carbon Flows"; stage_begin()
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
pres <- tryCatch(prism_pick(src$PrismFolder, prism_choice(read_ds("ClimateOptions")$PrismGrid)), error = function(e) fail("%s", conditionMessage(e))); source_note("PrismFolder", sprintf("PRISM %s grid", pres))   # (Climate Options: PRISM Grid)
clim <- ecodiv_climate(src$EcodivisionFile, src$PrismFolder, pres)
eco <- unique(data.table(ecodiv = as.character(st_drop_geometry(read_sf(src$EcodivisionFile))$ecodiv),
                         StratumId = as.integer(st_drop_geometry(read_sf(src$EcodivisionFile))$StrtmId)))
eco[, Stratum := stl$Name[match(StratumId, as.integer(stl$Id))]][, temp := clim$mat[match(ecodiv, clim$ecodiv)]]
eco <- eco[!is.na(Stratum)]
say("Ecodivision mean annual temperature (PRISM %s normals): %s", pres, paste(sprintf("%s %.1f C", eco$ecodiv, eco$temp), collapse = ", "))
progressBar()

# ---- 3b: calibrate DOM decay (src/calibrate.R): snags, down wood, forest floor to FIA; soil to gNATSGO ----------------------
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
copt <- read_ds("CarbonOptions"); dm <- copt$DeadOrganicMatterModel[1]
# (the sheet reads as its labels; option 2's label starts like option 1's, so it is tested first)
dom_mode <- if (is.null(dm) || is.na(dm)) 4L else if (is.numeric(dm)) as.integer(dm) else if (grepl("^(FIA measured|Measured)", dm)) 4L else
  if (grepl("^FIA (dead|condition) pools, CBM", dm)) 2L else if (grepl("^(Calibrated|FIA condition pools)", dm)) 1L else if (grepl("^CBM default", dm)) 3L else NA_integer_
if (is.na(dom_mode)) fail("Carbon Method: unrecognised Dead Organic Matter choice '%s'", dm)
# Carbon Assumptions - Live Turnover (to-do 21): each value the user set, per cell - the ecodivision row's, else the forest type's
# all-ecodivisions row's (columns lt_<sheet column>; blank = the CBM Crosswalk's rates, src/flows.R turnover_rates). An empty sheet
# with the FIA measured dead wood method takes the package's rows (to-do 32, 2026-10-30: stem turnover fitted to FIA's background
# mortality, tools/calibrate-stem-turnover.R; CBM's rate ran 1.5-5x low and left the mature snags short)
lt <- as.data.table(datasheet(scn, ds("LiveTurnover"), optional = TRUE, lookupsAsFactors = FALSE)); LTC <- names(LIVE_TURNOVER_COLS); lt_src <- "Carbon Assumptions"
if (!nrow(lt) && dom_mode == 4L) { lt <- fread(pkg_file("defaults", "carbon-assumptions", "fia-measured", "live-turnover.csv"), colClasses = "character", na.strings = "")
  lt_src <- "the package (FIA background mortality; the sheet is empty)" }
if (nrow(lt)) {
  lt[, StratumId := as.character(StratumId)]; for (k in LTC) lt[, (k) := if (k %in% names(lt)) as.numeric(get(k)) else NA_real_]
  dup <- lt[duplicated(lt[, .(StratumId, StateClassId)])]; if (nrow(dup)) fail("Live Turnover: more than one row for %s", paste(unique(paste(dup$StratumId, dup$StateClassId)), collapse = "; "))
  own <- lt[!is.na(StratumId)][cells, on = .(StratumId = Stratum, StateClassId = StateClass), ..LTC]; all <- lt[is.na(StratumId)][cells, on = .(StateClassId = StateClass), ..LTC]
  for (k in LTC) cells[, (paste0("lt_", k)) := data.table::fcoalesce(own[[k]], all[[k]])]
  if (lt_src == "Carbon Assumptions") say("Live Turnover: %d rows from %s: %s", nrow(lt), lt_src, paste(sprintf("%s%s (%s)", ifelse(is.na(lt$StratumId), "", paste0(lt$StratumId, " / ")), sub("^Forest: ", "", lt$StateClassId),
      apply(lt[, ..LTC], 1, function(v) paste(sprintf("%s %s", LTC[!is.na(v)], v[!is.na(v)]), collapse = ", "))), collapse = "; "))
  else { u <- cells[!is.na(lt_StemTurnover)]
    say("Live Turnover: %d rows from %s; stem turnover in this build's %d forest cells %.4f-%.4f /yr (median %.4f), the other rates CBM's", nrow(lt), lt_src, nrow(u),
        min(u$lt_StemTurnover), max(u$lt_StemTurnover), stats::median(u$lt_StemTurnover)) }
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
# burial of the forested wetland twins (to-do 53): Mg C/ha/yr over the soil target = the yearly share of BG Slow
bur <- read_default("spinup", "wetland-burial.csv")
cells[, burial_rate := as.numeric(bur$Burial)[match(StateClass, bur$StateClass)] / soil_target][is.na(burial_rate), burial_rate := 0]
# methane of the forested wetland twins (defaults/spinup/wetland-ch4.csv, Mg C/ha/yr as CH4; a class without a row releases none)
# (Carbon Assumptions: Wetland Methane, src/wetland-params.R: a scenario may set its own targets, with ranges, and the cap)
wopt <- wetland_settings(); wtg <- wetland_class_targets(read_default("stockflow", "emergent-wetland-regions.csv"), read_default("spinup", "wetland-ch4.csv"), read_wetland("WetlandMethaneTarget"), read_default("stockflow", "wetland-methane-targets.csv"))
if (length(wopt$changed) || any(wtg$Source == "scenario")) say("Wetland Methane: %s; %d of %d methane targets set in this scenario", if (length(wopt$changed)) paste(sprintf("%s = %s", wopt$changed, vapply(wopt$changed, function(k) format(wopt[[k]]), "")), collapse = ", ") else "the package settings", sum(wtg$Source == "scenario"), nrow(wtg))
cells[, ch4_target := wtg[is.na(Region), Target][match(StateClass, wtg[is.na(Region), StateClassId])]][is.na(ch4_target), ch4_target := 0]
if (any(cells$burial_rate > 0)) say("Burial (BG Slow -> Deep Soil): %s", paste(cells[burial_rate > 0, sprintf("%s %s %.5f/yr", Stratum, sub("^Wetland: ", "", StateClass), burial_rate)], collapse = "; "))
fx <- fia_tables(gopt, src$EcodivisionFile)   # Growth Curve Options: FIA Data (src/fia.R)
dat <- fia_dom_data(fx$cond, fx$dist, gopt, cw); rm(fx)
cells[, plots := dat$obs[, .(n = sum(n)), by = .(sc, ecodiv)][cells, on = c("sc", "ecodiv"), n]][is.na(plots), plots := 0L]
# the study area: calibrate and write flows only for its ecodivisions (every forest type in them, so a cell that changes type during a
# run still has flows). Each ecodivision x type is calibrated on its own FIA plots, so these values are the same as a CONUS build's;
# the forest-type fallback for cells with few plots stays pooled over every ecodivision of the type (all_cells). Only the soil
# multiplier of a cell with no gNATSGO target (a median over its type's cells) now comes from the study area's cells.
all_cells <- cells; study <- study_ecodivisions()
if (!is.null(study)) { cells <- cells[Stratum %in% study]
  say("Study area: %d of %d ecodivisions (%s): %d of %d ecodivision x forest type cells", length(study), uniqueN(all_cells$Stratum),
      paste(study, collapse = ", "), nrow(cells), nrow(all_cells)) }
say("Decay calibration: %d cells, %d with >= %d FIA plots (own fit), %d with a gNATSGO soil target; return intervals %d-%d yr",
    nrow(cells), cells[plots >= MIN_PLOTS_CELL, .N], MIN_PLOTS_CELL, cells[!is.na(soil_target), .N], min(cells$ri), max(cells$ri))
# Carbon Method (sheet CarbonOptions, on the Carbon Assumptions scenario): dead organic matter 4 = FIA measured dead wood (default from
# 2026-10-27, to-do 19; src/calibrate.R cal_fit_measured; needs the FIA DataMart Folder with the <ST>_COND_DWM_CALC tables), 3 = CBM
# defaults (no calibration - the CONUS 1km build's way); 1 and 2 (FIA condition pools, no longer offered, 2026-10-28) still run in older
# libraries. A pool that is not calibrated keeps multiplier 1. Soil organic carbon: 1 = soil decay calibrated to gNATSGO, 2 = CBM
# defaults; blank = gNATSGO with options 1 and 4, CBM with 2 and 3 (as before the choice existed).
# (copt and dom_mode are read above, before Live Turnover)
sm0 <- if ("SoilCarbonModel" %in% names(copt)) copt$SoilCarbonModel[1] else NA
soil_mode <- if (is.null(sm0) || is.na(sm0)) (if (dom_mode %in% c(1L, 4L)) 1L else 2L) else if (is.numeric(sm0)) as.integer(sm0) else if (grepl("^gNATSGO|^gSSURGO", sm0)) 1L else if (grepl("^CBM", sm0)) 2L else NA_integer_
if (is.na(soil_mode)) fail("Carbon Method: unrecognised Soil Organic Carbon choice '%s'", sm0)
say("Carbon Method: dead organic matter = %s; soil organic carbon = %s", c("calibrated to FIA condition pools (snags, down wood, floor; older option)", "FIA condition pools (older option)",
    "CBM defaults (no calibration)", "FIA measured dead wood (down woody material and snags in mature stands; regional decay)")[dom_mode],
    c("soil decay calibrated to gNATSGO", "CBM defaults (from the spin-up)")[soil_mode])
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
# drought and insect mortality (to-do 3, lucasCore 2.0): the event moves 83% of each live tree pool to the dead pools and emits nothing
# (the mean loss of FIA stands over the 70% line), as the third disturbance of Carbon Assumptions: Disturbance Flows. A library made
# before the type existed has no such group: the event's rows are left out (mort_def FALSE)
mort_def <- "Mortality: Drought and Insects" %in% stsim_list("TransitionType")$Name; MORT_DF <- "Drought and insect mortality"
if (!mort_def) ev_def <- ev_def[TransitionGroupId != DF_GROUPS[[MORT_DF]]]
dfl <- as.data.table(datasheet(scn, ds("DisturbanceFlow"), optional = TRUE, lookupsAsFactors = FALSE)); df_src <- "Carbon Assumptions"
if (!nrow(dfl)) { dfl <- preset("disturbance-flows"); df_src <- sprintf("the %s preset (the sheet is empty)", basename(preset_dir)) }
# the grass, shrub and emergent wetland classes' own high-severity fire (to-do 39: chaparral 2026-11-06, the others 2026-11-07;
# tools/make_nonforest_fire.R): a sheet filled before then has no rows for them, so each class with none takes the preset's
pre_cls <- setdiff(unique(preset("disturbance-flows")$StateClassId), NA)
miss <- setdiff(intersect(pre_cls, scl$Name), unique(as.character(dfl$StateClassId)))
if (length(miss)) {
  add <- preset("disturbance-flows")[StateClassId %in% miss]
  dfl <- rbind(dfl[, lapply(.SD, as.character)], add[, lapply(.SD, as.character)], fill = TRUE)
  say("Disturbance Flows: %d high-severity fire rows for %d classes the sheet has none for, from the %s preset (%s)", nrow(add), length(miss), basename(preset_dir), paste(miss, collapse = ", ")) }
dfl[, `:=`(StratumId = as.character(StratumId), StateClassId = as.character(StateClassId), Disturbance = as.character(Disturbance),
           AgeMin = suppressWarnings(as.integer(AgeMin)), Share = as.numeric(Share))]
dfl[Disturbance %in% as.character(seq_along(DF_GROUPS)), Disturbance := names(DF_GROUPS)[as.integer(Disturbance)]]
# a sheet filled before the event existed has no rows for it: it takes the preset's; a library without the type takes none
if (!mort_def) dfl <- dfl[!Disturbance %in% MORT_DF] else if (!any(dfl$Disturbance %in% MORT_DF)) { add <- preset("disturbance-flows")[Disturbance == MORT_DF]
  dfl <- rbind(dfl, add[, `:=`(StratumId = as.character(StratumId), StateClassId = as.character(StateClassId), AgeMin = suppressWarnings(as.integer(AgeMin)), Share = as.numeric(Share))], fill = TRUE)
  if (df_src == "Carbon Assumptions") say("Disturbance Flows: %d drought and insect mortality rows from the %s preset (the sheet has none for it)", nrow(add), basename(preset_dir)) }
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
check(STAGE, "high-severity fire, clearcut and drought and insect mortality move at most each pool's whole stock", eb$v <= 1 + 1e-4, sprintf("largest share %.4f (%s)", eb$v, eb$what))
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
  # fits: each upland forest type pooled over its ecodivisions (the fallback), and each ecodivision over its upland types with enough
  # plots (shared snag, down log and fine woody debris multipliers; litter and duff per type). Forested wetland classes (user,
  # 2026-11-10: dead wood on waterlogged ground decays apart from upland's): one with enough plots in its ecodivision is fitted on
  # them alone, except duff, which takes its upland counterpart's multiplier there - FIA's duff on hydric plots is the top of the
  # muck or peat (mature means 60-150 Mg C/ha against 5-30 upland), carbon the model holds as soil. One with too few takes the
  # ecodivision's upland values (its counterpart's litter and duff). Fitted alone over every ecodivision, the thin wetland plots
  # had driven snag and duff multipliers to their limits (2026-11-10).
  wet <- is_wetland_forest(cells$StateClass); up_of <- function(x) sub("^Wetland: ", "Forest: ", x)
  cells[, dgrp := Stratum]
  ecos <- unique(cells[!wet & mplots >= MIN_DWM_CELL, Stratum])
  cp_sc <- all_cells$sc[match(up_of(cells$StateClass[wet]), all_cells$StateClass)]   # the wetland classes' upland counterparts
  types <- unique(all_cells[sc %in% c(cells[!wet & !(Stratum %in% ecos & mplots >= MIN_DWM_CELL), sc], cp_sc) & mplots > 0 & !is_wetland_forest(StateClass), sc])
  parallel::clusterExport(cl, c("dat_m", "cells", "all_cells"), envir = environment())
  jobs <- c(lapply(types, function(s) list(kind = "type", rows = all_cells[sc == s & mplots > 0])), lapply(ecos, function(e) list(kind = "eco", rows = cells[!wet & Stratum == e & mplots >= MIN_DWM_CELL])))
  fits <- parallel::parLapply(cl, jobs, function(j) cal_fit_measured(j$rows, ctx, dat_m))
  ft <- stats::setNames(fits[seq_along(types)], types); fe <- stats::setNames(fits[length(types) + seq_along(ecos)], ecos)
  M5 <- c("snag", "cwd", "fwd", "litter", "duff")
  # a fit's value of pool g for a cell outside it: from a row where g was calibrated, not one the user fixed
  pick <- function(f, rows, gs) stats::setNames(lapply(gs, function(g) { j <- which(is.na(rows[[paste0("fx_", g)]]))[1]; f[[g]][if (is.na(j)) 1L else j] }), gs)
  # the upland values a wetland class takes in ecodivision e: its counterpart's row of the ecodivision fit, else the counterpart pooled
  up_vals <- function(e, cls) { s <- as.character(all_cells$sc[match(up_of(cls), all_cells$StateClass)])
    if (e %in% names(fe)) { rows <- jobs[[length(types) + match(e, ecos)]]$rows; j <- match(s, as.character(rows$sc)); if (!is.na(j)) return(as.list(fe[[e]][j, ..M5])) }
    if (!is.na(s) && s %in% names(ft)) return(pick(ft[[s]], jobs[[match(s, types)]]$rows, M5)); NULL }
  wo <- which(wet & cells$mplots >= MIN_DWM_CELL)
  wjobs <- lapply(wo, function(i) { r <- copy(cells[i]); uv <- up_vals(r$Stratum, r$StateClass); r[, hold_duff := if (is.null(uv)) 1 else uv$duff]; list(kind = "wetland", rows = r) })
  wfits <- if (length(wjobs)) parallel::parLapply(cl, wjobs, function(j) cal_fit_measured(j$rows, ctx, dat_m)) else list()
  if (any(wet)) say("Dead wood decay: %d forested wetland cells, %d fitted on their own plots (duff from the upland counterpart: FIA's hydric duff is muck or peat, held as soil), the rest on the ecodivision's upland values",
                    sum(wet), length(wo))
  cells[, `:=`(Level = NA_character_, m_snag = NA_real_, m_cwd = NA_real_, m_floor = NA_real_, clearcut = NA_real_)]
  setm <- function(i, v, lv) cells[i, `:=`(Level = lv, m_snag = v[["snag"]], m_cwd = v[["cwd"]], m_fwd = v[["fwd"]], m_litter = v[["litter"]], m_duff = v[["duff"]])]
  for (i in seq_len(nrow(cells))) { e <- cells$Stratum[i]; s <- as.character(cells$sc[i])
    if (wet[i]) {
      k <- match(i, wo); uv <- up_vals(e, cells$StateClass[i])
      if (!is.na(k)) setm(i, as.list(wfits[[k]][1, ..M5]), "Wetland class; duff of its upland type")
      else if (e %in% names(fe) && !is.null(uv)) setm(i, c(pick(fe[[e]], jobs[[length(types) + match(e, ecos)]]$rows, c("snag", "cwd", "fwd")), uv[c("litter", "duff")]), "Ecodivision (upland); litter and duff of its upland type")
      else if (!is.null(uv)) setm(i, uv, "Upland type (pooled)")
      next }
    tf <- if (s %in% names(ft)) pick(ft[[s]], jobs[[match(s, types)]]$rows, M5) else NULL
    if (e %in% names(fe)) { f <- fe[[e]]; rows <- jobs[[length(types) + match(e, ecos)]]$rows; j <- match(cells$sc[i], rows$sc)
      if (!is.na(j)) setm(i, as.list(f[j, ..M5]), "Ecodivision")
      else if (!is.null(tf)) setm(i, c(pick(f, rows, c("snag", "cwd", "fwd")), tf[c("litter", "duff")]), "Ecodivision; litter and duff by forest type")
    } else if (!is.null(tf)) setm(i, tf, "Forest type") }
  fits <- c(fits, wfits); jobs <- c(jobs, wjobs)   # for the misfit reduction below
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
if (soil_mode == 1L) {   # Soil Organic Carbon: gNATSGO
  free <- which(is.na(cells$fx_soil)); cells[, m_soil := NA_real_]
  if (length(free)) cells[free, m_soil := unlist(parallel::parLapply(cl, free, function(i) cal_soil(cells[i], ctx, mult_i(i), w_i(i))))]
  cells[, SoilSource := ifelse(is.na(m_soil), ifelse(is.na(soil_target), "Forest type median (no gNATSGO target)", "Forest type median (target unreachable)"), "gNATSGO target")]
  cells[is.na(m_soil), m_soil := median(cells[sc == .BY$sc, m_soil], na.rm = TRUE), by = sc]
  cells[is.na(m_soil), m_soil := median(cells$m_soil, na.rm = TRUE)]
  # no cell of the study area reaches a gNATSGO target (2026-11-16: Sabine and Lacassine refuges, one forest cell with a target and
  # that one out of reach): nothing to take a median of, so the CBM soil decay as it is; before this the spin-up below stopped on NA
  cells[is.na(m_soil), `:=`(m_soil = 1, SoilSource = "CBM default (no cell of the study area reaches a gNATSGO target)")]
} else cells[, `:=`(m_soil = 1, SoilSource = "CBM default")]
cells[!is.na(fx_soil), `:=`(m_soil = fx_soil, SoilSource = "User (Carbon Assumptions: Fixed Decay Multipliers)")]
parallel::clusterExport(cl, "cells", envir = environment())
# how far spin-up soil sits from gNATSGO: cycle-averaged belowground carbon (BG very fast + fast + slow) vs the cell's gNATSGO mean
cells[, eq_bg := unlist(parallel::parLapply(cl, seq_len(nrow(cells)), function(i) cal_bg(cells[i], ctx, c(mult_i(i), list(soil = cells$m_soil[i])), w_i(i))))]
parallel::stopCluster(cl)
gs <- cells[!is.na(soil_target)]
if (nrow(gs)) say("Soil vs gNATSGO: spin-up belowground carbon %.0f vs gNATSGO %.0f Mg C/ha (medians over %d cells; ratio median %.2f, range %.2f-%.2f)",
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
ng <- list(); fm_g <- list(); fm_d <- list(); rates <- list(); err <- 0; nneg <- 0; ch4_cells <- list()
# the stand ages present, by ecodivision and class, for the methane share of the forested wetlands (stage 5's state class, age and
# strata maps; none when stage 5 has not run): the share is calibrated on the stands the library has, not on a disturbance cycle
ch4_ages <- NULL
if (any(cells$ch4_target > 0, na.rm = TRUE)) { ic3 <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE)); f3 <- c("StratumFileName", "StateClassFileName", "AgeFileName")
  if (nrow(ic3) && all(f3 %in% names(ic3)) && !anyNA(unlist(ic3[1, f3, with = FALSE])) && all(file.exists(unlist(ic3[1, f3, with = FALSE])))) {
    v3 <- as.data.table(terra::values(terra::rast(unlist(ic3[1, f3, with = FALSE])), mat = TRUE)); setnames(v3, c("P", "S", "A"))
    ch4_ages <- v3[!is.na(P) & !is.na(S) & !is.na(A)][, `:=`(Stratum = stl$Name[match(P, as.integer(stl$Id))], StateClass = scl$Name[match(S, as.integer(scl$Id))])][
      StateClass %in% cells[ch4_target > 0, StateClass], .(Stratum, StateClass, A)] } }
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
  dv <- add_burial(dom_flow_values(r, k$softwood, cells$temp[i], cbm, dp = dom_parameters(dpt, s)), cm$burial_rate); fixed <- BURIAL_FLOW
  if (!is.na(cm$snag_fall)) { dv <- set_snag_fall(dv, cm$snag_fall); fixed <- c(fixed, SNAG_FALL_FLOWS) }
  dv <- scale_decay(dv, c(mult_i(which(cells$Stratum == s & cells$StateClass == c0)), list(soil = cm$m_soil)), fixed)
  # Carbon Rates read-out (to-do 30): the rates just built, with their sources
  fxg <- FX_USED[!is.na(unlist(cm[, paste0("fx_", FX_USED), with = FALSE]))]
  rates[[i]] <- cbind(data.table(StratumId = s, StateClassId = c0, MeanTemperature = cells$temp[i]),
                      rate_rows(dv, r, dom_parameters(dpt, s), cells$temp[i], c(mult_i(which(cells$Stratum == s & cells$StateClass == c0)), list(soil = cm$m_soil)), fxg,
                                cm$Level, cm$SoilSource, if (!is.na(cm$snag_fall)) cm$SnagFallSource else NA_character_))
  # methane (forested wetlands; src/flows.R METHANE_POOLS): the fraction of what the class's source pools emit (soil, root litter and
  # the forest floor) that meets its target, over the cell's disturbance cycle at the rates just built; each pool's emission then split
  # into CO2 and CH4. The emission is worked out from the mean pools of the reference stand and the litter the live pools shed into the fast ones
  # (methane_source_emission): a fast pool loses most of its litter within the year, so its own stock says little about what passed through it.
  # The reference stand has the ages the library's cells of the class have (this ecodivision's, else every ecodivision's), and is one
  # disturbance cycle only where the library has no cell of the class (methane_age_weights, src/flows.R)
  if (isTRUE(cm$ch4_target > 0)) { S4 <- cal_setup(cells[i], ctx); d <- cal_dom(S4, ctx$fo, c(mult_i(i), list(soil = cm$m_soil)), w_i(i)); n4 <- min(nrow(d), nrow(S4$live))
    a4 <- if (is.null(ch4_ages)) numeric() else { a <- ch4_ages[Stratum == s & StateClass == c0, A]; if (length(a)) a else ch4_ages[StateClass == c0, A] }
    w4 <- methane_age_weights(a4, cm$ri, n4); src4 <- if (length(a4)) sprintf("%d cells, mean age %.0f", length(a4), mean(a4)) else sprintf("no cells: a %d-year cycle", cm$ri)
    ems <- methane_source_emission(drop(w4 %*% d[seq_len(n4), c(METHANE_POOLS$code, "SnagBranch"), drop = FALSE]), drop(w4 %*% S4$live[seq_len(n4), , drop = FALSE]), dv); em <- sum(ems); f <- min(cm$ch4_target / em, wopt$MethaneCapShare)
    ch4_cells[[length(ch4_cells) + 1]] <- data.table(StratumId = s, StateClassId = c0, Target = cm$ch4_target, SourceEmission = em, ForestFloor = sum(ems[METHANE_POOLS[forest_floor == TRUE, code]]), Share = f, Stand = src4)
    dv <- ch4_split(dv, f) }
  fm_d[[i]] <- data.table(StratumId = s, StateClassId = c0, AgeMin = NA_integer_, AgeMax = NA_integer_, FlowGroupId = paste(names(dv), "[Type]"), Value = unname(dv)) }
if (length(ch4_cells)) { ch4_cells <- rbindlist(ch4_cells)
  say("Forested wetland methane: %s", paste(ch4_cells[, sprintf("%s %s target %.3f Mg C/ha/yr = %.1f%% of a source emission of %.2f (forest floor %.2f, soil and root litter %.2f; %s)%s", StratumId, sub("^Wetland: ", "", StateClassId), Target, 100 * Share,
                                                            SourceEmission, ForestFloor, SourceEmission - ForestFloor, Stand, ifelse(Share >= wopt$MethaneCapShare - 1e-9, sprintf(" (capped: %.3f delivered)", Share * SourceEmission), ""))], collapse = "; ")) }
ng <- rbindlist(ng); fm_g <- rbindlist(fm_g); fm_d <- rbindlist(fm_d)
fm_d <- fm_d[!(FlowGroupId == paste(BURIAL_FLOW, "[Type]") & Value == 0)]   # burial only where a class has it
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
fp_forest <- fp_forest[FlowTypeId != BURIAL_FLOW | FromStateClassId %in% cells[burial_rate > 0, unique(StateClass)]]
fp <- rbind(fp_forest, rd("nonforest-pathways.csv"), rd("nonforest-pathways-agriculture.csv"), rd("organic-soil-pathways.csv"), ev_all[, which(vapply(ev_all, function(v) any(!is.na(v)), TRUE)), with = FALSE], fill = TRUE)   # events with the per-type fire rows
# Carbon Assumptions - Grassland, Shrubland and Wetland Carbon (to-do 39, 2026-10-30): the package's non-forest rates (the CONUS 1 km
# build's, from IBIS; one value per class, the same in every ecodivision, except the forested wetlands' growth curve and age-varying
# growth split) with the scenario's rows on top, the more specific last: a class's row for every ecodivision and age, then for one age,
# then for one ecodivision, then for both. Growth: Net Growth (Mg C/ha/yr). Rates: the growth split (Net Growth groups, shares that add
# to 1), live turnover and dead pool decay, emission and transfer (per year); for emergent wetlands a "<pool> ->" group is the pool's
# total yearly loss and the flows out of it are shares of that loss, adding to 1. The initial pools stay the package's tables (stage 8).
gs_m <- rbind(rd("nonforest-multipliers-grassland-shrubland.csv"), rd("nonforest-multipliers-wetland.csv"), rd("nonforest-multipliers-agriculture.csv"), fill = TRUE); nf_g <- rd("nonforest-net-growth.csv")
if (!"AgeMin" %in% names(gs_m)) gs_m[, AgeMin := NA_character_]
if (!"AgeMin" %in% names(nf_g)) nf_g[, AgeMin := NA_character_]
gsr <- as.data.table(datasheet(scn, ds("NonForestRate"), optional = TRUE, lookupsAsFactors = FALSE))
gsg <- as.data.table(datasheet(scn, ds("NonForestGrowth"), optional = TRUE, lookupsAsFactors = FALSE))
gs0 <- copy(gs_m); ng0 <- copy(nf_g)
# a sheet's rows onto a package table x (value column vx), the more specific last
put_rows <- function(x, r, keys, vr, vx = "Value") {
  r <- copy(r)[, `:=`(StratumId = as.character(StratumId), AgeMin = if ("AgeMin" %in% names(r)) as.character(as.integer(AgeMin)) else NA_character_, v = as.character(get(vr)))]
  for (lv in list(c(), "AgeMin", "StratumId", c("StratumId", "AgeMin"))) {
    s <- r[(if ("StratumId" %in% lv) !is.na(StratumId) else is.na(StratumId)) & (if ("AgeMin" %in% lv) !is.na(AgeMin) else is.na(AgeMin))]
    if (nrow(s)) x[s, on = c(keys, lv), (vx) := i.v] }
  invisible(x) }
if (nrow(gsr)) {
  gsr <- gsr[!is.na(StateClassId) & !is.na(FlowGroupId) & !is.na(Value)]
  # a row that names an emergent wetland flow as it was before the classes had flow types of their own (lucasCore 1.9 and earlier: the
  # shared or the wetland flow type; src/nonforest-solve.R NF_EMERGENT_TYPES) means the class's own flow
  source(pkg_file("src", "nonforest-solve.R")); ety <- function(x) paste(x, "[Type]")
  eold <- gsr$StateClassId %in% names(NF_AG_TO_SOIL) & gsr$FlowGroupId %in% ety(names(NF_EMERGENT_TYPES))
  if (any(eold)) { say("Grassland, Shrubland and Wetland Carbon: %d emergent wetland rows name a flow by its name before lucasCore 1.10; read as the classes' own flow types (%s)", sum(eold), paste(unique(gsr$FlowGroupId[eold]), collapse = "; "))
    gsr[eold, FlowGroupId := ety(NF_EMERGENT_TYPES[sub(" \\[Type\\]$", "", FlowGroupId)])] }
  bad <- gsr[!paste(StateClassId, FlowGroupId) %in% gs_m[, paste(StateClassId, FlowGroupId)]]
  check(STAGE, "every non-forest rate row names a grassland, shrubland, wetland or agriculture class and one of its flows", !nrow(bad), paste(head(unique(bad[, paste(StateClassId, FlowGroupId)]), 5), collapse = "; "))
  put_rows(gs_m, gsr, c("StateClassId", "FlowGroupId"), "Value") }
if (nrow(gsg)) put_rows(nf_g, gsg[!is.na(StateClassId) & !is.na(NetGrowth)], "StateClassId", "NetGrowth")
dr <- sum(as.numeric(gs_m$Value) != as.numeric(gs0$Value)); dg <- sum(as.numeric(nf_g$Value) != as.numeric(ng0$Value))
say("Grassland, Shrubland and Wetland Carbon: %s; %d of %d rates and %d of %d net growth values differ from the package's%s", if (nrow(gsr) || nrow(gsg)) sprintf("%d rate and %d growth rows in this scenario", nrow(gsr), nrow(gsg)) else "no rows (the package values)",
    dr, nrow(gs_m), dg, nrow(nf_g[StateClassId %in% gs_m$StateClassId]), if (dr + dg > 0) " (the initial pools stay the package's)" else "")
spl <- gs_m[grepl("^Net Growth .*: Atmosphere ->", FlowGroupId), .(s = sum(as.numeric(Value))), by = .(StratumId, StateClassId, AgeMin)]
check(STAGE, "grassland, shrubland and wetland growth splits add to 1 (at every age)", all(abs(spl$s - 1) < 1e-3), paste(head(spl[abs(s - 1) >= 1e-3, sprintf("%s %s %s %.3f", StratumId, StateClassId, AgeMin, s)], 5), collapse = "; "))
# emergent wetlands: the shares out of a pool's total loss ("AG Very Fast ->" etc.) add to 1
POOL_OUT <- c(`AG Very Fast ->` = "AG Very Fast ->", `BG Very Fast ->` = "BG Very Fast ->", `BG Slow ->` = "BG Slow ->")
sh <- rbindlist(lapply(names(POOL_OUT), function(p) { pool <- sub(" ->$", "", p)
  gs_m[StratumId %in% gs_m[FlowGroupId == p, unique(StratumId)] & StateClassId %in% gs_m[FlowGroupId == p, unique(StateClassId)] &
       grepl(sprintf("^(Decay|Emission|Lateral Transport|Stabilization)( Emergent)?: %s -> ", pool), FlowGroupId), .(pool = pool, s = sum(as.numeric(Value))), by = .(StratumId, StateClassId)] }))
check(STAGE, "emergent wetland shares out of each pool's total loss add to 1", !nrow(sh) || all(abs(sh$s - 1) < 1e-3), paste(head(sh[abs(s - 1) >= 1e-3, sprintf("%s %s %s %.3f", StratumId, StateClassId, pool, s)], 5), collapse = "; "))
check(STAGE, "grassland, shrubland and wetland rates are between 0 and 1 and net growth is not negative", all(between(as.numeric(gs_m$Value), 0, 1)) && all(as.numeric(nf_g$Value) >= 0))
# Wetland Methane (src/wetland-params.R): an emergent class whose target the scenario sets, or whose fitted methane fraction is above
# the scenario's cap, takes the fraction that target asks of its fitted belowground emission (defaults/stockflow/emergent-wetland-fit.csv:
# no refit). Each pool's CO2 and CH4 shares still add to its emission share, so the pools, burial and lateral export stay as fitted.
source(pkg_file("src", "nonforest-solve.R"))
wfit <- read_default("stockflow", "emergent-wetland-fit.csv")
wb <- merge(wfit[, .(StratumId, StateClassId, Region, Bg = as.numeric(BelowgroundEmission), f0 = as.numeric(CH4Share))], wtg[!is.na(Region), .(StateClassId, Region, Target, Low, High, Source)], by = c("StateClassId", "Region"))
wb[, f := ifelse(Source == "scenario" | f0 > wopt$MethaneCapShare, wetland_share(Target, Bg, wopt$MethaneCapShare), f0)]
for (r in which(abs(wb$f - wb$f0) > 1e-12)) for (k in names(NF_CH4$ch4)) {
  ic <- which(gs_m$StratumId == wb$StratumId[r] & gs_m$StateClassId == wb$StateClassId[r] & gs_m$FlowGroupId == paste(NF_CH4$co2[[k]], "[Type]")); ih <- which(gs_m$StratumId == wb$StratumId[r] & gs_m$StateClassId == wb$StateClassId[r] & gs_m$FlowGroupId == paste(NF_CH4$ch4[[k]], "[Type]"))
  if (length(ic) != 1 || length(ih) != 1) next
  e <- as.numeric(gs_m$Value[ic]) + as.numeric(gs_m$Value[ih]); h <- round(e * wb$f[r], 8); set(gs_m, ih, "Value", as.character(h)); set(gs_m, ic, "Value", as.character(round(e - h, 10))) }
if (any(abs(wb$f - wb$f0) > 1e-12)) say("Wetland Methane: %d emergent wetland budgets take a methane fraction of their own (target or cap of this scenario): %s", sum(abs(wb$f - wb$f0) > 1e-12),
    paste(head(wb[abs(f - f0) > 1e-12, sprintf("%s %s %.3f Mg C/ha/yr = %.1f%% (%.1f%% as fitted)%s", StratumId, sub("^Wetland: ", "", StateClassId), Target, 100 * f, 100 * f0, ifelse(f >= wopt$MethaneCapShare - 1e-9, " at the cap", ""))], 6), collapse = "; "))
if (all(is.na(gs_m$AgeMin))) gs_m[, AgeMin := NULL]
# post-disturbance classes (to-do 57; src/disturbed-carbon.R): derived from the rows above, so they follow their parents
dcl <- disturbed_classes(scl)
dcb <- disturbed_carbon(dcl, read_default("transitions", "post-disturbance-regions.csv"), study, rd("nonforest-pathways.csv"), gs_m, nf_g, fm_d, FOREST_PATHWAYS,
                        cells[burial_rate > 0, unique(StateClass)], ev_all, BURIAL_FLOW)
if (nrow(dcl)) {
  fp <- rbind(fp, dcb$fp, dcb$ev, fill = TRUE)
  say("Disturbed classes: %d forest (forest dead wood, decay and soil; live carbon as the ecodivision's shrub class), %d shrub (their parent's rows): %d pathways, %d multipliers, %d net growth values",
      length(dcb$forest), length(dcb$shrub), nrow(dcb$fp) + if (is.null(dcb$ev)) 0L else nrow(dcb$ev), nrow(dcb$fm), nrow(dcb$sav)) }
fm <- rbind(fm_g, fm_d, gs_m, dcb$fm, rd("nonforest-multipliers-other.csv"), fill = TRUE)
# (the CONUS 1km build also had 0.01 "scalar" multipliers on the four climate flow groups, undoing climate rasters stored as
# integers x 100; stage 7 writes true multipliers, so there are none: a run without climate multipliers runs at normal climate)
sav <- rbind(ng, nf_g, dcb$sav, fill = TRUE)
for (k in c("Iteration", "Timestep")) for (x in list(fp, fm, sav)) if (k %in% names(x)) x[, (k) := NULL]
# cropland and pasture growth varies by year (to-do 39 step 6, user 2026-11-07): the Crop Yield flow multiplier on Net Growth
# Agriculture: Total = the ecodivision's NASS yield index (defaults/stockflow/ag-crop-yield.csv, tools/make_agriculture.R; 1.0 = the
# level the rates were solved at); ST-Sim keeps a timestep's value until the next, so the row after the last NASS year (the mean index
# of its last 10 years) holds for every later year and for projections
cy <- rd("ag-crop-yield.csv")
if (nrow(cy)) {
  if (!"Crop Yield" %in% stsim_list("FlowMultiplierType")$Name) fail("the library has no Flow Multiplier Type 'Crop Yield': run tools/sync-library.R on it")
  fm <- rbind(fm, cy[, .(Timestep, StratumId, StateClassId, FlowGroupId = "Net Growth Agriculture: Total", FlowMultiplierTypeId = "Crop Yield", Value)], fill = TRUE)
  say("Crop Yield: %d yearly cropland and pasture growth multipliers, %s-%s (range %.2f-%.2f)", nrow(cy), min(cy$Timestep), max(cy$Timestep), min(as.numeric(cy$Value)), max(as.numeric(cy$Value))) }

# every flow type, flow group, stock type and state class named must exist in the library's definitions
ft <- stsim_list("FlowType")$Name; fg <- stsim_list("FlowGroup")$Name; stt <- stsim_list("StockType")$Name
# methane from emergent wetlands (2026-11-16; src/nonforest-solve.R NF_CH4): BG Slow and BG Very Fast each release carbon as CO2 and
# as CH4, both shares of the pool's total loss, each with its own Q10 (stage 7: Q10 Wetland CH4 on the methane; Q10 Wetland Flows on the
# CO2 and on the litter's other losses, by flow types of the emergent classes' own, as lucasWet has them: 2026-11-24). A library made
# before the methane definitions runs as before: the soil's emission by the shared flow type and no methane, each pool's CH4 share put
# back into its CO2 share, so the pools, burial and lateral export at the normal climate are the same either way.
source(pkg_file("src", "nonforest-solve.R")); g4 <- NF_CH4; ty4 <- function(x) paste(x, "[Type]")
# a library without the emergent classes' own flow types (made before lucasCore 1.10 and not updated): their flows go by the flow types
# they had (the forested wetlands' for soil and root litter CO2 and soil CH4, the shared ones for aboveground litter and root litter
# decay). The rates are the package's as fitted, so the soil's CO2 and CH4 then run before the year's litter arrives (flow order 5) and
# the soil settles a little above its fitted stock; and those flows keep the Q10s of the types they go by
has_em <- all(NF_EMERGENT_TYPES %in% ft) && all(c(ty4(unique(NF_EMERGENT_TYPES)), NF_EMERGENT_Q10) %in% fg)
if (!has_em) { say("Emergent wetlands: this library lacks the classes' own flow types (it predates lucasCore 1.10; update it, or run tools/sync-library.R), so their litter and soil flows go by the earlier flow types: soil CO2 and CH4 at flow order 5 and no single wetland Q10")
  eb <- rev(NF_EMERGENT_TYPES); eb <- setNames(names(eb), eb)[!duplicated(eb)]   # the classes' own flow type -> the one it had (the wetland one where there are two)
  fm[FlowGroupId %in% ty4(names(eb)), FlowGroupId := ty4(eb[sub(" \\[Type\\]$", "", FlowGroupId)])]; fp[FlowTypeId %in% names(eb), FlowTypeId := unname(eb[FlowTypeId])] }
# every methane source pool: soil and root litter (forested wetlands, and emergent ones by their own flow types), the forest floor (forested)
mp4 <- METHANE_POOLS
has_ch4 <- all(c(mp4$co2, mp4$ch4) %in% ft) && all(c(ty4(c(mp4$co2, mp4$ch4)), g4$q10, CH4_FLOWS$soil_q10) %in% fg)
if (has_em) mp4 <- rbind(mp4, data.table(code = c("BGS", "BGVF"), pool = c("BG Slow", "BG Very Fast"), other = NA_character_, forest_floor = FALSE, shared = unname(g4$shared), co2 = unname(g4$co2), ch4 = unname(g4$ch4)))
c4 <- rbindlist(lapply(seq_len(nrow(mp4)), function(k) merge(fm[FlowGroupId == ty4(mp4$ch4[k]), .(StratumId, StateClassId, ch4 = as.numeric(Value))],
                                                            fm[FlowGroupId == ty4(mp4$co2[k]), .(StratumId, StateClassId, co2 = as.numeric(Value))], by = c("StratumId", "StateClassId"))[, pool := mp4$code[k]]))
if (has_ch4) {
  # the forested wetland classes that release methane, and their Disturbed classes (which take their parents' rates): their pathways
  fp <- ch4_pathways(fp, unique(fm[FlowGroupId == ty4(CH4_FLOWS$soil_ch4), StateClassId]))
  sh4 <- c4[, ifelse(ch4 + co2 > 0, ch4 / (ch4 + co2), 0)]   # (a share at the cap is the cap to rounding: 2026-11-16, the Great Dismal Swamp twins at 0.3 failed an exact test)
  say("Wetland methane: %d wetland classes (emergent, forested and their disturbed classes) release %.1f-%.1f%% of what their source pools emit as CH4 at the normal climate", uniqueN(c4$StateClassId), 100 * min(sh4), 100 * max(sh4))
  check(STAGE, "the methane share of what a wetland's source pools emit is between 0 and the cap", all(sh4 >= 0 & sh4 <= wopt$MethaneCapShare + 1e-7), sprintf("cap %.2f; largest %.4f", wopt$MethaneCapShare, max(sh4)))
  # the uncertainty draws: a class whose target has a range gets, for each of the first Uncertainty Draws iterations, a methane factor
  # and the CO2 factor that takes the same carbon off its CO2 (tabular, by ecodivision and class). Estuarine emergent marsh is left to
  # stage 8, which writes its factors per cell (they depend on the salinity zones in each cell)
  if (wopt$UncertaintyDraws > 0) { if (!all(c(METHANE_UNCERTAINTY_TYPE) %in% stsim_list("FlowMultiplierType")$Name) || !all(WETLAND_FACTOR_GROUPS %in% fg)) {
      say("Wetland Methane: %d uncertainty draws asked for, but this library has no '%s' multiplier type or wetland methane flow groups (it predates them): every iteration runs at the targets", wopt$UncertaintyDraws, METHANE_UNCERTAINTY_TYPE)
    } else { bs <- c4[pool == "BGS", .(StratumId, StateClassId, f = ifelse(ch4 + co2 > 0, ch4 / (ch4 + co2), 0))][StateClassId != "Wetland: Estuarine Emergent"]
      bs[, parent := sub("^Disturbed: Wetland (.+ Group)$", "Wetland: \\1", StateClassId)][, Region := wb$Region[match(paste(StratumId, parent), paste(wb$StratumId, wb$StateClassId))]]
      tk <- match(paste(bs$parent, bs$Region), paste(wtg$StateClassId, wtg$Region)); bs[, `:=`(Target = wtg$Target[tk], Low = wtg$Low[tk], High = wtg$High[tk])]
      ir <- wetland_iteration_rows(bs[!is.na(Target)], wopt$UncertaintyDraws, wopt$MethaneCapShare); if (nrow(ir)) fm <- rbind(fm, ir, fill = TRUE)
      say("Wetland Methane: %d uncertainty draws; %d classes with a target range get their own methane and CO2 factors in iterations 1 to %d (%d rows)%s", wopt$UncertaintyDraws, uniqueN(ir$StateClassId), wopt$UncertaintyDraws, nrow(ir),
          if (nrow(ir)) sprintf("; methane factor %.2f to %.2f", min(ir[FlowGroupId == WETLAND_FACTOR_GROUPS[["ch4"]], Value]), max(ir[FlowGroupId == WETLAND_FACTOR_GROUPS[["ch4"]], Value])) else "") } }
} else { say("Wetland methane: this library lacks the wetland CO2 and CH4 emission flow types (it predates them, or the forest floor ones), so wetland emission is all counted as CO2 and wetland soil has no temperature response")
  num <- is.numeric(fm$Value)
  for (k in seq_len(nrow(mp4))) { x <- c4[pool == mp4$code[k]]; if (!nrow(x)) next; at <- fm[, which(FlowGroupId == ty4(mp4$co2[k]) & paste(StratumId, StateClassId) %in% x[, paste(StratumId, StateClassId)])]
    v <- x[match(fm[at, paste(StratumId, StateClassId)], paste(StratumId, StateClassId)), ch4 + co2]; set(fm, at, "Value", if (num) v else as.character(v)) }
  fm <- fm[!FlowGroupId %in% ty4(mp4$ch4)]; fp <- fp[!FlowTypeId %in% mp4$ch4]
  for (k in seq_len(nrow(mp4))) { fm[FlowGroupId == ty4(mp4$co2[k]), FlowGroupId := ty4(mp4$shared[k])]; fp[FlowTypeId == mp4$co2[k], FlowTypeId := mp4$shared[k]] } }
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
stage_done()
progressBar(type = "end")
