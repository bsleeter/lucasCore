# =============================================================================
# make_management.R - the management transitions of to-do 58 (user 2026-11-13: "Start with replanting, salvage and site prep on a
# dedicated page"): replanting after a disturbance, with or without site preparation, and its failure
# =============================================================================
# Writes, removing its own earlier rows first (so a rerun does not duplicate anything) and touching no other row:
#   defaults/stsim/stsim_TransitionType.csv, stsim_TransitionGroup.csv, stsim_TransitionTypeGroup.csv
#     six types (Ids 1200-1205): Management: Replanting / after Burn Site Prep / after Mechanical Site Prep, and each "(failed)";
#     groups Management: Replanting (all six), Site Preparation: Burn and Site Preparation: Mechanical (their two types each)
#   defaults/transitions/pathways/management.csv
#     from every disturbed forest class (Id 2100-2999, upland and wetland twins): a planting that takes goes to its parent forest
#     class at age 0 (age reset); a failed one stays in the disturbed class with its age, where it can still return or convert.
#     No ages on the pathways: the Management Actions page sets the window (stage 9 multipliers), and stage 6 gives every type
#     without a map a zero target, so nothing is planted unless a projection asks for it
#   defaults/stockflow/event-pathways.csv
#     site preparation's carbon, on the two Site Preparation groups (planted and failed alike). Pile and burn: the shrub and herb
#     cover's foliage and wood burn as a clearcut's slash burn does (96% to CO2, CO, CH4; 4% to dead matter), roots die, half the
#     litter and fine woody debris and 30% of the branch snags burn. Mechanical (mastication): foliage and wood go to litter and
#     fine woody debris, roots die. Judgement values (provisional): see docs/ui-improvements.md to-do 58
#   defaults/metadata/definitions.csv
# Usage: Rscript tools/make_management.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
D <- function(...) file.path(pkg, "defaults", ...)
TYPES <- data.table(Name = c("Management: Replanting", "Management: Replanting (failed)",
                             "Management: Replanting after Burn Site Prep", "Management: Replanting after Burn Site Prep (failed)",
                             "Management: Replanting after Mechanical Site Prep", "Management: Replanting after Mechanical Site Prep (failed)"),
                    Id = 1200:1205, Prep = rep(c(NA, "Burn", "Mechanical"), each = 2), Failed = rep(c(FALSE, TRUE), 3),
                    Color = rep(c("255,0,128,0", "255,154,205,50"), 3))
GRP <- "Management: Replanting"; PREP <- c(Burn = "Site Preparation: Burn", Mechanical = "Site Preparation: Mechanical")
mine <- function(x) grepl("^(Management: Replanting|Site Preparation: )", x)

# text-line edits: drop this tool's lines, append the new ones
edit_lines <- function(f, drop, add) { l <- readLines(f, encoding = "UTF-8"); keep <- c(l[1], l[-1][!drop(l[-1])])
  writeLines(c(keep, add), f, useBytes = TRUE); cat(sprintf("%s: %d lines removed, %d written\n", sub(paste0(pkg, "/"), "", f), length(l) - length(keep), length(add))) }
first_field <- function(l) sub(",.*$", "", sub('^"([^"]*)".*$', "\\1", l))

edit_lines(D("stsim", "stsim_TransitionType.csv"), function(l) mine(first_field(l)), TYPES[, sprintf('%s,%d,"%s",,', Name, Id, Color)])
edit_lines(D("stsim", "stsim_TransitionGroup.csv"), function(l) mine(first_field(l)), c(paste0(GRP, ",,"), paste0(PREP, ",,")))
tg <- c(TYPES[, sprintf("%s,%s,", Name, GRP)], TYPES[!is.na(Prep), sprintf("%s,%s,", Name, PREP[Prep])])
edit_lines(D("stsim", "stsim_TransitionTypeGroup.csv"), function(l) mine(first_field(l)), tg)

# pathways from every disturbed forest class
sc <- fread(D("stsim", "stsim_StateClass.csv")); dis <- sc[Id >= 2100 & Id < 3000, .(Name, Parent = sc$Name[match(Id - 2000L, sc$Id)])]
stopifnot(nrow(dis) > 0, !anyNA(dis$Parent))
pw <- rbindlist(lapply(seq_len(nrow(TYPES)), function(i) dis[, .(Iteration = "", Timestep = "", StratumIdSource = "", StateClassIdSource = Name, StratumIdDest = "",
  StateClassIdDest = if (TYPES$Failed[i]) Name else Parent, SecondaryStratumId = "", TertiaryStratumId = "", TransitionTypeId = TYPES$Name[i], Probability = "1",
  Proportion = "", AgeMin = "", AgeMax = "", AgeRelative = "", AgeReset = if (TYPES$Failed[i]) "No" else "Yes", TSTMin = "", TSTMax = "", TSTRelative = "")]))
fwrite(pw, D("transitions", "pathways", "management.csv"), quote = FALSE); cat(sprintf("defaults/transitions/pathways/management.csv: %d pathways (%d disturbed forest classes x %d types)\n", nrow(pw), nrow(dis), nrow(TYPES)))

# site preparation carbon (event flows), keyed on the two Site Preparation groups
ev <- function(g, from, to, ft, m) sprintf(",,,,,,,%s,,,,%s,%s,,%s,,%s,,,,,", from, to, g, ft, m)
burn <- function(g) c(
  ev(g, "Biomass: Foliage", "DOM: Aboveground Very Fast", "LULC: Mortality Live", 0.04), ev(g, "Biomass: Other Wood", "DOM: Aboveground Fast", "LULC: Mortality Live", 0.04),
  unlist(lapply(c("Biomass: Foliage", "Biomass: Other Wood"), function(s) c(ev(g, s, "Atmosphere: CO2", "LULC: Emission Live CO2", 0.864),
    ev(g, s, "Atmosphere: CO", "LULC: Emission Live CO", 0.0864), ev(g, s, "Atmosphere: CH4", "LULC: Emission Live CH4", 0.0096)))),
  roots(g),
  unlist(lapply(list(c("DOM: Aboveground Very Fast", 0.5), c("DOM: Aboveground Fast", 0.5), c("DOM: Snag Branch", 0.3)), function(s) { k <- as.numeric(s[2])
    c(ev(g, s[1], "Atmosphere: CO2", "LULC: Emission DOM CO2", 0.9 * k), ev(g, s[1], "Atmosphere: CO", "LULC: Emission DOM CO", 0.09 * k),
      ev(g, s[1], "Atmosphere: CH4", "LULC: Emission DOM CH4", 0.01 * k)) })))
roots <- function(g) c(ev(g, "Biomass: Fine Root", "DOM: Belowground Very Fast", "LULC: Mortality Live", 1), ev(g, "Biomass: Coarse Root", "DOM: Belowground Fast", "LULC: Mortality Live", 1))
mech <- function(g) c(ev(g, "Biomass: Foliage", "DOM: Aboveground Very Fast", "LULC: Mortality Live", 1), ev(g, "Biomass: Other Wood", "DOM: Aboveground Fast", "LULC: Mortality Live", 1), roots(g))
edit_lines(D("stockflow", "event-pathways.csv"), function(l) grepl(",Site Preparation: [A-Za-z]+,", l), c(burn(PREP[["Burn"]]), mech(PREP[["Mechanical"]])))

# definitions
dl <- c(
  'TransitionType,Management: Replanting,"Planting after a disturbance (Management Actions page): a disturbed forest class back to its forest type at age 0, without site preparation.",',
  'TransitionType,Management: Replanting (failed),"A planting that did not take (the Management Actions page\'s survival): the cell stays in its disturbed class with its age, where it can still return or convert.",',
  'TransitionType,Management: Replanting after Burn Site Prep,"Planting after pile-and-burn site preparation (its carbon: the Site Preparation: Burn group).",',
  'TransitionType,Management: Replanting after Burn Site Prep (failed),"A planting after pile-and-burn site preparation that did not take: the site preparation carbon flows, then the cell stays disturbed.",',
  'TransitionType,Management: Replanting after Mechanical Site Prep,"Planting after mechanical site preparation (mastication; its carbon: the Site Preparation: Mechanical group).",',
  'TransitionType,Management: Replanting after Mechanical Site Prep (failed),"A planting after mechanical site preparation that did not take: the site preparation carbon flows, then the cell stays disturbed.",',
  'TransitionGroup,Management: Replanting,"Every replanting transition, planted or failed, with or without site preparation (to-do 58).",',
  'TransitionGroup,Site Preparation: Burn,"Replanting after pile-and-burn site preparation: shrub and herb cover burned, roots killed, half the litter and fine woody debris and 30% of the branch snags burned.",',
  'TransitionGroup,Site Preparation: Mechanical,"Replanting after mechanical site preparation (mastication): shrub and herb cover to litter and fine woody debris, roots killed.",')
edit_lines(D("metadata", "definitions.csv"), function(l) grepl("^Transition(Type|Group),(Management: Replanting|Site Preparation: )", l), dl)
