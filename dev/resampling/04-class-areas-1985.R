# =============================================================================
# 04-class-areas-1985.R - to-do item 8: every NLCD class's 1985 area at 30 m against the 150 m modal and area-matched maps (P26)
# =============================================================================
# 30 m area = the 30 m pixels of each class inside the study area's 150 m cells (same aggregation blocks as the Build). Modal = the
# Build's map; area match = developed matched per county (02-compare-methods.R), the rest modal or the cell's most common
# non-developed class. Writes dev/resampling/class-areas-1985.csv. Read-only.
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) })
pkg <- "F:/lucasCore"; build <- file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim.data/Scenario-2"); km2 <- 0.0225
for (e in parse(file.path(pkg, "src/shared.R")))
  if (is.call(e) && identical(as.character(e[[1]]), "<-") && as.character(e[[2]]) %in% c("MODEL_CRS", "model_lattice", "grid_blocks")) eval(e, globalenv())
R <- rast(file.path(build, "stsim_InitialConditionsSpatial", "StateClass.tif"))
L <- model_lattice(st_transform(read_sf("F:/lucas-master/Data Sources/FIA/EcoDivision_map/EcoDivisions_Dissolve.shp"), MODEL_CRS), res(R)[1])
n30 <- rast("F:/lucas-master/Data Sources/NLCD/Annual NLCD/Annual_NLCD_LndCov_1985_CU_C1V0.tif"); b <- grid_blocks(n30, L, R)
x <- crop(n30, b$ext); levels(x) <- NULL
cls <- c(11, 12, 21, 22, 23, 24, 31, 41, 42, 43, 52, 71, 81, 82, 90, 95)
cnt <- mask(project(aggregate(segregate(x, classes = cls), b$fact, "sum", na.rm = TRUE), R, method = "near"), R)
a30 <- global(cnt, "sum", na.rm = TRUE)[[1]] * 900 / 1e6

s <- rast(file.path(pkg, "dev/resampling/cache/shares_1985.tif")); m <- values(s[["modal"]], mat = FALSE); d <- values(s[["dev"]], mat = FALSE)
dm <- values(s[["devmode"]], mat = FALSE); nd <- values(s[["nondev"]], mat = FALSE); ok <- !is.na(m)
county <- values(rast(file.path(build, "stsim_InitialConditionsSpatial", "SecondaryStrata.tif")), mat = FALSE)
isdev <- function(v) !is.na(v) & v >= 21 & v <= 24
dd <- d; dd[is.na(dd)] <- 0; take <- logical(length(m)); sel <- ok & !is.na(county)
dt <- data.table(i = which(sel), c = county[sel], d = dd[sel]); dt[, k := round(sum(d)), by = c]; setorder(dt, c, -d); dt[, r := seq_len(.N), by = c]
take[dt[r <= k & d > 0, i]] <- TRUE; am <- m; am[take] <- dm[take]; lo <- ok & isdev(m) & !take; am[lo] <- nd[lo]

name <- c(`11` = "Open water", `12` = "Ice/snow", `21` = "Developed open", `22` = "Developed low", `23` = "Developed medium", `24` = "Developed high",
          `31` = "Barren", `41` = "Deciduous forest", `42` = "Evergreen forest", `43` = "Mixed forest", `52` = "Shrub/scrub", `71` = "Grassland",
          `81` = "Pasture/hay", `82` = "Cultivated crops", `90` = "Woody wetlands", `95` = "Herbaceous wetlands")
res <- data.table(code = cls, class = name[as.character(cls)], km2_30m = round(a30, 1),
                  km2_modal = round(sapply(cls, function(c) sum(m == c, na.rm = TRUE)) * km2, 1),
                  km2_areamatch = round(sapply(cls, function(c) sum(am == c, na.rm = TRUE)) * km2, 1))
res[, `:=`(modal_pct = round(100 * km2_modal / km2_30m), areamatch_pct = round(100 * km2_areamatch / km2_30m))]
tot <- res[, .(code = NA, class = "Total", km2_30m = sum(km2_30m), km2_modal = sum(km2_modal), km2_areamatch = sum(km2_areamatch), modal_pct = NA, areamatch_pct = NA)]
res <- rbind(res, tot)
err <- function(col) round(sum(abs(res[class != "Total"][[col]] - res[class != "Total", km2_30m])) / 2)
cat(sprintf("Area misallocated (half the sum of absolute class differences): modal %d km2, area match %d km2 of %.0f\n",
            err("km2_modal"), err("km2_areamatch"), tot$km2_30m))
fwrite(res, file.path(pkg, "dev/resampling/class-areas-1985.csv")); print(res)
