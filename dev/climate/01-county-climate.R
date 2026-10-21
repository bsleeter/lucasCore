# =============================================================================
# 01-county-climate.R - annual PRISM climate indices by county, 1985-2023 (FIA's public plot location stops at county)
# =============================================================================
# For each county and year: the Miami forest multiplier (stage 7's model: year / 1991-2020 normal, computed on the 4 km grid then
# averaged over the county's cells), the precipitation ratio, and the temperature anomaly. Forest cells only would be better, but
# FIA plots are forest and most forested counties are mostly forest; written to dev/climate/county-climate.csv.
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
for (v in c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA")) if (grepl("syncro", tolower(Sys.getenv(v)))) Sys.unsetenv(v)
PR <- "F:/lucas-master/Data Sources/Climate/prism"; OUT <- "F:/lucasCore/dev/climate"
pf <- function(var, y) Sys.glob(file.path(PR, "annual", var, "*", sprintf("PRISM_*_%d_bil.bil", y)))[1]
Tn <- rast(Sys.glob(file.path(PR, "normals", "PRISM_tmean_30yr_normal_*_annual_bil", "*.bil"))[1])
Pn <- rast(Sys.glob(file.path(PR, "normals", "PRISM_ppt_30yr_normal_*_annual_bil", "*.bil"))[1])
miami <- function(t, p) min(2540 / (1 + exp(1.584 - 0.0622 * t)), (0.551 * p^1.055) / exp(0.000306 * p))
Fn <- miami(Tn, Pn)
co <- vect("F:/lucas-master/Data Sources/Study Areas/Counties/tl_rd22_us_county.shp"); co <- project(co, crs(Tn))
co$gid <- as.integer(co$GEOID); Z <- rasterize(co, Tn, "gid")
res <- rbindlist(lapply(1985:2023, function(y) { Ty <- rast(pf("tmean", y)); Py <- rast(pf("precip", y))
  s <- c(miami(Ty, Py) / Fn, Py / Pn, Ty - Tn, Py, Ty); names(s) <- c("miami", "pratio", "tanom", "ppt", "tmean")
  z <- as.data.table(zonal(s, Z, "mean", na.rm = TRUE)); setnames(z, 1, "GEOID"); z[, Year := y]; z }))
fwrite(res, file.path(OUT, "county-climate.csv"))
cat(nrow(res), "county-years;", uniqueN(res$GEOID), "counties\n"); print(res[, lapply(.SD, function(v) round(sd(v), 3)), .SDcols = c("miami", "pratio", "tanom")])
