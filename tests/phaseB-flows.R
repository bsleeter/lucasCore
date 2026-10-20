# =============================================================================
# phaseB-flows.R - stages 2-4 run in a new library: carbon curves -> stock-flow configuration -> initial stocks by age
# =============================================================================
# Usage: Rscript tests/phaseB-flows.R [--dir=dev/libs]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
D <- opt("dir", "F:/lucasCore/dev/libs"); dir.create(D, showWarnings = FALSE, recursive = TRUE)
f <- file.path(D, "lucasCore-flows.ssim"); unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
if (system2(file.path(R.home("bin"), "Rscript.exe"), c("tools/new-library.R", shQuote(f)), stdout = FALSE)) stop("new-library.R failed")
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions")
sc <- scenario(L, summary = TRUE)
S <- rsyncrosim::scenario(P, "Growth curves and carbon flows"); dependency(S) <- sc$ScenarioId[sc$Name == "Stock-Flow Definitions"]
saveDatasheet(S, data.frame(StageNameId = c("2 - Fit Growth Curves", "3 - Carbon Flows", "4 - Spin-up and Initial Stocks"), RunOrder = 1:3), "core_Pipeline")
t0 <- Sys.time(); R <- run(S); cat(sprintf("run took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); lg <- lg[nzchar(lg) & !grepl("depends on|You should load|conda|undetermined|ssimLibrary", lg)]
cat(paste(unique(lg[grepl("^3 Carbon|^4 Initial|Forest:|Writing|Carbon curves|Decay calibration|Spin-up|Mean stocks|Error|Failure|failed|temperature", lg)]), collapse = "\n"), "\n")
dc <- as.data.table(datasheet(R, "lucasCore_OutputDecayCalibration", lookupsAsFactors = FALSE)); fwrite(dc, file.path(D, "decay-calibration.csv"))
print(dc[, .N, by = .(Level, SoilSource)])
v <- datasheet(R, "lucasCore_OutputValidation")
ok <- nrow(v) > 0 && all(v$Status == "Pass") && nrow(datasheet(R, "stsim_FlowPathway")) > 0 && !any(grepl("[Failure]", lg, fixed = TRUE))
for (sh in c("stsim_FlowPathway", "stsim_FlowMultiplier", "stsim_StateAttributeValue", "lucasCore_InitialStockCurve"))
  cat(sprintf("%-32s %8d rows\n", sh, nrow(datasheet(R, sh))))
fm <- as.data.table(datasheet(R, "stsim_FlowMultiplier", lookupsAsFactors = FALSE)); fwrite(fm, file.path(D, "flow-multipliers.csv"))
fwrite(as.data.table(datasheet(R, "stsim_StateAttributeValue", lookupsAsFactors = FALSE)), file.path(D, "state-attributes.csv"))
fwrite(as.data.table(datasheet(R, "lucasCore_InitialStockCurve", lookupsAsFactors = FALSE)), file.path(D, "initial-stocks.csv"))
cat("result scenario:", scenarioId(R), "\n")
cat(if (ok) "FLOWS OK\n" else "FLOWS FAILED\n")
