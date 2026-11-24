# =============================================================================
# mortality.R - drought and insect mortality events (to-do 3; stage 6)
# =============================================================================
# One transition type, Mortality: Drought and Insects: a stand that loses most of its live trees to drought, insects or disease,
# with no fire and no cutting. The event is mapped at 30 m (user decisions 2026-11-22 to 24; the design and its tests are in
# dev/mortality and the design doc):
#   A 30 m pixel has the event in year y when
#     1. its USFS forest type group is a softwood group (codes 100-399; pinyon/juniper, 180, has its own line)
#     2. Annual NLCD shows forest (41-43) and tree canopy cover is at least MORT$floor (20%) at y - MORT$span (5 years)
#     3. LCMS shows Desiccation (4) or Insect, Disease or Drought Stress (12) in at least one year y - span .. y
#     4. tree canopy cover has fallen by at least the line, as a share of its value at y - span
#     5. no MTBS burn (1-4) and no LCMS Wildfire, Prescribed Fire, Tree Removal or other named cause (1,2,3,5,6,7,8,9) in y - span .. y + 1
#     6. it is the first year the pixel meets these (counted from MORT$first, 1990, whatever the Build's start year)
#   The line is the pixel's ecodivision's (defaults/transitions/mortality-lines.csv: set so the flagged share of softwood forest
#   matches FIA's share of stands that lost 70% or more of their live carbon between visits; tools: dev/mortality/17 to 19). An
#   ecodivision with no row has no event: the rule finds almost nothing in the East, where FIA's heavy mortality is mostly not insects.
# Placement on the model grid (user 2026-11-22, 23): each cell's share of flagged pixels is ranked within the year and cells are
# taken from the top until their area equals the year's flagged area; they get 1 in the transition spatial multiplier and all
# others 0, so every iteration of the historical run has the same die-off. Area that does not fill a whole cell carries to the
# next year. "Fraction as probability" (the share written as the multiplier, as fire and harvest are) stays as a setting.
# =============================================================================
MORT_TYPE <- "Mortality: Drought and Insects"; MORT_GROUP <- paste0(MORT_TYPE, " [Type]"); MORT_SOURCE <- "CanopyLcms"
MORT <- list(span = 5L, floor = 20L, first = 1990L, stress = c(4L, 12L), named = c(1L, 2L, 3L, 5L, 6L, 7L, 8L, 9L), burn = 1:4, pj = 180L)

# The scenario's Mortality page (single row; package.xml MortalityOptions). Blank = on, ranked selection, the shipped lines, the
# pathways' minimum age.
mortality_options <- function(x) {
  x <- data.table::as.data.table(x); g <- function(k) if (nrow(x) && k %in% names(x)) x[[k]][1] else NA
  en <- g("Enabled"); pl <- g("Placement")
  pl <- if (is.character(pl) || is.factor(pl)) c(`ranked selection` = 1L, `fraction as probability` = 2L)[tolower(trimws(as.character(pl)))] else suppressWarnings(as.integer(pl))
  pl <- unname(pl); if (length(pl) && !is.na(pl) && !pl %in% 1:2) stop(sprintf("Mortality: Placement is %s; use Ranked selection or Fraction as probability", g("Placement")))
  num <- function(k, lo, hi) { v <- suppressWarnings(as.numeric(g(k))); if (!is.na(v) && (v < lo || v > hi)) stop(sprintf("Mortality: %s is %s; give a value from %s to %s", k, v, lo, hi)); v }
  list(enabled = is.na(en) || isTRUE(as.logical(en)) || identical(toupper(as.character(en)), "YES"),
       placement = if (!is.na(pl) && pl == 2L) "probability" else "ranked",
       line = num("CanopyLossLine", 0.01, 1), pj_line = num("PinyonJuniperLine", 0.01, 1), min_age = num("MinimumAge", 0, 500))
}

# The line of each ecodivision (StrtmId of the ecodivision file): the other softwoods' and pinyon/juniper's. The page's values, when
# given, replace the shipped ones in every ecodivision that has a row; they do not extend the event to an ecodivision with none.
mortality_lines <- function(tab, eco, opt) {
  tab <- data.table::as.data.table(tab); eco <- unique(data.table::as.data.table(eco)[, .(ecodiv = as.character(ecodiv), StrtmId = as.integer(StrtmId))])
  w <- data.table::dcast(tab[, .(ecodiv = as.character(Ecodivision), g = ifelse(ForestGroups == "pinyon/juniper", "pj_line", "line"), Line = as.numeric(Line))], ecodiv ~ g, value.var = "Line")
  for (k in c("line", "pj_line")) if (!k %in% names(w)) w[, (k) := NA_real_]
  if (!is.na(opt$line)) w[!is.na(line), line := opt$line]
  if (!is.na(opt$pj_line)) w[!is.na(pj_line), pj_line := opt$pj_line]
  merge(eco, w, by = "ecodiv")[, .(ecodiv, StrtmId, line, pj_line)]
}

# The years the rule can be judged in, from the files on disk: tree canopy cover at y and y - span, NLCD at y - span, LCMS in every
# year y - span .. y. MTBS and the year after (y + 1) are used where they exist.
mortality_years <- function(years, has_tc, has_nl, has_lc) {
  ok <- vapply(years, function(y) y >= MORT$first && has_tc(y) && has_tc(y - MORT$span) && has_nl(y - MORT$span) && all(vapply((y - MORT$span):y, has_lc, TRUE)), TRUE)
  years[ok]
}

# Worker: one band of 30 m rows of the block extent a$E (xmin, xmax, ymin, ymax; every input sits on the one national 30 m lattice,
# so each is read by window and nothing is resampled). Returns, per block cell of the band (a$fact x a$fact pixels) and output
# year, the number of pixels flagged; and per year the pixels flagged in all.
mortality_band <- function(i, a) {
  library(terra); a$clear(); terraOptions(progress = 0)
  r0 <- a$rows[i]; nrw <- min(a$step, a$nr - r0); nc <- a$nc; n <- nrw * nc; x0 <- a$E[1]; y1 <- a$E[4] - r0 * 30; e <- ext(x0, x0 + nc * 30, y1 - nrw * 30, y1)
  rd <- function(f, idx = NULL) { r <- rast(f); v <- rep(NA_integer_, n)
    if (abs(res(r)[1] - 30) > 1e-6 || abs((xmin(r) - x0) / 30 - round((xmin(r) - x0) / 30)) > 1e-3 || abs((ymax(r) - y1) / 30 - round((ymax(r) - y1) / 30)) > 1e-3) stop("not on the 30 m grid of the Annual NLCD: ", f)
    ie <- intersect(ext(r), e); if (is.null(ie) || xmax(ie) - xmin(ie) < 30 || ymax(ie) - ymin(ie) < 30) return(if (is.null(idx)) v else v[idx])
    c0 <- round((xmin(ie) - x0) / 30); q0 <- round((y1 - ymax(ie)) / 30); wc <- round((xmax(ie) - xmin(ie)) / 30); wr <- round((ymax(ie) - ymin(ie)) / 30)
    x <- as.integer(values(r, mat = FALSE, row = round((ymax(r) - ymax(ie)) / 30) + 1, nrows = wr, col = round((xmin(ie) - xmin(r)) / 30) + 1, ncols = wc))
    if (wc == nc && wr == nrw) v <- x else v[rep((q0 + seq_len(wr) - 1) * nc, each = wc) + c0 + seq_len(wc)] <- x
    if (is.null(idx)) v else v[idx] }
  nb <- (nrw / a$fact) * (nc / a$fact); out <- matrix(0L, nb, length(a$out)); tot <- numeric(length(a$out))
  # the forest type tiles are overlapping rectangles filled with 65535 outside their own region: a pixel takes the first tile with a type
  ftv <- rep(NA_integer_, n); for (f in a$ft) { v <- rd(f); v[v == 65535L | v == 0L] <- NA_integer_; k <- is.na(ftv); ftv[k] <- v[k] }
  blk <- ((seq_len(n) - 1L) %/% nc %/% a$fact) * (nc / a$fact) + ((seq_len(n) - 1L) %% nc) %/% a$fact + 1L   # each pixel's block cell in the band
  ed <- a$eco[(r0 / a$fact) * (nc / a$fact) + blk]; j <- match(ed, a$lines$StrtmId)
  pl <- ifelse(!is.na(ftv) & ftv == a$pj, a$lines$pj_line[j], a$lines$line[j]); cf <- which(!is.na(ftv) & ftv >= 100L & ftv < 400L & !is.na(pl))
  if (!length(cf)) return(list(counts = out, total = tot))
  pl <- pl[cf]; blk <- blk[cf]; m <- length(cf); ALL <- a$all; ix <- function(k) match(k, ALL)
  bad <- matrix(FALSE, m, length(ALL)); st <- bad; tc <- matrix(NA_integer_, m, length(ALL))
  for (q in seq_along(ALL)) { k <- as.character(ALL[q])
    if (!is.null(a$lc[[k]])) { v <- rd(a$lc[[k]], cf); bad[, q] <- v %in% a$named; st[, q] <- v %in% a$stress }
    if (!is.null(a$mt[[k]])) bad[, q] <- bad[, q] | rd(a$mt[[k]], cf) %in% a$burn
    if (!is.null(a$tc[[k]])) { v <- rd(a$tc[[k]], cf); v[v > 100L] <- NA_integer_; tc[, q] <- v } }
  done <- rep(FALSE, m)
  for (y in a$years) { t0 <- tc[, ix(y - a$span)]; t1 <- tc[, ix(y)]; w <- intersect((y - a$span):(y + 1L), ALL)
    hit <- !done & rd(a$nl[[as.character(y - a$span)]], cf) %in% 41:43 & !is.na(t0) & t0 >= a$floor & !is.na(t1) & rowSums(bad[, ix(w), drop = FALSE]) == 0 &
      rowSums(st[, ix((y - a$span):y), drop = FALSE]) > 0 & (t0 - t1) / t0 >= pl
    hit[is.na(hit)] <- FALSE; done[hit] <- TRUE; o <- match(y, a$out)
    if (!is.na(o) && any(hit)) { out[, o] <- tabulate(blk[hit], nb); tot[o] <- sum(hit) } }
  list(counts = out, total = tot)
}

# Ranked selection for one year. share: each cell's flagged share (0 where none); cls: the cell's class has the pathway; can: it has
# the pathway and has not had the event; old: it is at or over the minimum age; room: the share of the cell not taken by fire, harvest
# or a land-use change this year. Returns the cells that take the event and the area book-keeping, in cells.
# The year's area is what was flagged on cells that can take it, plus what was flagged on cells whose class has no pathway (30 m
# softwood pixels in a cell of another class): that area lands on the next-ranked cells, so the total the line was set for is kept
# (user 2026-11-24; P27 at 300 m had 10% of its flagged area on such cells). Flags on a cell that already had the event are not
# counted again: the cell died whole.
mortality_select <- function(share, can, old, room, carry, cls = can) {
  share[is.na(share)] <- 0; has <- share > 0
  moved <- sum(share[has & !cls]); again <- sum(share[has & cls & !can]); young <- sum(share[has & can & !old]); ok <- has & can & old
  t <- pmin(share, room); held <- sum((share - t)[ok]); target <- carry + sum(t[ok]) + moved
  free <- which(ok & room >= 1 - 1e-9); k <- min(length(free), floor(target + 1e-9))
  sel <- if (k > 0) free[order(-share[free], free)][seq_len(k)] else integer()
  list(sel = sel, flagged = sum(share), moved = moved, again = again, young = young, held = held, target = target, carry = target - k)
}
