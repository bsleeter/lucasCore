# =============================================================================
# unit-resume.R - the record a Build stage keeps so a later Build need not run it again (src/resume.R)
# =============================================================================
# Plain R, made-up sheets and files, no SyncroSim: the SyncroSim objects resume.R asks about are stood in for here. Checks the
# checksum of a sheet (keys and row order do not count, a file counts by its content), what a read and a write note, the signature of
# a data source, and that a record's files are found again by content after SyncroSim renamed one. The whole of it - a stage skipped
# in a real Build - is tests/phaseZ33-build-resume.R.
# Usage: Rscript tests/unit-resume.R
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
.rs <- new.env(); .rs$on <- TRUE; .rs$ok <- TRUE; .rs$files <- character(); .rs$md5 <- new.env(); .rs$written <- character(); .rs$reads <- list()
source(file.path(pkg, "src", "resume.R"))
ok <- 0; bad <- 0
expect <- function(what, cond) { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, "\n") } }
tmp <- file.path(tempdir(), "unit-resume"); unlink(tmp, recursive = TRUE); dir.create(tmp)
put <- function(dir, name, text) { d <- file.path(tmp, dir); dir.create(d, recursive = TRUE, showWarnings = FALSE); f <- file.path(d, name); writeLines(text, f); normalizePath(f, winslash = "/") }

# ---- the checksum of a sheet ----
a <- data.frame(StratumId = c("A", "B"), Value = c(1.5, 2), stringsAsFactors = FALSE)
expect("checksum: the same rows give the same checksum", rs_hash(a, "lucasCore_X") == rs_hash(a, "lucasCore_X"))
expect("checksum: row order does not count", rs_hash(a, "lucasCore_X") == rs_hash(a[2:1, ], "lucasCore_X"))
expect("checksum: a changed value counts", rs_hash(a, "lucasCore_X") != rs_hash(transform(a, Value = c(1.5, 2.1)), "lucasCore_X"))
expect("checksum: the sheet's own key and the scenario id do not count", rs_hash(a, "lucasCore_X") == rs_hash(cbind(XId = 7:8, ScenarioId = 14L, a), "lucasCore_X"))
expect("checksum: another sheet's id column counts", rs_hash(a, "lucasCore_X") != rs_hash(cbind(YId = 7:8, a), "lucasCore_X"))
expect("checksum: a factor reads as its labels", rs_hash(a, "lucasCore_X") == rs_hash(transform(a, StratumId = factor(StratumId)), "lucasCore_X"))
expect("checksum: an empty sheet has one", is.character(rs_hash(a[0, ], "lucasCore_X")) && rs_hash(a[0, ], "lucasCore_X") != rs_hash(a, "lucasCore_X"))
f1 <- put("Scenario-1/s", "Age.tif", "old forest"); f2 <- put("Scenario-2/s", "Age.tif", "old forest"); f3 <- put("Scenario-3/s", "Age.tif", "young forest")
sh <- function(f) data.frame(AgeFileName = f, stringsAsFactors = FALSE)
expect("checksum: a file counts by its content, not its folder", rs_hash(sh(f1), "s") == rs_hash(sh(f2), "s"))
expect("checksum: a file of the same name and other content counts", rs_hash(sh(f1), "s") != rs_hash(sh(f3), "s"))
expect("checksum: a file that is not there counts by its name", rs_hash(sh(file.path(tmp, "a", "Gone.tif")), "s") == rs_hash(sh(file.path(tmp, "b", "Gone.tif")), "s"))

# ---- what a call names ----
cl <- rs_call(list("obj", "lucasCore_X", optional = TRUE))
expect("a call by position: object, sheet, the rest", cl$ssimObject == "obj" && cl$name == "lucasCore_X" && isTRUE(cl$extra$optional))
cl <- rs_call(list(name = "lucasCore_X", ssimObject = "obj", lookupsAsFactors = FALSE))
expect("a call by name", cl$ssimObject == "obj" && cl$name == "lucasCore_X" && identical(names(cl$extra), "lookupsAsFactors"))

# ---- reads and writes (the scenario stood in for) ----
rs_scope <- function(obj) obj
rs_note_read(list("scn", "lucasCore_X", optional = TRUE), a); h1 <- .rs$reads[[1]]$hash
rs_note_read(list("scn", "lucasCore_X", optional = TRUE), transform(a, Value = 9))
expect("a read: the first read of a sheet is the one kept", length(.rs$reads) == 1 && .rs$reads[[1]]$hash == h1 && h1 == rs_hash(a, "lucasCore_X"))
rs_note_read(list("prj", "lucasCore_X", optional = TRUE), a)
expect("a read: the project's sheet of the same name is another read", length(.rs$reads) == 2 && .rs$reads[[2]]$scope == "prj")
.rs$written <- "lucasCore_W"; rs_note_read(list("scn", "lucasCore_W"), a)
expect("a read: a sheet the stage wrote itself is not a read", length(.rs$reads) == 2)
rs_note_read(list("scn"), list(a)); expect("a read: a list of sheets is not a read", length(.rs$reads) == 2 && .rs$ok)
w <- rs_note_write("scn", data.frame(Name = "x", AgeFileName = f1, stringsAsFactors = FALSE), "s", list(append = TRUE))
expect("a write: a file is kept as its checksum, size and name", startsWith(w$data$AgeFileName, RS_FILE) && endsWith(w$data$AgeFileName, "|Age.tif") && w$data$Name == "x" && isTRUE(w$args$append))
expect("a write: outside the scenario is refused", inherits(try(rs_note_write("prj", a, "s", list()), silent = TRUE), "try-error"))

# ---- the files of a record, found again ----
rs_data_dir <- function(id, sheet) file.path(tmp, sprintf("Scenario-%d", id), sheet)
rs_me <- function() 9L
rec <- list(writes = list(w))
r <- rs_find_files(rec, 1L); expect("files: found in the earlier result's folder", is.null(r$missing) && length(r$files) == 1 && normalizePath(r$files[[1]]$from, winslash = "/") == f1 && r$files[[1]]$base == "Age.tif")
invisible(file.rename(f1, file.path(dirname(f1), "Age(2).tif"))); writeLines("something else", f1)
r <- rs_find_files(rec, 1L); expect("files: found by content after SyncroSim renamed it", is.null(r$missing) && basename(r$files[[1]]$from) == "Age(2).tif")
r <- rs_find_files(rec, 3L); expect("files: a result that no longer has the file says so", !is.null(r$missing) && grepl("Age.tif", r$missing))

# ---- the signature of a data source ----
d1 <- put("src", "a.shp", "shape"); invisible(put("src", "a.dbf", "table")); s0 <- rs_path_sig(d1)
expect("data source: the same file gives the same signature", s0 == rs_path_sig(d1))
writeLines("another table, longer", file.path(dirname(d1), "a.dbf")); expect("data source: a file's companion counts", s0 != rs_path_sig(d1))
g0 <- rs_path_sig(dirname(d1)); invisible(put("src", "b.tif", "new year")); expect("data source: a file added to a folder counts", g0 != rs_path_sig(dirname(d1)))
expect("data source: a path that is not there", rs_path_sig(file.path(tmp, "none")) == "missing" && rs_path_sig(NA_character_) == "missing")

unlink(tmp, recursive = TRUE)
cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
