# =============================================================================
# 02-rpa-vs-nlcd.R - do the RPA county rates of 2012-2020 resemble what Annual NLCD shows for those years? (exploratory)
# =============================================================================
# The RPA ratio (01-rpa-county-ratios.R) multiplies an NLCD-based area, so it only carries over if RPA's calibration step and NLCD
# describe the same change. For every county that lies wholly inside an Annual NLCD copy (30 m; the regional copies of the data home, or
# the national files in land-cover/nlcd-annual when they are there), the pixels are counted by their class in 2012 and in 2020 (end
# points, so a pixel that flickers and returns is not counted), and set against the RPA county matrix of 2012-2020 (mean of the 20
# futures):
#   Urbanization             not developed, water or ice (2012) > developed 21-24 (2020); also > 22-24 only (without Open Space)
#   Ag Expansion             barren, forest, shrub, grass, wetland > 82 (Cropland) or 81 (Pasture)
#   Ag Contraction           82 or 81 > barren, forest, shrub, grass, wetland
#   Ag Change                82 > 81 and 81 > 82
#   Developed land in 2020   NLCD 21-24 and 22-24, against RPA's urban total at the start of 2020-2030
# RPA is non-federal land only and its urban class is the NRI's developed land; NLCD here is all land.
# Writes 02-rpa-vs-nlcd-county.csv (one row per county and item) and prints the totals by NLCD copy.
# Usage: Rscript dev/land-use-demand/02-rpa-vs-nlcd.R     (LUCAS_DATA_HOME = the Data Sources folder)
# =============================================================================
pkg <- local({ d <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))); while (!file.exists(file.path(d, "package.xml")) && dirname(d) != d) d <- dirname(d); d })   # the package folder
DS <- Sys.getenv("LUCAS_DATA_HOME", "E:/lucasData")
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) })
OUT <- file.path(pkg, "dev/land-use-demand"); CA <- file.path(OUT, "cache"); terraOptions(progress = 0, memfrac = 0.3)
say <- function(...) cat(sprintf(...), "\n")
Y0 <- 2012L; Y1 <- 2020L; KM2 <- 100 * 0.0040468564
nf <- function(dir, y) { f <- file.path(dir, sprintf("Annual_NLCD_LndCov_%d_CU_C1V%d.tif", y, c(0L, 2L))); f <- f[file.exists(f) & file.size(f) > 1000]; if (length(f)) f[1] else NA_character_ }
dirs <- c(Sys.getenv("LUCAS_NLCD_NATIONAL", "F:/lucas-master/Data Sources/NLCD/Annual NLCD"), file.path(DS, "land-cover/nlcd-annual"),file.path(list.dirs(file.path(DS, "regions"), recursive = FALSE), "land-cover/nlcd-annual"))
dirs <- dirs[!is.na(vapply(dirs, nf, "", y = Y0)) & !is.na(vapply(dirs, nf, "", y = Y1))]
if (!length(dirs)) stop("no Annual NLCD copy with ", Y0, " and ", Y1)
cty <- read_sf(file.path(DS, "study-area/counties/tl_rd22_us_county.shp"))[, c("GEOID", "NAME", "STATEFP")]

# ---- NLCD: pixels by county, class in 2012 and class in 2020 ------------------------------------------------------------------------
DEV <- 21:24; NAT <- c(31L, 41:43, 52L, 71L, 90L, 95L)
# one county at a time (the national mosaic is 16 billion pixels), in parallel; cached per copy
tabs <- list(); done <- character(); cl <- parallel::makeCluster(min(32L, parallel::detectCores() - 4L))
for (d in dirs) { fa <- nf(d, Y0); fb <- nf(d, Y1); a <- rast(fa); nm <- if (grepl("regions", d)) basename(dirname(dirname(d))) else "CONUS"
  cf <- file.path(CA, sprintf("02-nlcd-%d-%d-%s.rds", Y0, Y1, nm))
  if (file.exists(cf)) { x <- readRDS(cf) } else {
    cp <- st_transform(cty, crs(a)); box <- st_as_sfc(st_bbox(ext(a), crs = st_crs(crs(a))))
    cp <- cp[lengths(st_within(cp, box)) > 0, ]; if (!nrow(cp)) { say("%s: no county wholly inside", nm); next }
    x <- rbindlist(parallel::parLapplyLB(cl, split(cp, seq_len(nrow(cp))), function(p, fa, fb) { library(terra); library(data.table); terraOptions(progress = 0, memfrac = 0.02)
      a <- rast(fa); v <- vect(p); a <- crop(a, align(ext(v), a, snap = "out")); b <- crop(rast(fb), a); levels(a) <- NULL; levels(b) <- NULL
      z <- rasterize(v, a, 1)
      data.table(z = values(z, mat = FALSE), a = values(a, mat = FALSE), b = values(b, mat = FALSE))[!is.na(z), .N, by = .(a, b)][, Fips := p$GEOID][] }, fa = fa, fb = fb))
    saveRDS(x, cf) }
  # a county counts only when the copy covers it (regional copies are cut to the region's shape, not to their bounding box)
  cov <- x[, .(Covered = sum(N[!is.na(a) & a > 0 & a < 250 & !is.na(b) & b > 0 & b < 250]) / sum(N)), by = Fips]
  ok <- setdiff(cov[Covered > 0.999, Fips], done); x <- x[Fips %in% ok]
  say("%s: %d counties wholly inside the grid, %d covered by the data and not yet counted", nm, nrow(cov), length(ok)); if (!length(ok)) next
  x[, Copy := nm]; done <- c(done, ok); tabs[[nm]] <- x }
parallel::stopCluster(cl)
x <- rbindlist(tabs); px <- 900 / 1e6   # km2 per pixel
item <- function(name, sel) x[eval(sel), .(Nlcd = sum(N) * px), by = .(Fips, Copy)][, Item := name]
n <- rbind(item("Urbanization", quote(!(a %in% c(DEV, 11L, 12L)) & b %in% DEV)), item("Urbanization (22-24)", quote(!(a %in% c(DEV, 11L, 12L)) & b %in% 22:24)),
           item("Urbanization from fr", quote(a %in% 41:43 & b %in% DEV)), item("Urbanization from cr", quote(a == 82L & b %in% DEV)),
           item("Urbanization from ps", quote(a == 81L & b %in% DEV)), item("Urbanization from rg", quote(a %in% c(52L, 71L) & b %in% DEV)),
           item("Ag Expansion: Cropland", quote(a %in% NAT & b == 82L)), item("Ag Expansion: Pasture", quote(a %in% NAT & b == 81L)),
           item("Ag Contraction: Cropland", quote(a == 82L & b %in% NAT)), item("Ag Contraction: Pasture", quote(a == 81L & b %in% NAT)),
           item("Ag Change: Cropland to Pasture", quote(a == 82L & b == 81L)), item("Ag Change: Pasture to Cropland", quote(a == 81L & b == 82L)),
           item("Developed land 2020", quote(b %in% DEV)), item("Developed land 2020 (22-24)", quote(b %in% 22:24)))
all_c <- unique(x[, .(Fips, Copy)]); n <- n[CJ(Fips = all_c$Fips, Item = unique(n$Item)), on = .(Fips, Item)]; n[is.na(Nlcd), Nlcd := 0]; n[, Copy := all_c$Copy[match(Fips, all_c$Fips)]]
flows <- !grepl("^Developed land", n$Item); n[flows, Nlcd := Nlcd / (Y1 - Y0)]   # flows: km2 a year

# ---- RPA: the calibration step, mean of the futures, km2 a year; urban land at the start of 2020-2030 --------------------------------
co <- readRDS(file.path(CA, "01-rpa-county.rds"))
r <- co[Step == "2012-2020" & Fips %in% all_c$Fips, .(Rpa = mean(PerYear)), by = .(Fips, Item = Group)]
R <- readRDS(file.path(DS, "land-use/rpa-2020/county_landuse_projections_RPA.rds"))
fips <- intersect(all_c$Fips, names(R[[1]][[1]]))
cell <- function(step, from, to, div) rowMeans(vapply(R, function(s) vapply(fips, function(k) s[[step]][[k]][from, to], 0), numeric(length(fips)))) * KM2 / div
r <- rbind(r, rbindlist(lapply(c("fr", "cr", "ps", "rg"), function(u) data.table(Fips = fips, Item = paste("Urbanization from", u), Rpa = cell("2012-2020", u, "ur", 8)))),
           data.table(Fips = fips, Item = "Developed land 2020", Rpa = cell("2020-2030", "ur", "t1", 1)))
r <- rbind(r, r[Item == "Urbanization"][, Item := "Urbanization (22-24)"], r[Item == "Developed land 2020"][, Item := "Developed land 2020 (22-24)"])
m <- merge(n, r, by = c("Fips", "Item"), all.x = TRUE); m[, Name := paste(cty$NAME, cty$STATEFP)[match(Fips, cty$GEOID)]]
say("Counties compared: %d (%d not in RPA)", uniqueN(m$Fips), uniqueN(m[is.na(Rpa) & Item == "Urbanization", Fips]))
fwrite(m[order(Item, Copy, Fips), .(Item, Copy, Fips, Name, NlcdKm2 = round(Nlcd, 4), RpaKm2 = round(Rpa, 4))], file.path(OUT, "02-rpa-vs-nlcd-county.csv"))

# ---- the comparison --------------------------------------------------------------------------------------------------------------
m <- m[!is.na(Rpa)]
tot <- m[, .(Counties = .N, Nlcd = sum(Nlcd), Rpa = sum(Rpa), NlcdOverRpa = sum(Nlcd) / sum(Rpa),
             Correlation = if (.N > 3 && sd(Nlcd) > 0 && sd(Rpa) > 0) cor(Nlcd, Rpa, method = "spearman") else NA_real_), by = Item]
say("\nAll compared counties (flows in km2 a year, 2012-2020; developed land in km2; correlation = Spearman across counties):")
print(tot[, .(Item, Counties, Nlcd = round(Nlcd, 1), Rpa = round(Rpa, 1), NlcdOverRpa = round(NlcdOverRpa, 2), Correlation = round(Correlation, 2))])
# the four RPA regions, by state FIPS
REG <- c(setNames(rep("Pacific Coast", 3), c("06", "41", "53")), setNames(rep("Rocky Mountain", 12), c("04", "08", "16", "20", "30", "31", "32", "35", "38", "46", "49", "56")),
         setNames(rep("South", 13), c("01", "05", "12", "13", "21", "22", "28", "37", "40", "45", "47", "48", "51")))
m[, State := substr(Fips, 1, 2)]; m[, Region := ifelse(State %in% names(REG), REG[State], "North")]
by_tab <- function(by) m[, .(Counties = .N, Nlcd = round(sum(Nlcd), 1), Rpa = round(sum(Rpa), 1), NlcdOverRpa = round(sum(Nlcd) / sum(Rpa), 2),
                             Correlation = round(if (.N > 3 && sd(Nlcd) > 0 && sd(Rpa) > 0) cor(Nlcd, Rpa, method = "spearman") else NA_real_, 2)), by = by]
say("\nBy RPA region:"); print(by_tab(c("Item", "Region"))[order(Item, Region)], nrows = 200)
stt <- by_tab(c("Item", "State")); fwrite(stt[order(Item, State)], file.path(OUT, "02-rpa-vs-nlcd-state.csv"))
say("\nUrbanization by state, NLCD / RPA: %s", paste(stt[Item == "Urbanization"][order(NlcdOverRpa), sprintf("%s %.2f", State, NlcdOverRpa)], collapse = ", "))
say("State NLCD / RPA quantiles (10%%, 50%%, 90%%): %s", paste(stt[Item %in% names(table(stt$Item)), .(q = sprintf("%s %.2f / %.2f / %.2f", Item[1], quantile(NlcdOverRpa, 0.1, na.rm = TRUE), median(NlcdOverRpa, na.rm = TRUE), quantile(NlcdOverRpa, 0.9, na.rm = TRUE))), by = Item]$q, collapse = "; "))
u <- m[Item == "Urbanization"][order(-Rpa)]
say("\nUrbanization by county, km2 a year (the %d largest by RPA):", min(25L, nrow(u)))
print(u[seq_len(min(25L, .N)), .(Name, Copy = substr(Copy, 1, 22), Nlcd = round(Nlcd, 2), Rpa = round(Rpa, 2), NlcdOverRpa = round(Nlcd / Rpa, 2))])
say("\nCounty NLCD / RPA for urbanization: 10%% %.2f, 25%% %.2f, median %.2f, 75%% %.2f, 90%% %.2f", quantile(u[Rpa > 0, Nlcd / Rpa], 0.1), quantile(u[Rpa > 0, Nlcd / Rpa], 0.25),
    median(u[Rpa > 0, Nlcd / Rpa]), quantile(u[Rpa > 0, Nlcd / Rpa], 0.75), quantile(u[Rpa > 0, Nlcd / Rpa], 0.9))
