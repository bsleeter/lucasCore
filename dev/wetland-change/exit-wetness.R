# To-do 2: when a pixel leaves water, does its DSWE open-water share in the following years tell wetland from barren?
# (user idea 2026-11-25: below 50% but not at 0% means wetland, at 0% means barren)
# With a third argument "partial" the same is done for the partial-water share (user 2026-11-25: "Yes, test partial"), with the exit era kept.
# Usage: Rscript exit-wetness.R <cache dir> "<region name>" [partial]   (after dswe-test.R; writes rules/<tag>-exit.csv or -exitp.csv)
suppressMessages({ library(terra); library(data.table) }); source("src/water-change.R")
args <- commandArgs(trailingOnly = TRUE); cache <- args[1]; rn <- args[2]; tag <- gsub("[^a-z]+", "-", tolower(rn)); HA <- 0.09; YEARS <- 1994:2025; PART <- length(args) > 2 && args[3] == "partial"
regions <- list("Louisiana delta plain" = c(-91.3, -89.7, 29.0, 29.9), "Louisiana chenier plain" = c(-93.9, -92.5, 29.5, 30.2),
  "Chesapeake eastern shore" = c(-76.5, -75.7, 38.0, 38.6), "San Francisco Bay and Delta" = c(-122.6, -121.5, 37.4, 38.3), "Western Lake Erie" = c(-83.6, -82.6, 41.3, 41.8),
  "Sierra Nevada reservoirs" = c(-120.7, -120.15, 37.6, 38.05), "Great Salt Lake" = c(-113.1, -111.9, 40.6, 41.7))
b <- regions[[rn]]; e <- ext(project(vect(ext(b[1], b[2], b[3], b[4]), crs = "EPSG:4326"), "EPSG:5070"))
nl <- function(y) { r <- rast(sprintf("E:/lucasData/land-cover/nlcd-annual/Annual_NLCD_LndCov_%d_CU_C1V2.tif", y)); crs(r) <- "EPSG:5070"; r }
tmpl <- crop(nl(2021), e)
O <- rast(lapply(YEARS, function(y) rast(file.path(cache, sprintf("dswe-%s-%d.tif", tag, y)), lyrs = 1)))
P <- rast(lapply(YEARS, function(y) rast(file.path(cache, sprintf("dswe-%s-%d.tif", tag, y)), lyrs = 2)))
N <- crop(rast(lapply(YEARS, nl)), tmpl); C <- rast(file.path(cache, sprintf("ccap2-%s-2021.tif", tag))); stopifnot(ncell(O) == ncell(N), ncell(O) == ncell(C))
ccap_lut <- rep("Other", 256); ccap_lut[c(0, 1) + 1] <- "None"; ccap_lut[13:18 + 1] <- "Wetland"; ccap_lut[21:23 + 1] <- "Water"; ccap_lut[19:20 + 1] <- "Barren"
ncls <- function(v) fifelse(v %in% c(90L, 95L), "Wetland", fifelse(v == 31L, "Barren", fifelse(v == 11L, "Water", "Other")))
BIN <- if (PART) c("under 1", "1 to 5", "5 to 10", "10 to 20", "20 to 40", "40 or more") else c("under 1", "1 to 5", "5 to 20", "20 to 50", "50 or more")
CUT <- if (PART) c(1, 5, 10, 20, 40) else c(1, 5, 20, 50)
readStart(O); readStart(N); readStart(C); readStart(P); step <- max(1L, floor(1.5e6 / ncol(O))); res <- list()
for (r0 in seq(1L, nrow(O), by = step)) { nr <- min(step, nrow(O) - r0 + 1L)
  o <- readValues(O, r0, nr, mat = TRUE); l <- readValues(N, r0, nr, mat = TRUE); storage.mode(o) <- "integer"; storage.mode(l) <- "integer"
  pv <- if (PART) { z <- readValues(P, r0, nr, mat = TRUE); storage.mode(z) <- "integer"; z } else o
  cc <- as.integer(readValues(C, r0, nr)); cc[is.na(cc)] <- 0L; cc <- ccap_lut[cc + 1L]
  x <- water_change(o, l); Y <- ncol(o)
  for (y in 2:(Y - 4L)) { i <- which(x$change[, y] %in% c(2L, 3L, 6L)); if (!length(i)) next
    k <- y:(y + 4L); land <- !x$water[i, k, drop = FALSE]; v <- pv[i, k, drop = FALSE]; v[!land] <- NA
    m <- rowMeans(v, na.rm = TRUE); mx <- suppressWarnings(apply(v, 1, max, na.rm = TRUE)); yrs <- rowSums(land)
    res[[length(res) + 1]] <- data.table(Side = ifelse(x$wetland_side[i], "Wetland side", "Away from wetland"), Nlcd = ncls(l[i, y + 4L]), Ccap = cc[i], Era = if (YEARS[y] <= 1998) "1995-98" else if (YEARS[y] <= 2012) "1999-2012" else "2013-21",
      Bin = BIN[findInterval(m, CUT) + 1L], LandYears = yrs, Open = m)[, .(N = .N, OpenSum = sum(Open, na.rm = TRUE), LandYearsSum = sum(LandYears)), by = .(Side, Nlcd, Ccap, Era, Bin)] } }
readStop(O); readStop(N); readStop(C)
res <- rbindlist(res)[, .(Kha = sum(N) * HA / 1000, MeanOpen = sum(OpenSum) / sum(N), MeanLandYears = sum(LandYearsSum) / sum(N)), by = .(Side, Nlcd, Ccap, Era, Bin)][, Region := rn]
fwrite(res, sprintf("dev/wetland-change/rules/%s-exit%s.csv", tag, if (PART) "p" else "")); cat(rn, "done:", round(sum(res$Kha), 1), "kha of water to land events\n")
