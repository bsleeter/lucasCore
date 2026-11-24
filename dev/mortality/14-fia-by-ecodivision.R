# =============================================================================
# 14-fia-by-ecodivision.R - to-do 3: FIA's share of conifer stands over the 70% line, by ecodivision, for the whole country
# =============================================================================
# User, 2026-11-23: the canopy-loss line is to be calibrated by ecodivision, not by pyrome. The line for a unit is set so the
# share of its conifer forest the map rule flags matches FIA's share of conifer stands that lost >= 70% of live aboveground
# carbon to non-fire mortality. This tallies the FIA side for every ecodivision, to show which have enough stands to set a
# line of their own. Conditions and filters as 04-fia-comparison.R (remeasured, trees alive at the previous visit, no fire-killed,
# cut or logging-killed trees, no fire or cutting recorded on the condition), every stand age. Conifer = softwood forest type
# groups (codes under 400); pinyon/juniper (180) is shown apart because its eligibility is open.
# Per ecodivision: conditions, those over the line, the share per remeasurement, the share per year (over the line / years
# between visits), the killed share of those over the line, and the years the second visits cover.
# Read-only. Usage: Rscript dev/mortality/14-fia-by-ecodivision.R <FIA DataMart folder> <out folder>
# =============================================================================
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(TRUE); dm <- a[1]; OUT <- a[2]; options(width = 250)
ST <- sub("_TREE.csv$", "", list.files(dm, "_TREE.csv$"))
cc <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[, .(PLT_CN = plt_cn, CONDID = as.integer(condid), ecodiv, fortyp_grp = as.integer(fortyp_grp))]
m <- rbindlist(lapply(ST, function(s) {
  pl <- fread(file.path(dm, sprintf("%s_PLOT.csv", s)), select = c("CN", "REMPER", "MEASYEAR"), colClasses = list(character = "CN"))
  t <- fread(file.path(dm, sprintf("%s_TREE.csv", s)), select = c("CN", "PREV_TRE_CN", "PLT_CN", "CONDID", "STATUSCD", "PREV_STATUS_CD", "AGENTCD", "CARBON_AG", "TPA_UNADJ"), colClasses = list(character = c("CN", "PREV_TRE_CN", "PLT_CN")))
  for (k in c("STATUSCD", "PREV_STATUS_CD", "AGENTCD", "CARBON_AG", "TPA_UNADJ")) set(t, j = k, value = as.numeric(t[[k]]))
  x <- merge(t[PREV_STATUS_CD %in% 1 & STATUSCD %in% 1:3 & !is.na(PREV_TRE_CN) & nzchar(PREV_TRE_CN)], t[, .(PREV_TRE_CN = CN, c0 = CARBON_AG * TPA_UNADJ)], by = "PREV_TRE_CN")[!is.na(c0)]
  if (!nrow(x)) return(NULL)
  x[, ag := AGENTCD %/% 10][, d := STATUSCD == 2]
  x <- x[, .(live0 = sum(c0[STATUSCD != 3]), cut = sum(c0[STATUSCD == 3]), dead = sum(c0[d & !ag %in% 3]), fire = sum(c0[d & ag %in% 3]), logging = sum(c0[d & ag %in% 8])), by = .(PLT_CN, CONDID = as.integer(CONDID))]
  co <- fread(file.path(dm, sprintf("%s_COND.csv", s)), select = c("PLT_CN", "CONDID", "DSTRBCD1", "DSTRBCD2", "DSTRBCD3", "TRTCD1", "TRTCD2", "TRTCD3"), colClasses = list(character = "PLT_CN"))
  co <- co[, .(PLT_CN, CONDID = as.integer(CONDID), cfire = DSTRBCD1 %in% 30:32 | DSTRBCD2 %in% 30:32 | DSTRBCD3 %in% 30:32, ctrt = TRTCD1 %in% c(10, 20) | TRTCD2 %in% c(10, 20) | TRTCD3 %in% c(10, 20))]
  x <- merge(x, co, by = c("PLT_CN", "CONDID"))
  merge(x, pl[, .(PLT_CN = CN, REMPER = as.numeric(REMPER), MEASYEAR, state = s)], by = "PLT_CN")[!is.na(REMPER) & REMPER > 0] }))
m <- merge(m, cc, by = c("PLT_CN", "CONDID"))[live0 > 0 & !is.na(fortyp_grp)]
m[, frac := dead / live0][, clean := fire == 0 & cut == 0 & logging == 0 & !cfire & !ctrt]
m[, kind := fcase(fortyp_grp == 180L, "pinyon/juniper", fortyp_grp < 400L, "conifer", fortyp_grp < 999L, "hardwood", default = "nonstocked")]
cat(sprintf("%d remeasured forest conditions in %d states; %d clean. Median years between visits %.1f; second visits %d to %d\n", nrow(m), length(ST), sum(m$clean), median(m$REMPER), min(m$MEASYEAR), max(m$MEASYEAR)))
w <- m[clean == TRUE]
sm <- function(d) d[, .(conds = .N, over70 = sum(frac >= 0.7), pct_per_visit = round(100 * mean(frac >= 0.7), 2), pct_per_year = round(100 * sum(frac >= 0.7) / sum(REMPER), 3),
                        killed_share = round(sum(dead[frac >= 0.7]) / sum(live0[frac >= 0.7]), 2), mort_carbon_over70_pct = round(100 * sum(dead[frac >= 0.7]) / sum(dead), 1), years = sprintf("%d-%d", min(MEASYEAR), max(MEASYEAR)))]
cat("\n===== all states, by kind of forest type group =====\n"); print(w[, sm(.SD), by = kind][order(-conds)])
cat("\n===== conifer stands (pinyon/juniper apart), by ecodivision =====\n")
E <- w[kind == "conifer", sm(.SD), by = ecodiv][order(-over70)]; print(E, nrows = 80); fwrite(E, file.path(OUT, "fia-conifer-by-ecodivision.csv"))
cat(sprintf("\necodivisions with conifer stands: %d; with >= 30 stands over the line: %d; 10 to 29: %d; 1 to 9: %d; none: %d\n", nrow(E), sum(E$over70 >= 30), sum(E$over70 >= 10 & E$over70 < 30), sum(E$over70 >= 1 & E$over70 < 10), sum(E$over70 == 0)))
cat("\n===== pinyon/juniper, by ecodivision =====\n"); print(w[kind == "pinyon/juniper", sm(.SD), by = ecodiv][order(-over70)])
cat("\n===== hardwood stands, by ecodivision (not eligible under the conifer-only decision) =====\n"); print(w[kind == "hardwood", sm(.SD), by = ecodiv][order(-over70)][1:min(.N, 25)])
cat("\n===== conifer stands over the line by forest type group, all states =====\n"); print(w[kind == "conifer", sm(.SD), by = fortyp_grp][order(-over70)])
