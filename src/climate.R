# =============================================================================
# climate.R - the climate-effect models shared by stage 7 (historical, PRISM) and stage 11 (projection, LOCA2)
# =============================================================================
# Climate Options picks the model of each effect; defaults/climate/flow-multipliers.csv lists the flow groups of each:
#   Forest growth      None | Miami NPP | Tree ring (default)
#   Non-forest growth  None | Miami NPP (default)
#   Decomposition      None | Q10 (default)
#   Miami NPP   forest NPP = min(f(MAT), f(MAP)), non-forest NPP = f(MAP) (Lieth 1975); multiplier = year / normal
#   Tree ring   1 + PrecipCoef (P/Pn - 1) + PrecipLagCoef (P last year/Pn - 1) + TempCoef (T - Tn), coefficients by ecodivision
#               (defaults/climate/tree-ring-coefficients.csv, tools/make_tree_ring_coefficients.R)
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
             NonForestGrowth = choice(co$NonForestGrowthModel, c("None", "Miami NPP")),
             Decomposition = choice(co$DecompositionModel, c("None", "Q10")))
  if (anyNA(model)) fail("Climate Options: unrecognised choice for %s", paste(names(model)[is.na(model)], collapse = ", "))
  fm <- read_default("climate", "flow-multipliers.csv"); fg <- stsim_list("FlowGroup")$Name
  check(stage, "every climate flow group exists", all(fm$FlowGroupId %in% fg), paste(setdiff(fm$FlowGroupId, fg), collapse = "; "))
  fm[, Model := model[Role]]
  say("Climate Options: forest growth = %s; non-forest growth = %s; decomposition = %s", model[["ForestGrowth"]], model[["NonForestGrowth"]], model[["Decomposition"]])
  fm[Model != "None"] }

# the parameters the models need on the model grid P: Q10 by flow group, tree-ring coefficients by primary stratum
climate_params <- function(fm, P, stage) {
  dom <- fread(pkg_file("defaults", "cbm", "tblDOMParametersDefault.csv"))
  q10 <- setNames(vapply(seq_len(nrow(fm)), function(i) { if (fm$Model[i] != "Q10") return(NA_real_)
    q <- unique(round(dom[SoilPoolID %in% as.integer(strsplit(fm$CbmPools[i], "|", fixed = TRUE)[[1]]), Q10], 4))
    if (length(q) != 1) { check(stage, sprintf("the CBM pools of %s share one Q10", fm$FlowGroupId[i]), FALSE, paste(q, collapse = ", ")); return(NA_real_) }
    q }, 0), fm$FlowGroupId)
  coef_r <- NULL
  if ("Tree ring" %in% fm$Model) {
    tc <- read_default("climate", "tree-ring-coefficients.csv")
    ids <- as.integer(terra::unique(P)[[1]]); miss <- setdiff(ids, as.integer(tc$Id))
    check(stage, "every ecodivision has tree-ring coefficients", !length(miss), paste("strata without:", paste(miss, collapse = ", ")))
    coef_r <- lapply(c(bp = "PrecipCoef", bl = "PrecipLagCoef", bt = "TempCoef"), function(k) classify(P, cbind(as.integer(tc$Id), as.numeric(tc[[k]])), others = NA))
    used <- tc[as.integer(Id) %in% ids]
    say("Tree-ring coefficients (precip, last year's precip, temperature): %s",
        paste(sprintf("%s %s/%s/%s (%s)", used$StratumId, used$PrecipCoef, used$PrecipLagCoef, used$TempCoef, used$Source), collapse = "; "))
  }
  list(q10 = q10, coef_r = coef_r) }

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
  # data; nrm: the normal's Miami NPP
  e$emit <- function(y, Ty, Py, Pl, Tn, Pn, nrm, climate) {
    tr_terms <- NULL
    for (j in seq_len(nrow(fm))) { g <- fm$FlowGroupId[j]; md <- fm$Model[j]
      r <- if (md == "Tree ring") {
        if (is.null(tr_terms)) tr_terms <- list(pr = to_grid(Py / Pn), pl = to_grid(Pl / Pn), ta = to_grid(Ty - Tn, fill = 0))
        max(1 + prm$coef_r$bp * (tr_terms$pr - 1) + prm$coef_r$bl * (tr_terms$pl - 1) + prm$coef_r$bt * tr_terms$ta, 0)
      } else if (md == "Miami NPP") { forest <- fm$Role[j] == "ForestGrowth"; to_grid(miami(Ty, Py, forest) / nrm[[if (forest) "forest" else "nonforest"]])
      } else to_grid(prm$q10[[g]]^((Ty - Tn) / 10))
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
