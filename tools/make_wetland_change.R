# =============================================================================
# make_wetland_change.R - the carbon of change among water, wetland and barren (to-do 2 step 5; user 2026-11-25: "Go to step 5")
# =============================================================================
# OPEN BEFORE RELEASE (user 2026-11-25): emitting every pool to the atmosphere when a wetland becomes water "does not seem right".
# The rows below are a placeholder taken from lucasWet; the fate of marsh carbon (emitted, left under water, sent to Aquatic, and over
# how many years) must be settled before this work is finalized.
# Writes, removing its own earlier rows first (so a rerun does not duplicate anything) and touching no other row:
#   defaults/stockflow/event-pathways.csv
#     Wetland Change: to Water, from every wetland class (emergent, forested and the disturbed forested twins): every live pool and every
#     dead pool down to the soil (DOM: Belowground Slow) leaves to the atmosphere as CO2 in the year of the change. This is what
#     lucasWet's Barataria model does through its classes "Water: Previously Emergent Wetland" and "Water: Previously Forested
#     Wetland" (D:/lucasWet, Barataria LocalCH4 GWP-100.ssim, read 2026-11-25): biomass turns over whole, every dead pool's emission is
#     1, lateral transport to Aquatic and burial are 0. Deep Soil, Peat and Black Carbon have no flow there and stay with the cell here.
#     One share (WATER_EMIT) sets it; the rest of each pool stays under water, where Water: All has no flows.
#     Barren that becomes water (a reservoir bed refilling) has no row: nothing moves.
#     Wetland Change: to Barren, from the two emergent classes: the live plants die into litter and root litter; nothing is emitted.
#     Barren has no flows, so the dead matter and the soil keep their carbon until the cell changes again.
#     Water or barren that becomes wetland has no row: the new marsh starts with the cell's stocks and grows on its class's flows.
# Usage: Rscript tools/make_wetland_change.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
D <- function(...) file.path(pkg, "defaults", ...)
WATER_EMIT <- 1   # share of each live and dead pool emitted when a wetland cell becomes water (lucasWet: all of it)
TO_WATER <- "Wetland Change: to Water [Type]"; TO_BARREN <- "Wetland Change: to Barren [Type]"
pw <- fread(D("transitions", "pathways", "wetland-change.csv"), colClasses = "character", na.strings = "")
wet <- pw[TransitionTypeId == "Wetland Change: to Water" & grepl("Wetland", StateClassIdSource), StateClassIdSource]
emg <- pw[TransitionTypeId == "Wetland Change: to Barren" & grepl("^Wetland: ", StateClassIdSource), StateClassIdSource]
LIVE <- paste("Biomass:", c("Coarse Root", "Fine Root", "Foliage", "Merchantable", "Other Wood"))
DEAD <- paste("DOM:", c("Aboveground Very Fast", "Aboveground Fast", "Aboveground Medium", "Aboveground Slow", "Belowground Very Fast", "Belowground Fast", "Belowground Slow", "Snag Stem", "Snag Branch"))
row <- function(cls, from, to, grp, flow, m) sprintf(",,,,,%s,,%s,,,,%s,%s,,%s,,%s,,,,,", cls, from, to, grp, flow, format(m, scientific = FALSE))
water <- unlist(lapply(wet, function(cl) c(row(cl, LIVE, "Atmosphere: CO2", TO_WATER, "LULC: Emission Live CO2", WATER_EMIT), row(cl, DEAD, "Atmosphere: CO2", TO_WATER, "LULC: Emission DOM CO2", WATER_EMIT))))
DIE <- data.table(from = paste("Biomass:", c("Foliage", "Fine Root", "Fine Root", "Coarse Root", "Coarse Root", "Merchantable", "Other Wood")),
                  to = paste("DOM:", c("Aboveground Very Fast", "Aboveground Very Fast", "Belowground Very Fast", "Aboveground Fast", "Belowground Fast", "Snag Stem", "Snag Branch")), m = c(1, 0.5, 0.5, 0.5, 0.5, 1, 1))
barren <- unlist(lapply(emg, function(cl) row(cl, DIE$from, DIE$to, TO_BARREN, "LULC: Mortality Live", DIE$m)))
f <- D("stockflow", "event-pathways.csv"); l <- sub("\r$", "", readLines(f, encoding = "UTF-8"))
keep <- c(l[1], l[-1][!grepl(",Wetland Change: [A-Za-z ]+ \\[Type\\],", l[-1])])
con <- file(f, "wb"); writeLines(c(keep, water, barren), con, sep = "\r\n", useBytes = TRUE); close(con)
cat(sprintf("defaults/stockflow/event-pathways.csv: %d lines removed, %d written (%d wetland classes to water, %d emergent classes to barren)\n", length(l) - length(keep), length(water) + length(barren), length(wet), length(emg)))
