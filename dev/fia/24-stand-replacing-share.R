# =============================================================================
# 24-stand-replacing-share.R - to-do 32: how much of FIA's non-fire mortality comes from stand-replacing events
# =============================================================================
# Design question (user, 2026-10-30): fit stem turnover (option A) to all non-fire mortality, or to the background without
# stand-replacing losses, so a later insect/disease event layer (option B) adds only the stand-replacing events without counting the
# same deaths twice. Per remeasured mature condition (as 23-stem-mortality.R: 11 western states, stand age >= 60, trees alive at the
# previous visit, cut trees left out, fire-killed apart): the share of its live aboveground carbon that died (non-fire) in the period;
# stand-replacing at >= 50% or >= 70%. Per cell: the share of its mortality carbon in stand-replacing conditions, the mortality rate
# with and without them, against CBM's stem turnover and the snag ratio. Writes dev/fia/out-z7/stand-replacing-share.csv. Read-only.
# Usage: Rscript dev/fia/24-stand-replacing-share.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; pkg <- "F:/lucasCore"; out <- file.path(pkg, "dev/fia/out-z7")
ST <- c("AZ", "CA", "CO", "ID", "MT", "NM", "NV", "OR", "UT", "WA", "WY")
cc <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[, .(PLT_CN = plt_cn, CONDID = as.integer(condid), ecodiv, fortyp_grp = as.integer(fortyp_grp), stdage = as.numeric(stdage))]
m <- rbindlist(lapply(ST, function(s) {
  pl <- fread(file.path(dm, sprintf("%s_PLOT.csv", s)), select = c("CN", "REMPER"), colClasses = list(character = "CN"))
  t <- fread(file.path(dm, sprintf("%s_TREE.csv", s)), select = c("CN", "PREV_TRE_CN", "PLT_CN", "CONDID", "STATUSCD", "PREV_STATUS_CD", "AGENTCD", "CARBON_AG", "TPA_UNADJ"),
             colClasses = list(character = c("CN", "PREV_TRE_CN", "PLT_CN")))
  x <- merge(t[PREV_STATUS_CD %in% 1 & STATUSCD %in% 1:2 & !is.na(PREV_TRE_CN) & nzchar(PREV_TRE_CN)], t[, .(PREV_TRE_CN = CN, c0 = CARBON_AG * TPA_UNADJ)], by = "PREV_TRE_CN")
  x <- merge(x, pl[, .(PLT_CN = CN, REMPER = as.numeric(REMPER))], by = "PLT_CN")[!is.na(c0) & !is.na(REMPER) & REMPER > 0]
  x[, .(live0 = sum(c0), dead = sum(c0[STATUSCD == 2 & !(AGENTCD %/% 10) %in% 3]), fire = sum(c0[STATUSCD == 2 & (AGENTCD %/% 10) %in% 3]),
        insect = sum(c0[STATUSCD == 2 & (AGENTCD %/% 10) %in% 1]), remper = mean(REMPER)), by = .(PLT_CN, CONDID = as.integer(CONDID))] }))
m <- merge(m, cc[stdage >= 60], by = c("PLT_CN", "CONDID"))[live0 > 0]
m[, frac := dead / live0]
cat(sprintf("%d remeasured mature conditions; median remeasurement %.1f yr; non-fire loss >= 50%%: %.1f%% of conditions, >= 70%%: %.1f%%\n",
            nrow(m), median(m$remper), 100 * mean(m$frac >= 0.5), 100 * mean(m$frac >= 0.7)))
cbx <- fread(file.path(pkg, "defaults/carbon-assumptions/fia-measured/cbm-crosswalk.csv")); eco <- fread(file.path(pkg, "defaults/cbm/tblEcoBoundaryDefault.csv"))
cbx[, cbm_stem := eco$StemAnnualTurnOverRate[match(CbmEcozoneId, eco$EcoBoundaryName)]]
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv"))[, StateClass := paste0("Forest: ", StateClassName)]
rate <- function(d) sum(d$dead / d$remper) / sum(d$live0)
r <- m[, .(conds = .N, all = rate(.SD), bg50 = rate(.SD[frac < 0.5]), bg70 = rate(.SD[frac < 0.7]),
           sr50 = sum(dead[frac >= 0.5]) / sum(dead), sr70 = sum(dead[frac >= 0.7]) / sum(dead), n50 = sum(frac >= 0.5),
           insect_sr50 = sum(insect[frac >= 0.5]) / pmax(sum(dead[frac >= 0.5]), 1e-9)), by = .(ecodiv, fortyp_grp)]
r[, StateClassId := cw$StateClass[match(fortyp_grp, cw$StateClassId)]][, cbm_stem := cbx$cbm_stem[match(StateClassId, cbx$StateClassId)]]
cm <- fread(file.path(out, "mature-vs-measured.csv"))[, .(ecodiv, fortyp_grp = as.integer(sc), cell = paste(StratumId, sub("Forest: ", "", StateClassId)), snag_r = standing_model / standing)]
d <- merge(r, cm, by = c("ecodiv", "fortyp_grp"))[conds >= 30]
fwrite(d, file.path(out, "stand-replacing-share.csv"))
options(width = 220)
w <- function(v) round(weighted.mean(v, d$conds[d$snag_r < 0.8 | TRUE]), 4)
cat("\nBy whether the model's snags fall short (< 0.8 x measured); rates per year of live aboveground carbon, weighted by conditions:\n")
print(d[, .(cells = .N, conds = sum(conds), cbm_stem = round(weighted.mean(cbm_stem, conds), 4), all = round(weighted.mean(all, conds), 4),
            bg_lt50 = round(weighted.mean(bg50, conds), 4), bg_lt70 = round(weighted.mean(bg70, conds), 4),
            sr_share50 = round(weighted.mean(sr50, conds), 2), sr_share70 = round(weighted.mean(sr70, conds), 2)), by = .(short = snag_r < 0.8)])
cat("\nCells, most conditions first (sr_share: share of the cell's non-fire mortality carbon in conditions that lost >= 50% / >= 70%):\n")
print(d[order(-conds)][1:min(.N, 30), .(cell = substr(cell, 1, 52), conds, n50, cbm = cbm_stem, all = round(all, 4), bg50 = round(bg50, 4), x_all = round(all / cbm_stem, 1),
                                         x_bg50 = round(bg50 / cbm_stem, 1), sr50 = round(sr50, 2), sr70 = round(sr70, 2), insect_sr = round(insect_sr50, 2), snag_r = round(snag_r, 2))])
