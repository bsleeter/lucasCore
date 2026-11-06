# =============================================================================
# unit-transition-pairs.R - land-use maps follow the pathways: each class pair has one transition group (2026-11-05)
# =============================================================================
# Plain R, no SyncroSim. Run: Rscript tests/unit-transition-pairs.R (from the package root)
suppressPackageStartupMessages(library(data.table))
source("src/transition-pairs.R")
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
pf <- list.files("defaults/transitions/pathways", "[.]csv$", full.names = TRUE)
pw <- rbindlist(lapply(pf, function(f) fread(f, colClasses = "character", na.strings = "")), fill = TRUE)
so <- fread("defaults/transitions/sources.csv", na.strings = "")
ttg <- fread("defaults/stsim/stsim_TransitionTypeGroup.csv", sep = ",", na.strings = "")
tts <- fread("defaults/stsim/stsim_TransitionType.csv", sep = ",", na.strings = "")
types <- function(g) if (endsWith(g, " [Type]")) sub(" [Type]", "", g, fixed = TRUE) else ttg[TransitionGroupId == g, TransitionTypeId]
lu <- so[Source %in% c("NlcdGain", "NlcdLoss", "NlcdChange"), TransitionGroupId]
P <- transition_pairs(pw, lu, types)
group_of <- function(from, to) P[From == from & To == to, Group]
check("no class pair has two groups", nrow(transition_pair_clashes(P)) == 0)
check("every land-use group has pairs", all(lu %in% P$Group))
check("every Ag Change type is in the package lists", all(c("Ag Change: Cropland to Pasture", "Ag Change: Pasture to Cropland") %in% tts$Name) && all(c("Ag Change: Cropland to Pasture", "Ag Change: Pasture to Cropland") %in% ttg[TransitionGroupId == "Ag Change", TransitionTypeId]))
check("transition type ids are unique", !anyDuplicated(tts$Id))
check("pasture to developed is urbanization, not contraction", identical(group_of(81L, 21L), "Urbanization: Open [Type]"))
check("cropland to developed is urbanization", identical(group_of(82L, 24L), "Urbanization: High [Type]"))
check("forest to developed is urbanization", identical(group_of(42L, 22L), "Urbanization: Low [Type]"))
check("shrub to pasture is expansion", identical(group_of(52L, 81L), "Ag Expansion: Pasture [Type]"))
check("pasture to forest is contraction from pasture", identical(group_of(81L, 41L), "Ag Contraction: Pasture"))
check("cropland to wetland is contraction from cropland", identical(group_of(82L, 90L), "Ag Contraction: Cropland"))
check("pasture to cropland is Ag Change", identical(group_of(81L, 82L), "Ag Change: Pasture to Cropland [Type]"))
check("cropland to pasture is Ag Change", identical(group_of(82L, 81L), "Ag Change: Cropland to Pasture [Type]"))
check("open to low is intensification", identical(group_of(21L, 22L), "Intensification: Open to Low [Type]"))
check("developed never reverts", !nrow(P[From %in% 21:24 & (To < From | To > 24L)]))
check("barren and water have no pairs", !nrow(P[From %in% c(11L, 12L, 31L) | To %in% c(11L, 12L, 31L)]))
check("natural to natural has no pair", !nrow(P[From %in% LU_NATURAL & To %in% LU_NATURAL]))
a <- c(81L, 81L, 82L, 81L, 42L, NA, 21L); b <- c(21L, 82L, 41L, 81L, 22L, 21L, 22L)
check("a cell is on only for its own pair", identical(pair_cells(a, b, P, "Ag Contraction: Pasture"), rep(FALSE, 7)) &&
      identical(which(pair_cells(a, b, P, "Ag Contraction: Cropland")), 3L) && identical(which(pair_cells(a, b, P, "Urbanization: Open [Type]")), 1L) &&
      identical(which(pair_cells(a, b, P, "Ag Change: Pasture to Cropland [Type]")), 2L) && identical(which(pair_cells(a, b, P, "Urbanization: Low [Type]")), 5L))
hits <- Reduce(`+`, lapply(lu, function(g) pair_cells(rep(a, 1), b, P, g)))
check("no cell in the example is in two groups", all(hits <= 1L) && hits[4] == 0L && hits[6] == 0L)
# the held class: a change with no pathway leaves it, so the next pair starts from the model's class
h <- c(42L, 42L, 81L, 52L, 21L, NA); b1 <- c(31L, 71L, 11L, 41L, 22L, 21L); on1 <- c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE)
h1 <- held_next(h, b1, on1)
check("natural to barren keeps natural; natural to natural follows; ag to water keeps ag; a mapped change moves; off land stays NA", identical(h1, c(42L, 71L, 81L, 41L, 22L, NA)))
b2 <- c(21L, 21L, 21L, 21L, 23L, 21L)
check("a natural cell the map showed as barren, then developed, is urbanization", identical(pair_cells(h1, b2, P, "Urbanization: Open [Type]"), c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE)) &&
      identical(pair_cells(h1, b2, P, "Intensification: Low to Medium [Type]"), c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE)))
# persistence: a change reversed within 3 years does not count
h0 <- c(42L, 42L, 81L, 81L, 52L, 22L)
later <- list(c(81L, 81L, 41L, 82L, 81L, 23L), c(81L, 81L, 41L, 82L, 81L, 23L), c(52L, 81L, 81L, 82L, 81L, 23L))
check("back to natural within 3 years reverts; staying does not; back to pasture reverts; a natural class counts as natural; developed never reverts",
      identical(reverts(h0, later), c(TRUE, FALSE, TRUE, FALSE, FALSE, FALSE)))
check("a later year past the record's end is not needed", identical(reverts(h0, later[1]), c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)))
check("the reversal must be within the window", identical(reverts(c(42L), list(81L, 81L, 81L, 41L)), FALSE) && identical(reverts(c(42L), list(81L, 81L, 41L, 81L)), TRUE))
check("the package persistence is 3 years", LU_PERSIST == 3L)
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
