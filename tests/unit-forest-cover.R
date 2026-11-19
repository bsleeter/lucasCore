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
expect("options: an empty sheet is Annual NLCD, 10%, the BpS gate, half the cell, no folder", o$definition == "nlcd" && o$threshold == 10 && o$gate == "bps" && o$rule == "share" && o$recovery == "canopy" && o$recovery_threshold == 30 && o$share == 0.5 && is.na(o$folder))
o <- forest_cover_options(data.table(ForestDefinition = 2L, CanopyThreshold = 15L, CanopyGate = 2L, CellShare = 0.3, TreeCanopyFolder = "D:/tcc"))
expect("options: numbers", o$definition == "canopy" && o$threshold == 15 && o$gate == "none" && o$share == 0.3 && o$folder == "D:/tcc")
o <- forest_cover_options(data.table(ForestDefinition = "Annual NLCD and tree canopy cover", CanopyThreshold = NA, CanopyGate = "Only where LANDFIRE BpS is forest", CellShare = NA, TreeCanopyFolder = ""))
expect("options: the list labels rsyncrosim gives, blanks as defaults", o$definition == "canopy" && o$threshold == 10 && o$gate == "bps" && o$share == 0.5 && is.na(o$folder))
expect("options: an unknown choice, a threshold and a share out of range are errors", err(forest_cover_options(data.table(ForestDefinition = "LANDFIRE"))) &&
       err(forest_cover_options(data.table(CanopyThreshold = 0L))) && err(forest_cover_options(data.table(CanopyThreshold = 101L))) && err(forest_cover_options(data.table(CellShare = 0))) && err(forest_cover_options(data.table(CellShare = 1.2))))
px <- xml2::read_xml(file.path(pkg, "package.xml")); f1 <- function(k) xml2::xml_attr(xml2::xml_find_first(px, sprintf("//dataSheet[@name='ForestCoverOptions']/column[@name='%s']", k)), "formula1")
lab <- function(v) paste(sprintf("%d:%s", seq_along(v), v), collapse = "|")
expect("package.xml: the two lists' labels are the ones the code reads", identical(f1("ForestDefinition"), lab(FOREST_DEFINITION)) && identical(f1("CanopyGate"), lab(FOREST_GATE)) && identical(f1("CellRule"), lab(FOREST_CELL_RULE)) && identical(f1("CanopyRecovery"), lab(FOREST_RECOVERY)))
tr <- xml2::xml_attr(xml2::xml_find_all(px, "//transformer[@name='InitialConditions']/dataSheet"), "name")
expect("package.xml: stage 5 reads the options and writes both outputs", all(c("ForestCoverOptions", "OutputForestCover", "OutputForestCoverMap") %in% tr))

# ---- which cells the canopy makes forest ------------------------------------------------------------------------------------------
nl <- c(31L, 52L, 71L, 41L, 90L, 95L, 21L, 82L, 11L, 52L, 52L, 52L, NA)
sh <- c(0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.49, 0.5, NA, 0.9)
expect("cells: barren, shrub and grass at or over the share; no other class, no cell under it or without canopy", identical(canopy_forest(nl, sh), c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE)))
expect("cells: a woody wetland cell keeps its class", identical(canopy_forest(c(52L, 52L), c(1, 1), c(TRUE, FALSE)), c(FALSE, TRUE)))
expect("cells: the share is a setting", identical(canopy_forest(c(52L, 52L), c(0.2, 0.4), FALSE, 0.3), c(FALSE, TRUE)))

# ---- area-matched cells ------------------------------------------------------------------------------------------------------------
# two units of 10 cells. Unit 1: 30 m forest share sums to 6 cells, 3 are forest already -> 3 of its 5 candidates, the highest shares.
# Unit 2: the target (2) is under the forest it already has (4) -> none. A candidate with no passing pixels is never taken.
un <- rep(1:2, each = 10); ex <- c(rep(TRUE, 3), rep(FALSE, 7), rep(TRUE, 4), rep(FALSE, 6)); tg <- c(rep(0.6, 10), rep(0.2, 10))
shr <- c(1, 1, 1, 0.9, 0.2, 0.8, 0.7, 0.3, 0.95, 0.99, rep(0.9, 10)); cnd <- c(rep(FALSE, 3), TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, rep(FALSE, 4), rep(TRUE, 6))
am <- canopy_area_match(shr, cnd, un, tg, ex)
expect("area-matched: each unit gains the cells its 30 m forest area still lacks, highest canopy share first", identical(which(am), c(4L, 6L, 7L)))
expect("area-matched: a unit with more forest than its target gains none", !any(am[11:20]))
expect("area-matched: never more cells than candidates, and none without passing pixels", sum(canopy_area_match(c(0.9, 0, 0.5, 0.4), c(TRUE, TRUE, FALSE, FALSE), 1L, rep(1, 4), rep(FALSE, 4))) == 1)
expect("area-matched: cells off the land do not count", sum(canopy_area_match(c(0.9, 0.8, 0.7, 0.6), rep(TRUE, 4), 1L, c(1, 1, 1, 1), rep(FALSE, 4), land = c(TRUE, TRUE, FALSE, FALSE))) == 2)
o <- forest_cover_options(data.table(CellRule = 2L)); expect("options: the cell rule", o$rule == "area" && forest_cover_options(data.table(CellRule = "Area-matched"))$rule == "area")

# ---- recovery by canopy (stage 6) -----------------------------------------------------------------------------------------------------
expect("recovery: on when the share is at or over the cell share in the year and the year before; a year without canopy is never on",
       identical(canopy_return_on(c(0.6, 0.6, 0.4, NA, 0.5), c(0.6, 0.4, 0.6, 0.9, 0.5)), c(TRUE, FALSE, FALSE, FALSE, TRUE)) && identical(canopy_return_on(0.6, 0.6, 0.7), FALSE))
onm <- rbind(c(TRUE, FALSE, TRUE, TRUE), c(FALSE, FALSE, FALSE, TRUE), c(FALSE, FALSE, FALSE, FALSE), c(TRUE, TRUE, TRUE, TRUE))
expect("recovery: the lag is to the first map on after the disturbance; none on, or no disturbance, gives NA", identical(return_lag(onm, 2001:2004, c(2001L, 2000L, 2000L, NA)), c(2L, 4L, NA, NA)))
expect("options: the recovery threshold is its own, 1 to 100", forest_cover_options(data.table(RecoveryThreshold = 40L))$recovery_threshold == 40 && err(forest_cover_options(data.table(RecoveryThreshold = 0L))))
expect("options: recovery can be left to NLCD", forest_cover_options(data.table(CanopyRecovery = 2L))$recovery == "nlcd" && forest_cover_options(data.table(CanopyRecovery = "NLCD forest only"))$recovery == "nlcd")
tr6 <- xml2::xml_attr(xml2::xml_find_all(px, "//transformer[@name='HistoricalTransitions']/dataSheet"), "name")
expect("package.xml: stage 6 reads the Forest Cover options", "ForestCoverOptions" %in% tr6)

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

# ---- the forest area check against FIA ------------------------------------------------------------------------------------------------
# 40 plots, the first 30 all forest, 5 half forest and half other land, 5 all other land; plot 1 has an older visit that is all other
# land (ignored: the newest visit counts) and a water condition that is not land
pl <- data.table(CN = as.character(1:40), INVYR = 2015L, STATECD = 6L, UNITCD = 1L, COUNTYCD = 1L, PLOT = 1:40)
old <- data.table(CN = "900", INVYR = 2008L, STATECD = 6L, UNITCD = 1L, COUNTYCD = 1L, PLOT = 1L)
cd <- rbind(data.table(PLT_CN = as.character(1:30), COND_STATUS_CD = 1L, CONDPROP_UNADJ = 1), data.table(PLT_CN = rep(as.character(31:35), each = 2), COND_STATUS_CD = rep(1:2, 5), CONDPROP_UNADJ = 0.5),
            data.table(PLT_CN = as.character(36:40), COND_STATUS_CD = 2L, CONDPROP_UNADJ = 1), data.table(PLT_CN = "900", COND_STATUS_CD = 2L, CONDPROP_UNADJ = 1))
cd[PLT_CN == "1", CONDPROP_UNADJ := 0.8]; cd <- rbind(cd, data.table(PLT_CN = "1", COND_STATUS_CD = 3L, CONDPROP_UNADJ = 0.2))
fi <- fia_forest_share(rbind(pl, old), cd)
expect("FIA: forest over forest and other land, each plot's newest visit, water left out", fi$plots == 40 && abs(fi$share - (29 + 0.8 + 2.5) / (39 + 0.8)) < 1e-9 && fi$se > 0 && fi$se < 0.1 && fi$from == 2015 && fi$to == 2015)
old2 <- copy(old)[, INVYR := 2001L]; fi2 <- fia_forest_share(rbind(pl[-1], old2), cd)
expect("FIA: a plot last visited before the span is left out", fi2$plots == 39)
few <- fia_forest_share(pl[1:10], cd)
expect("FIA: fewer than 20 plots gives no share, and no plots gives none", is.na(few$share) && few$plots == 10 && is.na(fia_forest_share(pl[0], cd)$share))
expect("verdict: within two standard errors, more, less, and no FIA figure", grepl("^within", forest_area_verdict(0.86, 0.85, 0.01)) && grepl("6.0 points more forest", forest_area_verdict(0.91, 0.85, 0.01)) &&
       grepl("less forest", forest_area_verdict(0.70, 0.85, 0.01)) && grepl("too few", forest_area_verdict(0.9, NA, NA)))
td <- file.path(tempdir(), "fia-dm"); dir.create(td, showWarnings = FALSE)
fwrite(data.table(CN = c("1", "2", "3"), INVYR = 2015L, STATECD = 6L, UNITCD = 1L, COUNTYCD = 1L, PLOT = 1:3, LAT = c(39, 39.5, 45), LON = c(-120, -120.5, -120), X = 1), file.path(td, "CA_PLOT.csv"))
fwrite(data.table(PLT_CN = c("1", "2", "3"), CONDID = 1L, COND_STATUS_CD = 1L, CONDPROP_UNADJ = 1), file.path(td, "CA_COND.csv"))
pb <- fia_plots_box(td, c(-121, 38, -119, 40)); cb <- fia_conds(td, pb)
expect("FIA: the plots inside the box and their conditions, read from the state tables", nrow(pb) == 2 && all(pb$State == "CA") && nrow(cb) == 2 && !nrow(fia_plots_box(tempdir(), c(-121, 38, -119, 40))))
expect("package.xml: stage 5 writes the Forest Area Check", "OutputForestAreaCheck" %in% tr)

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
