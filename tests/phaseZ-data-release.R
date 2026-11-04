# =============================================================================
# phaseZ-data-release.R - stage 17 writes a data release folder from a Build and its runs (to-do 14, Phase 3)
# =============================================================================
# On a library with a Build result and a finished run: a "Data Release (test)" scenario depending on the Build, pipeline stage 17 alone. Passes when the
# run succeeds, the folder holds the parent, model and run records, a backup in archive/, every file listed in Release Contents with the right
# checksum, and the stage's checks pass. Writes to the library it is given: never the P26 guide library.
# Usage: Rscript tests/phaseZ-data-release.R "<library.ssim>" --build=<result id> --runs=<id,id> --out=<empty folder> [--every=<n>]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); lib <- a[!startsWith(a, "--")][1]; arg <- function(k) sub(paste0("^--", k, "="), "", grep(paste0("^--", k, "="), a, value = TRUE))
id <- as.integer(arg("build")); runs <- as.integer(strsplit(arg("runs"), ",")[[1]]); out <- arg("out"); every <- arg("every")
L <- suppressWarnings(ssimLibrary(lib)); P <- rsyncrosim::project(L, 1)
S <- rsyncrosim::scenario(P, "Data Release (test)")
dependency(S) <- id
saveDatasheet(S, data.frame(StageNameId = "17 - Data Release", RunOrder = 1L), "core_Pipeline")
saveDatasheet(S, data.frame(OutputFolder = out, MapEvery = if (length(every)) as.integer(every) else NA_integer_), "lucasCore_DataReleaseOptions")
saveDatasheet(S, data.frame(RunScenarioId = runs), "lucasCore_DataReleaseRun")
R <- run(S)
capture.output(rl <- runLog(R)); lg <- trimws(strsplit(paste(rl, collapse = "\n"), "\n")[[1]])
cat(unique(lg[grepl("Release:|Still placeholder|17 Data Release -|Failure|Model archive", lg)]), sep = "\n")
v <- as.data.table(datasheet(R, "lucasCore_OutputValidation"))[Stage == "17 Data Release"]
ct <- as.data.table(datasheet(R, "lucasCore_OutputReleaseContents", lookupsAsFactors = FALSE))
files <- list.files(out, recursive = TRUE); files <- setdiff(files, "contents.csv"); files <- files[!startsWith(files, "review/")]
sums <- nrow(ct) > 0 && all(vapply(seq_len(min(nrow(ct), 20)), function(i) identical(ct$Sha256[i], digest::digest(file = file.path(out, ct$File[i]), algo = "sha256")), TRUE))
ok <- nrow(v) > 0 && all(v$Status == "Pass") && setequal(files, ct$File) && sums && file.exists(file.path(out, "release.xml")) && file.exists(file.path(out, "model", "model.xml")) &&
  length(grep("(historical|projections)/[^/]+/run.xml$", files)) == length(runs) && length(grep("^archive/.*[.]ssimbak$", files)) >= 1 &&
  all(file.exists(file.path(out, "review", c("reviewer-summary.html", "data-review-checklist.html", "metadata-review-checklist.html", "checks.csv"))))
ok <- ok && !grepl("PLACEHOLDER", paste(xml2::xml_text(xml2::xml_find_all(xml2::read_xml(file.path(out, "release.xml")), "//theme[themekt='USGS Metadata Identifier']/themekey")), collapse = ""), fixed = TRUE)
cat(sprintf("%d files, %d checks\n", length(files), nrow(v)))
cat(if (ok) "DATA RELEASE OK\n" else "DATA RELEASE FAILED\n")
