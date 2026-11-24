# =============================================================================
# 17-rule-national.R - to-do 3: the decided event rule (canopy loss inside the LCMS footprint) over all of CONUS, by tile
# =============================================================================
# User, 2026-11-23: the canopy-loss line is calibrated by ecodivision, from the national copies in the data home. This runs the
# rule of 08-rule-combined.R (--canopy-only --lcms-stress) on the national 30 m grids, at a range of lines, and tallies per
# ecodivision, forest type group, year and line: the eligible forest still open to the event and the pixels flagged.
# A 30 m pixel has the event in year y when
#   1. its forest type group is a conifer group (codes 100-399; pinyon/juniper 180 is tallied apart by its own code)
#   2. NLCD is forest (41-43) and tree canopy >= --floor at y - span
#   3. LCMS shows class 12 (insect, disease or drought stress) or 4 (desiccation) in any year y - span .. y
#   4. canopy loss against y - span is at or over the line
#   5. no MTBS severity 1-4 and no LCMS 1,2,3,5,6,7,8,9 in y - span .. y + 1
#   6. it is the pixel's first crossing of that line
# All the national grids share one 30 m lattice (origin 15,15), so tiles are read by window with no resampling. Tiles of
# --tile pixels square; a tile with no conifer pixel is skipped. Each tile's tally is saved in <out>/tiles so a stopped run resumes.
# With --lines-by=<csv of ecodiv,line> the line is the ecodivision's own (one line per pixel) and <out>/rule-national-300m.tif
# is written: per 300 m cell, eligible forest at the first year and pixels flagged in each year.
# Read-only on the data home. Usage: Rscript dev/mortality/17-rule-national.R <data home> <out folder> [--years=1990-2022]
#   [--lines=0.1,0.15,...,0.6] [--lines-by=<csv> [--pj-line=0.47]] [--span=5] [--floor=20] [--tile=3000] [--workers=32] [--only=<xmin,xmax,ymin,ymax>]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(parallel); library(sf) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; H <- pos[1]; OUT <- pos[2]; TD <- file.path(OUT, "tiles"); dir.create(TD, recursive = TRUE, showWarnings = FALSE)
yr <- as.integer(strsplit(opt("years", "1990-2022"), "-")[[1]]); YRS <- yr[1]:yr[2]; SPAN <- as.integer(opt("span", 5)); FLOOR <- as.integer(opt("floor", 20))
LINES <- as.numeric(strsplit(opt("lines", "0.1,0.15,0.2,0.25,0.3,0.35,0.4,0.45,0.5,0.55,0.6"), ",")[[1]]); LB <- opt("lines-by", NA)
TS <- as.integer(opt("tile", 3000)); W <- as.integer(opt("workers", 32)); ONLY <- opt("only", NA); A <- 10L; ALL <- (min(YRS) - SPAN):(max(YRS) + 1)
PJL <- as.numeric(opt("pj-line", NA))   # with --lines-by: the line of pinyon/juniper (group 180), in the ecodivisions that have a line
f_tc <- function(k) file.path(H, "land-cover/tree-canopy", sprintf("science_tcc_conus_%d.tif", k))
f_lc <- function(k) Sys.glob(file.path(H, "disturbance/lcms", k, "LCMS_CONUS_*_Change_*.tif"))[1]
HN <- opt("nlcd-home", H)   # test only: NLCD and MTBS from a region folder
f_nl <- function(k) Sys.glob(file.path(HN, "land-cover/nlcd-annual", sprintf("Annual_NLCD_LndCov_%d_*.tif", k)))[1]
f_mt <- function(k) Sys.glob(file.path(HN, "disturbance/mtbs", sprintf("mtbs_CONUS_%d*.tif", k)))[1]
FT <- Sys.glob(file.path(H, "land-cover/forest-type-groups", "*_ForestType.tif"))
FILES <- list(tc = vapply(ALL, f_tc, ""), lc = vapply(ALL, f_lc, ""), nl = vapply(YRS - SPAN, f_nl, ""), mt = vapply(ALL, f_mt, ""))
miss <- c(FILES$tc[!file.exists(FILES$tc)], if (anyNA(FILES$lc)) sprintf("LCMS %s", paste(ALL[is.na(FILES$lc)], collapse = " ")), if (anyNA(FILES$nl)) sprintf("NLCD %s", paste((YRS - SPAN)[is.na(FILES$nl)], collapse = " ")))
if (length(miss)) stop("missing inputs: ", paste(miss, collapse = "; "))
cat(sprintf("years %d-%d; canopy and causes %d-%d; MTBS years found %d of %d (missing: %s); forest type tiles %d\n", min(YRS), max(YRS), min(ALL), max(ALL), sum(!is.na(FILES$mt)), length(ALL), paste(ALL[is.na(FILES$mt)], collapse = " "), length(FT)))
G <- rast(FILES$tc[1]); gx <- xmin(G); gy <- ymax(G)
eco <- st_transform(read_sf(opt("ecodivisions", "F:/lucasCore/defaults/strata/ecodivisions/EcoDivisions_Dissolve.shp")), crs(G)); EC <- unique(data.table(ecodiv = eco$ecodiv, StrtmId = as.integer(eco$StrtmId)))
ECOF <- file.path(OUT, "ecodiv.gpkg"); if (!file.exists(ECOF)) write_sf(eco[, "StrtmId"], ECOF)
PL <- if (is.na(LB)) NULL else merge(fread(LB), EC, by = "ecodiv")[, .(StrtmId, line)]
tiles <- CJ(r = seq(0, nrow(G) - 1, by = TS), c = seq(0, ncol(G) - 1, by = TS)); tiles[, `:=`(nr = pmin(TS, (nrow(G) %/% A) * A - r), nc = pmin(TS, (ncol(G) %/% A) * A - c))]; tiles <- tiles[nr > 0 & nc > 0]
tiles[, `:=`(x0 = gx + c * 30, x1 = gx + (c + nc) * 30, y1 = gy - r * 30, y0 = gy - (r + nr) * 30, id = sprintf("r%06d-c%06d", r, c))]
if (!is.na(ONLY)) { o <- as.numeric(strsplit(ONLY, ",")[[1]]); tiles <- tiles[x1 > o[1] & x0 < o[2] & y1 > o[3] & y0 < o[4]] }
tag <- if (is.na(LB)) "lines" else "fitted"; tf <- function(id) file.path(TD, sprintf("%s-%s.rds", tag, id)); todo <- tiles[!file.exists(tf(id))]
cat(sprintf("%d tiles of %d px (%d already done); %d workers\n", nrow(tiles), TS, nrow(tiles) - nrow(todo), W)); t0 <- Sys.time()

one <- function(i) { library(terra); library(data.table); terraOptions(progress = 0); t <- todo[i]; e <- ext(t$x0, t$x1, t$y0, t$y1); n <- t$nr * t$nc
  # a window of any national grid on the tile's cells (NA outside the file's extent)
  rd <- function(f, idx = NULL) { r <- rast(f); ie <- intersect(ext(r), e); v <- rep(NA_integer_, n); if (is.null(ie) || xmax(ie) - xmin(ie) < 30 || ymax(ie) - ymin(ie) < 30) return(if (is.null(idx)) v else v[idx])
    c0 <- round((xmin(ie) - t$x0) / 30); r0 <- round((t$y1 - ymax(ie)) / 30); wc <- round((xmax(ie) - xmin(ie)) / 30); wr <- round((ymax(ie) - ymin(ie)) / 30)
    x <- as.integer(values(r, mat = FALSE, row = round((ymax(r) - ymax(ie)) / 30) + 1, nrows = wr, col = round((xmin(ie) - xmin(r)) / 30) + 1, ncols = wc))
    if (wc == t$nc && wr == t$nr) v <- x else v[rep((r0 + seq_len(wr) - 1) * t$nc, each = wc) + c0 + seq_len(wc)] <- x
    if (is.null(idx)) v else v[idx] }
  # the regional tiles are overlapping rectangles filled with 65535 outside their own region (no nodata flag set): a pixel takes the
  # first tile that has a type for it. (2026-11-23: the first national run let 65535 stand, which blanked the overlaps.)
  ftv <- rep(NA_integer_, n); for (f in FT) { v <- rd(f); v[v == 65535L | v == 0L] <- NA_integer_; k <- is.na(ftv); ftv[k] <- v[k] }
  cf <- which(!is.na(ftv) & ftv >= 100L & ftv < 400L); if (!length(cf)) { saveRDS(NULL, tf(t$id)); return(0L) }
  g <- ftv[cf]; rm(ftv); m <- length(cf); ix <- function(k) match(k, ALL)
  ev0 <- crop(vect(ECOF), e); if (!nrow(ev0)) { saveRDS(NULL, tf(t$id)); return(0L) }   # conifer pixels outside every ecodivision (across the border)
  er <- rasterize(ev0, rast(e, nrows = t$nr / A, ncols = t$nc / A, crs = crs(G)), "StrtmId", touches = TRUE)   # ecodivision at 300 m, spread to the 30 m cells
  ev <- as.integer(values(er, mat = FALSE)); ed <- ev[((cf - 1L) %/% t$nc %/% A) * (t$nc / A) + ((cf - 1L) %% t$nc) %/% A + 1L]
  bad <- matrix(FALSE, m, length(ALL)); st <- matrix(FALSE, m, length(ALL)); tc <- matrix(NA_integer_, m, length(ALL))
  for (j in seq_along(ALL)) { v <- rd(FILES$lc[j], cf); bad[, j] <- v %in% c(1L, 2L, 3L, 5L, 6L, 7L, 8L, 9L); st[, j] <- v %in% c(4L, 12L)
    if (!is.na(FILES$mt[j])) bad[, j] <- bad[, j] | rd(FILES$mt[j], cf) %in% 1:4
    v <- rd(FILES$tc[j], cf); v[v > 100L] <- NA_integer_; tc[, j] <- v }
  ln <- if (is.null(PL)) LINES else NA_real_; pl <- if (is.null(PL)) NULL else PL$line[match(ed, PL$StrtmId)]
  if (!is.null(pl) && !is.na(PJL)) pl[g == 180L & !is.na(pl)] <- PJL   # pinyon/juniper takes its own line wherever the event applies
  done <- matrix(FALSE, m, length(ln)); out <- list(); agg <- NULL
  ag <- function(v) { z <- integer(n); z[cf] <- as.integer(v); x <- rowsum(matrix(z, nrow = t$nr, byrow = TRUE), rep(seq_len(t$nr / A), each = A)); as.vector(t(t(rowsum(t(x), rep(seq_len(t$nc / A), each = A))))) }
  for (y in YRS) { t0 <- tc[, ix(y - SPAN)]; t1 <- tc[, ix(y)]
    base <- rd(FILES$nl[match(y - SPAN, YRS - SPAN)], cf) %in% 41:43 & !is.na(t0) & t0 >= FLOOR & !is.na(t1) & !is.na(ed) & rowSums(bad[, ix((y - SPAN):(y + 1)), drop = FALSE]) == 0
    if (!is.null(PL) && y == YRS[1]) agg <- list(forest = ag(base))
    ok <- base & rowSums(st[, ix((y - SPAN):y), drop = FALSE]) > 0; s <- (t0 - t1) / t0
    for (j in seq_along(ln)) { hit <- ok & !done[, j] & s >= (if (is.null(PL)) ln[j] else pl); hit[is.na(hit)] <- FALSE; open <- base & (!done[, j] | hit); done[hit, j] <- TRUE
      if (!is.null(PL)) agg[[as.character(y)]] <- ag(hit)
      out[[length(out) + 1]] <- data.table(Year = y, line = ln[j], StrtmId = ed[open], group = g[open], hit = hit[open])[, .(forest = .N, flagged = sum(hit)), by = .(Year, line, StrtmId, group)] } }
  saveRDS(list(tab = rbindlist(out), agg = agg, tile = t), tf(t$id)); m }
if (nrow(todo)) { cl <- makeCluster(min(W, nrow(todo))); clusterExport(cl, c("todo", "PJL", "FILES", "FT", "ALL", "YRS", "SPAN", "FLOOR", "LINES", "PL", "A", "ECOF", "tf", "TD", "tag", "G"))
  # the SpatRaster G cannot cross to a worker: each takes its coordinate system from the canopy file
  clusterEvalQ(cl, { library(terra); G <- rast(FILES$tc[1]); NULL }); np <- unlist(clusterApplyLB(cl, sample(nrow(todo)), one)); stopCluster(cl)
  cat(sprintf("TIME %d tiles, %.1f million conifer pixels: %.1f min\n", nrow(todo), sum(np) / 1e6, as.numeric(Sys.time() - t0, units = "mins"))) }
res <- lapply(tf(tiles$id), readRDS); res <- res[!vapply(res, is.null, TRUE)]
tab <- rbindlist(lapply(res, `[[`, "tab"))[, .(forest_km2 = sum(forest) * 9e-4, flagged_km2 = sum(flagged) * 9e-4), by = .(Year, line, StrtmId, group)]
tab <- merge(tab, EC, by = "StrtmId")[order(ecodiv, group, line, Year)]; fwrite(tab, file.path(OUT, sprintf("rule-national-%s.csv", tag)))
if (!is.null(PL)) { lay <- names(res[[1]]$agg); rr <- rast(ext(min(tiles$x0), max(tiles$x1), min(tiles$y0), max(tiles$y1)), resolution = 300, crs = crs(G), nlyrs = length(lay)); names(rr) <- lay
  ff <- file.path(OUT, "rule-national-300m.tif"); v <- matrix(0L, ncell(rr), length(lay))
  for (z in res) { tt <- z$tile; cells <- cellFromRowColCombine(rr, round((ymax(rr) - tt$y1) / 300) + seq_len(tt$nr / A), round((tt$x0 - xmin(rr)) / 300) + seq_len(tt$nc / A)); for (i in seq_along(lay)) v[cells, i] <- as.integer(z$agg[[lay[i]]]) }
  values(rr) <- v; writeRaster(rr, ff, datatype = "INT2U", gdal = "COMPRESS=DEFLATE", overwrite = TRUE) }
options(width = 250); s <- tab[group != 180, .(forest_km2 = round(sum(forest_km2[Year == min(Year)])), flagged_km2 = round(sum(flagged_km2)), mean_pct_per_year = round(100 * sum(flagged_km2) / sum(forest_km2), 3)), by = .(ecodiv, line)]
cat("\nconifer forest (pinyon/juniper apart) by ecodivision: eligible forest in the first year (km2) and mean yearly rate (%) by line\n"); print(dcast(s, ecodiv + forest_km2 ~ line, value.var = "mean_pct_per_year"), nrows = 60)
