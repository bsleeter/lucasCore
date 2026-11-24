# =============================================================================
# 04-fia-comparison.R - to-do 3, phase 0: FIA remeasured plots against the 70% line and against the canopy-loss rule
# =============================================================================
# User, 2026-11-22: "Match area to 70%" (the mapped area is the area truly over 70% killed; the carbon step applies the killed
# share of stands over that line), then "Run the FIA comparison". Three parts, all read-only:
#   A. West (11 states): remeasured forest conditions with no fire-killed and no cut trees. Per forest type group: how many lost
#      >= 70% (and >= 50%) of live aboveground carbon to non-fire mortality in one remeasurement, the killed share of those over
#      the line (what the carbon step would apply), and the recorded cause of death (AGENTCD).
#   B. The region's pyrome (--pyrome=27): plots whose public coordinates fall inside it, by whether the remeasurement spans the
#      2012-2016 die-off. The regional rate FIA gives, to set beside the reference sites (15-17% of pixels over 70% killed) and
#      the rule's area (14.6% of clean forest losing >= 30% of canopy).
#   C. Canopy cover around those plots: public FIA coordinates are moved up to about a mile (and some swapped), so a plot cannot
#      be matched to a 30 m pixel; the comparison is with clean forest within --radius (1000 m) of the public point.
# Conditions as tools/calibrate-stem-turnover.R (trees alive at the previous visit, carbon at the previous visit), every stand age.
# Usage: Rscript dev/mortality/04-fia-comparison.R <FIA DataMart folder> <region folder> <pyromes shp> <out folder> [--pyrome=27] [--pyrome-states=CA] [--first-by=2013] [--second-from=2016] [--radius=1000]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(sf); library(terra) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; dm <- pos[1]; R <- pos[2]; PY <- pos[3]; OUT <- pos[4]; dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
PYR <- as.integer(opt("pyrome", 27)); RAD <- as.numeric(opt("radius", 1000)); options(width = 250); terraOptions(progress = 0)
pkg <- local({ d <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))); while (!file.exists(file.path(d, "package.xml")) && dirname(d) != d) d <- dirname(d); d })
ST <- c("AZ", "CA", "CO", "ID", "MT", "NM", "NV", "OR", "UT", "WA", "WY")
cc <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[, .(PLT_CN = plt_cn, CONDID = as.integer(condid), ecodiv, fortyp_grp = as.integer(fortyp_grp), stdage = as.numeric(stdage))]
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv"))
m <- rbindlist(lapply(ST, function(s) {
  pl <- fread(file.path(dm, sprintf("%s_PLOT.csv", s)), select = c("CN", "REMPER", "MEASYEAR", "LAT", "LON"), colClasses = list(character = "CN"))
  t <- fread(file.path(dm, sprintf("%s_TREE.csv", s)), select = c("CN", "PREV_TRE_CN", "PLT_CN", "CONDID", "STATUSCD", "PREV_STATUS_CD", "AGENTCD", "CARBON_AG", "TPA_UNADJ"),
             colClasses = list(character = c("CN", "PREV_TRE_CN", "PLT_CN")))
  for (k in c("STATUSCD", "PREV_STATUS_CD", "AGENTCD", "CARBON_AG", "TPA_UNADJ")) set(t, j = k, value = as.numeric(t[[k]]))
  x <- merge(t[PREV_STATUS_CD %in% 1 & STATUSCD %in% 1:3 & !is.na(PREV_TRE_CN) & nzchar(PREV_TRE_CN)], t[, .(PREV_TRE_CN = CN, c0 = CARBON_AG * TPA_UNADJ)], by = "PREV_TRE_CN")[!is.na(c0)]
  x[, ag := AGENTCD %/% 10][, d := STATUSCD == 2]
  x <- x[, .(live0 = sum(c0[STATUSCD != 3]), cut = sum(c0[STATUSCD == 3]), dead = sum(c0[d & !ag %in% 3]), fire = sum(c0[d & ag %in% 3]),
             insect = sum(c0[d & ag %in% 1]), disease = sum(c0[d & ag %in% 2]), weather = sum(c0[d & ag %in% 5]), unknown = sum(c0[d & ag %in% 7]), logging = sum(c0[d & ag %in% 8]), other = sum(c0[d & (is.na(ag) | !ag %in% c(1, 2, 3, 5, 7, 8))]), trees = sum(STATUSCD != 3)),
         by = .(PLT_CN, CONDID = as.integer(CONDID))]
  co <- fread(file.path(dm, sprintf("%s_COND.csv", s)), select = c("PLT_CN", "CONDID", "DSTRBCD1", "DSTRBCD2", "DSTRBCD3", "TRTCD1", "TRTCD2", "TRTCD3"), colClasses = list(character = "PLT_CN"))
  co <- co[, .(PLT_CN, CONDID = as.integer(CONDID), cfire = DSTRBCD1 %in% 30:32 | DSTRBCD2 %in% 30:32 | DSTRBCD3 %in% 30:32, ctrt = TRTCD1 %in% c(10, 20) | TRTCD2 %in% c(10, 20) | TRTCD3 %in% c(10, 20))]
  x <- merge(x, co, by = c("PLT_CN", "CONDID"))
  merge(x, pl[, .(PLT_CN = CN, REMPER = as.numeric(REMPER), MEASYEAR, LAT, LON, state = s)], by = "PLT_CN")[!is.na(REMPER) & REMPER > 0] }))
m <- merge(m, cc, by = c("PLT_CN", "CONDID"))[live0 > 0 & !is.na(fortyp_grp)]
m[, frac := dead / live0][, clean := fire == 0 & cut == 0 & logging == 0 & !cfire & !ctrt][, Type := cw$StateClassName[match(fortyp_grp, cw$StateClassId)]][is.na(Type), Type := paste("group", fortyp_grp)]
cat(sprintf("%d remeasured forest conditions in %d western states (median remeasurement %.1f yr); %d with no fire-killed and no cut trees\n", nrow(m), length(ST), median(m$REMPER), sum(m$clean)))
w <- m[clean == TRUE]
smry <- function(d) d[, .(conds = .N, over70 = sum(frac >= 0.7), over70_pct = round(100 * mean(frac >= 0.7), 2), over50_pct = round(100 * mean(frac >= 0.5), 2),
  killed_share_over70 = round(sum(dead[frac >= 0.7]) / sum(live0[frac >= 0.7]), 3), killed_share_50to70 = round(sum(dead[frac >= 0.5 & frac < 0.7]) / sum(live0[frac >= 0.5 & frac < 0.7]), 3),
  mort_carbon_over70_pct = round(100 * sum(dead[frac >= 0.7]) / sum(dead), 1), mort_carbon_over50_pct = round(100 * sum(dead[frac >= 0.5]) / sum(dead), 1),
  insect_pct = round(100 * sum(insect[frac >= 0.7]) / sum(dead[frac >= 0.7])), disease_pct = round(100 * sum(disease[frac >= 0.7]) / sum(dead[frac >= 0.7])),
  weather_pct = round(100 * sum(weather[frac >= 0.7]) / sum(dead[frac >= 0.7])), unknown_pct = round(100 * sum(unknown[frac >= 0.7]) / sum(dead[frac >= 0.7])), other_pct = round(100 * sum(other[frac >= 0.7]) / sum(dead[frac >= 0.7])))]
cat("\n===== A. West: conditions over the 70% line, by forest type group (no fire-killed, no cut trees) =====\n")
cat("killed_share_over70 = dead / live aboveground carbon over the conditions over the line; cause columns = share of their dead carbon by recorded agent\n")
A <- rbind(w[, c(Type = "All types", smry(.SD))], w[, smry(.SD), by = Type][conds >= 100][order(-conds)], fill = TRUE)
print(A, nrows = 60); fwrite(A, file.path(OUT, "fia-over70-by-type.csv"))
cat("\nsize of the conditions over the line: live trees tallied at the previous visit (a condition with few trees crosses 70% by chance)\n")
print(w[, .(conds = .N, over70_pct = round(100 * mean(frac >= 0.7), 2), killed_share_over70 = round(sum(dead[frac >= 0.7]) / sum(live0[frac >= 0.7]), 3)), by = .(trees_at_previous_visit = cut(trees, c(0, 2, 5, 10, 20, Inf)))][order(trees_at_previous_visit)])
cat("
stand age at the second visit (the stem turnover fit uses conditions aged >= 60 then):
"); print(w[, smry(.SD)[, .(conds, over70, over70_pct, over50_pct, mort_carbon_over70_pct, mort_carbon_over50_pct)], by = .(age = cut(stdage, c(-1, 20, 60, Inf)))][order(age)])
cat("\nby state:\n"); print(w[, smry(.SD)[, .(conds, over70, over70_pct, over50_pct, killed_share_over70, mort_carbon_over70_pct)], by = state][order(state)])
cat("\nCalifornia by year of the second visit:\n"); print(w[state == "CA", smry(.SD)[, .(conds, over70, over70_pct, over50_pct, mort_carbon_over70_pct)], by = MEASYEAR][order(MEASYEAR)])

# ---- B. the pyrome ----------------------------------------------------------------------------------------------------
py <- read_sf(PY); py <- py[py$PYROME == PYR, ]
ca <- m[state %in% strsplit(opt("pyrome-states", "CA"), ",")[[1]] & !is.na(LAT) & !is.na(LON)]
pts <- st_transform(st_as_sf(ca, coords = c("LON", "LAT"), crs = 4269, remove = FALSE), st_crs(py))
ca <- ca[lengths(st_intersects(pts, py)) > 0]; ca[, y0 := MEASYEAR - round(REMPER)]
FV <- as.integer(opt("first-by", 2013)); SV <- as.integer(opt("second-from", 2016))   # the episode: first visit by FV, second visit SV on
ca[, span := fcase(y0 <= FV & MEASYEAR >= SV, sprintf("spans the episode (first visit by %d, second %d on)", FV, SV), MEASYEAR <= FV, sprintf("ends by %d", FV), default = "other")]
cat(sprintf("\n===== B. Pyrome %d (%s): %d remeasured forest conditions by public coordinates =====\n", PYR, py$NAME[1], nrow(ca)))
B <- ca[, .(conds = .N, plots = uniqueN(PLT_CN), clean = sum(clean), over70_pct = round(100 * mean(frac[clean] >= 0.7), 1), over50_pct = round(100 * mean(frac[clean] >= 0.5), 1),
            mean_killed_share = round(sum(dead[clean]) / sum(live0[clean]), 3), killed_share_over70 = round(sum(dead[clean & frac >= 0.7]) / sum(live0[clean & frac >= 0.7]), 3),
            mort_carbon_over70_pct = round(100 * sum(dead[clean & frac >= 0.7]) / sum(dead[clean]), 1), mort_carbon_over50_pct = round(100 * sum(dead[clean & frac >= 0.5]) / sum(dead[clean]), 1),
            with_fire_or_cut_pct = round(100 * mean(!clean), 1)), by = span][order(span)]
print(B); fwrite(B, file.path(OUT, "fia-pyrome.csv"))
d <- ca[clean == TRUE & startsWith(span, "spans")]
cat("\nspanning the die-off, by forest type group:\n"); print(d[, .(conds = .N, over70_pct = round(100 * mean(frac >= 0.7), 1), over50_pct = round(100 * mean(frac >= 0.5), 1), mean_killed_share = round(sum(dead) / sum(live0), 3)), by = Type][order(-conds)])
cat("\nspanning the die-off, by share killed: "); print(d[, .N, by = .(killed = cut(frac, c(-0.001, 0.1, 0.3, 0.5, 0.7, 1)))][order(killed)][, pct := round(100 * N / sum(N), 1)][])

# ---- C. canopy cover around the plots ---------------------------------------------------------------------------------
G <- rast(Sys.glob(file.path(R, "land-cover/nlcd-annual", "Annual_NLCD_LndCov_2011_*.tif"))[1]); n <- ncell(G)
on <- function(r) { levels(r) <- NULL; coltab(r) <- NULL; if (!compareGeom(r, G, stopOnError = FALSE)) r <- project(r, G, method = "near"); values(r, mat = FALSE) }
tc <- function(k) { v <- on(rast(file.path(R, "land-cover/tree-canopy", sprintf("science_tcc_conus_%d.tif", k)))); v[v > 100] <- NA; v }
lc <- function(k) on(rast(file.path(R, "disturbance/lcms", k, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", k))))
mt <- function(k) { f <- file.path(R, "disturbance/mtbs", sprintf("mtbs_CONUS_%d.tif", k)); if (!file.exists(f)) return(rep(FALSE, n)); v <- tryCatch(on(rast(f)), error = function(e) NULL); if (is.null(v)) rep(FALSE, n) else v %in% 1:4 }
bad <- rep(FALSE, n); for (k in 2010:2018) bad <- bad | lc(k) %in% c(1, 2, 3, 5, 6, 7, 8, 9) | mt(k)
t0 <- tc(2011); tp <- pmin(tc(2016), tc(2017), tc(2018)); ok <- values(G, mat = FALSE) %in% 41:43 & !is.na(t0) & t0 >= 20 & !is.na(tp) & !bad
rel <- ifelse(ok, (t0 - tp) / t0, NA); rm(t0, tp, bad); gc()
rr <- init(G, NA); values(rr) <- rel; r30 <- init(G, NA); values(r30) <- as.numeric(rel >= 0.3)
pp <- d[, .(live0 = sum(live0), dead = sum(dead)), by = .(PLT_CN, LAT, LON)][, frac := dead / live0]
v <- buffer(project(vect(as.matrix(pp[, .(LON, LAT)]), crs = "EPSG:4269"), crs(G)), RAD)
pp[, `:=`(rel_mean = extract(rr, v, fun = mean, na.rm = TRUE)[, 2], flagged30 = extract(r30, v, fun = mean, na.rm = TRUE)[, 2], clean_px = extract(r30, v, fun = function(x) sum(!is.na(x)))[, 2])]
pp <- pp[clean_px >= 300]; fwrite(pp, file.path(OUT, "fia-plots-canopy.csv"))
cat(sprintf("\n===== C. Canopy cover within %g m of the public plot point: %d plots spanning the die-off, clean, with >= 300 clean forest pixels around them =====\n", RAD, nrow(pp)))
cat(sprintf("correlation of the plot's share killed with the mean canopy loss around it %.2f (Spearman %.2f); with the share of pixels losing >= 30%% %.2f (Spearman %.2f)\n",
            cor(pp$frac, pp$rel_mean), cor(pp$frac, pp$rel_mean, method = "spearman"), cor(pp$frac, pp$flagged30), cor(pp$frac, pp$flagged30, method = "spearman")))
print(pp[, .(plots = .N, plot_killed_share = round(sum(dead) / sum(live0), 3), canopy_loss_around = round(mean(rel_mean), 3), flagged30_around_pct = round(100 * mean(flagged30), 1)), by = .(killed = cut(frac, c(-0.001, 0.1, 0.3, 0.5, 0.7, 1)))][order(killed)])
cat(sprintf("all these plots: %.1f%% over the 70%% line, %.1f%% over 50%%; mean share of pixels around them losing >= 30%% of canopy %.1f%%\n", 100 * mean(pp$frac >= 0.7), 100 * mean(pp$frac >= 0.5), 100 * mean(pp$flagged30)))
