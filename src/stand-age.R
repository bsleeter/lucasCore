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
#   2. the user's age for its forest type (the Stand Age page's manual ages by forest type; its ecodivision's row before the all-ecodivisions row)
#   3. an earlier age map that saw the stand before it burned (NASA CMS 1990 under a TreeMap Build, for a first fire after 1990)
#   4. the given percentile (default the 75th) of the ages of the unburned forest of its type in its ecodivision, taken over one
#      30 m pixel a cell (so the percentile is of stands, not of cell means); the upper part because the stands a fire takes are
#      on average older than the ones it leaves (Yellowstone: CMS gives 143 years where a fire came after 1990, 110 where none did)
#   5. what the age map gives (as before; also when the page is set to keep the source's)
# Stand Age Options also sets how a cell takes its age from its 30 m pixels: the pixel at its centre (default), or their mean, which
# was the rule until lucasCore 1.6.0 and pulls every cell toward the middle (Yellowstone at 300 m: almost no cell over 200 years
# where 6% of the pixels are), so the landscape has fewer young and old stands than the map it came from.
# No rsyncrosim here: tests/unit-stand-age.R sources it.
# =============================================================================

AGE_AGGREGATION <- c(centre = "The pixel at the cell's centre", mean = "Mean of the cell's pixels")
AGE_UNKNOWN <- c(default = "Estimate it", source = "Keep the age map's value")
AGE_RULES <- c(raster = "Stand age raster", type = "Manual age for the forest type", earlier = "Earlier age map (before the fire or cut)",
               percentile = "Undisturbed forest of its type", source = "Age map")

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

# the user's ages by forest type (the Stand Age page's manual ages by forest type): StratumId (blank = every ecodivision), StateClassId, Age; checked
age_type_table <- function(x) {
  x <- data.table::as.data.table(x); if (!nrow(x)) return(data.table::data.table(StratumId = character(), StateClassId = character(), Age = numeric()))
  x <- x[, .(StratumId = if ("StratumId" %in% names(x)) as.character(StratumId) else NA_character_, StateClassId = as.character(StateClassId), Age = as.numeric(Age))]
  x[!is.na(StratumId) & !nzchar(StratumId), StratumId := NA_character_]
  if (anyNA(x$StateClassId) || anyNA(x$Age)) stop("Stand Age, manual ages by forest type: every row needs a forest type and an age", call. = FALSE)
  if (any(x$Age < 1 | x$Age > 1000)) stop("Stand Age, manual ages by forest type: ages run from 1 to 1000 years", call. = FALSE)
  if (anyDuplicated(x[, .(StratumId, StateClassId)])) stop("Stand Age, manual ages by forest type: a forest type appears twice for one ecodivision", call. = FALSE)
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

# ---- stand age against the FIA plots of the study area (user 2026-11-19) ------------------------------------------------------
# The age maps misread a landscape's age structure: Olympic National Park starts with 40% of its forest under 80 years in TreeMap
# and in NASA CMS alike, where the park's 104 FIA plots have 18% (and 45% over 250 years against 23 and 21%), and the park starts
# at 74% of its carbon capacity. A plot cannot correct the map where it stands (public coordinates are moved by up to a mile; plot
# age against the map at its place correlates at 0.18), but the plots of a study area do give how much forest of each age there is.
# Stand Age page, "Match the age map to the FIA plots" (sheet StandAgeFia; off by default): within each forest type the cells keep
# the map's order from youngest to oldest and take the plots' ages at the same rank (quantile mapping), so the map says where the
# old forest is and the plots how much of it there is. A forest type with fewer than MinPlots plots (blank 30) is matched with the
# other such types to all the study area's plots; with fewer plots than that in all, nothing is matched.
AGE_CLASSES <- c(0, 20, 40, 80, 120, 160, 200, 250, 300, Inf)
AGE_CLASS_LABELS <- c("1-20", "21-40", "41-80", "81-120", "121-160", "161-200", "201-250", "251-300", "Over 300")
age_class <- function(a) AGE_CLASS_LABELS[cut(a, AGE_CLASSES, labels = FALSE)]

# Stand Age: FIA (single row): match (TRUE / FALSE) and min_plots (blank 30, at least 10)
age_fia_options <- function(x) {
  x <- data.table::as.data.table(x); g <- function(k) if (nrow(x) && k %in% names(x)) x[[k]][1] else NA
  v <- as.character(g("FiaMatch")); on <- !is.na(v) && (v %in% c("2", "Yes", "TRUE", "-1") || startsWith(v, "Yes"))
  n <- suppressWarnings(as.integer(g("MinPlots"))); if (is.na(n)) n <- 30L
  if (n < 10L) stop(sprintf("Stand Age: FIA: the fewest plots is %d; give at least 10", n), call. = FALSE)
  list(match = on, min_plots = n) }

# the forest conditions of the given plots with their stand age (PLT_CN, CONDID, COND_STATUS_CD, CONDPROP_UNADJ, STDAGE, FORTYPCD)
age_fia_conds <- function(dm, plots) {
  none <- data.table::data.table(PLT_CN = character(), CONDID = integer(), COND_STATUS_CD = integer(), CONDPROP_UNADJ = numeric(), STDAGE = numeric(), FORTYPCD = integer())
  if (!nrow(plots)) return(none)
  x <- data.table::rbindlist(lapply(unique(plots$State), function(s) { f <- file.path(dm, paste0(s, "_COND.csv")); if (!file.exists(f)) return(NULL)
    data.table::fread(f, select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "CONDPROP_UNADJ", "STDAGE", "FORTYPCD"), colClasses = list(character = "PLT_CN"), showProgress = FALSE)[PLT_CN %in% plots$CN] }))
  if (is.null(x) || !nrow(x)) none else x }

# The plots' stands at the start year. plots: CN, INVYR, STATECD, UNITCD, COUNTYCD, PLOT (inside the study area); conds as above;
# group_of: FORTYPCD -> forest type group code. The newest visit of each plot; a forest condition with a stand age; its age moved to
# the start year (STDAGE - (INVYR - y0)). A stand that started after the start year says nothing of what stood there then: left
# out and counted. Returns list(plots = data.table(Age, Weight, Group), dropped, visits = c(from, to))
age_fia_plots <- function(plots, conds, y0, group_of = function(code) code) {
  none <- list(plots = data.table::data.table(Age = numeric(), Weight = numeric(), Group = integer()), dropped = 0L, visits = c(NA_integer_, NA_integer_))
  if (!nrow(plots) || !nrow(conds)) return(none)
  p <- data.table::as.data.table(plots)[INVYR < 9999][order(-INVYR)]; p <- p[!duplicated(p[, .(STATECD, UNITCD, COUNTYCD, PLOT)])]
  cd <- data.table::as.data.table(conds)[PLT_CN %in% p$CN & COND_STATUS_CD %in% 1 & !is.na(STDAGE) & STDAGE > 0 & !is.na(CONDPROP_UNADJ) & CONDPROP_UNADJ > 0]
  if (!nrow(cd)) return(none)
  cd[, yr := p$INVYR[match(PLT_CN, p$CN)]][, a0 := STDAGE - (yr - y0)]
  keep <- cd[a0 >= 1]
  list(plots = keep[, .(Age = as.numeric(a0), Weight = as.numeric(CONDPROP_UNADJ), Group = as.integer(group_of(FORTYPCD)))], dropped = nrow(cd) - nrow(keep), visits = range(cd$yr)) }

# a weighted quantile function of the plots' ages: p in 0-1 -> age (straight lines between the plots' mid-ranks)
age_quantile <- function(age, w, p) {
  o <- order(age); a <- age[o]; w <- w[o]; if (length(a) == 1) return(rep(a, length(p)))
  stats::approx((cumsum(w) - w / 2) / sum(w), a, xout = p, rule = 2, ties = "ordered")$y }

# Quantile mapping of the cells' ages onto the plots'. One element per cell: age (the map's, at the start year), type (the cell's
# forest type group code, as the plots' Group) and ok (the cells to match: forest with an age the map knows). fia = age_fia_plots()$plots.
# Returns list(age = the ages with the matched cells replaced (whole years, at least 1), matched = which cells,
#              table = one row per group: Group (a code, or NA = the other types together), Plots, Cells, MapMedian, PlotMedian, Median)
age_fia_match <- function(age, type, ok, fia, min_plots = 30L) {
  out <- as.numeric(age); matched <- rep(FALSE, length(out)); tab <- list()
  ok <- ok & !is.na(age); if (nrow(fia) < min_plots || !any(ok)) return(list(age = out, matched = matched, table = data.table::data.table()))
  np <- fia[, .N, by = Group]; own <- np$Group[np$N >= min_plots & !is.na(np$Group)]
  one <- function(k, f, g) { if (!any(k)) return(invisible())
    a <- out[k]; p <- (rank(a, ties.method = "average") - 0.5) / length(a); new <- pmax(round(age_quantile(f$Age, f$Weight, p)), 1)
    tab[[length(tab) + 1]] <<- data.table::data.table(Group = g, Plots = nrow(f), Cells = sum(k), MapMedian = stats::median(a), PlotMedian = age_quantile(f$Age, f$Weight, 0.5), Median = stats::median(new))
    out[k] <<- new; matched[k] <<- TRUE }
  for (g in own) one(ok & type %in% g, fia[Group %in% g], g)
  one(ok & !(type %in% own), fia, NA_integer_)
  list(age = out, matched = matched, table = data.table::rbindlist(tab)) }

# the share of forest in each age class: age and weight (cells: 1; plots: their condition share). Returns AgeClass, Percent, in order
age_distribution <- function(age, w = rep(1, length(age))) {
  k <- !is.na(age) & age >= 1 & !is.na(w); cl <- factor(age_class(age[k]), AGE_CLASS_LABELS); s <- tapply(w[k], cl, sum); s[is.na(s)] <- 0
  data.table::data.table(AgeClass = AGE_CLASS_LABELS, Percent = if (sum(s) > 0) as.numeric(100 * s / sum(s)) else NA_real_) }
