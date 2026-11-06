# =============================================================================
# transition-pairs.R - which land-use transition group each NLCD class change belongs to (stage 6; user rule 2026-11-05)
# =============================================================================
# The transition pathways give every (from class, to class) pair one transition group. The land-use maps follow the same rule: a cell is on
# in a group's map in year y only when its class pair from year y-1 to year y is one of that group's. A change with no pathway (to or from
# barren or water, or among the natural classes) is on no map.
# =============================================================================
LU_NATURAL <- c(41L, 42L, 43L, 52L, 71L, 90L, 95L)   # the annual NLCD's natural classes that have pathways
LU_NAMED <- c("Developed: Open Space" = 21L, "Developed: Low Intensity" = 22L, "Developed: Medium Intensity" = 23L, "Developed: High Intensity" = 24L,
              "Agriculture: Pasture" = 81L, "Agriculture: Cropland" = 82L)

# the NLCD classes a state class stands for on the annual maps: natural state classes are one family, since a cell's natural class on the map
# need not be its state class (the any-year forest rule); NA for a class with no NLCD counterpart in the pathways
nlcd_of_class <- function(cls) { if (cls %in% names(LU_NAMED)) return(unname(LU_NAMED[cls]))
  if (grepl("^(Forest|Grassland|Shrubland|Wetland):", cls)) return(LU_NATURAL)
  NA_integer_ }

# one row per group and class pair. pw has StateClassIdSource, StateClassIdDest, TransitionTypeId; types maps a group to its transition types
transition_pairs <- function(pw, groups, types) {
  data.table::rbindlist(lapply(groups, function(g) { p <- unique(pw[pw$TransitionTypeId %in% types(g), c("StateClassIdSource", "StateClassIdDest")])
    unique(data.table::rbindlist(lapply(seq_len(nrow(p)), function(i) data.table::CJ(From = nlcd_of_class(p$StateClassIdSource[i]), To = nlcd_of_class(p$StateClassIdDest[i])))))[, Group := g][From != To] })) }

# pairs given to more than one group: must be none
transition_pair_clashes <- function(pairs) pairs[, .(N = data.table::uniqueN(Group), Groups = paste(sort(unique(Group)), collapse = " | ")), by = .(From, To)][N > 1]

# cells of one group on, from last year's (a) and this year's (b) classes
pair_cells <- function(a, b, pairs, group) { k <- pairs[Group == group, From * 1000L + To]; !is.na(a) & !is.na(b) & (a * 1000L + b) %in% k }

# The class the model holds after year y: a cell moves only along a pathway (on = on in some group's map), and among the natural classes,
# which the model does not tell apart on these maps. A change with no pathway (natural to barren, pasture to water) leaves the held class,
# so the cell's next pair starts where the model is: a natural cell the map shows as barren for a year and then developed is urbanization
# (found 2026-11-05: pairs from the map's own classes lost Placer's later intensification on such cells)
# Persistence (user decision 2026-11-05: model real, sustained change): a change counts only when the cell's map does not return to the class
# family it left within LU_PERSIST years. Families: the natural classes as one, pasture, cropland, each developed level (developed never
# reverts on the area-matched maps). A change in the last years of the record, with fewer years left to see, counts. A change that does not
# count leaves the held class, so the return is no change either.
LU_PERSIST <- 3L
lu_family <- function(x) ifelse(x %in% LU_NATURAL, 1L, x)
reverts <- function(h, later, k = LU_PERSIST) { f <- lu_family(h); r <- rep(FALSE, length(h))
  for (s in seq_len(min(k, length(later)))) { g <- lu_family(later[[s]]); r <- r | (!is.na(g) & !is.na(f) & g == f) }
  r }

held_next <- function(h, b, on) { n <- h; m <- on & !is.na(b); n[m] <- b[m]; nat <- !is.na(h) & !is.na(b) & h %in% LU_NATURAL & b %in% LU_NATURAL; n[nat] <- b[nat]; n }
