# =============================================================================
# 01-p26-2020.R - validation: the P26 historical run's 2020 carbon (result 14) against NFCMS v3.0's 2020 carbon (RDS-2025-0019, PSW)
# =============================================================================
# NFCMS 3.0 (Hasler and Williams 2025): 30 m, Mg CO2e per acre (-> Mg C/ha: x 2.471 / 3.667), nodata 65535, forest pixels only.
# Pools matched to lucasCore stock groups:
#   LiveBiomass (above + below ground, leaves, fine roots)  Biomass: Total
#   AbovegroundBiomass (live woody, no leaves)              Biomass: Merchantable [Type] + Biomass: Other Wood [Type]
#   SoilCarbon (organic and mineral layers)                 DOM: Soil
#   TotalEcosystemCarbon (all live and dead pools)          Total Ecosystem
# The run's 2020 average stock maps (Mg C/ha, 150 m) and its 2020 state class map; NFCMS averaged over each 150 m cell's forest
# pixels, with its forest share. Compared on cells forest in both (run's 2020 state class 100-999 and NFCMS forest share >= 50%), in
# total, per forest state class and per county, and cell by cell. Writes dev/nfcms/out/ (CSVs, difference rasters). Read-only.
# Usage: Rscript dev/nfcms/01-p26-2020.R [run result id, default 14] [year, default 2020]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(DBI) })
a <- commandArgs(TRUE); rid <- if (length(a) >= 1) as.integer(a[1]) else 14L; yr <- if (length(a) >= 2) as.integer(a[2]) else 2020L
lib <- "F:/lucasCore/dev/libs/LUCAS P26 Demo Library.ssim"; dd <- paste0(lib, ".data"); nf <- "F:/lucas-master/Data Sources/NFCMS/v3/Data/PSW"
out <- "F:/lucasCore/dev/nfcms/out"; dir.create(out, showWarnings = FALSE, recursive = TRUE); t0 <- Sys.time()
con <- dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO)
avg <- as.data.table(dbGetQuery(con, sprintf("SELECT g.Name, o.Filename FROM stsim_OutputAverageSpatialStockGroup o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId
                                             WHERE o.ScenarioId = %d AND o.Timestep = %d", rid, yr)))
scf <- dbGetQuery(con, sprintf("SELECT Filename FROM stsim_OutputSpatialState WHERE ScenarioId = %d AND Timestep = %d AND Iteration = 1", rid, yr))$Filename
scl <- as.data.table(dbGetQuery(con, "SELECT Id, Name FROM stsim_StateClass"))
ss <- as.data.table(dbGetQuery(con, "SELECT SecondaryStratumId, Id, Name FROM stsim_SecondaryStratum"))
ic <- dbGetQuery(con, "SELECT SecondaryStratumFileName FROM stsim_InitialConditionsSpatial WHERE ScenarioId = 2"); dbDisconnect(con)
fp <- function(f) list.files(file.path(dd, sprintf("Scenario-%d", rid)), paste0("^", gsub("[.]", "[.]", basename(f)), "$"), recursive = TRUE, full.names = TRUE)[1]
grp <- function(nm) { f <- avg[Name %in% nm, Filename]; if (length(f) != length(nm)) stop("missing stock group map: ", paste(setdiff(nm, avg$Name), collapse = ", ")); Reduce(`+`, lapply(f, function(x) rast(fp(x)))) }
L <- list(live = grp("Biomass: Total"), agb = grp(c("Biomass: Merchantable [Type]", "Biomass: Other Wood [Type]")), soil = grp("DOM: Soil"), tec = grp("Total Ecosystem"))
S <- rast(fp(scf)); U <- rast(file.path(dd, "Scenario-2", "stsim_InitialConditionsSpatial", basename(ic$SecondaryStratumFileName)))

# ---- NFCMS on the run's grid -------------------------------------------------------------------------------------------------
win <- as.polygons(ext(S) + 1000, crs = crs(S))
rd <- function(f) { r <- crop(rast(file.path(nf, f)), project(win, crs(rast(file.path(nf, f))))); NAflag(r) <- 65535; r }
fx <- rd("PSW_ForestExtent.tif"); NAflag(fx) <- 255
fshare <- project(classify(fx, cbind(c(0, 1), c(0, 1))), S, method = "average")
conv <- 2.471 / 3.667   # Mg CO2e per acre -> Mg C per ha
N <- lapply(c(live = "PSW_LiveBiomass2020.tif", agb = "PSW_AbovegroundBiomass2020.tif", soil = "PSW_SoilCarbon2020.tif", tec = "PSW_TotalEcosystemCarbon2020.tif"),
            function(f) project(rd(f) * conv, S, method = "average"))   # mean over the cell's forest pixels (non-forest is nodata)
cat(sprintf("NFCMS read and averaged to %g m in %.1f min\n", res(S)[1], as.numeric(Sys.time() - t0, units = "mins")))
for (k in names(N)) writeRaster(c(L[[k]], N[[k]], L[[k]] - N[[k]]), file.path(out, sprintf("%s-%d-lucas-nfcms-diff.tif", k, yr)), overwrite = TRUE, names = c("lucas", "nfcms", "diff"))

# ---- compare ---------------------------------------------------------------------------------------------------------------------
v <- data.table(sc = values(S, mat = FALSE), unit = values(U, mat = FALSE), fsh = values(fshare, mat = FALSE))
for (k in names(L)) { v[, (paste0(k, "_l")) := values(L[[k]], mat = FALSE)]; v[, (paste0(k, "_n")) := values(N[[k]], mat = FALSE)] }
ha <- prod(res(S)) / 1e4
v[, lucas_forest := !is.na(sc) & sc >= 100 & sc <= 999]; v[, nfcms_forest := !is.na(fsh) & fsh >= 0.5]
cat(sprintf("\nForest area %d: lucasCore state classes %.0f km2; NFCMS forest pixels %.0f km2 (cells >= 50%% forest: %.0f km2); both %.0f km2\n", yr,
            sum(v$lucas_forest) * ha / 100, sum(v$fsh, na.rm = TRUE) * ha / 100, sum(v$nfcms_forest) * ha / 100, sum(v$lucas_forest & v$nfcms_forest) * ha / 100))
b <- v[lucas_forest & nfcms_forest & !is.na(tec_n)]
pools <- c(live = "Live biomass", agb = "Aboveground woody", soil = "Soil", tec = "Total ecosystem")
tot <- rbindlist(lapply(names(pools), function(k) { l <- b[[paste0(k, "_l")]]; n <- b[[paste0(k, "_n")]]; ok <- !is.na(l) & !is.na(n)
  data.table(pool = pools[[k]], lucas_Tg = round(sum(l[ok]) * ha / 1e6, 1), nfcms_Tg = round(sum(n[ok]) * ha / 1e6, 1), ratio = round(sum(l[ok]) / sum(n[ok]), 3),
             lucas_MgC_ha = round(mean(l[ok]), 1), nfcms_MgC_ha = round(mean(n[ok]), 1), r_cells = round(cor(l[ok], n[ok]), 2)) }))
cat(sprintf("\nCells forest in both (%d cells, %.0f km2), %d:\n", nrow(b), nrow(b) * ha / 100, yr)); print(tot); fwrite(tot, file.path(out, sprintf("totals-%d.csv", yr)))
bt <- b[, .(km2 = round(.N * ha / 100), live_l = round(mean(live_l), 1), live_n = round(mean(live_n, na.rm = TRUE), 1), tec_l = round(mean(tec_l), 1), tec_n = round(mean(tec_n), 1),
            soil_l = round(mean(soil_l), 1), soil_n = round(mean(soil_n, na.rm = TRUE), 1)), by = sc][, StateClass := scl$Name[match(sc, scl$Id)]][order(-km2)]
cat("\nBy the run's forest state class (mean Mg C/ha):\n"); print(bt[km2 >= 50, .(StateClass, km2, live_l, live_n, soil_l, soil_n, tec_l, tec_n)]); fwrite(bt, file.path(out, sprintf("by-type-%d.csv", yr)))
bu <- b[, .(km2 = round(.N * ha / 100), live_ratio = round(sum(live_l) / sum(live_n, na.rm = TRUE), 2), tec_ratio = round(sum(tec_l) / sum(tec_n), 2), tec_l = round(mean(tec_l), 1), tec_n = round(mean(tec_n), 1)), by = unit][
  , County := sub("^[^:]*: ", "", ss$Name[match(unit, ss$Id)])][order(-km2)]
cat("\nBy county (secondary strata):\n"); print(bu[, .(County, km2, live_ratio, tec_ratio, tec_l, tec_n)]); fwrite(bu, file.path(out, sprintf("by-county-%d.csv", yr)))
cat(sprintf("\n%.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
