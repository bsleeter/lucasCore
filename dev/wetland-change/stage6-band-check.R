# To-do 2 step 4: stage 6's band worker (src/water-change.R, water_band) on a test box, put together as stage 6 does on a 300 m grid,
# against the rule run on every 30 m pixel of the same window. Stage 6 itself needs a library: this checks its arithmetic only.
# Usage: Rscript dev/wetland-change/stage6-band-check.R <cache dir> "<region name>" [first year] [last year]     (from the package root)
suppressPackageStartupMessages({ library(data.table); library(terra) })
source("src/water-change.R")
args <- commandArgs(trailingOnly = TRUE); cache <- args[1]; tag <- gsub("[^a-z]+", "-", tolower(args[2])); y0 <- if (length(args) > 2) as.integer(args[3]) else 1995L; y1 <- if (length(args) > 3) as.integer(args[4]) else 2021L
nlf <- function(y) file.path("E:/lucasData/land-cover/nlcd-annual", sprintf("Annual_NLCD_LndCov_%d_CU_C1V2.tif", y)); dwf <- function(y) file.path(cache, sprintf("dswe-%s-%d.tif", tag, y))
cand <- (y0 - WATER_LEAD):(y1 + 4L); wall <- water_rule_years(y0, y1, cand[file.exists(nlf(cand))]); dw <- wall[file.exists(dwf(wall))]; out <- intersect((y0 + 1L):y1, wall)
r <- rast(dwf(dw[1])); fact <- 10L; nc <- (ncol(r) %/% fact) * fact; nr <- (nrow(r) %/% fact) * fact; E <- c(xmin(r), xmin(r) + nc * 30, ymax(r) - nr * 30, ymax(r))
step <- max(fact, (floor(2e6 / nc) %/% fact) * fact); rows <- seq(0, nr - 1, by = step)
a <- list(clear = function() NULL, E = E, fact = fact, nr = nr, nc = nc, step = step, rows = rows, all = wall, out = out, dswe = setNames(lapply(dw, dwf), dw), nlcd = setNames(lapply(wall, nlf), wall), hi = 70, lo = 30, line = 50, hold = 5L)
cat(sprintf("%s: %d x %d pixels, %d bands of %d rows, years read %d-%d (%d with DSWE), wanted %d-%d\n", tag, nr, nc, length(rows), step, min(wall), max(wall), length(dw), min(out), max(out)))
t0 <- Sys.time(); got <- lapply(seq_along(rows), water_band, a = a); mins <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
cnt <- do.call(rbind, lapply(got, function(x) matrix(x, nrow = dim(x)[1]))); J <- length(out)
cat(sprintf("bands: %.1f min on one core (%.2f million pixel-years a second)\n", mins, nr * nc * length(wall) / 1e6 / (mins * 60)))
# as stage 6: each block cell's share of its pixels, per set of changes, on the 300 m grid
bt <- rast(ext(E), resolution = 30 * fact, crs = "EPSG:5070"); sets <- c("1", "2|5", "3|4")
grid <- vapply(sets, function(cs) { cd <- as.integer(strsplit(cs, "|", fixed = TRUE)[[1]]); bc <- Reduce(`+`, lapply(cd, function(k) cnt[, (k - 1L) * J + seq_len(J), drop = FALSE]))
  br <- rast(bt, nlyrs = J); values(br) <- bc / fact^2; stopifnot(max(values(br)) <= 1); sum(values(br)) * (30 * fact / 1000)^2 }, 0)
# the rule on every pixel of the window
e <- ext(E); rdv <- function(f) { x <- rast(f)[[1]]; if (!nzchar(crs(x))) crs(x) <- "EPSG:5070"; as.integer(values(crop(x, e), mat = FALSE)) }
O <- sapply(wall, function(y) if (y %in% dw) { v <- rdv(dwf(y)); v[!is.na(v) & v > 100L] <- NA_integer_; v } else rep(NA_integer_, nr * nc)); N <- sapply(wall, function(y) { x <- rast(nlf(y)); as.integer(values(crop(x, e), mat = FALSE)) })
t0 <- Sys.time(); w <- water_change(O, N); ch <- w$change[, match(out, wall), drop = FALSE]
px <- vapply(sets, function(cs) sum(ch %in% as.integer(strsplit(cs, "|", fixed = TRUE)[[1]])) * 9e-4, 0)
res <- data.table(Box = tag, Changes = c("to water (1)", "to wetland (2, 5)", "to barren (3, 4)"), Grid300mKm2 = round(grid, 3), Pixels30mKm2 = round(px, 3))
res[, Same := abs(Grid300mKm2 - Pixels30mKm2) < 1e-6]; print(res)
by_code <- vapply(unname(WATER_CHANGE), function(k) sum(cnt[, (k - 1L) * J + seq_len(J)]) * 9e-4, 0); names(by_code) <- names(WATER_CHANGE)
cat("km2 by change:", paste(sprintf("%s %.1f", names(by_code), by_code), collapse = "; "), "\n")
cat(sprintf("gross change to or from water %d-%d: %.1f thousand ha; pixels through the rule in the bands: all that can change, against %d in the window\n", min(out), max(out), sum(by_code[c(1, 2, 3, 6)]) / 10, nr * nc))
fwrite(res, sprintf("dev/wetland-change/rules/%s-stage6-band.csv", tag))
