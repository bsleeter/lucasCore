# To-do 2: USGS DSWE Annual Proportions (doi 10.5066/P16Q2FUD) against Annual NLCD and C-CAP on the test boxes.
# The yearly files are cloud-optimized GeoTIFFs in USGS's public bucket; the tile list comes from WaterMAP's catalog.
# Usage: Rscript dswe-test.R <cache dir> "<region name>"      (one region per run; writes dswe-*.csv beside this script)
suppressMessages({ library(terra); library(data.table) })
args <- commandArgs(trailingOnly = TRUE); cache <- args[1]; rn <- args[2]
dir.create(cache, showWarnings = FALSE, recursive = TRUE); out <- "dev/wetland-change"
regions <- list("Louisiana delta plain" = c(-91.3, -89.7, 29.0, 29.9), "Louisiana chenier plain" = c(-93.9, -92.5, 29.5, 30.2),
  "Chesapeake eastern shore" = c(-76.5, -75.7, 38.0, 38.6), "San Francisco Bay and Delta" = c(-122.6, -121.5, 37.4, 38.3),
  "Western Lake Erie" = c(-83.6, -82.6, 41.3, 41.8),
  "Sierra Nevada reservoirs" = c(-120.7, -120.15, 37.6, 38.05), "Great Salt Lake" = c(-113.1, -111.9, 40.6, 41.7))
b <- regions[[rn]]; tag <- gsub("[^a-z]+", "-", tolower(rn)); t0 <- Sys.time()
API <- "https://apps.usgs.gov/watermap/api/v1/stac/collections/dswe-proportions/items"
CCAP <- "/vsicurl/https://coastalimagery.blob.core.windows.net/ccap-landcover/CCAP_bulk_download/Regional_30meter_Land_Cover/"
ccap_file <- c("1996" = "conus_1996_ccap_landcover_20200311.tif", "2021" = "conus_2021_ccap_landcover_20241217.tif")
NLCD <- "E:/lucasData/land-cover/nlcd-annual/Annual_NLCD_LndCov_%d_CU_C1V2.tif"
CLS <- c("Water", "Wetland", "Barren", "Other"); HA <- 0.09; YEARS <- 1994:2025
ccap_lut <- rep(4L, 256); ccap_lut[c(0, 1) + 1] <- 0L; ccap_lut[13:18 + 1] <- 2L; ccap_lut[21:23 + 1] <- 1L; ccap_lut[19:20 + 1] <- 3L   # 0 = C-CAP maps nothing here
nlcd_lut <- rep(4L, 256); nlcd_lut[c(0, 250) + 1] <- NA; nlcd_lut[11 + 1] <- 1L; nlcd_lut[c(90, 95) + 1] <- 2L; nlcd_lut[31 + 1] <- 3L

e <- ext(project(vect(ext(b[1], b[2], b[3], b[4]), crs = "EPSG:4326"), "EPSG:5070"))
nl <- function(y) { r <- rast(sprintf(NLCD, y)); crs(r) <- "EPSG:5070"; r }   # NLCD and DSWE: the same Albers grid on WGS84, under a metre from NAD83
tmpl <- crop(nl(2021), e); nc <- ncell(tmpl)
rd_n <- function(y) nlcd_lut[as.integer(values(crop(nl(y), tmpl), mat = FALSE)) + 1L]
rd_c <- function(y) { f <- file.path(cache, sprintf("ccap2-%s-%s.tif", tag, y))
  if (!file.exists(f)) { r <- rast(paste0(CCAP, ccap_file[[as.character(y)]]))
    i <- intersect(ext(r), ext(tmpl)); x <- if (is.null(i)) init(tmpl, 0) else extend(crop(r, tmpl), tmpl, fill = 0)
    writeRaster(x, f, datatype = "INT1U", overwrite = TRUE) }
  v <- as.integer(values(rast(f), mat = FALSE)); v[is.na(v)] <- 0L; ccap_lut[v + 1L] }

# ---- DSWE: tiles of the box, then one cached crop a year (bands open, partial, count) ----
j <- jsonlite::fromJSON(sprintf("%s?limit=50&bbox=%s&datetime=2021-01-01T00:00:00Z/2021-12-31T23:59:59Z", API, paste(b[c(1, 3, 2, 4)], collapse = ",")), simplifyVector = FALSE)
href <- vapply(j$features, function(f) f$assets$dswe_proportion$href, "")
cat(rn, ":", length(href), "DSWE tiles;", format(nc, big.mark = ","), "cells\n")
dswe_file <- function(y) { f <- file.path(cache, sprintf("dswe-%s-%d.tif", tag, y)); if (file.exists(f)) return(f)
  parts <- lapply(sub("_2021_Props", sprintf("_%d_Props", y), href), function(u) { r <- try(rast(paste0("/vsicurl/", u)), silent = TRUE)
    if (inherits(r, "try-error")) { cat("  missing:", basename(u), "\n"); return(NULL) }
    crs(r) <- "EPSG:5070"; if (is.null(intersect(ext(r), ext(tmpl)))) return(NULL)
    extend(crop(r[[c(2, 3, 5)]], tmpl), tmpl) })
  parts <- Filter(Negate(is.null), parts); x <- if (length(parts) > 1) do.call(merge, parts) else parts[[1]]
  writeRaster(x, f, datatype = "INT1U", NAflag = 255, overwrite = TRUE); f }
for (y in YEARS) { dswe_file(y); if (y %% 5 == 0) cat(sprintf("  DSWE %d cached (%.1f min)\n", y, as.numeric(difftime(Sys.time(), t0, units = "mins")))) }

# ---- the cells that matter: water, wetland or barren in either product at either date, or ever wet in DSWE ----
N96 <- rd_n(1996); N21 <- rd_n(2021); C96 <- rd_c(1996); C21 <- rd_c(2021)
ever <- logical(nc); for (y in YEARS) { v <- values(rast(dswe_file(y))[[1:2]]); ever <- ever | (rowSums(v, na.rm = TRUE) >= 10) }
valid <- !is.na(N96) & !is.na(N21)
rel <- which(valid & (N96 <= 3L | N21 <= 3L | C96 %in% 1:3 | C21 %in% 1:3 | ever)); nr <- length(rel)
cat(sprintf("  %s cells valid, %s kept (%.0f kha)\n", format(sum(valid), big.mark = ","), format(nr, big.mark = ","), nr * HA / 1000))
N96 <- N96[rel]; N21 <- N21[rel]; C96 <- C96[rel]; C21 <- C21[rel]
ny <- length(YEARS); O <- matrix(as.raw(0), nr, ny); P <- matrix(as.raw(0), nr, ny); NW <- matrix(as.raw(0), nr, ny)   # NW: NLCD class
series <- vector("list", ny)
for (i in seq_len(ny)) { y <- YEARS[i]; v <- values(rast(dswe_file(y)))[rel, , drop = FALSE]; o <- as.integer(v[, 1]); p <- as.integer(v[, 2]); n <- v[, 3]
  na <- is.na(o) | is.na(p); if (i > 1) { o[na] <- as.integer(O[na, i - 1]); p[na] <- as.integer(P[na, i - 1]) } else { o[na] <- 0L; p[na] <- 0L }   # a year with no clear look keeps last year's value
  O[, i] <- as.raw(o); P[, i] <- as.raw(p); k <- rd_n(y)[rel]; k[is.na(k)] <- 4L; NW[, i] <- as.raw(k)
  series[[i]] <- data.table(Region = rn, Year = y, DsweOpenHa = sum(o) / 100 * HA, DswePartialHa = sum(p) / 100 * HA,
    DsweOpen50Ha = sum(o >= 50L) * HA, NlcdWaterHa = sum(k == 1L) * HA, NlcdWetlandHa = sum(k == 2L) * HA, NlcdBarrenHa = sum(k == 3L) * HA,
    MeanObs = mean(n, na.rm = TRUE), NoLookPct = 100 * mean(na)) }
series <- rbindlist(series)
col <- function(M, i) as.integer(M[, i]); iy <- function(y) match(y, YEARS)
m3 <- function(M, y) (col(M, iy(y - 1)) + col(M, iy(y)) + col(M, iy(y + 1))) / 3   # three-year mean about y

# ---- 1 how DSWE sits inside each product's classes (1996 and 2021, three-year means, bins of 10) ----
bin <- function(x) pmin(10L, as.integer(ceiling(x / 10)))   # 0 = none, 1 = up to 10% ... 10 = over 90%
hist <- rbindlist(lapply(c(1996, 2021), function(y) { Nk <- if (y == 1996) N96 else N21; Ck <- if (y == 1996) C96 else C21
  data.table(Year = y, Open = bin(m3(O, y)), Partial = bin(m3(P, y)), Nlcd = CLS[Nk], Ccap = c("None", CLS)[Ck + 1L])[, .(Ha = .N * HA), by = .(Year, Open, Partial, Nlcd, Ccap)] }))
hist[, Region := rn]

# ---- 2 does a water / not-water line hold from year to year (1996-2021)? ----
stab <- function(state, lab) { ys <- 1996:2021; prev <- state(ys[1]); first <- prev; nsw <- integer(nr); g <- 0; l <- 0
  for (y in ys[-1]) { cur <- state(y); g <- g + sum(!prev & cur); l <- l + sum(prev & !cur); nsw <- nsw + (prev != cur); prev <- cur }
  data.table(Region = rn, Rule = lab, WaterStartKha = sum(first) * HA / 1000, WaterEndKha = sum(prev) * HA / 1000,
    GrossToWaterKha = g * HA / 1000, GrossFromWaterKha = l * HA / 1000, NetToWaterKha = sum(!first & prev) * HA / 1000, NetFromWaterKha = sum(first & !prev) * HA / 1000,
    ChangedOnceKha = sum(nsw == 1L) * HA / 1000, ChangedTwiceKha = sum(nsw == 2L) * HA / 1000, ChangedMoreKha = sum(nsw > 2L) * HA / 1000) }
stability <- rbind(
  stab(function(y) col(NW, iy(y)) == 1L, "NLCD water, yearly"),
  stab(function(y) col(O, iy(y)) >= 25L, "DSWE open >= 25%, yearly"), stab(function(y) col(O, iy(y)) >= 50L, "DSWE open >= 50%, yearly"),
  stab(function(y) col(O, iy(y)) >= 75L, "DSWE open >= 75%, yearly"), stab(function(y) m3(O, y) >= 50, "DSWE open >= 50%, 3-year mean"),
  stab(function(y) (col(O, iy(y)) + col(P, iy(y))) >= 50L, "DSWE open+partial >= 50%, yearly"))

# ---- 3 DSWE as referee: how wet were the cells each product says changed, 1996 against 2021 ----
o96 <- m3(O, 1996); o21 <- m3(O, 2021); p96 <- m3(P, 1996); p21 <- m3(P, 2021)
referee <- data.table(Ccap = paste(c("None", CLS)[C96 + 1L], ">", c("None", CLS)[C21 + 1L]), Nlcd = paste(CLS[N96], ">", CLS[N21]), o96, o21, p96, p21)[,
  .(Kha = .N * HA / 1000, Open96 = mean(o96), Open21 = mean(o21), Partial96 = mean(p96), Partial21 = mean(p21)), by = .(Ccap, Nlcd)]
referee[, Region := rn]
# ---- 4 cells that became water, or stopped being water, in each product ----
D1 <- o96 < 50 & o21 >= 50; D0 <- o96 >= 50 & o21 < 50; hasC <- C96 > 0L & C21 > 0L
sets <- function(d, cc, nn, lab) data.table(Region = rn, Change = lab, DsweKha = sum(d) * HA / 1000, CcapKha = sum(cc) * HA / 1000, NlcdKha = sum(nn) * HA / 1000,
  DsweAndCcapKha = sum(d & cc) * HA / 1000, DsweAndNlcdKha = sum(d & nn) * HA / 1000, CcapAndNlcdKha = sum(cc & nn) * HA / 1000, AllThreeKha = sum(d & cc & nn) * HA / 1000)
overlap <- rbind(sets(D1, hasC & C96 != 1L & C21 == 1L, N96 != 1L & N21 == 1L, "Became water"),
  sets(D0, hasC & C96 == 1L & C21 != 1L, N96 == 1L & N21 != 1L, "Stopped being water"),
  sets(D1 & (N96 == 2L | C96 == 2L), hasC & C96 == 2L & C21 == 1L, N96 == 2L & N21 == 1L, "Wetland became water"),
  sets(D0 & (N21 == 2L | C21 == 2L), hasC & C96 == 1L & C21 == 2L, N96 == 1L & N21 == 2L, "Water became wetland"))

w <- function(x, f) { p <- file.path(out, f); old <- if (file.exists(p)) fread(p)[Region != rn] else NULL; fwrite(rbind(old, x, fill = TRUE), p) }
w(series, "dswe-series.csv"); w(hist, "dswe-hist.csv"); w(stability, "dswe-stability.csv"); w(referee, "dswe-referee.csv"); w(overlap, "dswe-overlap.csv")
cat(sprintf("%s done in %.1f min\n", rn, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
