  ab <- # =============================================================================
# 10-transition-suitability.R - stage 10: where projected transitions go (Projection Setup)
# =============================================================================
# Stage 9 sets how much of each transition happens per unit and year; until now its Target groups were placed at random among the
# allowed cells. Projection Allocation (an empty sheet uses defaults/projection/allocation.csv) gives each group a method:
#   Fitted  a logistic GAM on the annual NLCD record (user decisions 2026-10-22, tested on P26 in dev/urban): an event is an
#           undeveloped pixel (not NLCD 21-24, water or ice) that changes to the surface's Event Classes; pixels on GAP 1-3 land and
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
# threshold (none below 12% developed, full above 88%).
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
notT <- setdiff(al$TransitionGroupId, pt[Method == "Target", TransitionGroupId])
if (length(notT)) { say("Not Target groups in Projection Transitions (allocation applies to Target groups only): %s - skipped", paste(notT, collapse = "; ")); al <- al[!TransitionGroupId %in% notT] }
src <- read_data_sources(c("NlcdFolder", "FirePerimeterHistoryFile", "RoadsFile", "ElevationFile", "WuiFolder"))
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
say("Fitting layers ready: annual NLCD %d-%d, developed distance and share (epochs %s), roads, terrain, GAP, county, housing density 1990-2020, fire perimeters",
    y0, y1, paste(EPOCHS, collapse = ", "))
progressBar()

# ---- covariates ------------------------------------------------------------------------------------------------------------
BUILTIN <- c(`Distance to developed land` = "s(lDistDev, k = 8)", `Developed share within 1 km` = "s(DevShare, k = 6)", `Housing density (census decade)` = "s(lHU, k = 6)",
             `Distance to roads` = "s(lDistRoad, k = 6)", Slope = "s(Slope, k = 6)", Elevation = "s(Elev, k = 6)", `Land cover` = "LC", `GAP status` = "GAP", County = "s(County, bs = \"re\")")
cv <- read_ds("SuitabilityCovariate")
if (!nrow(cv)) cv <- data.table(Covariate = names(BUILTIN), Include = TRUE, Name = NA_character_, File = NA_character_)
cv[, Include := toupper(as.character(Include)) %in% c("YES", "TRUE", "-1", "1")]
on <- cv[Include == TRUE]
custom <- on[Covariate == "Custom raster"]
for (i in seq_len(nrow(custom))) { k <- make.names(custom$Name[i]); if (is.na(custom$File[i]) || !file.exists(custom$File[i])) fail("Suitability Covariates: custom raster %s not found (%s)", custom$Name[i], custom$File[i])
  f <- cf(paste0("custom_", k)); if (!file.exists(f)) writeRaster(resample(rast(custom$File[i]), G, method = "bilinear"), f, overwrite = TRUE) }
terms <- c(unname(BUILTIN[intersect(on$Covariate, names(BUILTIN))]), if (nrow(custom)) sprintf("s(%s, k = 6)", make.names(custom$Name)))
if (!length(terms)) fail("Suitability Covariates: no covariate is switched on")
say("Covariates: %s", paste(c(intersect(on$Covariate, names(BUILTIN)), custom$Name), collapse = ", "))
lc_group <- function(n) data.table::fcase(n %in% 41:43, "Forest", n == 52, "Shrub", n == 71, "Grass", n %in% 81:82, "Agriculture", n %in% c(90, 95), "Wetland", n == 31, "Barren", default = NA_character_)

# the covariate table of a set of cells for conditions in year y (cells of G)
layer_paths <- function(y) c(DistDev = ep_c(epoch_of(y), "distdev"), DevShare = ep_c(epoch_of(y), "devshare"), HU = hu_c(decade_of(y)), DistRoad = cf("distroad"),
  Slope = cf("slope"), Elev = cf("elev"), GAP = cf("gap"), County = cf("county"), setNames(vapply(make.names(custom$Name), function(k) cf(paste0("custom_", k)), ""), make.names(custom$Name)))
covs <- function(d) { d[, `:=`(lDistDev = log1p(DistDev), lDistRoad = log1p(DistRoad), lHU = log1p(HU))]; d }

# ---- per surface: sample, fit, test, predict -----------------------------------------------------------------------------------
cl <- makeCluster(10); on.exit(stopCluster(cl), add = TRUE)
clusterExport(cl, c("lc_group"), envir = environment()); invisible(clusterEvalQ(cl, { library(terra); library(data.table) }))
out_sum <- list(); out_curve <- list(); out_map <- list(); adj_set <- list(); adj_mult <- list(); surf_file <- list()
reg_m <- values(rast(cf("region")), mat = FALSE); std_m <- values(rast(cf("study")), mat = FALSE); gapv <- values(rast(cf("gap")), mat = FALSE)
to_model <- function(r) { a <- project(r, P, method = "average"); mask(a, P) }
for (sname in unique(al$Surface)) {
  gs <- al[Surface == sname]; meth <- gs$Method[1]; adj <- any(gs$Adjacency)
  if (uniqueN(gs$Method) > 1) fail("Projection Allocation: surface %s has groups with different methods", sname)
  if (meth == "Fitted") {
    to <- as.integer(strsplit(gs$EventClasses[1], "[|,; ]+")[[1]]); if (!length(to) || anyNA(to)) fail("Projection Allocation: surface %s needs Event Classes (NLCD codes)", sname)
    a <- list(nl = setNames(vapply(YRS, nl_c, ""), YRS), lp = lapply(setNames(YRS[-1], YRS[-1]), function(y) layer_paths(y - 1)), bf = setNames(vapply((y0 - burn_w):y1, bf, ""), (y0 - burn_w):y1),
              reg = cf("region"), gap = cf("gap"), to = to, nctrl = nctrl, bw = burn_w, clear = clear_syncrosim_proj)
    smp <- rbindlist(parLapply(cl, YRS[-1], function(y, a) { a$clear(); terraOptions(progress = 0, memfrac = 0.04)
      v <- function(f) values(rast(f), mat = FALSE)
      p <- v(a$nl[[as.character(y - 1)]]); q <- v(a$nl[[as.character(y)]]); g <- v(a$gap); rg <- v(a$reg)
      burn <- Reduce(`|`, lapply((y - a$bw):y, function(k) { b <- v(a$bf[[as.character(k)]]); !is.na(b) & b > 0 }))
      el <- which(!is.na(rg) & !is.na(p) & !(p %in% c(21:24, 11, 12)) & !(g %in% 1:3) & !burn)
      ev <- el[q[el] %in% a$to]; ne <- el[!(q[el] %in% 21:24)]
      set.seed(y); ctrl <- if (length(ne)) sample(ne, min(a$nctrl, length(ne))) else integer(); cells <- c(ev, ctrl)
      d <- data.table(Year = y, Event = rep(c(1L, 0L), c(length(ev), length(ctrl))), W = rep(c(1, length(ne) / max(1, length(ctrl))), c(length(ev), length(ctrl))), LC = lc_group(p[cells]))
      for (k in names(a$lp[[as.character(y)]])) d[[k]] <- v(a$lp[[as.character(y)]][[k]])[cells]
      d }, a = a))
    smp <- covs(smp[!is.na(LC) & !is.na(County) & !is.na(Slope)]); smp[, `:=`(LC = factor(LC), GAP = factor(GAP), County = factor(County))]
    nev <- smp[Event == 1, .N]; say("%s: %d events (%.1f km2 of %d m cells) and %d controls, %d-%d", sname, nev, nev * res_f^2 / 1e6, res_f, smp[Event == 0, .N], y0 + 1, y1)
    if (nev < 30) fail("%s: only %d events in the fitting region - choose a larger Suitability Fitting Region (adjacent counties, the pyrome, the ecoregion or the state)", sname, nev)
    tm <- terms; if (nlevels(smp$GAP) < 2) tm <- setdiff(tm, "GAP"); if (nlevels(smp$County) < 2) tm <- tm[!grepl("County", tm)]; if (nlevels(smp$LC) < 2) tm <- setdiff(tm, "LC")
    form <- as.formula(paste("Event ~", paste(tm, collapse = " + ")))
    fitm <- function(d) bam(form, family = binomial, data = d, weights = W / mean(W), discrete = TRUE, nthreads = min(32, detectCores() - 4))
    lev <- list(LC = levels(smp$LC), GAP = levels(smp$GAP), County = levels(smp$County))
    # predict over chosen cells of G from year y conditions; hold DevShare at a typical value when adjacency carries it in the run
    hold <- if (adj && "s(DevShare, k = 6)" %in% tm) median(smp[Event == 0, DevShare], na.rm = TRUE) else NA_real_
    pred_g <- function(m, y, cells) { lp <- layer_paths(y); n <- values(rast(nl_c(y)), mat = FALSE)[cells]; p <- rep(0, length(cells))
      ok <- !is.na(n) & !(n %in% c(DEV, 11, 12)) & !(gapv[cells] %in% 1:3)
      d <- data.table(LC = lc_group(n)); for (k in names(lp)) d[[k]] <- values(rast(lp[[k]]), mat = FALSE)[cells]
      ok <- ok & !is.na(d$LC) & !is.na(d$Slope) & (as.character(d$County) %in% lev$County | !any(grepl("County", tm)))
      d <- covs(d[ok]); if (!is.na(hold)) d[, DevShare := hold]
      d[, `:=`(LC = factor(LC, lev$LC), GAP = factor(GAP, lev$GAP), County = factor(County, lev$County))]
      if (nrow(d)) p[ok] <- predict(m, d, type = "response", block.size = 5e5); p }
    if (test_y > 0 && y1 - test_y > y0 + 5) { ty <- y1 - test_y
      m1 <- fitm(smp[Year <= ty]); cells <- which(!is.na(reg_m))
      pr <- pred_g(m1, ty, cells); a0 <- values(rast(nl_c(ty)), mat = FALSE)[cells]; b1 <- values(rast(nl_c(y1)), mat = FALSE)[cells]
      burn <- Reduce(`|`, lapply((ty - burn_w):y1, function(k) { b <- values(rast(bf(k)), mat = FALSE)[cells]; !is.na(b) & b > 0 }))
      el <- !is.na(a0) & !(a0 %in% c(DEV, 11, 12)) & !(gapv[cells] %in% 1:3) & !burn
      v <- data.table(p = pr[el], n = b1[el] %in% to)[order(-p)][, `:=`(land = seq_len(.N) / .N, got = cumsum(n) / max(1, sum(n)))]
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
    base <- smp[Event == 0][1][rep(1, 60)]
    for (k in intersect(c("lDistDev", "DevShare", "lHU", "lDistRoad", "Slope", "Elev", make.names(custom$Name)), all.vars(form))) {
      xs <- seq(quantile(smp[[k]], 0.01, na.rm = TRUE), quantile(smp[[k]], 0.99, na.rm = TRUE), length.out = 60); nd <- copy(base)
      for (j in intersect(c("lDistDev", "DevShare", "lHU", "lDistRoad", "Slope", "Elev", make.names(custom$Name)), all.vars(form))) nd[[j]] <- median(smp[Event == 0][[j]], na.rm = TRUE)
      nd[[k]] <- xs; ef <- predict(m, nd, type = "link", exclude = grep("County", tm, value = TRUE))
      out_curve[[length(out_curve) + 1]] <- data.table(Surface = sname, Covariate = k, X = if (grepl("^l", k)) expm1(xs) else xs, Effect = ef - max(ef)) }
    # the surface from the historical end year over the study area, on the model grid
    cells <- which(!is.na(std_m)); pv <- rep(NA_real_, ncell(G)); pv[cells] <- pred_g(m, y1, cells)
    surf <- to_model(setValues(rast(G), pv))
    # adjacency: the fitted developed-share curve, scaled to 1 at its highest
    if (adj && "s(DevShare, k = 6)" %in% tm) { xs <- seq(0, 1, 0.05); nd <- smp[Event == 0][1][rep(1, length(xs))]
      for (j in intersect(c("lDistDev", "lHU", "lDistRoad", "Slope", "Elev", make.names(custom$Name)), all.vars(form))) nd[[j]] <- median(smp[Event == 0][[j]], na.rm = TRUE)
      nd$DevShare <- xs; ef <- predict(m, nd, type = "link", exclude = grep("County", tm, value = TRUE)); amt <- exp(ef - max(ef))
      for (g in gs[Adjacency == TRUE, TransitionGroupId]) { adj_set[[g]] <- data.table(TransitionGroupId = g, StateAttributeTypeId = "Developed", NeighborhoodRadius = adj_r, UpdateFrequency = adj_up)
        adj_mult[[g]] <- data.table(TransitionGroupId = g, AttributeValue = xs, Amount = round(amt, 5)) } }
  } else {
    # Rules: WUI class weight x GAP status weight on the model grid
    rw <- read_ds("RuleWeight"); if (!nrow(rw)) rw <- read_default("projection", "rule-weights.csv"); rw <- rw[Surface == sname]
    if (!nrow(rw)) fail("Rule Weights: no weights for surface %s", sname)
    rw[, Weight := as.numeric(Weight)]; ws <- rw[grepl("^WUI", Layer)]; wg <- rw[grepl("^GAP", Layer)]
    surf <- mask(init(rast(P), 1), P)
    if (nrow(ws)) { wb <- read_sf(file.path(CA, "wui.gpkg")); wb$w <- ws$Weight[match(wb$WUICLASS2020, ws$Class)]; wb$w[is.na(wb$w)] <- 1
      surf <- surf * cover(rasterize(vect(st_transform(wb, crs(P))), P, "w"), init(rast(P), 1)) }
    if (nrow(wg)) { gm <- strata_raster(rows[["GAP Status"]], env$PackageDirectory, rast(P), P); w <- wg$Weight[match(values(gm, mat = FALSE), as.integer(wg$Class))]; w[is.na(w)] <- 1
      surf <- surf * setValues(rast(P), w) }
    surf <- mask(surf, P)
    out_sum[[length(out_sum) + 1]] <- data.table(Surface = sname, Item = "Rule weights", Value = nrow(rw), Note = paste(unique(rw$Layer), collapse = " x "))
    for (g in gs[Adjacency == TRUE, TransitionGroupId]) { adj_set[[g]] <- data.table(TransitionGroupId = g, StateAttributeTypeId = "Developed", NeighborhoodRadius = adj_r, UpdateFrequency = adj_up)
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
  scl <- stsim_list("StateClass"); dev_cl <- scl$Name[as.integer(scl$Id) %in% DEV]
  sav <- as.data.table(datasheet(scn, "stsim_StateAttributeValue", optional = TRUE, lookupsAsFactors = FALSE))
  if (nrow(sav)) sav <- sav[StateAttributeTypeId != "Developed"]
  dv <- data.table(StateClassId = scl$Name, StateAttributeTypeId = "Developed", Value = as.numeric(scl$Name %in% dev_cl))
  write_stsim(rbind(sav, dv, fill = TRUE)[, setdiff(names(rbind(sav, dv, fill = TRUE)), c("StateAttributeValueId", "ScenarioId")), with = FALSE], "StateAttributeValue")
  write_stsim(rbindlist(adj_set), "TransitionAdjacencySetting"); write_stsim(rbindlist(adj_mult), "TransitionAdjacencyMultiplier")
  say("Adjacency: %d groups, developed share within %g m, updated every %d years", length(adj_set), adj_r, adj_up) }
check(STAGE, "every allocated group has a multiplier from the historical end + 1", all(al$TransitionGroupId %in% names(new_rows)))
write_ds(rbindlist(out_sum, fill = TRUE), "OutputSuitability")
if (length(out_curve)) write_ds(rbindlist(out_curve), "OutputSuitabilityCurve")
write_ds(rbindlist(out_map), "OutputSuitabilityMap")
progressBar()
finish_checks()
