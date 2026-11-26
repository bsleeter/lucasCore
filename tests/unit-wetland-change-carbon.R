# Fast test of the carbon of water, wetland and barren change (to-do 2 step 5; no SyncroSim). Run: Rscript tests/unit-wetland-change-carbon.R (from the package root)
# The event rows tools/make_wetland_change.R writes: what leaves a wetland cell that becomes water or barren, and what does not.
suppressPackageStartupMessages(library(data.table))
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
rd <- function(...) fread(file.path("defaults", ...), colClasses = "character", na.strings = "")
ev <- rd("stockflow", "event-pathways.csv"); w <- ev[grepl("^Wetland Change", TransitionGroupId)][, m := as.numeric(Multiplier)]
pw <- rd("transitions", "pathways", "wetland-change.csv"); st <- rd("stsim", "stsim_StockType.csv")[[1]]; ft <- rd("stsim", "stsim_FlowType.csv")[[1]]; scl <- rd("stsim", "stsim_StateClass.csv")[[1]]
tw <- w[TransitionGroupId == "Wetland Change: to Water [Type]"]; tb <- w[TransitionGroupId == "Wetland Change: to Barren [Type]"]
wet <- pw[TransitionTypeId == "Wetland Change: to Water" & StateClassIdSource != "Barren: All", StateClassIdSource]
check("only the two groups with carbon have rows", setequal(unique(w$TransitionGroupId), c("Wetland Change: to Water [Type]", "Wetland Change: to Barren [Type]")))
check("stocks, flow types and classes are in the stsim lists", all(c(w$FromStockTypeId, w$ToStockTypeId) %in% st) && all(w$FlowTypeId %in% ft) && all(w$FromStateClassId %in% scl))
check("every row names its class: nothing applies to every class", !anyNA(w$FromStateClassId))
check("to water: every wetland class with the pathway has rows, and no other class", setequal(unique(tw$FromStateClassId), wet))
check("to water: Barren and Water lose nothing", !any(w$FromStateClassId %in% c("Barren: All", "Water: All")))
pools <- c(paste("Biomass:", c("Coarse Root", "Fine Root", "Foliage", "Merchantable", "Other Wood")), grep("^DOM: (Above|Below|Snag)", st, value = TRUE))
check("to water: every live and dead pool of every class goes to the atmosphere as CO2", all(tw[, .(ok = setequal(FromStockTypeId, pools) && all(ToStockTypeId == "Atmosphere: CO2")), by = FromStateClassId]$ok))
check("to water: deep soil, peat and black carbon stay", !any(w$FromStockTypeId %in% c("Deep Soil", "DOM: Peat", "DOM: Black Carbon")))
sh <- w[, .(s = sum(m)), by = .(TransitionGroupId, FromStateClassId, FromStockTypeId)]
check("no event moves more than a pool holds", all(sh$s <= 1 + 1e-9) && all(w$m >= 0))
check("to water: the whole pool leaves (lucasWet's water that was wetland)", all(abs(sh[TransitionGroupId == "Wetland Change: to Water [Type]", s] - 1) < 1e-9))
check("to barren: the emergent classes only, live pools to dead pools, nothing emitted", setequal(unique(tb$FromStateClassId), c("Wetland: Estuarine Emergent", "Wetland: Palustrine Emergent")) &&
        all(grepl("^Biomass: ", tb$FromStockTypeId)) && all(grepl("^DOM: ", tb$ToStockTypeId)) && all(tb$FlowTypeId == "LULC: Mortality Live"))
check("to barren: every live pool dies whole", all(abs(sh[TransitionGroupId == "Wetland Change: to Barren [Type]", s] - 1) < 1e-9) && sh[TransitionGroupId == "Wetland Change: to Barren [Type]", uniqueN(FromStockTypeId)] == 5)
check("no row is given twice", !anyDuplicated(w[, paste(TransitionGroupId, FromStateClassId, FromStockTypeId, ToStockTypeId)]))
check("emissions use the land-use change flow types, live and dead", all(tw[grepl("^Biomass", FromStockTypeId), FlowTypeId] == "LULC: Emission Live CO2") && all(tw[grepl("^DOM", FromStockTypeId), FlowTypeId] == "LULC: Emission DOM CO2"))
# the tool writes what the file holds (a rerun changes nothing)
tmp <- file.path(tempdir(), "wcc"); unlink(tmp, recursive = TRUE); for (d in c("tools", "defaults/stockflow", "defaults/transitions/pathways")) dir.create(file.path(tmp, d), recursive = TRUE)
file.copy("tools/make_wetland_change.R", file.path(tmp, "tools")); file.copy("defaults/stockflow/event-pathways.csv", file.path(tmp, "defaults/stockflow")); file.copy("defaults/transitions/pathways/wetland-change.csv", file.path(tmp, "defaults/transitions/pathways"))
out <- system2(file.path(R.home("bin"), "Rscript"), shQuote(file.path(tmp, "tools", "make_wetland_change.R")), stdout = TRUE, stderr = TRUE)
check("tools/make_wetland_change.R rewrites the file as it is", identical(readLines(file.path(tmp, "defaults/stockflow/event-pathways.csv")), readLines("defaults/stockflow/event-pathways.csv")))
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
