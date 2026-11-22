# =============================================================================
# unit-grid-tiles.R - grid tiles for spatial multiprocessing (src/shared.R: grid_tiles, auto_grid, is_grid_level), no SyncroSim run
# =============================================================================
# Grid tiles are rectangles of the model grid that each hold about the same number of land cells, whatever the strata.
# Usage: Rscript tests/unit-grid-tiles.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
ok <- 0; bad <- 0
expect <- function(what, cond, detail = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, detail, "\n") } }
# the tile helpers alone (shared.R needs a running SyncroSim scenario): evaluate only their definitions
keep <- c("TILE_LEVELS", "tile_level", "TILE_JOB_GB", "TILE_CELL_KB", "is_grid_level", "grid_tiles", "GRID_MIN_CELLS", "GRID_JOB_S", "GRID_CELL_S", "GRID_MERGE_S", "auto_grid", "grid_summary", "grid_notes")
for (e in parse(file.path(pkg, "src", "shared.R"))) { s <- deparse(e, width.cutoff = 500L)[1]; if (any(startsWith(s, paste0(keep, " <-"))) || startsWith(s, "TILE_JOB_GB")) eval(e, globalenv()) }
rect_ok <- function(g, nr, nc) all(vapply(seq_len(g$n), function(t) { i <- which(g$values == t); r <- (i - 1) %/% nc + 1; c <- (i - 1) %% nc + 1
  # every land cell inside a tile's box of rows and columns belongs to that tile
  inbox <- which(!is.na(g$values)); rr <- (inbox - 1) %/% nc + 1; cc <- (inbox - 1) %% nc + 1
  all(g$values[inbox[rr >= min(r) & rr <= max(r) & cc >= min(c) & cc <= max(c)]] == t) }, TRUE))

nr <- 100; nc <- 160; land <- rep(TRUE, nr * nc)
g <- grid_tiles(land, nr, nc, 8)
expect("all land, 8 tiles: every cell in a tile, eight equal tiles", g$n == 8 && !anyNA(g$values) && all(g$load == 2000))
expect("tiles are rectangles of the grid (no cell of another tile inside a tile's rows and columns)", rect_ok(g, nr, nc))
g <- grid_tiles(land, nr, nc, 7)
expect("a number that is not a power of two: 7 tiles within 5% of equal (cuts are whole rows and columns)", g$n == 7 && max(g$load) / mean(g$load) < 1.05 && min(g$load) / mean(g$load) > 0.95, paste(g$load, collapse = " "))
expect("one tile is the whole land", { g1 <- grid_tiles(land, nr, nc, 1); g1$n == 1 && all(g1$values == 1) })

# land that is not a rectangle: a disc with a lake in it, and sea around
rw <- rep(seq_len(nr), each = nc); cl <- rep(seq_len(nc), nr)
disc <- (rw - 50)^2 + ((cl - 80) / 1.6)^2 < 45^2 & !((rw - 40)^2 + (cl - 60)^2 < 12^2)
g <- grid_tiles(disc, nr, nc, 16)
expect("uneven land: cells that are not land have no tile, and every land cell has one", all(is.na(g$values[!disc])) && !anyNA(g$values[disc]) && sum(g$load) == sum(disc))
expect("uneven land: 16 tiles within 5% of equal in land cells", g$n == 16 && max(g$load) / mean(g$load) < 1.05 && min(g$load) / mean(g$load) > 0.95, sprintf("%d to %d", min(g$load), max(g$load)))
expect("uneven land: tiles are still rectangles of the grid", rect_ok(g, nr, nc))
expect("uneven land: tiles differ in area where land is sparse, not in cells", diff(range(g$box$rows * g$box$cols)) > 0)

# the largest unit no longer sets the pace: one unit with 59% of the land
unit <- ifelse(cl <= 94, 1L, 2L)   # (59% and 41%)
g <- grid_tiles(land, nr, nc, 12)
expect("a unit of 59% of the land is split: 12 tiles give about 12x, where whole units give 1.7x", sum(g$load) / max(g$load) > 11.5 && length(unique(g$values[unit == 1])) > 1)

expect("more tiles than cells: one tile a cell at most", { s <- c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE); gs <- grid_tiles(s, 2, 3, 10); gs$n == 3 && all(gs$load == 1) })
expect("a single row of land is cut along its length", { s <- rep(c(FALSE, TRUE, FALSE), each = 12); gs <- grid_tiles(s, 3, 12, 4); gs$n == 4 && all(gs$load == 3) })

expect("automatic: the square root of the land cells in thousands (Olympic 17, a million cells 32, five million 71)", auto_grid(275745, 112) == 17L && auto_grid(1e6, 112) == 32L && auto_grid(5e6, 112) == 71L)
expect("automatic: capped by the cores, and one job for a small study area", auto_grid(5e6, 16) == 16L && auto_grid(275745, 8) == 8L && auto_grid(19000, 112) == 1L)
expect("the Grid level is told from the strata levels, by number or by label", is_grid_level(4) && is_grid_level("4") && is_grid_level("Grid") && !is_grid_level(2) && !is_grid_level(NA) && !is_grid_level("Secondary"))
expect("a projection reads a Build's Grid level as whole Secondary units", tile_level(4) == "Secondary" && tile_level("Grid") == "Secondary")
g <- grid_tiles(disc, nr, nc, 16)
expect("the log line gives the cells in a tile and what that is in km2", grepl("16 grid tiles of about", grid_summary(g, 150)) && grepl("km2 of land at 150 m", grid_summary(g, 150)))
expect("the notes say grid tiles are for runs with no targets", any(grepl("no targets", grid_notes(g, 112))) && !any(grepl("wait their turn", grid_notes(g, 112))) && any(grepl("wait their turn", grid_notes(g, 8))) && any(grepl("merge threads", grid_notes(g, 112))))

# the gain the log states is the one the timings give, not the share of cells: Olympic, 17 tiles of 16,217 cells, ran 2.6 times faster
go <- list(load = rep(16217, 17), n = 17L); gain <- as.numeric(sub(".*about ([0-9.]+)x faster.*", "\\1", grid_notes(go, 112)[1]))
expect("the stated gain for Olympic's 17 tiles is near the 2.6 times measured, not 17", gain > 2.3 && gain < 3.1, sprintf("%.1f", gain))
cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
