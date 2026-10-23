# =============================================================================
# 02-lcms-vs-nlcd.R - harvest events at 30 m in the P26 pyrome, 1986-2023: LCMS Tree Removal vs the NLCD clearcut rule
# =============================================================================
# NLCD clearcut = a forest pixel (41-43) the year before that is shrub or grass (52, 71), outside a fire perimeter that year and the
# year before (the stage 6 / 10 rule). LCMS = USFS LCMS v2025-11 annual Change (cause of change; 9 = Tree Removal). Tree Removal on
# forest is split by what NLCD shows next: stand-replacing (shrub or grass within y..y+2: a clearcut candidate) or partial (still
# forest: a selection / thinning candidate). Uses the stage 10 cache of the phaseQ setup (P26 region, 30 m).
# Output: dev/harvest/lcms-*.csv and the console.
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(parallel) })
CA <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim.data/lucasCore-suitability/r30_-2170395_1863765_5539_11473_1985-2023"
LC <- "F:/lucas-master/Data Sources/LCMS/v2025-11/Change_Annual"; OUT <- "F:/lucasCore/dev/harvest"
cf <- function(k) file.path(CA, paste0(k, ".tif")); YRS <- 1986:2023
G <- rast(cf("region")); nc <- ncol(G)
own <- values(rast(cf("owner")), mat = FALSE); gap <- values(rast(cf("gap")), mat = FALSE)
OWN <- c(`0` = "Not forest", `1` = "Family", `2` = "Corporate", `3` = "TIMO/REIT", `4` = "Other private", `5` = "Federal", `6` = "State", `7` = "Local", `8` = "Tribal")
CAUSE <- c("Wind", "Hurricane", "Snow or Ice Transition", "Desiccation", "Inundation", "Prescribed Fire", "Wildfire", "Mechanical Land Transformation", "Tree Removal",
           "Defoliation", "Southern Pine Beetle", "Insect, Disease, or Drought Stress", "Other Loss", "Vegetation Successional Growth")

# per year: NLCD clearcut cells; LCMS loss cells (classes 1-13) with their cause; NLCD class the year before (forest?)
cl <- makeCluster(13); on.exit(stopCluster(cl))
yr <- parLapply(cl, YRS, function(y, CA, LC) { library(terra); library(data.table); terraOptions(progress = 0, memfrac = 0.05)
  cf <- function(k) file.path(CA, paste0(k, ".tif")); v <- function(f) values(rast(f), mat = FALSE)
  G <- rast(cf("region")); rg <- v(cf("region")); p <- v(cf(sprintf("nlcd_%d", y - 1))); q <- v(cf(sprintf("nlcd_%d", y)))
  b <- (v(cf(sprintf("burn_%d", y))) > 0) | (v(cf(sprintf("burn_%d", y - 1))) > 0); b[is.na(b)] <- FALSE
  nl <- which(!is.na(rg) & p %in% 41:43 & q %in% c(52, 71) & !b)
  r <- rast(file.path(LC, y, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", y)))
  r <- crop(r, project(as.polygons(ext(G), crs = crs(G)), crs(r)), snap = "out"); levels(r) <- NULL; coltab(r) <- NULL
  x <- values(project(r, G, method = "near"), mat = FALSE); i <- which(!is.na(rg) & !is.na(x) & x >= 1 & x <= 13)
  list(y = y, nl = nl, lc = data.table(cell = i, cause = x[i], forest = p[i] %in% 41:43), nforest = sum(!is.na(rg) & p %in% 41:43)) }, CA = CA, LC = LC)
names(yr) <- YRS
km2 <- 900 / 1e6
lcs <- rbindlist(lapply(yr, function(z) z$lc[, Year := z$y]))
nlc <- rbindlist(lapply(yr, function(z) data.table(cell = z$nl, Year = z$y)))
tr <- lcs[cause == 9 & forest == TRUE]
cat(sprintf("LCMS loss pixels read: %d; Tree Removal on forest: %.0f km2 over %d-%d\n", nrow(lcs), nrow(tr) * km2, min(YRS), max(YRS)))

# Tree Removal split by NLCD's next classes: shrub or grass within y..y+2 = stand-replacing
nlv <- function(y) values(rast(cf(sprintf("nlcd_%d", min(y, 2023)))), mat = FALSE)
tr[, standrep := FALSE]
for (y in YRS) { k <- tr$Year == y; if (!any(k)) next; c0 <- tr$cell[k]
  sr <- Reduce(`|`, lapply(y:min(y + 2, 2023), function(t) nlv(t)[c0] %in% c(52, 71))); tr$standrep[k] <- sr }

ann <- merge(merge(nlc[, .(NLCD_clearcut = .N * km2), by = Year], tr[, .(LCMS_TreeRemoval = .N * km2, LCMS_TR_standrep = sum(standrep) * km2, LCMS_TR_partial = sum(!standrep) * km2), by = Year], all = TRUE, by = "Year"),
             lcs[cause == 7, .(LCMS_Wildfire = .N * km2), by = Year], all = TRUE, by = "Year")
for (k in names(ann)) set(ann, which(is.na(ann[[k]])), k, 0)
cat("\nannual area (km2), P26 region at 30 m:\n"); print(ann, digits = 3)
cat("\nmeans per year (km2):\n"); print(rbind(ann[Year < 1999, c(Period = "1986-1998", lapply(.SD, function(x) round(mean(x), 1))), .SDcols = -1],
                                              ann[Year >= 1999, c(Period = "1999-2023", lapply(.SD, function(x) round(mean(x), 1))), .SDcols = -1]))
fwrite(ann, file.path(OUT, "lcms-annual.csv"))

# agreement
m1 <- lcs[, .(cell, LY = Year, cause)][nlc, on = "cell", allow.cartesian = TRUE][, .(cause = if (any(!is.na(LY) & LY >= Year - 2 & LY <= Year + 1)) {
  cs <- sort(unique(cause[!is.na(LY) & LY >= Year - 2 & LY <= Year + 1])); if (9 %in% cs) "Tree Removal" else CAUSE[cs[1]] } else "(no LCMS loss)"), by = .(cell, Year)]
cat(sprintf("\nwhat LCMS records on the %.0f km2 of NLCD clearcut pixels (y-2..y+1; Tree Removal wins when several):\n", nrow(m1) * km2))
print(m1[, .(km2 = round(.N * km2, 1), share = sprintf("%.1f%%", 100 * .N / nrow(m1))), by = cause][order(-km2)])
m2 <- nlc[, .(cell, NY = Year)][tr, on = "cell", allow.cartesian = TRUE][, .(hit = any(!is.na(NY) & NY >= Year & NY <= Year + 2)), by = .(cell, Year, standrep)]
cat(sprintf("\nLCMS Tree Removal on forest caught by the NLCD clearcut rule (y..y+2): %.1f%% (stand-replacing %.1f%%, partial %.1f%%)\n",
            100 * mean(m2$hit), 100 * m2[standrep == TRUE, mean(hit)], 100 * m2[standrep == FALSE, mean(hit)]))

# owner and GAP status
ow <- function(cells, lab) data.table(Set = lab, Owner = OWN[as.character(own[cells])], Gap = gap[cells])
o <- rbind(ow(nlc$cell, "NLCD clearcut"), ow(tr[standrep == TRUE, cell], "LCMS TR stand-replacing"), ow(tr[standrep == FALSE, cell], "LCMS TR partial"))
cat("\nowner type (share of each set, %):\n"); print(dcast(o[, .N, by = .(Set, Owner)][, share := round(100 * N / sum(N), 1), by = Set], Owner ~ Set, value.var = "share", fill = 0))
cat("\nshare on GAP 1-3:\n"); print(o[, .(GAP1to3 = sprintf("%.0f%%", 100 * mean(Gap %in% 1:3))), by = Set])
fwrite(o[, .N, by = .(Set, Owner, Gap)], file.path(OUT, "lcms-owner.csv"))

# patch sizes (8-connected pixels of one year), ha
patch_sizes <- function(ev, nc) { if (!length(ev)) return(integer()); ev <- sort(ev); col <- (ev - 1) %% nc; a <- integer(); b <- integer()
  for (o in list(c(1, 1), c(nc - 1, -1), c(nc, 0), c(nc + 1, 1))) { j <- ev + o[1]; ok <- if (o[2] == 1) col < nc - 1 else if (o[2] == -1) col > 0 else rep(TRUE, length(ev))
    m <- match(j[ok], ev); k <- which(ok)[!is.na(m)]; a <- c(a, k); b <- c(b, m[!is.na(m)]) }
  lab <- seq_along(ev); repeat { old <- lab; x <- data.table(k = c(a, b), v = c(lab[b], lab[a]))[, .(v = min(v)), by = k]; lab[x$k] <- pmin(lab[x$k], x$v); lab <- lab[lab]; if (identical(lab, old)) break }
  as.integer(table(lab)) }
ps <- function(lab, d) { s <- unlist(lapply(split(d$cell, d$Year), patch_sizes, nc = nc)) * 0.09
  data.table(Set = lab, Patches = length(s), Median_ha = median(s), AreaWeightedMedian_ha = { o <- sort(s); o[which(cumsum(o) >= sum(o) / 2)[1]] }, SinglePixelShare = round(mean(s <= 0.09), 3), Max_ha = max(s)) }
pz <- rbind(ps("NLCD clearcut", nlc), ps("LCMS TR stand-replacing", tr[standrep == TRUE]), ps("LCMS TR partial", tr[standrep == FALSE]))
cat("\npatch sizes (ha):\n"); print(pz, digits = 3); fwrite(pz, file.path(OUT, "lcms-patches.csv"))
cat("DONE\n")
