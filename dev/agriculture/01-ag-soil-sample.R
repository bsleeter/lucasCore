# =============================================================================
# 01-ag-soil-sample.R - CONUS sample of cropland and pasture soil carbon by ecodivision (to-do 39 step 6)
# =============================================================================
# As dev/nonforest/03-grass-shrub-sample.R, for agriculture: in each of the 19 ecodivisions, WINDOWS windows of 3 x 3 km (100 x 100
# cells at 30 m, EPSG:5070) centred on random NLCD cultivated crops (82) or pasture/hay (81) cells of NLCD_YEAR. Every 30 m cell of the
# window that NLCD maps as 81 or 82 gets its class (82 -> Agriculture: Cropland, 81 -> Agriculture: Pasture, as stage 5 keeps them)
# and is read for gNATSGO soc0_30 and soc0_999 (July 2020, Microsoft Planetary Computer gnatsgo-rasters, 10 m, g C/m2, read at 30 m
# as the mean of the 10 m cells; Mg C/ha = g C/m2 / 100). NLCD 2021 is the year closest to gNATSGO's soil surveys that the national
# Annual NLCD holds here. Growth comes from NASS county yields instead (02-nass-county-npp.R).
# Output: one row per window x class (cells, soil), dev/agriculture/01-ag-soil-sample.csv. Summaries: tools/make_agriculture.R.
# Input, as an environment variable: NLCD (the national Annual NLCD tif of NLCD_YEAR).
# Usage: NLCD=<tif> Rscript dev/agriculture/01-ag-soil-sample.R [windows per ecodivision] [workers]
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table); library(parallel) })
a <- commandArgs(TRUE); WINDOWS <- if (length(a) >= 1) as.integer(a[1]) else 60L; WORKERS <- if (length(a) >= 2) as.integer(a[2]) else 12L
NLCD <- Sys.getenv("NLCD"); if (!file.exists(NLCD)) stop("set NLCD to the national Annual NLCD tif (2021)")
HALF <- 1500; OUT <- file.path(pkg, "dev", "agriculture", "01-ag-soil-sample.csv"); AG <- c(`81` = "Agriculture: Pasture", `82` = "Agriculture: Cropland")
set.seed(20261107)

eco <- st_read(file.path(pkg, "defaults/strata/ecodivisions/EcoDivisions_Dissolve.shp"), quiet = TRUE)
base <- unique(st_drop_geometry(eco)[!startsWith(eco$ecodiv, "M"), c("ecodiv", "StrtmNm")])
eco$name <- ifelse(startsWith(eco$ecodiv, "M"), paste(base$StrtmNm[match(sub("^M", "", eco$ecodiv), base$ecodiv)], "Mountains"), eco$StrtmNm)
eco <- st_transform(aggregate(eco["geometry"], by = list(name = eco$name), FUN = function(x) x[1]), 5070)
cat(sprintf("%d ecodivisions, %d windows each, %d workers\n", nrow(eco), WINDOWS, WORKERS))

# ---- window centres: random NLCD 81 / 82 cells in each ecodivision (half on each class where both exist) ------------------------
nl <- rast(NLCD)
centres <- rbindlist(lapply(seq_len(nrow(eco)), function(i) {
  got <- data.table(x = numeric(), y = numeric(), cls = integer()); tries <- 0
  while ((got[cls == 82, .N] < WINDOWS / 2 || got[cls == 81, .N] < WINDOWS / 2) && tries < 40) { tries <- tries + 1
    p <- st_coordinates(st_sample(eco[i, ], 4000)); v <- terra::extract(nl, project(vect(p, crs = "EPSG:5070"), crs(nl)))[, 2]
    got <- rbind(got, data.table(x = p[, 1], y = p[, 2], cls = v)[cls %in% c(81, 82)]) }
  n81 <- min(got[cls == 81, .N], WINDOWS %/% 2); n82 <- min(got[cls == 82, .N], WINDOWS - n81)
  if (n81 + n82 < WINDOWS) n81 <- min(got[cls == 81, .N], WINDOWS - n82)
  pick <- rbind(got[cls == 82][seq_len(n82)], got[cls == 81][seq_len(n81)])
  if (nrow(pick) < WINDOWS) cat(sprintf("  %s: %d crop and %d pasture centres\n", eco$name[i], n82, n81))
  pick[, `:=`(StratumId = eco$name[i], window = seq_len(.N))] }))
cat(sprintf("%d window centres\n", nrow(centres)))

retry <- function(f, n = 6) { for (i in seq_len(n)) { r <- tryCatch(f(), error = function(e) e); if (!inherits(r, "error")) return(r); Sys.sleep(2^i + runif(1, 0, 2)) }; stop(conditionMessage(r)) }
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
    cls <- unname(AG[as.character(n)])
    if (!any(!is.na(cls))) return(NULL)
    ll <- ext(project(as.polygons(w, crs = "EPSG:5070"), "EPSG:4326")) + 0.002
    b <- as.vector(ll); f <- retry(function() fromJSON(sprintf("https://planetarycomputer.microsoft.com/api/stac/v1/search?collections=gnatsgo-rasters&bbox=%f,%f,%f,%f&limit=20", b[1], b[3], b[2], b[4]), simplifyVector = FALSE)$features)
    tok <- pc_token()
    soil <- function(asset) { parts <- Filter(Negate(is.null), lapply(f, function(ft) { h <- ft$assets[[asset]]$href; if (is.null(h)) return(NULL)
      r <- rast(sprintf("/vsicurl/%s?%s", h, tok)); e <- intersect(ext(w) + 30, ext(r)); if (is.null(e)) NULL else crop(r, e) }))
      if (!length(parts)) return(rep(NA_real_, ncell(g)))
      m <- if (length(parts) > 1) do.call(merge, parts) else parts[[1]]
      m <- classify(m, cbind(-Inf, 0, NA), include.lowest = TRUE)   # 0 and the undeclared -1920 no-data are missing (as stage 5)
      values(resample(m, g, method = "average"), mat = FALSE) / 100 }
    d <- data.table(cls, s30 = soil("soc0_30"), s999 = soil("soc0_999"))[!is.na(cls)]
    d[, .(cells = .N, soilCells = sum(!is.na(s30)), Soil0to30 = mean(s30, na.rm = TRUE), Soil0to999 = mean(s999, na.rm = TRUE),
          Soil0to999Median = as.numeric(median(s999, na.rm = TRUE))), by = .(StateClassId = cls)][, `:=`(StratumId = ce$StratumId, window = ce$window, x = ce$x, y = ce$y)]
  }, error = function(e) data.table(StratumId = ce$StratumId, window = ce$window, x = ce$x, y = ce$y, error = conditionMessage(e))) }

t0 <- Sys.time()
cl <- makeCluster(WORKERS); clusterExport(cl, c("centres", "HALF", "NLCD", "AG", "retry", "pc_token"))
res <- parLapplyLB(cl, seq_len(nrow(centres)), one); stopCluster(cl)
out <- rbindlist(res, fill = TRUE)
if (!"error" %in% names(out)) out[, error := NA_character_]
cat(sprintf("%.1f min; %d window x class rows; %d windows failed\n", as.numeric(Sys.time() - t0, units = "mins"), nrow(out[is.na(error)]), out[!is.na(error), uniqueN(paste(StratumId, window))]))
if (any(!is.na(out$error))) print(head(out[!is.na(error), .(StratumId, window, error = substr(error, 1, 150))], 10))
fwrite(out, OUT)
cat("wrote", OUT, "\n")
