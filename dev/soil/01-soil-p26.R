# =============================================================================
# 01-soil-p26.R - where the soil carbon of the P26 build comes from, and what gSSURGO says there (user's lucasBuild-fulltest-v2, read only)
# =============================================================================
# (1) gSSURGO soc 0-999 (the whole profile, g C/m2) at 30 m over P26: missing / zero share, distribution, Mg C/ha.
# (2) the chain in the build: stage 5 soil targets (ecodivision x class mean of gSSURGO on the 150 m grid) -> stage 3 calibrated soil
#     multiplier -> stage 4 belowground slow at age 100 -> stage 8 soil map, by forest class.
# (3) live carbon vs soil carbon, cell by cell.
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table); library(rsyncrosim) })
for (v in c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA")) if (grepl("syncro", tolower(Sys.getenv(v)))) Sys.unsetenv(v)
DS <- "F:/lucas-master/Data Sources/"; R4 <- "F:/lucasCore/dev/libs/lucasBuild-fulltest-v2.ssim.data/Scenario-4/"
so <- rast(paste0(DS, "gSSURGO/gssurgo_soc_0_999.tif")); cat("gSSURGO:", names(so), datatype(so), "res", res(so), "\n")
cat(paste(readLines(paste0(DS, "gSSURGO/gssurgo_soc_0_999.tif.aux.xml"), warn = FALSE), collapse = "\n"), "\n")
py <- read_sf(paste0(DS, "Pyromes/Data/Pyromes_CONUS_20200206.shp")); pv <- vect(st_transform(py[py$PYROME == 26, ], crs(so)))
s30 <- mask(crop(so, pv), pv)
v <- values(s30, mat = FALSE); n <- sum(!is.na(values(mask(init(s30, 1), pv), mat = FALSE)))
cat(sprintf("\n(1) P26 at 30 m: %d pixels; NA %.1f%%, zero %.1f%%\n", n, 100 * mean(is.na(v[seq_len(length(v))])), 100 * mean(v == 0, na.rm = TRUE)))
q <- quantile(v[!is.na(v) & v > 0] * 0.01, c(.05, .25, .5, .75, .95)); cat("Mg C/ha (non-zero):", paste(names(q), round(q, 1), collapse = "  "), " mean", round(mean(v[!is.na(v) & v > 0]) * 0.01, 1), "\n")

L <- ssimLibrary("F:/lucasCore/dev/libs/lucasBuild-fulltest-v2.ssim"); R <- scenario(L, 4)
g <- function(sh) as.data.table(datasheet(R, sh, lookupsAsFactors = FALSE, optional = TRUE))
st <- g("lucasCore_OutputSoilTarget"); dc <- g("lucasCore_OutputDecayCalibration"); isc <- g("lucasCore_InitialStockCurve")
cat("\n(2) stage 5 soil targets (Mg C/ha):\n"); print(st[order(-Cells)][1:10])
a100 <- isc[Age == 100, .(BGS100 = round(mean(BGS), 1), Live100 = round(mean(TotalLive), 1)), by = .(StratumId, StateClassId)]
ch <- merge(st[, .(StratumId, StateClassId, Target = SoilTarget, Cells)], dc[, .(StratumId, StateClassId, SoilMultiplier = round(SoilDecayMultiplier, 3), SoilSource)],
            by = c("StratumId", "StateClassId"), all.x = TRUE)
ch <- merge(ch, a100, by = c("StratumId", "StateClassId"), all.x = TRUE)
cat("\ntarget -> calibrated soil decay multiplier -> spin-up BG slow and live carbon at age 100:\n"); print(ch[order(-Cells)][1:10])

f <- function(p) rast(list.files(file.path(R4, "stsim_InitialStockSpatial"), p, full.names = TRUE)[1])
bgs <- f("^DOM-Belowground-Slow"); live <- sum(rast(lapply(c("^Biomass-Merchantable", "^Biomass-Other", "^Biomass-Foliage", "^Biomass-Fine", "^Biomass-Coarse"), f)))
S <- rast(list.files(file.path(R4, "stsim_InitialConditionsSpatial"), "^StateClass", full.names = TRUE)[1])
d <- data.table(S = values(S, mat = FALSE), live = values(live, mat = FALSE), soil = values(bgs, mat = FALSE))[!is.na(S) & S >= 100]
cat(sprintf("\n(3) forest cells: mean live %.0f, mean soil %.0f Mg C/ha; soil/live ratio of the means %.2f; median per-cell ratio %.2f\n",
            mean(d$live), mean(d$soil), mean(d$soil) / mean(d$live), median(d$soil / pmax(d$live, 1))))
print(d[, .(cells = .N, live = round(mean(live)), soil = round(mean(soil)), ratio = round(mean(soil) / mean(live), 2)), by = S][order(-cells)][1:8])
