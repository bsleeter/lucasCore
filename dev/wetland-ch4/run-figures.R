# =============================================================================
# run-figures.R - stage 13 (Run Figures) on a history and a projection, and stage 14 (Compare Runs) on the two, for a chain made by full-chain.R
# =============================================================================
# Usage: Rscript dev/wetland-ch4/run-figures.R <library.ssim> <Build result> <historical result> <projection result> [tag]
# Prints each stage's run log tail, the figures written and where the wetland methane figures are.
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); lib <- normalizePath(a[1], winslash = "/"); bid <- as.integer(a[2]); hid <- as.integer(a[3]); pid <- as.integer(a[4]); tag <- if (length(a) > 4) a[5] else "chain"
L <- suppressWarnings(ssimLibrary(lib)); P <- rsyncrosim::project(L, "Definitions")
fresh <- function(nm) { sc <- as.data.table(rsyncrosim::scenario(L, summary = TRUE)); old <- sc[Name == nm & IsResult == "No", ScenarioId]
  if (length(old)) delete(L, scenario = old, force = TRUE); S <- rsyncrosim::scenario(P, nm); dependency(S) <- bid; S }
go <- function(S, sheet) { t0 <- Sys.time(); R <- tryCatch(run(S), error = function(e) e)
  if (inherits(R, "error")) { cat(name(S), "FAILED:", conditionMessage(R), "\n"); return(invisible()) }
  log <- trimws(unlist(strsplit(as.character(runLog(R)), "\n"))); log <- log[nzchar(log)]
  cat(sprintf("\n== %s: result %d, %.1f min\n", name(S), scenarioId(R), as.numeric(Sys.time() - t0, units = "mins")))
  cat(substr(grep("pass|FAIL|Failure|Warning\\]|Error|wetland|methane", log, value = TRUE, ignore.case = TRUE), 1, 260), sep = "\n")
  f <- as.data.table(datasheet(R, sheet, lookupsAsFactors = FALSE)); cat(sprintf("%d figures\n", nrow(f))); print(f[, .(Figure, Title = substr(Title, 1, 70), File = basename(FileName))], nrows = 100)
  w <- f[grepl("wetland|methane", Title, ignore.case = TRUE)]; if (nrow(w)) cat("wetland figures:", w$FileName, sep = "\n") }
for (r in c(hid, pid)) { S <- fresh(sprintf("Run Figures %d %s", r, tag)); saveDatasheet(S, data.frame(StageNameId = "13 - Run Figures", RunOrder = 1L), "core_Pipeline")
  saveDatasheet(S, data.frame(RunScenarioId = r), "lucasCore_RunFigureOptions"); go(S, "lucasCore_OutputRunFigure") }
S <- fresh(sprintf("Compare Runs %s", tag)); saveDatasheet(S, data.frame(StageNameId = "14 - Compare Runs", RunOrder = 1L), "core_Pipeline")
saveDatasheet(S, data.frame(RunScenarioId = c(hid, pid)), "lucasCore_CompareRunOptions"); go(S, "lucasCore_OutputCompareFigure")
