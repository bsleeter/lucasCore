# =============================================================================
# export-carbon-maps-150.R - full-resolution carbon maps for the dashboard: compressed 16-bit grids, one JSON file per map
# =============================================================================
# Live biomass (stock group Biomass: Total) and dead organic matter including soil (Total Ecosystem - Biomass: Total; the run maps
# no DOM total group) in the first and last year, and mean annual NECB (the Total Ecosystem change over the years, g C/m2/yr). Each
# map is the model grid, row by row, coded 0-65534 between the map's own min and max (65535 = no data), little-endian uint16,
# zlib-compressed and base64: [{Map, Label, Units, Year, Columns, Rows, CellSize, Min, Max, Data}] (the page decodes it with the
# browser's DecompressionStream('deflate')). Coding steps are (Max - Min) / 65534: under 0.01 Mg C/ha for the stock maps.
# Also the change in DOM + soil, and a hillshade of the DEM on the same grid for the page to shade the maps with.
# Usage: Rscript tools/export-carbon-maps-150.R <library.ssim> <result scenario id> <out folder> [<DEM .tif>]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra); library(jsonlite) })
a <- commandArgs(TRUE); if (length(a) < 3) stop("usage: Rscript tools/export-carbon-maps-150.R <library.ssim> <result id> <out folder>")
f <- normalizePath(a[1], winslash = "/"); rid <- as.integer(a[2]); out <- a[3]; dir.create(out, showWarnings = FALSE, recursive = TRUE)
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions")
sg <- as.data.table(datasheet(P, "stsim_StockGroup", includeKey = TRUE)); gid <- function(n) sg[Name == n, StockGroupId]
D <- file.path(paste0(f, ".data"), sprintf("Scenario-%d", rid), "stsim_OutputAverageSpatialStockGroup")
yrs <- range(as.integer(sub(".*ts([0-9]+)[.]tif$", "\\1", list.files(D, "[.]tif$"))))
r <- function(n, y) { p <- file.path(D, sprintf("avgstkg_%d.it0.ts%d.tif", gid(n), y)); if (!file.exists(p)) stop("no map ", basename(p)); rast(p) }
live <- lapply(yrs, function(y) r("Biomass: Total", y)); tot <- lapply(yrs, function(y) r("Total Ecosystem", y))
dom <- Map(`-`, tot, live); necb <- (tot[[2]] - tot[[1]]) / diff(yrs) * 100

enc <- function(x, map, label, units, year) { v <- values(x, mat = FALSE); lo <- min(v, na.rm = TRUE); hi <- max(v, na.rm = TRUE)
  code <- ifelse(is.na(v), 65535L, as.integer(round((v - lo) / max(hi - lo, 1e-9) * 65534)))
  z <- memCompress(writeBin(code, raw(), size = 2, endian = "little"), "gzip")
  stopifnot(identical(readBin(memDecompress(z, "gzip"), "integer", n = length(code), size = 2, signed = FALSE, endian = "little"), code))
  list(Map = map, Label = label, Units = units, Year = year, Columns = ncol(x), Rows = nrow(x), CellSize = res(x)[1], Min = lo, Max = hi, Data = base64_enc(z)) }
# a hillshade for the page to shade the maps with: the DEM averaged onto the model grid, lit from the northwest at 45 degrees
dem_file <- if (length(a) >= 4) a[4] else "F:/lucas-master/Data Sources/DEM/LF2020_Elev_220_CONUS/Tif/LC20_Elev_220.tif"
g <- live[[1]]; dem <- rast(dem_file); levels(dem) <- NULL
dem <- project(crop(dem, project(as.polygons(ext(g) + 1000, crs = crs(g)), crs(dem))), g, method = "average")
hs <- shade(terrain(dem, "slope", unit = "radians"), terrain(dem, "aspect", unit = "radians"), angle = 45, direction = 315)
maps <- list(enc(live[[1]], "live", "Live biomass", "Mg C/ha", yrs[1]), enc(live[[2]], "live", "Live biomass", "Mg C/ha", yrs[2]),
             enc(dom[[1]], "dom", "Dead organic matter and soil", "Mg C/ha", yrs[1]), enc(dom[[2]], "dom", "Dead organic matter and soil", "Mg C/ha", yrs[2]),
             enc(necb, "necb", "NECB, mean per year", "g C/m2/yr", NA_integer_),
             enc(dom[[2]] - dom[[1]], "domchange", "Change in dead organic matter and soil", "Mg C/ha", NA_integer_),
             enc(hs, "hillshade", "Hillshade (LANDFIRE elevation)", "0-1", NA_integer_))
for (m in maps) { fn <- file.path(out, sprintf("map-%s%s.json", m$Map, if (is.na(m$Year)) "" else paste0("-", m$Year)))
  write_json(list(m), fn, auto_unbox = TRUE, digits = NA); cat(sprintf("%s: %s %s, %d x %d, %.1f-%.1f %s, %.1f MB\n", basename(fn), m$Label, m$Year, m$Columns, m$Rows, m$Min, m$Max, m$Units, file.size(fn) / 1e6)) }
cell_ha <- prod(res(live[[1]])) / 1e4
cat(sprintf("totals: live %.1f / %.1f Tg, DOM %.1f / %.1f Tg (%d / %d)\n", global(live[[1]], "sum", na.rm = TRUE)[[1]] * cell_ha / 1e6, global(live[[2]], "sum", na.rm = TRUE)[[1]] * cell_ha / 1e6,
            global(dom[[1]], "sum", na.rm = TRUE)[[1]] * cell_ha / 1e6, global(dom[[2]], "sum", na.rm = TRUE)[[1]] * cell_ha / 1e6, yrs[1], yrs[2]))
