# =============================================================================
# 03-cdl-ecodivision-sample.R - the CDL-based cropland and pasture growth of each ecodivision, which Cropland Productivity is divided by
# =============================================================================
# (2026-11-08: no longer the divisor - stage 8 divides by the ecodivision's NASS level, ag-targets.csv NPP, so each cell grows at its
# own crops' county rates; kept as the record of the ecodivision CDL means.)
# (user 2026-11-07: normalize by ecodivision.) Stage 8's Cropland Productivity map gives each cell the mean growth of its Cropland Data
# Layer pixels (src/cropland.R: each pixel's crop takes its county's NASS growth; fallow 0; crops NASS does not survey left out). That
# estimate and the NASS level the growth rows hold (ag-targets.csv) are measured differently (fallow, unsurveyed crops), so the map is
# divided by the same estimate's ecodivision mean: the map then only spreads growth within the ecodivision, which keeps the NASS level
# on average. This samples it: the 1,140 windows of 3 x 3 km of dev/agriculture/01-ag-soil-sample.R (centred on NLCD 2021 cultivated
# crops or pasture/hay), every 30 m pixel NLCD 2021 maps as 82 (cropland) or 81 (pasture), every CDL year of CDL_YEARS the folder has.
# Writes dev/agriculture/03-cdl-ecodivision-sample.csv (window x class: pixel-years with a growth value, their sum, and all pixel-years)
# and prints the ecodivision means; tools/make_agriculture.R writes them to defaults/stockflow/ag-cdl-ecodivision-npp.csv.
# Inputs, as environment variables: NLCD (the national Annual NLCD 2021 tif), CDL (the folder of national year_30m_cdls.tif),
# COUNTIES (TIGER county shapefile).
# Usage: NLCD=<tif> CDL=<folder> COUNTIES=<shp> Rscript dev/agriculture/03-cdl-ecodivision-sample.R [workers]
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages({ library(terra); library(data.table); library(parallel) })
a <- commandArgs(TRUE); WORKERS <- if (length(a) >= 1) as.integer(a[1]) else 12L
NLCD <- Sys.getenv("NLCD"); CDL <- Sys.getenv("CDL"); COUNTIES <- Sys.getenv("COUNTIES")
CDL_YEARS <- 2014:2023; cf <- file.path(CDL, sprintf("%d_30m_cdls.tif", CDL_YEARS)); cf <- cf[file.exists(cf)]
if (!file.exists(NLCD) || !length(cf) || !file.exists(COUNTIES)) stop("set NLCD, CDL and COUNTIES")
HALF <- 1500; OUT <- file.path(pkg, "dev", "agriculture", "03-cdl-ecodivision-sample.csv")
ce <- unique(fread(file.path(pkg, "dev", "agriculture", "01-ag-soil-sample.csv"))[, .(StratumId, window, x, y)])
rd <- function(f) fread(file.path(pkg, "defaults", "stockflow", f), colClasses = "character", na.strings = "")
xw <- rd("cdl-crops.csv"); cg <- rd("ag-county-crop-npp.csv"); eg <- rd("ag-ecodivision-crop-npp.csv")
cat(sprintf("%d windows, CDL years %s, %d workers\n", nrow(ce), paste(sub("_30m_cdls.tif", "", basename(cf)), collapse = " "), WORKERS))

one <- function(k) {
  suppressPackageStartupMessages({ library(terra); library(data.table) }); terra::terraOptions(progress = 0, memfrac = 0.2)
  source(file.path(pkg, "src", "cropland.R"))
  w <- ce[k]; tryCatch({
    e <- ext(w$x - HALF, w$x + HALF, w$y - HALF, w$y + HALF)
    r0 <- crop(rast(cf[1]), project(as.polygons(e, crs = "EPSG:5070"), crs(rast(cf[1]))), snap = "out")
    cls <- values(project(crop(rast(NLCD), project(ext(r0) + 90, crs(r0), crs(rast(NLCD)))), r0, method = "near"), mat = FALSE)
    co <- vect(COUNTIES, extent = ext(project(as.polygons(ext(r0) + 100, crs = crs(r0)), "EPSG:4269"))); co <- project(co, crs(r0))
    if (!nrow(co)) return(data.table(StratumId = w$StratumId, window = w$window, error = "no county"))
    ck <- rasterize(co, r0, field = seq_len(nrow(co)))
    lk <- cdl_lookup(co$GEOID, rep(w$StratumId, nrow(co)), xw, cg, eg)
    out <- rbindlist(lapply(cf, function(f) { v <- values(cdl_npp(crop(rast(f), r0), ck, lk), mat = FALSE)
      data.table(cls, v)[cls %in% c(81, 82), .(pixels = .N, valued = sum(!is.na(v)), sum = sum(v, na.rm = TRUE)), by = cls] }))
    out[, .(pixels = sum(pixels), valued = sum(valued), sum = sum(sum)), by = cls][, `:=`(StratumId = w$StratumId, window = w$window,
      StateClassId = fifelse(cls == 82, "Agriculture: Cropland", "Agriculture: Pasture"))][, cls := NULL][] },
    error = function(e) data.table(StratumId = w$StratumId, window = w$window, error = conditionMessage(e))) }

t0 <- Sys.time()
cl <- makeCluster(WORKERS); clusterExport(cl, c("ce", "cf", "NLCD", "COUNTIES", "HALF", "xw", "cg", "eg", "pkg"))
res <- rbindlist(parLapplyLB(cl, seq_len(nrow(ce)), one), fill = TRUE); stopCluster(cl)
if (!"error" %in% names(res)) res[, error := NA_character_]
cat(sprintf("%.1f min; %d window x class rows; %d windows failed\n", as.numeric(Sys.time() - t0, units = "mins"), nrow(res[is.na(error)]), res[!is.na(error), uniqueN(paste(StratumId, window))]))
if (any(!is.na(res$error))) print(head(res[!is.na(error), .(StratumId, window, error = substr(error, 1, 150))], 10))
fwrite(res, OUT)
print(res[is.na(error), .(windows = uniqueN(window), valuedShare = round(sum(valued) / sum(pixels), 2), CdlNPP = round(sum(sum) / sum(valued), 2)), by = .(StateClassId, StratumId)][order(StateClassId, StratumId)], nrows = 60)
cat("wrote", OUT, "\n")
