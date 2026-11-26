# =============================================================================
# make_wetland_change.R - the carbon of change among water, wetland and barren (to-do 2 step 5; src/wetland-change-carbon.R)
# =============================================================================
# Writes, removing its own earlier rows first (so a rerun changes nothing) and touching no other row:
#   defaults/transitions/pathways/wetland-change.csv  the upland forest, shrub and grass classes to Water (one row per state class)
#   defaults/stockflow/event-pathways.csv              the event rows at the default shares (defaults/stockflow/wetland-change-carbon.csv);
#                                                      stage 3 writes them again from the Build's Wetland Change Carbon page
#   defaults/stsim/stsim_FlowType.csv                  the two flow types that carry carbon to Aquatic (WCC_NEW); the rest are standard
#   defaults/stockflow/stsim_FlowTypeGroupMembership.csv, stsim_FlowOrder.csv, stsim_OutputFilterFlows.csv   their groups, order and output
# Usage: Rscript tools/make_wetland_change.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
D <- function(...) file.path(pkg, "defaults", ...); source(file.path(pkg, "src", "wetland-change-carbon.R"))
rd <- function(...) fread(D(...), colClasses = "character", na.strings = "")
edit <- function(f, mine, add) { l <- sub("\r$", "", readLines(f, encoding = "UTF-8")); keep <- c(l[1], l[-1][!mine(l[-1])])
  con <- file(f, "wb"); writeLines(c(keep, add), con, sep = "\r\n", useBytes = TRUE); close(con)
  cat(sprintf("%s: %d lines removed, %d written\n", sub(paste0(pkg, "/"), "", f, fixed = TRUE), length(l) - length(keep), length(add))) }
# Upland forest, shrub and grass classes (and their disturbed twins) to Water (user 2026-11-26: "allow these vegetated classes to convert ...
# capture new reservoir construction"). Not agriculture or developed: change in and out of those belongs to the land-use sources.
sc <- rd("stsim", "stsim_StateClass.csv")$Name; veg <- sc[grepl(WCC_UPLAND, sc) & !grepl("Wetland", sc)]
edit(D("transitions", "pathways", "wetland-change.csv"), function(l) grepl(WCC_UPLAND_ROW, l) & !grepl("^,,,Disturbed: Wetland ", l), sprintf(",,,%s,,Water: All,,,Wetland Change: to Water,1,,,,,Yes,,,", veg))
v <- wcc_shares(rd("stockflow", "wetland-change-carbon.csv")); x <- wcc_rows(v, rd("transitions", "pathways", "wetland-change.csv"))
edit(D("stockflow", "event-pathways.csv"), function(l) grepl(",Wetland Change: [A-Za-z ]+ \\[Type\\],", l), x[, do.call(paste, c(lapply(.SD, function(z) ifelse(is.na(z), "", z)), sep = ","))])
mine <- function(l) grepl("^,*Wetland Change: (Emission|Export|Mortality) ", l); T <- WCC_NEW
edit(D("stsim", "stsim_FlowType.csv"), mine, sprintf("%s,%s", T, c(
                                                                    "Wetland that becomes water: live carbon carried to Aquatic", "Wetland that becomes water: dead and soil carbon carried to Aquatic")))
emit <- function(t, pool) sprintf("%s,%s,%s", t, c("Emission: Total", "Emission: Total (CO2e)", "LULC: Emission", "LULC: Emission (CO2e)", "LULC: Emission CO2", "LULC: Emission CO2 (CO2e)", paste("LULC: Emission", pool),
                                                   sprintf("LULC: Emission %s (CO2e)", pool), "Net Biome Productivity", "Net Biome Productivity (CO2e)"), c(1, 3.67, 1, 3.67, 1, 3.67, 1, 3.67, -1, -3.67))
export <- function(t) sprintf("%s,%s,%s", t, c("Lateral Flux", "Lateral Flux (CO2e)", "Net Biome Productivity", "Net Biome Productivity (CO2e)"), c(1, 3.67, -1, -3.67))
edit(D("stockflow", "stsim_FlowTypeGroupMembership.csv"), mine, c(export(T[["export_live"]]), export(T[["export_dom"]])))
edit(D("stockflow", "stsim_FlowOrder.csv"), mine, sprintf(",,%s,%s", T, c(11, 10)))
edit(D("stockflow", "stsim_OutputFilterFlows.csv"), mine, sprintf("%s [Type],Yes,No,No", T))
cat(wcc_label(v), "\n")
