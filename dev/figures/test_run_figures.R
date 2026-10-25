# =============================================================================
# test_run_figures.R - draw the run figures (src/run-figures.R) of an ST-Sim run outside SyncroSim, read-only
# =============================================================================
# Usage: Rscript dev/figures/test_run_figures.R <library.ssim> <run result id> <build result id> [out dir]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra); library(sf); library(DBI); library(RSQLite) })
a <- commandArgs(TRUE); lib <- a[1]; rid <- as.integer(a[2]); bid <- as.integer(a[3]); out <- if (length(a) >= 4) a[4] else "F:/lucasCore/dev/figures/out-run"
source("F:/lucasCore/src/figures.R"); source("F:/lucasCore/src/run-figures.R")
con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
ic <- q("SELECT StateClassFileName FROM stsim_InitialConditionsSpatial WHERE ScenarioId = %d", bid)
grid <- rast(file.path(paste0(lib, ".data"), sprintf("Scenario-%d", bid), "stsim_InitialConditionsSpatial", basename(ic$StateClassFileName[1])))
scl <- q("SELECT Name, Color FROM stsim_StateClass"); dem <- q("SELECT ElevationFile FROM lucasCore_DataSource")$ElevationFile[1]
sa <- q("SELECT u.Name FROM lucasCore_StudyArea s JOIN stsim_SecondaryStratum u ON u.SecondaryStratumId = s.UnitId WHERE s.ScenarioId = %d", bid)
if (!nrow(sa)) sa <- q("SELECT u.Name FROM lucasCore_StudyArea s JOIN stsim_SecondaryStratum u ON u.SecondaryStratumId = s.UnitId")
obs <- q("SELECT Timestep, TransitionGroup, Area FROM lucasCore_OutputTransitionSummary WHERE ScenarioId = %d", bid)
rn <- q("SELECT Name FROM core_Scenario WHERE ScenarioId = %d", rid)$Name; dbDisconnect(con)
t0 <- Sys.time(); X <- load_run(lib, rid); cat(sprintf("loaded in %.0f s\n", as.numeric(Sys.time() - t0, units = "secs")))
res <- run_figures(X, grid, setNames(argb(scl$Color), scl$Name), dem, if (nrow(sa)) paste(sub("^[^:]*: ", "", sa$Name), collapse = ", ") else "Study area", obs, out,
                   run_name = sub(" \\(\\[.*$", "", rn))
print(res[, .(Figure, Title, File = basename(FileName))]); cat(sprintf("%.0f s\n", as.numeric(Sys.time() - t0, units = "secs")))
