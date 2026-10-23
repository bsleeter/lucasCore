# =============================================================================
# 01-landfire-vs-nlcd.R - clearcut events at 30 m in the P26 pyrome: the NLCD rule (stage 6 / 10) vs LANDFIRE disturbance, 1999-2023
# =============================================================================
# NLCD clearcut = a forest pixel (41-43) the year before that is shrub or grass (52, 71) and not inside a fire perimeter that year or
# the year before. LANDFIRE = each year's US_DIST raster by DIST_TYPE (Clearcut, Harvest, Thinning, ...). Uses the stage 10 cache of
# the phaseQ setup (P26 region, 30 m). Reports annual areas, how often each finds the other's events (NLCD can lag: +-2 years), what
# LANDFIRE says the NLCD events are, the owner types and the patch sizes. Output: dev/harvest/compare-*.csv and the console.
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(parallel) })
CA <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim.data/lucasCore-suitability/r30_-2170395_1863765_5539_11473_1985-2023"
LF <- "F:/lucas-master/Data Sources/Landfire Disturbance"; OUT <- "F:/lucasCore/dev/harvest"
cf <- function(k) file.path(CA, paste0(k, ".tif")); YRS <- 1999:2023
reg <- values(rast(cf("region")), mat = FALSE); G <- rast(cf("region")); nc <- ncol(G)
own <- values(rast(cf("owner")), mat = FALSE); gap <- values(rast(cf("gap")), mat = FALSE)
OWN <- c(`0` = "Not forest", `1` = "Family", `2` = "Corporate", `3` = "TIMO/REIT", `4` = "Other private", `5` = "Federal", `6` = "State", `7` = "Local", `8` = "Tribal")

# per year: NLCD clearcut cells, and every LANDFIRE-disturbed cell with its type (in the region)
cl <- makeCluster(13); on.exit(stopCluster(cl))
yr <- parLapply(cl, YRS, function(y, CA, LF) { library(terra); library(data.table); terraOptions(progress = 0, memfrac = 0.05)
  cf <- function(k) file.path(CA, paste0(k, ".tif")); v <- function(f) values(rast(f), mat = FALSE)
  G <- rast(cf("region")); rg <- v(cf("region")); p <- v(cf(sprintf("nlcd_%d", y - 1))); q <- v(cf(sprintf("nlcd_%d", y)))
  b <- (v(cf(sprintf("burn_%d", y))) > 0) | (v(cf(sprintf("burn_%d", y - 1))) > 0); b[is.na(b)] <- FALSE
  nl <- which(!is.na(rg) & p %in% 41:43 & q %in% c(52, 71) & !b)
  d <- file.path(LF, sprintf("US_DIST%d", y)); tif <- Sys.glob(file.path(d, "*", "Tif", "*.tif"))[1]; csv <- Sys.glob(file.path(d, "*", "CSV_Data", "*.csv"))[1]
  at <- fread(csv); setnames(at, toupper(names(at)))
  r <- rast(tif); r <- crop(r, project(as.polygons(ext(G), crs = crs(G)), crs(r)), snap = "out"); levels(r) <- NULL
  # codes -> a small type number before projecting (codes go above 255 and project keeps the source's 8-bit type)
  types <- setdiff(unique(at$DIST_TYPE), c(NA, "NA", "Fill-NoData", "Fill-Not Mapped", "Water"))
  rcl <- cbind(at$VALUE, match(at$DIST_TYPE, types)); rcl <- rcl[!is.na(rcl[, 2]), , drop = FALSE]
  r <- classify(r, rcl, others = NA); r <- project(r, G, method = "near"); x <- v(r); i <- which(!is.na(rg) & !is.na(x) & x > 0)
  ty <- types[x[i]]; keep <- !is.na(ty)
  list(y = y, nl = nl, lf = data.table(cell = i[keep], type = ty[keep], forest = p[i[keep]] %in% 41:43)) }, CA = CA, LF = LF)
names(yr) <- YRS

# annual areas (km2, 30 m pixels)
km2 <- 900 / 1e6
ann <- rbindlist(lapply(yr, function(z) data.table(Year = z$y, NLCD_clearcut = length(z$nl) * km2,
  LF_Clearcut = z$lf[type == "Clearcut", .N] * km2, LF_Harvest = z$lf[type == "Harvest", .N] * km2, LF_Thinning = z$lf[type == "Thinning", .N] * km2,
  LF_Clearcut_Harvest_on_forest = z$lf[type %in% c("Clearcut", "Harvest") & forest, .N] * km2)))
cat("annual area (km2), P26 region at 30 m:\n"); print(ann, digits = 3)
cat("\ntotals 1999-2023 (km2):\n"); print(ann[, lapply(.SD, sum), .SDcols = -1], digits = 4)
fwrite(ann, file.path(OUT, "compare-annual.csv"))

# agreement: an NLCD event matched by LANDFIRE Clearcut/Harvest within y-2..y+1, and a LANDFIRE Clearcut/Harvest event (on forest)
# seen by NLCD within y..y+2
lfc <- rbindlist(lapply(yr, function(z) z$lf[type %in% c("Clearcut", "Harvest"), .(cell, Year = z$y, type, forest)]))
nlc <- rbindlist(lapply(yr, function(z) data.table(cell = z$nl, Year = z$y)))
m1 <- lfc[, .(cell, LY = Year)][nlc, on = "cell", allow.cartesian = TRUE][, .(hit = any(!is.na(LY) & LY >= Year - 2 & LY <= Year + 1)), by = .(cell, Year)]
m2 <- nlc[, .(cell, NY = Year)][lfc[forest == TRUE], on = "cell", allow.cartesian = TRUE][, .(hit = any(!is.na(NY) & NY >= Year & NY <= Year + 2)), by = .(cell, Year, type)]
cat(sprintf("\nNLCD clearcut pixels matched by LANDFIRE Clearcut/Harvest (y-2..y+1): %.1f%% of %.0f km2\n", 100 * mean(m1$hit), nrow(m1) * km2))
cat("LANDFIRE events on forest seen by NLCD as forest -> shrub/grass (y..y+2):\n"); print(m2[, .(km2 = .N * km2, seen_by_NLCD = sprintf("%.1f%%", 100 * mean(hit))), by = type])

# what LANDFIRE calls the NLCD events (any LANDFIRE type in y-2..y+1; first match by priority of type)
lfa <- rbindlist(lapply(yr, function(z) z$lf[, .(cell, LY = z$y, type)]))
w <- lfa[nlc, on = "cell", allow.cartesian = TRUE][, .(type = if (any(!is.na(LY) & LY >= Year - 2 & LY <= Year + 1)) paste(sort(unique(type[!is.na(LY) & LY >= Year - 2 & LY <= Year + 1])), collapse = "+") else "(none)"), by = .(cell, Year)]
cat("\nwhat LANDFIRE records on the NLCD clearcut pixels (y-2..y+1):\n"); print(w[, .(km2 = round(.N * km2, 1), share = sprintf("%.1f%%", 100 * .N / nrow(w))), by = type][order(-km2)][1:15])

# owner type and GAP status of each set
ow <- function(cells, lab) data.table(Set = lab, Owner = OWN[as.character(own[cells])], Gap = gap[cells])
o <- rbind(ow(nlc$cell, "NLCD clearcut"), ow(lfc[type == "Clearcut", cell], "LF Clearcut"), ow(lfc[type == "Harvest", cell], "LF Harvest"),
           ow(rbindlist(lapply(yr, function(z) z$lf[type == "Thinning", .(cell)]))$cell, "LF Thinning"))
cat("\nowner type (share of each set's pixels):\n"); print(dcast(o[, .N, by = .(Set, Owner)][, share := round(100 * N / sum(N), 1), by = Set], Owner ~ Set, value.var = "share", fill = 0))
cat("\nGAP status 1-3 (protected or federal multiple use) share:\n"); print(o[, .(GAP1to3 = sprintf("%.0f%%", 100 * mean(Gap %in% 1:3))), by = Set])
fwrite(o[, .N, by = .(Set, Owner, Gap)], file.path(OUT, "compare-owner.csv"))

# patch sizes (8-connected pixels of one year), ha
patch_sizes <- function(ev, nc) { if (!length(ev)) return(integer()); ev <- sort(ev); col <- (ev - 1) %% nc; a <- integer(); b <- integer()
  for (o in list(c(1, 1), c(nc - 1, -1), c(nc, 0), c(nc + 1, 1))) { j <- ev + o[1]; ok <- if (o[2] == 1) col < nc - 1 else if (o[2] == -1) col > 0 else rep(TRUE, length(ev))
    m <- match(j[ok], ev); k <- which(ok)[!is.na(m)]; a <- c(a, k); b <- c(b, m[!is.na(m)]) }
  lab <- seq_along(ev); repeat { old <- lab; x <- data.table(k = c(a, b), v = c(lab[b], lab[a]))[, .(v = min(v)), by = k]; lab[x$k] <- pmin(lab[x$k], x$v); lab <- lab[lab]; if (identical(lab, old)) break }
  as.integer(table(lab)) }
ps <- function(lab, get) { s <- unlist(lapply(yr, function(z) patch_sizes(get(z), nc))) * 0.09
  data.table(Set = lab, Patches = length(s), Median_ha = median(s), AreaWeightedMedian_ha = { o <- sort(s); o[which(cumsum(o) >= sum(o) / 2)[1]] }, SinglePixelShare = mean(s <= 0.09), Max_ha = max(s)) }
pz <- rbind(ps("NLCD clearcut", function(z) z$nl), ps("LF Clearcut", function(z) z$lf[type == "Clearcut", cell]), ps("LF Harvest", function(z) z$lf[type == "Harvest", cell]),
            ps("LF Thinning", function(z) z$lf[type == "Thinning", cell]))
cat("\npatch sizes (ha):\n"); print(pz, digits = 3); fwrite(pz, file.path(OUT, "compare-patches.csv"))
cat("DONE\n")
