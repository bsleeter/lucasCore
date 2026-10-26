# =============================================================================
# 03-dead-by-age.R - where lucasCore's dead pools part from FIA: standing dead, down dead and litter by stand age band, per forest type,
# in the run's starting stocks (1985) and in 2020, against FIA plots in P26's counties
# =============================================================================
# FIA: the USGS condition table (the calibration target; down dead as in it), latest visit per plot-condition from 2001, stand age
# bands of stage 3's calibration (calibrate.R CAL_BANDS). lucasCore: result 14's average stock maps, pooled as stage 3 matches them to
# FIA (src/dom.R FIA_DOM: standing = Snag Stem + Snag Branch; down = AG Medium + AG Fast; litter = AG Very Fast + AG Slow; the LUCAS stock
# groups differ: DOM: Down Deadwood holds BG Fast, DOM: Litter holds AG Fast, AG Slow is in DOM: Soil) and its age and state class maps in 1985 and 2020. Mg C/ha.
# Writes dev/nfcms/out/dead-by-age.csv. Read-only.
# Usage: Rscript dev/nfcms/03-dead-by-age.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(DBI) })
lib <- "F:/lucasCore/dev/libs/LUCAS P26 Demo Library.ssim"; dd <- paste0(lib, ".data"); out <- "F:/lucasCore/dev/nfcms/out"; rid <- 14L
BANDS <- c(0, 10, 20, 40, 60, 80, 100, 150, 300)
TYPES <- c(370, 260, 240, 220, 920)   # California Mixed Conifer, Fir/Spruce/Mountain Hemlock, Lodgepole, Ponderosa, Western Oak (state class = FIA group)
con <- dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO)
q <- function(s) as.data.table(dbGetQuery(con, s))
avg <- q(sprintf("SELECT g.Name, o.Timestep, o.Filename FROM stsim_OutputAverageSpatialStockGroup o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId WHERE o.ScenarioId = %d AND o.Timestep IN (1985, 2020)", rid))
agf <- q(sprintf("SELECT Timestep, Filename FROM stsim_OutputSpatialAge WHERE ScenarioId = %d AND Iteration = 1 AND Timestep IN (1985, 2020)", rid))
scf <- q(sprintf("SELECT Timestep, Filename FROM stsim_OutputSpatialState WHERE ScenarioId = %d AND Iteration = 1 AND Timestep IN (1985, 2020)", rid))
scl <- q("SELECT Id, Name FROM stsim_StateClass"); cty <- q("SELECT DISTINCT SecondaryStratumId FROM stsim_OutputStratumState WHERE ScenarioId = 14"); ssn <- q("SELECT SecondaryStratumId, Id FROM stsim_SecondaryStratum")
dbDisconnect(con)
fips <- ssn[SecondaryStratumId %in% cty$SecondaryStratumId, Id] %% 1e5
fp <- function(f) list.files(file.path(dd, sprintf("Scenario-%d", rid)), paste0("^", gsub("[.]", "[.]", basename(f)), "$"), recursive = TRUE, full.names = TRUE)[1]
lucas <- rbindlist(lapply(c(1985L, 2020L), function(y) {
  g <- function(nm) Reduce(`+`, lapply(avg[Timestep == y & Name %in% nm, Filename], function(x) rast(fp(x))))
  st <- g(c("DOM: Snag Stem [Type]", "DOM: Snag Branch [Type]"))
  v <- data.table(sc = values(rast(fp(scf[Timestep == y, Filename])), mat = FALSE), age = values(rast(fp(agf[Timestep == y, Filename])), mat = FALSE),
                  standing = values(st, mat = FALSE), down = values(g(c("DOM: Aboveground Medium [Type]", "DOM: Aboveground Fast [Type]")), mat = FALSE),
                  litter = values(g(c("DOM: Aboveground Very Fast [Type]", "DOM: Aboveground Slow [Type]")), mat = FALSE))
  v[sc %in% TYPES][, band := cut(age, BANDS)][!is.na(band), .(source = sprintf("lucas %d", y), n = .N, standing = mean(standing), down = mean(down), litter = mean(litter)), by = .(sc, band)] }))
f <- 2.2417
x <- as.data.table(readRDS("F:/lucas-master/Data Sources/FIA/USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds"))[(statecd * 1000 + countycd) %in% fips & invyr >= 2001 & invyr < 9999 & fortyp_grp %in% TYPES & !is.na(stdage)]
x[, pid := paste(statecd, unitcd, countycd, plot)]; setorder(x, pid, condid, -invyr); x <- x[!duplicated(paste(pid, condid))]
fia <- x[, band := cut(stdage, BANDS)][!is.na(band), .(source = "FIA", n = .N, standing = mean(c_ag_standing_dead_trees_short_tons_per_acre * f), down = mean(c_down_dead_tons_per_acre * f),
                                                     litter = mean(c_litter_tons_per_acre * f)), by = .(sc = fortyp_grp, band)]
d <- rbind(fia, lucas); d[, type := sub("Forest: ", "", scl$Name[match(sc, scl$Id)])]
w <- dcast(d, type + band ~ source, value.var = c("standing", "down", "litter", "n"))
setcolorder(w, c("type", "band", grep("^n_", names(w), value = TRUE)))
w <- w[order(type, band)]; for (k in names(w)[sapply(w, is.numeric)]) w[, (k) := round(get(k), 1)]
fwrite(w, file.path(out, "dead-by-age.csv")); options(width = 250)
for (p in c("standing", "down", "litter")) { cat(sprintf("\n%s (Mg C/ha) by stand age band:\n", p)); print(w[, c("type", "band", "n_FIA", grep(paste0("^", p, "_"), names(w), value = TRUE)), with = FALSE]) }
# area-weighted totals per type: what the age mix contributes
tt <- d[, .(n = sum(n), standing = sum(n * standing) / sum(n), down = sum(n * down) / sum(n), litter = sum(n * litter) / sum(n)), by = .(type, source)]
cat("\nAll ages (weighted by plots or cells):\n"); print(dcast(tt, type ~ source, value.var = c("standing", "down", "litter"))[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 1) else z)])
am <- d[, .(mean_age_band = weighted.mean(as.integer(band), n)), by = .(type, source)]
cat("\nAge mix (share of plots or cells per band):\n"); print(dcast(d[, .(band, share = round(100 * n / sum(n))), by = .(type, source)], type + source ~ band, value.var = "share", fill = 0))
