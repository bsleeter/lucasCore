# =============================================================================
# 5-initial-conditions.R - stage 5: state class and stand age maps, annual NLCD, and the per-cell spin-up return intervals and soil
# carbon targets
# =============================================================================
# Replaces the NLCD, MaxForestExtent, LandfireEVT, RCMAP, NOAA CCAP, BuildStateClassMap and StandAgeCMS chunks of "Build LUCAS Model
# CONUS Annual NLCD FIA Update.Rmd" (L227-572, L2314-2408) and the FRI part of "Update FIA Curve Model Parameters.R" (L238-295).
# Changes from the CONUS 1km build:
#   * forest type, grass/shrub and wetland types take the most common class of the 30 m pixels in each cell (the build sampled one
#     30 m pixel per cell)
#   * start-year developed (21-24), agriculture (81, 82), water (11) and ice (12) keep their class; the "forest in any year" rule
#     applies only to natural cells (user decision 2026-10-20: the build turned 69,895 developed/ag cells of 1985 into forest)
#   * one Douglas-fir class (200; user decision 2026-10-21): coastal vs inland is carried by the ecodivision of its curves
#   * the clearcut minimum-age rule needs the clearcut maps and moves to stage 6
# Also writes the annual NLCD at the model's resolution (stage 6 builds the transitions from it), and per ecodivision x forest class
# the replacement-fire return interval (LANDFIRE FRI_REPLAC) and the mean gSSURGO soil carbon that stage 3 calibrates with.
# Needs stage 1 (same pipeline, or a dependency on its result).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
suppressPackageStartupMessages({ library(terra); library(sf); library(parallel) })
STAGE <- "5 Initial Conditions"
progressBar(type = "begin", totalSteps = 9)

src <- read_data_sources(c("EcodivisionFile", "NlcdFolder", "Evt2001File", "Evt2016File", "RcmapFile", "CcapFile", "StandAgeFile", "FriFile", "SoilCarbonFile"))
opt <- read_ds("BuildOptions"); y0 <- opt$StartYear[1]; y1 <- opt$EndYear[1]
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StratumFileName[1])) fail("no strata rasters: run stage 1 first (same pipeline, or depend on a stage 1 result)")
P <- rast(ic$StratumFileName[1]); R <- rast(P); m <- !is.na(P); res_m <- res(P)[1]
L <- model_lattice(st_transform(read_sf(src$EcodivisionFile), MODEL_CRS), res_m)
scl <- stsim_list("StateClass"); stl <- stsim_list("Stratum")
say("Grid: %d x %d cells of %d m, %d land cells; years %d-%d", ncol(R), nrow(R), res_m, global(m, "sum", na.rm = TRUE)[[1]], y0, y1)
crop_to <- function(x, buf = 3000) crop(x, project(as.polygons(ext(R) + buf, crs = crs(R)), crs(x)))
lc <- function(f) fread(pkg_file("defaults", "landcover", f))

# ---- Land Cover Crosswalks: the scenario's sheet (users may edit it), else the package default ------------------------------
# One row per Source (EVT 2016, EVT 2001, RCMAP, C-CAP, USFS Forest Type Group) x Code -> stsim State Class. Forest types (100-999) come
# from EVT or the USFS map (Build Options), grassland and shrubland types from RCMAP, wetland types (90-96) from C-CAP; nothing else is used.
XW_SOURCES <- c("EVT 2016", "EVT 2001", "RCMAP", "C-CAP", "USFS Forest Type Group")
xw_def <- read_default("landcover", "land-cover-crosswalks.csv")[, .(Source, Code = as.integer(Code), Description, StateClassId)]
xw <- as.data.table(datasheet(scn, ds("LandCoverCrosswalk"), optional = TRUE, lookupsAsFactors = FALSE))
if (nrow(xw)) {
  if (is.numeric(xw$Source)) xw[, Source := XW_SOURCES[Source]]
  xw <- xw[, .(Source = as.character(Source), Code = as.integer(Code), Description = as.character(Description), StateClassId = as.character(StateClassId))]
  cmp <- merge(xw[, in_sheet := TRUE], xw_def[, in_def := TRUE], by = c("Source", "Code"), all = TRUE, suffixes = c("", ".def"))
  xw[, in_sheet := NULL]; xw_def[, in_def := NULL]
  same <- function(a, b) (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)
  chg <- cmp[in_sheet %in% TRUE & in_def %in% TRUE & !same(StateClassId, StateClassId.def)]
  chg[is.na(Description), Description := Description.def]
  add <- cmp[in_sheet %in% TRUE & !in_def %in% TRUE]; gone <- cmp[!in_sheet %in% TRUE & in_def %in% TRUE]
  say("Land Cover Crosswalks: the scenario's sheet (%d rows): %d changed from the package default, %d added, %d removed", nrow(xw), nrow(chg), nrow(add), nrow(gone))
  for (i in seq_len(min(nrow(chg), 25))) with(chg[i], say("  %s %d %s: %s -> %s", Source, Code, Description, ifelse(is.na(StateClassId.def), "(none)", StateClassId.def),
                                                         ifelse(is.na(StateClassId), "(none)", StateClassId)))
  if (nrow(chg) > 25) say("  ... and %d more changes", nrow(chg) - 25)
} else { xw <- xw_def; say("Land Cover Crosswalks: the sheet is empty, so the package default (%d rows)", nrow(xw)) }
xw[, Id := as.integer(scl$Id[match(StateClassId, scl$Name)])]
xsrc <- function(s) xw[Source == s & !is.na(Code)]
progressBar()

# ---- annual NLCD on the model grid (parallel over years) --------------------------------------------------------------
years <- y0:y1; nfs <- file.path(src$NlcdFolder, sprintf("Annual_NLCD_LndCov_%d_CU_C1V0.tif", years))
miss <- years[!file.exists(nfs)]; if (length(miss)) fail("Annual NLCD missing for %s", paste(miss, collapse = ", "))
td <- TD(); pf <- ic$StratumFileName[1]; Lw <- wrap(L)
cl <- makeCluster(max(1, min(length(years), 20, detectCores() - 1)))
clusterExport(cl, c("nlcd_on_grid", "grid_blocks", "clear_syncrosim_proj", "td", "pf", "Lw"), envir = environment())
invisible(clusterEvalQ(cl, clear_syncrosim_proj()))
nl_files <- parLapply(cl, seq_along(years), function(i, years, nfs) { library(terra); P <- rast(pf); L <- unwrap(Lw)
  n <- mask(nlcd_on_grid(nfs[i], L, rast(P)), P); f <- file.path(td, sprintf("NLCD_%d.tif", years[i]))
  writeRaster(n, f, overwrite = TRUE, datatype = "INT1U", gdal = c("COMPRESS=DEFLATE", "TILED=YES")); f }, years = years, nfs = nfs)
stopCluster(cl); nl_files <- unlist(nl_files)
say("Annual NLCD: %d years written (modal: each cell's most common 30 m class)", length(years))
# Build Options: Land Cover Resampling. Area-matched replaces the modal maps with maps whose class areas equal the 30 m areas in each
# secondary stratum unit, year by year (src/landcover-match.R); everything downstream reads these maps
lcr <- if ("LandCoverResampling" %in% names(opt) && !is.na(opt$LandCoverResampling[1])) as.character(opt$LandCoverResampling[1]) else "1"
if (lcr == "2" || grepl("^Area", lcr)) {
  source(pkg_file("src", "landcover-match.R"))
  t0 <- Sys.time(); cd <- file.path(td, "lc-counts"); dir.create(cd, showWarnings = FALSE)
  cl <- makeCluster(max(1, min(length(years), 20, detectCores() - 1)))
  clusterExport(cl, c("nlcd_counts_on_grid", "grid_blocks", "clear_syncrosim_proj", "LC_CLASSES", "cd", "pf", "Lw"), envir = environment())
  invisible(clusterEvalQ(cl, clear_syncrosim_proj()))
  cfs <- unlist(parLapply(cl, seq_along(years), function(i, years, nfs) { library(terra); P <- rast(pf); L <- unwrap(Lw)
    s <- mask(nlcd_counts_on_grid(nfs[i], L, rast(P)), P); f <- file.path(cd, sprintf("counts_%d.tif", years[i]))
    writeRaster(s, f, overwrite = TRUE, datatype = "INT2U", gdal = c("COMPRESS=DEFLATE", "TILED=YES")); f }, years = years, nfs = nfs))
  stopCluster(cl)
  land <- !is.na(values(P, mat = FALSE)); cell_km2 <- (res_m / 1000)^2
  match_step <- lc_matcher(values(rast(ic$SecondaryStratumFileName[1]), mat = FALSE)[land])
  DEVI <- which(LC_CLASSES %in% 21:24); prev <- NULL; pp <- NULL; short <- 0; nrev <- 0; lost <- 0; wrong <- list(); a30 <- list()
  for (i in seq_along(years)) {
    K <- values(rast(cfs[i]), mat = TRUE)[land, , drop = FALSE]; K[is.na(K)] <- 0
    first <- is.null(prev)
    if (first) { M <- match(values(rast(nl_files[i]), mat = FALSE)[land], LC_CLASSES); prev <- ifelse(is.na(M), max.col(K, ties.method = "first"), M) }   # the first year starts from the modal map
    r <- match_step(prev, K, first); A <- r$cur; short <- short + r$short
    if (!first) { lost <- lost + sum(prev %in% DEVI & !(A %in% DEVI)); if (!is.null(pp)) nrev <- nrev + sum(A == pp & A != prev) }
    px <- colSums(K); a30[[i]] <- px / sum(px) * sum(land) * cell_km2   # the 30 m class areas, scaled to the land cells' area
    wrong[[i]] <- c(modal = sum(abs(tabulate(match(values(rast(nl_files[i]), mat = FALSE)[land], LC_CLASSES), 16) * cell_km2 - a30[[i]])) / 2,
                    matched = sum(abs(tabulate(A, 16) * cell_km2 - a30[[i]])) / 2)
    v <- rep(NA_integer_, ncell(P)); v[land] <- LC_CLASSES[A]   # replaces the year's modal map
    writeRaster(setValues(rast(P), v), nl_files[i], overwrite = TRUE, datatype = "INT1U", gdal = c("COMPRESS=DEFLATE", "TILED=YES"))
    pp <- prev; prev <- A }
  unlink(cd, recursive = TRUE); W <- do.call(rbind, wrong); d30 <- vapply(a30, function(a) sum(a[DEVI]), 0)
  dev_km2 <- function(f) sum(values(rast(f), mat = FALSE) %in% 21:24, na.rm = TRUE) * cell_km2
  say("Land cover resampling: area-matched per secondary stratum unit (%.1f min). Area in the wrong class vs the 30 m areas: %d %.0f km2 (modal %.0f), %d %.0f km2 (modal %.0f), mean %.0f km2 (modal %.0f)",
      as.numeric(Sys.time() - t0, units = "mins"), y0, W[1, "matched"], W[1, "modal"], y1, W[nrow(W), "matched"], W[nrow(W), "modal"], mean(W[, "matched"]), mean(W[, "modal"]))
  say("Developed land: 30 m %.0f -> %.0f km2, matched %.0f -> %.0f km2; developed cells lost %d; A->B->A reversals %.0f km2; cells a class could not be filled for %.0f (sum over years)",
      d30[1], d30[length(d30)], dev_km2(nl_files[1]), dev_km2(nl_files[length(nl_files)]), lost, nrev * cell_km2, short)
  check(STAGE, "area matching: developed land never reverts", lost == 0, sprintf("%d cells", lost))
  check(STAGE, "area matching: less area in the wrong class than modal in every year", all(W[, "matched"] <= W[, "modal"]),
        sprintf("%d years worse", sum(W[, "matched"] > W[, "modal"])))
}
N <- rast(nl_files); names(N) <- years; n0 <- N[[1]]
progressBar()

# ---- forest type (Build Options: Forest Type Map); most common forest type group of the 30 m pixels; cells with none from neighbours
#   LANDFIRE EVT (default)   EVT 2016, else EVT 2001 where 2016 is not forest (incl. "Recently ...")
#   USFS forest type groups  the NFCMS regional tiles (FIA forest type group codes) that touch the study area, mosaicked
ftg <- function(v) { v <- suppressWarnings(as.integer(v)); ifelse(!is.na(v) & v >= 100 & v <= 999, v, NA_integer_) }
fmap <- opt$ForestTypeMap[1]
fmap <- if (is.null(fmap) || is.na(fmap)) "LANDFIRE EVT" else if (is.numeric(fmap)) c("LANDFIRE EVT", "USFS forest type groups")[fmap] else as.character(fmap)
if (identical(fmap, "USFS forest type groups")) {
  ftf <- read_data_sources("ForestTypeGroupFolder")$ForestTypeGroupFolder
  tiles <- list.files(ftf, "_ForestType[.]tif$", full.names = TRUE); if (!length(tiles)) fail("no *_ForestType.tif tiles in %s", ftf)
  win <- function(r) project(as.polygons(ext(R) + 3000, crs = crs(R)), crs(r))
  hit <- Filter(function(f) { r <- rast(f); !is.null(intersect(ext(r), ext(win(r)))) }, tiles)
  if (!length(hit)) fail("no USFS forest type group tile covers the study area (%s)", ftf)
  us <- lapply(hit, function(f) { r <- rast(f); levels(r) <- NULL; crop(r, win(r)) })
  usfs30 <- if (length(us) == 1) us[[1]] else do.call(merge, us)
  xu <- xsrc("USFS Forest Type Group")
  f30 <- classify(usfs30, cbind(xu$Code, ftg(xu$Id)), others = NA)
  say("Forest type map: USFS forest type groups (%s)", paste(sub("_ForestType[.]tif$", "", basename(hit)), collapse = ", "))
} else {
  x16 <- xsrc("EVT 2016"); x01 <- xsrc("EVT 2001")
  recent <- x16[grepl("Recently", Description), Code]
  e16 <- crop_to(rast(src$Evt2016File)); e01 <- crop_to(rast(src$Evt2001File)); levels(e16) <- NULL; levels(e01) <- NULL
  f16 <- classify(e16, cbind(x16$Code, ftg(x16$Id)), others = NA); f16[e16 %in% recent] <- NA
  f01 <- classify(e01, cbind(x01$Code, ftg(x01$Id)), others = NA)
  f30 <- cover(f16, project(f01, f16, method = "near"))
  say("Forest type map: LANDFIRE EVT 2016 (EVT 2001 where 2016 is not forest)")
}
Fz <- project(f30, R, method = "mode")
no_type <- global(mask(is.na(Fz), m), "sum", na.rm = TRUE)[[1]]
Fz <- fill_modal(mask(Fz, m), m, 500)
say("Forest type: %d land cells have no forest type pixel in the map and take their neighbours' (only those that are forest matter)", no_type)
progressBar()

# ---- grassland / shrubland (RCMAP 2001) and wetland (C-CAP 2001) types, filled from NLCD then from neighbours -------------
rc <- xsrc("RCMAP")[!is.na(Id)]; rcr <- crop_to(rast(src$RcmapFile)); levels(rcr) <- NULL
G <- project(classify(rcr, cbind(rc$Code, rc$Id), others = NA), R, method = "mode")
G <- cover(G, classify(n0, rbind(c(71, 72), c(52, 54)), others = NA)); G <- fill_modal(mask(G, m), m, 54)
cx <- xsrc("C-CAP")[!is.na(Id) & Id >= 90]; ccr <- crop_to(rast(src$CcapFile)); levels(ccr) <- NULL
# every code found in the study area window needs a crosswalk row (a missing row would silently count as unmapped)
maps <- if (exists("usfs30")) list(list("USFS Forest Type Group", usfs30)) else list(list("EVT 2016", e16), list("EVT 2001", e01))
miss_codes <- rbindlist(lapply(c(maps, list(list("RCMAP", rcr), list("C-CAP", ccr))), function(z) {
  v <- terra::unique(z[[2]])[[1]]; v <- v[!is.na(v)]; data.table(Source = z[[1]], Code = setdiff(as.integer(v), xsrc(z[[1]])$Code)) }))
check(STAGE, "every land cover code in the study area has a crosswalk row", !nrow(miss_codes),
      if (nrow(miss_codes)) paste(head(paste(miss_codes$Source, miss_codes$Code), 10), collapse = "; ") else "")
W <- project(classify(ccr, cbind(cx$Code, cx$Id), others = NA), R, method = "mode")
W <- cover(W, classify(n0, cbind(90:99, 90:99), others = NA)); W <- fill_modal(mask(W, m), m, 90)
progressBar()

# ---- state class ------------------------------------------------------------------------------------------------------
ever_forest <- app(N, function(x) as.integer(any(x %in% 41:43)))
land_use <- n0 %in% c(11, 12, 21:24, 81, 82)
S <- n0
S <- ifel(S %in% c(52, 71), G, S)
S <- ifel(ever_forest == 1 & !land_use, Fz, S)
S <- ifel(S == 95, W, S)
S <- ifel(S %in% c(90, 91), 90, S)
S <- mask(S, m)
forest <- S >= 100 | S == 90
progressBar()

# ---- stand age: NASA CMS 1990 shifted to the start year, filled from neighbours, forest and forested wetland only --------
A <- project(crop_to(rast(src$StandAgeFile)), R, method = "average")
A <- round(A - (1990 - y0)); A[A <= 0] <- NA
A <- fill_modal(mask(A, m), m, round(global(A, "mean", na.rm = TRUE)[[1]]))
A <- mask(ifel(forest, max(A, 1), 0), m)
progressBar()

# ---- per ecodivision x forest class: replacement-fire return interval and mean gSSURGO soil carbon ---------------------
fri <- lc("LF16_FRI_200.csv")
Fr <- classify(crop_to(rast(src$FriFile)), cbind(as.integer(fri$Value), ifelse(fri$FRI_REPLAC > 0, as.numeric(fri$FRI_REPLAC), NA)), others = NA)
Fr <- project(Fr, R, method = "average")
# gSSURGO soc 0-999 (g C/m2): 0 and its undeclared no-data value (-1920, the CONUS median: ocean and unmapped areas) are missing
So <- crop_to(rast(src$SoilCarbonFile)); So <- classify(So, cbind(-Inf, 0, NA), include.lowest = TRUE); So <- project(So, R, method = "average") * 0.01
z <- data.table(P = values(P, mat = FALSE), S = values(S, mat = FALSE), fri = values(Fr, mat = FALSE), soil = values(So, mat = FALSE))[!is.na(P) & S >= 100]
z[, `:=`(StratumId = stl$Name[match(P, as.integer(stl$Id))], StateClassId = scl$Name[match(S, as.integer(scl$Id))])]
ri <- z[!is.na(fri), .(ReturnInterval = as.integer(round(mean(fri))), Cells = .N), by = .(StratumId, StateClassId)]
st <- z[!is.na(soil) & soil > 0, .(SoilTarget = round(mean(soil), 2), Cells = .N), by = .(StratumId, StateClassId)]
fc <- unique(z[, .(StratumId, StateClassId)])
progressBar()

# ---- checks -----------------------------------------------------------------------------------------------------------
vS <- values(S, mat = FALSE); vP <- values(P, mat = FALSE); v0 <- values(n0, mat = FALSE); vA <- values(A, mat = FALSE); vF <- values(forest, mat = FALSE)
check(STAGE, "every land cell has a state class", !any(!is.na(vP) & is.na(vS)), sprintf("%d land cells without one", sum(!is.na(vP) & is.na(vS))))
miss <- raster_ids_in_list(S, "StateClass")
check(STAGE, "state class values are stsim State Class Ids", !length(miss), if (length(miss)) paste("not in the list:", paste(miss, collapse = ", ")) else "")
lu <- !is.na(v0) & v0 %in% c(11, 12, 21:24, 81, 82)
check(STAGE, "start-year developed, agriculture, water and ice keep their class", all(vS[lu] == v0[lu]), sprintf("%d cells", sum(lu)))
check(STAGE, "forest cells have an age of at least 1 and other cells 0", all(vA[which(vF == 1)] >= 1) && all(vA[which(vF == 0)] == 0))
check(STAGE, "every forest ecodivision x class has a return interval", nrow(ri) == nrow(fc), sprintf("%d of %d", nrow(ri), nrow(fc)))
say("Forest cells: %d (%.1f%% of land); natural cells made forest by the any-year rule: %d; developed/ag/water/ice kept: %d",
    sum(vF == 1, na.rm = TRUE), 100 * mean(vF[!is.na(vP)] == 1), sum(!is.na(v0) & !(v0 %in% 41:43) & vS >= 100 & !lu, na.rm = TRUE), sum(lu))
say("Return intervals: %d cells, %d-%d yr (median %d); gSSURGO soil targets: %d cells, median %.0f Mg C/ha",
    nrow(ri), min(ri$ReturnInterval), max(ri$ReturnInterval), as.integer(median(ri$ReturnInterval)), nrow(st), median(st$SoilTarget))
progressBar()

# ---- outputs ----------------------------------------------------------------------------------------------------------
fS <- write_raster(S, "StateClass.tif"); fA <- write_raster(A, "StandAge.tif")
row <- ic[1]; row$StateClassFileName <- fS; row$AgeFileName <- fA
saveDatasheet(scn, as.data.frame(row), "stsim_InitialConditionsSpatial")
write_ds(data.frame(Year = years, FileName = nl_files), "OutputNlcdAnnual")
write_ds(data.frame(ForestTypeFileName = write_raster(Fz, "ForestType.tif"), GrassShrubFileName = write_raster(G, "GrassShrubType.tif"),
                    WetlandFileName = write_raster(W, "WetlandType.tif"), EverForestFileName = write_raster(mask(ever_forest, m), "EverForest.tif", datatype = "INT1U")),
         "OutputLandCoverLayers")
write_ds(ri, "OutputReturnInterval"); write_ds(st, "OutputSoilTarget")
summ <- data.table(S = vS, A = vA)[!is.na(S), .(Cells = .N, MeanAge = round(mean(A), 1)), by = S][, StateClassId := scl$Name[match(S, as.integer(scl$Id))]]
write_ds(summ[order(-Cells), .(StateClassId, Cells, MeanAge)], "OutputStateClassSummary")
progressBar()
finish_checks()
progressBar(type = "end")
