# =============================================================================
# test_compare_figures.R - draw the comparison figures (src/compare-figures.R) of ST-Sim runs outside SyncroSim, read-only
# =============================================================================
# Usage: Rscript dev/figures/test_compare_figures.R <library.ssim> <build result id> <run ids, comma separated; the first projection
#        is the baseline> [labels, comma separated] [out dir]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra); library(sf); library(DBI); library(RSQLite) })
a <- commandArgs(TRUE); lib <- a[1]; bid <- as.integer(a[2]); ids <- as.integer(strsplit(a[3], ",")[[1]])
labs <- if (length(a) >= 4 && nzchar(a[4])) strsplit(a[4], ",")[[1]] else rep(NA_character_, length(ids))
out <- if (length(a) >= 5) a[5] else "F:/lucasCore/dev/figures/out-compare"
source("F:/lucasCore/src/figures.R"); source("F:/lucasCore/src/run-figures.R"); source("F:/lucasCore/src/compare-figures.R")
con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
ic <- q("SELECT StateClassFileName FROM stsim_InitialConditionsSpatial WHERE ScenarioId = %d", bid)
grid <- rast(file.path(paste0(lib, ".data"), sprintf("Scenario-%d", bid), "stsim_InitialConditionsSpatial", basename(ic$StateClassFileName[1])))
dem <- q("SELECT ElevationFile FROM lucasCore_DataSource")$ElevationFile[1]
sa <- q("SELECT u.Name FROM lucasCore_StudyArea s JOIN stsim_SecondaryStratum u ON u.SecondaryStratumId = s.UnitId"); dbDisconnect(con)
t0 <- Sys.time(); R <- compare_runs(lib, data.table(RunScenarioId = ids, Label = labs))
cat(sprintf("loaded %d runs in %.0f s: %s\n", length(R), as.numeric(Sys.time() - t0, units = "secs"),
            paste(vapply(R, function(r) sprintf("%d %s%s%s", r$rid, r$label, if (r$hist) " [history]" else "", if (r$base) " [baseline]" else ""), ""), collapse = "; ")))
unlink(out, recursive = TRUE)
res <- compare_figures(R, grid, dem, if (nrow(sa)) paste(unique(sub("^[^:]*: ", "", sa$Name)), collapse = ", ") else "Study area", out)
print(res[, .(Figure, Title, File = basename(FileName))]); print(attr(res, "carbon")); print(attr(res, "land")); cat(sprintf("%.0f s\n", as.numeric(Sys.time() - t0, units = "secs")))
