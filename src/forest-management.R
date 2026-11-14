# =============================================================================
# forest-management.R - the Forest Management page as changes to a projection's harvest (stage 9); improved forest management
# =============================================================================
# User 2026-11-13: "the easiest to incorporate next would be changes/improved forest management ... change the target areas for
# clearcut and selection (increase selection and reduce clearcut), increase the minimum harvest age"; "Protecting old forest should
# just use the MaxAge field which is complimentary to MinAge for both harvest types". A row is a change to the harvest in its years
# and its place (a unit at any of the three strata levels, blank = any; with spatial tiles every row names a unit of the tile level):
#   - the targets stage 9 drew from the historical harvest maps: a share of clearcut moved to selection (by area, or by volume: a
#     clearcut hectare removes 0.97 of the merchantable wood, a selection hectare 0.5, so a moved hectare becomes 1.94), then a share
#     of selection moved to light selection (Forest Selection 20%, removing 0.2; by volume a hectare becomes 2.5), then every type
#     scaled (HarvestScale: 0.8 = a fifth less harvest, 2 = twice as much).
#   - age windows: a minimum and a maximum stand age per harvest type (clearcut; selection, light selection too), as multipliers of
#     0 outside the window. They can only narrow the Build's pathways (whose minimum ages stage 6 set). Light selection also keeps
#     Forest Selection's minimum ages per forest type (Builds made before it had its own).
# Where a row names a strata level the harvest targets are not keyed on (federal land within a county), the targets of the three
# types move to the combined keys, each target split by its group's historical harvest in the reference years (forest land where none
# was mapped). Everywhere else the drawn targets are unchanged.
# Timber revenue (management_revenue below): what each harvest earns, per unit area harvested, so harvesting less shows as revenue
# given up against the baseline (Compare Runs, Compare Cost Summary): merchantable volume (the Build's curves, by ecodivision, forest
# type and age) x the type's removal share x the region's stumpage price for the type's wood (defaults/forest-management/stumpage.csv,
# softwood or hardwood by forest-type-wood.csv). Written on every projection, baselines included.
# =============================================================================

FM_TYPES <- c(CC = "Forest Harvest: Forest Clearcut", SEL = "Forest Harvest: Forest Selection", LIGHT = "Forest Harvest: Forest Selection 20%")
FM_GROUPS <- setNames(paste0(FM_TYPES, " [Type]"), names(FM_TYPES))
FM_REMOVAL <- c(CC = 0.97, SEL = 0.5, LIGHT = 0.2)   # merchantable wood to the forestry sector (defaults/stockflow/event-pathways.csv)
FM_REVENUE <- "Management Revenue: Harvest Timber"
FM_LV <- c("Primary", "Secondary", "Tertiary")

# the sheet's rows with defaults filled in; NULL with none in the projection
forest_management_rows <- function(fm, y1, pend, say, fail) {
  fm <- data.table::as.data.table(fm); if (!nrow(fm)) return(NULL)
  num <- function(x) suppressWarnings(as.numeric(as.character(x))); or <- function(x, d) if (length(x) == 0 || is.na(x)) d else x
  col <- function(r, k) if (k %in% names(r)) r[[k]] else NA
  rows <- data.table::rbindlist(lapply(seq_len(nrow(fm)), function(i) { r <- fm[i]
    s0 <- max(y1 + 1, or(num(col(r, "StartYear")), y1 + 1)); s1 <- min(pend, or(num(col(r, "EndYear")), pend))
    if (s1 < s0) { say("Forest Management: row %d has no year in the projection (%d-%d): left out", i, y1 + 1, pend); return(NULL) }
    sc <- or(num(col(r, "HarvestScale")), 1); sh <- or(num(col(r, "ClearcutToSelection")), 0); li <- or(num(col(r, "LightSelection")), 0)
    if (sc < 0) fail("Forest Management: row %d's harvest scale must be 0 or more", i)
    if (sh < 0 || sh > 1 || li < 0 || li > 1) fail("Forest Management: row %d's shares must be 0-1", i)
    b <- as.character(col(r, "ShiftBasis")); vol <- !is.na(b) && (grepl("^Vol", b) || identical(b, "2"))
    ag <- vapply(c("ClearcutMinAge", "ClearcutMaxAge", "SelectionMinAge", "SelectionMaxAge"), function(k) num(col(r, k)), 0)
    if (any(ag < 0, na.rm = TRUE)) fail("Forest Management: row %d's ages must be 0 or more", i)
    if (!is.na(ag[1]) && !is.na(ag[2]) && ag[2] < ag[1]) fail("Forest Management: row %d's clearcut ages run backwards (%g to %g)", i, ag[1], ag[2])
    if (!is.na(ag[3]) && !is.na(ag[4]) && ag[4] < ag[3]) fail("Forest Management: row %d's selection ages run backwards (%g to %g)", i, ag[3], ag[4])
    data.table::data.table(Row = i, S0 = s0, S1 = s1, Scale = sc, Shift = sh, ByVolume = vol, Light = li,
                           CcMin = ag[[1]], CcMax = ag[[2]], SelMin = ag[[3]], SelMax = ag[[4]],
                           Primary = as.character(col(r, "StratumId")), Secondary = as.character(col(r, "SecondaryStratumId")), Tertiary = as.character(col(r, "TertiaryStratumId"))) }))
  if (!nrow(rows)) NULL else rows }

# the harvest targets as the rows change them. tt: stage 9's targets (all groups); cells: one row per land cell with its Primary,
# Secondary and Tertiary unit names, forest weight (w_forest) and, per harvest group, its historical harvest (columns named by group);
# lev_col: the level -> column map. Returns the new targets of the three types (projection years) and a summary per row
forest_management_targets <- function(tt, rows, y1, cells, lev_col, tile_lvl, say, fail) {
  if (!is.na(tile_lvl)) { bad <- unique(rows[is.na(get(tile_lvl)), Row])
    if (length(bad)) fail("Forest Management: this projection runs in spatial tiles of %s units, so every row needs a %s unit (rows %s have none)", tile_lvl, tile_lvl, paste(bad, collapse = ", ")) }
  # the harvest targets' own level (stage 9 keys a Target group on one level)
  own <- unique(unlist(lapply(FM_GROUPS[c("CC", "SEL")], function(g) { x <- tt[TransitionGroupId == g & Timestep > y1]
    FM_LV[vapply(FM_LV, function(L) lev_col[[L]] %in% names(x) && any(!is.na(x[[lev_col[[L]]]])), TRUE)] })))
  if (!nrow(tt[TransitionGroupId %in% FM_GROUPS[c("CC", "SEL")] & Timestep > y1])) fail("Forest Management: the projection has no clearcut or selection targets (Projection Transitions: Target)")
  K <- FM_LV[FM_LV %in% unique(c(own, if (!is.na(tile_lvl)) tile_lvl, FM_LV[vapply(FM_LV, function(L) any(!is.na(rows[[L]])), TRUE)]))]
  if (!length(K)) K <- character()
  kc <- function(d) if (length(K)) do.call(paste, c(lapply(K, function(L) d[[L]]), sep = "\r")) else rep("all", nrow(d))
  cells <- data.table::copy(cells); cells[, Key := kc(cells)]; combos <- unique(cells[, c("Key", K), with = FALSE])
  okey <- function(d) if (length(own)) do.call(paste, c(lapply(own, function(L) d[[L]]), sep = "\r")) else rep("all", nrow(d))
  cells[, OKey := okey(cells)]
  # one group's projection targets on the combined keys: each of its own-level targets split by the group's historical harvest
  rekey <- function(g, w) { x <- data.table::copy(tt[TransitionGroupId == g & Timestep > y1])
    if (!nrow(x)) return(data.table::data.table(Iteration = integer(), Timestep = integer(), Key = character(), Amount = numeric()))
    for (L in own) data.table::setnames(x, lev_col[[L]], L, skip_absent = TRUE)
    x[, OKey := okey(x)]
    if (!"Iteration" %in% names(x)) x[, Iteration := NA_integer_]
    if (identical(sort(own), sort(K))) return(x[, .(Iteration, Timestep, Key = OKey, Amount)])
    sh <- data.table::data.table(OKey = cells$OKey, Key = cells$Key, wv = w, fv = cells$w_forest)[, .(w = sum(wv), f = sum(fv)), by = .(OKey, Key)]
    sh[, share := { s <- sum(w); if (s > 0) w / s else if (sum(f) > 0) f / sum(f) else 1 / .N }, by = OKey]
    m <- merge(x[, .(Iteration, Timestep, OKey, Amount)], sh[, .(OKey, Key, share)], by = "OKey", allow.cartesian = TRUE)
    lost <- x[!OKey %in% sh$OKey, sum(Amount)]; if (lost > 0) say("Forest Management: %s targets in %.1f amount units fall outside the study area's units, left out", g, lost)
    m[, .(Amount = sum(Amount * share)), by = .(Iteration, Timestep, Key)] }
  cc <- rekey(FM_GROUPS[["CC"]], cells[[FM_GROUPS[["CC"]]]]); se <- rekey(FM_GROUPS[["SEL"]], cells[[FM_GROUPS[["SEL"]]]])
  if (!length(K) || identical(sort(own), sort(K))) { } else say("Forest Management: harvest targets on %s (each %s target split by its historical harvest)", paste(K, collapse = " x "), paste(own, collapse = " x "))
  # every key, iteration and projection year, with the three types side by side
  it <- unique(c(cc$Iteration, se$Iteration)); yrs <- sort(unique(c(cc$Timestep, se$Timestep)))
  W <- data.table::CJ(Iteration = it, Timestep = yrs, Key = combos$Key)
  W <- merge(W, cc[, .(Iteration, Timestep, Key, CC = Amount)], by = c("Iteration", "Timestep", "Key"), all.x = TRUE)
  W <- merge(W, se[, .(Iteration, Timestep, Key, SEL = Amount)], by = c("Iteration", "Timestep", "Key"), all.x = TRUE)
  W[is.na(CC), CC := 0]; W[is.na(SEL), SEL := 0]; W[, `:=`(CC0 = CC, SEL0 = SEL, LIGHT = 0, Rows = 0L)]
  W <- merge(W, combos, by = "Key", sort = FALSE)
  kv <- FM_REMOVAL[["CC"]] / FM_REMOVAL[["SEL"]]; lv <- FM_REMOVAL[["SEL"]] / FM_REMOVAL[["LIGHT"]]
  for (j in seq_len(nrow(rows))) { r <- rows[j]
    m <- W$Timestep >= r$S0 & W$Timestep <= r$S1
    for (L in FM_LV) if (!is.na(r[[L]])) { if (!L %in% K) fail("internal: level %s not in the keys", L); m <- m & W[[L]] == r[[L]] }
    if (!any(m)) fail("Forest Management: row %d's place (%s) has no land in the study area", r$Row, paste(stats::na.omit(c(r$Primary, r$Secondary, r$Tertiary)), collapse = " / "))
    W[m, Rows := Rows + 1L]
    W[m, `:=`(SEL = SEL + CC * r$Shift * (if (r$ByVolume) kv else 1), CC = CC * (1 - r$Shift))]
    W[m, `:=`(LIGHT = SEL * r$Light * (if (r$ByVolume) lv else 1), SEL = SEL * (1 - r$Light))]
    W[m, `:=`(CC = CC * r$Scale, SEL = SEL * r$Scale, LIGHT = LIGHT * r$Scale)] }
  if (any(W$Rows > 1)) { w <- W[Rows > 1][1]; fail("Forest Management: two rows change the harvest of the same place in %d: give each place and year one row", w$Timestep) }
  out <- data.table::rbindlist(lapply(names(FM_GROUPS), function(k) W[, c("Iteration", "Timestep", K, k), with = FALSE][, TransitionGroupId := FM_GROUPS[[k]]][]), use.names = FALSE)
  data.table::setnames(out, ncol(out) - 1L, "Amount")
  for (L in K) data.table::setnames(out, L, lev_col[[L]])
  if (all(is.na(out$Iteration))) out[, Iteration := NULL]
  where <- function(p, s, t) { w <- paste(stats::na.omit(c(p, s, t)), collapse = " / "); if (nzchar(w)) w else "study area" }
  ny <- function(r) length(unique(W[Timestep >= r$S0 & Timestep <= r$S1, Timestep])) * max(1L, length(unique(W$Iteration)))
  sm <- data.table::rbindlist(lapply(seq_len(nrow(rows)), function(j) { r <- rows[j]; m <- W$Timestep >= r$S0 & W$Timestep <= r$S1
    for (L in FM_LV) if (!is.na(r[[L]])) m <- m & W[[L]] == r[[L]]
    n <- ny(r); ag <- function(a, b) if (is.na(a) && is.na(b)) "Build's" else sprintf("%s-%s", if (is.na(a)) "Build's" else a, if (is.na(b)) "any" else b)
    data.table::data.table(Row = r$Row, Where = where(r$Primary, r$Secondary, r$Tertiary), StartYear = r$S0, EndYear = r$S1,
                           ClearcutBefore = round(sum(W$CC0[m]) / n, 2), ClearcutAfter = round(sum(W$CC[m]) / n, 2),
                           SelectionBefore = round(sum(W$SEL0[m]) / n, 2), SelectionAfter = round(sum(W$SEL[m]) / n, 2), LightSelectionAfter = round(sum(W$LIGHT[m]) / n, 2),
                           ClearcutAges = ag(r$CcMin, r$CcMax), SelectionAges = ag(r$SelMin, r$SelMax),
                           Note = sprintf("scale %g; %g%% of clearcut to selection%s; %g%% of selection to light selection", r$Scale, 100 * r$Shift, if (r$ByVolume) " (by volume)" else "", 100 * r$Light)) }))
  list(targets = out, summary = sm, keys = K) }

# age windows (multipliers: 1 inside, 0 outside) per row and harvest type, from its start year, back to 1 after its end; light selection
# keeps Forest Selection's minimum age per forest type (sel_min: StratumId (ecodivision or NA), StateClassId, AgeMin) where a row moves
# selection to it. lev_col: level -> column
forest_management_ages <- function(rows, y1, pend, sel_min, lev_col) {
  win <- function(a0, a1) { a0 <- if (is.na(a0)) 0 else a0
    d <- data.table::data.table(AgeMin = c(0, a0, if (!is.na(a1)) a1 + 1), AgeMax = c(a0 - 1, if (is.na(a1)) NA else a1, if (!is.na(a1)) NA), Amount = c(0, 1, if (!is.na(a1)) 0))
    d[is.na(AgeMax) | AgeMax >= AgeMin] }
  out <- list()
  for (j in seq_len(nrow(rows))) { r <- rows[j]
    keys <- data.table::data.table(StratumId = r$Primary, SecondaryStratumId = r$Secondary, TertiaryStratumId = r$Tertiary)
    add <- function(g, w, extra = NULL) { if (is.null(w) || !nrow(w)) return()
      x <- cbind(data.table::data.table(Timestep = r$S0, TransitionGroupId = g), keys, w)
      if (!is.null(extra)) for (k in names(extra)) x[, (k) := extra[[k]]]
      out[[length(out) + 1]] <<- x
      if (r$S1 < pend) { z <- cbind(data.table::data.table(Timestep = r$S1 + 1L, TransitionGroupId = g), keys, data.table::data.table(Amount = 1))
        if (!is.null(extra)) for (k in names(extra)) z[, (k) := extra[[k]]]
        out[[length(out) + 1]] <<- z } }
    if (!is.na(r$CcMin) || !is.na(r$CcMax)) add(FM_GROUPS[["CC"]], win(r$CcMin, r$CcMax))
    if (!is.na(r$SelMin) || !is.na(r$SelMax)) add(FM_GROUPS[["SEL"]], win(r$SelMin, r$SelMax))
    if (r$Light > 0) {   # per forest type: the row's selection window, at least Forest Selection's minimum there
      sm <- if (is.null(sel_min) || !nrow(sel_min)) data.table::data.table(StratumId = NA_character_, StateClassId = NA_character_, AgeMin = 0) else sel_min
      if (!is.na(r$Primary)) sm <- sm[is.na(StratumId) | StratumId == r$Primary]
      for (i in seq_len(nrow(sm))) { a0 <- max(c(r$SelMin, sm$AgeMin[i]), na.rm = TRUE)
        ex <- list(StateClassId = sm$StateClassId[i]); if (is.na(r$Primary) && !is.na(sm$StratumId[i])) ex$StratumId <- sm$StratumId[i]
        add(FM_GROUPS[["LIGHT"]], win(a0, r$SelMax), ex) } } }
  if (!length(out)) return(NULL)
  x <- data.table::rbindlist(out, fill = TRUE); x[, names(x)[vapply(x, function(v) !all(is.na(v)), TRUE)], with = FALSE] }

# ---- timber revenue ------------------------------------------------------------------------------------------------------------
FM_BAND <- 10L; FM_BAND_TOP <- 150L   # age bands 0-9, 10-19, ... and 150 and older, valued at their middle age (155 for the last)
forest_management_revenue_defaults <- function(dir, per_ha = 1) {
  st <- data.table::fread(file.path(dir, "stumpage.csv"), na.strings = "")
  wd <- data.table::fread(file.path(dir, "forest-type-wood.csv"), na.strings = "")
  if (!all(c("All") %in% st$Region) || !all(c("Softwood", "Hardwood") %in% st[Region == "All", Wood])) stop("stumpage.csv needs national (Region All) Softwood and Hardwood rows", call. = FALSE)
  list(price = st[, .(Region, Wood, Central, Low, High)], wood = wd[, .(ForestType, Wood)], per_ha = per_ha) }
# rows of stsim_TransitionAttributeValue: Management Revenue: Harvest Timber on the three harvest types, per ecodivision, forest type
# and age band, from y1 + 1. vc: the Build's merchantable volume curves (StratumId, StateClassId, Age, MerchantableVolume m3/ha);
# cost: management_cost_defaults (its region map); eco: the study area's ecodivisions
forest_management_revenue <- function(vc, rev, cost, eco, y1, fixed = FALSE, types = FM_TYPES, removal = FM_REMOVAL) {
  groups <- setNames(paste0(types, " [Type]"), names(types))   # (fuel treatments add their thinning types: src/fuel-treatments.R)
  vc <- data.table::as.data.table(vc)[StratumId %in% eco & !is.na(MerchantableVolume)]
  if (!nrow(vc)) return(NULL)
  ftype <- sub("^[^:]*: ", "", vc$StateClassId); wood <- rev$wood$Wood[match(ftype, rev$wood$ForestType)]; wood[is.na(wood)] <- "Softwood"
  vc[, Wood := wood][, Region := mg_region(cost, StratumId)]
  price <- function(region, w) { p <- rev$price
    one <- function(ww) { r <- p[Region == region & Wood == ww]; if (!nrow(r)) r <- p[Region == "All" & Wood == ww]; unlist(r[1, .(Central, Low, High)]) }
    if (w == "Mixed") (one("Softwood") + one("Hardwood")) / 2 else one(w) }
  bands <- data.table::data.table(AgeMin = seq(0L, FM_BAND_TOP, FM_BAND))[, `:=`(AgeMax = ifelse(AgeMin == FM_BAND_TOP, NA_integer_, AgeMin + FM_BAND - 1L), Mid = AgeMin + FM_BAND %/% 2L)]
  out <- data.table::rbindlist(lapply(split(vc, by = c("StratumId", "StateClassId")), function(d) { d <- d[order(Age)]
    v <- stats::approx(d$Age, d$MerchantableVolume, xout = bands$Mid, rule = 2)$y; pr <- price(d$Region[1], d$Wood[1])
    data.table::rbindlist(lapply(names(types), function(k) { val <- v * removal[[k]] * pr[["Central"]] / rev$per_ha
      b <- lapply(val, function(x) mg_beta(x, pr, fixed))
      data.table::data.table(Timestep = y1 + 1L, StratumId = d$StratumId[1], StateClassId = d$StateClassId[1], TransitionGroupId = groups[[k]],
                             TransitionAttributeTypeId = FM_REVENUE, AgeMin = bands$AgeMin, AgeMax = bands$AgeMax, Value = round(val, 2),
                             DistributionType = vapply(b, `[[`, "", "DistributionType"), DistributionSD = vapply(b, `[[`, 0, "DistributionSD"),
                             DistributionMin = vapply(b, `[[`, 0, "DistributionMin"), DistributionMax = vapply(b, `[[`, 0, "DistributionMax"))[Value > 0] })) }))
  out[, DistributionFrequencyId := ifelse(is.na(DistributionType), NA_character_, "Iteration Only")]
  out[, names(out)[vapply(out, function(x) !all(is.na(x)), TRUE)], with = FALSE] }
