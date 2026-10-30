# =============================================================================
# 05-lcms-cut-age.R - to-do 34, a second view of harvest age: the age of the stands LCMS saw cut, from the NASA CMS 1990 age map
# =============================================================================
# The FIA ages (04, tools/calibrate-harvest-age.R) come from a few plots per type. Here, every 30 m pixel of pyrome 26 (Northern Sierra
# Nevada) that LCMS maps as Tree Removal (class 9) on last year's NLCD forest (41-43), split as stage 6 splits it: clearcut if NLCD shows
# shrub or grass (52, 71) that year or within the two after, else selection. Each pixel's first cut after 1990 (a later one is on a stand
# the first cut changed); its age at the cut = CMS age 1990 + (year - 1990); its forest type group from TreeMap 2016 (FORTYPCD of the
# pixel's FIA plot; a pixel cut before 2016 shows its type after the cut). Per type and harvest: pixels (as km2) and percentiles of age
# at the cut, against the FIA values (defaults/transitions/harvest-age.csv). Writes dev/harvest/out/lcms-cut-age.csv. Read-only.
# Usage: Rscript dev/harvest/05-lcms-cut-age.R [--pyrome=26]
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) })
a <- commandArgs(TRUE); PYR <- as.integer(sub("^--pyrome=", "", c(grep("^--pyrome=", a, value = TRUE), "--pyrome=26")[1]))
ds <- "F:/lucas-master/Data Sources"; pkg <- "F:/lucasCore"; out <- file.path(pkg, "dev/harvest/out"); Y0 <- 1990; Y1 <- 2023
nf <- function(y) file.path(ds, "NLCD/Annual NLCD", sprintf("Annual_NLCD_LndCov_%d_CU_C1V0.tif", y))
lf <- function(y) Sys.glob(file.path(ds, "LCMS/v2025-11/Change_Annual", y, sprintf("*Change_%d.tif", y)))[1]
ref <- rast(nf(2000))
pyr <- read_sf(file.path(ds, "Pyromes/Data/Pyromes_CONUS_20200206.shp")); idc <- intersect(c("PYROME", "Pyrome", "PYROME_ID", "ID"), names(pyr))[1]
pyr <- st_transform(pyr[pyr[[idc]] == PYR, ], crs(ref)); E <- align(ext(vect(pyr)), ref)
rd <- function(f) { r <- crop(rast(f), E, snap = "out"); levels(r) <- NULL; if (any(dim(r)[1:2] != c(nrow(rd0), ncol(rd0)))) r <- resample(r, rd0, "near"); r }
rd0 <- crop(ref, E, snap = "out"); inside <- !is.na(values(rasterize(vect(pyr), rd0), mat = FALSE))
cat(sprintf("Pyrome %d: %.0f km2 at 30 m (%d pixels)\n", PYR, sum(inside) * 9e-4, sum(inside)))
nl <- function(y) values(rd(nf(y)), mat = FALSE)
t0 <- Sys.time(); first <- rep(NA_integer_, ncell(rd0)); kind <- rep(NA_character_, ncell(rd0))
N <- list(); for (y in (Y0):(min(Y0 + 2, Y1))) N[[as.character(y)]] <- nl(y)
for (y in (Y0 + 1):Y1) {
  for (k in y:min(y + 2, Y1)) if (is.null(N[[as.character(k)]])) N[[as.character(k)]] <- nl(k)
  lc <- values(rd(lf(y)), mat = FALSE)
  cut <- inside & lc %in% 9 & N[[as.character(y - 1)]] %in% 41:43 & is.na(first)
  sr <- Reduce(`|`, lapply(y:min(y + 2, Y1), function(k) N[[as.character(k)]] %in% c(52, 71)))
  first[cut] <- y; kind[cut] <- ifelse(sr[cut], "Clearcut", "Selection")
  N[[as.character(y - 1)]] <- NULL
  cat(sprintf("%d: %d pixels first cut (%.1f min)\n", y, sum(cut), as.numeric(Sys.time() - t0, units = "mins"))) }
i <- which(!is.na(first))
age90 <- values(rd(file.path(ds, "Stand Age/cms_age_1990.tif")), mat = FALSE)[i]
tm <- values(rd(file.path(ds, "TreeMap/Data/TreeMap2016.tif")), mat = FALSE)[i]
vat <- as.data.table(foreign::read.dbf(file.path(ds, "TreeMap/Data/TreeMap2016.tif.vat.dbf")))
grp <- fread(file.path(ds, "FIA/DataMart/REFERENCE/REF_FOREST_TYPE.csv"), select = c("VALUE", "TYPGRPCD"))
gnm <- fread(file.path(ds, "FIA/DataMart/REFERENCE/REF_FOREST_TYPE_GROUP.csv"), select = c("VALUE", "MEANING"))
ha <- fread(file.path(pkg, "defaults/transitions/harvest-age.csv"), na.strings = "")
norm <- function(x) sub("sgroup$", "group", gsub("[^a-z]", "", tolower(sub("^Forest: ", "", x))))
types <- unique(ha$StateClassId); gnm[, Type := types[match(norm(MEANING), norm(types))]]
ft <- vat$FORTYPCD[match(tm, vat$Value)]
x <- data.table(year = first[i], kind = kind[i], age = age90 + (first[i] - Y0), cms = age90, Type = gnm$Type[match(grp$TYPGRPCD[match(ft, grp$VALUE)], gnm$VALUE)])
cat(sprintf("%d pixels cut (%.0f km2): %s; %.1f%% without a CMS age, %.1f%% without a TreeMap forest type\n", nrow(x), nrow(x) * 9e-4,
            paste(x[, .N, by = kind][, sprintf("%s %.0f km2", kind, N * 9e-4)], collapse = ", "), 100 * mean(is.na(x$cms) | x$cms <= 0 | x$cms > 1000), 100 * mean(is.na(x$Type))))
x <- x[!is.na(cms) & cms > 0 & cms <= 1000 & !is.na(Type)]
q <- function(v, p) as.numeric(quantile(v, p))
s <- x[, .(km2 = round(.N * 9e-4, 1), p05 = q(age, .05), p10 = q(age, .1), p25 = q(age, .25), median = q(age, .5), under40 = round(mean(age < 40), 2)), by = .(Type, kind)]
# the FIA value P26's main ecodivision uses: its Mediterranean Mountains row, else the all-ecodivision row
fia <-ha[is.na(Ecodivision) | Ecodivision == "Mediterranean Mountains"][order(Ecodivision, na.last = TRUE)][, .(FIA = AgeMin[1]), by = .(Type = StateClassId, kind = sub("^.*: Forest ", "", TransitionTypeId))]
s <- merge(s, fia, by = c("Type", "kind"), all.x = TRUE)
s[, BelowFIA := NA_real_]; for (j in seq_len(nrow(s))) s$BelowFIA[j] <- round(x[Type == s$Type[j] & kind == s$kind[j], mean(age < s$FIA[j])], 2)
fwrite(s, file.path(out, sprintf("lcms-cut-age-p%d.csv", PYR)))
options(width = 200); print(s[km2 >= 1][order(kind, -km2), .(Harvest = kind, Type = sub("^Forest: ", "", Type), km2, p05, p10, p25, median, FIA, BelowFIA)])
cat("\nAge at the cut by year band (all types):\n"); print(dcast(x[, .(p10 = q(age, .1), median = q(age, .5)), by = .(kind, band = cut(year, c(1990, 2000, 2010, 2023), dig.lab = 4))], band ~ kind, value.var = c("p10", "median")))
