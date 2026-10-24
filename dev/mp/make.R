# make.R - test projections for multiprocessing (3 projection years). Usage: Rscript dev/mp/make.R <setup id> <iterations> <name> [<name> ...]
# prints the new scenario ids; sets library multiprocessing with: Rscript dev/mp/make.R --mp <on TRUE|FALSE> <jobs> <multiscenario TRUE|FALSE>
suppressPackageStartupMessages({ library(rsyncrosim) })
a <- commandArgs(TRUE); f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
if (a[1] == "--mp") { L <- ssimLibrary(f); saveDatasheet(L, data.frame(EnableMultiprocessing = as.logical(a[2]), MaximumJobs = as.integer(a[3]), EnableMultiScenario = as.logical(a[4])), "core_Multiprocessing")
  print(datasheet(L, "core_Multiprocessing")); quit(save = "no") }
ids <- c()
for (nm in a[-(1:2)]) { out <- system2(RS, c("F:/lucasCore/tools/new-projection.R", shQuote(f), shQuote(c("--historical=49", "--stage9", sprintf("--build=%s", a[1]), "--years=3", sprintf("--iterations=%s", a[2]), "--replace", sprintf("--name=%s", nm)))), stdout = TRUE, stderr = TRUE)
  ids <- c(ids, as.integer(tail(out[!grepl("Warning|undetermined|^In ssimLibrary", out)], 1))) }
cat("IDS", paste(ids, collapse = ","), "\n")
