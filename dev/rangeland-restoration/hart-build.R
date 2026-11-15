# Rangeland restoration test area (user 2026-11-14: "Lets switch to Hart Mountain. For this we could build the model at 300m just for
# the sake of testing and speed"): a Build of Hart Mountain National Antelope Refuge (+10 km, the Data Download's buffer), 300 m,
# 1985-2023. Library F:/lucasCore/dev/libs/hart-mountain/HartMountain.ssim (tools/new-library.R; Data Download 2026-11-14).
# Usage: Rscript dev/rangeland-restoration/hart-build.R [stages, default "1,5,2,3,4,6,7,8,12"] [--name=Build]
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); st <- if (length(a) && !grepl("^--", a[1])) as.integer(strsplit(a[1], ",")[[1]]) else c(1L, 5L, 2L, 3L, 4L, 6L, 7L, 8L, 12L)
nm <- sub("^--name=", "", grep("^--name=", a, value = TRUE)); if (!length(nm)) nm <- "Build Hart Mountain 300 m"
L <- ssimLibrary("F:/lucasCore/dev/libs/hart-mountain/HartMountain.ssim", summary = FALSE); P <- project(L, 1)
sc <- as.data.table(scenario(L, summary = TRUE))
S <- scenario(P, nm); dependency(S) <- sc[Name %in% c("Stock-Flow Definitions", "Carbon Assumptions") & IsResult == "No", ScenarioId]
names_all <- c(`0` = "0 - Stock-Flow Definitions", `1` = "1 - Study Area and Strata", `5` = "5 - Initial Conditions", `2` = "2 - Fit Growth Curves", `3` = "3 - Carbon Flows",
               `4` = "4 - Spin-up and Initial Stocks", `6` = "6 - Historical Transitions", `7` = "7 - Climate Multipliers", `8` = "8 - Initial Stock Maps", `12` = "12 - Build Figures")
saveDatasheet(S, data.frame(StageNameId = names_all[as.character(st)], RunOrder = seq_along(st)), "core_Pipeline")
saveDatasheet(S, data.frame(Resolution = 300L, StartYear = 1985L, EndYear = 2023L, SecondarySourceId = "States", TertiarySourceId = "Federal Lands"), "lucasCore_BuildOptions")
saveDatasheet(S, data.frame(UnitId = "FWS: Hart Mountain National Antelope Refuge"), "lucasCore_StudyArea")
cat(sprintf("scenario %d: %s, stages %s\n", scenarioId(S), nm, paste(st, collapse = ", ")))
t0 <- Sys.time(); r <- run(S); cat(sprintf("result %d (%.1f min)\n", scenarioId(r), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
