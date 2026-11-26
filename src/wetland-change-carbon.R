# =============================================================================
# wetland-change-carbon.R - the carbon of change among water, wetland and barren (to-do 2; stage 3 and tools/make_wetland_change.R)
# =============================================================================
# User decisions 2026-11-25: when a wetland cell becomes water each pool splits three ways, to the atmosphere (CO2), to Aquatic, and
# what stays in the cell under water, all in the year of the change ("The three way split is good. All the fluxes should occur in the
# transition year"), with the shares on a Build page ("expose these numbers ... in the UI during the Build").
#   Coastal  the estuarine wetland classes (emergent and forested): the platform erodes or ponds
#   Inland   every other class that can become water: the other wetland classes (palustrine emergent, the forested groups and their
#            disturbed twins) and the upland forest, shrub and grass classes (a new reservoir, user 2026-11-26): flooded in place
#   Soil     DOM: Belowground Slow (the top metre);  Plants and litter: the live pools and every other dead pool
#   Deep Soil, DOM: Peat and DOM: Black Carbon have no row: they stay with the cell.
# The shares and where each comes from: defaults/stockflow/wetland-change-carbon.csv (Default; Low and High are the published or
# judged range, shown on the page, not sampled). The page (package.xml WetlandChangeCarbon, single row) replaces a default when filled.
# Forest that becomes water (user 2026-11-26: "forest Stems and Coarse Roots go to deadwood"): in a tree class (WCC_TREE) the stems move to
# DOM: Snag Stem and the coarse roots to DOM: Belowground Fast, and what those two dead pools already hold stays; the shares above do not
# touch them. A Water cell then releases both pools to the atmosphere at one yearly rate (FloodedWoodDecay, default 1%; wcc_water_rows).
# Water has no other carbon flow: every other pool left in a flooded cell stays as it is.
# Wetland to barren (emergent classes): the live plants die into litter and root litter; nothing leaves the cell.
# Water or barren that becomes wetland, and barren that becomes water, have no row.
# Emission and mortality use the standard land-use change flow types; the transition group of each row says which event it is (user
# 2026-11-26: "Why not just turn the standard pathways on?"). The emergent classes' flow multipliers used to set every LULC flow group
# to 0 (defaults/stockflow/nonforest-multipliers-wetland.csv), which silenced these rows and the classes' own fire rows; those 380
# rows are gone. Carbon carried to Aquatic has two flow types of its own: no standard event type goes to Aquatic, and the yearly
# lateral transport types carry each class's small yearly rate as their multiplier.
# =============================================================================
WCC_WATER <- "Wetland Change: to Water [Type]"; WCC_BARREN <- "Wetland Change: to Barren [Type]"; WCC_COASTAL <- "Estuarine"
WCC_UPLAND <- "^(Forest|Disturbed|Shrubland|Grassland): "; WCC_UPLAND_ROW <- "^,,,(Forest|Shrubland|Grassland|Disturbed): [^,]*,,Water: All,"   # the upland classes that can become water (tools/make_wetland_change.R)
WCC_TYPES <- c(emit_live = "LULC: Emission Live CO2", emit_dom = "LULC: Emission DOM CO2", export_live = "Wetland Change: Export Live",
               export_dom = "Wetland Change: Export DOM", die = "LULC: Mortality Live")
WCC_NEW <- WCC_TYPES[c("export_live", "export_dom")]   # the two the package adds to the standard set
WCC_LIVE <- paste("Biomass:", c("Coarse Root", "Fine Root", "Foliage", "Merchantable", "Other Wood")); WCC_SOIL <- "DOM: Belowground Slow"
WCC_LITTER <- paste("DOM:", c("Aboveground Very Fast", "Aboveground Fast", "Aboveground Medium", "Aboveground Slow", "Belowground Very Fast", "Belowground Fast", "Snag Stem", "Snag Branch"))
WCC_COLS <- c("Iteration", "Timestep", "FromStratumId", "FromSecondaryStratumId", "FromTertiaryStratumId", "FromStateClassId", "FromAgeMin", "FromStockTypeId", "ToStratumId", "ToStateClassId", "ToAgeMin",
              "ToStockTypeId", "TransitionGroupId", "StateAttributeTypeId", "FlowTypeId", "TargetType", "Multiplier", "TransferToStratumId", "TransferToSecondaryStratumId", "TransferToTertiaryStratumId", "TransferToStateClassId", "TransferToAgeMin")
WCC_POOLS <- c("CoastalSoil", "CoastalPlant", "InlandSoil", "InlandPlant")

WCC_TREE <- "^Forest: |Forested$|Group$"; WCC_DECAY <- "FloodedWoodDecay"   # the classes with trees (forest, forested wetland, and their disturbed twins); the rate column
WCC_WOOD <- data.table::data.table(live = c("Biomass: Merchantable", "Biomass: Coarse Root"), dead = c("DOM: Snag Stem", "DOM: Belowground Fast"), flow = c("Emission: Snag Stem -> Atmosphere", "Emission: BG Fast -> Atmosphere"))
# The shares: the defaults table (a data.table of defaults/stockflow/wetland-change-carbon.csv) with the page's row over it (blank = the
# default). Returns a named numeric vector by Column; stops when a share is outside 0-1 or a pool's two shares pass 1.
wcc_shares <- function(def, sheet = NULL) {
  v <- setNames(as.numeric(def$Default), def$Column); src <- setNames(rep("default", length(v)), names(v))
  if (!is.null(sheet) && nrow(sheet)) for (k in intersect(names(v), names(sheet))) { x <- suppressWarnings(as.numeric(sheet[[k]][1])); if (!is.na(x)) { v[k] <- x; src[k] <- "page" } }
  bad <- is.na(v) | v < 0 | v > 1
  if (any(bad)) stop(sprintf("Wetland Change Carbon: a share must be between 0 and 1 (%s)", paste(names(v)[bad], collapse = ", ")))
  for (p in WCC_POOLS) { s <- v[[paste0(p, "Emitted")]] + v[[paste0(p, "Aquatic")]]
    if (s > 1 + 1e-9) stop(sprintf("Wetland Change Carbon: %sEmitted + %sAquatic is %.3f; the two shares of a pool cannot pass 1", p, p, s)) }
  attr(v, "source") <- src; v }

# The event rows (character columns, as defaults/stockflow/event-pathways.csv). v: wcc_shares(); pw: the pathways
# (defaults/transitions/pathways/wetland-change.csv). A share of 0 writes no row.
wcc_rows <- function(v, pw) {
  wet <- pw[TransitionTypeId == "Wetland Change: to Water" & !grepl("^(Barren|Water): ", StateClassIdSource), unique(StateClassIdSource)]   # every class with carbon to lose
  emg <- pw[TransitionTypeId == "Wetland Change: to Barren" & grepl("^Wetland: ", StateClassIdSource), unique(StateClassIdSource)]
  one <- function(cl, from, to, grp, type, m) data.table::data.table(FromStateClassId = cl, FromStockTypeId = from, ToStockTypeId = to, TransitionGroupId = grp, FlowTypeId = type, Multiplier = m)
  water <- data.table::rbindlist(lapply(wet, function(cl) { p <- if (grepl(WCC_COASTAL, cl, fixed = TRUE)) "Coastal" else "Inland"; g <- function(k) v[[paste0(p, k)]]
    tree <- grepl(WCC_TREE, cl); lv <- if (tree) setdiff(WCC_LIVE, WCC_WOOD$live) else WCC_LIVE; lt <- if (tree) setdiff(WCC_LITTER, WCC_WOOD$dead) else WCC_LITTER
    rbind(if (tree) one(cl, WCC_WOOD$live, WCC_WOOD$dead, WCC_WATER, WCC_TYPES[["die"]], 1),
          one(cl, lv, "Atmosphere: CO2", WCC_WATER, WCC_TYPES[["emit_live"]], g("PlantEmitted")), one(cl, lv, "Aquatic", WCC_WATER, WCC_TYPES[["export_live"]], g("PlantAquatic")),
          one(cl, lt, "Atmosphere: CO2", WCC_WATER, WCC_TYPES[["emit_dom"]], g("PlantEmitted")), one(cl, lt, "Aquatic", WCC_WATER, WCC_TYPES[["export_dom"]], g("PlantAquatic")),
          one(cl, WCC_SOIL, "Atmosphere: CO2", WCC_WATER, WCC_TYPES[["emit_dom"]], g("SoilEmitted")), one(cl, WCC_SOIL, "Aquatic", WCC_WATER, WCC_TYPES[["export_dom"]], g("SoilAquatic"))) }))
  die <- data.table::data.table(from = paste("Biomass:", c("Foliage", "Fine Root", "Fine Root", "Coarse Root", "Coarse Root", "Merchantable", "Other Wood")),
                                to = paste("DOM:", c("Aboveground Very Fast", "Aboveground Very Fast", "Belowground Very Fast", "Aboveground Fast", "Belowground Fast", "Snag Stem", "Snag Branch")), m = c(1, 0.5, 0.5, 0.5, 0.5, 1, 1))
  barren <- data.table::rbindlist(lapply(emg, function(cl) one(cl, die$from, die$to, WCC_BARREN, WCC_TYPES[["die"]], die$m)))
  x <- rbind(water, barren)[Multiplier > 0]; x[, Multiplier := format(Multiplier, scientific = FALSE, trim = TRUE, drop0trailing = TRUE)]
  for (k in setdiff(WCC_COLS, names(x))) x[, (k) := NA_character_]
  data.table::setcolorder(x, WCC_COLS); x[] }

# The yearly release of flooded dead wood on Water cells: fp, the two flow pathways (at 1), and fm, their flow multipliers (the rate).
wcc_water_rows <- function(v, water = "Water: All") list(
  fp = data.table::data.table(FromStateClassId = water, FromStockTypeId = WCC_WOOD$dead, ToStockTypeId = "Atmosphere", FlowTypeId = WCC_WOOD$flow, Multiplier = 1),
  fm = data.table::data.table(StateClassId = water, FlowGroupId = paste(WCC_WOOD$flow, "[Type]"), Value = v[[WCC_DECAY]]))
# One line for the log: the shares in use and which came from the page.
wcc_label <- function(v) { s <- attr(v, "source"); f <- function(p) sprintf("%.0f%% emitted, %.0f%% to Aquatic, %.0f%% stays", 100 * v[[paste0(p, "Emitted")]], 100 * v[[paste0(p, "Aquatic")]], 100 * (1 - v[[paste0(p, "Emitted")]] - v[[paste0(p, "Aquatic")]]))
  sprintf("coastal soil %s; coastal plants and litter %s; inland soil %s; inland plants and litter %s; flooded forest stems and coarse roots to dead wood, released at %s%% a year (%s)", f("CoastalSoil"), f("CoastalPlant"), f("InlandSoil"), f("InlandPlant"), format(100 * v[[WCC_DECAY]]),
          if (any(s == "page")) paste("from the page:", paste(names(s)[s == "page"], collapse = ", ")) else "the package defaults") }
