# =============================================================================
# co2.R - the CO2 fertilization growth multiplier of the projection years (to-do 46; stage 11)
# =============================================================================
#   multiplier = 1 + beta x ln(CO2_t / CO2_ref), floored at 0
# CO2_t is the SSP's global annual mean (defaults/climate/co2-ssp.csv: Meinshausen et al. 2020, the CMIP6 concentrations, from the
# RCMIP v5.1.0 annual means, Nicholls et al. 2020, doi:10.5281/zenodo.4589756), held at the ceiling when one is set. CO2_ref is the
# CO2 of the Build's historical end year from the same series (or a ppm the user gives): the growth curves are fitted to FIA
# remeasurements that already carry the historical CO2, so only the rise after the historical end counts (user decision 2026-11-05:
# projections only).
# beta comes from defaults/climate/co2-betas.csv (Low / Central / High, the literature review "CO2 fertilization betas for LUCAS",
# accepted 2026-11-06) by the class's vegetation type (co2-classes.csv). Forest classes mix the ECM and AM betas by the class's ECM
# share of live basal area (co2-ecm-share.csv, by ecodivision where FIA has 30+ conditions, else CONUS; tools/make_co2_ecm_share.R)
# and taper with stand age from the young to the mature value (co2-age-bands.csv). A forest class with no ECM share takes the
# "Forest" row at every age. Beta Adjustments rows replace values of the chosen series. No rsyncrosim here: tests source it.
# =============================================================================

CO2_SERIES <- c("None", "Low", "Central", "High")
CO2_BANDS <- function(bands) ifelse(is.na(bands$AgeMax), sprintf("%d+", as.integer(bands$AgeMin)), sprintf("%d-%d", as.integer(bands$AgeMin), suppressWarnings(as.integer(bands$AgeMax))))
CO2_BAND_LABELS <- c("0-25", "26-50", "51-75", "76-100", "101+")

# the Climate page's CO2 Fertilization value (the list's number or its label; blank = Central) as a series name
co2_series_name <- function(v) {
  if (length(v) == 0 || is.na(v) || !nzchar(as.character(v))) return("Central")
  n <- suppressWarnings(as.integer(v)); if (!is.na(n) && n %in% seq_along(CO2_SERIES)) return(CO2_SERIES[n])
  m <- CO2_SERIES[tolower(CO2_SERIES) == tolower(trimws(as.character(v)))]
  if (!length(m)) stop(sprintf("CO2 Fertilization '%s' is not one of %s", v, paste(CO2_SERIES, collapse = ", "))); m }

# CO2 Beta Adjustments age bands (the list's number or label) as band numbers; blank stays NA
co2_band_id <- function(v) { v <- as.character(v); n <- suppressWarnings(as.integer(v)); l <- match(trimws(v), CO2_BAND_LABELS)
  out <- ifelse(!is.na(l), l, n); if (any(!is.na(v) & nzchar(v) & is.na(out))) stop(sprintf("unknown age band: %s", paste(unique(v[!is.na(v) & is.na(out)]), collapse = ", ")))
  as.integer(out) }

# the CO2 of years for an SSP folder code (ssp245 ...), years up to 2014 from the historical series
co2_ppm <- function(tab, code, years) {
  s <- tab[Scenario == code]; if (!nrow(s)) stop(sprintf("no CO2 series for scenario '%s' (have: %s)", code, paste(setdiff(unique(tab$Scenario), "historical"), collapse = ", ")))
  h <- tab[Scenario == "historical"]; v <- ifelse(years <= max(h$Year), h$CO2[match(years, h$Year)], s$CO2[match(years, s$Year)])
  if (anyNA(v)) stop(sprintf("no CO2 for %s in %s", paste(years[is.na(v)], collapse = ", "), code))
  v }

# the yearly series: Timestep, CO2 (ppm), Used (after the ceiling), Ref, LnRatio
co2_series <- function(tab, code, years, ref_year, ref_ppm = NA, cap = NA) {
  ref <- if (!is.na(ref_ppm)) ref_ppm else co2_ppm(tab, code, ref_year)
  c <- co2_ppm(tab, code, years); u <- if (!is.na(cap)) pmin(c, cap) else c
  data.table::data.table(Timestep = as.integer(years), CO2 = c, Used = u, Ref = ref, LnRatio = log(u / ref)) }

# beta of every class x stratum x age band for one series (Low / Central / High).
#   classes: StateClassId, Type, FlowGroupId; strata: names; ecm: StateClassId, StratumId (NA = CONUS), EcmShare
#   adjust (optional): StateClassId, StratumId (NA = every stratum), AgeBand (NA = every band), Beta - applied blank-stratum first,
#   blank band first, so the more specific row wins
co2_betas <- function(classes, strata, series, betas, bands, ecm, adjust = NULL) {
  if (!series %in% CO2_SERIES[-1]) stop(sprintf("CO2 series must be one of %s", paste(CO2_SERIES[-1], collapse = ", ")))
  b <- function(type) { v <- betas[[series]][match(type, betas$Type)]; if (anyNA(v)) stop(sprintf("no %s beta for %s", series, paste(unique(type[is.na(v)]), collapse = ", "))); as.numeric(v) }
  g <- data.table::CJ(StateClassId = classes$StateClassId, StratumId = strata, AgeBand = as.integer(bands$AgeBand), sorted = FALSE)
  g[, `:=`(Type = classes$Type[match(StateClassId, classes$StateClassId)], FlowGroupId = classes$FlowGroupId[match(StateClassId, classes$StateClassId)],
           w = as.numeric(bands$YoungWeight)[match(AgeBand, bands$AgeBand)])]
  e_loc <- ecm[!is.na(StratumId)]; e_us <- ecm[is.na(StratumId)]
  g[, EcmShare := e_loc$EcmShare[match(paste(StateClassId, StratumId), paste(e_loc$StateClassId, e_loc$StratumId))]]
  g[is.na(EcmShare), EcmShare := e_us$EcmShare[match(StateClassId, e_us$StateClassId)]]
  g[Type != "Forest", EcmShare := NA_real_]
  g[, Beta := b(Type[1]), by = Type]
  f <- g$Type == "Forest" & !is.na(g$EcmShare)
  if (any(f)) { s <- g$EcmShare[f]
    young <- s * b("Forest ECM young") + (1 - s) * b("Forest AM young"); mature <- s * b("Forest ECM mature") + (1 - s) * b("Forest AM mature")
    g[f, Beta := mature + w * (young - mature)] }
  g[, Source := data.table::fifelse(f, "ECM share and age", "type")]
  if (!is.null(adjust) && nrow(adjust)) {
    a <- data.table::as.data.table(adjust)[!is.na(StateClassId) & !is.na(Beta)]
    for (lv in list(c(FALSE, FALSE), c(FALSE, TRUE), c(TRUE, FALSE), c(TRUE, TRUE))) {
      s <- a[(!is.na(StratumId)) == lv[1] & (!is.na(AgeBand)) == lv[2]]
      for (i in seq_len(nrow(s))) { r <- s[i]
        hit <- g$StateClassId == r$StateClassId & (is.na(r$StratumId) | g$StratumId == r$StratumId) & (is.na(r$AgeBand) | g$AgeBand == r$AgeBand)
        g[hit, `:=`(Beta = as.numeric(r$Beta), Source = "Beta Adjustments")] } } }
  g[, Beta := round(Beta, 4)]
  g[, .(StateClassId, StratumId, AgeBand, Type, FlowGroupId, EcmShare, Beta, Source)] }

# stsim_FlowMultiplier rows (type "CO2") for the betas and series: a class with one beta everywhere gets blank stratum and age rows,
# one that varies only by age gets blank-stratum band rows, else every stratum x band is written (no blank fallbacks: a specific
# row would hide them)
co2_rows <- function(bt, ser, bands) {
  bt <- data.table::copy(bt)
  bt[, nb := data.table::uniqueN(Beta), by = .(StateClassId, AgeBand)]
  bt[, k := if (data.table::uniqueN(Beta) == 1) "one" else if (all(nb == 1)) "age" else "all", by = StateClassId]
  key <- rbind(unique(bt[k == "one", .(StateClassId, FlowGroupId, StratumId = NA_character_, AgeBand = NA_integer_, Beta)]),
               unique(bt[k == "age", .(StateClassId, FlowGroupId, StratumId = NA_character_, AgeBand, Beta)]),
               bt[k == "all", .(StateClassId, FlowGroupId, StratumId, AgeBand, Beta)])
  key[, `:=`(AgeMin = as.integer(bands$AgeMin)[match(AgeBand, bands$AgeBand)], AgeMax = suppressWarnings(as.integer(bands$AgeMax))[match(AgeBand, bands$AgeBand)])]
  r <- key[rep(seq_len(.N), each = nrow(ser))][, `:=`(Timestep = rep(ser$Timestep, nrow(key)), l = rep(ser$LnRatio, nrow(key)))]
  r[, Value := round(pmax(0, 1 + Beta * l), 4)]
  r[, .(Timestep, StratumId, StateClassId, AgeMin, AgeMax, FlowGroupId, FlowMultiplierTypeId = "CO2", Value)] }
