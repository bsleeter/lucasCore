# To-do 2: which water-line rule keeps flicker low without losing reservoir drawdown and refill?
# Rules on the yearly DSWE open-water share: a plain 50% line, a 3-year mean, two-threshold lines
# (a cell turns to water above the high line and back to land below the low line), and 5-year persistence.
# Results are kept apart for the wetland side (cells Annual NLCD calls wetland in 1996 or 2021) and the other side.
# Usage: Rscript dswe-rules.R <cache dir> "<region name>"   (after dswe-test.R; writes rules/<tag>-*.csv)
suppressMessages({ library(terra); library(data.table) })
args <- commandArgs(trailingOnly = TRUE); cache <- args[1]; rn <- args[2]
out <- "dev/wetland-change/rules"; dir.create(out, showWarnings = FALSE)
tag <- gsub("[^a-z]+", "-", tolower(rn)); HA <- 0.09; YEARS <- 1994:2025
regions <- list("Louisiana delta plain" = c(-91.3, -89.7, 29.0, 29.9), "Louisiana chenier plain" = c(-93.9, -92.5, 29.5, 30.2),
  "Chesapeake eastern shore" = c(-76.5, -75.7, 38.0, 38.6), "San Francisco Bay and Delta" = c(-122.6, -121.5, 37.4, 38.3), "Western Lake Erie" = c(-83.6, -82.6, 41.3, 41.8),
  "Sierra Nevada reservoirs" = c(-120.7, -120.15, 37.6, 38.05), "Great Salt Lake" = c(-113.1, -111.9, 40.6, 41.7))
b <- regions[[rn]]; e <- ext(project(vect(ext(b[1], b[2], b[3], b[4]), crs = "EPSG:4326"), "EPSG:5070"))
nl <- function(y) { r <- rast(sprintf("E:/lucasData/land-cover/nlcd-annual/Annual_NLCD_LndCov_%d_CU_C1V2.tif", y)); crs(r) <- "EPSG:5070"; r }
tmpl <- crop(nl(2021), e); wv <- function(y) values(crop(nl(y), tmpl), mat = FALSE) %in% c(90, 95); WET <- wv(1996) | wv(2021)
open <- function(y) values(rast(file.path(cache, sprintf("dswe-%s-%d.tif", tag, y)), lyrs = 1), mat = FALSE)
RULES <- c("Yearly 50", "3-year mean 50", "Two lines 60/40", "Two lines 70/30", "Two lines 80/20", "Hold 5 years", "Hold 3 years")
o <- open(YEARS[1]); n <- length(o); stopifnot(n == length(WET)); init <- !is.na(o) & o >= 50
S <- lapply(RULES, function(r) init); names(S) <- RULES
F <- lapply(RULES, function(r) integer(n)); names(F) <- RULES
run5 <- integer(n); run3 <- integer(n); p1 <- o; p2 <- rep(NA_real_, n); res <- list()
SIDES <- c("Wetland", "Other"); side <- function(p) if (p == "Wetland") WET else !WET
step <- function(r, new, y) {   # new: TRUE water, FALSE land, NA keep the state
  ch <- !is.na(new) & new != S[[r]]; S[[r]][ch] <<- new[ch]; F[[r]][ch] <<- F[[r]][ch] + 1L
  for (p in SIDES) { k <- side(p); to <- sum(ch & k & S[[r]])
    res[[length(res) + 1]] <<- data.table(Region = rn, Rule = r, Side = p, Year = y, WaterKha = sum(S[[r]] & k) * HA / 1000, ToKha = to * HA / 1000, FromKha = (sum(ch & k) - to) * HA / 1000) } }
two <- function(r, o, hi, lo) { new <- rep(NA, n); new[!S[[r]] & o >= hi] <- TRUE; new[S[[r]] & o <= lo] <- FALSE; new }
hold <- function(r, raw, run, k) { d <- !is.na(raw) & raw != S[[r]]; run[d] <- run[d] + 1L; run[!is.na(raw) & !d] <- 0L
  new <- rep(NA, n); f <- run >= k; new[f] <- !S[[r]][f]; run[f] <- 0L; list(new, run) }
eqf <- function(o, y) data.table(Year = y, Side = SIDES, EqKha = c(sum(o[WET], na.rm = TRUE), sum(o[!WET], na.rm = TRUE)) / 100 * HA / 1000)
z <- function(v) { v[is.na(v)] <- 0; v }
eq <- eqf(o, YEARS[1])
for (y in YEARS[-1]) { o <- open(y); raw <- o >= 50; eq <- rbind(eq, eqf(o, y))
  step("Yearly 50", raw, y)
  step("Two lines 60/40", two("Two lines 60/40", o, 60, 40), y); step("Two lines 70/30", two("Two lines 70/30", o, 70, 30), y); step("Two lines 80/20", two("Two lines 80/20", o, 80, 20), y)
  # 3-year mean centred on the year before (dated to that year)
  k <- (!is.na(p2)) + (!is.na(p1)) + (!is.na(o)); m <- (z(p2) + z(p1) + z(o)) / k
  if (y >= YEARS[3]) step("3-year mean 50", m >= 50, y - 1L)
  # hold k years: the state turns once the yearly line has sat on the other side k years running (dated to the first of them)
  h <- hold("Hold 5 years", raw, run5, 5L); run5 <- h[[2]]; step("Hold 5 years", h[[1]], y - 4L)
  h <- hold("Hold 3 years", raw, run3, 3L); run3 <- h[[2]]; step("Hold 3 years", h[[1]], y - 2L)
  p2 <- p1; p1 <- o }
res <- merge(rbindlist(res), eq, by = c("Year", "Side"))
fwrite(res, file.path(out, paste0(tag, "-yearly.csv")))
fl <- rbindlist(lapply(RULES, function(r) rbindlist(lapply(SIDES, function(p) { v <- F[[r]][side(p)]
  data.table(Region = rn, Rule = r, Side = p, Once = sum(v == 1L) * HA / 1000, Twice = sum(v == 2L) * HA / 1000, More = sum(v > 2L) * HA / 1000) }))))
fwrite(fl, file.path(out, paste0(tag, "-flips.csv")))
cat(rn, "done\n")
