# =============================================================================
# capacity.R - carbon carrying capacity: the carbon each cell would hold under its potential natural vegetation and natural fire regime
# =============================================================================
# A yardstick for a run's carbon (user, 2026-11-18: "a metric where historical and/or projections for a region can be compared back to
# what the true carbon carrying capacity of the region was"). Decisions taken with the user that day:
#   definition   the natural-regime mean (Keith et al. 2009, doi 10.1073/pnas.0901970106): the mean stock of a landscape of the cell's
#                potential vegetation under its natural stand-replacing fire regime, not the old-growth maximum (kept as an upper bound)
#   source       the model's own tables: stage 4's stock curves and stage 5's return intervals (LANDFIRE FRI), the non-forest classes'
#                steady states, LANDFIRE Biophysical Settings (BpS) as the potential vegetation map. Fixed, computed once in the Build
#   forest type  hybrid: a cell that is forest today keeps its forest type; BpS decides only where land is off its potential:
#                developed and farmed land. Natural grassland, shrubland and barren land keeps its own class (user 2026-11-18: the
#                annual NLCD maps these main groups from satellite observations with relatively high accuracy, while BpS is a modeled
#                product; on Yellowstone BpS read 87.5% of the land as forest potential, NLCD 31% of it as grass and shrub). Carbon
#                Capacity Options can count such land as forest on its BpS forest share instead. A full BpS name -> forest type group
#                crosswalk is
#                to-do 69, to become a user choice
#   pools        live biomass, dead wood and litter (the stock groups Biomass: Total, DOM: Deadwood, DOM: Litter). Soil is left out:
#                the model's soil starts from gNATSGO, which already carries the land's use
# The natural-regime mean of a forest type: its stock by age since a high-severity fire (stage 4's curve, which starts from the limit of
# repeated fire cycles at the return interval) averaged over the ages a landscape holds when a stand burns with the same chance 1 / RI
# every year: P(age = a) = (1 / RI) (1 - 1 / RI)^a, the ages past the curve's last counted at the last.
# Known limits: replacement fire only (no surface fire regime, so dead wood and litter of frequent-fire types are on the high side);
# today's forest type is taken as natural; historical climate (a projection's climate and CO2 do not move the yardstick).
# No rsyncrosim here: tests/unit-capacity.R sources it. Stage 8 (src/8-initial-stocks-spatial.R) builds the maps and tables; the run
# side (capacity_series, capacity_split) is used by stages 13 and 14.
# =============================================================================

CAPACITY_GROUPS <- c(Live = "Biomass: Total", DeadWood = "DOM: Deadwood", Litter = "DOM: Litter")
CAPACITY_FIRE <- "Fire: High Severity [Type]"

# the share of a landscape at each age 0..amax under return interval ri (years); sums to 1, the last age holding every older stand
regime_weights <- function(ri, amax) {
  ri <- max(as.numeric(ri), 1); amax <- as.integer(amax); if (is.na(ri) || is.na(amax) || amax < 0) stop("regime_weights: a return interval and a last age of 0 or more are needed")
  p <- 1 / ri; w <- p * (1 - p)^(0:amax); w[amax + 1L] <- (1 - p)^amax; w }

# the natural-regime mean of stocks given by age. stock: a vector or a matrix (one row per entry of ages, one column per pool);
# ages: the age each row starts at (0, 1, 2 ... or the lower edges of age bins, the first 0); ri: the return interval.
# Returns one value per column
regime_mean <- function(stock, ages, ri) {
  stock <- as.matrix(stock); o <- order(ages); ages <- as.integer(ages[o]); stock <- stock[o, , drop = FALSE]
  if (!length(ages) || ages[1] != 0L) stop("regime_mean: the ages must start at 0")
  amax <- max(ages); w <- regime_weights(ri, amax); row <- findInterval(0:amax, ages)
  colSums(stock[row, , drop = FALSE] * w) }

# The capacity table by ecodivision x class. cv: Initial Stock Curves (StratumId, StateClassId, TransitionGroupId, Age and the pool
# columns); ri: StratumId, StateClassId, ReturnInterval; cols: a named list Live, DeadWood, Litter of the curve columns in each group.
# One row per ecodivision x class with a return interval: ReturnInterval, MeanAge (the regime's mean stand age within the curve), the
# three groups and Capacity (their sum; Mg C/ha), and UpperBound: the same pools at the curve's last age (the old-growth end)
capacity_by_type <- function(cv, ri, cols, last = CAPACITY_FIRE) {
  cv <- data.table::as.data.table(cv); ri <- data.table::as.data.table(ri)
  miss <- setdiff(names(CAPACITY_GROUPS), names(cols)); if (length(miss)) stop(sprintf("capacity_by_type: no curve columns for %s", paste(miss, collapse = ", ")))
  x <- cv[TransitionGroupId == last]; if (!nrow(x)) stop(sprintf("capacity_by_type: the stock curves have no rows after '%s'", last))
  key <- unique(x[, .(StratumId, StateClassId)])
  key[, ReturnInterval := as.numeric(ri$ReturnInterval)[match(paste(StratumId, StateClassId), paste(ri$StratumId, ri$StateClassId))]]
  key <- key[!is.na(ReturnInterval) & ReturnInterval > 0]
  data.table::rbindlist(lapply(seq_len(nrow(key)), function(i) {
    d <- x[StratumId == key$StratumId[i] & StateClassId == key$StateClassId[i]][order(Age)]
    g <- vapply(names(CAPACITY_GROUPS), function(k) rowSums(as.matrix(d[, cols[[k]], with = FALSE])), numeric(nrow(d)))
    m <- regime_mean(g, d$Age, key$ReturnInterval[i]); w <- regime_weights(key$ReturnInterval[i], max(d$Age))
    data.table::data.table(StratumId = key$StratumId[i], StateClassId = key$StateClassId[i], ReturnInterval = key$ReturnInterval[i],
      MeanAge = sum(w * (0:max(d$Age))), Live = m[["Live"]], DeadWood = m[["DeadWood"]], Litter = m[["Litter"]], Capacity = sum(m), UpperBound = sum(g[nrow(g), ])) })) }

# the land cover group of a state class, as the figures name them (run-figures.R's cover_group, with forested wetland under Wetland)
capacity_cover <- function(x) { g <- sub(":.*$", "", x); g[grepl("^Forest", x)] <- "Forest"
  g[!is.na(x) & !g %in% c("Forest", "Disturbed", "Shrubland", "Grassland", "Agriculture", "Developed", "Wetland", "Water")] <- "Barren and other"; g }

# a forest type, a forested wetland type, or a forest type's disturbed class (not a disturbed shrub class)
CAPACITY_SHRUBS <- c("Chaparral", "Sage", "Native Sage Steppe", "Invaded Sage Steppe", "Non-sage")
is_forest_like <- function(x) !is.na(x) & (grepl("^(Forest: |Wetland: .+ Group$)", x) | (startsWith(x, "Disturbed: ") & !sub("^Disturbed: ", "", x) %in% CAPACITY_SHRUBS))

# BpS value -> what the land would carry: "forest", "grass", "shrub", "bare" or "none" (water, ice, not mapped). lookup: bps_lookup()
# (src/reforestation.R: VALUE, GROUPVEG, Potential); groups: defaults/landcover/bps-groups.csv with its NonForestCover column;
# riparian_as: how riparian and savanna BpS read (Reforestation Options): "forest", or "non-forest" (then their NonForestCover)
bps_capacity_cover <- function(lookup, groups, riparian_as = "forest") {
  lookup <- data.table::as.data.table(lookup); groups <- data.table::as.data.table(groups)
  if (!"NonForestCover" %in% names(groups)) stop("bps-groups.csv has no NonForestCover column")
  nf <- groups$NonForestCover[match(lookup$GROUPVEG, groups$GROUPVEG)]; nf[is.na(nf) | !nzchar(nf)] <- "none"
  bad <- setdiff(nf, c("grass", "shrub", "bare", "none")); if (length(bad)) stop(sprintf("bps-groups.csv: NonForestCover '%s' is not grass, shrub, bare or blank", paste(bad, collapse = "', '")))
  ifelse(lookup$Potential == "forest" | (lookup$Potential == "riparian or savanna" & riparian_as == "forest"), "forest", ifelse(lookup$Potential == "other", "none", nf)) }

# Each cell's capacity (Mg C/ha of live biomass, dead wood and litter). One element per cell of every vector:
#   cls      the start-year state class name            own      the class's own capacity where it has one (a forest type's or
#   start    the cell's starting stock of the pools              forested wetland's regime mean, a shrub class's mature stock), else NA
#   forest   the capacity of the forest type the cell would carry (its own type's, or the type it would reach), NA when unknown
#   upper_own, upper_forest   the same at the old-growth end
#   grass, shrub   the capacity of its ecodivision's potential grass and shrub class (NA when unknown)
#   f_forest, f_grass, f_shrub, f_bare   the shares of the cell's BpS pixels of each potential cover (NA without BpS)
#   own_is_forest   own is a forest capacity (a forest type, its disturbed class, a forested wetland)
# Rules (the hybrid choice):
#   a class with a capacity of its own (forest, forested wetland, a shrub class with a mature stock): that
#   disturbed forest (Disturbed: <forest type>): its forest type's (passed as own)
#   developed and agriculture: the BpS mix of forest, grass, shrub and bare over the pixels BpS maps; no mapped pixel: its start stock
#   grassland, shrubland, barren: its own class (own, else its start stock); with natural = "bps", forest on its BpS forest share
#   and its own class on the rest
#   everything else (emergent wetland, water, ice): its start stock
# A part whose capacity is unknown takes the cell's start stock (a deficit of 0 there). Returns capacity, upper, forest_share (the
# share of the cell counted at a forest capacity) and basis (which rule).
CAPACITY_NATURAL <- c(own = "Its own class (annual NLCD)", bps = "LANDFIRE BpS potential")
capacity_cells <- function(cls, start, own, upper_own, forest, upper_forest, grass, shrub, f_forest, f_grass, f_shrub, f_bare, own_is_forest = is_forest_like(cls), natural = "own") {
  if (!natural %in% names(CAPACITY_NATURAL)) stop(sprintf("natural non-forest land counts as 'own' or 'bps', not '%s'", natural))
  n <- length(cls); g <- capacity_cover(cls); z <- function(v) { v <- rep_len(as.numeric(v), n); v[is.na(v)] <- 0; v }
  ff <- z(f_forest); fg <- z(f_grass); fs <- z(f_shrub); fb <- z(f_bare); mapped <- ff + fg + fs + fb
  or <- function(a, b) ifelse(is.na(a), b, a)
  cap <- start; up <- start; fsh <- rep(0, n); basis <- rep("start stock", n)
  # 1 a class with its own capacity
  k <- !is.na(cls) & !is.na(own) & !g %in% c("Developed", "Agriculture", "Grassland", "Shrubland", "Barren and other")
  cap[k] <- own[k]; up[k] <- or(upper_own, own)[k]; fsh[k] <- as.numeric(rep_len(own_is_forest, n)[k] %in% TRUE); basis[k] <- "own class"
  # 2 developed and agriculture: the BpS mix
  k <- !is.na(cls) & g %in% c("Developed", "Agriculture") & mapped > 0
  mix <- function(fo) (ff * or(fo, start) + fg * or(grass, start) + fs * or(shrub, start)) / pmax(mapped, 1e-12)
  cap[k] <- mix(forest)[k]; up[k] <- mix(or(upper_forest, forest))[k]; fsh[k] <- (ff / pmax(mapped, 1e-12))[k] * !is.na(forest[k]); basis[k] <- "BpS mix"
  # 3 natural non-forest: its own class; with natural = "bps", forest on the BpS forest share and the class's own on the rest
  k <- !is.na(cls) & g %in% c("Grassland", "Shrubland", "Barren and other") & !grepl("^(Water|Snow)", cls)
  sh <- if (natural == "bps") ifelse(mapped > 0, ff / pmax(mapped, 1e-12), 0) * !is.na(forest) else rep(0, n); rest <- or(own, start)
  cap[k] <- (sh * or(forest, start) + (1 - sh) * rest)[k]; up[k] <- (sh * or(or(upper_forest, forest), start) + (1 - sh) * or(or(upper_own, own), start))[k]
  fsh[k] <- sh[k]; basis[k] <- ifelse(sh[k] > 0, "forest on its BpS forest share", "own class")
  list(capacity = cap, upper = up, forest_share = fsh, basis = basis) }

# ---- the run side (stages 13 and 14) ----------------------------------------------------------------------------------------
# A run's stock of the capacity pools by year against the capacity. stocks: a run's stock table (Timestep, StockGroup, Mg; load_run's
# X$stocks); capacity, upper: Tg C. Returns Timestep, Stock (Tg C), Capacity, UpperBound, RealisedShare (% of the capacity) and
# Deficit (capacity - stock, Tg C; negative when the land holds more than the capacity)
capacity_series <- function(stocks, capacity, upper = NA_real_) {
  if (is.null(stocks) || !nrow(stocks) || is.na(capacity)) return(NULL)
  s <- data.table::as.data.table(stocks)[StockGroup %in% CAPACITY_GROUPS, .(Stock = sum(Mg) / 1e6, n = data.table::uniqueN(StockGroup)), by = Timestep][order(Timestep)]
  if (!nrow(s) || any(s$n < length(CAPACITY_GROUPS))) return(NULL)
  s[, .(Timestep, Stock, Capacity = capacity, UpperBound = upper, RealisedShare = if (capacity > 0) 100 * Stock / capacity else NA_real_, Deficit = capacity - Stock)] }

# The deficit of one year by cause (Tg C), from maps on the model grid. cls: each cell's state class name that year; stock: its stock
# of the capacity pools (Mg C/ha); capacity, forest_share: the Build's maps; ha: a cell's area.
#   Land use           the cell is developed or agriculture
#   Non-forest cover   natural grassland, shrubland or barren land whose capacity is mostly (half or more) forest: forest at the start
#                      that has since converted, and, with natural = "bps", land BpS maps as forest potential
#   Disturbed land     the cell is in a disturbed class: forest (or shrubland) after a stand-replacing disturbance, waiting to return
#   Live biomass       every other cell (land in its potential cover): its live biomass against the live part of its capacity. For
#                      forest this is stand age and stocking: stands younger, or older, than the natural regime's mean
#   Dead wood and litter   the same cells' dead wood and litter against theirs. Mostly stand age again: the regime's landscape holds
#                      recently burned stands (rich in dead wood) and old ones, a landscape of middle-aged stands neither. In part
#                      the stand's last disturbance: one the Build starts after a clearcut holds less dead wood than one started
#                      after a fire (Yellowstone 2026-11-18: 1.4 of the 5.65 Tg C; fire as every type's last disturbance left 4.25)
# A cause's value is net: cells above their capacity count against it. stock_live, capacity_live: the live biomass part of each.
CAPACITY_CAUSES <- c("Land use", "Non-forest cover", "Disturbed land", "Live biomass", "Dead wood and litter")
CAPACITY_CAUSE_LABELS <- c("Land\nuse", "Non-forest\ncover", "Disturbed\nland", "Live\nbiomass", "Dead wood,\nlitter")   # under the figures' bars
CAPACITY_CAUSE_COLS <- c("DeficitLandUse", "DeficitCover", "DeficitDisturbed", "DeficitLive", "DeficitDead")   # their columns in the run and comparison tables
capacity_split <- function(cls, stock, capacity, forest_share, ha, stock_live, capacity_live) {
  ok <- !is.na(cls) & !is.na(stock) & !is.na(capacity) & !is.na(stock_live) & !is.na(capacity_live); g <- capacity_cover(cls)
  whole <- ifelse(g %in% c("Developed", "Agriculture"), "Land use", ifelse(g %in% c("Grassland", "Shrubland", "Barren and other") & !is.na(forest_share) & forest_share >= 0.5, "Non-forest cover",
                  ifelse(g == "Disturbed", "Disturbed land", NA)))
  d <- (capacity - stock) * ha / 1e6; dl <- (capacity_live - stock_live) * ha / 1e6; rest <- ok & is.na(whole)
  out <- c(vapply(CAPACITY_CAUSES[1:3], function(k) sum(d[ok & whole %in% k]), 0), sum(dl[rest]), sum((d - dl)[rest])); names(out) <- CAPACITY_CAUSES; out }

# The Build's capacity maps as cell vectors. row: its Carbon Capacity Maps row (full paths). Returns the grid (a SpatRaster), each
# cell's capacity, upper bound, forest share and starting stock, a cell's area (ha) and the totals (Tg C); NULL when there is no map
capacity_maps <- function(row) {
  row <- data.table::as.data.table(row)
  f <- function(k) if (nrow(row) && k %in% names(row) && !is.na(row[[k]][1]) && file.exists(row[[k]][1])) row[[k]][1] else NA_character_
  cf <- f("CapacityFileName"); if (is.na(cf)) return(NULL)
  r <- terra::rast(cf); v <- terra::values(r, mat = FALSE); ha <- prod(terra::res(r)) / 1e4
  g <- function(k) { p <- f(k); if (is.na(p)) rep(NA_real_, length(v)) else terra::values(terra::rast(p), mat = FALSE) }
  up <- g("UpperBoundFileName"); tg <- function(x) if (all(is.na(x))) NA_real_ else sum(x, na.rm = TRUE) * ha / 1e6
  list(grid = r, capacity = v, upper = up, forest_share = g("ForestShareFileName"), start = g("StartStockFileName"), live = g("LiveFileName"), ha = ha, total = tg(v), upper_total = tg(up), start_total = tg(g("StartStockFileName"))) }

# One year of a run against the capacity, from its maps. C: capacity_maps(); sc: the year's state class map (path); hl: the paths of the
# year's maps of the three stock groups; sc_list: Id, Name. Returns each cell's stock of the pools and the deficit by cause, or NULL
# when a map is missing or on another grid
capacity_year <- function(C, sc, hl, sc_list) {
  if (is.null(C) || is.null(sc) || is.na(sc) || !file.exists(sc) || length(hl) < length(CAPACITY_GROUPS) || anyNA(hl) || !all(file.exists(hl))) return(NULL)
  s <- terra::rast(sc); if (!isTRUE(terra::compareGeom(s, C$grid, stopOnError = FALSE))) return(NULL)
  if (all(is.na(C$live))) return(NULL)   # (a Build without the live part of the capacity)
  m <- vapply(hl, function(p) terra::values(terra::rast(p), mat = FALSE), numeric(terra::ncell(s))); stock <- rowSums(m)   # hl: live biomass first
  cls <- sc_list$Name[match(terra::values(s, mat = FALSE), sc_list$Id)]
  list(stock = stock, split = capacity_split(cls, stock, C$capacity, C$forest_share, C$ha, m[, 1], C$live)) }

# The comparison table of stage 14: one row per run (R: compare_runs()'s list; C: capacity_maps()). Stock, share and deficit at the
# start and end, the end share against the baseline's, and the end deficit by cause where the run wrote its maps
compare_capacity <- function(R, C) {
  if (is.null(C)) return(NULL)
  S <- lapply(R, function(r) capacity_series(r$X$stocks, C$total, C$upper_total)); if (any(vapply(S, is.null, TRUE))) return(NULL)
  b <- which(vapply(R, function(r) isTRUE(r$base), TRUE))[1]; at <- function(d, y, k) { v <- d[[k]][d$Timestep == y]; if (length(v)) v[1] else NA_real_ }
  be <- at(S[[b]], R[[b]]$X$years[2], "RealisedShare")
  data.table::rbindlist(lapply(seq_along(R), function(i) { r <- R[[i]]; d <- S[[i]]; y0 <- r$X$years[1]; y1 <- r$X$years[2]
    sp <- capacity_year(C, r$X$sc1, r$X$hl1, r$X$sc_list); sp <- if (is.null(sp)) setNames(rep(NA_real_, length(CAPACITY_CAUSES)), CAPACITY_CAUSES) else sp$split
    cbind(data.table::data.table(RunScenarioId = r$rid, Label = r$label, Role = if (r$hist) "History" else if (r$base) "Baseline" else "Run", StartYear = y0, EndYear = y1,
      Capacity = C$total, UpperBound = C$upper_total, StockStart = at(d, y0, "Stock"), StockEnd = at(d, y1, "Stock"), ShareStart = at(d, y0, "RealisedShare"), ShareEnd = at(d, y1, "RealisedShare"),
      DeficitEnd = at(d, y1, "Deficit"), VsBaseline = if (r$hist || r$base || y1 != R[[b]]$X$years[2]) NA_real_ else at(d, y1, "RealisedShare") - be),
      data.table::as.data.table(as.list(setNames(unname(sp), CAPACITY_CAUSE_COLS)))) })) }

# ---- the Build side (stage 8) -----------------------------------------------------------------------------------------------
# a disturbed class's parent, by name: a forest type's disturbed class (Id 2000 + the type's) -> the type; a disturbed shrub class ->
# its shrub class; any other class -> itself. scl: the state class list (Name, Id)
capacity_parent <- function(cls, scl) { id <- as.integer(scl$Id); p <- scl$Name[match(id[match(cls, scl$Name)] - 2000L, id)]
  d <- !is.na(cls) & startsWith(cls, "Disturbed: "); out <- cls; out[d] <- ifelse(is.na(p[d]), sub("^Disturbed: ", "Shrubland: ", cls[d]), p[d]); out }

# Every land cell's capacity, with the tables stage 8 saves. One element per cell of P for land, sname, cname, pname, reach, secondary
# and the multipliers; out: the starting pools (Mg C/ha), one column per stock type named as st$StockTypeId.
#   P          the stratum raster (the grid)            land      TRUE on the study area's cells
#   sname      each cell's ecodivision name             cname     its start-year state class name; pname: capacity_parent() of it
#   st         defaults/initialstocks/stock-types.csv (StockTypeId, Attribute, CurveColumn); membership: stock type -> stock group
#   cv, ri     Initial Stock Curves, and return intervals by StratumId x StateClassId (the first row of a pair counts)
#   steady     the steady non-forest classes' pools (StratumId, StateClassId, StateAttributeTypeId, Value); aged: the same by AgeMin for
#              the classes that grow by age since fire (chaparral, the sage family): their last age is their mature stock
#   regions    defaults/transitions/post-disturbance-regions.csv (Ecodivision, ShrubClass, GrassClass)
#   m_site, m_gs   the site productivity multiplier (times the stocking multiplier when stocking is on: stage 8) and the grass and shrub productivity multiplier of every cell, or NULL (1)
#   reach      the forest type each cell would reach (stage 5's ReforestType, by name), or NULL
#   bps_file   LANDFIRE BpS (30 m), or NA; bps: bps_lookup(); bps_groups: bps-groups.csv; riparian_as: Reforestation Options
#   secondary  each cell's secondary stratum name, or NULL
#   natural    how natural grassland, shrubland and barren land counts: "own" (its own class) or "bps" (capacity_cells)
# Returns capacity, upper, forest_share and start (one value per cell, NA off the land), basis, the table by type (the rows the maps
# use) and the summary by ecodivision x secondary stratum x start cover, and totals (Tg C). Logs through say (sprintf arguments).
capacity_build <- function(P, land, sname, cname, pname, out, st, cv, ri, membership, steady, aged, regions, m_site = NULL, m_gs = NULL, reach = NULL,
                           bps_file = NA, bps = NULL, bps_groups = NULL, riparian_as = "forest", secondary = NULL, natural = "own", say = function(...) message(sprintf(...))) {
  st <- data.table::as.data.table(st); gmb <- data.table::as.data.table(membership); n <- length(land); cell_ha <- prod(terra::res(P)) / 1e4
  one <- function(v) if (is.null(v)) rep(1, n) else { v <- as.numeric(v); v[is.na(v)] <- 1; v }; m_site <- one(m_site); m_gs <- one(m_gs)
  ht <- st[StockTypeId %in% gmb[StockGroupId %in% CAPACITY_GROUPS, StockTypeId]]
  ccols <- lapply(CAPACITY_GROUPS, function(g) st[StockTypeId %in% gmb[StockGroupId == g, StockTypeId] & !is.na(CurveColumn) & nzchar(CurveColumn), CurveColumn])
  ri <- data.table::as.data.table(ri)[!is.na(ReturnInterval) & ReturnInterval > 0]; ri <- ri[!duplicated(paste(StratumId, StateClassId))]
  ct <- capacity_by_type(data.table::as.data.table(cv)[StratumId %in% unique(sname[land])], ri, ccols); ctk <- paste(ct$StratumId, ct$StateClassId)
  start <- rowSums(out[, ht$StockTypeId, drop = FALSE]); start[!land] <- NA
  lt_ <- st[StockTypeId %in% gmb[StockGroupId == CAPACITY_GROUPS[["Live"]], StockTypeId]]; start_l <- rowSums(out[, lt_$StockTypeId, drop = FALSE]); start_l[!land] <- NA
  # each cell's own class: a forest type's regime mean (upland forest times its site productivity multiplier, as its starting stocks are)
  upl <- land & !is.na(pname) & startsWith(pname, "Forest: "); k_own <- match(paste(sname, pname), ctk)
  own <- ct$Capacity[k_own] * ifelse(upl, m_site, 1); up_own <- ct$UpperBound[k_own] * ifelse(upl, m_site, 1)
  own_l <- ct$Live[k_own] * ifelse(upl, m_site, 1)
  # the non-forest classes by ecodivision: the steady classes' starting stock, the aged shrub classes' mature (last age) stock
  sm <- function(x, attrs = ht$Attribute) data.table::as.data.table(x)[StateAttributeTypeId %in% attrs, .(v = sum(as.numeric(Value))), by = .(StratumId, StateClassId)]
  aged <- data.table::as.data.table(aged)
  mature <- aged[, .SD[AgeMin == max(AgeMin)], by = .(StratumId, StateClassId)]
  nfc <- rbind(sm(steady), sm(mature)); nfk <- paste(nfc$StratumId, nfc$StateClassId)
  nfl <- rbind(sm(steady, lt_$Attribute), sm(mature, lt_$Attribute)); nfc[, l := nfl$v[match(nfk, paste(nfl$StratumId, nfl$StateClassId))]][is.na(l), l := 0]
  is_aged <- land & !is.na(pname) & pname %in% unique(aged$StateClassId)
  own[is_aged] <- (nfc$v[match(paste(sname, pname), nfk)] * m_gs)[is_aged]; up_own[is_aged] <- own[is_aged]
  own_l[is_aged] <- (nfc$l[match(paste(sname, pname), nfk)] * m_gs)[is_aged]
  # the grass and shrub class land off its potential would carry: the ecodivision's most common natural one on the map, else the package's
  regions <- data.table::as.data.table(regions)
  pick <- function(prefix, col) { d <- data.table::data.table(e = sname, c = cname)[land & !is.na(cname) & startsWith(cname, prefix) & !grepl("Irrigated", cname), .N, by = .(e, c)][order(-N)][, .SD[1], by = e]
    c1 <- d$c[match(sname, d$e)]; ifelse(is.na(c1), regions[[col]][match(sname, regions$Ecodivision)], c1) }
  k_g <- match(paste(sname, pick("Grassland: ", "GrassClass")), nfk); k_s <- match(paste(sname, pick("Shrubland: ", "ShrubClass")), nfk)
  g_cap <- nfc$v[k_g] * m_gs; s_cap <- nfc$v[k_s] * m_gs; g_l <- nfc$l[k_g] * m_gs; s_l <- nfc$l[k_s] * m_gs
  # the forest type each cell would carry: its own, else the type it would reach, else its ecodivision's most common
  emode <- data.table::data.table(e = sname, c = pname)[upl, .N, by = .(e, c)][order(-N)][, .SD[1], by = e]
  rt <- if (is.null(reach)) rep(NA_character_, n) else as.character(reach)
  rt <- ifelse(upl, pname, ifelse(is.na(rt) | is.na(match(paste(sname, rt), ctk)), emode$c[match(sname, emode$e)], rt)); k_f <- match(paste(sname, rt), ctk)
  f_cap <- ct$Capacity[k_f] * m_site; f_up <- ct$UpperBound[k_f] * m_site
  f_l <- ct$Live[k_f] * m_site
  # potential cover: the share of each cell's 30 m BpS pixels that would be forest, grass, shrub or bare
  fsh <- list(NA, NA, NA, NA)
  if (is.null(bps_file) || is.na(bps_file) || !file.exists(bps_file)) say("Carbon capacity: no LANDFIRE BpS (Data Sources: BpsFile; a Data Download fetches it): developed and farmed land keeps its starting stock as its capacity, and natural non-forest land its own class's") else {
    b30 <- terra::rast(bps_file); levels(b30) <- NULL; b30 <- terra::crop(b30, terra::project(terra::as.polygons(terra::ext(P) + 1000, crs = terra::crs(P)), terra::crs(b30)), snap = "out")
    kc <- match(bps_capacity_cover(bps, bps_groups, riparian_as), c("forest", "grass", "shrub", "bare"))
    b30 <- terra::classify(b30, cbind(as.integer(bps$VALUE), ifelse(is.na(kc), 0L, kc)), others = 0L)
    fsh <- lapply(1:4, function(k) terra::values(terra::project((b30 == k) * 1, P, method = "average"), mat = FALSE))
    say("Carbon capacity: potential cover of the land (LANDFIRE BpS): forest %.1f%%, grass %.1f%%, shrub %.1f%%, bare %.1f%%, not mapped %.1f%%", 100 * mean(fsh[[1]][land], na.rm = TRUE), 100 * mean(fsh[[2]][land], na.rm = TRUE),
        100 * mean(fsh[[3]][land], na.rm = TRUE), 100 * mean(fsh[[4]][land], na.rm = TRUE), 100 * (1 - mean(Reduce(`+`, lapply(fsh, function(v) ifelse(is.na(v), 0, v)))[land]))) }
  say("Carbon capacity: natural grassland, shrubland and barren land counts as %s (Carbon Capacity Options)", if (natural == "bps") "forest on the share of its pixels LANDFIRE BpS maps as forest potential, its own class on the rest" else "its own class, as the annual NLCD maps it")
  cc <- capacity_cells(cname, start, own, up_own, f_cap, f_up, g_cap, s_cap, fsh[[1]], fsh[[2]], fsh[[3]], fsh[[4]], own_is_forest = is_forest_like(pname), natural = natural)
  capv <- ifelse(land, cc$capacity, NA); upv <- ifelse(land, pmax(cc$upper, cc$capacity), NA); fshv <- ifelse(land, cc$forest_share, NA)
  # the live biomass part of the capacity: the same rules on the live pools alone (they are linear in the stocks)
  livev <- ifelse(land, capacity_cells(cname, start_l, own_l, own_l, f_l, f_l, g_l, s_l, fsh[[1]], fsh[[2]], fsh[[3]], fsh[[4]], own_is_forest = is_forest_like(pname), natural = natural)$capacity, NA)
  no_own <- land & is_forest_like(pname) & is.na(own)
  if (any(no_own)) say("Carbon capacity: %d forest cells have no return interval or stock curve for their ecodivision and type (%s); their capacity is their starting stock",
                       sum(no_own), paste(utils::head(unique(paste(sname, pname)[no_own]), 3), collapse = "; "))
  tg <- function(v) sum(v[land], na.rm = TRUE) * cell_ha / 1e6
  say("Carbon capacity (live biomass, dead wood and litter under potential natural vegetation and its natural fire regime): %.2f Tg C, upper bound %.2f (old growth); the land starts with %.2f Tg C, %.0f%% of its capacity",
      tg(capv), tg(upv), tg(start), 100 * tg(start) / tg(capv))
  bs <- data.table::data.table(b = cc$basis, cap = capv, s = start)[land, .(Cells = .N, Cap = sum(cap) * cell_ha / 1e6, Start = sum(s) * cell_ha / 1e6), by = b][order(-Cells)]
  for (i in seq_len(nrow(bs))) say("  %s: %d cells, capacity %.2f Tg C, starting stock %.2f", bs$b[i], bs$Cells[i], bs$Cap[i], bs$Start[i])
  d0 <- capacity_split(cname, start, capv, fshv, cell_ha, start_l, livev)
  say("Carbon capacity: the starting deficit of %.2f Tg C by cause: %s", tg(capv) - tg(start), paste(sprintf("%s %+.2f", names(d0), d0), collapse = ", "))
  csum <- data.table::data.table(StratumId = sname, SecondaryStratumId = if (is.null(secondary)) NA_character_ else secondary, Cover = capacity_cover(cname), cap = capv, up = upv, s = start)[land,
    .(Cells = .N, MeanCapacity = round(mean(cap), 2), MeanStart = round(mean(s), 2), Capacity = round(sum(cap) * cell_ha / 1e6, 4), UpperBound = round(sum(up) * cell_ha / 1e6, 4),
      StartStock = round(sum(s) * cell_ha / 1e6, 4)), by = .(StratumId, SecondaryStratumId, Cover)]
  csum[, RealisedShare := ifelse(Capacity > 0, round(100 * StartStock / Capacity, 1), NA_real_)]; data.table::setorder(csum, StratumId, SecondaryStratumId, -Capacity)
  used <- data.table::data.table(k = c(paste(sname, pname)[land & !is.na(k_own) & !is_aged], paste(sname, rt)[land & !upl & !is.na(fshv) & fshv > 0 & !is.na(k_f)]))[, .(Cells = .N), by = k]
  ctw <- ct[ctk %in% used$k]; ctw[, Cells := used$Cells[match(paste(StratumId, StateClassId), used$k)]]
  list(capacity = capv, upper = upv, forest_share = fshv, start = start, basis = cc$basis, total = tg(capv), upper_total = tg(upv), start_total = tg(start), split = d0, live = livev,
       type = ctw[order(StratumId, -Cells), .(StratumId, StateClassId, Cells, ReturnInterval = as.integer(round(ReturnInterval)), MeanAge = round(MeanAge, 1), Live = round(Live, 2), DeadWood = round(DeadWood, 2),
                                              Litter = round(Litter, 2), Capacity = round(Capacity, 2), UpperBound = round(UpperBound, 2))],
       summary = csum[, .(StratumId, SecondaryStratumId, Cover, Cells, MeanCapacity, MeanStart, Capacity, UpperBound, StartStock, RealisedShare)]) }

# Carbon Capacity Options' Natural Non-Forest Land (single row; 1 or blank = its own class, 2 = LANDFIRE BpS potential; rsyncrosim gives
# the list label) as "own" or "bps"
capacity_natural <- function(opt) { opt <- data.table::as.data.table(opt); v <- if (nrow(opt) && "NaturalNonForest" %in% names(opt)) opt$NaturalNonForest[1] else NA
  if (is.na(v) || !nzchar(as.character(v))) return("own"); v <- as.character(v)
  if (v %in% c("1", CAPACITY_NATURAL[["own"]])) "own" else if (v %in% c("2", CAPACITY_NATURAL[["bps"]])) "bps" else stop(sprintf("Carbon Capacity Options: Natural Non-Forest Land is '%s'; use %s", v, paste(CAPACITY_NATURAL, collapse = " or "))) }
