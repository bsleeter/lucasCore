# Unit test: management actions (to-do 58; tools/make_management.R, src/management.R). Replanting with or without site preparation
# and its failure act on every disturbed forest class, the site preparation carbon moves at most each pool's stock, and the Management
# Actions rows become targets that add up to the area asked for, on one set of strata keys, with an age window.
# Usage: Rscript tests/unit-management.R   (from the package folder)
suppressPackageStartupMessages(library(data.table))
D <- function(...) file.path("defaults", ...)
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
rd <- function(f) fread(f, colClasses = "character", na.strings = "")
source(file.path("src", "management.R"))

# ---- defaults ----------------------------------------------------------------------------------------------------------------
sc <- rd(D("stsim", "stsim_StateClass.csv")); id <- as.integer(sc$Id); disf <- sc[id >= 2100 & id < 3000]
ty <- rd(D("stsim", "stsim_TransitionType.csv")); tg <- rd(D("stsim", "stsim_TransitionTypeGroup.csv")); gr <- rd(D("stsim", "stsim_TransitionGroup.csv"))
rep6 <- setdiff(MG_TYPES, MG_SALVAGE)
check("six replanting types, Ids 1200-1205, unique", all(rep6 %in% ty$Name) && setequal(as.integer(ty$Id[match(rep6, ty$Name)]), 1200:1205) && !anyDuplicated(ty$Id))
check("groups: Management: Replanting (the six), Site Preparation: Burn and Mechanical (two each)", all(c(MG_REPLANT_GROUP, "Site Preparation: Burn", "Site Preparation: Mechanical") %in% gr$Name) &&
      setequal(tg[TransitionGroupId == MG_REPLANT_GROUP, TransitionTypeId], rep6) &&
      setequal(tg[TransitionGroupId == "Site Preparation: Burn", TransitionTypeId], grep("Burn", rep6, value = TRUE)) &&
      setequal(tg[TransitionGroupId == "Site Preparation: Mechanical", TransitionTypeId], grep("Mechanical", rep6, value = TRUE)))
pw <- rd(D("transitions", "pathways", "management.csv"))
check("31 disturbed forest classes, each with the six types", nrow(disf) == 31 && nrow(pw) == 31 * 6 && all(pw[, .N, by = StateClassIdSource]$N == 6) && setequal(pw$StateClassIdSource, disf$Name))
ok <- pw[!grepl("failed", TransitionTypeId)]; fl <- pw[grepl("failed", TransitionTypeId)]
check("a planting that takes goes to the parent forest class at age 0", all(ok$StateClassIdDest == sc$Name[match(as.integer(sc$Id[match(ok$StateClassIdSource, sc$Name)]) - 2000L, id)]) && all(ok$AgeReset == "Yes"))
check("a failed planting stays in its disturbed class with its age", all(fl$StateClassIdDest == fl$StateClassIdSource) && all(fl$AgeReset == "No"))
check("no ages on the pathways (the page sets the window)", all(is.na(pw$AgeMin) & is.na(pw$AgeMax)))
sv <- rd(D("transitions", "pathways", "harvest.csv"))[TransitionTypeId == MG_SALVAGE]
check("salvage logging on the disturbed forest classes only", setequal(sv$StateClassIdSource, disf$Name))
ev <- rd(D("stockflow", "event-pathways.csv"))[TransitionGroupId %in% c("Site Preparation: Burn", "Site Preparation: Mechanical")]
check("site preparation flows: both groups", setequal(unique(ev$TransitionGroupId), c("Site Preparation: Burn", "Site Preparation: Mechanical")))
check("site preparation moves at most each pool's whole stock", all(ev[, sum(as.numeric(Multiplier)), by = .(TransitionGroupId, FromStockTypeId)]$V1 <= 1 + 1e-9))
check("pile and burn emits; mechanical does not", any(grepl("^Atmosphere", ev[TransitionGroupId == "Site Preparation: Burn", ToStockTypeId])) &&
      !any(grepl("^Atmosphere", ev[TransitionGroupId == "Site Preparation: Mechanical", ToStockTypeId])))
de <- rd(D("metadata", "definitions.csv"))
check("every management type and group is defined", all(c(rep6, MG_REPLANT_GROUP, "Site Preparation: Burn", "Site Preparation: Mechanical") %in% de$Name))

# ---- the page as targets -------------------------------------------------------------------------------------------------------
say <- function(...) invisible(NULL); fail <- function(...) stop(sprintf(...), call. = FALSE)
# 6 land cells: secondary units 1 (cells 1-3) and 2 (4-6); tertiary A (1, 2, 4) and B (3, 5, 6); forest on all but cell 6
land <- rep(TRUE, 6); lev <- list(Primary = rep(1L, 6), Secondary = c(1L, 1L, 1L, 2L, 2L, 2L), Tertiary = c(1L, 1L, 2L, 1L, 2L, 2L))
lev_list <- list(Primary = data.table(Name = "Eco", Id = "1"), Secondary = data.table(Name = c("S1", "S2"), Id = c("1", "2")), Tertiary = data.table(Name = c("A", "B"), Id = c("1", "2")))
lev_col <- c(Primary = "StratumId", Secondary = "SecondaryStratumId", Tertiary = "TertiaryStratumId")
scv <- c(200L, 2200L, 200L, 2200L, 200L, 32L)
run <- function(ma, tile = NA_character_) management_targets(ma, 1985L, 2023L, 2030L, land, lev, lev_list, lev_col, tile, scv, say, fail)
r1 <- run(data.table(ActionId = "Replanting", Amount = 100, Survival = 0.8, SitePreparation = "Pile and burn", Priority = "None (random among eligible cells)"))
t1 <- r1$targets[Timestep > 2023]
check("replanting: 80% planted, 20% failed, every projection year, the burn types", all(abs(t1[grepl("failed", TransitionGroupId), Amount] - 20) < 1e-9) &&
      all(abs(t1[!grepl("failed", TransitionGroupId), Amount] - 80) < 1e-9) && uniqueN(t1$Timestep) == 7 && all(grepl("after Burn Site Prep", t1$TransitionGroupId)))
check("no strata named, no tiles: one row a year with no strata keys", !any(c("SecondaryStratumId", "TertiaryStratumId") %in% names(r1$targets)) && nrow(t1) == 14)
check("a zero row at the historical start replaces stage 6's", all(r1$targets[Timestep == 1985, Amount] == 0) && setequal(r1$groups, unique(r1$targets$TransitionGroupId)))
m1 <- r1$multipliers[TransitionGroupId == "Management: Replanting after Burn Site Prep [Type]"]
check("replanting window 1-5 by default: 0 below, 1 within, 0 above", nrow(m1) == 3 && identical(m1$Amount, c(0, 1, 0)) && m1$AgeMin[2] == 1 && m1$AgeMax[2] == 5)
r2 <- run(data.table(ActionId = c("Salvage logging", "Salvage logging"), Amount = c(30, 60), StartYear = c(NA, 2028), TertiaryStratumId = c("B", NA)))
t2 <- r2$targets[Timestep > 2023]
check("salvage by tertiary unit: B gets 30 a year, A none, until 2027", all(t2[Timestep < 2028 & TertiaryStratumId == "B", Amount] == 30) && all(t2[Timestep < 2028 & TertiaryStratumId == "A", Amount] == 0))
check("salvage: from 2028 the study-area row adds 60 spread by forest land (A 3 forest cells, B 2)", all(abs(t2[Timestep >= 2028, sum(Amount), by = Timestep]$V1 - 90) < 1e-9) &&
      all(abs(t2[Timestep >= 2028 & TertiaryStratumId == "A", Amount] - 36) < 1e-9))
check("salvage window 0-2 by default", identical(r2$multipliers$Amount, c(1, 0)) && r2$multipliers$AgeMax[1] == 2)
r3 <- run(data.table(ActionId = "Replanting", Amount = 90, Survival = 1, SecondaryStratumId = "S2"), tile = "Secondary")
t3 <- r3$targets[Timestep > 2023 & !grepl("failed", TransitionGroupId)]
check("with tiles: keys at the tile level; the row's unit gets it all", "SecondaryStratumId" %in% names(t3) && all(t3[SecondaryStratumId == "S2", Amount] == 90) && all(t3[SecondaryStratumId == "S1", Amount] == 0))
check("with tiles, a row with no tile-level unit stops (a target must lie inside one tile)", inherits(try(run(data.table(ActionId = "Salvage logging", Amount = 10, TertiaryStratumId = "A"), tile = "Secondary"), silent = TRUE), "try-error"))
r4 <- run(data.table(ActionId = "Salvage logging", Amount = c(10, 20), SecondaryStratumId = "S1", TertiaryStratumId = c("A", "B")), tile = "Secondary")
t4 <- r4$targets[Timestep > 2023]
check("with tiles, a tile unit and a unit at another level (County A > owner A, then owner B)", all(c("SecondaryStratumId", "TertiaryStratumId") %in% names(t4)) &&
      all(t4[SecondaryStratumId == "S1" & TertiaryStratumId == "A", Amount] == 10) && all(t4[SecondaryStratumId == "S1" & TertiaryStratumId == "B", Amount] == 20) && all(t4[SecondaryStratumId == "S2", Amount] == 0))
r5 <- run(data.table(ActionId = "Salvage logging", Amount = 7, StratumId = "Eco"))
check("a primary (ecodivision) unit: keys on StratumId", "StratumId" %in% names(r5$targets) && all(r5$targets[Timestep > 2023, Amount] == 7))
check("two replanting priorities in one scenario stop", inherits(try(run(data.table(ActionId = c("Replanting", "Replanting"), Amount = 1,
      Priority = c("None (random among eligible cells)", "Far from live forest (least likely to return on its own)"))), silent = TRUE), "try-error"))
check("a row outside the projection is left out", is.null(run(data.table(ActionId = "Replanting", Amount = 5, StartYear = 2040))))
# ---- costs (transition attributes) -------------------------------------------------------------------------------------------
cf <- file.path("defaults", "management", "costs.csv")
cd <- management_cost_defaults(cf)
dv <- function(region, item) mg_cost_default(cd, region, item)
check("cost defaults: national rows for every item, Low <= Central <= High", all(c(MG_COST_ITEMS, MG_LOSS_ITEM) %in% cd$values[Region == "All", Item]) &&
      all(cd$values[Item != MG_LOSS_ITEM, Low <= Central & Central <= High]))
check("every cost region in the defaults has a row in the region map, every map region has costs", setequal(setdiff(unique(cd$values$Region), "All"), unique(cd$regions$Region)))
check("every ecodivision (primary stratum) has a cost region", setequal(fread(file.path("defaults", "stsim", "stsim_Stratum.csv"))$Name, cd$regions$Ecodivision))
check("cost defaults convert per hectare to the library's unit (acres: /2.471), the loss share stays",
      abs(mg_cost_default(management_cost_defaults(cf, 2.471), "All", "Planting")[["Central"]] - dv("All", "Planting")[["Central"]] / 2.471) < 1e-9 &&
      mg_cost_default(management_cost_defaults(cf, 2.471), "All", MG_LOSS_ITEM)[["Central"]] == 0.25)
check("a region without its own row takes the national one", identical(dv("Interior West", "Site preparation: Mechanical"), dv("All", "Site preparation: Mechanical")))
runc <- function(ma) management_targets(ma, 1985L, 2023L, 2030L, land, lev, lev_list, lev_col, NA_character_, scv, say, fail, cost_defaults = cd)
c1 <- runc(data.table(ActionId = "Replanting", Amount = 100, Survival = 0.8, SitePreparation = "Pile and burn", Priority = "None (random among eligible cells)"))$costs
check("replanting with pile and burn: planting and site preparation on the planted and failed types, national defaults (an unknown ecodivision), from the projection start",
      nrow(c1) == 4 && setequal(c1$TransitionAttributeTypeId, MG_COST_TYPES[c("Planting", "Prep")]) && all(c1$Timestep == 2024) &&
      all(c1[TransitionAttributeTypeId == MG_COST_TYPES[["Planting"]], Value] == dv("All", "Planting")[["Central"]]) &&
      all(c1[TransitionAttributeTypeId == MG_COST_TYPES[["Prep"]], Value] == dv("All", "Site preparation: Pile and burn")[["Central"]]) && all(grepl(" \\[Type\\]$", c1$TransitionGroupId)))
check("each value is a Beta over its range, sampled once per iteration, sd^2 < (mean - min)(max - mean)",
      all(c1$DistributionType == "Beta") && all(c1$DistributionFrequencyId == "Iteration Only") &&
      all(c1[TransitionAttributeTypeId == MG_COST_TYPES[["Planting"]], DistributionMin == 600 & DistributionMax == 3000]) &&
      all(c1$DistributionSD^2 < (c1$Value - c1$DistributionMin) * (c1$DistributionMax - c1$Value)))
c2 <- runc(data.table(ActionId = "Replanting", Amount = 10, Cost = 500, SitePreparation = "None"))$costs
check("a row's own cost wins, with the default range scaled to it; no site preparation, no site preparation cost",
      nrow(c2) == 2 && all(c2$Value == 500) && all(c2$TransitionAttributeTypeId == MG_COST_TYPES[["Planting"]]) && all(abs(c2$DistributionMin - 250) < 1e-6 & abs(c2$DistributionMax - 1250) < 1e-6))
c2f <- runc(data.table(ActionId = "Replanting", Amount = 10, Cost = 500, SitePreparation = "None", CostRange = "Fixed values"))$costs
check("CostRange Fixed: the value alone, no distribution", nrow(c2f) == 2 && !"DistributionType" %in% names(c2f))
r3c <- runc(data.table(ActionId = "Salvage logging", Amount = 30, TertiaryStratumId = "B"))
sv <- r3c$costs[TransitionAttributeTypeId == MG_COST_TYPES[["Salvage"]]]; rv <- r3c$costs[TransitionAttributeTypeId == MG_COST_TYPES[["Revenue"]]][order(AgeMin)]
check("salvage: the logging cost (one row) and the timber revenue by age 0-2, falling 25% a year, in the row's unit",
      nrow(sv) == 1 && sv$Value == dv("All", "Salvage logging")[["Central"]] && is.na(sv$AgeMin) && nrow(rv) == 3 && identical(as.numeric(rv$AgeMin), c(0, 1, 2)) &&
      all(abs(rv$Value - dv("All", "Salvage timber revenue")[["Central"]] * 0.75^(0:2)) < 1e-6) && all(r3c$costs$TertiaryStratumId == "B"))
check("summary: cost per area, and revenue per area at the window's start", all(r3c$summary$CostPerArea == dv("All", "Salvage logging")[["Central"]]) &&
      all(r3c$summary$RevenuePerArea == dv("All", "Salvage timber revenue")[["Central"]]))
check("two overlapping rows for the same type and place at different costs stop", inherits(try(runc(data.table(ActionId = "Salvage logging", Amount = 5, Cost = c(100, 200))), silent = TRUE), "try-error"))
check("the same rows at the same cost are fine", !inherits(try(runc(data.table(ActionId = "Salvage logging", Amount = 5, Cost = c(100, 100))), silent = TRUE), "try-error"))
check("without cost defaults no costs", is.null(r1$costs))
# two cost regions in the study area: values per ecodivision, each its region's default
rr <- management_rows(data.table(ActionId = "Replanting", Amount = 10, SitePreparation = "Mechanical"), 2023L, 2030L, say, fail)
m2 <- management_costs(rr, cd, c("Mediterranean", "Marine"), fail)$values
check("two regions: per ecodivision (California, Pacific Northwest; mechanical in the PNW falls back to national)",
      setequal(m2$StratumId, c("Mediterranean", "Marine")) &&
      all(m2[StratumId == "Mediterranean" & TransitionAttributeTypeId == MG_COST_TYPES[["Planting"]], Value] == dv("California", "Planting")[["Central"]]) &&
      all(m2[StratumId == "Marine" & TransitionAttributeTypeId == MG_COST_TYPES[["Prep"]], Value] == dv("All", "Site preparation: Mechanical")[["Central"]]))
m1 <- management_costs(rr, cd, c("Mediterranean", "Mediterranean Mountains"), fail)$values
check("one region: no ecodivision keys, that region's values", !"StratumId" %in% names(m1) && all(m1[TransitionAttributeTypeId == MG_COST_TYPES[["Planting"]], Value] == dv("California", "Planting")[["Central"]]))

# budget mode: an area from a budget at the central cost per area
rb <- runc(data.table(ActionId = "Replanting", Budget = 330000, Survival = 0.8, SitePreparation = "Pile and burn"))
pc <- dv("All", "Planting")[["Central"]] + dv("All", "Site preparation: Pile and burn")[["Central"]]
check("budget: area = budget / (planting + site preparation), split by survival", abs(sum(rb$targets[Timestep == 2024, Amount]) - 330000 / pc) < 1e-6 &&
      abs(rb$targets[Timestep == 2024 & grepl("failed", TransitionGroupId), sum(Amount)] - 0.2 * 330000 / pc) < 1e-6 && all(grepl("budget", rb$summary$Note)))
sb <- runc(data.table(ActionId = "Salvage logging", Budget = 51000))
check("budget, salvage: area = budget / logging cost", abs(sum(sb$targets[Timestep == 2024, Amount]) - 51000 / dv("All", "Salvage logging")[["Central"]]) < 1e-6)
check("an area and a budget on one row stop", inherits(try(runc(data.table(ActionId = "Salvage logging", Amount = 5, Budget = 1000)), silent = TRUE), "try-error"))
check("a budget without cost defaults stops", inherits(try(run(data.table(ActionId = "Salvage logging", Budget = 1000)), silent = TRUE), "try-error"))

cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
