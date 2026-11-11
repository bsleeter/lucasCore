# To-do 57: cells that start as forest only through stage 5's "forest in any year" rule - a natural cell that NLCD shows as
# grass, shrub or barren in the start year but forest in some later year. What age and carbon do they start with, and when does
# NLCD first show them as forest? Stage 5 sets an unknown age (or a stand that began after the start year) from its neighbours.
# Usage: Rscript dev/fire/start-ever-forest.R <label> <InitialConditionsSpatial folder> <InitialStockSpatial folder> <NLCD folder> <model|30m>
#   NLCD folder: a Build's lucasCore_OutputNlcdAnnual (NLCD_<year>.tif on the model grid: "model"), or a data home's
#   land-cover/nlcd-annual (Annual_NLCD_LndCov_<year>_CU_C1V2.tif at 30 m, taken to the model grid by its most common class: "30m")
suppressMessages({ library(terra); library(data.table) }); terraOptions(progress = 0)
a <- commandArgs(TRUE); lab <- a[1]; icd <- a[2]; std <- a[3]; nld <- a[4]; kind <- a[5]
S <- rast(file.path(icd, "StateClass.tif")); A <- rast(list.files(icd, "^StandAge.*\\.tif$", full.names = TRUE)[1])
nl <- function(y) { if (kind == "model") rast(file.path(nld, sprintf("NLCD_%d.tif", y))) else
  project(crop(rast(file.path(nld, sprintf("Annual_NLCD_LndCov_%d_CU_C1V2.tif", y))), project(as.polygons(ext(S), crs = crs(S)), "EPSG:5070")), S, method = "mode") }
yrs <- 1985:2023; vS <- values(S, mat = FALSE); vA <- values(A, mat = FALSE)
forest <- !is.na(vS) & vS >= 100   # forest type groups and the wetland twins (stage 5: S >= 100)
N <- sapply(yrs, function(y) values(nl(y), mat = FALSE)[which(forest)]); colnames(N) <- yrs
st <- N[, "1985"]; nfs <- st %in% c(31, 52, 71)                 # grass, shrub or barren in NLCD in the start year
firstF <- apply(N, 1, function(r) { i <- which(r %in% 41:43); if (length(i)) yrs[i[1]] else NA_integer_ })
bio <- Reduce(`+`, lapply(list.files(std, "^Biomass-.*\\.tif$", full.names = TRUE), function(f) values(rast(f), mat = FALSE)[which(forest)]))
tot <- Reduce(`+`, lapply(list.files(std, "\\.tif$", full.names = TRUE), function(f) { v <- values(rast(f), mat = FALSE)[which(forest)]; v[is.na(v)] <- 0; v }))
D <- data.table(age = vA[which(forest)], nfs, start = st, firstF, bio, tot)
ha <- prod(res(S)) / 1e4
cat(sprintf("== %s: %d forest cells at the start (%.0f kha)\n", lab, nrow(D), nrow(D) * ha / 1e3))
cat(sprintf("   of them grass, shrub or barren in NLCD 1985 (forest only by the any-year rule): %d cells, %.1f kha (%.1f%%)\n",
            sum(D$nfs), sum(D$nfs) * ha / 1e3, 100 * mean(D$nfs)))
print(D[nfs == TRUE, .(kha = round(.N * ha / 1e3, 1)), by = .(NLCD_1985 = c(`31` = "Barren", `52` = "Shrub", `71` = "Grass")[as.character(start)])])
cat("   first year NLCD shows them as forest:\n")
print(D[nfs == TRUE, .(kha = round(.N * ha / 1e3, 1)), by = .(first_forest = cut(firstF, c(1985, 1990, 1995, 2000, 2005, 2010, 2015, 2023), right = TRUE, include.lowest = TRUE))][order(first_forest)])
ab <- function(x) cut(x, c(0, 5, 10, 20, 40, 80, 150, Inf), labels = c("1-5", "6-10", "11-20", "21-40", "41-80", "81-150", ">150"))
cat("   starting age (share of cells, %): these cells against forest that is NLCD forest in 1985\n")
g <- rbind(D[nfs == TRUE, .(grp = "forest by the rule", b = ab(age))], D[start %in% 41:43, .(grp = "NLCD forest 1985", b = ab(age))])
print(dcast(g[, .N, by = .(grp, b)][, p := round(100 * N / sum(N), 1), by = grp], b ~ grp, value.var = "p", fill = 0))
cat("   starting carbon (map units, per cell's stock density): mean live biomass and mean total of all starting stocks\n")
print(rbind(D[nfs == TRUE, .(group = "forest by the rule", live = mean(bio, na.rm = TRUE), all_stocks = mean(tot))],
            D[nfs == TRUE & age > 20, .(group = "  ... of them older than 20", live = mean(bio, na.rm = TRUE), all_stocks = mean(tot))],
            D[start %in% 41:43 & age <= 10, .(group = "NLCD forest 1985, age 1-10", live = mean(bio, na.rm = TRUE), all_stocks = mean(tot))],
            D[start %in% 41:43, .(group = "NLCD forest 1985, all", live = mean(bio, na.rm = TRUE), all_stocks = mean(tot))])[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 1) else v)])
cat(sprintf("   these cells' share of the starting live biomass: %.1f%%; if they started at the age 1-10 mean instead: %.1f%% less live biomass overall\n",
            100 * sum(D[nfs == TRUE, bio], na.rm = TRUE) / sum(D$bio, na.rm = TRUE),
            100 * sum(D[nfs == TRUE & !is.na(bio), bio - D[start %in% 41:43 & age <= 10, mean(bio, na.rm = TRUE)]]) / sum(D$bio, na.rm = TRUE)))
