# =============================================================================
# make_nonforest_fire.R - grassland, shrubland and emergent wetland fire flows by severity (to-do 39, 2026-11-07)
# =============================================================================
# Run from the package root: Rscript tools/make_nonforest_fire.R
# Before this, only chaparral had fire rows of its own, and only for high severity; every other fire on grass, shrub and emergent
# wetland used the all-class rows, which are forest's (medium severity killed 53.5% of roots; high severity killed 95% of grass roots).
# Reads defaults/stockflow/nonforest-fire.csv (one row per class and severity: shares of each pool burned, killed and left, with the
# basis of each) and chaparral-age.csv (chaparral's high severity, which its starting pools by age also use: tools/make_grass_shrub.R).
# For each class and severity the shares become one row per from -> to pool pair that the all-class rows of that fire use, 0 where the
# class moves nothing: in ST-Sim a class row hides the all-class rows of its pair at every age (checked on the Solano run 2026-11-07:
# chaparral's high-severity wood split 0.55 burned / 0.45 standing exactly). To = Atmosphere is the carbon burned, split 90% CO2, 9% CO,
# 1% CH4 (src/dom.R GAS_SPLIT).
# Writes:
#   high severity          the class rows of both Disturbance Flows presets (defaults/carbon-assumptions/<method>/disturbance-flows.csv);
#                          stage 3 adds a class's preset rows to a filled sheet that has none for it
#   medium and low         class rows in defaults/stockflow/event-pathways.csv (those two fires are not on the Disturbance Flows sheet)
# Rerunning is harmless: it replaces the class rows it wrote before.
# =============================================================================
suppressPackageStartupMessages(library(data.table))
source("src/dom.R")
d <- function(...) file.path("defaults", ...)
rd <- function(...) fread(d(...), colClasses = "character", na.strings = "", encoding = "UTF-8")
wr <- function(x, ...) fwrite(x, d(...), na = "", quote = "auto")
FOL <- "Biomass: Foliage"; WOOD <- "Biomass: Other Wood"; MER <- "Biomass: Merchantable"; FR <- "Biomass: Fine Root"; CR <- "Biomass: Coarse Root"
AGVF <- "DOM: Aboveground Very Fast"; AGF <- "DOM: Aboveground Fast"; AGM <- "DOM: Aboveground Medium"; AGS <- "DOM: Aboveground Slow"
SB <- "DOM: Snag Branch"; SS <- "DOM: Snag Stem"; BGVF <- "DOM: Belowground Very Fast"; BGF <- "DOM: Belowground Fast"
GROUP <- c(High = "Fire: High Severity [Type]", Medium = "Fire: Medium Severity [Type]", Low = "Fire: Low Severity [Type]")

f <- rd("stockflow", "nonforest-fire.csv"); num <- c("Foliage", "FoliageKilled", "Wood", "WoodKilled", "RootKilled", "Litter", "AgMedium", "AgSlow", "Snag")
for (k in num) set(f, j = k, value = as.numeric(f[[k]]))
cp <- rd("stockflow", "chaparral-age.csv"); cpv <- setNames(as.numeric(cp$Value), cp$Parameter)
f <- rbind(f, data.table(StateClassId = "Shrubland: Chaparral", Severity = "High", Foliage = cpv[["FireFoliage"]], FoliageKilled = 1 - cpv[["FireFoliage"]],
                         Wood = cpv[["FireWood"]], WoodKilled = 1 - cpv[["FireWood"]], RootKilled = 1 - cpv[["RootSurvival"]], Litter = cpv[["FireDead"]],
                         AgMedium = cpv[["FireDead"]], AgSlow = cpv[["FireAgSlow"]], Snag = cpv[["FireDead"]], Source = "chaparral-age.csv"))
if (anyDuplicated(f[, .(StateClassId, Severity)])) stop("nonforest-fire.csv: a class and severity twice")
if (f[, any(Foliage + FoliageKilled > 1 + 1e-9 | Wood + WoodKilled > 1 + 1e-9 | RootKilled > 1)]) stop("nonforest-fire.csv: a pool gives more than its whole stock")
CLASSES <- unique(f$StateClassId)

# the shares of one class and severity, by from -> to pair (To "Atmosphere" = burned)
shares <- function(r) c(
  setNames(c(r$Foliage, r$Wood, r$Wood, r$Litter, r$Litter, r$AgMedium, r$AgSlow, r$Snag, r$Snag),
           paste(c(FOL, WOOD, MER, AGVF, AGF, AGM, AGS, SB, SS), "Atmosphere")),
  setNames(c(r$FoliageKilled, r$WoodKilled, r$WoodKilled, r$RootKilled, r$RootKilled),
           paste(c(FOL, WOOD, MER, FR, CR), c(AGVF, SB, SS, BGVF, BGF))))
used <- data.table(FromStockTypeId = c(FOL, WOOD, MER, AGVF, AGF, AGM, AGS, SB, SS, FOL, WOOD, MER, FR, CR),
                   ToStockTypeId = c(rep("Atmosphere", 9), AGVF, SB, SS, BGVF, BGF))
class_rows <- function(pairs, sev) rbindlist(lapply(CLASSES, function(cls) { r <- f[StateClassId == cls & Severity == sev]
  if (!nrow(r)) stop(sprintf("nonforest-fire.csv: no %s row for %s", sev, cls))
  s <- shares(r); p <- copy(pairs); k <- paste(p$FromStockTypeId, p$ToStockTypeId)
  p[, `:=`(StratumId = NA_character_, StateClassId = cls, Disturbance = "High-severity fire", AgeMin = NA_integer_, Share = ifelse(k %in% names(s), s[k], 0))] }))
pairs_of <- function(x) unique(rbind(unique(x[, .(FromStockTypeId, ToStockTypeId)]), used))

# ---- high severity: the Disturbance Flows presets ------------------------------------------------------------------------------
for (m in c("cbm-defaults", "fia-measured")) {
  x <- rd("carbon-assumptions", m, "disturbance-flows.csv")
  gen <- x[Disturbance == "High-severity fire" & is.na(StratumId) & is.na(StateClassId)]
  rows <- class_rows(pairs_of(gen), "High")[, .(StratumId, StateClassId, Disturbance, AgeMin = as.character(AgeMin), FromStockTypeId, ToStockTypeId, Share = as.character(signif(Share, 6)))]
  x <- rbind(x[!(StateClassId %in% CLASSES & Disturbance == "High-severity fire")], rows)
  wr(x, "carbon-assumptions", m, "disturbance-flows.csv")
  cat(sprintf("%s: %d high-severity fire rows for %d classes\n", m, nrow(rows), length(CLASSES))) }

# ---- medium and low severity: class rows in the event table ----------------------------------------------------------------------
ev <- rd("stockflow", "event-pathways.csv")
for (sev in c("Medium", "Low")) { g <- GROUP[[sev]]
  gen <- ev[TransitionGroupId == g & is.na(FromStateClassId) & is.na(FromStratumId)][, ToStockTypeId := ifelse(startsWith(ToStockTypeId, "Atmosphere: "), "Atmosphere", ToStockTypeId)]
  sh <- class_rows(pairs_of(gen), sev)
  e <- sheet_to_events(sh, ev, CLASSES)[, TransitionGroupId := g]
  ev <- rbind(ev[!(TransitionGroupId == g & FromStateClassId %in% CLASSES)], e[, names(ev), with = FALSE])
  cat(sprintf("%s severity: %d event rows for %d classes\n", sev, nrow(e), length(CLASSES))) }
wr(ev, "stockflow", "event-pathways.csv")
