# =============================================================================
# water-change.R - change among water, wetland and barren at 30 m, from yearly DSWE open water and the annual NLCD (to-do 2; rule agreed 2026-11-25)
# =============================================================================
# DSWE open water (the share of a year's clear looks that read open water, 0-100) says whether a pixel is water; the annual NLCD says what
# the land side is. Two rules set the water state, by side:
#   - the wetland side (a pixel the NLCD calls wetland in any year given): a change counts only once the pixel has read on the other side
#     of `line` for `hold` clear years running, and is dated to the first of them. A marsh edge that floods and drains produces nothing.
#   - everywhere else (`inland`, default "nlcd"; user 2026-11-26: "Yes, NLCD alone"): the annual NLCD decides alone. A pixel turns to
#     water in the first of `land_hold` years running the NLCD calls it open water, and back to land in the first of `land_hold` years
#     running it calls it land; a change first seen in the last `land_hold` - 1 years is not counted. DSWE has no say here. Two earlier
#     rules are kept for comparison: "dswe" (two lines on each year's value: water at `hi` or more, land at `lo` or less) read an
#     alpine lake under ice as land and high barren ground as water (P27, Sierra Nevada); "agree" (the same, only in a year the NLCD
#     says so too) worked as a ratchet, because DSWE reads low under ice in many years: P27 water fell 27 km2 at 30 m where the NLCD's
#     fell 10.
#     Land that leaves water here is barren whatever the NLCD calls it.
# A year with no clear look (NA) changes nothing and does not break a run of years.
# Pixels are independent, so a caller may pass any block of rows. The first year only sets the starting state: give the rule a few years
# before the first year wanted, and note that wetland-side changes first seen in the last `hold` - 1 years cannot be confirmed.
# =============================================================================
WATER_CHANGE <- c("To Water" = 1L, "Water to Wetland" = 2L, "Water to Barren" = 3L, "Wetland to Barren" = 4L, "Barren to Wetland" = 5L, "Water to Other Land" = 6L)
# open, nlcd: integer matrices, one row per pixel and one column per year (the same years, in order).
# Returns change (a WATER_CHANGE code or 0 per pixel and year), water (the water state per pixel and year, held changes dated to their
# first year), wetland_side (per pixel), and confirmed (the last column whose wetland-side changes are confirmed).
water_change <- function(open, nlcd, hi = 70, lo = 30, line = 50, hold = 5L, land_hold = 2L, wet = c(90L, 95L), barren = 31L, water = 11L, inland = c("nlcd", "agree", "dswe")) {
  n <- nrow(open); Y <- ncol(open); inland <- match.arg(inland); agree <- inland == "agree"; land_hold <- as.integer(land_hold)
  if (!identical(dim(open), dim(nlcd))) stop("water_change: open water and NLCD must have the same pixels and years.")
  if (Y < 2L) stop("water_change: at least two years are needed.")
  isw <- matrix(nlcd %in% wet, n, Y); isb <- matrix(nlcd %in% barren, n, Y); isl <- !matrix(nlcd %in% water | is.na(nlcd), n, Y); isq <- matrix(nlcd %in% water, n, Y)
  W <- rowSums(isw) > 0
  # ---- the water state ----
  s <- ifelse(is.na(open[, 1]), nlcd[, 1] %in% water, open[, 1] >= line)   # no clear look in the first year: the NLCD decides
  M <- matrix(FALSE, n, Y); M[, 1] <- s
  s2 <- s; sh <- s; run <- integer(n); st <- integer(n)
  if (inland != "dswe") { k1 <- !W & !is.na(nlcd[, 1]); s2[k1] <- isq[k1, 1]; M[, 1] <- ifelse(W, s, s2) }   # away from wetland the NLCD sets the start
  for (y in 2:Y) { o <- open[, y]; look <- !is.na(o)
    if (inland == "nlcd") { if (y + land_hold - 1L <= Y) { q <- y:(y + land_hold - 1L); up <- !s2 & rowSums(isq[, q, drop = FALSE]) == land_hold; dn <- s2 & rowSums(isl[, q, drop = FALSE]) == land_hold } else up <- dn <- logical(n)
    } else { up <- !s2 & look & o >= hi; dn <- s2 & look & o <= lo }
    if (agree) { up <- up & isq[, y]; dn <- dn & isl[, y] }   # the NLCD must say the same that year (isl: land, and known)
    s2[up] <- TRUE; s2[dn] <- FALSE
    d <- look & (o >= line) != sh; st[d & run == 0L] <- y; run[d] <- run[d] + 1L; run[look & !d] <- 0L
    M[, y] <- ifelse(W, sh, s2)
    f <- which(W & run >= hold)
    if (length(f)) { sh[f] <- !sh[f]; run[f] <- 0L
      for (j in unique(st[f])) { r <- f[st[f] == j]; M[r, j:y] <- sh[r] } } }   # dated to the first year on the other side
  # ---- the changes ----
  ch <- matrix(0L, n, Y)
  for (y in 2:Y) { a <- M[, y - 1L]; b <- M[, y]
    ch[!a & b, y] <- WATER_CHANGE[["To Water"]]
    tl <- which(a & !b)
    if (length(tl)) {   # what the pixel becomes. Away from wetland: always barren (user 2026-11-25; the NLCD calls an exposed reservoir bed grassland,
      # which would grow carbon for a year and lose it on refill). Wetland side: the NLCD's most common land class over the years it stays land
      k <- y:min(Y, y + hold - 1L); land <- !M[tl, k, drop = FALSE]
      nw <- rowSums(isw[tl, k, drop = FALSE] & land); nb <- rowSums(isb[tl, k, drop = FALSE] & land); no <- rowSums(isl[tl, k, drop = FALSE] & land) - nw - nb
      ch[tl, y] <- ifelse(!W[tl], WATER_CHANGE[["Water to Barren"]], ifelse(nw + nb + no == 0L, WATER_CHANGE[["Water to Wetland"]],
        ifelse(nw >= nb & nw >= no, WATER_CHANGE[["Water to Wetland"]], ifelse(nb >= no, WATER_CHANGE[["Water to Barren"]], WATER_CHANGE[["Water to Other Land"]])))) }
    # land both years: wetland and barren trading places in the NLCD, each held `land_hold` years
    if (y - land_hold >= 1L && y + land_hold - 1L <= Y) { p <- (y - land_hold):(y - 1L); q <- y:(y + land_hold - 1L); dry <- !a & !b
      ch[dry & rowSums(isw[, p, drop = FALSE]) == land_hold & rowSums(isb[, q, drop = FALSE]) == land_hold, y] <- WATER_CHANGE[["Wetland to Barren"]]
      ch[dry & rowSums(isb[, p, drop = FALSE]) == land_hold & rowSums(isw[, q, drop = FALSE]) == land_hold, y] <- WATER_CHANGE[["Barren to Wetland"]] } }
  list(change = ch, water = M, wetland_side = W, confirmed = Y - as.integer(hold) + 1L)
}
# ---- stage 6: the rule over the Build's 30 m window ---------------------------------------------------------------------------
WATER_DSWE_FILE <- "DSWE_open_water_%d.tif"   # one file a year in the DsweFolder Data Source (src/download-sources.R)
WATER_LEAD <- 5L                                # years read before the start year, so the water state has settled by the first year wanted
WATER_UPLAND_SHARE <- 0.5                       # an upland forest, shrub or grass cell becomes water only in a year this share of its pixels did (stage 6)
# The years the rule reads for a Build of y0 to y1: `lead` years before the start year and `hold` - 1 after the end year (a wetland-side
# change is confirmed only once it has held), kept to the years the annual NLCD has. A year with no DSWE file is read as no clear look.
water_rule_years <- function(y0, y1, nlcd_years, lead = WATER_LEAD, hold = 5L) { yy <- (y0 - lead):(y1 + hold - 1L); yy[yy %in% nlcd_years] }
# One band of 30 m rows (stage 6 runs the bands in parallel, as src/mortality.R). a: E (xmin, xmax, ymin, ymax of the aggregation
# blocks), fact (30 m pixels per model cell side), nr, nc, step, rows (each band's first row), all (the years read), out (the years
# wanted), dswe and nlcd (file per year, named by year; no DSWE entry = no clear look), clear. Returns, for each block cell of the
# band, the number of its pixels with each change in each year wanted: an array of block cells x years x the six WATER_CHANGE codes.
# Only pixels that can change go through the rule: one that never reads `line` or more open water, is not NLCD water in the first
# year and is not both wetland and barren in the NLCD can produce nothing.
water_band <- function(i, a) {
  library(terra); a$clear(); terraOptions(progress = 0)
  r0 <- a$rows[i]; nrw <- min(a$step, a$nr - r0); nc <- a$nc; n <- nrw * nc; x0 <- a$E[1]; y1 <- a$E[4] - r0 * 30; e <- ext(x0, x0 + nc * 30, y1 - nrw * 30, y1)
  rd <- function(f) { r <- rast(f)[[1]]; v <- rep(NA_integer_, n)
    if (abs(res(r)[1] - 30) > 1e-6 || abs((xmin(r) - x0) / 30 - round((xmin(r) - x0) / 30)) > 1e-3 || abs((ymax(r) - y1) / 30 - round((ymax(r) - y1) / 30)) > 1e-3) stop("not on the 30 m grid of the Annual NLCD: ", f)
    ie <- intersect(ext(r), e); if (is.null(ie) || xmax(ie) - xmin(ie) < 30 || ymax(ie) - ymin(ie) < 30) return(v)
    c0 <- round((xmin(ie) - x0) / 30); q0 <- round((y1 - ymax(ie)) / 30); wc <- round((xmax(ie) - xmin(ie)) / 30); wr <- round((ymax(ie) - ymin(ie)) / 30)
    x <- as.integer(values(r, mat = FALSE, row = round((ymax(r) - ymax(ie)) / 30) + 1, nrows = wr, col = round((xmin(ie) - xmin(r)) / 30) + 1, ncols = wc))
    if (wc == nc && wr == nrw) v <- x else v[rep((q0 + seq_len(wr) - 1) * nc, each = wc) + c0 + seq_len(wc)] <- x
    v }
  ALL <- a$all; Y <- length(ALL); nb <- (nrw / a$fact) * (nc / a$fact); out <- array(0L, c(nb, length(a$out), length(WATER_CHANGE)))
  O <- vector("list", Y); N <- vector("list", Y); wet <- logical(n); bar <- logical(n); cand <- logical(n)
  for (q in seq_len(Y)) { k <- as.character(ALL[q]); f <- a$dswe[[k]]
    o <- if (is.null(f)) rep(NA_integer_, n) else rd(f); o[!is.na(o) & o > 100L] <- NA_integer_; v <- rd(a$nlcd[[k]])
    cand <- cand | (!is.na(o) & o >= min(a$line, a$hi)) | v %in% 11L   # any year of NLCD water: away from wetland the NLCD decides
    wet <- wet | v %in% c(90L, 95L); bar <- bar | v %in% 31L; O[[q]] <- o; N[[q]] <- v }
  k <- which(cand | (wet & bar)); if (!length(k)) return(out)
  w <- water_change(matrix(unlist(lapply(O, `[`, k), use.names = FALSE), length(k), Y), matrix(unlist(lapply(N, `[`, k), use.names = FALSE), length(k), Y),
                    hi = a$hi, lo = a$lo, line = a$line, hold = a$hold)
  blk <- (((k - 1L) %/% nc) %/% a$fact) * (nc / a$fact) + ((k - 1L) %% nc) %/% a$fact + 1L   # each pixel's block cell in the band
  for (j in seq_along(a$out)) { cj <- w$change[, match(a$out[j], ALL)]
    for (cc in unname(WATER_CHANGE)) { h <- cj == cc; if (any(h)) out[, j, cc] <- tabulate(blk[h], nb) } }
  out
}
