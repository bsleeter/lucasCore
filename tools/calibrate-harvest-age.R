# =============================================================================
# calibrate-harvest-age.R - the package's minimum harvest ages, from stand age at harvest in FIA remeasurement (to-do 34)
# =============================================================================
# Run once, up front (user decision 2026-10-30), not in the Build: writes defaults/transitions/harvest-age.csv, which stage 6 applies
# to the clearcut and selection pathways (a Build's Minimum Harvest Age page overrides any row), and the AgeMin column of
# defaults/transitions/pathways/harvest.csv (the all-ecodivision values, kept in step).
# Cuts: every FIA DataMart state (<ST>_PLOT, <ST>_COND). A cut = a condition whose current visit records cutting (TRTCD 10) with a
# treatment year inside the remeasurement interval, paired with the same CONDID at the plot's previous visit (PLOT.PREV_PLT_CN). Age at
# the cut = the previous visit's STDAGE + (treatment year - previous measurement year); forest type = the previous visit's type group;
# ecodivision from the previous visit's (fuzzed) coordinates; live basal area loss = 1 - BALIVE now / before. Clearcut = loss >= 75%
# (Forest Clearcut), selection = 10-75% (Forest Selection; LCMS partial removal, stage 6's only selection source).
# Minimum age = the --percentile (default 10th) of age at the cut: per forest type over all states when it has at least --min-cuts
# (20); per type x ecodivision too where that has at least --min-eco-cuts (30). A type with too few cuts takes the culmination of mean
# annual increment of its merchantable volume curves (median over ecodivisions) from --curves (a Build result: library.ssim:scenario id),
# else keeps the package value. Selection is capped at the clearcut value. Stage 6 lowers these to the study area's own mapped cuts and
# takes selection a set number of years below clearcut (the Minimum Harvest Age page).
# Usage:
#   Rscript tools/calibrate-harvest-age.R [--dm=<FIA DataMart folder>] [--curves="<library.ssim>:<result id>"] [--percentile=0.1]
#                                         [--min-cuts=20] [--min-eco-cuts=30] [--dry-run]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(sf) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
ds0 <- fread(file.path(pkg, "defaults/library/project/lucasCore_DataSource.csv"))
dm <- opt("dm", ds0$FiaDataMartFolder[1]); ecof <- ds0$EcodivisionFile[1]
PCT <- as.numeric(opt("percentile", 0.1)); MIN_CUTS <- as.integer(opt("min-cuts", 20)); MIN_ECO <- as.integer(opt("min-eco-cuts", 30)); dry <- "--dry-run" %in% a
KINDS <- c(clearcut = "Forest Harvest: Forest Clearcut", selection = "Forest Harvest: Forest Selection")

hp <- file.path(pkg, "defaults/transitions/pathways/harvest.csv"); hv <- fread(hp, colClasses = "character", na.strings = "")
types <- unique(hv[TransitionTypeId == KINDS[["clearcut"]], StateClassIdSource])
norm <- function(x) sub("sgroup$", "group", gsub("[^a-z]", "", tolower(sub("^Forest: ", "", x))))   # "Other western softwoods group" = "Other Western Softwood Group"
grp <- fread(file.path(dm, "REFERENCE", "REF_FOREST_TYPE.csv"), select = c("VALUE", "TYPGRPCD"))
gnm <- fread(file.path(dm, "REFERENCE", "REF_FOREST_TYPE_GROUP.csv"), select = c("VALUE", "MEANING"))
gnm[, Type := types[match(norm(MEANING), norm(types))]]

# ---- the cuts -------------------------------------------------------------------------------------------------------------
sts <- sort(sub("_PLOT[.]csv$", "", list.files(dm, "^[A-Z]{2}_PLOT[.]csv$"))); sts <- sts[file.exists(file.path(dm, paste0(sts, "_COND.csv")))]
t0 <- Sys.time()
cuts <- rbindlist(lapply(sts, function(s) {
  pl <- fread(file.path(dm, sprintf("%s_PLOT.csv", s)), select = c("CN", "PREV_PLT_CN", "MEASYEAR", "LAT", "LON"), colClasses = list(character = c("CN", "PREV_PLT_CN")))
  cd <- fread(file.path(dm, sprintf("%s_COND.csv", s)), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "STDAGE", "FORTYPCD", "BALIVE", paste0("TRTCD", 1:3), paste0("TRTYR", 1:3)),
              colClasses = list(character = "PLT_CN"))
  for (k in c(paste0("TRTCD", 1:3), paste0("TRTYR", 1:3), "STDAGE", "BALIVE", "FORTYPCD")) set(cd, j = k, value = as.numeric(cd[[k]]))
  cd <- merge(cd, pl[, .(PLT_CN = CN, PREV_PLT_CN, MEASYEAR, LAT, LON)], by = "PLT_CN")
  cd[, TRTYR := fcase(TRTCD1 %in% 10 & between(TRTYR1, 1900, 2100), TRTYR1, TRTCD2 %in% 10 & between(TRTYR2, 1900, 2100), TRTYR2,
                      TRTCD3 %in% 10 & between(TRTYR3, 1900, 2100), TRTYR3, default = NA_real_)]
  now <- cd[!is.na(TRTYR) & !is.na(PREV_PLT_CN) & nzchar(PREV_PLT_CN), .(PREV_PLT_CN, CONDID, TRTYR, ba1 = BALIVE)]
  pre <- cd[COND_STATUS_CD %in% 1, .(PREV_PLT_CN = PLT_CN, CONDID, age0 = STDAGE, typ0 = FORTYPCD, ba0 = BALIVE, y0 = MEASYEAR, LAT, LON)]
  x <- merge(now, pre, by = c("PREV_PLT_CN", "CONDID"))
  x[TRTYR >= y0 & TRTYR <= y0 + 20 & !is.na(age0) & age0 >= 0 & !is.na(typ0)][, State := s][] }))
cuts[, age := age0 + (TRTYR - y0)]
cuts[, loss := fifelse(!is.na(ba0) & ba0 > 0, 1 - fifelse(is.na(ba1), 0, ba1) / ba0, NA_real_)]
cuts[, kind := fcase(loss >= 0.75, "clearcut", loss >= 0.10, "selection", default = NA_character_)]
cuts <- merge(cuts, grp[, .(typ0 = VALUE, TYPGRPCD)], by = "typ0", all.x = TRUE)
cuts <- merge(cuts, gnm[, .(TYPGRPCD = VALUE, Type)], by = "TYPGRPCD", all.x = TRUE)
cuts <- cuts[!is.na(kind) & !is.na(Type)]
eco <- read_sf(ecof); pts <- unique(cuts[!is.na(LAT) & !is.na(LON), .(LAT, LON)])
j <- st_join(st_transform(st_as_sf(pts, coords = c("LON", "LAT"), crs = 4269, remove = FALSE), st_crs(eco)), eco["ecodiv"])
en <- unique(as.data.table(st_drop_geometry(eco))[, .(ecodiv = as.character(ecodiv), StrtmNm)])   # one name per code: a second M260 polygon is named "Mediterranean" (2026-10-30)
en <- en[order(ecodiv, -(startsWith(ecodiv, "M") & grepl("Mountains$", StrtmNm)))][!duplicated(ecodiv)]
pts[, Ecodivision := en$StrtmNm[match(as.character(j$ecodiv[match(paste(LAT, LON), paste(j$LAT, j$LON))]), en$ecodiv)]]
cuts <- merge(cuts, pts, by = c("LAT", "LON"), all.x = TRUE)
cat(sprintf("%d states read in %.1f min: %d cuts with a forest type (%d clearcut, %d selection); %d without an ecodivision\n", length(sts),
            as.numeric(Sys.time() - t0, units = "mins"), nrow(cuts), cuts[kind == "clearcut", .N], cuts[kind == "selection", .N], cuts[is.na(Ecodivision), .N]))

# ---- minimum ages -----------------------------------------------------------------------------------------------------------
pq <- function(x) as.integer(round(quantile(x, PCT, type = 7)))
fit_t <- cuts[, .(Cuts = .N, AgeMin = pq(age)), by = .(Type, kind)]
fit_e <- cuts[!is.na(Ecodivision), .(Cuts = .N, AgeMin = pq(age)), by = .(Ecodivision, Type, kind)][Cuts >= MIN_ECO]
# fallback: culmination of mean annual increment of a Build result's merchantable volume curves
cmai <- NULL; cv <- opt("curves", NA)
if (!is.na(cv)) { suppressPackageStartupMessages(library(rsyncrosim)); lp <- sub(":[0-9]+$", "", cv); id <- as.integer(sub("^.*:", "", cv))
  vc <- as.data.table(datasheet(scenario(suppressWarnings(ssimLibrary(lp)), id), "lucasCore_MerchantableVolumeCurve", lookupsAsFactors = FALSE))
  cmai <- vc[Age > 0 & MerchantableVolume > 0][order(StratumId, StateClassId, Age)][, .(c = Age[which.max(MerchantableVolume / Age)]), by = .(StratumId, Type = StateClassId)][
    , .(CMAI = as.integer(round(median(c)))), by = Type] }
pkgv <- hv[TransitionTypeId == KINDS[["clearcut"]], .(Type = StateClassIdSource, Package = as.integer(AgeMin))]
pc <- function(p) sprintf("%dth percentile", round(100 * p))
rows <- rbindlist(lapply(types, function(t) rbindlist(lapply(names(KINDS), function(k) {
  f <- fit_t[Type == t & kind == k]; m <- if (!is.null(cmai)) cmai[Type == t, CMAI] else integer(0); p <- pkgv[Type == t, Package]
  base <- if (nrow(f) && f$Cuts >= MIN_CUTS) data.table(AgeMin = f$AgeMin, Cuts = f$Cuts, Source = sprintf("FIA age at cut, %s, %d cuts, all states", pc(PCT), f$Cuts))
    else if (length(m) && !is.na(m)) data.table(AgeMin = m, Cuts = if (nrow(f)) f$Cuts else 0L, Source = sprintf("culmination of mean annual increment (%d FIA cuts: too few)", if (nrow(f)) f$Cuts else 0L))
    else if (k == "clearcut" && length(p) && !is.na(p)) data.table(AgeMin = p, Cuts = if (nrow(f)) f$Cuts else 0L, Source = "package value (too few FIA cuts, no curves)")
    else NULL
  e <- fit_e[Type == t & kind == k, .(Ecodivision, AgeMin, Cuts, Source = sprintf("FIA age at cut, %s, %d cuts in the ecodivision", pc(PCT), Cuts))]
  rbind(if (!is.null(base)) cbind(Ecodivision = NA_character_, base), e)[, `:=`(StateClassId = t, TransitionTypeId = KINDS[[k]])] }))))
# selection never above clearcut (user 2026-10-30: thinning comes before final harvest; FIA's partial cuts' young tail sits at or above
# clearcut's from how stand age is recorded in uneven stands). The same ecodivision's clearcut, else the type's. Stage 6 also takes it
# a set number of years below (Minimum Harvest Age: Selection younger than clearcut by)
cc <- rows[TransitionTypeId == KINDS[["clearcut"]]]
rows[TransitionTypeId == KINDS[["selection"]], cap := { k <- match(paste(Ecodivision, StateClassId), cc[, paste(Ecodivision, StateClassId)])
  k0 <- match(StateClassId, cc[is.na(Ecodivision), StateClassId]); fifelse(is.na(k), cc[is.na(Ecodivision)]$AgeMin[k0], cc$AgeMin[k]) }]
rows[!is.na(cap) & AgeMin > cap, `:=`(AgeMin = cap, Source = paste0(Source, "; capped at the clearcut value"))][, cap := NULL]
setcolorder(rows, c("Ecodivision", "StateClassId", "TransitionTypeId", "AgeMin", "Cuts", "Source"))
setorder(rows, StateClassId, TransitionTypeId, Ecodivision, na.last = FALSE)
options(width = 220); print(rows[, .(Ecodivision, Type = sub("^Forest: ", "", StateClassId), Harvest = sub("^.*: Forest ", "", TransitionTypeId), AgeMin, Cuts, Source)], nrows = 500)
chg <- merge(pkgv, rows[is.na(Ecodivision) & TransitionTypeId == KINDS[["clearcut"]], .(Type = StateClassId, New = AgeMin)], by = "Type")[Package != New]
cat(sprintf("\nClearcut all-ecodivision values changed for %d of %d types\n", nrow(chg), nrow(pkgv)))
if (dry) quit(save = "no")
fwrite(rows, file.path(pkg, "defaults/transitions/harvest-age.csv"), na = "")
for (k in names(KINDS)) { v <- rows[is.na(Ecodivision) & TransitionTypeId == KINDS[[k]]]
  hv[TransitionTypeId == KINDS[[k]], AgeMin := as.character(v$AgeMin[match(StateClassIdSource, v$StateClassId)])] }
fwrite(hv, hp, na = "")
cat(sprintf("wrote %s (%d rows) and the AgeMin column of %s\n", file.path(pkg, "defaults/transitions/harvest-age.csv"), nrow(rows), hp))
