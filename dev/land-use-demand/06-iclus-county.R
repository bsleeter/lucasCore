# =============================================================================
# 06-iclus-county.R - EPA ICLUS v2.1.1 land use by county: pixels by class in one decade and the next (exploratory; feeds 07)
# =============================================================================
# ICLUS v2.1.1 (U.S. EPA 2020; SSP2-RCP4.5 and SSP5-RCP8.5, each with HadGEM2-ES and GISS-E2-R driving migration): 90 m maps of 19
# land-use classes, 2000 and 2010 (US-NLUD, observed) and every decade 2020-2100. Three runs come as GeoTIFFs with the 2000 and 2010
# maps; SSP5 HadGEM2-ES comes as a file geodatabase of 2020-2100 only, so its 2000 and 2010 maps are taken from another run (they are
# the same observed maps). For every county wholly inside the grid, its pixels by class at each decade and the next.
# Writes cache/06-iclus-<run>.rds (Fips, Year = the first year of the step, a, b, N).
# Usage: Rscript dev/land-use-demand/06-iclus-county.R   (LUCAS_DATA_HOME = the Data Sources folder; maps in land-use/iclus)
# =============================================================================
pkg <- local({ d <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))); while (!file.exists(file.path(d, "package.xml")) && dirname(d) != d) d <- dirname(d); d })
DS <- Sys.getenv("LUCAS_DATA_HOME", "E:/lucasData"); suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) })
CA <- file.path(pkg, "dev/land-use-demand/cache"); dir.create(CA, showWarnings = FALSE); say <- function(...) cat(format(Sys.time(), "%H:%M"), sprintf(...), "\n")
IC <- file.path(DS, "land-use/iclus"); RUNS <- c("ssp2_rcp45_hadgem2_es", "ssp2_rcp45_giss_e2_r", "ssp5_rcp85_hadgem2_es", "ssp5_rcp85_giss_e2_r")
# the maps of a run: a named vector year -> source (a GeoTIFF, or a geodatabase raster)
maps <- function(run) { d <- file.path(IC, paste0("ICLUS_v2_1_1_land_use_conus_", run)); g <- paste0(d, ".gdb")
  if (dir.exists(d)) { f <- list.files(d, "_[0-9]{4}[^/]*[.]tif$", full.names = TRUE); return(setNames(f, sub(".*_conus_([0-9]{4}).*", "\\1", basename(f)))) }
  if (dir.exists(g)) { s <- describe(g, sds = TRUE)$name; return(setNames(s, sub(".*_conus_([0-9]{4})_.*", "\\1", s))) }
  stop("no ICLUS maps for ", run) }
all_maps <- lapply(setNames(RUNS, RUNS), maps)
base <- Filter(function(m) all(c("2000", "2010") %in% names(m)), all_maps)[[1]][c("2000", "2010")]
for (r in RUNS) { m <- all_maps[[r]]; m <- c(base[setdiff(names(base), names(m))], m); all_maps[[r]] <- m[order(as.integer(names(m)))]
  say("%s: %s", r, paste(names(all_maps[[r]]), collapse = " ")) }
cty <- read_sf(file.path(DS, "study-area/counties/tl_rd22_us_county.shp"))[, "GEOID"]
t0 <- rast(all_maps[[1]][1]); cp <- st_transform(cty, crs(t0)); cp <- cp[lengths(st_within(cp, st_as_sfc(st_bbox(ext(t0), crs = st_crs(crs(t0)))))) > 0, ]
say("grid %d x %d cells of %g m; %d counties wholly inside", ncol(t0), nrow(t0), res(t0)[1], nrow(cp))
cl <- parallel::makeCluster(min(32L, parallel::detectCores() - 4L))
for (r in RUNS) { cf <- file.path(CA, sprintf("06-iclus-%s.rds", r)); if (file.exists(cf)) { say("%s: cached", r); next }
  x <- rbindlist(parallel::parLapplyLB(cl, split(cp, seq_len(nrow(cp))), function(p, m) { library(terra); library(data.table); terraOptions(progress = 0, memfrac = 0.02)
    v <- vect(p); a <- rast(m[1]); e <- align(ext(v), a, snap = "out"); a <- crop(a, e); levels(a) <- NULL; z <- values(rasterize(v, a, 1), mat = FALSE); k <- !is.na(z)
    # the maps do not share one extent (the geodatabase's is smaller, and a run's decades can differ): each is cut to the county's
    # window, and put on the first map's cells by nearest neighbour where its lattice is offset
    val <- lapply(m, function(f) { b <- crop(rast(f), e, extend = TRUE); levels(b) <- NULL; if (!compareGeom(b, a, stopOnError = FALSE)) b <- resample(b, a, method = "near"); values(b, mat = FALSE)[k] })
    rbindlist(lapply(seq_len(length(m) - 1), function(i) data.table(a = val[[i]], b = val[[i + 1]])[, .N, by = .(a, b)][, Year := as.integer(names(m)[i])]))[, Fips := p$GEOID][] }, m = all_maps[[r]]))
  saveRDS(x, cf); dv <- 10:16
  say("%s: %d counties; new developed land (classes 3-9 to 10-16) km2 a decade: %s", r, uniqueN(x$Fips),
      paste(x[a %in% 3:9 & b %in% dv, .(k = sum(N) * res(t0)[1]^2 / 1e6), by = Year][order(Year), sprintf("%d %.0f", Year, k)], collapse = ", ")) }
parallel::stopCluster(cl)
