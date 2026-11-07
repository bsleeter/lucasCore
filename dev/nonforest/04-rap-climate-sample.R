# =============================================================================
# 04-rap-climate-sample.R - yearly RAP NPP and PRISM climate at the grass and shrub sample windows (to-do 39 step 7)
# =============================================================================
# The sample for a grass and shrub climate response fitted to RAP, in place of Miami NPP (the forest counterpart is the tree-ring
# response, tools/make_tree_ring_coefficients.R). The windows are those of 03-grass-shrub-sample.R (1,140 windows of 3 x 3 km, 60 per
# ecodivision, centred on NLCD 2001 grass or shrub; their centres are in 03-grass-shrub-sample.csv). In each window:
#   classes  every 30 m NLCD 2001 grass (71) or shrub (52) cell gets its model class as stage 5 does (RCMAP 1985 vegetation state
#            where mapped, else 71 -> Grassland: Natural Perennial, 52 -> Shrubland: Non-sage); cells RAP sees as mostly trees
#            (2014-2023 mean tree NPP > herb + shrub) are left out, as in the targets
#   NPP      RAP vegetation NPP v3 (Robinson et al. 2019; CC0) every year of YEARS, bands annual herbaceous, perennial herbaceous,
#            shrub, tree (Mg C/ha/yr = raw / 1000), the mean over the window's cells of each class
#   climate  PRISM annual precipitation and mean temperature (current release, annual-us25m) at the window centre for YEARS and the
#            year before the first (the lag), and the 1991-2020 normals
# The raw RAP crop of every window (all bands, all years, RAP's own lon/lat grid) is kept in RAP_WINDOWS, one GeoTIFF per window, so a
# refit or another class rule never reads RAP again (user, 2026-11-07: keep what is downloaded; the full 30 m CONUS archive, about 3 TB,
# is not needed). A window already there is read from disk.
# Output: one row per window x class x year, dev/nonforest/04-rap-climate-sample.csv. The fit is 05-rap-climate-fit.R.
# Inputs, as environment variables: NLCD_2001 (national Annual NLCD 2001 tif), RCMAP_1985 (RCMAP 1985 vegetation state tif), PRISM
# (a home's climate/prism folder, with annual-us25m/{ppt,tmean} and normals), RAP_WINDOWS (the folder for the window crops, e.g.
# <home>/derived/rap-npp-windows).
# Usage: NLCD_2001=<tif> RCMAP_1985=<tif> PRISM=<dir> RAP_WINDOWS=<dir> Rscript dev/nonforest/04-rap-climate-sample.R [workers]
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages({ library(terra); library(data.table); library(parallel) })
a <- commandArgs(TRUE); WORKERS <- if (length(a) >= 1) as.integer(a[1]) else 12L
NLCD <- Sys.getenv("NLCD_2001"); RCMAP <- Sys.getenv("RCMAP_1985"); PRISM <- Sys.getenv("PRISM"); WIN <- Sys.getenv("RAP_WINDOWS")
if (!file.exists(NLCD) || !file.exists(RCMAP) || !dir.exists(PRISM) || !nzchar(WIN)) stop("set NLCD_2001, RCMAP_1985, PRISM and RAP_WINDOWS")
dir.create(WIN, recursive = TRUE, showWarnings = FALSE)
RAP <- "/vsicurl/https://rangeland.ntsg.umt.edu/data/rap/rap-vegetation-npp/v3/vegetation-npp-v3-%d.tif"
YEARS <- 1986:2023; TARGET_YEARS <- 2014:2023; HALF <- 1500; OUT <- file.path(pkg, "dev", "nonforest", "04-rap-climate-sample.csv")
xw <- fread(file.path(pkg, "defaults/landcover/land-cover-crosswalks.csv"))[Source == "RCMAP" & StateClassId != "" & !is.na(StateClassId), .(Code, StateClassId)]
centres <- unique(fread(file.path(pkg, "dev/nonforest/03-grass-shrub-sample.csv"))[is.na(error) | error == "", .(StratumId, window, x, y)])
NW <- Sys.getenv("N_WINDOWS"); if (nzchar(NW)) { centres <- centres[seq_len(as.integer(NW))]; OUT <- sub("[.]csv$", "-test.csv", OUT) }   # a trial on the first N
cat(sprintf("%d windows, %d years, %d workers\n", nrow(centres), length(YEARS), WORKERS))

# ---- climate at the window centres (PRISM in the home: no download) ---------------------------------------------------------
pf <- function(v, y) { f <- Sys.glob(file.path(PRISM, "annual-us25m", v, sprintf("prism_%s_us_25m_%d*.tif", v, y))); if (length(f) != 1) stop(sprintf("PRISM %s %d: %d files", v, y, length(f))); f }
pts <- vect(as.matrix(centres[, .(x, y)]), crs = "EPSG:5070")
ex <- function(f) { r <- rast(f); terra::extract(r, project(pts, crs(r)), method = "bilinear")[, 2] }
yy <- c(min(YEARS) - 1, YEARS)
clim <- rbindlist(lapply(yy, function(y) data.table(centres[, .(StratumId, window)], Year = y, Ppt = ex(pf("ppt", y)), Tmean = ex(pf("tmean", y)))))
nrm <- data.table(centres[, .(StratumId, window)], PptNormal = ex(Sys.glob(file.path(PRISM, "normals", "prism_ppt_us_25m_2020_avg_30y.tif"))),
                  TmeanNormal = ex(Sys.glob(file.path(PRISM, "normals", "prism_tmean_us_25m_2020_avg_30y.tif"))))
cat(sprintf("PRISM: %d window-years; %d windows without a value\n", nrow(clim), clim[is.na(Ppt), uniqueN(paste(StratumId, window))]))

# ---- one window -------------------------------------------------------------------------------------------------------------
retry <- function(f, n = 6) { for (i in seq_len(n)) { r <- tryCatch(f(), error = function(e) e); if (!inherits(r, "error")) return(r); Sys.sleep(2^i + runif(1, 0, 2)) }; stop(conditionMessage(r)) }
one <- function(k) {
  suppressPackageStartupMessages({ library(terra); library(data.table) })
  terra::terraOptions(progress = 0, memfrac = 0.2)
  ce <- centres[k]; w <- ext(ce$x - HALF, ce$x + HALF, ce$y - HALF, ce$y + HALF); g <- rast(w, res = 30, crs = "EPSG:5070")
  tryCatch({
    n <- values(project(crop(rast(NLCD), project(ext(w) + 90, "EPSG:5070", crs(rast(NLCD)))), g, method = "near"), mat = FALSE)
    rcr <- rast(RCMAP)
    rc <- if (is.null(intersect(ext(w) + 90, ext(rcr)))) rep(NA_integer_, ncell(g)) else values(project(crop(rcr, ext(w) + 90), g, method = "near"), mat = FALSE)
    cls <- ifelse(n %in% c(52, 71), xw$StateClassId[match(rc, xw$Code)], NA)
    cls <- ifelse(n %in% c(52, 71) & is.na(cls), ifelse(n == 71, "Grassland: Natural Perennial", "Shrubland: Non-sage"), cls)
    if (!any(!is.na(cls))) return(NULL)
    # the raw crop of every year, kept: read from disk when there
    wf <- file.path(WIN, sprintf("%s_%03d.tif", gsub("[^A-Za-z0-9]+", "-", ce$StratumId), ce$window))
    ll <- ext(project(as.polygons(w, crs = "EPSG:5070"), "EPSG:4326")) + 0.002
    if (file.exists(wf)) raw <- rast(wf) else {
      raw <- rast(lapply(YEARS, function(y) { r <- retry(function() crop(rast(sprintf(RAP, y)), ll, snap = "out")); names(r) <- sprintf("%d_%s", y, c("annual", "perennial", "shrub", "tree")); r }))
      tmp <- paste0(wf, ".tmp.tif"); writeRaster(raw, tmp, overwrite = TRUE, datatype = "INT2U", gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2"))
      file.rename(tmp, wf); raw <- rast(wf) }
    v <- values(project(classify(raw, cbind(65535, NA)), g, method = "near"), mat = TRUE) / 1000   # cells x (years x 4), Mg C/ha/yr
    col <- function(y, b) match(sprintf("%d_%s", y, b), names(raw))
    tm <- function(b) rowMeans(v[, col(TARGET_YEARS, b), drop = FALSE], na.rm = TRUE)
    keep <- !is.na(cls) & !(tm("tree") > tm("annual") + tm("perennial") + tm("shrub"))
    if (!any(keep)) return(NULL)
    rbindlist(lapply(YEARS, function(y) { d <- data.table(cls = cls[keep], a1 = v[keep, col(y, "annual")], a2 = v[keep, col(y, "perennial")], a3 = v[keep, col(y, "shrub")], a4 = v[keep, col(y, "tree")])
      d[, .(cells = .N, nppCells = sum(!is.na(a1)), NppAnnual = mean(a1, na.rm = TRUE), NppPerennial = mean(a2, na.rm = TRUE), NppShrub = mean(a3, na.rm = TRUE), NppTree = mean(a4, na.rm = TRUE)),
        by = .(StateClassId = cls)][, Year := y] }))[, `:=`(StratumId = ce$StratumId, window = ce$window, x = ce$x, y = ce$y)]
  }, error = function(e) data.table(StratumId = ce$StratumId, window = ce$window, x = ce$x, y = ce$y, error = conditionMessage(e))) }

t0 <- Sys.time()
cl <- makeCluster(WORKERS); clusterExport(cl, c("centres", "HALF", "NLCD", "RCMAP", "RAP", "YEARS", "TARGET_YEARS", "WIN", "xw", "retry"))
res <- parLapplyLB(cl, seq_len(nrow(centres)), one); stopCluster(cl)
out <- rbindlist(res, fill = TRUE); if (!"error" %in% names(out)) out[, error := NA_character_]
cat(sprintf("%.1f min; %d window x class x year rows; %d windows failed\n", as.numeric(Sys.time() - t0, units = "mins"), nrow(out[is.na(error)]), out[!is.na(error), uniqueN(paste(StratumId, window))]))
if (any(!is.na(out$error))) print(head(out[!is.na(error), .(StratumId, window, error = substr(error, 1, 150))], 10))
out <- merge(out, clim, by = c("StratumId", "window", "Year"), all.x = TRUE)
lag <- clim[, .(StratumId, window, Year = Year + 1L, PptLag = Ppt)]; out <- merge(out, lag, by = c("StratumId", "window", "Year"), all.x = TRUE)
out <- merge(out, nrm, by = c("StratumId", "window"), all.x = TRUE)
fwrite(out, OUT); cat("wrote", OUT, "\n")
