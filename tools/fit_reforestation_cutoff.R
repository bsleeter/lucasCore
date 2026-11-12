# =============================================================================
# fit_reforestation_cutoff.R - the reforestation cutoff by ecodivision (to-do 57 step 2; user 2026-11-12: fitted, with an override)
# =============================================================================
# Stage 5 tells regrowth from reforestation by when NLCD first shows a natural cell as forest: before the cutoff (years after the
# start year) it is regrowth from a disturbance before the record, and starts as forest; at or after it, on forest potential, it
# reforests. The cutoff is how long forest takes to come back after a dated stand-replacing disturbance, from the national layers in
# F:/lucas-master/Data Sources:
#   - events: NLCD forest (41-43) the year before, then LCMS Tree Removal (9) that NLCD shows as shrub or grass (52, 71) that year or
#     within two (stage 6's clearcut), or MTBS high severity (4) that NLCD shows as barren, shrub or grass within two years; the
#     first event per pixel, in 1986-1995, on LANDFIRE BpS 2020
#     forest potential (src/reforestation.R; riparian and savanna as forest)
#   - return: the first year after the event that NLCD shows forest two years running and in at least 2/3 of the years from then to
#     2025 (the regrowth rule's test). T = that year - the event year.
#   - every event has at least 29 years of record after it (the 1995 cohort's last testable year is 2024), so return times are not
#     censored within 29 years: the cutoff is the Quantile (default 0.9) of T among the events that returned within 29 years. (The
#     plan's Kaplan-Meier version is undefined where more than 10% never return, as after many western burns, and those are
#     conversions, not slow returns.) Events that never returned are counted, not used. Each tile counts as at most TileCap (500) events in the quantile.
# Sample: 10 km tiles (333 x 333 cells on the NLCD grid), TilesPerEco per ecodivision, centred on random NLCD 1985 forest pixels
# (tiles keep the sample fast: windows, not scattered points; the minimum counts tiles as well as events since events cluster).
# An ecodivision short of MinEvents returned events or MinTiles tiles with them takes its pair's value (mountains <-> lowland of the
# same division), then its domain's (first digit: 2 humid temperate, 3 dry, 4 humid tropical), then CONUS's.
# Writes defaults/landcover/reforestation-cutoff.csv (Ecodivision blank = CONUS; read most specific first) and, with --detail, the
# events to dev/fire/reforestation-cutoff-events.csv.
# Usage: Rscript tools/fit_reforestation_cutoff.R [--tiles=30] [--quantile=0.9] [--min-events=100] [--min-tiles=5] [--tile-cap=500] [--cores=20] [--detail]
# =============================================================================
suppressMessages({ library(terra); library(data.table); library(parallel) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) as.numeric(sub("^[^=]*=", "", m[1])) else d }
TILE_CAP <- opt("tile-cap", 500); TILES <- opt("tiles", 30); Q <- opt("quantile", 0.9); MIN_EV <- opt("min-events", 100); MIN_TILES <- opt("min-tiles", 5); CORES <- opt("cores", 20)
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
DS <- "F:/lucas-master/Data Sources"; Y0 <- 1985; Y1 <- 2025; EV <- 1986:1995; MAXT <- 29
nlcd_f <- vapply(Y0:Y1, function(y) list.files(file.path(DS, "NLCD", "Annual NLCD"), sprintf("^Annual_NLCD_LndCov_%d_CU_C1V.[.]tif$", y), full.names = TRUE)[1], "")
lcms_f <- vapply(EV[1]:(max(EV) + 2), function(y) list.files(file.path(DS, "LCMS", "v2025-11", "Change_Annual", y), "Change_.*[.]tif$", full.names = TRUE)[1], "")
mtbs_f <- file.path(DS, "MTBS", "Burn Severity", sprintf("mtbs_CONUS_%d.tif", EV))
eco_f <- file.path(DS, "FIA", "Ecodivisions_30m.tif"); bps_f <- file.path(DS, "BpS", "LF2020_BPS_CONUS", "LF2020_BPS_CONUS", "Tif", "LF2020_BPS_CONUS.tif")
stopifnot(all(file.exists(c(nlcd_f, lcms_f, mtbs_f, eco_f, bps_f))))
en <- unique(fread(file.path(DS, "FIA", "EcoDivision_Strata.csv"))[, .(eco = as.integer(StratumId), Ecodivision = StratumName)], by = "eco")
en[eco == 2601, Ecodivision := "Mediterranean Mountains"]

# ---- tile centres: random NLCD 1985 forest pixels, TILES per ecodivision ----------------------------------------------------------
set.seed(57); ecoR <- rast(eco_f); n85 <- rast(nlcd_f[1]); levels(n85) <- NULL
pts <- spatSample(ecoR, 4e5, "random", xy = TRUE, na.rm = TRUE); names(pts)[3] <- "eco"; pts <- as.data.table(pts)[eco > 0]
pts[, nl := extract(n85, as.matrix(pts[, .(x, y)]))[, 1]]; pts <- pts[nl %in% 41:43]
cen <- pts[, .SD[sample(.N, min(.N, TILES))], by = eco]
cat(sprintf("%d tiles in %d ecodivisions (%d forest pixels drawn)\n", nrow(cen), uniqueN(cen$eco), nrow(pts)))

# ---- per tile: events 1986-1995 on forest potential, their return times ---------------------------------------------------------
one_tile <- function(i) {
  suppressMessages({ library(terra); library(data.table) }); terraOptions(progress = 0)
  x0 <- floor((cen$x[i] - 5000 - 15) / 30) * 30 + 15; y0 <- floor((cen$y[i] - 5000 - 15) / 30) * 30 + 15; e <- ext(x0, x0 + 9990, y0, y0 + 9990)
  rd <- function(f) { r <- rast(f); levels(r) <- NULL; if (is.null(intersect(ext(r), e))) return(matrix(NA_integer_, 333L * 333L, 1))   # (a mosaic that misses the tile: no event there)
    r <- crop(r, e, snap = "near", extend = TRUE); v <- as.integer(values(r, mat = FALSE)); stopifnot(length(v) == 333L * 333L); matrix(v, ncol = 1) }
  N <- do.call(cbind, lapply(nlcd_f, rd)); colnames(N) <- Y0:Y1
  f <- N >= 41 & N <= 43; f[is.na(f)] <- FALSE; sg <- N %in% c(52L, 71L); dim(sg) <- dim(N); nf <- N %in% c(31L, 52L, 71L); dim(nf) <- dim(N)
  L <- do.call(cbind, lapply(lcms_f, rd)); M <- do.call(cbind, lapply(mtbs_f, rd))
  ev <- rep(NA_integer_, nrow(N)); cause <- rep(NA_character_, nrow(N))
  for (d in EV) { j <- d - Y0 + 1; free <- is.na(ev) & f[, j - 1]
    cc <- free & L[, d - EV[1] + 1] %in% 9L & (sg[, j] | sg[, j + 1] | sg[, j + 2])
    hs <- free & !cc & M[, d - EV[1] + 1] %in% 4L & (nf[, j] | nf[, j + 1] | nf[, j + 2])   # (stand-replacing as NLCD sees it: barren, shrub or grass within two years)
    ev[cc | hs] <- d; cause[cc] <- "clearcut"; cause[hs] <- "high-severity fire" }
  k <- which(!is.na(ev)); if (!length(k)) return(NULL)
  ny <- ncol(N); Tr <- vapply(k, function(p) { r <- f[p, ]; s <- ev[p] - Y0 + 1; s0 <- s - 1 + which(!r[s:(s + 2)])[1]   # (from the first non-forest year)
    for (t in (s0 + 1):(ny - 1)) if (r[t] && r[t + 1] && mean(r[t:ny]) >= 2 / 3) return(as.integer(t - s)); NA_integer_ }, 1L)
  xy <- xyFromCell(crop(rast(nlcd_f[1]), e, snap = "near"), k)
  data.table(tile = i, eco = cen$eco[i], x = xy[, 1], y = xy[, 2], year = ev[k], cause = cause[k], Tret = Tr) }
cl <- makeCluster(CORES); clusterExport(cl, c("cen", "nlcd_f", "lcms_f", "mtbs_f", "Y0", "Y1", "EV"))
t0 <- Sys.time(); D <- rbindlist(parLapply(cl, seq_len(nrow(cen)), one_tile)); stopCluster(cl)
cat(sprintf("%d events in %d tiles (%.1f min)\n", nrow(D), uniqueN(D$tile), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
# each pixel's own ecodivision and BpS (the tile's centre ecodivision is only for the draw)
D[, eco := as.integer(extract(ecoR, as.matrix(D[, .(x, y)]))[, 1])]
b <- rast(bps_f); levels(b) <- NULL; D[, bps := as.integer(extract(b, as.matrix(D[, .(x, y)]))[, 1])]
read_default <- function(...) fread(file.path(pkg, "defaults", ...), encoding = "UTF-8"); source(file.path(pkg, "src", "reforestation.R"))
D[, potential := bps_potential(bps)]; D <- D[potential == "forest" & eco %in% en$eco]
D[, returned := !is.na(Tret) & Tret <= MAXT]
if ("--detail" %in% a) fwrite(D, file.path(pkg, "dev", "fire", "reforestation-cutoff-events.csv"))

# ---- the cutoff: Quantile of T among returned events, by ecodivision with fallbacks ---------------------------------------------
# each tile counts as at most TILE_CAP events (events cluster: one large burn or harvest unit can hold most of an ecodivision's events;
# equal weights instead let tiles with a few events swing it: Hot Continental 12 -> 21 years)
wq <- function(v, w, p) { o <- order(v); v <- v[o]; cw <- cumsum(w[o]) / sum(w); v[which(cw >= p)[1]] }
fit <- function(x) { r <- x[returned == TRUE]; if (nrow(r) < MIN_EV || uniqueN(r$tile) < MIN_TILES) return(NULL); r[, w := min(.N, TILE_CAP) / .N, by = tile]
  list(Years = as.integer(wq(r$Tret, r$w, Q)), Median = as.numeric(wq(r$Tret, r$w, 0.5)), Events = nrow(x), Returned = sum(x$returned), Tiles = uniqueN(x$tile),
       Clearcut = mean(x$cause == "clearcut")) }
pair <- function(e) if (e >= 1000) e %/% 10 else e * 10 + 1
dom <- function(e) as.integer(substr(as.character(e), 1, 1))
D[, dom := dom(eco)]
conus <- fit(D); stopifnot(!is.null(conus))
out <- rbindlist(lapply(en$eco, function(e) {
  own <- fit(D[eco == e]); src <- "own events"
  if (is.null(own)) { own <- fit(D[eco %in% c(e, pair(e))]); src <- sprintf("with %s", en$Ecodivision[match(pair(e), en$eco)]) }
  if (is.null(own)) { own <- fit(D[dom == dom(e)]); src <- sprintf("domain %d", dom(e)) }
  if (is.null(own)) { own <- conus; src <- "CONUS" }
  data.table(Ecodivision = en$Ecodivision[match(e, en$eco)], Years = own$Years, MedianYears = own$Median, Events = sum(D$eco == e), Returned = sum(D$eco == e & D$returned),
             Tiles = uniqueN(D[eco == e, tile]), ClearcutShare = round(mean(D[eco == e, cause] == "clearcut"), 2), Source = src) }))
out <- rbind(data.table(Ecodivision = NA_character_, Years = conus$Years, MedianYears = conus$Median, Events = conus$Events, Returned = conus$Returned,
                        Tiles = conus$Tiles, ClearcutShare = round(conus$Clearcut, 2), Source = "CONUS"), out)
out[, Source := sprintf("%s; quantile %.2f of years to NLCD forest after clearcut or high-severity fire 1986-1995 on BpS forest, returns within %d years (tools/fit_reforestation_cutoff.R, %s)",
                        Source, Q, MAXT, format(Sys.Date()))]
fwrite(out, file.path(pkg, "defaults", "landcover", "reforestation-cutoff.csv"))
print(out[, .(Ecodivision, Years, MedianYears, Events, Returned, Tiles, ClearcutShare, Source = sub(";.*", "", Source))])
cat(sprintf("\nreturned within %d years: %.0f%% of %d events (clearcut %.0f%%, high-severity fire %.0f%%)\n", MAXT, 100 * mean(D$returned), nrow(D),
            100 * D[cause == "clearcut", mean(returned)], 100 * D[cause != "clearcut", mean(returned)]))
