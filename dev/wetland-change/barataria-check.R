# To-do 2 independent check: the split DSWE rule against the marsh loss mapped in the lucasWet Barataria model
# (historical transition maps for 2001-2006, 2006-2010 and 2010-2016, 30 m).
# Usage: Rscript barataria-check.R <cache dir>     (writes barataria-check.csv, barataria-referee.csv, barataria-yearly.csv)
suppressMessages({ library(terra); library(data.table) }); options(width = 220)
cache <- commandArgs(trailingOnly = TRUE)[1]; t0 <- Sys.time(); HA <- 0.09
B <- "D:/lucasWet/models/Barataria LocalCH4 GWP-100.ssim.data"
API <- "https://apps.usgs.gov/watermap/api/v1/stac/collections/dswe-proportions/items"
NLCD <- "E:/lucasData/land-cover/nlcd-annual/Annual_NLCD_LndCov_%d_CU_C1V2.tif"
YEARS <- 1999:2021; EP <- c(2001, 2006, 2010, 2016)
ic <- rast(file.path(B, "Scenario-200/stsim_InitialConditionsSpatial/LUCAS_2001.tif"))
nl <- function(y) { r <- rast(sprintf(NLCD, y)); crs(r) <- "EPSG:5070"; r }
tmpl <- crop(nl(2021), ext(ic)); n <- ncell(tmpl)
onto <- function(r) values(resample(r, tmpl, method = "near"), mat = FALSE)   # the model grid sits a few metres off NLCD's
IC <- onto(ic); IN <- !is.na(IC)
# model state classes: 11 water, 13 and 14 water that was wetland, 90 95 96 wetland, 97 unconsolidated shore, 98 99 unvegetated wetland
WATER <- c(11, 13, 14); VEG <- c(90, 95, 96); UNVEG <- c(98, 99); WETALL <- c(VEG, UNVEG, 97)
tmf <- list.files(file.path(B, "Scenario-204/stsim_TransitionSpatialMultiplier"), "tif$", full.names = TRUE)
tm <- data.table(File = tmf); tm[, c("Y1", "Y2", "A", "Z") := tstrsplit(sub(".*historical-(\\d+)-to-(\\d+)-sc-(\\d+)-to-(\\d+).tif", "\\1 \\2 \\3 \\4", File), " ", type.convert = TRUE)]
tm[, Kind := fifelse(A %in% WETALL & Z %in% WATER, 1L, fifelse(A %in% WATER & Z %in% WETALL, 2L, fifelse(A %in% VEG & Z %in% UNVEG, 3L,
  fifelse(!(A %in% c(WATER, WETALL)) & Z %in% WATER, 4L, fifelse(A %in% WATER & !(Z %in% c(WATER, WETALL)), 5L, 0L)))))]
KIND <- c("Wetland to water", "Water to wetland", "Wetland to unvegetated", "Other land to water", "Water to other land")
model <- lapply(EP[-4], function(y1) { k <- integer(n); for (i in which(tm$Y1 == y1 & tm$Kind > 0)) { v <- onto(rast(tm$File[i])); k[!is.na(v) & v > 0] <- tm$Kind[i] }; k })
cat(sprintf("model maps read (%.1f min)\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
# ---- DSWE open water, one cached crop a year ----
bb <- as.vector(ext(project(as.polygons(ext(tmpl), crs = "EPSG:5070"), "EPSG:4326")))
j <- jsonlite::fromJSON(sprintf("%s?limit=50&bbox=%s&datetime=2021-01-01T00:00:00Z/2021-12-31T23:59:59Z", API, paste(bb[c(1, 3, 2, 4)], collapse = ",")), simplifyVector = FALSE)
href <- vapply(j$features, function(f) f$assets$dswe_proportion$href, ""); cat(length(href), "DSWE tiles;", n, "cells\n")
open <- function(y) { f <- file.path(cache, sprintf("dswe-barataria-%d.tif", y))
  if (!file.exists(f)) { parts <- lapply(sub("_2021_Props", sprintf("_%d_Props", y), href), function(u) { r <- rast(paste0("/vsicurl/", u)); crs(r) <- "EPSG:5070"
      if (is.null(intersect(ext(r), ext(tmpl)))) return(NULL); extend(crop(r[[2]], tmpl), tmpl) })
    parts <- Filter(Negate(is.null), parts); x <- if (length(parts) > 1) do.call(merge, parts) else parts[[1]]
    writeRaster(x, f, datatype = "INT1U", NAflag = 255, overwrite = TRUE) }
  values(rast(f), mat = FALSE) }
# ---- the split rule: hold 5 years on the wetland side, two lines (70 / 30) elsewhere ----
wv <- function(y) values(crop(nl(y), tmpl), mat = FALSE) %in% c(90, 95)
WET <- IC %in% WETALL | wv(2001) | wv(2021)
z <- function(v) { v[is.na(v)] <- 0; v }
o1 <- open(1999); o2 <- open(2000); o3 <- open(2001); init <- (z(o1) + z(o2) + z(o3)) / pmax(1, (!is.na(o1)) + (!is.na(o2)) + (!is.na(o3))) >= 50
m3 <- list(); m3[["2001"]] <- (z(o1) + z(o2) + z(o3)) / pmax(1, (!is.na(o1)) + (!is.na(o2)) + (!is.na(o3)))
Sh <- init; run <- integer(n); St <- init                      # held state (as confirmed), two-line state
P <- lapply(EP, function(t) init); names(P) <- EP              # state at each epoch year, with held changes dated to their first year
yearly <- list(); prev <- list(o2, o3)
for (y in 2001:2021) { o <- if (y == 2001) o3 else open(y)
  if (y > 2001) { new <- rep(NA, n); new[!St & o >= 70] <- TRUE; new[St & o <= 30] <- FALSE; ch <- !is.na(new); St[ch] <- new[ch] }
  for (t in EP) if (y == t) P[[as.character(t)]][!WET] <- St[!WET]
  raw <- o >= 50; d <- !is.na(raw) & raw != Sh; run[d] <- run[d] + 1L; run[!is.na(raw) & !d] <- 0L
  f <- run >= 5L; if (any(f)) { Sh[f] <- !Sh[f]; run[f] <- 0L; s0 <- y - 4L
    for (t in EP) if (s0 <= t) { k <- f & WET; P[[as.character(t)]][k] <- !P[[as.character(t)]][k] }
    yearly[[length(yearly) + 1]] <- data.table(Year = s0, ToWaterKha = sum(f & WET & Sh & IN) * HA / 1000, ToLandKha = sum(f & WET & !Sh & IN) * HA / 1000) }
  if (y %in% c(2006, 2010, 2016) + 1L) { a <- prev[[1]]; b <- prev[[2]]; m3[[as.character(y - 1L)]] <- (z(a) + z(b) + z(o)) / pmax(1, (!is.na(a)) + (!is.na(b)) + (!is.na(o))) }
  prev <- list(prev[[2]], o)
  if (y %% 5 == 0) cat(sprintf("  %d done (%.1f min)\n", y, as.numeric(difftime(Sys.time(), t0, units = "mins")))) }
fwrite(rbindlist(yearly)[order(Year)], "dev/wetland-change/barataria-yearly.csv")
# ---- compare by epoch ----
res <- list(); ref <- list()
for (e in 1:3) { a <- P[[e]]; b <- P[[e + 1]]; k <- model[[e]]; ep <- paste(EP[e], EP[e + 1], sep = "-")
  dl <- IN & WET & !a & b; dg <- IN & WET & a & !b; dol <- IN & !WET & !a & b; dog <- IN & !WET & a & !b
  kha <- function(x) sum(x) * HA / 1000
  res[[e]] <- data.table(Epoch = ep, Change = c("Wetland side to water", "Water to wetland side", "Other land to water", "Water to other land"),
    ModelKha = c(kha(k == 1L), kha(k == 2L), kha(k == 4L), kha(k == 5L)), ModelUnvegKha = c(kha(k == 3L), NA, NA, NA),
    RuleKha = c(kha(dl), kha(dg), kha(dol), kha(dog)), BothKha = c(kha(dl & k == 1L), kha(dg & k == 2L), kha(dol & k == 4L), kha(dog & k == 5L)),
    RuleOnModelUnvegKha = c(kha(dl & k == 3L), NA, NA, NA))
  o_a <- m3[[as.character(EP[e])]]; o_b <- m3[[as.character(EP[e + 1])]]; o_end <- m3[["2016"]]
  ref[[e]] <- rbindlist(lapply(1:5, function(i) { s <- IN & k == i; data.table(Epoch = ep, ModelChange = KIND[i], Kha = kha(s), OpenStart = mean(o_a[s]), OpenEnd = mean(o_b[s]), Open2016 = mean(o_end[s]),
    PctOver50End = 100 * mean(o_b[s] >= 50), PctOver70End = 100 * mean(o_b[s] >= 70)) })) }
res <- rbindlist(res); ref <- rbindlist(ref)
tot <- res[, .(Epoch = "2001-2016", ModelKha = sum(ModelKha), ModelUnvegKha = sum(ModelUnvegKha), RuleKha = sum(RuleKha), BothKha = sum(BothKha), RuleOnModelUnvegKha = sum(RuleOnModelUnvegKha)), by = Change]
a <- P[["2001"]]; b <- P[["2016"]]
anyk <- function(i) model[[1]] == i | model[[2]] == i | model[[3]] == i; ml <- IN & anyk(1L) & !(model[[3]] == 2L); mg <- IN & anyk(2L) & !(model[[3]] == 1L)
net <- data.table(Epoch = "2001-2016 whole period, any epoch", Change = c("Wetland side to water", "Water to wetland side"), ModelKha = c(sum(ml), sum(mg)) * HA / 1000,
  RuleKha = c(sum(IN & WET & !a & b), sum(IN & WET & a & !b)) * HA / 1000, BothKha = c(sum(ml & WET & !a & b), sum(mg & WET & a & !b)) * HA / 1000)
res <- rbind(res, tot, net, fill = TRUE)
fwrite(res, "dev/wetland-change/barataria-check.csv"); fwrite(ref, "dev/wetland-change/barataria-referee.csv")
r2 <- function(x) if (is.numeric(x)) round(x, 2) else x
cat("\nModel area", round(sum(IN) * HA / 1000), "kha; model 2001 water", round(sum(IC %in% WATER) * HA / 1000), "kha, wetland", round(sum(IC %in% WETALL) * HA / 1000),
  "kha; rule water 2001", round(sum(P[["2001"]] & IN) * HA / 1000), "kha; rule and model agree on water in 2001 for", round(100 * mean((P[["2001"]] == (IC %in% WATER))[IN]), 1), "% of cells\n\n")
print(res[, lapply(.SD, r2)], nrows = 50); cat("\n"); print(ref[, lapply(.SD, r2)], nrows = 50); cat("\n"); print(fread("dev/wetland-change/barataria-yearly.csv")[, lapply(.SD, r2)])
