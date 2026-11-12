# To-do 57: how big is reforestation across CONUS? A random sample of 30 m pixels, read from the national Annual NLCD (1985-2025),
# LCMS Change (1985-2023) and MTBS burn severity (1985-2023) in F:/lucas-master/Data Sources. An event: a natural non-forest pixel
# (NLCD 31, 52, 71, 95) that becomes forest (41-43, 90) two years running and is forest in at least 2/3 of the years after, 1986-2023
# (the regrowth rule's persistence test, here per pixel). Each pixel's first event is sorted by what the record shows before it, from
# 1985: a fire (MTBS 2-4, LCMS 6-7) or harvest (LCMS 9 Tree Removal) - covered already by post-fire return and harvest regrowth - or
# nothing recorded: non-forest since 1985 (disturbance before 1985, or encroachment) or forest earlier in the record and lost with no
# recorded cause. Areas are the sample share x the ecodivision's land area.
# Usage: Rscript dev/fire/reforestation-conus.R [n points, default 3e6]
suppressMessages({ library(terra); library(data.table); library(parallel) })
DS <- "F:/lucas-master/Data Sources"; out <- file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))), "reforestation-conus")
dir.create(out, showWarnings = FALSE); n <- as.numeric(commandArgs(TRUE)[1]); if (is.na(n)) n <- 3e6
yrs <- 1985:2025; FOR <- c(41:43, 90); NAT <- c(31, 52, 71, 95)
eco <- rast(file.path(DS, "FIA", "Ecodivisions_30m.tif")); en <- fread(file.path(DS, "FIA", "EcoDivision_Strata.csv"))
set.seed(57); e <- ext(eco); xy <- cbind(runif(n, e$xmin, e$xmax), runif(n, e$ymin, e$ymax))
ev <- extract(eco, xy)[, 1]; keep <- !is.na(ev) & ev > 0; xy <- xy[keep, ]; ev <- ev[keep]
frac <- mean(keep); cat(sprintf("%d of %d points on CONUS land (ecodivision map): %.0f%%\n", nrow(xy), n, 100 * frac))
files <- c(setNames(vapply(yrs, function(y) list.files(file.path(DS, "NLCD", "Annual NLCD"), sprintf("^Annual_NLCD_LndCov_%d_CU_C1V.[.]tif$", y), full.names = TRUE)[1], ""), paste0("n", yrs)),
           setNames(vapply(1985:2023, function(y) list.files(file.path(DS, "LCMS", "v2025-11", "Change_Annual", y), "Change_.*[.]tif$", full.names = TRUE)[1], ""), paste0("l", 1985:2023)),
           setNames(file.path(DS, "MTBS", "Burn Severity", sprintf("mtbs_CONUS_%d.tif", 1985:2023)), paste0("m", 1985:2023)),
           bps = file.path(DS, "BpS", "LF2020_BPS_CONUS", "LF2020_BPS_CONUS", "Tif", "LF2020_BPS_CONUS.tif"))
stopifnot(all(file.exists(files)))
cl <- makeCluster(20); clusterExport(cl, "xy")
V <- parLapply(cl, files, function(f) { library(terra); terraOptions(progress = 0); { r <- rast(f); levels(r) <- NULL; as.integer(extract(r, xy)[, 1]) } }); stopCluster(cl)
V <- as.data.table(V); setnames(V, names(files))
N <- as.matrix(V[, paste0("n", yrs), with = FALSE]); L <- as.matrix(V[, paste0("l", 1985:2023), with = FALSE]); M <- as.matrix(V[, paste0("m", 1985:2023), with = FALSE])
f <- matrix(N %in% FOR, nrow(N)); nat <- matrix(N %in% NAT, nrow(N)); ny <- length(yrs)
dist <- matrix(L %in% c(6, 7, 9) | M %in% 2:4, nrow(L)); cutm <- matrix(L %in% 9, nrow(L))
evy <- rep(NA_integer_, nrow(N)); flick <- rep(FALSE, nrow(N))
for (t in 2:which(yrs == 2023)) { c0 <- is.na(evy) & nat[, t - 1] & f[, t] & f[, t + 1]; if (!any(c0)) next
  sh <- rowMeans(f[c0, t:ny, drop = FALSE]) >= 2 / 3; i <- which(c0); evy[i[sh]] <- t; flick[i[!sh]] <- TRUE }
i <- which(!is.na(evy)); t <- evy[i]
before <- function(X) vapply(seq_along(i), function(j) any(X[i[j], seq_len(t[j] - 1)]), TRUE)
fb <- before(dist & !cutm); cb <- before(cutm); wasF <- vapply(seq_along(i), function(j) any(f[i[j], seq_len(t[j] - 1)]), TRUE)
cut_after <- vapply(seq_along(i), function(j) any(cutm[i[j], t[j]:ncol(cutm)]), TRUE)
D <- data.table(pt = i, x = xy[i, 1], y = xy[i, 2], eco = ev[i], year = yrs[t], start = N[i, 1], bps = V$bps[i], cut_after, kind = fifelse(fb, "after fire", fifelse(cb, "after harvest", fifelse(wasF, "no record: forest lost in the record", "no record: non-forest since 1985"))))
# area: each sample point stands for CONUS land area / points on land; CONUS land area from the ecodivision map's pixel count
land_px <- global(!is.na(eco) & eco > 0, "sum", na.rm = TRUE)[[1]]; ha_pt <- land_px * 0.09 / nrow(xy)
fwrite(D, file.path(out, "events.csv")); saveRDS(list(ev = ev, f1985 = f[, 1], f2023 = f[, which(yrs == 2023)], nat1985 = nat[, 1], nat2005 = nat[, which(yrs == 2005)], flick = flick & is.na(evy), ha_pt = ha_pt), file.path(out, "sample.rds"))
cat(sprintf("each point: %.0f ha; CONUS land %.1f Mha; NLCD forest %.1f Mha (1985), %.1f Mha (2023); natural non-forest %.1f Mha (1985)\n", ha_pt, land_px * 0.09 / 1e6,
            sum(f[, 1]) * ha_pt / 1e6, sum(f[, which(yrs == 2023)]) * ha_pt / 1e6, sum(nat[, 1]) * ha_pt / 1e6))
cat(sprintf("reforestation events 1986-2023 (first per pixel): %.2f Mha (%d points); failed the persistence test: %.2f Mha\n", nrow(D) * ha_pt / 1e6, nrow(D), sum(flick & is.na(evy)) * ha_pt / 1e6))
print(D[, .(Mha = round(.N * ha_pt / 1e6, 2), kha_per_yr = round(.N * ha_pt / 1e3 / 38, 1), points = .N), by = kind][order(-Mha)])
cat("\nno record (both kinds), by ecodivision: Mha, kha a year, and % of the ecodivision's 1985 natural non-forest\n")
nr <- D[kind %like% "^no record"]
bye <- merge(nr[, .(Mha = .N * ha_pt / 1e6), by = eco], data.table(eco = ev, nat = nat[, 1])[, .(nat_Mha = sum(nat) * ha_pt / 1e6), by = eco], by = "eco")
bye[, `:=`(Ecodivision = en$StratumName[match(eco, en$ecodiv)], kha_per_yr = round(Mha * 1e3 / 38, 1), pct_of_nat = round(100 * Mha / nat_Mha, 1), Mha = round(Mha, 3), nat_Mha = round(nat_Mha, 2))]
print(bye[order(-Mha), .(Ecodivision, Mha, kha_per_yr, nat_Mha, pct_of_nat)])
cat("\nno record, non-forest since 1985: by NLCD class in 1985 and period (Mha)\n")
x <- nr[kind == "no record: non-forest since 1985"]
print(dcast(x[, .(Mha = round(.N * ha_pt / 1e6, 2)), by = .(NLCD_1985 = c(`31` = "Barren", `52` = "Shrub", `71` = "Grass", `95` = "Emergent wetland")[as.character(start)],
        period = cut(year, c(1985, 1995, 2005, 2015, 2023), labels = c("1986-95", "1996-2005", "2006-15", "2016-23")))], NLCD_1985 ~ period, value.var = "Mha", fill = 0))
cat(sprintf("\nunrecorded reforestation by period (Mha a year): %s\n", paste(nr[, .(r = .N * ha_pt / 1e6), by = .(p = cut(year, c(1985, 1995, 2005, 2015, 2023)))][order(p), sprintf("%s %.3f", p, r / 10)], collapse = "; ")))
