# =============================================================================
# unit-study-boundary.R - a study area from the user's own boundary file (src/strata.R: boundary_polygon, boundary_name)
# =============================================================================
# The Study Area page takes a file of polygons in place of named units. boundary_polygon reads it as one outline in EPSG:5070 and
# stops with what is wrong. Made-up files in a temporary folder, no SyncroSim. Usage: Rscript tests/unit-study-boundary.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(sf); library(terra) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "strata.R"))
ok <- 0; bad <- 0
expect <- function(what, cond, detail = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, detail, "\n") } }
says <- function(expr) tryCatch({ force(expr); "" }, error = function(e) conditionMessage(e))
tmp <- file.path(tempdir(), "unit-study-boundary"); unlink(tmp, recursive = TRUE); dir.create(tmp)
box <- function(xa, xb, ya, yb, crs = 5070) st_sfc(st_polygon(list(rbind(c(xa, ya), c(xb, ya), c(xb, yb), c(xa, yb), c(xa, ya)))), crs = crs)
# two squares of 10 km in the Olympic Peninsula's part of EPSG:5070, 10 km apart, and one that overlaps the first by half
a <- box(-2100000, -2090000, 3050000, 3060000); b <- box(-2080000, -2070000, 3050000, 3060000); c2 <- box(-2095000, -2085000, 3050000, 3060000)
km2 <- function(p) as.numeric(st_area(p)) / 1e6

g1 <- file.path(tmp, "one.gpkg"); write_sf(st_sf(id = 1L, geometry = a), g1, quiet = TRUE)
p <- boundary_polygon(g1)
expect("a GeoPackage of one polygon: its outline in EPSG:5070", inherits(p, "sfc") && length(p) == 1 && st_crs(p) == st_crs(5070) && abs(km2(p) - 100) < 1e-6)

g2 <- file.path(tmp, "three.gpkg"); write_sf(st_sf(id = 1:3, geometry = c(a, b, c2)), g2, quiet = TRUE)
p <- boundary_polygon(g2)
expect("several polygons are taken together: overlap counted once, separate parts kept", length(p) == 1 && abs(km2(p) - 250) < 1e-6)

g3 <- file.path(tmp, "lonlat.geojson"); write_sf(st_transform(st_sf(id = 1L, geometry = a), 4326), g3, quiet = TRUE)
p <- boundary_polygon(g3)
expect("another projection (GeoJSON in longitude and latitude) is converted", st_crs(p) == st_crs(5070) && abs(km2(p) - 100) < 0.5 && abs(st_bbox(p)[["xmin"]] + 2100000) < 50)

s1 <- file.path(tmp, "shape.shp"); write_sf(st_sf(id = 1L, geometry = a), s1, quiet = TRUE)
expect("a shapefile with its companions", abs(km2(boundary_polygon(s1)) - 100) < 1e-6)
z <- file.path(tmp, "shape.zip"); old <- setwd(tmp); utils::zip(z, list.files(tmp, pattern = "^shape[.]"), flags = "-q"); setwd(old)
if (file.exists(z)) expect("a zipped shapefile", abs(km2(boundary_polygon(z)) - 100) < 1e-6) else cat("skip: no zip program on this machine\n")
invisible(file.remove(file.path(tmp, "shape.prj")))
expect("a shapefile without its .prj says it has no projection", grepl("no projection", says(boundary_polygon(s1))))

g4 <- file.path(tmp, "layers.gpkg"); write_sf(st_sf(id = 1L, geometry = a), g4, layer = "west", quiet = TRUE); write_sf(st_sf(id = 2L, geometry = b), g4, layer = "east", quiet = TRUE)
write_sf(st_sf(id = 3L, geometry = st_sfc(st_point(c(-2000000, 3000000)), crs = 5070)), g4, layer = "sites", quiet = TRUE)
expect("a file of several layers: the polygons of every layer, points left out", abs(km2(boundary_polygon(g4)) - 200) < 1e-6)

g5 <- file.path(tmp, "points.gpkg"); write_sf(st_sf(id = 1L, geometry = st_sfc(st_point(c(-2000000, 3000000)), crs = 5070)), g5, quiet = TRUE)
expect("a file with no polygons says so", grepl("no polygons", says(boundary_polygon(g5))))
g6 <- file.path(tmp, "alaska.gpkg"); write_sf(st_sf(id = 1L, geometry = box(-150, -149, 64, 65, 4326)), g6, quiet = TRUE)
expect("a boundary outside the lower 48 states says so", grepl("outside the lower 48", says(boundary_polygon(g6))))
expect("a file that is not there says so", grepl("does not exist", says(boundary_polygon(file.path(tmp, "nowhere.gpkg")))))
txt <- file.path(tmp, "notes.txt"); writeLines("not a map", txt)
expect("a file that is not a map says it could not be read, or has no polygons", grepl("could not be read|no polygons|no layers", says(boundary_polygon(txt))))
expect("no file named says so", grepl("no file named", says(boundary_polygon(NA))) && grepl("no file named", says(boundary_polygon(""))))

expect("the study area's name: the one typed, else the file's name", boundary_name("Upper Skokomish", g1) == "Upper Skokomish" && boundary_name(NA, g1) == "one" && boundary_name("  ", "C:/a b/My Area.v2.shp") == "My Area.v2")

# on the model grid: a cell is in when its centre is (stage 1: mask(P, rasterize(vect(poly), R, 1)))
R <- rast(xmin = -2101500, xmax = -2088500, ymin = 3048500, ymax = 3061500, resolution = 150, crs = "EPSG:5070")
n <- sum(!is.na(values(rasterize(vect(boundary_polygon(g1)), R, 1))))
expect("on a 150 m grid the outline keeps the cells whose centres it holds (100 km2: about 4,444 cells)", abs(n * 0.0225 - 100) < 1.5, sprintf("%d cells", n))

# the outline kept with the Build result (stage 1): GeoJSON in longitude and latitude, the same bytes each time, the same cells read back
keep <- function(p, f) { if (file.exists(f)) file.remove(f); write_sf(st_sf(name = "x", geometry = st_transform(p, 4326)), f, driver = "GeoJSON", quiet = TRUE); f }
dir.create(file.path(tmp, "a")); dir.create(file.path(tmp, "b"))   # (the file's name is written into it: stage 1 always uses the same one)
p0 <- boundary_polygon(g2); k1 <- keep(p0, file.path(tmp, "a", "study-area-boundary.geojson")); k2 <- keep(p0, file.path(tmp, "b", "study-area-boundary.geojson"))
expect("the kept outline is written the same byte for byte each time", unname(tools::md5sum(k1)) == unname(tools::md5sum(k2)))
back <- st_union(st_transform(st_geometry(read_sf(k1, quiet = TRUE)), 5070))
expect("read back, the kept outline has the area of the file's", abs(km2(back) - km2(p0)) < 1e-4)
cells <- function(p) which(!is.na(values(rasterize(vect(p), R, 1), mat = FALSE)))
expect("read back, the kept outline keeps the same cells", identical(cells(back), cells(p0)) && length(cells(p0)) > 1000)

unlink(tmp, recursive = TRUE)
cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
