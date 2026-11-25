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
       clustered = pick("ProjectionPlacement", c("clustered", "random")) == 1L)
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
