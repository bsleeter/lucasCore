# =============================================================================
# make_carbon_presets.R - the Carbon Assumptions rows of each carbon method, as one CSV per sheet (user, 2026-10-28)
# =============================================================================
# defaults/carbon-assumptions/<method>/<sheet>.csv, with the sheets' own column names and the values as the pages show them (lookup
# names, list labels), so the Carbon Method page's Fill button (ui/Defaults.cs), tools/carbon-assumptions.R (new and synced libraries)
# and stage 3 (a Carbon Assumptions scenario never filled) all read the same rows:
#   fia-measured   FIA measured dead wood (Carbon Options 4): the fitted fire and clearcut flows (defaults/stockflow/event-pathways.csv),
#                  the fitted fire snag shares, the calibration settings written out at their defaults
#   cbm-defaults   CBM defaults (Carbon Options 3): the LUCAS fire and clearcut flows of the CONUS 1 km build (the event table before
#                  the 2026-10-27 fit: defaults/stockflow/event-pathways-lucas.csv), no fire snag shares, no calibration settings
# Both: the CBM Crosswalk and Dead Organic Matter Parameters of the package (CBM-CFS3), the Growth Inputs of the package (forest type
# crosswalk and merchantable carbon density); Live Turnover, Spin-up, Mature Age by Forest Type and Fixed Decay
# Multipliers empty (CBM rates, stage 5's LANDFIRE intervals, nothing fixed). Rerun after changing any of those defaults.
# Usage: Rscript tools/make_carbon_presets.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- "F:/lucasCore"; e <- new.env(); for (f in c("flows.R", "dom.R")) sys.source(file.path(pkg, "src", f), envir = e)
rd <- function(...) fread(file.path(pkg, "defaults", ...), colClasses = "character", na.strings = "")
out <- file.path(pkg, "defaults", "carbon-assumptions"); dir.create(out, showWarnings = FALSE)
w <- function(x, method, sheet) { d <- file.path(out, method); dir.create(d, showWarnings = FALSE); fwrite(x, file.path(d, paste0(sheet, ".csv")), na = "") }

cbx <- rd("cbm", "species-crosswalk.csv")[, .(StateClassId, CbmEcozoneId = EcoBoundaryId, CbmSpeciesTypeId = SpeciesTypeId)]
dom <- rd("cbm", "dom-parameters.csv")
flows <- function(ev) e$events_to_sheet(ev)[, .(StratumId = NA_character_, StateClassId = NA_character_, Disturbance, AgeMin, FromStockTypeId, ToStockTypeId, Share)]
lucas <- rd("stockflow", "event-pathways-lucas.csv"); fitted <- rd("stockflow", "event-pathways.csv")
sc <- fread(file.path(pkg, "defaults", "stsim", "stsim_StateClass.csv"), colClasses = "character")
fss <- rd("spinup", "fire-snag-share.csv")[, .(StateClassId = sc$Name[match(StateClassId, sc$Id)], Share)]
if (anyNA(fss$StateClassId)) stop("fire-snag-share.csv has state class ids not in defaults/stsim/stsim_StateClass.csv")
settings <- data.table(MatureAge = 60L, ExclusionYears = 30L, MinPlotsOwnFit = 30L, MinSnagsOwnRate = 200L, MinPlotsConditionPools = 200L,
                       MultiplierMin = 0.05, MultiplierMax = 20, SoilMultiplierMin = 0.02, SoilMultiplierMax = 50)
cw <- rd("growth", "forest-type-crosswalk.csv"); den <- rd("growth", "merch-carbon-density.csv")
gcl <- c(EastSoftwood = "East Softwood", EastHardwood = "East Hardwood", WestSoftwood = "West Softwood", WestHardwood = "West Hardwood")
growth <- data.table(StateClassId = sc$Name[match(cw$StateClassId, sc$Id)], FiaTypeGroups = cw$FiaTypeGroups, GrowthClass = unname(gcl[cw$LagClass]),
                     MerchCarbonDensity = den$MgCPerM3[match(cw$StateClassId, den$StateClassId)], DeciduousShare = den$DeciduousShare[match(cw$StateClassId, den$StateClassId)], FineRootShare = NA_character_)
if (anyNA(growth[, !"FineRootShare"])) stop("forest-type-crosswalk.csv and merch-carbon-density.csv do not cover the same state classes")
empty <- list(`live-turnover` = data.table(StratumId = character(), StateClassId = character()),
              `mature-age` = data.table(StratumId = character(), StateClassId = character(), MatureAge = character(), ExclusionYears = character()),
              `spin-up` = data.table(StratumId = character(), StateClassId = character()),
              `fixed-decay-multipliers` = data.table(StratumId = character(), StateClassId = character(), Pool = character(), Multiplier = character()))
for (m in c("fia-measured", "cbm-defaults")) {
  w(cbx, m, "cbm-crosswalk"); w(dom, m, "dom-parameters"); w(growth, m, "growth-inputs")
  w(flows(if (m == "fia-measured") fitted else lucas), m, "disturbance-flows")
  w(if (m == "fia-measured") fss else fss[0], m, "fire-snag-share")
  w(if (m == "fia-measured") settings else settings[0], m, "decay-calibration-settings")
  for (k in names(empty)) w(empty[[k]], m, k) }
for (m in c("fia-measured", "cbm-defaults")) cat(m, ":", paste(sprintf("%s %d", sub("\\.csv$", "", list.files(file.path(out, m))),
    sapply(list.files(file.path(out, m), full.names = TRUE), function(f) nrow(fread(f)))), collapse = ", "), "\n")
