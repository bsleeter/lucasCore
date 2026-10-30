# =============================================================================
# calibrate-stem-turnover.R - the package's stem turnover (live stem mortality) from FIA remeasurement (to-do 32, option A)
# =============================================================================
# Run once, up front, like tools/calibrate-harvest-age.R: writes defaults/carbon-assumptions/fia-measured/live-turnover.csv (the Live
# Turnover rows stage 3 uses when a scenario's Live Turnover sheet is empty and the Carbon Method is FIA measured dead wood; Fill on the
# Carbon Method page copies them into the sheet). Only StemTurnover is set; every other rate stays CBM's.
# Why (dev/fia/22-24): the spin-up's mature-stand snags ran short of FIA's in 72 of 193 cells because CBM's stem turnover (one rate per
# type, its CBM ecozone) is 1.5-5x below FIA's measured mortality. Design (user, 2026-10-30): background mortality only - conditions
# that lost >= --stand-replacing (70%) of their live aboveground carbon to non-fire causes in one remeasurement period are left out, so
# a later insect/disease event layer (to-do 32 option B) adds only stand-replacing events without counting the same deaths twice.
# FIA, every DataMart state: trees alive at the previous visit (PREV_STATUS_CD 1) of remeasured conditions with stand age >= --min-age
# (60, as the dead wood calibration's mature stands); mortality = their previous-visit aboveground carbon (CARBON_AG x TPA_UNADJ) if
# dead now (STATUSCD 2) and not fire-killed (AGENTCD 30-39), per year of REMPER; rate = mortality / live carbon at the previous visit
# (trees cut since, STATUSCD 3, left out of both). Per forest type over all ecodivisions with >= --min-conds (30) conditions, and per
# type x ecodivision where that has >= --min-conds; a type with fewer keeps CBM's. A forest type takes its own FIA group's
# conditions first (Western White Pine, which pools other groups for growth, only its own).
# Usage: Rscript tools/calibrate-stem-turnover.R [--dm=<FIA DataMart folder>] [--stand-replacing=0.7] [--min-age=60] [--min-conds=30] [--dry-run]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(sf) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
ds0 <- fread(file.path(pkg, "defaults/library/project/lucasCore_DataSource.csv"))
dm <- opt("dm", ds0$FiaDataMartFolder[1]); SR <- as.numeric(opt("stand-replacing", 0.7)); MIN_AGE <- as.numeric(opt("min-age", 60)); MIN_N <- as.integer(opt("min-conds", 30)); MIN_DIA <- as.numeric(opt("min-dia", 0)); dry <- "--dry-run" %in% a
cf <- file.path(dm, "fia-conditions.rds"); if (!file.exists(cf)) stop("no ", cf, ": run a Build's stage 2 with the FIA DataMart folder first (it caches the conditions)")
cc <- readRDS(cf)$cond[, .(PLT_CN = plt_cn, CONDID = as.integer(condid), ecodiv, fortyp_grp = as.integer(fortyp_grp), stdage = as.numeric(stdage))][!is.na(stdage) & stdage >= MIN_AGE]
eco <- unique(as.data.table(st_drop_geometry(read_sf(ds0$EcodivisionFile[1])))[, .(ecodiv = as.character(ecodiv), Ecodivision = StrtmNm)])
# one name per code: the shapefile has a second M260 polygon named "Mediterranean" (found 2026-10-30); a mountain code keeps its "Mountains" name
eco <- eco[order(ecodiv, -(startsWith(ecodiv, "M") & grepl("Mountains$", Ecodivision)))][!duplicated(ecodiv)]
# FIA group -> forest type: the type of that code first, else the first type that pools it
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv"))[, StateClass := paste0("Forest: ", StateClassName)]
g2t <- rbindlist(lapply(seq_len(nrow(cw)), function(i) data.table(grp = as.integer(strsplit(as.character(cw$FiaTypeGroups[i]), ";")[[1]]), StateClass = cw$StateClass[i], own = cw$StateClassId[i])))
g2t <- g2t[order(grp, -(grp == own))][!duplicated(grp)]

sts <- sort(sub("_TREE[.]csv$", "", list.files(dm, "^[A-Z]{2}_TREE[.]csv$"))); t0 <- Sys.time()
m <- rbindlist(lapply(sts, function(s) {
  pl <- fread(file.path(dm, sprintf("%s_PLOT.csv", s)), select = c("CN", "REMPER"), colClasses = list(character = "CN"))
  t <- fread(file.path(dm, sprintf("%s_TREE.csv", s)), select = c("CN", "PREV_TRE_CN", "PLT_CN", "CONDID", "STATUSCD", "PREV_STATUS_CD", "AGENTCD", "CARBON_AG", "TPA_UNADJ", "DIA"),
             colClasses = list(character = c("CN", "PREV_TRE_CN", "PLT_CN")))
  for (k in c("STATUSCD", "PREV_STATUS_CD", "AGENTCD", "CARBON_AG", "TPA_UNADJ", "DIA")) set(t, j = k, value = as.numeric(t[[k]]))
  x <- merge(t[PREV_STATUS_CD %in% 1 & STATUSCD %in% 1:2 & !is.na(PREV_TRE_CN) & nzchar(PREV_TRE_CN)], t[, .(PREV_TRE_CN = CN, c0 = CARBON_AG * TPA_UNADJ, dia0 = DIA)], by = "PREV_TRE_CN")[is.na(dia0) | dia0 >= MIN_DIA]
  x <- merge(x, pl[, .(PLT_CN = CN, REMPER = as.numeric(REMPER))], by = "PLT_CN")[!is.na(c0) & !is.na(REMPER) & REMPER > 0]
  x[, .(live0 = sum(c0), dead = sum(c0[STATUSCD == 2 & !(AGENTCD %/% 10) %in% 3]), remper = mean(REMPER)), by = .(PLT_CN, CONDID = as.integer(CONDID))] }))
m <- merge(m, cc, by = c("PLT_CN", "CONDID"))[live0 > 0]
m[, frac := dead / live0]; m <- merge(m, g2t[, .(fortyp_grp = grp, StateClass)], by = "fortyp_grp")[, ecodiv := as.character(ecodiv)]
cat(sprintf("%d states read in %.1f min: %d remeasured conditions aged >= %g with a forest type; %.1f%% lost >= %.0f%% to non-fire causes (left out)\n",
            length(sts), as.numeric(Sys.time() - t0, units = "mins"), nrow(m), MIN_AGE, 100 * mean(m$frac >= SR), 100 * SR))
bg <- m[frac < SR]
rate <- function(d) sum(d$dead / d$remper) / sum(d$live0)
ft <- bg[, .(Conditions = .N, Rate = rate(.SD)), by = StateClass][Conditions >= MIN_N]
fe <- merge(bg, eco, by = "ecodiv")[, .(Conditions = .N, Rate = rate(.SD)), by = .(StateClass, Ecodivision)][Conditions >= MIN_N]   # by name: two codes can share one
# CBM's stem turnover of each type, for the log
cbx <- fread(file.path(pkg, "defaults/carbon-assumptions/fia-measured/cbm-crosswalk.csv")); te <- fread(file.path(pkg, "defaults/cbm/tblEcoBoundaryDefault.csv"))
cbx[, CBM := te$StemAnnualTurnOverRate[match(CbmEcozoneId, te$EcoBoundaryName)]]
ft[, CBM := cbx$CBM[match(StateClass, cbx$StateClassId)]]
options(width = 200)
cat("\nForest types (all ecodivisions):\n"); print(ft[order(StateClass), .(Type = sub("^Forest: ", "", StateClass), Conditions, FIA = round(Rate, 4), CBM, x = round(Rate / CBM, 1))], nrows = 100)
cat(sprintf("\n%d type x ecodivision rows (>= %d conditions); FIA / CBM %.1f-%.1fx\n", nrow(fe), MIN_N,
            min(fe$Rate / cbx$CBM[match(fe$StateClass, cbx$StateClassId)]), max(fe$Rate / cbx$CBM[match(fe$StateClass, cbx$StateClassId)])))
out <- rbind(ft[, .(StratumId = NA_character_, StateClassId = StateClass, StemTurnover = round(Rate, 4))],
             fe[, .(StratumId = Ecodivision, StateClassId = StateClass, StemTurnover = round(Rate, 4))])[order(StateClassId, StratumId, na.last = FALSE)]
lt0 <- fread(file.path(pkg, "defaults/carbon-assumptions/fia-measured/live-turnover.csv"))
cols <- setdiff(names(fread(file.path(pkg, "defaults/carbon-assumptions/fia-measured/live-turnover.csv"), nrows = 0)), "StemTurnover")
if (dry) quit(save = "no")
hdr <- c("StratumId", "StateClassId", "FoliageTurnover", "BranchTurnover", "BranchToSnag", "StemTurnover", "FineRootTurnover", "FineRootToAG", "CoarseRootTurnover",
         "CoarseRootToAG", "StemSnagFall", "BranchSnagFall")
for (k in setdiff(hdr, names(out))) out[, (k) := NA_real_]
fwrite(out[, ..hdr], file.path(pkg, "defaults/carbon-assumptions/fia-measured/live-turnover.csv"), na = "")
cat(sprintf("wrote %d rows to defaults/carbon-assumptions/fia-measured/live-turnover.csv\n", nrow(out)))
