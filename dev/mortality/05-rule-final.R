# =============================================================================
# 05-rule-final.R - to-do 3, phase 0: the map rule in the form stage 6 would use, by year, over one region
# =============================================================================
# After phase 0 (2026-11-22): tree canopy cover falls slowly, so the loss is measured against the canopy --span (5) years before,
# and the line is set by region so the flagged area matches FIA's share of stands over 70% killed (user: "Yes, match to FIA").
# The rule for a 30 m pixel in year y, for each --lines value:
#   forest (NLCD 41-43) in y-span with canopy >= --floor then; (canopy[y-span] - canopy[y]) / canopy[y-span] >= line;
#   no fire or cutting (MTBS 1-4; LCMS 6, 7, 8, 9) and no other named LCMS cause (1, 2, 3, 5) from y-span to y+1;
#   the event year is the FIRST year the line is crossed: a pixel is flagged once in the run (it leaves the forest's live pool).
# Prints, per line: area by year, and the share of the forest that was clean over --fia (2011-2019, the years FIA's die-off
# remeasurements span in the southern Sierra) flagged in those years, to set beside FIA's share of stands over the line.
# The region's rasters share one grid (same extent and cell; only the projection's name differs), so values are read in row blocks.
# Read-only. Usage: Rscript dev/mortality/05-rule-final.R <region folder> <out folder> [--years=1990-2022] [--span=5] [--floor=20]
#                     [--lines=0.3,0.35,0.4,0.45,0.5,0.6] [--fia=2011-2019] [--workers=12]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(parallel) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; R <- pos[1]; OUT <- pos[2]; dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
yr <- as.integer(strsplit(opt("years", "1990-2022"), "-")[[1]]); YRS <- yr[1]:yr[2]; SPAN <- as.integer(opt("span", 5)); FLOOR <- as.numeric(opt("floor", 20))
LINES <- as.numeric(strsplit(opt("lines", "0.3,0.35,0.4,0.45,0.5,0.6"), ",")[[1]]); fia <- as.integer(strsplit(opt("fia", "2011-2019"), "-")[[1]]); W <- as.integer(opt("workers", 12))
f_nl <- function(k) Sys.glob(file.path(R, "land-cover/nlcd-annual", sprintf("Annual_NLCD_LndCov_%d_*.tif", k)))[1]
f_tc <- function(k) file.path(R, "land-cover/tree-canopy", sprintf("science_tcc_conus_%d.tif", k))
f_lc <- function(k) file.path(R, "disturbance/lcms", k, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", k))
f_mt <- function(k) file.path(R, "disturbance/mtbs", sprintf("mtbs_CONUS_%d.tif", k))
G <- rast(f_nl(YRS[1])); for (f in c(f_tc(YRS[1]), f_lc(YRS[1]))) { r <- rast(f); stopifnot(all(dim(r) == dim(G)), isTRUE(all.equal(as.vector(ext(r)), as.vector(ext(G))))) }
ALL <- (min(YRS) - SPAN):(max(YRS) + 1); nr <- nrow(G); blocks <- split(seq_len(nr), cut(seq_len(nr), W * 4, labels = FALSE))
cl <- makeCluster(W); clusterExport(cl, c("R", "YRS", "SPAN", "FLOOR", "LINES", "ALL", "fia", "f_nl", "f_tc", "f_lc", "f_mt"))
res <- parLapply(cl, blocks, function(rows) { library(terra); library(data.table); terraOptions(progress = 0)
  rd <- function(f) { r <- rast(f); levels(r) <- NULL; coltab(r) <- NULL; as.integer(values(r, mat = FALSE, row = rows[1], nrows = length(rows))) }
  n <- length(rd(f_nl(YRS[1]))); ix <- function(k) match(k, ALL)
  tc <- vapply(ALL, function(k) { v <- rd(f_tc(k)); v[v > 100L] <- NA_integer_; v }, integer(n))
  bad <- vapply(ALL, function(k) { b <- rd(f_lc(k)) %in% c(1L, 2L, 3L, 5L, 6L, 7L, 8L, 9L); f <- f_mt(k); if (file.exists(f)) b <- b | rd(f) %in% 1:4; b }, logical(n))
  done <- matrix(FALSE, n, length(LINES)); out <- list()
  # the forest that was clean over the FIA years, for the share flagged in them
  f0 <- rd(f_nl(fia[1] - SPAN)) %in% 41:43 & !is.na(tc[, ix(fia[1] - SPAN)]) & tc[, ix(fia[1] - SPAN)] >= FLOOR & rowSums(bad[, ix((fia[1] - SPAN):(fia[2] + 1)), drop = FALSE]) == 0
  fl <- matrix(FALSE, n, length(LINES))
  for (y in YRS) { t0 <- tc[, ix(y - SPAN)]; t1 <- tc[, ix(y)]
    ok <- rd(f_nl(y - SPAN)) %in% 41:43 & !is.na(t0) & t0 >= FLOOR & !is.na(t1) & rowSums(bad[, ix((y - SPAN):(y + 1)), drop = FALSE]) == 0
    rel <- (t0 - t1) / t0
    for (j in seq_along(LINES)) { hit <- ok & rel >= LINES[j] & !done[, j]; done[hit, j] <- TRUE
      if (y >= fia[1] && y <= fia[2]) fl[, j] <- fl[, j] | (hit & f0)
      out[[length(out) + 1]] <- data.table(Year = y, line = LINES[j], eligible = sum(ok & !done[, j]) + sum(hit), flagged = sum(hit)) } }
  list(by = rbindlist(out), fia = data.table(line = LINES, forest = sum(f0), flagged = colSums(fl))) })
stopCluster(cl)
by <- rbindlist(lapply(res, `[[`, "by"))[, .(eligible_km2 = sum(eligible) * 9e-4, flagged_km2 = sum(flagged) * 9e-4), by = .(Year, line)]
fi <- rbindlist(lapply(res, `[[`, "fia"))[, .(forest_km2 = sum(forest) * 9e-4, flagged_km2 = sum(flagged) * 9e-4), by = line][, flagged_pct := round(100 * flagged_km2 / forest_km2, 2)]
fwrite(by, file.path(OUT, "rule-final-by-year.csv")); fwrite(fi, file.path(OUT, "rule-final-fia-years.csv")); options(width = 250)
cat(sprintf("Region %s. Canopy loss against %d years before, first crossing only; forest with canopy >= %g%%, no fire, cutting or other named cause from y-%d to y+1\n", basename(R), SPAN, FLOOR, SPAN))
cat("\nflagged area by year (km2), by canopy-loss line:\n"); print(dcast(by, Year ~ line, value.var = "flagged_km2")[, lapply(.SD, round, 1)], nrows = 60)
cat("\neligible forest (km2) at the lowest line:\n"); print(by[line == min(line), .(Year, eligible_km2 = round(eligible_km2))][Year %in% c(min(Year), 2000, 2005, 2010, 2015, 2020, max(Year))])
cat(sprintf("\nshare of the forest clean over %d-%d that is flagged in those years (to set beside FIA's share of stands over 70%% killed):\n", fia[1], fia[2])); print(fi[, lapply(.SD, round, 2)])
