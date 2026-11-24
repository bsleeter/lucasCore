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
tt <- function(x) sub("^Disturbed: (.+ Group)$", "Disturbed: Wetland \\1",   # the twin's disturbed class (to-do 57)
                      sub("^(Ag Contraction (Cropland|Pasture)): (.+ Group)$", "\\1: Wetland \\3", x))

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
ofs <- rd(D("stockflow", "stsim_OutputFilterStocks.csv")); st8 <- paste(unique(rd(D("initialstocks", "stock-types.csv"))$StockTypeId), "[Type]")
check("every stock stage 8 starts (DOM: Peat too) is mapped, so a projection can start from a historical run's final maps (2026-11-11: peat was not)",
      all(st8 %in% ofs$StockGroupId) && all(ofs[StockGroupId %in% st8, Spatial == "Yes" & AvgSpatial == "Yes"]))

# ---- methane from the forested wetland twins (2026-11-16; src/flows.R METHANE_POOLS): soil, root litter and the forest floor ---------
local({ e <- new.env(); sys.source(file.path(pkg, "src", "dom.R"), envir = e); sys.source(file.path(pkg, "src", "flows.R"), envir = e); sys.source(file.path(pkg, "src", "nonforest-solve.R"), envir = e)
  g <- e$CH4_FLOWS; n <- e$NF_CH4; p <- e$METHANE_POOLS; w4 <- rd(D("spinup", "wetland-ch4.csv"))
  memb <- rd(D("stockflow", "stsim_FlowTypeGroupMembership.csv")); fo <- rd(D("stockflow", "stsim_FlowOrder.csv")); ft <- fread(D("stsim", "stsim_FlowType.csv"), sep = ",")$Name
  o <- function(x) as.numeric(fo$Order[match(x, fo$FlowTypeId)]); mg <- function(x) memb[FlowTypeId == x]
  check("the forested and emergent wetland methane flows: the same shared flow types and root litter CH4; the emergent classes' soil and CO2 by flow types of their own (2026-11-24), which stand for the forested ones",
        identical(unname(e$NF_EMERGENT_TYPES[c(g$soil_co2, g$litter_co2, g$soil_ch4)]), unname(c(n$co2, n$ch4[["soil"]]))) && n$ch4[["litter"]] == g$litter_ch4 && g$soil_q10 == "Q10 Wetland Soil" &&
        identical(unname(n$shared), c(g$shared_soil, g$shared_litter)) && n$sink == g$sink && n$max_share == g$max_share && identical(p$co2[1:2], c(g$soil_co2, g$litter_co2)) && identical(p$ch4[1:2], c(g$soil_ch4, g$litter_ch4)))
  check("five source pools: soil and root litter, and the forest floor (leaf litter, twig litter, humus)", identical(p$code, c("BGS", "BGVF", "AGVF", "AGF", "AGS")) && identical(p[forest_floor == TRUE, code], e$FIA_DOM$litter) &&
        all(p$shared %in% e$FOREST_PATHWAYS$FlowType) && all(p[!is.na(other), other] %in% e$FOREST_PATHWAYS$FlowType))
  check("every source pool's flow types are defined, at the flow order of the pool's shared emission", all(c(p$co2, p$ch4) %in% ft) && all(o(p$co2) == o(p$shared)) && all(o(p$ch4) == o(p$shared)))
  check("each wetland CO2 flow keeps its pool's Q10 group (the soil's has its own); each CH4 flow has Q10 Wetland CH4 alone, counts as carbon (1) and as methane in CO2e (33.5)",
        all(vapply(seq_len(nrow(p)), function(i) { q <- function(x) grep("^Q10", mg(x)$FlowGroupId, value = TRUE); v <- function(x, k) as.numeric(mg(x)[FlowGroupId == k, Value])
          identical(q(p$co2[i]), if (p$code[i] == "BGS") "Q10 Wetland Soil" else q(p$shared[i])) && identical(q(p$ch4[i]), "Q10 Wetland CH4") &&
            "Emission: Wetland Methane Source CO2" %in% mg(p$co2[i])$FlowGroupId && v(p$ch4[i], "Emission: Total Rh") == 1 && v(p$ch4[i], "Net Biome Productivity") == -1 &&
            v(p$ch4[i], "Emission: Total (CO2e)") == 33.5 && v(p$ch4[i], "Net Ecosystem Productivity (CO2e)") == -33.5 && v(p$ch4[i], "Emission: Wetland CH4") == 1 &&
            v(p$co2[i], "Emission: Total (CO2e)") == 3.67 }, TRUE)))
  check("a methane target for each of the three twins and no other class, all positive", setequal(w4$StateClass, TW) && all(as.numeric(w4$CH4) > 0))
  vals <- c("Emission: BG Slow -> Atmosphere" = 0.004, "Stabilization: BG Slow -> Deep Soil" = 0.0005, "Emission: BG Very Fast -> Atmosphere" = 0.4, "Decay: BG Very Fast -> BG Slow" = 0.08,
            "Emission: AG Very Fast -> Atmosphere" = 0.3, "Decay: AG Very Fast -> AG Slow" = 0.07, "Emission: AG Fast -> Atmosphere" = 0.12, "Decay: AG Fast -> AG Slow" = 0.02,
            "Emission: AG Slow -> Atmosphere" = 0.015, "Transfer: AG Slow -> BG Slow" = 0.006, "Emission: AG Medium -> Atmosphere" = 0.03)
  s <- e$ch4_split(vals, 0.25)
  check("the split: every source pool's emission as CO2 (three quarters, by its wetland flow type) and CH4 (a quarter); down wood and every decay, transfer and burial untouched",
        !any(p$shared %in% names(s)) && isTRUE(all.equal(unname(s[p$co2]), unname(0.75 * vals[p$shared]))) && isTRUE(all.equal(unname(s[p$ch4]), unname(0.25 * vals[p$shared]))) &&
        identical(s[setdiff(names(vals), p$shared)], vals[setdiff(names(vals), p$shared)]) && length(s) == length(vals) + nrow(p))
  u <- e$ch4_unsplit(s)
  check("and back: the spin-up sees the rates it always did (each pool's total loss unchanged)", setequal(names(u), names(vals)) && isTRUE(all.equal(u[names(vals)], vals)) && identical(e$ch4_unsplit(vals), vals))
  # the year's emission: a fast pool emits from its stock plus the litter the live pools shed into it that year; a slow pool from its stock
  vt <- c(vals, "Biomass Turnover: Foliage -> AG Very Fast" = 0.9, "Biomass Turnover: Fine Roots -> AG Very Fast" = 0.3, "Biomass Turnover: Fine Roots -> BG Very Fast" = 0.3,
          "Biomass Turnover: Other Wood -> AG Fast" = 0.03, "Biomass Turnover: Coarse Roots -> AG Fast" = 0.01, "Transfer: Snag Branch -> AG Fast" = 0.07)
  stock <- c(BGS = 200, BGVF = 1, AGVF = 0, AGF = 8, AGS = 20, SnagBranch = 2); live <- c(Merchantable = 60, Other = 20, Foliage = 2, FineRoots = 1.5, CoarseRoots = 12)
  em <- e$methane_source_emission(stock, live, vt)
  want <- c(BGS = 200 * 0.004, BGVF = (1 + 1.5 * 0.3) * 0.4, AGVF = (0 + 2 * 0.9 + 1.5 * 0.3) * 0.3, AGF = (8 + 20 * 0.03 + 12 * 0.01 + 2 * 0.07) * 0.12, AGS = 20 * 0.015)
  check("the source emission: a fast pool emits from its stock and the year's litter (one that empties every year still emits its intake), a slow pool from its stock", isTRUE(all.equal(em, want)) && em[["AGVF"]] > 0)
  # the reference stand of the share: the ages the library has for the class, else one disturbance cycle
  wa <- e$methane_age_weights(c(80, 80, 120, 500, NA), 11, 201); wc <- e$methane_age_weights(numeric(), 11, 201)
  check("the share's reference stand: the stand ages present (an age past the curve counts as its last age), and one disturbance cycle only where the class has no cells",
        isTRUE(all.equal(sum(wa), 1)) && isTRUE(all.equal(wa[c(81, 121, 201)], c(0.5, 0.25, 0.25))) && sum(wa > 0) == 3 &&
        isTRUE(all.equal(wc, c(rep(1 / 11, 11), rep(0, 190)))) && isTRUE(all.equal(e$methane_age_weights(numeric(), 300, 50), rep(1 / 50, 50))) &&
        isTRUE(all.equal(e$methane_age_weights(c(-3, 0.4), 11, 5), c(1, 0, 0, 0, 0))))
  fp <- rbind(e$FOREST_PATHWAYS[, .(FromStateClassId = TW[1], FromStockTypeId = From, ToStockTypeId = To, FlowTypeId = FlowType, TransitionGroupId = NA_character_)],
              e$FOREST_PATHWAYS[, .(FromStateClassId = UP[1], FromStockTypeId = From, ToStockTypeId = To, FlowTypeId = FlowType, TransitionGroupId = NA_character_)],
              data.table(FromStateClassId = TW[1], FromStockTypeId = "DOM: Belowground Slow", ToStockTypeId = "Atmosphere: CO2", FlowTypeId = "LULC: Emission DOM CO2", TransitionGroupId = "Fire"))
  q <- e$ch4_pathways(fp, TW[1]); tw <- q[FromStateClassId == TW[1] & is.na(TransitionGroupId)]
  check("pathways: the twin's five source pools emit CO2 by their wetland flow types and CH4 beside them, each from its own pool to Atmosphere: CH4; the upland class and the event rows as they were; a second pass adds nothing",
        !any(p$shared %in% tw$FlowTypeId) && all(vapply(seq_len(nrow(p)), function(i) tw[FlowTypeId == p$co2[i], .N == 1 && ToStockTypeId == "Atmosphere"] &&
          tw[FlowTypeId == p$ch4[i], .N == 1 && ToStockTypeId == g$sink] && tw[FlowTypeId == p$ch4[i], FromStockTypeId] == tw[FlowTypeId == p$co2[i], FromStockTypeId], TRUE)) &&
        identical(q[FromStateClassId == UP[1]], fp[FromStateClassId == UP[1]]) && identical(q[!is.na(TransitionGroupId)], fp[!is.na(TransitionGroupId)]) && nrow(e$ch4_pathways(q, TW[1])) == nrow(q))
  s3 <- paste(readLines(file.path(pkg, "src", "3-carbon-flows.R")), collapse = "\n"); s4 <- paste(readLines(file.path(pkg, "src", "4-initial-stocks.R")), collapse = "\n")
  check("stage 3 splits a twin's rates after the Carbon Rates read-out, on the emission of all its source pools, and gives the classes with methane their pathways; stage 4 steps the pools with the rates put back together",
        grepl("dv <- ch4_split(dv, f)", s3, fixed = TRUE) && regexpr("rates[[i]] <- cbind", s3, fixed = TRUE) < regexpr("dv <- ch4_split(dv, f)", s3, fixed = TRUE) &&
        grepl("methane_source_emission(drop(w4 %*% d[seq_len(n4), c(METHANE_POOLS$code,", s3, fixed = TRUE) && grepl("w4 <- methane_age_weights(a4, cm$ri, n4)", s3, fixed = TRUE) && grepl("fp <- ch4_pathways(fp, ", s3, fixed = TRUE) && grepl("vals <- ch4_unsplit(", s4, fixed = TRUE)) })
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
