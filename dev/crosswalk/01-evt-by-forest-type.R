# =============================================================================
# 01-evt-by-forest-type.R - which LANDFIRE EVTs make each forest type in a pyrome (stage 5's 30 m mapping, before the 150 m modal)
# =============================================================================
# EVT 2016, with EVT 2001 where 2016 is "Recently ..." (as stage 5), crosswalked to forest type groups; area by forest type x EVT.
# Usage: Rscript dev/crosswalk/01-evt-by-forest-type.R [pyrome number, default 26]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) })
for (v in c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA")) if (grepl("syncro", tolower(Sys.getenv(v)))) Sys.unsetenv(v)
a <- commandArgs(TRUE); PY <- if (length(a)) as.integer(a[1]) else 26L
DS <- "F:/lucas-master/Data Sources/"; DF <- "F:/lucasCore/defaults/landcover/"; OUT <- "F:/lucasCore/dev/crosswalk"
py <- read_sf(paste0(DS, "Pyromes/Data/Pyromes_CONUS_20200206.shp")); py <- py[py$PYROME == PY, ]
e16 <- rast(paste0(DS, "EVT/LF2016_EVT_200_CONUS/LF2016_EVT_200_CONUS/Tif/LC16_EVT_200.tif")); e01 <- rast(paste0(DS, "EVT/US_105_EVT/US_105_EVT/Tif/us_105evt.tif"))
pv <- vect(st_transform(py, crs(e16)))
e16 <- mask(crop(e16, pv), pv); levels(e16) <- NULL
x16 <- fread(paste0(DF, "evt2016-crosswalk-CONUS-v2.csv")); x01 <- fread(paste0(DF, "evt2001-crosswalk-CONUS-v2.csv"))
recent <- x16[grepl("Recently", EVT_NAME), VALUE]
t16 <- as.data.table(freq(e16))[, .(VALUE = as.integer(value), px = count)]
t16 <- merge(t16, x16[, .(VALUE, EVT_NAME, ID, LUCAS_State_Class_Name)], by = "VALUE", all.x = TRUE)
# the 2001 EVT under the "Recently" pixels of 2016
rp <- e16 %in% recent
e01c <- mask(project(crop(e01, project(pv, crs(e01))), e16, method = "near"), rp, maskvalues = c(0, NA)); levels(e01c) <- NULL
t01 <- as.data.table(freq(e01c))[, .(Value = as.integer(value), px = count)]
t01 <- merge(t01, x01[, .(Value, EVT_Name, ID, LUCAS_State_Class_Name)], by = "Value", all.x = TRUE)
t <- rbind(t16[!VALUE %in% recent, .(Vintage = "2016", Code = VALUE, EVT = EVT_NAME, ID, Class = LUCAS_State_Class_Name, px)],
           t01[, .(Vintage = "2001 (under 2016 Recently)", Code = Value, EVT = EVT_Name, ID, Class = LUCAS_State_Class_Name, px)])
t[, km2 := round(px * 900 / 1e6, 1)]
f <- t[ID >= 100 & ID <= 999][order(ID, -km2)]
fwrite(f, file.path(OUT, sprintf("evt-by-forest-type-P%d.csv", PY)))
cat(sprintf("Pyrome %d: forest EVT pixels %.0f km2 (2001 under Recently: %.0f km2)\n\n", PY, sum(f$km2), f[Vintage != "2016", sum(km2)]))
cat("Area by forest type:\n"); print(f[, .(km2 = sum(km2), EVTs = .N), by = .(ID, Class)][order(-km2)])
cat("\nEVTs of every forest type:\n"); for (i in unique(f$ID)) { g <- f[ID == i]; cat(sprintf("\n%d %s (%.0f km2)\n", i, g$Class[1], sum(g$km2)))
  print(g[, .(km2 = sum(km2)), by = .(Code, EVT)][order(-km2)][1:min(.N, 8)], row.names = FALSE) }
