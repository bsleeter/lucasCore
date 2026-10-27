# =============================================================================
# 09-fit-events.R - high-severity fire and clearcut event flows set from FIA's before/after pairs (08-event-shares.R), then the
# mature-stand calibration (06) and the young-stand check (07) rerun with them
# =============================================================================
# 08 (California, Mediterranean Mountains, stand-replacing pairs; shares of the live aboveground wood before the event):
#   high-severity fire (65 pairs)  snags 0.54, down logs added ~0, forest floor kept 0.18      LUCAS today: snags 0.97, floor kept 0.46
#   clearcut (11 pairs)            slash (fine woody debris + down logs) 0.04, floor kept 0.71   LUCAS today: slash 0.32, floor kept 1.00
# Fitted values (stands >= 11 years; younger stands keep theirs):
#   fire      merchantable -> snag stem 0.65, emitted 0.35; other wood -> snag branch 0.30, emitted 0.70 (with 70% merchantable wood:
#             0.70 x 0.65 + 0.30 x 0.30 = 0.545 to snags); AG Slow (humus) emitted 0.80 (was 0.08), AG Very Fast stays 1.0
#   clearcut  other wood -> AG Fast 0.13 (was 1.0), the rest emitted (piled and burned; 0.30 x 0.13 = 0.04 of the wood left as slash);
#             foliage -> AG Very Fast 0.13, the rest emitted; AG Very Fast and AG Slow 29% emitted (site preparation)
# Emissions split CO2 / CO / CH4 as 0.90 / 0.09 / 0.01, as the table's fire flows do. Writes dev/fia/event-pathways-fitted.csv and runs
# 06 and 07 into dev/fia/out-cal-events.
# Usage: Rscript dev/fia/09-fit-events.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- "F:/lucasCore"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
e <- fread(file.path(pkg, "defaults/stockflow/event-pathways.csv"), na.strings = "", colClasses = "character")
FIRE <- "Fire: High Severity [Type]"; CUT <- "Forest Harvest: Forest Clearcut [Type]"
emis <- function(from, group, total, age = NA_character_) {   # three emission rows (CO2, CO, CH4) for a pool
  data.table(FromAgeMin = age, FromStockTypeId = from, ToStockTypeId = c("Atmosphere: CO2", "Atmosphere: CO", "Atmosphere: CH4"), TransitionGroupId = group,
             FlowTypeId = c("LULC: Emission Live CO2", "LULC: Emission Live CO", "LULC: Emission Live CH4"), Multiplier = as.character(round(total * c(0.9, 0.09, 0.01), 6))) }
drop <- function(group, from, age = NULL) { k <- e$TransitionGroupId == group & e$FromStockTypeId == from
  if (!is.null(age)) k <- k & (if (is.na(age)) is.na(e$FromAgeMin) else e$FromAgeMin %in% age); e <<- e[!k] }
put <- function(rows) e <<- rbind(e, rows, fill = TRUE)
# fire, stands >= 11
drop(FIRE, "Biomass: Merchantable", "11"); put(data.table(FromAgeMin = "11", FromStockTypeId = "Biomass: Merchantable", ToStockTypeId = "DOM: Snag Stem", TransitionGroupId = FIRE, FlowTypeId = "LULC: Mortality Live", Multiplier = "0.65"))
put(emis("Biomass: Merchantable", FIRE, 0.35, "11"))
drop(FIRE, "Biomass: Other Wood", "11"); put(data.table(FromAgeMin = "11", FromStockTypeId = "Biomass: Other Wood", ToStockTypeId = "DOM: Snag Branch", TransitionGroupId = FIRE, FlowTypeId = "LULC: Mortality Live", Multiplier = "0.30"))
put(emis("Biomass: Other Wood", FIRE, 0.70, "11"))
drop(FIRE, "DOM: Aboveground Slow", NA); put(emis("DOM: Aboveground Slow", FIRE, 0.80))
# clearcut
drop(CUT, "Biomass: Other Wood", NA); put(data.table(FromStockTypeId = "Biomass: Other Wood", ToStockTypeId = "DOM: Aboveground Fast", TransitionGroupId = CUT, FlowTypeId = "LULC: Mortality Live", Multiplier = "0.13"))
put(emis("Biomass: Other Wood", CUT, 0.87))
drop(CUT, "Biomass: Foliage", NA); put(data.table(FromStockTypeId = "Biomass: Foliage", ToStockTypeId = "DOM: Aboveground Very Fast", TransitionGroupId = CUT, FlowTypeId = "LULC: Mortality Live", Multiplier = "0.13"))
put(emis("Biomass: Foliage", CUT, 0.87))
put(emis("DOM: Aboveground Very Fast", CUT, 0.29)); put(emis("DOM: Aboveground Slow", CUT, 0.29))
for (k in names(e)) set(e, j = k, value = ifelse(is.na(e[[k]]), "", e[[k]]))
f <- file.path(pkg, "dev/fia/event-pathways-fitted.csv"); fwrite(e, f)
cat("fitted event table:", f, sprintf("(%d rows)\n", nrow(e)))
print(e[TransitionGroupId %in% c(FIRE, CUT) & (FromAgeMin %in% c("", "11")) & FromStockTypeId %in% c("Biomass: Merchantable", "Biomass: Other Wood", "Biomass: Foliage", "DOM: Aboveground Slow", "DOM: Aboveground Very Fast"),
        .(event = sub(" \\[Type\\]", "", TransitionGroupId), FromAgeMin, FromStockTypeId, ToStockTypeId, Multiplier)][order(event, FromStockTypeId)])
Sys.setenv(LUCAS_EVENT_FILE = f, LUCAS_CAL_OUT = file.path(pkg, "dev/fia/out-cal-events"))
for (s in c("06-calibrate-measured.R", "07-young-stand-replacing.R")) { cat("\n==== ", s, "\n"); o <- system2(RS, file.path(pkg, "dev/fia", s), stdout = TRUE, stderr = TRUE); cat(tail(o, 60), sep = "\n") }
