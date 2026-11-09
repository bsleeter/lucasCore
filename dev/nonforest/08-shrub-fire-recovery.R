# =============================================================================
# 08-shrub-fire-recovery.R - grass and shrub growth by years since fire from RAP and MTBS (to-do 39 step 8)
# =============================================================================
# A chronosequence in the 1,140 grass and shrub windows of 03-grass-shrub-sample.R (their RAP NPP crops, 1986-2023, kept by
# 04-rap-climate-sample.R). In each window, on RAP's own 30 m lon/lat grid:
#   class     RCMAP 1985 vegetation state (2 annual grass, 3 natural perennial grass, 5 native sage steppe, 6 invaded sage steppe,
#             7 sage, 8 non-sage, 9 chaparral), as stage 5 maps it
#   fires     MTBS burned-area perimeters 1984-2023 (fires of 1,000 acres and more in the West); a cell inside one perimeter of
#             1988-2022 and no other is "burned in year F"; a cell inside none is a control; cells inside two or more are left out
#   ratio     the burned cell's NPP in year F + t over the mean of its window's control cells of the same class that year (so the
#             year's weather cancels), divided by the same ratio averaged over the years before the fire (up to 5; so the cell's own
#             site cancels). 1 = growing as the unburned neighbours do. t = 0 is the fire year.
# Bands: shrub, herbaceous (annual + perennial) and total (herb + shrub; the tree band is left out as in the targets).
# Perimeters hold unburned islands and every severity, so the ratios are a mix of burned and unburned ground: a lower bound on the
# drop and an upper bound on the recovery time is not implied either way (islands recover nothing because they lost nothing).
# Output: dev/nonforest/08-shrub-fire-recovery.csv (window x class x fire year x t: cells, mean ratios) and
#         dev/nonforest/08-shrub-fire-recovery-summary.csv (class x t, weighted by cells, with fires and windows counted).
# Inputs, as environment variables: RAP_WINDOWS (the window crops), RCMAP_1985 (tif), MTBS (mtbs_perims_DD.shp).
# Usage: RAP_WINDOWS=<dir> RCMAP_1985=<tif> MTBS=<shp> Rscript dev/nonforest/08-shrub-fire-recovery.R [workers]
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table); library(parallel) })
a <- commandArgs(TRUE); WORKERS <- if (length(a) >= 1) as.integer(a[1]) else 12L
WIN <- Sys.getenv("RAP_WINDOWS"); RCMAP <- Sys.getenv("RCMAP_1985"); MTBS <- Sys.getenv("MTBS")
if (!dir.exists(WIN) || !file.exists(RCMAP) || !file.exists(MTBS)) stop("set RAP_WINDOWS, RCMAP_1985 and MTBS")
YEARS <- 1986:2023; FIRE_YEARS <- 1988:2022; PRE <- 5L; MIN_CONTROL <- 20L
CLASS <- c(`2` = "Grassland: Annual", `3` = "Grassland: Natural Perennial", `5` = "Shrubland: Native Sage Steppe", `6` = "Shrubland: Invaded Sage Steppe",
           `7` = "Shrubland: Sage", `8` = "Shrubland: Non-sage", `9` = "Shrubland: Chaparral")
OUT <- file.path(pkg, "dev", "nonforest")
files <- list.files(WIN, "[.]tif$", full.names = TRUE)
if (nzchar(Sys.getenv("WINDOW_MATCH"))) files <- grep(Sys.getenv("WINDOW_MATCH"), files, value = TRUE)   # a trial on some windows
cat(sprintf("%d windows, %d workers\n", length(files), WORKERS))

# perimeters: year and a bounding box each, for a quick per-window filter
fp <- st_read(MTBS, quiet = TRUE)
fp$yr <- as.integer(substr(as.character(fp$ig_date), 1, 4))
fp <- fp[!is.na(fp$yr) & fp$yr >= 1984 & fp$yr <= 2023 & fp$incid_type %in% c("Wildfire", "Wildland Fire Use", "Prescribed Fire", "Unknown"), c("event_id", "yr", "incid_type")]
fp <- st_make_valid(st_transform(fp, 4326))
bb <- t(vapply(st_geometry(fp), function(g) as.numeric(st_bbox(g)), numeric(4)))
saveRDS(list(fp = fp, bb = bb), PERIM <- tempfile(fileext = ".rds"))
cat(sprintf("MTBS: %d perimeters 1984-2023\n", nrow(fp)))

one <- function(f) {
  suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) })
  terra::terraOptions(progress = 0, memfrac = 0.2)
  tryCatch({
    raw <- rast(f); e <- as.vector(ext(raw))   # xmin xmax ymin ymax
    P <- readRDS(PERIM); hit <- which(P$bb[, 1] <= e[2] & P$bb[, 3] >= e[1] & P$bb[, 2] <= e[4] & P$bb[, 4] >= e[3])
    if (!length(hit)) return(NULL)
    p <- P$fp[hit, ]
    g <- rast(raw, nlyrs = 1)
    re <- project(ext(raw) + 0.002, "EPSG:4326", crs(rast(RCMAP)))
    if (is.null(intersect(re, ext(rast(RCMAP))))) return(NULL)   # outside RCMAP's mapped area (the East): no sage classes
    rc <- values(project(crop(rast(RCMAP), project(ext(raw) + 0.002, "EPSG:4326", crs(rast(RCMAP)))), g, method = "near"), mat = FALSE)
    cls <- CLASS[as.character(rc)]
    if (!any(!is.na(cls))) return(NULL)
    # per cell: how many perimeters cover it and the year of the (only) one
    v <- vect(p); nf <- values(rasterize(v, g, fun = "count", background = 0, touches = FALSE), mat = FALSE)
    fy <- values(rasterize(v, g, field = "yr", fun = "max", background = NA, touches = FALSE), mat = FALSE)
    x <- values(classify(raw, cbind(65535, NA)), mat = TRUE) / 1000
    col <- function(b) match(sprintf("%d_%s", YEARS, b), names(raw))
    sh <- x[, col("shrub"), drop = FALSE]; hb <- x[, col("annual"), drop = FALSE] + x[, col("perennial"), drop = FALSE]; tt <- sh + hb
    tree <- rowMeans(x[, col("tree"), drop = FALSE], na.rm = TRUE)
    keep <- !is.na(cls) & !(tree > rowMeans(tt, na.rm = TRUE))
    ctrl <- keep & nf == 0; burned <- keep & nf == 1 & fy %in% FIRE_YEARS
    if (!any(burned)) return(NULL)
    out <- list()
    for (k in unique(cls[burned])) {
      ck <- ctrl & cls == k; if (sum(ck) < MIN_CONTROL) next
      cm <- list(shrub = colMeans(sh[ck, , drop = FALSE], na.rm = TRUE), herb = colMeans(hb[ck, , drop = FALSE], na.rm = TRUE), total = colMeans(tt[ck, , drop = FALSE], na.rm = TRUE))
      for (F in unique(fy[burned & cls == k])) {
        bk <- which(burned & cls == k & fy == F); i0 <- F - min(YEARS) + 1; pre <- max(1, i0 - PRE):(i0 - 1)
        r <- lapply(list(shrub = sh, herb = hb, total = tt), function(m) m[bk, , drop = FALSE])
        rel <- lapply(names(r), function(b) { q <- sweep(r[[b]], 2, cm[[b]], "/"); q[!is.finite(q)] <- NA
          base <- rowMeans(q[, pre, drop = FALSE], na.rm = TRUE); sweep(q[, i0:length(YEARS), drop = FALSE], 1, base, "/") })
        names(rel) <- names(r)
        # base NPP before the fire (the controls' mean of those years), so a recovery in Mg C/ha/yr can be read off too
        out[[length(out) + 1]] <- data.table(StateClassId = k, FireYear = F, t = 0:(length(YEARS) - i0), cells = length(bk),
          shrub = colMeans(rel$shrub, na.rm = TRUE), herb = colMeans(rel$herb, na.rm = TRUE), total = colMeans(rel$total, na.rm = TRUE),
          shrubMedian = apply(rel$shrub, 2, median, na.rm = TRUE), totalMedian = apply(rel$total, 2, median, na.rm = TRUE),
          preShrub = mean(cm$shrub[pre]), preHerb = mean(cm$herb[pre]), controls = sum(ck)) }
    }
    if (!length(out)) return(NULL)
    rbindlist(out)[, window := sub("[.]tif$", "", basename(f))]
  }, error = function(e) data.table(window = sub("[.]tif$", "", basename(f)), error = conditionMessage(e))) }

t0 <- Sys.time()
cl <- makeCluster(WORKERS); clusterExport(cl, c("PERIM", "RCMAP", "YEARS", "FIRE_YEARS", "PRE", "MIN_CONTROL", "CLASS"))
res <- parLapplyLB(cl, files, one); stopCluster(cl)
d <- rbindlist(res, fill = TRUE); if (!"error" %in% names(d)) d[, error := NA_character_]
cat(sprintf("%.1f min; %d windows with burned cells; %d failed\n", as.numeric(Sys.time() - t0, units = "mins"), d[is.na(error), uniqueN(window)], d[!is.na(error), uniqueN(window)]))
if (any(!is.na(d$error))) print(head(unique(d[!is.na(error), .(window, error = substr(error, 1, 150))]), 10))
d <- d[is.na(error)][, error := NULL]
fwrite(d, file.path(OUT, "08-shrub-fire-recovery.csv"))
w <- function(x, n) { ok <- is.finite(x); if (!any(ok)) NA_real_ else sum(x[ok] * n[ok]) / sum(n[ok]) }
s <- d[, .(cells = sum(cells), fires = uniqueN(paste(window, FireYear)), windows = uniqueN(window), shrub = w(shrub, cells), herb = w(herb, cells), total = w(total, cells),
           shrubMedian = w(shrubMedian, cells), totalMedian = w(totalMedian, cells), preShrub = w(preShrub, cells), preHerb = w(preHerb, cells)), by = .(StateClassId, t)][order(StateClassId, t)]
fwrite(s, file.path(OUT, "08-shrub-fire-recovery-summary.csv"))
print(s[t %in% c(0, 1, 2, 3, 5, 10, 15, 20, 25, 30), .(StateClassId, t, cells, fires, windows, shrub = round(shrub, 2), herb = round(herb, 2), total = round(total, 2))])
