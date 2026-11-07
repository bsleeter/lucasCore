# =============================================================================
# make_grass_shrub.R - grassland and shrubland growth, soil decay and starting pools by ecodivision from a CONUS sample (to-do 39)
# =============================================================================
# Run from the package root: Rscript tools/make_grass_shrub.R
# Reads dev/nonforest/03-grass-shrub-sample.csv (dev/nonforest/03-grass-shrub-sample.R: RAP NPP 2014-2023 and gNATSGO soil in 3 x 3 km
# windows across CONUS, by class as stage 5 maps it) and, for each ecodivision x grassland or shrubland class:
#   targets   NPP = RAP herb + shrub NPP (the tree band left out); soil 0-30 cm and whole profile from gNATSGO. An ecodivision keeps its
#             own value with >= MIN_WINDOWS windows and >= MIN_CELLS cells of the class; otherwise the class's CONUS mean (all windows).
#             Shrubland: Post Fire Shrub (made by fire, not mapped) takes Shrubland: Non-sage's targets.
#   rates     today's (the CONUS 1 km build's, IBIS) turnover, litter rates and growth split, with Net Growth = NPP and BG Slow's
#             outflow scaled so the ordered steady state (src/nonforest-solve.R) holds the 0-30 cm soil
#   pools     the steady state of those rates; Deep Soil starts with the soil below 30 cm (whole profile - 0-30 cm)
# Writes the grass and shrub rows of defaults/stockflow/nonforest-multipliers-grassland-shrubland.csv and nonforest-net-growth.csv,
# defaults/initialstocks/grassland-shrubland.csv (now by ecodivision, with Deep Soil), defaults/stockflow/grass-shrub-targets.csv (the
# targets with their source and counts) and grass-shrub-fit.csv. Today's values are kept once in defaults/stockflow/legacy-ibis/; the
# carbon method presets lose their grass and shrub rows (a class-wide row would override the ecodivision values). Rerunning is harmless.
# =============================================================================
suppressPackageStartupMessages(library(data.table))
source("src/nonforest-solve.R")
MIN_WINDOWS <- 5L; MIN_CELLS <- 500L
d <- function(...) file.path("defaults", ...)
rd <- function(...) fread(d(...), colClasses = "character", na.strings = "", encoding = "UTF-8")
wr <- function(x, ...) fwrite(x, d(...), na = "", quote = "auto")

fm <- rd("stockflow", "nonforest-multipliers-grassland-shrubland.csv"); ng <- rd("stockflow", "nonforest-net-growth.csv")
pa <- rd("stockflow", "nonforest-pathways.csv"); memb <- rd("stockflow", "stsim_FlowTypeGroupMembership.csv"); ord <- rd("stockflow", "stsim_FlowOrder.csv")
st <- rd("initialstocks", "stock-types.csv"); GS <- sort(unique(fm$StateClassId)); ECO <- sort(unique(fm$StratumId))

# ---- keep the legacy values once ---------------------------------------------------------------------------------------------
L <- d("stockflow", "legacy-ibis"); dir.create(L, showWarnings = FALSE)
if (!file.exists(file.path(L, "grass-shrub-multipliers.csv"))) {
  wr(fm, "stockflow", "legacy-ibis", "grass-shrub-multipliers.csv")
  wr(ng[StateClassId %in% GS], "stockflow", "legacy-ibis", "grass-shrub-net-growth.csv")
  wr(rd("initialstocks", "grassland-shrubland.csv"), "stockflow", "legacy-ibis", "grass-shrub-initial-stocks.csv")
  for (m in c("cbm-defaults", "fia-measured")) for (f in c("nonforest-rates", "nonforest-growth")) {
    x <- rd("carbon-assumptions", m, paste0(f, ".csv")); wr(x[StateClassId %in% GS], "stockflow", "legacy-ibis", sprintf("preset-%s-%s-grass-shrub.csv", m, f)) }
  cat("Kept the legacy grassland and shrubland values in defaults/stockflow/legacy-ibis/\n") }
lm <- rd("stockflow", "legacy-ibis", "grass-shrub-multipliers.csv")

# ---- targets by ecodivision x class --------------------------------------------------------------------------------------------
s <- fread("dev/nonforest/03-grass-shrub-sample.csv")[is.na(error) & cells > 0]
s[, Npp := NppAnnual + NppPerennial + NppShrub]
agg <- function(x) x[, .(Windows = uniqueN(window), Cells = sum(cells), Treed = sum(treed, na.rm = TRUE), NPP = weighted.mean(Npp, nppCells, na.rm = TRUE),
                         NppTree = weighted.mean(NppTree, nppCells, na.rm = TRUE),
                         Soil0to30 = weighted.mean(Soil0to30, soilCells, na.rm = TRUE), Soil0to999 = weighted.mean(Soil0to999, soilCells, na.rm = TRUE)), by = StateClassId]
own <- s[, agg(.SD), by = StratumId]; conus <- agg(s)
tg <- CJ(StratumId = ECO, StateClassId = GS)
tg[, src := ifelse(StateClassId == "Shrubland: Post Fire Shrub", "Shrubland: Non-sage", StateClassId)]
tg <- merge(tg, own, by.x = c("StratumId", "src"), by.y = c("StratumId", "StateClassId"), all.x = TRUE)
tg[, Source := fifelse(!is.na(Windows) & Windows >= MIN_WINDOWS & Cells >= MIN_CELLS & is.finite(NPP) & is.finite(Soil0to30), "ecodivision sample", "CONUS class mean")]
cm <- conus[match(tg$src, StateClassId)]; fb <- which(tg$Source == "CONUS class mean")
for (k in c("NPP", "NppTree", "Soil0to30", "Soil0to999", "Windows", "Cells")) set(tg, i = fb, j = k, value = cm[[k]][fb])
tg[src != StateClassId, Source := paste(Source, "(Non-sage targets)")]
# ecodivisions where most NLCD 2001 grass and shrub cells are trees by 2014-2023 (RAP): their own values rest on the few cells left
tr <- fread("dev/nonforest/03-grass-shrub-sample.csv")[is.na(error), .(share = sum(treed, na.rm = TRUE) / (sum(cells) + sum(treed, na.rm = TRUE))), by = StratumId]
tg[, TreedShare := round(tr$share[match(StratumId, tr$StratumId)], 2)]
tg[startsWith(Source, "ecodivision") & TreedShare > 0.7, Source := paste(Source, "- few untreed cells (most of the ecodivision's NLCD 2001 grass and shrub is trees by 2014-2023)")]
tg[StateClassId == "Grassland: Irrigated Perennial", Source := paste(Source, "- small sample (RAP is not meant for irrigated land; alfalfa and irrigated pasture are Agriculture: Pasture)")]
if (anyNA(tg$NPP) || anyNA(tg$Soil0to30)) stop("no targets for: ", paste(unique(tg[is.na(NPP) | is.na(Soil0to30), src]), collapse = "; "))
tg[, Deep := pmax(0, Soil0to999 - Soil0to30)][, NPP := round(NPP, 4)]   # NPP as written, so the fit and the table agree

# ---- fit --------------------------------------------------------------------------------------------------------------------
fits <- list(); newm <- list(); pools <- list()
for (i in seq_len(nrow(tg))) {
  e <- tg$StratumId[i]; cls <- tg$StateClassId[i]
  p <- pa[FromStratumId == e & FromStateClassId == cls]; m0 <- lm[StratumId == e & StateClassId == cls, .(FlowGroupId, Value)]
  fit <- nf_fit_pool(p, m0, memb, ord, tg$NPP[i], "DOM: Belowground Slow", tg$Soil0to30[i])
  m1 <- fit$mult[FlowGroupId %in% fit$groups, Value := signif(Value, 8)]   # only the fitted rates are written; the rest stay as they are
  ss <- nf_steady(nf_flows(p, m1, memb, ord), tg$NPP[i])
  newm[[i]] <- m1[FlowGroupId %in% fit$groups][, `:=`(StratumId = e, StateClassId = cls)]
  pools[[i]] <- data.table(StratumID = e, StateClassID = cls, pool = c(names(ss$stock), "Deep Soil"), Value = c(ss$stock, tg$Deep[i]))
  fits[[i]] <- data.table(StratumId = e, StateClassId = cls, NPP = round(tg$NPP[i], 4), SoilLossFactor = signif(fit$factor, 4),
                          SoilLoss = signif(sum(m1[FlowGroupId %in% fit$groups, Value]), 4), Live = round(sum(ss$stock[grep("^Biomass", names(ss$stock))]), 3),
                          Dead = round(sum(ss$stock[grepl("^DOM", names(ss$stock)) & names(ss$stock) != "DOM: Belowground Slow"]), 3),
                          Soil0to30 = round(ss$stock[["DOM: Belowground Slow"]], 2), DeepSoil = round(tg$Deep[i], 2)) }
fits <- rbindlist(fits); newm <- rbindlist(newm); pools <- rbindlist(pools)

# ---- write -------------------------------------------------------------------------------------------------------------------
fm2 <- copy(lm); fm2[newm, on = .(StratumId, StateClassId, FlowGroupId), Value := as.character(i.Value)]
wr(fm2, "stockflow", "nonforest-multipliers-grassland-shrubland.csv")
ng[fits, on = .(StratumId, StateClassId), Value := as.character(i.NPP)]; wr(ng, "stockflow", "nonforest-net-growth.csv")
pools[, StateAttributeTypeID := setNames(st$Attribute, st$StockTypeId)[pool]]
if (anyNA(pools$StateAttributeTypeID)) stop("a pool has no attribute in stock-types.csv")
out <- pools[, .(StratumID, StateClassID, StateAttributeTypeID, AgeMin = NA_character_, AgeMax = NA_character_, Value = as.character(round(Value, 4)))]
wr(out[order(StratumID, StateClassID, StateAttributeTypeID)], "initialstocks", "grassland-shrubland.csv")
wr(tg[, .(StratumId, StateClassId, Source, Windows, Cells, TreedCellsLeftOut = Treed, EcodivisionTreedShare = TreedShare, NPP = round(NPP, 4), NppTree = round(NppTree, 4),
          Soil0to30 = round(Soil0to30, 2), Soil0to999 = round(Soil0to999, 2), DeepSoil = round(Deep, 2))], "stockflow", "grass-shrub-targets.csv")
wr(fits, "stockflow", "grass-shrub-fit.csv")
for (m in c("cbm-defaults", "fia-measured")) for (f in c("nonforest-rates", "nonforest-growth")) {
  x <- rd("carbon-assumptions", m, paste0(f, ".csv")); wr(x[!StateClassId %in% GS], "carbon-assumptions", m, paste0(f, ".csv")) }

cat(sprintf("%d ecodivision x class fits: %d from the ecodivision sample, %d from the CONUS class mean\n", nrow(tg), sum(startsWith(tg$Source, "ecodivision")), sum(startsWith(tg$Source, "CONUS"))))
lg <- rd("stockflow", "legacy-ibis", "grass-shrub-net-growth.csv")[StratumId == "Marine", .(StateClassId, old = as.numeric(Value))]
print(merge(conus[, .(StateClassId, Windows, Cells, NPP = round(NPP, 2), Soil0to30 = round(Soil0to30), Soil0to999 = round(Soil0to999))], lg, by = "StateClassId", all = TRUE))
