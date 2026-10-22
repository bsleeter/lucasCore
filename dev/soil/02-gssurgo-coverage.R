# =============================================================================
# 02-gssurgo-coverage.R - gSSURGO soc 0-999 inside P26 only: the -1920 sentinel, zeros, real values, and where the gaps are
# =============================================================================
# Also re-computes the stage 5 targets two ways on the build's 150 m grid: as stage 5 did (0 = missing, -1920 averaged in) and with
# -1920 treated as missing, by ecodivision x forest class; and the share of each class's cells with no gSSURGO value at all.
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) })
for (v in c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA")) if (grepl("syncro", tolower(Sys.getenv(v)))) Sys.unsetenv(v)
DS <- "F:/lucas-master/Data Sources/"; R4 <- "F:/lucasCore/dev/libs/lucasBuild-fulltest-v2.ssim.data/Scenario-4/"
so <- rast(paste0(DS, "gSSURGO/gssurgo_soc_0_999.tif"))
py <- read_sf(paste0(DS, "Pyromes/Data/Pyromes_CONUS_20200206.shp")); pv <- vect(st_transform(py[py$PYROME == 26, ], crs(so)))
s30 <- mask(crop(so, pv), pv); inside <- !is.na(values(mask(init(crop(so, pv), 1), pv), mat = FALSE)); v <- values(s30, mat = FALSE)[inside]
cat(sprintf("P26 inside the polygon: %d pixels (%.0f km2)\n", length(v), length(v) * 9e-4))
cat(sprintf("  NA %.1f%%; -1920 sentinel %.1f%%; other negative %.2f%%; zero %.1f%%; positive %.1f%%\n", 100 * mean(is.na(v)), 100 * mean(v == -1920, na.rm = TRUE) * mean(!is.na(v)),
            100 * mean(v < 0 & v != -1920, na.rm = TRUE) * mean(!is.na(v)), 100 * mean(v == 0, na.rm = TRUE) * mean(!is.na(v)), 100 * mean(v > 0, na.rm = TRUE) * mean(!is.na(v))))
q <- quantile(v[!is.na(v) & v > 0] * 0.01, c(.05, .25, .5, .75, .95)); cat("  positive values, Mg C/ha:", paste(names(q), round(q, 1), collapse = "  "), "\n")

# on the build's 150 m grid, by class
S <- rast(list.files(file.path(R4, "stsim_InitialConditionsSpatial"), "^StateClass", full.names = TRUE)[1])
P <- rast(list.files(file.path(R4, "stsim_InitialConditionsSpatial"), "^PrimaryStrata", full.names = TRUE)[1])
sc <- crop(so, project(as.polygons(ext(S) + 3000, crs = crs(S)), crs(so)))
a <- sc; NAflag(a) <- 0; as_built <- project(a, S, method = "average") * 0.01                    # stage 5: 0 missing, -1920 kept
b <- classify(sc, cbind(c(-Inf, 0), c(0, 0.5), c(NA, NA)), right = FALSE, others = NULL)          # every value <= 0 missing
b <- sc; b[b <= 0] <- NA; fixed <- project(b, S, method = "average") * 0.01
d <- data.table(S = values(S, mat = FALSE), P = values(P, mat = FALSE), built = values(as_built, mat = FALSE), fixed = values(fixed, mat = FALSE))[!is.na(S) & S >= 100]
cat("\nforest classes on the 150 m grid: soil target as built vs with -1920 (and 0) missing; share of cells with no gSSURGO value\n")
print(d[, .(cells = .N, as_built = round(mean(built, na.rm = TRUE), 1), fixed = round(mean(fixed, na.rm = TRUE), 1),
            cells_with_negative = round(mean(built < 0, na.rm = TRUE), 3), no_value = round(mean(is.na(fixed)), 3)), by = S][order(-cells)][1:8])
cat(sprintf("\nall forest cells: as built %.1f, fixed %.1f Mg C/ha; %.1f%% of forest cells have no gSSURGO value\n",
            mean(d$built, na.rm = TRUE), mean(d$fixed, na.rm = TRUE), 100 * mean(is.na(d$fixed))))
