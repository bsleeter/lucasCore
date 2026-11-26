# Fast test of stage 6's water, wetland and barren source (to-do 2 step 4; no SyncroSim, no network). Run: Rscript tests/unit-water-change-source.R (from the package root)
# The band worker against the rule run on every pixel, and the tables that connect the six Wetland Change types.
suppressPackageStartupMessages({ library(data.table); library(terra) })
source("src/water-change.R")
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
# ---- a 12 x 12 pixel window, 11 years, blocks of 3 x 3 pixels, read in two bands of 6 rows ----
set.seed(11); d <- file.path(tempdir(), "wc-unit"); unlink(d, recursive = TRUE); dir.create(d); yy <- 2000:2010; np <- 144L
open <- matrix(0L, np, length(yy)); cur <- sample(c(0L, 20L, 60L, 100L), np, TRUE)
for (j in seq_along(yy)) { k <- runif(np) < 0.3; cur[k] <- sample(c(0L, 20L, 45L, 60L, 80L, 100L), sum(k), TRUE); open[, j] <- cur }
open[sample(length(open), 60)] <- 255L   # no clear look
nl <- matrix(sample(c(11L, 31L, 90L, 95L, 71L), np, TRUE), np, length(yy)); k <- sample(np, 50); nl[k, 6:11] <- sample(c(31L, 95L, 11L), 50, TRUE)
mk <- function(v, xmin = 0, nc = 12) { r <- rast(nrows = 12, ncols = nc, xmin = xmin, xmax = 360, ymin = 0, ymax = 360, crs = "EPSG:5070"); values(r) <- v; r }
fo <- function(y) file.path(d, sprintf(WATER_DSWE_FILE, y)); fn <- function(y) file.path(d, sprintf("nlcd_%d.tif", y))
for (j in seq_along(yy)) { writeRaster(mk(nl[, j]), fn(yy[j]), datatype = "INT1U"); if (yy[j] != 2004L) writeRaster(mk(open[, j]), fo(yy[j]), datatype = "INT1U", NAflag = 255) }
open[, yy == 2004L] <- 255L   # a year with no file reads as no clear look
a <- list(clear = function() NULL, E = c(0, 360, 0, 360), fact = 3L, nr = 12L, nc = 12L, step = 6L, rows = c(0L, 6L), all = yy, out = 2002:2008,
          dswe = setNames(lapply(setdiff(yy, 2004L), fo), setdiff(yy, 2004L)), nlcd = setNames(lapply(yy, fn), yy), hi = 70, lo = 30, line = 50, hold = 5L)
got <- lapply(1:2, water_band, a = a); cnt <- do.call(rbind, lapply(got, function(x) matrix(x, nrow = dim(x)[1])))
o2 <- open; o2[o2 > 100L] <- NA_integer_; w <- water_change(o2, nl); blk <- ((seq_len(np) - 1L) %/% 12L %/% 3L) * 4L + ((seq_len(np) - 1L) %% 12L) %/% 3L + 1L
want <- do.call(cbind, lapply(unname(WATER_CHANGE), function(cc) sapply(a$out, function(y) tabulate(blk[w$change[, match(y, yy)] == cc], 16L))))
check("each band returns block cells x years wanted x the six changes", identical(dim(got[[1]]), c(8L, 7L, 6L)))
check("the bands give the same counts as the rule run on every pixel", identical(unname(cnt), unname(want)) && sum(cnt) > 20)
check("more than one kind of change is in the test", sum(colSums(matrix(colSums(cnt), 7)) > 0) >= 4)
check("no block has more changed pixels in a year than it holds", max(Reduce(`+`, lapply(1:6, function(k) cnt[, (k - 1L) * 7L + 1:7]))) <= 9L)
# a DSWE file that covers part of the window: the rest reads as no clear look
for (y in setdiff(yy, 2004L)) writeRaster(mk(open[, yy == y][(seq_len(np) - 1L) %% 12L >= 4L], xmin = 120, nc = 8), fo(y), datatype = "INT1U", NAflag = 255, overwrite = TRUE)
o3 <- o2; o3[(seq_len(np) - 1L) %% 12L < 4L, ] <- NA_integer_; w3 <- water_change(o3, nl)
got3 <- do.call(rbind, lapply(lapply(1:2, water_band, a = a), function(x) matrix(x, nrow = dim(x)[1])))
want3 <- do.call(cbind, lapply(unname(WATER_CHANGE), function(cc) sapply(a$out, function(y) tabulate(blk[w3$change[, match(y, yy)] == cc], 16L))))
check("a DSWE file smaller than the window is placed by its own extent", identical(unname(got3), unname(want3)))
r <- rast(fn(2000L)); ext(r) <- ext(15, 375, 0, 360); writeRaster(r, file.path(d, "off.tif")); a2 <- a; a2$nlcd[["2000"]] <- file.path(d, "off.tif")
check("a file off the 30 m grid is refused", inherits(try(water_band(1L, a2), silent = TRUE), "try-error"))
check("the years read: five before the start year and four after the end year, where the NLCD has them", identical(water_rule_years(2001L, 2021L, 1985:2024), 1996:2024) && identical(water_rule_years(1986L, 2023L, 1985:2024), 1985:2024))
# ---- the tables ----
rd <- function(...) fread(file.path("defaults", ...), colClasses = "character", na.strings = "")
pw <- rd("transitions", "pathways", "wetland-change.csv"); scl <- rd("stsim", "stsim_StateClass.csv"); tt <- rd("stsim", "stsim_TransitionType.csv"); tg <- rd("stsim", "stsim_TransitionTypeGroup.csv")
so <- rd("transitions", "sources.csv")[Source == "WaterChange"]; grp <- rd("stsim", "stsim_TransitionGroup.csv")
check("pathway classes and types are in the stsim lists", all(c(pw$StateClassIdSource, pw$StateClassIdDest) %in% scl[[1]]) && all(pw$TransitionTypeId %in% tt[[1]]))
check("no pathway is given twice", !anyDuplicated(pw[, paste(StateClassIdSource, TransitionTypeId)]))
check("to Water leaves every wetland class, Barren, and the upland forest, shrub and grass classes", setequal(pw[TransitionTypeId == "Wetland Change: to Water", StateClassIdSource], c(grep("^(Wetland|Disturbed|Forest|Shrubland|Grassland): ", scl[[1]], value = TRUE), "Barren: All")))
check("no agriculture or developed class has a wetland change pathway", !any(grepl("^(Agriculture|Developed): ", c(pw$StateClassIdSource, pw$StateClassIdDest))))
check("new wetland is emergent, from Water or Barren only", setequal(pw[grepl("^Wetland: ", StateClassIdDest), StateClassIdDest], c("Wetland: Estuarine Emergent", "Wetland: Palustrine Emergent")) &&
        setequal(pw[grepl("^Wetland: ", StateClassIdDest), StateClassIdSource], c("Water: All", "Barren: All")))
check("to Barren leaves Water and the emergent wetlands", setequal(pw[StateClassIdDest == "Barren: All", StateClassIdSource], c("Water: All", "Wetland: Estuarine Emergent", "Wetland: Palustrine Emergent")))
check("every source row names a type with a pathway", all(sub(" [Type]", "", so$TransitionGroupId, fixed = TRUE) %in% pw$TransitionTypeId) && setequal(sub(" [Type]", "", so$TransitionGroupId, fixed = TRUE), unique(pw$TransitionTypeId)))
cd <- lapply(strsplit(so$Classes, "|", fixed = TRUE), as.integer)
check("the source rows use every change with a transition once per destination (Water to Other Land has none)", setequal(unlist(cd), 1:5) && identical(sort(unlist(unique(cd))), 1:5))
check("the two emergent types share one set of changes (stage 6 splits them by the nearest wetland type)", identical(so[grepl("Emergent", TransitionGroupId), unique(Classes)], "2|5"))
check("the misspelt type name is gone", !any(grepl("Palustine", tt[[1]])) && "Wetland Change: to Palustrine Forested" %in% tt[[1]] && !anyDuplicated(tt[[2]][grepl("^Wetland Change", tt[[1]])]))
wg <- tg[grepl("^Wetland Change", TransitionTypeId)]
check("the six types are in the Gain and Loss groups", nrow(wg) == 6 && all(wg$TransitionGroupId %in% grp[[1]]) && setequal(wg[TransitionGroupId == "Wetland Change: Loss", TransitionTypeId], c("Wetland Change: to Water", "Wetland Change: to Barren")))
s6 <- paste(readLines("src/6-historical-transitions.R", warn = FALSE), collapse = "\n")
check("stage 6 reads the source and leaves it out when there is no DSWE", grepl('so[Source == "WaterChange"]', s6, fixed = TRUE) && grepl('read_data_sources("DsweFolder", optional = TRUE)', s6, fixed = TRUE))
# ranked placement (user 2026-11-25): whole cells by rank, as mortality; stage 6 calls mortality_select with the pathway as the only gate
check("stage 6 places the changes by rank as whole cells", grepl("mortality_select(sh, can, all7, room, carry7[[k$g]], can)", s6, fixed = TRUE) && grepl('"INT1U")\n          nxt[s$sel] <- k$to[match(cur7[s$sel], k$from)]', gsub("\r", "", s6), fixed = TRUE))
source("src/mortality.R")
sh <- c(0.9, 0.6, 0.5, 0.4, 0.3, 0); can <- c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE); room <- c(1, 0.5, 1, 1, 1, 1); s <- mortality_select(sh, can, rep(TRUE, 6), room, 0.2, can)
check("the year's area is the shares on cells with the pathway, less what another transition holds, plus the shares on cells without it and the carry",
      isTRUE(all.equal(s$target, 0.2 + 0.9 + 0.5 + 0.4 + 0.3 + 0.5)) && isTRUE(all.equal(s$moved, 0.5)) && isTRUE(all.equal(s$held, 0.1)))
check("whole free cells are taken from the largest share down, and the rest carries", identical(s$sel, c(1L, 4L)) && isTRUE(all.equal(s$carry, 0.8)))
check("the file name pattern is the download's", grepl(sprintf('DSWE_FILE <- "%s"', WATER_DSWE_FILE), paste(readLines("src/download-sources.R", warn = FALSE), collapse = "
"), fixed = TRUE))
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
