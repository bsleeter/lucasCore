# =============================================================================
# 10-transition-suitability.R - stage 10: where projected transitions go (Projection Setup)
# =============================================================================
# Stage 9 sets how much of each transition happens per unit and year; until now its Target groups were placed at random among the
# allowed cells. Projection Allocation (an empty sheet uses defaults/projection/allocation.csv) gives each group a method:
#   Fitted  a logistic GAM on the annual NLCD record (user decisions 2026-10-22, tested on P26 in dev/urban): an event is a pixel
#           whose class the year before is one of the surface's Source Classes (blank = not developed, water or ice) and that changes
#           to one of its Event Classes (NLCD codes, or LANDFIRE:<disturbance type> for selection harvest); controls are eligible
#           pixels that stay within the Source Classes. Pixels on the GAP status the Target group excludes (Projection Transitions) and
#           pixels inside a fire perimeter of the last Burn Window years are left out (post-fire relabelling); every event and a
#           weighted sample of unchanged pixels per year, fitted on the Suitability Fitting Region (blank = the study area) at the
#           Fitting Resolution (30 m = native NLCD; coarser is faster), with the covariates switched on in Suitability Covariates.
#           Tested out of sample (fit before the last Test Years, map from that year, scored on the change since), then refitted
#           on all years and predicted from the historical end year over the study area
#   Rules   the old LUCAS rules: a weight per WUI class (SILVIS 2020) and per GAP status (Rule Weights; defaults from the CONUS 1km
#           build), multiplied
#   None    stage 9's map (random among allowed cells)
# Each surface is averaged onto the model grid, scaled to 0-1 and multiplied by the group's stage 9 map (its excluded GAP status),
# and replaces that map from the historical end + 1. Adjacency (ST-Sim, updated in the run): the share of developed land around a
# cell (state attribute Developed, written here) scales its multiplier - for Fitted surfaces by the fitted developed-share curve
# (that covariate is then held at a typical value in the static surface, so it is not counted twice), for Rules by the old
# threshold (none below 12% developed, full above 88%); a surface of agriculture events uses the agriculture share (attribute
# Agriculture) the same way.
# Covariates per surface (Suitability Covariates, Surface blank = every surface; empty sheet = defaults/projection/covariates.csv).
# Patch sizes (user decision 2026-10-22, Suitability Options): the events of each year are joined into patches (8-neighbour pixels of
# the fitting grid), and each Target group gets their sizes in model cells as an ST-Sim Transition Size Distribution (relative amount =
# number of patches per size class), so a 30-150 m model places patches rather than scattered cells; skipped when nearly all
# patches are one model cell.
# Run in a Projection Setup scenario after stage 9 (tools/new-projection-setup.R); projections depend on its result.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "strata.R"))
suppressPackageStartupMessages({ library(terra); library(sf); library(mgcv); library(parallel) })
STAGE <- "10 Transition Suitability"
progressBar(type = "begin", totalSteps = 8)
nz <- function(v, d) if (is.null(v) || !length(v) || is.na(v[1])) d else v[1]

opt <- read_ds("BuildOptions"); pend <- nz(opt$ProjectionEndYear, NA)
if (is.na(pend)) { say("No projection in Build Options: stage 10 has nothing to do"); progressBar(type = "end"); quit(save = "no") }
nl <- read_ds("OutputNlcdAnnual"); if (!nrow(nl)) fail("no annual NLCD table: run stage 5 first")
y0 <- min(nl$Year); y1 <- max(nl$Year)
sched <- read_ds("OutputProjectionSchedule"); if (!nrow(sched)) fail("no projection schedule: run stage 9 first")
al <- read_ds("ProjectionAllocation")
if (!nrow(al)) { al <- read_default("projection", "allocation.csv"); al_src <- "defaults/projection/allocation.csv" } else al_src <- "the Projection Allocation sheet"
al[, Method := sub(" .*", "", Method)]; al[, Adjacency := toupper(as.character(Adjacency)) %in% c("YES", "TRUE", "-1", "1")]
al <- al[Method %in% c("Fitted", "Rules")]
if (!nrow(al)) { say("Projection Allocation: every group None - stage 9's maps stay"); progressBar(type = "end"); finish_checks(); quit(save = "no") }
so <- read_ds("SuitabilityOptions")
res_f <- nz(so$FitResolution, 30L); if (res_f %% 30 != 0) fail("Suitability Options: the fitting resolution must be a multiple of 30 m (NLCD)")
burn_w <- nz(so$BurnWindow, 3L); nctrl <- nz(so$ControlsPerYear, 25000L); test_y <- nz(so$TestYears, 11L); adj_up <- nz(so$AdjacencyUpdate, 5L)
say("Projection Allocation (%s): %s", al_src, paste(al[, sprintf("%s -> %s %s", TransitionGroupId, Method, Surface)], collapse = "; "))

ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
P <- rast(ic$StratumFileName[1]); land <- !is.na(values(P, mat = FALSE)); res_m <- res(P)[1]
adj_r <- nz(so$AdjacencyRadius, 3 * res_m)
sm <- as.data.table(datasheet(scn, "stsim_TransitionSpatialMultiplier", optional = TRUE, lookupsAsFactors = FALSE)); if (!"Iteration" %in% names(sm)) sm[, Iteration := NA_integer_]
pt <- read_ds("ProjectionTransition"); if (!nrow(pt)) pt <- read_default("projection", "transitions.csv")
pt[, Method := sub(" .*", "", Method)]
# a Target group's surface, or one of its members' (a type group of the named group Urbanization: the spatial allocation decides the type)
ttg <- stsim_list("TransitionTypeGroup")
grp_types <- function(g) if (endsWith(g, " [Type]")) substr(g, 1, nchar(g) - 7) else ttg[TransitionGroupId == g, TransitionTypeId]
t_types <- unlist(lapply(pt[Method == "Target", TransitionGroupId], grp_types))
notT <- al$TransitionGroupId[!vapply(al$TransitionGroupId, function(g) { ty <- grp_types(g); length(ty) > 0 && all(ty %in% t_types) }, TRUE)]
if (length(notT)) { say("Not Target groups in Projection Transitions (allocation applies to Target groups only): %s - skipped", paste(notT, collapse = "; ")); al <- al[!TransitionGroupId %in% notT] }
# each allocated group's Target group (itself, or the named group it belongs to): its excluded GAP status and its size distribution
tg <- pt[Method == "Target"]
al[, Target := vapply(TransitionGroupId, function(g) { ty <- grp_types(g); tg$TransitionGroupId[vapply(tg$TransitionGroupId, function(t) all(ty %in% grp_types(t)), TRUE)][1] }, "")]
codes_of <- function(s) if (is.null(s) || is.na(s) || !nzchar(s)) integer() else as.integer(strsplit(s, "[|,; ]+")[[1]])
al[, ExGap := vapply(Target, function(t) paste(codes_of(tg[TransitionGroupId == t, ExcludeGap][1]), collapse = "|"), "")]
if (!"SourceClasses" %in% names(al)) al[, SourceClasses := NA_character_]
NOT_SOURCE <- c(21:24, 11, 12)   # blank Source Classes: every class but developed, water and ice
src <- read_data_sources(c("NlcdFolder", "FirePerimeterHistoryFile", "RoadsFile", "ElevationFile", "WuiFolder"))

# ---- covariates, per surface ---------------------------------------------------------------------------------------------------
BUILTIN <- c(`Distance to developed land` = "s(lDistDev, k = 8)", `Developed share within 1 km` = "s(DevShare, k = 6)", `Housing density (census decade)` = "s(lHU, k = 6)",
             `Distance to roads` = "s(lDistRoad, k = 6)", Slope = "s(Slope, k = 6)", Elevation = "s(Elev, k = 6)", `Land cover` = "LC", `GAP status` = "GAP", County = "s(County, bs = \"re\")",
             `Distance to agriculture` = "s(lDistAg, k = 6)", `Agriculture share within 1 km` = "s(AgShare, k = 6)", `Crop productivity (NCCPI)` = "s(Nccpi, k = 6)", `Forest owner type` = "Owner")
cv <- read_ds("SuitabilityCovariate"); cv_src <- "the Suitability Covariates sheet"
if (!nrow(cv)) { cv <- read_default("projection", "covariates.csv"); cv_src <- "defaults/projection/covariates.csv" }
for (k in c("Surface", "Name", "File")) if (!k %in% names(cv)) cv[, (k) := NA_character_]
cv[, Include := toupper(as.character(Include)) %in% c("YES", "TRUE", "-1", "1")]; cv[is.na(Surface), Surface := ""]
# a surface's covariates: the rows for every surface, with its own rows added (a built-in on both: its own row decides)
cov_for <- function(s) { o <- cv[Surface == s]; b <- cv[Surface == "" & !(Covariate != "Custom raster" & Covariate %in% o$Covariate)]; rbind(b, o)[Include == TRUE] }
fitted_s <- unique(al[Method == "Fitted", Surface])
need <- unique(unlist(lapply(fitted_s, function(s) cov_for(s)$Covariate)))
custom <- unique(cv[Include == TRUE & Covariate == "Custom raster", .(Name, File)])
lf_types <- unique(sub("^LANDFIRE:\\s*", "", grep("^LANDFIRE:", al[Method == "Fitted", EventClasses], value = TRUE)))
lc_kinds <- unique(sub("^LCMS:\\s*", "", grep("^LCMS:", al[Method == "Fitted", EventClasses], value = TRUE)))
if (any(!lc_kinds %in% c("standrep", "partial"))) fail("Projection Allocation: LCMS events are LCMS:standrep or LCMS:partial")
ag_ev <- function(e) { k <- suppressWarnings(codes_of(e)); length(k) > 0 && all(k %in% 81:82) }
need_ag <- any(c("Distance to agriculture", "Agriculture share within 1 km") %in% need) || any(al[Method == "Fitted" & Adjacency == TRUE, vapply(EventClasses, ag_ev, TRUE)])
rows <- sources_from_sheet(as.data.table(datasheet(prj, ds("StratumSource"), optional = TRUE, lookupsAsFactors = FALSE)))
by_num <- setNames(rows, vapply(rows, function(s) as.character(s$Number), ""))
ul <- stsim_list("SecondaryStratum"); ul[, Id := as.integer(Id)]
progressBar()

# ---- the fitting region and the study area as polygons --------------------------------------------------------------------
units_poly <- function(names) { uid <- ul$Id[match(names, ul$Name)]; if (anyNA(uid)) fail("units not in the unit list: %s", paste(names[is.na(uid)], collapse = ", "))
  parts <- split(unit_native(uid), unit_source(uid))
  do.call(rbind, lapply(names(parts), function(k) { s <- by_num[[k]]; p <- strata_polygons(s, env$PackageDirectory); p <- p[p$StratumId %in% parts[[k]], ]; st_sf(geometry = st_union(st_geometry(p))) })) }
sa <- read_ds("StudyArea"); sr <- read_ds("SuitabilityRegion")
study <- if (nrow(sa)) st_union(units_poly(as.character(sa$UnitId))) else st_as_sfc(st_bbox(ext(P), crs = st_crs(crs(P))))
region <- if (nrow(sr)) st_union(units_poly(as.character(sr$UnitId))) else study
say("Fitting region: %s; study area: %s", if (nrow(sr)) paste(sr$UnitId, collapse = ", ") else "the study area", if (nrow(sa)) paste(sa$UnitId, collapse = ", ") else "all")

# ---- the fitting grid (NLCD 30 m lattice, aggregated to the fitting resolution) and its layer cache ---------------------------
nl_file <- function(y) file.path(src$NlcdFolder, sprintf("Annual_NLCD_LndCov_%d_CU_C1V0.tif", y))
ref <- rast(nl_file(y1)); both <- st_transform(st_union(c(st_transform(region, crs(ref)), st_transform(study, crs(ref)))), crs(ref))
E30 <- align(ext(vect(both)) + 2000, ref, snap = "out"); fact <- res_f / 30
G <- if (fact > 1) aggregate(rast(crop(ref, E30)), fact) else rast(crop(ref, E30))
key <- sprintf("r%d_%d_%d_%d_%d_%d-%d", res_f, round(xmin(G)), round(ymin(G)), ncol(G), nrow(G), y0, y1)
CA <- file.path(paste0(env$LibraryFilePath, ".data"), "lucasCore-suitability", key); dir.create(CA, recursive = TRUE, showWarnings = FALSE)
cf <- function(k) file.path(CA, paste0(k, ".tif"))
if (!file.exists(cf("region"))) { writeRaster(rasterize(vect(st_transform(region, crs(G))), G, 1), cf("region"), datatype = "INT1U", gdal = "COMPRESS=DEFLATE")
  writeRaster(rasterize(vect(st_transform(study, crs(G))), G, 1), cf("study"), datatype = "INT1U", gdal = "COMPRESS=DEFLATE") }
say("Fitting grid: %d x %d cells of %d m (cache %s)", ncol(G), nrow(G), res_f, key)
DEV <- 21:24; YRS <- y0:y1; EPOCHS <- unique(c(seq(y0, y1, 5), y1)); nl_c <- function(y) cf(sprintf("nlcd_%d", y))
todo <- YRS[!file.exists(vapply(YRS, nl_c, ""))]
if (length(todo)) { cl <- makeCluster(min(20, length(todo))); on.exit(stopCluster(cl), add = TRUE)
  a <- list(nf = vapply(todo, nl_file, ""), out = vapply(todo, nl_c, ""), E = as.vector(E30), fact = fact, clear = clear_syncrosim_proj)
  parLapply(cl, seq_along(todo), function(i, a) { library(terra); a$clear(); terraOptions(progress = 0, memfrac = 0.04)
    r <- crop(rast(a$nf[i]), ext(a$E)); levels(r) <- NULL; if (a$fact > 1) r <- aggregate(r, a$fact, "modal")
    writeRaster(r, a$out[i], datatype = "INT1U", gdal = "COMPRESS=DEFLATE", overwrite = TRUE); NULL }, a = a); stopCluster(cl); on.exit() }
win <- 2 * round(500 / res_f) + 1
ep_c <- function(e, k) cf(sprintf("%s_%d", k, e))
todo <- EPOCHS[!file.exists(vapply(EPOCHS, ep_c, "", k = "devshare"))]
if (length(todo)) { cl <- makeCluster(length(todo)); a <- list(inp = vapply(todo, nl_c, ""), dd = vapply(todo, ep_c, "", k = "distdev"), ds = vapply(todo, ep_c, "", k = "devshare"), win = win, clear = clear_syncrosim_proj)
  parLapply(cl, seq_along(todo), function(i, a) { library(terra); a$clear(); terraOptions(progress = 0, memfrac = 0.06)
    d <- rast(a$inp[i]) %in% 21:24
    writeRaster(distance(ifel(d, 1, NA)), a$dd[i], datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE)
    writeRaster(focal(d, w = a$win, fun = "mean", na.rm = TRUE), a$ds[i], datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE); NULL }, a = a); stopCluster(cl) }
epoch_of <- function(y) max(EPOCHS[EPOCHS <= y])
progressBar()

# static layers: roads, elevation and slope, GAP status, county, housing density by census decade, fire perimeters by year
G30 <- function(f, fun) { r <- crop(rast(f), E30, snap = "out"); levels(r) <- NULL; if (fact > 1) r <- aggregate(r, fact, fun, na.rm = TRUE); resample(r, G, method = "near") }
if (!file.exists(cf("distroad"))) { r <- G30(src$RoadsFile, "max"); writeRaster(distance(ifel(!is.na(r) & r > 0, 1, NA)), cf("distroad"), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE") }
if (!file.exists(cf("slope"))) { d <- G30(src$ElevationFile, "mean"); writeRaster(d, cf("elev"), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE"); writeRaster(terrain(d, "slope"), cf("slope"), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE") }
Gm <- init(G, 1)
if (!file.exists(cf("gap"))) { g <- strata_raster(rows[["GAP Status"]], env$PackageDirectory, G, Gm); writeRaster(g, cf("gap"), datatype = "INT1U", gdal = "COMPRESS=DEFLATE") }
if (!file.exists(cf("county"))) { cp <- strata_polygons(rows[["Counties"]], env$PackageDirectory, bbox = st_bbox(st_transform(both, 5070)))   # no fill: a 30 m modal fill over 29 km is too slow
  writeRaster(rasterize(vect(st_transform(cp, crs(G))), G, "StratumId"), cf("county"), datatype = "INT4S", gdal = "COMPRESS=DEFLATE") }
DECS <- c(1990, 2000, 2010, 2020); decade_of <- function(y) max(DECS[DECS <= max(y, 1990)]); hu_c <- function(d) cf(sprintf("hu_%d", d))
if (!file.exists(hu_c(2020))) {
  stp <- strata_polygons(rows[["States"]], env$PackageDirectory, bbox = st_bbox(st_transform(both, 5070)))
  ab <- state.abb[match(sub("^State: ", "", ul$Name[match(unit_id(rows[["States"]]$Number, stp$StratumId), ul$Id)]), state.name)]
  gdb <- file.path(src$WuiFolder, sprintf("%s_wui_block_1990_2020_change_v4.gdb", ab)); gdb <- gdb[file.exists(gdb)]
  if (!length(gdb)) fail("no SILVIS WUI blocks for the area in %s (states %s)", src$WuiFolder, paste(ab, collapse = ", "))
  b <- do.call(rbind, lapply(gdb, function(f) read_sf(f)[, c(sprintf("HUDEN%d", DECS), "WUICLASS2020")])); b <- st_transform(b, crs(G))
  b <- b[lengths(st_intersects(b, st_transform(both, crs(G)))) > 0, ]
  for (d in DECS) writeRaster(rasterize(vect(b), G, sprintf("HUDEN%d", d)), hu_c(d), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE)
  saveRDS(st_drop_geometry(b)[, "WUICLASS2020", drop = FALSE], file.path(CA, "wui_classes.rds")); write_sf(b[, "WUICLASS2020"], file.path(CA, "wui.gpkg")) }
bf <- function(y) cf(sprintf("burn_%d", y))
if (!file.exists(bf(y1))) { lay <- tools::file_path_sans_ext(basename(src$FirePerimeterHistoryFile))
  fp <- st_read(src$FirePerimeterHistoryFile, query = sprintf('SELECT FIRE_YEAR_ FROM "%s" WHERE FIRE_YEAR_ >= %d AND FIRE_YEAR_ <= %d', lay, y0 - burn_w, y1), quiet = TRUE)
  fp <- st_make_valid(st_transform(fp, crs(G))); fp <- fp[lengths(st_intersects(fp, st_as_sfc(st_bbox(ext(G), crs = st_crs(crs(G)))))) > 0, ]; fp$yr <- as.integer(fp$FIRE_YEAR_)
  for (y in (y0 - burn_w):y1) { s <- fp[fp$yr == y, ]; r <- if (nrow(s)) !is.na(rasterize(vect(s), G, field = 1)) else init(G, 0)
    writeRaster(r, bf(y), datatype = "INT1U", gdal = "COMPRESS=DEFLATE", overwrite = TRUE) } }
# agriculture distance and share by epoch (agriculture covariates, or adjacency on an agriculture surface)
if (need_ag) { todo <- EPOCHS[!file.exists(vapply(EPOCHS, ep_c, "", k = "agshare"))]
  if (length(todo)) { cl <- makeCluster(length(todo)); a <- list(inp = vapply(todo, nl_c, ""), dd = vapply(todo, ep_c, "", k = "distag"), ds = vapply(todo, ep_c, "", k = "agshare"), win = win, clear = clear_syncrosim_proj)
    parLapply(cl, seq_along(todo), function(i, a) { library(terra); a$clear(); terraOptions(progress = 0, memfrac = 0.06)
      d <- rast(a$inp[i]) %in% c(81, 82)
      writeRaster(distance(ifel(d, 1, NA)), a$dd[i], datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE)
      writeRaster(focal(d, w = a$win, fun = "mean", na.rm = TRUE), a$ds[i], datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE); NULL }, a = a); stopCluster(cl) } }
# crop productivity: Data Source NccpiFile, or fetched for the fitting grid from Planetary Computer (src/nccpi.R); no soil data = 0
if ("Crop productivity (NCCPI)" %in% need && !file.exists(cf("nccpi"))) {
  nf <- tryCatch(as.data.table(datasheet(prj, ds("DataSource"), lookupsAsFactors = FALSE, optional = TRUE))$NccpiFile[1], error = function(e) NA_character_)
  r30 <- rast(E30, res = 30, crs = crs(ref))
  if (is.null(nf) || is.na(nf) || !nzchar(nf)) { source(pkg_file("src", "nccpi.R")); nf <- file.path(CA, "nccpi_30m.tif")
    if (!file.exists(nf)) { say("NCCPI: fetching gNATSGO nccpi3all for the fitting grid from Planetary Computer"); fetch_nccpi(r30, nf) } }
  if (!file.exists(nf)) fail("Data Sources: NccpiFile not found (%s)", nf)
  n <- crop(rast(nf), E30, snap = "out"); if (!compareGeom(n, r30, stopOnError = FALSE)) n <- resample(n, r30, method = "bilinear")
  if (fact > 1) n <- aggregate(n, fact, "mean", na.rm = TRUE)
  n <- resample(n, G, method = "near"); cov_n <- global((!is.na(n)) & (!is.na(rast(cf("region")))), "sum")[[1]] / max(1, global(!is.na(rast(cf("region"))), "sum")[[1]])
  if (cov_n < 0.5) fail("NCCPI covers %.0f%% of the fitting region (%s): fetch it for the region (tools/fetch-nccpi.R) or clear Data Source NccpiFile", 100 * cov_n, nf)
  writeRaster(ifel(is.na(n), 0, n), cf("nccpi"), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE"); say("NCCPI: %.0f%% of the fitting region has soil data (the rest = 0)", 100 * cov_n) }
# forest owner type (USFS forest ownership circa 2017; not forest = 0)
OWNERS <- c(`0` = "Not forest", `1` = "Family", `2` = "Corporate", `3` = "TIMO/REIT", `4` = "Other private", `5` = "Federal", `6` = "State", `7` = "Local", `8` = "Tribal")
if ("Forest owner type" %in% need && !file.exists(cf("owner"))) { of <- read_data_sources("ForestOwnerFile")$ForestOwnerFile
  o <- rast(of); bx <- project(as.polygons(E30, crs = crs(ref)), crs(o)); o <- crop(o, bx, snap = "out"); levels(o) <- NULL
  o <- project(o, rast(E30, res = 30, crs = crs(ref)), method = "near"); if (fact > 1) o <- aggregate(o, fact, "modal", na.rm = TRUE)
  o <- resample(o, G, method = "near"); writeRaster(ifel(is.na(o), 0, o), cf("owner"), datatype = "INT1U", gdal = "COMPRESS=DEFLATE") }
# LANDFIRE disturbance events by year (selection harvest: LANDFIRE:Thinning), as the share of each fitting cell's pixels (an event when >= half)
lf_c <- function(t, y) cf(sprintf("lf_%s_%d", gsub("[^A-Za-z0-9]+", "", t), y))
for (t in lf_types) { todo <- YRS[-1][!file.exists(vapply(YRS[-1], lf_c, "", t = t))]
  if (!length(todo)) next
  src$LandfireDisturbanceFolder <- read_data_sources("LandfireDisturbanceFolder")$LandfireDisturbanceFolder
  files <- lapply(todo, function(y) { d <- file.path(src$LandfireDisturbanceFolder, sprintf("US_DIST%d", y)); tif <- Sys.glob(file.path(d, "*", "Tif", "*.tif")); csv <- Sys.glob(file.path(d, "*", "CSV_Data", "*.csv"))
    if (!length(tif) || !length(csv)) return(NULL); at <- fread(csv[1]); setnames(at, toupper(names(at))); list(tif = tif[1], codes = as.integer(at[DIST_TYPE %in% strsplit(t, "|", fixed = TRUE)[[1]], VALUE])) })
  miss <- todo[vapply(files, is.null, TRUE)]; if (length(miss)) say("LANDFIRE disturbance missing for %s: no %s events in those years", paste(range(miss), collapse = "-"), t)
  cl <- makeCluster(min(10, length(todo))); a <- list(f = files, out = vapply(todo, lf_c, "", t = t), E = as.vector(E30), fact = fact, G = cf("region"), clear = clear_syncrosim_proj)
  parLapply(cl, seq_along(todo), function(i, a) { library(terra); a$clear(); terraOptions(progress = 0, memfrac = 0.04); g <- rast(a$G)
    if (is.null(a$f[[i]])) { writeRaster(init(g, 0), a$out[i], datatype = "INT1U", gdal = "COMPRESS=DEFLATE", overwrite = TRUE); return(NULL) }
    r <- rast(a$f[[i]]$tif); r <- crop(r, project(as.polygons(ext(a$E), crs = crs(g)), crs(r)), snap = "out"); levels(r) <- NULL
    e <- r %in% a$f[[i]]$codes; e <- project(e, rast(ext(a$E), res = 30, crs = crs(g)), method = "near"); if (a$fact > 1) e <- aggregate(e, a$fact, "mean", na.rm = TRUE)
    writeRaster(resample(e, g, method = "near") >= 0.5, a$out[i], datatype = "INT1U", gdal = "COMPRESS=DEFLATE", overwrite = TRUE); NULL }, a = a); stopCluster(cl) }
# LCMS Tree Removal (class 9) by year on the fitting grid (an event when >= half the cell's pixels); stand-replacing or partial is
# decided per surface from the NLCD of the following years, as in stage 6
lc_c <- function(y) cf(sprintf("lcms9_%d", y))
if (length(lc_kinds)) { todo <- YRS[-1][!file.exists(vapply(YRS[-1], lc_c, ""))]
  if (length(todo)) { lcd <- read_data_sources("LcmsFolder")$LcmsFolder
    files <- vapply(todo, function(y) { f <- Sys.glob(file.path(lcd, y, sprintf("*Change_%d.tif", y))); if (length(f)) f[1] else NA_character_ }, "")
    if (anyNA(files)) say("LCMS missing for %s: no harvest events in those years", paste(todo[is.na(files)], collapse = ", "))
    cl <- makeCluster(min(10, length(todo))); a <- list(f = files, out = vapply(todo, lc_c, ""), E = as.vector(E30), fact = fact, G = cf("region"), clear = clear_syncrosim_proj)
    parLapply(cl, seq_along(todo), function(i, a) { library(terra); a$clear(); terraOptions(progress = 0, memfrac = 0.04); g <- rast(a$G)
      if (is.na(a$f[i])) { writeRaster(init(g, 0), a$out[i], datatype = "INT1U", gdal = "COMPRESS=DEFLATE", overwrite = TRUE); return(NULL) }
      r <- rast(a$f[i]); r <- crop(r, project(as.polygons(ext(a$E), crs = crs(g)), crs(r)), snap = "out"); levels(r) <- NULL
      e <- r == 9; e <- project(e, rast(ext(a$E), res = 30, crs = crs(g)), method = "near"); if (a$fact > 1) e <- aggregate(e, a$fact, "mean", na.rm = TRUE)
      writeRaster(resample(e, g, method = "near") >= 0.5, a$out[i], datatype = "INT1U", gdal = "COMPRESS=DEFLATE", overwrite = TRUE); NULL }, a = a); stopCluster(cl) } }
for (i in seq_len(nrow(custom))) { k <- make.names(custom$Name[i]); if (is.na(custom$File[i]) || !file.exists(custom$File[i])) fail("Suitability Covariates: custom raster %s not found (%s)", custom$Name[i], custom$File[i])
  f <- cf(paste0("custom_", k)); if (!file.exists(f)) writeRaster(resample(rast(custom$File[i]), G, method = "bilinear"), f, overwrite = TRUE) }
say("Fitting layers ready: annual NLCD %d-%d, developed%s distance and share (epochs %s), roads, terrain, GAP, county, housing density 1990-2020, fire perimeters%s%s%s%s",
    y0, y1, if (need_ag) " and agriculture" else "", paste(EPOCHS, collapse = ", "), if (file.exists(cf("nccpi"))) ", NCCPI" else "",
    if (file.exists(cf("owner"))) ", forest owner" else "", if (length(lf_types)) paste0(", LANDFIRE ", paste(lf_types, collapse = ", ")) else "", if (length(lc_kinds)) ", LCMS Tree Removal" else "")
say("Covariates (%s): %s", cv_src, paste(vapply(fitted_s, function(s) sprintf("%s = %s", s, paste(cov_for(s)[, ifelse(Covariate == "Custom raster", Name, Covariate)], collapse = ", ")), ""), collapse = "; "))
progressBar()
lc_group <- function(n) data.table::fcase(n %in% 41:43, "Forest", n == 52, "Shrub", n == 71, "Grass", n %in% 81:82, "Agriculture", n %in% c(90, 95), "Wetland", n == 31, "Barren", default = NA_character_)

# the covariate table of a set of cells for conditions in year y (cells of G)
layer_paths <- function(y) c(DistDev = ep_c(epoch_of(y), "distdev"), DevShare = ep_c(epoch_of(y), "devshare"), HU = hu_c(decade_of(y)), DistRoad = cf("distroad"),
  Slope = cf("slope"), Elev = cf("elev"), GAP = cf("gap"), County = cf("county"),
  if (need_ag) c(DistAg = ep_c(epoch_of(y), "distag"), AgShare = ep_c(epoch_of(y), "agshare")),
  if (file.exists(cf("nccpi"))) c(Nccpi = cf("nccpi")), if (file.exists(cf("owner"))) c(Owner = cf("owner")),
  setNames(vapply(make.names(custom$Name), function(k) cf(paste0("custom_", k)), ""), make.names(custom$Name)))
covs <- function(d) { d[, `:=`(lDistDev = log1p(DistDev), lDistRoad = log1p(DistRoad), lHU = log1p(HU))]; if ("DistAg" %in% names(d)) d[, lDistAg := log1p(DistAg)]
  if ("Owner" %in% names(d)) d[, Owner := OWNERS[as.character(Owner)]]; d }
# a surface's model terms
terms_for <- function(s) { on <- cov_for(s); cu <- on[Covariate == "Custom raster"]
  c(unname(BUILTIN[intersect(on$Covariate, names(BUILTIN))]), if (nrow(cu)) sprintf("s(%s, k = 6)", make.names(cu$Name))) }
# patches: the sizes (in fitting cells) of 8-connected groups of event cells, by label propagation (cells = indices of a grid nc wide)
patch_sizes <- function(ev, nc) { if (!length(ev)) return(integer()); ev <- sort(ev); col <- (ev - 1) %% nc
  a <- integer(); b <- integer()
  for (o in list(c(1, 1), c(nc - 1, -1), c(nc, 0), c(nc + 1, 1))) { j <- ev + o[1]; ok <- if (o[2] == 1) col < nc - 1 else if (o[2] == -1) col > 0 else rep(TRUE, length(ev))
    m <- match(j[ok], ev); k <- which(ok)[!is.na(m)]; a <- c(a, k); b <- c(b, m[!is.na(m)]) }
  lab <- seq_along(ev)
  repeat { old <- lab; x <- data.table(k = c(a, b), v = c(lab[b], lab[a]))[, .(v = min(v)), by = k]; lab[x$k] <- pmin(lab[x$k], x$v); lab <- lab[lab]; if (identical(lab, old)) break }
  as.integer(table(lab)) }

# ---- per surface: sample, fit, test, predict -----------------------------------------------------------------------------------
cl <- makeCluster(10); on.exit(stopCluster(cl), add = TRUE)
clusterExport(cl, c("lc_group"), envir = environment()); invisible(clusterEvalQ(cl, { library(terra); library(data.table) }))
out_sum <- list(); out_curve <- list(); out_map <- list(); adj_set <- list(); adj_mult <- list(); surf_file <- list(); patches <- list()
reg_m <- values(rast(cf("region")), mat = FALSE); std_m <- values(rast(cf("study")), mat = FALSE); gapv <- values(rast(cf("gap")), mat = FALSE)
to_model <- function(r) { a <- project(r, P, method = "average"); mask(a, P) }
for (sname in unique(al$Surface)) {
  gs <- al[Surface == sname]; meth <- gs$Method[1]; adj <- any(gs$Adjacency)
  if (uniqueN(gs$Method) > 1) fail("Projection Allocation: surface %s has groups with different methods", sname)
  # who is eligible (Source Classes, the Target group's excluded GAP status) and what an event is (Event Classes)
  sc <- codes_of(gs$SourceClasses[1]); exg <- codes_of(gs$ExGap[1]); inS <- function(x) if (length(sc)) x %in% sc else !(x %in% NOT_SOURCE)
  lft <- if (grepl("^LANDFIRE:", gs$EventClasses[1])) sub("^LANDFIRE:\\s*", "", gs$EventClasses[1]) else NA_character_
  lck <- if (grepl("^LCMS:", gs$EventClasses[1])) sub("^LCMS:\\s*", "", gs$EventClasses[1]) else NA_character_
  to <- if (is.na(lft) && is.na(lck)) suppressWarnings(codes_of(gs$EventClasses[1])) else integer()
  if (meth == "Fitted" && is.na(lft) && is.na(lck) && (!length(to) || anyNA(to))) fail("Projection Allocation: surface %s needs Event Classes (NLCD codes, LANDFIRE:<type> or LCMS:standrep|partial)", sname)
  # adjacency in the run: developed share for developed events, agriculture share for agriculture events
  attr_k <- if (length(to) && all(to %in% DEV)) "Developed" else if (length(to) && all(to %in% 81:82)) "Agriculture" else NA_character_
  if (adj && is.na(attr_k)) { say("%s: adjacency applies to developed or agriculture events only - off", sname); adj <- FALSE }
  share_k <- c(Developed = "DevShare", Agriculture = "AgShare")[attr_k]
  if (meth == "Fitted") {
    terms <- terms_for(sname); if (!length(terms)) fail("Suitability Covariates: no covariate is switched on for surface %s", sname)
    a <- list(nl = setNames(vapply(YRS, nl_c, ""), YRS), lp = lapply(setNames(YRS[-1], YRS[-1]), function(y) layer_paths(y - 1)), bf = setNames(vapply((y0 - burn_w):y1, bf, ""), (y0 - burn_w):y1),
              lf = if (!is.na(lft)) setNames(vapply(YRS[-1], lf_c, "", t = lft), YRS[-1]) else NULL, reg = cf("region"), gap = cf("gap"), sc = sc, nots = NOT_SOURCE, exg = exg,
              lc = if (!is.na(lck)) setNames(vapply(YRS[-1], lc_c, ""), YRS[-1]) else NULL, kind = lck, y1 = y1,
              to = to, nctrl = nctrl, bw = burn_w, nc = ncol(G), patch = patch_sizes, clear = clear_syncrosim_proj)
    res_y <- parLapply(cl, YRS[-1], function(y, a) { a$clear(); terraOptions(progress = 0, memfrac = 0.04)
      v <- function(f) values(rast(f), mat = FALSE); inS <- function(x) if (length(a$sc)) x %in% a$sc else !(x %in% a$nots)
      p <- v(a$nl[[as.character(y - 1)]]); q <- v(a$nl[[as.character(y)]]); g <- v(a$gap); rg <- v(a$reg)
      burn <- Reduce(`|`, lapply((y - a$bw):y, function(k) { b <- v(a$bf[[as.character(k)]]); !is.na(b) & b > 0 }))
      el <- which(!is.na(rg) & !is.na(p) & inS(p) & !(g %in% a$exg) & !burn)
      # LCMS: Tree Removal, stand-replacing when NLCD shows shrub or grass that year or within two; no tree removal is a control
      tr <- if (!is.null(a$lc)) { e <- v(a$lc[[as.character(y)]])[el]; !is.na(e) & e > 0 } else rep(FALSE, length(el))
      isev <- if (!is.null(a$lf)) { e <- v(a$lf[[as.character(y)]])[el]; !is.na(e) & e > 0
      } else if (!is.null(a$lc)) { sr <- Reduce(`|`, lapply(y:min(y + 2, a$y1), function(k) v(a$nl[[as.character(k)]])[el] %in% c(52, 71)))
        if (a$kind == "standrep") tr & sr else tr & !sr
      } else q[el] %in% a$to
      ev <- el[isev]; ne <- el[!isev & !tr & inS(q[el])]   # controls: eligible cells that stayed within the source classes
      set.seed(y); ctrl <- if (length(ne)) sample(ne, min(a$nctrl, length(ne))) else integer(); cells <- c(ev, ctrl)
      d <- data.table(Year = y, Event = rep(c(1L, 0L), c(length(ev), length(ctrl))), W = rep(c(1, length(ne) / max(1, length(ctrl))), c(length(ev), length(ctrl))), LC = lc_group(p[cells]))
      for (k in names(a$lp[[as.character(y)]])) d[[k]] <- v(a$lp[[as.character(y)]][[k]])[cells]
      list(d = d, ps = data.table(Year = y, Cells = a$patch(ev, a$nc))) }, a = a)
    smp <- rbindlist(lapply(res_y, `[[`, "d")); patches[[sname]] <- rbindlist(lapply(res_y, `[[`, "ps"))
    smp <- covs(smp[!is.na(LC) & !is.na(County) & !is.na(Slope)]); smp[, `:=`(LC = factor(LC), GAP = factor(GAP), County = factor(County))]
    if ("Owner" %in% names(smp)) smp[, Owner := factor(Owner)]
    nev <- smp[Event == 1, .N]; say("%s: %d events (%.1f km2 of %d m cells) and %d controls, %d-%d", sname, nev, nev * res_f^2 / 1e6, res_f, smp[Event == 0, .N], y0 + 1, y1)
    if (nev < 30) fail("%s: only %d events in the fitting region - choose a larger Suitability Fitting Region (adjacent counties, the pyrome, the ecoregion or the state)", sname, nev)
    tm <- terms; if (nlevels(smp$GAP) < 2) tm <- setdiff(tm, "GAP"); if (nlevels(smp$County) < 2) tm <- tm[!grepl("County", tm)]; if (nlevels(smp$LC) < 2) tm <- setdiff(tm, "LC")
    if ("Owner" %in% tm && nlevels(smp$Owner) < 2) tm <- setdiff(tm, "Owner")
    form <- as.formula(paste("Event ~", paste(tm, collapse = " + ")))
    fitm <- function(d) bam(form, family = binomial, data = d, weights = W / mean(W), discrete = TRUE, nthreads = min(32, detectCores() - 4))
    lev <- list(LC = levels(smp$LC), GAP = levels(smp$GAP), County = levels(smp$County), Owner = if ("Owner" %in% names(smp)) levels(smp$Owner))
    # predict over chosen cells of G from year y conditions; hold the share that adjacency carries in the run at a typical value
    share_t <- if (adj) sprintf("s(%s, k = 6)", share_k) else NA_character_
    hold <- if (adj && share_t %in% tm) median(smp[Event == 0][[share_k]], na.rm = TRUE) else NA_real_
    pred_g <- function(m, y, cells) { lp <- layer_paths(y); n <- values(rast(nl_c(y)), mat = FALSE)[cells]; p <- rep(0, length(cells))
      ok <- !is.na(n) & inS(n) & !(gapv[cells] %in% exg)
      d <- data.table(LC = lc_group(n)); for (k in names(lp)) d[[k]] <- values(rast(lp[[k]]), mat = FALSE)[cells]
      ok <- ok & !is.na(d$LC) & !is.na(d$Slope) & (as.character(d$County) %in% lev$County | !any(grepl("County", tm)))
      d <- covs(d[ok]); if (!is.na(hold)) d[[share_k]] <- hold
      d[, `:=`(LC = factor(LC, lev$LC), GAP = factor(GAP, lev$GAP), County = factor(County, lev$County))]
      if ("Owner" %in% names(d)) d[, Owner := factor(Owner, lev$Owner)]
      if (nrow(d)) p[ok] <- predict(m, d, type = "response", block.size = 5e5); p[is.na(p)] <- 0; p }
    if (test_y > 0 && y1 - test_y > y0 + 5) { ty <- y1 - test_y
      m1 <- fitm(smp[Year <= ty]); cells <- which(!is.na(reg_m))
      pr <- pred_g(m1, ty, cells); a0 <- values(rast(nl_c(ty)), mat = FALSE)[cells]
      hit <- if (!is.na(lft)) Reduce(`|`, lapply((ty + 1):y1, function(k) { e <- values(rast(lf_c(lft, k)), mat = FALSE)[cells]; !is.na(e) & e > 0 }))
        else if (!is.na(lck)) Reduce(`|`, lapply((ty + 1):y1, function(k) { e <- values(rast(lc_c(k)), mat = FALSE)[cells]; t <- !is.na(e) & e > 0
          sr <- Reduce(`|`, lapply(k:min(k + 2, y1), function(j) values(rast(nl_c(j)), mat = FALSE)[cells] %in% c(52, 71))); if (lck == "standrep") t & sr else t & !sr }))
        else values(rast(nl_c(y1)), mat = FALSE)[cells] %in% to
      burn <- Reduce(`|`, lapply((ty - burn_w):y1, function(k) { b <- values(rast(bf(k)), mat = FALSE)[cells]; !is.na(b) & b > 0 }))
      el <- !is.na(a0) & inS(a0) & !(gapv[cells] %in% exg) & !burn
      v <- data.table(p = pr[el], n = hit[el])[order(-p)][, `:=`(land = seq_len(.N) / .N, got = cumsum(n) / max(1, sum(n)))]
      top <- vapply(c(0.01, 0.10), function(q) v[which(land >= q)[1], got], 0)
      r <- frank(v$p); n1 <- as.numeric(sum(v$n)); n0 <- as.numeric(sum(!v$n)); aucv <- (sum(r[v$n]) - n1 * (n1 + 1) / 2) / (n1 * n0)
      say("%s, out of sample (fit %d-%d, map from %d, %.1f km2 of change %d-%d): AUC %.3f; the top 1%% / 10%% of eligible land held %.0f%% / %.0f%% of it",
          sname, y0 + 1, ty, ty, n1 * res_f^2 / 1e6, ty + 1, y1, aucv, 100 * top[1], 100 * top[2])
      out_sum[[length(out_sum) + 1]] <- data.table(Surface = sname, Item = c("Test AUC", "Test share of change in the top 1% of land", "Test share of change in the top 10% of land", "Test change (km2)"),
        Value = c(aucv, top, n1 * res_f^2 / 1e6), Note = sprintf("fit %d-%d, map from %d, scored on %d-%d; random placement: 0.5, 0.01, 0.10", y0 + 1, ty, ty, ty + 1, y1))
      check(STAGE, sprintf("%s: the out-of-sample map beats random placement", sname), is.finite(aucv) && aucv > 0.5, sprintf("AUC %.3f", aucv)) }
    m <- fitm(smp); sm_m <- summary(m)
    out_sum[[length(out_sum) + 1]] <- data.table(Surface = sname, Item = c("Events (km2)", "Controls", "Deviance explained"), Value = c(nev * res_f^2 / 1e6, smp[Event == 0, .N], sm_m$dev.expl),
      Note = c(sprintf("%d m cells, %d-%d, fitting region", res_f, y0 + 1, y1), "weighted to the unchanged land of each year", paste(tm, collapse = " + ")))
    # response curves (others at typical unchanged-land values)
    CONT <- c("lDistDev", "DevShare", "lHU", "lDistRoad", "Slope", "Elev", "lDistAg", "AgShare", "Nccpi", make.names(custom$Name))
    base <- smp[Event == 0][1][rep(1, 60)]; vs <- intersect(CONT, all.vars(form))
    for (k in vs) {
      xs <- seq(quantile(smp[[k]], 0.01, na.rm = TRUE), quantile(smp[[k]], 0.99, na.rm = TRUE), length.out = 60); nd <- copy(base)
      for (j in vs) nd[[j]] <- median(smp[Event == 0][[j]], na.rm = TRUE)
      nd[[k]] <- xs; ef <- predict(m, nd, type = "link", exclude = grep("County", tm, value = TRUE))
      out_curve[[length(out_curve) + 1]] <- data.table(Surface = sname, Covariate = k, X = if (grepl("^l", k)) expm1(xs) else xs, Effect = ef - max(ef)) }
    # the surface from the historical end year over the study area, on the model grid
    cells <- which(!is.na(std_m)); pv <- rep(NA_real_, ncell(G)); pv[cells] <- pred_g(m, y1, cells)
    surf <- to_model(setValues(rast(G), pv))
    # adjacency: the fitted share curve, scaled to 1 at its highest
    if (adj && share_t %in% tm) { xs <- seq(0, 1, 0.05); nd <- smp[Event == 0][1][rep(1, length(xs))]
      for (j in setdiff(vs, share_k)) nd[[j]] <- median(smp[Event == 0][[j]], na.rm = TRUE)
      nd[[share_k]] <- xs; ef <- predict(m, nd, type = "link", exclude = grep("County", tm, value = TRUE)); amt <- exp(ef - max(ef))
      for (g in gs[Adjacency == TRUE, TransitionGroupId]) { adj_set[[g]] <- data.table(TransitionGroupId = g, StateAttributeTypeId = attr_k, NeighborhoodRadius = adj_r, UpdateFrequency = adj_up)
        adj_mult[[g]] <- data.table(TransitionGroupId = g, AttributeValue = xs, Amount = round(amt, 5)) } }
  } else {
    # Rules: WUI class weight x GAP status weight on the model grid
    rw <- read_ds("RuleWeight"); if (!nrow(rw)) rw <- read_default("projection", "rule-weights.csv"); rw <- rw[Surface == sname]
    if (!nrow(rw)) say("Rule Weights: none for surface %s - every allowed cell weighs 1", sname)
    rw[, Weight := as.numeric(Weight)]; ws <- rw[grepl("^WUI", Layer)]; wg <- rw[grepl("^GAP", Layer)]
    surf <- mask(init(rast(P), 1), P)
    if (nrow(ws)) { wb <- read_sf(file.path(CA, "wui.gpkg")); wb$w <- ws$Weight[match(wb$WUICLASS2020, ws$Class)]; wb$w[is.na(wb$w)] <- 1
      surf <- surf * cover(rasterize(vect(st_transform(wb, crs(P))), P, "w"), init(rast(P), 1)) }
    if (nrow(wg)) { gm <- strata_raster(rows[["GAP Status"]], env$PackageDirectory, rast(P), P); w <- wg$Weight[match(values(gm, mat = FALSE), as.integer(wg$Class))]; w[is.na(w)] <- 1
      surf <- surf * setValues(rast(P), w) }
    surf <- mask(surf, P)
    out_sum[[length(out_sum) + 1]] <- data.table(Surface = sname, Item = "Rule weights", Value = nrow(rw), Note = paste(unique(rw$Layer), collapse = " x "))
    if (adj) for (g in gs[Adjacency == TRUE, TransitionGroupId]) { adj_set[[g]] <- data.table(TransitionGroupId = g, StateAttributeTypeId = attr_k, NeighborhoodRadius = adj_r, UpdateFrequency = adj_up)
      adj_mult[[g]] <- data.table(TransitionGroupId = g, AttributeValue = c(0, 0.12, 0.88), Amount = c(0, 0, 1)) }
  }
  q <- global(surf, fun = function(x) quantile(x[x > 0], 0.995, na.rm = TRUE))[[1]]
  surf <- clamp(surf / max(q, 1e-12), 0, 1)
  surf_file[[sname]] <- write_raster(surf, sprintf("Suitability-%s.tif", gsub("[^A-Za-z0-9]+", "-", sname)), "FLT4S")
  out_map[[sname]] <- data.table(Surface = sname, FileName = surf_file[[sname]])
  out_sum[[length(out_sum) + 1]] <- data.table(Surface = sname, Item = "Land with a multiplier above 0 (share of model cells)", Value = global(surf > 0, "mean", na.rm = TRUE)[[1]], Note = meth)
  progressBar()
}

# ---- multipliers: the surface times each group's stage 9 map, from the historical end + 1 --------------------------------------
new_rows <- list()
for (i in seq_len(nrow(al))) { g <- al$TransitionGroupId[i]
  old <- sm[TransitionGroupId == g & Timestep == y1 + 1 & is.na(Iteration), MultiplierFileName]
  if (length(old) && grepl("^Suitability-", basename(old[1]))) fail("%s already has a stage 10 surface: base the Projection Setup on the Build result, not on another Projection Setup", g)
  s <- rast(surf_file[[al$Surface[i]]]); if (length(old) && !is.na(old[1])) s <- s * rast(old[1])
  f <- write_raster(s, sprintf("Suitability-%s.tif", gsub("[^A-Za-z0-9]+", "-", sub(" [Type]", "", g, fixed = TRUE))), "FLT4S")
  new_rows[[g]] <- data.table(Iteration = NA_integer_, Timestep = y1 + 1L, TransitionGroupId = g, MultiplierFileName = f) }
sm_out <- rbind(sm[!(TransitionGroupId %in% al$TransitionGroupId & Timestep == y1 + 1 & is.na(Iteration)), .(Iteration, Timestep, TransitionGroupId, MultiplierFileName)], rbindlist(new_rows))
write_stsim(sm_out, "TransitionSpatialMultiplier")
if (length(adj_set)) {
  # the state attributes adjacency reads: 1 on developed (NLCD 21-24) or agriculture (81, 82) classes
  scl <- stsim_list("StateClass"); used <- unique(rbindlist(adj_set)$StateAttributeTypeId); ATTR <- list(Developed = DEV, Agriculture = c(81L, 82L))
  sav <- as.data.table(datasheet(scn, "stsim_StateAttributeValue", optional = TRUE, lookupsAsFactors = FALSE))
  if (nrow(sav)) sav <- sav[!StateAttributeTypeId %in% names(ATTR)]
  dv <- rbindlist(lapply(used, function(k) data.table(StateClassId = scl$Name, StateAttributeTypeId = k, Value = as.numeric(as.integer(scl$Id) %in% ATTR[[k]]))))
  sv <- rbind(sav, dv, fill = TRUE); write_stsim(sv[, setdiff(names(sv), c("StateAttributeValueId", "ScenarioId")), with = FALSE], "StateAttributeValue")
  write_stsim(rbindlist(adj_set), "TransitionAdjacencySetting"); write_stsim(rbindlist(adj_mult), "TransitionAdjacencyMultiplier")
  say("Adjacency: %s; share within %g m, updated every %d years", paste(rbindlist(adj_set)[, sprintf("%s (%s)", TransitionGroupId, StateAttributeTypeId)], collapse = ", "), adj_r, adj_up) }

# ---- patch sizes: each Target group's historical event sizes as an ST-Sim size distribution ------------------------------------
# A patch's area in model cells (at least 1); size classes of 1, 2, 3, 5, 10, 20, 50, ... cells up to the largest patch; relative
# amount = the number of patches in the class (ST-Sim samples event sizes from it until they sum to the target). Groups whose
# patches are nearly all one model cell get none (placement stays cell by cell).
psz <- nz(so$PatchSizes, TRUE); psz <- isTRUE(as.logical(psz)) || identical(psz, -1L) || identical(psz, 1L)
if (psz && length(patches)) {
  term <- as.data.table(datasheet(prj, "stsim_Terminology", optional = TRUE, lookupsAsFactors = FALSE))
  au <- if (nrow(term) && !is.na(term$AmountUnits[1])) tolower(term$AmountUnits[1]) else "hectares"
  per_ha <- c(acres = 2.4710538, hectares = 1, `square kilometers` = 0.01, `square meters` = 1e4, `square miles` = 0.003861022)[[au]]
  cell_ha <- res_m^2 / 1e4; fit_ha <- res_f^2 / 1e4
  breaks <- c(1, 2, 3, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000)
  sd_rows <- list()
  for (t in unique(al[Surface %in% names(patches), Target])) {
    p <- rbindlist(patches[unique(al[Target == t & Surface %in% names(patches), Surface])])
    if (!nrow(p)) next
    n <- pmax(1, round(p$Cells * fit_ha / cell_ha)); top <- breaks[min(which(breaks >= max(n)))]; br <- breaks[breaks <= top]
    cnt <- as.numeric(table(factor(findInterval(n, c(0, br), left.open = TRUE), levels = seq_along(br))))
    one <- mean(n == 1)
    out_sum[[length(out_sum) + 1]] <- data.table(Surface = t, Item = c("Historical patches", "Patches of one model cell (share)", "Largest patch (model cells)", "Median patch (ha)"),
      Value = c(length(n), one, max(n), median(p$Cells) * fit_ha), Note = sprintf("%d m model cells; 8-connected event pixels of %d m, one year", res_m, res_f))
    if (one >= 0.95) { say("%s: %.0f%% of %d historical patches are one model cell - no size distribution", t, 100 * one, length(n)); next }
    sd_rows[[t]] <- data.table(TransitionGroupId = t, MaximumArea = br * cell_ha * per_ha, RelativeAmount = cnt)[RelativeAmount > 0]
    say("%s: size distribution from %d historical patches (median %.1f ha, largest %d cells; %.0f%% one cell)", t, length(n), median(p$Cells) * fit_ha, max(n), 100 * one) }
  if (length(sd_rows)) {
    write_stsim(rbindlist(sd_rows), "TransitionSizeDistribution")
    write_stsim(data.table(TransitionGroupId = names(sd_rows), Priority = "None", MaximizeFidelityToDistribution = TRUE, MaximizeFidelityToTotalArea = TRUE), "TransitionSizePrioritization") }
}
check(STAGE, "every allocated group has a multiplier from the historical end + 1", all(al$TransitionGroupId %in% names(new_rows)))
write_ds(rbindlist(out_sum, fill = TRUE), "OutputSuitability")
if (length(out_curve)) write_ds(rbindlist(out_curve), "OutputSuitabilityCurve")
write_ds(rbindlist(out_map), "OutputSuitabilityMap")
progressBar()
finish_checks()
