# =============================================================================
# make_agriculture.R - cropland and pasture growth, harvest, decay and starting pools by ecodivision (to-do 39 step 6)
# =============================================================================
# Run from the package root: Rscript tools/make_agriculture.R   (after dev/agriculture/01-ag-soil-sample.R and 02-nass-county-npp.R)
# User decisions 2026-11-07: agriculture grows and decays carbon like the other classes; one cropland class (NLCD 82, orchards and
# vineyards inside it for now) and pasture (NLCD 81); growth from NASS county yields; harvest to a new Agriculture Sector stock; yields
# vary by year.
#   targets   NPP: the ecodivision's NASS level (02: Tech. Bull. 1939 Table 3-3 coefficients over the ecodivision's fixed 1985-2023
#             crop mix), with its aboveground and harvested shares; soil: the ecodivision's gNATSGO whole profile under the class (01).
#             An ecodivision keeps its own values with enough data (NPP: >= MIN_HA harvested ha a year; soil: >= MIN_WINDOWS windows and
#             >= MIN_CELLS cells); otherwise the class's CONUS mean.
#   flows     the pools each class has (to-do 39 step 2): foliage and fine roots, aboveground and belowground very fast litter, AG
#             Slow, BG Slow. Growth (flow order 1) splits Net Growth between foliage and roots; harvest (order 2) moves a share of the
#             foliage to the Agriculture Sector (cropland: the NASS harvested share of aboveground growth; pasture: Removal); the rest of
#             the foliage and the roots die back to litter (order 6), so live carbon is 0 at year end. Litter decay rates from
#             defaults/stockflow/ag-literature.csv, each loss split as CBM-CFS3 does (0.815 of AG very fast emitted, 0.83 of BG very
#             fast; AG Slow mixes 0.006/yr into BG Slow). AG Slow's emission and BG Slow's emission are solved so the ordered steady
#             state (src/nonforest-solve.R) holds AgSlow and the soil target.
#   yearly    the Crop Yield flow multiplier on Net Growth Agriculture: Total = the ecodivision's NASS yield index for the year (1.0 =
#             the level the rates were solved at); the year after the last NASS year it holds ProjectionIndex (the mean of the last
#             10 NASS years), which projections keep.
# Writes defaults/stockflow/nonforest-pathways-agriculture.csv, nonforest-multipliers-agriculture.csv, ag-targets.csv, ag-crop-yield.csv,
# the agriculture rows of nonforest-net-growth.csv, ag-county-crop-npp.csv, ag-ecodivision-crop-npp.csv and ag-cac-county-crop-npp.csv (crop group growth for the
# Cropland Productivity and Crop Harvest maps), and defaults/initialstocks/agriculture.csv (the steady state); removes the old zero
# agriculture rows from nonforest-multipliers-other.csv. Rerunning is harmless.
# =============================================================================
suppressPackageStartupMessages(library(data.table))
source("src/nonforest-solve.R")
MIN_WINDOWS <- 10L; MIN_CELLS <- 1000L; MIN_HA <- 10000; INDEX_LAST <- 10L
d <- function(...) file.path("defaults", ...)
rd <- function(...) fread(d(...), colClasses = "character", na.strings = "", encoding = "UTF-8")
wr <- function(x, ...) fwrite(x, d(...), na = "", quote = "auto")
AG <- c("Agriculture: Cropland", "Agriculture: Pasture")
TY <- function(x) paste(x, "[Type]")
FOL <- "Biomass: Foliage"; FR <- "Biomass: Fine Root"; AGVF <- "DOM: Aboveground Very Fast"; BGVF <- "DOM: Belowground Very Fast"
AGS <- "DOM: Aboveground Slow"; BGS <- "DOM: Belowground Slow"; SECTOR <- "Agriculture Sector"
G_FOL <- "Net Growth Agriculture: Atmosphere -> Foliage"; G_FR <- "Net Growth Agriculture: Atmosphere -> Fine Roots"; HARV <- "Harvest: Foliage -> Agriculture Sector"
EM <- c(AGVF = 0.815, BGVF = 0.83)
frac <- function(k) 1 - exp(-k)

pa <- rd("stockflow", "nonforest-pathways.csv"); memb <- rd("stockflow", "stsim_FlowTypeGroupMembership.csv"); ord <- rd("stockflow", "stsim_FlowOrder.csv")
oth <- rd("stockflow", "nonforest-multipliers-other.csv"); ng <- rd("stockflow", "nonforest-net-growth.csv"); st <- rd("initialstocks", "stock-types.csv")
lit <- rd("stockflow", "ag-literature.csv"); ECO <- sort(unique(pa$FromStratumId))
for (x in c(G_FOL, G_FR, HARV)) if (!x %in% ord$FlowTypeId) stop("no flow order for ", x, " (defaults/stockflow/stsim_FlowOrder.csv)")

# ---- targets ---------------------------------------------------------------------------------------------------------------------
s <- fread("dev/agriculture/01-ag-soil-sample.csv")[is.na(error) | error == ""][, wid := paste(StratumId, window)]
sagg <- function(x) x[, .(Windows = uniqueN(wid), Cells = sum(cells), Soil0to30 = weighted.mean(Soil0to30, soilCells, na.rm = TRUE),
                          Soil0to999 = weighted.mean(Soil0to999, soilCells, na.rm = TRUE)), by = StateClassId]
so <- s[, sagg(.SD), by = StratumId]; sc <- sagg(s)
n <- fread("dev/agriculture/02-nass-ecodivision-npp.csv")
lev <- n[, .(level = level[1], agShare = agShare[1], harvShare = harvShare[1], ha = mean(ha[YEAR %between% c(1985, 2023)]), counties = max(counties)), by = .(StratumId, StateClassId)]
lc <- lev[, .(level = weighted.mean(level, ha), agShare = weighted.mean(agShare, ha * level), harvShare = weighted.mean(harvShare, ha * level)), by = StateClassId]
idx <- n[, .(StratumId, StateClassId, Timestep = YEAR, index)]
ic <- merge(n, lev[, .(StratumId, StateClassId, w = ha * level)], by = c("StratumId", "StateClassId"))[, .(index = sum(w * index) / sum(w)), by = .(StateClassId, Timestep = YEAR)]

tg <- CJ(StratumId = ECO, StateClassId = AG)
tg <- merge(merge(tg, so, by = c("StratumId", "StateClassId"), all.x = TRUE), lev, by = c("StratumId", "StateClassId"), all.x = TRUE)
tg[, SoilSource := fifelse(!is.na(Windows) & Windows >= MIN_WINDOWS & Cells >= MIN_CELLS & is.finite(Soil0to999), "ecodivision sample", "CONUS class mean")]
tg[, NppSource := fifelse(!is.na(level) & ha >= MIN_HA, "ecodivision NASS", "CONUS class mean")]
for (k in c("Soil0to30", "Soil0to999")) tg[SoilSource != "ecodivision sample", (k) := sc[[k]][match(StateClassId, sc$StateClassId)]]
for (k in c("level", "agShare", "harvShare")) tg[NppSource != "ecodivision NASS", (k) := lc[[k]][match(StateClassId, lc$StateClassId)]]
tg[, NPP := round(level, 4)]
# yearly index: the ecodivision's own where its NPP is, else the class's CONUS index
yr <- rbindlist(lapply(seq_len(nrow(tg)), function(i) { r <- tg[i]
  x <- if (r$NppSource == "ecodivision NASS") idx[StratumId == r$StratumId & StateClassId == r$StateClassId, .(Timestep, index)] else ic[StateClassId == r$StateClassId, .(Timestep, index)]
  x[, `:=`(StratumId = r$StratumId, StateClassId = r$StateClassId)] }))
last <- max(yr$Timestep)
tg[, ProjectionIndex := yr[Timestep > last - INDEX_LAST, mean(index), by = .(StratumId, StateClassId)][.SD, on = .(StratumId, StateClassId), V1]]
lt <- function(cls, k) lit[StateClassId == cls][[k]]

# ---- flows of a class: the annual grass pathways cut to the pools agriculture has, with its own growth and a harvest flow ---------
KEEP <- c("Biomass Turnover: Foliage -> AG Very Fast", "Biomass Turnover: Fine Roots -> BG Very Fast", "Emission: AG Very Fast -> Atmosphere", "Decay: AG Very Fast -> AG Slow",
          "Emission: AG Slow -> Atmosphere", "Transfer: AG Slow -> BG Slow", "Emission: BG Very Fast -> Atmosphere", "Decay: BG Very Fast -> BG Slow", "Emission: BG Slow -> Atmosphere")
path_of <- function(e, cls) {
  t <- pa[FromStratumId == e & FromStateClassId == "Grassland: Annual"]
  g <- t[FlowTypeId %in% c("Net Growth Non Forest: Atmosphere -> Foliage", "Net Growth Non Forest: Atmosphere -> Fine Roots")]
  g[, FlowTypeId := sub("Net Growth Non Forest", "Net Growth Agriculture", FlowTypeId)]
  h <- copy(g[1])[, `:=`(FromStockTypeId = FOL, ToStockTypeId = SECTOR, StateAttributeTypeId = NA_character_, FlowTypeId = HARV)]
  rbind(g, h, t[FlowTypeId %in% KEEP])[, FromStateClassId := cls] }
rates_of <- function(r) { cls <- r$StateClassId; g <- function(k) as.numeric(lt(cls, k))
  rm <- if (identical(lt(cls, "Removal"), "nass")) r$harvShare / r$agShare else g("Removal")
  v <- c(setNames(c(r$agShare, 1 - r$agShare, rm, 1, 1), TY(c(G_FOL, G_FR, HARV, KEEP[1], KEEP[2]))),
         setNames(frac(g("kAgVeryFast")) * c(EM[["AGVF"]], 1 - EM[["AGVF"]]), TY(KEEP[3:4])),
         setNames(c(0.015, 0.006), TY(KEEP[5:6])),
         setNames(frac(g("kBgVeryFast")) * c(EM[["BGVF"]], 1 - EM[["BGVF"]]), TY(KEEP[7:8])),
         setNames(0.0033, TY(KEEP[9])))
  data.table(FlowGroupId = names(v), Value = unname(v)) }

fits <- list(); mult <- list(); pools <- list(); paths <- list()
for (i in seq_len(nrow(tg))) { r <- tg[i]; p <- path_of(r$StratumId, r$StateClassId); m <- rates_of(r)
  m <- nf_fit_pool(p, m, memb, ord, r$NPP, AGS, as.numeric(lt(r$StateClassId, "AgSlow")), only = TY("Emission: AG Slow -> Atmosphere"))$mult
  m <- nf_fit_pool(p, m, memb, ord, r$NPP, BGS, r$Soil0to999)$mult; m[, Value := signif(Value, 8)]
  ss <- nf_steady(nf_flows(p, m, memb, ord), r$NPP)
  paths[[i]] <- p; mult[[i]] <- m[, `:=`(StratumId = r$StratumId, StateClassId = r$StateClassId)]
  pools[[i]] <- data.table(StratumID = r$StratumId, StateClassID = r$StateClassId, pool = c(names(ss$stock), "Deep Soil"), Value = c(ss$stock, 0))
  fits[[i]] <- data.table(StratumId = r$StratumId, StateClassId = r$StateClassId, NPP = r$NPP, Harvest = round(ss$sink[[SECTOR]], 4),
                          Live = round(sum(ss$stock[grep("^Biomass", names(ss$stock))]), 4), AgLitter = round(ss$stock[[AGVF]], 3), RootLitter = round(ss$stock[[BGVF]], 3),
                          AgSlow = round(ss$stock[[AGS]], 3), Soil = round(ss$stock[[BGS]], 2), SoilEmission = signif(m[FlowGroupId == TY("Emission: BG Slow -> Atmosphere"), Value], 4)) }
fits <- rbindlist(fits); mult <- rbindlist(mult); pools <- rbindlist(pools); paths <- rbindlist(paths)
if (any(fits$Live > 1e-6)) stop("live carbon is not 0 at year end")

# ---- write -------------------------------------------------------------------------------------------------------------------
wr(paths[, names(pa), with = FALSE], "stockflow", "nonforest-pathways-agriculture.csv")
tm <- oth[0]; fm <- rbindlist(list(tm, mult[, .(StratumId, StateClassId, FlowGroupId, Value = as.character(Value))]), fill = TRUE)
setorder(fm, StratumId, StateClassId, FlowGroupId); wr(fm, "stockflow", "nonforest-multipliers-agriculture.csv")
wr(oth[!StateClassId %in% AG], "stockflow", "nonforest-multipliers-other.csv")
t0 <- ng[1][, `:=`(StratumId = NA_character_, StateClassId = NA_character_, Value = NA_character_)]
nga <- cbind(t0[rep(1, nrow(tg)), setdiff(names(ng), c("StratumId", "StateClassId", "Value")), with = FALSE], tg[, .(StratumId, StateClassId, Value = as.character(NPP))])[, names(ng), with = FALSE]
wr(rbind(ng[!StateClassId %in% AG], nga), "stockflow", "nonforest-net-growth.csv")
yo <- rbind(yr[, .(StratumId, StateClassId, Timestep, Value = round(index, 4))],
            tg[, .(StratumId, StateClassId, Timestep = last + 1L, Value = round(ProjectionIndex, 4))])
setorder(yo, StateClassId, StratumId, Timestep); wr(yo, "stockflow", "ag-crop-yield.csv")
attr_of <- setNames(st$Attribute, st$StockTypeId); pools[, StateAttributeTypeID := attr_of[pool]]
if (anyNA(pools$StateAttributeTypeID)) stop("a pool has no attribute in stock-types.csv")
wr(pools[, .(StratumID, StateClassID, StateAttributeTypeID, AgeMin = NA_character_, AgeMax = NA_character_, Value = as.character(round(Value, 4)))][order(StratumID, StateClassID, StateAttributeTypeID)],
   "initialstocks", "agriculture.csv")
wr(merge(tg[, .(StratumId, StateClassId, NppSource, HarvestedHa = round(ha), Counties = counties, NPP, AgShare = round(agShare, 4), HarvestShare = round(harvShare, 4),
                ProjectionIndex = round(ProjectionIndex, 4), SoilSource, Windows, Cells, Soil0to30 = round(Soil0to30, 2), Soil0to999 = round(Soil0to999, 2))],
         fits[, .(StratumId, StateClassId, Harvest, AgLitter, RootLitter, AgSlow, SoilEmission)], by = c("StratumId", "StateClassId")), "stockflow", "ag-targets.csv")
print(fits[, .(n = .N, NPP = round(median(NPP), 2), Harvest = round(median(Harvest), 2), AgLitter = round(median(AgLitter), 2), RootLitter = round(median(RootLitter), 2),
               AgSlow = round(median(AgSlow), 2), Soil = round(median(Soil), 1), SoilK = signif(median(SoilEmission), 3)), by = StateClassId])
cat(sprintf("yearly Crop Yield index %d-%d; projection index (mean of the last %d NASS years) %s\n", min(yr$Timestep), last, INDEX_LAST,
            paste(tg[, sprintf("%s %.2f-%.2f", sub("Agriculture: ", "", StateClassId[1]), min(ProjectionIndex), max(ProjectionIndex)), by = StateClassId]$V1, collapse = "; ")))
# the crop group growth the Cropland Productivity map looks up (stage 8; dev/agriculture/02-nass-county-npp.R): by county and by
# ecodivision, 1985-2023 means per harvested ha of NPP, aboveground growth and harvest (the Crop Harvest map)
for (f in c("county", "ecodivision")) wr(fread(sprintf("dev/agriculture/02-nass-%s-crop-npp.csv", f), colClasses = list(character = if (f == "county") "GEOID" else NULL)),
                                         "stockflow", sprintf("ag-%s-crop-npp.csv", f))
# California's County Agricultural Commissioners' growth of the crops NASS's survey leaves out (dev/agriculture/05-cac-county-crop-npp.R;
# user 2026-11-08): the map takes these county values only, with no fallback
if (file.exists("dev/agriculture/05-cac-county-crop-npp.csv")) wr(fread("dev/agriculture/05-cac-county-crop-npp.csv", colClasses = list(character = "GEOID")), "stockflow", "ag-cac-county-crop-npp.csv") else
  cat("dev/agriculture/05-cac-county-crop-npp.csv not found: ag-cac-county-crop-npp.csv not written\n")
# (2026-11-08: the map is divided by the ecodivision's NASS level, NPP above, so ag-cdl-ecodivision-npp.csv is no longer written)
if (file.exists(d("stockflow", "ag-cdl-ecodivision-npp.csv"))) invisible(file.remove(d("stockflow", "ag-cdl-ecodivision-npp.csv")))
