# Fast test of the USGS DSWE annual open water Data Source (no SyncroSim, no network). Run: Rscript tests/unit-dswe-source.R (from the package root)
# The download itself reads USGS's bucket: dev/wetland-change/dswe-handler-check.R runs it on a small region.
suppressPackageStartupMessages({ library(data.table); library(terra) })
for (f in c("datahome.R", "download.R", "download-sources.R")) source(file.path("src", f))
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
h <- download_handlers()$DsweFolder
check("there is a DsweFolder handler that clips at its source", !is.null(h) && h$column == "DsweFolder" && isTRUE(h$clips) && h$method == "cog")
ctx <- function(y) list(years = y, region = list(box = c(-2118795, 1922925, -2099085, 1938255), poly = "polygon"), keep = FALSE)
p <- h$plan(ctx(c(2019L, 2021L)))
check("the plan is one file a year, read where it sits", identical(p$year, 2019:2021) && identical(p$out, sprintf("DSWE_open_water_%d.tif", 2019:2021)) && !any(p$fetch))
check("an open end year runs to the last year the source has", max(h$plan(ctx(c(2020L, NA)))$year) == max(DSWE_YEARS_SOURCE))
check("years outside the source are refused", inherits(try(h$plan(ctx(c(1970L, 1980L))), silent = TRUE), "try-error"))
t21 <- c("https://example.org/abc/DSWE_H02V09_Annual_2021_Props.tif", "https://example.org/def/DSWE_H03V09_Annual_2021_Props.tif")
check("a tile's address for another year differs only in the year", identical(dswe_year(t21, 1994L), sub("2021", "1994", t21)) && identical(dswe_year(t21, 2021L), t21))
# ---- a year's open water from two tiles: band 2 only, cut to the region, on the tiles' grid ----
d <- file.path(tempdir(), "dswe-unit"); unlink(d, recursive = TRUE); dir.create(d)
tile <- function(name, xmin, v) { r <- rast(nrows = 10, ncols = 10, xmin = xmin, xmax = xmin + 300, ymin = 0, ymax = 300, crs = "EPSG:5070", nlyrs = 5)
  values(r) <- cbind(1L, rep(v, 100), 3L, 4L, 5L); f <- file.path(d, sprintf("DSWE_%s_Annual_2021_Props.tif", name)); writeRaster(r, f, datatype = "INT1U", NAflag = 255, overwrite = TRUE); f }
tl <- c(tile("A", 0, 80L), tile("B", 300, 20L)); for (f in tl) file.copy(f, sub("2021", "2020", f))
local_open <- function(tiles, year, dest, region) { src <- dswe_year(tiles, year); ok <- file.exists(src)   # dswe_open_water with files on disk in place of /vsicurl/
  v <- tempfile(fileext = ".vrt"); sf::gdal_utils("buildvrt", src[ok], v, options = c("-b", "2")); clip_raster(v, dest, region); sum(!ok) }
miss <- local_open(tl, 2020L, file.path(d, "out.tif"), list(box = c(150, 30, 450, 270), poly = "polygon")); r <- rast(file.path(d, "out.tif"))
check("the mosaic keeps band 2 of each tile and nothing else", miss == 0 && nlyr(r) == 1 && setequal(unique(values(r, mat = FALSE)), c(80L, 20L)))
check("it is cut to the region's box on the tiles' own cells", all(as.vector(ext(r)) == c(150, 450, 30, 270)) && all(res(r) == 30))
file.remove(sub("2021", "2020", tl[2]))
check("a tile with no file in a year is counted, and the rest is still written", local_open(tl, 2020L, file.path(d, "out2.tif"), list(box = c(30, 30, 270, 270), poly = "polygon")) == 1)
# ---- registered everywhere a Data Source is ----
ds <- fread("defaults/library/data-sources.csv", colClasses = "character")[Column == "DsweFolder"]
check("data-sources.csv has the row with a home place and the DOI", nrow(ds) == 1 && ds$HomePath == "land-cover/dswe-open-water" && ds$Doi == "10.5066/P16Q2FUD")
ep <- fread("defaults/download/endpoints.csv", colClasses = "character")[Column == "DsweFolder"]
check("endpoints.csv has the row, clipped at the source", nrow(ep) == 1 && ep$Method == "cog" && ep$Clip == "source")
check("citations.csv has the citation", nrow(fread("defaults/metadata/citations.csv", colClasses = "character")[Column == "DsweFolder"]) == 1)
x <- paste(readLines("package.xml", warn = FALSE), collapse = "\n")
check("package.xml: DsweFolder is a Data Sources column", grepl('<column name="DsweFolder" [^>]*isOptional="True"/>', x))
u <- paste(readLines("ui/LucasCoreUpdates.cs", warn = FALSE), collapse = "\n")
check("the library update adds the column", grepl('AddColumn(store, "lucasCore_DataSource", "DsweFolder", "TEXT")', u, fixed = TRUE))
check("the update description has no apostrophe", !grepl("'", regmatches(u, regexpr('\\[Update\\(2\\.1, "[^"]*"', u))))
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
