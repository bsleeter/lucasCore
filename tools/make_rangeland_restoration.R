# =============================================================================
# make_rangeland_restoration.R - the post-fire rangeland restoration transitions (mitigation measure 5; user 2026-11-14: "start on #5
# a post fire rangeland restoration"; the outcome: "keep it straight to native sage steppe but with a corresponding failure rate")
# =============================================================================
# Writes, removing its own earlier rows first (a rerun duplicates nothing) and touching no other row:
#   defaults/stsim/stsim_TransitionType.csv, stsim_TransitionGroup.csv, stsim_TransitionTypeGroup.csv
#     eight types (Ids 1310-1317): Management: Aerial Seeding, Drill Seeding, Sagebrush Planting, Herbicide and Seeding, and each
#     "(failed)"; group Management: Rangeland Restoration (all eight)
#   defaults/transitions/pathways/rangeland-restoration.csv
#     - seeding and planting from the burned sage family (Disturbed: Sage, Native Sage Steppe, Invaded Sage Steppe);
#     - herbicide and seeding from burned invaded steppe, and from converted annual grass (Grassland: Annual). Only the Great Basin
#       and steppe ecodivisions' annual grass is meant (Temperate Desert and Steppe, and their mountains; California's annual
#       grassland is another system), but the pathway has no stratum: stage 6 needs every ecodivision of a study area to have the
#       same pathways (Hart Mountain Build 2026-11-14), so stage 9 sets a zero multiplier on annual grass elsewhere (src/management.R);
#     - a success goes to Shrubland: Native Sage Steppe at age 0 (age reset); a failure stays in its class with its age, where a
#       disturbed cell can still return or convert as before. The share that succeeds is the Management Actions row's (stage 9).
#     No ages on the pathways and no map: the page sets the window (stage 9 multipliers), and stage 6 gives every type without a
#     map a zero target, so nothing is treated unless a projection asks for it. No carbon flows: seeding and spraying move little
#     carbon; the class change carries the rest (Native Sage Steppe's growth from age 0)
#   defaults/metadata/definitions.csv
# Values (success, windows, costs): dev/rangeland-restoration/research.md (provisional)
# Usage: Rscript tools/make_rangeland_restoration.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
D <- function(...) file.path(pkg, "defaults", ...)
BASE <- c("Management: Aerial Seeding", "Management: Drill Seeding", "Management: Sagebrush Planting", "Management: Herbicide and Seeding")
TYPES <- data.table(Name = as.vector(rbind(BASE, paste(BASE, "(failed)"))), Id = 1310:1317, Failed = rep(c(FALSE, TRUE), 4),
                    Herbicide = rep(c(FALSE, FALSE, FALSE, TRUE), each = 2), Color = rep(c("255,107,142,35", "255,189,183,107"), 4))
GRP <- "Management: Rangeland Restoration"
TARGET <- "Shrubland: Native Sage Steppe"
SAGE_DIST <- c("Disturbed: Sage", "Disturbed: Native Sage Steppe", "Disturbed: Invaded Sage Steppe")
ANNUAL <- "Grassland: Annual"; ANNUAL_ECO <- c("Temperate Desert", "Temperate Desert Mountains", "Temperate Steppe", "Temperate Steppe Mountains")
mine <- function(x) x %in% TYPES$Name | x == GRP
edit_lines <- function(f, drop, add) { l <- readLines(f, encoding = "UTF-8"); keep <- c(l[1], l[-1][!drop(l[-1])])
  writeLines(c(keep, add), f, useBytes = TRUE); cat(sprintf("%s: %d lines removed, %d written\n", sub(paste0(pkg, "/"), "", f), length(l) - length(keep), length(add))) }
first_field <- function(l) sub(",.*$", "", sub('^"([^"]*)".*$', "\\1", l))

edit_lines(D("stsim", "stsim_TransitionType.csv"), function(l) mine(first_field(l)), TYPES[, sprintf('%s,%d,"%s",,', Name, Id, Color)])
edit_lines(D("stsim", "stsim_TransitionGroup.csv"), function(l) mine(first_field(l)), paste0(GRP, ",,"))
edit_lines(D("stsim", "stsim_TransitionTypeGroup.csv"), function(l) mine(first_field(l)), TYPES[, sprintf("%s,%s,", Name, GRP)])

sc <- fread(D("stsim", "stsim_StateClass.csv")); stopifnot(all(c(SAGE_DIST, ANNUAL, TARGET) %in% sc$Name))
st <- fread(D("stsim", "stsim_Stratum.csv")); stopifnot(all(ANNUAL_ECO %in% st$Name))
pw1 <- function(type, failed, from, eco = "") data.table(Iteration = "", Timestep = "", StratumIdSource = eco, StateClassIdSource = from, StratumIdDest = "",
  StateClassIdDest = if (failed) from else TARGET, SecondaryStratumId = "", TertiaryStratumId = "", TransitionTypeId = type, Probability = "1", Proportion = "",
  AgeMin = "", AgeMax = "", AgeRelative = "", AgeReset = if (failed) "No" else "Yes", TSTMin = "", TSTMax = "", TSTRelative = "")
pw <- rbindlist(lapply(seq_len(nrow(TYPES)), function(i) { t <- TYPES[i]
  if (!t$Herbicide) rbindlist(lapply(SAGE_DIST, function(s) pw1(t$Name, t$Failed, s))) else
    rbind(pw1(t$Name, t$Failed, "Disturbed: Invaded Sage Steppe"), pw1(t$Name, t$Failed, ANNUAL)) }))
fwrite(pw, D("transitions", "pathways", "rangeland-restoration.csv"), quote = FALSE)
cat(sprintf("defaults/transitions/pathways/rangeland-restoration.csv: %d pathways\n", nrow(pw)))

dl <- c(
  'TransitionType,Management: Aerial Seeding,"Post-fire aerial (broadcast) seeding of perennial grasses, forbs and sagebrush on burned sage and sage steppe (Management Actions page): a success goes to Native Sage Steppe at age 0.",',
  'TransitionType,Management: Aerial Seeding (failed),"Aerial seeding that did not establish (the page\'s success share): the cell stays in its disturbed class with its age, where it can still return or convert.",',
  'TransitionType,Management: Drill Seeding,"Post-fire drill seeding of a native perennial grass mix (often with sagebrush broadcast) on burned sage and sage steppe: a success goes to Native Sage Steppe at age 0.",',
  'TransitionType,Management: Drill Seeding (failed),"Drill seeding that did not establish: the cell stays disturbed with its age.",',
  'TransitionType,Management: Sagebrush Planting,"Planting sagebrush seedlings (plugs, container stock) on burned sage and sage steppe: a success goes to Native Sage Steppe at age 0.",',
  'TransitionType,Management: Sagebrush Planting (failed),"Sagebrush planting that did not establish: the cell stays disturbed with its age.",',
  'TransitionType,Management: Herbicide and Seeding,"Pre-emergent herbicide against annual grass (imazapic or indaziflam) followed by seeding, on burned invaded steppe or converted annual grass in the Great Basin and steppe ecodivisions: a success goes to Native Sage Steppe at age 0.",',
  'TransitionType,Management: Herbicide and Seeding (failed),"Herbicide and seeding that did not establish perennials: the cell stays in its class (burned invaded steppe or annual grass) with its age.",',
  'TransitionGroup,Management: Rangeland Restoration,"Every post-fire rangeland restoration transition, established or failed: aerial and drill seeding, sagebrush planting, herbicide and seeding.",')
edit_lines(D("metadata", "definitions.csv"), function(l) grepl(sprintf("^Transition(Type|Group),(%s)", paste(c(BASE, GRP), collapse = "|")), l), dl)
