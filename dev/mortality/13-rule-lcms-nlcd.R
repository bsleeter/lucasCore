# =============================================================================
# 13-rule-lcms-nlcd.R - to-do 3, phase 0: the event from LCMS and NLCD alone, year by year
# =============================================================================
# User, 2026-11-23: LCMS is the source (canopy cover and RAP set aside); 12-lcms-only.R found that LCMS's stress class together
# with NLCD moving the pixel out of forest cuts the area to about FIA's. This is that rule in the form a build would run:
#   a pixel has the event in year t when
#     it is in an eligible forest type group (--types raster on the region grid, --type-keep codes) and NLCD forest (41-43) in t-1,
#     NLCD is not forest in t (the first time; a pixel has the event once),
#     LCMS shows class 12 (Insect, Disease, or Drought Stress) or 4 (Desiccation) in at least one of t-lookback..t,
#     and no fire (MTBS 1-4), cutting or other named cause (LCMS 1,2,3,5,6,7,8,9) in t-lookback..t+1.
# So the event year is the year NLCD records the loss, which may lag the deaths.
# Prints the area by year and by forest type group, and the share of the forest clean over --fia that is flagged in those
# years (against FIA's share of stands over the 70% line). Writes <out>/rule-lcms-nlcd-300m.tif (per 300 m cell: eligible forest
# pixels at the start, then pixels flagged in each year; the form 09-placement.R reads) and rule-lcms-nlcd-by-year.csv.
# If <out>/salo-300m.tif exists (11-salo-comparison.R), prints the agreement with Salo.
# Read-only on the data home. Usage: Rscript dev/mortality/13-rule-lcms-nlcd.R <region folder> <out folder> --types=<raster>
#   [--type-keep=180,220,240,260,280,340,360,370] [--years=1985-2025] [--lookback=3] [--fia=2011-2019] [--workers=8]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(parallel) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; R <- pos[1]; OUT <- pos[2]; TY <- opt("types", NA); KEEP <- as.integer(strsplit(opt("type-keep", "180,220,240,260,280,340,360,370"), ",")[[1]])
yr <- as.integer(strsplit(opt("years", "1985-2025"), "-")[[1]]); Y <- yr[1]:yr[2]; LB <- as.integer(opt("lookback", 3)); fia <- as.integer(strsplit(opt("fia", "2011-2019"), "-")[[1]]); W <- as.integer(opt("workers", 8)); A <- 10L
f_nl <- function(k) Sys.glob(file.path(R, "land-cover/nlcd-annual", sprintf("Annual_NLCD_LndCov_%d_*.tif", k)))[1]
f_lc <- function(k) file.path(R, "disturbance/lcms", k, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", k))
f_mt <- function(k) file.path(R, "disturbance/mtbs", sprintf("mtbs_CONUS_%d.tif", k))
Y <- Y[!is.na(vapply(Y, f_nl, "")) & file.exists(f_lc(Y))]; G <- rast(f_nl(Y[1])); NC <- ncol(G); nr <- (nrow(G) %/% A) * A; nc <- (NC %/% A) * A
t0 <- Sys.time(); BL <- max(A, (ceiling(nr / (W * 6)) %/% A) * A); starts <- seq(1, nr, by = BL)
cl <- makeCluster(W); clusterExport(cl, c("R", "TY", "KEEP", "Y", "LB", "fia", "A", "NC", "nr", "nc", "BL", "f_nl", "f_lc", "f_mt"))
res <- parLapply(cl, starts, function(r0) { library(terra); library(data.table); terraOptions(progress = 0); nrw <- min(BL, nr - r0 + 1)
  rd <- function(f) { r <- rast(f); levels(r) <- NULL; coltab(r) <- NULL; as.integer(values(r, mat = FALSE, row = r0, nrows = nrw)) }
  ft <- rd(TY); col <- (seq_along(ft) - 1L) %% NC; ix <- which(ft %in% KEEP & col < nc); ncell <- (nrw / A) * (nc / A); zero <- integer(ncell)
  if (!length(ix)) return(list(by = NULL, fia = c(0, 0), agg = c(list(forest = zero), setNames(rep(list(zero), length(Y)), Y)), grp = NULL))
  g <- ft[ix]; c3 <- (((ix - 1L) %/% NC) %/% A) * (nc / A) + col[ix] %/% A + 1L; n <- length(ix)
  sst <- sbd <- rep(99L, n); done <- pend <- rep(FALSE, n); fprev <- NULL; fW <- clW <- flW <- rep(FALSE, n); by <- list(); agg <- list(); grp <- NULL
  for (k in Y) { nl <- rd(f_nl(k))[ix] %in% 41:43; l <- rd(f_lc(k))[ix]; bd <- l %in% c(1L, 2L, 3L, 5L, 6L, 7L, 8L, 9L); f <- f_mt(k); if (file.exists(f)) bd <- bd | rd(f)[ix] %in% 1:4
    sst <- ifelse(l %in% c(4L, 12L), 0L, sst + 1L); sbd <- ifelse(bd, 0L, sbd + 1L)
    if (is.null(fprev)) { agg$forest <- tabulate(c3[nl], ncell); grp <- data.table(group = g[nl])[, .(forest = .N), by = group] } else {
      hit <- pend & !bd; done[hit] <- TRUE                                       # last year's candidates, with no fire or cutting this year either
      agg[[as.character(k - 1L)]] <- tabulate(c3[hit], ncell); if (any(hit)) by[[length(by) + 1]] <- data.table(Year = k - 1L, group = g[hit])[, .(flagged = .N), by = .(Year, group)]
      if ((k - 1L) >= fia[1] && (k - 1L) <= fia[2]) flW <- flW | hit
      pend <- fprev & !nl & sst <= LB & sbd > LB & !done }
    if (k == fia[1] - 1L) { fW <- nl; clW <- rep(TRUE, n) }; if (k >= fia[1] - LB && k <= fia[2] + 1L) clW <- clW & !bd
    fprev <- nl }
  agg[[as.character(max(Y))]] <- zero
  list(by = rbindlist(by), fia = c(sum(fW & clW), sum(flW & fW & clW)), agg = agg, grp = grp) })
stopCluster(cl); cat(sprintf("TIME the LCMS and NLCD rule over %d years, %d x %d pixels, %d workers: %.1f min\n", length(Y), nrow(G), NC, W, as.numeric(Sys.time() - t0, units = "mins")))
by <- rbindlist(lapply(res, `[[`, "by"))[, .(km2 = sum(flagged) * 9e-4), by = .(Year, group)]; grp <- rbindlist(lapply(res, `[[`, "grp"))[, .(forest_km2 = sum(forest) * 9e-4), by = group][order(-forest_km2)]
fwrite(by, file.path(OUT, "rule-lcms-nlcd-by-year.csv")); options(width = 250)
lay <- c("forest", as.character(Y[-length(Y)])); rr <- rast(nrows = nr / A, ncols = nc / A, xmin = xmin(G), xmax = xmin(G) + nc * 30, ymax = ymax(G), ymin = ymax(G) - nr * 30, crs = crs(G), nlyrs = length(lay))
for (i in seq_along(lay)) values(rr[[i]]) <- unlist(lapply(res, function(z) z$agg[[lay[i]]])); names(rr) <- lay
writeRaster(rr, file.path(OUT, "rule-lcms-nlcd-300m.tif"), datatype = "INT2U", gdal = "COMPRESS=DEFLATE", overwrite = TRUE)
cat(sprintf("\nRegion %s. Event = eligible forest leaves NLCD forest in year t, LCMS stress class within %d years before, no fire or cutting. Eligible forest in %d: %.0f km2\n", basename(R), LB, Y[1], sum(grp$forest_km2)))
cat("\neligible forest by type group (km2), and the share of it flagged over the whole record:\n"); print(merge(grp, by[, .(flagged_km2 = sum(km2)), by = group], all.x = TRUE)[, `:=`(forest_km2 = round(forest_km2), flagged_km2 = round(flagged_km2, 1), flagged_pct = round(100 * flagged_km2 / forest_km2, 2))][order(-forest_km2)])
cat("\nflagged area by year (km2), all groups and by group:\n"); wd <- dcast(by, Year ~ group, value.var = "km2", fill = 0); wd[, all := rowSums(.SD), .SDcols = -1]; setcolorder(wd, c("Year", "all")); print(wd[, lapply(.SD, round, 1)], nrows = 60)
ff <- colSums(do.call(rbind, lapply(res, `[[`, "fia")))
cat(sprintf("\nforest clean over %d-%d: %.0f km2; flagged in those years: %.0f km2 = %.2f%%\n", fia[1], fia[2], ff[1] * 9e-4, ff[2] * 9e-4, 100 * ff[2] / ff[1]))
sf <- file.path(OUT, "salo-300m.tif")
if (file.exists(sf)) { s <- rast(sf)[[1]]; yy <- as.integer(names(rr)[-1]); cc <- function(x, y) sprintf("%.2f (Spearman %.2f)", cor(x, y), cor(x, y, method = "spearman"))
  for (wn in list(2012:2018, 2013:2021)) { d <- data.table(forest = values(rr[[1]])[, 1], fl = values(sum(rr[[1 + which(yy %in% wn)]]))[, 1], salo = values(s)[, 1], row = rowFromCell(rr, 1:ncell(rr)), col = colFromCell(rr, 1:ncell(rr)))[forest >= 50 & !is.na(salo)]
    b <- d[, .(forest = sum(forest), fl = sum(fl), salo = weighted.mean(salo, forest)), by = .(r = (row - 1) %/% 2, c = (col - 1) %/% 2)][forest >= 200]
    cat(sprintf("\nagainst Salo, events of %d-%d: flagged %.2f%% of eligible forest; correlation of the flagged share with Salo's dead share at 300 m %s, at 600 m %s\n", min(wn), max(wn), 100 * sum(d$fl) / sum(d$forest), cc(d$fl / d$forest, d$salo), cc(b$fl / b$forest, b$salo)))
    print(d[, .(cells = .N, flagged_pct = round(100 * sum(fl) / sum(forest), 2)), by = .(salo_share = cut(salo, c(-0.001, 0, 0.02, 0.05, 0.1, 0.2, 1), labels = c("0", "0-2%", "2-5%", "5-10%", "10-20%", "over 20%")))][order(salo_share)]) } }
