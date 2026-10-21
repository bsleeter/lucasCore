# =============================================================================
# 3-carbon-flows.R - stage 3: stock-flow parameters (net growth, growth split, turnover, DOM decay) and the full flow configuration
# =============================================================================
# Replaces lucasbuilder's "2 - Generate Flow Pathways" (2-flow-pathways.R) for forest state classes, driven by the stage 2 FIA carbon
# curves (src/flows.R explains each piece and which inputs are US and which are CBM). Non-forest classes (grassland, shrubland,
# wetland, developed) and the transition-triggered event flows are the LUCAS defaults in defaults/stockflow (from the CONUS 1km
# model). The fixed definitions (flow pathway diagram, flow order, groups, output options) come from the 'Stock-Flow Definitions'
# scenario that tools/new-library.R creates: a stage 3 scenario depends on it (and on a stage 2 result, or runs after stage 2).
# Needs the Live-Tree Carbon Curves of stage 2 (same pipeline, or a dependency on a stage 2 result).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "growth.R")); source(pkg_file("src", "flows.R")); source(pkg_file("src", "dom.R")); source(pkg_file("src", "calibrate.R"))
suppressPackageStartupMessages({ library(terra); library(sf) })
STAGE <- "3 Carbon Flows"
progressBar(type = "begin", totalSteps = 6)

src <- read_data_sources(c("EcodivisionFile", "PrismFolder", "FiaConditionFile", "FiaDisturbanceFile"))
gopt <- as.list(read_ds("GrowthOptions"))
cbm <- pkg_file("defaults", "cbm")
if (!nrow(datasheet(scn, "stsim_FlowPathwayDiagram", optional = TRUE)))
  fail("no Flow Pathway Diagram: make this scenario depend on the 'Stock-Flow Definitions' scenario that tools/new-library.R creates")
cc <- as.data.table(datasheet(scn, ds("CarbonCurve"), optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(cc)) fail("Live-Tree Carbon Curves are empty: run stage 2 first (same pipeline, or depend on a stage 2 result)")
setnames(cc, c("StratumId", "StateClassId"), c("Stratum", "StateClass"))
cw <- read_default("growth", "forest-type-crosswalk.csv"); dens <- read_default("growth", "merch-carbon-density.csv")
scl <- stsim_list("StateClass"); stl <- stsim_list("Stratum")
cw[, StateClass := scl$Name[match(StateClassId, scl$Id)]][, softwood := grepl("Softwood$", LagClass)]
cw[, deciduous := as.numeric(dens$DeciduousShare[match(StateClassId, dens$StateClassId)])]
if (anyNA(cw$deciduous)) fail("merch-carbon-density.csv has no DeciduousShare for some state classes (run tools/make_wood_density.R)")
say("Carbon curves: %d cells x %d ages", uniqueN(cc[, .(Stratum, StateClass)]), uniqueN(cc$Age))

# ecodivision mean annual temperature (PRISM normals) for DOM decay
clim <- ecodiv_climate(src$EcodivisionFile, src$PrismFolder)
eco <- unique(data.table(ecodiv = as.character(st_drop_geometry(read_sf(src$EcodivisionFile))$ecodiv),
                         StratumId = as.integer(st_drop_geometry(read_sf(src$EcodivisionFile))$StrtmId)))
eco[, Stratum := stl$Name[match(StratumId, as.integer(stl$Id))]][, temp := clim$mat[match(ecodiv, clim$ecodiv)]]
eco <- eco[!is.na(Stratum)]
say("Ecodivision mean annual temperature (PRISM): %s", paste(sprintf("%s %.1f C", eco$ecodiv, eco$temp), collapse = ", "))
progressBar()

# ---- 3b: calibrate DOM decay (src/calibrate.R): snags, down wood, forest floor to FIA; soil to gSSURGO ----------------------
MIN_PLOTS_CELL <- 200
cells <- unique(cc[, .(Stratum, StateClass)])
miss <- setdiff(cells$StateClass, cw$StateClass); if (length(miss)) fail("carbon curves for state classes not in the forest crosswalk: %s", paste(miss, collapse = ", "))
cells[, sc := cw$StateClassId[match(StateClass, cw$StateClass)]][, ecodiv := eco$ecodiv[match(Stratum, eco$Stratum)]][, temp := eco$temp[match(Stratum, eco$Stratum)]]
# return intervals and soil targets from stage 5 when this scenario has them (a stage 5 result upstream), else the provisional defaults
ri5 <- as.data.table(datasheet(scn, ds("OutputReturnInterval"), optional = TRUE, lookupsAsFactors = FALSE))
so5 <- as.data.table(datasheet(scn, ds("OutputSoilTarget"), optional = TRUE, lookupsAsFactors = FALSE))
ri_tab <- if (nrow(ri5)) ri5[, .(Stratum = StratumId, StateClass = StateClassId, ReturnInterval)] else read_default("spinup", "return-interval.csv")
soil_t <- if (nrow(so5)) so5[, .(Stratum = StratumId, StateClass = StateClassId, SoilTarget)] else read_default("spinup", "soil-targets.csv")
say("Return intervals: %s; soil targets: %s", if (nrow(ri5)) sprintf("stage 5 (%d cells)", nrow(ri5)) else "provisional defaults",
    if (nrow(so5)) sprintf("stage 5 (%d cells)", nrow(so5)) else "provisional defaults")
cells[, ri := as.numeric(ri_tab$ReturnInterval)[match(paste(Stratum, StateClass), paste(ri_tab$Stratum, ri_tab$StateClass))]]
cells[is.na(ri), ri := median(as.numeric(ri_tab[StateClass == .BY$StateClass, ReturnInterval])), by = StateClass]
cells[is.na(ri), ri := median(as.numeric(ri_tab$ReturnInterval))][, ri := as.integer(round(ri))]
cells[, soil_target := as.numeric(soil_t$SoilTarget)[match(paste(Stratum, StateClass), paste(soil_t$Stratum, soil_t$StateClass))]]
dat <- fia_dom_data(src$FiaConditionFile, src$FiaDisturbanceFile, gopt, cw)
cells[, plots := dat$obs[, .(n = sum(n)), by = .(sc, ecodiv)][cells, on = c("sc", "ecodiv"), n]][is.na(plots), plots := 0L]
say("Decay calibration: %d cells, %d with >= %d FIA plots (own fit), %d with a gSSURGO soil target; return intervals %d-%d yr",
    nrow(cells), cells[plots >= MIN_PLOTS_CELL, .N], MIN_PLOTS_CELL, cells[!is.na(soil_target), .N], min(cells$ri), max(cells$ri))
ctx <- list(cc = cc, cw = cw, dens = dens, cbm = cbm, fo = fread(pkg_file("defaults", "stockflow", "stsim_FlowOrder.csv")),
            ev = fread(pkg_file("defaults", "stockflow", "event-pathways.csv"), na.strings = ""))
t0 <- Sys.time(); cl <- parallel::makeCluster(max(1, min(30, parallel::detectCores() - 1)))
parallel::clusterExport(cl, c("ctx", "dat", "cells"), envir = environment())
pkgdir <- env$PackageDirectory; parallel::clusterExport(cl, "pkgdir", envir = environment())
invisible(parallel::clusterEvalQ(cl, { library(data.table); for (f in c("flows.R", "dom.R", "calibrate.R")) source(file.path(pkgdir, "src", f)) }))
own <- which(cells$plots >= MIN_PLOTS_CELL); types <- unique(cells[plots > 0, sc])
fc <- parallel::parLapply(cl, own, function(i) cal_fit(cells[i], ctx, dat))
ft <- stats::setNames(parallel::parLapply(cl, types, function(s) cal_fit(cells[sc == s & plots > 0], ctx, dat)), types)
cells[, `:=`(Level = NA_character_, m_snag = NA_real_, m_cwd = NA_real_, m_floor = NA_real_, clearcut = NA_real_)]
for (j in seq_along(own)) cells[own[j], `:=`(Level = "Cell", m_snag = fc[[j]]$snag, m_cwd = fc[[j]]$cwd, m_floor = fc[[j]]$floor, clearcut = fc[[j]]$clearcut)]
for (s in types) cells[is.na(Level) & sc == s, `:=`(Level = "Forest type", m_snag = ft[[s]]$snag, m_cwd = ft[[s]]$cwd, m_floor = ft[[s]]$floor, clearcut = ft[[s]]$clearcut)]
if (anyNA(cells$Level)) fail("no FIA dead-carbon plots for state classes %s", paste(unique(cells[is.na(Level), StateClass]), collapse = ", "))
parallel::clusterExport(cl, "cells", envir = environment())
cells[, m_soil := unlist(parallel::parLapply(cl, seq_len(nrow(cells)), function(i) cal_soil(cells[i], ctx, list(snag = cells$m_snag[i], cwd = cells$m_cwd[i], floor = cells$m_floor[i]), cells$clearcut[i])))]
parallel::stopCluster(cl)
cells[, SoilSource := ifelse(is.na(m_soil), ifelse(is.na(soil_target), "Forest type median (no gSSURGO target)", "Forest type median (target unreachable)"), "gSSURGO target")]
cells[is.na(m_soil), m_soil := median(cells[sc == .BY$sc, m_soil], na.rm = TRUE), by = sc]
cells[is.na(m_soil), m_soil := median(cells$m_soil, na.rm = TRUE)]
red <- c(sapply(fc, function(f) 1 - f$loss1 / f$loss0), sapply(ft, function(f) 1 - f$loss1 / f$loss0))
say("Decay calibration took %.1f min; median misfit reduction %.0f%%; median multipliers snag %.2f, down wood %.2f, forest floor %.2f, soil %.2f; clearcut share %.2f",
    as.numeric(Sys.time() - t0, units = "mins"), 100 * median(red), median(cells$m_snag), median(cells$m_cwd), median(cells$m_floor), median(cells$m_soil), median(cells$clearcut))
check(STAGE, "decay multipliers are finite and inside [0.05, 20] (soil [0.02, 50])",
      all(is.finite(as.matrix(cells[, .(m_snag, m_cwd, m_floor, m_soil)]))) && all(cells[, c(m_snag, m_cwd, m_floor)] >= 0.05 - 1e-9 & cells[, c(m_snag, m_cwd, m_floor)] <= 20 + 1e-9) &&
        all(cells$m_soil >= 0.02 - 1e-9 & cells$m_soil <= 50 + 1e-9))
check(STAGE, "calibration reduces the FIA dead-carbon misfit in every fit", all(red > 0), sprintf("smallest reduction %.0f%%", 100 * min(red)))
write_ds(cells[, .(StratumId = Stratum, StateClassId = StateClass, Level, Plots = plots, ReturnInterval = ri, SnagDecayMultiplier = round(m_snag, 4),
                   DownWoodDecayMultiplier = round(m_cwd, 4), ForestFloorDecayMultiplier = round(m_floor, 4), SoilDecayMultiplier = round(m_soil, 4),
                   ClearcutShare = round(clearcut, 3), SoilTarget = round(soil_target, 2), SoilSource)], "OutputDecayCalibration")
progressBar()

# ---- forest: net growth, growth split, turnover and decay per cell ----------------------------------------------------
rates <- setNames(lapply(cw$StateClass, function(s) { k <- cw[StateClass == s]; turnover_rates(s, k$softwood, k$deciduous, cbm) }), cw$StateClass)
ng <- list(); fm_g <- list(); fm_d <- list(); err <- 0; nneg <- 0
for (i in seq_len(nrow(cells))) { s <- cells$Stratum[i]; c0 <- cells$StateClass[i]; r <- rates[[c0]]; k <- cw[StateClass == c0]
  p <- cc[Stratum == s & StateClass == c0][order(Age)]
  g <- net_growth(p, r)
  sh <- g[, lapply(.SD, function(v) ifelse(Total > 0, v / Total, 0.2)), .SDcols = names(LIVE_POOLS)]
  nneg <- nneg + sum(as.matrix(sh) < 0)
  # mass balance check: one year of turnover then growth reproduces the next year's pools
  tr <- pool_turnover(r)
  for (pl in names(LIVE_POOLS)) err <- max(err, max(abs(p[[pl]][-1] - ((1 - tr[[pl]]) * p[[pl]][-nrow(p)] + g$Total * sh[[pl]]))))
  amax <- c(g$Age[-nrow(g)], NA)                                            # the last age applies to every older age
  ng[[i]] <- data.table(StratumId = s, StateClassId = c0, StateAttributeTypeId = "Net Growth", AgeMin = g$Age, AgeMax = amax, Value = g$Total)
  fm_g[[i]] <- rbindlist(lapply(names(LIVE_POOLS), function(pl) data.table(StratumId = s, StateClassId = c0, AgeMin = g$Age, AgeMax = amax,
                                                                           FlowGroupId = paste(GROWTH_FLOW[[pl]], "[Type]"), Value = sh[[pl]])))
  cm <- cells[Stratum == s & StateClass == c0]
  dv <- scale_decay(dom_flow_values(r, k$softwood, eco[Stratum == s, temp], cbm), list(snag = cm$m_snag, cwd = cm$m_cwd, floor = cm$m_floor, soil = cm$m_soil))
  fm_d[[i]] <- data.table(StratumId = s, StateClassId = c0, AgeMin = NA_integer_, AgeMax = NA_integer_, FlowGroupId = paste(names(dv), "[Type]"), Value = unname(dv)) }
ng <- rbindlist(ng); fm_g <- rbindlist(fm_g); fm_d <- rbindlist(fm_d)
say("Forest: %d net growth rows, %d growth-split rows (%d negative shares), %d turnover/decay rows", nrow(ng), nrow(fm_g), nneg, nrow(fm_d))
progressBar()

# ---- checks ---------------------------------------------------------------------------------------------------------
check(STAGE, "every forest cell has net growth at every age", nrow(ng) == nrow(cells) * (uniqueN(cc$Age) - 1) && all(is.finite(ng$Value)),
      sprintf("%d rows", nrow(ng)))
check(STAGE, "net growth is positive", all(ng$Value > 0), sprintf("smallest %.4f Mg C/ha/yr", min(ng$Value)))
check(STAGE, "growth shares add to 1", fm_g[, abs(sum(Value) - 1), by = .(StratumId, StateClassId, AgeMin)][, max(V1)] < 1e-9)
check(STAGE, "turnover then growth reproduces the stage 2 carbon curves", err < 1e-6, sprintf("max error %.2e Mg C/ha", err))
dsum <- fm_d[, .(Value = sum(Value)), by = .(StratumId, StateClassId, from = sub(" -> .*", "", sub("^[^:]+: ", "", sub(" \\[Type\\]$", "", FlowGroupId))))]
check(STAGE, "flows out of each pool take at most its whole stock each year", all(fm_d$Value >= 0) && max(dsum$Value) <= 1 + 1e-9, sprintf("largest total rate %.3f; pools at the 1.0 cap: %d cells", max(dsum$Value), dsum[Value > 1 - 1e-9, uniqueN(paste(StratumId, StateClassId))]))

# ---- assemble the stock-flow configuration (forest built here + LUCAS defaults) ---------------------------------------
rd <- function(f) { x <- fread(pkg_file("defaults", "stockflow", f), colClasses = "character", na.strings = "")
  x[, which(vapply(x, function(v) any(!is.na(v)), TRUE)), with = FALSE] }
fp_forest <- rbindlist(lapply(cw$StateClass, function(c0) FOREST_PATHWAYS[, .(FromStateClassId = c0, FromStockTypeId = From, ToStockTypeId = To,
                                                                                StateAttributeTypeId = Attribute, FlowTypeId = FlowType, Multiplier = 1)]))
fp <- rbind(fp_forest, rd("nonforest-pathways.csv"), rd("event-pathways.csv"), fill = TRUE)
fm <- rbind(fm_g, fm_d, rd("nonforest-multipliers-grassland-shrubland.csv"), rd("nonforest-multipliers-wetland.csv"),
            rd("nonforest-multipliers-other.csv"), rd("scalar-multipliers.csv"), fill = TRUE)
sav <- rbind(ng, rd("nonforest-net-growth.csv"), fill = TRUE)
for (k in c("Iteration", "Timestep")) for (x in list(fp, fm, sav)) if (k %in% names(x)) x[, (k) := NULL]

# every flow type, flow group, stock type and state class named must exist in the library's definitions
ft <- stsim_list("FlowType")$Name; fg <- stsim_list("FlowGroup")$Name; stt <- stsim_list("StockType")$Name
bad <- unique(c(setdiff(fp$FlowTypeId, ft), setdiff(unique(fm$FlowGroupId), fg), setdiff(c(fp$FromStockTypeId, fp$ToStockTypeId), stt),
                setdiff(na.omit(c(fp$FromStateClassId, fm$StateClassId, sav$StateClassId)), scl$Name)))
check(STAGE, "every flow type, flow group, stock type and state class used is defined", !length(bad),
      if (length(bad)) paste("undefined:", paste(head(bad, 8), collapse = "; ")) else "")
progressBar()

say("Writing %d flow pathways, %d flow multipliers, %d state attribute values", nrow(fp), nrow(fm), nrow(sav))
saveDatasheet(scn, as.data.frame(fp), "stsim_FlowPathway")
saveDatasheet(scn, as.data.frame(int_cols(fm)), "stsim_FlowMultiplier")
saveDatasheet(scn, as.data.frame(int_cols(sav)), "stsim_StateAttributeValue")
progressBar()
finish_checks()
progressBar(type = "end")
