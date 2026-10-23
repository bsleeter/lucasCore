# =============================================================================
# fetch-nccpi.R - gNATSGO crop productivity (NCCPI, nccpi3all) for a region, from Microsoft Planetary Computer, as one 30 m GeoTIFF
# =============================================================================
# Stage 10 fetches NCCPI for its fitting region by itself when Data Source NccpiFile is blank; this makes a file to point NccpiFile at
# (EPSG:5070, on the NLCD 30 m lattice, masked to the buffered region). The download logic is src/nccpi.R.
# Usage: Rscript tools/fetch-nccpi.R --pyrome=26 [--buffer=10000] [--out="F:/lucas-master/Data Sources/gSSURGO/nccpi3all_P26.tif"]
#        Rscript tools/fetch-nccpi.R --vector=<polygons> [--buffer=...] --out=...
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(jsonlite) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
source(file.path(here, "..", "src", "nccpi.R"))
DS <- "F:/lucas-master/Data Sources"; buf <- as.numeric(opt("buffer", 10000))
py <- opt("pyrome", NA)
if (!is.na(py)) { v <- vect(file.path(DS, "Pyromes", "Data", "Pyromes_CONUS_20200206.shp")); v <- v[v$PYROME == as.integer(py)]
  out <- opt("out", file.path(DS, "gSSURGO", sprintf("nccpi3all_P%s.tif", py)))
} else { vf <- opt("vector", NA); if (is.na(vf)) stop("give --pyrome or --vector"); v <- vect(vf); out <- opt("out", NA); if (is.na(out)) stop("give --out") }
if (!nrow(v)) stop("no polygons")
reg <- buffer(project(aggregate(v), "EPSG:5070"), buf)
# the NLCD 30 m lattice (EPSG:5070, origin on 30 m multiples) over the buffered region
e <- ext(reg); g <- rast(ext(floor(e$xmin / 30) * 30, ceiling(e$xmax / 30) * 30, floor(e$ymin / 30) * 30, ceiling(e$ymax / 30) * 30), res = 30, crs = "EPSG:5070")
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
tmp <- tempfile(fileext = ".tif"); n <- fetch_nccpi(g, tmp)
m <- mask(rast(tmp), reg); writeRaster(m, out, overwrite = TRUE, gdal = c("COMPRESS=DEFLATE", "TILED=YES"), datatype = "FLT4S")
s <- global(m, c("min", "max", "mean", "notNA"), na.rm = TRUE)
cat(sprintf("wrote %s from %d tiles: %d x %d cells, NCCPI %.2f-%.2f (mean %.2f), %.0f%% of the region covered\n", out, n, nrow(m), ncol(m), s$min, s$max, s$mean, 100 * s$notNA / global(rasterize(reg, g), "notNA")[[1]]))
