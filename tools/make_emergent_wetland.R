# =============================================================================
# make_emergent_wetland.R - emergent wetland rates and starting pools by ecodivision, fitted to regional targets (to-do 39 step 1)
# =============================================================================
# Run from the package root: Rscript tools/make_emergent_wetland.R
# Reads defaults/stockflow/emergent-wetland-regions.csv (targets by class and region, each with its source) and
# emergent-wetland-ecodivisions.csv (the region of each ecodivision, one for estuarine and one for palustrine) and tidal-marsh-npp.csv
# (the USGS tidal marsh NPP map by ecodivision, dev/nonforest/09-tidal-marsh-npp.R: estuarine NPP and peak foliage where the map holds
# 10 km2 or more of the class), fits each ecodivision x
# class with src/nonforest-solve.R nf_fit_emergent (ST-Sim's flow order; peak live carbon, year-end litter and BG Slow, burial into
# Deep Soil), and writes:
#   defaults/stockflow/nonforest-multipliers-wetland.csv  emergent rows: growth split, turnover, each pool's total loss, burial share
#   defaults/stockflow/nonforest-net-growth.csv          emergent rows: Net Growth = NPP
#   defaults/initialstocks/emergent-wetland.csv          by ecodivision and class: the fitted steady state. BG Slow holds the soil to 1 m
#                                                        (0-30 + 30-100 cm) and Deep Soil starts at 0, so a cell's soil means the same in
#                                                        every class (user 2026-11-07); Deep Soil gains only the carbon buried during a run
#   defaults/stockflow/emergent-wetland-fit.csv          one row per ecodivision x class: targets, fitted rates, burial share
# The values these replace (the CONUS 1 km build's, from coastal Louisiana field data via IBIS; the same in every ecodivision) are kept
# once in defaults/stockflow/legacy-ibis/ for the step 3 target-source choice. The carbon method presets lose their emergent rows, so a
# filled Grassland, Shrubland and Wetland Carbon sheet no longer overrides the package's ecodivision values (tools/sync-library.R drops
# such rows from existing libraries when they still hold the legacy values exactly). Rerunning is harmless.
# =============================================================================
suppressPackageStartupMessages(library(data.table))
source("src/nonforest-solve.R")
EMERGENT <- c("Wetland: Estuarine Emergent", "Wetland: Palustrine Emergent")
d <- function(...) file.path("defaults", ...)
rd <- function(...) fread(d(...), colClasses = "character", na.strings = "", encoding = "UTF-8")
wr <- function(x, ...) fwrite(x, d(...), na = "", quote = "auto")

fm <- rd("stockflow", "nonforest-multipliers-wetland.csv"); ng <- rd("stockflow", "nonforest-net-growth.csv")
pa <- rd("stockflow", "nonforest-pathways.csv"); memb <- rd("stockflow", "stsim_FlowTypeGroupMembership.csv"); ord <- rd("stockflow", "stsim_FlowOrder.csv")
ini <- rd("initialstocks", "emergent-wetland.csv"); st <- rd("initialstocks", "stock-types.csv")
reg <- rd("stockflow", "emergent-wetland-regions.csv"); eco <- rd("stockflow", "emergent-wetland-ecodivisions.csv")
num <- c("NPP", "AgShare", "PeakFoliage", "RootShoot", "AgLitter", "BgLitter", "Soil0to30", "Soil30to100", "Burial")
for (k in num) set(reg, j = k, value = as.numeric(reg[[k]]))
tmap <- rd("stockflow", "tidal-marsh-npp.csv")[, `:=`(Km2 = as.numeric(Km2), MapNPP = as.numeric(MapNPP))]; MIN_KM2 <- 10
stopifnot(!anyNA(reg[, ..num]),all(eco$StratumId %in% fm$StratumId), all(unique(fm[StateClassId %in% EMERGENT, StratumId]) %in% eco$StratumId))

# ---- keep the legacy values once ---------------------------------------------------------------------------------------------
dir.create(d("stockflow", "legacy-ibis"), showWarnings = FALSE)
if (!file.exists(d("stockflow", "legacy-ibis", "emergent-multipliers.csv"))) {
  wr(fm[StateClassId %in% EMERGENT], "stockflow", "legacy-ibis", "emergent-multipliers.csv")
  wr(ng[StateClassId %in% EMERGENT], "stockflow", "legacy-ibis", "emergent-net-growth.csv")
  wr(ini, "stockflow", "legacy-ibis", "emergent-initial-stocks.csv")
  for (m in c("cbm-defaults", "fia-measured")) for (f in c("nonforest-rates", "nonforest-growth")) {
    x <- rd("carbon-assumptions", m, paste0(f, ".csv")); wr(x[StateClassId %in% EMERGENT], "stockflow", "legacy-ibis", sprintf("preset-%s-%s.csv", m, f)) }
  cat("Kept the legacy emergent wetland values in defaults/stockflow/legacy-ibis/\n") }
leg_m <- rd("stockflow", "legacy-ibis", "emergent-multipliers.csv")   # fit from the legacy shares, so a rerun gives the same values

# ---- fit each ecodivision x class --------------------------------------------------------------------------------------------
fits <- list(); newm <- list(); pools <- list()
for (i in seq_len(nrow(eco))) for (cls in EMERGENT) {
  e <- eco$StratumId[i]; r <- if (cls == EMERGENT[1]) eco$EstuarineRegion[i] else eco$PalustrineRegion[i]
  t <- reg[StateClassId == cls & Region == r]; if (nrow(t) != 1) stop(sprintf("no targets for %s in region %s", cls, r))
  # estuarine NPP from the USGS tidal marsh map where it holds MIN_KM2 or more of the class in the ecodivision (to-do 39 step 10, user
  # 2026-11-08: recalibrate to the map; the regional values were inference); peak foliage = the map's peak aboveground carbon (one crop
  # a year: aboveground NPP, a third of the total). Palustrine keeps its regional targets: the model's class is mostly inland marsh,
  # which the map does not cover.
  tm <- tmap[StratumId == e & StateClassId == cls & Km2 >= MIN_KM2]
  if (cls == EMERGENT[1] && nrow(tm)) { t <- copy(t); t[, `:=`(NPP = round(tm$MapNPP, 2), PeakFoliage = round(tm$MapNPP / 3, 3))]; nsrc <- "USGS tidal marsh map" } else nsrc <- "region"
  p <- pa[FromStratumId == e & FromStateClassId == cls]; m0 <- leg_m[StratumId == e & StateClassId == cls, .(FlowGroupId, Value)]
  tgt <- function(t) list(npp = t$NPP, ag_share = t$AgShare, foliage = t$PeakFoliage, roots = t$PeakFoliage * t$RootShoot, ag_litter = t$AgLitter,
                          bg_litter = t$BgLitter, soil = t$Soil0to30 + t$Soil30to100, burial = t$Burial)
  tg <- tgt(t); fit <- tryCatch(nf_fit_emergent(p, m0, memb, ord, tg), error = function(err) err)
  # where the map's NPP cannot supply the region's burial (Savanna, south Florida: map 2.83 against the region's 1.62 Mg C/ha/yr), the
  # map's NPP is kept and burial gives way (user 2026-11-08: hitting NPP matters more than the burial rate): scaled by map / region NPP,
  # then lowered by a tenth at a time until the soil target and burial can both be held; the burial used is recorded
  if (inherits(fit, "error") && nsrc != "region") { b0 <- t$Burial; rnpp <- reg[StateClassId == cls & Region == r, NPP]; t <- copy(t); t[, Burial := round(b0 * NPP / rnpp, 4)]
    repeat { tg <- tgt(t); fit <- tryCatch(nf_fit_emergent(p, m0, memb, ord, tg), error = function(err) err)
      if (!inherits(fit, "error") || t$Burial < 0.01) break; t[, Burial := round(Burial * 0.9, 4)] }
    nsrc <- sprintf("USGS tidal marsh map; burial lowered from %.2f to %.3f (the map's NPP cannot supply the region's)", b0, t$Burial)
    cat(sprintf("%s %s: map NPP %.2f; burial lowered from %.2f to %.3f Mg C/ha/yr\n", e, cls, t$NPP, b0, t$Burial)) }
  if (inherits(fit, "error")) stop(sprintf("%s %s (NPP %s, %s): %s", e, cls, t$NPP, nsrc, conditionMessage(fit)), call. = FALSE)
  m1 <- fit$mult[, Value := round(Value, 6)]
  # starting pools: the steady state of the rates as written (rounded), so a Build starts where the rates hold it
  ss <- nf_steady(nf_flows(p, m1, memb, ord), t$NPP)
  newm[[length(newm) + 1]] <- m1[, `:=`(StratumId = e, StateClassId = cls)]
  pools[[length(pools) + 1]] <- data.table(StratumID = e, StateClassID = cls, pool = c(names(ss$stock), "Deep Soil"), Value = c(ss$stock, 0))
  g <- NF_EMERGENT; v <- function(x) m1[FlowGroupId == x, Value]
  fits[[length(fits) + 1]] <- data.table(StratumId = e, StateClassId = cls, Region = r, NppSource = nsrc, NPP = t$NPP, PeakFoliage = t$PeakFoliage, PeakLive = round(tg$foliage + tg$roots, 3),
    FoliageTurnover = v(g$k_fol), RootTurnover = v(g$k_root), AgLitterLoss = v(g$k_ag), BgLitterLoss = v(g$k_bg), SoilLoss = v(g$k_soil),
    BurialShare = v(g$burial), SoilEmissionShare = v(g$soil_emit), Burial = round(ss$sink[["Deep Soil"]], 4), Aquatic = round(ss$sink[["Aquatic"]], 4),
    YearEndLive = round(sum(ss$stock[c("Biomass: Foliage", "Biomass: Fine Root")]), 3), Soil = round(ss$stock[["DOM: Belowground Slow"]], 2),
    Dieback = paste(fit$dieback, collapse = "; ")) }
fits <- rbindlist(fits); newm <- rbindlist(newm); pools <- rbindlist(pools)

# ---- write the package tables ------------------------------------------------------------------------------------------------
fm[newm, on = .(StratumId, StateClassId, FlowGroupId), Value := as.character(i.Value)]
wr(fm, "stockflow", "nonforest-multipliers-wetland.csv")
ng[fits, on = .(StratumId, StateClassId), Value := as.character(i.NPP)]
wr(ng, "stockflow", "nonforest-net-growth.csv")
attr_of <- setNames(st$Attribute, st$StockTypeId)
pools[, StateAttributeTypeID := attr_of[pool]]
if (anyNA(pools$StateAttributeTypeID)) stop("a pool has no attribute in stock-types.csv: ", paste(unique(pools[is.na(StateAttributeTypeID), pool]), collapse = "; "))
out <- pools[, .(StratumID, StateClassID, StateAttributeTypeID, AgeMin = NA_character_, AgeMax = NA_character_, Value = as.character(round(Value, 4)))]
wr(out[order(StratumID, StateClassID, StateAttributeTypeID)], "initialstocks", "emergent-wetland.csv")
wr(fits, "stockflow", "emergent-wetland-fit.csv")

# ---- presets: no emergent rows (the package holds ecodivision values a class-wide row would override) ---------------------------
for (m in c("cbm-defaults", "fia-measured")) for (f in c("nonforest-rates", "nonforest-growth")) {
  x <- rd("carbon-assumptions", m, paste0(f, ".csv")); wr(x[!StateClassId %in% EMERGENT], "carbon-assumptions", m, paste0(f, ".csv")) }

cat(sprintf("Fitted %d ecodivision x class budgets; NPP %.1f-%.1f, burial %.2f-%.2f Mg C/ha/yr, soil to 1 m %.0f-%.0f Mg C/ha\n",
            nrow(fits), min(fits$NPP), max(fits$NPP), min(fits$Burial), max(fits$Burial), min(fits$Soil), max(fits$Soil)))
print(unique(fits[, !c("StratumId")]), nrows = 50)
