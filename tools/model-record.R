# =============================================================================
# model-record.R - write the FGDC CSDGM model record of a Build result (to-do 14, Phase 2) and check it with mp
# =============================================================================
# Usage: Rscript tools/model-record.R "<library.ssim>" --build=<result scenario id> [--out=<folder>] [--mp=<path to mp.exe>]
# Writes <out>/model.xml (default: the folder of the library, model-record-<id>/) and <out>/model-mp.txt, and prints what is still
# a placeholder or drafted, what the generator had to infer, and mp's errors and warnings. Reads the library; writes nothing to it.
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "metadata.R")); source(file.path(pkg, "src", "metadata-record.R"))
a <- commandArgs(TRUE); arg <- function(k) { v <- sub(paste0("^--", k, "="), "", grep(paste0("^--", k, "="), a, value = TRUE)); if (length(v)) v[1] else NA_character_ }
lib <- a[!startsWith(a, "--")][1]; sid <- as.integer(arg("build"))
if (is.na(lib) || is.na(sid)) stop("usage: Rscript tools/model-record.R \"<library.ssim>\" --build=<result scenario id> [--out=] [--mp=]")
out <- arg("out"); if (is.na(out)) out <- file.path(dirname(normalizePath(lib, winslash = "/")), sprintf("model-record-%d", sid))
if (!is.na(arg("mp"))) options(lucas.mp = arg("mp"))
dir.create(out, showWarnings = FALSE, recursive = TRUE)

facts <- md_build_facts(lib, sid)
x <- md_model_content(facts, file.path(pkg, "defaults", "metadata"))
f <- file.path(out, "model.xml"); xml2::write_xml(md_csdgm(x), f)
cat(sprintf("model record: %s (%d lineage sources, %d process steps)\n", f, length(x$quality$sources), length(x$quality$steps)))
cat("still to supply:\n", paste0("  ", x$draft, "\n"), sep = "")
if (length(x$notes)) cat("notes:\n", paste0("  ", x$notes, "\n"), sep = "")
m <- md_mp(f)
if (is.null(m)) cat("mp not found: set --mp=, the option lucas.mp or LUCAS_MP\n") else {
  writeLines(m$Message, file.path(out, "model-mp.txt"))
  cat(sprintf("mp: %d errors, %d warnings\n", sum(m$Level == "Error"), sum(m$Level == "Warning"))); if (nrow(m)) cat(paste0("  ", m$Message, "\n"), sep = "") }
