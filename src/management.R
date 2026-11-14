# =============================================================================
# management.R - the Management Actions page as ST-Sim targets (stage 9) and the replanting priority (stage 10); to-do 58
# =============================================================================
# User 2026-11-13: "Start with replanting, salvage and site prep on a dedicated page". A row is an action (Replanting, Salvage
# logging), its years, an area a year, optionally a secondary and/or tertiary stratum unit, a window in years since the disturbance
# (the disturbed classes' age), and for replanting a survival share, a site preparation and a priority. The types act on the
# disturbed forest classes only (tools/make_management.R; salvage: tools/make_post_disturbance.R); stage 6 gave each a zero target.
#   - Replanting: the area a year times Survival on the planting type of the row's site preparation, the rest on its "(failed)" type
#     (the cell stays disturbed with its age; both carry the site preparation carbon).
#   - Where: a unit at any of the three strata levels a row names, blank = any (blank at all three = the whole study area). With
#     spatial tiles every row must name a unit of the tile level (a target must lie inside one tile).
#   - Maps: the replanting family, its [Type] groups and salvage's are main groups (defaults/stockflow/main-transition-groups.csv), mapped.
#   - Targets: on one set of strata keys per run (the spatial tile level, and every level a row names), a row for every unit
#     combination of the study area in every projection year, zero where no action applies; a row's area is spread over the
#     combinations it covers by their forest and disturbed forest land at the projection start (a later fire may fall elsewhere:
#     ST-Sim plants what it can and reports the rest unmet).
#   - The window: a multiplier on each type, 0 outside it. One window per action.
#   - Priority (replanting, stage 10): None, or far from live forest (management_priority).
# =============================================================================

MG_REPLANT <- c(None = "Management: Replanting", Burn = "Management: Replanting after Burn Site Prep", Mechanical = "Management: Replanting after Mechanical Site Prep")
MG_SALVAGE <- "Forest Harvest: Salvage Logging"
MG_TYPES <- c(as.vector(rbind(MG_REPLANT, paste(MG_REPLANT, "(failed)"))), MG_SALVAGE)
MG_GROUPS <- paste0(MG_TYPES, " [Type]")
MG_REPLANT_GROUP <- "Management: Replanting"

# the sheet's rows, one per type they drive (replanting: planted and failed), with defaults filled in
management_rows <- function(ma, y1, pend, say, fail) {
  ma <- data.table::as.data.table(ma); if (!nrow(ma)) return(NULL)
  num <- function(x) suppressWarnings(as.numeric(as.character(x))); or <- function(x, d) if (length(x) == 0 || is.na(x)) d else x
  col <- function(r, k) if (k %in% names(r)) r[[k]] else NA
  rows <- data.table::rbindlist(lapply(seq_len(nrow(ma)), function(i) { r <- ma[i]; act <- as.character(col(r, "ActionId"))
    rep <- grepl("^Replanting", act); if (!rep && !grepl("^Salvage", act)) fail("Management Actions: row %d has no action (Replanting or Salvage logging)", i)
    a <- num(col(r, "Amount")); bud <- num(col(r, "Budget"))
    if (!is.na(a) && !is.na(bud)) fail("Management Actions: row %d gives both an area a year and a budget: give one", i)
    if (is.na(bud) && (is.na(a) || a < 0)) fail("Management Actions: row %d needs an area a year (0 or more) or a budget", i)
    if (!is.na(bud) && bud < 0) fail("Management Actions: row %d's budget must be 0 or more", i)
    s0 <- max(y1 + 1, or(num(col(r, "StartYear")), y1 + 1)); s1 <- min(pend, or(num(col(r, "EndYear")), pend))
    if (s1 < s0) { say("Management Actions: row %d (%s) has no year in the projection (%d-%d): left out", i, act, y1 + 1, pend); return(NULL) }
    a0 <- or(num(col(r, "MinAge")), if (rep) 1 else 0); a1 <- or(num(col(r, "MaxAge")), if (rep) 5 else 2)
    if (a1 < a0) fail("Management Actions: row %d's years since the disturbance run backwards (%g to %g)", i, a0, a1)
    sv <- if (rep) or(num(col(r, "Survival")), 0.8) else 1; if (sv < 0 || sv > 1) fail("Management Actions: row %d's survival must be 0-1", i)
    p <- as.character(col(r, "SitePreparation")); prep <- if (!rep) NA_character_ else if (is.na(p) || grepl("^None", p)) "None" else if (grepl("burn", p, ignore.case = TRUE)) "Burn" else "Mechanical"
    pri <- if (rep && grepl("^Far", as.character(col(r, "Priority")))) "Far from live forest" else "None"
    pri1 <- as.character(col(r, "StratumId")); sec <- as.character(col(r, "SecondaryStratumId")); ter <- as.character(col(r, "TertiaryStratumId"))
    base <- if (rep) MG_REPLANT[[prep]] else MG_SALVAGE
    cost <- num(col(r, "Cost")); spc <- num(col(r, "SitePrepCost")); rev <- num(col(r, "Revenue")); crange <- as.character(col(r, "CostRange"))
    out <- data.table::data.table(Row = i, Action = if (rep) "Replanting" else "Salvage logging", Type = base, Share = sv, S0 = s0, S1 = s1, A = a,
                                  A0 = a0, A1 = a1, Prep = prep, Priority = pri, Primary = pri1, Secondary = sec, Tertiary = ter, Cost = cost, PrepCost = spc, Revenue = rev, CostRange = crange, Budget = bud)
    if (rep) out <- rbind(out, data.table::copy(out)[, `:=`(Type = paste(base, "(failed)"), Share = 1 - sv)])
    out }))
  if (!nrow(rows)) return(NULL)
  w <- unique(rows[, .(Action, A0, A1)]); if (anyDuplicated(w$Action)) fail("Management Actions: every %s row needs the same years since the disturbance", w$Action[duplicated(w$Action)][1])
  pr <- unique(rows[Action == "Replanting", Priority]); if (length(pr) > 1) fail("Management Actions: every Replanting row needs the same priority")
  rows }

# ---- costs (user 2026-11-13: "start with costs per hectare and research defaults"; ranges: "Transition Attribute Values ... can also
# hold a distribution of cost values to give us a built in range in estimated cost") -------------------------------------------
# ST-Sim transition attributes (types from tools/make_management.R, USD) on the management types' [Type] groups, from a row's start
# year in its strata:
#   - Planting and Site Preparation on the planted and the failed type alike (the money is spent either way); Salvage Logging (the
#     logging and haul cost) and Salvage Timber revenue on salvage. Net = revenue - costs, in the outputs.
#   - Values: a row's own (Cost, SitePrepCost, Revenue), else the package default of its region (defaults/management/costs.csv,
#     USD per hectare, converted to the library's amount units): each ecodivision (primary stratum) belongs to a cost region
#     (cost-regions.csv), a region without its own row takes the national one (All). With more than one region in the study area,
#     values are written per ecodivision.
#   - Range: each value is a Beta distribution (mean = the value, min and max = the range, SD = a sixth of the range), sampled once
#     per iteration (each iteration is one cost scenario; several iterations give the spread). A row's own value takes the default's
#     range scaled to it; CostRange "Fixed" writes the value alone.
#   - Salvage revenue falls with years since the fire (the disturbed class's age): value at age a = revenue x (1 - loss)^a, a row per
#     age of the window (loss: "Salvage revenue loss per year", 0.25).
MG_COST_TYPES <- c(Planting = "Management Cost: Planting", Prep = "Management Cost: Site Preparation", Salvage = "Management Cost: Salvage Logging",
                   Revenue = "Management Revenue: Salvage Timber")
MG_COST_ITEMS <- c(Planting = "Planting", Burn = "Site preparation: Pile and burn", Mechanical = "Site preparation: Mechanical",
                   Salvage = "Salvage logging", Revenue = "Salvage timber revenue")
MG_LOSS_ITEM <- "Salvage revenue loss per year"
management_cost_defaults <- function(file, per_ha = 1, regions = file.path(dirname(file), "cost-regions.csv")) {
  d <- data.table::fread(file, na.strings = "", colClasses = list(character = c("Region", "Item", "Unit")))
  need <- c(MG_COST_ITEMS, MG_LOSS_ITEM)
  miss <- setdiff(need, d[Region == "All", Item])
  if (length(miss)) stop(sprintf("%s needs national (Region All) rows for %s", basename(file), paste(miss, collapse = ", ")), call. = FALSE)
  bad <- d[Unit != "share" & !(Low <= Central & Central <= High)]
  if (nrow(bad)) stop(sprintf("%s: Low <= Central <= High fails for %s", basename(file), paste(bad$Region, bad$Item, collapse = "; ")), call. = FALSE)
  d[Unit != "share", `:=`(Central = Central / per_ha, Low = Low / per_ha, High = High / per_ha)]
  rg <- if (file.exists(regions)) data.table::fread(regions, na.strings = "") else data.table::data.table(Ecodivision = character(), Region = character())
  list(values = d[, .(Region, Item, Central, Low, High)], regions = rg[, .(Ecodivision, Region)]) }
# the default (central, low, high) of an item in a region, the national one where the region has none
mg_cost_default <- function(defaults, region, item) { v <- defaults$values
  r <- v[Region == region & Item == item]; if (!nrow(r)) r <- v[Region == "All" & Item == item]; unlist(r[1, .(Central, Low, High)]) }
mg_region <- function(defaults, eco) { r <- defaults$regions$Region[match(eco, defaults$regions$Ecodivision)]; ifelse(is.na(r), "All", r) }
# Beta parameters for a value with a range (the default range scaled to the value); none when fixed or the range is empty
mg_beta <- function(v, d, fixed) {
  if (fixed || !is.finite(v) || v <= 0 || d[["High"]] <= d[["Low"]] || d[["Central"]] <= 0) return(list(DistributionType = NA_character_, DistributionSD = NA_real_, DistributionMin = NA_real_, DistributionMax = NA_real_))
  lo <- v * d[["Low"]] / d[["Central"]]; hi <- v * d[["High"]] / d[["Central"]]
  if (!(lo < v && v < hi)) return(list(DistributionType = NA_character_, DistributionSD = NA_real_, DistributionMin = NA_real_, DistributionMax = NA_real_))
  sd <- min((hi - lo) / 6, sqrt(0.9 * (v - lo) * (hi - v)))   # a Beta needs sd^2 < (mean - min)(max - mean)
  list(DistributionType = "Beta", DistributionSD = signif(sd, 6), DistributionMin = signif(lo, 6), DistributionMax = signif(hi, 6)) }
management_costs <- function(rows, defaults, prim_units, fail) {
  rows <- data.table::copy(rows)
  if (!"CostRange" %in% names(rows)) rows[, CostRange := NA_character_]
  if (!"Revenue" %in% names(rows)) rows[, Revenue := NA_real_]
  loss <- defaults$values[Region == "All" & Item == MG_LOSS_ITEM, Central][1]
  prim_units <- unique(prim_units); reg <- mg_region(defaults, prim_units)
  per_unit <- length(unique(reg)) > 1   # several cost regions: values per ecodivision
  out <- list(); sm <- list()
  for (j in seq_len(nrow(rows))) { r <- rows[j]; fixed <- isTRUE(grepl("^Fixed", r$CostRange)) || identical(as.character(r$CostRange), "2")
    units <- if (!is.na(r$Primary)) r$Primary else prim_units
    if (!per_unit && is.na(r$Primary)) units <- NA_character_
    items <- if (r$Action == "Replanting") c(Planting = MG_COST_ITEMS[["Planting"]], if (r$Prep != "None") c(Prep = MG_COST_ITEMS[[r$Prep]])) else
      c(Salvage = MG_COST_ITEMS[["Salvage"]], Revenue = MG_COST_ITEMS[["Revenue"]])
    own <- c(Planting = r$Cost, Prep = r$PrepCost, Salvage = r$Cost, Revenue = r$Revenue)
    tot <- c(cost = 0, rev = 0)
    for (u in units) { rg <- if (is.na(u)) reg[1] else mg_region(defaults, u)
      for (k in names(items)) { d <- mg_cost_default(defaults, rg, items[[k]]); v <- if (is.na(own[[k]])) d[["Central"]] else own[[k]]
        ages <- if (k == "Revenue") r$A0:r$A1 else NA_integer_
        for (a in ages) { f <- if (is.na(a)) 1 else (1 - loss)^a
          b <- mg_beta(v * f, d, fixed)
          out[[length(out) + 1]] <- data.table::data.table(Row = r$Row, Type = r$Type, S0 = r$S0, S1 = r$S1, StratumId = u, Secondary = r$Secondary, Tertiary = r$Tertiary,
            AgeMin = a, AgeMax = a, Attr = MG_COST_TYPES[[k]], Value = round(v * f, 4), DistributionType = b$DistributionType,
            DistributionSD = b$DistributionSD, DistributionMin = b$DistributionMin, DistributionMax = b$DistributionMax) }
        if (k == "Revenue") tot[["rev"]] <- tot[["rev"]] + v * (1 - loss)^r$A0 / length(units) else tot[["cost"]] <- tot[["cost"]] + v / length(units) } }
    sm[[j]] <- data.table::data.table(CostPerArea = tot[["cost"]], RevenuePerArea = if (r$Action == "Replanting") NA_real_ else tot[["rev"]]) }
  a <- data.table::rbindlist(out, fill = TRUE)
  # two rows for the same type, place and age whose years overlap must agree: ST-Sim keeps one value per type, place, age and year
  a[, k := paste(Type, Attr, StratumId, Secondary, Tertiary, AgeMin)]
  for (kk in unique(a$k)) { z <- a[k == kk][order(S0)]; if (nrow(z) > 1) for (j in 2:nrow(z)) if (z$S0[j] <= max(z$S1[1:(j - 1)]) && any(z$Value[1:(j - 1)][z$S1[1:(j - 1)] >= z$S0[j]] != z$Value[j]))
    fail("Management Actions: rows %d and %d act on the same type and place in the same years at different costs", z$Row[j - 1], z$Row[j]) }
  v <- unique(a[, .(Timestep = S0, StratumId, SecondaryStratumId = Secondary, TertiaryStratumId = Tertiary, TransitionGroupId = paste0(Type, " [Type]"),
                    TransitionAttributeTypeId = Attr, AgeMin, AgeMax, Value, DistributionType,
                    DistributionFrequencyId = ifelse(is.na(DistributionType), NA_character_, "Iteration Only"), DistributionSD, DistributionMin, DistributionMax)])
  v <- v[, names(v)[vapply(v, function(x) !all(is.na(x)), TRUE)], with = FALSE]
  rows <- cbind(rows, data.table::rbindlist(sm))
  list(values = v, rows = rows) }

# targets (Timestep, TransitionGroupId, strata key columns, Amount), age multipliers, and a summary; NULL with no rows
management_targets <- function(ma, y0, y1, pend, land, lev, lev_list, lev_col, tile_lvl, sc_vals, say, fail, cost_defaults = NULL) {
  rows <- management_rows(ma, y1, pend, say, fail); if (is.null(rows)) return(NULL)
  LV <- c("Primary", "Secondary", "Tertiary")
  # with spatial tiles every row names a unit of the tile level: a target must lie inside one tile (user 2026-11-13: "if using spatial
  # multiprocessing, these area targets ... MUST be specified at the same strata"); units at the other levels are optional
  if (!is.na(tile_lvl)) { bad <- unique(rows[is.na(get(tile_lvl)), Row])
    if (length(bad)) fail("Management Actions: this projection runs in spatial tiles of %s units, so every row needs a %s unit (rows %s have none): add a row for each unit to manage", tile_lvl, tile_lvl, paste(bad, collapse = ", ")) }
  K <- unique(c(if (!is.na(tile_lvl)) tile_lvl, LV[vapply(LV, function(L) any(!is.na(rows[[L]])), TRUE)]))
  name_of <- function(L, ids) lev_list[[L]]$Name[match(ids, as.integer(lev_list[[L]]$Id))]
  fw <- !is.na(sc_vals) & ((sc_vals >= 100 & sc_vals <= 999) | (sc_vals >= 2100 & sc_vals <= 2999))
  cells <- data.table::data.table(w = as.numeric(fw[land]), one = 1)
  for (L in LV) data.table::set(cells, j = L, value = name_of(L, lev[[L]][land]))
  key <- if (length(K)) do.call(paste, c(lapply(K, function(L) cells[[L]]), sep = "\r")) else rep("all", nrow(cells))
  cells[, Key := key]; combos <- unique(cells[, c("Key", K), with = FALSE])
  # each row's area over the combinations it covers, by forest and disturbed forest land (cell counts where it has none)
  alloc <- data.table::rbindlist(lapply(unique(rows$Row), function(i) { r <- rows[Row == i][1]
    m <- (is.na(r$Primary) | cells$Primary == r$Primary) & (is.na(r$Secondary) | cells$Secondary == r$Secondary) & (is.na(r$Tertiary) | cells$Tertiary == r$Tertiary)
    if (!any(m)) fail("Management Actions: row %d's strata (%s) have no land in the study area", i, paste(stats::na.omit(c(r$Primary, r$Secondary, r$Tertiary)), collapse = " / "))
    x <- cells[m, .(w = sum(w), n = sum(one)), by = Key]; if (sum(x$w) > 0) x[, f := w / sum(w)] else x[, f := n / sum(n)]
    x[, .(Row = i, Key, f)] }))
  # costs (on the rows, central per area), and budget mode (to-do 58 cost follow-ups, user 2026-11-13): a row with a budget (USD a
  # year) instead of an area gets the area its budget pays for at its central cost per area (replanting: planting + site preparation,
  # planted and failed alike; salvage: the logging cost). With the cost range on, what a run spends varies around the budget by iteration
  cst <- if (!is.null(cost_defaults)) management_costs(rows, cost_defaults, unique(stats::na.omit(cells$Primary)), fail) else NULL
  if (!is.null(cst)) rows <- cst$rows
  if (any(!is.na(rows$Budget))) {
    if (is.null(cst)) fail("Management Actions: a budget needs the cost defaults (defaults/management/costs.csv)")
    b <- !is.na(rows$Budget); bad <- unique(rows[b & !(CostPerArea > 0), Row])
    if (length(bad)) fail("Management Actions: rows %s have a budget but no cost per area to turn it into an area", paste(bad, collapse = ", "))
    rows[b, A := Budget / CostPerArea]
    for (i in unique(rows[b, Row])) with(rows[Row == i][1], say("Management Actions: row %d, a budget of %s USD a year at %.0f USD per unit area: %.1f a year", i, format(Budget, big.mark = ","), CostPerArea, A)) }
  yrs <- (y1 + 1):pend; types <- unique(rows$Type)
  tt <- data.table::rbindlist(lapply(types, function(ty) { rr <- rows[Type == ty]
    yr <- data.table::rbindlist(lapply(yrs, function(y) { act <- rr[S0 <= y & S1 >= y]
      a <- if (nrow(act)) merge(alloc, act[, .(Row, A, Share)], by = "Row")[, .(Amount = sum(A * Share * f)), by = Key] else data.table::data.table(Key = character(), Amount = numeric())
      merge(combos[, .(Key)], a, by = "Key", all.x = TRUE)[is.na(Amount), Amount := 0][, Timestep := y] }))
    rbind(combos[, .(Key, Amount = 0, Timestep = y0)], yr)[, TransitionGroupId := paste0(ty, " [Type]")] }))
  tt <- merge(tt, combos, by = "Key", sort = FALSE)[, Key := NULL]
  for (L in K) data.table::setnames(tt, L, lev_col[[L]])
  mult <- data.table::rbindlist(lapply(types, function(ty) { r <- rows[Type == ty][1]; g <- paste0(ty, " [Type]")
    data.table::data.table(Timestep = y1 + 1L, TransitionGroupId = g, AgeMin = c(0, r$A0, r$A1 + 1), AgeMax = c(r$A0 - 1, r$A1, NA), Amount = c(0, 1, 0))[is.na(AgeMax) | AgeMax >= AgeMin] }))
  where <- function(p, s, t) { w <- mapply(function(a, b, c) paste(stats::na.omit(c(a, b, c)), collapse = " / "), p, s, t, USE.NAMES = FALSE); ifelse(nzchar(w), w, "study area") }
  sm <- rows[, .(Row, TransitionType = Type, StartYear = S0, EndYear = S1, AreaPerYear = A * Share, YearsSinceDisturbance = sprintf("%g-%g", A0, A1),
                 Where = where(Primary, Secondary, Tertiary),
                 Note = paste0(ifelse(Action == "Replanting", sprintf("%s %g a year; survival %g; site preparation %s; priority %s", Action, round(A, 2), ifelse(grepl("failed", Type), 1 - Share, Share), Prep, Priority), Action),
                               ifelse(is.na(Budget), "", sprintf("; from a budget of %s USD a year", format(Budget, big.mark = ",")))),
                 CostPerArea = if (!is.null(cst)) round(CostPerArea, 2) else NA_real_, RevenuePerArea = if (!is.null(cst)) round(RevenuePerArea, 2) else NA_real_)]
  for (i in unique(rows$Row)) with(rows[Row == i][1], say("Management Actions: row %d, %s %g a year %d-%d, %g-%g years since the disturbance, %s%s",
    i, Action, A, S0, S1, A0, A1, where(Primary, Secondary, Tertiary),
    if (Action == "Replanting") sprintf("; survival %g, site preparation %s, priority %s", Share, Prep, Priority) else ""))
  say("Management Actions: targets for %d types on %s (%d unit combinations)", length(types), if (length(K)) paste(K, collapse = " x ") else "the whole study area", nrow(combos))
  list(targets = tt, multipliers = mult, summary = sm, costs = if (!is.null(cst)) cst$values else NULL, groups = paste0(types, " [Type]"), far = any(rows$Priority == "Far from live forest")) }
