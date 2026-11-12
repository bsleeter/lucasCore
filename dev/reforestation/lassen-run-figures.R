# To-do 57 step 6: Run Figures (stage 13) of Lassen runs, to check the post-disturbance and reforestation figures.
# Usage: Rscript dev/reforestation/lassen-run-figures.R <Build result for the grid> <further Build result> <run id> [<run id> ...]
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- as.integer(commandArgs(TRUE)); L <- ssimLibrary("F:/lucasCore/dev/libs/lassen/Lassen.ssim", summary = FALSE); P <- rsyncrosim::project(L, 1)
for (rid in a[-(1:2)]) { S <- scenario(P, sprintf("Run Figures %d (step 6)", rid)); dependency(S) <- a[1:2]
  saveDatasheet(S, data.frame(StageNameId = "13 - Run Figures", RunOrder = 1L), "core_Pipeline")
  saveDatasheet(S, data.frame(RunScenarioId = rid), "lucasCore_RunFigureOptions")
  r <- run(S); f <- as.data.table(datasheet(r, "lucasCore_OutputRunFigure", lookupsAsFactors = FALSE))
  cat(sprintf("run %d -> result %d: %d figures: %s\n", rid, scenarioId(r), nrow(f), paste(f$Title, collapse = "; ")))
  for (k in grep("disturb|eforest", f$Title, ignore.case = TRUE)) cat("  ", f$FileName[k], "\n") }
