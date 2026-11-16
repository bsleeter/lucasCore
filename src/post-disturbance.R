# =============================================================================
# post-disturbance.R - the post-disturbance settings by class and ecodivision (to-do 57; user 2026-11-11: windows by region)
# =============================================================================
# defaults/transitions/post-disturbance-settings.csv: one row per ParentClass ("Forest" = every forest type group and wetland twin,
# Ids 100-999, or one class's name) and Ecodivision (blank = every ecodivision). For each parent class and ecodivision the most
# specific row wins: the class in that ecodivision, the class anywhere, then (forest classes) Forest in that ecodivision, Forest
# anywhere. Read by tools/make_post_disturbance.R (pathways), stage 5 (the window of a cell that starts disturbed) and stage 9 (the
# return chance by age), and tests/unit-post-disturbance.R.
# =============================================================================
PD_COLS <- c("Window", "ReturnAgeMin", "ReturnProbability", "ReburnConversion", "ShrubShare")

# st: the settings table; parents: parent class names; is_forest: TRUE where the parent is a forest class (Ids 100-999); eco: the
# ecodivisions. Returns Parent, Ecodivision and the PD_COLS (numeric) for every parent x ecodivision a row covers.
pd_resolve <- function(st, parents, is_forest, eco) {
  st <- data.table::as.data.table(st); if (!"Ecodivision" %in% names(st)) st[, Ecodivision := NA_character_]
  st[, Ecodivision := as.character(Ecodivision)][!is.na(Ecodivision) & !nzchar(trimws(Ecodivision)), Ecodivision := NA_character_]
  for (k in PD_COLS) if (k %in% names(st)) data.table::set(st, j = k, value = suppressWarnings(as.numeric(st[[k]]))) else data.table::set(st, j = k, value = NA_real_)
  # (rows for ecodivisions outside `eco` are ignored: stages 5 and 9 pass only the study area's; tests/unit-post-disturbance.R checks
  # the names against the full list)
  if (anyDuplicated(st[, .(ParentClass, Ecodivision)])) stop("post-disturbance-settings.csv: a ParentClass and Ecodivision appear twice")
  pick <- function(p, f, e) {
    for (x in list(st[ParentClass == p & Ecodivision %in% e], st[ParentClass == p & is.na(Ecodivision)],
                   if (f) st[ParentClass == "Forest" & Ecodivision %in% e], if (f) st[ParentClass == "Forest" & is.na(Ecodivision)]))
      if (!is.null(x) && nrow(x)) return(x[1, PD_COLS, with = FALSE])
    NULL }
  data.table::rbindlist(lapply(seq_along(parents), function(i) data.table::rbindlist(lapply(eco, function(e) {
    r <- pick(parents[i], is_forest[i], e); if (is.null(r)) NULL else cbind(data.table::data.table(Parent = parents[i], Ecodivision = e), r) }))))
}

# TRUE for each parent whose settings in `cols` differ between ecodivisions (those get pathway or multiplier rows by ecodivision;
# the others one row for every ecodivision)
pd_varies <- function(res, cols = PD_COLS) {
  v <- res[, .(n = data.table::uniqueN(do.call(paste, lapply(cols, function(k) .SD[[k]])))), by = Parent, .SDcols = cols]
  stats::setNames(v$n > 1, v$Parent)
}

# ---- a second witness for forest return: LANDFIRE's 2016 vegetation type (user 2026-11-15) ------------------------------------------
# NLCD is slow to call a regenerating stand forest where trees grow slowly: on Yellowstone's 1988 high-severity burn it shows 2% forest
# in 2016, where LANDFIRE's Existing Vegetation Type of 2016 maps half as a tree type (dev/fire/README-return-witness.md). So a
# disturbed forest cell also returns when LANDFIRE 2016 shows trees on it, but only a cell whose forest loss came at least
# PD_WITNESS$min_years before 2016: on younger burns the label is not reliable (30-40% "tree" 3-4 years after a high-severity fire,
# against 6-17% at 5-9 years), LANDFIRE treating the ten years before a mapping year as recent disturbance.
# When the cell returns is not known (some year between the loss and 2016): it is taken at min_years after the loss, the youngest
# stand the witness is trusted on. tools/fit_post_disturbance.R counts the same event at the same age, so the fitted return chance
# and the historical maps agree.
PD_WITNESS <- list(year = 2016L, min_years = 15L, share = 0.5)

# tree_share: the share of each cell's LANDFIRE 2016 pixels that are a tree type (defaults/transitions/evt2016-tree-classes.csv);
# last_forest: the last year up to the witness year that NLCD shows the cell as forest (NA = never since y0); last_fire: the last
# year up to the witness year of a stand-replacing fire on most of the cell (NA = none); y0: the first year of the record.
# Returns the year each cell returns by the witness, NA where it does not: the loss (the later of the two, y0 when neither is known)
# plus min_years, when that is no later than the witness year.
pd_witness_year <- function(tree_share, last_forest, last_fire, y0, w = PD_WITNESS) {
  lost <- pmax(ifelse(is.na(last_forest), y0, last_forest), ifelse(is.na(last_fire), y0, last_fire))
  yr <- as.integer(lost + w$min_years)
  ifelse(!is.na(tree_share) & tree_share >= w$share & yr <= w$year, yr, NA_integer_)
}
