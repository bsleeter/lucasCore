# =============================================================================
# fire-maps.R - the projection's fire inputs on the P26 grid (Projection Setup result 17): the ignition multiplier and the yearly
# fire multiplier maps (each cell's chance of burning in a year), for a quiet, a typical and a large drawn year. Read-only.
# Usage: Rscript dev/figures/fire-maps.R [out dir]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(DBI); library(RSQLite) })
a <- commandArgs(TRUE); out <- if (length(a)) a[1] else "F:/lucasCore/dev/figures/out-fire"
source("F:/lucasCore/src/figures.R")
lib <- "F:/lucasCore/dev/libs/LUCAS P26 Demo Library.ssim"; d17 <- file.path(paste0(lib, ".data"), "Scenario-17")
grid <- rast(file.path(paste0(lib, ".data"), "Scenario-2", "stsim_InitialConditionsSpatial", "StateClass.tif"))
con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); dem <- dbGetQuery(con, "SELECT ElevationFile FROM lucasCore_DataSource")$ElevationFile[1]
sched <- as.data.table(dbGetQuery(con, "SELECT Timestep, HistoricalYear FROM lucasCore_OutputProjectionSchedule WHERE ScenarioId = 17 AND SamplingSet = 'Fire' AND Iteration = 1"))
dbDisconnect(con)
K <- figure_kit(grid, dem, out, "P26 Northern Sierra Nevada; Projection Setup result 17 (fire method 2: FSim burn probability), 150 m grid.")
use_kit(K, environment())

fm <- file.path(d17, "stsim_TransitionSpatialMultiplier", sprintf("Projection-Fire_%d.tif", sort(unique(sched$HistoricalYear))))
yrs <- sort(unique(sched$HistoricalYear)); km <- sapply(fm, function(f) sum(values(rast(f), mat = FALSE), na.rm = TRUE) * prod(res(grid)) / 1e6)
names(km) <- yrs; q <- yrs[km > 50]; pick <- c(q[which.min(km[km > 50])], yrs[which.min(abs(km - median(km)))], yrs[which.max(km)])   # quietest year that burned > 50 km2, median, largest
cat("expected burned area by drawn year (km2):\n"); print(round(km))
brk <- c(0, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, Inf); lab <- c("<0.5%", "0.5-1%", "1-2%", "2-5%", "5-10%", "10-20%", ">20%")
cols <- colorRampPalette(c("#fde7b0", "#f0a03a", "#c93a1d", "#5c0f14"))(length(lab))
used <- function(y) paste(sched[HistoricalYear == y, Timestep], collapse = ", ")
P <- lapply(pick, function(y) { v <- cv(rast(fm[yrs == y])); k <- ifelse(is.na(v) | v <= 0, NA, findInterval(v, brk, left.open = TRUE))
  list(k = k, cols = cols, lab = lab, key = TRUE, title = sprintf("Fire multiplier, drawn year %d", y),
       sub = sprintf("%.0f km2 expected; used in %s", km[as.character(y)], used(y))) })
ig <- cv(rast(file.path(d17, "stsim_TransitionSpatialInitiationMultiplier", "Projection-Fire-Ignition.tif")))
ib <- c(0, 0.25, 0.5, 1, 2, 3, Inf); il <- c("<0.25", "0.25-0.5", "0.5-1", "1-2", "2-3", ">3")
P <- c(list(list(k = ifelse(is.na(ig) | ig <= 0, NA, findInterval(ig, ib, left.open = TRUE)), cols = colorRampPalette(c("#e8eef5", "#7aa6c8", "#1f4e79"))(length(il)), lab = il,
                 key = TRUE, title = "Ignition multiplier", sub = "the burn probability, mean 1 in the pyrome")), P)
map_figure("projection_fire_inputs", "Projected fire inputs", P,
  sprintf("(a) Where fires start: the FSim burn probability as an ST-Sim spatial initiation multiplier, scaled to mean 1 across the pyrome. (b-d) Each cell's chance of burning in a year: the drawn historical year's burned share of the pyrome, spread by the burn probability, for a quiet (%d), a typical (%d) and the largest (%d) of the %d fire years drawn for 2024-2050. Grey: not burnable.%s",
          pick[1], pick[2], pick[3], length(yrs), if (dem_ok) " Shaded relief from the elevation data source." else ""))
cat("done:", out, "\n")
