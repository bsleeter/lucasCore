# =============================================================================
# dashboard-export.R - a LUCAS library's runs as the data bundle the output dashboard reads (to-do 12, prototype)
# =============================================================================
# Usage (reads the library read-only; works on a library of any SyncroSim version, since it opens the file through SQLite):
#   Rscript tools/dashboard-export.R <library.ssim> <out folder> <historical result id> <projection result id>=<label> [...]
#   e.g. Rscript tools/dashboard-export.R "dev/libs/Pyrome 27.ssim" dev/dashboard/p27 9 "26=ACCESS-CM2 SSP2-4.5" "18=ACCESS-CM2 SSP5-8.5"
# Writes, in <out>:
#   meta.json     region, grid, runs (years, iterations, the years each map layer has), state classes with colours and cover groups,
#                 strata (ecoregion x county combinations), the keys of every table cube, boundaries in grid cell units
#   tables-<run>.json   cubes: a flat array per measure in the order [combo][key][iteration][year] (combo = ecoregion x county):
#                 area (ha, by state class), trans (ha, by transition group), stocks (t C, by stock group x cover group),
#                 flows (t C, by flow group), losses (t C, by flow group x cause, the run figures' loss_cause)
#   maps/         8-bit greyscale PNGs of the whole grid box, one byte per cell (255 outside the study area):
#                 strata (combo index), relief (shaded relief, 2x the grid, the whole box), and for each run and year
#                 sc (state class index, iteration 1), dist (disturbance code, iteration 1), age (years / 2, iteration 1),
#                 tec / live (total ecosystem / live carbon, t C per ha / 2, mean over iterations); for a projection of more
#                 than one iteration chance-<fire|harvest|mort|change> (iterations with the event over the projection, 0-n)
# 255 is "no data" in every byte layer.
# =============================================================================
suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(data.table); library(terra); library(jsonlite) })
args <- commandArgs(TRUE)
if (length(args) < 3) stop("usage: dashboard-export.R <library> <out> <historical id> <projection id>=<label> ...")
here <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), ".."))
source(file.path(here, "src", "run-figures.R"))   # cover_group, COVER_COLS, loss_cause
lib <- normalizePath(args[1]); out <- args[2]; dir.create(file.path(out, "maps"), recursive = TRUE, showWarnings = FALSE)
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
combos <- q("SELECT DISTINCT o.StratumId p, o.SecondaryStratumId s FROM stsim_OutputStratumState o WHERE ScenarioId IN (%s)", inl)
pn <- q("SELECT StratumId p, Name FROM stsim_Stratum"); sn <- q("SELECT SecondaryStratumId s, Name FROM stsim_SecondaryStratum")
combos <- merge(merge(combos, pn, by = "p"), sn, by = "s", suffixes = c("", ".s"))
setnames(combos, c("Name", "Name.s"), c("ecoregion", "county")); setorder(combos, county, ecoregion); combos[, combo := .I - 1L]
combos[, county := sub("^County: ", "", county)]
cid <- function(p, s) combos$combo[match(paste(p, s), paste(combos$p, combos$s))]

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
tables_meta <- list()
for (i in seq_len(nrow(runs))) { R <- runs[i]; rid <- R$id
  area <- q("SELECT Iteration, Timestep, StratumId p, SecondaryStratumId s, StateClassId k, SUM(Amount) v FROM stsim_OutputStratumState WHERE ScenarioId = %d GROUP BY 1,2,3,4,5", rid)
  area[, `:=`(combo = cid(p, s), key = sc$Name[match(k, sc$StateClassId)])]
  tr <- q("SELECT o.Iteration, o.Timestep, o.StratumId p, o.SecondaryStratumId s, g.Name key, SUM(o.Amount) v FROM stsim_OutputStratumTransition o JOIN stsim_TransitionGroup g ON g.TransitionGroupId = o.TransitionGroupId WHERE o.ScenarioId = %d GROUP BY 1,2,3,4,5", rid)
  tr[, combo := cid(p, s)]
  st <- q("SELECT o.Iteration, o.Timestep, o.StratumId p, o.SecondaryStratumId s, g.Name g, o.StateClassId c, SUM(o.Amount) v FROM stsim_OutputStock o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId
           WHERE o.ScenarioId = %d AND g.Name IN (%s) GROUP BY 1,2,3,4,5,6", rid, paste(sprintf("'%s'", STOCKS), collapse = ","))
  st[, `:=`(combo = cid(p, s), key = paste(g, cover_group(sc$Name[match(c, sc$StateClassId)]), sep = "|"))]
  say("%s: area %d, transitions %d, stocks %d rows", R$run, nrow(area), nrow(tr), nrow(st))
  fl <- q("SELECT o.Iteration, o.Timestep, o.FromStratumId p, o.FromSecondaryStratumId s, g.Name g, t.Name t, SUM(o.Amount) v FROM stsim_OutputFlow o JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId
           LEFT JOIN stsim_TransitionType t ON t.TransitionTypeId = o.TransitionTypeId WHERE o.ScenarioId = %d AND g.Name IN (%s) GROUP BY 1,2,3,4,5,6", rid, paste(sprintf("'%s'", FLOWS), collapse = ","))
  fl[, combo := cid(p, s)]
  say("%s: flows %d rows", R$run, nrow(fl))
  flows <- fl[, .(combo, key = g, Iteration, Timestep, v)]
  losses <- fl[g %in% LOSS_GROUPS, .(combo, key = paste(g, loss_cause(g, fifelse(is.na(t), "", t)), sep = "|"), Iteration, Timestep, v)]
  keys <- list(area = sc$Name, trans = sort(unique(tr$key)), stocks = sort(unique(st$key)), flows = intersect(FLOWS, unique(flows$key)), losses = sort(unique(losses$key)))
  T <- list(area = cube(area[, .(combo, key, Iteration, Timestep, v)], keys$area, R, 1), trans = cube(tr[, .(combo, key, Iteration, Timestep, v)], keys$trans, R, 1),
            stocks = cube(st[, .(combo, key, Iteration, Timestep, v)], keys$stocks, R, 0), flows = cube(flows, keys$flows, R, 1), losses = cube(losses, keys$losses, R, 1))
  write_json(T, file.path(out, sprintf("tables-%s.json", R$run)), digits = NA)
  tables_meta[[R$run]] <- keys }

# ---- grid, mask, strata, relief, boundaries -------------------------------------------------------------------------------
ic <- dd(hist_id, "stsim_InitialConditionsSpatial")
p_r <- rast(file.path(ic, "PrimaryStrata.tif")); s_r <- rast(file.path(ic, "SecondaryStrata.tif"))
first_sc <- q("SELECT Filename FROM stsim_OutputSpatialState WHERE ScenarioId = %d AND Iteration = %d ORDER BY Timestep LIMIT 1", hist_id, runs$it0[1])$Filename
g <- rast(file.path(dd(hist_id, "stsim_OutputSpatialState"), basename(first_sc)))
mask <- !is.na(values(g)[, 1]); cells <- which(mask); n <- length(cells)
wpng <- function(v, f, tmpl = g, at = cells) {   # one byte per cell, the whole grid, 255 outside the study area
  full <- rep(255L, ncell(tmpl)); full[at] <- as.integer(v); r <- rast(tmpl); values(r) <- full; p <- file.path(out, "maps", f)
  writeRaster(r, p, datatype = "INT1U", filetype = "PNG", overwrite = TRUE, gdal = "WORLDFILE=NO", NAflag = NA); unlink(paste0(p, ".aux.xml")) }
byte <- function(v) { v <- round(v); v[is.na(v) | v < 0] <- 255L; v[v > 254] <- 254L; v }
# strata: the map values are the strata IDs; the tables' StratumId/SecondaryStratumId are the database keys
pid <- q("SELECT StratumId p, ID m FROM stsim_Stratum"); sid <- q("SELECT SecondaryStratumId s, ID m FROM stsim_SecondaryStratum")
pv <- pid$p[match(values(p_r)[cells, 1], pid$m)]; sv <- sid$s[match(values(s_r)[cells, 1], sid$m)]
wpng(byte(cid(pv, sv)), "strata.png")
say("grid %d x %d, %d cells in the study area", ncol(g), nrow(g), n)
dem_f <- Sys.getenv("LUCAS_DEM", "")
if (!nzchar(dem_f)) { ef <- q("SELECT ElevationFile FROM lucasCore_DataSource")$ElevationFile; dem_f <- if (length(ef) && !is.na(ef[1])) ef[1] else "" }
relief <- NULL
if (nzchar(dem_f) && file.exists(dem_f)) {
  fine <- rast(ext(g), ncols = ncol(g) * 2, nrows = nrow(g) * 2, crs = crs(g))
  d <- project(rast(dem_f), fine, method = "bilinear")
  slp <- terrain(d, "slope", unit = "radians"); asp <- terrain(d, "aspect", unit = "radians")
  hs <- Reduce(`+`, lapply(c(300, 337, 15), function(k) shade(slp, asp, angle = 42, direction = k))) / 3
  hv <- values(hs)[, 1]; hv[is.na(hv)] <- median(hv, na.rm = TRUE); hv <- (hv - quantile(hv, .005)) / diff(quantile(hv, c(.005, .995)))
  wpng(byte(pmin(pmax(hv, 0), 1) * 254), "relief.png", tmpl = fine, at = seq_len(ncell(fine))); relief <- list(ncol = ncol(fine), nrow = nrow(fine))
  # elevation in the study area (m, / 20), for the hover readout
  e <- project(rast(dem_f), g, method = "bilinear"); wpng(byte(values(e)[cells, 1] / 20), "elev.png")
  say("relief from %s", dem_f) } else say("no elevation file: no relief (set LUCAS_DEM)")
to_grid <- function(v) { xy <- crds(v); data.table(x = round((xy[, 1] - xmin(g)) / res(g)[1], 1), y = round((ymax(g) - xy[, 2]) / res(g)[2], 1)) }
outline <- function(r, keyname) {   # polygons of a strata map in grid cell units, simplified
  r <- mask(r, g); pl <- simplifyGeom(as.polygons(r, dissolve = TRUE), tolerance = res(g)[1] * .8)
  lapply(seq_len(nrow(pl)), function(i) { gi <- geom(pl[i]); parts <- split(as.data.table(gi), by = c("part", "hole"))
    list(id = values(pl)[i, 1], rings = unname(lapply(parts, function(p) { m <- cbind(round((p$x - xmin(g)) / res(g)[1], 1), round((ymax(g) - p$y) / res(g)[2], 1)); unname(as.vector(t(m))) }))) }) }
s_map <- s_r; values(s_map) <- sid$s[match(values(s_r)[, 1], sid$m)]
p_map <- p_r; values(p_map) <- pid$p[match(values(p_r)[, 1], pid$m)]
study <- g; values(study) <- ifelse(mask, 1L, NA_integer_)
bounds <- list(study = outline(study), county = outline(s_map), ecoregion = outline(p_map))
for (b in c("county", "ecoregion")) for (j in seq_along(bounds[[b]])) bounds[[b]][[j]]$name <- if (b == "county") sub("^County: ", "", sn$Name[match(bounds[[b]][[j]]$id, sn$s)]) else pn$Name[match(bounds[[b]][[j]]$id, pn$p)]

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
rdv <- function(f) values(rast(f))[cells, 1]
layers <- list()
for (i in seq_len(nrow(runs))) { R <- runs[i]; rid <- R$id; L <- list()
  ssm <- q("SELECT Iteration, Timestep, Filename FROM stsim_OutputSpatialState WHERE ScenarioId = %d", rid)
  for (y in sort(unique(ssm[Iteration == R$it0, Timestep]))) { v <- rdv(file.path(dd(rid, "stsim_OutputSpatialState"), basename(ssm[Iteration == R$it0 & Timestep == y, Filename][1])))
    wpng(byte(sc$idx[match(v, sc$MapId)]), sprintf("sc-%s-%d.png", R$run, y)) }
  L$sc <- sort(unique(ssm[Iteration == R$it0, Timestep]))
  agm <- if (dbExistsTable(con, "stsim_OutputSpatialAge")) q("SELECT Timestep, Filename FROM stsim_OutputSpatialAge WHERE ScenarioId = %d AND Iteration = %d", rid, R$it0) else data.table()
  for (y in agm$Timestep) wpng(byte(rdv(file.path(dd(rid, "stsim_OutputSpatialAge"), basename(agm[Timestep == y, Filename][1]))) / 2), sprintf("age-%s-%d.png", R$run, y))
  L$age <- sort(agm$Timestep)
  for (lay in list(c("tec", "Total Ecosystem"), c("live", "Biomass: Total"))) {
    m <- q("SELECT o.Timestep, o.Filename FROM stsim_OutputAverageSpatialStockGroup o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId WHERE o.ScenarioId = %d AND g.Name = '%s'", rid, lay[2])
    for (y in m$Timestep) wpng(byte(rdv(file.path(dd(rid, "stsim_OutputAverageSpatialStockGroup"), basename(m[Timestep == y, Filename][1]))) / 2), sprintf("%s-%s-%d.png", lay[1], R$run, y))
    L[[lay[1]]] <- sort(m$Timestep) }
  trm <- q("SELECT o.Iteration, o.Timestep, g.Name AS Grp, o.Filename FROM stsim_OutputSpatialTransition o JOIN stsim_TransitionGroup g ON g.TransitionGroupId = o.TransitionGroupId WHERE o.ScenarioId = %d AND (%s)",
           rid, paste(sprintf("g.Name = '%s' OR g.Name LIKE '%s:%%'", DIST_GROUPS, DIST_GROUPS), collapse = " OR "))   # a family's own map, or its type groups' (harvest and mortality map only by type)
  trm[, File := file.path(dd(rid, "stsim_OutputSpatialTransition"), basename(Filename))]
  dyears <- sort(unique(trm[Iteration == R$it0, Timestep]))
  for (y in dyears) { code <- rep(0L, n)
    for (f in trm[Iteration == R$it0 & Timestep == y, File]) { v <- rdv(f); k <- which(!is.na(v) & v > 0); if (length(k)) { cv <- tt$code[match(v[k], tt$MapId)]; code[k[!is.na(cv)]] <- cv[!is.na(cv)] } }
    wpng(code, sprintf("dist-%s-%d.png", R$run, y)) }
  L$dist <- dyears
  say("%s maps: sc %d, age %d, tec %d, live %d, dist %d years", R$run, length(L$sc), length(L$age), length(L$tec), length(L$live), length(dyears))
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
region <- q("SELECT Name FROM stsim_TertiaryStratum")$Name
meta <- list(
  title = sub("^Pyrome: ", "", region[1]), library = basename(lib), exported = format(Sys.time(), "%Y-%m-%d %H:%M"),
  grid = list(ncol = ncol(g), nrow = nrow(g), res = res(g)[1], xmin = xmin(g), ymax = ymax(g), crs = "EPSG:5070", cells = n, relief = relief),
  runs = lapply(seq_len(nrow(runs)), function(i) { R <- runs[i]; list(key = R$run, id = R$id, label = R$label, kind = R$kind, years = c(R$y0, R$y1), iterations = c(R$it0, R$it1),
                                                                     keys = tables_meta[[R$run]], maps = layers[[R$run]]) }),
  classes = lapply(seq_len(nrow(sc)), function(i) list(name = sc$Name[i], group = sc$group[i], color = sc$color[i])),
  groups = lapply(names(COVER_COLS), function(k) list(name = k, color = unname(COVER_COLS[k]))),
  combos = lapply(seq_len(nrow(combos)), function(i) list(ecoregion = combos$ecoregion[i], county = combos$county[i])),
  dist = lapply(seq_len(nrow(DIST)), function(i) list(code = DIST$code[i], name = DIST$name[i], color = DIST$color[i])),
  units = list(area = "ha", carbon = "t C", maps_carbon = "t C/ha, stored / 2", maps_age = "years, stored / 2", elev = "m, stored / 20"),
  bounds = bounds)
write_json(meta, file.path(out, "meta.json"), auto_unbox = TRUE, digits = NA)
dbDisconnect(con)
f <- list.files(out, recursive = TRUE, full.names = TRUE)
say("done: %d files, %.1f MB in %s", length(f), sum(file.size(f)) / 1e6, out)
