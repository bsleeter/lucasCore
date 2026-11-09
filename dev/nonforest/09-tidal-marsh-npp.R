# =============================================================================
# 09-tidal-marsh-npp.R - mapped tidal marsh NPP by ecodivision and class (to-do 39 step 10, 2026-11-08)
# =============================================================================
# Woltz, Stagg, Byrd, Windham-Myers, Rovai and Zhu 2023, Biomass Carbon Stock and Net Primary Productivity in Tidal Herbaceous
# Wetlands of the Conterminous United States (USGS data release, doi 10.5066/P9I1PCLS, CC0): 30 m CONUS total NPP (gC/m2/yr) for 2015
# of estuarine (EEM) and palustrine (PEM) emergent tidal marsh; aboveground NPP is one third of the total everywhere (peak aboveground
# biomass with one crop a year; belowground from field and literature ratios).
# For each map class, the 30 m pixels are averaged to 900 m blocks (sum and count), each block takes the package ecodivision it lies
# in, and the pixel-weighted mean, 10th and 90th percentiles and area are written per ecodivision x class to
# defaults/stockflow/tidal-marsh-npp.csv. tools/make_emergent_wetland.R takes the estuarine NPP target from it where the map holds
# MIN_KM2 or more of the class; stage 8 (Tidal Marsh Productivity) divides each cell's mapped NPP by the map mean of its ecodivision x
# class, so only the pattern within an ecodivision comes from the cell.
# Input: TIDAL_NPP = the folder holding NPP_CONUSTidalEEM_gCm2.tif and NPP_CONUSTidalPEM_gCm2.tif (as unzipped, each in a folder of
# its name, or directly). Usage: TIDAL_NPP=<dir> Rscript dev/nonforest/09-tidal-marsh-npp.R   (about 10 minutes)
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages({ library(terra); library(data.table); library(sf) })
D <- Sys.getenv("TIDAL_NPP"); if (!dir.exists(D)) stop("set TIDAL_NPP to the folder with the unzipped NPP rasters")
terraOptions(progress = 0)
tif <- function(k) { f <- list.files(D, sprintf("^NPP_CONUSTidal%s_gCm2[.]tif$", k), recursive = TRUE, full.names = TRUE); f <- f[!dir.exists(f)]
  if (length(f) != 1) stop(sprintf("%d files NPP_CONUSTidal%s_gCm2.tif in %s", length(f), k, D)); f }
eco <- st_read(file.path(pkg, "defaults/strata/ecodivisions/EcoDivisions_Dissolve.shp"), quiet = TRUE)
base <- unique(st_drop_geometry(eco)[!startsWith(eco$ecodiv, "M"), c("ecodiv", "StrtmNm")])
eco$name <- ifelse(startsWith(eco$ecodiv, "M"), paste(base$StrtmNm[match(sub("^M", "", eco$ecodiv), base$ecodiv)], "Mountains"), eco$StrtmNm)
CLS <- c(EEM = "Wetland: Estuarine Emergent", PEM = "Wetland: Palustrine Emergent")
d <- rbindlist(lapply(names(CLS), function(k) { r <- rast(tif(k)); levels(r) <- NULL   # the cell value is the total NPP
  s <- aggregate(r, 30, fun = "sum", na.rm = TRUE); n <- aggregate(!is.na(r), 30, fun = "sum", na.rm = TRUE)
  x <- data.table(xyFromCell(s, 1:ncell(s)), sum = values(s, mat = FALSE), n = values(n, mat = FALSE))[n > 0]
  pts <- st_as_sf(x, coords = c("x", "y"), crs = crs(r)); x[, StratumId := eco$name[st_nearest_feature(st_transform(pts, st_crs(eco)), eco)]]
  x[, StateClassId := CLS[[k]]] }))
wq <- function(v, w, p) { o <- order(v); cw <- cumsum(w[o]) / sum(w); v[o][which(cw >= p)[1]] }
out <- d[, .(Km2 = round(sum(n) * 900 / 1e6, 1), Pixels = sum(n), MapNPP = round(sum(sum) / sum(n) / 100, 3),
            P10 = round(wq(sum / n, n, 0.1) / 100, 2), P90 = round(wq(sum / n, n, 0.9) / 100, 2)), by = .(StratumId, StateClassId)][order(StateClassId, StratumId)]
out[, Source := "Woltz et al. 2023 USGS data release doi 10.5066/P9I1PCLS (2015; Mg C/ha/yr = gC/m2/yr / 100; P10 and P90 of 900 m block means)"]
fwrite(out, file.path(pkg, "defaults/stockflow/tidal-marsh-npp.csv"))
print(out[, -"Source"])
