# =============================================================================
# 8-initial-stocks-spatial.R - stage 8: initial carbon stock rasters (ST-Sim Initial Stocks, spatial)
# =============================================================================
# Replaces the initialStocks chunk of "Build LUCAS Model CONUS Annual NLCD FIA Update.Rmd" (L2434-2890). Every land cell gets the 14
# carbon pools (Mg C/ha) of its start-year state:
#   forest classes          stage 4's Initial Stock Curves: ecodivision x forest class x last disturbance x stand age (age capped at the
#                           curves' maximum)
#   forested wetland        defaults/initialstocks/wetland-forested-{fire,harvest}.csv, by class x age (the CONUS 1km build's tables)
#   grass/shrub, emergent   defaults/initialstocks/grassland-shrubland.csv and emergent-wetland.csv, by class
#   wetland                 (the same build tables; they come from the build's non-forest spin-up with the non-forest flows stage 3
#                           also uses)
#   everything else         0 (developed, agriculture, barren, water, ice)
#   last disturbance        high-severity fire where an interagency fire perimeter of 1900 to the start year covers the cell, otherwise
#                           clearcut (the build's rule; with few early perimeters in the East, eastern forest is mostly post-harvest), or
#                           high-severity fire for the forest types Carbon Assumptions: Spin-up sets so
#   soil (BG slow)          gSSURGO wherever the class's value is 0 (the build's rule). Forest keeps its spin-up value: stage 3
#                           calibrated soil decay to each ecodivision x class's mean gSSURGO, so forest cells start at the class's
#                           gSSURGO mean and in balance with their decay rates
# Stand age is the stage 6 map when it ran (clearcut minimum age applied), else stage 5's.
# Needs stages 4 and 5 (6 recommended): same pipeline, or dependencies on their results.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
suppressPackageStartupMessages({ library(terra); library(sf) })
STAGE <- "8 Initial Stocks Spatial"
progressBar(type = "begin", totalSteps = 5)

src <- read_data_sources(c("FirePerimeterHistoryFile", "SoilCarbonFile"))
opt <- read_ds("BuildOptions"); y0 <- opt$StartYear[1]
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StateClassFileName[1]) || is.na(ic$AgeFileName[1])) fail("no state class or age map: run stage 5 first (same pipeline, or depend on a stage 5 result)")
cv <- as.data.table(datasheet(scn, ds("InitialStockCurve"), optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(cv)) fail("Initial Stock Curves are empty: run stage 4 first (same pipeline, or depend on a stage 4 result)")
P <- rast(ic$StratumFileName[1]); S <- rast(ic$StateClassFileName[1]); A <- rast(ic$AgeFileName[1])
scl <- stsim_list("StateClass"); stl <- stsim_list("Stratum"); stt <- stsim_list("StockType")$Name
st <- read_default("initialstocks", "stock-types.csv")
check(STAGE, "every stock type exists", all(st$StockTypeId %in% stt), paste(setdiff(st$StockTypeId, stt), collapse = "; "))
if (any(vapply(.checks, function(x) x$Status != "Pass", TRUE))) finish_checks()
land <- !is.na(values(P, mat = FALSE)); vP <- values(P, mat = FALSE); vS <- values(S, mat = FALSE); vA <- values(A, mat = FALSE)
cname <- scl$Name[match(vS, as.integer(scl$Id))]; sname <- stl$Name[match(vP, as.integer(stl$Id))]
cell_ha <- (res(P)[1] / 100)^2
progressBar()

# ---- last disturbance: interagency fire perimeters, 1900 to the start year --------------------------------------------------
lay <- tools::file_path_sans_ext(basename(src$FirePerimeterHistoryFile))
fp <- st_read(src$FirePerimeterHistoryFile, query = sprintf('SELECT FIRE_YEAR_ FROM "%s" WHERE FIRE_YEAR_ >= 1900 AND FIRE_YEAR_ <= %d', lay, y0), quiet = TRUE)
fp <- st_make_valid(st_transform(fp, crs(P)))
bb <- st_as_sfc(st_bbox(c(xmin = xmin(P), ymin = ymin(P), xmax = xmax(P), ymax = ymax(P)), crs = st_crs(crs(P))))
fp <- fp[lengths(st_intersects(fp, bb)) > 0, ]
burned <- if (nrow(fp)) !is.na(values(rasterize(vect(fp), P, field = 1), mat = FALSE)) else rep(FALSE, ncell(P))
say("Last disturbance: %d fire perimeters of 1900-%d intersect the study area; %.1f%% of land cells inside one",
    nrow(fp), y0, 100 * mean(burned[land]))
# outside the perimeters: clearcut, unless Carbon Assumptions: Spin-up sets high-severity fire for the cell's forest type (the
# ecodivision row's choice, else the type's all-ecodivisions row's)
postfire <- burned
sp <- as.data.table(datasheet(scn, ds("Spinup"), optional = TRUE, lookupsAsFactors = FALSE))
if (nrow(sp) && "LastDisturbanceUnburned" %in% names(sp) && any(!is.na(sp$LastDisturbanceUnburned))) {
  sp <- sp[!is.na(LastDisturbanceUnburned)][, `:=`(StratumId = as.character(StratumId), fire = LastDisturbanceUnburned %in% c(2L, "2", "High-severity fire"))]   # a list column reads as its label
  ch <- data.table(sname, cname)
  own <- sp[!is.na(StratumId)][ch, on = .(StratumId = sname, StateClassId = cname), fire, mult = "first"]
  all <- sp[is.na(StratumId)][ch, on = .(StateClassId = cname), fire, mult = "first"]
  uf <- data.table::fcoalesce(own, all); postfire <- burned | (!is.na(uf) & uf)
  say("Spin-up (Carbon Assumptions): high-severity fire as the last disturbance outside the perimeters for %d land cells of %s", sum(land & postfire & !burned),
      paste(sub("^Forest: ", "", unique(sp[fire == TRUE, paste0(ifelse(is.na(StratumId), "", paste0(StratumId, " / ")), StateClassId)])), collapse = ", "))
}
last <- ifelse(postfire, "Fire: High Severity [Type]", "Forest Harvest: Forest Clearcut [Type]")
say("Last disturbance: %.1f%% of land cells post-fire, the rest post-clearcut", 100 * mean(postfire[land]))
progressBar()

# ---- pools by class -----------------------------------------------------------------------------------------------------
out <- matrix(0, ncell(P), nrow(st), dimnames = list(NULL, st$StockTypeId)); src_of <- rep(NA_character_, ncell(P))
# forest: stage 4 curves
amax <- max(cv$Age); fk <- paste(cv$StratumId, cv$StateClassId, cv$TransitionGroupId, cv$Age)
isF <- land & !is.na(vS) & vS >= 100
key <- paste(sname, cname, last, pmin(pmax(round(vA), 0), amax))
m <- match(key[isF], fk)
check(STAGE, "every forest cell finds its ecodivision x class x last disturbance x age in the stock curves", !anyNA(m),
      sprintf("%d of %d forest cells unmatched (e.g. %s)", sum(is.na(m)), sum(isF), paste(head(unique(key[isF][is.na(m)]), 3), collapse = "; ")))
out[which(isF)[!is.na(m)], ] <- as.matrix(cv[m[!is.na(m)], st$CurveColumn, with = FALSE]); src_of[isF] <- "stock curves (stage 4)"
# legacy class tables: by class (and age for forested wetland)
lt <- function(f) { x <- read_default("initialstocks", f); setnames(x, gsub("ID$", "Id", names(x)))
  x[, `:=`(Value = as.numeric(Value), AgeMin = suppressWarnings(as.integer(AgeMin)))][StateAttributeTypeId %in% st$Attribute] }
fill_class <- function(tab, cells, by_age = FALSE, label) {
  if (!any(cells)) return(invisible())
  w <- dcast(tab, if (by_age) StateClassId + AgeMin ~ StateAttributeTypeId else StateClassId ~ StateAttributeTypeId, value.var = "Value", fun.aggregate = sum)
  k <- if (by_age) paste(cname[cells], pmin(pmax(round(vA[cells]), 0), max(w$AgeMin))) else cname[cells]
  mm <- match(k, if (by_age) paste(w$StateClassId, w$AgeMin) else w$StateClassId)
  check(STAGE, sprintf("every %s cell finds its class in the table", label), !anyNA(mm), sprintf("%d unmatched (%s)", sum(is.na(mm)), paste(head(unique(k[is.na(mm)]), 3), collapse = "; ")))
  for (j in seq_len(nrow(st))) if (st$Attribute[j] %in% names(w)) out[which(cells)[!is.na(mm)], j] <<- w[[st$Attribute[j]]][mm[!is.na(mm)]]
  src_of[cells] <<- label }
wf_cls <- unique(lt("wetland-forested-fire.csv")$StateClassId)
isWF <- land & cname %in% wf_cls
fill_class(lt("wetland-forested-fire.csv"), isWF & postfire, TRUE, "forested wetland (post-fire)")
fill_class(lt("wetland-forested-harvest.csv"), isWF & !postfire, TRUE, "forested wetland (post-harvest)")
gs <- lt("grassland-shrubland.csv"); fill_class(gs, land & cname %in% unique(gs$StateClassId), FALSE, "grassland/shrubland")
ew <- lt("emergent-wetland.csv"); fill_class(ew, land & cname %in% unique(ew$StateClassId), FALSE, "emergent wetland")
src_of[land & is.na(src_of)] <- "zero (developed, agriculture, barren, water, ice)"
progressBar()

# ---- soil: gSSURGO where the class's belowground slow is 0 -----------------------------------------------------------------
So <- crop(rast(src$SoilCarbonFile), project(as.polygons(ext(P) + 3000, crs = crs(P)), crs(rast(src$SoilCarbonFile))))
So <- classify(So, cbind(-Inf, 0, NA), include.lowest = TRUE)   # 0 and the undeclared -1920 no-data value are missing (as stage 5)
vSo <- values(project(So, P, method = "average") * 0.01, mat = FALSE)
bgs <- which(st$StockTypeId == "DOM: Belowground Slow"); sub_ <- land & out[, bgs] == 0 & !is.na(vSo)
out[sub_, bgs] <- vSo[sub_]
say("Soil: gSSURGO used for %d cells whose class has no belowground slow carbon (%s)", sum(sub_), paste(names(table(src_of[sub_])), collapse = ", "))
out[!land, ] <- NA
progressBar()

# ---- checks, summary, outputs -----------------------------------------------------------------------------------------
check(STAGE, "every land cell has every pool, none negative", !anyNA(out[land, ]) && all(out[land, ] >= 0), sprintf("%d NA, %d negative", sum(is.na(out[land, ])), sum(out[land, ] < 0, na.rm = TRUE)))
live <- grep("^Biomass", st$StockTypeId); dom <- setdiff(seq_len(nrow(st)), c(live, bgs))
d <- data.table(S = vS, src = src_of, fire = postfire, live = rowSums(out[, live]), dom = rowSums(out[, dom]), soil = out[, bgs])[land]
summ <- d[, .(Cells = .N, PostFire = round(mean(fire), 3), Live = round(mean(live), 1), Dom = round(mean(dom), 1), Soil = round(mean(soil), 1),
              TotalTg = round(sum(live + dom + soil) * cell_ha / 1e6, 2), Source = src[1]), by = S][order(-TotalTg)]
summ[, StateClassId := scl$Name[match(S, as.integer(scl$Id))]]
tot <- d[, sum(live + dom + soil)] * cell_ha / 1e9
say("Initial carbon: %.2f Pg C (live %.2f, dead organic matter %.2f, soil %.2f); forest mean live %.0f, DOM %.0f, soil %.0f Mg C/ha",
    tot, sum(d$live) * cell_ha / 1e9, sum(d$dom) * cell_ha / 1e9, sum(d$soil) * cell_ha / 1e9,
    mean(d[!is.na(S) & S >= 100, live]), mean(d[!is.na(S) & S >= 100, dom]), mean(d[!is.na(S) & S >= 100, soil]))
files <- vapply(seq_len(nrow(st)), function(j) write_raster(setValues(rast(P), out[, j]), sprintf("%s.tif", gsub("[^A-Za-z0-9]+", "-", st$StockTypeId[j])), "FLT4S"), "")
write_stsim(data.table(StockTypeId = st$StockTypeId, RasterFileName = files), "InitialStockSpatial")
write_ds(summ[, .(StateClassId, Cells, PostFire, Live, Dom, Soil, TotalTg, Source)], "OutputInitialStockSummary")
progressBar()
finish_checks()
progressBar(type = "end")
