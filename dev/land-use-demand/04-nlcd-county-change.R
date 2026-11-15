# =============================================================================
# 04-nlcd-county-change.R - Annual NLCD pixels by county, class in one year and class in another (exploratory; feeds 05 and 06)
# =============================================================================
# For each pair of years given, every county wholly inside the national Annual NLCD mosaic is counted pixel by pixel: its 30 m pixels
# by their class in the first year and in the second (end points, so a pixel that flickers and returns is not counted). One county
# at a time in parallel (the mosaic is 16 billion pixels). Writes cache/04-nlcd-<y0>-<y1>.rds (Fips, a, b, N); 02-rpa-vs-nlcd.R made
# the same table for 2012-2020 from any NLCD copy.
# Usage: Rscript dev/land-use-demand/04-nlcd-county-change.R 2000-2010 2010-2020   (LUCAS_NLCD_NATIONAL = the folder of the mosaics)
# =============================================================================
pkg <- local({ d <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))); while (!file.exists(file.path(d, "package.xml")) && dirname(d) != d) d <- dirname(d); d })
DS <- Sys.getenv("LUCAS_DATA_HOME", "E:/lucasData"); NL <- Sys.getenv("LUCAS_NLCD_NATIONAL", "F:/lucas-master/Data Sources/NLCD/Annual NLCD")
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) })
CA <- file.path(pkg, "dev/land-use-demand/cache"); dir.create(CA, showWarnings = FALSE); say <- function(...) cat(format(Sys.time(), "%H:%M"), sprintf(...), "\n")
nf <- function(y) { f <- file.path(NL, sprintf("Annual_NLCD_LndCov_%d_CU_C1V%d.tif", y, c(0L, 2L))); f <- f[file.exists(f)]; if (!length(f)) stop("no Annual NLCD for ", y, " in ", NL); f[1] }
pairs <- commandArgs(TRUE); if (!length(pairs)) pairs <- c("2000-2010", "2010-2020")
cty <- read_sf(file.path(DS, "study-area/counties/tl_rd22_us_county.shp"))[, "GEOID"]
cl <- parallel::makeCluster(min(32L, parallel::detectCores() - 4L))
for (p in pairs) { y <- as.integer(strsplit(p, "-")[[1]]); cf <- file.path(CA, sprintf("04-nlcd-%d-%d.rds", y[1], y[2])); if (file.exists(cf)) { say("%s: cached", p); next }
  fa <- nf(y[1]); fb <- nf(y[2]); a <- rast(fa); cp <- st_transform(cty, crs(a)); cp <- cp[lengths(st_within(cp, st_as_sfc(st_bbox(ext(a), crs = st_crs(crs(a)))))) > 0, ]
  x <- rbindlist(parallel::parLapplyLB(cl, split(cp, seq_len(nrow(cp))), function(p, fa, fb) { library(terra); library(data.table); terraOptions(progress = 0, memfrac = 0.02)
    a <- rast(fa); v <- vect(p); a <- crop(a, align(ext(v), a, snap = "out")); b <- crop(rast(fb), a); levels(a) <- NULL; levels(b) <- NULL
    z <- rasterize(v, a, 1)
    data.table(z = values(z, mat = FALSE), a = values(a, mat = FALSE), b = values(b, mat = FALSE))[!is.na(z), .N, by = .(a, b)][, Fips := p$GEOID][] }, fa = fa, fb = fb))
  saveRDS(x, cf); say("%s: %d counties, %.0f km2 newly developed", p, uniqueN(x$Fips), x[!(a %in% c(21:24, 11L, 12L)) & b %in% 21:24, sum(N)] * 900 / 1e6) }
parallel::stopCluster(cl)
