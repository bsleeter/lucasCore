# =============================================================================
# make_fuel_treatments.R - the fuel treatment transitions (user 2026-11-13: "Next is Fuel Treatments"; the effect form: "Lets go with
# the severity shift"): mechanical thinning, prescribed burn, and thin and burn on live upland forest
# =============================================================================
# Writes, removing its own earlier rows first (a rerun duplicates nothing) and touching no other row:
#   defaults/stsim/stsim_TransitionType.csv, stsim_TransitionGroup.csv, stsim_TransitionTypeGroup.csv
#     three types (Ids 1300-1302): Fuel Treatment: Mechanical Thinning / Prescribed Burn / Thin and Burn, in group Fuel Treatment
#   defaults/transitions/pathways/fuel-treatments.csv
#     from every upland forest class (Forest: *) to itself, no age reset: a treatment changes neither the forest type nor the stand
#     age. Each type's own time since transition (its [Type] group, stage 9's stsim_TimeSinceTransitionGroup) resets to 0 when it
#     happens (a blank TST Relative), which the severity multipliers and the retreatment interval read. No ages on the pathways and
#     no map: stage 6 gives each a zero target, so nothing is treated unless a projection asks for it
#   defaults/stockflow/event-pathways.csv: the treatments' carbon (FLOWS below, from dev/fuel-treatments/research.md)
#   defaults/metadata/definitions.csv
# Usage: Rscript tools/make_fuel_treatments.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
D <- function(...) file.path(pkg, "defaults", ...)
TYPES <- data.table(Name = c("Fuel Treatment: Mechanical Thinning", "Fuel Treatment: Prescribed Burn", "Fuel Treatment: Thin and Burn"),
                    Id = 1300:1302, Color = c("255,160,82,45", "255,255,140,0", "255,205,92,92"))
GRP <- "Fuel Treatment"
mine <- function(x) grepl("^Fuel Treatment", x)
edit_lines <- function(f, drop, add) { l <- readLines(f, encoding = "UTF-8"); keep <- c(l[1], l[-1][!drop(l[-1])])
  writeLines(c(keep, add), f, useBytes = TRUE); cat(sprintf("%s: %d lines removed, %d written\n", sub(paste0(pkg, "/"), "", f), length(l) - length(keep), length(add))) }
first_field <- function(l) sub(",.*$", "", sub('^"([^"]*)".*$', "\\1", l))

edit_lines(D("stsim", "stsim_TransitionType.csv"), function(l) mine(first_field(l)), TYPES[, sprintf('%s,%d,"%s",,', Name, Id, Color)])
edit_lines(D("stsim", "stsim_TransitionGroup.csv"), function(l) mine(first_field(l)), paste0(GRP, ",,"))
edit_lines(D("stsim", "stsim_TransitionTypeGroup.csv"), function(l) mine(first_field(l)), TYPES[, sprintf("%s,%s,", Name, GRP)])

sc <- fread(D("stsim", "stsim_StateClass.csv")); fo <- sc[grepl("^Forest: ", Name), Name]; stopifnot(length(fo) > 0)
pw <- rbindlist(lapply(TYPES$Name, function(t) data.table(Iteration = "", Timestep = "", StratumIdSource = "", StateClassIdSource = fo, StratumIdDest = "",
  StateClassIdDest = fo, SecondaryStratumId = "", TertiaryStratumId = "", TransitionTypeId = t, Probability = "1", Proportion = "", AgeMin = "", AgeMax = "",
  AgeRelative = "", AgeReset = "No", TSTMin = "", TSTMax = "", TSTRelative = "")))
fwrite(pw, D("transitions", "pathways", "fuel-treatments.csv"), quote = FALSE)
cat(sprintf("defaults/transitions/pathways/fuel-treatments.csv: %d pathways (%d upland forest classes x %d types)\n", nrow(pw), length(fo), nrow(TYPES)))

# carbon of the treatments (event flows on each type's [Type] group): written once the research gives the shares
src <- D("fuel-treatments", "flows.csv")
if (file.exists(src)) {
  fl <- fread(src, na.strings = "")   # Treatment, FromStockTypeId, ToStockTypeId, FlowTypeId, Multiplier
  ev <- function(g, from, to, ft, m) sprintf(",,,,,,,%s,,,,%s,%s,,%s,,%s,,,,,", from, to, g, ft, m)
  add <- fl[, ev(paste0(Treatment, " [Type]"), FromStockTypeId, ToStockTypeId, FlowTypeId, Multiplier)]
  edit_lines(D("stockflow", "event-pathways.csv"), function(l) grepl(",Fuel Treatment: [A-Za-z ]+ \\[Type\\],", l), add)
} else cat("no defaults/fuel-treatments/flows.csv yet: event flows not written\n")

dl <- c(
  'TransitionType,Fuel Treatment: Mechanical Thinning,"Fuel treatment by thinning from below (Fuel Treatments page): small trees and ladder fuels removed, merchantable wood to the forestry sector, slash treated. The forest type and stand age stay; for some years after, a wildfire in the cell is less often high severity (stage 9 multipliers by time since the treatment).",',
  'TransitionType,Fuel Treatment: Prescribed Burn,"Fuel treatment by prescribed underburning: litter and fine woody debris partly burned, some understory mortality. The forest type and stand age stay; for some years after, a wildfire in the cell is less often high severity.",',
  'TransitionType,Fuel Treatment: Thin and Burn,"Fuel treatment by thinning followed by prescribed burning: both carbon effects, and the strongest and longest reduction of high-severity fire.",',
  'TransitionGroup,Fuel Treatment,"Every fuel treatment: mechanical thinning, prescribed burn, thin and burn.",')
edit_lines(D("metadata", "definitions.csv"), function(l) grepl("^Transition(Type|Group),Fuel Treatment", l), dl)
