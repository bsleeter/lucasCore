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
  f <- nf_flows(pa[FromStratumId == "Marine" & FromStateClassId == cls], nf_ch4_prepare(lm[StratumId == "Marine" & StateClassId == cls, .(FlowGroupId, Value)]), memb, ord)
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
sh <- fm[StateClassId %in% EM & grepl("^(Emission|Lateral Transport|Stabilization|Decay)( Emergent)?: BG Slow ->", FlowGroupId), .(s = sum(as.numeric(Value))), by = .(StratumId, StateClassId)]
check("BG Slow's shares (emission, lateral, burial) add to 1", all(abs(sh$s - 1) < 1e-5))
# ---- structure as lucasWet's (2026-11-24): litter to the soil, the classes' own flow types, one wetland Q10 ------------------------------
g4 <- NF_CH4; ET <- unique(unname(NF_EMERGENT_TYPES)); A2S <- "Decay: AG Very Fast -> BG Slow"; ty <- function(x) paste(x, "[Type]")
for (pool in c("AG Very Fast", "BG Very Fast")) { s2 <- fm[StateClassId %in% EM & grepl(sprintf("^(Emission|Lateral Transport|Decay)( Emergent)?: %s ->", pool), FlowGroupId), .(s = sum(as.numeric(Value))), by = .(StratumId, StateClassId)]
  check(sprintf("%s's shares (emission, lateral, to the soil) add to 1", pool), nrow(s2) == 2 * uniqueN(fm$StratumId) && all(abs(s2$s - 1) < 1e-5)) }
check("aboveground litter feeds the soil in both classes of every ecodivision: 28% of its loss in estuarine marsh, 36% in palustrine (lucasWet's shares), out of the emission share",
      pa[FlowTypeId == A2S, .N] == 2 * uniqueN(fm$StratumId) && all(pa[FlowTypeId == A2S, FromStockTypeId == "DOM: Aboveground Very Fast" & ToStockTypeId == "DOM: Belowground Slow" & FromStateClassId %in% EM]) &&
      all(fm[FlowGroupId == ty(A2S), as.numeric(Value) == NF_AG_TO_SOIL[StateClassId]]) && fm[FlowGroupId == ty(A2S), .N] == 2 * uniqueN(fm$StratumId) &&
      { lg0 <- rd("stockflow", "legacy-ibis", "emergent-multipliers.csv"); x <- merge(fm[FlowGroupId == ty("Emission Emergent: AG Very Fast -> Atmosphere"), .(StratumId, StateClassId, e = as.numeric(Value))],
          lg0[FlowGroupId == ty("Emission: AG Very Fast -> Atmosphere"), .(StratumId, StateClassId, e0 = as.numeric(Value))]); nrow(x) == 2 * uniqueN(fm$StratumId) && x[, all(abs(e + NF_AG_TO_SOIL[StateClassId] - e0) < 1e-6)] })
check("the emergent classes' own flow types: defined, with an order and an output filter, used by the emergent classes only, and no emergent pathway or rate keeps the flow type it replaces",
      all(ET %in% fread("defaults/stsim/stsim_FlowType.csv", sep = ",", colClasses = "character")$Name) && all(ET %in% ord$FlowTypeId) && all(ty(ET) %in% rd("stockflow", "stsim_OutputFilterFlows.csv")$FlowGroupId) &&
      all(pa[FlowTypeId %in% ET, FromStateClassId] %in% EM) && all(vapply(ET, function(x) pa[FlowTypeId == x, .N] == 2 * uniqueN(fm$StratumId), TRUE)) && !nrow(pa[FromStateClassId %in% EM & FlowTypeId %in% names(NF_EMERGENT_TYPES)]) &&
      !nrow(fm[StateClassId %in% EM & FlowGroupId %in% ty(names(NF_EMERGENT_TYPES))]) && all(fm[FlowGroupId %in% ty(ET), StateClassId] %in% EM))
q10of <- function(x) grep("^Q10", memb[FlowTypeId == x, FlowGroupId], value = TRUE)
dead <- unique(pa[FromStateClassId %in% EM & FromStockTypeId %in% c("DOM: Aboveground Very Fast", "DOM: Belowground Very Fast", "DOM: Belowground Slow") & FlowTypeId != "Decay: AG Very Fast -> AG Slow", FlowTypeId])
NOQ <- c("Stabilization: BG Slow -> Deep Soil", "Lateral Transport: BG Slow -> Aquatic")
check("one temperature response, as lucasWet: every loss of an emergent wetland's litter and soil is in Q10 Wetland Flows alone; methane in Q10 Wetland CH4 alone; soil export and burial in none",
      length(dead) == 11 && all(vapply(dead, function(x) identical(q10of(x), if (grepl("CH4$", x)) g4$q10 else if (x %in% NOQ) character() else NF_EMERGENT_Q10), TRUE)) &&
      setequal(memb[FlowGroupId == NF_EMERGENT_Q10, FlowTypeId], setdiff(dead[!grepl("CH4$", dead)], NOQ)))
check("the forested wetland soil keeps its own Q10 group (2.0), and the package Q10s are lucasWet's: 1.5 for the emergent classes' litter and soil, 2.57 for methane",
      { cf <- fread("defaults/climate/flow-multipliers.csv", colClasses = "character", na.strings = ""); q <- function(g) as.numeric(cf[FlowGroupId == g, Q10])
        identical(memb[FlowGroupId == "Q10 Wetland Soil", FlowTypeId], "Emission: BG Slow -> Atmosphere (Wetland)") && q("Q10 Wetland Soil") == 2 && q(NF_EMERGENT_Q10) == 1.5 && q(g4$q10) == 2.57 })
check("Net Growth = the fitted NPP (the region's, or the tidal marsh map's for estuarine)", all(merge(ng[StateClassId %in% EM, .(StratumId, StateClassId, v = as.numeric(Value))], fit[, .(StratumId, StateClassId, NPP = as.numeric(NPP))])[, v == NPP]))
worst <- 0; bworst <- 0
for (i in seq_len(nrow(fit))) {
  e <- fit$StratumId[i]; cls <- fit$StateClassId[i]; t <- reg[StateClassId == cls & Region == fit$Region[i]]
  f <- nf_flows(pa[FromStratumId == e & FromStateClassId == cls], fm[StratumId == e & StateClassId == cls, .(FlowGroupId, Value)], memb, ord)
  t <- copy(t)[, `:=`(NPP = fit$NPP[i], PeakFoliage = fit$PeakFoliage[i])]   # estuarine NPP and peak foliage from the tidal marsh map where it holds the class
  if (grepl("burial lowered", fit$NppSource[i])) t[, Burial := as.numeric(sub("^.* to ([0-9.]+) .*$", "\\1", fit$NppSource[i]))]   # where the map NPP cannot supply the region's burial
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
check("Deep Soil starts at 0 (one soil definition: BG Slow holds the soil to 1 m; Deep Soil is burial during a run; user 2026-11-07)", all(ds$ds == 0))
bs <- merge(ini[StateAttributeTypeID == "Carbon Initial Conditions: Belowground Slow", .(StratumId = StratumID, StateClassId = StateClassID, b = as.numeric(Value))], fit[, .(StratumId, StateClassId, Region)])
check("BG Slow starts with the region's soil to 1 m (0-30 + 30-100 cm)", all(merge(bs, reg[, .(StateClassId, Region, t = as.numeric(Soil0to30) + as.numeric(Soil30to100))], by = c("StateClassId", "Region"))[, abs(b / t - 1) < 1e-3]))   # within 0.1%: the rates are written to 6 decimals
check("Pacific values: Marine estuarine burial 1.10, Mediterranean 1.04 (Wang et al. 2019)",
      isTRUE(all.equal(as.numeric(fit[StratumId == "Marine" & StateClassId == EM[1], Burial]), 1.10, tolerance = 1e-3)) &&
      isTRUE(all.equal(as.numeric(fit[StratumId == "Mediterranean" & StateClassId == EM[1], Burial]), 1.04, tolerance = 1e-3)))
pr <- unlist(lapply(c("cbm-defaults", "fia-measured"), function(m) c(rd("carbon-assumptions", m, "nonforest-rates.csv")$StateClassId, rd("carbon-assumptions", m, "nonforest-growth.csv")$StateClassId)))
check("the carbon method presets hold no emergent rows (they would override the ecodivision values)", !any(pr %in% EM))
check("Deep Soil is in stage 8's stock list with no forest curve column", { s <- st[StockTypeId == "Deep Soil"]; nrow(s) == 1 && is.na(s$CurveColumn) })

# ---- methane from emergent wetlands (2026-11-16): CO2 and CH4 flows from BG Slow and BG Very Fast, each with its own Q10 --------------
g4 <- NF_CH4; ty4 <- function(x) paste(x, "[Type]"); dd <- function(f) fread(file.path("defaults", "stsim", f), sep = ",", colClasses = "character", encoding = "UTF-8")$Name
o4 <- function(x) as.numeric(ord$Order[match(x, ord$FlowTypeId)]); mg <- function(ft) memb[FlowTypeId == ft]
check("methane definitions: the wetland soil CO2 flow type, a CH4 flow type for each pool, the two Q10 groups and the reporting groups; no holding stock",
      all(c(g4$co2, g4$ch4) %in% dd("stsim_FlowType.csv")) && all(c(g4$q10, g4$soil_q10, "Emission: Wetland CH4", "Emission: Wetland CH4 (CO2e)") %in% dd("stsim_FlowGroup.csv")) &&
      !any(grepl("Wetland.*Gas", c(dd("stsim_StockType.csv"), dd("stsim_FlowType.csv")))))
check("flow order: each CH4 flow at the order of its pool's CO2 emission (flows of one order draw on the same stock); the soil's with burial and lateral export, after the year's litter has reached it (as lucasWet; the forested wetland soil stays at the shared order)",
      all(o4(g4$ch4) == o4(g4$co2)) && o4(g4$co2[["soil"]]) == o4("Stabilization: BG Slow -> Deep Soil") && o4(g4$co2[["soil"]]) == o4("Lateral Transport: BG Slow -> Aquatic") &&
      all(o4(c("Decay: AG Very Fast -> BG Slow", "Decay Emergent: BG Very Fast -> BG Slow")) < o4(g4$co2[["soil"]])) && o4("Emission: BG Slow -> Atmosphere (Wetland)") == o4(g4$shared_soil))
wv <- function(ft, g) as.numeric(mg(ft)[FlowGroupId == g, Value])
WCO2 <- "Emission: Wetland Methane Source CO2"   # the group a marsh salinity multiplier adjusts (stage 8)
check("each emergent CO2 flow is in every group its shared counterpart is in but a Q10 group (the same weights), plus the wetland CO2 group and the one wetland Q10 group; the shared soil emission has no Q10",
      all(vapply(names(g4$co2), function(k) { w <- mg(g4$co2[[k]])$FlowGroupId; s <- grep("^Q10", mg(g4$shared[[k]])$FlowGroupId, value = TRUE, invert = TRUE); own <- c(WCO2, NF_EMERGENT_Q10)
        setequal(setdiff(w, own), s) && all(own %in% w) && all(vapply(s, function(g) wv(g4$co2[[k]], g) == wv(g4$shared[[k]], g), TRUE)) }, TRUE)) && !any(grepl("^Q10", mg(g4$shared_soil)$FlowGroupId)) &&
      identical(g4$soil_q10, NF_EMERGENT_Q10))
check("each CH4 flow: in its pool's total loss, in the carbon groups as carbon (1) and the CO2e groups as methane (33.5), in Q10 Wetland CH4 and no other Q10 group",
      all(vapply(names(g4$ch4), function(k) { ft <- g4$ch4[[k]]; pool <- c(soil = "BG Slow ->", litter = "BG Very Fast ->")[[k]]
        wv(ft, pool) == 1 && all(vapply(c("Emission: Total", "Emission: Total Rh", "Emission: Wetland CH4"), function(g) wv(ft, g) == 1, TRUE)) &&
          all(vapply(c("Net Ecosystem Productivity", "Net Biome Productivity"), function(g) wv(ft, g) == -1, TRUE)) &&
          all(vapply(c("Emission: Total (CO2e)", "Emission: Total Rh (CO2e)", "Emission: Wetland CH4 (CO2e)"), function(g) wv(ft, g) == 33.5, TRUE)) &&
          all(vapply(c("Net Ecosystem Productivity (CO2e)", "Net Biome Productivity (CO2e)"), function(g) wv(ft, g) == -33.5, TRUE)) &&
          identical(grep("^Q10", mg(ft)$FlowGroupId, value = TRUE), g4$q10) }, TRUE)))
check("the two wetland Q10s are fixed values in the climate table (methane, and the soil's CO2)",
      { cf <- fread("defaults/climate/flow-multipliers.csv", colClasses = "character", na.strings = ""); x <- cf[match(c(g4$q10, g4$soil_q10), FlowGroupId)]
        !anyNA(x$FlowGroupId) && all(x$Role == "Decomposition") && all(as.numeric(x$Q10) >= 1) })
check("only the emergent classes have their CO2 and CH4 flows in the package pathways, every one of them has all four, and none keeps a shared belowground emission",
      setequal(unique(pa[FlowTypeId %in% c(g4$co2, g4$ch4), FromStateClassId]), EM) && pa[FromStateClassId %in% EM & FlowTypeId %in% c(g4$co2, g4$ch4), .N] == 4 * nrow(fit) &&
      !nrow(pa[FromStateClassId %in% EM & FlowTypeId %in% g4$shared]) && all(pa[FlowTypeId %in% g4$ch4, ToStockTypeId] == g4$sink) &&
      all(pa[FlowTypeId == g4$ch4[["soil"]], FromStockTypeId] == "DOM: Belowground Slow") && all(pa[FlowTypeId == g4$ch4[["litter"]], FromStockTypeId] == "DOM: Belowground Very Fast") &&
      !nrow(fm[StateClassId %in% EM & FlowGroupId %in% ty4(g4$shared)]))
sh4 <- rbindlist(lapply(names(g4$ch4), function(k) merge(fm[FlowGroupId == ty4(g4$ch4[[k]]), .(StratumId, StateClassId, ch4 = as.numeric(Value))],
                                                        fm[FlowGroupId == ty4(g4$co2[[k]]) & StateClassId %in% EM, .(StratumId, StateClassId, co2 = as.numeric(Value))])[, pool := k]))[, f := ch4 / (ch4 + co2)]
check("a methane target for every region; one methane fraction for both pools of a class (to the 6 decimals written), at or under the cap",
      !anyNA(as.numeric(reg$CH4)) && nrow(sh4) == 2 * nrow(fit) && sh4[, .(d = diff(range(f))), by = .(StratumId, StateClassId)][, all(d < 1e-4)] && all(sh4$f <= g4$max_share) &&
      merge(sh4[, .(f = mean(f)), by = .(StratumId, StateClassId)], fit[, .(StratumId, StateClassId, s = as.numeric(CH4Share))])[, all(abs(f - s) < 1e-4)])
cw <- 0; pw <- 0; qw <- 0; mw <- 0; lost <- Inf
for (i in seq_len(nrow(fit))) {
  e <- fit$StratumId[i]; cls <- fit$StateClassId[i]; npp <- as.numeric(fit$NPP[i]); tg <- as.numeric(reg[StateClassId == cls & Region == fit$Region[i], CH4])
  p <- pa[FromStratumId == e & FromStateClassId == cls]; m <- fm[StratumId == e & StateClassId == cls, .(FlowGroupId, Value)]
  ss <- nf_steady(nf_flows(p, m, memb, ord), npp); cw <- max(cw, abs(ss$sink[[g4$sink]] - tg))
  # the same class before methane: each pool's CH4 share back in its CO2 share
  m0 <- copy(m)[, Value := as.numeric(Value)]; for (k in names(g4$ch4)) m0[FlowGroupId == ty4(g4$co2[[k]]), Value := Value + m0[FlowGroupId == ty4(g4$ch4[[k]]), Value]]
  m0[FlowGroupId %in% ty4(g4$ch4), Value := 0]; s0 <- nf_steady(nf_flows(p, m0, memb, ord), npp); k <- names(s0$stock)
  pw <- max(pw, max(abs(ss$stock[k] - s0$stock[k])), max(abs(ss$sink[names(s0$sink)] - s0$sink)))
  # a warm year: methane's multiplier at 1.3, everything else normal. From the same pools the year's methane is 1.3 times a normal
  # year's (its own Q10, from both pools), and the extra comes out of the pools gram for gram (nothing else leaves faster)
  S0 <- c(ss$stock, setNames(rep(0, length(ss$sink)), names(ss$sink)))
  a <- nf_simulate(nf_flows(p, m, memb, ord), npp, S0, 1); b <- nf_simulate(nf_flows(p, rbind(m, data.table(FlowGroupId = g4$q10, Value = "1.3")), memb, ord), npp, S0, 1)
  qw <- max(qw, abs(b[[g4$sink]] / a[[g4$sink]] - 1.3)); mw <- max(mw, abs(sum(b) - sum(a)))
  lost <- min(lost, sum(a[names(ss$stock)]) - sum(b[names(ss$stock)])) }
check(sprintf("methane at the steady state is the region's target (largest gap %.1e Mg C/ha/yr)", cw), cw < 1e-4)
check(sprintf("mass balance at the normal climate: with and without methane every pool, burial and lateral export are the same (largest gap %.1e)", pw), pw < 1e-6)
check(sprintf("in a warm year methane release responds by exactly its own Q10 multiplier (largest gap %.1e)", qw), qw < 1e-9)
check(sprintf("and carbon is conserved: the extra methane leaves the pools and reaches the atmosphere gram for gram (largest gap %.1e); the pools do fall (%.3f Mg C/ha or more)", mw, lost), mw < 1e-9 && lost > 0)
check("a target above the cap is refused", inherits(tryCatch(nf_fit_ch4(p, m, memb, ord, npp, 10), error = function(err) err), "error"))

# ---- grassland and shrubland by ecodivision, literature rates (tools/make_grass_shrub.R; to-do 39, 2026-11-06) --------------------
gm <- rd("stockflow", "nonforest-multipliers-grassland-shrubland.csv"); gi <- rd("initialstocks", "grassland-shrubland.csv"); gt <- rd("stockflow", "grass-shrub-targets.csv")
gf <- rd("stockflow", "grass-shrub-fit.csv"); lit <- rd("stockflow", "grass-shrub-literature.csv"); GS <- sort(unique(gm$StateClassId)); CHAP <- "Shrubland: Chaparral"
sa <- rd("stockflow", "shrub-age.csv"); SAGE <- sa$StateClassId; BYAGE <- c(CHAP, SAGE)
check("a grass and shrub target and fit for every ecodivision x class", nrow(gt) == uniqueN(gm$StratumId) * length(GS) && nrow(gf) == nrow(gt))
sh <- function(cls) { r <- lit[StateClassId == cls]; while (!is.na(r$RatesOf)) r <- lit[StateClassId == r$RatesOf]; as.numeric(c(r$ShareFoliage, r$ShareWood, r$ShareFineRoot, r$ShareCoarseRoot)) }
NGG <- paste("Net Growth Non Forest: Atmosphere ->", c("Foliage", "Other Wood", "Fine Roots", "Coarse Roots"), "[Type]")
# (to-do 55, 2026-11-09) a grass class with live-stock targets has its split fitted to them (tools/make_grass_shrub.R fit_stocks): foliage
# and fine roots only, summing to 1; every other class keeps the table's split
fitted <- lit[!is.na(AgLiveTarget) & kFoliage == "dieback", StateClassId]
ok_sh <- all(vapply(setdiff(GS, c(BYAGE, fitted)), function(cls) { x <- gm[StateClassId == cls & is.na(AgeMin) & FlowGroupId %in% NGG]; all(abs(as.numeric(x$Value[match(NGG, x$FlowGroupId)]) - sh(cls)) < 1e-6) }, TRUE))
check("each class's growth split is the literature table's (no IBIS share)", ok_sh)
ok_fit <- all(vapply(fitted, function(cls) { x <- gm[StateClassId == cls & is.na(AgeMin) & FlowGroupId %in% NGG]; v <- as.numeric(x$Value[match(NGG, x$FlowGroupId)])
  all(!is.na(v)) && all(v >= 0) && all(abs(tapply(v, rep(x$StratumId[1], 4), sum) - 1) < 1e-6) && v[2] == 0 && v[4] == 0 }, TRUE))
check("a grass class fitted to live-stock targets grows foliage and fine roots only, summing to 1", length(fitted) > 0 && ok_fit)
# the fitted stocks: at the class's CONUS mean NPP, live carbon meets the targets (annual grass: the ratio, its stocks following NPP)
fs <- gf[StateClassId %in% lit[!is.na(AgLiveTarget), StateClassId]]
fs[, `:=`(ag = as.numeric(lit$AgLiveTarget[match(StateClassId, lit$StateClassId)]), rt = as.numeric(lit$RootLiveTarget[match(StateClassId, lit$StateClassId)]))]
fs[, ratio_ok := abs(as.numeric(Aboveground) / as.numeric(Roots) - ag / rt) < 0.02 * ag / rt]
check("every class with live-stock targets holds their aboveground : root ratio in every ecodivision", nrow(fs) > 0 && all(fs$ratio_ok))
ngg <- ng[StateClassId %in% setdiff(GS, BYAGE)]
check("grass and shrub Net Growth = RAP NPP (chaparral: by age)", all(merge(ngg[, .(StratumId, StateClassId, v = as.numeric(Value))], gt[, .(StratumId, StateClassId, t = as.numeric(NPP))])[, abs(v - t) < 1e-9]) &&
      ng[StateClassId == CHAP, uniqueN(AgeMin)] == 101)
sp <- gm[grepl("^Net Growth Non Forest", FlowGroupId), .(s = sum(as.numeric(Value))), by = .(StratumId, StateClassId, AgeMin)]
check("growth splits add to 1 at every age", all(abs(sp$s - 1) < 1e-5))
gw <- 0
for (i in which(!gt$StateClassId %in% BYAGE)) { e <- gt$StratumId[i]; cls <- gt$StateClassId[i]
  ss <- nf_steady(nf_flows(pa[FromStratumId == e & FromStateClassId == cls], gm[StratumId == e & StateClassId == cls, .(FlowGroupId, Value)], memb, ord), as.numeric(gt$NPP[i]))
  x <- gi[StratumID == e & StateClassID == cls][, .(pool = st$StockTypeId[match(StateAttributeTypeID, st$Attribute)], v = as.numeric(Value))]
  pl <- intersect(x$pool, names(ss$stock)); gw <- max(gw, max(abs(ss$stock[pl] - x[match(pl, pool), v]))) }
check(sprintf("grass and shrub starting pools are the steady state of the written rates (largest gap %.1e Mg C/ha)", gw), gw < 1e-3)
fit_ok <- gf[StateClassId != CHAP, all(abs(as.numeric(Soil) - as.numeric(gt$Soil0to999[match(paste(StratumId, StateClassId), paste(gt$StratumId, gt$StateClassId))])) < 0.01)]
check("BG Slow holds the gNATSGO whole-profile target, and Deep Soil starts at 0", fit_ok && all(as.numeric(gi[StateAttributeTypeID == "Carbon Initial Conditions: Deep Soil", Value]) == 0))
# chaparral: one year at age A from the pools at age A gives the pools at age A + 1 (rates and growth looked up at age A)
cp <- rd("initialstocks", "chaparral.csv"); cg <- ng[StateClassId == CHAP]; e <- "Mediterranean"; p <- pa[FromStratumId == e & FromStateClassId == CHAP]
pool_at <- function(a) { x <- cp[StratumID == e & as.integer(AgeMin) == a]; setNames(as.numeric(x$Value), st$StockTypeId[match(x$StateAttributeTypeID, st$Attribute)]) }
rates_at <- function(a) { m <- gm[StratumId == e & StateClassId == CHAP]; m[is.na(AgeMin) | as.integer(AgeMin) == min(a, 100)][!(is.na(AgeMin) & FlowGroupId %in% m[!is.na(AgeMin), FlowGroupId]), .(FlowGroupId, Value)] }
step <- function(a) { mp <- nf_annual_map(nf_flows(p, rates_at(a), memb, ord), as.numeric(cg[StratumId == e & as.integer(AgeMin) == min(a, 100), Value]))
  S <- pool_at(a); x <- setNames(rep(0, length(mp$pools)), mp$pools); x[intersect(names(S), mp$pools)] <- S[intersect(names(S), mp$pools)]; (mp$M %*% x + mp$c)[, 1] }
cw <- max(vapply(c(0, 1, 5, 20, 60, 98), function(a) { y <- step(a); z <- pool_at(a + 1); k <- intersect(names(z), names(y)); max(abs(y[k] - z[k])) }, 1))
check(sprintf("chaparral: a year at age A takes the age-A pools to the age-(A+1) pools (largest gap %.1e Mg C/ha)", cw), cw < 1e-3)
ag <- vapply(c(0, 10, 30, 100), function(a) { s <- pool_at(a); sum(s[c("Biomass: Foliage", "Biomass: Other Wood")]) }, 1)
check(sprintf("chaparral aboveground live rises with age to the curve's maximum (%s Mg C/ha at 0, 10, 30, 100)", paste(round(ag, 2), collapse = ", ")), all(diff(ag) > 0) && ag[1] < 0.5)
# the sage family by age (to-do 39 step 8): growth rows each year to 39 and in 5-year bins after; pools at each bin start
si <- rd("initialstocks", "shrub-age.csv")
sage_ok <- vapply(SAGE, function(cls) { e <- "Temperate Desert"; p <- pa[FromStratumId == e & FromStateClassId == cls]; amax <- as.integer(sa[StateClassId == cls, AgeMax])
  m <- gm[StratumId == e & StateClassId == cls]; A <- sort(unique(as.integer(m$AgeMin)))
  rates_at <- function(a) { b <- A[findInterval(min(a, amax), A)]; m[is.na(AgeMin) | as.integer(AgeMin) == b][!(is.na(AgeMin) & FlowGroupId %in% m[!is.na(AgeMin), FlowGroupId]), .(FlowGroupId, Value)] }
  g <- ng[StratumId == e & StateClassId == cls]; growth_at <- function(a) as.numeric(g[as.integer(AgeMin) == A[findInterval(min(a, amax), A)], Value])
  pool_at <- function(a) { x <- si[StratumID == e & StateClassID == cls & as.integer(AgeMin) == a]; setNames(as.numeric(x$Value), st$StockTypeId[match(x$StateAttributeTypeID, st$Attribute)]) }
  step <- function(S, a) { mp <- nf_annual_map(nf_flows(p, rates_at(a), memb, ord), growth_at(a)); x <- setNames(rep(0, length(mp$pools)), mp$pools)
    x[intersect(names(S), mp$pools)] <- S[intersect(names(S), mp$pools)]; y <- (mp$M %*% x + mp$c)[, 1]; S[names(y)] <- y; S }
  gap <- 0; for (b in intersect(c(0, 5, 20, 38, 40, 60), A[A < amax])) { nb <- A[match(b, A) + 1]; S <- pool_at(b); for (a in b:(nb - 1)) S <- step(S, a)
    z <- pool_at(nb); k <- intersect(names(z), names(S)); gap <- max(gap, max(abs(S[k] - z[k]))) }
  wood <- vapply(c(0, 10, 30, amax), function(a) pool_at(A[findInterval(a, A)])[["Biomass: Other Wood"]], 1)[!duplicated(pmin(c(0, 10, 30, amax), amax))]
  mat <- m[as.integer(AgeMin) == amax & FlowGroupId %in% NGG]; mt <- gt[StratumId == e & StateClassId == cls, as.numeric(NPP)]
  mv <- as.numeric(mat$Value[match(NGG, mat$FlowGroupId)])
  # a class with a herbaceous part (HerbOf; to-do 55) has its split from RAP's herbaceous share, not the table: a valid split then
  herb_of <- function(k) { r <- lit[StateClassId == k]; if (!is.na(r$HerbOf)) TRUE else if (!is.na(r$RatesOf)) herb_of(r$RatesOf) else FALSE }
  split_ok <- if (herb_of(cls)) all(mv >= 0) && abs(sum(mv) - 1) < 1e-6 else all(abs(mv - sh(cls)) < 1e-6)
  c(gap = gap, rising = all(diff(wood) > 0), mature = split_ok && abs(growth_at(amax) - mt) < 1e-4,
    later = abs(growth_at(5) - mt) < 1e-4) }, c(gap = 0, rising = 0, mature = 0, later = 0))
check(sprintf("sage family: the age-bin pools step to the next bin's (largest gap %.1e Mg C/ha)", max(sage_ok["gap", ])), max(sage_ok["gap", ]) < 1e-3)
check("sage family: wood rises with years since fire (surviving coarse roots die back first); at AgeMax the literature split and RAP NPP; from age 2 the mature NPP",
      all(sage_ok[c("rising", "mature", "later"), ] == 1))
df <- rd("carbon-assumptions", "fia-measured", "disturbance-flows.csv")[StateClassId == CHAP]
check("chaparral fire rows in the presets, no pool losing more than it holds", nrow(df) > 0 && df[, .(s = sum(as.numeric(Share))), by = FromStockTypeId][, all(s <= 1 + 1e-9)] &&
      abs(df[FromStockTypeId == "Biomass: Fine Root", sum(as.numeric(Share))] - 0.25) < 1e-6)
pr2 <- unlist(lapply(c("cbm-defaults", "fia-measured"), function(m) c(rd("carbon-assumptions", m, "nonforest-rates.csv")$StateClassId, rd("carbon-assumptions", m, "nonforest-growth.csv")$StateClassId)))
check("the presets hold no grass or shrub rate rows", !any(pr2 %in% GS))

pkg <- "."
# tidal marsh NPP map (to-do 39 step 10): estuarine NPP from the map where it holds 10 km2 or more; Tidal Marsh Productivity in stage 8
tmn <- rd("stockflow", "tidal-marsh-npp.csv")
mapped <- merge(fit[StateClassId == EM[1]], tmn[as.numeric(Km2) >= 10, .(StratumId, StateClassId, MapNPP = as.numeric(MapNPP))], by = c("StratumId", "StateClassId"))
check(sprintf("estuarine NPP and peak foliage are the tidal marsh map's in %d of the %d ecodivisions it covers (the rest with burial lowered: the map NPP cannot supply the region's); palustrine keeps its regions'", mapped[NppSource == "USGS tidal marsh map", .N], nrow(mapped)),
      nrow(mapped) >= 5 && mapped[NppSource == "USGS tidal marsh map", .N >= 5 && all(abs(as.numeric(NPP) - round(MapNPP, 2)) < 1e-9 & abs(as.numeric(PeakFoliage) - round(MapNPP / 3, 3)) < 1e-9)] && mapped[, all(startsWith(NppSource, "USGS tidal marsh map"))] &&
      fit[StateClassId == EM[2], all(NppSource == "region")])
s8 <- paste(readLines(file.path(pkg, "src", "8-initial-stocks-spatial.R")), collapse = "\n"); px <- paste(readLines(file.path(pkg, "package.xml")), collapse = "\n")
mt <- fread(file.path(pkg, "defaults", "stsim", "stsim_FlowMultiplierType.csv"), sep = ",")$Name
check("Tidal Marsh Productivity: a Build Option, a data source, a multiplier type; stage 8 writes it on Net Growth Wetland: Total; stages 7 and 11 carry it",
      grepl('name="TidalMarshProductivity"', px, fixed = TRUE) && grepl('name="TidalMarshNppFolder"', px, fixed = TRUE) && "Tidal Marsh Productivity" %in% mt &&
      "TidalMarshNppFolder" %in% fread(file.path(pkg, "defaults", "library", "data-sources.csv"))$Column &&
      grepl('put_multiplier("Tidal Marsh Productivity", fg', s8, fixed = TRUE) && grepl('fg <- "Net Growth Wetland: Total"', s8, fixed = TRUE) &&
      all(vapply(c("7-climate-multipliers.R", "11-projection-climate.R"), function(f) grepl('"Crop Mix", "Tidal Marsh Productivity", "Marsh Salinity")', paste(readLines(file.path(pkg, "src", f)), collapse = "\n"), fixed = TRUE), TRUE)))

# ---- marsh salinity (2026-11-16): estuarine marsh methane by LANDFIRE salinity zone, as a pair of flow spatial multipliers (stage 8) ----
zt <- rd("stockflow", "marsh-salinity-ch4.csv"); zc <- rd("stockflow", "marsh-salinity-evt.csv"); evx <- fread(file.path(pkg, "defaults", "landcover", "evt2016-crosswalk-CONUS-v2.csv"))
check("marsh salinity: a methane value for every salinity zone in every estuarine region, saltier zones lower",
      setequal(zt$Region, unique(eco$EstuarineRegion)) && zt[, .N, by = Region][, all(N == uniqueN(zc$Zone))] && setequal(zt$Zone, zc$Zone) && all(as.numeric(zt$CH4) > 0) &&
      dcast(zt[, .(Region, Zone, v = as.numeric(CH4))], Region ~ Zone, value.var = "v")[, all(oligohaline > brackish & brackish > salt & `salt-brackish` < brackish & `salt-brackish` > salt)])
check("marsh salinity: every zoned LANDFIRE code is a tidal marsh class of the EVT crosswalk under the same name, each once",
      !anyDuplicated(zc$Code) && all(as.integer(zc$Code) %in% evx$VALUE) && all(zc$EvtName == evx$EVT_NAME[match(as.integer(zc$Code), evx$VALUE)]) && all(grepl("Marsh", zc$EvtName)))
f4 <- as.numeric(fit[StateClassId == EM[1], CH4Share]); b4 <- as.numeric(fit[StateClassId == EM[1], CH4])
mm <- outer(seq_along(f4), c(0.0135, 0.087, 0.412, 1.286), function(i, t) pmin(t / b4[i], g4$max_share / f4[i])); cf <- (1 - f4 * mm) / (1 - f4)
check("marsh salinity: for every estuarine budget and zone value, the CO2 factor takes off what the methane factor adds (a cell's belowground emission unchanged) and neither is negative",
      max(abs((1 - f4) * cf + f4 * mm - 1)) < 1e-12 && all(cf >= 0) && all(mm >= 0) && all(f4 * mm <= g4$max_share + 1e-12))
check("marsh salinity: the multiplier type and both flow groups are defined, the wetland CO2 group holds wetland CO2 flows only (the emergent classes' two among them), the CH4 group CH4 flows only; stage 8 writes the pair and stages 7 and 11 carry it",
      "Marsh Salinity" %in% mt && WCO2 %in% dd("stsim_FlowGroup.csv") && all(g4$co2 %in% memb[FlowGroupId == WCO2, FlowTypeId]) && all(grepl("(Wetland)", setdiff(memb[FlowGroupId == WCO2, FlowTypeId], g4$co2), fixed = TRUE)) && all(g4$ch4 %in% memb[FlowGroupId == "Emission: Wetland CH4", FlowTypeId]) && all(grepl("CH4$", memb[FlowGroupId == "Emission: Wetland CH4", FlowTypeId])) &&
      grepl('put_multiplier("Marsh Salinity", rows = srows)', s8, fixed = TRUE) && grepl('SAL_FG <- c("Emission: Wetland CH4", "Emission: Wetland Methane Source CO2")', s8, fixed = TRUE))

cat(sprintf("\n%d of %d checks passed\n", n - fails, n)); if (fails) quit(status = 1)
