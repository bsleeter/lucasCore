# =============================================================================
# 21-placement-national.R - to-do 3: do the national events fall where FIA plots found heavy mortality? By ecodivision.
# =============================================================================
# The fitted lines match FIA's amount of heavy mortality by construction; this checks placement, as 09-placement.R did for the
# two test pyromes. Per clean remeasured softwood stand (the table 18-fit-lines-by-ecodivision.R caches, with the plot's public
# coordinates from the PLOT tables; they are fuzzed by up to about 1.6 km, which blurs every number here): the share of the
# eligible forest within --radius (1000 m) of the point that the rule flagged in the stand's years between visits, against the
# stand's share of live carbon killed. Western ecodivisions only (the event applies there). Read-only.
# Usage: Rscript dev/mortality/21-placement-national.R <FIA DataMart folder> <fia-stands.rds> <rule-national-300m.tif> <out csv> [--radius=1000]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; dm <- pos[1]; RAD <- as.numeric(opt("radius", 1000)); options(width = 220); terraOptions(progress = 0)
WEST <- c("240", "260", "310", "320", "330", "340", "M240", "M260", "M310", "M330", "M340")
m <- readRDS(pos[2])[clean == TRUE & fortyp_grp < 400L & ecodiv %in% WEST][, kind := fifelse(fortyp_grp == 180L, "pinyon/juniper", "conifer")][, `:=`(y1 = MEASYEAR, y0 = MEASYEAR - pmax(1L, as.integer(round(REMPER))))]
xy <- rbindlist(lapply(unique(m$state), function(s) fread(file.path(dm, sprintf("%s_PLOT.csv", s)), select = c("CN", "LAT", "LON"), colClasses = list(character = "CN"))))
m <- merge(m, xy[, .(PLT_CN = CN, LAT, LON)], by = "PLT_CN")[!is.na(LAT) & !is.na(LON)]
r <- rast(pos[3]); yrs <- as.integer(names(r)[-1]); m <- m[y0 >= min(yrs) - 1 & y1 <= max(yrs)]
v <- buffer(project(vect(as.matrix(m[, .(LON, LAT)]), crs = "EPSG:4269"), crs(r)), RAD)
x <- as.matrix(extract(r, v, fun = sum, na.rm = TRUE)[, -1]); m[, forest := x[, 1]]; fl <- x[, -1, drop = FALSE]
m[, flagged := vapply(seq_len(.N), function(i) sum(fl[i, yrs > y0[i] & yrs <= y1[i]]), 0)]; d <- m[forest >= 300][, share := flagged / forest]
fwrite(d[, .(PLT_CN, CONDID, kind, ecodiv, fortyp_grp, y0, y1, frac, forest, flagged, share)], pos[4])
one <- function(d) { top <- d$share >= quantile(d$share, 0.9) & d$share > 0; k <- d$frac >= 0.7
  data.table(stands = nrow(d), over70 = sum(k), rule_pct = round(100 * sum(d$flagged) / sum(d$forest), 2), fia_pct = round(100 * mean(k), 2), spearman = round(suppressWarnings(cor(d$share, d$frac, method = "spearman")), 2),
             around_under10 = round(100 * d[frac < 0.1, sum(flagged) / sum(forest)], 2), around_10_30 = round(100 * d[frac >= 0.1 & frac < 0.3, sum(flagged) / sum(forest)], 2), around_30_70 = round(100 * d[frac >= 0.3 & frac < 0.7, sum(flagged) / sum(forest)], 2),
             around_over70 = if (any(k)) round(100 * d[k, sum(flagged) / sum(forest)], 2) else NA_real_, over70_with_any_flag_pct = if (any(k)) round(100 * mean(d$share[k] > 0)) else NA_real_,
             top_tenth_over70_pct = round(100 * mean(k[top]), 1), top_tenth_holds_pct = if (any(k)) round(100 * sum(top & k) / sum(k)) else NA_real_) }
cat(sprintf("%d clean softwood stands in the West with at least %d eligible pixels within %g m and both visits inside %d-%d\n", nrow(d), 300, RAD, min(yrs), max(yrs)))
cat("columns: rule_pct = share of the forest around the stands flagged between visits; around_* = the same around stands by their share killed;\n  top_tenth_* = of the tenth of stands with the most flagged around them, the share over the 70% line, and the share of all over-70% stands they hold\n\n")
res <- rbind(cbind(kind = "conifer", ecodiv = "West", one(d[kind == "conifer"])), cbind(kind = "pinyon/juniper", ecodiv = "West", one(d[kind == "pinyon/juniper"])), d[, one(.SD), by = .(kind, ecodiv)][stands >= 100][order(kind, -over70)])
print(res, nrows = 60); fwrite(res, sub("[.]csv$", "-summary.csv", pos[4]))
