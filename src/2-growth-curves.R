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
say("Growth options: lag %d yr, penalty %g, min plots per ecodivision %d, ages 0-%d, inventories from %d, volume cap q%.3f",
    opt$LagYears, opt$Penalty, opt$MinPlotsEcodivision, opt$MaximumAge, opt$MinInventoryYear, opt$VolumeCapQuantile)

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

# ---- fit each distinct set of FIA type groups once (201 shares 200's) -----------------------------------------------
sets <- unique(cw$FiaTypeGroups)
fit_set <- function(s) { g <- as.integer(strsplit(s, ";")[[1]]); d <- x[fortyp_grp %in% g]
  if (nrow(d) < 30) return(list(set = s, error = sprintf("only %d plots", nrow(d))))
  r <- tryCatch(fit_forest_type(d, eco$ecodiv, clim, opt), error = function(e) conditionMessage(e))
  if (is.character(r)) list(set = s, error = r) else list(set = s, fit = r) }
nw <- max(1, min(length(sets), detectCores() - 1))
cl <- makeCluster(nw)
clusterExport(cl, c("x", "eco", "clim", "opt", "wb_curve", "fit_single", "fit_type", "fit_forest_type"))
invisible(clusterEvalQ(cl, library(data.table)))
t0 <- Sys.time(); fits <- parLapply(cl, sets, fit_set); stopCluster(cl); names(fits) <- sets
say("Fitted %d type-group sets on %d workers in %.1f min", length(sets), nw, as.numeric(Sys.time() - t0, units = "mins"))
bad <- Filter(function(f) !is.null(f$error), fits)
if (length(bad)) fail("growth fits failed: %s", paste(sprintf("%s (%s)", names(bad), sapply(bad, `[[`, "error")), collapse = "; "))
progressBar()

# ---- parameters and curves ------------------------------------------------------------------------------------------
par <- rbindlist(lapply(seq_len(nrow(cw)), function(i) { f <- copy(fits[[cw$FiaTypeGroups[i]]]$fit)
  f[, `:=`(StateClassId = as.integer(cw$StateClassId[i]), FiaTypeGroups = cw$FiaTypeGroups[i])]; f }))
par <- merge(par, eco, by = "ecodiv")
par[, StateClassName := scl$Name[match(StateClassId, as.integer(scl$Id))]][, StratumName := stl$Name[match(StratumId, as.integer(stl$Id))]]
ages <- 0:opt$MaximumAge
cur <- par[, .(Age = ages, MerchantableVolume = wb_curve(ages, A, k, c, opt$LagYears)), by = .(StratumName, StateClassName, StratumId, StateClassId)]

conv <- par[Method == "Fitted" & converged == FALSE, .N]
check(STAGE, "every forest state class x ecodivision has a curve", nrow(par) == nrow(cw) * nrow(eco) && !anyNA(par$A),
      sprintf("%d of %d cells", par[!is.na(A), .N], nrow(cw) * nrow(eco)))
check(STAGE, "volumes are finite and non-negative", all(is.finite(cur$MerchantableVolume)) && all(cur$MerchantableVolume >= 0))
check(STAGE, "curves never decrease with age", cur[, all(diff(MerchantableVolume) >= -1e-9), by = .(StratumId, StateClassId)][, all(V1)])
q99 <- x[, .(q99 = quantile(vol, .99)), by = fortyp_grp]
vmax <- par[, .(vmax = wb_curve(opt$MaximumAge, A, k, c, opt$LagYears)), by = .(StateClassId, FiaTypeGroups, ecodiv)]
vmax[, q99 := sapply(FiaTypeGroups, function(s) max(q99$q99[q99$fortyp_grp %in% as.integer(strsplit(s, ";")[[1]])]))]
check(STAGE, sprintf("volume at age %d stays within 3x the type's 99th-percentile plot volume", opt$MaximumAge), all(vmax$vmax <= 3 * vmax$q99),
      sprintf("worst ratio %.2f", max(vmax$vmax / vmax$q99)))
say("Cells by method: %s; fitted cells where the optimiser hit its iteration limit: %d",
    paste(par[, .N, by = Method][, sprintf("%s %d", Method, N)], collapse = ", "), conv)

write_ds(par[, .(StratumId = StratumName, StateClassId = StateClassName, Method, Plots, A = round(A, 3), k = signif(k, 6), c = round(c, 4),
                 VolumeAtMaxAge = round(wb_curve(opt$MaximumAge, A, k, c, opt$LagYears), 1), FiaTypeGroups)], "OutputGrowthParameter")
write_ds(cur[, .(StratumId = StratumName, StateClassId = StateClassName, Age, MerchantableVolume = round(MerchantableVolume, 3))], "MerchantableVolumeCurve")
progressBar()

# ---- report: every curve over a sample of its plots -----------------------------------------------------------------
pdf_file <- file.path(TD(), "GrowthCurves.pdf")
grDevices::pdf(pdf_file, width = 14, height = 10)
set.seed(1)
for (i in seq_len(nrow(cw))) { sc <- as.integer(cw$StateClassId[i]); g <- as.integer(strsplit(cw$FiaTypeGroups[i], ";")[[1]])
  graphics::par(mfrow = c(4, 5), mar = c(2.5, 2.5, 2, 0.5), oma = c(0, 0, 3, 0), mgp = c(1.4, 0.4, 0), cex = 0.7)
  ymax <- max(par[StateClassId == sc, wb_curve(opt$MaximumAge, A, k, c, opt$LagYears)], quantile(x[fortyp_grp %in% g, vol], .99))
  for (j in seq_len(nrow(eco))) { e <- eco$ecodiv[j]; p <- par[StateClassId == sc & ecodiv == e]; d <- x[fortyp_grp %in% g & ecodiv == e]
    if (nrow(d) > 1500) d <- d[sample(.N, 1500)]
    graphics::plot(d$stdage, d$vol, pch = 16, cex = 0.3, col = grDevices::adjustcolor("grey40", 0.35), xlim = c(0, opt$MaximumAge), ylim = c(0, ymax),
                   xlab = "Stand age (yr)", ylab = "m3/ha", main = sprintf("%s  %s, n=%d", e, p$Method, p$Plots))
    graphics::lines(ages, wb_curve(ages, p$A, p$k, p$c, opt$LagYears), lwd = 2,
                    col = c(Fitted = "#1b6ca8", Climate = "#d1495b", CONUS = "#edae49")[p$Method]) }
  graphics::mtext(sprintf("%s (FIA %s): blue = fitted, red = climate-predicted, orange = CONUS-wide", par[StateClassId == sc, StateClassName][1], cw$FiaTypeGroups[i]), outer = TRUE, cex = 1)
}
grDevices::dev.off()
write_ds(data.frame(FileName = pdf_file), "OutputGrowthReport")
progressBar()
finish_checks()
progressBar(type = "end")
