# A home's LOCA2 folder serves all its regions: west cut and CONUS file of the same run can sit side by side.
# loca2_best must take one file per period, and never a file that misses the study window.
# Run: Rscript tests/unit-loca2-cuts.R (from the package root)
suppressPackageStartupMessages({ library(data.table); library(terra) })
source("src/loca2.R")
d <- tempfile("loca2-"); dir.create(d)
mk <- function(name, x0, x1, y0, y1) { f <- file.path(d, name); writeRaster(rast(ext(x0, x1, y0, y1), res = 0.5, vals = 1, crs = "EPSG:4326"), f); f }
# longitudes 0-360 as the real files have them
conus1 <- mk("a.1950-2014.tif", 234.5, 293.5, 23.875, 53.5); west1 <- mk("a.1950-2014.west.tif", 235.5, 246.5, 32, 42)
conus2 <- mk("a.2015-2044.tif", 234.5, 293.5, 23.875, 53.5); west2 <- mk("a.2015-2044.west.tif", 235.5, 246.5, 32, 42)
fs <- data.table(file = c(conus1, west1, conus2, west2), y0 = c(1950L, 1950L, 2015L, 2015L), y1 = c(2014L, 2014L, 2044L, 2044L))
puget <- ext(-125.07, -120.19, 45.18, 49.84)    # north of the west cut
sierra <- ext(-122, -119, 38, 41)               # inside both
edge <- ext(-125.07, -120, 40, 44)              # runs past the top of the west cut
nowhere <- ext(10, 11, 45, 46)
fails <- 0L
check <- function(what, got, want) { ok <- identical(got, want); if (!ok) fails <<- fails + 1L
  cat(sprintf("%s: %s\n", if (ok) "pass" else "FAIL", what)); if (!ok) { cat(" got: ", basename(got), "\n want:", basename(want), "\n") } }
check("window north of the west cut takes CONUS, one file per period", loca2_best(fs, puget)$file, c(conus1, conus2))
check("window inside both takes the smaller cut", loca2_best(fs, sierra)$file, c(west1, west2))
check("window past the edge of the west cut takes CONUS", loca2_best(fs, edge)$file, c(conus1, conus2))
check("window outside every file takes nothing", loca2_best(fs, nowhere)$file, character())
check("west cut alone and missing the window is dropped", loca2_best(fs[file %in% c(west1, west2)], puget)$file, character())
check("an empty list stays empty", loca2_best(fs[0], puget)$file, character())
check("shuffled input keeps the periods in order", loca2_best(fs[c(4, 1, 3, 2)], puget)$file, c(conus1, conus2))
r <- loca2_rast(conus1); check("longitudes shift to -180..180", round(as.vector(ext(r))[["xmin"]], 1), -125.5)
unlink(d, recursive = TRUE)
if (fails) stop(fails, " failed") else cat("all passed\n")
