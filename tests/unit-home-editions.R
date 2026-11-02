# =============================================================================
# unit-home-editions.R - editions of a dataset in Data Sources Home (to-do 12; plan, "Design: editions")
# =============================================================================
# Plain R, no SyncroSim, no network: a fake handler whose version changes from v1 to v2. Checks that
#   - a new version is skipped, with a note, unless Fetch new editions is ticked, and the first edition is untouched
#   - with it ticked, the new edition lands in <folder>/editions/<tag>/ beside the first, which stays byte for byte the same
#   - a rerun finds the new edition up to date; a growing dataset's new edition gets every item, not only the missing ones
#   - the Build's choice: no edition = the first; a named edition = its folder; an edition the home lacks = none
#   - home_editions lists a folder's editions, and another region's copy under its own folder
# Usage: Rscript tests/unit-home-editions.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "datahome.R")); source(file.path(pkg, "src", "download.R"))
ok <- 0; bad <- 0
expect <- function(what, cond) { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, "\n") } }
shas <- function(d) { f <- list.files(d, recursive = TRUE, full.names = TRUE); f <- f[!grepl("/editions/", f)]; setNames(vapply(f, function(x) digest::digest(file = x, algo = "sha256"), ""), f) }

home <- file.path(tempdir(), "home-editions"); unlink(home, recursive = TRUE); dir.create(home); home <- normalizePath(home, winslash = "/")
layout <- data.table(Column = c("TestFile", "TestFolder"), HomePath = c("t/file/*.tif", "t/folder"), Source = "test", Version = "v1", Doi = NA_character_)
P26 <- c(-2100000, 2000000, -2000000, 2100000); FAR <- c(1000000, 1000000, 1100000, 1100000)
ctx_for <- function(name, box, new = FALSE) list(home = home, region_home = file.path(home, "regions", name), region = list(box = box, poly = "polygon", units = name, buffer_km = 10),
                                                 years = c(1985L, NA), keep = FALSE, new_editions = new, connections = 1L, log = function(x) invisible())
file_h <- function(v) list(column = "TestFile", name = "test file", version = v,
  plan = function(ctx) data.table(url = "https://example.org/x", file = "x", fetch = FALSE),
  finish = function(ctx, items) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE); f <- file.path(ctx$place, "test.tif"); writeLines(paste(v, ctx$region$units), f); f })
folder_h <- function(v, n) list(column = "TestFolder", name = "test folder", version = v,
  plan = function(ctx) data.table(url = sprintf("https://example.org/%d", seq_len(n)), file = sprintf("y%d.tif", seq_len(n)), fetch = FALSE),
  have = function(ctx, items) { f <- read_files(ctx$store)[Column == "TestFolder"]; file.path("t/folder", items$file) %in% f$Path },
  finish = function(ctx, items) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE); for (x in items$file) writeLines(paste(v, x), file.path(ctx$place, x)); ctx$place })
p26 <- file.path(home, "regions", "P26")

invisible(run_dataset(file_h("v1"), ctx_for("P26", P26), layout)); invisible(run_dataset(folder_h("v1", 3), ctx_for("P26", P26), layout))
invisible(run_dataset(file_h("v1"), ctx_for("FAR", FAR), layout))
s0 <- shas(p26)

r <- run_dataset(file_h("v2"), ctx_for("P26", P26), layout)
expect("a new version is skipped without Fetch new editions", r$Status == "skipped" && grepl("new edition v2 available", r$Next))
expect("nothing is written for it", !dir.exists(file.path(p26, "editions")) && identical(s0, shas(p26)))

r <- run_dataset(file_h("v2"), ctx_for("P26", P26, new = TRUE), layout)
ed <- file.path(p26, "editions", "v2")
expect("with Fetch new editions it lands in editions/v2", r$Status == "done" && file.exists(file.path(ed, "t/file/test.tif")) && grepl("editions/v2", r$Next))
expect("the new edition holds the new version", identical(readLines(file.path(ed, "t/file/test.tif")), "v2 P26"))
expect("its own manifest says v2", identical(read_manifest(ed)[Column == "TestFile", Version], "v2"))
expect("the first edition is byte for byte unchanged", identical(s0, shas(p26)))
expect("the first edition's manifest still says v1", identical(read_manifest(p26)[Column == "TestFile", Version], "v1"))
expect("a rerun finds the new edition up to date", run_dataset(file_h("v2"), ctx_for("P26", P26, new = TRUE), layout)$Status == "skipped")
expect("the first edition stays up to date for v1", run_dataset(file_h("v1"), ctx_for("P26", P26), layout)$Status == "skipped")

r <- run_dataset(folder_h("v2", 4), ctx_for("P26", P26, new = TRUE), layout)
expect("a growing dataset's new edition gets every item", r$Status == "done" && length(list.files(file.path(ed, "t/folder"))) == 4)
expect("the first edition's folder keeps its 3 v1 files", length(list.files(file.path(p26, "t/folder"))) == 3 && identical(s0, shas(p26)))

pick <- function(e = NULL, box = P26) { p <- home_pick(home, "TestFile", "t/file/*.tif", box, e); if (is.null(p)) NA_character_ else home_label(home, p$dir) }
expect("no edition chosen: the first", identical(pick(), "regions/P26"))
expect("edition v2 chosen: its folder", identical(pick("v2"), "regions/P26/editions/v2"))
expect("an edition the home lacks: none", is.na(pick("v9")))
expect("an edition elsewhere does not cover FAR: v2 is only in P26", identical(pick("v2", FAR + c(1, 1, -1, -1)), "regions/P26/editions/v2") &&
         isFALSE(manifest_covers(home_pick(home, "TestFile", "t/file/*.tif", FAR + c(1, 1, -1, -1), "v2")$dir, "TestFile", FAR + c(1, 1, -1, -1))))
e <- home_editions(home, "TestFile")
expect("home_editions: P26 first, P26 v2 and FAR first", nrow(e) == 3 && setequal(paste(e$Folder, e$Edition), c("regions/P26 ", "regions/P26 v2", "regions/FAR ")))
expect("edition tags are folder-safe", identical(edition_tag("LF2025_Dist25 (final)"), "LF2025_Dist25-final"))

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
