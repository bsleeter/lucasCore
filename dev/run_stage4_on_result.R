# Run stage 4 alone on the latest stage 3 result of a library
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); f <- if (length(a)) a[1] else "F:/lucasCore/dev/libs/lucasCore-flows.ssim"
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE))
r3 <- max(sc[IsResult == "Yes" & grepl("Carbon flows", Name), ScenarioId])
S <- rsyncrosim::scenario(P, sprintf("Initial stocks on result %d", r3)); dependency(S) <- r3
saveDatasheet(S, data.frame(StageNameId = "4 - Spin-up and Initial Stocks", RunOrder = 1), "core_Pipeline")
t0 <- Sys.time(); R <- run(S); cat(sprintf("run took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
cat(paste(unique(lg[grepl("^4 Initial|Spin-up|Mean stocks|Failure|rror", lg)]), collapse = "\n"), "\n")
x <- as.data.table(datasheet(R, "lucasCore_InitialStockCurve", lookupsAsFactors = FALSE)); cat("Initial Stock Curves:", nrow(x), "rows\n")
fwrite(x, paste0(tools::file_path_sans_ext(f), "-initial-stocks.csv"))
