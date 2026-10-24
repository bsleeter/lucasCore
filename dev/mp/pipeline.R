# pipeline.R - set the pipeline of test scenarios. Usage: Rscript dev/mp/pipeline.R <ids comma-separated> stage9|stsim|both
suppressPackageStartupMessages({ library(rsyncrosim) })
a <- commandArgs(TRUE); L <- ssimLibrary("F:/lucasCore/dev/libs/lucasCore-suitability.ssim")
for (id in as.integer(strsplit(a[1], ",")[[1]])) { S <- scenario(L, id)
  st <- grep("ST-Sim|stsim", levels(datasheet(S, "core_Pipeline", lookupsAsFactors = TRUE, optional = TRUE)$StageNameId), value = TRUE, ignore.case = TRUE)[1]
  p <- switch(a[2], stage9 = "9 - Projection Transitions", stsim = st, both = c("9 - Projection Transitions", st))
  saveDatasheet(S, data.frame(StageNameId = p, RunOrder = seq_along(p)), "core_Pipeline"); cat(id, ":", paste(p, collapse = " > "), "\n") }
