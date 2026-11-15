# =============================================================================
# iclus.R - EPA ICLUS v2.1.1 land-use maps to a county table of new developed land by decade (Data Download; Land Use Demand)
# =============================================================================
# ICLUS v2.1.1 (U.S. EPA 2020): 90 m maps of 19 land-use classes for SSP2-RCP4.5 and SSP5-RCP8.5, each with HadGEM2-ES and GISS-E2-R
# driving migration; 2000 and 2010 (US-NLUD, observed) and every decade 2020-2100. Three runs are distributed as GeoTIFFs with the 2000
# and 2010 maps; SSP5 HadGEM2-ES as a file geodatabase of 2020-2100 only, so its 2010 map is taken from another run (the same
# observed map). The maps do not share one extent, so each is cut to the county's window.
# "New developed land" = pixels outside classes 12-16 at one decade and inside them at the next: 12 suburban, 13 urban low, 14 urban
# high, 15 commercial, 16 industrial (dev/land-use-demand/07-iclus-demand.R: by county these follow NLCD developed land best, rank
# correlation 0.82; the exurban classes 10-11 are mostly not NLCD developed, and 17-18 never change). 2000-2010 is left out: the two
# observed maps differ by far more than a decade's change. Needs terra, sf, data.table, parallel.
# =============================================================================

ICLUS_RUNS <- c("ssp2_rcp45_hadgem2_es", "ssp2_rcp45_giss_e2_r", "ssp5_rcp85_hadgem2_es", "ssp5_rcp85_giss_e2_r")
ICLUS_DEVELOPED <- 12:16
ICLUS_URL <- "https://dmap-prod-oms-edc.s3.amazonaws.com/ORD/NCEA/ICLUS_v2.1.1/land_use/ICLUS_v2_1_1_land_use_conus_%s.zip"

# the maps of a run under `dir` (where the release's zips were unpacked): a named vector year -> source (a GeoTIFF, or a geodatabase raster)
iclus_maps <- function(dir, run) { d <- file.path(dir, paste0("ICLUS_v2_1_1_land_use_conus_", run)); g <- paste0(d, ".gdb")
  if (dir.exists(d)) { f <- list.files(d, "_[0-9]{4}[^/]*[.]tif$", full.names = TRUE); return(setNames(f, sub(".*_conus_([0-9]{4}).*", "\\1", basename(f)))) }
  if (dir.exists(g)) { s <- terra::describe(g, sds = TRUE)$name; return(setNames(s, sub(".*_conus_([0-9]{4})_.*", "\\1", s))) }
  stop(sprintf("no ICLUS maps for %s in %s", run, dir), call. = FALSE) }

# every run's maps from 2010 on, the 2010 map borrowed where a run lacks it
iclus_all_maps <- function(dir, runs = ICLUS_RUNS) { m <- lapply(setNames(runs, runs), function(r) iclus_maps(dir, r))
  base <- Filter(function(x) "2010" %in% names(x), m); if (!length(base)) stop("no ICLUS run holds the 2010 map", call. = FALSE)
  lapply(m, function(x) { if (!"2010" %in% names(x)) x <- c(base[[1]]["2010"], x); x <- x[as.integer(names(x)) >= 2010]; x[order(as.integer(names(x)))] }) }

# counties (an sf with a column of county ids, `id`) x runs x decades: km2 of new developed land. One county at a time, on `workers` cores
iclus_county_table <- function(dir, counties, id = "GEOID", runs = ICLUS_RUNS, classes = ICLUS_DEVELOPED, workers = 1L, log = function(x) NULL) {
  maps <- iclus_all_maps(dir, runs); t0 <- terra::rast(maps[[1]][1])
  cp <- sf::st_transform(counties, terra::crs(t0)); cp <- cp[lengths(sf::st_within(cp, sf::st_as_sfc(sf::st_bbox(terra::ext(t0), crs = sf::st_crs(terra::crs(t0)))))) > 0, ]
  if (!nrow(cp)) stop("no county lies inside the ICLUS maps", call. = FALSE)
  one <- function(p, m, id, classes) { terra::terraOptions(progress = 0, memfrac = 0.02)
    v <- terra::vect(p); a <- terra::rast(m[1]); e <- terra::align(terra::ext(v), a, snap = "out"); a <- terra::crop(a, e); levels(a) <- NULL
    k <- !is.na(terra::values(terra::rasterize(v, a, 1), mat = FALSE))
    val <- lapply(m, function(f) { b <- terra::crop(terra::rast(f), e, extend = TRUE); levels(b) <- NULL; if (!terra::compareGeom(b, a, stopOnError = FALSE)) b <- terra::resample(b, a, method = "near")
      terra::values(b, mat = FALSE)[k] %in% classes })
    px <- prod(terra::res(a)) / 1e6
    data.frame(Fips = p[[id]][1], Year = as.integer(names(m)[-length(m)]), Km2 = vapply(seq_len(length(m) - 1), function(i) sum(!val[[i]] & val[[i + 1]]) * px, 0)) }
  parts <- split(cp, seq_len(nrow(cp))); cl <- if (workers > 1) parallel::makeCluster(workers) else NULL; on.exit(if (!is.null(cl)) parallel::stopCluster(cl), add = TRUE)
  data.table::rbindlist(lapply(runs, function(r) { log(sprintf("  ICLUS %s: %d counties, decades %s", r, length(parts), paste(names(maps[[r]]), collapse = " ")))
    x <- if (is.null(cl)) lapply(parts, one, m = maps[[r]], id = id, classes = classes) else parallel::parLapplyLB(cl, parts, one, m = maps[[r]], id = id, classes = classes)
    data.table::rbindlist(x)[, Run := r][] }))[, .(Fips = sprintf("%05d", as.integer(Fips)), Run, Year, Km2 = round(Km2, 4))] }
