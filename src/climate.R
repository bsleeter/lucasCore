# =============================================================================
# climate.R - the climate-effect models shared by stage 7 (historical, PRISM) and stage 11 (projection, LOCA2)
# =============================================================================
# Climate Options picks the model of each effect; defaults/climate/flow-multipliers.csv lists the flow groups of each:
#   Forest growth      None | Miami NPP | Tree ring (default)
#   Non-forest growth  None | Miami NPP (default) | RAP fit
#   Decomposition      None | Q10 (default)
#   Miami NPP   forest NPP = min(f(MAT), f(MAP)), non-forest NPP = f(MAP) (Lieth 1975); multiplier = year / normal
#   Tree ring   1 + PrecipCoef (P/Pn - 1) + PrecipLagCoef (P last year/Pn - 1) + TempCoef (T - Tn), coefficients by ecodivision
#               (defaults/climate/tree-ring-coefficients.csv, tools/make_tree_ring_coefficients.R)
#   RAP fit     grass and shrub growth fitted to RAP NPP 1986-2023 at the sample windows, by ecodivision, half variance-scaled
#               (defaults/climate/rap-climate-coefficients.csv; tools/make_rap_climate_coefficients.R, dev/nonforest/07-...):
#               1 + sum_k (Coef_k + AridCoef_k ar) s_k + (PrecipLagCoef + PrecipLagAridCoef ar) pl + TempCoef (T - Tn), floored at 0;
#               s_k = (season k's rain - its normal) / the water year's normal, for Oct-Dec, Jan-Mar, Apr-Jun, Jul-Sep of the
#               October-September water year; pl = last water year / normal - 1; ar = log(water-year normal / 500 mm), clamped to the
#               range the ecodivision's fit saw. PRISM monthly in stage 7; LOCA2 monthly in stage 11
#   Q10         Q10 ^ ((T - Tn) / 10), Q10 read from the CBM DOM table for the listed pools (the same values stage 3 uses)
#   None        no multiplier: the flow runs at normal climate every year
# Every multiplier is an anomaly against the 1991-2020 normal of its own data, so 1.0 means "the climate the curves and decay rates
# were fitted to" for PRISM years and LOCA2 years alike (the delta method).
# =============================================================================

# the flow groups and model of each climate effect, from Climate Options; None effects dropped
climate_flows <- function(co, stage) {
  choice <- function(v, labels) { v <- v[1]; if (is.null(v) || is.na(v)) return(NA_character_)
    if (is.numeric(v)) labels[v] else labels[match(tolower(v), tolower(labels))] }
  model <- c(ForestGrowth = choice(co$ForestGrowthModel, c("None", "Miami NPP", "Tree ring")),
             NonForestGrowth = choice(co$NonForestGrowthModel, c("None", "Miami NPP", "RAP fit")),
             Decomposition = choice(co$DecompositionModel, c("None", "Q10")))
  if (anyNA(model)) fail("Climate Options: unrecognised choice for %s", paste(names(model)[is.na(model)], collapse = ", "))
  fm <- read_default("climate", "flow-multipliers.csv"); fg <- stsim_list("FlowGroup")$Name
  check(stage, "every climate flow group exists", all(fm$FlowGroupId %in% fg), paste(setdiff(fm$FlowGroupId, fg), collapse = "; "))
  fm[, Model := model[Role]]
  say("Climate Options: forest growth = %s; non-forest growth = %s; decomposition = %s", model[["ForestGrowth"]], model[["NonForestGrowth"]], model[["Decomposition"]])
  fm[Model != "None"] }

# the parameters the models need on the model grid P: Q10 by flow group, tree-ring and RAP fit coefficients by primary stratum
climate_params <- function(fm, P, stage) {
  # Q10s from Carbon Assumptions: Dead Organic Matter Parameters (to-do 21; package default = CBM-CFS3's). The pools of one climate flow
  # group must share a Q10; where ecodivision rows give a group a different Q10, it is a raster on the model grid (P holds stratum ids).
  dpt <- read_dom_parameters(); stl <- stsim_list("Stratum")
  pool_of <- c(`0` = "AG Very Fast", `1` = "BG Very Fast", `2` = "AG Fast", `3` = "BG Fast", `4` = "AG Medium", `5` = "AG Slow", `6` = "BG Slow",
               `7` = "Snag Stem", `8` = "Snag Branch", `9` = "Snag Stem", `10` = "Snag Branch")
  q_at <- function(pools, st) { x <- dpt[!is.na(StratumId) & StratumId %in% st & Pool %in% pools]; x <- rbind(x, dpt[is.na(StratumId) & Pool %in% setdiff(pools, x$Pool)])
    unique(round(x$Q10, 4)) }
  q10 <- setNames(lapply(seq_len(nrow(fm)), function(i) { if (fm$Model[i] != "Q10") return(NA_real_)
    pools <- unique(pool_of[strsplit(fm$CbmPools[i], "|", fixed = TRUE)[[1]]]); base <- q_at(pools, NA_character_)
    ss <- unique(na.omit(dpt[Pool %in% pools, StratumId])); qs <- lapply(ss, function(s) q_at(pools, s))
    if (length(base) != 1 || any(lengths(qs) != 1)) { check(stage, sprintf("the dead pools of %s (%s) share one Q10 (Dead Organic Matter Parameters)", fm$FlowGroupId[i],
                                                                           paste(pools, collapse = ", ")), FALSE, paste(unique(c(base, unlist(qs))), collapse = ", ")); return(NA_real_) }
    qs <- unlist(qs); dif <- qs != base
    if (!any(dif)) return(base)
    say("%s: Q10 %.3g, by ecodivision %s", fm$FlowGroupId[i], base, paste(sprintf("%s %.3g", ss[dif], qs[dif]), collapse = ", "))
    classify(P, cbind(as.integer(stl$Id[match(ss[dif], stl$Name)]), qs[dif]), others = base) }), fm$FlowGroupId)
  # the linear models (tree ring for forest, RAP fit for grass and shrub): coefficient rasters by primary stratum
  lin <- list(`Tree ring` = list(f = "tree-ring-coefficients.csv", what = "tree-ring",
                                  cols = c(bp = "PrecipCoef", bl = "PrecipLagCoef", bt = "TempCoef")),
              `RAP fit` = list(f = "rap-climate-coefficients.csv", what = "RAP fit", cols = RAP_COEF))
  coef <- list()
  for (md in intersect(names(lin), fm$Model)) {
    tc <- read_default("climate", lin[[md]]$f)
    ids <- as.integer(terra::unique(P)[[1]]); miss <- setdiff(ids, as.integer(tc$Id))
    check(stage, sprintf("every ecodivision has %s coefficients", lin[[md]]$what), !length(miss), paste("strata without:", paste(miss, collapse = ", ")))
    cols <- lin[[md]]$cols; nocol <- setdiff(cols, names(tc))
    check(stage, sprintf("%s has every coefficient column", lin[[md]]$f), !length(nocol), paste(nocol, collapse = ", "))
    coef[[md]] <- lapply(cols, function(k) classify(P, cbind(as.integer(tc$Id), as.numeric(tc[[k]])), others = NA))
    used <- tc[as.integer(Id) %in% ids]
    if (md == "Tree ring") say("%s coefficients (precip, last year's precip, temperature): %s", md,
        paste(sprintf("%s %s/%s/%s (%s)", used$StratumId, used$PrecipCoef, used$PrecipLagCoef, used$TempCoef, used$Source), collapse = "; "))
    else say("RAP fit coefficients (Oct-Dec, Jan-Mar, Apr-Jun, Jul-Sep rain; last year's; temperature; scale): %s",
        paste(sprintf("%s %s/%s/%s/%s/%s/%s x%s (%s)", used$StratumId, used$OndCoef, used$JfmCoef, used$AmjCoef, used$JasCoef, used$PrecipLagCoef,
                      used$TempCoef, used$Scale, used$Source), collapse = "; "))
  }
  list(q10 = q10, coef = coef, coef_r = coef[["Tree ring"]]) }

# the RAP fit columns of defaults/climate/rap-climate-coefficients.csv, by the names emit() uses
RAP_COEF <- c(ond = "OndCoef", jfm = "JfmCoef", amj = "AmjCoef", jas = "JasCoef", bl = "PrecipLagCoef", bt = "TempCoef",
              ond_a = "OndAridCoef", jfm_a = "JfmAridCoef", amj_a = "AmjAridCoef", bl_a = "PrecipLagAridCoef", amin = "AridMin", amax = "AridMax")
RAP_SEASONS <- list(ond = 10:12, jfm = 1:3, amj = 4:6, jas = 7:9)   # months of the water year ending in year y: ond is of y - 1

# what emit() takes for RAP fit: S, the year's rain by season (a list by RAP_SEASONS); S1, last year's; Sn, the 1991-2020 normals
rap_water_year <- function(S, S1, Sn) list(S = S, Sn = Sn, Pn = Reduce(`+`, Sn), Pl = Reduce(`+`, S1))

miami <- function(t, p, forest) { if (!forest) return(6116 * (1 - exp(-6.05e-5 * p)))
  min(2540 / (1 + exp(1.584 - 0.0622 * t)), (0.551 * p^1.055) / exp(0.000306 * p)) }
climate_normals <- function(Tn, Pn) list(forest = miami(Tn, Pn, TRUE), nonforest = miami(Tn, Pn, FALSE))

# the lon/lat window of the climate data around the model grid
climate_window <- function(P) ext(project(as.polygons(ext(P) + 20000, crs = crs(P)), "EPSG:4326")) + 0.5

# an emitter: emit() writes one year's multiplier rasters for every flow group and records the rows and a summary
climate_emitter <- function(fm, P, prm) {
  land <- !is.na(values(P, mat = FALSE))
  e <- new.env(); e$rows <- list(); e$summ <- list(); e$unfilled <- 0
  # grow the source field two cells into its no-data margin (coast), then interpolate to the model grid; anything still empty is the fill
  to_grid <- function(x, fill = 1) { for (k in 1:2) x <- focal(x, 3, "mean", na.policy = "only", na.rm = TRUE)
    r <- mask(project(x, P, method = "bilinear"), P); n <- global(is.na(r) & !is.na(P), "sum")[[1]]
    r <- mask(cover(r, init(P, fill)), P); attr(r, "unfilled") <- n; r }
  # Ty, Py: the year's annual mean temperature and precipitation; Pl: last year's precipitation; Tn, Pn: the 1991-2020 normal of the same
  # data; nrm: the normal's Miami NPP; wy: the water years RAP fit uses (rap_water_year()): S, the year's seasonal rain (a list by
  # RAP_SEASONS), Sn their 1991-2020 normals, Pn the water-year normal, Pl last water year's rain
  e$emit <- function(y, Ty, Py, Pl, Tn, Pn, nrm, climate, wy = NULL) {
    tr <- NULL   # the tree-ring terms, made once a year for every forest flow group
    for (j in seq_len(nrow(fm))) { g <- fm$FlowGroupId[j]; md <- fm$Model[j]
      r <- if (md == "Tree ring") { cf <- prm$coef[[md]]
        if (is.null(tr)) tr <- list(pr = to_grid(Py / Pn), pl = to_grid(Pl / Pn), ta = to_grid(Ty - Tn, fill = 0))
        max(1 + cf$bp * (tr$pr - 1) + cf$bl * (tr$pl - 1) + cf$bt * tr$ta, 0)
      } else if (md == "RAP fit") { cf <- prm$coef[[md]]
        if (is.null(wy)) stop("RAP fit needs water-year precipitation (emit(wy = ...))")
        ar <- max(min(to_grid(log(wy$Pn / 500), fill = 0), cf$amax), cf$amin)
        s <- lapply(names(RAP_SEASONS), function(k) to_grid((wy$S[[k]] - wy$Sn[[k]]) / wy$Pn, fill = 0)); names(s) <- names(RAP_SEASONS)
        pl <- to_grid(wy$Pl / wy$Pn - 1, fill = 0)
        max(1 + (cf$ond + cf$ond_a * ar) * s$ond + (cf$jfm + cf$jfm_a * ar) * s$jfm + (cf$amj + cf$amj_a * ar) * s$amj + cf$jas * s$jas +
              (cf$bl + cf$bl_a * ar) * pl + cf$bt * to_grid(Ty - Tn, fill = 0), 0)
      } else if (md == "Miami NPP") { forest <- fm$Role[j] == "ForestGrowth"; to_grid(miami(Ty, Py, forest) / nrm[[if (forest) "forest" else "nonforest"]])
      } else { q <- prm$q10[[g]]; if (inherits(q, "SpatRaster")) q^(to_grid(Ty - Tn, fill = 0) / 10) else to_grid(q^((Ty - Tn) / 10)) }   # Q10 by ecodivision: a raster
      if (!is.null(attr(r, "unfilled"))) e$unfilled <- max(e$unfilled, attr(r, "unfilled"))
      r <- round(r, 3)
      f <- write_raster(r, sprintf("%s_%d.tif", gsub("[^A-Za-z0-9]+", "-", g), y), "FLT4S")
      v <- values(r, mat = FALSE)[land]
      e$rows[[length(e$rows) + 1]] <- data.table(Timestep = y, FlowGroupId = g, MultiplierFileName = f)
      e$summ[[length(e$summ) + 1]] <- data.table(Timestep = y, FlowGroup = g, Model = md, Climate = climate, Mean = mean(v, na.rm = TRUE), Min = min(v, na.rm = TRUE),
                                                 Max = max(v, na.rm = TRUE), NaCells = sum(is.na(v))) } }
  e }

# the rows and summary of an emitter, with a constant 1.0 the year after the last (ST-Sim keeps the last multiplier otherwise)
climate_finish <- function(e, fm, P, stage) {
  summ <- rbindlist(e$summ); rows <- rbindlist(e$rows); last <- max(summ$Timestep)
  one <- write_raster(mask(init(P, 1), P), "One.tif", "FLT4S")
  rows <- rbind(rows, data.table(Timestep = last + 1, FlowGroupId = fm$FlowGroupId, MultiplierFileName = one))
  check(stage, "every land cell has a multiplier in every year", all(summ$NaCells == 0), sprintf("%d cell-years without one", sum(summ$NaCells)))
  # (growth can reach 0: a desert cell's precipitation in a very dry year against a small normal; tree ring is floored at 0)
  check(stage, "multipliers are finite and not negative", all(is.finite(summ$Min) & summ$Min >= 0 & is.finite(summ$Max)), sprintf("range %.3f-%.3f", min(summ$Min), max(summ$Max)))
  if (e$unfilled > 0) say("Cells beyond the gap fill (set to normal): %d", e$unfilled)
  mb <- sum(file.size(unique(rows$MultiplierFileName))) / 2^20
  say("Rasters: %d files, %.0f MB (%.2f MB each)", uniqueN(rows$MultiplierFileName), mb, mb / uniqueN(rows$MultiplierFileName))
  list(rows = rows, summ = summ) }
