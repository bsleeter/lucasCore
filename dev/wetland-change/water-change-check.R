# To-do 2: src/water-change.R on real data, against the earlier rule test (dswe-rules.R). Reads the cached DSWE crops, in blocks of rows.
# Usage: Rscript water-change-check.R <cache dir> "<region name>"   (writes rules/<tag>-function.csv)
suppressMessages({ library(terra); library(data.table) }); source("src/water-change.R")
args <- commandArgs(trailingOnly = TRUE); cache <- args[1]; rn <- args[2]; tag <- gsub("[^a-z]+", "-", tolower(rn)); HA <- 0.09; YEARS <- 1994:2025
regions <- list("Louisiana chenier plain" = c(-93.9, -92.5, 29.5, 30.2), "Sierra Nevada reservoirs" = c(-120.7, -120.15, 37.6, 38.05), "Great Salt Lake" = c(-113.1, -111.9, 40.6, 41.7))
b <- regions[[rn]]; e <- ext(project(vect(ext(b[1], b[2], b[3], b[4]), crs = "EPSG:4326"), "EPSG:5070"))
nl <- function(y) { r <- rast(sprintf("E:/lucasData/land-cover/nlcd-annual/Annual_NLCD_LndCov_%d_CU_C1V2.tif", y)); crs(r) <- "EPSG:5070"; r }
tmpl <- crop(nl(2021), e)
O <- rast(lapply(YEARS, function(y) rast(file.path(cache, sprintf("dswe-%s-%d.tif", tag, y)), lyrs = 1)))
N <- crop(rast(lapply(YEARS, nl)), tmpl); stopifnot(ncell(O) == ncell(N))
readStart(O); readStart(N); step <- max(1L, floor(1.5e6 / ncol(O))); res <- list(); wat <- 0; eq <- 0; sides <- c(0, 0)
for (r0 in seq(1L, nrow(O), by = step)) { nr <- min(step, nrow(O) - r0 + 1L)
  o <- readValues(O, r0, nr, mat = TRUE); l <- readValues(N, r0, nr, mat = TRUE); storage.mode(o) <- "integer"; storage.mode(l) <- "integer"
  x <- water_change(o, l)
  res[[length(res) + 1]] <- rbindlist(lapply(seq_along(YEARS), function(i) data.table(Year = YEARS[i], Side = rep(c("Wetland", "Other"), each = 7), Code = rep(0:6, 2),
    N = c(tabulate(x$change[x$wetland_side, i] + 1L, 7), tabulate(x$change[!x$wetland_side, i] + 1L, 7)))))
  wat <- wat + colSums(x$water); eq <- eq + colSums(o, na.rm = TRUE) / 100; sides <- sides + c(sum(x$wetland_side), sum(!x$wetland_side)) }
readStop(O); readStop(N)
res <- rbindlist(res)[Code > 0, .(Kha = sum(N) * HA / 1000), by = .(Year, Side, Code)][, Change := names(WATER_CHANGE)[Code]][, Region := rn]
fwrite(res, sprintf("dev/wetland-change/rules/%s-function.csv", tag))
w <- data.table(Year = YEARS, WaterKha = wat * HA / 1000, EqKha = eq * HA / 1000)[Year %in% 1996:2021]
cat(rn, ": wetland side", round(sides[1] * HA / 1000), "kha, other", round(sides[2] * HA / 1000), "kha\n")
cat(sprintf("swing followed %.2f, corr %.2f\n", diff(range(w$WaterKha)) / diff(range(w$EqKha)), cor(w$WaterKha, w$EqKha)))
print(dcast(res[Year %in% 1996:2021, .(Kha = round(sum(Kha), 2)), by = .(Side, Change)], Change ~ Side, value.var = "Kha", fill = 0))
cat("gross to or from water 1996-2021:", round(res[Year %in% 1996:2021 & Code %in% c(1, 2, 3, 6), sum(Kha)], 1), "kha; wetland side after 2021:", round(res[Year > 2021 & Side == "Wetland" & Code %in% c(1, 2, 3, 6), sum(Kha)], 2), "\n")
