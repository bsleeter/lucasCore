# Experiment 16: the DOM simulator at CBM default decay (PRISM temperature) against FIA dead carbon, a few cells
suppressPackageStartupMessages(library(data.table))
for (f in c("growth.R", "flows.R", "dom.R")) source(file.path("F:/lucasCore/src", f))
cbm <- "F:/lucasCore/defaults/cbm"; sf <- "F:/lucasCore/defaults/stockflow"
cc <- fread("F:/lucasCore/dev/libs/carbon-curves.csv"); cw <- fread("F:/lucasCore/defaults/growth/forest-type-crosswalk.csv", colClasses = "character")
dens <- fread("F:/lucasCore/defaults/growth/merch-carbon-density.csv", colClasses = "character")
fo <- fread(file.path(sf, "stsim_FlowOrder.csv")); ev <- fread(file.path(sf, "event-pathways.csv"), na.strings = "")
clim <- fread("F:/lucasCore/dev/growth/out_ecodiv_climate.csv", colClasses = c(ecodiv = "character"))
codes <- fread("F:/lucas-master/Data Sources/FIA/EcoDivision_Strata.csv", colClasses = "character"); st <- fread("F:/lucasCore/defaults/stsim/stsim_Stratum.csv")
# event flow sums per live pool (should be 1: no live carbon left behind)
for (g in c("Fire: High Severity [Type]", "Forest Harvest: Forest Clearcut [Type]")) {
  s <- ev[TransitionGroupId == g & FromStockTypeId %in% LIVE_POOLS, .(sum = sum(as.numeric(Multiplier))), by = .(FromStockTypeId, FromAgeMin)]; cat(g, ":", paste(sprintf("%s %.3f", s$FromStockTypeId, s$sum), collapse = "; "), "\n") }
D <- "F:/lucas-master/Data Sources/FIA/"
x <- as.data.table(readRDS(paste0(D, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds")))
x <- merge(x, as.data.table(readRDS(paste0(D, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds"))), by = c("plt_cn", "condid"))
x <- x[dstrbcd1 %in% 0 & trtcd1 %in% 0 & !is.na(stdage) & stdage >= 1 & stdage <= 300 & invyr >= 1997]
x[, pid := sprintf("%02d-%d-%03d-%05d", statecd, unitcd, countycd, plot)]; setorder(x, pid, condid, -invyr); x <- x[!duplicated(paste(pid, condid))]
f <- 2.2417; x[, `:=`(standing_dead = c_ag_standing_dead_trees_short_tons_per_acre * f, down_dead = c_down_dead_tons_per_acre * f, litter = c_litter_tons_per_acre * f, soil = c_soil_org_tons_per_acre * f, ecodiv = as.character(ecodiv))]
cells <- data.table(sc = c("500", "200", "160", "800"), ecodiv = c("220", "M240", "230", "210"), ri = c(100, 300, 50, 400))
for (i in seq_len(nrow(cells))) { k <- cw[StateClassId == cells$sc[i]]; scn <- paste0("Forest: ", k$StateClassName); e <- cells$ecodiv[i]
  sname <- st$Name[match(as.integer(codes$StratumId[match(e, codes$ecodiv)]), st$Id)]
  p <- cc[StratumId == sname & StateClassId == scn][order(Age)]; live <- as.matrix(p[, names(LIVE_POOLS), with = FALSE])
  sw <- grepl("Softwood$", k$LagClass); r <- turnover_rates(scn, sw, as.numeric(dens[StateClassId == k$StateClassId, DeciduousShare]), cbm)
  m <- dom_matrices(dom_flow_values(r, sw, clim[ecodiv == e, mat], cbm), fo)
  hist <- disturbance_matrices(ev, "Fire: High Severity [Type]", scn, cells$ri[i]); last_f <- hist; last_h <- disturbance_matrices(ev, "Forest Harvest: Forest Clearcut [Type]", scn, cells$ri[i])
  t0 <- Sys.time(); dm <- 0.5 * fia_dom_sums(dom_by_age(m, live, cells$ri[i], hist, last_f)) + 0.5 * fia_dom_sums(dom_by_age(m, live, cells$ri[i], hist, last_h))
  ms <- as.numeric(Sys.time() - t0, units = "secs") * 1000
  g <- as.integer(strsplit(k$FiaTypeGroups, ";")[[1]]); d <- x[fortyp_grp %in% g & ecodiv == e]
  d[, band := cut(stdage, c(0, 20, 50, 100, 150, 300))]
  ob <- d[, .(plots = .N, standing_dead = mean(standing_dead), down_dead = mean(down_dead), litter = mean(litter), soil = mean(soil), age = round(mean(stdage))), by = band][order(band)]
  ob[, `:=`(sim_standing = dm[age + 1, "standing_dead"], sim_down = dm[age + 1, "down_dead"], sim_litter = dm[age + 1, "litter"], sim_soil = dm[age + 1, "soil"])]
  cat(sprintf("\n== %s, %s (RI %d yr, %.0f ms per cell)\n", k$StateClassName, e, cells$ri[i], ms)); print(ob[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 1) else v)])
}
