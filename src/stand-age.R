# =============================================================================
# stand-age.R - stand age where the age map cannot know it, and the Stand Age Options (stage 5)
# =============================================================================
# The age maps post-date the start year (NASA CMS: 1990; TreeMap: 2016). A stand that burned between the start year and the map's
# year shows in the map as what grew back, or as its unburned remnants, never as what stood there in the start year. Yellowstone,
# 2026-11-18: the 40% of the park's forest inside the 1988 fire perimeters started at 99 years, the same as the unburned forest,
# where the fire history gives stands of 200 years and more, and the park started at 86% of its carbon carrying capacity; with 200
# to 300 years there it starts at 95 to 98%.
# Such a cell's age is "unknown": a forest cell inside an interagency fire perimeter of a year after the start year, up to the age
# map's year. Its start-year age is the first of (user, 2026-11-18: "have a default approach, one based of a user input value for
# each forest type, or an uploaded raster would all be good options to have in place"):
#   1. the user's stand age raster, where it has a value (this one applies to every forest cell, unknown or not)
#   2. the user's age for its forest type (Stand Age: Unknown Ages; its ecodivision's row before the all-ecodivisions row)
#   3. an earlier age map that saw the stand before it burned (NASA CMS 1990 under a TreeMap Build, for a first fire after 1990)
#   4. the given percentile (default the 75th) of the ages of the unburned forest of its type in its ecodivision, taken over one
#      30 m pixel a cell (so the percentile is of stands, not of cell means); the upper part because the stands a fire takes are
#      on average older than the ones it leaves (Yellowstone: CMS gives 143 years where a fire came after 1990, 110 where none did)
#   5. what the age map gives (as before; also when Unknown Ages is set to keep the source's)
# Stand Age Options also sets how a cell takes its age from its 30 m pixels: the pixel at its centre (default), or their mean, which
# was the rule until lucasCore 1.5.2 and pulls every cell toward the middle (Yellowstone at 300 m: almost no cell over 200 years
# where 6% of the pixels are), so the landscape has fewer young and old stands than the map it came from.
# No rsyncrosim here: tests/unit-stand-age.R sources it.
# =============================================================================

AGE_AGGREGATION <- c(centre = "The pixel at the cell's centre", mean = "Mean of the cell's pixels")
AGE_UNKNOWN <- c(default = "Estimate it", source = "Keep the age map's value")
AGE_RULES <- c(raster = "Stand age raster", type = "Unknown Ages: forest type value", earlier = "Earlier age map (before the fire)",
               percentile = "Unburned forest of its type", source = "Age map")

# Stand Age Options (single row; a list column reads as its number or its label; blank = the default): aggregate ("centre" or
# "mean"), unknown ("default" or "source"), percentile (1-99, blank 75), raster (a path or NA) and raster_year (NA = the start year)
age_options <- function(x) {
  x <- data.table::as.data.table(x); g <- function(k) if (nrow(x) && k %in% names(x)) x[[k]][1] else NA
  pick <- function(k, labels, what) { v <- g(k); if (is.na(v) || !nzchar(as.character(v))) return(names(labels)[1]); v <- as.character(v)
    i <- if (v %in% as.character(seq_along(labels))) as.integer(v) else match(v, labels)
    if (is.na(i)) stop(sprintf("Stand Age Options: %s is '%s'; use %s", what, v, paste(labels, collapse = " or ")), call. = FALSE); names(labels)[i] }
  p <- suppressWarnings(as.numeric(g("UnknownPercentile"))); if (is.na(p)) p <- 75
  if (p < 1 || p > 99) stop(sprintf("Stand Age Options: Percentile is %s; give 1 to 99", p), call. = FALSE)
  f <- g("AgeRasterFile"); f <- if (is.na(f) || !nzchar(as.character(f))) NA_character_ else as.character(f)
  list(aggregate = pick("Aggregation", AGE_AGGREGATION, "Cell Age"), unknown = pick("UnknownRule", AGE_UNKNOWN, "Unknown Ages"), percentile = p,
       raster = f, raster_year = suppressWarnings(as.integer(g("AgeRasterYear")))) }

# the user's ages by forest type (Stand Age: Unknown Ages): StratumId (blank = every ecodivision), StateClassId, Age; checked
age_type_table <- function(x) {
  x <- data.table::as.data.table(x); if (!nrow(x)) return(data.table::data.table(StratumId = character(), StateClassId = character(), Age = numeric()))
  x <- x[, .(StratumId = if ("StratumId" %in% names(x)) as.character(StratumId) else NA_character_, StateClassId = as.character(StateClassId), Age = as.numeric(Age))]
  x[!is.na(StratumId) & !nzchar(StratumId), StratumId := NA_character_]
  if (anyNA(x$StateClassId) || anyNA(x$Age)) stop("Stand Age: Unknown Ages: every row needs a forest type and an age", call. = FALSE)
  if (any(x$Age < 1 | x$Age > 1000)) stop("Stand Age: Unknown Ages: ages run from 1 to 1000 years", call. = FALSE)
  if (anyDuplicated(x[, .(StratumId, StateClassId)])) stop("Stand Age: Unknown Ages: a forest type appears twice for one ecodivision", call. = FALSE)
  x[] }

# the percentile of the ages of the unburned forest of each ecodivision x forest type. age: one stand's age per cell (a pixel's, not
# a cell mean); ok: the cells to use (forest, not unknown, with an age). A pair with fewer than min_cells takes its ecodivision's
# percentile over every type; an ecodivision with fewer still has none. Returns StratumId, StateClassId, Age, Cells
age_percentiles <- function(eco, cls, age, ok, p = 75, min_cells = 30) {
  d <- data.table::data.table(eco, cls, age)[ok & !is.na(age) & !is.na(eco) & !is.na(cls)]
  if (!nrow(d)) return(data.table::data.table(StratumId = character(), StateClassId = character(), Age = numeric(), Cells = integer()))
  q <- function(v) as.numeric(stats::quantile(v, p / 100, names = FALSE))
  own <- d[, .(Age = q(age), Cells = .N), by = .(StratumId = eco, StateClassId = cls)]; all <- d[, .(AgeAll = q(age), CellsAll = .N), by = .(StratumId = eco)]
  out <- merge(own, all, by = "StratumId"); out[Cells < min_cells, Age := ifelse(CellsAll >= min_cells, AgeAll, NA_real_)]
  rbind(out[!is.na(Age), .(StratumId, StateClassId, Age, Cells)], all[CellsAll >= min_cells, .(StratumId, StateClassId = NA_character_, Age = AgeAll, Cells = CellsAll)]) }

# Each forest cell's start-year age. One element per cell of every vector:
#   forest      TRUE on the cells that carry a stand age            eco, cls    ecodivision and forest type names
#   age         the age map's start-year age (the Build's rule so far), every forest cell filled
#   burn_year   the year of the cell's first fire after the start year, up to the age map's year; NA = none (its age is known)
#   raster_age  the user's raster, moved to the start year; NA where it has no value
#   earlier_age an earlier age map moved to the start year, earlier_year its year (NA = none): used where it predates burn_year
#   type_table  age_type_table(); pct: age_percentiles() (its StateClassId NA row serves a type the ecodivision has too few cells of)
#   unknown     "default" (estimate the unknown cells) or "source" (keep the age map's)
# Returns age (whole years, at least 1 on forest; the input elsewhere) and rule (a name of AGE_RULES; NA off forest)
age_assign <- function(forest, eco, cls, age, burn_year = NA, raster_age = NA, earlier_age = NA, earlier_year = NA, type_table = age_type_table(data.frame()),
                       pct = NULL, unknown = "default", max_age = 1000) {
  n <- length(forest); rp <- function(v) rep_len(v, n); burn_year <- rp(burn_year); raster_age <- rp(as.numeric(raster_age)); earlier_age <- rp(as.numeric(earlier_age))
  out <- as.numeric(age); rule <- ifelse(forest, "source", NA_character_)
  unk <- forest & !is.na(burn_year) & unknown == "default"; left <- unk
  put <- function(k, v, r) { k <- k & !is.na(v) & v >= 1; out[k] <<- v[k]; rule[k] <<- r; left[k] <<- FALSE }
  # 2 the user's age for the forest type: the ecodivision's row, else the all-ecodivisions row
  if (nrow(type_table)) { own <- type_table$Age[match(paste(eco, cls), paste(type_table$StratumId, type_table$StateClassId))]
    all <- type_table[is.na(StratumId)]; put(left, ifelse(is.na(own), all$Age[match(cls, all$StateClassId)], own), "type") }
  # 3 an earlier age map that saw the stand before its first fire after the start year
  if (!is.na(earlier_year)) put(left & burn_year > earlier_year, earlier_age, "earlier")
  # 4 the percentile of the unburned forest of its type in its ecodivision (else of the ecodivision's forest)
  if (!is.null(pct) && nrow(pct)) { own <- pct$Age[match(paste(eco, cls), paste(pct$StratumId, pct$StateClassId))]; any_t <- pct[is.na(StateClassId)]
    put(left, ifelse(is.na(own), any_t$Age[match(eco, any_t$StratumId)], own), "percentile") }
  # 1 the user's raster wins wherever it has a value, on every forest cell
  k <- forest & !is.na(raster_age) & raster_age >= 1; out[k] <- raster_age[k]; rule[k] <- "raster"
  out[forest] <- pmin(pmax(round(out[forest]), 1), max_age)
  list(age = out, rule = rule) }

# the table stage 5 saves: per forest type and rule, the cells, their mean age and the mean age the age map gave them
age_summary <- function(cls, rule, age, source_age) {
  d <- data.table::data.table(StateClassId = cls, Rule = rule, age, source_age)[!is.na(rule)]
  d[, .(Cells = .N, MeanAge = round(mean(age), 1), SourceAge = round(mean(source_age), 1)), by = .(StateClassId, Rule = unname(AGE_RULES[Rule]))][order(StateClassId, -Cells)] }
