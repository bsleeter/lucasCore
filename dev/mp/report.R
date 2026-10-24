# report.R - outcome of the latest result of each scenario id given: runs or fails, whether stages ran as jobs, failure lines
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
L <- ssimLibrary("F:/lucasCore/dev/libs/lucasCore-suitability.ssim"); s <- as.data.table(scenario(L, summary = TRUE))
for (p in as.integer(strsplit(commandArgs(TRUE)[1], ",")[[1]])) { r <- max(s[IsResult == "Yes" & ParentId == p, ScenarioId])
  lg <- trimws(strsplit(paste(runLog(scenario(L, r)), collapse = "\n"), "\n")[[1]]); lg <- lg[nzchar(lg)]
  it <- tryCatch(nrow(unique(as.data.table(datasheet(scenario(L, r), "stsim_OutputStock"))[, .(Iteration)])), error = function(e) NA)
  cat(sprintf("scenario %d -> result %d: %s; iterations in output %s\n", p, r, if (any(grepl("\\[Failure\\]", lg))) "FAILS" else "RUNS", it))
  cat("  ", unique(lg[grepl("creating jobs|running jobs|Failure|xception|STARTING|COMPLETE", lg)]), sep = "\n   ") ; cat("\n") }
