# =============================================================================
# nccpi.R - gNATSGO crop productivity (NCCPI, nccpi3all) for a region from Microsoft Planetary Computer, on a given 30 m grid
# =============================================================================
# The national raster is not on disk: only the cloud-optimized tiles over the region are read (STAC collection gnatsgo-rasters; the
# tiles sit in storage account soils, container gnatsgo, whose anonymous SAS token covers them), cropped, reprojected onto the grid
# and mosaicked. nccpi3all = the highest of the corn/soybean, small grain and cotton indices (0-1). Used by stage 10 (Data Source
# NccpiFile blank) and tools/fetch-nccpi.R.
# =============================================================================
fetch_nccpi <- function(grid, out) {
  api <- "https://planetarycomputer.microsoft.com/api"
  bb <- ext(project(as.polygons(ext(grid), crs = crs(grid)), "EPSG:4326"))
  items <- jsonlite::fromJSON(sprintf("%s/stac/v1/search?collections=gnatsgo-rasters&bbox=%f,%f,%f,%f&limit=200", api, bb$xmin, bb$ymin, bb$xmax, bb$ymax), simplifyVector = FALSE)$features
  if (!length(items)) stop("no gNATSGO tiles over the region")
  tok <- jsonlite::fromJSON(sprintf("%s/sas/v1/token/soils/gnatsgo", api))$token
  hrefs <- vapply(items, function(it) it$assets$nccpi3all$href, "")
  box <- as.polygons(ext(grid), crs = crs(grid))
  parts <- lapply(hrefs, function(h) { r <- rast(sprintf("/vsicurl/%s?%s", h, tok)); rr <- tryCatch(crop(r, project(box, crs(r))), error = function(e) NULL)
    if (is.null(rr)) NULL else project(rr, grid, method = "bilinear") })
  parts <- parts[!vapply(parts, is.null, TRUE)]
  m <- if (length(parts) > 1) do.call(mosaic, c(unname(parts), fun = "mean")) else parts[[1]]
  names(m) <- "nccpi3all"
  writeRaster(m, out, overwrite = TRUE, gdal = c("COMPRESS=DEFLATE", "TILED=YES"), datatype = "FLT4S")
  invisible(length(parts))
}
