# =============================================================================
# phaseZ3-run-figures.R - stage 13 as its own scenario: figures of the newest ST-Sim run, drawn and saved
# =============================================================================
# On the library tests/phaseX-studio-library.R made (its historical run and projections): a "Run Figures (phaseZ3)" scenario depending
# on the Build result, pipeline stage 13 alone, Run Figures blank (= the newest ST-Sim result). Passes when the run succeeds, Run
# Figures has rows that are PNGs, and stage 13's checks passed. Usage: Rscript tests/phaseZ3-run-figures.R [run result id]
# (bring the library up to date first: Rscript tools/sync-library.R <library>)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); f <- "F:/lucasCore/dev/libs/lucasCore-studio-library.ssim"
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(rsyncrosim::scenario(L, summary = TRUE))
bid <- max(sc[IsResult == "Yes" & grepl("Build", Name, fixed = TRUE) & !grepl("Figures", Name), ScenarioId]); cat("Build result", bid, "\n")
for (i in sc[IsResult == "No" & Name == "Run Figures (phaseZ3)", ScenarioId]) delete(L, scenario = i, force = TRUE)
S <- rsyncrosim::scenario(P, "Run Figures (phaseZ3)"); dependency(S) <- bid
saveDatasheet(S, data.frame(StageNameId = "13 - Run Figures", RunOrder = 1L), "core_Pipeline")
if (length(a)) saveDatasheet(S, data.frame(RunScenarioId = as.integer(a[1])), "lucasCore_RunFigureOptions")
t0 <- Sys.time(); R <- run(S); cat(sprintf("stage 13 took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); cat(unique(lg[grepl("figures drawn|Run [0-9]|newest|Failure|FAIL", lg)]), sep = "\n")
fig <- as.data.table(datasheet(R, "lucasCore_OutputRunFigure", lookupsAsFactors = FALSE))
v <- as.data.table(datasheet(R, "lucasCore_OutputValidation"))[Stage == "13 Run Figures"]
png_sig <- function(p) file.exists(p) && identical(readBin(p, "raw", 8), as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)))
ok <- nrow(fig) > 0 && all(vapply(fig$FileName, png_sig, TRUE)) && nrow(v) > 0 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))
print(fig[, .(Figure, Title, File = basename(FileName), RunScenarioId)])
cat(if (ok) "RUN FIGURES OK\n" else "RUN FIGURES FAILED\n")
