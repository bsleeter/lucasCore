# =============================================================================
# 05-itrdb-parse.R - read the ITRDB NOAA-template chronologies (CONUS base sites) into one table
# =============================================================================
# Writes dev/climate/itrdb-sites.csv (site, lat, lon, elevation, species, years, ecodivision, FIA forest type group of the species
# where known) and dev/climate/itrdb-series.csv (site, year, standard ring-width index, sample depth).
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) })
for (v in c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA")) if (grepl("syncro", tolower(Sys.getenv(v)))) Sys.unsetenv(v)
D <- "F:/lucas-master/Data Sources/ITRDB/chronologies"; OUT <- "F:/lucasCore/dev/climate"
fs <- list.files(D, "-crn-noaa[.]txt$", full.names = TRUE)
meta <- function(l, k) { m <- grep(sprintf("^#\\s*%s:", k), l, value = TRUE); if (!length(m)) return(NA_character_); trimws(sub(sprintf("^#\\s*%s:", k), "", m[1])) }
rd <- lapply(fs, function(f) { l <- readLines(f, warn = FALSE, encoding = "UTF-8")
  site <- sub("-crn-noaa[.]txt$", "", basename(f))
  sp <- meta(l, "Species_Code"); if (is.na(sp)) sp <- sub(".* - ([A-Z]{4}) - ITRDB.*", "\\1", l[1])
  s <- data.table(site = site, title = sub("^#\\s*", "", l[1]), lat = as.numeric(meta(l, "Northernmost_Latitude")), lon = as.numeric(meta(l, "Easternmost_Longitude")),
                  elev = suppressWarnings(as.numeric(meta(l, "Elevation_m"))), species = sp, first = as.integer(meta(l, "First_Year")), last = as.integer(meta(l, "Last_Year")))
  dl <- l[!startsWith(l, "#") & nzchar(trimws(l))]
  if (length(dl) < 2) return(list(s, NULL))
  x <- tryCatch(fread(text = paste(dl, collapse = "\n"), sep = "\t", header = TRUE), error = function(e) NULL)
  if (is.null(x) || !all(c("age_CE", "trsgi") %in% names(x))) return(list(s, NULL))
  list(s, data.table(site = site, year = as.integer(x$age_CE), rwi = as.numeric(x$trsgi), depth = if ("numsamp" %in% names(x)) as.integer(x$numsamp) else NA_integer_)) })
sites <- rbindlist(lapply(rd, `[[`, 1)); ser <- rbindlist(lapply(rd, `[[`, 2))
ser <- ser[!is.na(rwi) & rwi >= 0]
# ecodivision of each site
eco <- vect("F:/lucas-master/Data Sources/FIA/EcoDivision_map/EcoDivisions_Dissolve.shp")
pts <- project(vect(sites[!is.na(lat) & !is.na(lon)], geom = c("lon", "lat"), crs = "EPSG:4326"), crs(eco))
e <- extract(eco[, "StrtmNm"], pts); sites[!is.na(lat) & !is.na(lon), ecodiv := e$StrtmNm]
sites <- merge(sites, ser[, .(n_years = .N, y_last = max(year), n_since1985 = sum(year >= 1985), med_depth = as.numeric(median(depth, na.rm = TRUE))), by = site], by = "site", all.x = TRUE)
fwrite(sites, file.path(OUT, "itrdb-sites.csv")); fwrite(ser, file.path(OUT, "itrdb-series.csv"))
cat(nrow(sites), "sites;", uniqueN(ser$site), "with data;", sites[is.na(ecodiv), .N], "outside the ecodivisions\n")
cat("\nlast year of the chronology:\n"); print(table(cut(sites$y_last, c(0, 1960, 1980, 1985, 1990, 2000, 2010, 2025), dig.lab = 4)))
cat("\nsites with >= 15 years since 1985:", sites[n_since1985 >= 15, .N], "; >= 10:", sites[n_since1985 >= 10, .N], "\n")
cat("\ntop species:\n"); print(head(sites[, .N, by = species][order(-N)], 15))
cat("\nby ecodivision (>= 15 yr since 1985 / all):\n"); print(sites[, .(all = .N, recent = sum(n_since1985 >= 15, na.rm = TRUE)), by = ecodiv][order(-all)])
