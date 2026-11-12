# =============================================================================
# make_reforestation.R - the Reforestation transition: its group, types and pathways (to-do 57 step 5; user 2026-11-12)
# =============================================================================
# A natural non-forest cell becomes forest when NLCD shows forest (historical runs, stage 6) or where the projection's suitability
# surface puts it (stages 9-10). Each forest type is its own transition type, "Reforestation: <type>" (as Ag Contraction's), so
# stage 6 can gate each to the cells whose destination is that type (stage 5's ReforestType.tif); all are in the group
# "Reforestation". Pathways: from every natural non-forest class - Barren: All, the shrub classes (sage family, Non-sage,
# Chaparral), the grass classes and Wetland: Palustrine Emergent - to every forest type group and forested wetland twin (Ids
# 100-999), probability 1, age reset (a new stand from age 0, user 2026-11-12; the grass or shrub live carbon carries over, since no
# flows are triggered). Left out: the disturbed classes (they return by Post-disturbance: Forest Return within their window),
# Shrubland: Post Fire Shrub (class 59, to be retired), Wetland: Estuarine Emergent (tidal marsh), the estuarine forested class
# (91; no FIA curves of its own as a destination).
# Writes defaults/transitions/pathways/reforestation.csv and the Reforestation rows of defaults/stsim (TransitionType,
# TransitionGroup, TransitionTypeGroup; not TransitionSimulationGroup, as Post-disturbance) and defaults/stockflow/main-transition-groups.csv. Rerunnable.
# A library made before gets the group and types from the 1.4 update (ui/LucasCoreUpdates.cs, Update_1_400).
# Usage: Rscript tools/make_reforestation.R   (from the repository root)
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
D <- function(...) file.path(pkg, "defaults", ...)
rd <- function(f) fread(f, sep = ",", colClasses = "character", na.strings = NULL, encoding = "UTF-8", fill = TRUE)
wr <- function(x, f) { for (k in names(x)) set(x, which(x[[k]] == ""), k, NA_character_); fwrite(x, f, quote = "auto", na = ""); cat(sprintf("%-62s %d rows\n", sub(paste0(pkg, "/"), "", f), nrow(x))) }
GRP <- "Reforestation"; PFX <- "Reforestation: "; ID0 <- 1100L
SOURCES <- c("Barren: All", "Shrubland: Sage", "Shrubland: Native Sage Steppe", "Shrubland: Invaded Sage Steppe", "Shrubland: Non-sage", "Shrubland: Chaparral",
             "Grassland: Annual", "Grassland: Natural Perennial", "Grassland: Irrigated Perennial", "Wetland: Palustrine Emergent")

sc <- rd(D("stsim", "stsim_StateClass.csv")); stopifnot(all(SOURCES %in% sc$Name))
fo <- sc[as.integer(Id) >= 100 & as.integer(Id) <= 999][order(as.integer(Id))]
fo[, ylab := fifelse(StateLabelXId == "Wetland", paste("Wetland", StateLabelYId), StateLabelYId)][, type := paste0(PFX, ylab)]
stopifnot(!anyDuplicated(fo$type))

# ---- definitions ---------------------------------------------------------------------------------------------------------------
tt <- rd(D("stsim", "stsim_TransitionType.csv")); tt <- tt[!startsWith(Name, PFX)]
stopifnot(!any(as.integer(tt$Id) %in% (ID0 + seq_len(nrow(fo)) - 1L)))
tt <- rbind(tt, data.table(Name = fo$type, Id = as.character(ID0 + seq_len(nrow(fo)) - 1L), Color = "255,120,170,80", Legend = "", Description = ""), fill = TRUE)
wr(tt, D("stsim", "stsim_TransitionType.csv"))
tg <- rd(D("stsim", "stsim_TransitionGroup.csv")); tg <- tg[Name != GRP]; tg <- rbind(tg, data.table(Name = GRP, Description = "", IsAuto = ""), fill = TRUE)
wr(tg, D("stsim", "stsim_TransitionGroup.csv"))
ttg <- rd(D("stsim", "stsim_TransitionTypeGroup.csv")); ttg <- ttg[!startsWith(TransitionTypeId, PFX)]
ttg <- rbind(ttg, data.table(TransitionTypeId = fo$type, TransitionGroupId = GRP, IsAuto = ""), fill = TRUE)
wr(ttg, D("stsim", "stsim_TransitionTypeGroup.csv"))
mg <- rd(D("stockflow", "main-transition-groups.csv")); if (!GRP %in% mg$TransitionGroupId) mg <- rbind(mg, data.table(TransitionGroupId = GRP, Spatial = "Yes", SpatialProbability = "Yes"))
wr(mg, D("stockflow", "main-transition-groups.csv"))

# ---- pathways ------------------------------------------------------------------------------------------------------------------
pw <- CJ(src = SOURCES, i = seq_len(nrow(fo)), sorted = FALSE)
pw <- data.table(Iteration = "", Timestep = "", StratumIdSource = "", StateClassIdSource = pw$src, StratumIdDest = "", StateClassIdDest = fo$Name[pw$i],
                 SecondaryStratumId = "", TertiaryStratumId = "", TransitionTypeId = fo$type[pw$i], Probability = "1", Proportion = "", AgeMin = "", AgeMax = "",
                 AgeRelative = "", AgeReset = "Yes", TSTMin = "", TSTMax = "", TSTRelative = "")
wr(pw, D("transitions", "pathways", "reforestation.csv"))
cat(sprintf("Reforestation: %d types (Ids %d-%d), %d source classes, %d pathways\n", nrow(fo), ID0, ID0 + nrow(fo) - 1L, length(SOURCES), nrow(pw)))
