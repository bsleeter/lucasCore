# =============================================================================
# reforestation.R - forest potential from LANDFIRE Biophysical Settings (to-do 57: the reforestation transition)
# =============================================================================
# Stage 5 starts a natural cell that NLCD shows becoming forest late in the record, or on land whose potential vegetation is not forest,
# as its start-year class; a Reforestation transition then takes it to forest when NLCD does. Potential vegetation is LANDFIRE BpS
# 2020 (Data Source BpsFile; LFPS layer LF2020_BPS, the current CONUS edition). LFPS jobs return the raster alone, so the attribute
# table ships as defaults/landcover/LF20_BPS_220.csv (VALUE, BPS_CODE, BPS_NAME, GROUPVEG; from the national zip's CSV_Data), and
# defaults/landcover/bps-groups.csv sorts each GROUPVEG into a potential: forest, riparian or savanna, non-forest or other.
# BpS values with no GROUPVEG (Hawaii and one boreal Alaska type) and values not in the table read as other.
# =============================================================================
BPS_POTENTIAL <- c("forest", "riparian or savanna", "non-forest", "other")

# the BpS value -> potential lookup: a data.table VALUE, GROUPVEG, Potential (one of BPS_POTENTIAL)
bps_lookup <- function(tab = read_default("landcover", "LF20_BPS_220.csv"), groups = read_default("landcover", "bps-groups.csv")) {
  tab <- data.table::as.data.table(tab); groups <- data.table::as.data.table(groups)
  bad <- setdiff(groups$Potential, BPS_POTENTIAL)
  if (length(bad)) stop(sprintf("bps-groups.csv: Potential '%s' is not one of %s", paste(bad, collapse = "', '"), paste(BPS_POTENTIAL, collapse = ", ")))
  if (anyDuplicated(groups$GROUPVEG)) stop("bps-groups.csv: a GROUPVEG appears twice")
  out <- tab[, .(VALUE = as.integer(VALUE), GROUPVEG = as.character(GROUPVEG))]
  out[, Potential := groups$Potential[match(GROUPVEG, groups$GROUPVEG)]][is.na(Potential), Potential := "other"][]
}

# potential for BpS values v (integer vector): "forest", "non-forest" or "other"; riparian or savanna reads as forest unless
# riparian_as = "non-forest" (Reforestation Options, user default 2026-11-12: forest)
bps_potential <- function(v, lookup = bps_lookup(), riparian_as = "forest") {
  if (!riparian_as %in% c("forest", "non-forest")) stop(sprintf("riparian or savanna BpS reads as forest or non-forest, not '%s'", riparian_as))
  p <- lookup$Potential[match(as.integer(v), lookup$VALUE)]; p[is.na(p)] <- "other"
  p[p == "riparian or savanna"] <- riparian_as; p
}

# The reforestation cutoff (to-do 57 step 2): years after the start year from which a natural cell's first NLCD forest counts as
# reforestation rather than regrowth from a disturbance before the record. defaults/landcover/reforestation-cutoff.csv
# (tools/fit_reforestation_cutoff.R) gives it by ecodivision, a blank Ecodivision row for any other; override (Reforestation
# Options' CutoffYears, a number) replaces it everywhere. Returns one value per element of eco (ecodivision names).
reforest_cutoff <- function(eco, tab = read_default("landcover", "reforestation-cutoff.csv"), override = NA) {
  if (!is.na(suppressWarnings(as.numeric(override)))) { v <- as.numeric(override)
    if (v < 1 || v > 60) stop(sprintf("the reforestation cutoff override is %s years; give 1 to 60", override)); return(rep(v, length(eco))) }
  tab <- data.table::as.data.table(tab); tab[, Ecodivision := as.character(Ecodivision)][!is.na(Ecodivision) & !nzchar(trimws(Ecodivision)), Ecodivision := NA_character_]
  if (anyDuplicated(tab$Ecodivision)) stop("reforestation-cutoff.csv: an Ecodivision appears twice")
  all <- tab[is.na(Ecodivision), as.numeric(Years)]; v <- as.numeric(tab$Years[match(eco, tab$Ecodivision)])
  if (anyNA(v) && !length(all)) stop(sprintf("reforestation-cutoff.csv: no row for %s and no blank Ecodivision row", paste(unique(eco[is.na(v)]), collapse = ", ")))
  v[is.na(v)] <- all[1]; v
}

# The scenario's Reforestation Options (single row; package.xml ReforestationOptions): enabled (blank = TRUE), cutoff override
# (blank = NA: the fitted table), how riparian and savanna BpS read (1 or blank = "forest", 2 = "non-forest")
reforest_options <- function(x) {
  x <- data.table::as.data.table(x); g <- function(k) if (nrow(x) && k %in% names(x)) x[[k]][1] else NA
  en <- g("Enabled"); cy <- suppressWarnings(as.numeric(g("CutoffYears")))
  ra <- g("RiparianAs"); ra <- if (is.character(ra) || is.factor(ra)) c(`forest potential` = 1L, `non-forest potential` = 2L)[tolower(trimws(as.character(ra)))] else suppressWarnings(as.integer(ra))   # (rsyncrosim gives the list label)
  ra <- unname(ra); if (length(ra) && is.na(ra) && is.character(g("RiparianAs")) && nzchar(g("RiparianAs"))) stop(sprintf("Reforestation Options: Riparian and Savanna Read As is %s; use Forest potential or Non-forest potential", g("RiparianAs")))
  if (!is.na(ra) && !ra %in% 1:2) stop(sprintf("Reforestation Options: Riparian and Savanna Read As is %s; use 1 (forest potential) or 2 (non-forest)", ra))
  list(enabled = is.na(en) || isTRUE(as.logical(en)) || identical(toupper(as.character(en)), "YES"),
       cutoff = cy, riparian_as = if (!is.na(ra) && ra == 2L) "non-forest" else "forest")
}

# Which candidate cells reforest (to-do 57 step 4). nl: NLCD codes, one row per candidate cell (natural, not forest at the start,
# forest in some later year), one column per year (first the start year); potential: each cell's BpS potential (bps_potential);
# cutoff: each cell's cutoff (reforest_cutoff); share: the regrowth rule's ForestShare. A cell's first forest is the first year NLCD
# shows forest (41-43) two years running; it must then be forest in at least `share` of the years after (cells that flicker keep
# the any-year rule's forest start, user 2026-11-12). It reforests when that first forest is on BpS non-forest (encroachment), or on
# BpS forest at or after its cutoff (slow recovery). "other" potential (water, fill) keeps the forest start.
# Returns reforest (logical), first (years from the start to the first forest; NA where never two years running) and persistent.
reforest_pick <- function(nl, years, potential, cutoff, share = 2 / 3) {
  nl <- as.matrix(nl); ny <- ncol(nl); n <- nrow(nl); stopifnot(length(years) == ny, length(potential) %in% c(1, n))
  potential <- rep_len(potential, n); cutoff <- rep_len(as.numeric(cutoff), n)
  first <- rep(NA_integer_, n); keep <- rep(FALSE, n); if (!n || ny < 3) return(list(reforest = keep, first = first, persistent = keep))
  f <- nl >= 41 & nl <= 43; f[is.na(f)] <- FALSE
  for (i in seq_len(n)) { r <- f[i, ]; k <- which(r[-ny] & r[-1]); k <- k[k >= 2]
    if (!length(k)) next; t <- k[1]; first[i] <- as.integer(years[t] - years[1]); keep[i] <- mean(r[t:ny]) >= share }
  list(reforest = keep & !is.na(first) & (potential == "non-forest" | (potential == "forest" & first >= cutoff)), first = first, persistent = keep)
}
