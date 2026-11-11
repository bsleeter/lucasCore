# Unit test: src/disturbed-carbon.R, the carbon flows stage 3 derives for the post-disturbance classes (to-do 57), on made-up tables.
# Usage: Rscript tests/unit-disturbed-carbon.R   (from the package folder)
suppressPackageStartupMessages(library(data.table))
source(file.path("src", "flows.R")); source(file.path("src", "disturbed-carbon.R"))
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
scl <- data.table(Name = c("Forest: Mixed Group", "Forest: Other Group", "Shrubland: Non-sage", "Shrubland: Chaparral", "Shrubland: Sage",
                           "Disturbed: Mixed Group", "Disturbed: Other Group", "Disturbed: Sage"), Id = c("370", "380", "54", "55", "53", "2370", "2380", "2053"))
rg <- data.table(Ecodivision = c("E1", "E2"), ShrubClass = c("Shrubland: Non-sage", "Shrubland: Chaparral"), GrassClass = "Grassland: Annual")
pw <- function(cls, eco) data.table(FromStratumId = eco, FromStateClassId = cls,
  FromStockTypeId = c("Atmosphere", "Biomass: Foliage", "DOM: Aboveground Fast"), ToStockTypeId = c("Biomass: Foliage", "DOM: Aboveground Very Fast", "Atmosphere"),
  FlowTypeId = c("Net Growth Non Forest: Atmosphere -> Foliage", "Biomass Turnover: Foliage -> AG Very Fast", "Emission: AG Fast -> Atmosphere"), Multiplier = "1")
nfp <- rbindlist(lapply(c("Shrubland: Non-sage", "Shrubland: Chaparral", "Shrubland: Sage"), function(k) rbindlist(lapply(c("E1", "E2", "E3"), function(e) pw(k, e)))))
gm <- function(cls, eco, v) data.table(StratumId = eco, StateClassId = cls, AgeMin = c("0", NA, NA),
  FlowGroupId = c("Net Growth Non Forest: Atmosphere -> Foliage [Type]", "Biomass Turnover: Foliage -> AG Very Fast [Type]", "Emission: AG Fast -> Atmosphere [Type]"), Value = as.character(v))
gs_m <- rbind(gm("Shrubland: Non-sage", "E1", c(1, 0.5, 0.1)), gm("Shrubland: Chaparral", "E2", c(1, 0.3, 0.2)), gm("Shrubland: Non-sage", "E2", c(1, 0.6, 0.15)),
              gm("Shrubland: Sage", "E1", c(1, 0.2, 0.05)), gm("Shrubland: Sage", "E3", c(1, 0.25, 0.06)))
nf_g <- data.table(StratumId = c("E1", "E2", "E1"), StateClassId = c("Shrubland: Non-sage", "Shrubland: Chaparral", "Shrubland: Sage"), StateAttributeTypeId = "Net Growth", Value = c("2", "3", "1"))
fm_d <- data.table(StratumId = c("E1", "E1", "E1", "E2", "E2"), StateClassId = "Forest: Mixed Group", AgeMin = NA_integer_, AgeMax = NA_integer_,
                   FlowGroupId = c("Biomass Turnover: Foliage -> AG Very Fast [Type]", "Emission: AG Fast -> Atmosphere [Type]", "Stabilization: BG Slow -> Deep Soil [Type]",
                                   "Biomass Turnover: Foliage -> AG Very Fast [Type]", "Emission: AG Fast -> Atmosphere [Type]"), Value = c(0.9, 0.04, 0.001, 0.8, 0.03))
ev <- data.table(FromStratumId = NA_character_, FromStateClassId = c(NA, "Shrubland: Sage", "Forest: Mixed Group"), FromStockTypeId = "Biomass: Foliage", ToStockTypeId = "Atmosphere",
                 TransitionGroupId = "Fire: High Severity [Type]", Multiplier = c("0.9", "0.95", "0.8"))
dc <- disturbed_classes(scl)
check("disturbed classes and their parents by Id (2000 + the parent's)", nrow(dc) == 3 && setequal(dc[kind == "Forest", parent], c("Forest: Mixed Group", "Forest: Other Group")) &&
      dc[D == "Disturbed: Sage", parent] == "Shrubland: Sage" && dc[D == "Disturbed: Sage", kind] == "Shrub")
r <- disturbed_carbon(dc, rg, c("E1", "E2"), nfp, gs_m, nf_g, fm_d, FOREST_PATHWAYS, burial = character(), ev = ev)
check("a disturbed forest class only where its forest type has rates", identical(r$forest, "Disturbed: Mixed Group"))
fpD <- r$fp[FromStateClassId == "Disturbed: Mixed Group"]
check("disturbed forest pathways: live growth and turnover from the ecodivision's shrub class, in the study area only",
      setequal(fpD[!startsWith(FromStockTypeId, "DOM: "), unique(FromStratumId)], c("E1", "E2")) && !any(fpD$FromStratumId %in% "E3"))
check("disturbed forest pathways: dead wood from the forest pathways (no stratum), not from the shrub class; no burial without it",
      all(is.na(fpD[startsWith(FromStockTypeId, "DOM: "), FromStratumId])) && fpD[startsWith(FromStockTypeId, "DOM: "), .N] == FOREST_PATHWAYS[startsWith(From, "DOM: ") & FlowType != "Stabilization: BG Slow -> Deep Soil", .N])
fmD <- r$fm[StateClassId == "Disturbed: Mixed Group"]
check("live rates as the ecodivision's shrub class: Non-sage in E1, Chaparral in E2",
      fmD[StratumId == "E1" & grepl("^Biomass Turnover", FlowGroupId), as.numeric(Value)] == 0.5 && fmD[StratumId == "E2" & grepl("^Biomass Turnover", FlowGroupId), as.numeric(Value)] == 0.3)
check("dead wood rates as its forest type's (burial too where the type has it), never the shrub's",
      fmD[StratumId == "E1" & grepl("^Emission", FlowGroupId), as.numeric(Value)] == 0.04 && fmD[StratumId == "E2" & grepl("^Emission", FlowGroupId), as.numeric(Value)] == 0.03 &&
      fmD[grepl("^Stabilization", FlowGroupId), .N] == 1)
check("one rate per ecodivision, flow group and age (no duplicate rows for ST-Sim)", !anyDuplicated(r$fm[, .(StratumId, StateClassId, FlowGroupId, AgeMin)]))
fmS <- r$fm[StateClassId == "Disturbed: Sage"]
check("a disturbed shrub class takes its parent's rows, in the study area", nrow(fmS) == 3 && all(fmS$StratumId == "E1") && fmS[grepl("^Biomass Turnover", FlowGroupId), Value] == "0.2")
check("net growth: the shrub source's", r$sav[StateClassId == "Disturbed: Mixed Group" & StratumId == "E1", Value] == "2" && r$sav[StateClassId == "Disturbed: Mixed Group" & StratumId == "E2", Value] == "3" &&
      r$sav[StateClassId == "Disturbed: Sage", Value] == "1")
check("fire: a disturbed shrub class takes its parent's class rows; disturbed forest none (the all-class rows apply)",
      nrow(r$ev) == 1 && r$ev$FromStateClassId == "Disturbed: Sage" && r$ev$Multiplier == "0.95")
b <- disturbed_carbon(dc, rg, NULL, nfp, gs_m, nf_g, fm_d, FOREST_PATHWAYS, burial = "Forest: Mixed Group")
check("burial for a disturbed class whose forest type has it", b$fp[FromStateClassId == "Disturbed: Mixed Group" & FlowTypeId == "Stabilization: BG Slow -> Deep Soil", .N] == 1)
check("no disturbed classes: empty results", nrow(disturbed_carbon(dc[0], rg, NULL, nfp, gs_m, nf_g, fm_d, FOREST_PATHWAYS)$fm) == 0)
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
