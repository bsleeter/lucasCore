# To-do 2: does DSWE drift as Landsat sensors come and go? Yearly DSWE on cells neither NLCD nor C-CAP changes
# (water, marsh, other land), and the year the DSWE marsh loss happened.
# Usage: Rscript dswe-drift.R <cache dir> "<region name>"   (after dswe-test.R, which fills the cache; writes drift/<tag>-*.csv)
suppressMessages({ library(terra); library(data.table) })
args <- commandArgs(trailingOnly = TRUE); cache <- args[1]; rn <- args[2]
out <- "dev/wetland-change/drift"; dir.create(out, showWarnings = FALSE)
regions <- list("Louisiana delta plain" = c(-91.3, -89.7, 29.0, 29.9), "Louisiana chenier plain" = c(-93.9, -92.5, 29.5, 30.2),
  "Chesapeake eastern shore" = c(-76.5, -75.7, 38.0, 38.6), "San Francisco Bay and Delta" = c(-122.6, -121.5, 37.4, 38.3),
  "Western Lake Erie" = c(-83.6, -82.6, 41.3, 41.8),
  "Sierra Nevada reservoirs" = c(-120.7, -120.15, 37.6, 38.05), "Great Salt Lake" = c(-113.1, -111.9, 40.6, 41.7))
b <- regions[[rn]]; tag <- gsub("[^a-z]+", "-", tolower(rn)); HA <- 0.09; YEARS <- 1994:2025
NLCD <- "E:/lucasData/land-cover/nlcd-annual/Annual_NLCD_LndCov_%d_CU_C1V2.tif"
ccap_lut <- rep(4L, 256); ccap_lut[c(0, 1) + 1] <- 0L; ccap_lut[13:18 + 1] <- 2L; ccap_lut[21:23 + 1] <- 1L; ccap_lut[19:20 + 1] <- 3L
nlcd_lut <- rep(4L, 256); nlcd_lut[c(0, 250) + 1] <- NA; nlcd_lut[11 + 1] <- 1L; nlcd_lut[c(90, 95) + 1] <- 2L; nlcd_lut[31 + 1] <- 3L
e <- ext(project(vect(ext(b[1], b[2], b[3], b[4]), crs = "EPSG:4326"), "EPSG:5070"))
nl <- function(y) { r <- rast(sprintf(NLCD, y)); crs(r) <- "EPSG:5070"; r }
tmpl <- crop(nl(2021), e)
rd_n <- function(y) nlcd_lut[as.integer(values(crop(nl(y), tmpl), mat = FALSE)) + 1L]
rd_c <- function(y) { v <- as.integer(values(rast(file.path(cache, sprintf("ccap2-%s-%s.tif", tag, y))), mat = FALSE)); v[is.na(v)] <- 0L; ccap_lut[v + 1L] }
dswe <- function(y) values(rast(file.path(cache, sprintf("dswe-%s-%d.tif", tag, y))))   # open, partial, count
N96 <- rd_n(1996); N21 <- rd_n(2021); C96 <- rd_c(1996); C21 <- rd_c(2021)
# NLCD the same class in every year 1994-2025, so a cell NLCD moved and moved back is not called unchanged
same <- !is.na(N96); for (y in YEARS) { k <- rd_n(y); same <- same & !is.na(k) & k == N96 }
cs <- function(k) C96 == 0L & C21 == 0L | C96 == k & C21 == k   # C-CAP agrees, or maps nothing here
m3 <- function(y, j) { a <- 0; for (yy in (y - 1):(y + 1)) { v <- dswe(yy)[, j]; v[is.na(v)] <- 0; a <- a + v }; a / 3 }
o96 <- m3(1996, 1); o21 <- m3(2021, 1)
sets <- list("Unchanged water" = which(same & N96 == 1L & cs(1L)), "Unchanged marsh" = which(same & N96 == 2L & cs(2L)), "Unchanged other land" = which(same & N96 == 4L & cs(4L)),
  "Unchanged barren" = which(same & N96 == 3L), "C-CAP marsh loss" = which(C96 == 2L & C21 == 1L),
  "DSWE marsh loss" = which(o96 < 50 & o21 >= 50 & (N96 == 2L | C96 == 2L)))
cat(rn, ":", paste(names(sets), round(lengths(sets) * HA / 1000, 1), collapse = " | "), "kha\n")
dl <- sets[["DSWE marsh loss"]]; OL <- matrix(0, length(dl), length(YEARS))
series <- rbindlist(lapply(seq_along(YEARS), function(i) { v <- dswe(YEARS[i]); if (length(dl)) { o <- v[dl, 1]; o[is.na(o)] <- NA; OL[, i] <<- o }
  rbindlist(lapply(names(sets), function(s) { x <- v[sets[[s]], , drop = FALSE]
    data.table(Region = rn, Set = s, Year = YEARS[i], Kha = nrow(x) * HA / 1000, Open = mean(x[, 1], na.rm = TRUE), Partial = mean(x[, 2], na.rm = TRUE),
      PctOpenOver50 = 100 * mean(x[, 1] >= 50, na.rm = TRUE), Obs = mean(x[, 3], na.rm = TRUE), NoLookPct = 100 * mean(is.na(x[, 1]))) })) }))
fwrite(series, file.path(out, paste0(tag, "-series.csv")))
# the year each DSWE marsh-loss cell first reads open water at 50% or more on a three-year mean, and stays there to 2021
if (length(dl)) { for (i in 2:ncol(OL)) { na <- is.na(OL[, i]); OL[na, i] <- OL[na, i - 1] }; OL[is.na(OL)] <- 0
  M <- (OL[, 1:(ncol(OL) - 2)] + OL[, 2:(ncol(OL) - 1)] + OL[, 3:ncol(OL)]) / 3; my <- YEARS[2:(length(YEARS) - 1)]   # centred means, 1995-2024
  k <- which(my >= 1996 & my <= 2021); W <- M[, k, drop = FALSE] >= 50
  last_dry <- apply(W, 1, function(r) { z <- which(!r); if (length(z)) max(z) else 0L })   # last year below the line
  yr <- my[k][pmin(last_dry + 1L, length(k))]
  timing <- data.table(Region = rn, Year = yr)[, .(Kha = .N * HA / 1000), by = .(Region, Year)][order(Year)]
  fwrite(timing, file.path(out, paste0(tag, "-timing.csv"))) }
cat(rn, "done\n")
