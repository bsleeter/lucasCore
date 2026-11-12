# To-do 57 step 8: the Reforestation suitability surface of a Lassen Projection Setup result (stage 10), with the historical
# reforesting cells (stage 5) and the fitted effects of the forest covariates. Usage: Rscript dev/reforestation/lassen-surface.R <setup result> <stage 5 result>
suppressMessages({ library(rsyncrosim); library(terra); library(data.table) })
a <- as.integer(commandArgs(TRUE)); L <- ssimLibrary("F:/lucasCore/dev/libs/lassen/Lassen.ssim", summary = FALSE); s <- scenario(L, a[1]); b <- scenario(L, a[2])
mp <- as.data.table(datasheet(s, "lucasCore_OutputSuitabilityMap", lookupsAsFactors = FALSE)); cv <- as.data.table(datasheet(s, "lucasCore_OutputSuitabilityCurve", lookupsAsFactors = FALSE))
f <- mp[Surface == "Reforestation"]; fcol <- grep("File", names(f), value = TRUE)[1]; sf0 <- rast(f[[fcol]][1])
ic <- datasheet(b, "stsim_InitialConditionsSpatial"); S <- rast(ic$StateClassFileName[1]); nl <- datasheet(b, "lucasCore_OutputNlcdAnnual"); n0 <- rast(nl$FileName[nl$Year == 1985])
N <- rast(nl$FileName); ff <- app(N >= 41 & N <= 43, function(x) { k <- which(x[-length(x)] & x[-1]); k <- k[k >= 2]; if (length(k)) 1 else NA })
rf <- S < 100 & n0 %in% c(31, 52, 71, 95) & !is.na(ff); sfm <- resample(sf0, S, method = "near")
park <- sf::st_transform(sf::read_sf("E:/lucasData/study-area/padus-units/padus4-units.gpkg", query = "SELECT * FROM nps_units WHERE Unit_Nm = 'Lassen Volcanic National Park'"), crs(S))
png(file.path("dev", "reforestation", "lassen-reforestation-surface.png"), 2000, 1050, res = 140); layout(matrix(c(1, 1, 2, 1, 1, 3, 1, 1, 4), 3, byrow = TRUE))
pal <- hcl.colors(50, "YlGn", rev = TRUE)
plot(sfm, col = pal, axes = FALSE, mar = c(1, 1, 3, 5), main = "Reforestation suitability (stage 10, Projection Setup) - 0 to 1, where the projection places reforestation", plg = list(title = "suitability"))
plot(ifel(S >= 100 & S <= 999, 1, NA), col = adjustcolor("grey55", 0.55), legend = FALSE, add = TRUE)
plot(as.points(ifel(rf, 1, NA)), add = TRUE, pch = 21, cex = 0.9, bg = "#c0392b", col = "white", lwd = 0.4)
plot(vect(park), add = TRUE, border = "black", lwd = 1.4)
legend("bottomleft", bty = "n", pch = c(15, 21), pt.bg = c(NA, "#c0392b"), col = c(adjustcolor("grey55", 0.55), "white"), pt.cex = c(1.6, 1),
       legend = c("forest at the start (not eligible)", "cells that reforested 1986-2023 (stage 5)"))
CN <- c(BpsForest = "Forest potential (BpS share)", lDistFor = "Distance to forest", ForShare = "Forest share within 1 km")
for (k in names(CN)) { x <- cv[Surface == "Reforestation" & Covariate == k]
  if (!nrow(x)) { plot.new(); title(CN[[k]]); text(0.5, 0.5, "(curve not in this result: rerun the setup)", col = "grey40"); next }
  plot(x$X, x$Effect, type = "l", lwd = 2, col = "#2e7d32", xlab = if (k == "lDistFor") "metres to the nearest forest" else "share", ylab = "effect (log odds)", main = CN[[k]])
  abline(h = 0, col = "grey70", lty = 2) }
invisible(dev.off())
v <- values(sfm, mat = FALSE); r <- values(rf, mat = FALSE) %in% 1; ok <- !is.na(v) & values(S < 100, mat = FALSE) %in% 1
cat(sprintf("surface on eligible cells: median %.2f; on the historical reforesting cells: median %.2f; those cells' share of the top 10%% of eligible land: %.0f%%\n",
            median(v[ok]), median(v[ok & r]), 100 * mean(v[ok & r] >= quantile(v[ok], 0.9))))
