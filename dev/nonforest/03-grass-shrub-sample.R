# =============================================================================
# 03-grass-shrub-sample.R - CONUS sample of grassland and shrubland growth and soil carbon by ecodivision and class (to-do 39)
# =============================================================================
# A cluster sample: in each of the 19 ecodivisions, WINDOWS windows of 3 x 3 km (100 x 100 cells at 30 m, EPSG:5070) centred on random
# NLCD grassland (71) or shrubland (52) cells. In each window every 30 m cell that NLCD maps as 52 or 71 gets its model class as stage 5
# gives it (RCMAP 1985 vegetation state class 2-9 where mapped, else 71 -> Grassland: Natural Perennial, 52 -> Shrubland: Non-sage;
# defaults/landcover/land-cover-crosswalks.csv), and is read for:
#   NPP    RAP rangeland NPP v3 (Robinson et al. 2019, doi 10.3390/rs11121427; CC0), bands 1-3 (annual forb and grass, perennial forb
#          and grass, shrub; the tree band is kept apart), the mean of YEARS; raw kg C/m2 x 1e4, so Mg C/ha/yr = raw / 1000
#   soil   gNATSGO soc0_30 and soc0_999 (July 2020, Microsoft Planetary Computer gnatsgo-rasters, 10 m, g C/m2; read at 30 m as the
#          mean of the 10 m cells); Mg C/ha = g C/m2 / 100
# Output: one row per window x class (cells, mean NPP by band, soil), dev/nonforest/03-grass-shrub-sample.csv. Summaries and the
# fit are tools/make_grass_shrub.R. RAP is meant for rangelands and not for agricultural land: Irrigated Perennial grassland is flagged.
# Inputs, as environment variables: NLCD_2001 (the national Annual NLCD 2001 tif, e.g. a national home's land-cover/nlcd-annual) and
# RCMAP_1985 (the RCMAP 1985 vegetation state tif, from 1985_vegetation_state.zip).
# Usage: NLCD_2001=<tif> RCMAP_1985=<tif> Rscript dev/nonforest/03-grass-shrub-sample.R [windows per ecodivision] [workers]
# Run 2026-11-06: 60 windows per ecodivision, 12 workers, 9.6 min; 1,140 windows, none failed.
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table); library(parallel) })
a <- commandArgs(TRUE); WINDOWS <- if (length(a) >= 1) as.integer(a[1]) else 60L; WORKERS <- if (length(a) >= 2) as.integer(a[2]) else 12L
NLCD <- Sys.getenv("NLCD_2001"); RCMAP <- Sys.getenv("RCMAP_1985")
if (!file.exists(NLCD) || !file.exists(RCMAP)) stop("set NLCD_2001 and RCMAP_1985 to the national NLCD 2001 and RCMAP 1985 vegetation state tifs")
RAP <- "/vsicurl/https://rangeland.ntsg.umt.edu/data/rap/rap-vegetation-npp/v3/vegetation-npp-v3-%d.tif"
YEARS <- 2014:2023; HALF <- 1500; OUT <- file.path(pkg, "dev", "nonforest", "03-grass-shrub-sample.csv")
set.seed(20261106)

eco <- st_read(file.path(pkg, "defaults/strata/ecodivisions/EcoDivisions_Dissolve.shp"), quiet = TRUE)
base <- unique(st_drop_geometry(eco)[!startsWith(eco$ecodiv, "M"), c("ecodiv", "StrtmNm")])
eco$name <- ifelse(startsWith(eco$ecodiv, "M"), paste(base$StrtmNm[match(sub("^M", "", eco$ecodiv), base$ecodiv)], "Mountains"), eco$StrtmNm)
eco <- st_transform(aggregate(eco["geometry"], by = list(name = eco$name), FUN = function(x) x[1]), 5070)
xw <- fread(file.path(pkg, "defaults/landcover/land-cover-crosswalks.csv"))[Source == "RCMAP" & StateClassId != "" & !is.na(StateClassId), .(Code, StateClassId)]
cat(sprintf("%d ecodivisions, %d windows each, %d RAP years, %d workers\n", nrow(eco), WINDOWS, length(YEARS), WORKERS))

# ---- window centres: random NLCD 52 / 71 cells in each ecodivision ------------------------------------------------------------
nl <- rast(NLCD)
centres <- rbindlist(lapply(seq_len(nrow(eco)), function(i) {
  got <- data.table(); tries <- 0
  while (nrow(got) < WINDOWS && tries < 40) { tries <- tries + 1
    p <- st_coordinates(st_sample(eco[i, ], 4000)); v <- terra::extract(nl, project(vect(p, crs = "EPSG:5070"), crs(nl)))[, 2]
    got <- rbind(got, data.table(x = p[, 1], y = p[, 2])[v %in% c(52, 71)]) }
  if (nrow(got) < WINDOWS) cat(sprintf("  %s: only %d grass/shrub centres\n", eco$name[i], nrow(got)))
  got[seq_len(min(WINDOWS, nrow(got)))][, `:=`(StratumId = eco$name[i], window = seq_len(.N))] }))
cat(sprintf("%d window centres\n", nrow(centres)))

# ---- one window: classes, RAP NPP, gNATSGO soil ---------------------------------------------------------------------------------
# a remote call with retries (Planetary Computer refuses some requests when many come at once)
retry <- function(f, n = 6) { for (i in seq_len(n)) { r <- tryCatch(f(), error = function(e) e); if (!inherits(r, "error")) return(r); Sys.sleep(2^i + runif(1, 0, 2)) }; stop(conditionMessage(r)) }
# one read token per worker, renewed after 20 minutes
pc_token <- function() { if (!exists(".tok", envir = globalenv()) || difftime(Sys.time(), get(".tok_t", envir = globalenv()), units = "mins") > 20) {
    assign(".tok", retry(function() jsonlite::fromJSON("https://planetarycomputer.microsoft.com/api/sas/v1/token/soils/gnatsgo")$token), envir = globalenv())
    assign(".tok_t", Sys.time(), envir = globalenv()) }
  get(".tok", envir = globalenv()) }
one <- function(k) {
  suppressPackageStartupMessages({ library(terra); library(data.table); library(jsonlite) })
  terra::terraOptions(progress = 0, memfrac = 0.2)
  ce <- centres[k]; w <- ext(ce$x - HALF, ce$x + HALF, ce$y - HALF, ce$y + HALF); g <- rast(w, res = 30, crs = "EPSG:5070")
  tryCatch({
    n <- values(project(crop(rast(NLCD), project(ext(w) + 90, "EPSG:5070", crs(rast(NLCD)))), g, method = "near"), mat = FALSE)
    rcr <- rast(RCMAP)   # western US only: outside it, the NLCD rule
    rc <- if (is.null(intersect(ext(w) + 90, ext(rcr)))) rep(NA_integer_, ncell(g)) else values(project(crop(rcr, ext(w) + 90), g, method = "near"), mat = FALSE)
    cls <- ifelse(n %in% c(52, 71), xw$StateClassId[match(rc, xw$Code)], NA)
    cls <- ifelse(n %in% c(52, 71) & is.na(cls), ifelse(n == 71, "Grassland: Natural Perennial", "Shrubland: Non-sage"), cls)
    if (!any(!is.na(cls))) return(NULL)
    ll <- ext(project(as.polygons(w, crs = "EPSG:5070"), "EPSG:4326")) + 0.002
    npp <- Reduce(`+`, lapply(YEARS, function(y) { r <- retry(function() crop(rast(sprintf(RAP, y)), ll)); r <- classify(r, cbind(65535, NA)); project(r, g, method = "near") })) / length(YEARS)
    nv <- values(npp) / 1000   # Mg C/ha/yr
    b <- as.vector(ll); f <- retry(function() fromJSON(sprintf("https://planetarycomputer.microsoft.com/api/stac/v1/search?collections=gnatsgo-rasters&bbox=%f,%f,%f,%f&limit=20", b[1], b[3], b[2], b[4]), simplifyVector = FALSE)$features)
    tok <- pc_token()
    soil <- function(asset) { parts <- Filter(Negate(is.null), lapply(f, function(ft) { h <- ft$assets[[asset]]$href; if (is.null(h)) return(NULL)
      r <- rast(sprintf("/vsicurl/%s?%s", h, tok)); e <- intersect(ext(w) + 30, ext(r)); if (is.null(e)) NULL else crop(r, e) }))
      if (!length(parts)) return(rep(NA_real_, ncell(g)))
      m <- if (length(parts) > 1) do.call(merge, parts) else parts[[1]]
      m <- classify(m, cbind(-Inf, 0, NA), include.lowest = TRUE)   # 0 and the undeclared -1920 no-data are missing (as stage 5)
      values(resample(m, g, method = "average"), mat = FALSE) / 100 }
    s30 <- soil("soc0_30"); s999 <- soil("soc0_999")
    d <- data.table(cls, a1 = nv[, 1], a2 = nv[, 2], a3 = nv[, 3], a4 = nv[, 4], s30, s999)[!is.na(cls)]
    # NLCD 2001 grass and shrub cells that RAP (2014-2023) sees as mostly trees (regrown clearcuts, succession) are left out
    d[, treed := !is.na(a4) & a4 > a1 + a2 + a3]
    td <- d[, .(treed = sum(treed)), by = .(StateClassId = cls)]; d <- d[treed == FALSE]
    if (!nrow(d)) return(td[, `:=`(cells = 0L, StratumId = ce$StratumId, window = ce$window, x = ce$x, y = ce$y)])
    merge(td, d[, .(cells = .N, nppCells = sum(!is.na(a1)), NppAnnual = mean(a1, na.rm = TRUE), NppPerennial = mean(a2, na.rm = TRUE), NppShrub = mean(a3, na.rm = TRUE),
          NppTree = mean(a4, na.rm = TRUE), soilCells = sum(!is.na(s30)), Soil0to30 = mean(s30, na.rm = TRUE), Soil0to999 = mean(s999, na.rm = TRUE)),
      by = .(StateClassId = cls)], by = "StateClassId", all.x = TRUE)[is.na(cells), cells := 0L][, `:=`(StratumId = ce$StratumId, window = ce$window, x = ce$x, y = ce$y)]
  }, error = function(e) data.table(StratumId = ce$StratumId, window = ce$window, x = ce$x, y = ce$y, error = conditionMessage(e))) }

t0 <- Sys.time()
cl <- makeCluster(WORKERS); clusterExport(cl, c("centres", "HALF", "NLCD", "RCMAP", "RAP", "YEARS", "xw", "retry", "pc_token"))
res <- parLapplyLB(cl, seq_len(nrow(centres)), one); stopCluster(cl)
out <- rbindlist(res, fill = TRUE)
if (!"error" %in% names(out)) out[, error := NA_character_]
cat(sprintf("%.1f min; %d window x class rows; %d windows failed\n", as.numeric(Sys.time() - t0, units = "mins"), nrow(out[is.na(error)]), out[!is.na(error), uniqueN(paste(StratumId, window))]))
if (any(!is.na(out$error))) print(head(out[!is.na(error), .(StratumId, window, error = substr(error, 1, 150))], 10))
fwrite(out, OUT)
cat("wrote", OUT, "\n")
