# =============================================================================
# unit-home-regions.R - Home layout By region and the write-once rule (to-do 12; plan, "Second study areas: home layout")
# =============================================================================
# Plain R, no SyncroSim, no network: a fake handler stands in for a source. Checks that
#   - a Build picks the smallest region whose manifest covers its study area, a national copy last, and a folder that does not
#     cover it only when nothing else holds the dataset
#   - a Data Download writes into its own region folder, national copies at the top
#   - a second region under a name already used for another box stops before fetching, and the first region's files are
#     byte for byte unchanged; under its own name it downloads beside the first
#   - staging never replaces a recorded file, keeps an identical one, and replaces an unrecorded leftover of a failed download
#   - a growing dataset (have) adds files without touching the ones there
# Usage: Rscript tests/unit-home-regions.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "datahome.R")); source(file.path(pkg, "src", "download.R"))
ok <- 0; bad <- 0
expect <- function(what, cond) { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, "\n") } }
fails <- function(expr, pattern) { m <- tryCatch({ force(expr); "" }, error = function(e) conditionMessage(e)); grepl(pattern, m) }
sha <- function(f) digest::digest(file = f, algo = "sha256")

home <- file.path(tempdir(), "home-regions"); unlink(home, recursive = TRUE); dir.create(home)
home <- normalizePath(home, winslash = "/")
layout <- data.table(Column = c("TestFile", "TestFolder", "TestNational"), HomePath = c("t/file/*.tif", "t/folder", "t/national"),
                     Source = "test", Version = "v1", Doi = NA_character_)
P26 <- c(-2100000, 2000000, -2000000, 2100000); CA <- c(-2400000, 1200000, -1600000, 2500000); FAR <- c(1000000, 1000000, 1100000, 1100000)
region <- function(box, units) list(box = box, poly = "polygon", units = units, buffer_km = 10)
ctx_for <- function(name, box, units) list(home = home, region_home = if (is.null(name)) NULL else file.path(home, "regions", name),
                                           region = region(box, units), years = c(1985L, NA), keep = FALSE, connections = 1L, opts = NULL, log = function(x) invisible())
# a handler that "fetches" nothing and writes the region's box into its file: two regions give different bytes
writes <- function(ctx) paste(ctx$region$units, paste(ctx$region$box, collapse = " "))
H_file <- list(column = "TestFile", name = "test file", version = "v1",
  plan = function(ctx) data.table(url = "https://example.org/x", file = "x", fetch = FALSE),
  finish = function(ctx, items) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE); f <- file.path(ctx$place, "test.tif"); writeLines(writes(ctx), f); f })
H_folder <- list(column = "TestFolder", name = "test folder", version = "v1",
  plan = function(ctx) data.table(url = sprintf("https://example.org/%d", 2001:2003), file = sprintf("y%d.tif", 2001:2003), fetch = FALSE),
  have = function(ctx, items) { f <- read_files(ctx$store)[Column == "TestFolder"]; file.path("t/folder", items$file) %in% f$Path },
  finish = function(ctx, items) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE)
    for (x in items$file) writeLines(paste(x, writes(ctx)), file.path(ctx$place, x)); ctx$place })
H_nat <- list(column = "TestNational", name = "test national", national = TRUE, version = "v1",
  plan = function(ctx) data.table(url = "https://example.org/n", file = "n", fetch = FALSE),
  finish = function(ctx, items) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE); writeLines("CONUS", file.path(ctx$place, "n.tif")); ctx$place })

# ---- downloads ---------------------------------------------------------------------------------------------------------------
a <- ctx_for("P26", P26, "P26")
for (h in list(H_file, H_folder, H_nat)) r <- run_dataset(h, a, layout)
expect("P26 file lands in regions/P26", file.exists(file.path(home, "regions/P26/t/file/test.tif")))
expect("national copy lands at the top", file.exists(file.path(home, "t/national/n.tif")) && !dir.exists(file.path(home, "regions/P26/t/national")))
expect("region manifest records the P26 box", identical(as.numeric(read_manifest(file.path(home, "regions/P26"))[Column == "TestFile", Xmin]), P26[1]))
expect("national row at the top says national", identical(read_manifest(home)[Column == "TestNational", Copy], "national"))
before <- vapply(list.files(file.path(home, "regions/P26"), recursive = TRUE, full.names = TRUE), sha, "")

expect("rerun of P26 skips", run_dataset(H_file, a, layout)$Status == "skipped")
expect("P26 national rerun skips at the top", run_dataset(H_nat, a, layout)$Status == "skipped")
# a nested study area under the same name: covered, so skipped (nested reuse)
expect("a box inside P26 under its name skips", run_dataset(H_file, ctx_for("P26", P26 + c(10000, 10000, -10000, -10000), "inside"), layout)$Status == "skipped")
# another box under the same name: refused before anything is fetched
b_same <- ctx_for("P26", FAR, "FAR")
expect("FAR under the name P26 is refused", fails(run_dataset(H_file, b_same, layout), "write-once: regions/P26 already holds test file for P26"))
expect("FAR under P26 refused for a growing dataset too", fails(run_dataset(H_folder, b_same, layout), "write-once"))
after <- vapply(list.files(file.path(home, "regions/P26"), recursive = TRUE, full.names = TRUE), sha, "")
expect("P26 files byte for byte unchanged", identical(before, after))
# under its own name it downloads beside P26
b <- ctx_for("FAR", FAR, "FAR"); for (h in list(H_file, H_folder, H_nat)) run_dataset(h, b, layout)
expect("FAR lands in regions/FAR", file.exists(file.path(home, "regions/FAR/t/file/test.tif")))
expect("P26 still unchanged after FAR", identical(before, vapply(names(before), sha, "")))
c_big <- ctx_for("CA", CA, "CA"); invisible(run_dataset(H_file, c_big, layout))

# ---- the Build's choice ------------------------------------------------------------------------------------------------------
pick <- function(col, box) { p <- home_pick(home, col, layout[Column == col, HomePath], box); if (is.null(p)) NA_character_ else home_label(home, p$dir) }
expect("study area inside P26 reads P26 (smallest)", identical(pick("TestFile", P26 + c(5000, 5000, -5000, -5000)), "regions/P26"))
expect("study area in CA outside P26 reads CA", identical(pick("TestFile", c(-2300000, 1300000, -2200000, 1400000)), "regions/CA"))
expect("study area in FAR reads FAR", identical(pick("TestFile", FAR + c(1, 1, -1, -1)), "regions/FAR"))
expect("national dataset read at the top", identical(pick("TestNational", P26), "the top of the home"))
nc <- home_pick(home, "TestFile", "t/file/*.tif", c(0, 0, 10, 10))
expect("nothing covers: a folder is still returned for the coverage message", !is.null(nc) && isFALSE(manifest_covers(nc$dir, "TestFile", c(0, 0, 10, 10))))
expect("no study area known: the top first, else a region", !is.null(home_pick(home, "TestFile", "t/file/*.tif", NULL)))
# a hand-laid top copy (no manifest row) comes after a covering region but before one that does not cover
dir.create(file.path(home, "t/file"), recursive = TRUE); writeLines("hand", file.path(home, "t/file/hand.tif"))
expect("covering region beats a hand-laid top copy", identical(pick("TestFile", P26), "regions/P26"))
expect("hand-laid top copy beats a region that does not cover", identical(pick("TestFile", c(0, 0, 10, 10)), "the top of the home"))
unlink(file.path(home, "t/file"), recursive = TRUE)
expect("region names are folder-safe", identical(region_name(c("P26 Northern Sierra", "P29/foot")), "P26-Northern-Sierra-P29-foot"))
expect("a long region name is shortened with a hash", nchar(region_name(strrep("Unit ", 30))) == 60)

# ---- staging -------------------------------------------------------------------------------------------------------------
st <- file.path(home, "regions/P26", ".staging", "TestFile"); dir.create(st, recursive = TRUE, showWarnings = FALSE)
writeLines("different", file.path(st, "test.tif"))
expect("staging refuses to replace a recorded file", fails(commit_staged(st, file.path(home, "regions/P26/t/file"), st, file.path(home, "regions/P26"), "TestFile"), "write-once"))
expect("the recorded file is unchanged", identical(before, vapply(names(before), sha, "")))
dir.create(st, recursive = TRUE); invisible(file.copy(file.path(home, "regions/P26/t/file/test.tif"), file.path(st, "test.tif")))
expect("staging keeps an identical file", identical(commit_staged(st, file.path(home, "regions/P26/t/file"), st, file.path(home, "regions/P26"), "TestFile"),
                                                   file.path(home, "regions/P26/t/file")) && identical(before, vapply(names(before), sha, "")))
# a failed earlier download left an unrecorded file: it may be replaced
lf <- file.path(home, "regions/LEFT"); dir.create(file.path(lf, "t/file"), recursive = TRUE); writeLines("partial", file.path(lf, "t/file/test.tif"))
write_manifest(lf, data.table(Column = "TestFile", Dataset = "test file", Status = "failed", Note = "stopped"))
r <- run_dataset(H_file, ctx_for("LEFT", P26, "LEFT"), layout)
expect("an unrecorded leftover of a failed download is replaced", r$Status == "done" && !identical(readLines(file.path(lf, "t/file/test.tif")), "partial"))

# ---- growing -------------------------------------------------------------------------------------------------------------
g0 <- vapply(list.files(file.path(home, "regions/P26/t/folder"), full.names = TRUE), sha, "")
H_more <- H_folder; H_more$plan <- function(ctx) data.table(url = sprintf("https://example.org/%d", 2001:2005), file = sprintf("y%d.tif", 2001:2005), fetch = FALSE)
r <- run_dataset(H_more, a, layout)
g1 <- vapply(list.files(file.path(home, "regions/P26/t/folder"), full.names = TRUE), sha, "")
expect("growing adds two years", r$Status == "done" && length(g1) == 5)
expect("growing leaves the first three byte for byte", identical(g0, g1[names(g0)]))
expect("files.csv lists all five", nrow(read_files(file.path(home, "regions/P26"))[Column == "TestFolder"]) == 5)

# ---- records/ (to-do 52): tables lost, files in place ------------------------------------------------------------------------
# 2026-11-04: the home was copied folders only; the top-level manifest.csv and files.csv stayed behind and 9 GB was fetched again
expect("a done dataset keeps its rows in records/", all(file.exists(record_files(home, "TestNational"))) && all(file.exists(record_files(file.path(home, "regions/P26"), "TestFile"))))
top0 <- read_manifest(home); invisible(file.remove(file.path(home, c("manifest.csv", "files.csv"))))
rp <- file.path(home, "regions/P26"); p0 <- read_files(rp); invisible(file.remove(file.path(rp, "files.csv")))   # a region that lost only files.csv
expect("with the tables gone the national dataset is not up to date", !dataset_up_to_date(home, "TestNational", region(P26, "P26")))
msg <- character(); got <- home_restore_records(home, function(x) msg <<- c(msg, x))
expect("restore puts the top rows back", setequal(got, top0[Status == "done", Column]) && identical(read_manifest(home)[Column == "TestNational", Copy], "national"))
expect("restore says what it restored", any(grepl("restored the manifest.csv and files.csv rows of", msg)))
expect("restore puts a region's files.csv rows back", "TestFile" %in% home_restore_records(rp, function(x) invisible()) && setequal(read_files(rp)$Path, p0$Path))
fetched <- FALSE; H_watch <- modifyList(H_nat, list(plan = function(ctx) { fetched <<- TRUE; H_nat$plan(ctx) }))
expect("after the restore a rerun skips without planning a fetch", run_dataset(H_watch, a, layout)$Status == "skipped" && !fetched)
# a file changed since its record: not restored, and the rerun fetches
invisible(file.remove(file.path(home, c("manifest.csv", "files.csv")))); writeLines("CONUS, changed", file.path(home, "t/national/n.tif"))
msg <- character(); got <- home_restore_records(home, function(x) msg <<- c(msg, x))
expect("a dataset whose file changed size is not restored", !"TestNational" %in% got && any(grepl("TestNational: .*not restored", msg)))
# an existing done row with no record (a home filled before records/) gets one
invisible(file.remove(record_files(rp, "TestFolder"))); home_restore_records(rp, function(x) invisible())
expect("a done dataset without a record gets one", all(file.exists(record_files(rp, "TestFolder"))))

# a Build's cache beside a dataset (FIA's fia-conditions.rds) is never recorded, and a row an earlier version recorded for one is
# ignored, so a rebuilt cache leaves the dataset up to date (2026-11-09)
ch <- file.path(tempdir(), "home-cache"); unlink(ch, recursive = TRUE); dir.create(file.path(ch, "forest", "fia-datamart"), recursive = TRUE)
ch <- normalizePath(ch, winslash = "/"); dm <- file.path(ch, "forest", "fia-datamart")
writeLines("a", file.path(dm, "AL_COND.csv")); saveRDS(1:10, file.path(dm, "fia-conditions.rds"))
fr <- files_rows(ch, "FiaDataMartFolder", dm)
expect("a cache file is not recorded with its dataset", identical(fr$Path, "forest/fia-datamart/AL_COND.csv"))
write_files(ch, rbind(fr, data.table(Column = "FiaDataMartFolder", Path = "forest/fia-datamart/fia-conditions.rds", Bytes = "1", Sha256 = NA, Modified = NA)))
write_manifest(ch, data.table(Column = "FiaDataMartFolder", Copy = "national", Status = "done"))
saveRDS(1:1000, file.path(dm, "fia-conditions.rds"))   # rebuilt by a Build: another size than the old row says
expect("a cache row an earlier version recorded is dropped on reading", nrow(read_files(ch)) == 1)
expect("a rebuilt cache leaves the dataset up to date", isTRUE(dataset_up_to_date(ch, "FiaDataMartFolder", list(box = P26, poly = "polygon"))))

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
