# =============================================================================
# unit-download-by-hand.R - files put in a dataset's place by hand are recorded, not fetched again (2026-11-13: the CDL)
# =============================================================================
# Plain R, no SyncroSim, no network: a fake national handler with by_hand stands in for the CDL. A colleague unzipped the CDL into
# <home>/land-cover/cdl over a manifest row that an earlier download had left failed; Data Download fetched it all again (and failed
# again), so the Data Sources page showed "home failed" and a Build stopped on the row. Checks that
#   - every file in place by hand: done, nothing fetched, the failed row replaced by a done one (Method by hand), files.csv with checksums
#   - a rerun is up to date; a Build's home pick reads the folder and its coverage check passes
#   - Check only says the files will be recorded and writes nothing
#   - some files by hand: only the others are fetched, and all are recorded (direct, part by hand)
#   - the CDL handler takes a file only when it is the national 30 m layer
# Usage: Rscript tests/unit-download-by-hand.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
for (f in c("datahome.R", "download.R", "download-sources.R")) source(file.path(pkg, "src", f))
ok <- 0; bad <- 0
expect <- function(what, cond) { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, "\n") } }

root <- file.path(tempdir(), "by-hand"); unlink(root, recursive = TRUE); dir.create(root); root <- normalizePath(root, winslash = "/")
layout <- data.table(Column = "TestHand", HomePath = "t/hand", Source = "test", Version = "v1", Doi = NA_character_)
P26 <- c(-2100000, 2000000, -2000000, 2100000)
new_home <- function(name) { d <- file.path(root, name); dir.create(file.path(d, "regions", "P26"), recursive = TRUE)
  list(home = d, region_home = file.path(d, "regions", "P26"), region = list(box = P26, poly = "polygon", units = "P26", buffer_km = 10),
       years = c(2014L, NA), keep = FALSE, connections = 1L, opts = NULL, log = function(x) invisible()) }
fetched <- character()
H <- list(column = "TestHand", name = "test by hand", national = TRUE, version = "v1",
  plan = function(ctx) data.table(url = sprintf("https://example.org/%d.zip", 2014:2016), file = sprintf("%d.zip", 2014:2016), out = sprintf("%d.tif", 2014:2016), fetch = FALSE),
  have = function(ctx, items) recorded(ctx, "TestHand", file.path(ctx$place, items$out)),
  by_hand = function(ctx, items) file.exists(file.path(ctx$place, items$out)) & !grepl("bad", vapply(file.path(ctx$place, items$out), function(f) if (file.exists(f)) readLines(f, 1) else "", "")),
  finish = function(ctx, items) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE); fetched <<- c(fetched, items$out)
    for (x in items$out) writeLines(paste("fetched", x), file.path(ctx$place, x)); ctx$place })
by_hand <- function(ctx, years) { d <- file.path(ctx$home, "t/hand"); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  for (y in years) writeLines(paste("by hand", y), file.path(d, sprintf("%d.tif", y))) }

# ---- all by hand, over a failed row -----------------------------------------------------------------------------------------
a <- new_home("a"); by_hand(a, 2014:2016)
write_manifest(a$home, data.table(Column = "TestHand", Dataset = H$name, Status = "failed", Note = "Timeout was reached"))
r <- run_dataset(H, a, layout); m <- read_manifest(a$home)[Column == "TestHand"]; fr <- read_files(a$home)[Column == "TestHand"]
expect("all by hand: done, nothing fetched", identical(r$Status, "done") && !length(fetched) && r$Files == 3)
expect("the failed row is replaced by a done one, by hand, national", identical(m$Status, "done") && identical(m$Method, "by hand") && identical(m$Copy, "national"))
expect("files.csv lists the three with checksums", nrow(fr) == 3 && all(nchar(fr$Sha256) == 64))
expect("the files are left as they were", all(grepl("^by hand", vapply(file.path(a$home, "t/hand", sprintf("%d.tif", 2014:2016)), readLines, ""))))
expect("a rerun is up to date", identical(run_dataset(H, a, layout)$Status, "skipped") && !length(fetched))
pk <- home_pick(a$home, "TestHand", "t/hand", P26)
expect("a Build reads the folder, and its coverage check passes", !is.null(pk) && isTRUE(manifest_covers(pk$dir, "TestHand", P26)))

# ---- Check only ----------------------------------------------------------------------------------------------------------
b <- new_home("b"); by_hand(b, 2014:2016); r <- run_dataset(H, b, layout, check_only = TRUE)
expect("Check only: would record them, nothing fetched or written", identical(r$Status, "would download") && r$SizeMb == 0 && grepl("by hand", r$Next) &&
       !nrow(read_manifest(b$home)) && !length(fetched))

# ---- some by hand ----------------------------------------------------------------------------------------------------------
c1 <- new_home("c"); by_hand(c1, 2014:2015); writeLines("bad copy", file.path(c1$home, "t/hand", "2016.tif"))
r <- run_dataset(H, c1, layout); m <- read_manifest(c1$home)[Column == "TestHand"]
expect("some by hand: only the others are fetched (a file that is not the source's too)", identical(fetched, "2016.tif") && identical(r$Status, "done"))
expect("all three recorded, direct, part by hand", r$Files == 3 && identical(m$Method, "direct, part by hand"))
expect("the hand-placed ones are kept", all(grepl("^by hand", vapply(file.path(c1$home, "t/hand", sprintf("%d.tif", 2014:2015)), readLines, ""))))

# ---- the CDL handler -----------------------------------------------------------------------------------------------------
cdl <- download_handlers()$CdlFolder; d <- new_home("cdl"); d$place <- file.path(d$home, "land-cover", "cdl"); dir.create(d$place, recursive = TRUE)
said <- character(); d$log <- function(x) said <<- c(said, x)
small <- rast(xmin = -2e6, xmax = -1.97e6, ymin = 2e6, ymax = 2.03e6, res = 30, crs = "EPSG:5070"); values(small) <- 1L
writeRaster(small, file.path(d$place, "2014_30m_cdls.tif"), datatype = "INT1U", overwrite = TRUE)
items <- data.table(out = sprintf("%d_30m_cdls.tif", 2014:2015))
got <- cdl$by_hand(d, items)
expect("CDL: a clip is not the national layer (fetched again, and said), a missing year is not in place", identical(got, c(FALSE, FALSE)) && any(grepl("not the national 30 m CDL", said)))
nat <- "E:/lucasData/land-cover/cdl"
if (all(file.exists(file.path(nat, items$out)))) { e <- d; e$place <- nat
  expect("CDL: the national files are taken as they are", identical(cdl$by_hand(e, items), c(TRUE, TRUE))) } else cat("skip: no national CDL at", nat, "\n")

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
