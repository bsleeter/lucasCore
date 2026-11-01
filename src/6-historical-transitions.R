# =============================================================================
# 6-historical-transitions.R - stage 6: historical transition pathways and annual transition spatial multipliers
# =============================================================================
# Replaces the transition pathway chunk (L1153-1240) and the Urbanization, Ag Expansion, Ag Contraction, Natural Vegetation,
# Intensification, Wildfire, Forest Clearcut and Forest Selection chunks (L1272-2180) of "Build LUCAS Model CONUS Annual NLCD FIA
# Update.Rmd", and the clearcut minimum-age part of its StandAgeCMS chunk (L2376-2392). defaults/transitions/sources.csv says where each
# transition group's multiplier comes from:
#   NlcdGain / NlcdLoss  the modal annual NLCD on the model grid (stage 5) gains or loses the classes (1 = changed, 0 = not); land-use
#                        change is mapped where the cell's class changes, as in the state class map
#   NaturalVeg           each type of the group may only reach the nearest natural state class of the start year (ag contraction)
#   Mtbs                 MTBS burn severity
#   NlcdClearcut         the modal annual NLCD goes from forest to shrub or grass and most of the cell did not burn (MTBS) that year or
#                        the year before. Same 1 km NLCD as the state class map, so every clearcut cell is a forest class (user
#                        decision 2026-10-20: coherence between the maps comes before matching the 30 m area)
#   Landfire             LANDFIRE annual disturbance, by the disturbance type of each year's attribute table
#   Lcms                 USFS LCMS annual cause of change (user decision 2026-10-23: one harvest record for 1985 on; LANDFIRE starts
#                        in 1999): Tree Removal (class 9) on a pixel that was forest (NLCD 41-43) the year before, split by what NLCD
#                        shows next - "standrep" (shrub or grass that year or within the two after: clearcut) or "partial" (still forest:
#                        selection). Classes "9>standrep" / "9>partial"; fractions of 30 m pixels, as for LANDFIRE
# Changes from the CONUS 1km build:
#   * MTBS and LANDFIRE give each cell the fraction of its 30 m pixels that had the disturbance, so the expected area equals the 30 m
#     area (the build sampled one 30 m pixel per cell). Both have pathways on every class they occur on, so this keeps the maps coherent.
#     The cell's whole burned fraction goes to its most common severity, so the severities never compete for a cell (ST-Sim allows one
#     transition per cell per timestep)
#   * clearcut and selection come from LCMS Tree Removal (sources.csv; 2026-10-23). In P26 it is ~63 km2/yr with no break at 1999,
#     where the NLCD clearcut rule was half fire, drought and pixel noise and LANDFIRE Thinning (fuels treatments, mostly invisible to
#     Landsat) overlapped LCMS on 9% of its area (dev/harvest). If LANDFIRE is used, its type names cover codes the build's ranges
#     (441-443, 741-743, 941) missed (940, 942-948, the 4-digit codes from 2024)
#   * harvested cells get at least their pathway's minimum age at their first cut, clearcut or selection (to-do 34: the minimum ages are
#     FIA's 10th percentile of age at the cut, defaults/transitions/harvest-age.csv and the Minimum Harvest Age page; the build
#     required the minimum age in the start year)
#   * every pathway type with no spatial multiplier gets a zero target, so no type runs everywhere by default
# Needs stage 5 (same pipeline, or a dependency on its result).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
suppressPackageStartupMessages({ library(terra); library(sf); library(parallel) })
STAGE <- "6 Historical Transitions"
progressBar(type = "begin", totalSteps = 8)

src <- read_data_sources(c("EcodivisionFile", "NlcdFolder", "MtbsSeverityFolder", "LandfireDisturbanceFolder", "LcmsFolder"))
opt <- read_ds("BuildOptions"); y0 <- opt$StartYear[1]; y1 <- opt$EndYear[1]; yrs <- (y0 + 1):y1
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StateClassFileName[1]) || is.na(ic$AgeFileName[1])) fail("no state class or age map: run stage 5 first (same pipeline, or depend on a stage 5 result)")
P <- rast(ic$StratumFileName[1]); S <- rast(ic$StateClassFileName[1]); A <- rast(ic$AgeFileName[1]); m <- !is.na(P)
home_coverage(P)   # Data Sources read from the home folder must hold the study area (shared.R)
res_m <- res(P)[1]; cell_km2 <- (res_m / 1000)^2
nl <- read_ds("OutputNlcdAnnual"); miss <- setdiff(y0:y1, nl$Year)
if (length(miss)) fail("annual NLCD on the model grid is missing for %s: run stage 5 with the same years", paste(miss, collapse = ", "))
N <- rast(nl$FileName[match(y0:y1, nl$Year)]); names(N) <- y0:y1
L <- model_lattice(st_transform(read_sf(src$EcodivisionFile), MODEL_CRS), res_m)
scl <- stsim_list("StateClass"); ttl <- stsim_list("TransitionType"); tgl <- stsim_list("TransitionGroup"); ttg <- stsim_list("TransitionTypeGroup")
sid <- function(nm) as.integer(scl$Id[match(nm, scl$Name)])
vS <- values(S, mat = FALSE); vA <- values(A, mat = FALSE); land <- !is.na(values(P, mat = FALSE))
say("Grid: %d land cells of %d m; transitions %d-%d", sum(land), res_m, min(yrs), max(yrs))
progressBar()

# ---- pathways ---------------------------------------------------------------------------------------------------------
pf <- list.files(pkg_file("defaults", "transitions", "pathways"), "[.]csv$", full.names = TRUE)
pw <- rbindlist(lapply(pf, function(f) { x <- fread(f, colClasses = "character", na.strings = ""); setnames(x, gsub("ID", "Id", names(x)))
  x[, Set := tools::file_path_sans_ext(basename(f))] }), fill = TRUE)
badc <- setdiff(c(pw$StateClassIdSource, pw$StateClassIdDest), scl$Name); badt <- setdiff(pw$TransitionTypeId, ttl$Name)
check(STAGE, "pathway state classes and transition types are in the stsim lists", !length(badc) && !length(badt),
      paste(c(if (length(badc)) paste("classes:", paste(badc, collapse = "; ")), if (length(badt)) paste("types:", paste(badt, collapse = "; "))), collapse = " | "))
if (length(badc) || length(badt)) finish_checks()
num <- function(x) suppressWarnings(as.numeric(x))
tr <- pw[, .(StateClassIdSource, StateClassIdDest, TransitionTypeId, Probability = num(Probability), Proportion = num(Proportion), AgeMin = num(AgeMin),
             AgeMax = num(AgeMax), AgeRelative = num(AgeRelative), AgeReset = ifelse(is.na(AgeReset), NA, toupper(AgeReset) %in% c("YES", "TRUE")),
             TSTMin = num(TSTMin), TSTMax = num(TSTMax), TSTRelative = num(TSTRelative))]
# minimum harvest ages (to-do 34): the package's FIA values (defaults/transitions/harvest-age.csv, tools/calibrate-harvest-age.R: the
# 10th percentile of FIA stand age at the cut, per forest type and, where FIA has enough cuts, per ecodivision), lowered to the study
# area's own (LCMS cuts x the stand age map, below) and the Minimum Harvest Age page's rows; settled once the cut maps are made
stl <- stsim_list("Stratum"); vP <- values(P, mat = FALSE); eco_here <- stl$Name[as.numeric(stl$Id) %in% unique(vP)]
CC <- "Forest Harvest: Forest Clearcut"; SEL <- "Forest Harvest: Forest Selection"
ha <- read_default("transitions", "harvest-age.csv")[, .(Ecodivision, StateClassId, TransitionTypeId, FIA = num(AgeMin), Source)]
mh <- as.data.table(datasheet(scn, ds("MinimumHarvestAge"), optional = TRUE, lookupsAsFactors = FALSE))
mh <- if (nrow(mh)) mh[!is.na(StateClassId) & !is.na(TransitionTypeId) & !is.na(AgeMin), .(Ecodivision = as.character(StratumId), StateClassId = as.character(StateClassId),
                        TransitionTypeId = as.character(TransitionTypeId), AgeMin = num(AgeMin))] else data.table()
hopt <- read_ds("HarvestAgeOptions"); hv <- function(k, d) if (nrow(hopt) && k %in% names(hopt) && !is.na(hopt[[k]][1])) hopt[[k]][1] else d
H_MAPS <- as.logical(hv("UseStudyArea", TRUE)); H_MAP_KM2 <- num(hv("MinMapArea", 1)); H_OFFSET <- num(hv("SelectionOffset", 10)); H_FLOOR <- num(hv("SelectionFloor", 5))
badh <- rbind(ha[, .(StateClassId, TransitionTypeId)], if (nrow(mh)) mh[, .(StateClassId, TransitionTypeId)])[!paste(StateClassId, TransitionTypeId) %in% pw[, paste(StateClassIdSource, TransitionTypeId)]]
check(STAGE, "every minimum harvest age has a pathway", !nrow(badh), paste(unique(badh[, paste(StateClassId, TransitionTypeId)]), collapse = "; "))
tr[, StratumIdSource := NA_character_]
loc <- read_default("transitions", "state-locations.csv")[StateClassIdSource %in% scl$Name, .(StateClassIdSource, StateClassIdDest, Location)]
say("Pathways: %d rows in %d sets (%s); %d transition types", nrow(tr), uniqueN(pw$Set), paste(unique(pw$Set), collapse = ", "), uniqueN(pw$TransitionTypeId))

# a transition group's types, and the start-year state classes any of them can leave
TYPE_SUFFIX <- " [Type]"
grp_types <- function(g) if (endsWith(g, TYPE_SUFFIX)) substr(g, 1, nchar(g) - nchar(TYPE_SUFFIX)) else ttg[TransitionGroupId == g, TransitionTypeId]
elig_cells <- function(g) vS %in% sid(unique(pw[TransitionTypeId %in% grp_types(g), StateClassIdSource]))
so <- read_default("transitions", "sources.csv")
ok_g <- vapply(so$TransitionGroupId, function(g) if (endsWith(g, TYPE_SUFFIX)) grp_types(g) %in% ttl$Name else g %in% tgl$Name, TRUE)
check(STAGE, "every transition group in sources.csv exists", all(ok_g), paste(so$TransitionGroupId[!ok_g], collapse = "; "))
nopw <- so$TransitionGroupId[vapply(so$TransitionGroupId, function(g) !any(grp_types(g) %in% pw$TransitionTypeId), TRUE)]
if (length(nopw)) say("Sources with no pathway (skipped): %s", paste(nopw, collapse = "; "))
so <- so[ok_g & !TransitionGroupId %in% nopw]
codes <- function(x) as.integer(strsplit(x, "|", fixed = TRUE)[[1]])
progressBar()

# ---- land-use change from the modal annual NLCD (stage 5) ----------------------------------------------------------------
off_file <- write_raster(mask(init(P, 0), P), "Off.tif", "INT1U")
lu <- so[Source %in% c("NlcdGain", "NlcdLoss")]; lu[, Key := paste(Source, Classes)]
layers <- list()   # one row per group and year: the multiplier file (NA when nothing happened) and its source
for (k in unique(lu$Key)) { s <- lu[Key == k][1]; cl <- codes(s$Classes)
  for (y in yrs) { a <- N[[as.character(y - 1)]] %in% cl; b <- N[[as.character(y)]] %in% cl
    r <- mask(if (s$Source == "NlcdGain") !a & b else a & !b, P)
    f <- if (global(r, "sum", na.rm = TRUE)[[1]] > 0) write_raster(r, sprintf("%s-%s_%d.tif", s$Source, gsub("|", "-", s$Classes, fixed = TRUE), y), "INT1U") else NA_character_
    layers[[length(layers) + 1]] <- data.table(Timestep = y, TransitionGroupId = lu[Key == k, TransitionGroupId], Source = s$Source, File = f) } }
say("Land-use change: %d groups from the modal NLCD", nrow(lu))
progressBar()

# ---- 30 m disturbances: fraction of each cell's 30 m pixels, one year per worker ------------------------------------------
fire <- so[Source == "Mtbs"]; ncc <- so[Source == "NlcdClearcut"]; lfg <- so[Source == "Landfire"]; lcg <- so[Source == "Lcms"]
# the clearcut group (for the minimum-age rule): the NLCD clearcut source, or LCMS stand-replacing tree removal
ccs <- rbind(ncc, lcg[grepl("standrep", Classes)])
if (nrow(ccs) > 1) fail("sources.csv: only one clearcut group (NlcdClearcut or Lcms standrep) is supported")
cc_ft <- if (nrow(ncc)) lapply(strsplit(ncc$Classes, ">", fixed = TRUE)[[1]], codes) else list(integer(), integer())
lc_code <- as.integer(sub(">.*", "", lcg$Classes)); lc_kind <- sub(".*>", "", lcg$Classes)
if (any(!lc_kind %in% c("standrep", "partial"))) fail("sources.csv: Lcms classes must be <code>>standrep or <code>>partial")
lc <- setNames(vapply(yrs, function(y) { f <- Sys.glob(file.path(src$LcmsFolder, y, sprintf("*Change_%d.tif", y))); if (length(f)) f[1] else NA_character_ }, ""), yrs)
if (nrow(lcg) && anyNA(lc)) say("LCMS missing for %s: no %s in those years", paste(yrs[is.na(lc)], collapse = ", "), paste(lcg$TransitionGroupId, collapse = ", "))
lf_types <- strsplit(lfg$Classes, "|", fixed = TRUE)
nf <- setNames(nlcd_file(src$NlcdFolder, (y0):y1), y0:y1)
mt <- setNames(vapply((y0):y1, function(y) { f <- file.path(src$MtbsSeverityFolder, sprintf("mtbs_CONUS_%d.tif", y)); if (file.exists(f)) f else NA_character_ }, ""), y0:y1)
lf <- setNames(lapply(yrs, function(y) {
  d <- file.path(src$LandfireDisturbanceFolder, sprintf("US_DIST%d", y)); tif <- Sys.glob(file.path(d, "*", "Tif", "*.tif")); csv <- Sys.glob(file.path(d, "*", "CSV_Data", "*.csv"))
  if (!nrow(lfg) || !length(tif) || !length(csv)) return(NULL)
  a <- fread(csv[1]); setnames(a, toupper(names(a)))
  list(tif = tif[1], codes = lapply(lf_types, function(t) as.integer(a[DIST_TYPE %in% t, VALUE]))) }), yrs)
if (nrow(fire) && any(is.na(mt[as.character(yrs)]))) say("MTBS missing for %s: no fire in those years", paste(yrs[is.na(mt[as.character(yrs)])], collapse = ", "))
if (nrow(lfg)) { nolf <- yrs[vapply(lf, is.null, TRUE)]; if (length(nolf)) say("LANDFIRE disturbance missing for %s: no %s in those years", paste(range(nolf), collapse = "-"), paste(lfg$TransitionGroupId, collapse = ", ")) }

# per-year worker: reads the 30 m layers over the aggregation blocks of the model grid (shared.R, grid_blocks), flags each pixel, and
# writes one fraction raster per group
year_layers <- function(y, a) {
  library(terra); library(data.table); a$clear(); terraOptions(memfrac = a$memfrac, progress = 0)
  P <- rast(a$pf); E <- ext(a$E)
  rd <- function(f, ref = NULL) { r <- crop(rast(f), E, snap = "near", extend = TRUE); levels(r) <- NULL
    if (!is.null(ref)) { if (any(dim(r)[1:2] != dim(ref)[1:2])) stop("30 m grid of ", f, " does not match the NLCD grid")
      ext(r) <- ext(ref); crs(r) <- crs(ref) }
    r }
  ref <- rd(a$nf[[as.character(y)]]); lay <- list(); col <- c()
  f <- a$mt[[as.character(y)]]; if (!is.na(f)) { lay[[length(lay) + 1]] <- rd(f, ref); col["m"] <- length(lay) }
  li <- a$lf[[as.character(y)]]
  if (!is.null(li)) { lay[[length(lay) + 1]] <- rd(li$tif, ref); col["lf"] <- length(lay) }
  # LCMS: the change layer, last year's NLCD (forest?) and this and the next two years' (shrub or grass?)
  lci <- if (length(a$lc_groups) && y > a$y0) a$lc[[as.character(y)]] else NA_character_
  has_lc <- !is.na(lci)
  if (has_lc) { lay[[length(lay) + 1]] <- rd(lci, ref); col["lc"] <- length(lay); lay[[length(lay) + 1]] <- rd(a$nf[[as.character(y - 1)]], ref); col["p"] <- length(lay)
    nk <- c(); for (k in y:min(y + 2, a$y1)) { lay[[length(lay) + 1]] <- if (k == y) ref else rd(a$nf[[as.character(k)]], ref); nk <- c(nk, length(lay)) } }
  has_fire <- length(a$fire_groups) && "m" %in% names(col)
  grp <- c(if (has_fire) a$fire_groups, if (!is.null(li)) a$lf_groups, if (has_lc) a$lc_groups)
  part <- c(if (has_fire) rep("fire", length(a$fire_groups)), if (!is.null(li)) rep("lf", length(a$lf_groups)), if (has_lc) rep("lc", length(a$lc_groups)))
  if (!length(grp)) return(NULL)
  flag <- function(v) { v <- as.matrix(v); out <- matrix(0L, nrow(v), length(grp)); j <- 0
    if (has_fire) for (cc in a$fire_codes) { j <- j + 1; out[, j] <- v[, col[["m"]]] %in% cc }
    if (!is.null(li)) for (cc in li$codes) { j <- j + 1; out[, j] <- v[, col[["lf"]]] %in% cc }
    if (has_lc) { sr <- rowSums(matrix(v[, nk] %in% c(52, 71), nrow(v))) > 0; fo <- v[, col[["p"]]] %in% 41:43
      for (i in seq_along(a$lc_groups)) { j <- j + 1; t <- v[, col[["lc"]]] %in% a$lc_code[i] & fo; out[, j] <- if (a$lc_kind[i] == "standrep") t & sr else t & !sr } }
    out }
  ind <- app(rast(lay), flag, wopt = list(datatype = "INT1U", gdal = "COMPRESS=DEFLATE"))
  fr <- mask(project(aggregate(ind, a$fact, "mean"), P, method = "near"), P)
  # within a source with several groups (fire severities), the cell's total fraction goes to its most common group
  for (p in intersect(unique(part), "fire")) { i <- which(part == p); if (length(i) < 2) next   # (LCMS clearcut and selection are disjoint already)
    tot <- sum(fr[[i]]); w <- which.max(fr[[i]]); for (j in seq_along(i)) fr[[i[j]]] <- ifel(w == j, tot, 0) }
  out <- rbindlist(lapply(seq_along(grp), function(j) { r <- fr[[j]]; s <- global(r, "sum", na.rm = TRUE)[[1]]
    f <- if (s > 0) { p <- file.path(a$td, sprintf("%s_%d.tif", gsub("[^A-Za-z0-9]+", "-", sub(" [Type]", "", grp[j], fixed = TRUE)), y))
      writeRaster(r, p, overwrite = TRUE, datatype = "FLT4S", gdal = c("COMPRESS=DEFLATE", "TILED=YES")); p } else NA_character_
    data.table(Timestep = y, TransitionGroupId = grp[j], Source = c(fire = "Mtbs", lf = "Landfire", lc = "Lcms")[[part[j]]], File = f,
               Max = global(r, "max", na.rm = TRUE)[[1]]) }))
  tmpFiles(remove = TRUE); out }

dl <- data.table(Timestep = integer(), TransitionGroupId = character(), Source = character(), File = character(), Max = numeric())
if (nrow(fire) || nrow(lfg) || nrow(lcg)) {
  b <- grid_blocks(rast(nf[[1]]), L, P)
  wy <- c(y0, yrs)   # the start year's fire is needed for the first year's clearcut burn test
  ncl <- max(1, min(length(wy), 40, detectCores() - 2))
  args <- list(clear = clear_syncrosim_proj, memfrac = 0.6 / ncl, pf = ic$StratumFileName[1], E = as.vector(b$ext), fact = b$fact, td = TD(),
               nf = as.list(nf), mt = as.list(mt), lf = lf, fire_groups = fire$TransitionGroupId, fire_codes = lapply(fire$Classes, codes), lf_groups = lfg$TransitionGroupId,
               lc = as.list(lc), lc_groups = lcg$TransitionGroupId, lc_code = lc_code, lc_kind = lc_kind, y0 = y0, y1 = y1)
  say("30 m disturbances: %d years on %d workers (blocks of %d x %d pixels)", length(wy), ncl, b$fact, b$fact)
  t0 <- Sys.time(); cl <- makeCluster(ncl)
  res <- tryCatch(parLapply(cl, wy, year_layers, a = args), finally = stopCluster(cl))
  dl <- rbindlist(res)
  layers[[length(layers) + 1]] <- dl[Timestep %in% yrs, .(Timestep, TransitionGroupId, Source, File)]
  say("30 m disturbances done in %.1f min", as.numeric(Sys.time() - t0, units = "mins"))
  check(STAGE, "30 m disturbance multipliers are between 0 and 1", nrow(dl) > 0 && max(dl$Max, na.rm = TRUE) <= 1 + 1e-6, sprintf("max %.4f", max(dl$Max, na.rm = TRUE)))
}

# ---- clearcut from the modal annual NLCD: the cell's class goes from forest to shrub or grass, and most of the cell did not burn
# that year or the year before. Mapped on the same 1 km NLCD as the state class map, so a clearcut cell was forest in some year and
# the any-year forest rule has made it a forest class: only the pathway minimum age can stop it.
burn_frac <- function(y) { f <- dl[Timestep == y & Source == "Mtbs" & !is.na(File), File]
  if (!length(f)) return(init(P, 0)); sum(rast(f)) }   # one severity layer holds each cell's total burned fraction, the rest are 0
if (nrow(ncc)) {
  for (y in yrs) { r <- (N[[as.character(y - 1)]] %in% cc_ft[[1]]) & (N[[as.character(y)]] %in% cc_ft[[2]]) & (burn_frac(y - 1) < 0.5) & (burn_frac(y) < 0.5)
    r <- mask(r, P)
    f <- if (global(r, "sum", na.rm = TRUE)[[1]] > 0) write_raster(r, sprintf("NlcdClearcut_%d.tif", y), "INT1U") else NA_character_
    layers[[length(layers) + 1]] <- data.table(Timestep = y, TransitionGroupId = ncc$TransitionGroupId, Source = "NlcdClearcut", File = f) }
}
layers <- rbindlist(layers)
progressBar()

# ---- minimum harvest ages, settled (user decisions 2026-10-30) -------------------------------------------------------------------
# 1. the study area's own value: each forest type's 10th percentile of stand age at a cell's first cut (stage 5's age map, weighted by
#    the cut share of the cell), where the type has at least Minimum Harvest Age > Minimum mapped area of such cuts (LCMS in P26 cut
#    10-30 years younger at the 10th percentile than FIA's few plots show, dev/harvest/05-lcms-cut-age.R)
# 2. every package (FIA) row is lowered to it; 3. the page's rows replace or add; 4. selection is at most the clearcut minimum minus
#    the offset (the same ecodivision's clearcut, else the type's) and never below the floor, unless the page sets that selection row:
#    thinning comes before final harvest, while FIA and the maps put partial cuts' young tail at or above clearcut's
hg <- rbind(if (nrow(ccs)) data.table(TransitionGroupId = ccs$TransitionGroupId, kind = "clearcut"),
            if (nrow(lcg)) data.table(TransitionGroupId = lcg[grepl("partial", Classes), TransitionGroupId], kind = "selection"))
if (is.null(hg)) hg <- data.table(TransitionGroupId = character(), kind = character())
hg[, TransitionTypeId := vapply(TransitionGroupId, function(g) grp_types(g)[1], "")]
cn <- scl$Name[match(vS, as.integer(scl$Id))]; en <- stl$Name[match(vP, as.integer(stl$Id))]
hl <- layers[TransitionGroupId %in% hg$TransitionGroupId & !is.na(File)][, kind := hg$kind[match(TransitionGroupId, hg$TransitionGroupId)]]
setorder(hl, Timestep, -kind)   # within a year: selection, then clearcut
wq <- function(x, w, p) { o <- order(x); x <- x[o]; w <- w[o]; x[which(cumsum(w) / sum(w) >= p)[1]] }
smap <- data.table(StateClassId = character(), TransitionTypeId = character(), Map = numeric(), MapArea = numeric())
if (isTRUE(H_MAPS) && nrow(hl)) {
  # each harvest's first cut on a cell not yet clearcut (selection leaves the stand age; found 2026-10-30: taking only a cell's first
  # cut of any kind left Placer's clearcut almost unsampled, 1,860 of 2,051 cut cells being first cut by selection)
  # Only cuts after the age map's own year count (found 2026-10-30): the map already shows a stand cut before then as young (CMS 1990
  # moved back to 1985 puts a 1988 clearcut at about 0), so its cut would look like the cut of a very young stand. P26's fir/spruce
  # clearcut value was 10 yr with them, against 34 yr from the 30 m maps with cuts after 1990 only (dev/harvest/05-lcms-cut-age.R).
  asv <- opt$StandAgeSource[1]; AGE_YEAR <- if (!is.null(asv) && !is.na(asv) && (identical(suppressWarnings(as.integer(asv)), 2L) || startsWith(as.character(asv), "TreeMap"))) 2016L else 1990L
  seen <- list(clearcut = rep(FALSE, length(vS)), selection = rep(FALSE, length(vS))); pr <- rep(0, length(vS))
  fc <- rbindlist(lapply(seq_len(nrow(hl)), function(i) { v <- values(rast(hl$File[i]), mat = FALSE); y <- hl$Timestep[i]; k <- hl$kind[i]
    any_cut <- !is.na(v) & v > 0
    on <- any_cut & !seen[[k]] & pr < 0.5 & !is.na(cn) & startsWith(cn, "Forest:") & !is.na(vA) & y > AGE_YEAR; seen[[k]] <<- seen[[k]] | any_cut
    if (k == "clearcut") pr[any_cut] <<- 1 - (1 - pr[any_cut]) * (1 - v[any_cut])
    data.table(StateClassId = cn[on], TransitionTypeId = hg$TransitionTypeId[match(hl$TransitionGroupId[i], hg$TransitionGroupId)], age = vA[on] + (y - y0 - 1), w = v[on]) }))
  if (nrow(fc)) smap <- fc[, .(Map = round(wq(age, w, 0.1)), MapArea = sum(w) * cell_km2), by = .(StateClassId, TransitionTypeId)] }
ha[smap[MapArea >= H_MAP_KM2], on = .(StateClassId, TransitionTypeId), `:=`(Map = i.Map, MapArea = i.MapArea)]
if (!"Map" %in% names(ha)) ha[, `:=`(Map = NA_real_, MapArea = NA_real_)]
ha[, AgeMin := pmin(FIA, Map, na.rm = TRUE)][, Basis := fifelse(!is.na(Map) & Map < FIA, "study area maps", "FIA")]
if (nrow(mh)) {
  ha <- rbind(ha[!paste(Ecodivision, StateClassId, TransitionTypeId) %in% mh[, paste(Ecodivision, StateClassId, TransitionTypeId)]], mh[, Basis := "Minimum Harvest Age page"], fill = TRUE)
  say("Minimum Harvest Age page: %d rows replace or add to the package's (%s)", nrow(mh),
      paste(mh[, sprintf("%s %s%s %g", sub("^Forest: ", "", StateClassId), sub("^.*: Forest ", "", TransitionTypeId), ifelse(is.na(Ecodivision), "", paste0(" in ", Ecodivision)), AgeMin)], collapse = "; ")) }
# selection under clearcut: an ecodivision with its own clearcut row gets its own selection row (from the type's) so the cap can follow it
cce <- ha[TransitionTypeId == CC & !is.na(Ecodivision) & Ecodivision %in% eco_here]
add <- cce[!paste(Ecodivision, StateClassId) %in% ha[TransitionTypeId == SEL & !is.na(Ecodivision), paste(Ecodivision, StateClassId)]]
if (nrow(add)) ha <- rbind(ha, ha[TransitionTypeId == SEL & is.na(Ecodivision)][add[, .(StateClassId, E = Ecodivision)], on = "StateClassId", nomatch = 0][, Ecodivision := E][, E := NULL])
ccap <- function(e, t) { k <- match(paste(e, t), ha[TransitionTypeId == CC, paste(Ecodivision, StateClassId)])
  k0 <- match(t, ha[TransitionTypeId == CC & is.na(Ecodivision), StateClassId]); ifelse(is.na(k), ha[TransitionTypeId == CC & is.na(Ecodivision)]$AgeMin[k0], ha[TransitionTypeId == CC]$AgeMin[k]) }
s <- ha$TransitionTypeId == SEL & !ha$Basis %in% "Minimum Harvest Age page"
if (any(s)) { cap <- ccap(ha$Ecodivision[s], ha$StateClassId[s]) - H_OFFSET; new <- pmax(H_FLOOR, pmin(ha$AgeMin[s], cap, na.rm = TRUE))
  ch <- !is.na(new) & new != ha$AgeMin[s]; ha[which(s)[ch], `:=`(AgeMin = new[ch], Basis = sprintf("clearcut minimum - %g yr", H_OFFSET))] }
hb <- ha[is.na(Ecodivision)]; he <- ha[!is.na(Ecodivision) & Ecodivision %in% eco_here]
tr[hb, on = .(StateClassIdSource = StateClassId, TransitionTypeId), AgeMin := i.AgeMin]
sp <- unique(he[, .(StateClassIdSource = StateClassId, TransitionTypeId)])
# Strata are used everywhere or nowhere: with any ecodivision harvest-age row, every pathway (probabilistic and deterministic) is written
# once per ecodivision here and none is blank-stratum. ST-Sim takes a cell's stratum rows IN PLACE OF the blank-stratum rows, so a mix
# hides pathways: P26 Build 50 had harvest rows by ecodivision for two types and its historical run lost half its fire and urbanization.
if (nrow(sp)) {
  tr <- rbindlist(lapply(eco_here, function(e) copy(tr)[, StratumIdSource := e]))
  tr[he, on = .(StratumIdSource = Ecodivision, StateClassIdSource = StateClassId, TransitionTypeId), AgeMin := i.AgeMin]
  loc <- rbindlist(lapply(eco_here, function(e) copy(loc)[, StratumIdSource := e])) }
setcolorder(tr, "StratumIdSource")
tr <- tr[, names(tr)[vapply(tr, function(v) !all(is.na(v)), TRUE)], with = FALSE]
by_eco <- "StratumIdSource" %in% names(tr)
pset <- function(x, e) x[StratumIdSource == e, sort(paste(StateClassIdSource, TransitionTypeId))]
check(STAGE, "pathways use strata consistently (every row blank, or every ecodivision has every pathway)", !by_eco ||
      (!anyNA(tr$StratumIdSource) && setequal(unique(tr$StratumIdSource), eco_here) && all(vapply(eco_here, function(e) identical(pset(tr, e), pset(tr, eco_here[1])), TRUE)) &&
       "StratumIdSource" %in% names(loc) && !anyNA(loc$StratumIdSource) && setequal(unique(loc$StratumIdSource), eco_here)),
      if (by_eco) sprintf("%d pathway rows over %d ecodivisions", nrow(tr), length(eco_here)) else "no ecodivision rows")
if (by_eco) say("Pathways by ecodivision (an ecodivision harvest age): %d rows, %d deterministic, in each of %s", nrow(tr) / length(eco_here), nrow(loc) / length(eco_here), paste(eco_here, collapse = ", "))
here <-ha[(is.na(Ecodivision) | Ecodivision %in% eco_here) & StateClassId %in% unique(cn) & TransitionTypeId %in% c(CC, SEL)][order(StateClassId, TransitionTypeId, Ecodivision)]
say("Minimum harvest ages (study area maps %s, cuts after %s, at least %g km2; selection at most clearcut - %g yr, at least %g yr):", if (isTRUE(H_MAPS)) "on" else "off", if (exists("AGE_YEAR")) AGE_YEAR else "-", H_MAP_KM2, H_OFFSET, H_FLOOR)
for (i in seq_len(nrow(here))) with(here[i], say("  %s %s%s: %g yr (FIA %s, study area %s; %s)", sub("^Forest: ", "", StateClassId), sub("^.*: Forest ", "", TransitionTypeId),
  if (is.na(Ecodivision)) "" else paste0(" in ", Ecodivision), AgeMin, if (is.na(FIA)) "-" else format(FIA), if (is.na(Map)) "-" else sprintf("%g over %.1f km2", Map, MapArea), Basis))
check(STAGE, "selection minimum ages are not above clearcut's", { cs <- here[TransitionTypeId == SEL & Basis != "Minimum Harvest Age page"]
  all(is.na(cs$AgeMin) | cs$AgeMin <= pmax(H_FLOOR, ccap(cs$Ecodivision, cs$StateClassId) - H_OFFSET) + 1e-9, na.rm = TRUE) })

# ---- harvest minimum age: a harvested cell is at least its pathway's minimum age at its first cut -------------------------------
# Clearcut and selection (LCMS standrep / partial). The start age is raised so the first cut before any clearcut meets the minimum
# (a clearcut resets the age; a later cut on the regrowing stand cannot be helped by the start age and counts as blocked if young).
# Each cell's minimum is its own ecodivision's where the table has one (as the pathways).
age_blocked <- NULL
if (nrow(hg)) {
  min_age <- function(g) { v <- rep(NA_real_, length(vS))
    for (tt in grp_types(g)) { b <- hb[TransitionTypeId == tt]; e <- he[TransitionTypeId == tt]
      x <- b$AgeMin[match(cn, b$StateClassId)]
      if (nrow(e)) { k <- match(paste(en, cn), paste(e$Ecodivision, e$StateClassId)); x[!is.na(k)] <- e$AgeMin[k[!is.na(k)]] }
      v <- pmax(v, x, na.rm = TRUE) }
    v }
  vMin <- setNames(lapply(hg$TransitionGroupId, min_age), hg$TransitionGroupId)
  # ST-Sim ages cells at the end of each timestep, so a cell has aged (y - y0 - 1) years when the year-y transitions run. Any cut counts
  # (LCMS gives fractions of 30 m pixels: on a 1 km grid few cells are half cut, and at >= 0.5 43% of Placer's clearcut was age-blocked).
  # The multiplier is the chance the cell is cut that year, so a cell counts as reset once its chance of an earlier clearcut, pr, reaches
  # one half (found 2026-10-30: counting any clearcut fraction as a reset put 66% of Placer's clearcut area on regrowing stands)
  req <- rep(NA_real_, length(vS)); cut <- rep(FALSE, length(vS)); pr <- rep(0, length(vS)); first <- setNames(rep(0L, 2), c("clearcut", "selection"))
  for (i in seq_len(nrow(hl))) { v <- values(rast(hl$File[i]), mat = FALSE); y <- hl$Timestep[i]; vm <- vMin[[hl$TransitionGroupId[i]]]
    on <- !is.na(v) & v > 0
    hit <- on & pr < 0.5 & !is.na(vm); r <- vm[hit] - (y - y0 - 1); req[hit] <- pmax(req[hit], r, na.rm = TRUE)
    first[hl$kind[i]] <- first[hl$kind[i]] + sum(on & !cut); cut <- cut | on
    if (hl$kind[i] == "clearcut") pr[on] <- 1 - (1 - pr[on]) * (1 - v[on]) }
  raise <- !is.na(req) & !is.na(vA) & vA < req
  vA2 <- vA; vA2[raise] <- req[raise]
  say("Harvest minimum age: %d cells cut (first cut: %d selection, %d clearcut); %d start ages raised, by %.0f years on average (median %.0f)",
      sum(cut), first[["selection"]], first[["clearcut"]], sum(raise), if (any(raise)) mean(req[raise] - vA[raise]) else 0, if (any(raise)) median(req[raise] - vA[raise]) else 0)
  for (t in unique(cn[raise])) say("  %s: %d cells raised by %.0f years on average", sub("^Forest: ", "", t), sum(raise & cn == t), mean((req - vA)[raise & cn == t]))
  # blocked, expected area: a cut on a cell not yet reset (chance 1 - pr) is blocked if the raised start age has not reached the minimum;
  # one on a reset cell (chance pr) if the years since its last clearcut have not
  last <- rep(NA_real_, length(vS)); pr <- rep(0, length(vS)); after <- 0
  age_blocked <- rbindlist(lapply(seq_len(nrow(hl)), function(i) { v <- values(rast(hl$File[i]), mat = FALSE); y <- hl$Timestep[i]; vm <- vMin[[hl$TransitionGroupId[i]]]
    on <- !is.na(v) & v > 0 & !is.na(vm)
    b0 <- (vA2 + (y - y0 - 1)) < vm; b1 <- !is.na(last) & (y - last - 1) < vm
    e0 <- v * (1 - pr) * b0; e1 <- v * pr * b1; after <<- after + sum(e1[on]) * cell_km2
    if (hl$kind[i] == "clearcut") { pr[on] <<- 1 - (1 - pr[on]) * (1 - v[on]); last[on] <<- y }
    data.table(Timestep = y, TransitionGroupId = hl$TransitionGroupId[i], AgeBlockedArea = sum((e0 + e1)[on]) * cell_km2) }))[, .(AgeBlockedArea = sum(AgeBlockedArea)), by = .(Timestep, TransitionGroupId)]
  say("Harvest minimum age: %.1f km2 of cuts expected below the minimum, %.1f km2 of them on stands regrowing after a clearcut", sum(age_blocked$AgeBlockedArea), after)
  check(STAGE, "stand age after the harvest age rule is set on every land cell", !any(land & is.na(vA2)), sprintf("%d land cells without an age", sum(land & is.na(vA2))))
  A <- setValues(A, vA2)
}
progressBar()

# ---- ag contraction destinations: the nearest natural state class of the start year --------------------------------------
gates <- NULL; nv <- so[Source == "NaturalVeg"]
if (nrow(nv)) {
  Nat <- fill_modal(mask(ifel(S >= 40 & !(S %in% c(81, 82)), S, NA), m), m, 71)
  check(STAGE, "every land cell has a natural class for ag contraction", !any(land & is.na(values(Nat, mat = FALSE))))
  gt <- unique(pw[TransitionTypeId %in% unlist(lapply(nv$TransitionGroupId, grp_types)), .(TransitionTypeId, StateClassIdDest)])
  multi <- gt[, .N, by = TransitionTypeId][N > 1]
  check(STAGE, "each ag contraction type leads to a single state class", !nrow(multi), paste(multi$TransitionTypeId, collapse = "; "))
  gfile <- list()
  for (d in unique(gt$StateClassIdDest)) { id <- sid(d); r <- mask(Nat == id, P)
    gfile[[d]] <- if (global(r, "sum", na.rm = TRUE)[[1]] > 0) write_raster(r, sprintf("NaturalVeg-%d.tif", id), "INT1U") else off_file }
  gates <- gt[, .(Timestep = y0, TransitionGroupId = paste0(TransitionTypeId, TYPE_SUFFIX), MultiplierFileName = unlist(gfile[StateClassIdDest]))]
  say("Ag contraction: %d types gated to %d natural classes (%d present in the study area)", nrow(gt), length(gfile), sum(unlist(gfile) != off_file))
}
progressBar()

# ---- spatial multipliers, zero targets, checks ---------------------------------------------------------------------------
# every group with a time-varying source has a row in every year (Off when nothing happened), Off in the start year, and Off after
# the end year so that a projection does not inherit the last historical year
dyn <- unique(layers$TransitionGroupId)
grid_rows <- CJ(TransitionGroupId = dyn, Timestep = c(y0, yrs, y1 + 1))
sm <- merge(grid_rows, layers[, .(TransitionGroupId, Timestep, File)], by = c("TransitionGroupId", "Timestep"), all.x = TRUE)
sm[is.na(File), File := off_file]
sm <- rbind(sm[, .(Timestep, TransitionGroupId, MultiplierFileName = File)], gates)
full <- sm[TransitionGroupId %in% dyn & Timestep %in% c(y0, yrs, y1 + 1) & !is.na(MultiplierFileName), .(N = uniqueN(Timestep)), by = TransitionGroupId][N == length(yrs) + 2]
check(STAGE, "every time-varying group has a multiplier in every year", setequal(full$TransitionGroupId, dyn), paste(setdiff(dyn, full$TransitionGroupId), collapse = "; "))

covered <- unique(unlist(lapply(dyn, grp_types)))
zero <- setdiff(unique(pw$TransitionTypeId), covered)
tt0 <- data.table(Timestep = y0, TransitionGroupId = paste0(zero, TYPE_SUFFIX), Amount = 0)
check(STAGE, "every pathway type has a time-varying multiplier or a zero target", length(covered) + length(zero) >= uniqueN(pw$TransitionTypeId),
      sprintf("%d with multipliers, %d with zero targets (%s)", length(intersect(covered, pw$TransitionTypeId)), length(zero), paste(zero, collapse = "; ")))

# expected area per group and year; the area on start-year classes no type of the group can leave (land use moves on, so later-year
# figures are indicative)
el <- setNames(lapply(dyn, elig_cells), dyn)
# several land-use groups share one NLCD map (a cell becoming 22 is Urbanization: Low from natural or agricultural land, Intensification:
# Open to Low from 21), and the pathways split its cells by their class the year before; a group's area counts only the cells whose
# prior-year modal NLCD class fits its source classes, as stage 9 does (found 2026-10-24: each sharing group was given the whole map, so
# the summary's urbanization and intensification overstated the change by up to 3x)
LU <- c(21:24, 81L, 82L)
src_ids <- function(g) sid(unique(pw[TransitionTypeId %in% grp_types(g), StateClassIdSource]))
fits_prev <- function(g, y) { s <- src_ids(g); lu <- intersect(s, LU); n <- values(N[[as.character(y - 1)]], mat = FALSE)
  (n %in% lu) | (any(!s %in% LU) & !(n %in% LU)) }
summ <- layers[!is.na(File), { v <- values(rast(File), mat = FALSE); v[is.na(v)] <- 0
  if (Source %in% c("NlcdGain", "NlcdLoss")) v[!fits_prev(TransitionGroupId, Timestep)] <- 0
  .(Area = sum(v) * cell_km2, Cells = sum(v > 0), IneligibleArea = sum(v[!el[[TransitionGroupId]]]) * cell_km2) }, by = .(Timestep, TransitionGroupId, Source)]
if (!is.null(age_blocked)) summ <- merge(summ, age_blocked, by = c("Timestep", "TransitionGroupId"), all.x = TRUE) else summ[, AgeBlockedArea := NA_real_]
tot <- summ[, .(Area = sum(Area), Inel = sum(IneligibleArea), Blocked = sum(AgeBlockedArea, na.rm = TRUE), Years = .N), by = .(TransitionGroupId, Source)][order(Source, TransitionGroupId)]
for (i in seq_len(nrow(tot))) with(tot[i], say("%s (%s): %.0f km2 over %d years with any; %.1f%% on classes with no pathway%s", TransitionGroupId, Source, Area, Years,
                                               100 * Inel / max(Area, 1e-9), if (Blocked > 0) sprintf("; %.1f%% below the minimum age", 100 * Blocked / Area) else ""))
progressBar()

# ---- outputs ----------------------------------------------------------------------------------------------------------
write_stsim(tr, "Transition")
write_stsim(loc, "DeterministicTransition")
write_stsim(sm, "TransitionSpatialMultiplier")
if (nrow(tt0)) write_stsim(tt0, "TransitionTarget")
if (!is.null(age_blocked)) { row <- ic[1]; row$AgeFileName <- write_raster(A, "StandAge.tif"); saveDatasheet(scn, as.data.frame(row), "stsim_InitialConditionsSpatial") }
write_ds(summ[order(Timestep, Source, TransitionGroupId), .(Timestep, TransitionGroup = TransitionGroupId, Source, Area, Cells, IneligibleArea, AgeBlockedArea)], "OutputTransitionSummary")
write_ds(here[, .(StratumId = Ecodivision, StateClassId, TransitionTypeId, FiaAge = FIA, StudyAreaAge = Map, StudyAreaKm2 = round(MapArea, 2), AgeMin, Basis)], "OutputHarvestAge")
progressBar()
finish_checks()
progressBar(type = "end")
