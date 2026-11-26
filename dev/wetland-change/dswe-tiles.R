# Which Landsat ARD tiles (CONUS grid: 150 km tiles from x -2565585, y 3314805) each test box touches,
# with the share of the box in each tile.
suppressMessages(library(terra))
regions <- list("Louisiana delta plain" = c(-91.3, -89.7, 29.0, 29.9), "Louisiana chenier plain" = c(-93.9, -92.5, 29.5, 30.2),
  "Chesapeake eastern shore" = c(-76.5, -75.7, 38.0, 38.6), "San Francisco Bay and Delta" = c(-122.6, -121.5, 37.4, 38.3),
  "Western Lake Erie" = c(-83.6, -82.6, 41.3, 41.8),
  "Sierra Nevada reservoirs (New Melones, Don Pedro)" = c(-120.7, -120.15, 37.6, 38.05),
  "Great Salt Lake" = c(-113.1, -111.9, 40.6, 41.7))
for (rn in names(regions)) { b <- regions[[rn]]
  e <- ext(project(vect(ext(b[1], b[2], b[3], b[4]), crs = "EPSG:4326"), "EPSG:5070"))
  h <- floor((c(xmin(e), xmax(e)) + 2565585) / 150000); v <- floor((3314805 - c(ymax(e), ymin(e))) / 150000)
  g <- expand.grid(h = h[1]:h[2], v = v[1]:v[2])
  sh <- mapply(function(hh, vv) { t <- ext(-2565585 + hh * 150000, -2565585 + (hh + 1) * 150000, 3314805 - (vv + 1) * 150000, 3314805 - vv * 150000)
    i <- intersect(e, t); if (is.null(i)) 0 else (xmax(i) - xmin(i)) * (ymax(i) - ymin(i)) / ((xmax(e) - xmin(e)) * (ymax(e) - ymin(e))) }, g$h, g$v)
  cat(rn, ":", paste(sprintf("H%02dV%02d %.0f%%", g$h, g$v, 100 * sh), collapse = ", "), "\n") }
