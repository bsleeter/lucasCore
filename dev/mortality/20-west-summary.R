suppressPackageStartupMessages({library(terra); library(data.table)}); terraOptions(progress = 0); options(width = 220)
O <- "F:/lucasCore/dev/libs/mortality-national"; r <- rast(file.path(O, "rule-national-300m.tif")); eco <- vect(file.path(O, "ecodiv.gpkg")); L <- fread(file.path(O, "lines-west.csv"))
tab <- fread(file.path(O, "rule-national-fitted.csv"))[ecodiv %in% L$ecodiv & group != 180]
by <- tab[, .(forest_km2 = sum(forest_km2), flagged_km2 = sum(flagged_km2)), by = Year][, rate_pct := round(100 * flagged_km2 / forest_km2, 3)]; print(by[, lapply(.SD, round, 3)], nrows = 40)
e <- tab[Year > 1990, .(forest_first_km2 = round(sum(forest_km2[Year == 1991])), flagged_km2 = round(sum(flagged_km2)), mean_pct_yr = round(100 * sum(flagged_km2) / sum(forest_km2), 3), peak_year = .SD[, .(f = sum(flagged_km2)), by = Year][which.max(f), Year]), by = ecodiv][order(-flagged_km2)]
e[, cum_pct := round(100 * flagged_km2 / forest_first_km2, 1)]; print(merge(e, L, by = "ecodiv")[order(-flagged_km2)]); cat(sprintf("West 1991-2022: %.0f km2 flagged of %.0f km2 eligible in 1991 (%.1f%%); mean %.3f%% a year\n", sum(e$flagged_km2), sum(e$forest_first_km2), 100 * sum(e$flagged_km2) / sum(e$forest_first_km2), 100 * tab[Year > 1990, sum(flagged_km2) / sum(forest_km2)]))
pj <- fread(file.path(O, "rule-national-fitted.csv"))[group == 180, sum(flagged_km2)]; cat("pinyon/juniper flagged at the conifer lines (not part of the decision):", round(pj), "km2\n")
fwrite(by, file.path(O, "west-by-year.csv")); fwrite(e, file.path(O, "west-by-ecodivision.csv"))
yrs <- as.character(1991:2022); west <- eco[eco$StrtmId %in% c(240, 260, 310, 320, 330, 340, 2401, 2601, 3101, 3301, 3401), ]; rw <- crop(r, ext(west))
f <- aggregate(rw[["forest"]], 10, sum, na.rm = TRUE); tot <- aggregate(app(rw[[yrs]], sum), 10, sum, na.rm = TRUE); sh <- ifel(f >= 500, 100 * tot / f, NA)   # 3 km cells with at least 5% eligible conifer forest
per <- list(`1991-2000` = 1991:2000, `2001-2010` = 2001:2010, `2011-2022` = 2011:2022)
br <- c(0, 1, 2, 5, 10, 20, 40, 100); cols <- c("#e8e4d8", "#fde0a6", "#fdb863", "#f4873b", "#d94b2b", "#a51a1f", "#5c0a12")
png(file.path(O, "west-events-1991-2022.png"), 2400, 2000, res = 200); par(mar = c(1, 1, 3, 1))
plot(sh, breaks = br, col = cols, axes = FALSE, mar = c(1, 1, 3, 6), main = "Drought and insect events 1991-2022: % of eligible conifer forest flagged (3 km cells)", plg = list(title = "% flagged"), colNA = "white")
lines(west, col = "grey30", lwd = 0.8); dev.off()
png(file.path(O, "west-events-by-period.png"), 3600, 1500, res = 200); par(mfrow = c(1, 3))
for (n in names(per)) { s <- ifel(f >= 500, 100 * aggregate(app(rw[[as.character(per[[n]])]], sum), 10, sum, na.rm = TRUE) / f, NA); plot(s, breaks = br, col = cols, axes = FALSE, main = n, legend = n == "2011-2022", colNA = "white", mar = c(1, 1, 3, 5)); lines(west, col = "grey30", lwd = 0.6) }
dev.off()
png(file.path(O, "west-events-by-year.png"), 2000, 1000, res = 200); par(mar = c(4, 4.5, 2, 1)); b <- by[Year > 1990]; barplot(b$flagged_km2, names.arg = b$Year, las = 2, col = "#d94b2b", border = NA, ylab = "km2 flagged", main = "Western conifer forest flagged by year"); dev.off()
