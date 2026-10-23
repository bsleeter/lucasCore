# =============================================================================
# 9-projection-transitions.R - stage 9: projection transitions that resample whole historical years
# =============================================================================
# For the projection years (Build Options: historical end + 1 to the projection end), each transition group follows its row of
# Projection Transitions (an empty sheet uses defaults/projection/transitions.csv). User decisions 2026-10-22:
#   * each projection year and iteration draws one historical year from the reference period (Projection Options; blank = all
#     historical transition years); groups in the same Sampling Set draw the same year, so land-use change keeps the mix of one real
#     year, while fire draws its own (OutputProjectionSchedule lists every draw; the seed makes it repeatable)
#   * Target: the area the group had in the drawn year, in each unit of the chosen strata level (from stage 6's annual multiplier
#     maps), as Transition Targets; the group's spatial multiplier becomes 1 where it may happen (0 on excluded GAP status). Every unit
#     gets a row for every iteration and year, zeros included, because without a target the multiplier alone would let every eligible
#     cell transition
#   * named groups (the default rules, 2026-10-22): a Target named group (Urbanization) gets one area per unit and year, its members'
#     areas summed, and the spatial allocation decides which member type each cell gets; Historical Type Shares (Projection Options)
#     weights the members by their historical shares instead. A Probability named group (Fire) is split into its members
#   * fire (Fire Options; user decisions 2026-10-23): the fire group stays one group. Method 1: each drawn year gives every pyrome its
#     burned fraction of the burnable land (the group's map, times a slope selectivity fitted as the burned share by slope in the
#     historical fire maps, rescaled within the pyrome so its total holds); each severity type gets the drawn year's own share of
#     that pyrome's burned area; fires are sized from the interagency perimeters (wildfire, one per incident and year) as an ST-Sim
#     size distribution from the historical end + 1. Methods 2 (burn probability) and 3 (lucasFireC2F seasons) come next
#   * Probability: the group's burned (or changed) fraction of the eligible area of each unit of any Stratum Source in the drawn year,
#     as a per-cell multiplier map; it does not depend on the strata, so fire can use pyromes while land use uses counties
#   * None: the group stays off after the historical end (stage 6's Off rows)
#   * Spatial multiprocessing (Projection Options: Spatial Tiles): targets only add up if no target unit is split between tiles, so
#     every Target group must use one strata level and the tiles are made of whole units of it; Probability groups are exempt
# Needs stage 6 (same pipeline, or a dependency on its result). Writes nothing without a projection end year.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "strata.R"))
suppressPackageStartupMessages({ library(terra); library(sf) })
STAGE <- "9 Projection Transitions"
progressBar(type = "begin", totalSteps = 6)

opt <- read_ds("BuildOptions"); y0 <- opt$StartYear[1]; y1 <- opt$EndYear[1]
pend <- if ("ProjectionEndYear" %in% names(opt)) opt$ProjectionEndYear[1] else NA
if (is.na(pend)) { say("No projection in Build Options: stage 9 has nothing to do"); progressBar(type = "end"); quit(save = "no") }
if (pend <= y1) fail("Build Options: the projection end year (%d) must be after the historical end (%d)", pend, y1)
pyrs <- (y1 + 1):pend
po <- read_ds("ProjectionOptions")
nz <- function(v, d) if (is.null(v) || !length(v) || is.na(v[1])) d else v[1]
rs <- nz(po$ReferenceStartYear, y0 + 1); re <- nz(po$ReferenceEndYear, y1)
if (rs < y0 + 1 || re > y1 || rs > re) fail("Projection Options: reference period %d-%d must lie within the historical transition years %d-%d", rs, re, y0 + 1, y1)
ref <- rs:re; nit <- nz(po$Iterations, 10L); seed <- nz(po$RandomSeed, 1L); tiles <- nz(po$SpatialTiles, 1L)
say("Projection %d-%d, %d iterations; each year draws a historical year from %d-%d (seed %d)", min(pyrs), pend, nit, rs, re, seed)

# ---- the rules ----------------------------------------------------------------------------------------------------------
pt <- read_ds("ProjectionTransition")
if (!nrow(pt)) { pt <- read_default("projection", "transitions.csv"); src_rules <- "defaults/projection/transitions.csv"
} else { setnames(pt, "UnitSourceId", "UnitSource", skip_absent = TRUE); src_rules <- "the Projection Transitions sheet" }
pt[, Method := sub(" .*", "", Method)]; pt[, StrataLevel := sub(" .*", "", StrataLevel)]
for (k in c("UnitSource", "ExcludeGap", "SamplingSet", "StrataLevel")) if (!k %in% names(pt)) pt[, (k) := NA_character_]
pt[is.na(SamplingSet) | !nzchar(SamplingSet), SamplingSet := TransitionGroupId]
bad <- pt[!Method %in% c("Target", "Probability", "None")]; if (nrow(bad)) fail("Projection Transitions: unknown method for %s", paste(bad$TransitionGroupId, collapse = "; "))
bad <- pt[Method == "Target" & !StrataLevel %in% c("Primary", "Secondary", "Tertiary")]; if (nrow(bad)) fail("Projection Transitions: a Target group needs Target Strata: %s", paste(bad$TransitionGroupId, collapse = "; "))
bad <- pt[Method == "Probability" & (is.na(UnitSource) | !nzchar(UnitSource))]; if (nrow(bad)) fail("Projection Transitions: a Probability group needs Rate Units: %s", paste(bad$TransitionGroupId, collapse = "; "))
say("Rules from %s: %s", src_rules, paste(pt[, sprintf("%d %s", .N, Method[1]), by = Method]$V1, collapse = ", "))

# ---- stage 6's maps, the grid, the strata ---------------------------------------------------------------------------------
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StateClassFileName[1])) fail("no state class map: run stages 1, 5 and 6 first")
P <- rast(ic$StratumFileName[1]); S2 <- rast(ic$SecondaryStratumFileName[1]); S3 <- rast(ic$TertiaryStratumFileName[1]); S <- rast(ic$StateClassFileName[1])
land <- !is.na(values(P, mat = FALSE)); vS <- values(S, mat = FALSE)

# ---- mode 2: a stand-alone projection starts from a historical run's final maps (Projection Start) ----------------------------
# The historical run (a result scenario in this library, made with tools/new-historical.R --historical-only --bookend-maps) gives the
# state class and age of its first iteration in the historical end year, and one map per stock type ("<type> [Type]" stock groups);
# they replace the build's initial conditions and initial stocks, so ST-Sim continues from that state.
pst <- read_ds("ProjectionStart"); hid <- if (nrow(pst) && "HistoricalScenarioId" %in% names(pst)) pst$HistoricalScenarioId[1] else NA
if (!is.na(hid)) {
  ys <- if ("StartYear" %in% names(pst) && !is.na(pst$StartYear[1])) pst$StartYear[1] else y1
  if (ys != y1) fail("Projection Start: the start year must be the historical end (%d); the projection draws start in %d", y1, y1 + 1)
  hd <- file.path(paste0(env$LibraryFilePath, ".data"), sprintf("Scenario-%d", hid))
  scf <- file.path(hd, "stsim_OutputSpatialState", sprintf("sc.it1.ts%d.tif", ys)); agf <- file.path(hd, "stsim_OutputSpatialAge", sprintf("age.it1.ts%d.tif", ys))
  if (!file.exists(scf) || !file.exists(agf)) fail("Projection Start: historical run %d has no state class and age maps for %d (make it with tools/new-historical.R --historical-only --bookend-maps)", hid, ys)
  sg <- as.data.table(datasheet(prj, "stsim_StockGroup", includeKey = TRUE))
  ist <- as.data.table(datasheet(scn, "stsim_InitialStockSpatial", optional = TRUE, lookupsAsFactors = FALSE))
  if (!nrow(ist)) fail("Projection Start: the build has no initial stocks (stage 8) to know the stock types")
  stf <- vapply(ist$StockTypeId, function(t) { id <- sg[Name == paste0(t, " [Type]"), StockGroupId]
    f <- if (length(id)) file.path(hd, "stsim_OutputAverageSpatialStockGroup", sprintf("avgstkg_%d.it0.ts%d.tif", id[1], ys)) else NA_character_
    if (is.na(f) || !file.exists(f)) NA_character_ else f }, "")
  if (anyNA(stf)) fail("Projection Start: historical run %d has no %d map for %s (its Stock-Flow output must map every stock type)", hid, ys, paste(ist$StockTypeId[is.na(stf)], collapse = ", "))
  S <- mask(rast(scf), P); A <- mask(rast(agf), P)
  check(STAGE, "the historical run's maps are on the build's grid", compareGeom(S, P, stopOnError = FALSE), sprintf("run %d", hid))
  row <- ic[1]; row$StateClassFileName <- write_raster(S, sprintf("Start-StateClass_%d.tif", ys)); row$AgeFileName <- write_raster(A, sprintf("Start-Age_%d.tif", ys))
  saveDatasheet(scn, as.data.frame(row), "stsim_InitialConditionsSpatial")
  sfiles <- vapply(seq_along(stf), function(j) write_raster(mask(rast(stf[j]), P), sprintf("Start-%s_%d.tif", gsub("[^A-Za-z0-9]+", "-", ist$StockTypeId[j]), ys), "FLT4S"), "")
  write_stsim(data.table(StockTypeId = ist$StockTypeId, RasterFileName = sfiles), "InitialStockSpatial")
  vS <- values(S, mat = FALSE)
  tot <- sum(vapply(stf, function(f) global(mask(rast(f), P), "sum", na.rm = TRUE)[[1]], 0)) * prod(res(P)) / 1e4 / 1e6
  say("Projection Start: state class, age and %d stock maps of historical run %d in %d (%.2f Tg C in the stock types)", length(stf), hid, ys, tot)
}
sm <- as.data.table(datasheet(scn, "stsim_TransitionSpatialMultiplier", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(sm)) fail("no transition spatial multipliers: run stage 6 first")
if (!"Iteration" %in% names(sm)) sm[, Iteration := NA_integer_]
tt <- as.data.table(datasheet(scn, "stsim_TransitionTarget", optional = TRUE, lookupsAsFactors = FALSE))
term <- as.data.table(datasheet(prj, "stsim_Terminology", optional = TRUE, lookupsAsFactors = FALSE))
units_per_ha <- c(acres = 2.4710538, hectares = 1, `square kilometers` = 0.01, `square meters` = 1e4, `square miles` = 0.003861022)
au <- if (nrow(term) && !is.na(term$AmountUnits[1])) tolower(term$AmountUnits[1]) else "hectares"
if (!au %in% names(units_per_ha)) fail("stsim Terminology amount units '%s' are not known", au)
cell_amt <- prod(res(P)) / 1e4 * units_per_ha[[au]]; cell_km2 <- prod(res(P)) / 1e6
say("Grid: %d land cells of %g m; target amounts in %s (%.4g per cell)", sum(land), res(P)[1], au, cell_amt)
# eligibility: the start-year classes a group's pathways can leave (as stage 6)
scl <- stsim_list("StateClass"); ttg <- stsim_list("TransitionTypeGroup")
pf <- list.files(pkg_file("defaults", "transitions", "pathways"), "[.]csv$", full.names = TRUE)
pw <- rbindlist(lapply(pf, function(f) fread(f, colClasses = "character", na.strings = "")), fill = TRUE)
TYPE_SUFFIX <- " [Type]"
grp_types <- function(g) if (endsWith(g, TYPE_SUFFIX)) substr(g, 1, nchar(g) - nchar(TYPE_SUFFIX)) else ttg[TransitionGroupId == g, TransitionTypeId]
elig <- function(g) land & vS %in% as.integer(scl$Id[match(unique(pw[TransitionTypeId %in% grp_types(g), StateClassIdSource]), scl$Name)])

# named groups (user decision 2026-10-22): stage 6 maps the history per type group ("Urbanization: Low [Type]") or per sub-group
# ("Ag Contraction: Cropland"); a named group (Urbanization) without maps of its own works through its members - the groups with
# annual maps whose types all belong to it. A Target named group gets one area per unit and year, the sum of its members' areas, and the
# spatial allocation decides which member type each cell gets (Projection Options: Historical Type Shares weights them by their
# historical shares instead); a Probability named group is split into its members, each with its own rate map (fire per severity), all
# drawing the same year. Stage 6's static gate rows (Ag Contraction's nearest natural class) are not annual, so they stay as they are.
ann <- unique(sm[Timestep > y0 & Timestep <= y1, TransitionGroupId])
members <- function(g) { if (g %in% ann) return(g); ty <- grp_types(g); ann[vapply(ann, function(m) length(grp_types(m)) > 0 && all(grp_types(m) %in% ty), TRUE)] }
mem <- setNames(lapply(pt$TransitionGroupId, members), pt$TransitionGroupId)
miss <- pt[Method != "None" & lengths(mem[TransitionGroupId]) == 0, TransitionGroupId]
if (length(miss)) { say("No historical multiplier maps for %s: off in the projection", paste(miss, collapse = "; ")); pt[TransitionGroupId %in% miss, Method := "None"] }
tm <- unlist(mem[pt[Method == "Target", TransitionGroupId]], use.names = FALSE)
if (anyDuplicated(tm)) fail("Projection Transitions: %s would be targeted twice (a group and its own members, or two groups sharing members, are both Target)", paste(unique(tm[duplicated(tm)]), collapse = "; "))
# the fire group (Fire Options) is not split: its severity members get the drawn year's shares (below)
fo <- read_ds("FireOptions"); fire_g <- nz(fo$TransitionGroupId, "Fire")
fire_m <- c(Historical = 1L, Burn = 2L, lucasFireC2F = 3L)[sub(" .*", "", as.character(nz(fo$FireMethod, "Historical")))]; if (is.na(fire_m)) fire_m <- 1L
slope_on <- { v <- nz(fo$SlopeSelectivity, TRUE); isTRUE(as.logical(v)) || identical(v, -1L) || identical(v, 1L) }
ign_src <- c(Burn = 1L, `FPA-FOD` = 2L)[sub(" .*", "", as.character(nz(fo$IgnitionSource, "Burn")))]; if (is.na(ign_src)) ign_src <- 1L
pr <- pt[Method == "Probability" & !TransitionGroupId %in% ann & TransitionGroupId != fire_g]
if (nrow(pr)) { say("Probability named groups split into their members: %s", paste(vapply(pr$TransitionGroupId, function(g) sprintf("%s (%s)", g, paste(mem[[g]], collapse = ", ")), ""), collapse = "; "))
  pt <- rbind(pt[!TransitionGroupId %in% pr$TransitionGroupId], pr[, .(TransitionGroupId = mem[[TransitionGroupId]]), by = setdiff(names(pr), "TransitionGroupId")], use.names = TRUE)
  for (g in pt$TransitionGroupId) if (is.null(mem[[g]])) mem[[g]] <- g }
# default on (user decision 2026-10-22): a blank setting weights the types by their historical shares
type_shares <- { v <- nz(po$HistoricalTypeShares, TRUE); isTRUE(as.logical(v)) || identical(v, -1L) || identical(v, 1L) }
# a group's historical map for year y (stage 6 writes one row per group and year; Off.tif = nothing happened)
# (a build that already ran stage 9 holds Probability groups' historical rows per iteration instead: take iteration 1's, which are
# copies of the shared row)
hist_file <- function(g, y) { f <- sm[TransitionGroupId == g & Timestep == y & is.na(Iteration), MultiplierFileName]
  if (!length(f)) f <- sm[TransitionGroupId == g & Timestep == y & Iteration %in% 1L, MultiplierFileName]
  if (length(f)) f[1] else NA_character_ }
hist_vals <- function(g, y) { f <- hist_file(g, y); if (is.na(f)) return(numeric(length(land))); v <- values(rast(f), mat = FALSE); v[is.na(v)] <- 0; v }
# several groups share one NLCD gain map (gain to Medium: Urbanization: Medium, Intensification: Open to Medium and Low to Medium), and the
# pathways split its cells by their class the year before; a group's own area counts only the cells whose prior-year modal NLCD class
# fits its source classes: one of the group's developed (21-24) or agriculture (81, 82) source classes, or - when the group also starts
# from natural classes - neither developed nor agriculture (found 2026-10-22: without this every sharing group got the whole map, and projected urbanization was 2-3x)
LU <- c(21:24, 81L, 82L)
nl <- read_ds("OutputNlcdAnnual"); if (!nrow(nl)) fail("no annual NLCD table: run stage 5 first")
nlcd_prev <- function(y) { f <- nl$FileName[nl$Year == y - 1]; if (!length(f)) fail("annual NLCD for %d is missing", y - 1); values(rast(f), mat = FALSE) }
src_ids <- function(g) as.integer(scl$Id[match(unique(pw[TransitionTypeId %in% grp_types(g), StateClassIdSource]), scl$Name)])
fits_prev <- function(g, y) { s <- src_ids(g); lu <- intersect(s, LU); n <- nlcd_prev(y)
  (n %in% lu) | (any(!s %in% LU) & !(n %in% LU)) }
progressBar()

# strata for targets, units for rates, GAP status
lev <- list(Primary = values(P, mat = FALSE), Secondary = values(S2, mat = FALSE), Tertiary = values(S3, mat = FALSE))
lev_list <- list(Primary = stsim_list("Stratum"), Secondary = stsim_list("SecondaryStratum"), Tertiary = stsim_list("TertiaryStratum"))
lev_col <- c(Primary = "StratumId", Secondary = "SecondaryStratumId", Tertiary = "TertiaryStratumId")
rows <- sources_from_sheet(as.data.table(datasheet(prj, ds("StratumSource"), optional = TRUE, lookupsAsFactors = FALSE)))
unit_maps <- list()
unit_map <- function(name) { if (is.null(unit_maps[[name]])) { s <- rows[[name]]; if (is.null(s)) fail("Projection Transitions: no Stratum Source '%s'", name)
    unit_maps[[name]] <<- values(strata_raster(s, env$PackageDirectory, rast(P), P), mat = FALSE) }
  unit_maps[[name]] }
gap <- if (any(!is.na(pt$ExcludeGap) & nzchar(pt$ExcludeGap))) unit_map("GAP Status") else NULL
progressBar()

# ---- the draws -----------------------------------------------------------------------------------------------------------
sets <- sort(unique(pt[Method != "None", SamplingSet]))
sched <- rbindlist(lapply(seq_along(sets), function(i) { set.seed(seed * 1000L + i)
  d <- CJ(Iteration = seq_len(nit), Timestep = pyrs); d[, `:=`(SamplingSet = sets[i], HistoricalYear = sample(ref, .N, replace = TRUE))]; d }))
check(STAGE, "every draw is a reference year", all(sched$HistoricalYear %in% ref))
say("Sampling sets: %s", paste(sprintf("%s (%s)", sets, vapply(sets, function(s) paste(pt[SamplingSet == s, .N], "groups"), "")), collapse = "; "))

# ---- targets ------------------------------------------------------------------------------------------------------------
tg <- pt[Method == "Target"]; new_tt <- list(); new_sm <- list(); rates <- list(); allow_files <- list()
for (i in seq_len(nrow(tg))) { g <- tg$TransitionGroupId[i]; L <- tg$StrataLevel[i]; u <- lev[[L]]; units <- sort(unique(u[land])); ms <- mem[[g]]
  # area per unit and historical year, in the target's amount units: the sum of the members' areas
  am <- lapply(ms, function(m) { a <- vapply(ref, function(y) { v <- hist_vals(m, y) * fits_prev(m, y); vapply(units, function(k) sum(v[land & u == k]), 0) }, numeric(length(units)))
    matrix(a, nrow = length(units), dimnames = list(units, ref)) * cell_amt })
  a <- Reduce(`+`, am)
  dr <- sched[SamplingSet == tg$SamplingSet[i]]
  nm <- lev_list[[L]]$Name[match(units, as.integer(lev_list[[L]]$Id))]
  if (anyNA(nm)) fail("%s: %d %s units are not in the stsim list", g, sum(is.na(nm)), L)
  d <- dr[, .(Unit = units), by = .(Iteration, Timestep, HistoricalYear)]
  d[, Amount := a[cbind(match(Unit, units), match(HistoricalYear, ref))]]
  d[, (lev_col[[L]]) := nm[match(Unit, units)]]; d[, TransitionGroupId := g]
  new_tt[[g]] <- d[, c("Iteration", "Timestep", lev_col[[L]], "TransitionGroupId", "Amount"), with = FALSE]
  # where it may happen in the projection: everywhere but the excluded GAP statuses
  ex <- if (is.na(tg$ExcludeGap[i]) || !nzchar(tg$ExcludeGap[i])) integer() else as.integer(strsplit(tg$ExcludeGap[i], "[|,; ]+")[[1]])
  key <- if (length(ex)) paste(ex, collapse = "-") else "all"
  if (is.null(allow_files[[key]])) { ok <- land & !(if (length(ex)) gap %in% ex else FALSE)
    allow_files[[key]] <- write_raster(setValues(rast(P), ifelse(land, as.integer(ok), NA)), sprintf("Projection-Allowed-%s.tif", if (length(ex)) paste0("NotGap", key) else "All"), "INT1U") }
  new_sm[[g]] <- data.table(Iteration = NA_integer_, Timestep = y1 + 1L, TransitionGroupId = g, MultiplierFileName = allow_files[[key]])
  # the members of a named group: on everywhere (the group's map carries the GAP exclusion) or, with Historical Type Shares, each at its
  # share of the group's reference-period area in its unit relative to the largest member's (a unit without history: all at 1)
  if (is.null(allow_files[["all"]])) allow_files[["all"]] <- write_raster(setValues(rast(P), ifelse(land, 1L, NA)), "Projection-Allowed-All.tif", "INT1U")
  tot <- rowSums(a); shr <- vapply(am, function(x) ifelse(tot > 0, rowSums(x) / pmax(tot, 1e-12), 1), numeric(length(units)))
  shr <- matrix(shr, nrow = length(units)); rel <- shr / pmax(apply(shr, 1, max), 1e-12); rel[tot <= 0, ] <- 1
  for (j in seq_along(ms)) { m <- ms[j]; if (m == g) next
    f <- allow_files[["all"]]
    if (type_shares) { v <- rep(NA_real_, length(land)); v[land] <- rel[match(u[land], units), j]
      f <- write_raster(setValues(rast(P), v), sprintf("Projection-Share-%s.tif", gsub("[^A-Za-z0-9]+", "-", sub(TYPE_SUFFIX, "", m, fixed = TRUE))), "FLT4S") }
    new_sm[[m]] <- data.table(Iteration = NA_integer_, Timestep = y1 + 1L, TransitionGroupId = m, MultiplierFileName = f) }
  # a Projection Setup result already holds stage 10's surfaces for the group or its members (projections rerun stage 9 for the hand-over): keep them
  for (m in unique(c(g, ms))) { sf10 <- sm[TransitionGroupId == m & Timestep == y1 + 1 & is.na(Iteration) & grepl("^Suitability-", basename(MultiplierFileName)), MultiplierFileName]
    if (length(sf10) && !is.null(new_sm[[m]])) new_sm[[m]][, MultiplierFileName := sf10[1]] }
  if (length(ms) > 1 || ms[1] != g) say("%s: members %s; their historical shares %s (%s)", g, paste(ms, collapse = ", "),
      paste(sprintf("%.0f%%", 100 * colSums(matrix(vapply(am, rowSums, numeric(length(units))), nrow = length(units))) / max(sum(a), 1e-12)), collapse = " / "),
      if (type_shares) "used: Historical Type Shares" else "not used: the spatial allocation decides the type")
  el <- elig(g); share <- if (length(ex)) sum(el & !(gap %in% ex)) / max(1, sum(el)) else 1
  rates[[g]] <- data.table(TransitionGroup = g, Method = "Target", Unit = nm, MeanArea = rowMeans(a) / cell_amt * cell_km2,
                           MinArea = apply(a, 1, min) / cell_amt * cell_km2, MaxArea = apply(a, 1, max) / cell_amt * cell_km2, AllowedShare = share)
  say("%s: target by %s (%d units), mean %.2f km2/yr over %d-%d%s", g, L, length(units), sum(rowMeans(a)) / cell_amt * cell_km2, rs, re,
      if (length(ex)) sprintf("; %.0f%% of eligible land allowed (not GAP %s)", 100 * share, paste(ex, collapse = ", ")) else "") }
progressBar()

# ---- fire (method 1): the pyrome's burned fraction x slope selectivity, the drawn year's severity mix, perimeter fire sizes -----------
fire_rows <- pt[Method == "Probability" & TransitionGroupId == fire_g]; fire_sd <- data.table(); fire_out <- list(ign = NA_character_)
# ---- fire method 3: whole lucasFireC2F seasons, one-way (user decision 2026-10-23). Each projection year and iteration draws a
# season of a C2F run (its per-burn effects table: season, 1-based cell of the C2F grid, MTBS-style class 1-4); each severity type
# gets the season's burned fraction of every model cell (classes 1-2 low, 3 medium, 4 high; a cell burned twice in a season keeps
# its worst class), the fire group itself 1. C2F gives the fires' shape, so no size distribution, slope or ignition surface.
if (nrow(fire_rows) && fire_m == 3) { g <- fire_g; ms <- mem[[g]]
  lib <- nz(fo$C2FLibrary, NA_character_); rid <- nz(fo$C2FScenarioId, NA_integer_)
  if (is.na(lib) || is.na(rid)) fail("Fire Options: method 3 needs the lucasFireC2F library and result scenario id")
  D <- file.path(paste0(lib, ".data"), sprintf("Scenario-%d", rid))
  bef <- file.path(D, "lucasFireC2F_OutputBurnEffects", "burn_effects.parquet"); gf <- file.path(D, "lucasFireC2F_LandscapeRasters", "fire_zone.tif")
  if (!file.exists(bef) || !file.exists(gf)) fail("Fire Options: C2F result %d of %s has no per-burn effects table or landscape grid (run its stage 8 with the burn effects table on)", rid, basename(lib))
  g2 <- rast(gf); box <- project(as.polygons(ext(P), crs = crs(P)), crs(g2)); cidx <- cells(g2, ext(box))
  zv <- values(g2, mat = FALSE)[cidx]; cidx <- cidx[!is.na(zv)]
  mc <- cellFromXY(P, project(vect(xyFromCell(g2, cidx), crs = crs(g2)), crs(P)) |> crds()); keep <- !is.na(mc) & land[mc]; cidx <- cidx[keep]; mc <- mc[keep]
  covered <- mean(which(land) %in% mc)
  if (covered < 0.95) say("%s: the C2F grid covers %.0f%% of the land cells: the rest gets no fire from C2F seasons", g, 100 * covered)
  ev <- as.data.table(arrow::read_parquet(bef, col_select = c("Season", "Cell", "SeverityClass")))[Cell %in% cidx][, .(Sev = max(SeverityClass)), by = .(Season, Cell)]
  NS <- max(as.data.table(arrow::read_parquet(bef, col_select = "Season"))$Season)
  dr <- sched[SamplingSet == fire_rows$SamplingSet[1]]; set.seed(seed * 1000L + 99L); dr[, HistoricalYear := sample.int(NS, .N, replace = TRUE)]
  sched[SamplingSet == fire_rows$SamplingSet[1], HistoricalYear := dr$HistoricalYear]
  frac <- prod(res(g2)) / prod(res(P)); sev_of <- function(m) if (grepl("High", m)) 4L else if (grepl("Medium|Moderate", m)) 3L else 1:2
  ones <- write_raster(setValues(rast(P), ifelse(land, 1L, NA)), "Projection-Allowed-All.tif", "INT1U"); sfile <- list(); burned <- c()
  for (s in sort(unique(dr$HistoricalYear))) { e <- ev[Season == s]; burned[as.character(s)] <- nrow(e) * prod(res(g2)) / 1e6
    for (m in ms) { v <- rep(NA_real_, length(land)); v[land] <- 0; x <- e[Sev %in% sev_of(m)]
      if (nrow(x)) { cnt <- tabulate(mc[match(x$Cell, cidx)], nbins = length(land)); v[land] <- pmin(1, cnt[land] * frac) }
      sfile[[paste(m, s)]] <- write_raster(setValues(rast(P), v), sprintf("Projection-%s-C2F_%d.tif", gsub("[^A-Za-z0-9]+", "-", sub(TYPE_SUFFIX, "", m, fixed = TRUE)), s), "FLT4S") } }
  new_sm[[g]] <- dr[, .(Iteration, Timestep, TransitionGroupId = g, MultiplierFileName = ones)]
  for (m in ms) { h <- sm[TransitionGroupId == m & is.na(Iteration) & Timestep <= y1]; if (!nrow(h)) h <- sm[TransitionGroupId == m & Iteration %in% 1L & Timestep <= y1]
    new_sm[[m]] <- rbind(h[, .(Iteration = rep(seq_len(nit), each = .N), Timestep = rep(Timestep, nit), TransitionGroupId = m, MultiplierFileName = rep(MultiplierFileName, nit))],
                         dr[, .(Iteration, Timestep, TransitionGroupId = m, MultiplierFileName = unlist(sfile[paste(m, HistoricalYear)]))]) }
  hb <- Reduce(`+`, lapply(ms, function(m) vapply(ref, function(y) sum(hist_vals(m, y)[land]), 0))) * cell_km2
  rates[[g]] <- data.table(TransitionGroup = g, Method = "lucasFireC2F seasons", Unit = sprintf("C2F result %d (%d seasons)", rid, NS), MeanArea = mean(burned[as.character(dr$HistoricalYear)]),
                           MinArea = min(burned), MaxArea = max(burned), AllowedShare = covered)
  say("%s: %d lucasFireC2F seasons of result %d (%s); drawn seasons burn %.2f km2/yr on the study area's C2F cells (mean), the fire record %.2f km2/yr (%d-%d)",
      g, NS, rid, basename(lib), mean(burned[as.character(dr$HistoricalYear)]), mean(hb), rs, re) }
if (nrow(fire_rows) && fire_m < 3) { g <- fire_g; ms <- mem[[g]]; u <- unit_map(fire_rows$UnitSource[1]); el <- elig(g); units <- sort(unique(u[el]))
  den <- vapply(units, function(k) sum(el & u == k), 0); dr <- sched[SamplingSet == fire_rows$SamplingSet[1]]
  # burned cells by severity member, unit and year
  A <- lapply(ms, function(m) { a <- vapply(ref, function(y) { v <- hist_vals(m, y); vapply(units, function(k) sum(v[el & u == k]), 0) }, numeric(length(units)))
    matrix(a, nrow = length(units), dimnames = list(units, ref)) })
  tot <- Reduce(`+`, A); fr <- tot / pmax(den, 1)
  # slope selectivity: burned fraction per year by 30 m slope (averaged to the model grid) relative to the average, shrunk to 1 where few cells
  w <- rep(1, length(land)); ign_file <- NA_character_
  # method 2: an FSim-type burn probability guides where fire goes (it already holds terrain and fuels, so it replaces slope
  # selectivity), and the ignitions follow it or the FPA-FOD ignition density (Fire Options, user decision 2026-10-23)
  if (fire_m == 2) { bpf <- nz(fo$BurnProbabilityFile, NA_character_); if (is.na(bpf) || !nzchar(bpf)) bpf <- read_data_sources("BurnProbabilityFile")$BurnProbabilityFile
    if (!file.exists(bpf)) fail("Fire Options: burn probability raster not found (%s)", bpf)
    bp_r <- rast(bpf); bpm <- values(project(crop(bp_r, project(as.polygons(ext(P), crs = crs(P)), crs(bp_r)), snap = "out"), P, method = "average"), mat = FALSE)
    bpm[is.na(bpm) | bpm < 0] <- 0
    if (!any(bpm[el] > 0)) fail("Fire Options: the burn probability raster (%s) is 0 or missing over the burnable land", bpf)
    w <- bpm; slope_on <- FALSE
    say("%s: burn probability %s; mean %.4f/yr on burnable cells (slope selectivity off: the burn probability holds terrain)", g, basename(bpf), mean(bpm[el]))
    ig <- if (ign_src == 1) bpm else {
      ff <- read_data_sources("FpaFodFile")$FpaFodFile; bw <- nz(fo$IgnitionBandwidth, 5000)
      box <- st_as_sfc(st_bbox(st_buffer(st_as_sfc(st_bbox(ext(P) , crs = st_crs(crs(P)))), 3 * bw)))
      pts <- st_read(ff, layer = "Fires", wkt_filter = st_as_text(st_transform(box, st_crs(st_read(ff, layer = "Fires", query = "SELECT * FROM Fires LIMIT 0", quiet = TRUE)))), quiet = TRUE)
      pts <- st_transform(pts, crs(P)); n <- rasterize(vect(pts), rast(P), fun = "count", background = 0)
      sg <- bw / res(P)[1]; k <- max(1, ceiling(3 * sg)); gw <- outer(-k:k, -k:k, function(a, b) exp(-(a^2 + b^2) / (2 * sg^2))); gw <- gw / sum(gw)
      dv <- values(focal(n, w = gw, fun = "sum", na.rm = TRUE), mat = FALSE); dv[is.na(dv)] <- 0
      say("%s ignitions: FPA-FOD density from %d fire origins %s, smoothed over %g m", g, nrow(pts), basename(ff), bw); dv }
    iv <- rep(NA_real_, length(land)); iv[land] <- 0; for (k in units) { i <- el & u == k; iv[i] <- if (any(ig[i] > 0)) ig[i] / mean(ig[i]) else 1 }
    ign_file <- write_raster(setValues(rast(P), iv), sprintf("Projection-%s-Ignition.tif", gsub("[^A-Za-z0-9]+", "-", g)), "FLT4S")
    say("%s ignitions: %s (Spatial Initiation Multiplier, mean 1 within each %s unit)", g, if (ign_src == 1) "the burn probability" else "FPA-FOD ignition density", fire_rows$UnitSource[1]) }
  if (slope_on) { dem <- rast(read_data_sources("ElevationFile")$ElevationFile)
    d <- crop(dem, project(as.polygons(ext(P), crs = crs(P)), crs(dem)), snap = "out"); sl <- values(project(terrain(d, "slope", unit = "degrees"), P, method = "average"), mat = FALSE)
    b <- Reduce(`+`, lapply(ms, function(m) Reduce(`+`, lapply(ref, function(y) hist_vals(m, y))))) / length(ref)
    ok <- el & !is.na(sl); brk <- c(0, 5, 10, 15, 20, 25, 30, 35, 90); bin <- findInterval(sl[ok], brk, rightmost.closed = TRUE); mb <- mean(b[ok]); K <- 30
    st <- data.table(bin = bin, b = b[ok])[, .(Cells = .N, B = sum(b)), by = bin][order(bin)]
    st[, `:=`(SlopeFrom = brk[bin], SlopeTo = brk[bin + 1], BurnedPerYear = B / Cells, Ratio = ((B + K * mb) / (Cells + K)) / max(mb, 1e-12))]
    mid <- (st$SlopeFrom + pmin(st$SlopeTo, 45)) / 2
    w[ok] <- if (nrow(st) > 1) approx(mid, st$Ratio, sl[ok], rule = 2)$y else 1
    fire_out$slope <- st[, .(SlopeFrom, SlopeTo, Cells, BurnedPerYear, Ratio)]
    say("%s slope selectivity (burned share by slope, %d-%d): %s", g, rs, re, paste(sprintf("%g-%g deg %.2f", st$SlopeFrom, st$SlopeTo, st$Ratio), collapse = "; ")) }
  wn <- rep(0, length(land)); for (k in units) { i <- el & u == k; wn[i] <- if (any(w[i] > 0)) w[i] / mean(w[i]) else 1 }
  fire_out$ign <- ign_file
  # severity shares: the drawn year's mix in the unit; a unit and year without fire takes its long-term mix (no fire burns then anyway)
  lt <- matrix(vapply(A, rowSums, numeric(length(units))), nrow = length(units)); all_sh <- colSums(lt) / max(sum(lt), 1e-12)
  lt <- lt / pmax(rowSums(lt), 1e-12); lt[rowSums(lt) == 0, ] <- matrix(all_sh, sum(rowSums(lt) == 0), length(ms), byrow = TRUE)
  ffile <- list(); sfile <- list(); lost <- 0; tot_p <- 0; nm_g <- gsub("[^A-Za-z0-9]+", "-", sub(TYPE_SUFFIX, "", g, fixed = TRUE))
  for (y in sort(unique(dr$HistoricalYear))) { yc <- as.character(y); m <- rep(NA_real_, length(land)); m[land] <- 0
    p <- fr[match(u[el], units), yc] * wn[el]; lost <- lost + sum(pmax(p - 1, 0)); tot_p <- tot_p + sum(p); m[el] <- pmin(1, p)
    ffile[[yc]] <- write_raster(setValues(rast(P), m), sprintf("Projection-%s_%d.tif", nm_g, y), "FLT4S")
    for (j in seq_along(ms)) { s <- ifelse(tot[, yc] > 0, A[[j]][, yc] / pmax(tot[, yc], 1e-12), lt[, j]); v <- rep(NA_real_, length(land)); v[land] <- 0
      v[el] <- s[match(u[el], units)]
      sfile[[paste(ms[j], yc)]] <- write_raster(setValues(rast(P), v), sprintf("Projection-%s-Share_%d.tif", gsub("[^A-Za-z0-9]+", "-", sub(TYPE_SUFFIX, "", ms[j], fixed = TRUE)), y), "FLT4S") } }
  new_sm[[g]] <- dr[, .(Iteration, Timestep, TransitionGroupId = g, MultiplierFileName = unlist(ffile[as.character(HistoricalYear)]))]
  for (m in ms) { h <- sm[TransitionGroupId == m & is.na(Iteration) & Timestep <= y1]; if (!nrow(h)) h <- sm[TransitionGroupId == m & Iteration %in% 1L & Timestep <= y1]
    new_sm[[m]] <- rbind(h[, .(Iteration = rep(seq_len(nit), each = .N), Timestep = rep(Timestep, nit), TransitionGroupId = m, MultiplierFileName = rep(MultiplierFileName, nit))],
                         dr[, .(Iteration, Timestep, TransitionGroupId = m, MultiplierFileName = unlist(sfile[paste(m, HistoricalYear)]))]) }
  ua <- fr * den * cell_km2
  rates[[g]] <- data.table(TransitionGroup = g, Method = "Probability (fire)", Unit = sprintf("%s %s", fire_rows$UnitSource[1], units), MeanArea = rowMeans(ua),
                           MinArea = apply(ua, 1, min), MaxArea = apply(ua, 1, max), AllowedShare = 1)
  say("%s: rate by %s (%d units), mean %.2f km2/yr over %d-%d; severity %s; %d distinct years drawn%s", g, fire_rows$UnitSource[1], length(units), sum(rowMeans(ua)), rs, re,
      paste(sprintf("%s %.0f%%", sub(".*: | \\[Type\\]", "", ms), 100 * all_sh), collapse = " / "), uniqueN(dr$HistoricalYear),
      if (lost > 0) sprintf("; %.2f%% of the drawn area above probability 1 after slope selectivity (cut)", 100 * lost / max(tot_p, 1e-12)) else "")
  # fire sizes: interagency perimeters (wildfire; daily perimeters and prescribed fire left out; one per incident and year, its
  # largest record) touching the units, in model cells, as the fire group's size distribution
  fp_src <- read_data_sources("FirePerimeterHistoryFile")$FirePerimeterHistoryFile; lay <- tools::file_path_sans_ext(basename(fp_src))
  fp <- st_read(fp_src, query = sprintf("SELECT FIRE_YEAR_, INCIDENT, FEATURE_CA, GIS_ACRES FROM \"%s\" WHERE FIRE_YEAR_ >= %d AND FIRE_YEAR_ <= %d", lay, rs, re), quiet = TRUE)
  fp <- fp[fp$FEATURE_CA %in% c("Wildfire", "Wildfire Final Fire Perimeter", "Wildfire for Resource Benefit") & !is.na(fp$GIS_ACRES) & fp$GIS_ACRES > 0, ]
  upoly <- strata_polygons(rows[[fire_rows$UnitSource[1]]], env$PackageDirectory); upoly <- st_union(upoly[upoly$StratumId %in% units, ])
  fp <- st_transform(st_make_valid(fp), st_crs(upoly)); fp <- fp[lengths(st_intersects(fp, upoly)) > 0, ]
  fd <- as.data.table(st_drop_geometry(fp))[, .(Acres = max(as.numeric(GIS_ACRES))), by = .(FIRE_YEAR_, Incident = toupper(trimws(INCIDENT)))]
  cell_ha <- prod(res(P)) / 1e4; n <- pmax(1, round(fd$Acres * 0.40468564224 / cell_ha))
  brk <- c(1, 2, 3, 5, 10, 20, 50, 100, 200, 500, 1e3, 2e3, 5e3, 1e4, 2e4, 5e4, 1e5, 2e5, 5e5, 1e6); br <- brk[brk <= brk[min(which(brk >= max(n)))]]
  cnt <- as.numeric(table(factor(findInterval(n, c(0, br), left.open = TRUE), levels = seq_along(br))))
  fire_out$size <- data.table(MaximumCells = as.integer(br), MaximumArea = br * cell_amt, Fires = as.integer(cnt), Share = cnt / sum(cnt))
  fire_sd <- data.table(TransitionGroupId = g, MaximumArea = br * cell_amt, RelativeAmount = cnt)[RelativeAmount > 0]
  say("%s sizes: %d wildfires %d-%d touching the %s units; median %.0f ha, largest %.0f ha (%d model cells); %.0f%% one model cell",
      g, nrow(fd), rs, re, fire_rows$UnitSource[1], median(fd$Acres) * 0.40468564224, max(fd$Acres) * 0.40468564224, max(n), 100 * mean(n == 1)) }
progressBar()

# ---- probabilities --------------------------------------------------------------------------------------------------------
pg <- pt[Method == "Probability" & TransitionGroupId != fire_g]; prob_files <- list()
for (i in seq_len(nrow(pg))) { g <- pg$TransitionGroupId[i]; u <- unit_map(pg$UnitSource[i]); el <- elig(g); units <- sort(unique(u[el]))
  den <- vapply(units, function(k) sum(el & u == k), 0)
  dr <- sched[SamplingSet == pg$SamplingSet[i]]
  fr <- matrix(0, length(units), length(ref), dimnames = list(units, ref))
  for (y in ref) { v <- hist_vals(g, y); fr[, as.character(y)] <- vapply(units, function(k) sum(v[el & u == k]), 0) / pmax(den, 1) }
  # one map per drawn year: each eligible cell gets its unit's fraction
  for (y in sort(unique(dr$HistoricalYear))) { m <- rep(NA_real_, length(land)); m[land] <- 0
    m[el] <- fr[match(u[el], units), as.character(y)]
    prob_files[[paste(g, y)]] <- if (max(m, na.rm = TRUE) > 0) write_raster(setValues(rast(P), m), sprintf("Projection-%s_%d.tif", gsub("[^A-Za-z0-9]+", "-", sub(TYPE_SUFFIX, "", g, fixed = TRUE)), y), "FLT4S")
                                 else hist_file(g, y) }
  # the group's historical rows copied to every iteration, so ST-Sim never has to fall back from iteration rows to shared ones
  h <- sm[TransitionGroupId == g & is.na(Iteration) & Timestep <= y1]
  # (a build or setup that already ran stage 9 holds them per iteration: take iteration 1's, copies of the shared rows - without this a
  # Projection Setup on such a build lost fire's historical maps and projections from it had no fire, found 2026-10-22)
  if (!nrow(h)) h <- sm[TransitionGroupId == g & Iteration %in% 1L & Timestep <= y1]
  new_sm[[g]] <- rbind(h[, .(Iteration = rep(seq_len(nit), each = .N), Timestep = rep(Timestep, nit), TransitionGroupId = g, MultiplierFileName = rep(MultiplierFileName, nit))],
                       dr[, .(Iteration, Timestep, TransitionGroupId = g, MultiplierFileName = unlist(prob_files[paste(g, HistoricalYear)]))])
  ua <- fr * den * cell_km2
  rates[[g]] <- data.table(TransitionGroup = g, Method = "Probability", Unit = sprintf("%s %s", pg$UnitSource[i], units), MeanArea = rowMeans(ua),
                           MinArea = apply(ua, 1, min), MaxArea = apply(ua, 1, max), AllowedShare = 1)
  say("%s: rate by %s (%d units), mean %.2f km2/yr over %d-%d; %d distinct years drawn", g, pg$UnitSource[i], length(units), sum(rowMeans(ua)), rs, re, uniqueN(dr$HistoricalYear)) }
progressBar()

# ---- spatial multiprocessing tiles: whole units of the one target strata level ----------------------------------------------
if (tiles > 1) {
  lvls <- unique(tg$StrataLevel)
  check(STAGE, "with spatial tiles, every Target group uses one strata level", length(lvls) <= 1, paste(lvls, collapse = ", "))
  if (length(lvls) == 1) { u <- lev[[lvls]]; ua <- table(u[land]); ua <- sort(ua, decreasing = TRUE)
    load <- numeric(tiles); tile_of <- integer(length(ua))
    for (j in seq_along(ua)) { k <- which.min(load); tile_of[j] <- k; load[k] <- load[k] + ua[[j]] }
    tv <- rep(NA_integer_, length(land)); tv[land] <- tile_of[match(as.character(u[land]), names(ua))]
    tf <- write_raster(setValues(rast(P), tv), "Projection-Tiles.tif", "INT2U")
    saveDatasheet(scn, data.frame(MaskFileName = tf), "core_SpatialMultiprocessing")
    say("Spatial tiles: %d tiles of whole %s units (largest %.0f%%, smallest %.0f%% of the land)", tiles, lvls, 100 * max(load) / sum(load), 100 * min(load) / sum(load)) }
}

# ---- outputs ----------------------------------------------------------------------------------------------------------
fire_all <- if (nrow(fire_rows)) c(fire_g, mem[[fire_g]]) else character()   # fire group and members: all rows rewritten (per iteration)
handled <- unique(c(pt[Method != "None", TransitionGroupId], unlist(mem[tg$TransitionGroupId], use.names = FALSE), fire_all))
sm_out <- rbind(sm[!(TransitionGroupId %in% handled & (Timestep > y1 | TransitionGroupId %in% c(pg$TransitionGroupId, fire_all))),
                   .(Iteration, Timestep, TransitionGroupId, MultiplierFileName)], rbindlist(new_sm), fill = TRUE)
# earlier projection targets (stage 9 run again on a build that already has them) are replaced
if (nrow(tt) && "Timestep" %in% names(tt)) tt <- tt[!(TransitionGroupId %in% handled & !is.na(Timestep) & Timestep > y1)]
tt_out <- rbind(tt, rbindlist(new_tt, fill = TRUE), fill = TRUE)
nexp <- nit * length(pyrs)
cov <- if (length(new_tt)) rbindlist(new_tt, fill = TRUE)[, .(n = uniqueN(paste(Iteration, Timestep))), by = TransitionGroupId] else data.table(TransitionGroupId = character(), n = integer())
check(STAGE, "every Target group has a target in every iteration and projection year", all(cov$n == nexp), paste(cov[n != nexp, TransitionGroupId], collapse = "; "))
check(STAGE, "every Probability group has a map in every iteration and projection year",
      all(vapply(c(pg$TransitionGroupId, fire_all), function(g) nrow(sm_out[TransitionGroupId == g & Timestep > y1 & !is.na(MultiplierFileName)]) == nexp, TRUE)))
write_stsim(sm_out, "TransitionSpatialMultiplier")
if (nrow(fire_rows)) {
  # (method 3: no size distribution - an earlier one for the fire group is removed)
  write_size_dist(fire_sd, if (nrow(fire_sd)) data.table(TransitionGroupId = fire_g, Priority = "Largest", MaximizeFidelityToDistribution = TRUE, MaximizeFidelityToTotalArea = TRUE) else data.table(),
                  fire_g, y1 + 1L)
  if (!is.null(fire_out$size)) write_ds(fire_out$size, "OutputFireSize"); if (!is.null(fire_out$slope)) write_ds(fire_out$slope, "OutputFireSlope")
  # ignitions (method 2): the fire group's initiation multiplier from the historical end + 1, other groups' rows kept
  im <- as.data.table(datasheet(scn, "stsim_TransitionSpatialInitiationMultiplier", optional = TRUE, lookupsAsFactors = FALSE))
  if (nrow(im)) im <- im[TransitionGroupId != fire_g, setdiff(names(im), c("TransitionSpatialInitiationMultiplierId", "ScenarioId")), with = FALSE]
  if (!is.na(fire_out$ign)) im <- rbind(im, data.table(Timestep = y1 + 1L, TransitionGroupId = fire_g, MultiplierFileName = fire_out$ign), fill = TRUE)
  if (nrow(im)) write_stsim(im, "TransitionSpatialInitiationMultiplier") }
if (nrow(tt_out)) write_stsim(tt_out[, setdiff(names(tt_out), c("TransitionTargetId", "ScenarioId")), with = FALSE], "TransitionTarget")
write_ds(sched[order(SamplingSet, Iteration, Timestep), .(Iteration, Timestep, SamplingSet, HistoricalYear)], "OutputProjectionSchedule")
if (length(rates)) write_ds(rbindlist(rates), "OutputProjectionRate")
say("Projection inputs: %d target rows, %d multiplier rows", nrow(tt_out), nrow(sm_out))
progressBar()
finish_checks()
