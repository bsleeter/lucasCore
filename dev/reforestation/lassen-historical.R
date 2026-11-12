# To-do 57 step 7: does the historical run reforest the cells stage 5 started as non-forest in the year NLCD shows them as forest?
# Expected: a reforesting cell (stage 5) turns forest in the second year NLCD shows it as forest two years running (stage 6's
# NlcdPersist map), as its ReforestType. Compares the run's Reforestation transitions by year (stsim_OutputStratumTransition) with that,
# and its final state class map with the 2023 NLCD on those cells.
# Usage: Rscript dev/reforestation/lassen-historical.R <historical result id> <stage 5 result id (the Build)>
suppressMessages({ library(rsyncrosim); library(terra); library(data.table) })
a <- as.integer(commandArgs(TRUE)); L <- ssimLibrary("F:/lucasCore/dev/libs/lassen/Lassen.ssim", summary = FALSE); h <- scenario(L, a[1]); b <- scenario(L, a[2])
ic <- datasheet(b, "stsim_InitialConditionsSpatial"); lc <- datasheet(b, "lucasCore_OutputLandCoverLayers"); nl <- datasheet(b, "lucasCore_OutputNlcdAnnual")
S <- rast(ic$StateClassFileName[1]); RT <- rast(lc$ReforestTypeFileName[1]); N <- rast(nl$FileName); n0 <- N[[1]]; yrs <- nl$Year
ff <- app(N >= 41 & N <= 43, function(x) { k <- which(x[-length(x)] & x[-1]); k <- k[k >= 2]; if (length(k)) k[1] else NA })   # index of the first of two forest years
rf <- which(values(S < 100 & n0 %in% c(31, 52, 71, 95) & !is.na(ff), mat = FALSE) %in% 1)
exp_yr <- yrs[values(ff, mat = FALSE)[rf] + 1]                       # the second year of the two
cell_km2 <- prod(res(S)) / 1e6
ot <- as.data.table(datasheet(h, "stsim_OutputStratumTransition", lookupsAsFactors = FALSE))
got <- ot[grepl("^Reforestation", TransitionGroupId) & !grepl(" \\[Type\\]$", TransitionGroupId), .(cells = round(sum(Amount) / cell_km2 / 100)), by = .(Year = Timestep)]
if (!nrow(got)) got <- ot[grepl("^Reforestation", TransitionGroupId), .(cells = round(sum(Amount) / cell_km2 / 100 / 2)), by = .(Year = Timestep)]
cmp <- merge(data.table(Year = exp_yr)[, .(expected = .N), by = Year], got, by = "Year", all = TRUE)[order(Year)]
for (k in c("expected", "cells")) set(cmp, which(is.na(cmp[[k]])), k, 0)
cat(sprintf("reforesting cells: %d; expected to reforest by %d: %d; the run's Reforestation transitions: %d cells\n", length(rf), max(yrs), sum(exp_yr <= max(yrs)), sum(cmp$cells)))
print(cmp)
oc <- as.data.table(datasheet(h, "stsim_OutputSpatialState", optional = TRUE))
if (nrow(oc)) { last <- rast(oc[Timestep == max(Timestep), Filename][1]); v <- values(last, mat = FALSE)[rf]
  cat(sprintf("final map (%d): %d of %d reforesting cells forest (%d as their ReforestType); NLCD %d forest: %d\n", max(oc$Timestep), sum(v >= 100 & v <= 999), length(rf),
              sum(v == values(RT, mat = FALSE)[rf]), max(yrs), sum(values(N[[length(yrs)]], mat = FALSE)[rf] %in% 41:43))) }
