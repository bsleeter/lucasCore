# To-do 57 step 4: where the Lassen Build's reforesting cells are (stage 5 result), against the park and the NLCD start class.
# Usage: Rscript dev/reforestation/lassen-map.R <result id> -> dev/reforestation/lassen-step4.png
suppressMessages({ library(rsyncrosim); library(terra); library(data.table) })
id <- as.integer(commandArgs(TRUE)[1]); L <- ssimLibrary("F:/lucasCore/dev/libs/lassen/Lassen.ssim", summary = FALSE); s <- scenario(L, id)
ic <- datasheet(s, "stsim_InitialConditionsSpatial"); lc <- datasheet(s, "lucasCore_OutputLandCoverLayers"); nl <- datasheet(s, "lucasCore_OutputNlcdAnnual")
S <- rast(ic$StateClassFileName[1]); n0 <- rast(nl$FileName[nl$Year == 1985]); RT <- rast(lc$ReforestTypeFileName[1]); Bf <- rast(lc$BpsForestShareFileName[1])
N <- rast(nl$FileName); first <- app(N >= 41 & N <= 43, function(x) { k <- which(x[-length(x)] & x[-1]); k <- k[k >= 2]; if (length(k)) k[1] - 1 else NA })
rf <- (S < 100) & (S %in% c(31, 51:55, 71:73, 92:96)) & !is.na(first) & (n0 %in% c(31, 52, 71, 95))
park <- sf::st_transform(sf::read_sf("E:/lucasData/study-area/padus-units/padus4-units.gpkg", query = "SELECT * FROM nps_units WHERE Unit_Nm = 'Lassen Volcanic National Park'"), crs(S))
v <- data.table(S = values(S, mat = FALSE), n0 = values(n0, mat = FALSE), rf = values(rf, mat = FALSE), first = values(first, mat = FALSE), bf = values(Bf, mat = FALSE),
                inpark = !is.na(values(rasterize(vect(park), S), mat = FALSE)))
cat(sprintf("reforesting cells: %d (%d inside the park); start class: %s; BpS forest share median %.2f; first forest years after 1985: %s\n", sum(v$rf %in% 1), sum(v$rf %in% 1 & v$inpark),
            paste(v[rf %in% 1, .N, by = n0][, sprintf("NLCD %d: %d", n0, N)], collapse = ", "), v[rf %in% 1, median(bf, na.rm = TRUE)], paste(v[rf %in% 1, range(first)], collapse = "-")))
png(file.path("dev", "reforestation", "lassen-step4.png"), 1400, 900, res = 130)
cls <- ifel(S >= 100 & S <= 999, 1, ifel(S >= 2000, 2, ifel(rf, 3, 4)))
plot(cls, col = c("#4a7c3a", "#d9822b", "#c0392b", "#d9d4c7"), legend = FALSE, axes = FALSE, mar = c(1, 1, 3, 9), main = sprintf("Lassen 150 m, stage 5 (result %d): reforesting cells start as their 1985 class", id))
plot(vect(park), add = TRUE, border = "black", lwd = 1.5)
legend("topright", inset = c(-0.2, 0), xpd = TRUE, bty = "n", fill = c("#4a7c3a", "#d9822b", "#c0392b", "#d9d4c7"), legend = c("forest at start", "disturbed at start", "reforests later", "other non-forest"))
invisible(dev.off()); cat("dev/reforestation/lassen-step4.png\n")
