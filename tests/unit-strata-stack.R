# =============================================================================
# unit-strata-stack.R - a strata slot made of several sources (src/strata.R: strata_stack, strata_cover, strata_units)
# =============================================================================
# Land Manager and Land Designation are stacks: each cell takes the unit of the first source in the stack whose polygons cover it,
# and the cells none covers take the StackRest source's unit under that source's own fill rule. Made-up polygons on a 10 x 10 grid
# of 1 km cells, in a made-up package folder (presets.csv and three polygon files), no SyncroSim:
#   Park    x 0-5 km, all y        (id 1)      Forest  x 3-8 km, all y   (id 2)      Owner  y 0-5 km, all x  (id 3; uncovered = 9)
#   Wild    x 0-2 km, y 5-10 km    (id 7; uncovered = 9999)
# Usage: Rscript tests/unit-strata-stack.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(sf); library(terra) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "strata.R"))
ok <- 0; bad <- 0
expect <- function(what, cond, detail = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, detail, "\n") } }
tmp <- file.path(tempdir(), "unit-strata-stack"); unlink(tmp, recursive = TRUE); sd <- file.path(tmp, "defaults", "strata"); dir.create(sd, recursive = TRUE)
x0 <- 0; y0 <- 1000000   # (a corner in EPSG:5070)
box <- function(xa, xb, ya, yb, id) st_sf(id = id, geometry = st_sfc(st_polygon(list(rbind(c(x0 + xa, y0 + ya), c(x0 + xb, y0 + ya), c(x0 + xb, y0 + yb), c(x0 + xa, y0 + yb), c(x0 + xa, y0 + ya)) )), crs = 5070))
write_sf(box(0, 5000, 0, 10000, 1L), file.path(sd, "park.gpkg"), quiet = TRUE); write_sf(box(3000, 8000, 0, 10000, 2L), file.path(sd, "forest.gpkg"), quiet = TRUE)
write_sf(box(0, 10000, 0, 5000, 3L), file.path(sd, "owner.gpkg"), quiet = TRUE); write_sf(box(0, 2000, 5000, 10000, 7L), file.path(sd, "wild.gpkg"), quiet = TRUE)
pre <- data.table(Preset = c("Park", "Forest", "Owner", "Wild", "Manager", "Manager Forest First", "Designation", "Broken"), Number = c(10, 13, 8, 14, 101, 103, 102, 104),
                  Prefix = c("NPS", "NF", "Federal", "Wilderness", "Manager", "Manager2", "Designation", "Broken"), File = c("park.gpkg", "forest.gpkg", "owner.gpkg", "wild.gpkg", NA, NA, NA, NA),
                  IdField = c("id", "id", "id", "id", NA, NA, NA, NA), Overlap = "Last", Fill = "Default", DefaultId = c(9999, 9999, 9, 9999, NA, NA, NA, NA),
                  Stack = c(NA, NA, NA, NA, "Park;Forest;Owner", "Forest; Park;Owner", "Wild;Park", "Park;Nowhere"), StackRest = c(NA, NA, NA, NA, NA, NA, "Wild", NA))
fwrite(pre, file.path(sd, "presets.csv")); rows <- strata_presets(tmp)
R <- rast(xmin = x0, xmax = x0 + 10000, ymin = y0, ymax = y0 + 10000, resolution = 1000, crs = "EPSG:5070"); P <- setValues(R, 1L); P[1, 10] <- NA   # (one cell, top right, is not land)
at <- function(r, xkm, ykm) as.numeric(r[cellFromXY(r, cbind(x0 + xkm * 1000 + 500, y0 + ykm * 1000 + 500))][[1]])
U <- function(n, id) n * UNIT_OFFSET + id

expect("a source of its own polygons is not a stack; a stack lists its sources in order", is.null(strata_stack(rows$Park, tmp)) && identical(strata_stack(rows$Manager, tmp)$members, c("Park", "Forest", "Owner")))
expect("the cells no source covers come from the last of the stack, or the one named", strata_stack(rows$Manager, tmp)$rest == "Owner" && strata_stack(rows$Designation, tmp)$rest == "Wild")
expect("names in a stack may have spaces around them", identical(strata_stack(rows[["Manager Forest First"]], tmp)$members, c("Forest", "Park", "Owner")))

# a source of its own: the same units as before, as universal ids
p1 <- strata_units(rows$Park, tmp, R, P, rows)
expect("a plain source: its own raster as universal ids, uncovered land filled by its rule", at(p1, 2, 2) == U(10, 1) && at(p1, 7, 2) == U(10, 9999) && attr(p1, "numbers") == 10 && is.null(attr(p1, "cells")))

m <- strata_units(rows$Manager, tmp, R, P, rows)
expect("stack: the first source that covers a cell names it (the park where park and forest overlap)", at(m, 1, 8) == U(10, 1) && at(m, 4, 8) == U(10, 1) && at(m, 4, 2) == U(10, 1))
expect("stack: the next source names the cells the first does not cover", at(m, 6, 8) == U(13, 2) && at(m, 6, 2) == U(13, 2))
expect("stack: the last source's polygons name what is left of them", at(m, 9, 2) == U(8, 3))
expect("stack: cells no polygon covers take the rest source's own fill (Owner's default)", at(m, 8, 8) == U(8, 9))
expect("stack: a cell that is not land has no unit, and every land cell has one", is.na(P[1, 10][[1]]) && is.na(m[1, 10][[1]]) && sum(is.na(values(m))) == 1)
n <- attr(m, "cells")
expect("stack: how many cells each source gave, in order", identical(names(n), c("Park", "Forest", "Owner")) && n[["Park"]] == 50 && n[["Forest"]] == 30 && n[["Owner"]] == 10 && attr(m, "filled") == 9 && attr(m, "rest") == "Owner")
expect("stack: the Numbers its units can have are its sources'", setequal(attr(m, "numbers"), c(10, 13, 8)))

m2 <- strata_units(rows[["Manager Forest First"]], tmp, R, P, rows)
expect("stack: the order decides the overlap (forest first: the 2 km they share is forest)", at(m2, 4, 8) == U(13, 2) && at(m2, 1, 8) == U(10, 1) && attr(m2, "cells")[["Park"]] == 30)

d <- strata_units(rows$Designation, tmp, R, P, rows)
expect("stack: a source listed under one that covers it gives no cells", attr(d, "cells")[["Wild"]] == 10 && attr(d, "cells")[["Park"]] == 40)
expect("stack: the rest comes from the source named, not the last (Not wilderness, not Not a park)", at(d, 7, 2) == U(14, 9999) && at(d, 1, 8) == U(14, 7) && at(d, 4, 2) == U(10, 1))

expect("a stack that names a source the library lacks says so", grepl("Nowhere", tryCatch({ strata_units(rows$Broken, tmp, R, P, rows); "" }, error = function(e) conditionMessage(e))))
park <- rows$Park; park$NameTemplate <- "Park {id}"
ul <- universal_list(list(Park = park, Manager = rows$Manager), tmp)
expect("the unit list holds no unit of a stack", nrow(ul) == 1 && ul$Id == U(10, 1))

# units the study area does not name (strata_unnamed): 100,000 land cells
v <- c(rep(U(10, 1), 58000), rep(U(13, 2), 41000), rep(U(8, 9), 54), rep(U(8, 1), 1), rep(U(13, 5), 945), rep(NA, 10))
un <- strata_unnamed(v, c(U(10, 1), U(13, 2)), c(10, 13, 8), U(8, 9))
expect("unnamed: a named unit is never listed; the others are, with their cells", setequal(un$Id, c(U(8, 9), U(8, 1), U(13, 5))) && un[Id == U(13, 5), Cells] == 945)
expect("unnamed: a unit the study area does not name is removed, and so is an uncovered class under 0.1% of the land", all(un$Drop) && un[Id == U(8, 9), Default])
d2 <- strata_unnamed(c(rep(U(14, 7), 400), rep(U(14, 3), 2), rep(U(14, 9999), 600)), U(14, 7), 14, U(14, 9999))
expect("unnamed: an uncovered class that is much of the land stays (Not designated wilderness)", d2[Id == U(14, 9999), !Drop] && d2[Id == U(14, 3), Drop])
d3 <- strata_unnamed(c(rep(U(10, 1), 600), rep(U(13, 2), 400)), c(U(10, 1), U(14, 7)), c(10, 13, 8), U(8, 9))
expect("unnamed: a unit not named that holds 1% of the land or more is kept (a named wilderness inside a forest not named)", nrow(d3) == 1 && !d3$Drop)
expect("unnamed: a slot the study area names no unit of is left alone (states under a park)", nrow(strata_unnamed(c(rep(U(2, 53), 990), rep(U(2, 41), 10)), U(10, 1), 2, numeric())) == 0)
expect("unnamed: all of CONUS (no named unit) removes nothing", nrow(strata_unnamed(v, numeric(), c(10, 13, 8), U(8, 9))) == 0)

# the package's own two stacks
real <- strata_presets(pkg); lm <- strata_stack(real[["Land Manager"]], pkg); ld <- strata_stack(real[["Land Designation"]], pkg)
expect("Land Manager: parks first, the Federal Lands owner classes for the rest", !is.null(lm) && lm$members[1] == "National Parks" && lm$rest == "Federal Lands" && all(lm$members %in% names(real)))
expect("Land Designation: wilderness first, and Not designated wilderness for the rest", !is.null(ld) && ld$members[1] == "Wilderness" && ld$rest == "Wilderness" && all(ld$members %in% names(real)))

unlink(tmp, recursive = TRUE)
cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
