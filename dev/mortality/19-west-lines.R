# western lines: own where an ecodivision has >= 20 stands over the line and a fit; the western pooled line elsewhere
suppressPackageStartupMessages(library(data.table)); O <- commandArgs(TRUE)[1]; m <- readRDS(file.path(O, "fia-stands.rds")); R <- fread(file.path(O, "rule-national-lines.csv"))
WEST <- c("240", "260", "310", "320", "330", "340", "M240", "M260", "M310", "M330", "M340"); yr <- range(R$Year)
wk <- m[clean == TRUE & fortyp_grp < 400L & fortyp_grp != 180L & ecodiv %in% WEST][, `:=`(y1 = MEASYEAR, y0 = MEASYEAR - pmax(1L, as.integer(round(REMPER))) + 1L)][y0 >= yr[1] & y1 <= yr[2]]
rk <- R[group != 180 & ecodiv %in% WEST, .(rate = sum(flagged_km2) / sum(forest_km2)), by = .(line, Year)]; cum <- rk[order(Year), .(Year, cs = cumsum(rate)), by = line]; L <- sort(unique(cum$line))
sh <- vapply(L, function(l) { cs <- cum[line == l]; v <- c(0, cs$cs); names(v) <- c(min(cs$Year) - 1L, cs$Year); mean(v[as.character(wk$y1)] - v[as.character(wk$y0 - 1L)]) }, 0); tg <- mean(wk$frac >= 0.7)
i <- max(which(sh >= tg)); pooled <- round(L[i] + (sh[i] - tg) / (sh[i] - sh[i + 1]) * (L[i + 1] - L[i]), 3)
cat(sprintf("West pooled: %d stands, %d over 70%% (%.2f%%); rule share by line (%%): %s; pooled line %.3f\n", nrow(wk), sum(wk$frac >= 0.7), 100 * tg, paste(sprintf("%s=%.2f", L, 100 * sh), collapse = " "), pooled))
f <- fread(file.path(O, "lines-by-ecodivision.csv"))[kind == "conifer" & ecodiv %in% WEST]
out <- data.table(ecodiv = WEST)[, own := f$line[match(ecodiv, f$ecodiv)]][, n := f$over70[match(ecodiv, f$ecodiv)]][, `:=`(line = fifelse(!is.na(own) & !is.na(n) & n >= 20, own, pooled), basis = fifelse(!is.na(own) & !is.na(n) & n >= 20, "own", "west pooled"))]
print(out); fwrite(out[, .(ecodiv, line, basis)], file.path(O, "lines-west.csv"))
