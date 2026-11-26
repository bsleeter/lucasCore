# To-do 2 step 6: DSWE annual open water for a region already in the data home, through the package's own download handler
# (what a Data Download scenario with the source ticked would do), so a scratch library can run stage 6 on it.
# Usage: Rscript dev/wetland-change/dswe-region-download.R <home> <region folder name> [first year] [last year]     (from the package root)
suppressPackageStartupMessages({ library(data.table); library(terra) })
for (f in c("datahome.R", "download.R", "download-sources.R")) source(file.path("src", f))
args <- commandArgs(trailingOnly = TRUE); home <- normalizePath(args[1], winslash = "/"); rh <- file.path(home, "regions", args[2])
yy <- c(if (length(args) > 2) as.integer(args[3]) else min(DSWE_YEARS_SOURCE), if (length(args) > 3) as.integer(args[4]) else max(DSWE_YEARS_SOURCE))
m <- fread(file.path(rh, "manifest.csv"), colClasses = "character")[Column == "NlcdFolder"][1]   # the region as its annual NLCD was cut
stopifnot(nrow(m) == 1, !is.na(m$Xmin))
h <- download_handlers()$DsweFolder; layout <- fread("defaults/library/data-sources.csv", colClasses = "character")[Column == "DsweFolder"]
ctx <- list(home = home, region_home = rh, region = list(box = as.numeric(c(m$Xmin, m$Ymin, m$Xmax, m$Ymax)), poly = "polygon", units = m$Units, buffer_km = as.numeric(m$BufferKm)),
            years = yy, keep = FALSE, connections = 1L, opts = NULL, log = function(x) cat(x, "\n"))
t0 <- Sys.time(); out <- run_dataset(h, ctx, layout); cat(sprintf("%.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins")))); print(out)
f <- list.files(file.path(rh, layout$HomePath), "DSWE_open_water_.*tif$", full.names = TRUE); cat(length(f), "files,", round(sum(file.size(f)) / 1e6, 1), "MB\n"); print(rast(f[1]))
