# =============================================================================
# 01-urban-suitability-p26.R - where urbanization happens: a 30 m regression on the annual NLCD record, Pyrome P26 (exploratory)
# =============================================================================
# User request 2026-10-22: fit urbanization suitability at 30 m from the historical record, look at the spatial multipliers before it
# goes into the model; PAD-US GAP status that prohibits conversion turns cells off; ST-Sim adjacency multipliers will carry the
# dynamic part later.
#   event       a 30 m pixel that is developed (NLCD 21-24) in year t and was not in t-1, among pixels that could be (not developed,
#               not water or ice in t-1), 1986-2023
#   predictors  (year t-1) distance to developed land and developed share within ~1 km (5-year epochs 1985, 1990, ... 2020),
#               housing density (SILVIS WUI v4 blocks, the latest census decade 1990-2020), distance to roads (LANDFIRE 2023),
#               slope and elevation (LANDFIRE 2020), land cover group, GAP status (PAD-US), county
#   model       logistic GAM (mgcv::bam) on all events and a weighted sample of non-events; fitted on 1986-2012, tested on 2013-2023,
#               then refitted on all years
#   maps        suitability for 2024 (predictors from 2023) at 30 m and averaged to 150 m; GAP 1-3 = 0 (protected from conversion)
# Steps cache their results in dev/urban/cache; delete a file to redo its step.
# Usage: Rscript dev/urban/01-urban-suitability-p26.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table); library(mgcv); library(parallel); library(ggplot2) })
DS <- "F:/lucas-master/Data Sources"; OUT <- "F:/lucasCore/dev/urban"; CA <- file.path(OUT, "cache"); dir.create(CA, showWarnings = FALSE)
terraOptions(progress = 0, memfrac = 0.5)
t00 <- Sys.time(); say <- function(...) cat(format(Sys.time(), "%H:%M"), sprintf(...), "\n")
YRS <- 1985:2023; EPOCHS <- seq(1985, 2020, 5); DEV <- 21:24

# ---- the study area on the NLCD 30 m grid -----------------------------------------------------------------------------------
nl_file <- function(y) file.path(DS, "NLCD", "Annual NLCD", sprintf("Annual_NLCD_LndCov_%d_CU_C1V0.tif", y))
ref <- rast(nl_file(2023))
py <- st_transform(subset(read_sf(file.path(DS, "Pyromes", "Data", "Pyromes_CONUS_20200206.shp")), PYROME == 26), crs(ref))
E <- align(ext(vect(py)), ref, snap = "out"); EV <- as.vector(E)   # workers get the numbers (terra objects do not cross to them)
mask_file <- file.path(CA, "mask.tif")
if (!file.exists(mask_file)) writeRaster(rasterize(vect(py), crop(ref, E), 1), mask_file, datatype = "INT1U", gdal = "COMPRESS=DEFLATE")
M <- rast(mask_file); say("P26 on the 30 m grid: %d x %d, %.0f km2", ncol(M), nrow(M), global(M, "sum", na.rm = TRUE)[[1]] * 9e-4)

# ---- annual NLCD, cropped ----------------------------------------------------------------------------------------------------
nlc <- function(y) file.path(CA, sprintf("nlcd_%d.tif", y))
todo <- YRS[!file.exists(vapply(YRS, nlc, ""))]
if (length(todo)) { cl <- makeCluster(min(20, length(todo)))
  clusterExport(cl, c("CA", "DS", "nl_file", "nlc", "EV", "mask_file")); invisible(clusterEvalQ(cl, library(terra)))
  parLapply(cl, todo, function(y) { r <- crop(rast(nl_file(y)), ext(EV)); levels(r) <- NULL; writeRaster(mask(r, rast(mask_file)), nlc(y), datatype = "INT1U", gdal = "COMPRESS=DEFLATE"); NULL }); stopCluster(cl) }
say("annual NLCD cropped (%d years)", length(YRS))

# ---- dynamic predictors by epoch: distance to developed (m) and developed share within ~1 km (33 x 33 pixels) ----------------
ep_file <- function(e, k) file.path(CA, sprintf("%s_%d.tif", k, e))
todo <- EPOCHS[!file.exists(vapply(EPOCHS, ep_file, "", k = "devshare"))]
if (length(todo)) { cl <- makeCluster(length(todo))
  clusterExport(cl, c("CA", "DS", "nlc", "ep_file", "DEV")); invisible(clusterEvalQ(cl, { library(terra); terraOptions(progress = 0, memfrac = 0.08) }))
  parLapply(cl, todo, function(e) { n <- rast(nlc(e)); d <- n %in% DEV
    writeRaster(distance(ifel(d, 1, NA)), ep_file(e, "distdev"), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE)
    writeRaster(focal(d, w = 33, fun = "mean", na.rm = TRUE), ep_file(e, "devshare"), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE); NULL })
  stopCluster(cl) }
say("dynamic predictors for epochs %s", paste(EPOCHS, collapse = ", "))
epoch_of <- function(y) max(EPOCHS[EPOCHS <= y])

# ---- static predictors -------------------------------------------------------------------------------------------------------
st_file <- function(k) file.path(CA, paste0(k, ".tif"))
if (!file.exists(st_file("distroad"))) { r <- crop(rast(file.path(DS, "Roads", "LF2023_Roads_CONUS", "Tif", "LF2023_Roads_CONUS.tif")), E); levels(r) <- NULL
  r <- resample(r, M, method = "near"); writeRaster(distance(ifel(!is.na(r) & r > 0, 1, NA)), st_file("distroad"), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE") }
if (!file.exists(st_file("slope"))) { d <- crop(rast(file.path(DS, "DEM", "LF2020_Elev_220_CONUS", "Tif", "LC20_Elev_220.tif")), E); levels(d) <- NULL; d <- resample(d, M, method = "bilinear")
  writeRaster(d, st_file("elev"), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE"); writeRaster(terrain(d, "slope"), st_file("slope"), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE") }
if (!file.exists(st_file("gap"))) { g <- st_transform(read_sf(file.path(DS, "PADUS", "padus_gapstatus.shp")), crs(M)); g <- g[st_intersects(g, py, sparse = FALSE)[, 1], ]
  gf <- intersect(c("GAP_Sts", "GAP_STS", "gap_sts"), names(g))[1]; g$gap <- as.integer(as.character(st_drop_geometry(g)[[gf]]))
  r <- rasterize(vect(g), M, "gap", fun = "min"); writeRaster(mask(cover(r, init(M, 9)), M), st_file("gap"), datatype = "INT1U", gdal = "COMPRESS=DEFLATE") }
if (!file.exists(st_file("county"))) { co <- st_transform(read_sf(file.path(DS, "Study Areas", "Counties", "tl_rd22_us_county.shp")), crs(M)); co <- co[st_intersects(co, py, sparse = FALSE)[, 1], ]
  co$cid <- as.integer(co$GEOID); writeRaster(mask(rasterize(vect(co), M, "cid"), M), st_file("county"), datatype = "INT4S", gdal = "COMPRESS=DEFLATE") }
hu_file <- function(dec) file.path(CA, sprintf("hu_%d.tif", dec))
if (!file.exists(hu_file(2020))) { # P26 reaches into Nevada (Lake Tahoe east shore, Reno, Carson City): both states' blocks
  b <- do.call(rbind, lapply(c("CA", "NV"), function(s) read_sf(file.path(DS, "WUI", "2020", sprintf("%s_wui_block_1990_2020_change_v4.gdb", s)))[, c("HUDEN1990", "HUDEN2000", "HUDEN2010", "HUDEN2020")])); b <- st_transform(b, crs(M))
  b <- b[st_intersects(b, st_transform(py, crs(M)), sparse = FALSE)[, 1], ]
  for (dec in c(1990, 2000, 2010, 2020)) writeRaster(mask(rasterize(vect(b), M, sprintf("HUDEN%d", dec)), M), hu_file(dec), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE") }
decade_of <- function(y) max(c(1990, 2000, 2010, 2020)[c(1990, 2000, 2010, 2020) <= max(y, 1990)])
say("static predictors ready (roads, slope, elevation, GAP, county, housing density 1990-2020)")

# ---- events and a weighted sample of non-events --------------------------------------------------------------------------------
lc_group <- function(n) fcase(n %in% 41:43, "Forest", n == 52, "Shrub", n == 71, "Grass", n %in% 81:82, "Agriculture", n %in% c(90, 95), "Wetland", n == 31, "Barren", default = NA_character_)
samp_file <- file.path(CA, "sample.rds"); NCTRL <- 25000L
if (!file.exists(samp_file)) {
  cl <- makeCluster(10); clusterExport(cl, c("CA", "DS", "nlc", "ep_file", "epoch_of", "EPOCHS", "st_file", "hu_file", "decade_of", "DEV", "NCTRL", "lc_group"))
  invisible(clusterEvalQ(cl, { library(terra); library(data.table); terraOptions(progress = 0, memfrac = 0.04) }))
  smp <- rbindlist(parLapply(cl, YRS[-1], function(y) {
    a <- values(rast(nlc(y - 1)), mat = FALSE); b <- values(rast(nlc(y)), mat = FALSE)
    elig <- which(!is.na(a) & !(a %in% c(DEV, 11, 12))); ev <- elig[b[elig] %in% DEV]; ne <- setdiff(elig, ev)
    set.seed(y); ctrl <- sample(ne, min(NCTRL, length(ne)))
    cells <- c(ev, ctrl); e <- epoch_of(y - 1)
    v <- function(f) values(rast(f), mat = FALSE)[cells]
    data.table(Year = y, Cell = cells, Event = rep(c(1L, 0L), c(length(ev), length(ctrl))), W = rep(c(1, length(ne) / length(ctrl)), c(length(ev), length(ctrl))),
               LC = lc_group(a[cells]), DistDev = v(ep_file(e, "distdev")), DevShare = v(ep_file(e, "devshare")), HU = v(hu_file(decade_of(y - 1))),
               DistRoad = v(st_file("distroad")), Slope = v(st_file("slope")), Elev = v(st_file("elev")), GAP = v(st_file("gap")), County = v(st_file("county"))) }))
  stopCluster(cl); saveRDS(smp, samp_file) }
smp <- readRDS(samp_file); smp <- smp[!is.na(LC) & !is.na(County) & !is.na(Slope)]
smp[, `:=`(GAP = factor(GAP), LC = factor(LC), County = factor(County), lDistDev = log1p(DistDev), lDistRoad = log1p(DistRoad), lHU = log1p(HU))]
say("sample: %d events (%.1f km2), %d non-events; years %d-%d", smp[Event == 1, .N], smp[Event == 1, .N] * 9e-4, smp[Event == 0, .N], min(smp$Year), max(smp$Year))
print(smp[Event == 1, .N, by = LC][order(-N)])

# ---- fit, test, refit ------------------------------------------------------------------------------------------------------------
form <- Event ~ s(lDistDev, k = 8) + s(DevShare, k = 6) + s(lHU, k = 6) + s(lDistRoad, k = 6) + s(Slope, k = 6) + s(Elev, k = 6) + LC + GAP + s(County, bs = "re")
auc <- function(y, p, w = rep(1, length(y))) { o <- order(p); y <- y[o]; w <- w[o]; pos <- sum(w[y == 1]); neg <- sum(w[y == 0])
  cn <- cumsum(w * (y == 0)); sum(w[y == 1] * cn[y == 1]) / (pos * neg) }
nc <- min(32, detectCores() - 4)
m1 <- bam(form, family = binomial, data = smp[Year <= 2012], weights = W / mean(W), discrete = TRUE, nthreads = nc)
te <- smp[Year > 2012]; te[, p := predict(m1, te, type = "response")]
a_test <- auc(te$Event, te$p, te$W); a_dist <- auc(te$Event, -te$DistDev, te$W)
say("held-out AUC 2013-2023: %.3f (distance to developed alone %.3f; random placement 0.5)", a_test, a_dist)
# share of each year's new development that falls in the top 10%% of eligible land by suitability (random placement: 10%%)
cap <- te[, { thr <- Hmisc_q <- {o <- order(-p); cw <- cumsum(W[o]) / sum(W); p[o][which(cw >= 0.10)[1]]}; .(Top10 = sum(Event[p >= thr]) / sum(Event)) }, by = Year]
say("new development in the top 10%% most suitable land, 2013-2023: %.0f%% (random: 10%%)", 100 * mean(cap$Top10, na.rm = TRUE))
m <- bam(form, family = binomial, data = smp, weights = W / mean(W), discrete = TRUE, nthreads = nc)
saveRDS(m, file.path(CA, "model.rds")); print(summary(m)$s.table); print(summary(m)$p.table[, c(1, 4)])

# response curves
pd <- rbindlist(lapply(c("lDistDev", "DevShare", "lHU", "lDistRoad", "Slope", "Elev"), function(k) { g <- smp[sample(.N, 2000)]
  xs <- seq(quantile(smp[[k]], 0.01, na.rm = TRUE), quantile(smp[[k]], 0.99, na.rm = TRUE), length.out = 80)
  nd <- smp[rep(1, 80)]; for (j in c("lDistDev", "DevShare", "lHU", "lDistRoad", "Slope", "Elev")) nd[[j]] <- median(smp[Event == 0][[j]], na.rm = TRUE)
  nd[, LC := factor("Grass", levels(smp$LC))][, GAP := factor("9", levels(smp$GAP))]; nd[[k]] <- xs
  data.table(Var = k, x = xs, y = predict(m, nd, type = "link", exclude = "s(County)")) }))
lab <- c(lDistDev = "Distance to developed (m)", DevShare = "Developed share within ~1 km", lHU = "Housing density (units/km2)", lDistRoad = "Distance to roads (m)", Slope = "Slope (degrees)", Elev = "Elevation (m)")
pd[, X := ifelse(grepl("^l", Var), expm1(x), x)][, Var := factor(lab[Var], lab)]
pr <- ggplot(pd, aes(X, y - max(y), group = Var)) + geom_line(colour = "#B23A48", linewidth = 0.8) + facet_wrap(~Var, scales = "free_x") +
  scale_x_continuous(trans = "identity") + labs(x = NULL, y = "Effect on log-odds (0 = the predictor's best value)", title = "Urbanization suitability, P26: response curves",
  subtitle = sprintf("Logistic GAM on 30 m annual NLCD 1986-2023; others held at typical non-developed values (grassland, not in PAD-US). Held-out AUC 2013-2023 %.2f.", a_test)) +
  theme_minimal(base_size = 10) + theme(panel.grid.minor = element_blank(), strip.text = element_text(hjust = 0, face = "bold"), plot.background = element_rect(fill = "white", colour = NA))
ggsave(file.path(OUT, "urban-response-curves-p26.png"), pr, width = 10, height = 6, dpi = 180)

# ---- the suitability map for 2024 (predictors from 2023) --------------------------------------------------------------------------
s30 <- file.path(OUT, "urban-suitability-p26-30m.tif")
if (!file.exists(s30)) {
  n23 <- rast(nlc(2023)); e23 <- file.path(CA, "distdev_2023.tif"); s23 <- file.path(CA, "devshare_2023.tif")
  if (!file.exists(s23)) { d <- n23 %in% DEV; writeRaster(distance(ifel(d, 1, NA)), e23, datatype = "FLT4S", gdal = "COMPRESS=DEFLATE"); writeRaster(focal(d, w = 33, fun = "mean", na.rm = TRUE), s23, datatype = "FLT4S", gdal = "COMPRESS=DEFLATE") }
  stk <- c(n23, rast(e23), rast(s23), rast(hu_file(2020)), rast(st_file("distroad")), rast(st_file("slope")), rast(st_file("elev")), rast(st_file("gap")), rast(st_file("county")))
  names(stk) <- c("NLCD", "DistDev", "DevShare", "HU", "DistRoad", "Slope", "Elev", "GAP", "County")
  out <- rast(M); vals <- rep(NA_real_, ncell(M)); idx <- which(!is.na(values(M, mat = FALSE)))
  for (ch in split(idx, ceiling(seq_along(idx) / 2e6))) {
    d <- as.data.table(stk[ch]); d[, LC := lc_group(NLCD)]
    ok <- !is.na(d$LC) & !(d$NLCD %in% c(DEV, 11, 12)) & !is.na(d$County) & !is.na(d$Slope) & as.character(d$County) %in% levels(smp$County)
    d <- d[ok][, `:=`(GAP = factor(GAP, levels(smp$GAP)), LC = factor(LC, levels(smp$LC)), County = factor(County, levels(smp$County)), lDistDev = log1p(DistDev), lDistRoad = log1p(DistRoad), lHU = log1p(HU))]
    p <- rep(0, length(ch)); p[ok] <- predict(m, d, type = "response", block.size = 5e5)
    vals[ch] <- p }
  vals[vals > 0 & values(rast(st_file("gap")), mat = FALSE) %in% 1:3] <- 0   # protected from conversion
  writeRaster(setValues(out, vals), s30, datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE) }
S30 <- rast(s30)
# 150 m: the mean over the 25 pixels (pixels that cannot urbanize count as 0), scaled 0-1 at the 99.5th percentile
s150 <- file.path(OUT, "urban-suitability-p26-150m.tif")
if (!file.exists(s150)) { a <- aggregate(S30, 5, mean, na.rm = TRUE); q <- global(a, fun = function(v) quantile(v, 0.995, na.rm = TRUE))[[1]]
  writeRaster(clamp(a / q, 0, 1), s150, datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE) }
say("maps: %s, %s", basename(s30), basename(s150))
saveRDS(list(auc_test = a_test, auc_dist = a_dist, top10 = cap), file.path(OUT, "urban-suitability-p26-metrics.rds"))
say("done in %.0f min", as.numeric(Sys.time() - t00, units = "mins"))
