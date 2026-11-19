# =============================================================================
# unit-forest-cover.R - forest in the start year by tree canopy cover, and the Forest Cover options (src/forest-cover.R; stage 5)
# =============================================================================
# Plain R, made-up cells and a made-up raster, no SyncroSim. Checks the options (defaults, labels and numbers, bad values), which
# cells the canopy rule may change, the 30 m pass raster (threshold, no data, the BpS gate), and that the dataset is registered
# (data-sources.csv, endpoints.csv as optional, citations.csv, the download handler, package.xml's sheets and labels).
# Usage: Rscript tests/unit-forest-cover.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "forest-cover.R"))
ok <- 0; bad <- 0
expect <- function(what, cond) { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, "\n") } }
err <- function(e) inherits(try(e, silent = TRUE), "try-error")

# ---- options ------------------------------------------------------------------------------------------------------------------
o <- forest_cover_options(data.table())
expect("options: an empty sheet is Annual NLCD, 10%, the BpS gate, half the cell, no folder", o$definition == "nlcd" && o$threshold == 10 && o$gate == "bps" && o$share == 0.5 && is.na(o$folder))
o <- forest_cover_options(data.table(ForestDefinition = 2L, CanopyThreshold = 15L, CanopyGate = 2L, CellShare = 0.3, TreeCanopyFolder = "D:/tcc"))
expect("options: numbers", o$definition == "canopy" && o$threshold == 15 && o$gate == "none" && o$share == 0.3 && o$folder == "D:/tcc")
o <- forest_cover_options(data.table(ForestDefinition = "Annual NLCD and tree canopy cover", CanopyThreshold = NA, CanopyGate = "Only where LANDFIRE BpS is forest", CellShare = NA, TreeCanopyFolder = ""))
expect("options: the list labels rsyncrosim gives, blanks as defaults", o$definition == "canopy" && o$threshold == 10 && o$gate == "bps" && o$share == 0.5 && is.na(o$folder))
expect("options: an unknown choice, a threshold and a share out of range are errors", err(forest_cover_options(data.table(ForestDefinition = "LANDFIRE"))) &&
       err(forest_cover_options(data.table(CanopyThreshold = 0L))) && err(forest_cover_options(data.table(CanopyThreshold = 101L))) && err(forest_cover_options(data.table(CellShare = 0))) && err(forest_cover_options(data.table(CellShare = 1.2))))
px <- xml2::read_xml(file.path(pkg, "package.xml")); f1 <- function(k) xml2::xml_attr(xml2::xml_find_first(px, sprintf("//dataSheet[@name='ForestCoverOptions']/column[@name='%s']", k)), "formula1")
lab <- function(v) paste(sprintf("%d:%s", seq_along(v), v), collapse = "|")
expect("package.xml: the two lists' labels are the ones the code reads", identical(f1("ForestDefinition"), lab(FOREST_DEFINITION)) && identical(f1("CanopyGate"), lab(FOREST_GATE)))
tr <- xml2::xml_attr(xml2::xml_find_all(px, "//transformer[@name='InitialConditions']/dataSheet"), "name")
expect("package.xml: stage 5 reads the options and writes both outputs", all(c("ForestCoverOptions", "OutputForestCover", "OutputForestCoverMap") %in% tr))

# ---- which cells the canopy makes forest ------------------------------------------------------------------------------------------
nl <- c(31L, 52L, 71L, 41L, 90L, 95L, 21L, 82L, 11L, 52L, 52L, 52L, NA)
sh <- c(0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.49, 0.5, NA, 0.9)
expect("cells: barren, shrub and grass at or over the share; no other class, no cell under it or without canopy", identical(canopy_forest(nl, sh), c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE)))
expect("cells: a woody wetland cell keeps its class", identical(canopy_forest(c(52L, 52L), c(1, 1), c(TRUE, FALSE)), c(FALSE, TRUE)))
expect("cells: the share is a setting", identical(canopy_forest(c(52L, 52L), c(0.2, 0.4), FALSE, 0.3), c(FALSE, TRUE)))

# ---- the 30 m pass raster ---------------------------------------------------------------------------------------------------------
if (requireNamespace("terra", quietly = TRUE)) {
  r <- terra::rast(nrows = 2, ncols = 4, xmin = 0, xmax = 4, ymin = 0, ymax = 2, crs = "EPSG:5070"); terra::values(r) <- c(0, 9, 10, 55, 100, 101, 255, NA)
  expect("pass: at or over the threshold up to 100; over 100 and NA are no data and never pass", identical(as.numeric(terra::values(canopy_pass(r, 10), mat = FALSE)), c(0, 0, 1, 1, 1, 0, 0, 0)))
  expect("pass: the threshold moves the line", identical(as.numeric(terra::values(canopy_pass(r, 56), mat = FALSE)), c(0, 0, 0, 0, 1, 0, 0, 0)))
  g <- r; terra::values(g) <- c(1, 1, 0, 1, NA, 1, 1, 1)
  expect("pass: with a gate, only where the potential is forest (no potential = not forest)", identical(as.numeric(terra::values(canopy_pass(r, 10, g), mat = FALSE)), c(0, 0, 0, 1, 0, 0, 0, 0)))
} else cat("skip: terra not installed (the pass raster)\n")

# ---- the dataset is registered ------------------------------------------------------------------------------------------------------
dsr <- fread(file.path(pkg, "defaults", "library", "data-sources.csv"), colClasses = "character")[Column == "TreeCanopyFolder"]
expect("data-sources.csv has a TreeCanopyFolder row with a home place", nrow(dsr) == 1 && dsr$HomePath == "land-cover/tree-canopy")
ep <- fread(file.path(pkg, "defaults", "download", "endpoints.csv"), colClasses = "character")[Column == "TreeCanopyFolder"]
expect("endpoints.csv has it as optional (a Data Download fetches it only when asked)", nrow(ep) == 1 && ep$Fetched == "optional")
expect("citations.csv has a TreeCanopyFolder citation", nrow(fread(file.path(pkg, "defaults", "metadata", "citations.csv"))[Column == "TreeCanopyFolder"]) == 1)
h <- readLines(file.path(pkg, "src", "download-sources.R"))
expect("the download handler writes the file names stage 5 reads", any(grepl("H$TreeCanopyFolder <- list(", h, fixed = TRUE)) && any(grepl(sub("%d", "%d", TCC_FILE, fixed = TRUE), h, fixed = TRUE)))
s5 <- paste(readLines(file.path(pkg, "src", "5-initial-conditions.R")), collapse = "\n")
expect("stage 5 keeps canopy cells out of the regrowth, start-rule and reforestation picks", lengths(regmatches(s5, gregexpr("& !canopy_cell", s5, fixed = TRUE))) >= 3)

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
