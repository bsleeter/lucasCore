# =============================================================================
# phaseZ-build-figures.R - stage 12 as its own scenario on a Build result: the figures are drawn, saved and readable
# =============================================================================
# On the library tests/phaseX-studio-library.R made: a "Build Figures (phaseZ)" scenario depending on the newest Build result, pipeline
# stage 12 alone. Passes when the run succeeds, Build Figures has rows, every PNG exists in the result's folder and is a PNG, and
# stage 12's checks passed.
# Usage: Rscript tests/phaseZ-build-figures.R   (bring the library up to date first: Rscript tools/sync-library.R <library>)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-studio-library.ssim"
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(rsyncrosim::scenario(L, summary = TRUE))
bid <- max(sc[IsResult == "Yes" & grepl("Build", Name, fixed = TRUE) & !grepl("Figures", Name), ScenarioId]); cat("Build result", bid, "\n")
old <- sc[IsResult == "No" & Name == "Build Figures (phaseZ)", ScenarioId]; for (i in old) delete(L, scenario = i, force = TRUE)
S <- rsyncrosim::scenario(P, "Build Figures (phaseZ)")
dependency(S) <- bid
saveDatasheet(S, data.frame(StageNameId = "12 - Build Figures", RunOrder = 1L), "core_Pipeline")
t0 <- Sys.time(); R <- run(S); cat(sprintf("stage 12 took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); cat(unique(lg[grepl("figures drawn|hillshade|Failure|FAIL", lg)]), sep = "\n")
fig <- as.data.table(datasheet(R, "lucasCore_OutputBuildFigure", lookupsAsFactors = FALSE))
v <- as.data.table(datasheet(R, "lucasCore_OutputValidation"))[Stage == "12 Build Figures"]
png_sig <- function(p) file.exists(p) && identical(readBin(p, "raw", 8), as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)))
ok <- nrow(fig) > 0 && all(vapply(fig$FileName, png_sig, TRUE)) && nrow(v) > 0 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))
print(fig[, .(Figure, Title, File = basename(FileName))]); cat(dirname(fig$FileName[1]), "\n")
cat(if (ok) "BUILD FIGURES OK\n" else "BUILD FIGURES FAILED\n")
