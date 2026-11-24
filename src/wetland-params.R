# =============================================================================
# wetland-params.R - the wetland methane parameters a scenario can set (Carbon Assumptions: Wetland Methane), and their uncertainty
# =============================================================================
# The package values: methane targets by class and region (defaults/stockflow/emergent-wetland-regions.csv, the CH4 column; forested
# wetlands defaults/spinup/wetland-ch4.csv), estuarine marsh targets by salinity zone (defaults/stockflow/marsh-salinity-ch4.csv), the
# two wetland Q10s (defaults/climate/flow-multipliers.csv), the cap on methane's share of the belowground emission and the CO2
# equivalent of methane carbon. A scenario's sheets replace them:
#   Wetland Options (one row)   MethaneQ10, SoilQ10, MethaneCapShare, MethaneCO2e, UncertaintyDraws; a blank is the package value
#   Wetland Methane Targets     StateClassId, Region (blank = every region of the class), Target, TargetLow, TargetHigh
#   Marsh Salinity Targets      Region, Zone, Target, TargetLow, TargetHigh
# A target needs no refit: methane is a share of the belowground emission a class already has, and the share is the target over that
# emission (src/nonforest-solve.R), so stage 3 works it out at Build time.
# Uncertainty: a target with a low and a high is a triangular distribution (low, target, high). Each of the first UncertaintyDraws
# Monte Carlo iterations takes one quantile for every target (so an iteration is high everywhere or low everywhere: the ranges are
# mostly what is not known about wetland methane as a whole, not class by class), and gets its own methane factor and the CO2 factor
# that takes the same carbon off the CO2, so every iteration loses from its soil and litter what the class was fitted to lose.
# Iterations past UncertaintyDraws, and every iteration without ranges, run at the targets themselves.
# The package targets carry ranges of their own, drafted from the literature 2026-11-17 (wetland-methane-targets.csv: TargetLow, TargetHigh,
# RangeBasis; marsh-salinity-ch4.csv: CH4Low, CH4High, RangeBasis), so Uncertainty Draws alone turns the uncertainty on; they do nothing at 0 draws.
# No SyncroSim calls: stages 0, 3, 7 and 8 and tests/unit-wetland-params.R source it.
# =============================================================================
suppressPackageStartupMessages(library(data.table))

# the Q10s are lucasWet's (user 2026-11-24; the Barataria model): methane 2.57 (Delwiche et al. 2021; 3.83 until then) and 1.5 for what an
# emergent wetland's litter and soil lose otherwise (SoilQ10: the group Q10 Wetland Flows; 2.0 on the soil's CO2 alone until then)
WETLAND_OPTION_DEFAULTS <- list(MethaneQ10 = 2.57, SoilQ10 = 1.5, MethaneCapShare = 0.3, MethaneCO2e = 33.5, UncertaintyDraws = 0L)
FORESTED_WETLAND_SOIL_Q10 <- "Q10 Wetland Soil"   # the forested wetland classes' soil CO2: 2.0 (defaults/climate/flow-multipliers.csv) unless the scenario sets SoilQ10
# the fixed Q10s by climate flow group that stages 7 and 11 hand to climate_flows (src/climate.R): methane; the emergent classes' litter
# and soil (SoilQ10, 1.5 when blank); and the forested wetland soil, which takes SoilQ10 only when the scenario sets it (NA = the table's
# 2.0: forested wetlands were left as they were on 2026-11-24, to be brought onto the wetland Q10 in a second pass)
wetland_q10s <- function(o) c(`Q10 Wetland CH4` = o$MethaneQ10, `Q10 Wetland Flows` = o$SoilQ10, `Q10 Wetland Soil` = if ("SoilQ10" %in% o$changed) o$SoilQ10 else NA_real_)
WETLAND_OPTION_RANGE <- list(MethaneQ10 = c(1, 10), SoilQ10 = c(1, 10), MethaneCapShare = c(0.01, 0.5), MethaneCO2e = c(3.67, 200), UncertaintyDraws = c(0, 1000))
METHANE_UNCERTAINTY_TYPE <- "Methane Uncertainty"   # the Flow Multiplier Type of the per-iteration factors
WETLAND_FACTOR_GROUPS <- c(ch4 = "Emission: Wetland CH4", co2 = "Emission: Wetland Methane Source CO2")

# the options as a list: the sheet's row (a data.frame, or NULL) with the package value wherever it is blank; stops on a value out of range
wetland_options <- function(sheet = NULL) {
  o <- WETLAND_OPTION_DEFAULTS
  if (!is.null(sheet) && nrow(sheet)) for (k in intersect(names(o), names(sheet))) { v <- suppressWarnings(as.numeric(sheet[[k]][1])); if (!is.na(v)) o[[k]] <- v }
  for (k in names(o)) { r <- WETLAND_OPTION_RANGE[[k]]; if (o[[k]] < r[1] || o[[k]] > r[2]) stop(sprintf("Wetland Options: %s = %s is outside %s to %s", k, format(o[[k]]), format(r[1]), format(r[2])), call. = FALSE) }
  o$UncertaintyDraws <- as.integer(round(o$UncertaintyDraws)); o$changed <- names(WETLAND_OPTION_DEFAULTS)[vapply(names(WETLAND_OPTION_DEFAULTS), function(k) !isTRUE(all.equal(o[[k]], WETLAND_OPTION_DEFAULTS[[k]])), TRUE)]
  o }

# a low and a high must straddle the target (either may be blank: then the target is the end of the range)
check_ranges <- function(x, what) { num <- function(v) suppressWarnings(as.numeric(v))
  x[, `:=`(Target = num(Target), Low = num(Low), High = num(High))]
  bad <- x[is.na(Target) | Target < 0 | (!is.na(Low) & (Low < 0 | Low > Target)) | (!is.na(High) & High < Target)]
  if (nrow(bad)) stop(sprintf("%s: the target must be 0 or more with low <= target <= high (%d rows, first: %s)", what, nrow(bad), paste(unlist(bad[1]), collapse = " ")), call. = FALSE)
  x }

# methane targets by class and region: the package tables with the scenario's rows on top.
#   regions: emergent-wetland-regions.csv (StateClassId, Region, CH4); forest: wetland-ch4.csv (StateClass, CH4)
#   sheet: StateClassId, Region, Target, TargetLow, TargetHigh by name (Region blank = every region of the class), or NULL
#   A scenario's row replaces the package's target and its range together (a row without a low and a high has no range)
# Returns StateClassId, Region (NA for a forested class), Target, Low, High, Source ("package" or "scenario")
wetland_class_targets <- function(regions, forest, sheet = NULL, ranges = NULL) {
  x <- rbind(data.table(StateClassId = regions$StateClassId, Region = regions$Region, Target = regions$CH4),
             data.table(StateClassId = forest$StateClass, Region = NA_character_, Target = forest$CH4))[, `:=`(Low = NA_real_, High = NA_real_, Source = "package")]
  # the package's own low and high (ranges: defaults/stockflow/wetland-methane-targets.csv; StateClassId, Region, TargetLow, TargetHigh)
  if (!is.null(ranges) && nrow(ranges)) { rg <- as.data.table(ranges); rg[!is.na(Region) & !nzchar(as.character(Region)), Region := NA]
    k <- match(paste(x$StateClassId, x$Region), paste(rg$StateClassId, rg$Region)); x[, `:=`(Low = as.numeric(rg$TargetLow)[k], High = as.numeric(rg$TargetHigh)[k])] }
  x <- check_ranges(x, "package methane targets")
  if (is.null(sheet) || !nrow(sheet)) return(x[])
  s <- as.data.table(sheet)[, .(StateClassId = as.character(StateClassId), Region = as.character(Region), Target, Low = TargetLow, High = TargetHigh)]
  s[!is.na(Region) & !nzchar(Region), Region := NA_character_]; s <- check_ranges(s[!is.na(StateClassId)], "Wetland Methane Targets")
  unknown <- s[!StateClassId %in% x$StateClassId | (!is.na(Region) & !paste(StateClassId, Region) %in% x[, paste(StateClassId, Region)])]
  if (nrow(unknown)) stop(sprintf("Wetland Methane Targets: no such wetland class or region: %s", paste(unique(unknown[, paste0(StateClassId, if (!is.na(Region[1])) paste0(" / ", Region) else "")]), collapse = "; ")), call. = FALSE)
  for (i in order(!is.na(s$Region))) {   # the class-wide rows first, a region's own row after it
    k <- x$StateClassId == s$StateClassId[i] & (is.na(s$Region[i]) | (!is.na(x$Region) & x$Region == s$Region[i]))
    x[k, `:=`(Target = s$Target[i], Low = s$Low[i], High = s$High[i], Source = "scenario")] }
  x[] }

# estuarine marsh targets by salinity zone: the package table (Region, Zone, CH4) with the scenario's rows (Region, Zone, Target,
# TargetLow, TargetHigh) on top
wetland_zone_targets <- function(zones, sheet = NULL) {
  col <- function(n) if (n %in% names(zones)) as.numeric(zones[[n]]) else NA_real_   # (CH4Low and CH4High: the package's own ranges)
  x <- check_ranges(data.table(Region = zones$Region, Zone = zones$Zone, Target = zones$CH4)[, `:=`(Low = col("CH4Low"), High = col("CH4High"), Source = "package")], "package marsh salinity targets")
  if (is.null(sheet) || !nrow(sheet)) return(x[])
  s <- check_ranges(as.data.table(sheet)[!is.na(Region) & !is.na(Zone), .(Region = as.character(Region), Zone = as.character(Zone), Target, Low = TargetLow, High = TargetHigh)], "Marsh Salinity Targets")
  unknown <- s[!paste(Region, Zone) %in% x[, paste(Region, Zone)]]
  if (nrow(unknown)) stop(sprintf("Marsh Salinity Targets: no such region and zone: %s", paste(unique(unknown[, paste(Region, Zone, sep = " / ")]), collapse = "; ")), call. = FALSE)
  x[s, on = .(Region, Zone), `:=`(Target = i.Target, Low = i.Low, High = i.High, Source = "scenario")]
  x[] }

# the quantile q of a triangular distribution (lo, mode, hi)
tri_quantile <- function(q, lo, mode, hi) { if (hi <= lo) return(rep(mode, length(q))); fc <- (mode - lo) / (hi - lo)
  ifelse(q < fc, lo + sqrt(q * (hi - lo) * (mode - lo)), hi - sqrt((1 - q) * (hi - lo) * (hi - mode))) }
# a target at quantile q: the target itself without a range; a blank end of the range is the target
target_at <- function(q, target, low, high) { lo <- ifelse(is.na(low), target, low); hi <- ifelse(is.na(high), target, high)
  mapply(function(t, l, h) if (h <= l) t else tri_quantile(q, l, t, h), target, lo, hi) }
# one quantile per uncertainty draw (iteration 1 to n), the same for every target; reproducible
wetland_quantiles <- function(n, seed = 54321L) { if (n <= 0) return(numeric()); old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
  on.exit(if (is.null(old)) suppressWarnings(rm(".Random.seed", envir = globalenv())) else assign(".Random.seed", old, envir = globalenv())); set.seed(seed); stats::runif(n) }

# the methane share of the belowground emission that meets a target, held at the cap
wetland_share <- function(target, belowground, cap) pmin(target / belowground, cap)
# a methane factor m on a class whose methane share is f, held so f m stays within the cap, and the CO2 factor that takes the same
# carbon off the CO2: (1 - f) co2 + f ch4 = 1, so the pool's emission is what it was
wetland_factors <- function(f, m, cap) { m <- ifelse(f > 0, pmin(m, cap / f), 1); list(ch4 = m, co2 = ifelse(f < 1, (1 - f * m) / (1 - f), 1)) }

# the per-iteration factors of the classes whose target has a range, as stsim_FlowMultiplier rows.
#   budgets: StratumId, StateClassId, f (the class's methane share at its target), Target, Low, High
# Returns Iteration, StratumId, StateClassId, FlowGroupId, FlowMultiplierTypeId, Value (none when no class has a range or n is 0)
wetland_iteration_rows <- function(budgets, n, cap, seed = 54321L) {
  b <- as.data.table(budgets)[(!is.na(Low) & Low < Target) | (!is.na(High) & High > Target)][f > 0]
  if (!nrow(b) || n <= 0) return(data.table(Iteration = integer(), StratumId = character(), StateClassId = character(), FlowGroupId = character(), FlowMultiplierTypeId = character(), Value = numeric()))
  q <- wetland_quantiles(n, seed)
  # ST-Sim carries an iteration's rows on to the later iterations (2026-11-17: with 5 draws, iteration 6 of a Great Dismal Swamp run repeated
  # the fifth draw), so iteration n + 1 gets factors of 1: every iteration after the draws runs at the central targets
  rbindlist(lapply(seq_len(n + 1L), function(i) { t <- if (i > n) b$Target else target_at(q[i], b$Target, b$Low, b$High); fa <- wetland_factors(b$f, ifelse(b$Target > 0, t / b$Target, 1), cap)
    rbind(data.table(Iteration = i, StratumId = b$StratumId, StateClassId = b$StateClassId, FlowGroupId = WETLAND_FACTOR_GROUPS[["ch4"]], FlowMultiplierTypeId = METHANE_UNCERTAINTY_TYPE, Value = round(fa$ch4, 6)),
          data.table(Iteration = i, StratumId = b$StratumId, StateClassId = b$StateClassId, FlowGroupId = WETLAND_FACTOR_GROUPS[["co2"]], FlowMultiplierTypeId = METHANE_UNCERTAINTY_TYPE, Value = round(fa$co2, 6))) })) }

# the flow type group memberships (FlowTypeId, FlowGroupId, Value) with the CO2 equivalent of methane carbon set: every CH4 flow type's
# weight in a "(CO2e)" group, keeping its sign (emission groups +, productivity groups -)
ch4_co2e_memberships <- function(memb, co2e) { m <- copy(as.data.table(memb)); v <- suppressWarnings(as.numeric(m$Value))
  k <- grepl("CH4$", m$FlowTypeId) & grepl("\\(CO2e\\)$", m$FlowGroupId) & !is.na(v) & v != 0
  m[k, Value := if (is.character(m$Value)) as.character(sign(v[k]) * co2e) else sign(v[k]) * co2e]
  m[] }

# the package's flow types that a scenario's own stock-flow definitions lack: no flow order, no group membership (so the flow moves
# carbon that net biome productivity never counts), or no output filter for the type's own group. `want` and `have` are lists of
# the three sheets (order: FlowTypeId; members: FlowTypeId; filters: FlowGroupId); returns one line per sheet with gaps, none when
# complete. 2026-11-17: a library whose Stock-Flow Definitions scenario predated the forested wetland methane flows ran with about
# 1,200 Mg C a year leaving its swamp litter uncounted, and nothing said so.
definition_gaps <- function(want, have) {
  miss <- list(`flow order` = setdiff(unique(want$order$FlowTypeId), have$order$FlowTypeId),
               `flow type group memberships` = setdiff(unique(want$members$FlowTypeId), have$members$FlowTypeId),
               `flow output filters` = setdiff(unique(want$filters$FlowGroupId), have$filters$FlowGroupId))
  miss <- miss[lengths(miss) > 0]
  if (!length(miss)) return(character())
  vapply(names(miss), function(k) sprintf("%s: %d missing (%s%s)", k, length(miss[[k]]), paste(head(miss[[k]], 4), collapse = "; "), if (length(miss[[k]]) > 4) "; ..." else ""), "") }
