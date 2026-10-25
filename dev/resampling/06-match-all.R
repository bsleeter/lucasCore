# =============================================================================
# 06-match-all.R - to-do item 8: every NLCD class matched to its 30 m area per county and year (P26), developed additions-only
# =============================================================================
# From 05-class-counts.R (pixels of each class per 150 m cell) and 01-class-shares.R (the modal map). Each year starts from the year
# before (1985 from the modal map), so cells change only where the 30 m totals move:
#   1 developed: each county's developed cell count is the larger of last year's and the year's 30 m developed area (1985: exactly the
#     30 m area); the cells added are those with the most developed pixels. A developed cell keeps its class, raised when its most
#     common developed class is higher (no pathway back to natural land or to a lower intensity in the model). 1985 picks the
#     developed cells by rank from scratch; a modal-developed cell not picked takes its most common non-developed class.
#   2 every other class: the county's target is the class's 30 m area (cells, rounded so the targets add up to the county's
#     non-developed cells). Cells move from classes over their target to classes under it, the moves with the largest gain in 30 m
#     share first (share of the new class minus share of the current one), and only to a class the cell has pixels of. Classes that
#     cannot be filled that way stay short (reported).
# Scores per year against the 30 m counts: area in the wrong class, gross change (cells changing class) against the 30 m pixels
# changing class, A->B->A reversals, and the developed scores of 02-compare-methods.R. Writes cache/allmatch_<year>.tif and
# dev/resampling/match-all.csv. Read-only; no package code is changed.
# Usage: Rscript dev/resampling/06-match-all.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
pkg <- "F:/lucasCore"; cache <- file.path(pkg, "dev/resampling/cache"); build <- file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim.data/Scenario-2")
years <- 1985:2023; km2 <- 0.0225; CLS <- c(11, 12, 21, 22, 23, 24, 31, 41, 42, 43, 52, 71, 81, 82, 90, 95)
DEV <- which(CLS %in% 21:24); ND <- setdiff(seq_along(CLS), DEV)
tmpl <- rast(file.path(cache, "shares_1985.tif"))[["modal"]]
ok <- !is.na(values(tmpl, mat = FALSE)); n <- sum(ok)
cty <- values(rast(file.path(build, "stsim_InitialConditionsSpatial", "SecondaryStrata.tif")), mat = FALSE)[ok]; cty[is.na(cty)] <- -1
ci <- match(cty, sort(unique(cty))); G <- max(ci)
counts <- function(y) { m <- values(rast(file.path(cache, sprintf("counts_%d.tif", y))), mat = TRUE)[ok, , drop = FALSE]; m[is.na(m)] <- 0; m }
modal <- function(y) match(values(rast(file.path(cache, sprintf("shares_%d.tif", y)))[["modal"]], mat = FALSE)[ok], CLS)
gsum <- function(v, by = ci) { r <- rowsum(v, by, reorder = TRUE); out <- matrix(0, G, ncol(r)); out[as.integer(rownames(r)), ] <- r; out }
# largest-remainder rounding of each row of x so the row adds up to tot
# (x is scaled to tot first, so only the rounding remains)
lr_round <- function(x, tot) { x <- x * ifelse(rowSums(x) > 0, tot / rowSums(x), 0); f <- floor(x); r <- x - f; for (g in seq_len(nrow(x))) { k <- tot[g] - sum(f[g, ]); if (k > 0) { o <- order(-r[g, ])[seq_len(k)]; f[g, o] <- f[g, o] + 1 }
    else if (k < 0) { o <- order(r[g, ] + (f[g, ] == 0) * 2)[seq_len(-k)]; f[g, o] <- pmax(0, f[g, o] - 1) } }; f }

step <- function(prev, K, first) {
  cur <- prev; S <- K / 25; dsh <- rowSums(S[, DEV, drop = FALSE]); isd <- cur %in% DEV
  devmode <- DEV[max.col(K[, DEV, drop = FALSE], ties.method = "first")]; hasdev <- rowSums(K[, DEV, drop = FALSE]) > 0
  ndmode <- ND[max.col(K[, ND, drop = FALSE], ties.method = "first")]
  # 1 developed
  tgt <- round(as.vector(gsum(matrix(dsh))))
  if (first) { isd[] <- FALSE; k <- tgt } else k <- pmax(as.vector(gsum(matrix(as.numeric(isd)))), tgt)
  need <- k - as.vector(gsum(matrix(as.numeric(isd))))
  dt <- data.table(i = which(!isd & dsh > 0), g = ci[!isd & dsh > 0], d = dsh[!isd & dsh > 0])[order(g, -d)]
  dt[, r := seq_len(.N), by = g]; add <- dt[r <= need[g], i]
  newdev <- logical(n); newdev[add] <- TRUE
  if (first) { cur[!(newdev) & cur %in% DEV] <- ndmode[!(newdev) & cur %in% DEV]; cur[newdev] <- devmode[newdev] }
  else { cur[newdev] <- ifelse(hasdev[newdev], devmode[newdev], DEV[1]); up <- isd & hasdev & devmode > cur; cur[up] <- devmode[up] }
  isd <- cur %in% DEV
  # 2 the other classes
  Nnd <- as.vector(gsum(matrix(as.numeric(!isd))))
  T <- matrix(0, G, length(CLS)); T[, ND] <- lr_round(gsum(S[, ND, drop = FALSE]), Nnd)
  N <- matrix(0, G, length(CLS)); tab <- gsum(outer(cur, seq_along(CLS), "==") * 1); N[] <- tab
  sur <- N - T; sur[, DEV] <- 0
  for (pass in 1:3) {
    def <- which(sur < 0, arr.ind = TRUE); if (!nrow(def)) break
    cand <- rbindlist(lapply(unique(def[, 2]), function(c) { i <- which(!isd & S[, c] > 0 & cur != c); i <- i[sur[cbind(ci[i], cur[i])] > 0 & sur[cbind(ci[i], c)] < 0]
      if (!length(i)) NULL else data.table(i = i, to = c, gain = S[cbind(i, c)] - S[cbind(i, cur[i])]) }))
    if (!nrow(cand)) break
    setorder(cand, -gain); moved <- logical(n); I <- cand$i; TO <- cand$to; mv <- 0L
    for (j in seq_along(I)) { i <- I[j]; if (moved[i]) next; g <- ci[i]; a <- cur[i]; b <- TO[j]
      if (sur[g, a] > 0 && sur[g, b] < 0) { cur[i] <- b; moved[i] <- TRUE; sur[g, a] <- sur[g, a] - 1; sur[g, b] <- sur[g, b] + 1; mv <- mv + 1L } }
    if (!mv) break }
  list(cur = cur, short = -sum(pmin(sur, 0))) }

# ---- run the years, scoring modal and all-class matching side by side -----------------------------------------------------
sc <- list(); prevA <- NULL; prevM <- NULL; pp <- list(A = NULL, M = NULL); everA <- everM <- logical(n); t0 <- Sys.time()
for (y in years) {
  K <- counts(y); M <- modal(y); M[is.na(M)] <- max.col(K[is.na(M), seq_along(CLS), drop = FALSE], ties.method = "first"); r <- step(if (is.null(prevA)) M else prevA, K, is.null(prevA)); A <- r$cur
  out <- tmpl; v <- rep(NA_integer_, length(ok)); v[ok] <- CLS[A]; values(out) <- v
  writeRaster(out, file.path(cache, sprintf("allmatch_%d.tif", y)), overwrite = TRUE, datatype = "INT1U", gdal = "COMPRESS=DEFLATE")
  a30 <- colSums(K[, seq_along(CLS)]) * 900 / 1e6; aA <- tabulate(A, length(CLS)) * km2; aM <- tabulate(M, length(CLS)) * km2
  rev <- function(p2, p1, x) if (is.null(p2)) 0 else sum(x == p2 & x != p1) * km2
  dA <- A %in% DEV; dM <- M %in% DEV
  sc[[as.character(y)]] <- data.table(year = y, wrong_modal = sum(abs(aM - a30)) / 2, wrong_match = sum(abs(aA - a30)) / 2, short_cells = r$short,
    chg30 = sum(K[, "chg"]) * 900 / 1e6, chg_modal = if (is.null(prevM)) 0 else sum(M != prevM) * km2, chg_match = if (is.null(prevA)) 0 else sum(A != prevA) * km2,
    rev_modal = rev(pp$M, prevM, M), rev_match = rev(pp$A, prevA, A),
    dev30 = sum(a30[DEV]), dev_modal = sum(aM[DEV]), dev_match = sum(aA[DEV]),
    devlost_modal = if (is.null(prevM)) 0 else sum((prevM %in% DEV) & !dM) * km2, devlost_match = if (is.null(prevA)) 0 else sum((prevA %in% DEV) & !dA) * km2,
    first_modal = if (is.null(prevM)) 0 else sum(dM & !everM) * km2, first_match = if (is.null(prevA)) 0 else sum(dA & !everA) * km2)
  if (y == 1985 || y == 2023) { cls85 <- data.table(year = y, code = CLS, km2_30m = round(a30, 1), km2_modal = round(aM, 1), km2_match = round(aA, 1)); assign(paste0("cls", y), cls85) }
  everA <- everA | dA; everM <- everM | dM; pp <- list(A = prevA, M = prevM); prevA <- A; prevM <- M
  if (y %% 10 == 5) cat(sprintf("  %d done (%.1f min)\n", y, as.numeric(Sys.time() - t0, units = "mins"))) }
res <- rbindlist(sc); fwrite(res, file.path(pkg, "dev/resampling/match-all.csv"))
fwrite(rbind(cls1985, cls2023), file.path(pkg, "dev/resampling/match-all-classes.csv"))
f <- function(x) round(x)
cat(sprintf("\nArea in the wrong class (km2 of %.0f): 1985 modal %d, matched %d; 2023 modal %d, matched %d; mean over years modal %d, matched %d\n",
            n * km2, f(res[year == 1985, wrong_modal]), f(res[year == 1985, wrong_match]), f(res[year == 2023, wrong_modal]), f(res[year == 2023, wrong_match]),
            f(mean(res$wrong_modal)), f(mean(res$wrong_match))))
cat(sprintf("Cells a class could not be filled for (sum over years): %d\n", sum(res$short_cells)))
cat(sprintf("Gross change 1986-2023 (km2): 30 m pixels %d, modal cells %d, matched cells %d; A->B->A reversals: modal %d, matched %d\n",
            f(sum(res$chg30)), f(sum(res$chg_modal)), f(sum(res$chg_match)), f(sum(res$rev_modal)), f(sum(res$rev_match))))
cat(sprintf("Developed: 30 m %d -> %d; modal %d -> %d (first-time %d, lost %d); matched %d -> %d (first-time %d, lost %d)\n",
            f(res[year == 1985, dev30]), f(res[year == 2023, dev30]), f(res[year == 1985, dev_modal]), f(res[year == 2023, dev_modal]), f(sum(res$first_modal)), f(sum(res$devlost_modal)),
            f(res[year == 1985, dev_match]), f(res[year == 2023, dev_match]), f(sum(res$first_match)), f(sum(res$devlost_match))))
cl <- rbind(cls1985, cls2023)[, `:=`(modal_pct = round(100 * km2_modal / km2_30m), match_pct = round(100 * km2_match / km2_30m))]; print(cl)
cat(sprintf("%.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
