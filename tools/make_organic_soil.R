# =============================================================================
# make_organic_soil.R - peat: its own stock, lost to fire, drainage and urbanization (to-do 53; user 2026-11-10: "include now", then
# "How do we initiate soc for areas where it is much higher than the class mean? ... we are missing a large potential land use change effect")
# =============================================================================
# Every class starts its soil (BG Slow) at the class mean, in balance with its inputs. On organic soil the carbon above that is held in
# the stock DOM: Peat, cell by cell: stage 8 sets it to the cell's gNATSGO soil (soc0_999) above the class's soil, where the cell has
# Histosol components (Data Source HistosolFile). Peat has no decay of its own, so an undisturbed cell holds it; it is lost only by
#   Peat fire     a fire on any class burns part of the peat: Low 0.03, Medium 0.07, High 0.15 of the stock, written as the three gas
#                 rows (GAS_SPLIT). From about 15, 33 and 75 Mg C/ha burned of about 500 Mg C/ha: Turetsky et al. 2011 (undrained
#                 surface burns about 2 kg C/m2), IPCC 2013 Wetlands Supplement Table 2.6 (undrained boreal/temperate wildfire 66 t dm/ha
#                 = 33 Mg C/ha), Turetsky & Wieder 2001 (3.2 kg C/m2). Deep drought burns of drained peat (Reddy et al. 2015, Great
#                 Dismal Swamp 2011, 44 kg C/m2) are not represented: the model does not know a wetland is drained.
#   Drainage      cropland and pasture on peat (drained for farming) lose it each year: the US GHG Inventory's emission factors for
#                 cultivated organic soils (USDA Methods Report 2024 Table 3-13, Ogle et al. 2003), cropland 11.2 (cool temperate) / 14.0
#                 (warm temperate) / 14.3 (subtropical) and pasture 2.8 / 3.5 / 3.6 Mg C/ha/yr, as a yearly share of a reference peat
#                 stock of 600 Mg C/ha (organic woody wetland soils to 1 m, Uhran et al. 2021). Being a share, the loss slows as the peat
#                 is used up (half gone in about 30-40 years at cropland rates; IPCC applies the factor while the soil stays organic, and
#                 Everglades subsidence has slowed from 2.8 to 0.6 cm/yr since the 1920s). A wetland drained to farmland starts losing
#                 its peat the year it becomes cropland or pasture.
#   Urbanization  the shares of BG Slow the LUCAS urbanization pathways emit (0.2: CO2 0.18, CO 0.018, CH4 0.002).
# Writes defaults/stockflow/organic-soil-pathways.csv and adds the flow types, the group "LULC: Emission Peat", memberships, flow
# order, output filters, the Peat stock's groups (DOM: Soil, Total Ecosystem, as Deep Soil) and its diagram cell to the stock-flow
# definitions (rows already there are replaced).
# Notes and sources: dev/nonforest/review/notes/peat-fire-drained-organic-soils.md (local, not in git).
# Usage: Rscript tools/make_organic_soil.R            (from the repository root)
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
D <- function(...) file.path(pkg, "defaults", ...)
rd <- function(f) fread(f, sep = ",", colClasses = "character", na.strings = NULL, encoding = "UTF-8", fill = TRUE)
wr <- function(x, f) { for (k in names(x)) set(x, which(x[[k]] == ""), k, NA_character_); fwrite(x, f, quote = "auto", na = ""); cat(sprintf("%-55s %d rows\n", sub(paste0(pkg, "/"), "", f), nrow(x))) }

PEAT_STOCK <- "DOM: Peat"
GAS <- c(CO2 = 0.9, CO = 0.09, CH4 = 0.01)
PEAT <- paste("LULC: Emission Peat", names(GAS)); names(PEAT) <- names(GAS)
DRAIN <- "Emission: Drained Organic Soil -> Atmosphere"
BURN <- c(`Fire: Low Severity [Type]` = 0.03, `Fire: Medium Severity [Type]` = 0.07, `Fire: High Severity [Type]` = 0.15)
URBAN <- c(CO2 = 0.18, CO = 0.018, CH4 = 0.002)   # as defaults/stockflow/event-pathways.csv takes from BG Slow
REF_STOCK <- 600
ZONE <- c(`Warm Continental` = "cool", `Warm Continental Mountains` = "cool", `Hot Continental` = "warm", `Hot Continental Mountains` = "cool",
          Prairie = "cool", Marine = "warm", `Marine Mountains` = "cool", Mediterranean = "warm", `Mediterranean Mountains` = "cool",
          Subtropical = "warm", `Subtropical Mountains` = "warm", Savanna = "subtropical", `Temperate Desert` = "cool", `Temperate Desert Mountains` = "cool",
          `Temperate Steppe` = "cool", `Temperate Steppe Mountains` = "cool", `Tropical/Subtropical Desert` = "warm", `Tropical/Subtropical Steppe` = "warm",
          `Tropical/Subtropical Steppe Mountains` = "warm")
EF <- data.table(zone = c("cool", "warm", "subtropical"), `Agriculture: Cropland` = c(11.2, 14.0, 14.3), `Agriculture: Pasture` = c(2.8, 3.5, 3.6))
eco <- rd(D("strata", "ecodivisions-list.csv"))$Name; stopifnot(all(eco %in% names(ZONE)))

# ---- pathways (every class: a class without peat has nothing to lose) ---------------------------------------------------------------
tmpl <- rd(D("stockflow", "nonforest-pathways.csv"))[0]
row <- function(...) { a <- list(...); x <- as.data.table(lapply(setNames(names(tmpl), names(tmpl)), function(k) if (is.null(a[[k]])) rep("", max(lengths(a))) else as.character(a[[k]]))); x }
fire <- rbindlist(lapply(names(BURN), function(g) rbindlist(lapply(names(GAS), function(gs)
  row(FromStockTypeId = PEAT_STOCK, ToStockTypeId = paste0("Atmosphere: ", gs), TransitionGroupId = g, FlowTypeId = PEAT[[gs]], Multiplier = signif(BURN[[g]] * GAS[[gs]], 6))))))
urban <- rbindlist(lapply(names(URBAN), function(gs) row(FromStockTypeId = PEAT_STOCK, ToStockTypeId = paste0("Atmosphere: ", gs), TransitionGroupId = "Urbanization",
                                                        FlowTypeId = paste("LULC: Emission DOM", gs), Multiplier = URBAN[[gs]])))
drain <- rbindlist(lapply(eco, function(e) rbindlist(lapply(c("Agriculture: Cropland", "Agriculture: Pasture"), function(cl)
  row(FromStratumId = e, FromStateClassId = cl, FromStockTypeId = PEAT_STOCK, ToStockTypeId = "Atmosphere", FlowTypeId = DRAIN,
      Multiplier = signif(EF[zone == ZONE[[e]]][[cl]] / REF_STOCK, 6))))))
wr(rbind(fire, urban, drain), D("stockflow", "organic-soil-pathways.csv"))

# ---- definitions ------------------------------------------------------------------------------------------------------------------
new_ft <- c(PEAT, DRAIN)
ft <- rd(D("stsim", "stsim_FlowType.csv")); ft <- ft[!Name %in% new_ft]
ft <- rbind(ft, data.table(Name = new_ft, Description = c(rep("Peat (DOM: Peat) burned by fire", 3), "Oxidation of drained peat (DOM: Peat) under cropland and pasture")), fill = TRUE)
wr(ft, D("stsim", "stsim_FlowType.csv"))
old_fg <- c("Organic Soil", "LULC: Emission Peat", "LULC: Emission Peat (CO2e)")   # "Organic Soil" was the Organic Soil Share map's group (retired 2026-11-10)
fg <- rd(D("stsim", "stsim_FlowGroup.csv")); fg <- fg[!Name %in% old_fg]
fg <- rbind(fg, data.table(Name = old_fg[-1], Description = c("Peat burned by fire", "Peat burned by fire (CO2e)")), fill = TRUE)
wr(fg, D("stsim", "stsim_FlowGroup.csv"))
mb <- rd(D("stockflow", "stsim_FlowTypeGroupMembership.csv")); mb <- mb[!FlowTypeId %in% new_ft & FlowGroupId != "Organic Soil"]
like <- function(ft_new, ft_old, swap = NULL) { x <- mb[FlowTypeId == ft_old][, FlowTypeId := ft_new]
  if (!is.null(swap)) for (k in names(swap)) x[FlowGroupId == k, FlowGroupId := swap[[k]]]
  x }
mb <- rbind(mb, rbindlist(lapply(names(GAS), function(gs) like(PEAT[[gs]], paste("LULC: Emission Live", gs),
                                                               c(`LULC: Emission Live` = "LULC: Emission Peat", `LULC: Emission Live (CO2e)` = "LULC: Emission Peat (CO2e)")))),
            like(DRAIN, "Emission: BG Slow -> Atmosphere")[FlowGroupId != "BG Slow ->"])   # it leaves Peat, not BG Slow
wr(mb, D("stockflow", "stsim_FlowTypeGroupMembership.csv"))
fo <- rd(D("stockflow", "stsim_FlowOrder.csv")); fo <- fo[!FlowTypeId %in% new_ft]
fo <- rbind(fo, data.table(FlowTypeId = new_ft, Order = c("11", "11", "11", "5")), fill = TRUE); wr(fo, D("stockflow", "stsim_FlowOrder.csv"))
of <- rd(D("stockflow", "stsim_OutputFilterFlows.csv")); keys <- c(paste(new_ft, "[Type]"), "LULC: Emission Peat", "LULC: Emission Peat (CO2e)")
of <- rbind(of[!FlowGroupId %in% c(keys, "Organic Soil")], data.table(FlowGroupId = keys, Summary = "Yes", Spatial = "No", AvgSpatial = "No"))
wr(of, D("stockflow", "stsim_OutputFilterFlows.csv"))
mt <- rd(D("stsim", "stsim_FlowMultiplierType.csv")); wr(mt[Name != "Organic Soil Share"], D("stsim", "stsim_FlowMultiplierType.csv"))
# the Peat stock: soil, as Deep Soil (DOM: Soil, Total Ecosystem), beside it on the diagram; a starting map from stage 8
sm <- rd(D("stockflow", "stsim_StockTypeGroupMembership.csv")); sm <- sm[StockTypeId != PEAT_STOCK]
sm <- rbind(sm, data.table(StockTypeId = PEAT_STOCK, StockGroupId = c("DOM: Soil", "Total Ecosystem")), fill = TRUE); wr(sm, D("stockflow", "stsim_StockTypeGroupMembership.csv"))
dg <- rd(D("stockflow", "stsim_FlowPathwayDiagram.csv")); dg <- dg[StockTypeId != PEAT_STOCK]
stopifnot(!"F6" %in% dg$Location); wr(rbind(dg, data.table(StockTypeId = PEAT_STOCK, Location = "F6")), D("stockflow", "stsim_FlowPathwayDiagram.csv"))
st <- rd(D("initialstocks", "stock-types.csv")); if (!PEAT_STOCK %in% st$StockTypeId) st <- rbind(st, data.table(StockTypeId = PEAT_STOCK), fill = TRUE)
wr(st, D("initialstocks", "stock-types.csv"))
cat("done\n")
