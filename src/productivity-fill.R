# =============================================================================
# productivity-fill.R - a productivity multiplier for every land cell, filled from nearby cells that have one (stage 8)
# =============================================================================
# Site Productivity (forest) and Grass and Shrub Productivity each come from data that only covers cells of their own type at the
# start year (TreeMap pixels, RAP NPP of grass and shrub cells). ST-Sim applies a flow spatial multiplier to its flow group wherever a
# cell is in that year, so a cell that becomes forest, grass or shrub later in a run would otherwise grow at 1. The multiplier is a
# property of the site: every other land cell takes the inverse-distance weighted mean (weights 1 / distance^2) of the source cells of
# its own ecodivision within near_km, at the grid's resolution; cells still without one take the same over far_km, on a grid of about
# 1 km; cells with no source cell in reach keep 1 (user decision 2026-11-07, both multipliers).
# No rsyncrosim here: tests/unit-productivity-fill.R sources it.
# =============================================================================

# P: the stratum raster (ecodivision ids; NA off the study area). mult: one value per cell. src: TRUE where mult is the cell's own
# value and may be passed on. fill: TRUE where a value is wanted from the neighbours. Returns list(mult, filled = TRUE where filled)
fill_multiplier <- function(P, mult, src, fill, near_km = 2, far_km = 10) {
  eco <- terra::values(P, mat = FALSE); res_km <- terra::res(P)[1] / 1000
  got <- rep(FALSE, length(mult)); fill <- fill & !src
  idw <- function(n) { d <- sqrt(outer((-n:n)^2, (-n:n)^2, `+`)); ifelse(d <= n + 1e-9, 1 / pmax(d, 0.5)^2, 0) }
  one_pass <- function(r_val, r_one, n) {
    w <- idw(n)
    num <- terra::focal(r_val, w, fun = "sum", na.rm = TRUE); den <- terra::focal(r_one, w, fun = "sum", na.rm = TRUE)
    list(num = num, den = den) }
  for (e in unique(eco[fill & !is.na(eco)])) {
    s <- src & !is.na(eco) & eco == e; t <- fill & !is.na(eco) & eco == e
    if (!any(s)) next
    rv <- terra::setValues(terra::rast(P), ifelse(s, mult, NA)); r1 <- terra::setValues(terra::rast(P), ifelse(s, 1, NA))
    # near: at the grid's resolution
    p <- one_pass(rv, r1, max(1L, round(near_km / res_km)))
    v <- terra::values(p$num, mat = FALSE) / terra::values(p$den, mat = FALSE)
    k <- t & !got & is.finite(v); mult[k] <- v[k]; got[k] <- TRUE
    # far: on a grid of about 1 km (the near pass's cells already done)
    if (any(t & !got) && far_km > near_km) {
      f <- max(1L, round(1 / res_km))
      av <- terra::aggregate(rv * 1, f, fun = "sum", na.rm = TRUE); a1 <- terra::aggregate(r1, f, fun = "sum", na.rm = TRUE)
      av[a1 == 0] <- NA; a1[a1 == 0] <- NA
      q <- one_pass(av, a1, max(1L, round(far_km / (res_km * f))))
      vv <- terra::values(terra::resample(q$num / q$den, terra::rast(P), method = "near"), mat = FALSE)
      k <- t & !got & is.finite(vv); mult[k] <- vv[k]; got[k] <- TRUE } }
  list(mult = mult, filled = got) }
