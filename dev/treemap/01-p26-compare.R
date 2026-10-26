# =============================================================================
# 01-p26-compare.R - to-do item 10: TreeMap 2016 forest type and stand age on the P26 grid, against the Build's (USFS forest type
# groups, NASA CMS 1990 age) and LANDFIRE EVT 2016
# =============================================================================
# TreeMap 2016 (RDS-2021-0074, Data Sources/TreeMap/Data): a 30 m raster of imputed FIA plot ids; its attribute table gives each id
# the plot visit (CN = FIA PLT_CN) and the algorithm forest type FORTYPCD, but no stand age. Age comes from FIA DataMart COND
# (every <ST>_COND.csv in Data Sources/FIA/DataMart): the plot's forested condition whose FORTYPCD matches TreeMap's, else its
# largest, aged from the plot's inventory year to 2016 and then back to the Build's start year (1985), as stage 5 shifts CMS 1990.
# On the P26 grid (Build result 2): type = most common forest type group of the 30 m pixels (stage 5's rule), age = mean.
# Writes dev/treemap/out/ (type and age rasters, compare-type.csv, compare-age.csv) and prints the comparison. Read-only.
# Usage: Rscript dev/treemap/01-p26-compare.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
ds <- "F:/lucas-master/Data Sources"; out <- "F:/lucasCore/dev/treemap/out"; dir.create(out, showWarnings = FALSE, recursive = TRUE)
lib <- "F:/lucasCore/dev/libs/LUCAS P26 Demo Library.ssim"; b <- file.path(paste0(lib, ".data"), "Scenario-2")
y0 <- 1985L; vint <- 2016L; t0 <- Sys.time()
con <- DBI::dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO)
icf <- DBI::dbGetQuery(con, "SELECT StateClassFileName, AgeFileName FROM stsim_InitialConditionsSpatial WHERE ScenarioId = 2")   # stage 6 rewrites the age map
S <- rast(file.path(b, "stsim_InitialConditionsSpatial", icf$StateClassFileName)); A <- rast(file.path(b, "stsim_InitialConditionsSpatial", icf$AgeFileName))
scl <- as.data.table(DBI::dbGetQuery(con, "SELECT Id, Name FROM stsim_StateClass")); DBI::dbDisconnect(con)
xw <- fread("F:/lucasCore/defaults/landcover/land-cover-crosswalks.csv")
xw[, Id := scl$Id[match(StateClassId, scl$Name)]]

# ---- TreeMap on the P26 window: plot id -> PLT_CN -> FIA type group and stand age ------------------------------------------
tm <- rast(file.path(ds, "TreeMap", "Data", "TreeMap2016.tif"))
win <- project(as.polygons(ext(S) + 3000, crs = crs(S)), crs(tm)); tmc <- crop(tm, win); levels(tmc) <- NULL
rat <- as.data.table(foreign::read.dbf(file.path(ds, "TreeMap", "Data", "TreeMap2016.tif.vat.dbf"), as.is = TRUE))[, .(Value, CN = as.character(CN), FORTYPCD)]
px <- as.data.table(freq(tmc))[, .(Value = as.integer(value), px = count)]; ids <- px$Value; r <- rat[Value %in% ids]
cfs <- list.files(file.path(ds, "FIA", "DataMart"), "^[A-Z]{2}_COND[.]csv$", full.names = TRUE)
cd <- rbindlist(lapply(cfs, function(f) fread(f, select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "CONDPROP_UNADJ", "FORTYPCD", "STDAGE"), colClasses = list(character = "PLT_CN"))))
pl <- rbindlist(lapply(sub("_COND", "_PLOT", cfs), function(f) fread(f, select = c("CN", "INVYR"), colClasses = list(character = "CN"))))
cat(sprintf("TreeMap: %d plots imputed in the P26 window; FIA COND of %s: %d of them found (%.1f%% of the window's forest pixels)\n", nrow(r),
            paste(sub("_COND.csv", "", basename(cfs)), collapse = " "), sum(r$CN %in% cd$PLT_CN),
            100 * sum(px[Value %in% r[CN %in% cd$PLT_CN, Value], px]) / sum(px$px)))
fc <- cd[COND_STATUS_CD == 1 & PLT_CN %in% r$CN]
fc <- merge(fc, r[, .(PLT_CN = CN, tmtype = FORTYPCD)], by = "PLT_CN")
fc[, pick := (FORTYPCD == tmtype) * 10 + CONDPROP_UNADJ]; setorder(fc, PLT_CN, -pick); fc <- fc[!duplicated(PLT_CN)]
fc[, invyr := pl$INVYR[match(PLT_CN, pl$CN)]]
ft <- fread(file.path(ds, "FIA", "DataMart", "REFERENCE", "REF_FOREST_TYPE.csv"), select = c("VALUE", "TYPGRPCD"))
r[, grp := ft$TYPGRPCD[match(FORTYPCD, ft$VALUE)]]
r <- merge(r, fc[, .(CN = PLT_CN, STDAGE, invyr)], by = "CN", all.x = TRUE)
r[, age0 := STDAGE + (vint - invyr) - (vint - y0)]   # the plot's age at its visit, carried to 2016, then back to the start year
cat(sprintf("plots with an age: %d of %d; plot visits %d-%d (median %d)\n", sum(!is.na(r$STDAGE)), nrow(r), min(r$invyr, na.rm = TRUE), max(r$invyr, na.rm = TRUE), as.integer(median(r$invyr, na.rm = TRUE))))

# ---- 30 m layers -> P26 grid ------------------------------------------------------------------------------------------------
xu <- xw[Source == "USFS Forest Type Group" & !is.na(Code)]
grp_sc <- function(g) xu$Id[match(g, xu$Code)]   # FIA type group code -> lucasCore forest state class
T30 <- classify(tmc, cbind(r$Value, grp_sc(r$grp)), others = NA); G30 <- classify(tmc, cbind(r$Value, r$age0), others = NA)
Tz <- project(T30, S, method = "mode"); Az <- project(G30, S, method = "average")
writeRaster(Tz, file.path(out, "treemap-type-p26.tif"), overwrite = TRUE, datatype = "INT2S"); writeRaster(Az, file.path(out, "treemap-age1985-p26.tif"), overwrite = TRUE, datatype = "FLT4S")

# EVT 2016 forest types on the same grid (stage 5's LANDFIRE EVT rule, without the 2001 fill)
evt <- rast(file.path(ds, "EVT", "LF2016_EVT_200_CONUS", "LF2016_EVT_200_CONUS", "Tif", "LC16_EVT_200.tif"))   # Data Sources: Evt2016File
e <- crop(evt, project(as.polygons(ext(S) + 3000, crs = crs(S)), crs(evt))); levels(e) <- NULL
xe <- xw[Source == "EVT 2016" & !is.na(Code) & !is.na(Id) & Id >= 100 & Id <= 999]
Ez <- project(classify(e, cbind(xe$Code, xe$Id), others = NA), S, method = "mode")

# ---- compare on the Build's forest cells -----------------------------------------------------------------------------------------
v <- data.table(build = values(S, mat = FALSE), tm = values(Tz, mat = FALSE), evt = values(Ez, mat = FALSE), ab = values(A, mat = FALSE), at = values(Az, mat = FALSE))
f <- v[!is.na(build) & build >= 100 & build <= 999]
nm <- function(i) scl$Name[match(i, scl$Id)]
cat(sprintf("\nP26 forest cells (Build state class 100-999): %d. TreeMap has a forest type for %.1f%%, EVT 2016 for %.1f%%\n", nrow(f), 100 * mean(!is.na(f$tm)), 100 * mean(!is.na(f$evt))))
cat(sprintf("Same forest type as the Build (USFS forest type groups): TreeMap %.1f%%, EVT %.1f%%; TreeMap = EVT %.1f%%\n",
            100 * mean(f$tm == f$build, na.rm = TRUE), 100 * mean(f$evt == f$build, na.rm = TRUE), 100 * mean(f$tm == f$evt, na.rm = TRUE)))
ty <- merge(f[, .(build = .N), by = .(sc = build)], f[!is.na(tm), .(treemap = .N), by = .(sc = tm)], by = "sc", all = TRUE)
ty <- merge(ty, f[!is.na(evt), .(evt = .N), by = .(sc = evt)], by = "sc", all = TRUE)[, StateClass := nm(sc)][order(-build)]
for (k in c("build", "treemap", "evt")) ty[, (k) := round(100 * get(k) / nrow(f), 1)]
print(ty[, .(StateClass, build, treemap, evt)]); fwrite(ty, file.path(out, "compare-type.csv"))
cat("\nStand age in 1985 on forest cells (Build: NASA CMS 1990 shifted; TreeMap: plot age shifted from 2016):\n")
q <- function(x) round(quantile(x, c(.05, .25, .5, .75, .95), na.rm = TRUE))
ag <- rbind(data.table(source = "Build (CMS)", mean = round(mean(f$ab, na.rm = TRUE), 1), t(q(f$ab)), at_or_below_0 = NA_real_),
            data.table(source = "TreeMap", mean = round(mean(pmax(f$at, 1), na.rm = TRUE), 1), t(q(pmax(f$at, 1))), at_or_below_0 = round(100 * mean(f$at <= 0, na.rm = TRUE), 1)))
print(ag); fwrite(ag, file.path(out, "compare-age.csv"))
cat(sprintf("Correlation of cell ages, Build vs TreeMap: %.2f\n", cor(f$ab, f$at, use = "complete.obs")))
cat(sprintf("%.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
