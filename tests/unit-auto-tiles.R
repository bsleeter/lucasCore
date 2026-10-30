# =============================================================================
# unit-auto-tiles.R - fast checks of to-do 22 (automatic spatial tiles), no SyncroSim run
# =============================================================================
#   1. auto_tiles: the fewest tiles within 5% of the best finish (largest tile), up to ceiling(1 / the largest unit's share), capped by the units and the cores
#   2. tile_notes: the speed-up and memory line only with tiles, the "more tiles cannot help" and "one unit dominates" warnings
#   3. P26 (read only, from the latest Build result's strata maps): Plumas holds about 19.8% of the land -> 5 tiles, the number found
#      by trial on 2026-10-24
# Usage: Rscript tests/unit-auto-tiles.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) }); pkg <- "F:/lucasCore"; ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
# the tile helpers alone (shared.R needs a running SyncroSim scenario): evaluate only their definitions
ex <- parse(file.path(pkg, "src", "shared.R")); keep <- c("TILE_LEVELS", "tile_level", "pack_tiles", "tile_summary", "TILE_JOB_GB", "TILE_CELL_KB", "auto_tiles", "tile_notes")
for (e in ex) { s <- deparse(e, width.cutoff = 500L)[1]; if (any(startsWith(s, paste0(keep, " <-"))) || startsWith(s, "TILE_JOB_GB")) eval(e, globalenv()) }

# 1. the rule
u <- rep(1:5, c(40, 20, 20, 10, 10)); land <- rep(TRUE, length(u))
expect("units 40/20/20/10/10 -> 3 tiles (largest tile 40, the best)", auto_tiles(u, land, 64)$n == 3L)
u <- rep(1:4, c(52, 20, 15, 13)); expect("one unit holds 52% -> 2 tiles (floor(1/share) would say 1)", auto_tiles(u, rep(TRUE, 100), 64)$n == 2L)
u <- rep(1:20, 5); expect("20 equal units, 64 cores -> 20 tiles", auto_tiles(u, rep(TRUE, 100), 64)$n == 20L)
expect("capped by the cores: 8 cores -> 7 (7 tiles of 3 units finish as soon as 8)", auto_tiles(u, rep(TRUE, 100), 8)$n == 7L)
u <- rep(1:4, c(1, 1, 1, 97)); expect("one unit holds 97% -> 1 tile (one job)", auto_tiles(u, rep(TRUE, 100), 64)$n == 1L)
u <- rep(1:5, 20); expect("exactly 20% each -> 5 tiles (no floating-point loss)", auto_tiles(u, rep(TRUE, 100), 64)$n == 5L)
u <- c(rep(1:3, c(50, 30, 20)), NA, NA); expect("cells outside the land are ignored", auto_tiles(u, !is.na(u), 64)$share == 0.5)

# 2. the notes
u <- rep(1:6, c(30, 20, 15, 15, 10, 10)); land <- rep(TRUE, 100); a <- auto_tiles(u, land, 64)
n0 <- tile_notes(a, NULL, 1L, "Secondary", "A")
expect("one job: only the largest-unit line", length(n0) == 1 && grepl("the most tiles that help is 4", n0))
tl <- pack_tiles(u, land, 5); n5 <- tile_notes(a, tl, 5L, "Secondary", "A")
expect("5 tiles where 4 help: speed-up, memory and 'cannot finish sooner'", length(n5) == 3 && grepl("faster than one job; estimated peak memory", n5[2]) && grepl("cannot make the run finish sooner", n5[3]), paste(n5[-1], collapse = " | "))
d <- tile_notes(auto_tiles(rep(1:2, c(80, 20)), rep(TRUE, 100), 64), NULL, 1L, "Primary", "B")
expect("one unit holds 80%: the finer-level warning", any(grepl("at most 1.2x faster; a finer Spatial Tiles Strata level", d)))

# 3. P26
lib <- file.path(pkg, "dev/libs/LUCAS P26 Northern Sierra Nevada.ssim")
if (file.exists(lib)) {
  con <- DBI::dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO)
  ic <- DBI::dbGetQuery(con, "SELECT ScenarioId, StratumFileName, SecondaryStratumFileName FROM stsim_InitialConditionsSpatial WHERE SecondaryStratumFileName IS NOT NULL ORDER BY ScenarioId DESC LIMIT 1")
  sn <- DBI::dbGetQuery(con, "SELECT Id, Name FROM stsim_SecondaryStratum"); DBI::dbDisconnect(con)
  d <- file.path(paste0(lib, ".data"), paste0("Scenario-", ic$ScenarioId), "stsim_InitialConditionsSpatial")
  P <- values(rast(file.path(d, ic$StratumFileName)), mat = FALSE); S <- values(rast(file.path(d, ic$SecondaryStratumFileName)), mat = FALSE)
  a <- auto_tiles(S, !is.na(P), 64); nm <- sn$Name[match(a$unit, as.character(sn$Id))]
  expect("P26: largest county Plumas at about 19.8% -> 5 tiles", a$n == 5L && abs(100 * a$share - 19.8) < 0.5 && grepl("Plumas", nm),
         sprintf("(Build result %d: %s %.1f%%, %d tiles, %d units)", ic$ScenarioId, nm, 100 * a$share, a$n, a$units))
  tl <- pack_tiles(S, !is.na(P), a$n); cat(paste(tile_notes(a, tl, a$n, "Secondary", nm), collapse = "\n"), "\n")
} else cat("SKIP  P26 check: no", lib, "\n")
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
