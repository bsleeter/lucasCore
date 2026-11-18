# Unit test: src/reforestation.R, forest potential from LANDFIRE BpS (to-do 57: the reforestation transition), and the BpsFile
# Data Source's rows (package.xml, data-sources.csv, endpoints.csv, citations.csv, the download handler).
# Usage: Rscript tests/unit-reforestation.R   (from the package folder)
suppressPackageStartupMessages(library(data.table))
read_default <- function(...) fread(file.path("defaults", ...), encoding = "UTF-8")
source(file.path("src", "reforestation.R"))
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
tab <- read_default("landcover", "LF20_BPS_220.csv"); grp <- read_default("landcover", "bps-groups.csv"); lk <- bps_lookup(tab, grp)
check("the BpS table has every LF2020 value once", nrow(tab) == 2189 && !anyDuplicated(tab$VALUE))
check("every GROUPVEG in the table has a row in bps-groups.csv", all(setdiff(unique(tab$GROUPVEG), c(NA, "")) %in% grp$GROUPVEG))
check("every potential is a known one", all(lk$Potential %in% BPS_POTENTIAL))
v <- function(g) tab[GROUPVEG == g, VALUE][1]
p <- bps_potential(c(v("Conifer"), v("Hardwood-Conifer"), v("Peatland Forest"), v("Shrubland"), v("Grassland"), v("Sparse"), v("Riparian"), v("Savanna"), v("Open Water"), -9999L, 99999L, NA), lk)
check("forest groups read as forest", all(p[1:3] == "forest"))
check("shrub, grass and sparse read as non-forest", all(p[4:6] == "non-forest"))
check("riparian and savanna read as forest by default", all(p[7:8] == "forest"))
check("water, fill, unknown values and NA read as other", all(p[9:12] == "other"))
check("riparian and savanna read as non-forest when set", all(bps_potential(c(v("Riparian"), v("Savanna")), lk, "non-forest") == "non-forest"))
check("a bad riparian setting stops", inherits(try(bps_potential(1L, lk, "maybe"), silent = TRUE), "try-error"))
check("Hawaii types with no GROUPVEG read as other", all(bps_potential(tab[is.na(GROUPVEG) | GROUPVEG == "", VALUE], lk) == "other"))
g2 <- rbind(grp, data.table(GROUPVEG = "Conifer", Potential = "forest", Note = ""), fill = TRUE)   # (bps-groups.csv gained NonForestCover for the carbon capacity)
check("a GROUPVEG listed twice stops", inherits(try(bps_lookup(tab, g2), silent = TRUE), "try-error"))
g3 <- copy(grp)[GROUPVEG == "Sparse", Potential := "sparse"]
check("an unknown potential stops", inherits(try(bps_lookup(tab, g3), silent = TRUE), "try-error"))
# the Data Source is wired everywhere a LANDFIRE layer is
x <- readLines("package.xml"); check("package.xml has the BpsFile column", any(grepl('<column name="BpsFile"', x, fixed = TRUE)))
check("data-sources.csv has a BpsFile row with a home place", fread(file.path("defaults", "library", "data-sources.csv"))[Column == "BpsFile", nzchar(HomePath)])
ep <- fread(file.path("defaults", "download", "endpoints.csv"))[Column == "BpsFile"]
check("endpoints.csv has a BpsFile row for the LFPS layer LF2020_BPS", nrow(ep) == 1 && ep$Product == "LF2020_BPS" && ep$Method == "lfps")
check("citations.csv has a BpsFile citation", nrow(fread(file.path("defaults", "metadata", "citations.csv"))[Column == "BpsFile"]) == 1)
check("the download handler fetches LF2020_BPS", any(grepl('H$BpsFile <- lf_single("BpsFile"', readLines(file.path("src", "download-sources.R")), fixed = TRUE)))
# the reforestation cutoff (step 2)
ct <- read_default("landcover", "reforestation-cutoff.csv")
check("the cutoff table has a blank (CONUS) row and every ecodivision once", sum(is.na(ct$Ecodivision) | ct$Ecodivision == "") == 1 && !anyDuplicated(ct$Ecodivision) && nrow(ct) == 20)
check("every cutoff is 1 to 29 years (the fit's follow-up)", all(ct$Years >= 1 & ct$Years <= 29))
cv <- reforest_cutoff(c("Subtropical", "Mediterranean Mountains", "Nowhere"), ct)
check("an ecodivision takes its own cutoff, an unknown one the blank row's", cv[1] == ct[Ecodivision == "Subtropical", Years] && cv[2] == ct[Ecodivision == "Mediterranean Mountains", Years] && cv[3] == ct[is.na(Ecodivision) | Ecodivision == "", Years])
check("a number overrides the table everywhere", all(reforest_cutoff(c("Subtropical", "Marine"), ct, 15) == 15))
check("a blank override keeps the table", identical(reforest_cutoff("Marine", ct, NA), as.numeric(ct[Ecodivision == "Marine", Years])))
check("an override out of range stops", inherits(try(reforest_cutoff("Marine", ct, 0), silent = TRUE), "try-error"))
check("no row and no blank row stops", inherits(try(reforest_cutoff("Nowhere", ct[!is.na(Ecodivision) & Ecodivision != ""]), silent = TRUE), "try-error"))
# Reforestation Options (step 3)
o <- reforest_options(data.table())
check("no row: on, the fitted cutoff, riparian as forest", o$enabled && is.na(o$cutoff) && o$riparian_as == "forest")
o <- reforest_options(data.table(Enabled = FALSE, CutoffYears = 15L, RiparianAs = 2L))
check("a filled row: off, 15 years, riparian as non-forest", !o$enabled && o$cutoff == 15 && o$riparian_as == "non-forest")
check("blank cells read as the defaults", reforest_options(data.table(Enabled = NA, CutoffYears = NA_integer_, RiparianAs = NA_integer_))$enabled)
check("a bad riparian code stops", inherits(try(reforest_options(data.table(RiparianAs = 3L)), silent = TRUE), "try-error"))
check("package.xml declares the sheet as a stage 5 input", { x <- paste(readLines("package.xml"), collapse = "\n")
  grepl('<dataSheet name="ReforestationOptions"', x, fixed = TRUE) && grepl('programArguments="src/5-initial-conditions.R">[[:space:]]*<dataSheet name="BuildOptions" type="Input"/>[[:space:]]*<dataSheet name="ReforestationOptions" type="Input"/>', x) })
check("the list label from rsyncrosim reads too", reforest_options(data.table(RiparianAs = "Non-forest potential"))$riparian_as == "non-forest" && reforest_options(data.table(RiparianAs = "Forest potential"))$riparian_as == "forest")
# which cells reforest (step 4)
yr <- 1985:2015; S5 <- 52L; F4 <- 42L; at <- function(k) c(rep(S5, k), rep(F4, length(yr) - k))   # first forest k years after the start
flk <- c(S5, S5, F4, F4, rep(c(S5, S5, S5, F4), 6), S5, S5, S5)[seq_along(yr)]                    # forest two years running once, then mostly not
nl <- rbind(at(8), at(25), at(8), at(25), flk, rep(S5, length(yr)), at(25))
pk <- reforest_pick(nl, yr, c("forest", "forest", "non-forest", "non-forest", "non-forest", "non-forest", "other"), c(24, 24, 24, 24, 24, 24, 24))
check("BpS forest: forest after 8 years (before the cutoff) is regrowth, after 25 reforests", !pk$reforest[1] && pk$reforest[2])
check("BpS non-forest reforests at any timing", pk$reforest[3] && pk$reforest[4])
check("a cell that flickers keeps the forest start", !pk$reforest[5] && !pk$persistent[5] && identical(pk$first[5], 2L))
check("a cell never forest two years running is left alone", !pk$reforest[6] && is.na(pk$first[6]))
check("other BpS (water, fill) keeps the forest start", !pk$reforest[7])
check("first forest is counted in years after the start", identical(pk$first[1:2], c(8L, 25L)))
check("a per-cell cutoff applies cell by cell", identical(reforest_pick(nl[c(2, 2), ], yr, "forest", c(24, 26))$reforest, c(TRUE, FALSE)))
check("no cells gives empty results", length(reforest_pick(nl[0, , drop = FALSE], yr, character(), numeric())$reforest) == 0)
# the Reforestation group, types and pathways (step 5; tools/make_reforestation.R)
sc5 <- fread(file.path("defaults", "stsim", "stsim_StateClass.csv")); fo5 <- sc5[Id >= 100 & Id <= 999, Name]
tt5 <- fread(file.path("defaults", "stsim", "stsim_TransitionType.csv")); ttg5 <- fread(file.path("defaults", "stsim", "stsim_TransitionTypeGroup.csv"))
pw5 <- fread(file.path("defaults", "transitions", "pathways", "reforestation.csv"))
check("one Reforestation type per forest class, each in the group Reforestation", sum(startsWith(tt5$Name, "Reforestation: ")) == length(fo5) &&
      setequal(ttg5[TransitionGroupId == "Reforestation", TransitionTypeId], tt5[startsWith(Name, "Reforestation: "), Name]))
check("type ids are unique", !anyDuplicated(tt5$Id))
check("every natural non-forest source class reaches every forest class, once", nrow(pw5) == 10 * length(fo5) && !anyDuplicated(pw5[, .(StateClassIdSource, StateClassIdDest)]) &&
      all(pw5[, uniqueN(StateClassIdDest), by = StateClassIdSource]$V1 == length(fo5)))
check("no disturbed, estuarine or forest class is a source", !any(grepl("^Disturbed|Estuarine|^Forest", pw5$StateClassIdSource)) && all(pw5$StateClassIdSource %in% sc5$Name))
check("each pathway's type names its destination, probability 1, age reset", all(pw5$TransitionTypeId %in% tt5$Name) && all(pw5$Probability == 1) && all(pw5$AgeReset == "Yes") &&
      all(mapply(function(t, d) { y <- sc5[Name == d]; sub("^Reforestation: ", "", t) == if (y$StateLabelXId == "Wetland") paste("Wetland", y$StateLabelYId) else y$StateLabelYId }, pw5$TransitionTypeId, pw5$StateClassIdDest)))
check("Reforestation is a main (spatial) group for stock-flow and a transition simulation group (ST-Sim maps only those and [Type] groups)", "Reforestation" %in% fread(file.path("defaults", "stockflow", "main-transition-groups.csv"))$TransitionGroupId && "Reforestation" %in% fread(file.path("defaults", "stsim", "stsim_TransitionSimulationGroup.csv"), sep = ",")$TransitionGroupId)
check("the 1.4 library update adds the group, the types and the new columns", { u <- paste(readLines(file.path("ui", "LucasCoreUpdates.cs")), collapse = "\n")
  all(vapply(c('"Reforestation: " + y', '"lucasCore_DataSource", "BpsFile"', '"ReforestTypeFileName"', '"BpsForestShareFileName"'), grepl, TRUE, u, fixed = TRUE)) })
check("stage 6 reads Reforestation from NLCD (NlcdPersist on 41-43, not woody wetland) and takes the stage 5 maps and Reforestation Options", fread(file.path("defaults", "transitions", "sources.csv"))[TransitionGroupId == "Reforestation", Source == "NlcdPersist" && Classes == "41|42|43"] && grepl('programArguments="src/6-historical-transitions.R">[^<]*(<dataSheet [^>]*>[^<]*)*<dataSheet name="ReforestationOptions" type="Input"/>[^<]*<dataSheet name="OutputLandCoverLayers" type="Input"/>', paste(readLines("package.xml"), collapse = " ")))
# the projection (step 8)
check("Recent Years: blank is 10, a number is kept, 0 stops", reforest_options(data.table())$recent_years == 10L && reforest_options(data.table(RecentYears = 5L))$recent_years == 5L &&
      inherits(try(reforest_options(data.table(RecentYears = 0L)), silent = TRUE), "try-error"))
pt8 <- fread(file.path("defaults", "projection", "transitions.csv"))[TransitionGroupId == "Reforestation"]
check("projection: Reforestation is a Target group in its own sampling set", nrow(pt8) == 1 && pt8$Method == "Target" && pt8$SamplingSet == "Reforestation")
al8 <- fread(file.path("defaults", "projection", "allocation.csv"))[TransitionGroupId == "Reforestation"]
check("projection: a fitted Reforestation surface from barren, shrub, grass and emergent wetland, events by the stage 5 rule", nrow(al8) == 1 && al8$Method == "Fitted" && al8$SourceClasses == "31|52|71|95" && al8$EventClasses == "Reforestation")
cv8 <- fread(file.path("defaults", "projection", "covariates.csv"))[Surface == "Reforestation" & Include == "Yes", Covariate]
check("projection: the Reforestation surface has forest potential, distance to forest and forest share", setequal(cv8, c("Forest potential (BpS)", "Distance to forest", "Forest share within 1 km")) &&
      all(vapply(cv8, function(k) grepl(sprintf("`%s` = ", k), paste(readLines(file.path("src", "10-transition-suitability.R")), collapse = "\n"), fixed = TRUE), TRUE)))
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
