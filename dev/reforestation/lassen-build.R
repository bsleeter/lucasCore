# To-do 57 steps 4-9: a Build of Lassen Volcanic National Park (+10 km), 150 m (user 2026-11-12: a test library, run efficiency first), 1985-2023, for testing the reforestation transition
# in the West (user 2026-11-12). Library F:/lucasCore/dev/libs/lassen/Lassen.ssim (tools/new-library.R; Data Download done).
# Usage: Rscript dev/reforestation/lassen-build.R [stages, default "1,5"] [--name=Build]
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); st <- if (length(a) && !grepl("^--", a[1])) as.integer(strsplit(a[1], ",")[[1]]) else c(1L, 5L)
nm <- sub("^--name=", "", grep("^--name=", a, value = TRUE)); if (!length(nm)) nm <- "Build Lassen 150 m"
L <- ssimLibrary("F:/lucasCore/dev/libs/lassen/Lassen.ssim", summary = FALSE); P <- project(L, 1)
sc <- as.data.table(scenario(L, summary = TRUE))
d <- datasheet(P, "lucasCore_DataSource", optional = TRUE, empty = FALSE)   # the data home (Data Download done 2026-11-12 into E:/lucasData)
if (!nrow(d) || is.na(d$DataSourcesHome[1])) saveDatasheet(P, data.frame(DataSourcesHome = "E:/lucasData"), "lucasCore_DataSource", append = FALSE, force = TRUE)
S <- scenario(P, nm); dependency(S) <- sc[Name %in% c("Stock-Flow Definitions", "Carbon Assumptions") & IsResult == "No", ScenarioId]
names_all <- c(`0` = "0 - Stock-Flow Definitions", `1` = "1 - Study Area and Strata", `5` = "5 - Initial Conditions", `2` = "2 - Fit Growth Curves", `3` = "3 - Carbon Flows",
               `4` = "4 - Spin-up and Initial Stocks", `6` = "6 - Historical Transitions", `7` = "7 - Climate Multipliers", `8` = "8 - Initial Stock Maps", `12` = "12 - Build Figures")
saveDatasheet(S, data.frame(StageNameId = names_all[as.character(st)], RunOrder = seq_along(st)), "core_Pipeline")
saveDatasheet(S, data.frame(Resolution = 150L, StartYear = 1985L, EndYear = 2023L, SecondarySourceId = "States", TertiarySourceId = "Federal Lands"), "lucasCore_BuildOptions")
saveDatasheet(S, data.frame(UnitId = "NPS: Lassen Volcanic National Park"), "lucasCore_StudyArea")
cat(sprintf("scenario %d: %s, stages %s\n", scenarioId(S), nm, paste(st, collapse = ", ")))
r <- run(S); cat("result", scenarioId(r), "\n")
