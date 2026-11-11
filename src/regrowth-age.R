# =============================================================================
# regrowth-age.R - starting age of forest that NLCD shows regrowing (stage 5; to-do 57, user decision 2026-11-11)
# =============================================================================
# Stage 5 starts a natural cell as forest when NLCD shows it as forest in any year. Where the record shows it regrowing - not forest
# at the start, then forest and staying forest - its stand age comes from the record, not from CMS or TreeMap. Those sources dated
# Puget's 1980s clearcuts at about 45 years (TreeMap matches them to older FIA plots in 2016); NLCD shows them as shrub or grass in
# 1985 and forest by about 2000. A cell regrows when:
#   - it is not forest (NLCD 41-43) in the first NonForestYears years of the record;
#   - it is then forest two years running, from year t, less than RegrowthLag years after the start (a later first forest is more
#     likely an open stand filling in than regrowth from a disturbance before the start);
#   - it is forest in at least ForestShare of the years from t to the end of the record (open stands that flicker between forest and
#     shrub or grass in NLCD keep their source age).
# Its age at the start year is RegrowthLag - (t - start year), 1 to RegrowthLag: forest appears in NLCD about
# RegrowthLag years after a stand-replacing disturbance (P26 burns: median 21 years, dev/fire/p26-fire-gap.R).
# Settings: defaults/landcover/regrowth-age.csv.
# =============================================================================

# nl: matrix of NLCD codes, one row per cell, one column per year of the record (first column the start year); years: those years.
# Returns the age at the start year for cells that regrow, NA for the others.
regrowth_age <- function(nl, years, lag = 20, share = 2 / 3, nonforest_years = 2) {
  nl <- as.matrix(nl); ny <- ncol(nl); stopifnot(length(years) == ny)
  out <- rep(NA_integer_, nrow(nl)); if (!nrow(nl) || ny < nonforest_years + 2) return(out)
  f <- nl %in% 41:43; dim(f) <- dim(nl)
  ok <- rowSums(f[, seq_len(nonforest_years), drop = FALSE]) == 0
  for (i in which(ok)) {
    r <- f[i, ]; k <- which(r[-ny] & r[-1]); k <- k[k > nonforest_years]
    if (!length(k)) next
    t <- k[1]; if (years[t] - years[1] >= lag || mean(r[t:ny]) < share) next
    out[i] <- as.integer(min(lag, max(1, lag - (years[t] - years[1]))))
  }
  out
}

regrowth_settings <- function(tab) {
  v <- setNames(as.numeric(tab$Value), tab$Parameter)
  list(lag = unname(v["RegrowthLag"]), share = unname(v["ForestShare"]), nonforest_years = as.integer(v["NonForestYears"]))
}
