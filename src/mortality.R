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

# =============================================================================
# Projections (to-do 3 phase 2, lucasCore 2.0.2; stage 9): the empirical method
# =============================================================================
# How much (user decisions 2026-11-23): the historical years are drawn in blocks of consecutive years (5 by default), one drawn
# year for every unit; a unit is an ecodivision's softwood forest type group class (pinyon/juniper its own); the drawn year gives
# the unit the share of its forest still open to the event that had it that year, written as a Transition Multiplier Value by
# ecodivision, state class, iteration and year. It is a rate on what stands, so the area falls as the forest is used up.
# Where (user 2026-11-24: no single cells sprinkled over the eligible forest; "Add adjacency now"): three things localize it,
# all read from the Build's own yearly maps:
#   a surface  a logistic GAM of where the events fell on canopy cover, climate normals and terrain, scaled to average 1 in
#              every unit so it moves the die-off without changing the amount
#   patches    the sizes of the yearly patches (8-neighbour model cells) as a Transition Size Distribution, as fire has
#   spread     the chance by the share of recent die-off around a cell (ST-Sim adjacency on the state attribute Recent
#              Mortality, 1 on a disturbed softwood class in the years after the event), as a ratio to the chance the rate
#              and the surface give, so over the record the three together return the events that happened
# =============================================================================
MORT_SET <- "Mortality"; MORT_ATTR <- "Recent Mortality"; MORT_NEVER <- 999L
MORTP <- list(block = 5L, small_km2 = 250, min_events = 100L, max_controls = 300000L, k = 5L, clamp = 20,
              window = 3L, radius = 3L, share = c(0, 0.05, 0.1, 0.2, 0.4), adj_min_n = 1000L, adj_min_events = 30L, adj_cap = 30,
              sizes = c(1, 2, 3, 5, 10, 20, 50, 100, 200, 500, 1e3, 2e3, 5e3, 1e4, 2e4, 5e4, 1e5))

# The projection's Mortality page (single row; package.xml MortalityProjection). Blank = historical rates, blocks of 5, the Run Settings reference period, clustered.
mortality_projection_options <- function(x) {
  x <- data.table::as.data.table(x); g <- function(k) if (nrow(x) && k %in% names(x)) x[[k]][1] else NA
  pick <- function(k, lv) { v <- g(k); v <- if (is.character(v) || is.factor(v)) match(tolower(sub(" .*", "", trimws(as.character(v)))), lv) else suppressWarnings(as.integer(v))
    if (length(v) && !is.na(v) && !v %in% seq_along(lv)) stop(sprintf("Mortality: %s is %s", k, g(k))); if (!length(v) || is.na(v)) 1L else v }
  int <- function(k, lo, hi) { v <- suppressWarnings(as.integer(g(k))); if (!is.na(v) && (v < lo || v > hi)) stop(sprintf("Mortality: %s is %s; give a value from %s to %s", k, v, lo, hi)); v }
  b <- int("BlockYears", 1L, 50L); rs <- int("ReferenceStartYear", 1900L, 2200L); re <- int("ReferenceEndYear", 1900L, 2200L)
  if (!is.na(rs) && !is.na(re) && rs > re) stop(sprintf("Mortality: the reference years run from %d to %d; the start must not be after the end", rs, re))
  list(projection = c("rates", "off")[pick("Projection", c("historical", "off"))], block = if (is.na(b)) MORTP$block else b, ref_start = rs, ref_end = re,
       clustered = pick("ProjectionPlacement", c("clustered", "random")) == 1L, climate = pick("ClimateLink", c("as", "from")) == 2L)
}

# Block draws: every iteration fills the projection years with blocks of consecutive reference years. A block starts at any
# reference year with the same chance and runs on from the last year to the first, so every year is drawn equally often and the
# long-run mean is the reference period's.
mortality_blocks <- function(ref, pyrs, nit, block, seed) {
  set.seed(seed); n <- length(ref); block <- as.integer(max(1L, block)); nb <- ceiling(length(pyrs) / block)
  data.table::rbindlist(lapply(seq_len(nit), function(i) { st <- sample.int(n, nb, replace = TRUE)
    idx <- as.vector(vapply(st, function(s) as.integer((s - 1L + 0:(block - 1L)) %% n) + 1L, integer(block)))[seq_along(pyrs)]
    data.table::data.table(Iteration = i, Timestep = pyrs, HistoricalYear = ref[idx]) }))
}

# The cells still open to the event in year y: an eligible class, no event yet, at or over the minimum age (the start age carried
# forward: a stand a fire or a clearcut made young during the record is counted as open, a small share).
mortality_open <- function(ev, eligible, age0, mage, y0, y) eligible & (is.na(ev) | ev >= y) & !is.na(age0) & (age0 + (y - y0 - 1L)) >= mage

# Yearly rates by unit from events E and open cells N (units x reference years). A unit with fewer than `small` eligible cells at
# the start takes the rate of its ecodivision's units together (its softwoods pooled), a few cells being no record of their own.
mortality_rate_table <- function(E, N, eco, cells0, small) {
  r <- E / pmax(N, 1); r[N <= 0] <- 0; pooled <- cells0 < small
  for (e in unique(eco[pooled])) { k <- eco == e; pr <- colSums(E[k, , drop = FALSE]) / pmax(colSums(N[k, , drop = FALSE]), 1)
    r[k & pooled, ] <- matrix(pr, sum(k & pooled), ncol(E), byrow = TRUE) }
  r <- pmin(r, 1); dimnames(r) <- dimnames(E)
  list(rate = r, pooled = pooled, all = colSums(E) / pmax(colSums(N), 1))
}

# Patch sizes: each reference year's event cells joined into 8-neighbour patches on the model grid R; the number of patches per
# size class (the class's largest size in cells).
mortality_sizes <- function(ev, R, ref) {
  n <- unlist(lapply(ref, function(y) { k <- ev %in% y; if (!any(k)) return(integer())
    as.integer(table(terra::values(terra::patches(terra::setValues(R, ifelse(k, 1, NA)), directions = 8), mat = FALSE))) }))
  if (!length(n)) return(NULL)
  br <- MORTP$sizes[MORTP$sizes <= MORTP$sizes[min(which(MORTP$sizes >= max(n)))]]
  b <- factor(findInterval(n, c(0, br), left.open = TRUE), levels = seq_along(br)); a <- as.numeric(tapply(n, b, sum)); a[is.na(a)] <- 0
  list(table = data.table::data.table(MaximumCells = as.integer(br), Patches = as.integer(table(b)), AreaShare = a / sum(n)),
       n = length(n), mean = mean(n), max = max(n), single = sum(n == 1) / sum(n))
}

# The surface: where the reference period's events fell among the cells open to them, on the covariates X (a data.table, one
# column each, a row per cell; fitted on X, predicted from Xnow, which holds the covariates as they are at the historical end).
# Returns each cell's weight, averaging 1 over the pool cells of every unit, or NULL when there are too few events or no covariate.
mortality_surface <- function(event, pool, unit, X, Xnow = X, seed = 1L) {
  cov <- names(X)[vapply(names(X), function(k) { v <- X[[k]][pool]; sum(!is.na(v)) > 0.5 * sum(pool) && isTRUE(stats::sd(v, na.rm = TRUE) > 0) }, TRUE)]
  if (!length(cov)) return(NULL)
  ok <- pool & stats::complete.cases(X[, cov, with = FALSE]); ev <- which(ok & event)
  if (length(ev) < MORTP$min_events) return(NULL)
  set.seed(seed); ct <- which(ok & !event); if (length(ct) > MORTP$max_controls) ct <- sort(sample(ct, MORTP$max_controls))
  D <- cbind(data.table::data.table(y = rep(1:0, c(length(ev), length(ct)))), X[c(ev, ct), cov, with = FALSE])
  kk <- vapply(cov, function(k) as.integer(min(MORTP$k, data.table::uniqueN(D[[k]]) - 1L)), 1L); cov <- cov[kk >= 3]; if (!length(cov)) return(NULL)
  fm <- stats::as.formula(paste("y ~", paste(sprintf("s(%s, k = %d)", cov, kk[cov]), collapse = " + ")))
  g <- mgcv::bam(fm, data = D, family = stats::binomial(), discrete = TRUE)
  auc <- function(p, y) { r <- rank(p); (sum(r[y == 1]) - sum(y) * (sum(y) + 1) / 2) / (sum(y) * sum(y == 0)) }
  p <- as.numeric(stats::fitted(g)); top <- order(-p)[seq_len(ceiling(0.1 * length(p)))]
  # every cell with the covariates as they are now; the odds are the relative chance of a rare event, kept within clamp x the median
  okn <- stats::complete.cases(Xnow[, cov, with = FALSE]); w <- rep(NA_real_, nrow(Xnow))
  w[okn] <- exp(as.numeric(stats::predict(g, Xnow[okn, cov, with = FALSE], type = "link"))); md <- stats::median(w[okn & pool], na.rm = TRUE)
  if (!is.finite(md) || md <= 0) return(NULL)
  w <- pmin(pmax(w, md / MORTP$clamp), md * MORTP$clamp)
  st <- summary(g)$s.table
  list(w = mortality_scale(w, pool, unit), covariates = cov, auc = auc(p, D$y), top10 = sum(D$y[top]) / sum(D$y), events = length(ev), controls = length(ct),
       terms = data.table::data.table(Covariate = cov, ChiSq = as.numeric(st[, "Chi.sq"])))
}
# weights scaled to average 1 over the pool cells of each unit (a cell with no weight takes 1; a cell outside every unit the overall scale)
mortality_scale <- function(w, pool, unit) {
  all <- mean(w[pool], na.rm = TRUE); if (!is.finite(all) || all <= 0) return(rep(1, length(w)))
  m <- tapply(w[pool], unit[pool], mean, na.rm = TRUE); s <- as.numeric(m[as.character(unit)]); s[is.na(s) | s <= 0] <- all
  w <- w / s; w[is.na(w)] <- 1; w
}

# Spread: for every reference year, the open cells by the share of cells within the radius that had the event in the window of
# years before, their events, and the events the rate and the surface alone would give them (expect(y): per cell). The curve is
# events over expected per share class: a class with too few cell-years takes the class below, the curve does not fall as the
# share rises, and it is scaled so that over the record it returns the events that happened.
# open(y) and expect(y) are functions of the year; R is the model grid.
mortality_spread <- function(ev, land, R, ref, open, expect, radius = MORTP$radius, window = MORTP$window) {
  k <- -radius:radius; w <- outer(k, k, function(a, b) as.numeric(a^2 + b^2 <= radius^2)); nw <- sum(w)
  den <- terra::values(terra::focal(terra::setValues(R, as.numeric(land)), w, "sum", na.rm = TRUE), mat = FALSE)
  nb <- length(MORTP$share); lv <- seq_len(nb); N <- numeric(nb); E <- numeric(nb); X <- numeric(nb); S <- numeric(nb)
  add <- function(v, b) { s <- as.numeric(tapply(v, factor(b, levels = lv), sum)); s[is.na(s)] <- 0; s }
  for (y in ref) { o <- which(open(y)); if (!length(o)) next
    rec <- !is.na(ev) & ev < y & ev >= y - window
    sh <- if (any(rec)) terra::values(terra::focal(terra::setValues(R, as.numeric(rec)), w, "sum", na.rm = TRUE), mat = FALSE)[o] / pmax(den[o], 1) else numeric(length(o))
    b <- pmin(findInterval(sh, MORTP$share, left.open = TRUE) + 1L, nb)
    N <- N + tabulate(b, nb); E <- E + add(as.numeric(ev[o] %in% y), b); X <- X + add(expect(y)[o], b); S <- S + add(sh, b) }
  if (sum(E[-1]) < MORTP$adj_min_events || sum(X) <= 0) return(NULL)
  m <- ifelse(N >= MORTP$adj_min_n & X > 0, E / pmax(X, 1e-12), NA_real_); if (is.na(m[1])) m[1] <- 1
  for (i in 2:nb) if (is.na(m[i])) m[i] <- m[i - 1]
  m[-1] <- pmin(cummax(pmax(m[-1], m[1])), MORTP$adj_cap)
  m <- m * sum(E) / sum(X * m)   # the record's total is kept
  # the curve's points: no recent die-off near; then each class that holds cells, at their mean share; the last value held to a share of 1
  s <- MORTP$share; has <- which(N > 0 & lv > 1); at <- c(0, S[has] / N[has]); am <- c(m[1], m[has]); if (max(at) < 1) { at <- c(at, 1); am <- c(am, am[length(am)]) }
  list(curve = data.table::data.table(AttributeValue = round(at, 4), Amount = round(am, 4)),
       classes = data.table::data.table(Share = c("none", sprintf("%g-%g%%", 100 * s[-nb], 100 * s[-1])[seq_len(nb - 2)], sprintf("over %g%%", 100 * s[nb - 1])),
                                        CellYears = N, Events = E, Expected = X, Multiplier = m), cells = nw, near = sum(E[-1]) / sum(E))
}

# =============================================================================
# Two settings for exploring a climate response (lucasCore 2.0.3; user decisions 2026-11-25)
# =============================================================================
# The empirical method above has no climate in it: the same blocks of historical years fall anywhere in a projection. The record
# (1991-2022, 35 western pyromes) shows only a weak relation of the event to dryness, too weak to calibrate a response, so two
# settings let a user explore one against a climate run of their choice. Both are off when blank, which leaves the draws as drawn.
#   timing  (0 to 1)  the blocks an iteration drew are placed in time: a period's score is strength x its dryness (standardised
#                     over the periods) + sqrt(1 - strength^2) x noise, and the most severe block goes to the highest score. The
#                     blocks, and so the long-run rates, are those of the draw; only their order changes. 0.3 is about what the
#                     record shows (the driest third of years with 1.3 to 1.6 times the wettest third's area).
#   amount  (percent) the rate of a year is multiplied by 1 + amount x depth, the depth of the dry period the year falls in:
#                     its dryness above zero as a share of the deepest dryness of the run's own historical years (1 = as deep
#                     as that), held at MORTK$depth_cap. Wet years are unchanged; nothing is lowered.
# Dryness: the yearly water deficit of the study area's eligible forest (a monthly water balance: Hargreaves demand from maximum
# and minimum temperature, one soil store of MORTK$awc mm, snow held and melted by temperature; the October-September water
# year), as the mean of the MORTK$window years ending in the year, less the mean of the MORTK$baseline years around each year
# (the forest is taken to adjust to the climate it has had: a dry period is dry against its surrounding years, not against the
# record), over the spread of the run's MORTK$norm years. It is taken from the climate run alone, so a model's bias drops out.
MORTK <- list(window = 7L, baseline = 30L, awc = 150, depth_cap = 2, norm = 1991:2020, first = 1975L, timing_guide = 0.3)

# Yearly water deficit (mm; named by water year, complete years only) from a monthly series in time order: y, m, P (mm), TX and
# TN (C), at latitude lat (degrees).
mortality_deficit <- function(y, m, P, TX, TN, lat, awc = MORTK$awc) {
  stopifnot(length(y) == length(m), length(P) == length(y), length(TX) == length(y), length(TN) == length(y), !anyNA(c(P, TX, TN)))
  doy <- c(15, 46, 75, 106, 136, 167, 197, 228, 259, 289, 320, 350); dim_ <- c(31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31); ph <- lat * pi / 180
  ra <- vapply(1:12, function(k) { J <- doy[k]; dr <- 1 + 0.033 * cos(2 * pi * J / 365); dec <- 0.409 * sin(2 * pi * J / 365 - 1.39); ws <- acos(max(-1, min(1, -tan(ph) * tan(dec))))
    0.408 * (24 * 60 / pi) * 0.0820 * dr * (ws * sin(ph) * sin(dec) + cos(ph) * cos(dec) * sin(ws)) }, 0)   # extraterrestrial radiation as mm of evaporation a day
  tm <- (TX + TN) / 2; pet <- pmax(0, 0.0023 * ra[m] * (tm + 17.8) * sqrt(pmax(TX - TN, 0)) * dim_[m])
  soil <- awc; pack <- 0; def <- numeric(length(y))
  for (j in seq_along(y)) { rf <- max(0, min(1, tm[j] / 6)); pack <- pack + P[j] * (1 - rf); melt <- pack * rf; pack <- pack - melt; w <- P[j] * rf + melt   # rain share from 0 at 0 C to 1 at 6 C; the pack melts by the same share
    d <- w - pet[j]; if (d >= 0) { soil <- min(awc, soil + d); aet <- pet[j] } else { dr <- soil * (1 - exp(d / awc)); aet <- w + dr; soil <- soil - dr }
    def[j] <- pet[j] - aet }
  wy <- y + (m >= 10L); full <- as.integer(names(which(table(wy) == 12L))); o <- vapply(full, function(k) sum(def[wy == k]), 0); names(o) <- full; o
}

# Dryness by year (standard deviations; named by year) from the yearly deficit: see the head of this section. A year whose
# surrounding years are cut short by the ends of the series uses the years it has (at least the 10 nearest).
mortality_dryness <- function(def, window = MORTK$window, baseline = MORTK$baseline, norm = MORTK$norm) {
  ay <- as.integer(names(def)); if (!length(ay) || any(diff(ay) != 1L)) stop("Mortality: the water deficit series has missing years")
  nn <- intersect(norm, ay); if (length(nn) < 10L) stop(sprintf("Mortality: the climate run has fewer than 10 of the years %d-%d", min(norm), max(norm)))
  s <- stats::sd(def[as.character(nn)]); if (!is.finite(s) || s <= 0) stop("Mortality: the water deficit does not vary over the normal years, so dryness cannot be measured")
  z <- vapply(ay, function(k) { w <- intersect((k - baseline %/% 2L):(k + baseline %/% 2L - 1L), ay); if (length(w) < 10L) w <- ay[order(abs(ay - k))][seq_len(min(10L, length(ay)))]
    (def[[as.character(k)]] - mean(def[as.character(w)])) / s }, 0)
  ok <- ay[ay - window + 1L >= min(ay)]; o <- vapply(ok, function(k) mean(z[match((k - window + 1L):k, ay)]), 0); names(o) <- ok; o
}

# Depth of the dry period of each year of `dry` (named by year): dryness above zero as a share of the deepest dryness of the
# reference years, held at `cap`. The deepest dryness comes back as the attribute "deepest".
mortality_depth <- function(dry, ref_years, cap = MORTK$depth_cap) {
  d0 <- suppressWarnings(max(dry[as.character(intersect(ref_years, as.integer(names(dry))))]))
  if (!is.finite(d0) || d0 <= 0) stop("Mortality: the climate run has no dry period in its historical years to measure depth against")
  o <- pmin(pmax(dry, 0) / d0, cap); attr(o, "deepest") <- d0; o
}

# Timing: the whole blocks of each iteration of `drm` (mortality_blocks: Iteration, Timestep, HistoricalYear) placed by dryness.
# sev: the severity of a historical year (named by year: the study area's rate); dry: dryness by projection year (named by year).
# A last block cut short by the end of the projection stays where it is. strength 0 returns the draw unchanged.
mortality_place <- function(drm, sev, dry, block, strength, seed) {
  if (is.na(strength) || strength <= 0) return(data.table::copy(drm))
  if (strength > 1) stop("Mortality: the timing strength is between 0 and 1")
  miss <- setdiff(unique(drm$Timestep), as.integer(names(dry))); if (length(miss)) stop(sprintf("Mortality: no dryness for %d-%d", min(miss), max(miss)))
  zs <- function(v) if (length(v) > 1L && stats::sd(v) > 0) (v - mean(v)) / stats::sd(v) else v * 0
  set.seed(seed); block <- as.integer(max(1L, block)); o <- data.table::copy(drm); data.table::setorder(o, Iteration, Timestep)
  o[, HistoricalYear := { b <- (seq_len(.N) - 1L) %/% block; full <- as.integer(names(which(table(b) == block))); hy <- HistoricalYear
    if (length(full) > 1L) { sv <- vapply(full, function(k) mean(sev[as.character(hy[b == k])]), 0); dr <- vapply(full, function(k) mean(dry[as.character(Timestep[b == k])]), 0)
      to <- full[order(strength * zs(dr) + sqrt(1 - strength^2) * stats::rnorm(length(full)))]; from <- full[order(sv)]
      new <- hy; for (q in seq_along(full)) new[b == to[q]] <- hy[b == from[q]]; hy <- new }
    hy }, by = Iteration]
  o[]
}

# Amount: the multiplier on the drawn rate by projection year, 1 + amount (a share: 0.5 = 50%) x depth.
mortality_amount <- function(depth, amount) { if (is.na(amount) || amount <= 0) return(depth * 0 + 1); o <- 1 + amount * as.numeric(depth); names(o) <- names(depth); o }

# ---- how the two settings reach a projection (ST-Sim external variables) ------------------------------------------------------------
# A Projection Setup has no climate in it and serves any number of climate futures, and a scenario takes a whole sheet from the first of
# its dependencies that has rows (the setup, then the Projection Climate result). So when the setup's Mortality page says the timing and
# amount come from the Projection Climate result, the setup (stage 9) writes the rates as a lookup and no draws of its own: a Transition
# Multiplier Value row per unit whose value is read from the Distributions sheet by the external variable MORT_EV_YEAR (the drawn
# historical year), and a second multiplier (type MORT_CLIMATE) read by MORT_EV_PCT (a percentage on the rate). A Projection Climate
# result (stage 11) that depends on the setup writes the External Variables sheet, which the setup does not have: the setup's blocks
# placed by its run's dryness, and the percentage of each year (the blocks as drawn and 100 when its two settings are blank). ST-Sim
# stops when a variable has no values, so every projection from such a setup needs such a result. Tested on a small ST-Sim library
# (2026-11-25): the lookup returns the row of the variable's value, the two multipliers multiply, and an unconditional row beside the
# conditional ones is drawn at random with them, so it cannot serve as a default.
MORT_PREFIX <- "Mortality"; MORT_EV_YEAR <- "Mortality: Drawn Year"; MORT_EV_PCT <- "Mortality: Climate Percent"; MORT_CLIMATE <- "Mortality: Climate"
MORT_RATE <- "Mortality Rate: "; MORT_RATE_ALL <- "Mortality Rate: Study Area"; MORT_PCTS <- 100:500; MORT_FREQ <- "Iteration and Timestep"
# A unit's Distribution Type is its state class's ("Mortality Rate: " + the class without "Forest: "); the rows of the Distributions sheet
# carry the unit's ecodivision as their stratum, so one name per softwood class serves every study area (tested: a row with a stratum
# is read for that stratum's multiplier row only). The names ship with the package (defaults/stsim: the classes of
# defaults/transitions/pathways/mortality.csv), because a stage cannot add a definition to the library while it runs.
mortality_class_types <- function(classes) paste0(MORT_RATE, sub("^Forest: ", "", classes))

# The names the lookup needs that the library's definitions lack (character(0) = none missing). tools/add-definitions.R adds them to a
# library made before lucasCore 2.0.3.
mortality_definitions <- function(prj, classes) {
  need <- list(core_ExternalVariableType = c(MORT_EV_YEAR, MORT_EV_PCT), core_DistributionType = c(unique(mortality_class_types(classes)), MORT_RATE_ALL, MORT_CLIMATE), stsim_TransitionMultiplierType = MORT_CLIMATE)
  unlist(lapply(names(need), function(sh) { miss <- setdiff(need[[sh]], as.character(rsyncrosim::datasheet(prj, sh, optional = TRUE, lookupsAsFactors = FALSE)$Name)); if (length(miss)) sprintf("%s: %s", sh, paste(miss, collapse = ", ")) }))
}

# The lookup rows of a setup: rt = mortality_rate_table()'s result (rate: units x record years; all: the study area's rate by record
# year), rec_y its years, ref the reference years (the only ones a draw can name), t0 the first projection year.
mortality_lookup <- function(rt, rec_y, ref, u_eco, u_cls, t0) {
  ut <- mortality_class_types(u_cls); j <- match(ref, rec_y); nu <- length(u_cls)
  tmv <- data.table::rbindlist(list(
    data.table::data.table(Timestep = t0, StratumId = u_eco, StateClassId = u_cls, TransitionGroupId = MORT_GROUP, TransitionMultiplierTypeId = NA_character_, DistributionType = ut, DistributionFrequencyId = MORT_FREQ),
    data.table::data.table(Timestep = t0, StratumId = NA_character_, StateClassId = NA_character_, TransitionGroupId = MORT_GROUP, TransitionMultiplierTypeId = NA_character_, DistributionType = MORT_RATE_ALL, DistributionFrequencyId = MORT_FREQ),   # (a class with no unit of its own: the study area's rate)
    data.table::data.table(Timestep = t0, StratumId = NA_character_, StateClassId = NA_character_, TransitionGroupId = MORT_GROUP, TransitionMultiplierTypeId = MORT_CLIMATE, DistributionType = MORT_CLIMATE, DistributionFrequencyId = MORT_FREQ)))
  dv <- data.table::rbindlist(c(lapply(seq_len(nu), function(k) data.table::data.table(StratumId = u_eco[k], DistributionTypeId = ut[k], ExternalVariableTypeId = MORT_EV_YEAR, ExternalVariableMin = ref, ExternalVariableMax = ref, Value = signif(rt$rate[k, j], 6))),
    list(data.table::data.table(StratumId = NA_character_, DistributionTypeId = MORT_RATE_ALL, ExternalVariableTypeId = MORT_EV_YEAR, ExternalVariableMin = ref, ExternalVariableMax = ref, Value = signif(rt$all[j], 6)),
         data.table::data.table(StratumId = NA_character_, DistributionTypeId = MORT_CLIMATE, ExternalVariableTypeId = MORT_EV_PCT, ExternalVariableMin = MORT_PCTS, ExternalVariableMax = MORT_PCTS, Value = MORT_PCTS / 100))))
  list(tmv = tmv, dv = dv)
}

# The Projection Climate scenario's Mortality and Climate page (single row; package.xml MortalityClimate). Blank = neither setting.
mortality_climate_options <- function(x) {
  x <- data.table::as.data.table(x); g <- function(k) if (nrow(x) && k %in% names(x)) suppressWarnings(as.numeric(x[[k]][1])) else NA_real_
  s <- g("TimingStrength"); a <- g("AmountPercent"); amax <- (max(MORT_PCTS) - 100) / MORTK$depth_cap
  if (!is.na(s) && (s < 0 || s > 1)) stop(sprintf("Mortality and Climate: the timing strength is %s; give a value from 0 to 1", s))
  if (!is.na(a) && (a < 0 || a > amax)) stop(sprintf("Mortality and Climate: the increase in dry periods is %s%%; give a value from 0 to %g", a, amax))
  list(timing = if (is.na(s)) 0 else s, amount = if (is.na(a)) 0 else a / 100, on = isTRUE(s > 0) || isTRUE(a > 0))
}

# The External Variables rows of a climate result: the placed years, and the percentage on the rate of each year (whole percent, at
# most max(MORT_PCTS)). `mult` is named by projection year.
mortality_climate_rows <- function(placed, mult) {
  pct <- pmin(round(100 * mult[as.character(placed$Timestep)]), max(MORT_PCTS)); if (anyNA(pct)) stop("Mortality and Climate: a projection year has no multiplier")
  rbind(placed[, .(Iteration, Timestep, ExternalVariableTypeId = MORT_EV_YEAR, ExternalVariableValue = as.numeric(HistoricalYear))],
        data.table::data.table(Iteration = placed$Iteration, Timestep = placed$Timestep, ExternalVariableTypeId = MORT_EV_PCT, ExternalVariableValue = as.numeric(pct)))
}
