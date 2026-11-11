# Unit test: the forested wetland twins (to-do 53). Every default row of the three upland classes has its twin's row, the FIA split
# gives hydric conditions the twin's code, the regions table names a twin for every ecodivision, and burial is set for the twins only.
# Usage: Rscript tests/unit-wetland-forest.R   (from the package folder)
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath("."); D <- function(...) file.path(pkg, "defaults", ...)
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
rd <- function(f) fread(f, colClasses = "character", na.strings = "")
UP <- c("Forest: Spruce/Fir Group", "Forest: Oak/Gum/Cypress Group", "Forest: Elm/Ash/Cottonwood Group")
TW <- sub("^Forest: ", "Wetland: ", UP)
tt <- function(x) sub("^(Ag Contraction (Cropland|Pasture)): (.+ Group)$", "\\1: Wetland \\3", x)

# every row naming an upland class has a twin row with the same other values
files <- c(file.path("carbon-assumptions", c("cbm-defaults", "fia-measured"), "cbm-crosswalk.csv"),
           file.path("carbon-assumptions", c("cbm-defaults", "fia-measured"), "growth-inputs.csv"),
           file.path("cbm", "species-crosswalk.csv"), file.path("climate", "co2-classes.csv"), file.path("spinup", c("return-interval.csv", "soil-targets.csv")),
           file.path("transitions", "pathways", paste0(c("ag-contraction", "ag-expansion", "fire", "harvest", "urbanization"), ".csv")),
           character())
skip <- c(`transitions/pathways/harvest.csv` = "AgeMin")   # minimum harvest ages are the twins' own (tools/calibrate-harvest-age.R)
for (f in files) { x <- rd(D(f)); if (f %in% names(skip)) x[, (skip[[f]]) := NULL]
  key <- function(y) apply(y, 1, function(r) paste(ifelse(is.na(r), "", r), collapse = "|"))
  up <- x[Reduce(`|`, lapply(x, function(v) v %in% UP))]
  want <- copy(up); for (k in names(want)) { v <- want[[k]]; h <- v %in% UP; v[h] <- TW[match(v[h], UP)]; v <- tt(v)
    if (k == "FiaTypeGroups") v <- c(`120` = "121", `600` = "601", `700` = "701")[v] %||% v; set(want, j = k, value = v) }
  check(sprintf("%s: %d upland rows, each with its twin", f, nrow(up)), nrow(up) > 0 && all(key(want) %in% key(x))) }
sc <- rd(D("stsim", "stsim_StateClass.csv"))
# tables refitted on the split FIA conditions (2026-11-10): each twin has rows of its own there, fitted on its own plots
for (f in c(file.path("carbon-assumptions", "fia-measured", "live-turnover.csv"), file.path("climate", c("co2-ecm-share.csv", "co2-default-betas.csv")), file.path("transitions", "harvest-age.csv"))) {
  x <- rd(D(f)); cl <- intersect(c("StateClassId", "StateClassIdSource"), names(x))[1]
  check(sprintf("%s: rows for each twin", f), all(TW %in% x[[cl]])) }
check("the three twins are state classes 121, 601, 701, labelled Wetland", all(sc[match(TW, Name), Id] == c("121", "601", "701")) && all(sc[match(TW, Name), StateLabelXId] == "Wetland"))
cw <- rd(D("growth", "forest-type-crosswalk.csv"))
check("forest-type crosswalk: each twin fits on its own FIA code", all(cw[match(c("121", "601", "701"), StateClassId), FiaTypeGroups] == c("121", "601", "701")))
ty <- rd(D("stsim", "stsim_TransitionType.csv"))
check("the twins' Ag Contraction transition types exist with unique ids", all(tt(paste0("Ag Contraction Cropland: ", sub("^Forest: ", "", UP))) %in% ty$Name) && !anyDuplicated(ty$Id))
tg <- rd(D("stsim", "stsim_TransitionTypeGroup.csv"))
check("the twins' Ag Contraction types are in the same transition groups as the upland types'", all(vapply(sub("^Forest: ", "", UP), function(g) setequal(tg[TransitionTypeId == paste0("Ag Contraction Cropland: ", g), TransitionGroupId], tg[TransitionTypeId == paste0("Ag Contraction Cropland: Wetland ", g), TransitionGroupId]), TRUE)))
loc <- rd(D("transitions", "state-locations.csv"))
check("each twin has its own diagram cell", all(TW %in% loc$StateClassIdSource) && !anyDuplicated(loc$Location))

# the FIA split
fail <- function(...) stop(sprintf(...)); source(file.path(pkg, "src", "fia.R"))
g <- fia_hydric_group(c(120, 120, 600, 700, 800, 120, 600), c(31, 21, 39, 35, 31, NA, 40))
check("hydric conditions (physiographic class 31-39) of the three groups take the twin code, others keep theirs", identical(g, c(121L, 120L, 601L, 701L, 800L, 120L, 600L)))
eval(parse(text = grep("^is_(forest_class|wetland_forest) <-", readLines(file.path(pkg, "src", "shared.R")), value = TRUE)))
check("is_wetland_forest: the three twins only (stage 3 fits their dead wood apart from the upland types)",
      identical(is_wetland_forest(c(TW, UP, "Wetland: Estuarine Forested", "Wetland: Palustrine Emergent", NA)), c(TRUE, TRUE, TRUE, rep(FALSE, 6))) && all(is_forest_class(TW)))

# regions and burial
rg <- rd(D("growth", "wetland-forest-regions.csv")); eco <- rd(D("strata", "ecodivisions-list.csv"))
check("regions: one row per ecodivision, each naming a twin", nrow(rg) == uniqueN(rg$Ecodivision) && all(rg$StateClassId %in% TW))
check("regions: the northern lake states take Spruce/Fir and the Southeast Oak/Gum/Cypress",
      rg[Ecodivision == "Warm Continental", StateClassId] == TW[1] && rg[Ecodivision == "Subtropical", StateClassId] == TW[2])
bu <- rd(D("spinup", "wetland-burial.csv"))
check("burial: the three twins only, 0.25 / 0.1 / 0 Mg C/ha/yr", setequal(bu$StateClass, TW) && all(as.numeric(bu[match(TW, StateClass), Burial]) == c(0.25, 0.1, 0)))

# peat fire and drained organic soils (tools/make_organic_soil.R)
op <- rd(D("stockflow", "organic-soil-pathways.csv")); ft <- rd(D("stsim", "stsim_FlowType.csv")); stk <- rd(D("stsim", "stsim_StockType.csv"))
mb <- rd(D("stockflow", "stsim_FlowTypeGroupMembership.csv")); fo <- rd(D("stockflow", "stsim_FlowOrder.csv"))
check("organic soil pathways: flow types and stock types are defined", all(op$FlowTypeId %in% ft$Name) && all(c(op$FromStockTypeId, op$ToStockTypeId) %in% stk$Name))
check("every peat flow takes from DOM: Peat and has a flow order; the Organic Soil Share multiplier is gone", all(op$FromStockTypeId == "DOM: Peat") && all(unique(op$FlowTypeId) %in% fo$FlowTypeId) &&
      !"Organic Soil" %in% mb$FlowGroupId && !"Organic Soil Share" %in% rd(D("stsim", "stsim_FlowMultiplierType.csv"))$Name)
pf <- op[grepl("^Fire:", TransitionGroupId), .(s = sum(as.numeric(Multiplier))), by = .(FromStateClassId, TransitionGroupId)]
check("peat fire: any class burns 0.03 / 0.07 / 0.15 of its peat by severity (gases summed)", nrow(pf) == 3 && all(is.na(pf$FromStateClassId)) && all(abs(pf$s - c(0.03, 0.07, 0.15)[match(pf$TransitionGroupId, paste0("Fire: ", c("Low", "Medium", "High"), " Severity [Type]"))]) < 1e-9))
ev <- rd(D("stockflow", "event-pathways.csv")); ur <- op[TransitionGroupId %in% "Urbanization"]
check("urbanization emits the same share of peat as of BG Slow", nrow(ur) == 3 && abs(sum(as.numeric(ur$Multiplier)) - sum(as.numeric(ev[FromStockTypeId == "DOM: Belowground Slow" & TransitionGroupId == "Urbanization", Multiplier]))) < 1e-9)
sm <- rd(D("stockflow", "stsim_StockTypeGroupMembership.csv"))
check("Peat counts as soil and in total ecosystem carbon, as Deep Soil; it has a diagram cell and a starting map in stage 8",
      setequal(sm[StockTypeId == "DOM: Peat", StockGroupId], sm[StockTypeId == "Deep Soil", StockGroupId]) && "DOM: Peat" %in% rd(D("stockflow", "stsim_FlowPathwayDiagram.csv"))$StockTypeId &&
      "DOM: Peat" %in% rd(D("initialstocks", "stock-types.csv"))$StockTypeId)
check("drained peat does not count as a flow out of BG Slow", !"BG Slow ->" %in% mb[FlowTypeId == "Emission: Drained Organic Soil -> Atmosphere", FlowGroupId])
dr <- op[is.na(TransitionGroupId)]
check("drained organic soil: cropland and pasture in every ecodivision, cropland about 4 times pasture", nrow(dr) == 2 * nrow(eco) && all(dr[FromStateClassId == "Agriculture: Cropland", as.numeric(Multiplier)] / dr[FromStateClassId == "Agriculture: Pasture", as.numeric(Multiplier)][match(dr[FromStateClassId == "Agriculture: Cropland", FromStratumId], dr[FromStateClassId == "Agriculture: Pasture", FromStratumId])] > 3.5))
check("drained emissions count as emissions and against net biome productivity", all(c("Emission: Total", "Net Biome Productivity") %in% mb[FlowTypeId == "Emission: Drained Organic Soil -> Atmosphere", FlowGroupId]))
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
