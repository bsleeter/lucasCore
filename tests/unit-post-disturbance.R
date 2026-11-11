# Unit test: the post-disturbance state classes (to-do 57; tools/make_post_disturbance.R). Every forest type group, wetland twin and
# the five shrub classes have a disturbed class that high-severity fire leads to; from it a cell returns to its type within the window
# or converts at its end or at a reburn, and the proportions of each choice add up.
# Usage: Rscript tests/unit-post-disturbance.R   (from the package folder)
suppressPackageStartupMessages(library(data.table))
D <- function(...) file.path("defaults", ...)
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
rd <- function(f) fread(f, colClasses = "character", na.strings = "")
num <- function(x) as.numeric(ifelse(is.na(x), NA, x))
SHRUBS <- c("Shrubland: Sage", "Shrubland: Native Sage Steppe", "Shrubland: Invaded Sage Steppe", "Shrubland: Non-sage", "Shrubland: Chaparral")
sc <- rd(D("stsim", "stsim_StateClass.csv")); id <- as.integer(sc$Id)
par <- sc[(id >= 100 & id <= 999) | Name %in% SHRUBS]; dis <- sc[startsWith(Name, "Disturbed: ")]
check("36 disturbed classes: 31 forest (type groups and wetland twins), 5 shrub", nrow(par) == 36 && nrow(dis) == 36)
par[, did := as.character(2000L + as.integer(Id))]; par[, dname := dis$Name[match(did, dis$Id)]]
check("each parent has its disturbed class at Id 2000 + its Id, with a unique name", !anyNA(par$dname) && !anyDuplicated(dis$Name) && !anyDuplicated(sc$Id))
check("disturbed classes are labelled Disturbed, with existing Y labels", all(dis$StateLabelXId == "Disturbed") && "Disturbed" %in% rd(D("stsim", "stsim_StateLabelX.csv"))$Name &&
      all(dis$StateLabelYId %in% rd(D("stsim", "stsim_StateLabelY.csv"))$Name))
check("no disturbed class counts as forest (stages 5 and 8 test 100-999; is_forest_class is by name)", all(as.integer(dis$Id) > 999) && !any(grepl("^(Forest: |Wetland: .+ Group$)", dis$Name)))
ty <- rd(D("stsim", "stsim_TransitionType.csv")); tg <- rd(D("stsim", "stsim_TransitionTypeGroup.csv"))
RT <- c(Forest = "Post-disturbance: Forest Return", Shrub = "Post-disturbance: Shrub Return"); CV <- "Post-disturbance: Conversion"
check("the return and conversion types exist, each in its own group and in Post-disturbance", all(c(RT, CV) %in% ty$Name) && !anyDuplicated(ty$Id) &&
      all(vapply(c(RT, CV), function(t) setequal(tg[TransitionTypeId == t, TransitionGroupId], c(t, "Post-disturbance")), TRUE)))
fire <- rd(D("transitions", "pathways", "fire.csv")); pd <- rd(D("transitions", "pathways", "post-disturbance.csv"))
hi <- fire[TransitionTypeId == "Fire: High Severity"]
check("high-severity fire on every parent leads to its disturbed class (age reset), and none stays in the parent",
      all(vapply(seq_len(nrow(par)), function(i) { x <- hi[StateClassIdSource == par$Name[i]]; nrow(x) == 1 && x$StateClassIdDest == par$dname[i] && x$AgeReset == "Yes" }, TRUE)))
st <- fread(D("transitions", "post-disturbance-settings.csv")); par[, set := fifelse(as.integer(Id) >= 100, "Forest", Name)]; par <- merge(par, st, by.x = "set", by.y = "ParentClass")
ret <- pd[TransitionTypeId %in% RT]
check("each disturbed class can return to its parent at any age in its window (probability 1: the chance is a multiplier), age kept, by its kind's type",
      all(vapply(seq_len(nrow(par)), function(i) { p <- par[i]; x <- ret[StateClassIdSource == p$dname]
        nrow(x) == 1 && x$StateClassIdDest == p$Name && is.na(x$AgeMin) && num(x$AgeMax) == p$Window - 1 && x$AgeReset == "No" &&
          x$TransitionTypeId == RT[[if (as.integer(p$Id) >= 100) "Forest" else "Shrub"]] && num(x$Probability) == 1 }, TRUE)))
so <- rd(D("transitions", "sources.csv"))
check("stage 6 sources: return on NLCD two years running (forest incl. woody wetland, shrub), conversion on everywhere",
      so[TransitionGroupId == paste(RT[["Forest"]], "[Type]"), Source == "NlcdPersist" & Classes == "41|42|43|90"] && so[TransitionGroupId == paste(RT[["Shrub"]], "[Type]"), Source == "NlcdPersist" & Classes == "52"] &&
      so[TransitionGroupId == paste(CV, "[Type]"), Source == "All"])
eco <- rd(D("strata", "ecodivisions-list.csv"))$Name
# proportions of one choice add up in every ecodivision (rows with a blank stratum apply in all of them)
adds_up <- function(x) all(vapply(eco, function(e) { y <- x[is.na(StratumIdSource) | StratumIdSource == e]; nrow(y) > 0 && abs(sum(num(ifelse(is.na(y$Proportion), "1", y$Proportion))) - 1) < 1e-6 }, TRUE))
cv <- pd[TransitionTypeId == CV]
check("conversion at the window's end: proportions add to 1 in every ecodivision, to existing classes",
      all(vapply(seq_len(nrow(par)), function(i) { x <- cv[StateClassIdSource == par$dname[i]]; adds_up(x) && all(num(x$AgeMin) == par$Window[i]) }, TRUE)) && all(cv$StateClassIdDest %in% sc$Name))
check("disturbed forest converts to its ecodivision's shrub or grass class; sage, sage steppe and chaparral to annual grass",
      all(cv[startsWith(StateClassIdSource, "Disturbed: ") & StateClassIdSource %in% par[as.integer(Id) >= 100, dname], StateClassIdDest] %in%
            unlist(fread(D("transitions", "post-disturbance-regions.csv"))[, .(ShrubClass, GrassClass)])) &&
      all(cv[StateClassIdSource %in% par[Name %in% SHRUBS[c(1:3, 5)], dname], StateClassIdDest] == "Grassland: Annual"))
check("a high-severity reburn: proportions add to 1 in every ecodivision; the share staying is 1 - ReburnConversion, age reset",
      all(vapply(seq_len(nrow(par)), function(i) { x <- hi[StateClassIdSource == par$dname[i]]; s <- x[StateClassIdDest == par$dname[i]]
        adds_up(x) && all(x$AgeReset == "Yes") && all(abs(num(s$Proportion) - (1 - par$ReburnConversion[i])) < 1e-6) }, TRUE)))
check("medium and low severity keep a disturbed class and its age",
      all(vapply(par$dname, function(d) { x <- fire[StateClassIdSource == d & TransitionTypeId %in% c("Fire: Medium Severity", "Fire: Low Severity")]
        nrow(x) == 2 && all(x$StateClassIdDest == d) && all(x$AgeReset == "No") }, TRUE)))
for (f in c("urbanization.csv", "ag-expansion.csv")) { x <- rd(D("transitions", "pathways", f))
  check(sprintf("%s: each disturbed class has its parent's rows", f), all(vapply(seq_len(nrow(par)), function(i) {
    a <- x[StateClassIdSource == par$Name[i], paste(StateClassIdDest, TransitionTypeId)]; b <- x[StateClassIdSource == par$dname[i], paste(StateClassIdDest, TransitionTypeId)]
    length(a) > 0 && setequal(a, b) }, TRUE))) }
loc <- rd(D("transitions", "state-locations.csv"))
check("each disturbed class has a diagram cell; cells are unique", all(dis$Name %in% loc$StateClassIdSource) && !anyDuplicated(loc$Location))
check("each disturbed class has a CO2 class row", all(dis$Name %in% rd(D("climate", "co2-classes.csv"))$StateClassId))
check("no pathway leads into a disturbed class except fire", all(c(pd$StateClassIdDest, unlist(lapply(c("urbanization.csv", "ag-expansion.csv", "ag-contraction.csv", "harvest.csv", "ag-change.csv", "intensification.csv"),
      function(f) rd(D("transitions", "pathways", f))$StateClassIdDest))) %in% setdiff(sc$Name, dis$Name) | is.na(c(pd$StateClassIdDest, unlist(lapply(c("urbanization.csv", "ag-expansion.csv", "ag-contraction.csv", "harvest.csv", "ag-change.csv", "intensification.csv"),
      function(f) rd(D("transitions", "pathways", f))$StateClassIdDest))))))
pa <- fread(D("projection", "post-disturbance-adjacency.csv"))
check("return adjacency: Live Forest, a defined attribute type, multipliers rise with the share from above 0 to 1, weights for the mean",
      all(pa$StateAttributeTypeId == "Live Forest") && "Live Forest" %in% rd(D("stsim", "stsim_StateAttributeType.csv"))$Name && !is.unsorted(pa$AttributeValue) &&
      !is.unsorted(pa$Amount) && min(pa$Amount) > 0 && max(pa$Amount) == 1 && sum(pa$Weight) > 0 && all(pa$TransitionGroupId %in% paste(RT, "[Type]")))
fc <- rd(D("projection", "fire-class-multipliers.csv"))
check("fire by state class: names a disturbed kind or a class, in a known ecodivision, multiplier at least 1",
      all(fc$StateClassId %in% c("Disturbed: forest", "Disturbed: shrub", sc$Name)) && all(is.na(fc$StratumId) | fc$StratumId %in% eco) && all(num(fc$Multiplier) >= 1))
up <- grep("\\[Update\\(", readLines(file.path("ui", "LucasCoreUpdates.cs")), value = TRUE)
check("library update 1.4 exists, and no update description holds an apostrophe (SyncroSim writes it unquoted: the 1.3.0 failure)",
      any(grepl("\\[Update\\(1\\.4,", up)) && !any(grepl("'", up)))
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
