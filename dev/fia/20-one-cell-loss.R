# =============================================================================
# 20-one-cell-loss.R - one test-library cell (M330 Western White Pine, the phaseZ7 cell whose litter and fine woody debris multipliers
# went to 20): its measured mature-stand targets and the model's prediction at CBM rates, at the multipliers steady-state arithmetic
# implies (19-litter-input-sources.R: litter ~1.5x, fine woody debris ~3x) and at 20; and the misfit of each. Read-only.
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(DBI) })
pkg <- "F:/lucasCore"; dm <- "F:/lucas-master/Data Sources/FIA/DataMart"
say <- function(...) invisible(); fail <- function(...) stop(sprintf(...), call. = FALSE)
for (f in c("growth.R", "flows.R", "dom.R", "calibrate.R", "fia.R")) source(file.path(pkg, "src", f))
q <- function(lib, s) { con <- dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO); on.exit(dbDisconnect(con)); as.data.table(dbGetQuery(con, s)) }
tl <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim"); p26 <- file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim")
scl <- q(tl, "SELECT StateClassId, Name, Id FROM stsim_StateClass"); stl <- q(tl, "SELECT StratumId, Name FROM stsim_Stratum")
cc <- q(tl, "SELECT * FROM lucasCore_CarbonCurve WHERE ScenarioId = 47")[, `:=`(Stratum = stl$Name[match(StratumId, stl$StratumId)], StateClass = scl$Name[match(StateClassId, scl$StateClassId)])]
ds <- q(p26, "SELECT PrismFolder, EcodivisionFile FROM lucasCore_DataSource"); clim <- ecodiv_climate(ds$EcodivisionFile, ds$PrismFolder)
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv"))[, StateClass := scl$Name[match(StateClassId, scl$Id)]]
ev <- fread(file.path(pkg, "defaults/stockflow/event-pathways.csv"), colClasses = "character", na.strings = "")
ctx <- list(cc = cc, cw = cw, dens = fread(file.path(pkg, "defaults/growth/merch-carbon-density.csv")), cbm = file.path(pkg, "defaults/cbm"),
            fo = fread(file.path(pkg, "defaults/stockflow/stsim_FlowOrder.csv")), ev = ev)
dw <- readRDS(file.path(dm, "fia-deadwood.rds")); dat <- dwm_targets(dw, cw, 60)
k <- data.table(sc = 240L, StateClass = "Forest: Western White Pine Group", Stratum = "Temperate Steppe Mountains", ecodiv = "M330", temp = clim$mat[match("M330", clim$ecodiv)], ri = 156L, snag_fall = 0.0479)
cat("Live pools at ages 0, 20, 60, 100, 200 (Mg C/ha):\n"); print(cc[Stratum == k$Stratum & StateClass == k$StateClass & Age %in% c(0, 20, 60, 100, 200), .(Age, Merchantable, Other, Foliage, CoarseRoots, FineRoots, TotalLive)])
cat("\nMeasured targets:\n"); print(dat$obs[sc == k$sc & ecodiv == k$ecodiv])
S <- cal_setup(k, ctx)
show <- function(m, lab) { d <- cal_dom(S, ctx$fo, as.list(setNames(m, MEAS_MULT)), 0); sim <- sapply(MEAS_SIM, function(p) rowSums(d[, p, drop = FALSE]))
  cat(sprintf("\n%s  (snag %.2f, logs %.2f, fwd %.2f, litter %.2f, duff %.2f)\n", lab, m[1], m[2], m[3], m[4], m[5]))
  print(round(sim[c(1, 21, 61, 101, 151, 201), ], 2)) }
show(c(1, 1, 1, 1, 1), "CBM rates"); show(c(1, 1, 3, 1.5, 1), "steady-state guess"); show(c(1, 1, 20, 20, 1), "fwd and litter at 20")
