# =============================================================================
# 08-iclus-where.R - do the ICLUS maps say where development goes? ICLUS's modelled 2010-2020 against Annual NLCD 2010-2020 (exploratory)
# =============================================================================
# User question 2026-11-14: would the ICLUS 90 m maps add anything as a spatial allocation option? ICLUS's first modelled decade can be
# scored against what happened. In a set of growing counties, on ICLUS's 90 m cells:
#   eligible   not developed (21-24), water or ice in NLCD 2010 (the nearest 30 m pixel)
#   event      developed in NLCD 2020; also Low, Medium or High only (22-24: without Open Space)
#   scores     ICLUS new by 2020: the cell enters classes 10-16 (exurban and up) or 12-16 (suburban and up) between ICLUS 2010 and 2020
#              ICLUS when: the decade it first enters 12-16, 2020 to 2100 (earlier = higher), a ranking over the whole century
#              Distance: to the nearest NLCD 2010 developed cell (nearer = higher), the simplest surface there is
# AUC (0.5 = random) and how much of the new development fell on the cells ICLUS developed. SSP2-RCP4.5, HadGEM2-ES.
# Usage: Rscript dev/land-use-demand/08-iclus-where.R
# =============================================================================
pkg <- local({ d <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))); while (!file.exists(file.path(d, "package.xml")) && dirname(d) != d) d <- dirname(d); d })
DS <- Sys.getenv("LUCAS_DATA_HOME", "E:/lucasData"); NL <- Sys.getenv("LUCAS_NLCD_NATIONAL", "F:/lucas-master/Data Sources/NLCD/Annual NLCD")
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) }); source(file.path(pkg, "src/iclus.R")); terraOptions(progress = 0)
say <- function(...) cat(sprintf(...), "\n"); OUT <- file.path(pkg, "dev/land-use-demand")
CO <- c(`Placer CA` = "06061", `Sacramento CA` = "06067", `Riverside CA` = "06065", `Travis TX` = "48453", `Collin TX` = "48085", `Wake NC` = "37183", `Maricopa AZ` = "04013",
        `Ada ID` = "16001", `Loudoun VA` = "51107", `Dallas IA` = "19049", `Lancaster PA` = "42071", `Clark WA` = "53011")
m <- iclus_all_maps(file.path(DS, "land-use/iclus"), "ssp2_rcp45_hadgem2_es")[[1]]
cty <- read_sf(file.path(DS, "study-area/counties/tl_rd22_us_county.shp")); cty <- cty[cty$GEOID %in% CO, "GEOID"]
nf <- function(y) { f <- file.path(NL, sprintf("Annual_NLCD_LndCov_%d_CU_C1V%d.tif", y, c(0L, 2L))); f[file.exists(f)][1] }
auc <- function(score, ev) { r <- frank(score); n1 <- as.numeric(sum(ev)); n0 <- as.numeric(sum(!ev)); (sum(r[ev]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
res <- rbindlist(lapply(names(CO), function(nm) { p <- st_transform(cty[cty$GEOID == CO[[nm]], ], crs(rast(m[1]))); v <- vect(p)
  a <- crop(rast(m["2010"]), align(ext(v) + 3000, rast(m["2010"]), snap = "out")); levels(a) <- NULL; inside <- !is.na(values(rasterize(v, a, 1), mat = FALSE))
  ic <- sapply(m, function(f) { b <- crop(rast(f), a, extend = TRUE); levels(b) <- NULL; if (!compareGeom(b, a, stopOnError = FALSE)) b <- resample(b, a, method = "near"); values(b, mat = FALSE) })
  n10 <- rast(nf(2010)); bx <- project(as.polygons(ext(a), crs = crs(a)), crs(n10)); n10 <- crop(n10, bx, snap = "out"); n20 <- crop(rast(nf(2020)), n10); levels(n10) <- NULL; levels(n20) <- NULL
  v10 <- values(project(n10, a, method = "near"), mat = FALSE); v20 <- values(project(n20, a, method = "near"), mat = FALSE)
  dist <- values(distance(ifel(setValues(a, v10 %in% 21:24), 1, NA)), mat = FALSE)
  el <- inside & !is.na(v10) & !(v10 %in% c(21:24, 11L, 12L)) & !is.na(ic[, "2010"])
  d <- data.table(ev = v20[el] %in% 21:24, ev2 = v20[el] %in% 22:24, i10 = !(ic[el, "2010"] %in% 10:16) & ic[el, "2020"] %in% 10:16, i12 = !(ic[el, "2010"] %in% 12:16) & ic[el, "2020"] %in% 12:16,
                  in10 = ic[el, "2010"] %in% 10:16, dist = dist[el])
  # the decade a cell first enters 12-16 (11 = never by 2100; already in them in 2010 = 0)
  first <- rep(11L, sum(el)); for (j in rev(seq_len(ncol(ic)))) first[ic[el, j] %in% 12:16] <- j - 1L; d[, when := -first]
  data.table(County = nm, EligibleKm2 = round(nrow(d) * 0.0081), NewDevKm2 = round(sum(d$ev) * 0.0081, 1), NewDev2224Km2 = round(sum(d$ev2) * 0.0081, 1),
             IclusNew1016Km2 = round(sum(d$i10) * 0.0081, 1), IclusNew1216Km2 = round(sum(d$i12) * 0.0081, 1),
             Hit1216 = sum(d$ev & d$i12) / max(1, sum(d$ev)), Hit1216of2224 = sum(d$ev2 & d$i12) / max(1, sum(d$ev2)), Precision1216 = sum(d$ev & d$i12) / max(1, sum(d$i12)),
             OnExurban2010 = sum(d$ev & d$in10) / max(1, sum(d$ev)), ExurbanShareOfLand = mean(d$in10),
             AucNew1216 = auc(as.numeric(d$i12), d$ev), AucWhen = auc(d$when, d$ev), AucWhen2224 = auc(d$when, d$ev2), AucDistance = auc(-d$dist, d$ev), AucDistance2224 = auc(-d$dist, d$ev2)) }))
fwrite(res, file.path(OUT, "08-iclus-where.csv"))
say("ICLUS 2010-2020 (SSP2-RCP4.5, HadGEM2-ES) against NLCD 2010-2020, on land not developed in NLCD 2010:")
print(res[, .(County, NewDevKm2, NewDev2224Km2, IclusNew1016Km2, IclusNew1216Km2, Hit1216 = round(Hit1216, 2), Hit1216of2224 = round(Hit1216of2224, 2), Precision1216 = round(Precision1216, 2))])
say("\n(Hit = the share of NLCD's new developed land on cells ICLUS moved into classes 12-16; Precision = the share of those cells NLCD developed)")
print(res[, .(County, OnExurban2010 = round(OnExurban2010, 2), ExurbanShareOfLand = round(ExurbanShareOfLand, 2), AucWhen = round(AucWhen, 2), AucDistance = round(AucDistance, 2), AucWhen2224 = round(AucWhen2224, 2), AucDistance2224 = round(AucDistance2224, 2))])
say("\nMedians: hit %.2f, precision %.2f; AUC of ICLUS's order of development %.2f against distance to developed land %.2f (Low-High only: %.2f against %.2f); %.0f%% of new development was on land ICLUS already called exurban or denser in 2010 (%.0f%% of the eligible land)",
    median(res$Hit1216), median(res$Precision1216), median(res$AucWhen), median(res$AucDistance), median(res$AucWhen2224), median(res$AucDistance2224), 100 * median(res$OnExurban2010), 100 * median(res$ExurbanShareOfLand))
