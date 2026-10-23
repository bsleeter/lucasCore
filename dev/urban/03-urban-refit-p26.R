# =============================================================================
# 03-urban-refit-p26.R - urbanization suitability refitted with stricter events, plus a separate Open Space model (P26, 30 m)
# =============================================================================
# User decisions 2026-10-22 after the first look (01, 02): NLCD gains to Developed Open Space were mostly roads and post-fire
# relabelling, and a quarter of them fell on national forest land. Now:
#   urbanization  undeveloped (not 21-24, not water or ice) in t-1 -> Developed Low, Medium or High (22-24) in t
#   open space    undeveloped in t-1 -> Developed Open Space (21) in t, fitted and mapped separately
#   excluded      pixels on GAP 1-3 land (protected from conversion; 0 in the maps) and pixels inside an interagency fire perimeter
#                 of year t or the three years before (post-fire relabelling), both as events and as controls
#   test          fitted on 1986-2012; the map built from 2012 conditions is scored on 2013-2023 development (out of sample)
# Reuses 01's cache (cropped NLCD, epoch and static predictors). Usage: Rscript dev/urban/03-urban-refit-p26.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table); library(mgcv); library(parallel); library(ggplot2) })
DS <- "F:/lucas-master/Data Sources"; OUT <- "F:/lucasCore/dev/urban"; CA <- file.path(OUT, "cache")
terraOptions(progress = 0, memfrac = 0.5); t00 <- Sys.time(); say <- function(...) cat(format(Sys.time(), "%H:%M"), sprintf(...), "\n")
YRS <- 1985:2023; EPOCHS <- seq(1985, 2020, 5); DEVALL <- 21:24; NCTRL <- 25000L
M <- rast(file.path(CA, "mask.tif"))
nlc <- function(y) file.path(CA, sprintf("nlcd_%d.tif", y)); ep_file <- function(e, k) file.path(CA, sprintf("%s_%d.tif", k, e))
st_file <- function(k) file.path(CA, paste0(k, ".tif")); hu_file <- function(dec) file.path(CA, sprintf("hu_%d.tif", dec))
epoch_of <- function(y) max(EPOCHS[EPOCHS <= y]); decade_of <- function(y) max(c(1990, 2000, 2010, 2020)[c(1990, 2000, 2010, 2020) <= max(y, 1990)])
lc_group <- function(n) fcase(n %in% 41:43, "Forest", n == 52, "Shrub", n == 71, "Grass", n %in% 81:82, "Agriculture", n %in% c(90, 95), "Wetland", n == 31, "Barren", default = NA_character_)

# ---- fire perimeters by year (interagency history), 1982-2023 ---------------------------------------------------------------
bf <- function(y) file.path(CA, sprintf("burn_%d.tif", y))
if (!file.exists(bf(2023))) {
  f <- file.path(DS, "NIFS", "InterAgencyFirePerimeterHistory_All_Years_View", "InterAgencyFirePerimeterHistory_All_Years_View.shp"); lay <- tools::file_path_sans_ext(basename(f))
  fp <- st_read(f, query = sprintf('SELECT FIRE_YEAR_ FROM "%s" WHERE FIRE_YEAR_ >= 1982 AND FIRE_YEAR_ <= 2023', lay), quiet = TRUE)
  fp <- st_make_valid(st_transform(fp, crs(M))); bb <- st_as_sfc(st_bbox(c(xmin = xmin(M), ymin = ymin(M), xmax = xmax(M), ymax = ymax(M)), crs = st_crs(crs(M))))
  fp <- fp[lengths(st_intersects(fp, bb)) > 0, ]; fp$yr <- as.integer(fp$FIRE_YEAR_)
  for (y in 1982:2023) { s <- fp[fp$yr == y, ]
    r <- if (nrow(s)) !is.na(rasterize(vect(s), M, field = 1)) else init(M, 0)
    writeRaster(mask(r, M), bf(y), datatype = "INT1U", gdal = "COMPRESS=DEFLATE", overwrite = TRUE) }
  say("fire perimeters rasterized for 1982-2023 (%d perimeters)", nrow(fp)) }

# ---- dynamic predictors for 2012 (the out-of-sample map) and 2023 (the projection map) -----------------------------------------
for (y in c(2012, 2023)) if (!file.exists(ep_file(y, "devshare"))) { d <- rast(nlc(y)) %in% DEVALL
  writeRaster(distance(ifel(d, 1, NA)), ep_file(y, "distdev"), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE)
  writeRaster(focal(d, w = 33, fun = "mean", na.rm = TRUE), ep_file(y, "devshare"), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE) }

# ---- events and controls for one event type --------------------------------------------------------------------------------
TYPES <- list(urban = list(to = 22:24, label = "Urbanization (to Developed Low, Medium or High)"),
              openspace = list(to = 21L, label = "Developed Open Space"))
sample_type <- function(tp) {
  f <- file.path(CA, sprintf("sample_%s.rds", tp)); if (file.exists(f)) return(readRDS(f))
  to <- TYPES[[tp]]$to
  cl <- makeCluster(10); on.exit(stopCluster(cl))
  clusterExport(cl, c("CA", "nlc", "ep_file", "st_file", "hu_file", "bf", "epoch_of", "decade_of", "EPOCHS", "DEVALL", "NCTRL", "lc_group", "to"), envir = environment())
  invisible(clusterEvalQ(cl, { library(terra); library(data.table); terraOptions(progress = 0, memfrac = 0.04) }))
  s <- rbindlist(parLapply(cl, YRS[-1], function(y) {
    a <- values(rast(nlc(y - 1)), mat = FALSE); b <- values(rast(nlc(y)), mat = FALSE); g <- values(rast(st_file("gap")), mat = FALSE)
    burn <- Reduce(`|`, lapply((y - 3):y, function(k) { v <- values(rast(bf(k)), mat = FALSE); !is.na(v) & v > 0 }))
    elig <- which(!is.na(a) & !(a %in% c(DEVALL, 11, 12)) & !(g %in% 1:3) & !burn)
    ev <- elig[b[elig] %in% to]; ne <- elig[!(b[elig] %in% DEVALL)]   # controls: still undeveloped (a pixel that became another developed class is neither)
    set.seed(y); ctrl <- sample(ne, min(NCTRL, length(ne))); cells <- c(ev, ctrl); e <- epoch_of(y - 1)
    v <- function(f) values(rast(f), mat = FALSE)[cells]
    data.table(Year = y, Cell = cells, Event = rep(c(1L, 0L), c(length(ev), length(ctrl))), W = rep(c(1, length(ne) / length(ctrl)), c(length(ev), length(ctrl))),
               LC = lc_group(a[cells]), DistDev = v(ep_file(e, "distdev")), DevShare = v(ep_file(e, "devshare")), HU = v(hu_file(decade_of(y - 1))),
               DistRoad = v(st_file("distroad")), Slope = v(st_file("slope")), Elev = v(st_file("elev")), GAP = g[cells], County = v(st_file("county")),
               ExclBurn = sum(burn & !is.na(a)), ExclGap = sum(g %in% 1:3 & !is.na(a))) }))
  saveRDS(s, f); s }

prep <- function(s) { s <- s[!is.na(LC) & !is.na(County) & !is.na(Slope)]
  s[, `:=`(GAP = factor(GAP), LC = factor(LC), County = factor(County), lDistDev = log1p(DistDev), lDistRoad = log1p(DistRoad), lHU = log1p(HU))]; s }
form <- Event ~ s(lDistDev, k = 8) + s(DevShare, k = 6) + s(lHU, k = 6) + s(lDistRoad, k = 6) + s(Slope, k = 6) + s(Elev, k = 6) + LC + GAP + s(County, bs = "re")
nc <- min(32, detectCores() - 4)

# the suitability of every undeveloped, eligible pixel from year y's conditions (predictors as in the fit)
predict_map <- function(m, y, lev) {
  stk <- c(rast(nlc(y)), rast(ep_file(y, "distdev")), rast(ep_file(y, "devshare")), rast(hu_file(decade_of(y))), rast(st_file("distroad")),
           rast(st_file("slope")), rast(st_file("elev")), rast(st_file("gap")), rast(st_file("county")))
  names(stk) <- c("NLCD", "DistDev", "DevShare", "HU", "DistRoad", "Slope", "Elev", "GAP", "County")
  vals <- rep(NA_real_, ncell(M)); idx <- which(!is.na(values(M, mat = FALSE)))
  for (ch in split(idx, ceiling(seq_along(idx) / 2e6))) {
    d <- as.data.table(stk[ch]); d[, LC := lc_group(NLCD)]
    ok <- !is.na(d$LC) & !(d$NLCD %in% c(DEVALL, 11, 12)) & !(d$GAP %in% 1:3) & !is.na(d$County) & !is.na(d$Slope) & as.character(d$County) %in% lev$County
    p <- rep(0, length(ch))
    if (any(ok)) { d <- d[ok][, `:=`(GAP = factor(GAP, lev$GAP), LC = factor(LC, lev$LC), County = factor(County, lev$County), lDistDev = log1p(DistDev), lDistRoad = log1p(DistRoad), lHU = log1p(HU))]
      p[ok] <- predict(m, d, type = "response", block.size = 5e5) }
    vals[ch] <- p }
  setValues(rast(M), vals) }

res <- list()
for (tp in names(TYPES)) {
  s <- prep(sample_type(tp)); to <- TYPES[[tp]]$to
  say("%s: %d events (%.1f km2), %d controls; excluded each year: %.0f km2 GAP 1-3, %.0f km2 burned in the last 4 years (mean)", tp, s[Event == 1, .N], s[Event == 1, .N] * 9e-4,
      s[Event == 0, .N], mean(s$ExclGap) * 9e-4, mean(s$ExclBurn) * 9e-4)
  print(s[Event == 1, .(km2 = .N * 9e-4), by = LC][order(-km2)])
  lev <- list(GAP = levels(s$GAP), LC = levels(s$LC), County = levels(s$County))
  m1 <- bam(form, family = binomial, data = s[Year <= 2012], weights = W / mean(W), discrete = TRUE, nthreads = nc)
  # out of sample: the map from 2012 conditions, scored on 2013-2023 events of this type (same exclusions, eligible in 2012)
  p12 <- predict_map(m1, 2012, lev)
  a <- values(rast(nlc(2012)), mat = FALSE); b <- values(rast(nlc(2023)), mat = FALSE); g <- values(rast(st_file("gap")), mat = FALSE)
  burn <- Reduce(`|`, lapply(2009:2023, function(k) { v <- values(rast(bf(k)), mat = FALSE); !is.na(v) & v > 0 }))
  pv <- values(p12, mat = FALSE); el <- !is.na(a) & !(a %in% c(DEVALL, 11, 12)) & !(g %in% 1:3) & !burn & !is.na(pv)
  v <- data.table(p = pv[el], n = b[el] %in% to)[order(-p)][, `:=`(land = seq_len(.N) / .N, got = cumsum(n) / sum(n))]
  cap <- sapply(c(0.01, 0.05, 0.10, 0.25), function(q) v[which(land >= q)[1], got])
  aucv <- { r <- rank(v$p); n1 <- sum(v$n); n0 <- sum(!v$n); (sum(r[v$n]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
  say("%s, out of sample (fit 1986-2012, map from 2012, development 2013-2023 = %.1f km2): AUC %.3f; top 1/5/10/25%% of eligible land holds %s%% of it",
      tp, sum(v$n) * 9e-4, aucv, paste(round(100 * cap), collapse = "/"))
  m <- bam(form, family = binomial, data = s, weights = W / mean(W), discrete = TRUE, nthreads = nc); saveRDS(m, file.path(CA, sprintf("model_%s.rds", tp)))
  print(round(summary(m)$s.table, 3)); print(round(summary(m)$p.table[, c(1, 4)], 3))
  s30 <- file.path(OUT, sprintf("%s-suitability-p26-30m.tif", tp)); p23 <- predict_map(m, 2023, lev)
  writeRaster(p23, s30, datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE)
  a150 <- aggregate(p23, 5, mean, na.rm = TRUE); q <- global(a150, fun = function(x) quantile(x[x > 0], 0.995, na.rm = TRUE))[[1]]
  writeRaster(clamp(a150 / q, 0, 1), file.path(OUT, sprintf("%s-suitability-p26-150m.tif", tp)), datatype = "FLT4S", gdal = "COMPRESS=DEFLATE", overwrite = TRUE)
  res[[tp]] <- list(cap = v[unique(round(seq(1, .N, length.out = 400)))][, Type := TYPES[[tp]]$label], auc = aucv, top = cap, km2 = sum(v$n) * 9e-4)
}
saveRDS(res, file.path(OUT, "refit-metrics.rds"))
say("done in %.0f min", as.numeric(Sys.time() - t00, units = "mins"))
