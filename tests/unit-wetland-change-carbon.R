# Fast test of the carbon of water, wetland and barren change (to-do 2 step 5; no SyncroSim). Run: Rscript tests/unit-wetland-change-carbon.R (from the package root)
# The event rows src/wetland-change-carbon.R makes from the shares (defaults/stockflow/wetland-change-carbon.csv, or the Build's Wetland
# Change Carbon page): what leaves a wetland cell that becomes water or barren, where it goes, and what stays.
suppressPackageStartupMessages(library(data.table))
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
rd <- function(...) fread(file.path("defaults", ...), colClasses = "character", na.strings = "")
source("src/wetland-change-carbon.R")
ev <- rd("stockflow", "event-pathways.csv"); w <- ev[grepl("^Wetland Change", TransitionGroupId)][, m := as.numeric(Multiplier)]
pw <- rd("transitions", "pathways", "wetland-change.csv"); st <- rd("stsim", "stsim_StockType.csv")[[1]]; ft <- rd("stsim", "stsim_FlowType.csv")[[1]]; scl <- rd("stsim", "stsim_StateClass.csv")[[1]]
def <- rd("stockflow", "wetland-change-carbon.csv"); v <- wcc_shares(def)
tw <- w[TransitionGroupId == WCC_WATER]; tb <- w[TransitionGroupId == WCC_BARREN]
wet <- pw[TransitionTypeId == "Wetland Change: to Water" & StateClassIdSource != "Barren: All", StateClassIdSource]
check("only the two groups with carbon have rows", setequal(unique(w$TransitionGroupId), c(WCC_WATER, WCC_BARREN)))
check("stocks, flow types and classes are in the stsim lists", all(c(w$FromStockTypeId, w$ToStockTypeId) %in% st) && all(w$FlowTypeId %in% ft) && all(w$FromStateClassId %in% scl))
check("every row names its class: nothing applies to every class", !anyNA(w$FromStateClassId))
check("to water: every wetland class with the pathway has rows, and no other class", setequal(unique(tw$FromStateClassId), wet))
check("to water: Barren and Water lose nothing", !any(w$FromStateClassId %in% c("Barren: All", "Water: All")))
check("to water: carbon goes to the atmosphere as CO2 or to Aquatic, nowhere else", all(tw$ToStockTypeId %in% c("Atmosphere: CO2", "Aquatic")))
check("deep soil, peat and black carbon stay", !any(w$FromStockTypeId %in% c("Deep Soil", "DOM: Peat", "DOM: Black Carbon")))
sh <- w[, .(s = sum(m)), by = .(TransitionGroupId, FromStateClassId, FromStockTypeId)]
check("no event moves more than a pool holds", all(sh$s <= 1 + 1e-9) && all(w$m > 0))
got <- function(cl, pool, to) { x <- tw[FromStateClassId == cl & FromStockTypeId == pool & ToStockTypeId == to, m]; if (length(x)) x else 0 }
E <- "Wetland: Estuarine Emergent"; P <- "Wetland: Palustrine Emergent"
check("coastal soil takes the coastal soil shares", got(E, WCC_SOIL, "Atmosphere: CO2") == v[["CoastalSoilEmitted"]] && got(E, WCC_SOIL, "Aquatic") == v[["CoastalSoilAquatic"]])
check("coastal plants and litter take the coastal plant shares", got(E, "Biomass: Foliage", "Atmosphere: CO2") == v[["CoastalPlantEmitted"]] && got(E, "DOM: Aboveground Very Fast", "Aquatic") == v[["CoastalPlantAquatic"]])
check("inland soil takes the inland soil shares", got(P, WCC_SOIL, "Atmosphere: CO2") == v[["InlandSoilEmitted"]] && got(P, WCC_SOIL, "Aquatic") == v[["InlandSoilAquatic"]])
check("the estuarine classes are coastal and every other wetland class inland", all(tw[FromStockTypeId == WCC_SOIL & ToStockTypeId == "Atmosphere: CO2", m == ifelse(grepl("Estuarine", FromStateClassId), v[["CoastalSoilEmitted"]], v[["InlandSoilEmitted"]])]))
check("the defaults are the values agreed 2026-11-25", identical(unname(v[c("CoastalSoilEmitted", "CoastalSoilAquatic", "CoastalPlantEmitted", "CoastalPlantAquatic", "InlandSoilEmitted", "InlandSoilAquatic", "InlandPlantEmitted", "InlandPlantAquatic")]), c(0.4, 0.1, 0.75, 0.25, 0.1, 0, 1, 0)))
check("every default sits inside its range", all(as.numeric(def$Low) <= as.numeric(def$Default) & as.numeric(def$Default) <= as.numeric(def$High)))
check("to barren: the emergent classes only, live pools to dead pools, nothing leaves", setequal(unique(tb$FromStateClassId), c(E, P)) &&
        all(grepl("^Biomass: ", tb$FromStockTypeId)) && all(grepl("^DOM: ", tb$ToStockTypeId)) && all(tb$FlowTypeId == WCC_TYPES[["die"]]))
check("to barren: every live pool dies whole", all(abs(sh[TransitionGroupId == WCC_BARREN, s] - 1) < 1e-9) && sh[TransitionGroupId == WCC_BARREN, uniqueN(FromStockTypeId)] == 5)
check("no row is given twice", !anyDuplicated(w[, paste(TransitionGroupId, FromStateClassId, FromStockTypeId, ToStockTypeId)]))
check("the events use flow types of their own (the emergent classes' LULC flow multipliers are 0)", all(w$FlowTypeId %in% WCC_TYPES) && all(WCC_TYPES %in% ft))
fm <- rd("stockflow", "nonforest-multipliers-wetland.csv")
check("no flow multiplier names the events' flow types", !any(sub(" \\[Type\\]$", "", fm$FlowGroupId) %in% WCC_TYPES))
mem <- rd("stockflow", "stsim_FlowTypeGroupMembership.csv"); fo <- rd("stockflow", "stsim_FlowOrder.csv"); of <- rd("stockflow", "stsim_OutputFilterFlows.csv")
check("each flow type has its groups, order and output row", all(WCC_TYPES %in% mem$FlowTypeId) && all(WCC_TYPES %in% fo$FlowTypeId) && all(paste(WCC_TYPES, "[Type]") %in% of[[1]]))
check("emission counts as emission and export as lateral flux, both against net biome productivity",
      all(mem[FlowTypeId %in% WCC_TYPES[c("emit_live", "emit_dom")], .(ok = "Emission: Total" %in% FlowGroupId && "Net Biome Productivity" %in% FlowGroupId), by = FlowTypeId]$ok) &&
        all(mem[FlowTypeId %in% WCC_TYPES[c("export_live", "export_dom")], .(ok = "Lateral Flux" %in% FlowGroupId && "Net Biome Productivity" %in% FlowGroupId), by = FlowTypeId]$ok))
# the page over the defaults
pg <- data.table(CoastalSoilEmitted = 0.75, CoastalSoilAquatic = NA_real_); v2 <- wcc_shares(def, pg)
check("a filled value replaces the default and a blank keeps it", v2[["CoastalSoilEmitted"]] == 0.75 && v2[["CoastalSoilAquatic"]] == 0.1 && attr(v2, "source")[["CoastalSoilEmitted"]] == "page")
check("two shares of a pool that pass 1 are refused", inherits(tryCatch(wcc_shares(def, data.table(CoastalSoilEmitted = 0.95)), error = function(e) e), "error"))
check("a share of 0 writes no row", !nrow(wcc_rows(wcc_shares(def, data.table(CoastalSoilAquatic = 0)), pw)[FromStateClassId == E & FromStockTypeId == WCC_SOIL & ToStockTypeId == "Aquatic"]))
px <- paste(readLines("package.xml", warn = FALSE), collapse = "\n")
check("the Build page has a column for every share, with the default in its label", all(vapply(seq_len(nrow(def)), function(i) grepl(sprintf('<column name="%s" displayName="[^"]*blank = %s;', def$Column[i], format(as.numeric(def$Default[i]), nsmall = 2)), px), TRUE)))
# the tool writes what the files hold (a rerun changes nothing)
tmp <- file.path(tempdir(), "wcc"); unlink(tmp, recursive = TRUE); fs <- c("tools/make_wetland_change.R", "src/wetland-change-carbon.R", "defaults/stockflow/event-pathways.csv", "defaults/stockflow/wetland-change-carbon.csv",
  "defaults/transitions/pathways/wetland-change.csv", "defaults/stsim/stsim_FlowType.csv", "defaults/stockflow/stsim_FlowTypeGroupMembership.csv", "defaults/stockflow/stsim_FlowOrder.csv", "defaults/stockflow/stsim_OutputFilterFlows.csv")
for (f in fs) { dir.create(file.path(tmp, dirname(f)), recursive = TRUE, showWarnings = FALSE); file.copy(f, file.path(tmp, f)) }
out <- system2(file.path(R.home("bin"), "Rscript"), shQuote(file.path(tmp, "tools", "make_wetland_change.R")), stdout = TRUE, stderr = TRUE)
check("tools/make_wetland_change.R rewrites the files as they are", all(vapply(fs, function(f) identical(readLines(file.path(tmp, f)), readLines(f)), TRUE)))
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
