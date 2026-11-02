# =============================================================================
# data-home.R - check a Data Sources Home folder: which datasets are at their place, and what its manifest says (to-do 12)
# =============================================================================
# Each Data Sources column's place is its HomePath in defaults/library/data-sources.csv (src/datahome.R). Prints one line per
# dataset: found (the path), missing, or how many files match when it should be one; and the manifest's status and region when the
# Data Download stage wrote one. --create makes the empty folder layout (nothing is moved or deleted). --to-region=<name> moves a home
# laid out before regions (its clipped datasets at the top) into regions/<name>, national copies staying (--dry lists the moves).
# Usage: Rscript tools/data-home.R <home folder> [--create] [--to-region=<name> [--dry]]
# =============================================================================
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(TRUE); pos <- a[!grepl("^--", a)]
if (!length(pos)) stop("usage: Rscript tools/data-home.R <home folder> [--create]")
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
pkg <- normalizePath(file.path(here, ".."), winslash = "/"); source(file.path(pkg, "src", "datahome.R"))
home <- normalizePath(pos[1], winslash = "/", mustWork = FALSE)
if ("--create" %in% a) { made <- home_create(home, pkg); cat(sprintf("made %d folders in %s\n", length(made), home)) }
if (!dir.exists(home)) stop("no such folder: ", home)
tr <- sub("^--to-region=", "", grep("^--to-region=", a, value = TRUE))
if (length(tr)) { home_to_region(home, tr[1], pkg, dry = "--dry" %in% a, log = function(x) cat(x, "\n", sep = "")); if ("--dry" %in% a) quit(save = "no") }
s <- home_status(home, pkg); m <- read_manifest(home)
s <- merge(s, m[, .(Column, Status, Copy, Units, BufferKm, Downloaded)], by = "Column", all.x = TRUE, sort = FALSE)
for (i in seq_len(nrow(s))) with(s[i], cat(sprintf("%-26s %-8s %s%s\n", Column,
  if (!is.na(Path)) "found" else if (Found > 1) sprintf("%d files", Found) else "missing",
  if (!is.na(Path)) substring(Path, nchar(home) + 2) else Place,
  if (!is.na(Status)) sprintf("  [manifest: %s, %s%s, %s]", Status, if (identical(Copy, "national")) "national" else Units,
                              if (!is.na(BufferKm)) paste0(" + ", BufferKm, " km") else "", Downloaded) else "")))
cat(sprintf("%d of %d datasets at their place; manifest rows: %d\n", sum(!is.na(s$Path)), nrow(s), nrow(m)))
for (r in home_regions(home)) { rs <- home_status(r, pkg); cat(sprintf("%s: %d datasets at their place; manifest rows: %d\n", home_label(home, r), sum(!is.na(rs$Path)), nrow(read_manifest(r)))) }
