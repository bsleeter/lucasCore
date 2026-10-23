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
#   * Probability: the group's burned (or changed) fraction of the eligible area of each unit of any Stratum Source in the drawn year,
#     as a per-cell multiplier map; it does not depend on the strata, so fire can use pyromes while land use uses counties
#   * None: the group stays off after the historical end (stage 6's Off rows)
#   * Spatial multiprocessing (Projection Options: Spatial Tiles): targets only add up if no target unit is split between tiles, so
#     every Target group must use one strata level and the tiles are made of whole units of it; Probability groups are exempt
# Needs stage 6 (same pipeline, or a dependency on its result). Writes nothing without a projection end year.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "strata.R"))
suppressPackageStartupMessages({ library(terra) })
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
pr <- pt[Method == "Probability" & !TransitionGroupId %in% ann]
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

# ---- probabilities --------------------------------------------------------------------------------------------------------
pg <- pt[Method == "Probability"]; prob_files <- list()
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
handled <- unique(c(pt[Method != "None", TransitionGroupId], unlist(mem[tg$TransitionGroupId], use.names = FALSE)))
sm_out <- rbind(sm[!(TransitionGroupId %in% handled & (Timestep > y1 | TransitionGroupId %in% pg$TransitionGroupId)),
                   .(Iteration, Timestep, TransitionGroupId, MultiplierFileName)], rbindlist(new_sm), fill = TRUE)
# earlier projection targets (stage 9 run again on a build that already has them) are replaced
if (nrow(tt) && "Timestep" %in% names(tt)) tt <- tt[!(TransitionGroupId %in% handled & !is.na(Timestep) & Timestep > y1)]
tt_out <- rbind(tt, rbindlist(new_tt, fill = TRUE), fill = TRUE)
nexp <- nit * length(pyrs)
cov <- if (length(new_tt)) rbindlist(new_tt, fill = TRUE)[, .(n = uniqueN(paste(Iteration, Timestep))), by = TransitionGroupId] else data.table(TransitionGroupId = character(), n = integer())
check(STAGE, "every Target group has a target in every iteration and projection year", all(cov$n == nexp), paste(cov[n != nexp, TransitionGroupId], collapse = "; "))
check(STAGE, "every Probability group has a map in every iteration and projection year",
      all(vapply(pg$TransitionGroupId, function(g) nrow(sm_out[TransitionGroupId == g & Timestep > y1 & !is.na(MultiplierFileName)]) == nexp, TRUE)))
write_stsim(sm_out, "TransitionSpatialMultiplier")
if (nrow(tt_out)) write_stsim(tt_out[, setdiff(names(tt_out), c("TransitionTargetId", "ScenarioId")), with = FALSE], "TransitionTarget")
write_ds(sched[order(SamplingSet, Iteration, Timestep), .(Iteration, Timestep, SamplingSet, HistoricalYear)], "OutputProjectionSchedule")
if (length(rates)) write_ds(rbindlist(rates), "OutputProjectionRate")
say("Projection inputs: %d target rows, %d multiplier rows", nrow(tt_out), nrow(sm_out))
progressBar()
finish_checks()
