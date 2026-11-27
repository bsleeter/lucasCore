# =============================================================================
# dashboard-export.R - a LUCAS library's runs as the data bundle the output dashboard reads (to-do 12, prototype)
# =============================================================================
# Usage (reads the library read-only; works on a library of any SyncroSim version, since it opens the file through SQLite):
#   Rscript tools/dashboard-export.R <library.ssim> <out folder> <historical result id> [<projection result id>=<label> ...]
#                                    [--title=<region name>] [--strata=<name 1>,<name 2>,<name 3>] [--dem=<elevation tif>]
#   e.g. Rscript tools/dashboard-export.R "dev/libs/Pyrome 27.ssim" dev/dashboard/p27 9 "26=ACCESS-CM2 SSP2-4.5" "18=ACCESS-CM2 SSP5-8.5"
#   --title   the region's name (default: the tertiary stratum when there is one, else the library's file name)
#   --strata  names of the three strata (default: the "Kind: " prefix the stratum names share, else Primary/Secondary/Tertiary;
#             a dimension with one value in the outputs is left out of the filters)
#   --build   the Build result whose Carbon Capacity maps (stage 8) the runs are compared with (default: the newest before the historical run)
#   --dem     elevation for the shaded relief and the hover readout (default: env LUCAS_DEM, then the library's Elevation File)
# Writes, in <out>:
#   meta.json     region, grid, strata dimensions and their combinations, runs (years, iterations, map layers, wood products),
#                 state classes with colours and cover groups, the keys of every table cube, boundaries in grid cell units
#   tables-<run>.json   cubes: a flat array per measure in the order [combo][key][iteration][year] (combo = a combination of the
#                 strata kept as filters): area (ha, by state class), trans (ha, by transition group), stocks (t C, by stock group x
#                 cover group), flows (t C, by flow group), losses (t C, by flow group x cause, the run figures' loss_cause)
#   wood-<run>.json     harvested wood products for a run that has a Wood Products result (stage 18): pools and flows by year
#                 (mean and interval over iterations and draws) and carbon in use by end use. Not stratified.
#   maps/         8-bit PNGs of the whole grid box (255 = outside the study area or no data):
#                 strata.png (combo index, greyscale), relief.png (shaded relief, 2x the grid), elev.png (m / 20)
#                 <layer>-<run>-<k>.png: atlases, all the years of a layer in a few images: each tile is the grid, each tile's R, G
#                 and B channels are three consecutive years (meta lists the years and the tiles per image). Layers:
#                 sc (state class index, iteration 1), dist (disturbance code, iteration 1), age (years / 2, iteration 1),
#                 tec / live (t C per ha / 2, mean over iterations), npp / rh / nep / nbp (t C per ha per year, mean over iterations,
#                 signed square-root code around 127: v = sign(b - 127) * vmax * ((b - 127) / 127)^2, vmax in meta)
#                 cap (stock of live biomass, dead wood and litter as % of the carrying capacity, atlas), capacity.png (t C/ha / 2)
#                 chance-<fire|harvest|mort|change>-<run>.png, greyscale, for a run of more than one iteration: iterations with the event
# =============================================================================
suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(data.table); library(terra); library(jsonlite) })
argv <- commandArgs(TRUE); opt <- list()
for (a in grep("^--", argv, value = TRUE)) { kv <- regmatches(a, regexec("^--([^=]+)=(.*)$", a))[[1]]; if (length(kv) == 3) opt[[kv[2]]] <- kv[3] }
args <- grep("^--", argv, value = TRUE, invert = TRUE)
if (length(args) < 3) stop("usage: dashboard-export.R <library> <out> <historical id> [<projection id>=<label> ...] [--title=] [--strata=] [--dem=]")
here <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), ".."))
source(file.path(here, "src", "run-figures.R"))   # cover_group, COVER_COLS, loss_cause
lib <- normalizePath(args[1]); out <- args[2]
unlink(file.path(out, "maps"), recursive = TRUE); unlink(Sys.glob(file.path(out, c("tables-*.json", "wood-*.json", "meta.json"))))
dir.create(file.path(out, "maps"), recursive = TRUE, showWarnings = FALSE)
hist_id <- as.integer(args[3])
proj <- if (length(args) > 3) rbindlist(lapply(strsplit(args[-(1:3)], "="), function(p) data.table(id = as.integer(p[1]), label = p[2]))) else data.table(id = integer(), label = character())
con <- dbConnect(SQLite(), lib, flags = SQLITE_RO)
q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
dd <- function(rid, folder) file.path(paste0(lib, ".data"), sprintf("Scenario-%d", rid), folder)
t0 <- Sys.time(); say <- function(...) cat(sprintf("[%5.1f min] ", as.numeric(difftime(Sys.time(), t0, units = "mins"))), sprintf(...), "\n", sep = "")

runs <- rbind(data.table(id = hist_id, run = "hist", label = "Historical", kind = "historical"),
              if (nrow(proj)) proj[, .(id, run = sprintf("p%d", seq_len(.N)), label, kind = "projection")])
for (i in seq_len(nrow(runs))) { rc <- q("SELECT MIN(Iteration) i0, MAX(Iteration) i1, MIN(Timestep) y0, MAX(Timestep) y1 FROM stsim_OutputStratumState WHERE ScenarioId = %d", runs$id[i])
  if (is.na(rc$i1)) stop(sprintf("result %d has no state class output", runs$id[i]))
  runs[i, `:=`(it0 = rc$i0, it1 = rc$i1, y0 = rc$y0, y1 = rc$y1)] }
say("runs: %s", paste(sprintf("%s %d (%d-%d, %d it)", runs$run, runs$id, runs$y0, runs$y1, runs$it1), collapse = "; "))

# ---- dictionaries ---------------------------------------------------------------------------------------------------------
argb <- function(s) vapply(strsplit(s, ","), function(v) { v <- as.integer(v); if (length(v) == 4 && !anyNA(v)) sprintf("#%02x%02x%02x", v[2], v[3], v[4]) else "#999999" }, "")
inl <- paste(runs$id, collapse = ",")
sc <- q("SELECT StateClassId, ID AS MapId, Name, Color FROM stsim_StateClass WHERE StateClassId IN (SELECT DISTINCT StateClassId FROM stsim_OutputStratumState WHERE ScenarioId IN (%s)) ORDER BY Name", inl)
sc[, `:=`(idx = .I - 1L, group = cover_group(Name), color = argb(Color))]

# strata: three dimensions (primary, secondary, tertiary); those with more than one value in the outputs become filters
DIM <- data.table(col = c("StratumId", "SecondaryStratumId", "TertiaryStratumId"), tab = c("stsim_Stratum", "stsim_SecondaryStratum", "stsim_TertiaryStratum"),
                  abbr = c("p", "s", "t"), tif = c("PrimaryStrata.tif", "SecondaryStrata.tif", "TertiaryStrata.tif"), fallback = c("Primary stratum", "Secondary stratum", "Tertiary stratum"))
obs <- q("SELECT DISTINCT StratumId p, SecondaryStratumId s, TertiaryStratumId t FROM stsim_OutputStratumState WHERE ScenarioId IN (%s)", inl)
dict <- lapply(seq_len(nrow(DIM)), function(j) { d <- q("SELECT %s id, ID m, Name FROM %s", DIM$col[j], DIM$tab[j]); d[id %in% obs[[DIM$abbr[j]]]] })
user_names <- if (!is.null(opt$strata)) trimws(strsplit(opt$strata, ",")[[1]]) else character()
dims <- list()
for (j in seq_len(nrow(DIM))) { d <- dict[[j]]; pre <- unique(ifelse(grepl("^[^:]+: ", d$Name), sub(": .*$", "", d$Name), ""))
  shared <- length(pre) == 1 && nzchar(pre)
  d[, label := if (shared) sub("^[^:]+: ", "", Name) else Name]
  nm <- if (length(user_names) >= j && nzchar(user_names[j])) user_names[j] else if (shared) pre else DIM$fallback[j]
  dims[[j]] <- list(name = nm, d = d[order(label)], keep = nrow(d) > 1) }
kept <- which(vapply(dims, `[[`, TRUE, "keep"))
if (!length(kept)) kept <- 1L
for (j in kept) dims[[j]]$d[, v := .I - 1L]
obs$k <- do.call(paste, lapply(kept, function(j) dims[[j]]$d$v[match(obs[[DIM$abbr[j]]], dims[[j]]$d$id)]))
combos <- unique(obs[, c(DIM$abbr[kept], "k"), with = FALSE], by = "k")
setorderv(combos, "k"); combos[, combo := .I - 1L]
if (nrow(combos) > 254) stop(sprintf("%d strata combinations: more than the 254 the strata map can hold; leave a stratum out", nrow(combos)))
ckey <- function(...) { a <- list(...); do.call(paste, lapply(seq_along(kept), function(i) { j <- kept[i]; dims[[j]]$d$v[match(a[[i]], dims[[j]]$d$id)] })) }
cid <- function(p, s, t) { a <- list(p, s, t)[kept]; combos$combo[match(do.call(ckey, a), combos$k)] }
say("strata: %s; %d combinations", paste(sprintf("%s (%d)", vapply(dims, `[[`, "", "name"), vapply(dims, function(x) nrow(x$d), 0L)), collapse = ", "), nrow(combos))

STOCKS <- c("Total Ecosystem", "Biomass: Total", "DOM: Deadwood", "DOM: Litter", "DOM: Soil")
FLOWS <- c("Net Primary Productivity", "Emission: Total Rh", "Net Ecosystem Productivity", "Net Biome Productivity", "LULC: Emission", "LULC: Emission Peat",
           "LULC: Harvest", "LULC: Mortality", "Harvest: Agriculture", "Emission: Wetland CH4", "Emission: Wetland CH4 (CO2e)", "Lateral Flux")
LOSS_GROUPS <- c("LULC: Emission", "LULC: Emission Peat", "LULC: Harvest", "LULC: Mortality", "Harvest: Agriculture")

# ---- tables -----------------------------------------------------------------------------------------------------------------
cube <- function(d, keys, R, digits) {   # d: combo, key, Iteration, Timestep, v -> flat array [combo][key][iteration][year]
  nk <- length(keys); ni <- R$it1 - R$it0 + 1L; ny <- R$y1 - R$y0 + 1L
  a <- numeric(nrow(combos) * nk * ni * ny)
  d <- d[!is.na(combo) & key %in% keys, .(v = sum(v)), by = .(combo, key, Iteration, Timestep)]
  k <- ((d$combo * nk + match(d$key, keys) - 1L) * ni + (d$Iteration - R$it0)) * ny + (d$Timestep - R$y0) + 1L
  a[k] <- d$v; round(a, digits) }
tables_meta <- list(); wood_meta <- list()
for (i in seq_len(nrow(runs))) { R <- runs[i]; rid <- R$id
  area <- q("SELECT Iteration, Timestep, StratumId p, SecondaryStratumId s, TertiaryStratumId t, StateClassId k, SUM(Amount) v FROM stsim_OutputStratumState WHERE ScenarioId = %d GROUP BY 1,2,3,4,5,6", rid)
  area[, `:=`(combo = cid(p, s, t), key = sc$Name[match(k, sc$StateClassId)])]
  tr <- q("SELECT o.Iteration, o.Timestep, o.StratumId p, o.SecondaryStratumId s, o.TertiaryStratumId t, g.Name key, SUM(o.Amount) v FROM stsim_OutputStratumTransition o JOIN stsim_TransitionGroup g ON g.TransitionGroupId = o.TransitionGroupId WHERE o.ScenarioId = %d GROUP BY 1,2,3,4,5,6", rid)
  tr[, combo := cid(p, s, t)]
  st <- q("SELECT o.Iteration, o.Timestep, o.StratumId p, o.SecondaryStratumId s, o.TertiaryStratumId t, g.Name g, o.StateClassId c, SUM(o.Amount) v FROM stsim_OutputStock o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId
           WHERE o.ScenarioId = %d AND g.Name IN (%s) GROUP BY 1,2,3,4,5,6,7", rid, paste(sprintf("'%s'", STOCKS), collapse = ","))
  st[, `:=`(combo = cid(p, s, t), key = paste(g, cover_group(sc$Name[match(c, sc$StateClassId)]), sep = "|"))]
  say("%s: area %d, transitions %d, stocks %d rows", R$run, nrow(area), nrow(tr), nrow(st))
  fl <- q("SELECT o.Iteration, o.Timestep, o.FromStratumId p, o.FromSecondaryStratumId s, o.FromTertiaryStratumId t, g.Name g, tt.Name tn, SUM(o.Amount) v FROM stsim_OutputFlow o JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId
           LEFT JOIN stsim_TransitionType tt ON tt.TransitionTypeId = o.TransitionTypeId WHERE o.ScenarioId = %d AND g.Name IN (%s) GROUP BY 1,2,3,4,5,6,7", rid, paste(sprintf("'%s'", FLOWS), collapse = ","))
  fl[, combo := cid(p, s, t)]
  say("%s: flows %d rows", R$run, nrow(fl))
  flows <- fl[, .(combo, key = g, Iteration, Timestep, v)]
  losses <- fl[g %in% LOSS_GROUPS, .(combo, key = paste(g, loss_cause(g, fifelse(is.na(tn), "", tn)), sep = "|"), Iteration, Timestep, v)]
  keys <- list(area = sc$Name, trans = sort(unique(tr$key)), stocks = sort(unique(st$key)), flows = intersect(FLOWS, unique(flows$key)), losses = sort(unique(losses$key)))
  T <- list(area = cube(area[, .(combo, key, Iteration, Timestep, v)], keys$area, R, 1), trans = cube(tr[, .(combo, key, Iteration, Timestep, v)], keys$trans, R, 1),
            stocks = cube(st[, .(combo, key, Iteration, Timestep, v)], keys$stocks, R, 0), flows = cube(flows, keys$flows, R, 1), losses = cube(losses, keys$losses, R, 1))
  write_json(T, file.path(out, sprintf("tables-%s.json", R$run)), digits = NA)
  tables_meta[[R$run]] <- keys
  # harvested wood products: the newest stage 18 result that follows this run
  if (dbExistsTable(con, "lucasCore_OutputWoodProducts")) {
    wid <- q("SELECT MAX(ScenarioId) id FROM lucasCore_OutputWoodProducts WHERE RunScenarioId = %d", rid)$id
    if (length(wid) && !is.na(wid)) {
      w <- q("SELECT Year, Source, Variable, Mean, Lower, Upper FROM lucasCore_OutputWoodProducts WHERE ScenarioId = %d AND Iteration IS NULL AND Year >= %d ORDER BY Variable, Year", wid, runs$y0[1])
      eu <- q("SELECT Year, EndUse, InUse FROM lucasCore_OutputWoodProductsEndUse WHERE ScenarioId = %d AND Year >= %d ORDER BY EndUse, Year", wid, runs$y0[1])
      W <- list(result = wid, years = range(w$Year),
                vars = lapply(split(w, by = "Variable"), function(x) { x <- x[order(Year)]; list(year = x$Year, source = x$Source, mean = round(x$Mean, 1), lower = round(x$Lower, 1), upper = round(x$Upper, 1)) }),
                enduse = lapply(split(eu, by = "EndUse"), function(x) { x <- x[order(Year)]; list(year = x$Year, inuse = round(x$InUse, 1)) }))
      write_json(W, file.path(out, sprintf("wood-%s.json", R$run)), auto_unbox = TRUE, digits = NA)
      wood_meta[[R$run]] <- wid
      say("%s: wood products from result %d (%d-%d, %d variables, %d end uses)", R$run, wid, W$years[1], W$years[2], length(W$vars), length(W$enduse)) } } }

# ---- grid, mask, strata, relief, boundaries -------------------------------------------------------------------------------
ic <- dd(hist_id, "stsim_InitialConditionsSpatial")
first_sc <- q("SELECT Filename FROM stsim_OutputSpatialState WHERE ScenarioId = %d AND Iteration = %d ORDER BY Timestep LIMIT 1", hist_id, runs$it0[1])$Filename
g <- rast(file.path(dd(hist_id, "stsim_OutputSpatialState"), basename(first_sc)))
mask <- !is.na(values(g)[, 1]); cells <- which(mask); n <- length(cells)
writepng <- function(r, f) { p <- file.path(out, "maps", f); writeRaster(r, p, datatype = "INT1U", filetype = "PNG", overwrite = TRUE, gdal = "WORLDFILE=NO", NAflag = NA); unlink(paste0(p, ".aux.xml")) }
wpng <- function(v, f, tmpl = g, at = cells) {   # one byte per cell, the whole grid, 255 outside the study area
  full <- rep(255L, ncell(tmpl)); full[at] <- as.integer(v); r <- rast(tmpl); values(r) <- full; writepng(r, f) }
byte <- function(v) { v <- round(v); v[!is.na(v) & v > 254] <- 254L; v[is.na(v) | v < 0] <- 255L; v }   # cap first, so no value (255) stays 255
# an atlas: the years of one layer as tiles of the grid, three years per tile (R, G, B), at most ~8 million pixels per image
TILE_PX <- 8e6
atlas_plan <- function(ny) { tiles <- ceiling(ny / 3); per <- max(1L, min(tiles, floor(TILE_PX / ncell(g))))
  cols <- max(1L, min(per, floor(4096 / ncol(g)))); list(tiles = tiles, per = per, cols = cols) }
write_atlas <- function(vals, stem) {   # vals: list of byte vectors over `cells`, one per year
  ny <- length(vals); P <- atlas_plan(ny); nimg <- ceiling(P$tiles / P$per); W <- ncol(g); H <- nrow(g)
  for (k in seq_len(nimg)) { tk <- ((k - 1) * P$per + 1):min(P$tiles, k * P$per); nt <- length(tk); cols <- min(P$cols, nt); rows <- ceiling(nt / cols)
    img <- array(255L, c(H * rows, W * cols, 3))
    for (ti in seq_along(tk)) { r0 <- ((ti - 1) %/% cols) * H; c0 <- ((ti - 1) %% cols) * W
      for (ch in 1:3) { yi <- (tk[ti] - 1) * 3 + ch; if (yi > ny) next
        full <- rep(255L, ncell(g)); full[cells] <- as.integer(vals[[yi]]); img[r0 + seq_len(H), c0 + seq_len(W), ch] <- matrix(full, H, W, byrow = TRUE) } }
    r <- rast(img); ext(r) <- c(0, ncol(r), 0, nrow(r)); writepng(r, sprintf("%s-%d.png", stem, k)) }
  list(per = P$per, cols = P$cols, images = nimg) }
# strata map: the combo index of each cell (the map values are the strata IDs; the tables use the database keys)
smaps <- lapply(seq_len(nrow(DIM)), function(j) { f <- file.path(ic, DIM$tif[j]); if (file.exists(f)) rast(f) else NULL })
sv <- lapply(seq_len(nrow(DIM)), function(j) if (is.null(smaps[[j]])) rep(NA_integer_, n) else dict[[j]]$id[match(values(smaps[[j]])[cells, 1], dict[[j]]$m)])
wpng(byte(cid(sv[[1]], sv[[2]], sv[[3]])), "strata.png")
say("grid %d x %d at %g m, %d cells in the study area", ncol(g), nrow(g), res(g)[1], n)
dem_f <- if (!is.null(opt$dem)) opt$dem else Sys.getenv("LUCAS_DEM", "")
if (!nzchar(dem_f)) { ef <- q("SELECT ElevationFile FROM lucasCore_DataSource")$ElevationFile; dem_f <- if (length(ef) && !is.na(ef[1])) ef[1] else "" }
relief <- NULL
if (nzchar(dem_f) && file.exists(dem_f)) {
  sc2 <- if (ncell(g) > 2e6) 1 else 2   # relief at twice the grid unless the grid is already large
  fine <- rast(ext(g), ncols = ncol(g) * sc2, nrows = nrow(g) * sc2, crs = crs(g))
  d <- project(rast(dem_f), fine, method = "bilinear")
  slp <- terrain(d, "slope", unit = "radians"); asp <- terrain(d, "aspect", unit = "radians")
  hs <- Reduce(`+`, lapply(c(300, 337, 15), function(k) shade(slp, asp, angle = 42, direction = k))) / 3
  hv <- values(hs)[, 1]; hv[is.na(hv)] <- median(hv, na.rm = TRUE); hv <- (hv - quantile(hv, .005)) / diff(quantile(hv, c(.005, .995)))
  wpng(byte(pmin(pmax(hv, 0), 1) * 254), "relief.png", tmpl = fine, at = seq_len(ncell(fine))); relief <- list(ncol = ncol(fine), nrow = nrow(fine))
  e <- project(rast(dem_f), g, method = "bilinear"); wpng(byte(values(e)[cells, 1] / 20), "elev.png")
  say("relief from %s", dem_f) } else say("no elevation file: no relief (pass --dem= or set LUCAS_DEM)")
outline <- function(r) {   # polygons of a strata map in grid cell units, simplified
  r <- mask(r, g); pl <- simplifyGeom(as.polygons(r, dissolve = TRUE), tolerance = res(g)[1] * .8)
  lapply(seq_len(nrow(pl)), function(i) { gi <- geom(pl[i]); parts <- split(as.data.table(gi), by = c("part", "hole"))
    list(id = values(pl)[i, 1], rings = unname(lapply(parts, function(p) { m <- cbind(round((p$x - xmin(g)) / res(g)[1], 1), round((ymax(g) - p$y) / res(g)[2], 1)); unname(as.vector(t(m))) }))) }) }
study <- g; values(study) <- ifelse(mask, 1L, NA_integer_)
bounds <- list(study = outline(study))
for (j in kept) if (!is.null(smaps[[j]])) { r <- g; full <- rep(NA_integer_, ncell(g)); full[cells] <- dims[[j]]$d$v[match(sv[[j]], dims[[j]]$d$id)]; values(r) <- full
  b <- outline(r); for (x in seq_along(b)) b[[x]]$name <- dims[[j]]$d$label[match(b[[x]]$id, dims[[j]]$d$v)]
  bounds[[paste0("d", j)]] <- b }

# ---- carbon carrying capacity (stage 8, in the Build result the runs came from) ----------------------------------------------
# the Build is the newest result before the historical run that holds Carbon Capacity maps (or --build=<result id>); the capacity
# counts live biomass, dead wood and litter, as stage 13 does
cap <- NULL
if (dbExistsTable(con, "lucasCore_OutputCarbonCapacityMap")) {
  bid <- if (!is.null(opt$build)) as.integer(opt$build) else q("SELECT MAX(ScenarioId) id FROM lucasCore_OutputCarbonCapacityMap WHERE ScenarioId < %d", hist_id)$id
  cf <- if (length(bid) && !is.na(bid)) q("SELECT CapacityFileName c, UpperBoundFileName u FROM lucasCore_OutputCarbonCapacityMap WHERE ScenarioId = %d", bid) else data.table()
  if (nrow(cf)) { cdir <- dd(bid, "lucasCore_OutputCarbonCapacityMap")
    rd <- function(f) { if (is.na(f) || !file.exists(file.path(cdir, basename(f)))) return(NULL); r <- rast(file.path(cdir, basename(f)))
      if (!compareGeom(r, g, stopOnError = FALSE)) r <- resample(r, g, method = "near"); values(r)[cells, 1] }
    cv <- rd(cf$c[1]); uv <- rd(cf$u[1])
    if (!is.null(cv)) { ha <- res(g)[1] * res(g)[2] / 1e4; cc <- cid(sv[[1]], sv[[2]], sv[[3]])
      per <- function(v) { s <- tapply(v * ha, factor(cc, levels = combos$combo), sum, na.rm = TRUE); s[is.na(s)] <- 0; round(as.numeric(s), 0) }
      wpng(byte(cv / 2), "capacity.png")
      cap <- list(build = bid, total = I(per(cv)), upper = if (!is.null(uv)) I(per(uv)) else NULL, pools = c("Biomass: Total", "DOM: Deadwood", "DOM: Litter"))
      say("carbon capacity from Build result %d: %.2f Tg C%s", bid, sum(cap$total) / 1e6, if (!is.null(uv)) sprintf(", upper bound %.2f", sum(cap$upper) / 1e6) else "") } } }

# ---- maps by run and year -------------------------------------------------------------------------------------------------
tt <- q("SELECT ID AS MapId, Name FROM stsim_TransitionType")
DIST <- data.table(code = 1:12, name = c("Fire: low severity", "Fire: medium severity", "Fire: high severity", "Harvest: clearcut", "Harvest: selection", "Harvest: salvage",
                                           "Drought and insect mortality", "Urbanization", "Intensification", "Agricultural expansion", "Agricultural contraction", "Agricultural change"),
                   color = c("#f6c35b", "#f08a3c", "#c9341d", "#5b6670", "#98a4ad", "#7c6a58", "#8a5bb0", "#e0457b", "#b0306a", "#d9a441", "#7fb069", "#c4b47a"))
dist_code <- function(nm) fcase(grepl("^Fire: Low", nm), 1L, grepl("^Fire: Medium", nm), 2L, grepl("^Fire: High", nm), 3L, grepl("Clearcut", nm), 4L, grepl("Selection", nm), 5L,
                                grepl("Salvage", nm), 6L, grepl("^Mortality", nm), 7L, grepl("^Urbanization", nm), 8L, grepl("^Intensification", nm), 9L, grepl("^Ag Expansion", nm), 10L,
                                grepl("^Ag Contraction", nm), 11L, grepl("^Ag Change", nm), 12L, default = NA_integer_)
tt[, code := dist_code(Name)]
DIST_GROUPS <- c("Fire", "Forest Harvest", "Mortality", "Urbanization", "Intensification", "Ag Expansion", "Ag Contraction", "Ag Change")   # later groups overwrite earlier: none overlap in a year
FLUX <- data.table(fk = c("npp", "rh", "nep", "nbp"), group = c("Net Primary Productivity", "Emission: Total Rh", "Net Ecosystem Productivity", "Net Biome Productivity"))
rdv <- function(f) values(rast(f))[cells, 1]
sqcode <- function(v, vmax) { v[is.na(v)] <- NA; b <- 127 + sign(v) * round(127 * sqrt(pmin(abs(v), vmax) / vmax)); b[is.na(b)] <- 255L; as.integer(b) }
# the flux code's range: the 99.9th percentile of |v| over a few years of the historical run, so a burned cell does not flatten the rest
flux_vmax <- list()
fm <- q("SELECT o.Timestep, g.Name Grp, o.Filename FROM stsim_OutputAverageSpatialFlowGroup o JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId WHERE o.ScenarioId = %d AND g.Name IN (%s)",
        hist_id, paste(sprintf("'%s'", FLUX$group), collapse = ","))
for (x in seq_len(nrow(FLUX))) { m <- fm[Grp == FLUX$group[x]][order(Timestep)]
  if (!nrow(m)) next
  pick <- unique(m$Timestep[round(seq(1, nrow(m), length.out = min(6, nrow(m))))])
  v <- unlist(lapply(pick, function(y) rdv(file.path(dd(hist_id, "stsim_OutputAverageSpatialFlowGroup"), basename(m[Timestep == y, Filename][1])))))
  flux_vmax[[FLUX$fk[x]]] <- signif(max(1, quantile(abs(v), .999, na.rm = TRUE)), 2) }
say("flux map ranges (t C/ha/yr): %s", paste(names(flux_vmax), unlist(flux_vmax), sep = " ", collapse = ", "))
layers <- list()
for (i in seq_len(nrow(runs))) { R <- runs[i]; rid <- R$id; L <- list()
  add <- function(key, years, vals) { if (!length(years)) return(invisible()); A <- write_atlas(vals, sprintf("%s-%s", key, R$run)); L[[key]] <<- c(list(years = I(years)), A) }
  ssm <- q("SELECT Iteration, Timestep, Filename FROM stsim_OutputSpatialState WHERE ScenarioId = %d", rid)
  ys <- sort(unique(ssm[Iteration == R$it0, Timestep]))
  add("sc", ys, lapply(ys, function(y) byte(sc$idx[match(rdv(file.path(dd(rid, "stsim_OutputSpatialState"), basename(ssm[Iteration == R$it0 & Timestep == y, Filename][1]))), sc$MapId)])))
  agm <- if (dbExistsTable(con, "stsim_OutputSpatialAge")) q("SELECT Timestep, Filename FROM stsim_OutputSpatialAge WHERE ScenarioId = %d AND Iteration = %d", rid, R$it0) else data.table(Timestep = integer())
  ys <- sort(agm$Timestep); add("age", ys, lapply(ys, function(y) byte(rdv(file.path(dd(rid, "stsim_OutputSpatialAge"), basename(agm[Timestep == y, Filename][1]))) / 2)))
  sgm <- q("SELECT o.Timestep, g.Name Grp, o.Filename FROM stsim_OutputAverageSpatialStockGroup o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId WHERE o.ScenarioId = %d AND g.Name IN ('Total Ecosystem', 'Biomass: Total', 'DOM: Deadwood', 'DOM: Litter')", rid)
  sgf <- function(grp, y) file.path(dd(rid, "stsim_OutputAverageSpatialStockGroup"), basename(sgm[Grp == grp & Timestep == y, Filename][1]))
  for (lay in list(c("tec", "Total Ecosystem"), c("live", "Biomass: Total"))) {
    ys <- sort(sgm[Grp == lay[2], Timestep]); add(lay[1], ys, lapply(ys, function(y) byte(rdv(sgf(lay[2], y)) / 2))) }
  # stock as a share of the carrying capacity (%, live biomass + dead wood + litter over the capacity; 255 where the capacity is 0)
  if (!is.null(cap)) { ys <- Reduce(intersect, lapply(cap$pools, function(p) sgm[Grp == p, Timestep])); ys <- sort(ys)
    add("cap", ys, lapply(ys, function(y) { s <- Reduce(`+`, lapply(cap$pools, function(p) rdv(sgf(p, y)))); v <- ifelse(cv > 0, 100 * s / cv, NA); byte(v) })) }
  fmr <- q("SELECT o.Timestep, g.Name Grp, o.Filename FROM stsim_OutputAverageSpatialFlowGroup o JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId WHERE o.ScenarioId = %d AND g.Name IN (%s)",
           rid, paste(sprintf("'%s'", FLUX$group), collapse = ","))
  for (x in seq_len(nrow(FLUX))) { m <- fmr[Grp == FLUX$group[x]]; k <- FLUX$fk[x]; if (!nrow(m) || is.null(flux_vmax[[k]])) next
    ys <- sort(unique(m$Timestep)); add(k, ys, lapply(ys, function(y) sqcode(rdv(file.path(dd(rid, "stsim_OutputAverageSpatialFlowGroup"), basename(m[Timestep == y, Filename][1]))), flux_vmax[[k]]))) }
  trm <- q("SELECT o.Iteration, o.Timestep, g.Name AS Grp, o.Filename FROM stsim_OutputSpatialTransition o JOIN stsim_TransitionGroup g ON g.TransitionGroupId = o.TransitionGroupId WHERE o.ScenarioId = %d AND (%s)",
           rid, paste(sprintf("g.Name = '%s' OR g.Name LIKE '%s:%%'", DIST_GROUPS, DIST_GROUPS), collapse = " OR "))   # a family's own map, or its type groups' (harvest and mortality map only by type)
  trm[, File := file.path(dd(rid, "stsim_OutputSpatialTransition"), basename(Filename))]
  ys <- sort(unique(trm[Iteration == R$it0, Timestep]))
  add("dist", ys, lapply(ys, function(y) { code <- rep(0L, n)
    for (f in trm[Iteration == R$it0 & Timestep == y, File]) { v <- rdv(f); k <- which(!is.na(v) & v > 0); if (length(k)) { cv <- tt$code[match(v[k], tt$MapId)]; code[k[!is.na(cv)]] <- cv[!is.na(cv)] } }
    code }))
  say("%s maps: %s", R$run, paste(sprintf("%s %d", names(L), vapply(L, function(x) length(x$years), 0L)), collapse = ", "))
  # chance of an event over the run: the number of iterations in which the cell had it (fire, harvest, mortality), or ended in another class
  if (R$it1 > R$it0) {
    kind <- function(gp) fcase(grepl("^Fire($|:)", gp), "fire", grepl("^Forest Harvest($|:)", gp), "harvest", grepl("^Mortality($|:)", gp), "mort", default = NA_character_)
    trm[, Kind := kind(Grp)]
    for (kd in c("fire", "harvest", "mort")) { cnt <- integer(n)
      for (it in R$it0:R$it1) { hit <- logical(n); for (f in trm[Kind == kd & Iteration == it, File]) { v <- rdv(f); hit <- hit | (!is.na(v) & v > 0) }; cnt <- cnt + hit }
      wpng(cnt, sprintf("chance-%s-%s.png", kd, R$run)) }
    s0 <- rdv(file.path(dd(rid, "stsim_OutputSpatialState"), basename(ssm[Iteration == R$it0 & Timestep == R$y0, Filename][1]))); cnt <- integer(n)
    for (it in R$it0:R$it1) { v <- rdv(file.path(dd(rid, "stsim_OutputSpatialState"), basename(ssm[Iteration == it & Timestep == R$y1, Filename][1])))
      cnt <- cnt + (cover_group(sc$Name[match(v, sc$MapId)]) != cover_group(sc$Name[match(s0, sc$MapId)])) }
    wpng(cnt, sprintf("chance-change-%s.png", R$run)); L$chance <- c("fire", "harvest", "mort", "change")
    say("%s chance maps over %d iterations", R$run, R$it1 - R$it0 + 1L) }
  layers[[R$run]] <- L }

# ---- meta -------------------------------------------------------------------------------------------------------------------
tert <- dims[[3]]$d$label
title <- if (!is.null(opt$title)) opt$title else if (length(tert) == 1) tert else sub("\\.ssim$", "", basename(lib))
meta <- list(
  format = 2L, title = title, library = basename(lib), exported = format(Sys.time(), "%Y-%m-%d %H:%M"),
  grid = list(ncol = ncol(g), nrow = nrow(g), res = res(g)[1], xmin = xmin(g), ymax = ymax(g), crs = "EPSG:5070", cells = n, relief = relief),
  dims = lapply(kept, function(j) list(key = paste0("d", j), name = dims[[j]]$name, values = I(dims[[j]]$d$label))),
  combos = lapply(seq_len(nrow(combos)), function(i) I(as.integer(strsplit(combos$k[i], " ")[[1]]))),
  runs = lapply(seq_len(nrow(runs)), function(i) { R <- runs[i]; list(key = R$run, id = R$id, label = R$label, kind = R$kind, years = c(R$y0, R$y1), iterations = c(R$it0, R$it1),
                                                                     keys = tables_meta[[R$run]], maps = layers[[R$run]], wood = if (!is.null(wood_meta[[R$run]])) wood_meta[[R$run]] else NULL) }),
  classes = lapply(seq_len(nrow(sc)), function(i) list(name = sc$Name[i], group = sc$group[i], color = sc$color[i])),
  groups = lapply(names(COVER_COLS), function(k) list(name = k, color = unname(COVER_COLS[k]))),
  dist = lapply(seq_len(nrow(DIST)), function(i) list(code = DIST$code[i], name = DIST$name[i], color = DIST$color[i])),
  flux = flux_vmax, capacity = cap,
  units = list(area = "ha", carbon = "t C", maps_carbon = "t C/ha, stored / 2", maps_age = "years, stored / 2", elev = "m, stored / 20", maps_flux = "t C/ha/yr, signed square-root code"),
  bounds = bounds)
write_json(meta, file.path(out, "meta.json"), auto_unbox = TRUE, digits = NA, null = "null")
dbDisconnect(con)
f <- list.files(out, recursive = TRUE, full.names = TRUE)
say("done: %d files, %.1f MB in %s", length(f), sum(file.size(f)) / 1e6, out)
