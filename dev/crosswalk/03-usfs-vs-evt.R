# =============================================================================
# 03-usfs-vs-evt.R - forest type groups in a pyrome from the USFS forest type group map (NFCMS tiles) vs LANDFIRE EVT (stage 5's mapping)
# =============================================================================
# Both at 30 m on the EVT grid inside the pyrome: area by group from each, the agreement where both call a pixel forest, and the
# pixels only one of them calls forest. Also every code found in the nine USFS tiles (for the crosswalk default).
# Usage: Rscript dev/crosswalk/03-usfs-vs-evt.R [pyrome, default 26]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) })
for (v in c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA")) if (grepl("syncro", tolower(Sys.getenv(v)))) Sys.unsetenv(v)
a <- commandArgs(TRUE); PY <- if (length(a)) as.integer(a[1]) else 26L
DS <- "F:/lucas-master/Data Sources/"; FT <- paste0(DS, "NFCMS/Forest Type/")
xw <- fread("F:/lucasCore/defaults/landcover/land-cover-crosswalks.csv", na.strings = "")
sc <- fread("F:/lucasCore/defaults/stsim/stsim_StateClass.csv"); nm <- function(id) sc$Name[match(id, sc$Id)]
e16 <- rast(paste0(DS, "EVT/LF2016_EVT_200_CONUS/LF2016_EVT_200_CONUS/Tif/LC16_EVT_200.tif")); levels(e16) <- NULL
py <- read_sf(paste0(DS, "Pyromes/Data/Pyromes_CONUS_20200206.shp")); pv <- vect(st_transform(py[py$PYROME == PY, ], crs(e16)))
e <- mask(crop(e16, pv), pv)
ftg <- function(v) ifelse(!is.na(v) & v >= 100 & v <= 999, v, NA)
x16 <- xw[Source == "EVT 2016"]; x16[, Id := sc$Id[match(StateClassId, sc$Name)]]
fe <- classify(e, cbind(x16$Code, ftg(x16$Id)), others = NA)
tiles <- list.files(FT, "_ForestType[.]tif$", full.names = TRUE)
hit <- Filter(function(f) { r <- rast(f); !is.null(intersect(ext(r), ext(project(pv, crs(r))))) }, tiles)
cat("USFS tiles covering the pyrome:", paste(basename(hit), collapse = ", "), "\n")
u <- do.call(merge, lapply(hit, function(f) { r <- rast(f); levels(r) <- NULL; crop(r, project(pv, crs(r))) }))
u <- mask(project(u, e, method = "near"), pv); u <- classify(u, cbind(0, NA)); u <- ifel(u >= 100 & u <= 999, u, NA)
d <- data.table(evt = values(fe, mat = FALSE), usfs = values(u, mat = FALSE))[!is.na(evt) | !is.na(usfs)]
km <- function(n) round(n * 9e-4)
cat(sprintf("\nPyrome %d at 30 m: forest by EVT %d km2, by USFS %d km2; both %d km2 (same group %.1f%% of those), EVT only %d, USFS only %d\n", PY,
            km(sum(!is.na(d$evt))), km(sum(!is.na(d$usfs))), km(sum(!is.na(d$evt) & !is.na(d$usfs))), 100 * d[!is.na(evt) & !is.na(usfs), mean(evt == usfs)],
            km(sum(!is.na(d$evt) & is.na(d$usfs))), km(sum(is.na(d$evt) & !is.na(d$usfs)))))
t <- merge(d[!is.na(evt), .(EVT_km2 = km(.N)), by = .(g = evt)], d[!is.na(usfs), .(USFS_km2 = km(.N)), by = .(g = usfs)], by = "g", all = TRUE)
t[, Group := nm(g)]; cat("\nArea by forest type group:\n"); print(t[order(-pmax(EVT_km2, USFS_km2, na.rm = TRUE))][, .(g, Group, EVT_km2, USFS_km2)])
cat("\nWhere both are forest, the USFS group of EVT's main groups (km2):\n")
x <- d[!is.na(evt) & !is.na(usfs), .N, by = .(evt, usfs)][, km2 := km(N)][order(-N)]
print(dcast(x[evt %in% x[, sum(N), by = evt][order(-V1)][1:5, evt]], evt ~ usfs, value.var = "km2", fill = 0))
codes <- sort(unique(unlist(lapply(tiles, function(f) { r <- rast(f); levels(r) <- NULL; s <- spatSample(r, 3e5, "regular", na.rm = TRUE)[[1]]; unique(s) }))))
cat("\nCodes in the nine USFS tiles (sampled):", paste(codes, collapse = " "), "\n"); cat("not ST-Sim state classes:", paste(setdiff(codes, sc$Id), collapse = " "), "\n")
