# =============================================================================
# unit-agriculture.R - cropland and pasture carbon tables (to-do 39 step 6; no SyncroSim)
# =============================================================================
# Checks the package tables tools/make_agriculture.R writes: every ecodivision x class has pathways, rates, growth, yearly Crop Yield
# rows and starting pools; the flows, groups and stock they name are package definitions (with a flow order); growth splits add to 1
# and every rate is in 0-1; the ordered steady state of the rates (src/nonforest-solve.R) is the starting pools, holds the soil target,
# leaves no live carbon at year end and sends the harvest to the Agriculture Sector; stages 3 and 8 and the CO2 classes read them.
# Usage: Rscript tests/unit-agriculture.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
ok <- 0; bad <- 0
expect <- function(what, cond, detail = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, detail, "\n") } }
d <- function(...) file.path(pkg, "defaults", ...); rd <- function(...) fread(d(...), colClasses = "character", na.strings = "")
source(file.path(pkg, "src", "nonforest-solve.R"))
AG <- c("Agriculture: Cropland", "Agriculture: Pasture")
pa <- rd("stockflow", "nonforest-pathways-agriculture.csv"); fm <- rd("stockflow", "nonforest-multipliers-agriculture.csv"); ng <- rd("stockflow", "nonforest-net-growth.csv")
cy <- rd("stockflow", "ag-crop-yield.csv"); tg <- rd("stockflow", "ag-targets.csv"); is0 <- rd("initialstocks", "agriculture.csv")
memb <- rd("stockflow", "stsim_FlowTypeGroupMembership.csv"); ord <- rd("stockflow", "stsim_FlowOrder.csv"); st <- rd("initialstocks", "stock-types.csv")
eco <- sort(unique(rd("stockflow", "nonforest-pathways.csv")$FromStratumId)); want <- CJ(StratumId = eco, StateClassId = AG)[, k := paste(StratumId, StateClassId)]$k
expect("pathways for every ecodivision x class", setequal(unique(pa[, paste(FromStratumId, FromStateClassId)]), want))
expect("rates for every ecodivision x class", setequal(unique(fm[, paste(StratumId, StateClassId)]), want))
expect("growth for every ecodivision x class", setequal(ng[StateClassId %in% AG, paste(StratumId, StateClassId)], want))
expect("starting pools for every ecodivision x class", setequal(unique(is0[, paste(StratumID, StateClassID)]), want))
yrs <- cy[, .(y0 = min(as.integer(Timestep)), y1 = max(as.integer(Timestep)), n = .N), by = .(StratumId, StateClassId)]
expect("Crop Yield rows 1985-2023 or longer for every ecodivision x class", nrow(yrs) == length(want) && all(yrs$y0 <= 1985 & yrs$y1 >= 2024))
expect("Crop Yield index around 1 over 1985-2023", cy[as.integer(Timestep) %between% c(1985, 2023), abs(mean(as.numeric(Value)) - 1) < 0.05])
expect("the old zero agriculture rows are gone from nonforest-multipliers-other.csv", !any(rd("stockflow", "nonforest-multipliers-other.csv")$StateClassId %in% AG))
# definitions
nm <- function(f) fread(d("stsim", f), sep = ",", colClasses = "character", na.strings = "", fill = TRUE)$Name
expect("flow types are defined", all(unique(pa$FlowTypeId) %in% nm("stsim_FlowType.csv")), paste(setdiff(unique(pa$FlowTypeId), nm("stsim_FlowType.csv")), collapse = "; "))
expect("stock types are defined", all(unique(c(pa$FromStockTypeId, pa$ToStockTypeId)) %in% nm("stsim_StockType.csv")))
expect("every flow type has a flow order", all(unique(pa$FlowTypeId) %in% ord$FlowTypeId))
expect("Net Growth Agriculture: Total and Harvest: Agriculture are flow groups", all(c("Net Growth Agriculture: Total", "Harvest: Agriculture") %in% nm("stsim_FlowGroup.csv")))
expect("Crop Yield is a flow multiplier type", "Crop Yield" %in% nm("stsim_FlowMultiplierType.csv"))
expect("harvest lowers Net Biome Productivity", any(memb$FlowTypeId == "Harvest: Foliage -> Agriculture Sector" & memb$FlowGroupId == "Net Biome Productivity" & memb$Value == "-1"))
# rates
expect("every rate is in 0-1", all(between(as.numeric(fm$Value), 0, 1)))
spl <- fm[grepl("^Net Growth Agriculture", FlowGroupId), .(s = sum(as.numeric(Value))), by = .(StratumId, StateClassId)]
expect("growth splits add to 1", all(abs(spl$s - 1) < 1e-6))
# steady state = starting pools, soil target held, no live carbon at year end, harvest to the sector
chk <- rbindlist(lapply(want, function(k) { e <- sub(" Agriculture: .*$", "", k); cls <- sub("^.* (Agriculture: )", "\\1", k)
  p <- pa[FromStratumId == e & FromStateClassId == cls]; m <- fm[StratumId == e & StateClassId == cls, .(FlowGroupId, Value)]
  npp <- as.numeric(ng[StratumId == e & StateClassId == cls, Value]); ss <- nf_steady(nf_flows(p, m, memb, ord), npp)
  init <- is0[StratumID == e & StateClassID == cls]; att <- setNames(st$Attribute, st$StockTypeId)
  gap <- max(abs(vapply(names(ss$stock), function(s) ss$stock[[s]] - as.numeric(init[StateAttributeTypeID == att[[s]], Value]), 1)))
  data.table(k, gap, soil = ss$stock[["DOM: Belowground Slow"]] - as.numeric(tg[StratumId == e & StateClassId == cls, Soil0to999]),
             live = sum(ss$stock[grep("^Biomass", names(ss$stock))]), harvest = ss$sink[["Agriculture Sector"]]) }))
expect("the starting pools are the rates' steady state", all(chk$gap < 1e-3), sprintf("largest gap %.2g", max(chk$gap)))
expect("the soil target is held", all(abs(chk$soil) < 0.01), sprintf("largest %.3g", max(abs(chk$soil))))
expect("no live carbon at year end", all(chk$live < 1e-9))
expect("harvest goes to the Agriculture Sector in every ecodivision x class", all(chk$harvest > 0))
# the model reads them
s3 <- paste(readLines(file.path(pkg, "src", "3-carbon-flows.R")), collapse = "\n"); s8 <- paste(readLines(file.path(pkg, "src", "8-initial-stocks-spatial.R")), collapse = "\n")
expect("stage 3 reads the agriculture pathways, rates and Crop Yield", all(vapply(c("nonforest-pathways-agriculture.csv", "nonforest-multipliers-agriculture.csv", "ag-crop-yield.csv"), grepl, TRUE, s3, fixed = TRUE)))
expect("stage 8 reads the agriculture starting pools", grepl("agriculture.csv", s8, fixed = TRUE))
co2 <- rd("climate", "co2-classes.csv")
expect("CO2 fertilization of cropland and pasture acts on Net Growth Agriculture: Total", all(co2[StateClassId %in% AG, FlowGroupId] == "Net Growth Agriculture: Total"))
# Cropland Productivity (stage 8): the CDL crosswalk's crop groups have NASS growth; the option, data source and multiplier type exist
xw <- rd("stockflow", "cdl-crops.csv"); eg <- rd("stockflow", "ag-ecodivision-crop-npp.csv"); cg <- rd("stockflow", "ag-county-crop-npp.csv")
grp <- setdiff(unique(unlist(strsplit(na.omit(xw$Group), "|", fixed = TRUE))), "Fallow")
expect("every CDL crop group has NASS growth by ecodivision and county", all(grp %in% eg$Group) && all(grp %in% cg$Group), paste(setdiff(grp, eg$Group), collapse = "; "))
expect("CDL codes are unique and fallow is a group", !anyDuplicated(xw$Code) && "Fallow" %in% xw$Group)
expect("county GEOIDs keep their leading zeros", all(nchar(cg$GEOID) == 5))
px <- paste(readLines(file.path(pkg, "package.xml")), collapse = "\n")
expect("package.xml has Build Options: Cropland Productivity and Data Sources: CdlFolder", grepl('name="CropProductivity"', px, fixed = TRUE) && grepl('name="CdlFolder"', px, fixed = TRUE))
expect("Cropland Productivity is a flow multiplier type", "Cropland Productivity" %in% nm("stsim_FlowMultiplierType.csv"))
expect("stage 8 writes the Cropland Productivity multiplier; stages 7 and 11 carry it over",
       grepl("put_multiplier(\"Cropland Productivity\"", s8, fixed = TRUE) && all(vapply(c("7-climate-multipliers.R", "11-projection-climate.R"),
         function(f) grepl("\"Cropland Productivity\")", paste(readLines(file.path(pkg, "src", f)), collapse = "\n"), fixed = TRUE), TRUE)))
cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
