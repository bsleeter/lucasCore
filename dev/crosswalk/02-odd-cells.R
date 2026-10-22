# =============================================================================
# 02-odd-cells.R - where do a build's cells of a given forest type come from? (the user's lucasBuild-fulltest-v2, read only)
# =============================================================================
# For each odd class: the 30 m EVT 2016 and EVT 2001 values under its cells, and how stage 5 got there (2016 forest EVT, 2001 forest
# EVT where 2016 is not forest, or the neighbour fill of cells with no forest EVT pixel at all).
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
for (v in c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA")) if (grepl("syncro", tolower(Sys.getenv(v)))) Sys.unsetenv(v)
DS <- "F:/lucas-master/Data Sources/"; DF <- "F:/lucasCore/defaults/landcover/"
R4 <- "F:/lucasCore/dev/libs/lucasBuild-fulltest-v2.ssim.data/Scenario-4/"
S <- rast(list.files(file.path(R4, "stsim_InitialConditionsSpatial"), "^StateClass", full.names = TRUE)[1])
e16 <- rast(paste0(DS, "EVT/LF2016_EVT_200_CONUS/LF2016_EVT_200_CONUS/Tif/LC16_EVT_200.tif")); e01 <- rast(paste0(DS, "EVT/US_105_EVT/US_105_EVT/Tif/us_105evt.tif"))
levels(e16) <- NULL; levels(e01) <- NULL   # raw codes, not category labels
x16 <- fread(paste0(DF, "evt2016-crosswalk-CONUS-v2.csv")); x01 <- fread(paste0(DF, "evt2001-crosswalk-CONUS-v2.csv"))
ftg <- function(v) ifelse(!is.na(v) & v >= 100 & v <= 999, v, NA)
for (cls in c(990, 700, 920)) {
  cells <- which(values(S, mat = FALSE) == cls); xy <- xyFromCell(S, cells)
  # every 30 m pixel inside those 150 m cells (5 x 5 per cell)
  off <- expand.grid(dx = seq(-60, 60, 30), dy = seq(-60, 60, 30))
  pts <- vect(do.call(rbind, lapply(seq_len(nrow(off)), function(i) cbind(xy[, 1] + off$dx[i], xy[, 2] + off$dy[i]))), crs = crs(S))
  v16 <- extract(e16, project(pts, crs(e16)), ID = FALSE)[[1]]; v01 <- extract(e01, project(pts, crs(e01)), ID = FALSE)[[1]]
  v16 <- as.integer(if (is.factor(v16)) levels(v16)[v16] else v16); v01 <- as.integer(if (is.factor(v01)) levels(v01)[v01] else v01)
  d <- data.table(v16, v01)[, `:=`(f16 = ftg(x16$ID[match(v16, x16$VALUE)]), f01 = ftg(x01$ID[match(v01, x01$Value)]))]
  d[, how := fifelse(!is.na(f16), "2016 forest EVT", fifelse(!is.na(f01), "2001 forest EVT (2016 not forest)", "no forest EVT"))]
  cat(sprintf("\n==== class %d: %d cells (%.0f km2), %d pixels\n", cls, length(cells), length(cells) * 0.0225, nrow(d)))
  print(d[, .N, by = how][, share := round(N / sum(N), 3)][])
  cat("forest type the 30 m pixels give (2016, else 2001):\n"); print(d[, .N, by = .(ft = fifelse(!is.na(f16), f16, f01))][order(-N)][1:6])
  w <- d[!is.na(f01) & is.na(f16) & f01 == cls, .N, by = v01][order(-N)][1:5]; w[, EVT2001 := x01$EVT_Name[match(v01, x01$Value)]]
  cat("2001 EVTs giving this class where 2016 is not forest:\n"); print(w)
  w2 <- d[is.na(f16), .N, by = v16][order(-N)][1:5]; w2[, EVT2016 := x16$EVT_NAME[match(v16, x16$VALUE)]]
  cat("2016 EVTs (non-forest) of those pixels:\n"); print(w2) }
