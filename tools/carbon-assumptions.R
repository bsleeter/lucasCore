# =============================================================================
# carbon-assumptions.R - fill a Carbon Assumptions scenario's empty sheets with the package defaults (to-do 21; docs/carbon-assumptions.md)
# =============================================================================
# Sourced by tools/new-library.R (new libraries) and tools/sync-library.R (existing ones). Each sheet is filled only when empty, so a
# user's rows are never overwritten; a sheet added to the package later is filled the next time sync-library runs.
#   lucasCore_CbmCrosswalk   defaults/cbm/species-crosswalk.csv  (forest type -> CBM ecozone, species type)
#   lucasCore_DomParameter   defaults/cbm/dom-parameters.csv     (dead pool base decay rate, reference temperature, Q10, share emitted)
#   lucasCore_DisturbanceFlow defaults/stockflow/event-pathways.csv (high-severity fire and clearcut rows, gas rows merged: src/dom.R)
#   lucasCore_FireSnagShare  defaults/spinup/fire-snag-share.csv  (share of live wood fire leaves as snags, per forest type)
# Live Turnover and Spin-up start empty (blank = CBM rates; stage 5's return intervals, all-fire cycles).
# =============================================================================

CA_DESCRIPTION <- paste("The assumptions behind the carbon calibration (docs/carbon-assumptions.md), filled with the package defaults: change any row,",
  "or add a row for one ecodivision to override the all-ecodivisions row. Build scenarios depend on this scenario (it is not run).",
  "CBM Crosswalk: the CBM-CFS3 ecozone and species type each forest type takes its live turnover and snag rates from, and an optional mean",
  "annual temperature for dead-pool decay (blank = PRISM). Dead Organic Matter Parameters: each dead pool's base decay rate, reference",
  "temperature, Q10 and share emitted, and the AG Slow -> BG Slow transfer. Live Turnover: live pool turnover and snag fall (empty = CBM).",
  "Spin-up: return interval, share of past cycles ended by clearcut, last disturbance outside fire perimeters (empty = LANDFIRE, all fire,",
  "clearcut). Disturbance Flows: where high-severity fire and clearcut move each pool's carbon. Fire Snag Share: the share of live wood",
  "high-severity fire leaves standing, per forest type.")
DOM_POOL_LIST <- c("AG Very Fast", "BG Very Fast", "AG Fast", "BG Fast", "AG Medium", "AG Slow", "BG Slow", "Snag Stem", "Snag Branch")

fill_carbon_assumptions <- function(ca, pkg) {
  rd <- function(...) data.table::fread(file.path(pkg, "defaults", ...), colClasses = "character", na.strings = "")
  empty <- function(sh) !nrow(suppressWarnings(datasheet(ca, sh, optional = TRUE)))
  done <- character()
  if (empty("lucasCore_CbmCrosswalk")) { x <- rd("cbm", "species-crosswalk.csv")
    saveDatasheet(ca, data.frame(StateClassId = x$StateClassId, CbmEcozoneId = x$EcoBoundaryId, CbmSpeciesTypeId = x$SpeciesTypeId), "lucasCore_CbmCrosswalk")
    done <- c(done, sprintf("CBM Crosswalk %d rows", nrow(x))) }
  if (empty("lucasCore_DomParameter")) { x <- rd("cbm", "dom-parameters.csv")
    saveDatasheet(ca, data.frame(Pool = match(x$Pool, DOM_POOL_LIST), BaseDecayRate = as.numeric(x$BaseDecayRate), ReferenceTemperature = as.numeric(x$ReferenceTemperature),
                                 Q10 = as.numeric(x$Q10), ShareEmitted = as.numeric(x$ShareEmitted), TransferToBGSlow = as.numeric(x$TransferToBGSlow)), "lucasCore_DomParameter")
    done <- c(done, sprintf("Dead Organic Matter Parameters %d rows", nrow(x))) }
  if (empty("lucasCore_DisturbanceFlow")) {
    e <- new.env(); for (f in c("flows.R", "dom.R")) sys.source(file.path(pkg, "src", f), envir = e)
    x <- e$events_to_sheet(rd("stockflow", "event-pathways.csv"))
    saveDatasheet(ca, data.frame(Disturbance = match(x$Disturbance, names(e$DF_GROUPS)), AgeMin = x$AgeMin, FromStockTypeId = x$FromStockTypeId,
                                 ToStockTypeId = x$ToStockTypeId, Share = x$Share), "lucasCore_DisturbanceFlow")
    done <- c(done, sprintf("Disturbance Flows %d rows", nrow(x))) }
  if (empty("lucasCore_FireSnagShare")) { x <- rd("spinup", "fire-snag-share.csv")
    sc <- data.table::as.data.table(datasheet(ca, "stsim_StateClass", lookupsAsFactors = FALSE))
    x[, StateClass := sc$Name[match(StateClassId, as.character(sc$Id))]]; x <- x[!is.na(StateClass)]
    if (nrow(x)) { saveDatasheet(ca, data.frame(StateClassId = x$StateClass, Share = as.numeric(x$Share)), "lucasCore_FireSnagShare")
      done <- c(done, sprintf("Fire Snag Share %d rows", nrow(x))) } }
  if (length(done)) description(ca) <- CA_DESCRIPTION
  done }
