# =============================================================================
# 18-package-check.R - the package's measured calibration (src/calibrate.R dwm_targets, snag_fall_rates, cal_fit_measured; src/dom.R
# fire_snag_rows; defaults/stockflow/event-pathways.csv) on P26's four main types in M260, against the dev hybrid fit (06 with
# LUCAS_POOLED=hybrid: snags 0.05, down logs 0.85, fine woody debris 2.14; litter 0.31/0.72/0.22/0.28, duff 3.25/7.10/3.16/3.38).
# Usage: Rscript dev/fia/18-package-check.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(DBI) })
pkg <- "F:/lucasCore"; dm <- "F:/lucas-master/Data Sources/FIA/DataMart"
say <- function(...) cat(sprintf(...), "\n"); fail <- function(...) stop(sprintf(...), call. = FALSE)
for (f in c("growth.R", "flows.R", "dom.R", "calibrate.R", "fia.R")) source(file.path(pkg, "src", f))
con <- dbConnect(RSQLite::SQLite(), file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim"), flags = RSQLite::SQLITE_RO); q <- function(s) as.data.table(dbGetQuery(con, s))
scl <- q("SELECT StateClassId, Name, Id FROM stsim_StateClass"); stl <- q("SELECT StratumId, Name FROM stsim_Stratum")
cc <- q("SELECT * FROM lucasCore_CarbonCurve WHERE ScenarioId = 2"); ri5 <- q("SELECT * FROM lucasCore_OutputReturnInterval WHERE ScenarioId = 2")
ds <- q("SELECT PrismFolder, EcodivisionFile FROM lucasCore_DataSource"); dbDisconnect(con)
nm <- function(id, t) t$Name[match(id, t[[1]])]; cc[, `:=`(Stratum = nm(StratumId, stl), StateClass = nm(StateClassId, scl))]
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv")); cw[, StateClass := scl$Name[match(StateClassId, scl$Id)]]
clim <- ecodiv_climate(ds$EcodivisionFile, ds$PrismFolder)
ev <- fread(file.path(pkg, "defaults/stockflow/event-pathways.csv"), colClasses = "character", na.strings = "")
fs <- fread(file.path(pkg, "defaults/spinup/fire-snag-share.csv"))[, StateClass := scl$Name[match(StateClassId, scl$Id)]]
ev <- rbind(ev, fire_snag_rows(ev, fs))
ctx <- list(cc = cc, cw = cw, dens = fread(file.path(pkg, "defaults/growth/merch-carbon-density.csv")), cbm = file.path(pkg, "defaults/cbm"),
            fo = fread(file.path(pkg, "defaults/stockflow/stsim_FlowOrder.csv")), ev = ev)
TY <- c(370L, 260L, 220L, 920L)
cells <- data.table(sc = TY, StateClass = scl$Name[match(TY, scl$Id)], Stratum = "Mediterranean Mountains", ecodiv = "M260", temp = clim$mat[match("M260", clim$ecodiv)])
cells[, ri := as.integer(round(as.numeric(ri5$ReturnInterval[match(paste(Stratum, StateClass), paste(nm(ri5$StratumId, stl), nm(ri5$StateClassId, scl)))])))]
dw <- fia_dead_wood(dm, fia_datamart(dm, ds$EcodivisionFile)); dat <- dwm_targets(dw, cw, 60); fr <- snag_fall_rates(dw, cw)
cells[, snag_fall := fr$cell[cells, on = c("sc", "ecodiv"), rate]]
print(fr$cell[ecodiv == "M260" & sc %in% TY]); print(fr$type[sc %in% TY])
cells[, plots := dat$obs[cells, on = c("sc", "ecodiv"), .(n = sum(n)), by = .EACHI]$n]
print(cells)
t0 <- Sys.time(); m <- cal_fit_measured(cells, ctx, dat); cat(sprintf("fit %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
print(cbind(cells[, .(StateClass)], m[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 3) else v)]))
H <- disturbance_matrices(ev, FIRE_HS, cells$StateClass[1], 100); cat("Mixed Conifer fire, age 100: stem -> snag", H$Dl["SnagStem", "Merchantable"], ", branch -> snag", H$Dl["SnagBranch", "Other"], "\n")
H <- disturbance_matrices(ev, FIRE_HS, cells$StateClass[1], 5); cat("Mixed Conifer fire, age 5: stem -> snag", H$Dl["SnagStem", "Merchantable"], "\n")
