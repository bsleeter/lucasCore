# =============================================================================
# adjacency-curve.R - a transition's chance by the share of a class around a cell, read from the annual maps (stage 10, Method Adjacency)
# =============================================================================
# For Ag Change (user decision 2026-11-05: cropland becomes pasture near pasture, and the reverse; Puget's maps: 0.4 to 17 changes per
# 1,000 cropland cells a year as the pasture share within 450 m rises, 0.1 to 38 the other way). Each year, every model cell in the source
# classes is counted by the share of the attribute's classes within the radius, and as an event when it is in the event classes the next
# year. The curve is the event rate in share bins of 0.1, made non-decreasing and scaled to 1 at its highest: ST-Sim's adjacency multiplier.
# =============================================================================

# counts for one year: a and b the year's and the next year's class maps (model grid), w a focal window of 1s
adjacency_counts <- function(a, b, src, to, attr, w) {
  land <- !is.na(a); share <- terra::focal(a %in% attr, w, fun = "sum", na.rm = TRUE) / terra::focal(land, w, fun = "sum", na.rm = TRUE)
  va <- terra::values(a, mat = FALSE); vb <- terra::values(b, mat = FALSE); vs <- terra::values(share, mat = FALSE)
  k <- which(va %in% src & !is.na(vb) & !is.na(vs)); ev <- vb[k] %in% to
  list(counts = data.table::data.table(Bin = ceiling(round(vs[k] * 10, 6)) / 10, Event = ev)[, list(N = .N, Events = sum(Event)), by = Bin], events = k[ev]) }

# the multiplier curve from all years' counts: AttributeValue 0, 0.1, ..., 1 and Amount in 0-1; a bin with fewer than min_n cell-years (1,000: on
# Puget the fully surrounded bin held under 300 cells and alone set the scale)
# takes the bin below it
adjacency_curve <- function(counts, min_n = 1000) {
  x <- counts[, list(N = sum(N), Events = sum(Events)), by = Bin]; bins <- round(seq(0, 1, 0.1), 1)
  x <- x[data.table::data.table(Bin = bins), on = "Bin"]; x[is.na(N), `:=`(N = 0L, Events = 0L)]
  rate <- ifelse(x$N >= min_n, x$Events / pmax(x$N, 1), NA_real_)
  for (i in seq_along(rate)) if (is.na(rate[i])) rate[i] <- if (i == 1) 0 else rate[i - 1]
  rate <- cummax(rate); top <- max(rate)
  data.table::data.table(AttributeValue = bins, Amount = if (top > 0) round(rate / top, 5) else rep(1, length(bins)), Rate = rate, N = x$N, Events = x$Events) }
