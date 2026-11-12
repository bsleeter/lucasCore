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
