# =============================================================================
# data-release.R - write a data release folder from a Build and its runs (to-do 14, Phase 3), outside a run
# =============================================================================
# Usage: Rscript tools/data-release.R "<library.ssim>" --build=<id> --runs=<id,id> --out=<folder>
#        [--every=<n>] [--years=<y,y>] [--no-maps] [--no-archive] [--mp=<path to mp.exe>] [--info=<id of the scenario holding the Release Information page>]
# The newest Build Figures, Run Figures and Compare Runs results of these runs go in by themselves. Reads the library and writes nothing to it; --no-archive leaves out the
# backup, which writes to the library's .backup folder. Stage 17 writes the same folder inside a scenario.
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
for (f in c("datahome.R", "metadata.R", "metadata-record.R", "release.R")) source(file.path(pkg, "src", f))
a <- commandArgs(TRUE); arg <- function(k) { v <- sub(paste0("^--", k, "="), "", grep(paste0("^--", k, "="), a, value = TRUE)); if (length(v)) v[1] else NA_character_ }
ids <- function(k) { v <- arg(k); if (is.na(v)) integer() else as.integer(strsplit(v, ",")[[1]]) }
lib <- a[!startsWith(a, "--")][1]; build <- as.integer(arg("build")); runs <- ids("runs"); out <- arg("out")
if (is.na(lib) || is.na(build) || !length(runs) || is.na(out)) stop("usage: Rscript tools/data-release.R \"<library.ssim>\" --build=<id> --runs=<id,id> --out=<folder> [--every=] [--years=] [--no-maps] [--no-archive] [--mp=]")
if (!is.na(arg("mp"))) options(lucas.mp = arg("mp"))
y <- ids("years")
console <- suppressPackageStartupMessages({ library(rsyncrosim); file.path(filepath(session()), "SyncroSim.Console.exe") })
r <- rl_release(lib, build, runs, out, file.path(pkg, "defaults", "metadata"), every = if (is.na(arg("every"))) 1L else as.integer(arg("every")), years = if (length(y)) y else NULL,
                maps = !"--no-maps" %in% a, archive = !"--no-archive" %in% a, console = console, say = function(m) cat(m, "\n", sep = ""), info_scenario = if (is.na(arg("info"))) NA_integer_ else as.integer(arg("info")))
cat(sprintf("\n%s: %d files, %.2f GB\n", r$out, nrow(r$contents), sum(r$contents$bytes) / 1e9))
print(r$contents[, .(files = .N, MB = round(sum(bytes) / 1e6, 1)), by = product])
cat("\nchecks:\n"); for (i in seq_len(nrow(r$checks))) cat(sprintf("  %s  %s%s\n", if (r$checks$Pass[i]) "pass" else "FAIL", r$checks$Check[i], if (nzchar(r$checks$Detail[i])) paste0(": ", substr(r$checks$Detail[i], 1, 400)) else ""))
if (!r$mp_found) cat("mp not found\n") else { cat(sprintf("\nmp on %d records: %d errors, %d warnings\n", length(r$records), sum(r$mp$Level == "Error"), sum(r$mp$Level == "Warning"))); if (nrow(r$mp)) print(r$mp) }
