# =============================================================================
# 18-fit-lines-by-ecodivision.R - to-do 3: the canopy-loss line of each ecodivision, set against FIA
# =============================================================================
# The line of an ecodivision is the one at which the rule flags the same share of conifer forest that FIA finds in stands
# with over 70% of their live tree carbon killed between visits (no fire, no cutting). FIA stands are visited at different
# times, so the rule's side is built stand by stand: for each clean conifer stand of the ecodivision, the rule's yearly rates
# (flagged / eligible forest still open, the ecodivision's conifer forest, from 17-rule-national.R) are summed over the stand's
# own years between visits; the mean over stands is the share the rule would show on FIA's own schedule. The line is where that
# mean equals FIA's share, by interpolation between the lines run. Stands whose years fall outside the rule's record are left out
# of both sides. The uncertainty of FIA's share (Wilson 90% interval on over-70 stands / stands) gives the range of the line.
# Pinyon/juniper (group 180) is fitted apart. Usage:
#   Rscript dev/mortality/18-fit-lines-by-ecodivision.R <FIA DataMart folder> <rule-national-lines.csv> <out folder> [--min-over=30]
# =============================================================================
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; dm <- pos[1]; R <- fread(pos[2]); OUT <- pos[3]; MINO <- as.integer(opt("min-over", 30)); options(width = 250)
cache <- file.path(OUT, "fia-stands.rds")
if (file.exists(cache)) m <- readRDS(cache) else {
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
  m[, frac := dead / live0][, clean := fire == 0 & cut == 0 & logging == 0 & !cfire & !ctrt]; saveRDS(m, cache) }
yr <- range(R$Year); w <- m[clean == TRUE & fortyp_grp < 400L][, kind := fifelse(fortyp_grp == 180L, "pinyon/juniper", "conifer")][, `:=`(y1 = MEASYEAR, y0 = MEASYEAR - pmax(1L, as.integer(round(REMPER))) + 1L)]
cat(sprintf("rule record %d-%d; clean softwood stands %d, of which %d have all their years inside the record\n", yr[1], yr[2], nrow(w), w[y0 >= yr[1] & y1 <= yr[2], .N])); w <- w[y0 >= yr[1] & y1 <= yr[2]]
R[, kind := fifelse(group == 180L, "pinyon/juniper", "conifer")]; rate <- R[, .(rate = sum(flagged_km2) / sum(forest_km2), forest_km2 = sum(forest_km2)), by = .(kind, ecodiv, line, Year)]
wil <- function(k, n, z = 1.645) { p <- k / n; d <- 1 + z^2 / n; c((p + z^2 / (2 * n) - z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / d, (p + z^2 / (2 * n) + z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / d) }
# the line at which the rule's share equals a target: shares fall as the line rises; linear between the lines run, NA outside them
at <- function(lines, share, target) { o <- order(lines); lines <- lines[o]; share <- share[o]; if (is.na(target) || target > max(share) || target < min(share)) return(NA_real_)
  i <- max(which(share >= target)); if (i == length(lines)) return(lines[i]); lines[i] + (share[i] - target) / (share[i] - share[i + 1]) * (lines[i + 1] - lines[i]) }
fit <- function(wk, rk) { cum <- rk[order(Year), .(Year, cs = cumsum(rate)), by = line]; L <- sort(unique(cum$line))
  sh <- vapply(L, function(l) { cs <- cum[line == l]; v <- c(0, cs$cs); names(v) <- c(min(cs$Year) - 1L, cs$Year); mean(v[as.character(wk$y1)] - v[as.character(wk$y0 - 1L)]) }, 0)
  n <- nrow(wk); k <- sum(wk$frac >= 0.7); ci <- wil(k, n)
  data.table(stands = n, over70 = k, fia_pct = round(100 * k / n, 2), fia_lo = round(100 * ci[1], 2), fia_hi = round(100 * ci[2], 2), line = round(at(L, sh, k / n), 3), line_hi = round(at(L, sh, ci[1]), 3), line_lo = round(at(L, sh, ci[2]), 3),
             rule_pct_at_lowest = round(100 * sh[1], 2), rule_pct_at_highest = round(100 * sh[length(L)], 2), killed_share = round(wk[frac >= 0.7, sum(dead) / sum(live0)], 2), shares = list(setNames(round(100 * sh, 2), L))) }
res <- rbindlist(lapply(split(w, by = c("kind", "ecodiv")), function(wk) { rk <- rate[kind == wk$kind[1] & ecodiv == wk$ecodiv[1]]; if (!nrow(rk)) return(NULL); cbind(kind = wk$kind[1], ecodiv = wk$ecodiv[1], forest_km2 = round(rk[Year == min(Year), forest_km2[1]]), fit(wk, rk)) }))
nat <- rbindlist(lapply(split(w, by = "kind"), function(wk) { rk <- rate[kind == wk$kind[1], .(rate = sum(rate * forest_km2) / sum(forest_km2)), by = .(line, Year)]; cbind(kind = wk$kind[1], ecodiv = "all", forest_km2 = round(rate[kind == wk$kind[1] & Year == min(Year) & line == min(line), sum(forest_km2)]), fit(wk, rk)) }))
res <- rbind(nat, res[order(kind, -over70)])
cat("\nrule's share on FIA's schedule (%), by line:\n"); print(cbind(res[, .(kind, ecodiv)], rbindlist(lapply(res$shares, as.list))), nrows = 80)
res[, shares := NULL]; res[, basis := fifelse(ecodiv == "all", "national", fifelse(over70 >= MINO & !is.na(line), "own", "national default"))]
cat(sprintf("\nlines (own where an ecodivision has at least %d stands over 70%%; line_lo-line_hi from the 90%% interval of FIA's share):\n", MINO)); print(res, nrows = 80)
fwrite(res, file.path(OUT, "lines-by-ecodivision.csv"))
use <- res[kind == "conifer" & ecodiv != "all", .(ecodiv, line = fifelse(basis == "own", line, res[kind == "conifer" & ecodiv == "all", line]), basis)]; fwrite(use, file.path(OUT, "lines-fitted.csv")); cat("\nlines to use for conifer forest:\n"); print(use)
