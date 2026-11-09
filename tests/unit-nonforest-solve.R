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
check("Deep Soil starts at 0 (one soil definition: BG Slow holds the soil to 1 m; Deep Soil is burial during a run; user 2026-11-07)", all(ds$ds == 0))
bs <- merge(ini[StateAttributeTypeID == "Carbon Initial Conditions: Belowground Slow", .(StratumId = StratumID, StateClassId = StateClassID, b = as.numeric(Value))], fit[, .(StratumId, StateClassId, Region)])
check("BG Slow starts with the region's soil to 1 m (0-30 + 30-100 cm)", all(merge(bs, reg[, .(StateClassId, Region, t = as.numeric(Soil0to30) + as.numeric(Soil30to100))], by = c("StateClassId", "Region"))[, abs(b / t - 1) < 1e-3]))   # within 0.1%: the rates are written to 6 decimals
check("Pacific values: Marine estuarine burial 1.10, Mediterranean 1.04 (Wang et al. 2019)",
      isTRUE(all.equal(as.numeric(fit[StratumId == "Marine" & StateClassId == EM[1], Burial]), 1.10, tolerance = 1e-3)) &&
      isTRUE(all.equal(as.numeric(fit[StratumId == "Mediterranean" & StateClassId == EM[1], Burial]), 1.04, tolerance = 1e-3)))
pr <- unlist(lapply(c("cbm-defaults", "fia-measured"), function(m) c(rd("carbon-assumptions", m, "nonforest-rates.csv")$StateClassId, rd("carbon-assumptions", m, "nonforest-growth.csv")$StateClassId)))
check("the carbon method presets hold no emergent rows (they would override the ecodivision values)", !any(pr %in% EM))
check("Deep Soil is in stage 8's stock list with no forest curve column", { s <- st[StockTypeId == "Deep Soil"]; nrow(s) == 1 && is.na(s$CurveColumn) })

# ---- grassland and shrubland by ecodivision, literature rates (tools/make_grass_shrub.R; to-do 39, 2026-11-06) --------------------
gm <- rd("stockflow", "nonforest-multipliers-grassland-shrubland.csv"); gi <- rd("initialstocks", "grassland-shrubland.csv"); gt <- rd("stockflow", "grass-shrub-targets.csv")
gf <- rd("stockflow", "grass-shrub-fit.csv"); lit <- rd("stockflow", "grass-shrub-literature.csv"); GS <- sort(unique(gm$StateClassId)); CHAP <- "Shrubland: Chaparral"
sa <- rd("stockflow", "shrub-age.csv"); SAGE <- sa$StateClassId; BYAGE <- c(CHAP, SAGE)
check("a grass and shrub target and fit for every ecodivision x class", nrow(gt) == uniqueN(gm$StratumId) * length(GS) && nrow(gf) == nrow(gt))
sh <- function(cls) { r <- lit[StateClassId == cls]; while (!is.na(r$RatesOf)) r <- lit[StateClassId == r$RatesOf]; as.numeric(c(r$ShareFoliage, r$ShareWood, r$ShareFineRoot, r$ShareCoarseRoot)) }
NGG <- paste("Net Growth Non Forest: Atmosphere ->", c("Foliage", "Other Wood", "Fine Roots", "Coarse Roots"), "[Type]")
ok_sh <- all(vapply(setdiff(GS, BYAGE), function(cls) { x <- gm[StateClassId == cls & is.na(AgeMin) & FlowGroupId %in% NGG]; all(abs(as.numeric(x$Value[match(NGG, x$FlowGroupId)]) - sh(cls)) < 1e-6) }, TRUE))
check("each class's growth split is the literature table's (no IBIS share)", ok_sh)
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
  c(gap = gap, rising = all(diff(wood) > 0), mature = all(abs(as.numeric(mat$Value[match(NGG, mat$FlowGroupId)]) - sh(cls)) < 1e-6) && abs(growth_at(amax) - mt) < 1e-4,
    later = abs(growth_at(5) - mt) < 1e-4) }, c(gap = 0, rising = 0, mature = 0, later = 0))
check(sprintf("sage family: the age-bin pools step to the next bin's (largest gap %.1e Mg C/ha)", max(sage_ok["gap", ])), max(sage_ok["gap", ]) < 1e-3)
check("sage family: wood rises with years since fire (surviving coarse roots die back first); at AgeMax the literature split and RAP NPP; from age 2 the mature NPP",
      all(sage_ok[c("rising", "mature", "later"), ] == 1))
df <- rd("carbon-assumptions", "fia-measured", "disturbance-flows.csv")[StateClassId == CHAP]
check("chaparral fire rows in the presets, no pool losing more than it holds", nrow(df) > 0 && df[, .(s = sum(as.numeric(Share))), by = FromStockTypeId][, all(s <= 1 + 1e-9)] &&
      abs(df[FromStockTypeId == "Biomass: Fine Root", sum(as.numeric(Share))] - 0.25) < 1e-6)
pr2 <- unlist(lapply(c("cbm-defaults", "fia-measured"), function(m) c(rd("carbon-assumptions", m, "nonforest-rates.csv")$StateClassId, rd("carbon-assumptions", m, "nonforest-growth.csv")$StateClassId)))
check("the presets hold no grass or shrub rate rows", !any(pr2 %in% GS))

cat(sprintf("\n%d of %d checks passed\n", n - fails, n)); if (fails) quit(status = 1)
