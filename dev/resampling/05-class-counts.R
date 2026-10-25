# =============================================================================
# 05-class-counts.R - to-do item 8, all-class matching: each NLCD class's 30 m pixel count per 150 m cell, every year (P26)
# =============================================================================
# Same aggregation blocks as the Build (shared.R grid_blocks). Writes dev/resampling/cache/counts_<year>.tif: one layer per class
# (c11 ... c95, 0-25 pixels of a cell's 25) and `chg`, the cell's pixels whose class differs from the year before (0 in 1985): the 30 m
# gross change that a 150 m map can be compared with. Read-only; no package code is changed.
# Usage: Rscript dev/resampling/05-class-counts.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(parallel) })
pkg <- "F:/lucasCore"; out <- file.path(pkg, "dev/resampling/cache")
nlcd <- "F:/lucas-master/Data Sources/NLCD/Annual NLCD"; build <- file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim.data/Scenario-2")
years <- 1985:2023; CLS <- c(11, 12, 21, 22, 23, 24, 31, 41, 42, 43, 52, 71, 81, 82, 90, 95)
for (e in parse(file.path(pkg, "src/shared.R")))
  if (is.call(e) && identical(as.character(e[[1]]), "<-") && as.character(e[[2]]) %in% c("MODEL_CRS", "model_lattice", "grid_blocks")) eval(e, globalenv())
R <- rast(file.path(build, "stsim_InitialConditionsSpatial", "StateClass.tif"))
L <- model_lattice(st_transform(read_sf("F:/lucas-master/Data Sources/FIA/EcoDivision_map/EcoDivisions_Dissolve.shp"), MODEL_CRS), res(R)[1])
Rw <- wrap(R); Lw <- wrap(L)
cl <- makeCluster(8)   # the P26 historical run is using 17 cores
clusterExport(cl, c("grid_blocks", "Rw", "Lw", "nlcd", "out", "CLS"))
t0 <- Sys.time()
invisible(parLapply(cl, years, function(y) {
  library(terra); R <- unwrap(Rw); L <- unwrap(Lw)
  f <- file.path(out, sprintf("counts_%d.tif", y)); if (file.exists(f)) return(f)
  rd <- function(yy) { n <- rast(file.path(nlcd, sprintf("Annual_NLCD_LndCov_%d_CU_C1V0.tif", yy))); levels(n) <- NULL; n }
  n30 <- rd(y); b <- grid_blocks(n30, L, R); x <- crop(n30, b$ext)
  s <- aggregate(segregate(x, classes = CLS), b$fact, "sum", na.rm = TRUE); names(s) <- paste0("c", CLS)
  chg <- if (y > 1985) aggregate(x != crop(rd(y - 1), b$ext), b$fact, "sum", na.rm = TRUE) else aggregate(x * 0, b$fact, "sum", na.rm = TRUE)
  names(chg) <- "chg"; s <- mask(project(c(s, chg), R, method = "near"), R)
  writeRaster(s, f, overwrite = TRUE, datatype = "INT1U", gdal = c("COMPRESS=DEFLATE", "TILED=YES")); f }))
stopCluster(cl)
cat(sprintf("%d years in %.1f min\n", length(years), as.numeric(Sys.time() - t0, units = "mins")))
