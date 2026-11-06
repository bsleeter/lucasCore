# Fast test of the non-forest steady-state solver and the regional emergent wetland tables (to-do 39 step 1; no SyncroSim).
# Run: Rscript tests/unit-nonforest-solve.R (from the package root)
suppressPackageStartupMessages(library(data.table))
source("src/nonforest-solve.R")
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
rd <- function(...) fread(file.path("defaults", ...), colClasses = "character", na.strings = "", encoding = "UTF-8")
pa <- rd("stockflow", "nonforest-pathways.csv"); memb <- rd("stockflow", "stsim_FlowTypeGroupMembership.csv"); ord <- rd("stockflow", "stsim_FlowOrder.csv")
EM <- c("Wetland: Estuarine Emergent", "Wetland: Palustrine Emergent")

# ---- flow order rules: the package's ST-Sim options are the ones the solver assumes -----------------------------------------
s0 <- readLines("src/0-stock-flow-definitions.R")
check("stage 0 sets ApplyEquallyRankedSimultaneously = TRUE and ApplyBeforeTransitions = FALSE (same-order flows from the stocks at the start of their step)",
      any(grepl("ApplyBeforeTransitions = FALSE, ApplyEquallyRankedSimultaneously = TRUE", s0, fixed = TRUE)))
check("every flow type of the emergent pathways has a flow order", all(unique(pa[FromStateClassId %in% EM, FlowTypeId]) %in% ord$FlowTypeId))

# ---- a hand case: growth at order 1, turnover at order 6 ----------------------------------------------------------------------
toy_p <- data.table(FromStockTypeId = c("Atmosphere", "Biomass: Foliage"), ToStockTypeId = c("Biomass: Foliage", "Aquatic"),
                    FlowTypeId = c("g", "t"), Multiplier = "1")
toy_o <- data.table(FlowTypeId = c("g", "t"), Order = c("1", "6")); toy_m <- data.table(FlowGroupId = c("g [Type]", "t [Type]"), Value = c("1", "0.4"))
ss <- nf_steady(nf_flows(toy_p, toy_m, data.table(FlowTypeId = character(), FlowGroupId = character()), toy_o), 3)
check("growth before turnover: year-end stock = G (1 - k) / k (3 x 0.6 / 0.4 = 4.5) and the sink takes G", isTRUE(all.equal(ss$stock[["Biomass: Foliage"]], 4.5)) && isTRUE(all.equal(ss$sink[["Aquatic"]], 3)))
toy_o2 <- data.table(FlowTypeId = c("g", "t"), Order = c("6", "1"))
ss2 <- nf_steady(nf_flows(toy_p, toy_m, data.table(FlowTypeId = character(), FlowGroupId = character()), toy_o2), 3)
check("turnover before growth: year-end stock = G / k (7.5)", isTRUE(all.equal(ss2$stock[["Biomass: Foliage"]], 7.5)))
sim <- nf_simulate(nf_flows(toy_p, toy_m, data.table(FlowTypeId = character(), FlowGroupId = character()), toy_o), 3, c(), 400)
check("the simulated year agrees with the steady state", abs(sim[["Biomass: Foliage"]] - 4.5) < 1e-9)

# ---- the legacy rates reproduce the legacy starting pools (the order rules match how they were built) ----------------------------
lm <- rd("stockflow", "legacy-ibis", "emergent-multipliers.csv"); lg <- rd("stockflow", "legacy-ibis", "emergent-net-growth.csv")
li <- rd("stockflow", "legacy-ibis", "emergent-initial-stocks.csv"); st <- rd("initialstocks", "stock-types.csv")
for (cls in EM) {
  f <- nf_flows(pa[FromStratumId == "Marine" & FromStateClassId == cls], lm[StratumId == "Marine" & StateClassId == cls, .(FlowGroupId, Value)], memb, ord)
  s <- nf_steady(f, as.numeric(lg[StratumId == "Marine" & StateClassId == cls, Value]))$stock
  tab <- li[StateClassID == cls & as.numeric(Value) > 0][, .(pool = st$StockTypeId[match(StateAttributeTypeID, st$Attribute)], v = as.numeric(Value))]
  live_dom <- tab[!pool %in% "DOM: Belowground Slow"]
  check(sprintf("%s: the legacy rates' ordered steady state matches the legacy live and litter pools within 0.1%%", cls),
        all(abs(s[live_dom$pool] / live_dom$v - 1) < 1e-3))
  check(sprintf("%s: and the legacy soil within 3%%", cls), abs(s[["DOM: Belowground Slow"]] / tab[pool == "DOM: Belowground Slow", v] - 1) < 0.03) }

# ---- the new package tables ------------------------------------------------------------------------------------------------
fm <- rd("stockflow", "nonforest-multipliers-wetland.csv"); ng <- rd("stockflow", "nonforest-net-growth.csv"); ini <- rd("initialstocks", "emergent-wetland.csv")
fit <- rd("stockflow", "emergent-wetland-fit.csv"); reg <- rd("stockflow", "emergent-wetland-regions.csv"); eco <- rd("stockflow", "emergent-wetland-ecodivisions.csv")
check("every ecodivision of the package has a region for both classes", setequal(eco$StratumId, unique(fm$StratumId)) && all(eco$EstuarineRegion %in% reg$Region) && all(eco$PalustrineRegion %in% reg$Region))
check("a fit for every ecodivision x emergent class", nrow(fit) == 2 * nrow(eco))
check("all emergent rates between 0 and 1", fm[StateClassId %in% EM, all(between(as.numeric(Value), 0, 1))])
gs <- fm[StateClassId %in% EM & grepl("^Net Growth Wetland Emergent", FlowGroupId), .(s = sum(as.numeric(Value))), by = .(StratumId, StateClassId)]
check("growth splits add to 1", all(abs(gs$s - 1) < 1e-5))
sh <- fm[StateClassId %in% EM & grepl("^(Emission|Lateral Transport|Stabilization|Decay): BG Slow ->", FlowGroupId), .(s = sum(as.numeric(Value))), by = .(StratumId, StateClassId)]
check("BG Slow's shares (emission, lateral, burial) add to 1", all(abs(sh$s - 1) < 1e-5))
check("Net Growth = the region's NPP", all(merge(ng[StateClassId %in% EM, .(StratumId, StateClassId, v = as.numeric(Value))], fit[, .(StratumId, StateClassId, NPP = as.numeric(NPP))])[, v == NPP]))
worst <- 0; bworst <- 0
for (i in seq_len(nrow(fit))) {
  e <- fit$StratumId[i]; cls <- fit$StateClassId[i]; t <- reg[StateClassId == cls & Region == fit$Region[i]]
  f <- nf_flows(pa[FromStratumId == e & FromStateClassId == cls], fm[StratumId == e & StateClassId == cls, .(FlowGroupId, Value)], memb, ord)
  ss <- nf_steady(f, as.numeric(t$NPP))
  x <- ini[StratumID == e & StateClassID == cls][, .(pool = st$StockTypeId[match(StateAttributeTypeID, st$Attribute)], v = as.numeric(Value))]
  pools <- intersect(x$pool, names(ss$stock))
  worst <- max(worst, max(abs(ss$stock[pools] - x[match(pools, pool), v])))
  bworst <- max(bworst, abs(ss$sink[["Deep Soil"]] / as.numeric(t$Burial) - 1))
  peak <- ss$stock[["Biomass: Foliage"]] + as.numeric(t$NPP) * as.numeric(t$AgShare)
  if (i == 1) check(sprintf("%s %s: peak foliage %.2f = target %s", e, cls, peak, t$PeakFoliage), abs(peak - as.numeric(t$PeakFoliage)) < 1e-3) }
check(sprintf("starting pools are the steady state of the written rates (largest gap %.1e Mg C/ha)", worst), worst < 1e-3)
check(sprintf("burial into Deep Soil hits each region's target (largest gap %.2f%%)", 100 * bworst), bworst < 1e-3)
ds <- merge(ini[StateAttributeTypeID == "Carbon Initial Conditions: Deep Soil", .(StratumId = StratumID, StateClassId = StateClassID, ds = as.numeric(Value))], fit[, .(StratumId, StateClassId, Region)])
check("Deep Soil starts with the region's 30-100 cm soil", all(merge(ds, reg[, .(StateClassId, Region, t = as.numeric(Soil30to100))], by = c("StateClassId", "Region"))[, ds == t]))
check("Pacific values: Marine estuarine burial 1.10, Mediterranean 1.04 (Wang et al. 2019)",
      isTRUE(all.equal(as.numeric(fit[StratumId == "Marine" & StateClassId == EM[1], Burial]), 1.10, tolerance = 1e-3)) &&
      isTRUE(all.equal(as.numeric(fit[StratumId == "Mediterranean" & StateClassId == EM[1], Burial]), 1.04, tolerance = 1e-3)))
pr <- unlist(lapply(c("cbm-defaults", "fia-measured"), function(m) c(rd("carbon-assumptions", m, "nonforest-rates.csv")$StateClassId, rd("carbon-assumptions", m, "nonforest-growth.csv")$StateClassId)))
check("the carbon method presets hold no emergent rows (they would override the ecodivision values)", !any(pr %in% EM))
check("Deep Soil is in stage 8's stock list with no forest curve column", { s <- st[StockTypeId == "Deep Soil"]; nrow(s) == 1 && is.na(s$CurveColumn) })

cat(sprintf("\n%d of %d checks passed\n", n - fails, n)); if (fails) quit(status = 1)
