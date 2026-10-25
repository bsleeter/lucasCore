# =============================================================================
# 07-carbon-all.R - to-do item 8: first-order initial carbon effect of all-class matching (06-match-all.R) against the modal map, 1985
# =============================================================================
# A cell whose 1985 class changes from the modal class to another is given the mean 1985 Total Ecosystem density (P26 historical run,
# result 9) of the cells the modal map puts in that class in the same county (the study area's mean where the county has none).
# Not a model run: forest type, age and stand structure are not redone. Read-only.
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
pkg <- "F:/lucasCore"; cache <- file.path(pkg, "dev/resampling/cache"); lib <- file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim.data")
te <- values(rast(file.path(lib, "Scenario-9/stsim_OutputAverageSpatialStockGroup/avgstkg_628.it0.ts1985.tif")), mat = FALSE)
m <- values(rast(file.path(cache, "shares_1985.tif"))[["modal"]], mat = FALSE); a <- values(rast(file.path(cache, "allmatch_1985.tif")), mat = FALSE)
cty <- values(rast(file.path(lib, "Scenario-2/stsim_InitialConditionsSpatial/SecondaryStrata.tif")), mat = FALSE)
ok <- !is.na(m) & !is.na(a) & !is.na(te); dt <- data.table(m = m[ok], a = a[ok], te = te[ok], c = cty[ok])
dens_c <- dt[, .(d = mean(te)), by = .(c, cls = m)]; dens <- dt[, .(d0 = mean(te)), by = .(cls = m)]
ch <- dt[m != a]; ch <- merge(ch, dens_c, by.x = c("c", "a"), by.y = c("c", "cls"), all.x = TRUE); ch <- merge(ch, dens, by.x = "a", by.y = "cls", all.x = TRUE)
ch[is.na(d), d := d0]; ch[, delta := d - te]
grp <- function(v) fcase(v %in% 21:24, "Developed", v %in% 41:43, "Forest", v == 52, "Shrubland", v == 71, "Grassland", v %in% 81:82, "Agriculture",
                         v %in% 90:95, "Wetland", v %in% 11:12, "Water/ice", default = "Barren/other")
tot <- sum(dt$te) * 0.0225 * 100 / 1e6
cat(sprintf("1985: %.0f km2 change class; initial total ecosystem carbon %+.2f Tg C of %.1f (%+.2f%%)\n", nrow(ch) * 0.0225,
            sum(ch$delta) * 0.0225 * 100 / 1e6, tot, 100 * sum(ch$delta) * 0.0225 * 100 / 1e6 / tot))
print(ch[, .(km2 = round(.N * 0.0225), TgC = round(sum(delta) * 0.0225 * 100 / 1e6, 2)), by = .(from = grp(m), to = grp(a))][order(-abs(TgC))][1:12])
