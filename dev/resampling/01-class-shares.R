# =============================================================================
# 01-class-shares.R - to-do item 8 (area-preserving resampling): the 30 m Annual NLCD summarised on P26's 150 m model grid
# =============================================================================
# For every year 1985-2023, over the same aggregation blocks the Build uses (shared.R grid_blocks, nlcd_on_grid), writes one 150 m
# stack per year to dev/resampling/cache/shares_<year>.tif with layers:
#   modal     the Build's class (most common 30 m class; must equal the Build result's NLCD_<year>.tif)
#   dev       share of the cell's 30 m pixels that are developed (21-24)
#   devmode   most common developed class among them (NA if none)
#   nondev    most common non-developed class (NA if all developed)
#   ag        share in agriculture (81, 82)
#   forest    share in forest (41-43)
# Read-only on the library and the data sources; no package code is changed. 02-compare-methods.R builds the alternatives from these.
# Usage: Rscript dev/resampling/01-class-shares.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(parallel) })
pkg <- "F:/lucasCore"; lib <- file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim")
out <- file.path(pkg, "dev/resampling/cache"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
nlcd <- "F:/lucas-master/Data Sources/NLCD/Annual NLCD"; eco <- "F:/lucas-master/Data Sources/FIA/EcoDivision_map/EcoDivisions_Dissolve.shp"
build <- file.path(paste0(lib, ".data"), "Scenario-2")
years <- 1985:2023

# the Build's lattice and block functions, taken from shared.R without running the rest of it (it needs a SyncroSim session)
for (e in parse(file.path(pkg, "src/shared.R")))
  if (is.call(e) && identical(as.character(e[[1]]), "<-") && as.character(e[[2]]) %in% c("MODEL_CRS", "model_lattice", "grid_blocks")) eval(e, globalenv())
R <- rast(file.path(build, "stsim_InitialConditionsSpatial", "StateClass.tif"))
L <- model_lattice(st_transform(read_sf(eco), MODEL_CRS), res(R)[1])
Rw <- wrap(R); Lw <- wrap(L)

cl <- makeCluster(8)   # the P26 historical run is using 17 cores; keep this modest
clusterExport(cl, c("grid_blocks", "Rw", "Lw", "nlcd", "out"))
t0 <- Sys.time()
done <- parLapply(cl, years, function(y) {
  library(terra); R <- unwrap(Rw); L <- unwrap(Lw)
  f <- file.path(out, sprintf("shares_%d.tif", y)); if (file.exists(f)) return(f)
  n30 <- rast(file.path(nlcd, sprintf("Annual_NLCD_LndCov_%d_CU_C1V0.tif", y))); b <- grid_blocks(n30, L, R)
  x <- crop(n30, b$ext); levels(x) <- NULL; k <- b$fact
  dev <- x >= 21 & x <= 24
  s <- c(aggregate(x, k, "modal", na.rm = TRUE),
         aggregate(dev, k, "mean", na.rm = TRUE),
         aggregate(mask(x, dev, maskvalues = 0), k, "modal", na.rm = TRUE),
         aggregate(mask(x, dev, maskvalues = 1), k, "modal", na.rm = TRUE),
         aggregate(x == 81 | x == 82, k, "mean", na.rm = TRUE),
         aggregate(x >= 41 & x <= 43, k, "mean", na.rm = TRUE))
  s <- mask(project(s, R, method = "near"), R); names(s) <- c("modal", "dev", "devmode", "nondev", "ag", "forest")
  writeRaster(s, f, overwrite = TRUE, datatype = "FLT4S", gdal = c("COMPRESS=DEFLATE", "TILED=YES")); f })   # FLT4S: the shares are fractions
stopCluster(cl)
cat(sprintf("%d years in %.1f min\n", length(done), as.numeric(Sys.time() - t0, units = "mins")))

# the modal layer must reproduce the Build's own maps
for (y in c(1985, 2023)) {
  a <- rast(file.path(out, sprintf("shares_%d.tif", y)))[["modal"]]; b <- rast(file.path(build, "lucasCore_OutputNlcdAnnual", sprintf("NLCD_%d.tif", y)))
  d <- global(a != b, "sum", na.rm = TRUE)[[1]]; n <- global(!is.na(b), "sum")[[1]]
  cat(sprintf("%d: modal vs the Build's NLCD_%d.tif: %d of %d cells differ\n", y, y, d, n)) }
