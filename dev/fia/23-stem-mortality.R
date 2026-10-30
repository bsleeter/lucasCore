# =============================================================================
# 23-stem-mortality.R - to-do 32: FIA's measured tree mortality against CBM's stem turnover, and the snag shortfall
# =============================================================================
# With snag decay near zero, standing snags ~ stem mortality input / fall rate; the fall rate is FIA-measured, so a cell whose snags run
# short is one whose mortality input is too low. The model's input is CBM's stem turnover (StemAnnualTurnOverRate of the type's CBM
# ecozone, defaults/carbon-assumptions/fia-measured/cbm-crosswalk.csv): one rate per forest type, never fitted (to-do 32 / 20).
# FIA: remeasured trees alive at the previous visit (PREV_STATUS_CD 1) in the 11 western states; mortality = aboveground carbon of
# those dead now (STATUSCD 2) at the previous visit, per year of the remeasurement period; rate = mortality / live carbon at the
# previous visit (trees cut since, STATUSCD 3, left out of both); fire-killed (AGENTCD 30-39) shown apart, as the model's fire is.
# Mature conditions (stand age >= 60), as the calibration. Per cell, against the snag ratio of dev/fia/out-z7/mature-vs-measured.csv.
# Writes dev/fia/out-z7/stem-mortality.csv. Read-only.
# Usage: Rscript dev/fia/23-stem-mortality.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; pkg <- "F:/lucasCore"; out <- file.path(pkg, "dev/fia/out-z7")
ST <- c("AZ", "CA", "CO", "ID", "MT", "NM", "NV", "OR", "UT", "WA", "WY")
cc <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[, .(PLT_CN = plt_cn, CONDID = as.integer(condid), ecodiv, fortyp_grp = as.integer(fortyp_grp), stdage = as.numeric(stdage))]
m <- rbindlist(lapply(ST, function(s) {
  pl <- fread(file.path(dm, sprintf("%s_PLOT.csv", s)), select = c("CN", "REMPER"), colClasses = list(character = "CN"))
  t <- fread(file.path(dm, sprintf("%s_TREE.csv", s)), select = c("CN", "PREV_TRE_CN", "PLT_CN", "CONDID", "STATUSCD", "PREV_STATUS_CD", "AGENTCD", "CARBON_AG", "TPA_UNADJ"),
             colClasses = list(character = c("CN", "PREV_TRE_CN", "PLT_CN")))
  prev <- t[, .(PREV_TRE_CN = CN, c0 = CARBON_AG * TPA_UNADJ)]
  x <- merge(t[PREV_STATUS_CD %in% 1 & STATUSCD %in% 1:2 & !is.na(PREV_TRE_CN) & nzchar(PREV_TRE_CN)], prev, by = "PREV_TRE_CN")
  x <- merge(x, pl[, .(PLT_CN = CN, REMPER = as.numeric(REMPER))], by = "PLT_CN")[!is.na(c0) & !is.na(REMPER) & REMPER > 0]
  x[, .(live0 = sum(c0), dead = sum(c0[STATUSCD == 2 & !(AGENTCD %/% 10) %in% 3]), fire = sum(c0[STATUSCD == 2 & (AGENTCD %/% 10) %in% 3]), remper = mean(REMPER)),
    by = .(PLT_CN, CONDID = as.integer(CONDID))] }))
m <- merge(m, cc[stdage >= 60], by = c("PLT_CN", "CONDID"))
r <- m[live0 > 0, .(conds = .N, live0 = sum(live0), mort = sum(dead / remper) / sum(live0), fire = sum(fire / remper) / sum(live0)), by = .(ecodiv, fortyp_grp)]
# CBM's stem turnover of each type (its CBM ecozone in the package crosswalk)
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv")); cbx <- fread(file.path(pkg, "defaults/carbon-assumptions/fia-measured/cbm-crosswalk.csv"))
eco <- fread(file.path(pkg, "defaults/cbm/tblEcoBoundaryDefault.csv"))
cbx[, cbm_stem := eco$StemAnnualTurnOverRate[match(CbmEcozoneId, eco$EcoBoundaryName)]]
names(cw)[1:2]; cw[, StateClass := paste0("Forest: ", get(names(cw)[2]))]
r[, StateClassId := cw$StateClass[match(fortyp_grp, cw[[1]])]][, cbm_stem := cbx$cbm_stem[match(StateClassId, cbx$StateClassId)]]
cm <- fread(file.path(out, "mature-vs-measured.csv"))[, .(ecodiv, fortyp_grp = as.integer(sc), cell = paste(StratumId, sub("Forest: ", "", StateClassId)), n, snag_r = standing_model / standing)]
d <- merge(r, cm, by = c("ecodiv", "fortyp_grp"))[conds >= 30]
d[, ratio := mort / cbm_stem]
fwrite(d, file.path(out, "stem-mortality.csv"))
options(width = 220)
cat(sprintf("%d western cells with >= 30 remeasured mature conditions and snag targets\n", nrow(d)))
cat("\nFIA mortality (non-fire, /yr of live aboveground carbon) vs CBM stem turnover, by whether the model's snags fall short (< 0.8 x measured):\n")
print(d[, .(cells = .N, conds = sum(conds), fia_mort = round(weighted.mean(mort, conds), 4), fia_fire = round(weighted.mean(fire, conds), 4), cbm_stem = round(weighted.mean(cbm_stem, conds), 4),
            fia_over_cbm = round(weighted.mean(ratio, conds), 2)), by = .(short = snag_r < 0.8)])
cat(sprintf("\ncorrelation over cells (weighted by conditions): snag ratio vs FIA mortality / CBM stem turnover %.2f\n", cov.wt(d[, .(snag_r, ratio)], wt = d$conds, cor = TRUE)$cor[1, 2]))
cat("\nCells, most conditions first:\n")
print(d[order(-conds)][1:min(.N, 30), .(cell = substr(cell, 1, 55), conds, fia_mort = round(mort, 4), fia_fire = round(fire, 4), cbm_stem, fia_over_cbm = round(ratio, 2), snag_r = round(snag_r, 2))])
