# =============================================================================
# landcover-match.R - land cover resampling by area matching (Build Options: Land Cover Resampling = Area-matched; to-do item 8)
# =============================================================================
# The modal resampling gives each cell its most common 30 m class: it keeps a third of P26's developed area, makes developed cells
# flicker from year to year, and gives each area's dominant class 5% too much (dev/resampling/FINDINGS.md). Area matching makes every
# class's area in each secondary stratum unit equal its 30 m area, year by year, starting from the year before so cells change only
# where the 30 m totals move (the method of dev/resampling/06-match-all.R, P26: area in the wrong class 997 -> 28 km2 in 1985):
#   1 developed: a unit's developed cell count is the larger of last year's and the year's 30 m developed area (the first year:
#     exactly the 30 m area); the cells added are those with the largest developed share. A developed cell stays developed, raised
#     when its most common developed class is higher (there is no pathway back to natural land or to a lower intensity). The first
#     year picks the developed cells by rank from scratch; a modal-developed cell not picked takes its most common other class.
#   2 every other class: the unit's target is the class's 30 m area in cells (rounded so the targets add up to the unit's
#     non-developed cells). Cells move from classes over their target to classes under it, largest gain in 30 m share first, and only
#     to a class the cell has pixels of; a class that cannot be filled that way stays short (reported).
# Sourced by stage 5, which writes the matched maps as the annual NLCD; stages 6, 9 and 10 read those, so transitions and state classes
# come from the same maps.
# =============================================================================
LC_CLASSES <- c(11L, 12L, 21L, 22L, 23L, 24L, 31L, 41L, 42L, 43L, 52L, 71L, 81L, 82L, 90L, 95L)   # Annual NLCD land cover classes

# per cell, the number of 30 m pixels of each class (one layer per class), over the same aggregation blocks as nlcd_on_grid
nlcd_counts_on_grid <- function(nf, L, R) {
  n30 <- terra::rast(nf); levels(n30) <- NULL; b <- grid_blocks(n30, L, R)
  s <- terra::aggregate(terra::segregate(terra::crop(n30, b$ext), classes = LC_CLASSES), fact = b$fact, fun = "sum", na.rm = TRUE)
  names(s) <- paste0("c", LC_CLASSES); terra::project(s, R, method = "near") }

# a matcher for one study area: unit = each land cell's secondary stratum unit. Returns function(prev, K, first): prev the class index
# (1..16 in LC_CLASSES) of every cell the year before (the first year: the modal class), K the year's pixel counts (cells x 16)
lc_matcher <- function(unit) {
  unit[is.na(unit)] <- -1; ci <- match(unit, sort(unique(unit))); G <- max(ci); n <- length(ci)
  DEV <- which(LC_CLASSES %in% 21:24); ND <- setdiff(seq_along(LC_CLASSES), DEV)
  gsum <- function(v) { r <- rowsum(v, ci, reorder = TRUE); out <- matrix(0, G, ncol(r)); out[as.integer(rownames(r)), ] <- r; out }
  # largest-remainder rounding of each row of x so the row adds up to tot (x is scaled to tot first, so only the rounding remains)
  lr_round <- function(x, tot) { x <- x * ifelse(rowSums(x) > 0, tot / rowSums(x), 0); f <- floor(x); r <- x - f
    for (g in seq_len(nrow(x))) { k <- tot[g] - sum(f[g, ])
      if (k > 0) { o <- order(-r[g, ])[seq_len(k)]; f[g, o] <- f[g, o] + 1 }
      else if (k < 0) { o <- order(r[g, ] + (f[g, ] == 0) * 2)[seq_len(-k)]; f[g, o] <- pmax(0, f[g, o] - 1) } }
    f }
  function(prev, K, first) {
    cur <- prev; S <- K / pmax(rowSums(K), 1); dsh <- rowSums(S[, DEV, drop = FALSE]); isd <- cur %in% DEV
    devmode <- DEV[max.col(K[, DEV, drop = FALSE], ties.method = "first")]; hasdev <- rowSums(K[, DEV, drop = FALSE]) > 0
    ndmode <- ND[max.col(K[, ND, drop = FALSE], ties.method = "first")]
    # 1 developed: additions only
    tgt <- round(as.vector(gsum(matrix(dsh))))
    have <- as.vector(gsum(matrix(as.numeric(isd))))
    if (first) { isd[] <- FALSE; have[] <- 0; k <- tgt } else k <- pmax(have, tgt)
    need <- k - have
    dt <- data.table(i = which(!isd & dsh > 0))[, `:=`(g = ci[i], d = dsh[i])][order(g, -d)]
    dt[, r := seq_len(.N), by = g]; add <- dt[r <= need[g], i]
    newdev <- logical(n); newdev[add] <- TRUE
    if (first) { off <- !newdev & cur %in% DEV; cur[off] <- ndmode[off]; cur[newdev] <- devmode[newdev] }
    else { cur[newdev] <- ifelse(hasdev[newdev], devmode[newdev], DEV[1]); up <- isd & hasdev & devmode > cur; cur[up] <- devmode[up] }
    isd <- cur %in% DEV
    # 2 the other classes, balanced to their 30 m area in each unit
    Nnd <- as.vector(gsum(matrix(as.numeric(!isd))))
    Tg <- matrix(0, G, length(LC_CLASSES)); Tg[, ND] <- lr_round(gsum(S[, ND, drop = FALSE]), Nnd)
    Nc <- gsum(outer(cur, seq_along(LC_CLASSES), "==") * 1)
    sur <- Nc - Tg; sur[, DEV] <- 0
    for (pass in 1:3) {
      def <- which(sur < 0, arr.ind = TRUE); if (!nrow(def)) break
      cand <- rbindlist(lapply(unique(def[, 2]), function(c) { i <- which(!isd & S[, c] > 0 & cur != c)
        i <- i[sur[cbind(ci[i], cur[i])] > 0 & sur[cbind(ci[i], c)] < 0]
        if (!length(i)) NULL else data.table(i = i, to = c, gain = S[cbind(i, c)] - S[cbind(i, cur[i])]) }))
      if (!nrow(cand)) break
      setorder(cand, -gain); moved <- logical(n); I <- cand$i; TO <- cand$to; mv <- 0L
      for (j in seq_along(I)) { i <- I[j]; if (moved[i]) next; g <- ci[i]; a <- cur[i]; b <- TO[j]
        if (sur[g, a] > 0 && sur[g, b] < 0) { cur[i] <- b; moved[i] <- TRUE; sur[g, a] <- sur[g, a] - 1; sur[g, b] <- sur[g, b] + 1; mv <- mv + 1L } }
      if (!mv) break }
    list(cur = cur, short = -sum(pmin(sur, 0))) } }
