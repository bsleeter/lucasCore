# =============================================================================
# phaseH-copy-curves.R - stage 2 copies growth curves from another library (Growth Curve Options: Copy from another library)
# =============================================================================
# Source: a library with a stage 2 result (default: the phaseG-starter library, whose Growth Curves result holds the curves). A copy
# of the starter runs stages 1, 2 (copy), 3, 4 for the study area; then stage 2 alone must refuse a missing library, a scenario without
# curves, and this library as the source.
# Usage: Rscript tests/phaseH-copy-curves.R [--source=dev/libs/lucasCore-starter-County-Placer-California.ssim] [--units="County: Placer California"]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
D <- "F:/lucasCore/dev/libs"; UNITS <- opt("units", "County: Placer California")
SRC <- normalizePath(opt("source", file.path(D, "lucasCore-starter-County-Placer-California.ssim")), winslash = "/")
if (!file.exists(SRC)) stop("source library not found (run tests/phaseG-starter.R first): ", SRC)
f <- file.path(D, "lucasCore-copy-curves.ssim"); unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
file.copy("F:/lucasCore/Starter/LUCAS Core (CONUS).ssim", f)
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE))
sfd <- sc[Name == "Stock-Flow Definitions", ScenarioId]
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
go <- function(name, stages, gopt, desc, units = TRUE) {
  S <- rsyncrosim::scenario(P, name); dependency(S) <- sfd; description(S) <- desc
  saveDatasheet(S, gopt, "lucasCore_GrowthOptions")
  if (units) saveDatasheet(S, data.frame(UnitId = trimws(strsplit(UNITS, ",")[[1]])), "lucasCore_StudyArea")
  saveDatasheet(S, data.frame(StageNameId = stages, RunOrder = seq_along(stages)), "core_Pipeline")
  # a run that fails makes rsyncrosim's run() throw: read the reason from the newest result scenario's run log
  R <- tryCatch(run(S), error = function(e) NULL)
  if (is.null(R)) { s2 <- as.data.table(scenario(L, summary = TRUE)); R0 <- scenario(L, s2[IsResult == "Yes", max(ScenarioId)]); lg <- logl(R0)
    cat(sprintf("\n==== %s (run failed)\n", name)); cat(paste(unique(lg[grepl("^Error|fail\\(|not found|has no|is this library|Source", lg)]), collapse = "\n"), "\n")
    return(list(R = NULL, ok = FALSE)) }
  lg <- logl(R)
  cat(sprintf("\n==== %s\n", name)); cat(paste(unique(lg[grepl("copied from|differ from|options were empty|could not be read|^2 Growth|Study area: [0-9]|Decay calibration:|Spin-up:|Failure|rror", lg)]), collapse = "\n"), "\n")
  v <- datasheet(R, "lucasCore_OutputValidation"); list(R = R, ok = nrow(v) > 0 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))) }
copy_opt <- function(lib, sid = NA) data.frame(CurveSource = 2L, CurveLibrary = lib, CurveScenarioId = as.integer(sid))

r1 <- go("Copy curves", c("1 - Study Area and Strata", "2 - Fit Growth Curves", "3 - Carbon Flows", "4 - Spin-up and Initial Stocks"), copy_opt(SRC),
         sprintf("tests/phaseH-copy-curves.R: stages 1-4 for %s with growth curves copied from %s (latest result with curves).", UNITS, SRC))
n_cc <- if (r1$ok) nrow(datasheet(r1$R, "lucasCore_CarbonCurve")) else 0
r2 <- go("Missing source library", "2 - Fit Growth Curves", copy_opt("F:/no/such/library.ssim"), "tests/phaseH-copy-curves.R: must refuse a missing library.", FALSE)
r3 <- go("Scenario without curves", "2 - Fit Growth Curves", copy_opt(SRC, 1), "tests/phaseH-copy-curves.R: scenario 1 of the source has no curves; must refuse.", FALSE)
r4 <- go("This library as source", "2 - Fit Growth Curves", copy_opt(f), "tests/phaseH-copy-curves.R: must refuse this library as its own source.", FALSE)
ok <- r1$ok && n_cc > 0 && !r2$ok && !r3$ok && !r4$ok
cat(sprintf("\ncopy ok %s (%d carbon curve rows); refused: missing %s, no curves %s, same library %s\n", r1$ok, n_cc, !r2$ok, !r3$ok, !r4$ok))
cat(if (ok) "COPY CURVES OK\n" else "COPY CURVES FAILED\n")
