# =============================================================================
# 02-compare-methods.R - to-do item 8: alternatives to the modal 30 m -> 150 m land cover, scored on P26 1985-2023
# =============================================================================
# From 01-class-shares.R's yearly stacks. Each method gives a class per cell and year; the transitions would come from the same maps,
# so every method keeps state classes and transitions coherent (the rule the Build already follows). Methods:
#   modal          the Build today: the most common 30 m class
#   thresh_t       developed when at least t of the cell's 30 m pixels are developed (its most common developed class), else the
#                  modal class, or the most common non-developed class where the modal class is developed but below t
#   areamatch      per county and year, the cells with the largest developed shares become developed until the county's 30 m
#                  developed area is matched; the rest as thresh (modal, or non-developed mode)
#   areamatch_incr 1985 as areamatch, then only additions: each county keeps its developed cells and adds the next-highest shares
#                  until its 30 m area is met (never fewer cells than last year)
#   +mono          once developed, a cell stays developed (its developed class held, raised when the year's class is higher):
#                  the model has no pathway from developed back to natural land, so this is what it can represent
# Scores: developed / agriculture / forest area against the 30 m area (the shares summed), net developed change 1985-2023 against
# the 30 m change, developed area lost year to year (flicker), and first-time development (cells never developed before).
# Writes dev/resampling/compare-methods.csv and prints the table. Read-only; no package code is changed.
# Usage: Rscript dev/resampling/02-compare-methods.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
pkg <- "F:/lucasCore"; cache <- file.path(pkg, "dev/resampling/cache")
build <- file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim.data/Scenario-2")
years <- 1985:2023; km2 <- 0.0225
S <- lapply(years, function(y) rast(file.path(cache, sprintf("shares_%d.tif", y)))); names(S) <- years
county <- values(rast(file.path(build, "stsim_InitialConditionsSpatial", "SecondaryStrata.tif")), mat = FALSE)
v <- function(y, l) values(S[[as.character(y)]][[l]], mat = FALSE)
ok <- !is.na(v(1985, "modal")); county[!ok] <- NA
isdev <- function(x) !is.na(x) & x >= 21 & x <= 24

# ---- the methods: a function (year) -> class vector -----------------------------------------------------------------------
thresh <- function(t) function(y) { m <- v(y, "modal"); d <- v(y, "dev"); out <- m
  hi <- ok & !is.na(d) & d >= t; out[hi] <- v(y, "devmode")[hi]
  lo <- ok & isdev(m) & !hi; nd <- v(y, "nondev"); out[lo] <- nd[lo]; out }
areamatch <- function(y) { m <- v(y, "modal"); d <- v(y, "dev"); d[is.na(d)] <- 0; out <- m; take <- logical(length(m))
  dt <- data.table(i = which(ok & !is.na(county)), c = county[ok & !is.na(county)], d = d[ok & !is.na(county)])
  dt[, k := round(sum(d)), by = c]; setorder(dt, c, -d); dt[, r := seq_len(.N), by = c]
  take[dt[r <= k & d > 0, i]] <- TRUE
  out[take] <- v(y, "devmode")[take]; lo <- ok & isdev(m) & !take; nd <- v(y, "nondev"); out[lo] <- nd[lo]; out }
# areamatch_incr: 1985 as areamatch; then each county's developed cell count only grows, to the larger of last year's and the year's
# 30 m area, and the new cells are the non-developed cells with the largest developed share that year. No flicker by construction,
# and the developed area follows the 30 m area wherever that never shrinks.
areamatch_incr <- function() { cur <- NULL; function(y) {
  m <- v(y, "modal"); d <- v(y, "dev"); d[is.na(d)] <- 0; dmode <- v(y, "devmode"); nd <- v(y, "nondev")
  if (is.null(cur)) cur <<- logical(length(m))
  dt <- data.table(i = which(ok & !is.na(county)), c = county[ok & !is.na(county)], d = d[ok & !is.na(county)], on = cur[ok & !is.na(county)])
  dt[, k := pmax(sum(on), round(sum(d))), by = c]; dt[, need := k - sum(on), by = c]
  add <- dt[on == FALSE & d > 0][order(c, -d)][, .SD[seq_len(min(.N, need[1]))], by = c]$i
  cur[add] <<- TRUE
  out <- m; out[cur] <- ifelse(is.na(dmode[cur]), 21L, dmode[cur]); lo <- ok & isdev(m) & !cur; out[lo] <- nd[lo]; out } }
mono <- function(f) { prev <- NULL; function(y) { x <- f(y)
  if (!is.null(prev)) { held <- isdev(prev) & !isdev(x); x[held] <- prev[held]; up <- isdev(prev) & isdev(x) & x < prev; x[up] <- prev[up] }
  prev <<- x; x } }
methods <- list(modal = function(y) v(y, "modal"), modal_mono = mono(function(y) v(y, "modal")),
                thresh_0.2 = thresh(0.2), thresh_0.3 = thresh(0.3), thresh_0.4 = thresh(0.4),
                thresh_0.2_mono = mono(thresh(0.2)), thresh_0.3_mono = mono(thresh(0.3)),
                thresh_0.4_mono = mono(thresh(0.4)),
                areamatch = areamatch, areamatch_mono = mono(areamatch), areamatch_incr = mono(areamatch_incr()))

# ---- the 30 m reference ---------------------------------------------------------------------------------------------------
ref <- function(y, l) sum(v(y, l)[ok], na.rm = TRUE) * km2
R30 <- data.table(dev85 = ref(1985, "dev"), dev23 = ref(2023, "dev"), ag85 = ref(1985, "ag"), forest85 = ref(1985, "forest"))
cat(sprintf("30 m reference: developed %.0f km2 (1985) -> %.0f km2 (2023), net +%.0f; agriculture %.0f; forest %.0f km2 (1985)\n",
            R30$dev85, R30$dev23, R30$dev23 - R30$dev85, R30$ag85, R30$forest85))

# ---- score every method ---------------------------------------------------------------------------------------------------
score <- function(name, f) {
  prev <- NULL; ever <- logical(length(ok)); lost <- 0; first <- 0
  for (y in years) { x <- f(y); d <- isdev(x)
    if (y == 1985) { x85 <- x; ever <- d } else { lost <- lost + sum(isdev(prev) & !d) * km2; first <- first + sum(d & !ever) * km2; ever <- ever | d }
    prev <- x }
  a <- function(x, cl) sum(x %in% cl) * km2
  data.table(method = name, dev85 = a(x85, 21:24), dev23 = a(prev, 21:24), net_dev = a(prev, 21:24) - a(x85, 21:24),
             first_time = first, dev_lost = lost, ag85 = a(x85, 81:82), forest85 = a(x85, 41:43),
             open85 = a(x85, 21), low85 = a(x85, 22), medhigh85 = a(x85, 23:24)) }
t0 <- Sys.time()
res <- rbindlist(lapply(names(methods), function(n) { r <- score(n, methods[[n]]); cat(sprintf("  %-16s done\n", n)); r }))
res[, `:=`(dev85_pct = round(100 * dev85 / R30$dev85), net_pct = round(100 * net_dev / (R30$dev23 - R30$dev85)),
           ag85_pct = round(100 * ag85 / R30$ag85), forest85_pct = round(100 * forest85 / R30$forest85))]
fwrite(res, file.path(pkg, "dev/resampling/compare-methods.csv"))
print(res[, .(method, dev85 = round(dev85), dev85_pct, dev23 = round(dev23), net_dev = round(net_dev), net_pct, first_time = round(first_time),
              dev_lost = round(dev_lost), ag85_pct, forest85 = round(forest85), forest85_pct)])
cat(sprintf("%.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
