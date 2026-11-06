# =============================================================================
# targets-from-run.R - projection targets from what a historical run realized (stage 9; user decision 2026-11-05)
# =============================================================================
# Projection Options > Targets From Historical Run: each Target group's area per unit and reference year is what that historical run's
# ST-Sim output shows the group did there, so the projection continues at the rate the historical period could reproduce (the mapped area
# also holds change the model cannot place: repeat LCMS flags, cuts below the minimum age, cells whose class has no pathway).
# =============================================================================

# out: the run's stsim_OutputStratumTransition (names, not ids). One matrix per group: units x reference years, in the output's amount
# units (the same as the targets'), the mean over the run's iterations
realized_area <- function(out, group, col, unit_names, units, ref) {
  nit <- max(1L, data.table::uniqueN(out$Iteration))
  x <- out[out$TransitionGroupId == group & out$Timestep %in% ref, list(a = sum(Amount) / nit), by = c(col, "Timestep")]
  M <- matrix(0, length(units), length(ref), dimnames = list(units, ref))
  if (!nrow(x)) return(M)
  i <- match(x[[col]], unit_names); j <- match(x$Timestep, ref); ok <- !is.na(i) & !is.na(j)
  M[cbind(i[ok], j[ok])] <- x$a[ok]
  attr(M, "unmatched") <- sum(x$a[!ok])
  M }
