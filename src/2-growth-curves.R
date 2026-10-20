# =============================================================================
# 2-growth-curves.R - stage 2: merchantable volume curves for every forest state class x FIA ecodivision
# =============================================================================
# Replaces "Calculate Growth Curves - Weibull.R" (one interactive fit per type group x ecodivision, fitted to age medians, 68 of
# the 551 cells) with the method in src/growth.R. Writes the Merchantable Volume Curves (ages 0 to Maximum Age) that stage 3
# turns into carbon parameters, the fitted parameters with the method used for each cell, and a PDF of every curve over its data.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "growth.R"))
suppressPackageStartupMessages({ library(terra); library(sf); library(parallel) })
STAGE <- "2 Growth Curves"
progressBar(type = "begin", totalSteps = 5)

src <- read_data_sources(c("FiaConditionFile", "FiaDisturbanceFile", "EcodivisionFile", "PrismFolder"))
opt <- as.list(read_ds("GrowthOptions"))
fixed_lag <- !is.null(opt$LagYears) && !is.na(opt$LagYears)
say("Growth options: lag %s, penalty %g, min plots per ecodivision %d, ages 0-%d, inventories from %d, volume cap q%.3f",
    if (fixed_lag) sprintf("fixed at %g yr", opt$LagYears) else sprintf("fitted per forest type (0-%g yr; class lag below %d plots)", opt$MaximumLag, opt$MinPlotsLag),
    opt$Penalty, opt$MinPlotsEcodivision, opt$MaximumAge, opt$MinInventoryYear, opt$VolumeCapQuantile)

# ---- the cells: forest state classes x primary strata ---------------------------------------------------------------
cw <- read_default("growth", "forest-type-crosswalk.csv")
scl <- stsim_list("StateClass"); stl <- stsim_list("Stratum")
miss <- setdiff(cw$StateClassId, scl$Id); if (length(miss)) fail("forest-type crosswalk state classes not in stsim State Class: %s", paste(miss, collapse = ", "))
eco <- st_drop_geometry(read_sf(src$EcodivisionFile))
if (!all(c("ecodiv", "StrtmId") %in% names(eco))) fail("%s needs fields ecodiv and StrtmId", basename(src$EcodivisionFile))
eco <- unique(data.table(ecodiv = as.character(eco$ecodiv), StratumId = as.integer(eco$StrtmId)))
eco <- eco[StratumId %in% as.integer(stl$Id)]
miss <- setdiff(as.integer(stl$Id), eco$StratumId); if (length(miss)) fail("stsim Strata with no ecodivision in %s: %s", basename(src$EcodivisionFile), paste(miss, collapse = ", "))
say("Cells: %d forest state classes x %d ecodivisions = %d curves", nrow(cw), nrow(eco), nrow(cw) * nrow(eco))
progressBar()

# ---- data and ecodivision climate -----------------------------------------------------------------------------------
x <- growth_data(src$FiaConditionFile, src$FiaDisturbanceFile, opt)
say("FIA: %d plot-conditions after filters (%d plots)", nrow(x), uniqueN(x$pid))
clim <- ecodiv_climate(src$EcodivisionFile, src$PrismFolder)
progressBar()

grp_of <- function(s) as.integer(unlist(strsplit(s, ";")))
sets <- unique(cw[, .(FiaTypeGroups, LagClass)], by = "FiaTypeGroups")
sets[, plots := sapply(FiaTypeGroups, function(s) x[fortyp_grp %in% grp_of(s), .N])]
classes <- cw[, .(FiaTypeGroups = paste(unique(grp_of(FiaTypeGroups)), collapse = ";")), by = LagClass]
nw <- max(1, min(nrow(sets) + nrow(classes), detectCores() - 1))
cl <- makeCluster(nw)
clusterExport(cl, c("x", "eco", "clim", "opt", "grp_of", "wb_curve", "fit_single", "fit_type", "fit_lag", "fit_forest_type"))
invisible(clusterEvalQ(cl, library(data.table)))

# ---- lags: per forest type with enough plots, else the class's ------------------------------------------------------
t0 <- Sys.time()
if (fixed_lag) { sets[, `:=`(Lag = opt$LagYears, LagSource = "Fixed")]
} else {
  jobs <- c(setNames(classes$FiaTypeGroups, paste0("class:", classes$LagClass)),
            setNames(sets[plots >= opt$MinPlotsLag]$FiaTypeGroups, paste0("type:", sets[plots >= opt$MinPlotsLag]$FiaTypeGroups)))
  lg <- parLapply(cl, jobs, function(s) tryCatch(fit_lag(x[fortyp_grp %in% grp_of(s)], opt), error = function(e) conditionMessage(e)))
  names(lg) <- names(jobs)
  bad <- lg[sapply(lg, is.character)]; if (length(bad)) fail("lag fits failed: %s", paste(names(bad), unlist(bad), sep = " - ", collapse = "; "))
  # look up one value per row: unlist() of a list with missing names drops them and shifts every later lag onto the wrong type
  get_lag <- function(key) vapply(key, function(k) if (is.null(lg[[k]])) NA_real_ else lg[[k]], 0)
  sets[, Lag := ifelse(plots >= opt$MinPlotsLag, get_lag(paste0("type:", FiaTypeGroups)), get_lag(paste0("class:", LagClass)))]
  if (anyNA(sets$Lag)) fail("no lag for: %s", paste(sets[is.na(Lag), FiaTypeGroups], collapse = ", "))
  sets[, LagSource := ifelse(plots >= opt$MinPlotsLag, "Type", paste("Class", LagClass))]
  say("Class lags: %s", paste(sprintf("%s %.1f", classes$LagClass, get_lag(paste0("class:", classes$LagClass))), collapse = ", "))
  say("Type lags: %s", paste(sets[, sprintf("%s %.1f (%s)", FiaTypeGroups, Lag, LagSource)], collapse = "; "))
}

# ---- fit each distinct set of FIA type groups once (201 shares 200's) -----------------------------------------------
fit_set <- function(i) { s <- sets$FiaTypeGroups[i]; d <- x[fortyp_grp %in% grp_of(s)]
  if (nrow(d) < 30) return(list(error = sprintf("only %d plots", nrow(d))))
  r <- tryCatch(fit_forest_type(d, eco$ecodiv, clim, opt, sets$Lag[i]), error = function(e) conditionMessage(e))
  if (is.character(r)) list(error = r) else list(fit = r) }
clusterExport(cl, c("sets", "fit_set"))
fits <- parLapply(cl, seq_len(nrow(sets)), fit_set); stopCluster(cl); names(fits) <- sets$FiaTypeGroups
say("Fitted %d type-group sets on %d workers in %.1f min", nrow(sets), nw, as.numeric(Sys.time() - t0, units = "mins"))
bad <- Filter(function(f) !is.null(f$error), fits)
if (length(bad)) fail("growth fits failed: %s", paste(sprintf("%s (%s)", names(bad), sapply(bad, `[[`, "error")), collapse = "; "))
progressBar()

# ---- parameters and curves ------------------------------------------------------------------------------------------
par <- rbindlist(lapply(seq_len(nrow(cw)), function(i) { f <- copy(fits[[cw$FiaTypeGroups[i]]]$fit)
  f[, `:=`(StateClassId = as.integer(cw$StateClassId[i]), FiaTypeGroups = cw$FiaTypeGroups[i], LagSource = sets[FiaTypeGroups == cw$FiaTypeGroups[i], LagSource])]; f }))
par <- merge(par, eco, by = "ecodiv")
par[, StateClassName := scl$Name[match(StateClassId, as.integer(scl$Id))]][, StratumName := stl$Name[match(StratumId, as.integer(stl$Id))]]
ages <- 0:opt$MaximumAge
cur <- par[, .(Age = ages, MerchantableVolume = wb_curve(ages, A, k, c, L)), by = .(StratumName, StateClassName, StratumId, StateClassId)]

conv <- par[Method == "Fitted" & converged == FALSE, .N]
check(STAGE, "every forest state class x ecodivision has a curve", nrow(par) == nrow(cw) * nrow(eco) && !anyNA(par$A),
      sprintf("%d of %d cells", par[!is.na(A), .N], nrow(cw) * nrow(eco)))
check(STAGE, "volumes are finite and non-negative", all(is.finite(cur$MerchantableVolume)) && all(cur$MerchantableVolume >= 0))
check(STAGE, "curves never decrease with age", cur[, all(diff(MerchantableVolume) >= -1e-9), by = .(StratumId, StateClassId)][, all(V1)])
q99 <- x[, .(q99 = quantile(vol, .99)), by = fortyp_grp]
vmax <- par[, .(vmax = wb_curve(opt$MaximumAge, A, k, c, L)), by = .(StateClassId, FiaTypeGroups, ecodiv)]
vmax[, q99 := sapply(FiaTypeGroups, function(s) max(q99$q99[q99$fortyp_grp %in% as.integer(strsplit(s, ";")[[1]])]))]
check(STAGE, sprintf("volume at age %d stays within 3x the type's 99th-percentile plot volume", opt$MaximumAge), all(vmax$vmax <= 3 * vmax$q99),
      sprintf("worst ratio %.2f", max(vmax$vmax / vmax$q99)))
say("Cells by method: %s; fitted cells where the optimiser hit its iteration limit: %d",
    paste(par[, .N, by = Method][, sprintf("%s %d", Method, N)], collapse = ", "), conv)

write_ds(par[, .(StratumId = StratumName, StateClassId = StateClassName, Method, Plots, Lag = round(L, 2), LagSource, A = round(A, 3), k = signif(k, 6), c = round(c, 4),
                 VolumeAtMaxAge = round(wb_curve(opt$MaximumAge, A, k, c, L), 1), FiaTypeGroups)], "OutputGrowthParameter")
write_ds(cur[, .(StratumId = StratumName, StateClassId = StateClassName, Age, MerchantableVolume = round(MerchantableVolume, 3))], "MerchantableVolumeCurve")
progressBar()

# ---- report: every curve over a sample of its plots -----------------------------------------------------------------
pdf_file <- file.path(TD(), "GrowthCurves.pdf")
grDevices::pdf(pdf_file, width = 14, height = 10)
set.seed(1)
for (i in seq_len(nrow(cw))) { sc <- as.integer(cw$StateClassId[i]); g <- as.integer(strsplit(cw$FiaTypeGroups[i], ";")[[1]])
  graphics::par(mfrow = c(4, 5), mar = c(2.5, 2.5, 2, 0.5), oma = c(0, 0, 3, 0), mgp = c(1.4, 0.4, 0), cex = 0.7)
  ymax <- max(par[StateClassId == sc, wb_curve(opt$MaximumAge, A, k, c, L)], quantile(x[fortyp_grp %in% g, vol], .99))
  for (j in seq_len(nrow(eco))) { e <- eco$ecodiv[j]; p <- par[StateClassId == sc & ecodiv == e]; d <- x[fortyp_grp %in% g & ecodiv == e]
    if (nrow(d) > 1500) d <- d[sample(.N, 1500)]
    graphics::plot(d$stdage, d$vol, pch = 16, cex = 0.3, col = grDevices::adjustcolor("grey40", 0.35), xlim = c(0, opt$MaximumAge), ylim = c(0, ymax),
                   xlab = "Stand age (yr)", ylab = "m3/ha", main = sprintf("%s  %s, n=%d", e, p$Method, p$Plots))
    graphics::lines(ages, wb_curve(ages, p$A, p$k, p$c, p$L), lwd = 2,
                    col = c(Fitted = "#1b6ca8", Climate = "#d1495b", CONUS = "#edae49")[p$Method]) }
  graphics::mtext(sprintf("%s (FIA %s), lag %.1f yr (%s): blue = fitted, red = climate-predicted, orange = CONUS-wide", par[StateClassId == sc, StateClassName][1], cw$FiaTypeGroups[i], par[StateClassId == sc, L][1], par[StateClassId == sc, LagSource][1]), outer = TRUE, cex = 1)
}
grDevices::dev.off()
write_ds(data.frame(FileName = pdf_file), "OutputGrowthReport")
progressBar()
finish_checks()
progressBar(type = "end")
