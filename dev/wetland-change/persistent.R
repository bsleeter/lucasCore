# NLCD changes that persist: a class held in all of 1994-1996 and another held in all of 2021-2025, against
# C-CAP 1996 > 2021. Usage: Rscript persistent.R <cache dir> (after compare-nlcd-ccap.R, which fills the cache)
suppressMessages({ library(terra); library(data.table) }); options(width = 200)
cache <- commandArgs(trailingOnly = TRUE)[1]
NLCD <- "E:/lucasData/land-cover/nlcd-annual/Annual_NLCD_LndCov_%d_CU_C1V2.tif"
ccap_lut <- rep(4L, 256); ccap_lut[c(0, 1) + 1] <- NA; ccap_lut[13:18 + 1] <- 2L; ccap_lut[21:23 + 1] <- 1L; ccap_lut[19:20 + 1] <- 3L
nlcd_lut <- rep(4L, 256); nlcd_lut[c(0, 250) + 1] <- NA; nlcd_lut[11 + 1] <- 1L; nlcd_lut[c(90, 95) + 1] <- 2L; nlcd_lut[31 + 1] <- 3L
tags <- unique(sub("^ccap-(.*)-\\d{4}\\.tif$", "\\1", list.files(cache, "^ccap-.*tif$")))
res <- rbindlist(lapply(tags, function(tag) {
  tmpl <- rast(file.path(cache, sprintf("ccap-%s-1996.tif", tag)))
  rc <- function(y) ccap_lut[as.integer(values(rast(file.path(cache, sprintf("ccap-%s-%d.tif", tag, y))), mat = FALSE)) + 1L]
  rn <- function(y) { r <- rast(sprintf(NLCD, y)); crs(r) <- crs(tmpl); nlcd_lut[as.integer(values(crop(r, tmpl), mat = FALSE)) + 1L] }
  stable <- function(ys) { m <- rn(ys[1]); for (y in ys[-1]) { v <- rn(y); m[!is.na(m) & (is.na(v) | v != m)] <- 0L }; m }   # 0 = not one class throughout
  s <- stable(1994:1996); e <- stable(2021:2025); c0 <- rc(1996); c1 <- rc(2021)
  ok <- !is.na(s) & !is.na(e) & !is.na(c0) & !is.na(c1)
  f <- function(a, b) { n <- ok & s == a & e == b; cc <- ok & c0 == a & c1 == b
    data.table(Region = tag, Change = paste(c("Water", "Wetland", "Barren")[a], ">", c("Water", "Wetland", "Barren")[b]),
      NlcdPersistentKha = sum(n) * 0.09 / 1000, CcapKha = sum(cc) * 0.09 / 1000, BothKha = sum(n & cc) * 0.09 / 1000,
      CcapSameDirectionAnyTimePct = NA_real_) }
  rbind(f(2, 1), f(1, 2), f(2, 3), f(3, 1), f(1, 3)) }))
res[, `:=`(NlcdConfirmedPct = round(100 * BothKha / NlcdPersistentKha, 1), CcapConfirmedPct = round(100 * BothKha / CcapKha, 1), CcapSameDirectionAnyTimePct = NULL)]
print(res[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)])
fwrite(res, "dev/wetland-change/persistent.csv")
