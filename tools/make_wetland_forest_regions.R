# =============================================================================
# make_wetland_forest_regions.R - which forested wetland twin a woody wetland cell of another forest type takes, by ecodivision
# (to-do 53; user 2026-11-10: "assign those cells ... to one of our three forested wetland classes ... which is closer or more common
# in that region")
# =============================================================================
# About 23% of FIA's hydric forest (physiographic class 31-39) is outside the Spruce/Fir, Oak/Gum/Cypress and Elm/Ash/Cottonwood
# groups (aspen/birch, oak/pine, maple, western riparian types). Stage 5 gives a woody wetland cell of such a type (or of no type)
# the twin most common among the hydric conditions of the three groups in its ecodivision (condition proportion summed, latest
# inventory of each plot from 2000). An ecodivision with fewer than MIN_COND hydric conditions of the three takes Elm/Ash/Cottonwood:
# the West's woody wetlands are mostly riparian cottonwood and willow.
# Input: FIA (the DataMart folder: <ST>_PLOT.csv, <ST>_COND.csv, REFERENCE/REF_FOREST_TYPE.csv or FIADB_REFERENCE.zip).
# Writes defaults/growth/wetland-forest-regions.csv.
# Usage: FIA=<DataMart folder> Rscript tools/make_wetland_forest_regions.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(sf) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
FIA <- Sys.getenv("FIA"); if (!dir.exists(FIA)) stop("set FIA to the FIA DataMart folder")
MIN_COND <- 30; DEFAULT <- "Wetland: Elm/Ash/Cottonwood Group"
fail <- function(...) stop(sprintf(...), call. = FALSE); source(file.path(pkg, "src", "fia.R"))   # fia_reference, fia_hydric_group
ref <- fia_reference(FIA)
TWIN <- c(`121` = "Wetland: Spruce/Fir Group", `601` = "Wetland: Oak/Gum/Cypress Group", `701` = "Wetland: Elm/Ash/Cottonwood Group")
sts <- sub("_COND[.]csv$", "", list.files(FIA, "^[A-Z]{2}_COND[.]csv$"))
x <- rbindlist(lapply(sts, function(s) {
  pl <- fread(file.path(FIA, paste0(s, "_PLOT.csv")), select = c("CN", "STATECD", "UNITCD", "COUNTYCD", "PLOT", "INVYR", "LAT", "LON"), colClasses = list(character = "CN"))
  cd <- fread(file.path(FIA, paste0(s, "_COND.csv")), select = c("PLT_CN", "COND_STATUS_CD", "FORTYPCD", "PHYSCLCD", "CONDPROP_UNADJ"), colClasses = list(character = "PLT_CN"))
  cd <- cd[COND_STATUS_CD == 1 & PHYSCLCD >= 31 & PHYSCLCD <= 39]
  pl <- pl[INVYR >= 2000 & INVYR < 9999][order(-INVYR)][, .SD[1], by = .(STATECD, UNITCD, COUNTYCD, PLOT)]   # latest visit per plot
  merge(cd, pl[, .(CN, LAT, LON)], by.x = "PLT_CN", by.y = "CN") }))
x[, grp := fia_hydric_group(ref$ft$TYPGRPCD[match(FORTYPCD, ref$ft$VALUE)], PHYSCLCD)]
eco <- read_sf(file.path(pkg, "defaults", "strata", "ecodivisions", "EcoDivisions_Dissolve.shp"))
pts <- st_transform(st_as_sf(x[!is.na(LAT) & !is.na(LON)], coords = c("LON", "LAT"), crs = 4269), st_crs(eco))
x <- as.data.table(st_drop_geometry(st_join(pts, eco[c("ecodiv", "StrtmNm")])))[!is.na(StrtmNm)][, ecodiv := StrtmNm]
cat(sprintf("hydric forest conditions: %d (%.0f%% of their area in the three groups)\n", nrow(x), 100 * x[grp %in% names(TWIN), sum(CONDPROP_UNADJ)] / sum(x$CONDPROP_UNADJ)))
tl <- x[grp %in% names(TWIN), .(Area = sum(CONDPROP_UNADJ), N = .N), by = .(Ecodivision = ecodiv, grp)]
w <- dcast(tl, Ecodivision ~ grp, value.var = "Area", fill = 0); n <- tl[, .(Conditions = sum(N)), by = Ecodivision]
w <- merge(merge(data.table(Ecodivision = sort(unique(eco$StrtmNm))), w, all.x = TRUE), n, all.x = TRUE)
for (k in setdiff(names(w), "Ecodivision")) set(w, which(is.na(w[[k]])), k, 0)
for (k in names(TWIN)) if (!k %in% names(w)) w[, (k) := 0]
w[, StateClassId := fifelse(Conditions >= MIN_COND, TWIN[names(TWIN)[max.col(as.matrix(.SD), ties.method = "first")]], DEFAULT), .SDcols = names(TWIN)]
other <- x[!grp %in% names(TWIN), .(OtherConditions = .N), by = .(Ecodivision = ecodiv)]
w <- merge(w, other, all.x = TRUE); w[is.na(OtherConditions), OtherConditions := 0]
out <- w[, .(Ecodivision, StateClassId, Conditions, SpruceFirShare = round(`121` / pmax(`121` + `601` + `701`, 1e-9), 3),
             OakGumCypressShare = round(`601` / pmax(`121` + `601` + `701`, 1e-9), 3), ElmAshCottonwoodShare = round(`701` / pmax(`121` + `601` + `701`, 1e-9), 3),
             OtherConditions, Source = fifelse(Conditions >= MIN_COND, "most hydric FIA area of the three groups", sprintf("fewer than %d hydric conditions of the three: default", MIN_COND)))]
fwrite(out, file.path(pkg, "defaults", "growth", "wetland-forest-regions.csv")); print(out[, .(Ecodivision, StateClassId, Conditions, OtherConditions)])
