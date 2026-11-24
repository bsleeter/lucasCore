# =============================================================================
# 08-rule-combined.R - to-do 3, phase 0: the map rule on canopy loss and RAP tree production together, at 30 m, timed
# =============================================================================
# 2026-11-22: canopy cover placed the Colorado die-off poorly and RAP tree production (RapNppFolder band 4) did better there; the
# two together were near the better one in both test pyromes (07-rap-signal.R, at 1 km around FIA plots). The user's worry is
# build time, so this runs the combined rule at 30 m the way a build would and prints how long each step takes:
#   step 1 (once per region, cached in <out>/rap-tree): each year's RAP tree band put on the region's 30 m grid, and its mean
#           over the region's forest. RAP is 4 bands in longitude/latitude, so this is the costly part.
#   step 2: the rule, by row blocks. For a pixel in year y:
#             canopy loss  cl = (canopy[y-span] - canopy[y]) / canopy[y-span]
#             production   n(t) = mean RAP tree NPP of t-1, t, t+1, divided by the region's forest mean of the same years
#             production loss nl = 1 - n(y) / n(y-span), held within -1..1 (0 where there was almost no tree production)
#             score = (cl + W * nl) / 2, W = --weight (0.35: one standard deviation of canopy loss per one of production loss,
#                     from the FIA plot neighbourhoods of both pyromes), so the score reads in canopy-loss units
#           forest (NLCD 41-43) at y-span with canopy >= --floor; no fire, cutting or other named cause y-span..y+1; the event
#           year is the first year the score crosses the line. --canopy-only=TRUE scores on cl alone (the 05 rule) for comparison.
# Prints area by year per line and the share of the forest clean over --fia flagged in those years (to match FIA's share of
# stands over 70%). With --write=<line> also writes <out>/rule-combined-300m.tif: per 300 m cell, forest pixels and pixels
# flagged in each year at that line.
# Read-only on the data home. Usage: Rscript dev/mortality/08-rule-combined.R <region folder> <out folder> [--years=2000-2022]
#   [--types=<type raster on the grid> --type-keep=220,260 --suffix=-conifer]  (eligible forest; default all)
#   [--span=5] [--floor=20] [--weight=0.35] [--lines=0.15,0.2,0.25,0.3,0.35,0.4,0.5] [--fia=2011-2019] [--workers=8] [--write=0.3] [--canopy-only=FALSE]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(parallel) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; R <- pos[1]; OUT <- pos[2]; RT <- file.path(OUT, "rap-tree"); dir.create(RT, recursive = TRUE, showWarnings = FALSE)
yr <- as.integer(strsplit(opt("years", "2000-2022"), "-")[[1]]); YRS <- yr[1]:yr[2]; SPAN <- as.integer(opt("span", 5)); FLOOR <- as.numeric(opt("floor", 20)); WT <- as.numeric(opt("weight", 0.35))
LINES <- as.numeric(strsplit(opt("lines", "0.15,0.2,0.25,0.3,0.35,0.4,0.5"), ",")[[1]]); fia <- as.integer(strsplit(opt("fia", "2011-2019"), "-")[[1]]); W <- as.integer(opt("workers", 8))
WR <- as.numeric(opt("write", NA)); CO <- as.logical(opt("canopy-only", "FALSE")); A <- 10L
ST <- as.logical(opt("lcms-stress", "FALSE"))   # require the LCMS stress class (12 or 4) in at least one of y-span..y
TY <- opt("types", NA); KEEP <- as.integer(strsplit(opt("type-keep", "0"), ",")[[1]]); SUF <- opt("suffix", "")   # eligible forest: a type raster on the region grid and the codes kept
f_nl <- function(k) Sys.glob(file.path(R, "land-cover/nlcd-annual", sprintf("Annual_NLCD_LndCov_%d_*.tif", k)))[1]
f_tc <- function(k) file.path(R, "land-cover/tree-canopy", sprintf("science_tcc_conus_%d.tif", k))
f_lc <- function(k) file.path(R, "disturbance/lcms", k, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", k))
f_mt <- function(k) file.path(R, "disturbance/mtbs", sprintf("mtbs_CONUS_%d.tif", k))
f_rp <- function(k) file.path(R, "land-cover/rap-npp", sprintf("rap-npp-v3-%d.tif", k)); f_rt <- function(k) file.path(RT, sprintf("rap-tree-%d.tif", k))
G <- rast(f_nl(YRS[1])); levels(G) <- NULL; coltab(G) <- NULL
ALL <- (min(YRS) - SPAN):(max(YRS) + 1); NY <- (min(YRS) - SPAN - 1):(max(YRS) + 1)   # canopy and cause years; production years
tm <- function(label, t0) cat(sprintf("TIME %s: %.1f min\n", label, as.numeric(Sys.time() - t0, units = "mins")))

# ---- step 1: RAP tree production on the region's grid, once ------------------------------------------------------------
t1 <- Sys.time(); fm <- file.path(RT, "forest-mask.tif"); mf <- file.path(RT, "forest-means.csv")
if (!CO) {
  if (!file.exists(fm)) { tc0 <- rast(f_tc(min(YRS) - SPAN)); crs(tc0) <- crs(G); writeRaster(ifel((G >= 41) & (G <= 43) & (tc0 >= FLOOR) & (tc0 <= 100), 1, NA), fm, datatype = "INT1U", gdal = "COMPRESS=DEFLATE", overwrite = TRUE) }
  need <- NY[!file.exists(f_rt(NY))]
  if (length(need)) { cl <- makeCluster(min(W, length(need))); clusterExport(cl, c("f_rp", "f_rt", "f_nl", "R", "RT", "YRS", "fm"))
    parLapply(cl, need, function(k) { library(terra); terraOptions(progress = 0, memfrac = 0.08); G <- rast(f_nl(YRS[1])); r <- rast(f_rp(k))[[4]]; NAflag(r) <- 65535
      project(r, G, method = "bilinear", filename = f_rt(k), datatype = "INT2U", gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2"), overwrite = TRUE); NULL }); stopCluster(cl) }
  have <- if (file.exists(mf)) fread(mf) else data.table(year = integer(), mean = numeric()); todo <- setdiff(NY, have$year)
  if (length(todo)) { cl <- makeCluster(min(W, length(todo))); clusterExport(cl, c("f_rt", "fm", "RT"))
    mm <- parLapply(cl, todo, function(k) { library(terra); terraOptions(progress = 0, memfrac = 0.08); global(mask(rast(f_rt(k)), rast(fm)), "mean", na.rm = TRUE)[1, 1] }); stopCluster(cl)
    have <- rbind(have, data.table(year = todo, mean = unlist(mm)))[order(year)]; fwrite(have, mf) }
  M <- have$mean[match(NY, have$year)]; M3 <- (M + c(NA, head(M, -1)) + c(M[-1], NA)) / 3; names(M3) <- NY   # region forest mean of t-1, t, t+1
  tm(sprintf("step 1, RAP tree band to the 30 m grid (%d years new, %d cached), %.1f GB", length(need), length(NY) - length(need), sum(file.size(f_rt(NY))) / 2^30), t1)
} else M3 <- NULL

# ---- step 2: the rule ---------------------------------------------------------------------------------------------------
t2 <- Sys.time(); nr <- (nrow(G) %/% A) * A; nc <- (ncol(G) %/% A) * A; BL <- max(A, (ceiling(nr / (W * 6)) %/% A) * A); starts <- seq(1, nr, by = BL)
cl <- makeCluster(W); clusterExport(cl, c("R", "YRS", "SPAN", "FLOOR", "LINES", "ALL", "NY", "fia", "WT", "WR", "CO", "A", "M3", "nr", "nc", "BL", "f_nl", "f_tc", "f_lc", "f_mt", "f_rt", "RT", "TY", "KEEP", "ST"))
res <- parLapply(cl, starts, function(r0) { library(terra); library(data.table); terraOptions(progress = 0); nrw <- min(BL, nr - r0 + 1)
  rd <- function(f) { r <- rast(f); levels(r) <- NULL; coltab(r) <- NULL; as.integer(values(r, mat = FALSE, row = r0, nrows = nrw)) }
  n <- length(rd(f_nl(YRS[1]))); ix <- function(k) match(k, ALL); ftv <- if (is.na(TY)) rep(0L, n) else rd(TY); el <- if (is.na(TY)) rep(TRUE, n) else ftv %in% KEEP; grp <- list(); keep <- rep(c(rep(TRUE, nc), rep(FALSE, n / nrw - nc)), nrw)
  tc <- vapply(ALL, function(k) { v <- rd(f_tc(k)); v[v > 100L] <- NA_integer_; v }, integer(n))
  bad <- vapply(ALL, function(k) { b <- rd(f_lc(k)) %in% c(1L, 2L, 3L, 5L, 6L, 7L, 8L, 9L); f <- f_mt(k); if (file.exists(f)) b <- b | rd(f) %in% 1:4; b }, logical(n))
  st <- if (ST) vapply(ALL, function(k) rd(f_lc(k)) %in% c(4L, 12L), logical(n)) else NULL
  if (!CO) { np <- vapply(NY, function(k) rd(f_rt(k)), integer(n)); jx <- function(k) match(k, NY)
    n3 <- function(k) (np[, jx(k - 1)] + np[, jx(k)] + np[, jx(k + 1)]) / 3 / M3[as.character(k)] }
  done <- matrix(FALSE, n, length(LINES)); out <- list(); fl <- matrix(FALSE, n, length(LINES))
  f0 <- el & rd(f_nl(fia[1] - SPAN)) %in% 41:43 & !is.na(tc[, ix(fia[1] - SPAN)]) & tc[, ix(fia[1] - SPAN)] >= FLOOR & rowSums(bad[, ix((fia[1] - SPAN):(fia[2] + 1)), drop = FALSE]) == 0
  agg <- NULL; jw <- if (is.na(WR)) NA else which.min(abs(LINES - WR))
  ag <- function(v) { m <- matrix(v[keep] + 0, nrow = nrw, byrow = TRUE); x <- rowsum(m, rep(seq_len(nrw / A), each = A)); as.vector(t(t(rowsum(t(x), rep(seq_len(nc / A), each = A))))) }
  if (!is.na(jw)) agg <- list(forest = ag(el & rd(f_nl(min(YRS) - SPAN)) %in% 41:43 & !is.na(tc[, 1]) & tc[, 1] >= FLOOR))
  for (y in YRS) { t0 <- tc[, ix(y - SPAN)]; t1 <- tc[, ix(y)]
    ok <- el & rd(f_nl(y - SPAN)) %in% 41:43 & !is.na(t0) & t0 >= FLOOR & !is.na(t1) & rowSums(bad[, ix((y - SPAN):(y + 1)), drop = FALSE]) == 0; base <- ok; if (ST) ok <- ok & rowSums(st[, ix((y - SPAN):y), drop = FALSE]) > 0
    s <- (t0 - t1) / t0
    if (!CO) { a0 <- n3(y - SPAN); a1 <- n3(y); nl <- ifelse(is.na(a0) | is.na(a1) | a0 < 0.05, 0, pmax(-1, pmin(1, 1 - a1 / a0))); s <- (s + WT * nl) / 2 }
    for (j in seq_along(LINES)) { hit <- ok & s >= LINES[j] & !done[, j]; done[hit, j] <- TRUE
      if (y >= fia[1] && y <= fia[2]) fl[, j] <- fl[, j] | (hit & f0)
      if (!is.na(jw) && j == jw) { agg[[as.character(y)]] <- ag(hit)   # and, by forest type group, the forest still open to the event and what was flagged
        grp[[length(grp) + 1]] <- data.table(Year = y, group = ftv[base], hit = hit[base], open = !done[base, j] | hit[base])[, .(forest = sum(open), flagged = sum(hit)), by = .(Year, group)] }
      out[[length(out) + 1]] <- data.table(Year = y, line = LINES[j], flagged = sum(hit)) } }
  list(by = rbindlist(out), fia = data.table(line = LINES, forest = sum(f0), flagged = colSums(fl)), agg = agg, rows = nrw / A, grp = rbindlist(grp)) })
stopCluster(cl)
by <- rbindlist(lapply(res, `[[`, "by"))[, .(flagged_km2 = sum(flagged) * 9e-4), by = .(Year, line)]
fi <- rbindlist(lapply(res, `[[`, "fia"))[, .(forest_km2 = sum(forest) * 9e-4, flagged_km2 = sum(flagged) * 9e-4), by = line][, flagged_pct := round(100 * flagged_km2 / forest_km2, 2)]
tag <- paste0(if (CO) "canopy" else "combined", SUF)
if (!is.na(WR)) fwrite(rbindlist(lapply(res, `[[`, "grp"))[, .(forest_km2 = sum(forest) * 9e-4, flagged_km2 = sum(flagged) * 9e-4), by = .(Year, group)][order(group, Year)], file.path(OUT, sprintf("rule-%s-by-group.csv", tag)))
fwrite(by, file.path(OUT, sprintf("rule-%s-by-year.csv", tag))); fwrite(fi, file.path(OUT, sprintf("rule-%s-fia-years.csv", tag)))
if (!is.na(WR)) { lay <- names(res[[1]]$agg); rr <- rast(nrows = nr / A, ncols = nc / A, xmin = xmin(G), xmax = xmin(G) + nc * 30, ymax = ymax(G), ymin = ymax(G) - nr * 30, crs = crs(G), nlyrs = length(lay))
  for (i in seq_along(lay)) values(rr[[i]]) <- unlist(lapply(res, function(z) z$agg[[lay[i]]])); names(rr) <- lay
  writeRaster(rr, file.path(OUT, sprintf("rule-%s-300m.tif", tag)), datatype = "INT2U", gdal = "COMPRESS=DEFLATE", overwrite = TRUE) }
tm(sprintf("step 2, the %s rule over %d years, %d x %d pixels, %d workers", tag, length(YRS), nrow(G), ncol(G), W), t2)
options(width = 250)
cat(sprintf("\nRegion %s, %s rule (weight %g). First crossing only; lead-in from %d\n", basename(R), tag, WT, min(YRS)))
cat("\nflagged area by year (km2), by line:\n"); print(dcast(by, Year ~ line, value.var = "flagged_km2")[, lapply(.SD, round, 1)], nrows = 60)
cat(sprintf("\nshare of the forest clean over %d-%d flagged in those years:\n", fia[1], fia[2])); print(fi[, lapply(.SD, round, 2)])
