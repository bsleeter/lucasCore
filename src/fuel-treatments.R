# =============================================================================
# fuel-treatments.R - the Fuel Treatments page as ST-Sim targets and multipliers (stage 9)
# =============================================================================
# User 2026-11-13: "Next is Fuel Treatments"; the effect: "Lets go with the severity shift". A row is a treatment (mechanical
# thinning, prescribed burn, thin and burn), its years, an area a year (or a budget), a place (a unit at any of the three strata
# levels; with spatial tiles every row names a unit of the tile level), and for each treatment a stand-age window, a retreatment
# interval and a priority. The types act on live upland forest (tools/make_fuel_treatments.R); stage 6 gave each a zero target.
#   - Targets: on one set of strata keys (the tile level and the levels rows name), every unit combination every projection year,
#     zero where no row applies; a row's area spread over its combinations by their upland forest land (management.R's way).
#   - Time since treatment: each type's own [Type] group is a TST group (stsim_TimeSinceTransitionGroup), reset to 0 by the treatment;
#     an untreated cell's clock stays at its maximum, so no window below matches it.
#   - The severity shift: for a wildfire in a treated cell, multipliers on Fire: High and Medium Severity (< 1) and Low Severity (> 1)
#     by years since the treatment (defaults/fuel-treatments/effects.csv). The low-severity multiplier is set so the expected burned
#     area stays: 1 + ((1 - mH) sH + (1 - mM) sM) / sL, with s the study area's historical burned shares by severity. ST-Sim takes the
#     first multiplier row a cell matches, so the most effective treatment's rows come first (thin and burn, burn, thinning).
#   - Age window and retreatment: per treatment type (one each), multipliers on its [Type] group: 0 while its own clock is under the
#     retreatment interval, then 0 outside the stand-age window. The TST rows come first (an untreated cell matches none of them).
#   - Priority: random, or more likely where wildfire has burned more often (the historical fire maps over the reference years: a
#     spatial multiplier, 0.1 + frequency, scaled to mean 1 over the eligible cells).
#   - Costs: Management Cost: Fuel Treatment (USD per unit area, by region, a Beta per iteration, management.R's machinery); thinning's
#     merchantable wood earns the harvest timber revenue (forest-management.R).
# =============================================================================

FT_TYPES <- c(Thin = "Fuel Treatment: Mechanical Thinning", Burn = "Fuel Treatment: Prescribed Burn", ThinBurn = "Fuel Treatment: Thin and Burn")
FT_GROUPS <- setNames(paste0(FT_TYPES, " [Type]"), names(FT_TYPES))
FT_ORDER <- c("ThinBurn", "Burn", "Thin")   # the most effective first (ST-Sim's first matching multiplier row)
FT_SEV <- c(High = "Fire: High Severity [Type]", Medium = "Fire: Medium Severity [Type]", Low = "Fire: Low Severity [Type]")
FT_COST <- "Management Cost: Fuel Treatment"
FT_DEFAULT <- list(MinAge = c(Thin = 20, Burn = 20, ThinBurn = 20), Retreat = c(Thin = 15, Burn = 5, ThinBurn = 10))   # replaced by the defaults file when present

ft_key <- function(x) { x <- as.character(x)
  k <- ifelse(grepl("thin and|thinburn|^3$", x, ignore.case = TRUE), "ThinBurn", ifelse(grepl("burn|^2$", x, ignore.case = TRUE), "Burn", ifelse(grepl("thin|^1$", x, ignore.case = TRUE), "Thin", NA_character_))); k }

fuel_treatment_rows <- function(ft, y1, pend, say, fail, defaults = NULL) {
  ft <- data.table::as.data.table(ft); if (!nrow(ft)) return(NULL)
  num <- function(x) suppressWarnings(as.numeric(as.character(x))); or <- function(x, d) if (length(x) == 0 || is.na(x)) d else x
  col <- function(r, k) if (k %in% names(r)) r[[k]] else NA
  d <- if (is.null(defaults)) FT_DEFAULT else defaults
  rows <- data.table::rbindlist(lapply(seq_len(nrow(ft)), function(i) { r <- ft[i]; k <- ft_key(col(r, "TreatmentId"))
    if (is.na(k)) fail("Fuel Treatments: row %d has no treatment (Mechanical thinning, Prescribed burn, Thin and burn)", i)
    a <- num(col(r, "Amount")); bud <- num(col(r, "Budget"))
    if (!is.na(a) && !is.na(bud)) fail("Fuel Treatments: row %d gives both an area a year and a budget: give one", i)
    if (is.na(bud) && (is.na(a) || a < 0)) fail("Fuel Treatments: row %d needs an area a year (0 or more) or a budget", i)
    s0 <- max(y1 + 1, or(num(col(r, "StartYear")), y1 + 1)); s1 <- min(pend, or(num(col(r, "EndYear")), pend))
    if (s1 < s0) { say("Fuel Treatments: row %d has no year in the projection: left out", i); return(NULL) }
    a0 <- or(num(col(r, "MinAge")), d$MinAge[[k]]); a1 <- num(col(r, "MaxAge")); re <- or(num(col(r, "Retreatment")), d$Retreat[[k]])
    if (!is.na(a1) && a1 < a0) fail("Fuel Treatments: row %d's stand ages run backwards (%g to %g)", i, a0, a1)
    if (re < 0) fail("Fuel Treatments: row %d's retreatment interval must be 0 or more", i)
    pri <- if (grepl("^Fire|^2$", as.character(col(r, "Priority")))) "Fire likelihood" else "Random"
    data.table::data.table(Row = i, Key = k, Type = FT_TYPES[[k]], S0 = s0, S1 = s1, A = a, Budget = bud, A0 = a0, A1 = a1, Retreat = re, Priority = pri,
                           Primary = as.character(col(r, "StratumId")), Secondary = as.character(col(r, "SecondaryStratumId")), Tertiary = as.character(col(r, "TertiaryStratumId")),
                           Cost = num(col(r, "Cost")), CostRange = as.character(col(r, "CostRange"))) }))
  if (!nrow(rows)) return(NULL)
  w <- unique(rows[, .(Key, A0, A1, Retreat, Priority)]); if (anyDuplicated(w$Key)) fail("Fuel Treatments: every %s row needs the same stand ages, retreatment interval and priority", FT_TYPES[[w$Key[duplicated(w$Key)][1]]])
  rows }

# costs per row (central, per amount unit) and the attribute values; defaults: management_cost_defaults-like list (values with Item =
# the treatment name, Region), regions from the management cost map
fuel_treatment_costs <- function(rows, ftc, cost, prim_units, fail) {
  prim_units <- unique(prim_units); reg <- mg_region(cost, prim_units); per_unit <- length(unique(reg)) > 1
  dflt <- function(region, k) { v <- ftc[Region == region & Treatment == k]; if (!nrow(v)) v <- ftc[Region == "All" & Treatment == k]
    if (!nrow(v)) fail("Fuel Treatments: no default cost for %s", FT_TYPES[[k]]); unlist(v[1, .(Central, Low, High)]) }
  out <- list(); cpa <- numeric(nrow(rows))
  for (j in seq_len(nrow(rows))) { r <- rows[j]; fixed <- isTRUE(grepl("^Fixed", r$CostRange)) || identical(r$CostRange, "2")
    units <- if (!is.na(r$Primary)) r$Primary else if (per_unit) prim_units else NA_character_
    tot <- 0
    for (u in units) { rg <- if (is.na(u)) reg[1] else mg_region(cost, u); d <- dflt(rg, r$Key); v <- if (is.na(r$Cost)) d[["Central"]] else r$Cost
      b <- mg_beta(v, d, fixed); tot <- tot + v / length(units)
      out[[length(out) + 1]] <- data.table::data.table(Row = r$Row, Timestep = r$S0, S1 = r$S1, StratumId = u, SecondaryStratumId = r$Secondary, TertiaryStratumId = r$Tertiary,
        TransitionGroupId = FT_GROUPS[[r$Key]], TransitionAttributeTypeId = FT_COST, Value = round(v, 4), DistributionType = b$DistributionType,
        DistributionSD = b$DistributionSD, DistributionMin = b$DistributionMin, DistributionMax = b$DistributionMax) }
    cpa[j] <- tot }
  a <- data.table::rbindlist(out, fill = TRUE)
  a[, k := paste(TransitionGroupId, StratumId, SecondaryStratumId, TertiaryStratumId)]
  for (kk in unique(a$k)) { z <- a[k == kk][order(Timestep)]; if (nrow(z) > 1) for (j in 2:nrow(z)) if (z$Timestep[j] <= max(z$S1[1:(j - 1)]) && any(z$Value[1:(j - 1)][z$S1[1:(j - 1)] >= z$Timestep[j]] != z$Value[j]))
    fail("Fuel Treatments: rows %d and %d treat the same place in the same years at different costs", z$Row[j - 1], z$Row[j]) }
  v <- unique(a[, .(Timestep, StratumId, SecondaryStratumId, TertiaryStratumId, TransitionGroupId, TransitionAttributeTypeId, Value, DistributionType,
                    DistributionFrequencyId = ifelse(is.na(DistributionType), NA_character_, "Iteration Only"), DistributionSD, DistributionMin, DistributionMax)])
  list(values = v[, names(v)[vapply(v, function(x) !all(is.na(x)), TRUE)], with = FALSE], per_area = cpa) }

# targets, multipliers, the TST groups, a summary. cells: one row per land cell (Primary, Secondary, Tertiary names, w = eligible upland
# forest 0/1); effects: TreatmentKey, TSTMin, TSTMax, High, Medium; shares: the historical burned shares (High, Medium, Low)
fuel_treatment_targets <- function(rows, y0, y1, pend, cells, lev_col, tile_lvl, effects, shares, say, fail, costs = NULL) {
  LV <- c("Primary", "Secondary", "Tertiary")
  if (!is.na(tile_lvl)) { bad <- unique(rows[is.na(get(tile_lvl)), Row])
    if (length(bad)) fail("Fuel Treatments: this projection runs in spatial tiles of %s units, so every row needs a %s unit (rows %s have none)", tile_lvl, tile_lvl, paste(bad, collapse = ", ")) }
  if (!is.null(costs)) { rows <- data.table::copy(rows)[, CostPerArea := costs$per_area]
    b <- !is.na(rows$Budget); if (any(b)) { if (any(!(rows$CostPerArea[b] > 0))) fail("Fuel Treatments: a budget needs a cost per area")
      rows[b, A := Budget / CostPerArea] } } else if (any(!is.na(rows$Budget))) fail("Fuel Treatments: a budget needs the cost defaults")
  K <- LV[LV %in% unique(c(if (!is.na(tile_lvl)) tile_lvl, LV[vapply(LV, function(L) any(!is.na(rows[[L]])), TRUE)]))]
  cells <- data.table::copy(cells); cells[, Key := if (length(K)) do.call(paste, c(lapply(K, function(L) cells[[L]]), sep = "\r")) else "all"]
  combos <- unique(cells[, c("Key", K), with = FALSE])
  alloc <- data.table::rbindlist(lapply(rows$Row, function(i) { r <- rows[Row == i]
    m <- (is.na(r$Primary) | cells$Primary == r$Primary) & (is.na(r$Secondary) | cells$Secondary == r$Secondary) & (is.na(r$Tertiary) | cells$Tertiary == r$Tertiary)
    if (!any(m)) fail("Fuel Treatments: row %d's place has no land in the study area", i)
    x <- cells[m, .(w = sum(w), n = .N), by = Key]; if (sum(x$w) > 0) x[, f := w / sum(w)] else x[, f := n / sum(n)]
    x[, .(Row = i, Key, f)] }))
  yrs <- (y1 + 1):pend
  tt <- data.table::rbindlist(lapply(names(FT_TYPES), function(k) { rr <- rows[Key == k]
    yr <- data.table::rbindlist(lapply(yrs, function(y) { act <- rr[S0 <= y & S1 >= y]
      a <- if (nrow(act)) merge(alloc, act[, .(Row, A)], by = "Row")[, .(Amount = sum(A * f)), by = Key] else data.table::data.table(Key = character(), Amount = numeric())
      merge(combos[, .(Key)], a, by = "Key", all.x = TRUE)[is.na(Amount), Amount := 0][, Timestep := y] }))
    rbind(combos[, .(Key, Amount = 0, Timestep = y0)], yr)[, TransitionGroupId := FT_GROUPS[[k]]] }))
  tt <- merge(tt, combos, by = "Key", sort = FALSE)[, Key := NULL]; for (L in K) data.table::setnames(tt, L, lev_col[[L]])
  # the severity shift, by time since each treatment used, the most effective first
  used <- FT_ORDER[FT_ORDER %in% unique(rows$Key)]
  sh <- shares / sum(shares); if (!(sh[["Low"]] > 0)) sh[["Low"]] <- 1e-6
  sev <- data.table::rbindlist(lapply(used, function(k) { e <- effects[TreatmentKey == k]
    if (!nrow(e)) fail("Fuel Treatments: no severity effects for %s (defaults/fuel-treatments/effects.csv)", FT_TYPES[[k]])
    lo <- 1 + ((1 - e$High) * sh[["High"]] + (1 - e$Medium) * sh[["Medium"]]) / sh[["Low"]]
    data.table::rbindlist(lapply(names(FT_SEV), function(s) data.table::data.table(Timestep = y1 + 1L, TransitionGroupId = FT_SEV[[s]], TSTGroupId = FT_GROUPS[[k]],
      TSTMin = e$TSTMin, TSTMax = e$TSTMax, Amount = round(switch(s, High = e$High, Medium = e$Medium, Low = lo), 4)))) }))
  # retreatment first (an untreated cell's clock matches none), then the stand-age window
  win <- data.table::rbindlist(lapply(used, function(k) { r <- rows[Key == k][1]; g <- FT_GROUPS[[k]]
    re <- if (r$Retreat > 0) data.table::data.table(Timestep = y1 + 1L, TransitionGroupId = g, TSTGroupId = g, TSTMin = 0L, TSTMax = as.integer(r$Retreat - 1), Amount = 0) else NULL
    ag <- data.table::data.table(AgeMin = c(0, r$A0, if (!is.na(r$A1)) r$A1 + 1), AgeMax = c(r$A0 - 1, if (is.na(r$A1)) NA else r$A1, if (!is.na(r$A1)) NA), Amount = c(0, 1, if (!is.na(r$A1)) 0))[is.na(AgeMax) | AgeMax >= AgeMin]
    rbind(re, cbind(data.table::data.table(Timestep = y1 + 1L, TransitionGroupId = g), ag), fill = TRUE) }), fill = TRUE)
  tst <- data.table::data.table(TransitionTypeId = FT_TYPES[used], TransitionGroupId = FT_GROUPS[used])
  where <- function(p, s, t) { w <- paste(stats::na.omit(c(p, s, t)), collapse = " / "); if (nzchar(w)) w else "study area" }
  sm <- rows[, .(Row, Treatment = Type, StartYear = S0, EndYear = S1, AreaPerYear = round(A, 2), Where = mapply(where, Primary, Secondary, Tertiary),
                 StandAges = sprintf("%g-%s", A0, ifelse(is.na(A1), "any", as.character(A1))), Retreatment = Retreat, Priority,
                 CostPerArea = if ("CostPerArea" %in% names(rows)) round(CostPerArea, 2) else NA_real_,
                 Note = ifelse(is.na(Budget), "", sprintf("from a budget of %s USD a year", format(Budget, big.mark = ","))))]
  eff <- sev[, .(Treatment = sub(" \\[Type\\]$", "", TSTGroupId), Severity = sub("^Fire: | \\[Type\\]$", "", TransitionGroupId), Years = sprintf("%d-%d", TSTMin, TSTMax), Multiplier = Amount)]
  for (i in seq_len(nrow(rows))) with(rows[i], say("Fuel Treatments: row %d, %s %.1f a year %d-%d, %s; stand ages %g-%s, retreatment %g yr, priority %s",
    Row, Type, A, S0, S1, where(Primary, Secondary, Tertiary), A0, ifelse(is.na(A1), "any", A1), Retreat, Priority))
  list(targets = tt, multipliers = rbind(sev, win, fill = TRUE), tst = tst, summary = sm, effects = eff, groups = unname(FT_GROUPS),
       fire_priority = any(rows$Priority == "Fire likelihood"), keys = K) }

# merchantable wood to the forestry sector per thinning treatment (its event flows, defaults/fuel-treatments/flows.csv): the share
# that earns the harvest timber revenue (forest-management.R); 0 when the flows give none
ft_removal <- function(file = if (exists("pkg_file")) pkg_file("defaults", "fuel-treatments", "flows.csv") else file.path("defaults", "fuel-treatments", "flows.csv")) {
  out <- c(Thin = 0, ThinBurn = 0); if (!file.exists(file)) return(out)
  fl <- data.table::fread(file, na.strings = ""); fl[, Key := ft_key(Treatment)]
  for (k in names(out)) out[[k]] <- sum(fl[Key == k & FromStockTypeId == "Biomass: Merchantable" & ToStockTypeId == "Forestry Sector", as.numeric(Multiplier)])
  out }
