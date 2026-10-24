# 03-compare.R - stage 9's outputs in a projection result that failed in ST-Sim under multiprocessing (82) vs one that ran (85)
suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(data.table) })
con <- dbConnect(SQLite(), "F:/lucasCore/dev/libs/lucasCore-suitability.ssim", flags = SQLITE_RO)
tabs <- c("stsim_InitialConditionsSpatial", "stsim_InitialStockSpatial", "stsim_TransitionSpatialMultiplier", "stsim_TransitionTarget",
          "stsim_TransitionSizeDistribution", "stsim_TransitionSizePrioritization", "stsim_TransitionSpatialInitiationMultiplier",
          "core_SpatialMultiprocessing", "stsim_RunControl", "stsim_OutputOptionsSpatial", "stsim_OutputFilterTransitionGroups", "core_Pipeline")
cnt <- rbindlist(lapply(tabs, function(t) { x <- dbGetQuery(con, sprintf("SELECT ScenarioId, COUNT(*) n FROM %s WHERE ScenarioId IN (82, 85) GROUP BY ScenarioId", t))
  data.table(Table = t, failed_82 = sum(x$n[x$ScenarioId == 82]), ok_85 = sum(x$n[x$ScenarioId == 85])) }))
print(cnt)
for (t in c("stsim_InitialConditionsSpatial", "stsim_InitialStockSpatial")) { cat("\n", t, "\n"); print(dbGetQuery(con, sprintf("SELECT * FROM %s WHERE ScenarioId IN (82, 85)", t))) }
sm <- as.data.table(dbGetQuery(con, "SELECT ScenarioId, Iteration, Timestep, TransitionGroupId, MultiplierFileName FROM stsim_TransitionSpatialMultiplier WHERE ScenarioId IN (82, 85)"))
cat("\nmultiplier files: rows, NA iteration, distinct files\n"); print(sm[, .(rows = .N, na_iter = sum(is.na(Iteration)), files = uniqueN(MultiplierFileName)), by = ScenarioId])
# files that exist in the scenario folders
for (s in c(82, 85)) { d <- sprintf("F:/lucasCore/dev/libs/lucasCore-suitability.ssim.data/Scenario-%d", s)
  f <- sm[ScenarioId == s, unique(MultiplierFileName)]; cat(sprintf("scenario %d: %d multiplier files, %d found in its folder tree\n", s, length(f), sum(file.exists(file.path(d, "stsim_TransitionSpatialMultiplier", basename(f)))))) }
print(dbGetQuery(con, "SELECT ScenarioId, * FROM core_Pipeline WHERE ScenarioId IN (82, 85, 68)"))
