# To-do 57: how the narrower reforestation design would start the Mount St Helens area (1980 eruption). Box around the mountain and the
# blast zone to its north (about 46.13-46.40 N, 122.45-121.95 W), 30 m Annual NLCD 1985-2025 and LANDFIRE BpS 2020. Each pixel that is
# natural non-forest in 1985 is sorted by its first forest year (two years running, forest in 2/3 of the years after, as in
# reforestation-conus.R): by 2004 (any-year rule: forest in 1985), 2005 on (late: starts as its 1985 class, reforests by transition),
# or never.
suppressMessages({ library(terra); library(data.table) })
DS <- "F:/lucas-master/Data Sources"; yrs <- 1985:2025; FOR <- c(41:43, 90); NAT <- c(31, 52, 71, 95)
nf <- vapply(yrs, function(y) list.files(file.path(DS, "NLCD", "Annual NLCD"), sprintf("^Annual_NLCD_LndCov_%d_CU_C1V.[.]tif$", y), full.names = TRUE)[1], "")
r0 <- rast(nf[1]); bx <- project(vect(ext(-122.45, -121.95, 46.13, 46.40), crs = "EPSG:4326"), crs(r0)); e <- ext(bx)
N <- sapply(nf, function(f) { r <- rast(f); levels(r) <- NULL; as.integer(values(crop(r, e))) }); colnames(N) <- yrs
bt <- fread(file.path(DS, "BpS", "LF2020_BPS_CONUS", "LF2020_BPS_CONUS", "CSV_Data", "LF2020_BPS.csv"))
b <- rast(file.path(DS, "BpS", "LF2020_BPS_CONUS", "LF2020_BPS_CONUS", "Tif", "LF2020_BPS_CONUS.tif")); levels(b) <- NULL
bv <- as.integer(values(resample(crop(b, e, snap = "out"), crop(r0, e), method = "near")))
f <- matrix(N %in% FOR, nrow(N)); ny <- length(yrs); first <- rep(NA_integer_, nrow(N))
for (t in 2:(ny - 1)) { c0 <- is.na(first) & f[, t] & f[, t + 1]; if (!any(c0)) next
  i <- which(c0); first[i[rowMeans(f[i, t:ny, drop = FALSE]) >= 2 / 3]] <- yrs[t] }
ha <- 0.09; n85 <- N[, 1]
cat(sprintf("box: %.0f km2; forest in 1985 %.0f km2; natural non-forest in 1985 %.0f km2\n", nrow(N) * ha / 100, sum(n85 %in% FOR) * ha / 100, sum(n85 %in% NAT) * ha / 100))
g <- bt$GROUPVEG[match(bv, bt$VALUE)]
D <- data.table(nlcd85 = c(`31` = "Barren", `52` = "Shrub", `71` = "Grass", `95` = "Emergent wetland")[as.character(n85)], first, bps = g)[n85 %in% NAT]
D[, group := fcase(is.na(first), "never forest by 2025", first <= 2004, "forest by 2004: forest in 1985 (any-year rule)", default = "forest from 2005: starts as 1985 class (late)")]
D[, bpsf := fifelse(bps %in% c("Conifer", "Conifer-Hardwood", "Hardwood", "Hardwood-Conifer"), "BpS forest", "BpS other")]
cat("\nnatural non-forest in 1985, by group (km2):\n"); print(D[, .(km2 = round(.N * ha / 100, 1), pct = round(100 * .N / nrow(D))), by = group][order(group)])
cat("\nby group and 1985 class (km2):\n"); print(dcast(D[, .N, by = .(group, nlcd85)], group ~ nlcd85, value.var = "N", fill = 0)[, lapply(.SD, function(v) if (is.numeric(v)) round(v * ha / 100, 1) else v)])
cat("\nby group and BpS (km2):\n"); print(dcast(D[, .N, by = .(group, bpsf)], group ~ bpsf, value.var = "N", fill = 0)[, lapply(.SD, function(v) if (is.numeric(v)) round(v * ha / 100, 1) else v)])
cat("\nfirst forest year, by 5 years (km2):\n"); print(D[!is.na(first), .(km2 = round(.N * ha / 100, 1)), by = .(period = paste0(5 * (first %/% 5), "-", 5 * (first %/% 5) + 4))][order(period)])
grp <- rast(crop(r0, e)); levels(grp) <- NULL; v <- rep(NA_integer_, nrow(N)); v[n85 %in% FOR] <- 0L
v[n85 %in% NAT] <- match(D$group, c("forest by 2004: forest in 1985 (any-year rule)", "forest from 2005: starts as 1985 class (late)", "never forest by 2025"))
values(grp) <- v; writeRaster(grp, file.path("dev", "fire", "st-helens-groups.tif"), overwrite = TRUE, datatype = "INT1U")
