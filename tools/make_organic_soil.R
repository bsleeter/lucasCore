# =============================================================================
# make_organic_soil.R - peat fire and drained organic soils (to-do 53; user 2026-11-10: "include now")
# =============================================================================
# Organic soils are marked per cell by the Organic Soil Share map stage 8 writes from Data Source HistosolFile (gNATSGO: each map
# unit's percent of Histosol components, averaged over the cell). That map is the Flow Spatial Multiplier of the flow group
# "Organic Soil", which holds the four flows below, so they act on organic soils only and in proportion to their share of the cell.
#   Peat fire     a fire on a forested wetland twin also burns part of its BG Slow (the peat): the share burned on a wholly organic
#                 cell, by severity, Low 0.03, Medium 0.07, High 0.15 of the stock, written as the three gas rows (GAS_SPLIT). From
#                 about 15, 33 and 75 Mg C/ha burned of about 500 Mg C/ha: Turetsky et al. 2011 (undrained surface burns about
#                 2 kg C/m2), IPCC 2013 Wetlands Supplement Table 2.6 (undrained boreal/temperate wildfire 66 t dm/ha = 33 Mg C/ha),
#                 Turetsky & Wieder 2001 (3.2 kg C/m2). Deep drought burns of drained peat (Reddy et al. 2015, Great Dismal Swamp
#                 2011, 44 kg C/m2) are not represented: the model does not know a wetland is drained.
#   Drained       cropland and pasture on organic soil (drained for farming) lose BG Slow each year: the US GHG Inventory's emission
#                 factors for cultivated organic soils (USDA Methods Report 2024 Table 3-13, Ogle et al. 2003), cropland 11.2 (cool
#                 temperate) / 14.0 (warm temperate) / 14.3 (subtropical) and pasture 2.8 / 3.5 / 3.6 Mg C/ha/yr, as a yearly share of
#                 a reference organic soil stock of 600 Mg C/ha (organic woody wetland soils to 1 m, Uhran et al. 2021). Being a share,
#                 the loss slows as the peat is used up (half gone in about 30-40 years at cropland rates; IPCC applies the factor
#                 while the soil stays organic, and Everglades subsidence has slowed from 2.8 to 0.6 cm/yr since the 1920s).
# Writes defaults/stockflow/organic-soil-pathways.csv and adds the flow types, the groups "Organic Soil" and "LULC: Emission Peat",
# their memberships, flow order and output filters to the stock-flow definitions (rows already there are replaced).
# Notes and sources: dev/nonforest/review/notes/peat-fire-drained-organic-soils.md (local, not in git).
# Usage: Rscript tools/make_organic_soil.R            (from the repository root)
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
D <- function(...) file.path(pkg, "defaults", ...)
rd <- function(f) fread(f, sep = ",", colClasses = "character", na.strings = NULL, encoding = "UTF-8", fill = TRUE)
wr <- function(x, f) { for (k in names(x)) set(x, which(x[[k]] == ""), k, NA_character_); fwrite(x, f, quote = "auto", na = ""); cat(sprintf("%-55s %d rows\n", sub(paste0(pkg, "/"), "", f), nrow(x))) }

GAS <- c(CO2 = 0.9, CO = 0.09, CH4 = 0.01)
PEAT <- paste("LULC: Emission Peat", names(GAS)); names(PEAT) <- names(GAS)
DRAIN <- "Emission: Drained Organic Soil -> Atmosphere"
TWINS <- c("Wetland: Spruce/Fir Group", "Wetland: Oak/Gum/Cypress Group", "Wetland: Elm/Ash/Cottonwood Group")
BURN <- c(`Fire: Low Severity [Type]` = 0.03, `Fire: Medium Severity [Type]` = 0.07, `Fire: High Severity [Type]` = 0.15)
REF_STOCK <- 600
ZONE <- c(`Warm Continental` = "cool", `Warm Continental Mountains` = "cool", `Hot Continental` = "warm", `Hot Continental Mountains` = "cool",
          Prairie = "cool", Marine = "warm", `Marine Mountains` = "cool", Mediterranean = "warm", `Mediterranean Mountains` = "cool",
          Subtropical = "warm", `Subtropical Mountains` = "warm", Savanna = "subtropical", `Temperate Desert` = "cool", `Temperate Desert Mountains` = "cool",
          `Temperate Steppe` = "cool", `Temperate Steppe Mountains` = "cool", `Tropical/Subtropical Desert` = "warm", `Tropical/Subtropical Steppe` = "warm",
          `Tropical/Subtropical Steppe Mountains` = "warm")
EF <- data.table(zone = c("cool", "warm", "subtropical"), `Agriculture: Cropland` = c(11.2, 14.0, 14.3), `Agriculture: Pasture` = c(2.8, 3.5, 3.6))
eco <- rd(D("strata", "ecodivisions-list.csv"))$Name; stopifnot(all(eco %in% names(ZONE)))

# ---- pathways -------------------------------------------------------------------------------------------------------------------
tmpl <- rd(D("stockflow", "nonforest-pathways.csv"))[0]
row <- function(...) { a <- list(...); x <- as.data.table(lapply(setNames(names(tmpl), names(tmpl)), function(k) if (is.null(a[[k]])) rep("", max(lengths(a))) else as.character(a[[k]]))); x }
fire <- rbindlist(lapply(TWINS, function(cl) rbindlist(lapply(names(BURN), function(g) rbindlist(lapply(names(GAS), function(gs)
  row(FromStateClassId = cl, FromStockTypeId = "DOM: Belowground Slow", ToStockTypeId = paste0("Atmosphere: ", gs), TransitionGroupId = g,
      FlowTypeId = PEAT[[gs]], Multiplier = signif(BURN[[g]] * GAS[[gs]], 6))))))))
drain <- rbindlist(lapply(eco, function(e) rbindlist(lapply(c("Agriculture: Cropland", "Agriculture: Pasture"), function(cl)
  row(FromStratumId = e, FromStateClassId = cl, FromStockTypeId = "DOM: Belowground Slow", ToStockTypeId = "Atmosphere", FlowTypeId = DRAIN,
      Multiplier = signif(EF[zone == ZONE[[e]]][[cl]] / REF_STOCK, 6))))))
wr(rbind(fire, drain), D("stockflow", "organic-soil-pathways.csv"))

# ---- definitions ------------------------------------------------------------------------------------------------------------------
new_ft <- c(PEAT, DRAIN)
ft <- rd(D("stsim", "stsim_FlowType.csv")); ft <- ft[!Name %in% new_ft]
ft <- rbind(ft, data.table(Name = new_ft, Description = c(rep("Peat burned by fire on organic soil (forested wetland twins; Organic Soil Share map)", 3),
                                                             "Oxidation of drained organic soil under cropland and pasture (Organic Soil Share map)")), fill = TRUE)
wr(ft, D("stsim", "stsim_FlowType.csv"))
new_fg <- c("Organic Soil", "LULC: Emission Peat", "LULC: Emission Peat (CO2e)")
fg <- rd(D("stsim", "stsim_FlowGroup.csv")); fg <- fg[!Name %in% new_fg]
fg <- rbind(fg, data.table(Name = new_fg, Description = c("The flows on organic soil only (peat fire, drained organic soil): the group of the Organic Soil Share spatial multiplier",
                                                          "Peat burned by fire", "Peat burned by fire (CO2e)")), fill = TRUE)
wr(fg, D("stsim", "stsim_FlowGroup.csv"))
mb <- rd(D("stockflow", "stsim_FlowTypeGroupMembership.csv")); mb <- mb[!FlowTypeId %in% new_ft]
like <- function(ft_new, ft_old, swap = NULL) { x <- mb[FlowTypeId == ft_old][, FlowTypeId := ft_new]
  if (!is.null(swap)) for (k in names(swap)) x[FlowGroupId == k, FlowGroupId := swap[[k]]]
  x }
mb <- rbind(mb, rbindlist(lapply(names(GAS), function(gs) like(PEAT[[gs]], paste("LULC: Emission Live", gs),
                                                               c(`LULC: Emission Live` = "LULC: Emission Peat", `LULC: Emission Live (CO2e)` = "LULC: Emission Peat (CO2e)")))),
            like(DRAIN, "Emission: BG Slow -> Atmosphere"))
mb <- rbind(mb, data.table(FlowTypeId = new_ft, FlowGroupId = "Organic Soil", Value = "1"), fill = TRUE)
wr(mb, D("stockflow", "stsim_FlowTypeGroupMembership.csv"))
fo <- rd(D("stockflow", "stsim_FlowOrder.csv")); fo <- fo[!FlowTypeId %in% new_ft]
fo <- rbind(fo, data.table(FlowTypeId = new_ft, Order = c("11", "11", "11", "5")), fill = TRUE); wr(fo, D("stockflow", "stsim_FlowOrder.csv"))
of <- rd(D("stockflow", "stsim_OutputFilterFlows.csv")); keys <- c(paste(new_ft, "[Type]"), "LULC: Emission Peat", "LULC: Emission Peat (CO2e)")
of <- rbind(of[!FlowGroupId %in% keys], data.table(FlowGroupId = keys, Summary = "Yes", Spatial = "No", AvgSpatial = "No"))
wr(of, D("stockflow", "stsim_OutputFilterFlows.csv"))
mt <- rd(D("stsim", "stsim_FlowMultiplierType.csv")); if (!"Organic Soil Share" %in% mt$Name) mt <- rbind(mt, data.table(Name = "Organic Soil Share"), fill = TRUE)
wr(mt, D("stsim", "stsim_FlowMultiplierType.csv"))
cat("done\n")
