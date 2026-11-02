# =============================================================================
# unit-strata-home.R - the Stratum Sources presets read their polygons from Data Sources Home (2026-11-02)
# =============================================================================
# Plain R, no SyncroSim, no network. Checks that
#   - every preset but the shipped ecodivisions names a Data Download dataset (DataSource), which has a data-sources.csv row with a
#     home place, a handler that keeps it whole (national) and an endpoints.csv row; and no preset, nor the Studio template's Stratum
#     Sources, names a file on the build machine
#   - every preset's ListFile exists and gives exactly the units of the shipped universal list (so new libraries need no polygons)
#   - strata_path: a File that exists wins; a File this machine lacks, or a blank one, reads the home through lucas.strata.home; with
#     no home the error names the dataset to download
#   - the handlers' unpacking: a shapefile and its sidecars from a zip and from a .tar.gz, flat into place; layers of a zipped
#     GeoPackage copied with only the named fields; home_pick finds the result at the dataset's place
# Usage: Rscript tests/unit-strata-home.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(sf) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "strata.R")); source(file.path(pkg, "src", "datahome.R")); source(file.path(pkg, "src", "download.R")); source(file.path(pkg, "src", "download-sources.R"))
ok <- 0; bad <- 0
expect <- function(what, cond, detail = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, detail, "\n") } }
sd <- file.path(pkg, "defaults", "strata")
pre <- fread(file.path(sd, "presets.csv"), colClasses = "character", na.strings = "")
lay <- home_layout(pkg); ep <- fread(file.path(pkg, "defaults", "download", "endpoints.csv"), colClasses = "character", na.strings = "")
H <- download_handlers()

# ---- presets -> datasets --------------------------------------------------------------------------------------------------
dl <- pre[Preset != "FIA Ecodivisions"]
expect("every preset but the ecodivisions names a dataset", !anyNA(dl$DataSource))
expect("each dataset has a data-sources.csv row with a home place", all(dl$DataSource %in% lay[!is.na(HomePath), Column]))
expect("each dataset has a handler", all(dl$DataSource %in% names(H)), paste(setdiff(dl$DataSource, names(H)), collapse = ", "))
expect("each handler keeps its dataset whole (national, at the top)", all(vapply(H[unique(dl$DataSource)], function(h) isTRUE(h$national), TRUE)))
expect("each dataset has an endpoints.csv row, fetched", all(dl$DataSource %in% ep[Fetched == "yes", Column]))
expect("no preset names a file on the build machine", !any(grepl("^[A-Za-z]:|lucas-master", pre$File)))
tp <- fread(file.path(pkg, "defaults", "library", "project", "lucasCore_StratumSource.csv"), colClasses = "character", na.strings = "")
expect("nor does the Studio template's Stratum Sources", !any(grepl("^[A-Za-z]:|lucas-master", tp$File)) && setequal(tp$Name, pre$Preset))
expect("the template's ListFiles match the presets'", identical(tp[match(pre$Preset, Name), ListFile], pre$ListFile))
expect("data-sources.csv and endpoints.csv parse with their columns", ncol(lay) == 11 && all(c("Column", "Fetched") %in% names(ep)) && !anyDuplicated(lay$Column) && !anyDuplicated(ep$Column))

# ---- shipped unit lists ---------------------------------------------------------------------------------------------------
ul <- fread(file.path(pkg, "defaults", "library", "project", "stsim_SecondaryStratum.csv"), colClasses = c(Name = "character", Id = "numeric"))
rows <- strata_presets(pkg)
expect("every preset has a ListFile on disk", all(vapply(rows, function(s) !is.na(s$ListFile) && file.exists(strata_file(s$ListFile, pkg)), TRUE)))
u2 <- universal_list(rows, pkg)
expect(sprintf("the presets' lists give the shipped universal list (%d units)", nrow(ul)), nrow(u2) == nrow(ul) && setequal(paste(u2$Name, u2$Id), paste(ul$Name, as.integer(ul$Id))))

# ---- strata_path ----------------------------------------------------------------------------------------------------------
tmp <- file.path(tempdir(), "strata-home"); unlink(tmp, recursive = TRUE); dir.create(tmp)
own <- file.path(tmp, "own.shp"); writeLines("x", own); athome <- file.path(tmp, "home.shp"); writeLines("x", athome)
st <- rows[["States"]]
options(lucas.strata.home = function(col) if (col == "StatesFile") athome else NA_character_)
x <- strata_path(modifyList(st, list(File = own)), pkg)
expect("a File that exists wins", identical(as.character(x), own) && !isTRUE(attr(x, "home")))
x <- strata_path(modifyList(st, list(File = "Z:/nowhere/states.shp")), pkg)
expect("a File this machine lacks reads the home", identical(as.character(x), athome) && isTRUE(attr(x, "home")))
expect("a blank File reads the home", identical(as.character(strata_path(st, pkg)), athome))
options(lucas.strata.home = function(col) NA_character_)
e <- tryCatch(strata_path(st, pkg), error = function(e) conditionMessage(e))
expect("no home: the error names the dataset to download", grepl("Data Download", e) && grepl("StatesFile", e), e)
cu <- modifyList(st, list(Preset = "My Regions", File = "Z:/nowhere/mine.shp"))
e <- tryCatch(strata_path(cu, pkg), error = function(e) conditionMessage(e))
expect("a custom source with a missing File says to set it", grepl("not found", e) && !grepl("Data Download", e), e)
options(lucas.strata.home = NULL)

# ---- unpacking ------------------------------------------------------------------------------------------------------------
p <- st_sf(STATEFP = c("06", "32"), NAME = c("California", "Nevada"), geometry = st_sfc(st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 0)))),
                                                                             st_polygon(list(rbind(c(1, 0), c(2, 0), c(2, 1), c(1, 0)))), crs = 4269))
src <- file.path(tmp, "src", "Data"); dir.create(src, recursive = TRUE); write_sf(p, file.path(src, "states_x.shp"), quiet = TRUE)
writeLines("<metadata/>", file.path(src, "states_x.shp.xml")); writeLines("other", file.path(src, "states_xx.txt"))
old <- setwd(file.path(tmp, "src")); zip <- file.path(tmp, "a.zip"); utils::zip(zip, list.files("Data", full.names = TRUE), flags = "-q"); utils::tar(file.path(tmp, "a.tar.gz"), "Data", compression = "gzip"); setwd(old)
ctx <- list(dl = file.path(tmp, "dl"))
place <- file.path(tmp, "home", "study-area", "states")
x <- shp_from_archive(ctx, zip, "Data/states_x.shp", place)
expect("a zipped shapefile lands flat in place, with its sidecars", identical(x, file.path(place, "states_x.shp")) &&
       all(file.exists(file.path(place, paste0("states_x.", c("shp", "shx", "dbf", "prj", "shp.xml"))))) && !file.exists(file.path(place, "states_xx.txt")))
expect("and reads back", nrow(read_sf(x)) == 2)
x2 <- shp_from_archive(ctx, file.path(tmp, "a.tar.gz"), "Data/states_x.shp", file.path(tmp, "tarplace"))
expect("a .tar.gz shapefile too", file.exists(x2) && nrow(read_sf(x2)) == 2)
e <- tryCatch(shp_from_archive(ctx, zip, "Data/none.shp", file.path(tmp, "np")), error = function(e) conditionMessage(e))
expect("a member the archive lacks stops", grepl("lacks", e), e)
pk <- home_pick(file.path(tmp, "home"), "StatesFile", lay[Column == "StatesFile", HomePath])
expect("home_pick finds it at the dataset's place", !is.null(pk) && identical(normalizePath(pk$path), normalizePath(x)))
g <- file.path(tmp, "g"); dir.create(g); gp <- file.path(g, "w.gpkg")
write_sf(transform(p, huc6 = c("180101", "180102"), name = c("A", "B"), extra = 1)[, c("huc6", "name", "extra")], gp, layer = "WBDHU6", quiet = TRUE)
write_sf(transform(p, huc8 = c("18010101", "18010201"), name = c("C", "D"))[, c("huc8", "name")], gp, layer = "WBDHU8", append = TRUE, quiet = TRUE)
old <- setwd(g); gz <- file.path(tmp, "g.zip"); utils::zip(gz, "w.gpkg", flags = "-q"); setwd(old)
out <- layers_to_gpkg(gz, "w.gpkg", c("WBDHU6", "WBDHU8"), list(c("huc6", "name"), c("huc8", "name")), file.path(tmp, "out", "wbd.gpkg"))
L <- st_layers(out)
expect("zipped layers copied into one GeoPackage", setequal(L$name, c("WBDHU6", "WBDHU8")))
h6 <- read_sf(out, layer = "WBDHU6")
expect("with only the named fields", setequal(setdiff(names(h6), attr(h6, "sf_column")), c("huc6", "name")) && nrow(h6) == 2)
o1 <- layers_to_gpkg(gz, "w.gpkg", NULL, list("huc6"), file.path(tmp, "out", "one.gpkg"), names = "one")
expect("the first layer, renamed, when no layer is named", identical(st_layers(o1)$name, "one"))

# ---- a library row made before the home, reading the home copy: the preset's read fields apply ------------------------------
fp <- st_sf(Own_Name = c("USFS", "BLM", "TRIB"), geometry = st_sfc(st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 0)))),
  st_polygon(list(rbind(c(1, 0), c(2, 0), c(2, 1), c(1, 0)))), st_polygon(list(rbind(c(2, 0), c(3, 0), c(3, 1), c(2, 0)))), crs = 5070))
pg <- file.path(tmp, "padus.gpkg"); write_sf(fp, pg, layer = "federal_fee", quiet = TRUE)
write_sf(transform(fp, GAP_Sts = c("1", "2", "4"))[, "GAP_Sts"], pg, layer = "gap_status", append = TRUE, quiet = TRUE)
options(lucas.strata.home = function(col) if (col == "PadusFile") pg else NA_character_)
old_fed <- modifyList(rows[["Federal Lands"]], list(File = "Z:/another-machine/Federal Lands/fedlanp010g.shp", Layer = NA, ValueField = "ADMIN1"))
fz <- strata_polygons(old_fed, pkg)
expect("an old Federal Lands row reads the home's federal_fee layer by Own_Name", identical(sort(fz$StratumId), c(1L, 4L, 5L)), paste(fz$StratumId, collapse = ","))
gz2 <- strata_polygons(modifyList(rows[["GAP Status"]], list(Layer = NA)), pkg)
expect("GAP Status reads the gap_status layer of the same file", identical(sort(gz2$StratumId), c(1L, 2L, 4L)))
options(lucas.strata.home = NULL)

# ---- curved polygons (PAD-US has MULTISURFACE features) are made straight-edged, which terra can rasterize ----------------
cv <- st_sf(id = 1:2, geometry = st_as_sfc(c("CURVEPOLYGON(CIRCULARSTRING(0 0, 10 10, 20 0, 10 -10, 0 0))", "POLYGON((30 0, 40 0, 40 10, 30 0))"), crs = 5070))
lp <- linear_polygons(cv)
expect("a curved polygon is made straight-edged, the others kept", all(as.character(st_geometry_type(lp)) %in% c("POLYGON", "MULTIPOLYGON")) &&
       abs(as.numeric(st_area(lp)[1]) - pi * 100) / (pi * 100) < 0.01 && identical(st_geometry(lp)[[2]], st_geometry(cv)[[2]]))
expect("and terra takes it", !inherits(tryCatch(terra::vect(lp), error = function(e) e), "error"))

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
