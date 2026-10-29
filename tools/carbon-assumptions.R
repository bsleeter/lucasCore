# =============================================================================
# carbon-assumptions.R - fill a Carbon Assumptions scenario with a carbon method's preset rows (to-do 21; docs/carbon-assumptions.md)
# =============================================================================
# Sourced by tools/new-library.R (new libraries) and tools/sync-library.R (existing ones). The rows are the method's preset files,
# defaults/carbon-assumptions/<method>/<sheet>.csv (tools/make_carbon_presets.R) - the same rows the Carbon Method page's Fill button
# writes and stage 3 uses for a scenario never filled. A scenario is filled only when it is unfilled as a whole (CBM Crosswalk, Dead
# Organic Matter Parameters and Disturbance Flows all empty), so a user's rows, and a sheet left empty on purpose, are never touched.
# =============================================================================

CA_DESCRIPTION <- paste("The assumptions behind the carbon calibration (docs/carbon-assumptions.md). Carbon Method: FIA measured dead wood or CBM",
  "defaults, and the soil organic carbon source; Fill writes the method's rows into the other sheets. Change any row, or add a row for one",
  "ecodivision to override the all-ecodivisions row. Build scenarios depend on this scenario (it is not run). CBM Crosswalk: the CBM-CFS3",
  "ecozone and species type each forest type takes its live turnover and snag rates from. Dead Organic Matter Parameters: each dead pool's",
  "base decay rate, reference temperature, Q10 and share emitted. Live Turnover: live pool turnover and snag fall (empty = CBM). Spin-up:",
  "return interval, share of past cycles ended by clearcut, last disturbance outside fire perimeters (empty = LANDFIRE, all fire, clearcut).",
  "Disturbance Flows: where high-severity fire and clearcut move each pool's carbon. Fire Snag Share: the share of live wood high-severity fire",
  "leaves standing (empty = none). Decay Calibration Settings, Mature Age by Forest Type and Fixed Decay Multipliers: how the FIA calibration",
  "fits (empty = defaults). Growth Inputs: each forest type's FIA type groups, growth class, merchantable carbon density, deciduous share and fine",
  "root share (empty = the package's).")
DOM_POOL_LIST <- c("AG Very Fast", "BG Very Fast", "AG Fast", "BG Fast", "AG Medium", "AG Slow", "BG Slow", "Snag Stem", "Snag Branch")
CA_METHODS <- c(`fia-measured` = 4L, `cbm-defaults` = 3L)

# list columns are saved as their codes; returns what was filled ("" when the scenario already had rows)
fill_carbon_assumptions <- function(ca, pkg, method = "fia-measured") {
  key <- c("lucasCore_CbmCrosswalk", "lucasCore_DomParameter", "lucasCore_DisturbanceFlow")
  if (any(vapply(key, function(sh) nrow(suppressWarnings(datasheet(ca, sh, optional = TRUE))) > 0, TRUE))) return(character())
  rd <- function(sheet) data.table::fread(file.path(pkg, "defaults", "carbon-assumptions", method, paste0(sheet, ".csv")), colClasses = "character", na.strings = "")
  num <- function(x, cols) { for (k in intersect(cols, names(x))) data.table::set(x, j = k, value = as.numeric(x[[k]])); x }
  done <- character(); put <- function(x, sheet, label) { if (nrow(x)) { saveDatasheet(ca, as.data.frame(x), sheet); done <<- c(done, sprintf("%s %d rows", label, nrow(x))) } }
  put(rd("cbm-crosswalk"), "lucasCore_CbmCrosswalk", "CBM Crosswalk")
  x <- num(rd("dom-parameters"), c("BaseDecayRate", "ReferenceTemperature", "Q10", "ShareEmitted", "TransferToBGSlow"))[, Pool := match(Pool, DOM_POOL_LIST)]
  put(x, "lucasCore_DomParameter", "Dead Organic Matter Parameters")
  x <- num(rd("disturbance-flows"), "Share")[, `:=`(Disturbance = match(Disturbance, c("High-severity fire", "Clearcut")), AgeMin = as.integer(AgeMin))]
  put(x[, !c("StratumId", "StateClassId")], "lucasCore_DisturbanceFlow", "Disturbance Flows")
  x <- num(rd("growth-inputs"), c("MerchCarbonDensity", "DeciduousShare", "FineRootShare"))[, GrowthClass := match(GrowthClass, c("East Softwood", "East Hardwood", "West Softwood", "West Hardwood"))]
  put(x, "lucasCore_GrowthInput", "Growth Inputs")
  x <- rd("mature-age"); for (k in intersect(c("MatureAge", "ExclusionYears"), names(x))) data.table::set(x, j = k, value = as.integer(x[[k]]))
  put(x, "lucasCore_MatureAge", "Mature Age by Forest Type")
  put(num(rd("fire-snag-share"), "Share"), "lucasCore_FireSnagShare", "Fire Snag Share")
  x <- num(rd("decay-calibration-settings"), c("MultiplierMin", "MultiplierMax", "SoilMultiplierMin", "SoilMultiplierMax"))
  for (k in intersect(c("MatureAge", "ExclusionYears", "MinPlotsOwnFit", "MinSnagsOwnRate", "MinPlotsConditionPools"), names(x))) data.table::set(x, j = k, value = as.integer(x[[k]]))
  put(x, "lucasCore_DecayCalibrationSetting", "Decay Calibration Settings")
  if (!nrow(suppressWarnings(datasheet(ca, "lucasCore_CarbonOptions", optional = TRUE)))) saveDatasheet(ca, data.frame(DeadOrganicMatterModel = CA_METHODS[[method]]), "lucasCore_CarbonOptions")
  if (length(done)) description(ca) <- CA_DESCRIPTION
  done }
