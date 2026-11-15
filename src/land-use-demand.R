# =============================================================================
# land-use-demand.R - how much land use changes in a projection, beyond the historical years stage 9 draws (Land Use Demand)
# =============================================================================
# User decisions 2026-11-14 (dev/land-use-demand; dev/avoided-conversion/ssp-projections.md). The aim is a wide, logically grounded
# range of what could happen with development under different scenario assumptions - alternative projections, not a prediction.
# Every method ends as the same thing, a ratio per unit and year that multiplies the Urbanization area stage 9 draws from the historical
# record, as it is (a ratio of 1 keeps the reference period's rate). Ag Expansion and Ag Contraction have settings of their own, with
# the methods that need no outside source (high or low years, the custom table): RPA's agriculture does not match Annual NLCD and
# barely changes, and ICLUS models none. Forest Harvest (clearcut and selection) has the same, and the 2020 RPA Assessment's timber
# harvest by region and scenario as a published path.
#   Historical         no ratio
#   Historical high /  each target unit's mean area in its highest (lowest) third of reference years, over its mean in all of them: the
#   low years          range the record itself shows, unit by unit
#   RPA                the 2020 RPA Assessment's urbanization relative to its own 2012-2020 step (Mihiar, Lewis & Coulston 2023,
#                      doi:10.2737/RDS-2023-0026; Data Source RpaLandUseFile): per RCP-SSP pair the mean of its five climate models,
#                      pooled by metropolitan area, the counties outside one by state (RPA's single counties are unreliable: rank
#                      correlation with Annual NLCD 0.53; 0.78 by metropolitan unit, 0.85 by state), or by state
#   ICLUS              EPA ICLUS v2.1.1's new developed land (classes 12-16, suburban and up) relative to its first modelled decade, 2010-2020
#                      (U.S. EPA 2020; Data Source IclusCountyFile, a county table the Data Download makes from the 90 m maps): SSP2-RCP4.5
#                      or SSP5-RCP8.5, the mean of its two climate models, 2020-2100; pooled as RPA (a third of counties have no new
#                      land in the base decade: ICLUS gives none to places that lose people)
#   Population         two levers. How many people: Hauer's (2019) county populations by SSP, 2020-2100 (doi:10.17605/OSF.IO/9YNFC; Data
#                      Source PopulationProjectionFile), as their change from 2020 on the Census 2020 population (Data Source
#                      CensusPopulationFile). How much land each new resident takes: a factor on the base period's (0.5 compact, 1 as
#                      2010-2020, 1.5 sprawl). New developed land a year = c0 x population + c1 x population gain a year (0 where a
#                      county loses people); as a ratio the county's own land per person cancels:
#                        ratio = (P + f x L x gain) / (P_base + L x gain_base),  L = c1 / c0,  base = 2010-2020
#                      L = 176 years, fitted on Annual NLCD and Census estimates of 3,053 counties, 2000-2020 (dev/land-use-demand/
#                      05-population-demand.R: R2 of the levels 0.67; it explains where development is, not how a county's rate changes
#                      from decade to decade, so the county ratios are scenarios). By county (default), metropolitan area or state
#   Custom             the user's own table: a ratio by year for any Stratum Source unit, or everywhere
# Ratios are given at anchor years (the midpoints of the source's steps, 1 at the midpoint of its base period) and interpolated between
# them; after the last anchor the last value is kept (RPA ends in 2070).
# Guards:
#   * a cap (default 3) on the ratio of every method but Custom
#   * RPA, ICLUS: a metropolitan unit (or county) with under DEMAND_MIN_CAL km2 a year of urbanization in the base step (ICLUS: 0.1)
#     takes its state's ratio
#   * Population: a county the tables do not hold (Connecticut's planning regions, a renamed county) takes its state's ratio
#   * a unit no source covers counts as 1
#   * the Target Strata need not be counties: a target unit takes the mean ratio of its cells, each cell having its county's (or custom
#     unit's) ratio and weighing by the group's historical area there. A target unit larger than the pooled units gets one blended ratio
# No SyncroSim here: stage 9 and tests/unit-land-use-demand.R source it.
# =============================================================================

DEMAND_PAIRS <- c("rcp45_ssp1", "rcp85_ssp2", "rcp85_ssp3", "rcp85_ssp5")
DEMAND_CAL <- "2012-2020"; DEMAND_STEPS <- c("2020-2030", "2030-2040", "2040-2050", "2050-2060", "2060-2070")
DEMAND_MID <- c(2016, 2025, 2035, 2045, 2055, 2065)   # RPA: the midpoint of 2012-2020 (ratio 1) and of the five decades
DEMAND_MIN_CAL <- 1          # km2 a year in 2012-2020 below which a metropolitan unit takes its state's ratio
DEMAND_KM2 <- 100 * 0.0040468564   # RPA's hundreds of acres to km2
DEMAND_L <- 176              # years: land per new resident over land per resident a year (dev/land-use-demand/05-population-demand.R)
DEMAND_SSPS <- paste0("SSP", 1:5)
DEMAND_EVERYWHERE <- "(everywhere)"   # the key of a custom row with no unit
DEMAND_METHODS <- c("Historical", "High", "Low", "RPA", "ICLUS", "Population", "Custom")

# the Land Use Demand sheet (single row; blank = the drawn years as they are)
demand_options <- function(x) { v <- function(k, d) if (is.null(x) || !nrow(x) || !k %in% names(x) || is.na(x[[k]][1]) || !nzchar(as.character(x[[k]][1]))) d else x[[k]][1]
  num <- function(k, d) { n <- suppressWarnings(as.numeric(v(k, d))); if (is.na(n) || n < 0) d else n }
  m <- as.character(v("UrbanMethod", "Historical"))
  method <- if (grepl("RPA", m, ignore.case = TRUE)) "RPA" else if (grepl("ICLUS", m, ignore.case = TRUE)) "ICLUS" else if (grepl("^Population", m, ignore.case = TRUE)) "Population" else if (grepl("^Custom", m, ignore.case = TRUE)) "Custom"
            else if (grepl("high", m, ignore.case = TRUE)) "High" else if (grepl("low", m, ignore.case = TRUE)) "Low" else "Historical"
  sc <- as.character(v("UrbanScenario", "RCP8.5-SSP2")); g <- regmatches(sc, regexec("RCP ?([0-9])[.]?([0-9]).*SSP ?([0-9])", sc, ignore.case = TRUE))[[1]]
  pair <- if (length(g) == 4) sprintf("rcp%s%s_ssp%s", g[2], g[3], g[4]) else NA_character_; if (!pair %in% DEMAND_PAIRS) pair <- NA_character_
  ssp <- toupper(regmatches(as.character(v("UrbanSsp", "SSP2")), regexpr("SSP ?[1-5]", as.character(v("UrbanSsp", "SSP2")), ignore.case = TRUE))); ssp <- gsub(" ", "", ssp)
  pl <- as.character(v("UrbanPooling", "")); pool <- if (grepl("^State", pl)) "State" else if (grepl("^Metro", pl)) "Metro" else if (grepl("^County", pl)) "County" else if (method %in% c("RPA", "ICLUS")) "Metro" else "County"
  ic <- toupper(gsub(" ", "", regmatches(as.character(v("UrbanIclus", "SSP2")), regexpr("SSP ?[0-9]", as.character(v("UrbanIclus", "SSP2")), ignore.case = TRUE))))
  cap <- num("UrbanMaxRatio", 3); if (cap <= 0) cap <- 3
  agm <- function(k) { s <- as.character(v(k, "Historical")); if (grepl("^Custom", s, ignore.case = TRUE)) "Custom" else if (grepl("high", s, ignore.case = TRUE)) "High" else if (grepl("low", s, ignore.case = TRUE)) "Low" else "Historical" }
  hm <- as.character(v("HarvestMethod", "Historical")); hs <- as.character(v("HarvestScenario", "RCP8.5-SSP2")); hg <- regmatches(hs, regexec("RCP ?([0-9])[.]?([0-9]).*SSP ?([0-9])", hs, ignore.case = TRUE))[[1]]
  hpair <- if (length(hg) == 4) sprintf("rcp%s%s_ssp%s", hg[2], hg[3], hg[4]) else NA_character_; if (!hpair %in% DEMAND_PAIRS) hpair <- NA_character_
  list(method = method, rpa = method == "RPA", pair = pair, scenario = sc, harvest_pair = hpair,
       ag = list(`Ag Expansion` = agm("AgExpansionMethod"), `Ag Contraction` = agm("AgContractionMethod"), `Forest Harvest` = if (grepl("RPA", hm, ignore.case = TRUE)) "RPA" else agm("HarvestMethod")), ssp = if (length(ssp) == 1 && ssp %in% DEMAND_SSPS) ssp else NA_character_, iclus = if (length(ic) == 1 && ic %in% c("SSP2", "SSP5")) ic else NA_character_,
       # Ag Change (cropland to pasture, pasture to cropland): one method for both directions, and a balance that moves them apart
       # (pasture to cropland times it, cropland to pasture over it; above 1 = more cropland, the more intensive agriculture)
       change = list(method = agm("AgChangeMethod"), balance = { b <- num("AgChangeBalance", 1); if (b <= 0) 1 else b }),
       land = num("LandPerNewResident", 1), weight = num("NewResidentWeight", DEMAND_L), pooling = pool, cap = cap) }

# ---- the common currency: ratios at anchor years to ratios by year ------------------------------------------------------------------
# decade (or step) ratios to the ratio of each year: linear between the anchors `mid` (the first is the base period's midpoint, ratio 1),
# 1 before the first, the last value after the last
demand_by_year <- function(r, years, mid = DEMAND_MID) stats::approx(mid, c(1, as.numeric(r)), xout = years, rule = 2)$y
# a matrix units x steps to units x years
demand_years <- function(ratios, mid, years) { out <- t(apply(ratios, 1, demand_by_year, years = years, mid = mid)); if (length(years) == 1) out <- matrix(out, ncol = 1)
  dimnames(out) <- list(rownames(ratios), years); out }

# the pooled unit of each county (GEOID as a number): the county itself (5 digits), its metropolitan area, else "rest-<state FIPS>", or
# its state FIPS
demand_unit <- function(geoid, crosswalk, pooling) { st <- sprintf("%02d", as.integer(geoid) %/% 1000L)
  if (pooling == "State") return(ifelse(is.na(geoid), NA_character_, st))
  if (pooling == "County") return(ifelse(is.na(geoid), NA_character_, sprintf("%05d", as.integer(geoid))))
  m <- as.character(crosswalk$Id[match(as.integer(geoid), as.integer(crosswalk$Value))])
  ifelse(is.na(geoid), NA_character_, ifelse(is.na(m), paste0("rest-", st), m)) }

# the ratio of each target unit and year. unit_of_cell = the cell's target unit (NA outside the study area), pooled_of_cell = the key of
# its ratio row (demand_unit, or a custom unit), weight = the group's historical area in the cell, ratios = keys x years. A cell whose
# key has no row counts as 1; a target unit without weight takes the plain mean of its cells. Returns target units x years, with
# attributes "missing" (keys without a row), "covered" (the share of the weight whose key has one) and "span" (per target unit, how
# many keys hold its weight)
demand_unit_ratio <- function(unit_of_cell, pooled_of_cell, weight, ratios) {
  ok <- !is.na(unit_of_cell); w <- weight[ok]; w[is.na(w)] <- 0
  d <- data.table::data.table(u = unit_of_cell[ok], p = pooled_of_cell[ok], w = w)[, .(w = sum(w), n = .N), by = .(u, p)]
  d[, w := if (sum(w) > 0) w else as.numeric(n), by = u]
  has <- !is.na(d$p) & d$p %in% rownames(ratios); miss <- sort(unique(d$p[!has & !is.na(d$p)]))
  r <- ratios[match(d$p, rownames(ratios)), , drop = FALSE]; r[is.na(r)] <- 1
  units <- sort(unique(d$u))
  out <- t(vapply(units, function(k) { i <- d$u == k; colSums(r[i, , drop = FALSE] * d$w[i]) / sum(d$w[i]) }, numeric(ncol(ratios))))
  if (ncol(ratios) == 1) out <- matrix(out, ncol = 1)
  dimnames(out) <- list(units, colnames(ratios)); attr(out, "missing") <- miss; attr(out, "covered") <- sum(d$w[has]) / sum(d$w)
  attr(out, "span") <- vapply(units, function(k) sum(d$u == k & d$w > 0), 0L); out }

# ---- Historical high / low years ----------------------------------------------------------------------------------------------
# a = target units x reference years (the areas stage 9 draws from). Each unit's mean over its highest (lowest) `share` of years over
# its mean over all of them; a unit with no area is 1. Constant over the projection
demand_history_ratio <- function(a, which = c("High", "Low"), share = 1 / 3, cap = Inf) { which <- match.arg(which); n <- max(1L, ceiling(ncol(a) * share))
  r <- apply(a, 1, function(v) { m <- mean(v); if (!(m > 0)) return(1); s <- sort(v, decreasing = which == "High"); mean(s[seq_len(n)]) / m })
  pmin(r, cap) }

# ---- RPA ------------------------------------------------------------------------------------------------------------------------
# RPA's urbanization by county and step for one pair, km2 a year, the mean of the pair's climate models. x = the published R list:
# futures ("<climate model>_<pair>") > steps ("2012-2020", "2020-2030" ...) > counties (5-digit FIPS) > a 6 x 6 matrix, rows = the
# use at the start (cr, ps, rg, fr, ur, t2), columns = the use at the end (..., t1), hundreds of acres over the step
demand_rpa_areas <- function(x, pair) {
  # the package's table (defaults/land-use-demand/rpa-county-urbanization.csv, tools/make_land_use_demand_tables.R): the same sums,
  # km2 a year by county and step, a column per future
  if (is.data.frame(x)) { x <- data.table::as.data.table(x); fut <- grep(paste0("_", pair, "$"), names(x), value = TRUE)
    if (!length(fut)) stop(sprintf("the RPA table has no future of pair %s", pair), call. = FALSE)
    steps <- c(DEMAND_CAL, DEMAND_STEPS); miss <- setdiff(steps, unique(x$Step)); if (length(miss)) stop(sprintf("the RPA table lacks the steps %s", paste(miss, collapse = ", ")), call. = FALSE)
    x <- x[Step %in% steps]; out <- data.table::data.table(Fips = sprintf("%05d", as.integer(x$Fips)), Step = x$Step, PerYear = rowMeans(as.matrix(x[, fut, with = FALSE])))
    attr(out, "models") <- length(fut); return(out) }
  fut <- grep(paste0("_", pair, "$"), names(x), value = TRUE); if (!length(fut)) stop(sprintf("the RPA table has no future of pair %s", pair), call. = FALSE)
  steps <- c(DEMAND_CAL, DEMAND_STEPS); miss <- setdiff(steps, names(x[[fut[1]]])); if (length(miss)) stop(sprintf("the RPA table lacks the steps %s", paste(miss, collapse = ", ")), call. = FALSE)
  d <- data.table::rbindlist(lapply(fut, function(s) data.table::rbindlist(lapply(steps, function(st) { m <- simplify2array(unclass(x[[s]][[st]]))
    if (!all(c("cr", "ps", "rg", "fr") %in% rownames(m)) || !"ur" %in% colnames(m)) stop("the RPA table's matrices are not the published 6 x 6 layout (cr, ps, rg, fr, ur)", call. = FALSE)
    yrs <- as.integer(sub(".*-", "", st)) - as.integer(sub("-.*", "", st))
    data.table::data.table(Fips = dimnames(m)[[3]], Step = st, PerYear = colSums(m[c("cr", "ps", "rg", "fr"), "ur", , drop = FALSE], dims = 2) * DEMAND_KM2 / yrs) }))))
  out <- d[, .(PerYear = mean(PerYear)), by = .(Fips, Step)]; attr(out, "models") <- length(fut); out }

# the decade ratios of the pooled units: a matrix units x decades, capped. areas = demand_rpa_areas. A metropolitan unit under min_cal
# km2 a year in 2012-2020 takes the ratio of the state most of its urbanization is in (attribute "fallback" names them); a unit, or
# state, with none is 1. Attribute "calibration" = each unit's km2 a year in 2012-2020
demand_ratios <- function(areas, crosswalk, pooling, cap = 3, min_cal = DEMAND_MIN_CAL, cal_step = DEMAND_CAL, steps = DEMAND_STEPS) {
  a <- data.table::copy(areas); a[, State := substr(Fips, 1, 2)]; a[, Unit := demand_unit(as.integer(Fips), crosswalk, pooling)]
  wide <- function(by) { p <- data.table::dcast(a[, .(PerYear = sum(PerYear)), by = c(by, "Step")], stats::as.formula(paste(by, "~ Step")), value.var = "PerYear", fill = 0)
    cal <- p[[cal_step]]; r <- as.matrix(p[, steps, with = FALSE]) / ifelse(cal > 0, cal, NA_real_); rownames(r) <- p[[by]]; list(r = r, cal = setNames(cal, p[[by]])) }
  u <- wide("Unit"); r <- u$r; fb <- character()
  if (pooling != "State") { s <- wide("State"); home <- a[Step == cal_step, .(v = sum(PerYear)), by = .(Unit, State)][order(-v), .(State = State[1]), by = Unit]
    small <- names(u$cal)[u$cal < min_cal]; st <- home$State[match(small, home$Unit)]
    r[small, ] <- s$r[st, , drop = FALSE]; fb <- small }
  r[is.na(r)] <- 1; r <- pmin(r, cap)
  attr(r, "fallback") <- fb; attr(r, "calibration") <- u$cal; r }

# ---- ICLUS -------------------------------------------------------------------------------------------------------------------------
# EPA ICLUS v2.1.1's new developed land (classes 12-16, suburban and up) by county and decade, for one SSP, km2 a year, the mean of
# its two climate models. tab = the Data Download's county table (Fips, Run "ssp2_rcp45_hadgem2_es" ..., Year = the decade's first
# year, Km2; src/iclus.R). The base is 2010-2020, ICLUS's first modelled decade (its 2000 and 2010 maps are observed, and differ by far
# more than a decade's change). Attributes: "steps" (the later decades), "mid" (2015, then each decade's middle), "models"
DEMAND_ICLUS <- c(SSP2 = "ssp2_rcp45", SSP5 = "ssp5_rcp85"); DEMAND_ICLUS_CAL <- "2010-2020"; DEMAND_ICLUS_MIN_CAL <- 0.1   # km2 a year
demand_iclus_areas <- function(tab, ssp) { if (!ssp %in% names(DEMAND_ICLUS)) stop(sprintf("ICLUS has SSP2 (RCP4.5) and SSP5 (RCP8.5), not %s", ssp), call. = FALSE)
  # (the package's table has a column per run: defaults/land-use-demand/iclus-county-new-developed.csv)
  if (all(c("Fips", "Year") %in% names(tab)) && !"Run" %in% names(tab)) tab <- data.table::melt(data.table::as.data.table(tab), id.vars = c("Fips", "Year"), variable.name = "Run", value.name = "Km2", variable.factor = FALSE)
  if (!all(c("Fips", "Run", "Year", "Km2") %in% names(tab))) stop("the ICLUS county table needs the columns Fips, Run, Year and Km2", call. = FALSE)
  t <- data.table::as.data.table(tab)[grepl(paste0("^", DEMAND_ICLUS[[ssp]], "_"), Run)]; if (!nrow(t)) stop(sprintf("the ICLUS county table has no run of %s", DEMAND_ICLUS[[ssp]]), call. = FALSE)
  if (!2010L %in% t$Year) stop("the ICLUS county table has no 2010-2020 decade (its base)", call. = FALSE)
  out <- t[, .(PerYear = mean(as.numeric(Km2)) / 10), by = .(Fips = sprintf("%05d", as.integer(Fips)), Year = as.integer(Year))][, .(Fips, Step = paste(Year, Year + 10L, sep = "-"), PerYear)]
  yrs <- sort(unique(as.integer(t$Year))); later <- yrs[yrs > 2010L]
  attr(out, "steps") <- paste(later, later + 10L, sep = "-"); attr(out, "mid") <- c(2015, later + 5); attr(out, "models") <- data.table::uniqueN(t$Run); out }

# ---- Forest harvest: the 2020 RPA Assessment's forest products projections --------------------------------------------------------
# Johnston, Guo & Prestemon 2023 (FOROM; doi:10.2737/RDS-2022-0073-2; Data Source RpaForestProductsFolder): one table per RPA scenario
# (Ch7_LM_v2.csv = RCP4.5-SSP1, HM = RCP8.5-SSP2, HL = RCP8.5-SSP3, HH = RCP8.5-SSP5), rows Measurement, Product, Units, Location and a
# column per year. Timber harvest level, total timber, in the table's six U.S. regions, every five years 2020-2070; the regions have no
# history in the table, so the ratio is to 2020, its first projected year. dev/land-use-demand/09-rpa-harvest.R: harvest rises in every
# scenario and region (2070: 1.04 to 1.45 x 2020) and the regions move together, so this is a narrow, demand-driven outlook; a ratio of
# volume on a harvested area takes the volume per hectare as unchanged.
DEMAND_HARVEST_FILE <- c(rcp45_ssp1 = "Ch7_LM_v2.csv", rcp85_ssp2 = "Ch7_HM_v2.csv", rcp85_ssp3 = "Ch7_HL_v2.csv", rcp85_ssp5 = "Ch7_HH_v2.csv")
# the table's six regions by state FIPS (the RPA subregions; the Great Plains states are in Rocky Mountain)
DEMAND_HARVEST_REGIONS <- list(`North East` = c("09", "10", "11", "23", "24", "25", "33", "34", "36", "42", "44", "50", "54"), `North Central` = c("17", "18", "19", "26", "27", "29", "39", "55"),
  `South East` = c("12", "13", "37", "45", "51"), `South Central` = c("01", "05", "21", "22", "28", "40", "47", "48"),
  `Rocky Mountain` = c("04", "08", "16", "20", "30", "31", "32", "35", "38", "46", "49", "56"), `Pacific Coast` = c("06", "41", "53"))
# the RPA region of each county (GEOID as a number), NA outside the conterminous states
demand_harvest_region <- function(geoid) { st <- sprintf("%02d", as.integer(geoid) %/% 1000L); r <- rep(NA_character_, length(st))
  for (k in names(DEMAND_HARVEST_REGIONS)) r[!is.na(geoid) & st %in% DEMAND_HARVEST_REGIONS[[k]]] <- k; r }
# the regions' harvest relative to 2020: a matrix regions x later years, capped; attribute "mid" = the anchor years (2020, then each year)
demand_harvest_ratios <- function(tab, cap = 3) { tab <- data.table::as.data.table(tab)
  if (!all(c("Measurement", "Product", "Location", "2020") %in% names(tab))) stop("the RPA forest products table needs the columns Measurement, Product, Location and the years from 2020", call. = FALSE)
  h <- tab[Measurement == "Timber harvest level" & Product == "total timber" & Location %in% names(DEMAND_HARVEST_REGIONS)]
  miss <- setdiff(names(DEMAND_HARVEST_REGIONS), h$Location); if (length(miss)) stop(sprintf("the RPA forest products table has no total timber harvest for %s", paste(miss, collapse = ", ")), call. = FALSE)
  yrs <- sort(suppressWarnings(as.integer(names(tab)))); yrs <- yrs[!is.na(yrs) & yrs > 2020]; base <- as.numeric(h[["2020"]])
  r <- vapply(as.character(yrs), function(y) as.numeric(h[[y]]) / base, numeric(nrow(h))); r <- matrix(r, nrow = nrow(h), dimnames = list(h$Location, yrs))
  r[!is.finite(r)] <- 1; r <- pmin(r, cap); attr(r, "mid") <- c(2020, yrs); r }
# ---- Population ------------------------------------------------------------------------------------------------------------------
# Hauer's county totals (GEOID, YEAR, SSP1 ... SSP5; the Data Download writes them from the published age-sex-race table) and the Census
# county estimates (co-est2020-alldata.csv: SUMLEV 50, STATE, COUNTY, POPESTIMATE2010, POPESTIMATE2020) as one table per county and
# step: Pm = population at the step's middle, G = its gain a year (0 when it falls), on the Census 2020 population; and the base
# 2010-2020 (Pb, Gb). Attribute "mid" = the anchor years (2015, then each step's middle)
demand_population <- function(hauer, census, ssp) {
  if (!ssp %in% names(hauer)) stop(sprintf("the population projections have no column %s", ssp), call. = FALSE)
  need <- c("SUMLEV", "STATE", "COUNTY", "POPESTIMATE2010", "POPESTIMATE2020"); if (!all(need %in% names(census))) stop(sprintf("the Census county estimates lack %s", paste(setdiff(need, names(census)), collapse = ", ")), call. = FALSE)
  cn <- census[as.integer(census$SUMLEV) == 50, ]; cn <- data.table::data.table(Fips = sprintf("%02d%03d", as.integer(cn$STATE), as.integer(cn$COUNTY)), P10 = as.numeric(cn$POPESTIMATE2010), P20 = as.numeric(cn$POPESTIMATE2020))
  h <- data.table::data.table(Fips = sprintf("%05d", as.integer(hauer$GEOID)), Year = as.integer(hauer$YEAR), H = as.numeric(hauer[[ssp]]))[order(Fips, Year)]
  if (!2020L %in% h$Year) stop("the population projections do not start in 2020", call. = FALSE)
  h <- merge(h, cn, by = "Fips"); h[, P := P20 * H / H[Year == 2020L], by = Fips]
  h[, `:=`(Pm = (P + data.table::shift(P)) / 2, G = pmax(P - data.table::shift(P), 0) / (Year - data.table::shift(Year)), Mid = (Year + data.table::shift(Year)) / 2), by = Fips]
  out <- h[!is.na(Pm), .(Fips, Mid, Pm, G, Pb = (P10 + P20) / 2, Gb = pmax(P20 - P10, 0) / 10)]
  attr(out, "mid") <- c(2015, sort(unique(out$Mid))); out }

# the step ratios of the pooled units, (sum P + land x L x sum gain) / (sum P_base + L x sum gain_base): units x steps, capped. A county
# of the crosswalk's states that the tables lack is covered by demand_fill
demand_population_ratios <- function(pop, crosswalk, pooling, land = 1, L = DEMAND_L, cap = 3) {
  p <- data.table::copy(pop); p[, Unit := demand_unit(as.integer(Fips), crosswalk, pooling)]
  s <- p[, .(Num = sum(Pm) + land * L * sum(G), Den = sum(Pb) + L * sum(Gb)), by = .(Unit, Mid)]
  w <- data.table::dcast(s[, .(Unit, Mid, R = ifelse(Den > 0, Num / Den, 1))], Unit ~ Mid, value.var = "R", fill = 1)
  r <- as.matrix(w[, -1, with = FALSE]); rownames(r) <- w$Unit; r <- pmin(r, cap); attr(r, "mid") <- attr(pop, "mid"); r }

# rows for the units the study area has and the ratios lack, from the state's ratios (a county unit "06061" or "rest-06" -> state "06";
# a metropolitan area code has no state in its name and stays missing). Returns the ratios with the rows added, attribute "filled"
demand_fill <- function(ratios, units_here, state_ratios) { miss <- setdiff(units_here[!is.na(units_here)], rownames(ratios))
  st <- ifelse(grepl("^[0-9]{5}$", miss), substr(miss, 1, 2), ifelse(grepl("^rest-", miss), sub("^rest-", "", miss), NA_character_))
  ok <- !is.na(st) & st %in% rownames(state_ratios); at <- attributes(ratios)
  if (any(ok)) { add <- state_ratios[st[ok], , drop = FALSE]; rownames(add) <- miss[ok]; ratios <- rbind(ratios, add); for (k in setdiff(names(at), c("dim", "dimnames"))) attr(ratios, k) <- at[[k]] }
  attr(ratios, "filled") <- miss[ok]; ratios }

# ---- Custom -----------------------------------------------------------------------------------------------------------------------
# the user's table (Key = a unit's name, or NA for everywhere; Year; Ratio) to keys x years: linear between a key's years, from 1 in the
# historical end year when its first year is later, the last value kept
demand_custom <- function(rows, years, y_end) { rows <- data.table::as.data.table(rows)[!is.na(Year) & !is.na(Ratio)]
  if (!nrow(rows)) stop("the custom multipliers (Land Use Change page) have no row with a year and a multiplier", call. = FALSE)
  if (any(rows$Ratio < 0)) stop("a Land Use Demand ratio cannot be below 0", call. = FALSE)
  rows[is.na(Key) | !nzchar(Key), Key := DEMAND_EVERYWHERE]; if (anyDuplicated(rows[, .(Key, Year)])) stop("the custom multipliers (Land Use Change page) have two rows for one unit and year", call. = FALSE)
  keys <- unique(rows$Key)
  out <- t(vapply(keys, function(k) { x <- rows[Key == k][order(Year)]; yy <- x$Year; rr <- x$Ratio; if (yy[1] > y_end) { yy <- c(y_end, yy); rr <- c(1, rr) }
    if (length(yy) == 1) rep(rr, length(years)) else stats::approx(yy, rr, xout = years, rule = 2)$y }, numeric(length(years))))
  if (length(years) == 1) out <- matrix(out, ncol = 1); dimnames(out) <- list(keys, years); out }
