# =============================================================================
# 22-snag-shortfall.R - to-do 32: why the spin-up's mature-stand snags fall short of FIA's in some cells
# =============================================================================
# The measured calibration (tests/phaseZ7-measured-dom.R, dev/fia/out-z7) leaves the model's snags under 80% of the measured standing
# dead in 72 of 193 cells with targets; 14 of them with snag decay already at its lower bound (no decay while standing), mostly the
# interior West mountains (lodgepole, fir/spruce, aspen). Hypothesis: the measured snags hold a pulse of insect-killed trees (the
# 2000s-2010s bark beetle outbreaks) that the spin-up's background mortality (CBM stem turnover) and fire cannot make.
# Test, on the 11 western states' FIA trees in mature conditions (stand age >= 60, as the calibration): each cell's standing dead carbon
# split by cause of death (TREE.AGENTCD: 10 insect, 20 disease, 30 fire, 50 weather, 70 unknown, other), and by measurement period,
# against the cell's model / measured snag ratio. Writes dev/fia/out-z7/snag-agents.csv. Read-only.
# Usage: Rscript dev/fia/22-snag-shortfall.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; out <- "F:/lucasCore/dev/fia/out-z7"; LB <- 0.000453592 * 2.471   # lb/ac -> Mg/ha
ST <- c("AZ", "CA", "CO", "ID", "MT", "NM", "NV", "OR", "UT", "WA", "WY")
cc <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[, .(PLT_CN = plt_cn, CONDID = as.integer(condid), ecodiv, fortyp_grp = as.integer(fortyp_grp), stdage = as.numeric(stdage), invyr)]
tr <- rbindlist(lapply(ST, function(s) {
  x <- fread(file.path(dm, sprintf("%s_TREE.csv", s)), select = c("PLT_CN", "CONDID", "STATUSCD", "STANDING_DEAD_CD", "AGENTCD", "TPA_UNADJ", "CARBON_AG"), colClasses = list(character = "PLT_CN"))
  x[STATUSCD %in% 2 & STANDING_DEAD_CD %in% 1 & !is.na(CARBON_AG) & !is.na(TPA_UNADJ)][, .(c = sum(CARBON_AG * TPA_UNADJ) * LB), by = .(PLT_CN, CONDID = as.integer(CONDID), agent = fcase(
    AGENTCD %/% 10 == 1, "insect", AGENTCD %/% 10 == 2, "disease", AGENTCD %/% 10 == 3, "fire", AGENTCD %/% 10 == 5, "weather", AGENTCD %/% 10 == 7 | is.na(AGENTCD) | AGENTCD == 0, "unknown", default = "other"))] }))
x <- merge(tr, cc[stdage >= 60], by = c("PLT_CN", "CONDID"))
cat(sprintf("%d mature conditions with standing dead in %d states\n", uniqueN(x[, paste(PLT_CN, CONDID)]), length(ST)))
ag <- dcast(x[, .(c = sum(c)), by = .(ecodiv, fortyp_grp, agent)], ecodiv + fortyp_grp ~ agent, value.var = "c", fill = 0)
A <- setdiff(names(ag), c("ecodiv", "fortyp_grp")); ag[, total := rowSums(.SD), .SDcols = A]; for (a in A) set(ag, j = paste0("sh_", a), value = round(ag[[a]] / ag$total, 2))
cm <- fread(file.path(out, "mature-vs-measured.csv"))[, .(ecodiv, fortyp_grp = as.integer(sc), cell = paste(StratumId, sub("Forest: ", "", StateClassId)), n, standing, standing_model)]
cm[, r := standing_model / standing]
d <- merge(cm, ag[, c("ecodiv", "fortyp_grp", grep("^sh_", names(ag), value = TRUE)), with = FALSE], by = c("ecodiv", "fortyp_grp"))
fwrite(d, file.path(out, "snag-agents.csv"))
options(width = 220)
cat("\nWestern cells with targets: snag share by cause of death, short (model < 0.8 x measured) vs not\n")
print(d[, c(list(cells = .N, plots = sum(n)), lapply(.SD, function(v) round(weighted.mean(v, n), 2))), by = .(short = r < 0.8), .SDcols = patterns("^sh_")])
cat("\nShort cells, most plots first\n"); print(d[r < 0.8][order(-n)][, c("cell", "n", "r", grep("^sh_", names(d), value = TRUE)), with = FALSE][1:min(.N, 25)])
cat(sprintf("\ncorrelation over cells (weighted by plots): model/measured vs insect share %.2f\n", cov.wt(d[, .(r, sh_insect)], wt = d$n, cor = TRUE)$cor[1, 2]))
# the pulse: measured standing dead by measurement period in the short interior-West cells
yr <- merge(x, unique(cc[, .(PLT_CN, invyr)]), by = c("PLT_CN"), suffixes = c("", ".y"), allow.cartesian = TRUE)
per <- yr[, .(c = sum(c)), by = .(PLT_CN, CONDID, ecodiv, fortyp_grp, invyr)][, .(standing = mean(c), plots = .N), by = .(ecodiv, fortyp_grp, period = cut(as.numeric(invyr), c(1990, 2005, 2012, 2025), dig.lab = 4))]
sc <- d[r < 0.8 & n >= 100, .(ecodiv, fortyp_grp, cell)]
cat("\nShort cells (>= 100 plots): mean standing dead per condition with any (Mg C/ha) by inventory period\n")
print(dcast(merge(per, sc, by = c("ecodiv", "fortyp_grp")), cell ~ period, value.var = "standing")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 1) else v)])
