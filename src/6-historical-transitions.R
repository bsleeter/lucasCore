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
# Changes from the CONUS 1km build:
#   * MTBS and LANDFIRE give each cell the fraction of its 30 m pixels that had the disturbance, so the expected area equals the 30 m
#     area (the build sampled one 30 m pixel per cell). Both have pathways on every class they occur on, so this keeps the maps coherent.
#     The cell's whole burned fraction goes to its most common severity, so the severities never compete for a cell (ST-Sim allows one
#     transition per cell per timestep)
#   * selection uses LANDFIRE's Thinning type in every year; the build's code ranges (441-443, 741-743, 941) missed codes 940 and 942-948
#     and do not apply to the 4-digit codes LANDFIRE uses from 2024
#   * clearcut cells get at least the clearcut pathway's minimum age in their first clearcut year (the build
#     required the minimum age in the start year)
#   * every pathway type with no spatial multiplier gets a zero target, so no type runs everywhere by default
# Needs stage 5 (same pipeline, or a dependency on its result).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
suppressPackageStartupMessages({ library(terra); library(sf); library(parallel) })
STAGE <- "6 Historical Transitions"
progressBar(type = "begin", totalSteps = 8)

src <- read_data_sources(c("EcodivisionFile", "NlcdFolder", "MtbsSeverityFolder", "LandfireDisturbanceFolder"))
opt <- read_ds("BuildOptions"); y0 <- opt$StartYear[1]; y1 <- opt$EndYear[1]; yrs <- (y0 + 1):y1
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StateClassFileName[1]) || is.na(ic$AgeFileName[1])) fail("no state class or age map: run stage 5 first (same pipeline, or depend on a stage 5 result)")
P <- rast(ic$StratumFileName[1]); S <- rast(ic$StateClassFileName[1]); A <- rast(ic$AgeFileName[1]); m <- !is.na(P)
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
tr <- tr[, names(tr)[vapply(tr, function(v) !all(is.na(v)), TRUE)], with = FALSE]
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
fire <- so[Source == "Mtbs"]; ccs <- so[Source == "NlcdClearcut"]; lfg <- so[Source == "Landfire"]
if (nrow(ccs) > 1) fail("sources.csv: only one NlcdClearcut group is supported")
cc_ft <- if (nrow(ccs)) lapply(strsplit(ccs$Classes, ">", fixed = TRUE)[[1]], codes) else list(integer(), integer())
lf_types <- strsplit(lfg$Classes, "|", fixed = TRUE)
nf <- setNames(file.path(src$NlcdFolder, sprintf("Annual_NLCD_LndCov_%d_CU_C1V0.tif", (y0):y1)), y0:y1)
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
  has_fire <- length(a$fire_groups) && "m" %in% names(col)
  grp <- c(if (has_fire) a$fire_groups, if (!is.null(li)) a$lf_groups)
  part <- c(if (has_fire) rep("fire", length(a$fire_groups)), if (!is.null(li)) rep("lf", length(a$lf_groups)))
  if (!length(grp)) return(NULL)
  flag <- function(v) { v <- as.matrix(v); out <- matrix(0L, nrow(v), length(grp)); j <- 0
    if (has_fire) for (cc in a$fire_codes) { j <- j + 1; out[, j] <- v[, col[["m"]]] %in% cc }
    if (!is.null(li)) for (cc in li$codes) { j <- j + 1; out[, j] <- v[, col[["lf"]]] %in% cc }
    out }
  ind <- app(rast(lay), flag, wopt = list(datatype = "INT1U", gdal = "COMPRESS=DEFLATE"))
  fr <- mask(project(aggregate(ind, a$fact, "mean"), P, method = "near"), P)
  # within a source with several groups (fire severities), the cell's total fraction goes to its most common group
  for (p in unique(part)) { i <- which(part == p); if (length(i) < 2) next
    tot <- sum(fr[[i]]); w <- which.max(fr[[i]]); for (j in seq_along(i)) fr[[i[j]]] <- ifel(w == j, tot, 0) }
  out <- rbindlist(lapply(seq_along(grp), function(j) { r <- fr[[j]]; s <- global(r, "sum", na.rm = TRUE)[[1]]
    f <- if (s > 0) { p <- file.path(a$td, sprintf("%s_%d.tif", gsub("[^A-Za-z0-9]+", "-", sub(" [Type]", "", grp[j], fixed = TRUE)), y))
      writeRaster(r, p, overwrite = TRUE, datatype = "FLT4S", gdal = c("COMPRESS=DEFLATE", "TILED=YES")); p } else NA_character_
    data.table(Timestep = y, TransitionGroupId = grp[j], Source = c(fire = "Mtbs", lf = "Landfire")[[part[j]]], File = f,
               Max = global(r, "max", na.rm = TRUE)[[1]]) }))
  tmpFiles(remove = TRUE); out }

dl <- data.table(Timestep = integer(), TransitionGroupId = character(), Source = character(), File = character(), Max = numeric())
if (nrow(fire) || nrow(lfg)) {
  b <- grid_blocks(rast(nf[[1]]), L, P)
  wy <- c(y0, yrs)   # the start year's fire is needed for the first year's clearcut burn test
  ncl <- max(1, min(length(wy), 40, detectCores() - 2))
  args <- list(clear = clear_syncrosim_proj, memfrac = 0.6 / ncl, pf = ic$StratumFileName[1], E = as.vector(b$ext), fact = b$fact, td = TD(),
               nf = as.list(nf), mt = as.list(mt), lf = lf, fire_groups = fire$TransitionGroupId, fire_codes = lapply(fire$Classes, codes), lf_groups = lfg$TransitionGroupId)
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
if (nrow(ccs)) {
  for (y in yrs) { r <- (N[[as.character(y - 1)]] %in% cc_ft[[1]]) & (N[[as.character(y)]] %in% cc_ft[[2]]) & (burn_frac(y - 1) < 0.5) & (burn_frac(y) < 0.5)
    r <- mask(r, P)
    f <- if (global(r, "sum", na.rm = TRUE)[[1]] > 0) write_raster(r, sprintf("NlcdClearcut_%d.tif", y), "INT1U") else NA_character_
    layers[[length(layers) + 1]] <- data.table(Timestep = y, TransitionGroupId = ccs$TransitionGroupId, Source = "NlcdClearcut", File = f) }
}
layers <- rbindlist(layers)
progressBar()

# ---- clearcut minimum age: a clearcut cell is at least the pathway's minimum age in its first clearcut year -------------------
age_blocked <- NULL
if (nrow(ccs)) {
  am <- pw[TransitionTypeId %in% grp_types(ccs$TransitionGroupId) & !is.na(AgeMin), .(AgeMin = max(as.integer(AgeMin))), by = StateClassIdSource]
  vMin <- am$AgeMin[match(vS, sid(am$StateClassIdSource))]
  req <- rep(NA_real_, length(vS)); ccl <- layers[TransitionGroupId == ccs$TransitionGroupId & !is.na(File)]
  # ST-Sim ages cells at the end of each timestep, so a cell has aged (y - y0 - 1) years when the year-y transitions run
  for (i in order(ccl$Timestep)) { v <- values(rast(ccl$File[i]), mat = FALSE); y <- ccl$Timestep[i]
    hit <- !is.na(v) & v >= 0.5 & is.na(req) & !is.na(vMin); req[hit] <- vMin[hit] - (y - y0 - 1) }
  raise <- !is.na(req) & !is.na(vA) & vA < req
  vA2 <- vA; vA2[raise] <- req[raise]
  say("Clearcut minimum age: %d cells cut; %d raised, by %.0f years on average", sum(!is.na(req)), sum(raise), if (any(raise)) mean(req[raise] - vA[raise]) else 0)
  age_blocked <- rbindlist(lapply(seq_len(nrow(ccl)), function(i) { v <- values(rast(ccl$File[i]), mat = FALSE); y <- ccl$Timestep[i]
    bl <- !is.na(v) & v > 0 & !is.na(vMin) & (vA2 + (y - y0 - 1)) < vMin
    data.table(Timestep = y, TransitionGroupId = ccl$TransitionGroupId[i], AgeBlockedArea = sum(v[bl]) * cell_km2) }))
  check(STAGE, "stand age after the clearcut rule is set on every land cell", !any(land & is.na(vA2)), sprintf("%d land cells without an age", sum(land & is.na(vA2))))
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
summ <- layers[!is.na(File), { v <- values(rast(File), mat = FALSE); v[is.na(v)] <- 0
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
if (nrow(ccs)) { row <- ic[1]; row$AgeFileName <- write_raster(A, "StandAge.tif"); saveDatasheet(scn, as.data.frame(row), "stsim_InitialConditionsSpatial") }
write_ds(summ[order(Timestep, Source, TransitionGroupId), .(Timestep, TransitionGroup = TransitionGroupId, Source, Area, Cells, IneligibleArea, AgeBlockedArea)], "OutputTransitionSummary")
progressBar()
finish_checks()
progressBar(type = "end")
