# To-do 2 step 3: the DSWE download handler on a small region (network), against the crops the tests read by hand.
# Usage: Rscript dev/wetland-change/dswe-handler-check.R <cache dir>     (from the package root; writes into a temporary home)
suppressPackageStartupMessages({ library(data.table); library(terra) })
for (f in c("datahome.R", "download.R", "download-sources.R")) source(file.path("src", f))
cache <- commandArgs(trailingOnly = TRUE)[1]
root <- file.path(tempdir(), "dswe-check"); unlink(root, recursive = TRUE); dir.create(file.path(root, "regions", "R"), recursive = TRUE); root <- normalizePath(root, winslash = "/")
box <- as.vector(ext(project(vect(ext(-120.6, -120.4, 37.9, 38.0), crs = "EPSG:4326"), "EPSG:5070")))[c(1, 3, 2, 4)]   # around New Melones
h <- download_handlers()$DsweFolder
layout <- fread("defaults/library/data-sources.csv", colClasses = "character")[Column == "DsweFolder"]
ctx <- list(home = root, region_home = file.path(root, "regions", "R"), region = list(box = box, poly = "polygon", units = "R", buffer_km = 0), years = c(2020L, 2021L),
  keep = FALSE, connections = 1L, opts = NULL, log = function(x) cat(x, "\n"))
t0 <- Sys.time(); out <- run_dataset(h, ctx, layout); cat(sprintf("%.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins")))); print(out)
f <- list.files(root, "DSWE_open_water_.*tif$", recursive = TRUE, full.names = TRUE); print(data.table(File = basename(f), Kb = round(file.size(f) / 1024)))
r <- rast(f[grepl("2021", f)]); print(r)
old <- rast(file.path(cache, "dswe-sierra-nevada-reservoirs-2021.tif"), lyrs = 1); crs(old) <- crs(r)
a <- values(crop(r, intersect(ext(r), ext(old))), mat = FALSE); b <- values(crop(old, intersect(ext(r), ext(old))), mat = FALSE)
cat("cells compared", length(a), "; same value", sum(a == b | (is.na(a) & is.na(b)), na.rm = TRUE), "; water cells (50 or more)", sum(a >= 50, na.rm = TRUE), "\n")
cat("grid on the 30 m NLCD grid:", all(abs((as.vector(ext(r)) - c(-2415585, -2415585, 164805, 164805)) %% 30) < 1e-6 | abs((as.vector(ext(r)) - c(-2415585, -2415585, 164805, 164805)) %% 30 - 30) < 1e-6), "\n")
print(list.files(root, "\\.csv$", recursive = TRUE))   # the record the download leaves beside the files
