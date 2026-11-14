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
    a <- num(col(r, "Amount")); if (is.na(a) || a < 0) fail("Management Actions: row %d needs an area a year (0 or more)", i)
    s0 <- max(y1 + 1, or(num(col(r, "StartYear")), y1 + 1)); s1 <- min(pend, or(num(col(r, "EndYear")), pend))
    if (s1 < s0) { say("Management Actions: row %d (%s) has no year in the projection (%d-%d): left out", i, act, y1 + 1, pend); return(NULL) }
    a0 <- or(num(col(r, "MinAge")), if (rep) 1 else 0); a1 <- or(num(col(r, "MaxAge")), if (rep) 5 else 2)
    if (a1 < a0) fail("Management Actions: row %d's years since the disturbance run backwards (%g to %g)", i, a0, a1)
    sv <- if (rep) or(num(col(r, "Survival")), 0.8) else 1; if (sv < 0 || sv > 1) fail("Management Actions: row %d's survival must be 0-1", i)
    p <- as.character(col(r, "SitePreparation")); prep <- if (!rep) NA_character_ else if (is.na(p) || grepl("^None", p)) "None" else if (grepl("burn", p, ignore.case = TRUE)) "Burn" else "Mechanical"
    pri <- if (rep && grepl("^Far", as.character(col(r, "Priority")))) "Far from live forest" else "None"
    pri1 <- as.character(col(r, "StratumId")); sec <- as.character(col(r, "SecondaryStratumId")); ter <- as.character(col(r, "TertiaryStratumId"))
    base <- if (rep) MG_REPLANT[[prep]] else MG_SALVAGE
    cost <- num(col(r, "Cost")); spc <- num(col(r, "SitePrepCost"))
    out <- data.table::data.table(Row = i, Action = if (rep) "Replanting" else "Salvage logging", Type = base, Share = sv, S0 = s0, S1 = s1, A = a,
                                  A0 = a0, A1 = a1, Prep = prep, Priority = pri, Primary = pri1, Secondary = sec, Tertiary = ter, Cost = cost, PrepCost = spc)
    if (rep) out <- rbind(out, data.table::copy(out)[, `:=`(Type = paste(base, "(failed)"), Share = 1 - sv)])
    out }))
  if (!nrow(rows)) return(NULL)
  w <- unique(rows[, .(Action, A0, A1)]); if (anyDuplicated(w$Action)) fail("Management Actions: every %s row needs the same years since the disturbance", w$Action[duplicated(w$Action)][1])
  pr <- unique(rows[Action == "Replanting", Priority]); if (length(pr) > 1) fail("Management Actions: every Replanting row needs the same priority")
  rows }

# ---- costs (user 2026-11-13: "start with costs per hectare and research defaults") ----------------------------------------------
# ST-Sim transition attributes (types from tools/make_management.R, USD): a row's cost per unit area, else the package default
# (defaults/management/costs.csv, USD per hectare, converted to the library's amount units), on its types' [Type] groups from its start
# year in its strata. Planting and site preparation cost go on the planted and the failed type alike (the money is spent either way)
MG_COST_TYPES <- c(Planting = "Management Cost: Planting", Prep = "Management Cost: Site Preparation", Salvage = "Management Cost: Salvage Logging")
management_cost_defaults <- function(file, per_ha = 1) {
  d <- data.table::fread(file, na.strings = ""); v <- setNames(as.numeric(d$CostPerHa) / per_ha, d$Item)
  need <- c("Planting", "Site preparation: Pile and burn", "Site preparation: Mechanical", "Salvage logging")
  if (!all(need %in% names(v))) stop(sprintf("%s needs rows %s", basename(file), paste(setdiff(need, names(v)), collapse = ", ")), call. = FALSE)
  v }
management_costs <- function(rows, defaults, lev_col, fail) {
  rows <- data.table::copy(rows)
  rows[, `:=`(PlantCost = ifelse(is.na(Cost), defaults[["Planting"]], Cost),
              SalvCost = ifelse(is.na(Cost), defaults[["Salvage logging"]], Cost),
              PrepC = ifelse(is.na(Prep) | Prep == "None", 0, ifelse(is.na(PrepCost), ifelse(Prep == "Burn", defaults[["Site preparation: Pile and burn"]], defaults[["Site preparation: Mechanical"]]), PrepCost)))]
  a <- rbind(rows[Action == "Replanting", .(Row, Type, S0, S1, Primary, Secondary, Tertiary, Attr = MG_COST_TYPES[["Planting"]], Value = PlantCost)],
             rows[Action == "Replanting" & Prep != "None", .(Row, Type, S0, S1, Primary, Secondary, Tertiary, Attr = MG_COST_TYPES[["Prep"]], Value = PrepC)],
             rows[Action != "Replanting", .(Row, Type, S0, S1, Primary, Secondary, Tertiary, Attr = MG_COST_TYPES[["Salvage"]], Value = SalvCost)])
  # two rows for the same type and place whose years overlap must agree on a cost: ST-Sim keeps one value per type, place and year
  a[, k := paste(Type, Attr, Primary, Secondary, Tertiary)]
  for (kk in unique(a$k)) { z <- a[k == kk][order(S0)]; if (nrow(z) > 1) for (j in 2:nrow(z)) if (z$S0[j] <= max(z$S1[1:(j - 1)]) && any(z$Value[1:(j - 1)][z$S1[1:(j - 1)] >= z$S0[j]] != z$Value[j]))
    fail("Management Actions: rows %d and %d act on the same type and place in the same years at different costs", z$Row[j - 1], z$Row[j]) }
  out <- unique(a[, .(Timestep = S0, StratumId = Primary, SecondaryStratumId = Secondary, TertiaryStratumId = Tertiary, TransitionGroupId = paste0(Type, " [Type]"),
                      TransitionAttributeTypeId = Attr, Value = round(Value, 4))])
  out <- out[, names(out)[vapply(out, function(v) !all(is.na(v)), TRUE)], with = FALSE]
  list(values = out, rows = rows) }

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
  cst <- if (!is.null(cost_defaults)) management_costs(rows, cost_defaults, lev_col, fail) else NULL
  if (!is.null(cst)) rows <- cst$rows
  where <- function(p, s, t) { w <- mapply(function(a, b, c) paste(stats::na.omit(c(a, b, c)), collapse = " / "), p, s, t, USE.NAMES = FALSE); ifelse(nzchar(w), w, "study area") }
  sm <- rows[, .(Row, TransitionType = Type, StartYear = S0, EndYear = S1, AreaPerYear = A * Share, YearsSinceDisturbance = sprintf("%g-%g", A0, A1),
                 Where = where(Primary, Secondary, Tertiary),
                 Note = ifelse(Action == "Replanting", sprintf("%s %g a year; survival %g; site preparation %s; priority %s", Action, A, ifelse(grepl("failed", Type), 1 - Share, Share), Prep, Priority), Action),
                 CostPerArea = if (!is.null(cst)) ifelse(Action == "Replanting", PlantCost + PrepC, SalvCost) else NA_real_)]
  for (i in unique(rows$Row)) with(rows[Row == i][1], say("Management Actions: row %d, %s %g a year %d-%d, %g-%g years since the disturbance, %s%s",
    i, Action, A, S0, S1, A0, A1, where(Primary, Secondary, Tertiary),
    if (Action == "Replanting") sprintf("; survival %g, site preparation %s, priority %s", Share, Prep, Priority) else ""))
  say("Management Actions: targets for %d types on %s (%d unit combinations)", length(types), if (length(K)) paste(K, collapse = " x ") else "the whole study area", nrow(combos))
  list(targets = tt, multipliers = mult, summary = sm, costs = if (!is.null(cst)) cst$values else NULL, groups = paste0(types, " [Type]"), far = any(rows$Priority == "Far from live forest")) }
