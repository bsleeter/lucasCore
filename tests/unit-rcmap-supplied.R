# =============================================================================
# unit-rcmap-supplied.R - RCMAP when ScienceBase refuses a script: a copy supplied by hand (2026-11-02)
# =============================================================================
# Plain R, no SyncroSim, no network: url_gone is replaced and a coarse raster on RCMAP's extent stands in for the map. Checks that
#   - with the address gone and nothing supplied the dataset stops, says what to do, and records no done row
#   - with the address up the zip is fetched as before; a region east of the map still needs no file
#   - a supplied tif or zip is clipped and recorded as by hand, and the supplied file stays where it was put
#   - a tif that is not the RCMAP map is refused
# Usage: Rscript tests/unit-rcmap-supplied.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
for (f in c("datahome.R", "download.R", "download-sources.R")) source(file.path(pkg, "src", f))
ok <- 0; bad <- 0
expect <- function(what, cond) { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, "\n") } }
msg <- function(expr) tryCatch({ force(expr); "" }, error = function(e) conditionMessage(e))

root <- file.path(tempdir(), "rcmap-supplied"); unlink(root, recursive = TRUE); dir.create(root); root <- normalizePath(root, winslash = "/")
h <- download_handlers()$RcmapFile
layout <- data.table(Column = "RcmapFile", HomePath = "land-cover/rcmap", Source = "test", Version = h$version, Doi = NA_character_)
box <- c(-2100000, 2000000, -2000000, 2100000)
new_home <- function(name) { d <- file.path(root, name); dir.create(file.path(d, "regions", "R"), recursive = TRUE); dir.create(file.path(d, "supplied"))
  list(home = d, region_home = file.path(d, "regions", "R"), region = list(box = box, poly = "polygon", units = "R", buffer_km = 10), years = c(1985L, NA),
       keep = FALSE, connections = 1L, opts = NULL, log = function(x) invisible()) }
map <- function(file, e = RCMAP_EXT) { r <- rast(xmin = e[1], xmax = e[2], ymin = e[3], ymax = e[4], nrows = 100, ncols = 100, crs = "EPSG:5070"); values(r) <- 3L; writeRaster(r, file, overwrite = TRUE, datatype = "INT1U"); file }
url_gone <- function(u) TRUE

# ---- nothing supplied ------------------------------------------------------------------------------------------------------
a <- new_home("a"); m <- msg(run_dataset(h, a, layout))
expect("address gone, nothing supplied: stops by hand", startsWith(m, "by hand:"))
expect("the message names the item and the folder", grepl(RCMAP_ITEM, m, fixed = TRUE) && grepl(file.path(a$home, "supplied"), m, fixed = TRUE))
expect("no done row", !identical(read_manifest(a$region_home)[Column == "RcmapFile", Status], "done"))

# ---- the address up, and a region outside --------------------------------------------------------------------------------
url_gone <- function(u) FALSE
p <- h$plan(a)
expect("address up: the zip is fetched as before", nrow(p) == 1 && isTRUE(p$fetch) && !"supplied" %in% names(p) && identical(p$url, RCMAP_URL))
east <- a; east$region$box <- c(1000000, 2000000, 1100000, 2100000)
expect("a region east of the map needs no file", grepl("no file is needed", msg(h$plan(east))))
url_gone <- function(u) TRUE

# ---- a supplied tif --------------------------------------------------------------------------------------------------------
b <- new_home("b"); own <- map(file.path(b$home, "supplied", RCMAP_TIF)); before <- digest::digest(file = own)
chk <- run_dataset(h, b, layout, check_only = TRUE)
expect("Check only names the supplied copy and fetches nothing", grepl("supplied by hand", chk$Next) && chk$SizeMb == 0)
r <- run_dataset(h, b, layout)
mf <- read_manifest(b$region_home)[Column == "RcmapFile"]; clip <- file.path(b$region_home, "land-cover/rcmap", RCMAP_TIF)
expect("supplied tif: done", identical(r$Status, "done") && file.exists(clip))
expect("clipped to the region", ncell(rast(clip)) < 100 * 100)
expect("the manifest says by hand", identical(mf$Method, "by hand") && grepl("Supplied by hand", mf$Note))
expect("the source's address and version are still recorded", grepl("sciencebase", mf$Url) && identical(mf$Version, h$version))
expect("the supplied file stays, unchanged", file.exists(own) && identical(digest::digest(file = own), before))

# ---- kept whole: copied, not moved -----------------------------------------------------------------------------------------
w <- new_home("w"); w$keep <- TRUE; own <- map(file.path(w$home, "supplied", RCMAP_TIF)); r <- run_dataset(h, w, layout)
expect("Keep national copies: the supplied tif is copied whole and stays", identical(r$Status, "done") && file.exists(own) && ncell(rast(file.path(w$region_home, "land-cover/rcmap", RCMAP_TIF))) == 100 * 100)

# ---- a supplied zip ------------------------------------------------------------------------------------------------------
z <- new_home("z"); tif <- map(file.path(root, RCMAP_TIF)); zp <- file.path(z$home, "supplied", "1985_vegetation_state.zip")
owd <- setwd(root); utils::zip(zp, RCMAP_TIF, flags = "-q"); setwd(owd)
if (!file.exists(zp)) system2("tar", c("-a", "-c", "-f", shQuote(zp), "-C", shQuote(root), RCMAP_TIF))
r <- run_dataset(h, z, layout)
expect("supplied zip: done, and the zip stays", identical(r$Status, "done") && file.exists(zp) && file.exists(file.path(z$region_home, "land-cover/rcmap", RCMAP_TIF)))

# ---- not the map ---------------------------------------------------------------------------------------------------------
n <- new_home("n"); map(file.path(n$home, "supplied", RCMAP_TIF), c(-2400000, 2300000, 200000, 3200000))
expect("a tif on another extent is refused", grepl("not the RCMAP map", msg(run_dataset(h, n, layout))))

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
