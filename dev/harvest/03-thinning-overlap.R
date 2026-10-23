# =============================================================================
# 03-thinning-overlap.R - LANDFIRE Thinning vs LCMS Tree Removal in the P26 pyrome, 1999-2023 (30 m)
# =============================================================================
# How much LANDFIRE Thinning area LCMS sees as Tree Removal (any year y-1..y+2), and how much of LCMS partial removal (Tree Removal that
# stays forest) LANDFIRE records as Thinning/Harvest/Clearcut; by owner. Explains the 125 vs 35 km2/yr gap.
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(parallel) })
CA <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim.data/lucasCore-suitability/r30_-2170395_1863765_5539_11473_1985-2023"
LF <- "F:/lucas-master/Data Sources/Landfire Disturbance"; LC <- "F:/lucas-master/Data Sources/LCMS/v2025-11/Change_Annual"
cf <- function(k) file.path(CA, paste0(k, ".tif")); YRS <- 1999:2023
own <- values(rast(cf("owner")), mat = FALSE)
OWN <- c(`0` = "Not forest", `1` = "Family", `2` = "Corporate", `3` = "TIMO/REIT", `4` = "Other private", `5` = "Federal", `6` = "State", `7` = "Local", `8` = "Tribal")
cl <- makeCluster(13); on.exit(stopCluster(cl))
yr <- parLapply(cl, YRS, function(y, CA, LF, LC) { library(terra); library(data.table); terraOptions(progress = 0, memfrac = 0.05)
  cf <- function(k) file.path(CA, paste0(k, ".tif")); G <- rast(cf("region")); rg <- values(G, mat = FALSE)
  p <- values(rast(cf(sprintf("nlcd_%d", y - 1))), mat = FALSE)
  d <- file.path(LF, sprintf("US_DIST%d", y)); tif <- Sys.glob(file.path(d, "*", "Tif", "*.tif"))[1]; at <- fread(Sys.glob(file.path(d, "*", "CSV_Data", "*.csv"))[1]); setnames(at, toupper(names(at)))
  types <- c("Thinning", "Harvest", "Clearcut"); rcl <- cbind(at$VALUE, match(at$DIST_TYPE, types)); rcl <- rcl[!is.na(rcl[, 2]), , drop = FALSE]
  r <- rast(tif); r <- crop(r, project(as.polygons(ext(G), crs = crs(G)), crs(r)), snap = "out"); levels(r) <- NULL
  x <- values(project(classify(r, rcl, others = NA), G, method = "near"), mat = FALSE); i <- which(!is.na(rg) & !is.na(x))
  l <- rast(file.path(LC, y, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", y))); l <- crop(l, project(as.polygons(ext(G), crs = crs(G)), crs(l)), snap = "out"); levels(l) <- NULL; coltab(l) <- NULL
  z <- values(project(l, G, method = "near"), mat = FALSE); j <- which(!is.na(rg) & z == 9 & p %in% 41:43)
  list(lf = data.table(cell = i, type = types[x[i]], Year = y), tr = data.table(cell = j, Year = y)) }, CA = CA, LF = LF, LC = LC)
lf <- rbindlist(lapply(yr, `[[`, "lf")); tr <- rbindlist(lapply(yr, `[[`, "tr")); km2 <- 900 / 1e6
cat(sprintf("LANDFIRE 1999-2023 (km2/yr): Thinning %.1f, Harvest %.1f, Clearcut %.1f; LCMS Tree Removal on forest %.1f\n",
            lf[type == "Thinning", .N] * km2 / 25, lf[type == "Harvest", .N] * km2 / 25, lf[type == "Clearcut", .N] * km2 / 25, nrow(tr) * km2 / 25))
a <- tr[, .(cell, TY = Year)][lf, on = "cell", allow.cartesian = TRUE][, .(seen = any(!is.na(TY) & TY >= Year - 1 & TY <= Year + 2)), by = .(cell, Year, type)]
a[, Owner := OWN[as.character(own[cell])]]
cat("\nLANDFIRE events that LCMS sees as Tree Removal (y-1..y+2):\n"); print(a[, .(km2 = round(.N * km2, 0), seen_by_LCMS = sprintf("%.0f%%", 100 * mean(seen))), by = type])
cat("\n... Thinning by owner:\n"); print(a[type == "Thinning", .(km2 = round(.N * km2, 0), seen_by_LCMS = sprintf("%.0f%%", 100 * mean(seen))), by = Owner][order(-km2)])
b <- lf[, .(cell, LY = Year, type)][tr, on = "cell", allow.cartesian = TRUE][, .(rec = { k <- !is.na(LY) & LY >= Year - 2 & LY <= Year + 1; if (any(k)) paste(sort(unique(type[k])), collapse = "+") else "(not in LANDFIRE)" }), by = .(cell, Year)]
cat("\nLCMS Tree Removal on forest by what LANDFIRE records (y-2..y+1):\n"); print(b[, .(km2 = round(.N * km2, 0), share = sprintf("%.0f%%", 100 * .N / nrow(b))), by = rec][order(-km2)])
