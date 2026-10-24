# 04-spatialmp.R - one projection (stage 9 + ST-Sim, scenario 68) under multi-scenario multiprocessing; prints whether ST-Sim's job
# fails and the first failure lines. Run with the package as it is, then with stage 9's core_SpatialMultiprocessing output removed.
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); CON <- "C:/Program Files/SyncroSim/SyncroSim.Console.exe"
saveDatasheet(L, data.frame(EnableMultiprocessing = TRUE, MaximumJobs = 3L, EnableMultiScenario = TRUE), "core_Multiprocessing")
t0 <- Sys.time(); system2(shQuote(CON), c("--run", paste0("--lib=", f), "--sids=68"), stdout = FALSE, stderr = FALSE)
saveDatasheet(L, data.frame(EnableMultiprocessing = FALSE, MaximumJobs = 1L, EnableMultiScenario = FALSE), "core_Multiprocessing")
s <- as.data.table(scenario(L, summary = TRUE)); r <- max(s[IsResult == "Yes" & ParentId == 68, ScenarioId])
lg <- trimws(strsplit(paste(runLog(scenario(L, r)), collapse = "\n"), "\n")[[1]]); lg <- lg[nzchar(lg)]
cat(sprintf("68 -> result %d in %.1f min: %s\n", r, as.numeric(Sys.time() - t0, units = "mins"), if (any(grepl("\\[Failure\\]", lg))) "FAILS" else "RUNS"))
cat(unique(lg[grepl("Failure|creating jobs|running jobs|Total time", lg)]), sep = "\n")
