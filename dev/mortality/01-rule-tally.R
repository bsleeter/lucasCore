# =============================================================================
# 01-rule-tally.R - to-do 3 (drought and insect mortality), phase 0: the candidate map rule at 30 m over one region, by year
# =============================================================================
# Design doc: "lucasCore drought and insect mortality design" (2026-11-22). The rule for a 30 m pixel in year y:
#   forest the year before (NLCD 41-43) with tree canopy cover >= --floor; canopy falls by a share between y-1 and the lower of
#   y+1, y+2 (USFS tree canopy cover); no fire or cutting from y-2 to y+2 (MTBS classes 1-4; LCMS Prescribed Fire 6, Wildfire 7,
#   Mechanical 8, Tree Removal 9) and no other named LCMS cause (Wind 1, Hurricane 2, Snow or Ice 3, Inundation 5).
#   LCMS Insect, Disease or Drought Stress (12), Desiccation (4) and Southern Pine Beetle (11) are recorded as corroboration:
#   in year y, and in any year y-2..y+2.
# Read-only on the region's files in a Data Sources Home (regions/<name>). Writes <out>/rule-tally.csv and prints the tables.
# Usage: Rscript dev/mortality/01-rule-tally.R <region folder> <out folder> [--floor=20] [--workers=18] [--years=1987-2021]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(parallel) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; R <- pos[1]; OUT <- pos[2]; dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
FLOOR <- as.numeric(opt("floor", 20)); yr <- as.integer(strsplit(opt("years", "1987-2021"), "-")[[1]]); YRS <- yr[1]:yr[2]
cl <- makeCluster(as.integer(opt("workers", 18)))
res <- parLapply(cl, YRS, function(y, R, FLOOR) { library(terra); library(data.table); terraOptions(progress = 0, memfrac = 0.02)
  nl <- function(k) rast(Sys.glob(file.path(R, "land-cover/nlcd-annual", sprintf("Annual_NLCD_LndCov_%d_*.tif", k)))[1])
  G <- nl(y - 1); p <- values(G, mat = FALSE)
  on_grid <- function(r) { levels(r) <- NULL; coltab(r) <- NULL; if (!compareGeom(r, G, stopOnError = FALSE)) r <- project(r, G, method = "near"); values(r, mat = FALSE) }
  lc <- function(k) on_grid(rast(file.path(R, "disturbance/lcms", k, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", k))))
  mt <- function(k) { f <- file.path(R, "disturbance/mtbs", sprintf("mtbs_CONUS_%d.tif", k)); if (!file.exists(f)) return(rep(FALSE, length(p)))
    v <- tryCatch(on_grid(rast(f)), error = function(e) NULL); if (is.null(v)) rep(FALSE, length(p)) else v %in% 1:4 }
  tc <- function(k) { v <- on_grid(rast(file.path(R, "land-cover/tree-canopy", sprintf("science_tcc_conus_%d.tif", k)))); v[v > 100] <- NA; v }
  xs <- lapply((y - 2):(y + 2), lc); x <- xs[[3]]
  other <- Reduce(`|`, lapply(xs, function(v) v %in% c(1, 2, 3, 5, 6, 7, 8, 9)))   # a named cause that is not drought or insects, y-2..y+2
  stress_w <- Reduce(`|`, lapply(xs, function(v) v %in% c(4, 11, 12)))             # drought or insect class, y-2..y+2
  burn <- Reduce(`|`, lapply((y - 2):(y + 2), mt))
  t0 <- tc(y - 1); t2 <- pmin(tc(y + 1), tc(y + 2)); rel <- (t0 - t2) / t0
  q <- values(nl(y + 2), mat = FALSE)
  ok <- p %in% 41:43 & !is.na(t0) & t0 >= FLOOR & !is.na(rel)
  d <- data.table(Year = y, stress_y = x[ok] %in% c(4, 11, 12), stress_w = stress_w[ok], clean = !(other[ok] | burn[ok]), rel = rel[ok], nonfor = q[ok] %in% c(52, 71))
  d[, .(km2 = .N * 9e-4, loss30 = sum(rel >= 0.3) * 9e-4, loss50 = sum(rel >= 0.5) * 9e-4, loss70 = sum(rel >= 0.7) * 9e-4,
        loss50_nonfor = sum(rel >= 0.5 & nonfor) * 9e-4, mean_rel = mean(rel)), by = .(Year, clean, stress_y, stress_w)] }, R = R, FLOOR = FLOOR)
stopCluster(cl)
d <- rbindlist(res); fwrite(d, file.path(OUT, "rule-tally.csv"))
options(width = 250)
cat(sprintf("Region %s; forest pixels (NLCD 41-43 the year before, canopy >= %g%%), %d-%d. clean = no fire, cutting or other named cause y-2..y+2\n\n", basename(R), FLOOR, min(YRS), max(YRS)))
cat("Totals over the years (km2-years):\n")
print(d[, .(km2 = round(sum(km2)), loss30 = round(sum(loss30), 1), loss50 = round(sum(loss50), 1), loss70 = round(sum(loss70), 1), loss50_pct = round(100 * sum(loss50) / sum(km2), 2),
            loss50_to_shrub_grass_pct = round(100 * sum(loss50_nonfor) / sum(loss50), 1), mean_rel = round(weighted.mean(mean_rel, km2), 3)), by = .(clean, stress_y, stress_w)][order(-clean, -stress_y, -stress_w)])
cat("\nBy year, clean pixels (km2): forest; LCMS stress class that year; canopy loss >= 30/50/70% (the rule), and the share of each with an LCMS stress class within y-2..y+2\n")
b <- d[clean == TRUE, .(forest = sum(km2), stress = sum(km2[stress_y]), loss30 = sum(loss30), loss50 = sum(loss50), loss70 = sum(loss70),
                        corr30 = 100 * sum(loss30[stress_w]) / sum(loss30), corr50 = 100 * sum(loss50[stress_w]) / sum(loss50), corr70 = 100 * sum(loss70[stress_w]) / sum(loss70),
                        loss50_pct_forest = 100 * sum(loss50) / sum(km2)), by = Year][order(Year)]
print(b[, lapply(.SD, round, 2)], nrows = 60)
