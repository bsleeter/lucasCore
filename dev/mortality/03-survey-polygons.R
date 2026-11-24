# =============================================================================
# 03-survey-polygons.R - to-do 3, phase 0: the canopy-loss rule against Forest Service aerial survey polygons, at polygon scale
# =============================================================================
# User, 2026-11-22: include a polygon-scale test. The survey polygons carry no confidence label and their intensity is unreliable
# per pixel (Slaton et al. 2021: a polygon outlines acres with mortality in them), so they are not used to set the threshold.
# The test is whether canopy loss rises with the mortality the observers recorded, and how much of what the rule flags lies
# inside their polygons. Source: Region 5 all-years IDS geodatabase (CONUS_Region5_AllYears.gdb; DAMAGE_AREAS, SURVEYED_AREAS).
# Subset: DAMAGE_TYPE mortality, bark beetles or drought on conifers left to the agent table printed below (nothing is dropped by
# agent; the table shows what is there), polygons only (AREA_TYPE), survey years --years (2013-2017: the die-off).
# Per 30 m pixel of the region's NLCD grid: the highest dead trees per acre (LEGACY_TPA) of any mortality polygon over it in those
# years, the number of years it was surveyed, canopy cover 2011 and the lowest of 2016-2018, fire and cutting 2010 on.
# Read-only. Usage: Rscript dev/mortality/03-survey-polygons.R <region folder> <ids gdb> <out folder> [--years=2013-2017]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; R <- pos[1]; GDB <- pos[2]; OUT <- pos[3]; dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
yr <- as.integer(strsplit(opt("years", "2013-2017"), "-")[[1]]); YRS <- yr[1]:yr[2]
terraOptions(progress = 0); options(width = 250)
nl <- function(k) rast(Sys.glob(file.path(R, "land-cover/nlcd-annual", sprintf("Annual_NLCD_LndCov_%d_*.tif", k)))[1])
G <- nl(2011); n <- ncell(G)
ly <- st_layers(GDB)$name; LA <- grep("^DAMAGE_AREAS", ly, value = TRUE)[1]; LS <- grep("^SURVEYED_AREAS", ly, value = TRUE)[1]
box <- st_as_sfc(st_bbox(c(xmin = xmin(G), ymin = ymin(G), xmax = xmax(G), ymax = ymax(G)), crs = st_crs(crs(G))))
rd <- function(layer) { c0 <- st_crs(st_read(GDB, query = sprintf("SELECT * FROM \"%s\" LIMIT 1", layer), quiet = TRUE))
  x <- st_read(GDB, layer = layer, wkt_filter = st_as_text(st_transform(box, c0)), quiet = TRUE); x <- x[x$SURVEY_YEAR %in% YRS, ]
  st_transform(st_make_valid(st_cast(x, "MULTIPOLYGON")), st_crs(crs(G))) }
da <- rd(LA); d <- as.data.table(st_drop_geometry(da))
cat(sprintf("%s: %d damage areas over the region, survey years %d-%d\n", basename(GDB), nrow(d), min(YRS), max(YRS)))
cat("\nby damage type and area type:\n"); print(d[, .N, by = .(DAMAGE_TYPE, AREA_TYPE)][order(-N)])
cat("\nfields filled by year (mortality records): dead trees per acre, percent affected, collection mode, source\n")
mort <- grepl("mortality", d$DAMAGE_TYPE, ignore.case = TRUE)
print(d[mort, .(records = .N, acres = round(sum(ACRES)), tpa_filled = sum(!is.na(LEGACY_TPA) & LEGACY_TPA > 0), tpa_median = median(LEGACY_TPA[LEGACY_TPA > 0], na.rm = TRUE),
                pct_filled = sum(!is.na(PERCENT_MID)), modes = paste(unique(COLLECTION_MODE), collapse = "|"), sources = paste(unique(DATA_SOURCE_NAME), collapse = "|")), by = SURVEY_YEAR][order(SURVEY_YEAR)])
cat("\nmortality records by agent (top 12 by acres):\n"); print(d[mort, .(records = .N, acres = round(sum(ACRES))), by = .(DCA_COMMON_NAME, HOST_GROUP)][order(-acres)][1:12])
keep <- mort & !is.na(d$LEGACY_TPA) & d$LEGACY_TPA > 0 & !grepl("point|grid", d$AREA_TYPE, ignore.case = TRUE)
cat(sprintf("\nkept: %d mortality polygons with dead trees per acre > 0 (%.0f acres)\n", sum(keep), sum(d$ACRES[keep])))
tpa <- rasterize(vect(da[keep, ]), G, field = "LEGACY_TPA", fun = "max", background = 0)
sv <- rd(LS); surveyed <- init(G, 0)
for (y in YRS) { s <- sv[sv$SURVEY_YEAR == y, ]; if (nrow(s)) surveyed <- surveyed + rasterize(vect(s), G, field = 1, background = 0) }
on <- function(r) { levels(r) <- NULL; coltab(r) <- NULL; if (!compareGeom(r, G, stopOnError = FALSE)) r <- project(r, G, method = "near"); values(r, mat = FALSE) }
tc <- function(k) { v <- on(rast(file.path(R, "land-cover/tree-canopy", sprintf("science_tcc_conus_%d.tif", k)))); v[v > 100] <- NA; v }
lc <- function(k) on(rast(file.path(R, "disturbance/lcms", k, sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", k))))
mt <- function(k) { f <- file.path(R, "disturbance/mtbs", sprintf("mtbs_CONUS_%d.tif", k)); if (!file.exists(f)) return(rep(FALSE, n)); v <- tryCatch(on(rast(f)), error = function(e) NULL); if (is.null(v)) rep(FALSE, n) else v %in% 1:4 }
xs <- lapply(2010:2018, lc)
other <- Reduce(`|`, lapply(xs, function(v) v %in% c(1, 2, 3, 5, 6, 7, 8, 9))); stress <- Reduce(`|`, lapply(xs[3:9], function(v) v %in% c(4, 11, 12))); burn <- Reduce(`|`, lapply(2010:2018, mt))
t0 <- tc(2011); tp <- pmin(tc(2016), tc(2017), tc(2018)); nlcd <- values(G, mat = FALSE)
p <- data.table(tpa = values(tpa, mat = FALSE), ns = values(surveyed, mat = FALSE), t0 = t0, tp = tp, stress = stress)[nlcd %in% 41:43 & !is.na(t0) & t0 >= 20 & !is.na(tp) & !(other | burn)]
p[, rel := (t0 - tp) / t0]
p[, cls := fcase(tpa > 40, "5: over 40 dead trees/acre", tpa > 15, "4: 15-40", tpa > 5, "3: 5-15", tpa > 0, "2: up to 5",
                 ns >= 3, "1: surveyed 3+ years, nothing mapped", default = "0: surveyed under 3 years, nothing mapped")]
cat(sprintf("\nClean forest pixels (NLCD forest 2011, canopy >= 20%%, no fire, cutting or other named cause 2010-2018): %.0f km2\n", nrow(p) * 9e-4))
cat("canopy loss 2011 to the lowest of 2016-2018, by the highest dead trees per acre the surveys recorded over the pixel:\n")
tab <- p[, .(km2 = round(.N * 9e-4), canopy_2011 = round(mean(t0), 1), rel_loss_mean = round(mean(rel), 3), rel_loss_median = round(median(rel), 3),
             loss30_pct = round(100 * mean(rel >= 0.3), 1), loss50_pct = round(100 * mean(rel >= 0.5), 1), loss70_pct = round(100 * mean(rel >= 0.7), 2),
             lcms_stress_pct = round(100 * mean(stress), 1)), by = cls][order(cls)]
print(tab); fwrite(tab, file.path(OUT, "survey-polygons.csv"))
cat("\nwhere the rule's pixels lie: share of the clean pixels with canopy loss of at least 30 / 50 / 70% that are inside a mortality polygon (any intensity; inside one over 15 dead trees/acre)\n")
print(rbindlist(lapply(c(0.3, 0.5, 0.7), function(t) { f <- p$rel >= t
  data.table(canopy_loss = t, flagged_km2 = round(sum(f) * 9e-4, 1), inside_any_pct = round(100 * mean(p$tpa[f] > 0), 1), inside_over15_pct = round(100 * mean(p$tpa[f] > 15), 1),
             forest_inside_any_pct = round(100 * mean(p$tpa > 0), 1), forest_inside_over15_pct = round(100 * mean(p$tpa > 15), 1)) })))
