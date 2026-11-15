# Unit test: post-fire rangeland restoration (mitigation measure 5; tools/make_rangeland_restoration.R, src/management.R). Seeding,
# sagebrush planting, and herbicide and seeding act on the burned sage family (herbicide and seeding also on annual grass in the
# steppe ecodivisions), a success goes to Native Sage Steppe at age 0 and a failure stays; the Management Actions rows become targets
# split by the success share, spread over the action's own land, with its window and its regional cost.
# Usage: Rscript tests/unit-rangeland-restoration.R   (from the package folder)
suppressPackageStartupMessages(library(data.table))
D <- function(...) file.path("defaults", ...)
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
rd <- function(f) fread(f, colClasses = "character", na.strings = "")
source(file.path("src", "management.R"))

# ---- defaults ----------------------------------------------------------------------------------------------------------------
RT <- c(MG_RESTORE$Type, paste(MG_RESTORE$Type, "(failed)"))
ty <- rd(D("stsim", "stsim_TransitionType.csv")); tg <- rd(D("stsim", "stsim_TransitionTypeGroup.csv")); sc <- rd(D("stsim", "stsim_StateClass.csv"))
check("eight restoration types, Ids 1310-1317, unique Ids", all(RT %in% ty$Name) && setequal(as.integer(ty$Id[match(RT, ty$Name)]), 1310:1317) && !anyDuplicated(ty$Id))
check("all eight in Management: Rangeland Restoration", setequal(tg[TransitionGroupId == "Management: Rangeland Restoration", TransitionTypeId], RT))
check("the sage class Ids are the burned sage family", setequal(sc[as.integer(Id) %in% MG_RESTORE_SAGE, Name], c("Disturbed: Sage", "Disturbed: Native Sage Steppe", "Disturbed: Invaded Sage Steppe")))
pw <- rd(D("transitions", "pathways", "rangeland-restoration.csv"))
ok <- pw[!grepl("failed", TransitionTypeId)]; fl <- pw[grepl("failed", TransitionTypeId)]
check("a success goes to Native Sage Steppe at age 0", all(ok$StateClassIdDest == "Shrubland: Native Sage Steppe") && all(ok$AgeReset == "Yes"))
check("a failure stays in its class with its age", all(fl$StateClassIdDest == fl$StateClassIdSource) && all(fl$AgeReset == "No"))
check("seeding and planting from the burned sage family only", setequal(unique(pw[!grepl("Herbicide", TransitionTypeId), StateClassIdSource]), sc[as.integer(Id) %in% MG_RESTORE_SAGE, Name]))
hb <- pw[grepl("Herbicide", TransitionTypeId)]
check("herbicide and seeding: burned invaded steppe and annual grass, no stratum (stage 6 needs the same pathways in every ecodivision)",
      setequal(unique(hb$StateClassIdSource), c("Disturbed: Invaded Sage Steppe", "Grassland: Annual")) && all(is.na(hb$StratumIdSource)))
check("every restoration pathway has no stratum", all(is.na(pw$StratumIdSource)))
check("every pathway's type, classes and strata exist", all(pw$TransitionTypeId %in% ty$Name) && all(c(pw$StateClassIdSource, pw$StateClassIdDest) %in% sc$Name) &&
      all(na.omit(pw$StratumIdSource) %in% rd(D("stsim", "stsim_Stratum.csv"))$Name))
mg <- rd(D("stockflow", "main-transition-groups.csv"))
check("the restoration [Type] groups and family are mapped", all(c(paste0(RT, " [Type]"), "Management: Rangeland Restoration") %in% mg$TransitionGroupId))
de <- rd(D("metadata", "definitions.csv")); check("every restoration type and the group are defined", all(c(RT, "Management: Rangeland Restoration") %in% de$Name))
at <- rd(D("stsim", "stsim_TransitionAttributeType.csv")); check("the restoration cost attribute type exists", MG_COST_TYPES[["Restoration"]] %in% at$Name)

# ---- the page as targets -------------------------------------------------------------------------------------------------------
say <- function(...) invisible(NULL); fail <- function(...) stop(sprintf(...), call. = FALSE)
# 6 cells: secondary S1 (1-3), S2 (4-6). Cell 1 Disturbed Sage, 2 Disturbed Native Sage Steppe, 3 forest, 4 Disturbed Invaded Sage
# Steppe, 5 annual grass, 6 Disturbed Sage. Primary: cells 1-4 in Temperate Desert, 5-6 in Mediterranean
land <- rep(TRUE, 6); lev <- list(Primary = c(1L, 1L, 1L, 1L, 2L, 2L), Secondary = c(1L, 1L, 1L, 2L, 2L, 2L), Tertiary = rep(1L, 6))
lev_list <- list(Primary = data.table(Name = c("Temperate Desert", "Mediterranean"), Id = c("1", "2")), Secondary = data.table(Name = c("S1", "S2"), Id = c("1", "2")),
                 Tertiary = data.table(Name = "A", Id = "1"))
lev_col <- c(Primary = "StratumId", Secondary = "SecondaryStratumId", Tertiary = "TertiaryStratumId")
scv <- c(2053L, 2051L, 200L, 2052L, 71L, 2053L)
cd <- management_cost_defaults(D("management", "costs.csv"))
run <- function(ma) management_targets(ma, 1985L, 2023L, 2030L, land, lev, lev_list, lev_col, NA_character_, scv, say, fail, cost_defaults = cd)
r1 <- run(data.table(ActionId = "Aerial seeding", Amount = 100, SecondaryStratumId = "S1"))
t1 <- r1$targets[Timestep > 2023]
check("aerial seeding: the default success 0.15 established, 0.85 failed, every projection year",
      all(abs(t1[TransitionGroupId == "Management: Aerial Seeding [Type]", sum(Amount), by = Timestep]$V1 - 15) < 1e-9) &&
      all(abs(t1[TransitionGroupId == "Management: Aerial Seeding (failed) [Type]", sum(Amount), by = Timestep]$V1 - 85) < 1e-9) && uniqueN(t1$Timestep) == 7)
check("its window is the default 0-1 years since the fire", all(r1$multipliers[Amount == 1, AgeMin] == 0) && all(r1$multipliers[Amount == 1, AgeMax] == 1))
check("its cost on both types, per ecodivision (two cost regions here): Temperate Desert the national default, Mediterranean California's",
      nrow(r1$costs) == 4 && all(r1$costs$TransitionAttributeTypeId == MG_COST_TYPES[["Restoration"]]) &&
      all(r1$costs[StratumId == "Temperate Desert", Value] == mg_cost_default(cd, "All", "Aerial seeding")[["Central"]]) &&
      all(r1$costs[StratumId == "Mediterranean", Value] == mg_cost_default(cd, "California", "Aerial seeding")[["Central"]]))
# (a zero row naming a secondary unit keys the targets by secondary unit, so the spread shows)
zs <- data.table(ActionId = "Sagebrush planting", Amount = 0, SecondaryStratumId = "S1")
r2 <- run(rbind(data.table(ActionId = "Drill seeding", Amount = 90, Survival = 0.5), zs, fill = TRUE))
a2 <- r2$targets[Timestep == 2024 & TransitionGroupId == "Management: Drill Seeding [Type]"]
check("drill seeding over the study area: spread by the burned sage family (cells 1, 2, 4, 6), a success share set by the row",
      abs(sum(a2$Amount) - 45) < 1e-9 && abs(a2[SecondaryStratumId == "S1", Amount] - 22.5) < 1e-9 && abs(a2[SecondaryStratumId == "S2", Amount] - 22.5) < 1e-9)
r3 <- run(rbind(data.table(ActionId = "Herbicide and seeding", Amount = 60), zs, fill = TRUE))
a3 <- r3$targets[Timestep == 2024 & TransitionGroupId == "Management: Herbicide and Seeding [Type]"]
check("herbicide and seeding: only burned invaded steppe and steppe annual grass count (cell 4 here; cell 5 is Mediterranean grass)",
      abs(sum(a3$Amount) - 18) < 1e-9 && abs(a3[SecondaryStratumId == "S2", Amount] - 18) < 1e-9)
hm <- r3$multipliers[!is.na(StateClassId)]
check("herbicide and seeding: a zero multiplier on annual grass outside the steppe ecodivisions (Mediterranean here), both types",
      nrow(hm) == 2 && all(hm$StratumId == "Mediterranean") && all(hm$StateClassId == "Grassland: Annual") && all(hm$Amount == 0))
check("herbicide and seeding: any years since the disturbance by default", all(r3$multipliers[Amount == 1 & grepl("Herbicide", TransitionGroupId) & is.na(StateClassId), AgeMin] == 0) && all(r3$multipliers[Amount == 1 & grepl("Herbicide", TransitionGroupId) & is.na(StateClassId), AgeMax] >= 999))
r4 <- run(data.table(ActionId = "Sagebrush planting", Budget = 25000))
check("sagebrush planting from a budget: the area it pays for at the central cost (two regions: their mean)",
      abs(sum(r4$targets[Timestep == 2024, Amount]) - 25000 / mean(c(mg_cost_default(cd, "All", "Sagebrush planting")[["Central"]], mg_cost_default(cd, "California", "Sagebrush planting")[["Central"]]))) < 1e-6)
check("the summary names the row's success on both types", nrow(r4$summary) == 2 && all(grepl("success 0.35", r4$summary$Note)))
r5 <- run(rbind(data.table(ActionId = "Replanting", Amount = 10), data.table(ActionId = "Aerial seeding", Amount = 10), fill = TRUE))
check("replanting and seeding together: their own types, replanting on forest land", setequal(r5$groups, c(paste0(c(MG_REPLANT[["None"]], paste(MG_REPLANT[["None"]], "(failed)")), " [Type]"),
      paste0(c("Management: Aerial Seeding", "Management: Aerial Seeding (failed)"), " [Type]"))))
check("a success above 1 stops the setup", inherits(try(run(data.table(ActionId = "Aerial seeding", Amount = 10, Survival = 1.5)), silent = TRUE), "try-error"))
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
