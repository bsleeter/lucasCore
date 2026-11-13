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
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
