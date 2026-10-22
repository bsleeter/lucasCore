# =============================================================================
# 03-old-model-soil.R - the CONUS 1km model's spin-up soil (CBM default BG slow decay) vs this build's calibrated soil, in P26
# =============================================================================
# Old: Models/CONUS 1km/Data/Initial Stocks (Belowground Slow before the gSSURGO substitution, and live pools), by forest class of the
# old state class map. New: the user's lucasBuild-fulltest-v2. Also the equilibrium a CBM-default soil decay would give here,
# approximated as the calibrated value x the calibrated decay multiplier (equilibrium stock scales with 1 / decay rate).
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table); library(rsyncrosim) })
for (v in c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA")) if (grepl("syncro", tolower(Sys.getenv(v)))) Sys.unsetenv(v)
DS <- "F:/lucas-master/Data Sources/"; OLD <- "F:/lucas-master/Models/CONUS 1km/Data/"
py <- read_sf(paste0(DS, "Pyromes/Data/Pyromes_CONUS_20200206.shp")); py <- st_transform(py[py$PYROME == 26, ], "EPSG:5070")
rd <- function(f) { r <- rast(f); mask(crop(r, vect(st_transform(py, crs(r)))), vect(st_transform(py, crs(r)))) }
ist <- paste0(OLD, "Initial Stocks/")
sc <- rd(paste0(OLD, "Initial Conditions/State Class.tif"))
bgs <- rd(paste0(ist, "Belowground Slow.tif")); live <- sum(rast(lapply(c("Merchantable", "Other Wood", "Foliage", "Fine Root", "Coarse Root"), function(k) {
  f <- list.files(ist, sprintf("^%s.*[.]tif$", k), full.names = TRUE)[1]; rd(f) })))
d <- data.table(S = values(sc, mat = FALSE), soil = values(bgs, mat = FALSE), live = values(live, mat = FALSE))[!is.na(S) & S >= 100]
cat("Old CONUS 1km model, P26 forest (CBM-default BG slow from its spin-up):\n")
cat(sprintf("  mean live %.0f, mean BG slow %.0f Mg C/ha, ratio %.2f\n", mean(d$live, na.rm = TRUE), mean(d$soil, na.rm = TRUE), mean(d$soil, na.rm = TRUE) / mean(d$live, na.rm = TRUE)))
print(d[, .(cells = .N, live = round(mean(live, na.rm = TRUE)), soil = round(mean(soil, na.rm = TRUE))), by = S][order(-cells)][1:6])
L <- ssimLibrary("F:/lucasCore/dev/libs/lucasBuild-fulltest-v2.ssim"); R <- scenario(L, 4)
dc <- as.data.table(datasheet(R, "lucasCore_OutputDecayCalibration", lookupsAsFactors = FALSE))
isc <- as.data.table(datasheet(R, "lucasCore_InitialStockCurve", lookupsAsFactors = FALSE))[Age == 100, .(BGS = mean(BGS), Live = mean(TotalLive)), by = .(StratumId, StateClassId)]
x <- merge(isc, dc[, .(StratumId, StateClassId, m = SoilDecayMultiplier)], by = c("StratumId", "StateClassId"))
x[, BGS_cbm_default := BGS * m]
cat("\nThis build at age 100 (Mediterranean Mountains): calibrated BG slow, decay multiplier, approximate CBM-default equilibrium:\n")
print(x[StratumId == "Mediterranean Mountains", .(StateClassId, Live = round(Live), BGS_calibrated = round(BGS, 1), multiplier = round(m, 3), BGS_cbm_default = round(BGS_cbm_default, 1))][order(-Live)][1:8])
