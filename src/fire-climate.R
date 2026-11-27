# =============================================================================
# fire-climate.R - projected fire that follows climate: each projection year draws its historical fire year among those whose
# fire season was most like its own (to-do 9; user 2026-11-26: "the analog draw is what we should start with")
# =============================================================================
# Burned area by pyrome follows fire-season heat and dryness in the West (dev/fire-climate/01-fire-climate-signal.R: MTBS against PRISM,
# 1984-2023, Spearman 0.44 in the western pyromes, weighted by burned area, for the index used here). LOCA2 has precipitation and
# temperature only, so the index is made of those: the fire season's (May to September) mean daily maximum temperature and its
# precipitation, each a z-score against 1984-2014, summed with the precipitation's sign turned and scaled to one SD.
# The draw: a projection year takes, at random, one of the FIREK$k reference years whose index is nearest its own. A future hotter than
# every reference year draws among the hottest, so burned area rises with the climate up to the worst years on record and not past them.
#
# How it reaches a projection (as drought and insect mortality's two settings, src/mortality.R): a Projection Setup holds no climate and
# serves any number of climate futures, and a scenario takes a whole sheet from the first of its dependencies that has rows (the setup,
# then the Projection Climate result). ST-Sim cannot pick a spatial multiplier map by an external variable, so when the setup's Fire page
# says the fire years come from the Projection Climate result, the setup (stage 9) writes the fire group as
#   * one pattern map: each cell's long-run burned share (its unit's mean burned fraction over the reference years, times the slope
#     selectivity or the burn probability, mean 1 within the unit), and a map of 1 for each severity group;
#   * Transition Multiplier Value rows of type FIRE_CLIMATE read from the Distributions sheet by the external variable FIRE_EV_YEAR (the
#     drawn historical year): on the fire group the study area's burned fraction of that year as a ratio of the reference mean, and on each
#     severity group that year's share of the burned area (the long-run share in a year without fire).
# The Projection Climate result (stage 11) that depends on the setup writes the External Variables sheet: the analog draws, or the setup's
# own random draws (Fire Climate page: As the Projection Setup drew them). In a study area of one fire unit this gives every drawn year
# exactly its burned area and severity mix; with several units the drawn year sets the study area's total and mix, and each unit keeps
# its long-run share of it (which unit burned most in that year is not kept).
# =============================================================================

FIREK <- list(season = 5:9, base = 1984:2014, k = 5L, points = 400L)
FIRE_EV_YEAR <- "Fire: Drawn Year"; FIRE_CLIMATE <- "Fire: Climate"; FIRE_RATE_ALL <- "Fire Rate: Study Area"; FIRE_SEV <- "Fire Severity: "
FIRE_SET <- "Fire: Drawn Year"   # (the setup's own fire draws, copied to the schedule under this name for the Projection Climate result)
FIRE_FREQ <- "Iteration and Timestep"

# The distribution type of a severity group: "Fire: High Severity [Type]" -> "Fire Severity: High". The names ship with the package
# (defaults/stsim), because a stage cannot add a definition to the library while it runs.
fire_severity_type <- function(member) paste0(FIRE_SEV, sub("^.*: ", "", sub(" Severity$", "", sub(" \\[Type\\]$", "", member))))

# The names the lookup needs that the library's definitions lack (character(0) = none missing); the 2.2 library update adds them.
fire_definitions <- function(prj, members) {
  need <- list(core_ExternalVariableType = FIRE_EV_YEAR, core_DistributionType = c(FIRE_RATE_ALL, fire_severity_type(members)), stsim_TransitionMultiplierType = FIRE_CLIMATE)
  unlist(lapply(names(need), function(sh) { miss <- setdiff(need[[sh]], as.character(rsyncrosim::datasheet(prj, sh, optional = TRUE, lookupsAsFactors = FALSE)$Name)); if (length(miss)) sprintf("%s: %s", sh, paste(miss, collapse = ", ")) }))
}

# The Fire page's choice of where the fire years come from (FireOptions.FireYears): TRUE = from the Projection Climate result.
fire_years_from_climate <- function(fo) { v <- if (nrow(fo) && "FireYears" %in% names(fo)) fo$FireYears[1] else NA
  if (is.null(v) || is.na(v)) return(FALSE); identical(suppressWarnings(as.integer(sub(":.*", "", as.character(v)))), 2L) || startsWith(as.character(v), "From") }

# The lookup rows of a setup. ratio: the study area's burned fraction of each reference year over the reference mean (named by year);
# share: severity groups x reference years (each column sums to 1); members: the severity groups; g: the fire group; t0: the first
# projection year.
fire_lookup <- function(ratio, share, members, g, t0) {
  yrs <- as.integer(names(ratio)); stopifnot(length(yrs) > 0, ncol(share) == length(yrs), nrow(share) == length(members))
  st <- fire_severity_type(members)
  tmv <- data.table::data.table(Timestep = t0, StratumId = NA_character_, StateClassId = NA_character_, TransitionGroupId = c(g, members), TransitionMultiplierTypeId = FIRE_CLIMATE,
                                DistributionType = c(FIRE_RATE_ALL, st), DistributionFrequencyId = FIRE_FREQ)
  dv <- data.table::rbindlist(c(list(data.table::data.table(StratumId = NA_character_, DistributionTypeId = FIRE_RATE_ALL, ExternalVariableTypeId = FIRE_EV_YEAR, ExternalVariableMin = yrs, ExternalVariableMax = yrs, Value = signif(as.numeric(ratio), 6))),
    lapply(seq_along(members), function(j) data.table::data.table(StratumId = NA_character_, DistributionTypeId = st[j], ExternalVariableTypeId = FIRE_EV_YEAR, ExternalVariableMin = yrs, ExternalVariableMax = yrs, Value = signif(as.numeric(share[j, ]), 6)))))
  list(tmv = tmv, dv = dv)
}

# The Projection Climate scenario's Fire and Climate page (single row; package.xml FireClimate). Blank = the analog draw of FIREK$k years.
fire_climate_options <- function(x) {
  x <- data.table::as.data.table(x); g <- function(k) if (nrow(x) && k %in% names(x)) x[[k]][1] else NA
  m <- g("FireYears"); m <- if (is.na(m)) 1L else suppressWarnings(as.integer(sub(":.*", "", as.character(m)))); if (is.na(m)) m <- if (startsWith(as.character(g("FireYears")), "As")) 2L else 1L
  k <- suppressWarnings(as.numeric(g("AnalogYears"))); if (is.na(k)) k <- FIREK$k
  if (k < 1 || k != round(k)) stop(sprintf("Fire and Climate: the number of analog years is %s; give a whole number of 1 or more", k))
  list(analog = m == 1L, k = as.integer(k))
}

# Fire-season mean maximum temperature (C) and precipitation (mm) by year from a monthly series (y, m, TX, P).
fire_season <- function(y, m, TX, P, months = FIREK$season) {
  d <- data.table::data.table(y = y, m = m, TX = TX, P = P)[m %in% months]
  d[, .(n = .N, Tmax = mean(TX), Precip = sum(P)), by = y][n == length(months)][, n := NULL][order(y)]
}

# The observed fire seasons (PRISM 800 m monthly maximum temperature and precipitation, the mean over the points lonlat: a matrix of
# longitude and latitude, WGS84) of the given years, as fire_season() does. Needs src/prism.R and terra.
fire_prism_seasons <- function(folder, years, lonlat, months = FIREK$season) {
  fs <- data.table::CJ(y = as.integer(years), m = as.integer(months), v = c("tmax", "ppt"))
  fs[, file := prism_monthly(folder, "800 m", v, y, m)]; miss <- fs[!file.exists(file)]
  if (nrow(miss)) stop(sprintf("Fire and Climate: %d PRISM 800 m monthly grids missing under %s (first: %s); the fire seasons of %d-%d need monthly tmax and ppt. Run a Data Download with PrismFolder", nrow(miss), folder, basename(miss$file[1]), min(years), max(years)), call. = FALSE)
  pv <- NULL
  fs[, val := vapply(file, function(f) { r <- terra::rast(f); if (is.null(pv)) pv <<- terra::vect(terra::project(lonlat, "EPSG:4326", terra::crs(r)), crs = terra::crs(r))
    mean(terra::extract(r, pv, ID = FALSE)[[1]], na.rm = TRUE) }, 0)]
  w <- data.table::dcast(fs, y + m ~ v, value.var = "val")
  if (anyNA(w$tmax) || anyNA(w$ppt)) stop("Fire and Climate: PRISM has no value at the study area's points in some months", call. = FALSE)
  fire_season(w$y, w$m, w$tmax, w$ppt, months)
}

# The index of each year: zT - zP over the base years' mean and SD, scaled to the base years' SD. `base` is a fire_season() table of
# the observed climate (PRISM) over FIREK$base; the result is named by year.
fire_index <- function(s, base) {
  mT <- mean(base$Tmax); sT <- stats::sd(base$Tmax); mP <- mean(base$Precip); sP <- stats::sd(base$Precip)
  if (!is.finite(sT) || sT <= 0 || !is.finite(sP) || sP <= 0) stop("Fire and Climate: the fire season's temperature or precipitation does not vary over the base years")
  raw <- function(d) (d$Tmax - mT) / sT - (d$Precip - mP) / sP; sI <- stats::sd(raw(base))
  stats::setNames(raw(s) / sI, s$y)
}

# A climate run's fire seasons put on the observed scale (the delta method, as stage 11's flow multipliers): temperature shifted by the
# observed base mean less the run's, precipitation scaled by their ratio, so a model's bias drops out. run and obs are fire_season()
# tables; both must cover FIREK$base.
fire_delta <- function(run, obs, base = FIREK$base) {
  rb <- run[y %in% base]; ob <- obs[y %in% base]
  if (nrow(rb) < 10L || nrow(ob) < 10L) stop(sprintf("Fire and Climate: fewer than 10 fire seasons of %d-%d in the climate run or the observed record", min(base), max(base)))
  o <- data.table::copy(run); o[, `:=`(Tmax = Tmax - mean(rb$Tmax) + mean(ob$Tmax), Precip = Precip * mean(ob$Precip) / max(mean(rb$Precip), 1e-9))]; o[]
}

# The analog draw. ip: the index of each projection year (named by year); ih: the index of each reference year (named by year); the
# k nearest reference years of a projection year are its analogs, and each iteration takes one of them at random.
fire_analog_draw <- function(ip, ih, nit, k, seed) {
  hy <- as.integer(names(ih)); k <- min(as.integer(k), length(hy)); set.seed(seed)
  near <- lapply(ip, function(v) hy[order(abs(ih - v), stats::runif(length(ih)))][seq_len(k)])
  d <- data.table::CJ(Iteration = seq_len(nit), Timestep = as.integer(names(ip)))
  d[, HistoricalYear := { a <- near[[as.character(Timestep[1])]]; a[sample.int(length(a), .N, replace = TRUE)] }, by = Timestep]
  data.table::setorder(d, Iteration, Timestep); attr(d, "analogs") <- near; d[]
}

# The External Variables rows of a climate result for fire: the drawn year of every iteration and projection year.
fire_climate_rows <- function(draw) draw[, .(Iteration, Timestep, ExternalVariableTypeId = FIRE_EV_YEAR, ExternalVariableValue = as.numeric(HistoricalYear))]
