# =============================================================================
# phaseC-initial.R - stages 1 and 5 for a study area in a new library: strata, then state class, stand age, annual NLCD,
# return intervals and soil targets
# =============================================================================
# Usage: Rscript tests/phaseC-initial.R [--units="State: California"]  (Study Area units, comma-separated) [--dir=dev/libs]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
D <- opt("dir", "F:/lucasCore/dev/libs"); UNITS <- opt("units", "State: California"); dir.create(D, showWarnings = FALSE, recursive = TRUE)
f <- file.path(D, sprintf("lucasCore-initial-%s.ssim", gsub("[^A-Za-z0-9]+", "-", substr(UNITS, 1, 30))))
unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
if (system2(file.path(R.home("bin"), "Rscript.exe"), c("tools/new-library.R", shQuote(f)), stdout = FALSE)) stop("new-library.R failed")
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions")
S <- rsyncrosim::scenario(P, paste("Initial conditions:", UNITS))
saveDatasheet(S, data.frame(UnitId = trimws(strsplit(UNITS, ",")[[1]])), "lucasCore_StudyArea")
saveDatasheet(S, data.frame(StageNameId = c("1 - Study Area and Strata", "5 - Initial Conditions"), RunOrder = 1:2), "core_Pipeline")
t0 <- Sys.time(); R <- run(S); cat(sprintf("run took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
cat(paste(unique(lg[grepl("^5 Initial|^1 Study|Grid:|Annual NLCD|Forest cells|Return intervals|Error|Failure|failed", lg)]), collapse = "\n"), "\n")
v <- datasheet(R, "lucasCore_OutputValidation")
ok <- nrow(v) > 0 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))
sc <- as.data.table(datasheet(R, "lucasCore_OutputStateClassSummary", lookupsAsFactors = FALSE)); print(head(sc, 15))
fwrite(as.data.table(datasheet(R, "lucasCore_OutputReturnInterval", lookupsAsFactors = FALSE)), paste0(tools::file_path_sans_ext(f), "-return-interval.csv"))
fwrite(as.data.table(datasheet(R, "lucasCore_OutputSoilTarget", lookupsAsFactors = FALSE)), paste0(tools::file_path_sans_ext(f), "-soil-target.csv"))
cat("result scenario:", scenarioId(R), "\n")
cat(if (ok) "INITIAL OK\n" else "INITIAL FAILED\n")
