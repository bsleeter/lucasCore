# Experiment 17: calibrate DOM decay. Snags, down wood and forest floor to FIA (by age band); soil to gSSURGO (user 2026-10-20: FIA soil
# carbon is not reliable). Parameters per cell (>= 200 FIA plots) or per forest type: decay multipliers for snag, cwd, floor (log scale,
# 0.05-20) and the share of stands whose last disturbance was a clearcut (else high-severity fire); then the soil multiplier so that the
# belowground pools, averaged over the disturbance cycle, match the cell's mean gSSURGO carbon.
suppressPackageStartupMessages({ library(data.table); library(parallel); library(terra) })
for (f in c("growth.R", "flows.R", "dom.R")) source(file.path("F:/lucasCore/src", f))
cbm <- "F:/lucasCore/defaults/cbm"; sfd <- "F:/lucasCore/defaults/stockflow"; out_dir <- "F:/lucasCore/dev/growth"
cc <- fread("F:/lucasCore/dev/libs/carbon-curves.csv"); cw <- fread("F:/lucasCore/defaults/growth/forest-type-crosswalk.csv", colClasses = "character")
dens <- fread("F:/lucasCore/defaults/growth/merch-carbon-density.csv", colClasses = "character")
fo <- fread(file.path(sfd, "stsim_FlowOrder.csv")); ev <- fread(file.path(sfd, "event-pathways.csv"), na.strings = "")
clim <- fread(file.path(out_dir, "out_ecodiv_climate.csv"), colClasses = c(ecodiv = "character"))
codes <- fread("F:/lucas-master/Data Sources/FIA/EcoDivision_Strata.csv", colClasses = "character")[!duplicated(ecodiv)]
st <- fread("F:/lucasCore/defaults/stsim/stsim_Stratum.csv")
codes[, Stratum := st$Name[match(as.integer(StratumId), st$Id)]]
ri_tab <- fread("F:/lucasCore/defaults/spinup/return-interval.csv")

# ---- soil targets: mean gSSURGO carbon (Mg C/ha; zeros are unmapped) per ecodivision x forest type on the CONUS 1km grid ----
tgt_file <- file.path(out_dir, "out_soil_targets.csv")
if (!file.exists(tgt_file)) {
  ic <- "F:/lucas-master/Models/CONUS 1km/Data/Initial Conditions/"; P <- rast(paste0(ic, "PrimaryStrata.tif")); Fz <- rast(paste0(ic, "ForestTypeGroupFilled.tif"))
  s <- rast("F:/lucas-master/Data Sources/gSSURGO/gssurgo_soc_0_999.tif"); NAflag(s) <- 0
  s1 <- project(s, P, method = "average") * 0.01
  z <- data.table(P = values(P, mat = FALSE), F = values(Fz, mat = FALSE), soc = values(s1, mat = FALSE))[!is.na(P) & !is.na(F) & !is.na(soc) & soc > 0]
  t <- z[, .(soil_target = mean(soc), cells_1km = .N), by = .(StratumId = P, sc = F)]
  t[, Stratum := st$Name[match(StratumId, st$Id)]]; fwrite(t, tgt_file) }
soil_t <- fread(tgt_file); soil_t[, sc := as.character(sc)]

# ---- FIA dead carbon (latest visit, undisturbed, untreated) ----
D <- "F:/lucas-master/Data Sources/FIA/"
x <- as.data.table(readRDS(paste0(D, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds")))
x <- merge(x, as.data.table(readRDS(paste0(D, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds"))), by = c("plt_cn", "condid"))
x <- x[dstrbcd1 %in% 0 & trtcd1 %in% 0 & !is.na(stdage) & stdage >= 1 & stdage <= 300 & invyr >= 1997]
x[, pid := sprintf("%02d-%d-%03d-%05d", statecd, unitcd, countycd, plot)]; setorder(x, pid, condid, -invyr); x <- x[!duplicated(paste(pid, condid))]
f <- 2.2417; x[, `:=`(standing_dead = c_ag_standing_dead_trees_short_tons_per_acre * f, down_dead = c_down_dead_tons_per_acre * f, litter = c_litter_tons_per_acre * f, ecodiv = as.character(ecodiv))]
# each state class uses the plots of its own FIA group set (201 shares 200's plots; 240 uses all western softwoods, as its curves do)
g2sc <- cw[, .(fortyp_grp = as.integer(unlist(strsplit(FiaTypeGroups, ";")))), by = StateClassId]
x <- merge(x, g2sc, by = "fortyp_grp", allow.cartesian = TRUE); setnames(x, "StateClassId", "sc")
BANDS <- c(0, 10, 20, 40, 60, 80, 100, 150, 300); FIA3 <- c("standing_dead", "down_dead", "litter")
x[, band := cut(stdage, BANDS)]
obs <- x[, .(n = .N, standing_dead = mean(standing_dead), down_dead = mean(down_dead), litter = mean(litter)), by = .(sc, ecodiv, band)]
ages <- x[, .N, by = .(sc, ecodiv, band, stdage)]

# ---- the cells ----
cells <- unique(cc[, .(Stratum = StratumId, StateClass = StateClassId)])
cells[, sc := cw$StateClassId[match(sub("^Forest: ", "", StateClass), cw$StateClassName)]][, ecodiv := codes$ecodiv[match(Stratum, codes$Stratum)]]
cells[, ri := as.numeric(ri_tab$ReturnInterval)[match(paste(Stratum, StateClass), paste(ri_tab$Stratum, ri_tab$StateClass))]]
cells[is.na(ri), ri := ri_tab[StateClass == .BY$StateClass, as.numeric(median(ReturnInterval))], by = StateClass]
cells[is.na(ri), ri := median(ri_tab$ReturnInterval)]
cells[, ri := as.integer(round(ri))]
cells[, plots := obs[, .(n = sum(n)), by = .(sc, ecodiv)][cells, on = c("sc", "ecodiv"), n]][is.na(plots), plots := 0L]
cells[, soil_target := soil_t[cells, on = c("Stratum", sc = "sc"), soil_target]]
cat(nrow(cells), "cells;", cells[plots >= 200, .N], "with >= 200 FIA plots;", cells[!is.na(soil_target), .N], "with a gSSURGO target\n")

# per-cell model pieces
setup <- function(i) { k <- cells[i]; w <- cw[StateClassId == k$sc]; sw <- grepl("Softwood$", w$LagClass)
  live <- as.matrix(cc[StratumId == k$Stratum & StateClassId == k$StateClass][order(Age), names(LIVE_POOLS), with = FALSE])
  r <- turnover_rates(k$StateClass, sw, as.numeric(dens[StateClassId == k$sc, DeciduousShare]), cbm)
  list(k = k, live = live, vals = dom_flow_values(r, sw, clim[ecodiv == k$ecodiv, mat], cbm),
       hist = disturbance_matrices(ev, "Fire: High Severity [Type]", k$StateClass, k$ri),
       harv = disturbance_matrices(ev, "Forest Harvest: Forest Clearcut [Type]", k$StateClass, k$ri)) }
simulate <- function(S, mult, w_harv) { m <- dom_matrices(S$vals, fo, mult)
  (1 - w_harv) * fia_dom_sums(dom_by_age(m, S$live, S$k$ri, S$hist, S$hist)) + w_harv * fia_dom_sums(dom_by_age(m, S$live, S$k$ri, S$hist, S$harv)) }
# objective over a set of cells: plot-weighted squared error of band means, each pool scaled by its overall mean
loss <- function(par, SS, OB, AG, scale) { mult <- list(snag = exp(par[1]), cwd = exp(par[2]), floor = exp(par[3]), soil = 1); w <- plogis(par[4])
  tot <- 0
  for (j in seq_along(SS)) { sim <- simulate(SS[[j]], mult, w); ob <- OB[[j]]; ag <- AG[[j]]
    pr <- ag[, lapply(setNames(FIA3, FIA3), function(p) sum(N * sim[stdage + 1, p]) / sum(N)), by = band]
    m <- merge(ob, pr, by = "band", suffixes = c("", "_sim"))
    for (p in FIA3) tot <- tot + sum(m$n * ((m[[paste0(p, "_sim")]] - m[[p]]) / scale[[p]])^2) }
  tot }
fit_set <- function(idx) { SS <- lapply(idx, setup); OB <- lapply(idx, function(i) obs[sc == cells$sc[i] & ecodiv == cells$ecodiv[i]])
  AG <- lapply(idx, function(i) ages[sc == cells$sc[i] & ecodiv == cells$ecodiv[i]]); keep <- sapply(OB, nrow) > 0
  SS <- SS[keep]; OB <- OB[keep]; AG <- AG[keep]
  scale <- sapply(FIA3, function(p) weighted.mean(rbindlist(OB)[[p]], rbindlist(OB)$n))
  l0 <- loss(c(0, 0, 0, 0), SS, OB, AG, scale)
  o <- optim(c(0, 0, 0, 0), loss, SS = SS, OB = OB, AG = AG, scale = scale, method = "L-BFGS-B", lower = c(rep(log(0.05), 3), -6), upper = c(rep(log(20), 3), 6), control = list(maxit = 300))
  list(par = o$par, loss0 = l0, loss1 = o$value, n = sum(sapply(OB, function(z) sum(z$n)))) }
# soil: one multiplier so the cycle-averaged belowground carbon matches gSSURGO
fit_soil <- function(i, mult, w) { S <- setup(i); tgt <- cells$soil_target[i]; if (is.na(tgt)) return(NA_real_)
  bg <- function(ms) { mm <- modifyList(mult, list(soil = ms)); m <- dom_matrices(S$vals, fo, mm)
    d <- (1 - w) * dom_by_age(m, S$live, S$k$ri, S$hist, S$hist) + w * dom_by_age(m, S$live, S$k$ri, S$hist, S$harv)
    mean(rowSums(d[1:min(S$k$ri, nrow(d)), c("BGVF", "BGF", "BGS"), drop = FALSE])) }
  r <- tryCatch(uniroot(function(lm) log(bg(exp(lm))) - log(tgt), c(log(0.02), log(50)))$root, error = function(e) NA_real_)
  exp(r) }

cl <- makeCluster(min(30, detectCores() - 2))
clusterExport(cl, ls()); invisible(clusterEvalQ(cl, { library(data.table) }))
t0 <- Sys.time()
own <- which(cells$plots >= 200); types <- unique(cells$sc)
fits_cell <- parLapply(cl, own, fit_set); names(fits_cell) <- own
fits_type <- parLapply(cl, types, function(s) { idx <- which(cells$sc == s & cells$plots > 0); if (!length(idx)) return(NULL); fit_set(idx) }); names(fits_type) <- types
cat(sprintf("FIA fits: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
pick <- function(i) { f <- if (as.character(i) %in% names(fits_cell)) fits_cell[[as.character(i)]] else fits_type[[cells$sc[i]]]
  if (is.null(f)) c(0, 0, 0, 0, NA) else c(f$par, if (as.character(i) %in% names(fits_cell)) 1 else 2) }
P <- t(sapply(seq_len(nrow(cells)), pick))
cells[, `:=`(m_snag = exp(P[, 1]), m_cwd = exp(P[, 2]), m_floor = exp(P[, 3]), w_harvest = plogis(P[, 4]), level = c("cell", "type")[P[, 5]])]
clusterExport(cl, "cells")
cells[, m_soil := unlist(parLapply(cl, seq_len(nrow(cells)), function(i) fit_soil(i, list(snag = cells$m_snag[i], cwd = cells$m_cwd[i], floor = cells$m_floor[i], soil = 1), cells$w_harvest[i])))]
stopCluster(cl)
cat(sprintf("total %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
fwrite(cells, file.path(out_dir, "out_exp17_calibration.csv"))
print(cells[, .(cells = .N, m_snag = round(median(m_snag), 2), m_cwd = round(median(m_cwd), 2), m_floor = round(median(m_floor), 2), m_soil = round(median(m_soil, na.rm = TRUE), 2),
                w_harvest = round(median(w_harvest), 2), soil_unfit = sum(is.na(m_soil))), by = level])
cat("\nloss reduction (FIA pools), cell fits:", round(median(sapply(fits_cell, function(f) 1 - f$loss1 / f$loss0)), 3), " type fits:",
    round(median(sapply(Filter(Negate(is.null), fits_type), function(f) 1 - f$loss1 / f$loss0)), 3), "\n")
# ---- fit by pool and age band, CBM default decay vs calibrated (every cell with plots, plot-weighted) ----
ev_cell <- function(i, calibrated) { S <- setup(i); k <- cells[i]
  mult <- if (calibrated) list(snag = k$m_snag, cwd = k$m_cwd, floor = k$m_floor, soil = 1) else NULL
  sim <- simulate(S, mult, if (calibrated) k$w_harvest else 0.5); ag <- ages[sc == k$sc & ecodiv == k$ecodiv]
  if (!nrow(ag)) return(NULL)
  ag[, lapply(setNames(FIA3, FIA3), function(p) sum(N * sim[stdage + 1, p])), by = band][, `:=`(sc = k$sc, ecodiv = k$ecodiv)] }
cl <- makeCluster(min(30, detectCores() - 2)); clusterExport(cl, ls()); invisible(clusterEvalQ(cl, library(data.table)))
withp <- which(cells$plots > 0)
sim0 <- rbindlist(parLapply(cl, withp, ev_cell, calibrated = FALSE)); sim1 <- rbindlist(parLapply(cl, withp, ev_cell, calibrated = TRUE)); stopCluster(cl)
ob <- obs[, .(n = sum(n), standing_dead = sum(standing_dead * n), down_dead = sum(down_dead * n), litter = sum(litter * n)), by = band]
s0 <- sim0[, lapply(.SD, sum), by = band, .SDcols = FIA3]; s1 <- sim1[, lapply(.SD, sum), by = band, .SDcols = FIA3]
r <- data.table(band = ob$band, plots = ob$n)
for (p in FIA3) r[, (p) := sprintf("%.1f | %.1f | %.1f", ob[[p]] / ob$n, s0[[p]][match(ob$band, s0$band)] / ob$n, s1[[p]][match(ob$band, s1$band)] / ob$n)]
cat("
FIA | CBM default decay | calibrated (Mg C/ha)
"); print(r[order(band)])

