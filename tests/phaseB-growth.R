# =============================================================================
# phaseB-growth.R - stage 2 runs in a new library and produces a curve for every forest state class x ecodivision
# =============================================================================
# Usage: Rscript tests/phaseB-growth.R [--dir=dev/libs]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
D <- opt("dir", "F:/lucasCore/dev/libs"); dir.create(D, showWarnings = FALSE, recursive = TRUE)
f <- file.path(D, "lucasCore-growth.ssim"); unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
if (system2(file.path(R.home("bin"), "Rscript.exe"), c("tools/new-library.R", shQuote(f)), stdout = FALSE)) stop("new-library.R failed")
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions")
S <- rsyncrosim::scenario(P, "Growth curves")
saveDatasheet(S, data.frame(StageNameId = "2 - Fit Growth Curves", RunOrder = 1), "core_Pipeline")
t0 <- Sys.time(); R <- run(S); cat(sprintf("run took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); lg <- lg[nzchar(lg) & !grepl("depends on|You should load|conda|undetermined|ssimLibrary", lg)]
cat(paste(lg[grepl("Growth options|Cells|FIA:|Fitted|method|2 Growth|Error|Failure|failed", lg)], collapse = "\n"), "\n")
v <- datasheet(R, "lucasCore_OutputValidation"); ok <- nrow(v) > 0 && all(v$Status == "Pass")
p <- as.data.table(datasheet(R, "lucasCore_OutputGrowthParameter", lookupsAsFactors = FALSE))
cv <- as.data.table(datasheet(R, "lucasCore_MerchantableVolumeCurve", lookupsAsFactors = FALSE))
cat(sprintf("parameters: %d rows; curves: %d rows (%d cells x %d ages)\n", nrow(p), nrow(cv), uniqueN(cv[, .(StratumId, StateClassId)]), uniqueN(cv$Age)))
print(dcast(p[, .N, by = .(StateClassId, Method)], StateClassId ~ Method, value.var = "N", fill = 0))
fwrite(p, file.path(D, "growth-parameters.csv")); fwrite(cv, file.path(D, "growth-curves.csv"))
cat("report:", datasheet(R, "lucasCore_OutputGrowthReport")$FileName, "\n")
cat(if (ok) "GROWTH OK\n" else "GROWTH FAILED\n")
