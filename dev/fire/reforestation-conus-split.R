# To-do 57: split the CONUS sample's unrecorded reforestation (dev/fire/reforestation-conus.R; land non-forest since 1985 with no fire or
# harvest recorded before it) by timing, LANDFIRE BpS (2020) forest potential and later harvest, to tell regrowing clearcuts (already
# right: stage 5 starts them as forest with the NLCD regrowth age) from real reforestation (encroachment, old-field succession, slow
# recovery). Timing: first forest by 2004 is the regrowth rule's pattern (forest within 20 years of the start); 2005 on is late.
suppressMessages(library(data.table)); d <- file.path("dev", "fire", "reforestation-conus")
D <- fread(file.path(d, "events.csv")); s <- readRDS(file.path(d, "sample.rds")); hp <- s$ha_pt
bt <- fread("F:/lucas-master/Data Sources/BpS/LF2020_BPS_CONUS/LF2020_BPS_CONUS/CSV_Data/LF2020_BPS.csv")
grp <- function(g) fcase(g %in% c("Conifer", "Conifer-Hardwood", "Hardwood", "Hardwood-Conifer", "Peatland Forest"), "forest",
                         g %in% c("Riparian", "Savanna"), "riparian or savanna",
                         g %in% c("Grassland", "Shrubland", "Sparse", "Barren-Rock/Sand/Clay", "Peatland non-forest"), "non-forest", default = "other or unmapped")
D[, BpS := grp(bt$GROUPVEG[match(bps, bt$VALUE)])]
en <- unique(fread("F:/lucas-master/Data Sources/FIA/EcoDivision_Strata.csv")[, .(eco = as.integer(StratumId), Ecodivision = StratumName)], by = "eco"); en[eco == 2601, Ecodivision := "Mediterranean Mountains"]
D[, Ecodivision := en$Ecodivision[match(eco, en$eco)]]
x <- D[kind == "no record: non-forest since 1985"][, timing := fifelse(year <= 2004, "by 2004 (regrowth pattern)", "2005 on (late)")]
M <- function(n) round(n * hp / 1e6, 2)
cat(sprintf("unrecorded reforestation of land non-forest since 1985: %.1f Mha (%d points of %.0f ha)\n\n", M(nrow(x)), nrow(x), hp))
cat("by timing and BpS (Mha):\n"); print(dcast(x[, .N, by = .(timing, BpS)], timing ~ BpS, value.var = "N", fill = 0)[, lapply(.SD, function(v) if (is.numeric(v)) M(v) else v)])
cat(sprintf("\nharvested later in the record (LCMS Tree Removal after the event): %.0f%% of the by-2004 events, %.0f%% of the late ones\n",
            100 * x[timing %like% "^by", mean(cut_after)], 100 * x[timing %like% "^2005", mean(cut_after)]))
# three readings: regrowing clearcut (by 2004, forest potential), slow recovery (late, forest potential), new forest (non-forest potential)
x[, reading := fcase(BpS == "non-forest", "new forest (BpS non-forest)",
                     BpS == "forest" & timing %like% "^by", "regrowth pattern, forest potential (clearcut regrowth?)",
                     BpS == "forest", "late, forest potential (slow recovery?)", default = "riparian, savanna or other")]
cat("\nby reading (Mha, kha a year over 38 years, % harvested later):\n")
print(x[, .(Mha = M(.N), kha_yr = round(.N * hp / 1e3 / 38), cut_later_pct = round(100 * mean(cut_after)), points = .N), by = reading][order(-Mha)])
cat("\nby ecodivision and reading (Mha):\n")
w <- dcast(x[, .N, by = .(Ecodivision, reading)], Ecodivision ~ reading, value.var = "N", fill = 0); w[, total := rowSums(.SD), .SDcols = -1]
print(w[order(-total)][, lapply(.SD, function(v) if (is.numeric(v)) M(v) else v)])
cat("\nnew forest (BpS non-forest) by 1985 NLCD class and BpS group (Mha):\n")
print(x[BpS == "non-forest", .(Mha = M(.N)), by = .(NLCD_1985 = c(`31` = "Barren", `52` = "Shrub", `71` = "Grass", `95` = "Emergent wetland")[as.character(start)],
        BpS_group = bt$GROUPVEG[match(bps, bt$VALUE)])][order(-Mha)][1:10])
fwrite(x, file.path(d, "unrecorded-split.csv"))
