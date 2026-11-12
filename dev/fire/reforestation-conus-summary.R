# Summary of dev/fire/reforestation-conus.R's sample (events.csv, sample.rds): by ecodivision (raster codes: StratumId, mountains 2101 ...)
suppressMessages(library(data.table)); d <- file.path("dev", "fire", "reforestation-conus")
D <- fread(file.path(d, "events.csv")); s <- readRDS(file.path(d, "sample.rds")); hp <- s$ha_pt
en <- unique(fread("F:/lucas-master/Data Sources/FIA/EcoDivision_Strata.csv")[, .(eco = as.integer(StratumId), Ecodivision = StratumName)], by = "eco")
en[eco == 2601, Ecodivision := "Mediterranean Mountains"]
P <- data.table(eco = s$ev, f85 = s$f1985, n85 = s$nat1985)[, .(land_Mha = .N * hp / 1e6, forest85 = sum(f85) * hp / 1e6, nat85 = sum(n85) * hp / 1e6), by = eco]
E <- dcast(D[, .N, by = .(eco, kind)], eco ~ kind, value.var = "N", fill = 0)
setnames(E, c("eco", "harvest", "fire", "lost", "since85")[match(names(E), c("eco", "after harvest", "after fire", "no record: forest lost in the record", "no record: non-forest since 1985"))])
x <- merge(P, E, by = "eco", all.x = TRUE); for (k in c("harvest", "fire", "lost", "since85")) set(x, which(is.na(x[[k]])), k, 0)
x <- merge(x, en, by = "eco", all.x = TRUE)
r <- x[, .(Ecodivision, land_Mha = round(land_Mha, 1), forest85 = round(forest85, 1), nat85 = round(nat85, 1),
           harvest_kha_yr = round(harvest * hp / 1e3 / 38), fire_kha_yr = round(fire * hp / 1e3 / 38),
           unrec_since85_kha_yr = round(since85 * hp / 1e3 / 38), unrec_lost_kha_yr = round(lost * hp / 1e3 / 38),
           unrec_pct_nat85 = round(100 * since85 * hp / 1e6 / nat85, 1), pts = harvest + fire + lost + since85)]
print(r[order(-unrec_since85_kha_yr)])
cat(sprintf("\nCONUS: unrecorded reforestation of land non-forest since 1985 %.1f Mha (%.0f kha a year), %.1f%% of the 1985 natural non-forest; by period (kha a year): %s\n",
  D[kind == "no record: non-forest since 1985", .N] * hp / 1e6, D[kind == "no record: non-forest since 1985", .N] * hp / 1e3 / 38,
  100 * D[kind == "no record: non-forest since 1985", .N] * hp / 1e6 / (sum(s$nat1985) * hp / 1e6),
  paste(D[kind == "no record: non-forest since 1985", .(r = .N * hp / 1e3 / 10), by = .(p = cut(year, c(1985, 1995, 2005, 2015, 2023), labels = c("1986-95", "1996-2005", "2006-15", "2016-23")))][order(p), sprintf("%s %.0f", p, ifelse(p == "2016-23", r * 10 / 8, r))], collapse = "; ")))
cat(sprintf("each sample point %.0f ha; the smallest numbers above rest on a few points (pts)\n", hp))
