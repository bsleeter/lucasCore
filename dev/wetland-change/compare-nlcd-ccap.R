# To-do 2 (wetland / barren / water land-cover change): Annual NLCD against NOAA C-CAP at the level of
# water, wetland, barren and other, on a few coastal test boxes.
# Usage: Rscript compare-nlcd-ccap.R <cache dir> [region name ...]
# Writes areas.csv, changes.csv, agreement.csv, static.csv and flicker.csv beside this script (one set of rows per region).
suppressMessages({ library(terra); library(data.table) })
args <- commandArgs(trailingOnly = TRUE)
cache <- args[1]; dir.create(cache, showWarnings = FALSE, recursive = TRUE)
out <- "dev/wetland-change"
CCAP <- "/vsicurl/https://coastalimagery.blob.core.windows.net/ccap-landcover/CCAP_bulk_download/Regional_30meter_Land_Cover/"
ccap_file <- c("1996" = "conus_1996_ccap_landcover_20200311.tif", "2001" = "conus_2001_ccap_landcover_20200311.tif",
  "2006" = "conus_2006_ccap_landcover_20200311.tif", "2010" = "conus_2010_ccap_landcover_20200311.tif",
  "2016" = "conus_2016_ccap_landcover_20200311.tif", "2021" = "conus_2021_ccap_landcover_20241217.tif")
NLCD <- "E:/lucasData/land-cover/nlcd-annual/Annual_NLCD_LndCov_%d_CU_C1V2.tif"
regions <- list(   # lon min, lon max, lat min, lat max
  "Louisiana delta plain"   = c(-91.3, -89.7, 29.0, 29.9),
  "Louisiana chenier plain" = c(-93.9, -92.5, 29.5, 30.2),
  "Chesapeake eastern shore" = c(-76.5, -75.7, 38.0, 38.6),
  "San Francisco Bay and Delta" = c(-122.6, -121.5, 37.4, 38.3),
  "Western Lake Erie"       = c(-83.6, -82.6, 41.3, 41.8))
if (length(args) > 1) regions <- regions[args[-1]]
CLS <- c("Water", "Wetland", "Barren", "Other")
# C-CAP: 13-18 wetland; 21 open water with 22-23 aquatic bed; 19 unconsolidated shore with 20 barren; 0-1 no data
ccap_lut <- rep(4L, 256); ccap_lut[c(0, 1) + 1] <- NA; ccap_lut[13:18 + 1] <- 2L; ccap_lut[21:23 + 1] <- 1L; ccap_lut[19:20 + 1] <- 3L
# NLCD: 11 water; 90, 95 wetland; 31 barren; 0 and 250 no data
nlcd_lut <- rep(4L, 256); nlcd_lut[c(0, 250) + 1] <- NA; nlcd_lut[11 + 1] <- 1L; nlcd_lut[c(90, 95) + 1] <- 2L; nlcd_lut[31 + 1] <- 3L
HA <- 0.09
years <- as.integer(names(ccap_file))

for (rn in names(regions)) {
  b <- regions[[rn]]; t0 <- Sys.time()
  e <- ext(project(vect(ext(b[1], b[2], b[3], b[4]), crs = "EPSG:4326"), "EPSG:5070"))
  tag <- gsub("[^a-z]+", "-", tolower(rn))
  cc <- sapply(names(ccap_file), function(y) {
    f <- file.path(cache, sprintf("ccap-%s-%s.tif", tag, y))
    if (!file.exists(f)) crop(rast(paste0(CCAP, ccap_file[[y]])), e, filename = f, datatype = "INT1U")
    f })
  tmpl <- rast(cc[1])
  rd_c <- function(y) ccap_lut[as.integer(values(crop(rast(cc[[as.character(y)]]), tmpl), mat = FALSE)) + 1L]
  rd_n <- function(y) { r <- rast(sprintf(NLCD, y)); crs(r) <- crs(tmpl)   # same Albers grid; WGS84 against NAD83 is under a metre
    nlcd_lut[as.integer(values(crop(r, tmpl), mat = FALSE)) + 1L] }
  C <- sapply(years, rd_c); N <- sapply(years, rd_n)
  ok <- stats::complete.cases(C) & stats::complete.cases(N)   # cells both products map in every epoch
  C <- C[ok, , drop = FALSE]; N <- N[ok, , drop = FALSE]
  cat(sprintf("%s: %s cells (%.0f kha) in both products\n", rn, format(sum(ok), big.mark = ","), sum(ok) * HA / 1000))

  # 1 class areas by epoch
  areas <- rbindlist(lapply(seq_along(years), function(i) rbind(
    data.table(Region = rn, Product = "C-CAP", Year = years[i], Class = CLS, Ha = tabulate(C[, i], 4) * HA),
    data.table(Region = rn, Product = "NLCD", Year = years[i], Class = CLS, Ha = tabulate(N[, i], 4) * HA))))
  # 2 changes by interval (and the whole period)
  chg <- function(M, i, j, prod, lab) { k <- tabulate((M[, i] - 1L) * 4L + M[, j], 16)
    data.table(Region = rn, Product = prod, Interval = lab, From = rep(CLS, each = 4), To = rep(CLS, 4), Ha = k * HA) }
  iv <- cbind(seq_len(length(years) - 1), seq_len(length(years))[-1]); iv <- rbind(iv, c(1, length(years)))
  changes <- rbindlist(apply(iv, 1, function(p) { lab <- paste(years[p[1]], years[p[2]], sep = "-")
    rbind(chg(C, p[1], p[2], "C-CAP", lab), chg(N, p[1], p[2], "NLCD", lab)) }))
  # 3 cell agreement on the 1996-2021 change
  n <- length(years); kc <- (C[, 1] - 1L) * 4L + C[, n]; kn <- (N[, 1] - 1L) * 4L + N[, n]
  lab <- paste(rep(CLS, each = 4), rep(CLS, 4), sep = " > ")
  ag <- as.data.table(table(Ccap = factor(kc, 1:16, lab), Nlcd = factor(kn, 1:16, lab)))[N > 0]
  agreement <- ag[, .(Region = rn, Ccap, Nlcd, Ha = N * HA)]
  # 4 static agreement in 2021
  st <- as.data.table(table(Ccap = factor(C[, n], 1:4, CLS), Nlcd = factor(N[, n], 1:4, CLS)))
  static <- st[, .(Region = rn, Ccap, Nlcd, Ha = N * HA)]
  rm(C); gc()

  # 5 NLCD year by year, 1996-2021: how much of the yearly wetland/water change reverses
  prev <- N[, 1]; nsw <- integer(length(prev)); w2o <- 0; o2w <- 0; first <- prev
  yearly <- list()
  for (y in (years[1] + 1):years[n]) { cur <- rd_n(y)[ok]
    a <- sum(prev == 2L & cur == 1L); bb <- sum(prev == 1L & cur == 2L)
    d <- sum(prev == 2L & cur == 3L); f <- sum(prev == 3L & cur == 2L); g <- sum(prev == 1L & cur == 3L); h <- sum(prev == 3L & cur == 1L)
    yearly[[length(yearly) + 1]] <- data.table(Region = rn, Year = y, WetlandToWater = a * HA, WaterToWetland = bb * HA,
      WetlandToBarren = d * HA, BarrenToWetland = f * HA, WaterToBarren = g * HA, BarrenToWater = h * HA)
    sw <- (prev != cur) & prev <= 3L & cur <= 3L; nsw <- nsw + sw; prev <- cur }
  yearly <- rbindlist(yearly)
  flicker <- data.table(Region = rn,
    GrossWetlandToWater = sum(yearly$WetlandToWater), GrossWaterToWetland = sum(yearly$WaterToWetland),
    NetWetlandToWater = sum(first == 2L & prev == 1L) * HA, NetWaterToWetland = sum(first == 1L & prev == 2L) * HA,
    ChangedOnceHa = sum(nsw == 1L) * HA, ChangedTwiceHa = sum(nsw == 2L) * HA, ChangedMoreHa = sum(nsw > 2L) * HA)
  w <- function(x, f) { p <- file.path(out, f); old <- if (file.exists(p)) fread(p)[Region != rn] else NULL; fwrite(rbind(old, x, fill = TRUE), p) }
  w(areas, "areas.csv"); w(changes, "changes.csv"); w(agreement, "agreement.csv"); w(static, "static.csv"); w(flicker, "flicker.csv"); w(yearly, "nlcd-yearly.csv")
  cat(sprintf("  done in %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  rm(N); gc()
}
