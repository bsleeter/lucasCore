# =============================================================================
# run-figures.R - report figures of an ST-Sim run (a historical run or a projection) on a lucasCore Build; sourced by stage 13
# (src/13-run-figures.R), and testable outside a run (dev/figures/test_run_figures.R)
# =============================================================================
# Same format as the Build figures (src/figures.R, figure_kit): "Figure N" headers, lettered panels, maps on shaded relief.
#   maps    land cover in the first and last year and the land-use change between them, harvest included | fire: times burned,
#           highest severity, last burn | harvest: times harvested, type, last harvest | total ecosystem carbon in the first and last
#           year and its change
#   charts  land area by cover group | transitions per year, simulated against the Build's record | carbon stocks | carbon fluxes |
#           harvested wood products and NBP with them (when stage 18 has been run on the run: wp_of_run) |
#           carbon by secondary stratum (counties)
# A stand-alone projection is drawn with its historical run in front (find_history, join_runs): one set of figures from the start of the
# history to the end of the projection, a dashed line where the projection starts.
# load_run(lib, rid, ...) reads the run: its tables summed in SQL (iterations averaged) and its first-iteration maps by path; maps the
# run did not write (state class, fire or harvest transitions, total ecosystem carbon) leave their figure or panel out. Harvest is
# read from every mapped group named "Forest Harvest..." (the clearcut and selection [Type] groups by default), its cells classed by
# transition type name.
# =============================================================================
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })

cover_group <- function(x) { g <- sub(":.*$", "", x); g[grepl("^Forest", x)] <- "Forest"
  g[!g %in% c("Forest", "Disturbed", "Shrubland", "Grassland", "Agriculture", "Developed", "Wetland", "Water")] <- "Barren and other"; g }   # Disturbed: waiting to return or convert (to-do 57)
COVER_COLS <- c(Forest = "#2b8152", Disturbed = "#b5651d", Shrubland = "#c9a26b", Grassland = "#e6d77a", Agriculture = "#d98b3a", Developed = "#c0392b",
                Wetland = "#5aa9b8", Water = "#3b6ea8", `Barren and other` = "#a3a3a3")
FAMILIES <- c("Urbanization", "Intensification", "Ag Expansion", "Ag Contraction", "Ag Change", "Fire", "Forest Harvest")
# carbon lost each year, by cause (user, 2026-11-10: the flux figure's "fire emissions" were every transition's emissions): a transition's
# emissions and removals (LULC: Emission, LULC: Harvest) by its type, crop harvest (Harvest: Agriculture) and drained peat
LOSS_COLS <- c(Fire = "#c93a1d", Insect = "#7b4a8b", `Forest harvest` = "#6b6b6b", `Land use change` = "#8c6d31", `Crop harvest` = "#e3b23c", `Drained peat` = "#4a2f17")
loss_cause <- function(grp, type) data.table::fcase(grp == "Harvest: Agriculture", "Crop harvest", grepl("^Emission: Drained", grp), "Drained peat", grp == "Lateral Flux", "Lateral export",
                                                    grepl("^Fire", type), "Fire", grepl("^Insect", type), "Insect", grepl("^Forest Harvest", type), "Forest harvest",
                                                    default = "Land use change")
# emissions to the atmosphere by driver (Carbon fluxes c), carbon carried off the land (d), net biome productivity by land cover (f)
EMIS_COLS <- c(`Fire: vegetation` = "#c93a1d", `Fire: peat` = "#7f1d0f", Insect = "#7b4a8b", `Forest harvest` = "#6b6b6b", Urbanization = "#b07aa1", `Other land change` = "#8c6d31", `Drained peat` = "#4a2f17")
emis_driver <- function(type) data.table::fcase(grepl("^Fire", type), "Fire", grepl("^Insect", type), "Insect", grepl("^Forest Harvest", type), "Forest harvest",
                                               grepl("^Urbanization", type), "Urbanization", default = "Other land change")
REM_COLS <- c(`Forest harvest wood` = "#6b6b6b", `Wood from land use change` = "#8c6d31", `Crop harvest` = "#e3b23c", `Lateral export (water)` = "#6baed6")
BAL_COLS <- c(Forest = "#2b8152", Disturbed = "#b5651d", `Forested wetland` = "#66c2a5", `Emergent wetland` = "#9ecae1", Agriculture = "#d98b3a", `Grass and shrub` = "#c9a26b", Developed = "#c0392b", Other = "#a3a3a3")
# wetland methane (lucasCore 1.5) by the kind of wetland it came from: the two emergent classes, and the forested wetland classes together
CH4_COLS <- c(`Palustrine emergent marsh` = "#7fb6d9", `Estuarine emergent marsh` = "#2c7fb8", `Forested wetland` = "#66c2a5")
methane_kind <- function(x) data.table::fcase(grepl("Palustrine Emergent", x), "Palustrine emergent marsh", grepl("Estuarine Emergent", x), "Estuarine emergent marsh", default = "Forested wetland")
balance_group <- function(x) data.table::fcase(grepl("^Forest", x), "Forest", grepl("^Disturbed", x), "Disturbed", grepl("^Wetland: .*(Group|Forested)$", x), "Forested wetland", grepl("^Wetland", x), "Emergent wetland",
                                               grepl("^Agriculture", x), "Agriculture", grepl("^(Grassland|Shrubland)", x), "Grass and shrub", grepl("^Developed", x), "Developed", default = "Other")
RAMP_CHG <- colorRampPalette(c("#7a3b12", "#c98b4f", "#efd9b4", "#f5f2ec", "#cfe3b8", "#6fae74", "#1f5f3f"))

# ---- the run's tables and maps ---------------------------------------------------------------------------------------------
# lib: the library file; rid: the run's result scenario id
load_run <- function(lib, rid) {
  con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); on.exit(dbDisconnect(con))
  q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
  dd <- file.path(paste0(lib, ".data"), sprintf("Scenario-%d", rid))
  nit <- q("SELECT COUNT(DISTINCT Iteration) n FROM stsim_OutputStratumState WHERE ScenarioId = %d", rid)$n
  if (!nit) stop(sprintf("scenario %d has no ST-Sim state class output: is it a result of an ST-Sim run?", rid))
  sc <- q("SELECT ID AS Id, Name FROM stsim_StateClass"); tt <- q("SELECT ID AS Id, Name FROM stsim_TransitionType")
  area <- q("SELECT s.Timestep, c.Name AS Class, SUM(s.Amount) / %d AS ha FROM stsim_OutputStratumState s JOIN stsim_StateClass c ON c.StateClassId = s.StateClassId
             WHERE s.ScenarioId = %d GROUP BY s.Timestep, c.Name", nit, rid)
  yrs <- range(area$Timestep)
  trans <- q("SELECT t.Timestep, g.Name AS TransitionGroup, SUM(t.Amount) / %d AS ha FROM stsim_OutputStratumTransition t JOIN stsim_TransitionGroup g ON g.TransitionGroupId = t.TransitionGroupId
              WHERE t.ScenarioId = %d GROUP BY t.Timestep, g.Name", nit, rid)
  stocks <- if (dbExistsTable(con, "stsim_OutputStock")) q("SELECT o.Timestep, g.Name AS StockGroup, SUM(o.Amount) / %d AS Mg FROM stsim_OutputStock o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId
              WHERE o.ScenarioId = %d AND g.Name IN ('Total Ecosystem', 'Biomass: Total', 'DOM: Deadwood', 'DOM: Litter', 'DOM: Soil') GROUP BY o.Timestep, g.Name", nit, rid) else NULL
  flows <- if (dbExistsTable(con, "stsim_OutputFlow")) q("SELECT o.Timestep, g.Name AS FlowGroup, SUM(o.Amount) / %d AS Mg FROM stsim_OutputFlow o JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId
              WHERE o.ScenarioId = %d AND g.Name IN ('Net Primary Productivity', 'Emission: Total Rh', 'Net Ecosystem Productivity', 'Net Biome Productivity', 'LULC: Emission', 'LULC: Harvest')
              GROUP BY o.Timestep, g.Name", nit, rid) else NULL
  losses <- if (dbExistsTable(con, "stsim_OutputFlow")) q("SELECT o.Timestep, g.Name AS FlowGroup, t.Name AS TransitionType, SUM(o.Amount) / %d AS Mg FROM stsim_OutputFlow o
              JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId LEFT JOIN stsim_TransitionType t ON t.TransitionTypeId = o.TransitionTypeId WHERE o.ScenarioId = %d
              AND g.Name IN ('LULC: Emission', 'LULC: Emission Peat', 'LULC: Harvest', 'Harvest: Agriculture', 'Emission: Drained Organic Soil -> Atmosphere [Type]', 'Lateral Flux')
              GROUP BY o.Timestep, g.Name, t.Name", nit, rid) else NULL
  if (!is.null(losses)) losses[, Cause := loss_cause(FlowGroup, TransitionType)]
  # net biome productivity by the class it came from (a transition's losses count to the class the cell left)
  nbp_cls <- if (dbExistsTable(con, "stsim_OutputFlow")) q("SELECT o.Timestep, c.Name AS Class, SUM(o.Amount) / %d AS Mg FROM stsim_OutputFlow o JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId
              JOIN stsim_StateClass c ON c.StateClassId = o.FromStateClassId WHERE o.ScenarioId = %d AND g.Name = 'Net Biome Productivity' GROUP BY o.Timestep, c.Name", nit, rid) else NULL
  # wetland methane by the class that released it, in carbon and in CO2 equivalent (none in a run made before lucasCore 1.5)
  ch4 <- if (dbExistsTable(con, "stsim_OutputFlow")) q("SELECT o.Timestep, c.Name AS Class, g.Name AS FlowGroup, SUM(o.Amount) / %d AS Mg FROM stsim_OutputFlow o JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId
              JOIN stsim_StateClass c ON c.StateClassId = o.FromStateClassId WHERE o.ScenarioId = %d AND g.Name IN ('Emission: Wetland CH4', 'Emission: Wetland CH4 (CO2e)') GROUP BY o.Timestep, c.Name, g.Name", nit, rid) else NULL
  unit_c <- if (!is.null(stocks)) q("SELECT s.Name AS Unit, o.Timestep, SUM(o.Amount) / %d AS Mg FROM stsim_OutputStock o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId
              JOIN stsim_SecondaryStratum s ON s.SecondaryStratumId = o.SecondaryStratumId WHERE o.ScenarioId = %d AND g.Name = 'Total Ecosystem' AND o.Timestep IN (%d, %d)
              GROUP BY s.Name, o.Timestep", nit, rid, yrs[1], yrs[2]) else NULL
  unit_a <- q("SELECT s.Name AS Unit, SUM(o.Amount) / %d AS ha FROM stsim_OutputStratumState o JOIN stsim_SecondaryStratum s ON s.SecondaryStratumId = o.SecondaryStratumId
              WHERE o.ScenarioId = %d AND o.Timestep = %d GROUP BY s.Name", nit, rid, yrs[1])
  te_it <- if (nit > 1 && dbExistsTable(con, "stsim_OutputStock")) q("SELECT o.Iteration, o.Timestep, SUM(o.Amount) / 1e6 AS Tg FROM stsim_OutputStock o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId
              WHERE o.ScenarioId = %d AND g.Name = 'Total Ecosystem' GROUP BY o.Iteration, o.Timestep", rid) else NULL
  path <- function(folder, f) if (length(f) && !is.na(f[1])) file.path(dd, folder, basename(f[1])) else NA_character_
  ssm <- q("SELECT Timestep, Filename FROM stsim_OutputSpatialState WHERE ScenarioId = %d AND Iteration = 1", rid)
  # the stand age maps of iteration 1 in the first and last year (the stand age figure; a run without spatial age output has none)
  agm <- if (dbExistsTable(con, "stsim_OutputSpatialAge")) q("SELECT Timestep, Filename FROM stsim_OutputSpatialAge WHERE ScenarioId = %d AND Iteration = 1", rid) else data.table(Timestep = integer(), Filename = character())
  fire_id <- q("SELECT TransitionGroupId FROM stsim_TransitionGroup WHERE Name = 'Fire'")$TransitionGroupId
  fm <- if (length(fire_id)) q("SELECT Timestep, Filename FROM stsim_OutputSpatialTransition WHERE ScenarioId = %d AND Iteration = 1 AND TransitionGroupId = %d", rid, fire_id[1]) else data.table()
  hm <- q("SELECT o.Timestep, o.Filename FROM stsim_OutputSpatialTransition o JOIN stsim_TransitionGroup g ON g.TransitionGroupId = o.TransitionGroupId
           WHERE o.ScenarioId = %d AND o.Iteration = 1 AND g.Name LIKE 'Forest Harvest%%'", rid)
  te <- q("SELECT o.Timestep, o.Filename FROM stsim_OutputAverageSpatialStockGroup o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId WHERE o.ScenarioId = %d AND g.Name = 'Total Ecosystem'", rid)
  # the pools the carbon capacity counts (src/capacity.R): their average maps in the first and last year, for the deficit by cause
  hl <- q("SELECT o.Timestep, g.Name AS Grp, o.Filename FROM stsim_OutputAverageSpatialStockGroup o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId
           WHERE o.ScenarioId = %d AND g.Name IN ('Biomass: Total', 'DOM: Deadwood', 'DOM: Litter') AND o.Timestep IN (%d, %d)", rid, yrs[1], yrs[2])
  hl_of <- function(y) { d <- hl[Timestep == y]; if (uniqueN(d$Grp) < 3) character() else vapply(c("Biomass: Total", "DOM: Deadwood", "DOM: Litter"), function(g) path("stsim_OutputAverageSpatialStockGroup", d[Grp == g, Filename]), "") }
  # post-disturbance return and conversion, and reforestation (to-do 57 step 6): their yearly maps of iteration 1
  pdm <- q("SELECT o.Timestep, g.Name AS Grp, o.Filename FROM stsim_OutputSpatialTransition o JOIN stsim_TransitionGroup g ON g.TransitionGroupId = o.TransitionGroupId
           WHERE o.ScenarioId = %d AND o.Iteration = 1 AND (g.Name LIKE 'Post-disturbance: %%' OR g.Name = 'Reforestation')", rid)
  if (nrow(pdm)) pdm[, File := vapply(Filename, function(f) path("stsim_OutputSpatialTransition", f), "")]
  list(rid = rid, nit = nit, years = yrs, sc_list = sc, tt_list = tt, area = area, trans = trans, stocks = stocks, flows = flows, losses = losses, nbp_cls = nbp_cls, ch4 = ch4, unit_c = unit_c, unit_a = unit_a, te_it = te_it,
       sc0 = path("stsim_OutputSpatialState", ssm[Timestep == yrs[1], Filename]), sc1 = path("stsim_OutputSpatialState", ssm[Timestep == yrs[2], Filename]),
       fire = if (nrow(fm)) setNames(vapply(fm$Filename, function(f) path("stsim_OutputSpatialTransition", f), ""), fm$Timestep) else character(),
       harvest = if (nrow(hm)) setNames(vapply(hm$Filename, function(f) path("stsim_OutputSpatialTransition", f), ""), hm$Timestep) else character(),
       carbon0 = path("stsim_OutputAverageSpatialStockGroup", te[Timestep == yrs[1], Filename]), carbon1 = path("stsim_OutputAverageSpatialStockGroup", te[Timestep == yrs[2], Filename]),
       hl0 = hl_of(yrs[1]), hl1 = hl_of(yrs[2]), age0 = path("stsim_OutputSpatialAge", agm[Timestep == yrs[1], Filename]), age1 = path("stsim_OutputSpatialAge", agm[Timestep == yrs[2], Filename]),
       pd = if (nrow(pdm)) pdm[, .(Timestep, Grp, File)] else NULL)
}

# ---- a projection's historical run, and the two joined -------------------------------------------------------------------
# A stand-alone projection starts from a historical run's final year (stage 9's Projection Start, in its Projection Setup result).
# find_history: that run's id for result scenario rid (its own, its parent's or its parent's dependencies' Projection Start), or NA.
find_history <- function(lib, rid) {
  con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); on.exit(dbDisconnect(con))
  q <- function(s, ...) dbGetQuery(con, sprintf(s, ...))
  if (!dbExistsTable(con, "lucasCore_ProjectionStart")) return(NA_integer_)
  par <- q("SELECT ScenarioId FROM core_ScenarioResult WHERE ResultId = %d", rid)$ScenarioId
  ids <- c(rid, par, if (length(par)) q("SELECT DependencyId FROM core_ScenarioDependency WHERE ScenarioId = %d ORDER BY Priority", par[1])$DependencyId)
  for (i in ids) { h <- q("SELECT HistoricalScenarioId FROM lucasCore_ProjectionStart WHERE ScenarioId = %d", i)$HistoricalScenarioId
    if (length(h) && !is.na(h[1])) return(as.integer(h[1])) }
  NA_integer_ }
# join_runs: one run from the historical run's start to the projection's end. Tables: the historical run up to the projection's
# start year (its final year, which the projection starts from), the projection after it; maps: the first year from the historical
# run, the last from the projection; fire and harvest maps of both. `join` holds total ecosystem carbon in the start year in each
# (the hand-over check); `proj_start` marks the join in the charts.
join_runs <- function(H, P) {
  ys <- P$years[1]
  cut <- function(a, b) if (is.null(a) || is.null(b)) NULL else rbind(a[Timestep <= ys], b[Timestep > ys])
  J <- P; J$years <- c(H$years[1], P$years[2])
  for (k in c("area", "trans", "stocks", "flows", "losses", "nbp_cls", "ch4")) J[k] <- list(cut(H[[k]], P[[k]]))
  J$unit_c <- if (!is.null(H$unit_c) && !is.null(P$unit_c)) rbind(H$unit_c[Timestep == H$years[1]], P$unit_c[Timestep == P$years[2]]) else NULL
  J$unit_a <- H$unit_a; J$sc0 <- H$sc0; J$carbon0 <- H$carbon0; J$age0 <- H$age0; J["hl0"] <- list(H$hl0)
  late <- function(m) m[as.integer(names(m)) > ys]
  J$fire <- c(H$fire, late(P$fire)); J$harvest <- c(H$harvest, late(P$harvest))
  J$pd <- rbind(H$pd, if (!is.null(P$pd)) P$pd[Timestep > ys])
  te <- function(X) { s <- X$stocks; if (is.null(s)) NA_real_ else s[StockGroup == "Total Ecosystem" & Timestep == ys, sum(Mg)] / 1e6 }
  J$join <- c(history = te(H), projection = te(P)); J$proj_start <- ys; J$hist <- list(rid = H$rid, years = H$years)
  J }

# ---- the model grid from a run -------------------------------------------------------------------------------------------
# run_grid: the state class map of the first of result scenarios rids whose own initial conditions file is in the library's data
# folder (a run's result holds a copy of its Build's, or the projection's start map), or NA. Stages 13 and 14 read the grid from the
# Build result they depend on, and fall back to this when that file is gone (Puget Lowlands, 2026-11-12: the data folders of its
# older results, the Build's among them, had been removed, and SyncroSim failed the read with "Object reference not set").
run_grid <- function(lib, rids) {
  con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); on.exit(dbDisconnect(con))
  for (r in rids[!is.na(rids)]) { f <- dbGetQuery(con, sprintf("SELECT StateClassFileName f FROM stsim_InitialConditionsSpatial WHERE ScenarioId = %d", as.integer(r)))$f
    if (length(f) && !is.na(f[1])) { p <- file.path(paste0(lib, ".data"), sprintf("Scenario-%d", as.integer(r)), "stsim_InitialConditionsSpatial", basename(f[1]))
      if (file.exists(p)) return(structure(p, run = as.integer(r))) } }
  NA_character_ }
# the grid a figures stage draws on: the Build result's state class map (ic: its Initial Conditions Spatial sheet, or an error), else
# run_grid's; say: the stage's log function
figures_grid <- function(ic, lib, rids, say) {
  f <- if (inherits(ic, "error") || !nrow(ic) || is.na(ic$StateClassFileName[1])) NA_character_ else ic$StateClassFileName[1]
  if (!is.na(f) && file.exists(f)) return(f)
  g <- run_grid(lib, rids)
  if (!is.na(g)) say("The Build result's state class map is not readable (%s): the grid is read from run %d's initial conditions instead",
                     if (inherits(ic, "error")) "SyncroSim could not read it; its file may be missing from the library's data folder" else if (is.na(f)) "the Build result has none" else "its file is missing",
                     attr(g, "run"))
  as.character(g) }

# ---- harvested wood products (stage 18) ------------------------------------------------------------------------------------
# wp_of_run: the wood products of run rid, from the newest Wood Products result that followed it (stage 18's Wood Products sheet, the
# rows over all iterations: Year, Variable, Mean, Lower, Upper; Mg C), or NULL when stage 18 has not been run on it. A projection's
# result holds its historical run's years too (stage 18 joins them). Stages 13 and 14 keep it as X$wp.
wp_of_run <- function(lib, rid) {
  con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); on.exit(dbDisconnect(con))
  if (!dbExistsTable(con, "lucasCore_OutputWoodProducts")) return(NULL)
  s <- dbGetQuery(con, sprintf("SELECT MAX(ScenarioId) s FROM lucasCore_OutputWoodProducts WHERE RunScenarioId = %d", rid))$s
  if (!length(s) || is.na(s)) return(NULL)
  w <- as.data.table(dbGetQuery(con, sprintf("SELECT Year, Variable, Mean, Lower, Upper FROM lucasCore_OutputWoodProducts WHERE ScenarioId = %d AND RunScenarioId = %d AND Iteration IS NULL", s, rid)))
  if (!nrow(w)) return(NULL)
  setattr(w, "scenario", as.integer(s)); w }
# a wood products variable (or the sum of several) over the run's years, Tg C: Timestep, Tg (and Lower, Upper for one variable)
wp_tg <- function(X, v) { W <- X$wp; if (is.null(W)) return(data.table(Timestep = integer(), Tg = numeric(), Lower = numeric(), Upper = numeric()))
  W[Variable %in% v & Year >= X$years[1] & Year <= X$years[2], .(Tg = sum(Mean) / 1e6, Lower = if (.N == 1) Lower / 1e6 else NA_real_, Upper = if (.N == 1) Upper / 1e6 else NA_real_),
    by = .(Timestep = Year)][order(Timestep)] }
# net biome productivity counting storage in products (the production approach): the ecosystem's NBP, which counts harvest as a loss,
# plus the change in carbon stored in products in use and in landfills and dumps; Tg C per year, with the products' interval
nbp_products <- function(X) { s <- wp_tg(X, "StockChange")
  if (is.null(X$flows) || !nrow(s)) return(data.table(Timestep = integer(), Tg = numeric(), Lower = numeric(), Upper = numeric()))
  n <- X$flows[FlowGroup == "Net Biome Productivity", .(NBP = sum(Mg) / 1e6), by = Timestep]
  m <- merge(n, s, by = "Timestep"); m[, .(Timestep, Tg = NBP + Tg, Lower = NBP + Lower, Upper = NBP + Upper, NBP)][order(Timestep)] }

# ---- the figures -----------------------------------------------------------------------------------------------------------
# X: load_run(); grid: the Build's state class map (the model grid); sc_colours: state class Name -> colour; dem; label; observed: the
# Build's transition summary (Timestep, TransitionGroup, Area km2) or NULL; run_name
run_figures <- function(X, grid, sc_colours, dem, label, observed, outdir, run_name = sprintf("result %d", X$rid)) {
  y0 <- X$years[1]; y1 <- X$years[2]; ha_cell <- prod(res(grid)) / 1e4
  NOTE <- if (is.null(X$hist)) sprintf("%s; %s, %d-%d, %d iteration%s, %g m grid.", label, run_name, y0, y1, X$nit, if (X$nit > 1) "s (tables averaged; maps of iteration 1)" else "", res(grid)[1]) else
    sprintf("%s; historical run %d, %d-%d, then %s, %d-%d (dashed line), %d iteration%s, %g m grid.", label, X$hist$rid, y0, X$proj_start, run_name, X$proj_start + 1, y1, X$nit, if (X$nit > 1) "s (tables averaged; maps of iteration 1)" else "", res(grid)[1])
  K <- figure_kit(grid, dem, outdir, NOTE); use_kit(K, environment())
  relief <- if (dem_ok) " Shaded relief from the elevation data source." else ""
  rd <- function(f) if (!is.na(f) && file.exists(f)) rast(f) else NULL
  # a legend in rows under the plot (for panels whose legends are too long for the line above them); the panel needs mar[1] >= 7
  under_legend <- function(...) { n <- length(list(...)[[1]]); legend("top", ..., ncol = if (max(nchar(list(...)[[1]])) > 20) min(n, 2) else min(n, 3), inset = c(0, 1.12), xpd = NA, bty = "n", cex = .75, border = NA) }
  low <- function() par(mar = c(8, 5, 3, 1))
  # the join of a historical run and its projection (join_runs): a dashed line at the projection's start year, on year axes or between bars
  ps <- X$proj_start
  mark_at <- function(x) { abline(v = x, col = MUTED, lty = 2); mtext("projection", side = 3, at = x, adj = -0.05, line = -1.1, cex = .6, col = MUTED) }
  mark_line <- function() if (!is.null(ps)) mark_at(ps)
  mark_bar <- function(b, yrs) if (!is.null(ps)) { i <- match(ps, yrs); if (!is.na(i) && i < length(b)) mark_at((b[i] + b[i + 1]) / 2) }
  scn <- X$sc_list

  # ---- harvest per cell (iteration 1): times harvested, most intensive type (1 selection, 2 salvage, 3 clearcut), last year --------
  n_harv <- integer(length(inz)); hkind <- integer(length(inz)); last_h <- rep(NA_integer_, length(inz))
  kind_of <- function(id) { nm <- X$tt_list$Name[match(id, X$tt_list$Id)]; ifelse(grepl("Clearcut", nm), 3L, ifelse(grepl("Salvage", nm), 2L, 1L)) }
  for (y in unique(names(X$harvest))) { hit <- logical(length(inz))
    for (f in X$harvest[names(X$harvest) == y]) { r <- rd(f); if (is.null(r)) next; v <- cv(r); h <- !is.na(v) & v > 0
      hkind[h] <- pmax(hkind[h], kind_of(v[h])); hit <- hit | h }
    n_harv[hit] <- n_harv[hit] + 1L; last_h[hit] <- as.integer(y) }
  HARV_LAB <- c("Selection harvest", "Salvage logging", "Clearcut"); HARV_COLS <- c("#e0b43a", "#6b6b6b", "#7a4419")

  # ---- maps: land cover change ---------------------------------------------------------------------------------------------
  r0 <- rd(X$sc0); r1 <- rd(X$sc1)
  if (!is.null(r0) && !is.null(r1)) {
    a <- scn$Name[match(cv(r0), scn$Id)]; b <- scn$Name[match(cv(r1), scn$Id)]; ga <- cover_group(a); gb <- cover_group(b)
    lev <- c(Developed = 4L, Agriculture = 0L); dv <- function(x) match(sub("^Developed: ", "", x), c("Open Space", "Low Intensity", "Medium Intensity", "High Intensity"))
    ch <- rep(NA_integer_, length(a)); ok <- inz & !is.na(a) & !is.na(b)
    ch[ok] <- 1L
    ch[ok & gb == "Developed" & ga != "Developed"] <- 2L
    ch[ok & ga == "Developed" & gb == "Developed" & dv(b) > dv(a)] <- 3L
    ch[ok & gb == "Agriculture" & ga != "Agriculture"] <- 4L
    ch[ok & ga == "Agriculture" & gb != "Agriculture" & gb != "Developed"] <- 5L
    ch[ok & ch == 1L & a != b] <- 9L
    # harvest on land whose use did not change (forest stays forest): its most intensive type in the run, over any class change
    hv <- ok & ch %in% c(1L, 9L) & hkind > 0; ch[hv] <- 5L + hkind[hv]
    cl <- c("No change", "Urbanized", "Intensified", "To agriculture", "From agriculture", HARV_LAB, "Other change")
    cc <- c("#f1eee6", "#c0392b", "#7b1f1f", "#d98b3a", "#6fae74", HARV_COLS, "#7a76b8")
    pres <- sort(unique(ch[!is.na(ch)]))
    km2 <- function(k) sum(ch %in% k, na.rm = TRUE) * prod(res(el)) / 1e6
    P <- list(c(cats(r0, scn, n = 12, colours = sc_colours, label = short_class), list(title = sprintf("State class, %d", y0), sub = "the run's initial conditions")),
              c(cats(r1, scn, n = 12, colours = sc_colours, label = short_class), list(title = sprintf("State class, %d", y1), sub = "iteration 1")),
              list(k = match(ch, pres), cols = cc[pres], lab = cl[pres], key = TRUE, title = sprintf("Land-use change, %d-%d", y0, y1),
                   sub = sprintf("urbanized %.0f km2%s; first year against last", km2(2), if (any(hv)) sprintf(", harvested %.0f km2", km2(6:8)) else "")))
    map_figure("land_cover_change", "Land cover change", P,
      sprintf("(a, b) State class in the first and last year of the run (the twelve largest named). (c) What changed between them: development of non-developed land, a higher development intensity, gain or loss of agriculture, %sor another class change. A cell that changed and changed back counts as no change.%s",
              if (any(hv)) "forest harvested at least once during the run (its most intensive harvest type, from the yearly harvest transition maps of iteration 1), " else "", relief)) }

  # a run that mapped its transitions in a few years only (bookend maps) shows the fire and harvest of those years alone: say so
  part_maps <- function(files) { n <- length(unique(names(files))); if (n < y1 - y0) sprintf("; MAPPED IN %d OF %d YEARS ONLY (%s): the run did not write yearly transition maps", n, y1 - y0, paste(range(as.integer(names(files))), collapse = "-")) else "" }
  # ---- maps: fire --------------------------------------------------------------------------------------------------------------
  if (length(X$fire)) {
    n_burn <- integer(sum(TRUE, length(inz) - 1)); sev <- integer(length(inz)); last <- rep(NA_integer_, length(inz))
    tnames <- X$tt_list$Name; sev_of <- function(id) { nm <- tnames[match(id, X$tt_list$Id)]; ifelse(grepl("High", nm), 3L, ifelse(grepl("Medium", nm), 2L, ifelse(grepl("Low", nm), 1L, 0L))) }
    for (y in names(X$fire)) { r <- rd(X$fire[[y]]); if (is.null(r)) next; v <- cv(r); hit <- !is.na(v) & v > 0
      n_burn[hit] <- n_burn[hit] + 1L; s <- sev_of(v[hit]); sev[hit] <- pmax(sev[hit], s); last[hit] <- as.integer(y) }
    nb <- ifelse(n_burn == 0, NA, pmin(n_burn, 4L))
    yb <- c(y0, 1995, 2005, 2015, 2020, y1 + 1); yb <- unique(yb[yb >= y0 & yb <= y1 + 1]); ylab <- sprintf("%d-%d", head(yb, -1) + c(1, rep(0, length(yb) - 2)), tail(yb, -1) - 1)
    burned_km2 <- sum(n_burn > 0 & inz) * prod(res(el)) / 1e6
    map_figure("fire", sprintf("Fire, %d-%d", y0 + 1, y1), list(
      list(k = nb, cols = c("#fbe3a2", "#ef8f2a", "#c93a1d", "#5c0f14"), lab = c("1", "2", "3", "4+"), title = "Times burned", sub = sprintf("%.0f km2 burned at least once; grey: not burned%s", burned_km2, part_maps(X$fire))),
      list(k = ifelse(sev == 0, NA, sev), cols = c("#fbe3a2", "#ef8f2a", "#a81d1a"), lab = c("Low", "Medium", "High"), key = TRUE, title = "Highest burn severity", sub = "MTBS severity classes, as simulated"),
      list(k = ifelse(is.na(last), NA, findInterval(last, yb, rightmost.closed = TRUE)), cols = colorRampPalette(c("#fde7b0", "#e0702b", "#6b1a10"))(length(yb) - 1), lab = ylab,
           title = "Year of the last fire", sub = "grey: not burned")),
      sprintf("Fire in the run (iteration 1), from its yearly fire transition maps: how often each cell burned, its highest severity, and when it last burned.%s", relief)) }

  # ---- maps: harvest -----------------------------------------------------------------------------------------------------------
  if (any(n_harv > 0)) {
    yb <- c(y0, 1995, 2005, 2015, y1 + 1); yb <- unique(yb[yb >= y0 & yb <= y1 + 1]); ylab <- sprintf("%d-%d", head(yb, -1) + c(1, rep(0, length(yb) - 2)), tail(yb, -1) - 1)
    harv_km2 <- sum(n_harv > 0 & inz) * prod(res(el)) / 1e6; pk <- sort(unique(hkind[hkind > 0]))
    map_figure("harvest", sprintf("Forest harvest, %d-%d", y0 + 1, y1), list(
      list(k = ifelse(n_harv == 0, NA, pmin(n_harv, 3L)), cols = c("#e0b43a", "#a0612a", "#3d230b"), lab = c("1", "2", "3+"), title = "Times harvested", sub = sprintf("%.0f km2 harvested at least once; grey: not harvested%s", harv_km2, part_maps(X$harvest))),
      list(k = ifelse(hkind == 0, NA, match(hkind, pk)), cols = HARV_COLS[pk], lab = HARV_LAB[pk], key = TRUE, title = "Most intensive harvest", sub = "clearcut over salvage over selection"),
      list(k = ifelse(is.na(last_h), NA, findInterval(last_h, yb, rightmost.closed = TRUE)), cols = colorRampPalette(c("#efe3bd", "#b8894a", "#4a2c10"))(length(yb) - 1), lab = ylab,
           title = "Year of the last harvest", sub = "grey: not harvested")),
      sprintf("Forest harvest in the run (iteration 1), from its yearly harvest transition maps (the Forest Harvest groups mapped by the transition group output filter): how often each cell was harvested, its most intensive harvest type, and when it was last harvested.%s", relief)) }

  # ---- maps: after disturbance, and reforestation (to-do 57 step 6) ----------------------------------------------------------
  # Each cell that was in a disturbed class during the run (iteration 1): how it left it, from the yearly Post-disturbance maps (the
  # latest wins), or still waiting at the end (a disturbed class in the last year); when it last burned at high severity; and the
  # cells that reforested, by year
  pd <- X$pd; SHRUB_P <- c("Sage", "Native Sage Steppe", "Invaded Sage Steppe", "Non-sage", "Chaparral")
  if (!is.null(pd) && nrow(pd) && !is.null(r1)) {
    outc <- rep(NA_integer_, length(inz)); refy <- rep(NA_integer_, length(inz))
    code <- c(`Post-disturbance: Forest Return [Type]` = 1L, `Post-disturbance: Shrub Return [Type]` = 2L, `Post-disturbance: Conversion [Type]` = 3L)
    for (i in order(pd$Timestep)) { r <- rd(pd$File[i]); if (is.null(r)) next; v <- cv(r); hit <- !is.na(v) & v > 0
      if (pd$Grp[i] == "Reforestation") refy[hit] <- pd$Timestep[i] else if (pd$Grp[i] %in% names(code)) outc[hit] <- code[[pd$Grp[i]]] }
    v1 <- cv(r1); outc[inz & !is.na(v1) & v1 >= 2000] <- 4L
    v0 <- if (!is.null(r0)) cv(r0) else rep(NA_real_, length(inz)); started <- inz & !is.na(v0) & v0 >= 2000
    # the last stand-replacing fire: high severity, or moderate (Medium) in the shrub classes (tools/make_post_disturbance.R); a cell
    # counts as shrub when it starts or ends in a disturbed shrub class or came back to shrubland
    last_hs <- rep(NA_integer_, length(inz)); last_ms <- last_hs
    for (y in names(X$fire)) { r <- rd(X$fire[[y]]); if (is.null(r)) next; v <- cv(r); nm <- X$tt_list$Name[match(v, X$tt_list$Id)]
      last_hs[!is.na(v) & v > 0 & grepl("High", nm)] <- as.integer(y); last_ms[!is.na(v) & v > 0 & grepl("High|Medium", nm)] <- as.integer(y) }
    dsh <- X$sc_list$Id[X$sc_list$Name %in% paste0("Disturbed: ", SHRUB_P)]
    shr <- outc %in% 2L | v1 %in% dsh | v0 %in% dsh; last_hs[shr] <- last_ms[shr]
    if (any(!is.na(outc)) || any(!is.na(refy))) {
      km2c <- function(k) sum(outc %in% k & inz) * prod(res(el)) / 1e6
      OL <- c("Back to forest", "Back to shrubland", "Converted (shrub or grass)", "Still disturbed at the end"); OC <- c("#2b8152", "#c9a26b", "#c0392b", "#b5651d")
      pres <- sort(unique(outc[!is.na(outc)]))
      P <- list()
      if (length(pres)) P[[1]] <- list(k = match(outc, pres), cols = OC[pres], lab = sprintf("%s (%.1f km2)", OL[pres], vapply(pres, km2c, 0)), key = TRUE,
                                         title = "After disturbance: how each cell came out", sub = sprintf("cells in a disturbed class during the run; %.1f km2 started in one", sum(started) * prod(res(el)) / 1e6))
      if (length(pres)) { yb <- unique(c(y0, seq(y0 + 5, y1, by = 5), y1 + 1)); nb <- length(yb) - 1L
        # no high-severity fire on the maps: started disturbed (before the run), else a year the run did not map (a run that wrote no
        # transition maps, as a projection made with bookend maps)
        hs <- ifelse(is.na(outc), NA, ifelse(!is.na(last_hs), findInterval(last_hs, yb, rightmost.closed = TRUE) + 1L, ifelse(started, 1L, nb + 2L)))
        nomap <- any(hs %in% (nb + 2L))
        P[[length(P) + 1]] <- list(k = hs, cols = c("#d9d4c7", colorRampPalette(c("#fde7b0", "#e0702b", "#6b1a10"))(nb), "#8f8f8f"),
          lab = c(sprintf("before %d", y0 + 1), sprintf("%d-%d", head(yb, -1) + c(1, rep(0, length(yb) - 2)), tail(yb, -1) - 1), "no fire map for its year"), key = TRUE,
          title = "Last stand-replacing fire", sub = sprintf("the same cells (high severity; moderate or high in shrubland); before %d: started disturbed (a fire perimeter dates it)%s", y0 + 1, if (nomap) "; no fire map: the run wrote no transition maps that year" else "")) }
      if (any(!is.na(refy))) { yb <- unique(c(y0, seq(y0 + 5, y1, by = 5), y1 + 1))
        P[[length(P) + 1]] <- list(k = ifelse(is.na(refy), NA, findInterval(refy, yb, rightmost.closed = TRUE)), cols = colorRampPalette(c("#dfe6b4", "#62ab68", "#0f3a2b"))(length(yb) - 1),
          lab = sprintf("%d-%d", head(yb, -1) + c(1, rep(0, length(yb) - 2)), tail(yb, -1) - 1), key = TRUE, title = "Reforestation, by year",
          sub = sprintf("%.1f km2 of barren, shrub, grass or emergent wetland became forest", sum(!is.na(refy) & inz) * prod(res(el)) / 1e6)) }
      map_figure("post_disturbance", sprintf("After disturbance, and reforestation, %d-%d", y0 + 1, y1), P,
        sprintf("Iteration 1, from the run's yearly transition maps. %sA stand-replacing fire (high severity in forest, moderate or high in shrubland) moves the cell into its type's disturbed class; it returns to its type when %s, or converts to shrubland or grassland at the end of its window or at a stand-replacing reburn.%s%s",
                if (length(pres)) "(a) How each cell that was in a disturbed class left it (the latest exit), or that it is still waiting in the last year. (b) When those cells last had a stand-replacing fire. " else "",
                if (is.null(ps)) "the annual NLCD shows it again (historical years)" else "the annual NLCD shows it again (historical years) or with its yearly chance (projection years)",
                if (any(!is.na(refy))) sprintf(" (%s) Natural non-forest cells that became forest (Reforestation), by year.", letters[length(P)]) else "", relief)) }
  }

  # ---- charts: disturbed land and its outcomes over time (to-do 57 step 6) ----------------------------------------------------
  dis <- X$area[grepl("^Disturbed: ", Class)]
  pdt <- X$trans[TransitionGroup %in% c("Post-disturbance: Forest Return", "Post-disturbance: Shrub Return", "Post-disturbance: Conversion", "Reforestation")]
  if (nrow(dis) || nrow(pdt)) {
    dis[, Family := ifelse(sub("^Disturbed: ", "", Class) %in% SHRUB_P, "Disturbed shrubland", "Disturbed forest")]
    yrs <- y0:y1; da <- dcast(dis[, .(km2 = sum(ha) / 100), by = .(Timestep, Family)], Timestep ~ Family, value.var = "km2", fill = 0)
    ser <- function(g) { s <- pdt[TransitionGroup == g][match(yrs, Timestep), ha] / 100; s[is.na(s)] <- 0; s }
    TL <- c(`Post-disturbance: Forest Return` = "Back to forest", `Post-disturbance: Shrub Return` = "Back to shrubland", `Post-disturbance: Conversion` = "Converted", Reforestation = "Reforestation")
    TC <- c("#2b8152", "#c9a26b", "#c0392b", "#62ab68")
    chart_figure("post_disturbance_time", "Disturbed land and reforestation over time",
      sprintf("(a) Area in the disturbed classes each year (forest types and shrub types waiting to return or convert). (b) Area leaving them each year, back to their type or converted, and the area that reforested (natural non-forest becoming forest), in km2 a year%s.", if (is.null(ps)) "" else "; the dashed line marks the projection's start"),
      1, 2, h = 1150, draw = function() {
        low(); fams <- setdiff(names(da), "Timestep"); top <- max(c(unlist(da[, ..fams]), 0.01), na.rm = TRUE) * 1.1
        plot(NA, xlim = range(yrs), ylim = c(0, top), xlab = "", ylab = "km2"); hgrid()
        for (j in seq_along(fams)) lines(da$Timestep, da[[fams[j]]], col = c("#b5651d", "#d9b27a")[j], lwd = 2)
        mark_line(); ptitle(1, "Area in disturbed classes"); if (length(fams)) under_legend(fams, col = c("#b5651d", "#d9b27a")[seq_along(fams)], lwd = 2)
        low(); S <- sapply(names(TL), ser); top <- max(c(S, 0.01)) * 1.1
        plot(NA, xlim = range(yrs), ylim = c(0, top), xlab = "", ylab = "km2 per year"); hgrid()
        for (j in seq_along(TL)) lines(yrs, S[, j], col = TC[j], lwd = 2, type = "s")
        mark_line(); ptitle(2, "Leaving the disturbed classes, and reforestation")
        under_legend(sprintf("%s (%.1f km2 in all)", TL, colSums(S)), col = TC, lwd = 2) }) }

  # ---- forest stand age in the first and last year (user 2026-11-19: stand age is the model's least certain input) --------------
  # the age maps of iteration 1 on forest and forested wetland (a disturbed class counts its years since the disturbance and is left out)
  g0 <- rd(X$age0 %||% NA_character_); g1 <- rd(X$age1 %||% NA_character_)
  if (!is.null(g0) && !is.null(g1) && !is.null(r0) && !is.null(r1)) local({
    is_for <- function(nm) !is.na(nm) & grepl("Group$|Forested$", nm) & grepl("^(Forest|Wetland)", nm)
    n0 <- scn$Name[match(values(r0, mat = FALSE), scn$Id)]; n1 <- scn$Name[match(values(r1, mat = FALSE), scn$Id)]; f0 <- is_for(n0); f1 <- is_for(n1)
    v0 <- values(g0, mat = FALSE); v1 <- values(g1, mat = FALSE); v0[!f0 | v0 < 1] <- NA; v1[!f1 | v1 < 1] <- NA
    if (sum(!is.na(v0)) > 0 && sum(!is.na(v1)) > 0) {
      shr <- function(v) { t <- tabulate(cut(v[!is.na(v)], AGE_BRK, labels = FALSE), length(AGE_LAB)); 100 * t / sum(t) }
      M <- rbind(shr(v0), shr(v1)); dimnames(M) <- list(as.character(c(y0, y1)), AGE_LAB); ycol <- setNames(c("#a9a498", "#2b8152"), c(y0, y1))
      md <- function(v, nm) data.table(a = v, n = nm)[!is.na(a), .(m = as.numeric(median(a)), cells = .N), by = n]
      m0 <- md(v0, n0); m1 <- md(v1, n1); ft <- m0[order(-cells)][seq_len(min(.N, 10)), n]
      D <- data.table(Group = c("All forest", ft)); D[[as.character(y0)]] <- c(median(v0, na.rm = TRUE), m0$m[match(ft, m0$n)]); D[[as.character(y1)]] <- c(median(v1, na.rm = TRUE), m1$m[match(ft, m1$n)])
      km2 <- function(v) sum(!is.na(v)) * ha_cell / 100; u80 <- function(i) sum(M[i, 1:3]); o250 <- function(i) sum(M[i, 8:9])
      mv <- function(g, f) { v <- cv(g); nm <- scn$Name[match(cv(f), scn$Id)]; v[!is_for(nm) | v < 1] <- NA; v }
      map_figure("stand_age_maps", sprintf("Forest stand age, %d and %d", y0, y1), list(
        list(k = classed(mv(g0, r0), AGE_MAP_BRK), cols = RAMP_AGE(length(AGE_LAB)), lab = AGE_LAB, title = sprintf("Stand age, %d (years)", y0), sub = sprintf("%s km2 of forest; median %.0f years; grey: not forest", format(round(km2(v0)), big.mark = ","), median(v0, na.rm = TRUE))),
        list(k = classed(mv(g1, r1), AGE_MAP_BRK), cols = RAMP_AGE(length(AGE_LAB)), lab = AGE_LAB, title = sprintf("Stand age, %d (years)", y1), sub = sprintf("%s km2 of forest; median %.0f years; grey: not forest", format(round(km2(v1)), big.mark = ","), median(v1, na.rm = TRUE)))),
        sprintf("Stand age of the forest and forested wetland cells in the first and last year of the run (iteration 1), in the classes of the next figure. A stand ages a year each year; a stand-replacing fire or a clearcut sets it back to zero, and the cell is left out while it sits in a disturbed class.%s", relief))
      chart_figure("stand_age", "Forest by stand age", sprintf(paste0("(a) The share of the forest in each stand age class in %d and %d (iteration 1). Forest under 80 years goes from %.0f%% to %.0f%%, forest over 250 years from %.0f%% to %.0f%%. ",
          "(b) Median stand age of all forest and of the ten most extensive forest types of %d. The starting ages come from the Build's age map and the Stand Age page's rules, and are the model's least certain input (Build Figures: Forest stand age compares them with the study area's FIA plots)."),
          y0, y1, u80(1), u80(2), o250(1), o250(2), y0), 1, 2, h = 1150, draw = function() age_panels(M, ycol, D, ptitle, "Forest by stand age class", "Median stand age")) } })

  # ---- maps: carbon ------------------------------------------------------------------------------------------------------------
  c0 <- rd(X$carbon0); c1 <- rd(X$carbon1)
  if (!is.null(c0) && !is.null(c1)) {
    v0 <- cv(c0); v1 <- cv(c1); s <- steps(c(v0, v1)); dv <- v1 - v0
    m <- unname(quantile(abs(dv[inz]), 0.99, na.rm = TRUE)); m <- if (m > 0) m else 1; b <- unique(signif(m * c(-1, -.5, -.2, -.05, .05, .2, .5, 1), 1))
    dbrk <- c(-Inf, b, Inf); fm <- function(x) format(x, trim = TRUE)
    dlab <- c(paste0("<", fm(b[1])), ifelse(abs(b[-length(b)] + b[-1]) < 1e-9, paste0("±", fm(b[-1])), fm(b[-length(b)])), paste0(">", fm(b[length(b)])))   # lower edges; the class around 0 as +/-
    tot <- function(v) sum(v[inz], na.rm = TRUE) * prod(res(el)) / 1e4 / 1e6
    map_figure("carbon_change", sprintf("Total ecosystem carbon, %d and %d", y0, y1), list(
      list(k = classed(v0, s$brk), cols = RAMP_C(length(s$brk) - 1), lab = s$lab, title = sprintf("Total ecosystem carbon, %d (Mg C/ha)", y0), sub = sprintf("%.1f Tg C", tot(v0))),
      list(k = classed(v1, s$brk), cols = RAMP_C(length(s$brk) - 1), lab = s$lab, title = sprintf("Total ecosystem carbon, %d (Mg C/ha)", y1), sub = sprintf("%.1f Tg C", tot(v1))),
      list(k = classed(dv, dbrk), cols = RAMP_CHG(length(dbrk) - 1), lab = dlab, title = sprintf("Change, %d-%d (Mg C/ha)", y0, y1), sub = sprintf("%+.1f Tg C; brown loss, green gain", tot(v1) - tot(v0)))),
      sprintf("Total ecosystem carbon (all 14 CBM pools) in the first and last year of the run and the change between them; (a) and (b) share one scale, running to the 99.5th percentile.%s", relief)) }

  # ---- charts: land area by cover group --------------------------------------------------------------------------------------
  ar <- copy(X$area); ar[, Group := cover_group(Class)]; ag <- ar[, .(km2 = sum(ha) / 100), by = .(Timestep, Group)]
  gr <- names(COVER_COLS)[names(COVER_COLS) %in% ag$Group]; yy <- sort(unique(ag$Timestep))
  M <- sapply(gr, function(g) ag[Group == g][match(yy, Timestep), km2]); M[is.na(M)] <- 0
  chart_figure("land_area", "Land area by cover group", sprintf("(a) Area of each land cover group, %d-%d. (b) Its change since %d.", y0, y1, y0), 1, 2, h = 1150, draw = function() {
    low(); cs <- t(apply(M, 1, cumsum)); plot(NA, xlim = range(yy), ylim = c(0, max(cs) * 1.02), xlab = "", ylab = "Area (km2)", bty = "l", yaxt = "n")
    axis(2, at = axTicks(2), labels = format(axTicks(2), big.mark = ",", scientific = FALSE)); hgrid()
    for (j in rev(seq_along(gr))) polygon(c(yy, rev(yy)), c(cs[, j], rev(if (j > 1) cs[, j - 1] else rep(0, length(yy)))), col = COVER_COLS[gr[j]], border = NA); mark_line()
    ptitle(1, "Area by cover group"); under_legend(gr, fill = COVER_COLS[gr])
    low(); D <- sweep(M, 2, M[1, ]); plot(NA, xlim = range(yy), ylim = range(D), xlab = "", ylab = sprintf("Change since %d (km2)", y0), bty = "l"); hgrid(); abline(h = 0, col = MUTED, lty = 2)
    for (g in gr) lines(yy, D[, g], col = COVER_COLS[g], lwd = 2); mark_line(); ptitle(2, sprintf("Change since %d", y0)); under_legend(gr, col = COVER_COLS[gr], lwd = 2) })

  # ---- charts: transitions, simulated and recorded ---------------------------------------------------------------------------
  tr <- X$trans[TransitionGroup %in% FAMILIES, .(km2 = sum(ha) / 100), by = .(Timestep, Family = TransitionGroup)]
  fams <- FAMILIES[FAMILIES %in% tr$Family]
  if (length(fams)) {
    ob <- if (!is.null(observed) && nrow(observed)) { o <- copy(observed); o[, Family := sub(":.*$", "", trimws(sub(" \\[Type\\]$", "", TransitionGroup)))]; o[Family %in% fams, .(km2 = sum(Area)), by = .(Timestep, Family)] } else NULL
    nc <- min(3, length(fams)); nr <- ceiling(length(fams) / nc); yrs <- (y0 + 1):y1
    chart_figure("transitions", "Transitions per year", sprintf("Area of each transition family per year in the run (bars)%s%s.", if (is.null(ps)) "" else sprintf("; titles give the area simulated to %d + the area projected after it, and the record (to %d) in brackets", ps, ps), if (is.null(ob)) "" else ", and in the Build's historical record (points; the Build's transition summary, which double counted urbanization and intensification in Builds run before 24 October 2026: rerun stage 6)"),
      nr, nc, draw = function() for (i in seq_along(fams)) { s <- tr[Family == fams[i]][match(yrs, Timestep), km2]; s[is.na(s)] <- 0
        o <- if (!is.null(ob)) ob[Family == fams[i]][match(yrs, Timestep), km2] else NULL
        top <- max(c(s, o), 0.01, na.rm = TRUE) * 1.1
        b <- barplot(s, col = "#8da9c4", border = NA, space = .15, ylim = c(0, top), ylab = "km2 per year"); hgrid(); barplot(s, col = "#8da9c4", border = NA, space = .15, add = TRUE, axes = FALSE)
        at <- which(yrs %% 5 == 0); axis(1, at = b[at], labels = yrs[at], cex.axis = .75)
        if (!is.null(o)) points(b, o, pch = 16, cex = .6, col = INK); mark_bar(b, yrs)
        ptitle(i, if (is.null(ps)) sprintf("%s: %.0f km2 simulated%s", fams[i], sum(s), if (!is.null(o)) sprintf(", %.0f recorded", sum(o, na.rm = TRUE)) else "") else
          sprintf("%s: %.0f + %.0f km2%s", fams[i], sum(s[yrs <= ps]), sum(s[yrs > ps]), if (!is.null(o)) sprintf(" (%.0f recorded)", sum(o, na.rm = TRUE)) else "")) }) }

  # ---- charts: carbon stocks -------------------------------------------------------------------------------------------------
  if (!is.null(X$stocks) && nrow(X$stocks)) {
    st <- X$stocks[, .(Tg = sum(Mg) / 1e6), by = .(Timestep, StockGroup)]; yy <- sort(unique(st$Timestep))
    pools <- c(`Live biomass` = "Biomass: Total", `Dead wood` = "DOM: Deadwood", Litter = "DOM: Litter", Soil = "DOM: Soil")
    pc <- c(`Live biomass` = "#2b8152", `Dead wood` = "#a6611a", Litter = "#dfc27d", Soil = "#5a3a1c")
    M <- sapply(pools, function(g) st[StockGroup == g][match(yy, Timestep), Tg]); M[is.na(M)] <- 0; colnames(M) <- names(pools)
    te <- st[StockGroup == "Total Ecosystem"][match(yy, Timestep), Tg]
    chart_figure("carbon_stocks", "Carbon stocks", sprintf("(a) Carbon by pool, %d-%d. (b) The year-to-year change in total ecosystem carbon: the net ecosystem carbon balance, gain above zero.", y0, y1), 1, 2, h = 1150, draw = function() {
      low(); cs <- t(apply(M, 1, cumsum)); plot(NA, xlim = range(yy), ylim = c(0, max(cs, te, na.rm = TRUE) * 1.05), xlab = "", ylab = "Tg C", bty = "l"); hgrid()
      for (j in rev(seq_len(ncol(M)))) polygon(c(yy, rev(yy)), c(cs[, j], rev(if (j > 1) cs[, j - 1] else rep(0, length(yy)))), col = pc[j], border = NA)
      if (!is.null(X$te_it) && !is.null(ps)) { r <- X$te_it[Timestep >= ps, .(lo = min(Tg), hi = max(Tg)), by = Timestep][order(Timestep)]
        polygon(c(r$Timestep, rev(r$Timestep)), c(r$lo, rev(r$hi)), col = adjustcolor(INK, .18), border = NA) }   # Monte Carlo range of the projection
      lines(yy, te, lwd = 2, col = INK); mark_line(); ptitle(1, sprintf("Carbon stocks: %.0f to %.0f Tg C", te[1], te[length(te)])); under_legend(c(names(pc), "Total"), fill = c(pc, NA), lty = c(rep(NA, 4), 1), col = c(rep(NA, 4), INK))
      low(); d <- diff(te); b <- barplot(d, col = ifelse(d >= 0, "#2b8152", "#a81d1a"), border = NA, ylab = "Tg C per year"); hgrid(); abline(h = 0, col = MUTED)
      at <- which(yy[-1] %% 5 == 0); axis(1, at = b[at], labels = yy[-1][at], cex.axis = .75); mark_bar(b, yy[-1]); ptitle(2, sprintf("Net ecosystem carbon balance (mean %+.2f Tg C/yr)", mean(d))) }) }

  # ---- carbon against the carrying capacity (the Build's Carbon Capacity maps; src/capacity.R; user 2026-11-18) -----------------
  # X$cap: capacity_maps() of the Build result, set by the stage. (a) the run's live biomass, dead wood and litter against the capacity
  # (the natural-regime mean) and its upper bound (old growth); (b) the stock as a share of the capacity; (c) the deficit by cause in
  # the first and last year, from the run's maps (when it wrote them); and maps of the capacity, the last year's stock and the difference
  C <- X$cap; cs <- if (!is.null(C) && exists("capacity_series", mode = "function")) capacity_series(X$stocks, C$total, C$upper_total) else NULL
  if (!is.null(cs)) {
    c0y <- capacity_year(C, X$sc0, X$hl0, scn); c1y <- capacity_year(C, X$sc1, X$hl1, scn); has_split <- !is.null(c0y) && !is.null(c1y)
    pools <- c(`Live biomass` = "Biomass: Total", `Dead wood` = "DOM: Deadwood", Litter = "DOM: Litter"); pc <- c(`Live biomass` = "#2b8152", `Dead wood` = "#a6611a", Litter = "#dfc27d")
    stc <- X$stocks[, .(Tg = sum(Mg) / 1e6), by = .(Timestep, StockGroup)]; yy <- cs$Timestep
    M <- sapply(pools, function(g) stc[StockGroup == g][match(yy, Timestep), Tg]); M[is.na(M)] <- 0; n1 <- nrow(cs); has_up <- !is.na(C$upper_total)
    chart_figure("carbon_capacity", "Carbon against the carrying capacity", paste0(
      "The carrying capacity is what the land would hold in live biomass, dead wood and litter under its potential natural vegetation and natural fire regime: for forest, the mean stock of a landscape of the type ",
      "burning at its natural stand-replacing fire return interval (LANDFIRE), from the Build's own stock curves; land that is forest keeps its type, natural grassland and shrubland their class (unless Carbon Capacity Options says otherwise), and LANDFIRE Biophysical Settings say what developed and farmed ",
      "land would carry. Soil is not counted. It is fixed at the Build's historical climate. ",
      sprintf("(a) The run's stock of the three pools against the capacity%s. (b) The stock as a share of the capacity; above 100%% the land holds more than its natural regime would keep (fire exclusion, for one). ", if (has_up) " and its upper bound, the same land at the old-growth end of its curves" else ""),
      if (has_split) sprintf("(c) The deficit (capacity less stock) by cause in %d and %d, from the run's maps: developed and farmed land; disturbed land waiting to return to its cover; and, on land in its potential cover, live biomass (for forest, stands younger or older than the natural regime's mean age; a cell's stocking is in its capacity) apart from dead wood and litter (which also follow stand age: a landscape under its natural regime holds recently burned stands, rich in dead wood, and old ones; and, in part, the disturbance the Build starts each stand after, Carbon Assumptions: Spin-up). A cause's value is net of land above its capacity; and natural grassland, shrubland and barren land whose capacity is mostly forest (forest at the start that has since converted and, when Carbon Capacity Options counts it so, land LANDFIRE BpS maps as forest potential).", y0, y1) else ""),
      1, if (has_split) 3 else 2, h = 1150, draw = function() {
        low(); cum <- t(apply(M, 1, cumsum)); top <- max(cum, cs$Capacity, if (has_up) cs$UpperBound, na.rm = TRUE) * 1.06
        plot(NA, xlim = range(yy), ylim = c(0, top), xlab = "", ylab = "Tg C", bty = "l"); hgrid()
        for (j in rev(seq_len(ncol(M)))) polygon(c(yy, rev(yy)), c(cum[, j], rev(if (j > 1) cum[, j - 1] else rep(0, length(yy)))), col = pc[j], border = NA)
        abline(h = C$total, lwd = 2, col = INK); if (has_up) abline(h = C$upper_total, lty = 2, col = MUTED); mark_line()
        ptitle(1, sprintf("Stock %.0f of %.0f Tg C capacity in %d", cs$Stock[n1], C$total, y1))
        under_legend(c(names(pc), "Carrying capacity", if (has_up) "Upper bound (old growth)"), fill = c(pc, NA, if (has_up) NA), lty = c(rep(NA, 3), 1, if (has_up) 2), col = c(rep(NA, 3), INK, if (has_up) MUTED))
        low(); plot(NA, xlim = range(yy), ylim = range(c(cs$RealisedShare, 100)) + c(-3, 3), xlab = "", ylab = "% of the carrying capacity", bty = "l"); hgrid(); abline(h = 100, col = MUTED, lty = 2)
        lines(yy, cs$RealisedShare, lwd = 2, col = "#2b8152"); mark_line(); ptitle(2, sprintf("Share of the capacity: %.0f%% in %d, %.0f%% in %d", cs$RealisedShare[1], y0, cs$RealisedShare[n1], y1))
        if (has_split) { low(); S <- rbind(c0y$split, c1y$split); S <- S[, colSums(abs(S)) > 1e-9, drop = FALSE]; colnames(S) <- CAPACITY_CAUSE_LABELS[match(colnames(S), CAPACITY_CAUSES)]; bc <- c("#b9b4a6", "#8c6d31")
          b <- barplot(S, beside = TRUE, col = bc, border = NA, ylim = range(c(0, S)) * 1.15, ylab = "Tg C below the capacity", cex.names = .75); hgrid(); abline(h = 0, col = MUTED)
          barplot(S, beside = TRUE, col = bc, border = NA, add = TRUE, axes = FALSE, names.arg = rep("", ncol(S)))
          ptitle(3, sprintf("Deficit by cause: %.0f Tg C in %d, %.0f in %d", sum(S[1, ]), y0, sum(S[2, ]), y1)); under_legend(c(as.character(y0), as.character(y1)), fill = bc) } })
    if (!is.null(c1y)) {
      rc <- C$grid; rs <- setValues(rast(C$grid), c1y$stock); vc <- cv(rc); vs1 <- cv(rs); s <- steps(c(vc, vs1)); dv <- vs1 - vc
      m <- unname(quantile(abs(dv[inz]), 0.99, na.rm = TRUE)); m <- if (is.finite(m) && m > 0) m else 1; b <- unique(signif(m * c(-1, -.5, -.2, -.05, .05, .2, .5, 1), 1))
      dbrk <- c(-Inf, b, Inf); fm <- function(x) format(x, trim = TRUE)
      dlab <- c(paste0("<", fm(b[1])), ifelse(abs(b[-length(b)] + b[-1]) < 1e-9, paste0("±", fm(b[-1])), fm(b[-length(b)])), paste0(">", fm(b[length(b)])))
      tot <- function(v) sum(v[inz], na.rm = TRUE) * prod(res(el)) / 1e4 / 1e6
      map_figure("carbon_capacity_map", sprintf("Carbon against the carrying capacity, %d", y1), list(
        list(k = classed(vc, s$brk), cols = RAMP_C(length(s$brk) - 1), lab = s$lab, title = "Carrying capacity (Mg C/ha)", sub = sprintf("%.1f Tg C; live biomass, dead wood and litter", C$total)),
        list(k = classed(vs1, s$brk), cols = RAMP_C(length(s$brk) - 1), lab = s$lab, title = sprintf("Stock of the same pools, %d (Mg C/ha)", y1), sub = sprintf("%.1f Tg C", tot(vs1))),
        list(k = classed(dv, dbrk), cols = RAMP_CHG(length(dbrk) - 1), lab = dlab, title = sprintf("Stock less capacity, %d (Mg C/ha)", y1), sub = "brown below the capacity, green above")),
        sprintf("(a) The carbon carrying capacity: live biomass, dead wood and litter under each cell's potential natural vegetation and natural fire regime (the Build's Carbon Capacity map). (b) The run's stock of those pools in its last year (the average over its iterations). (c) The difference; a forest cell older than its regime's mean stands above its capacity, a young or cleared one below. (a) and (b) share one scale.%s", relief)) } }

  # ---- charts: carbon fluxes -------------------------------------------------------------------------------------------------
  # (a) productivity and respiration; (b) losses by cause and NBP; (c) emissions to the atmosphere by driver; (d) carbon carried off the
  # land; (e) the mean balance, NPP to NBP; (f) NBP by the land cover it came from (user, 2026-11-10: "include a couple more plots ...
  # to expand on the sources and types of the carbon losses")
  if (!is.null(X$flows) && nrow(X$flows)) {
    fl <- X$flows[, .(Tg = sum(Mg) / 1e6), by = .(Timestep, FlowGroup)]; yy <- sort(unique(fl$Timestep))
    g <- function(nm) { v <- fl[FlowGroup == nm][match(yy, Timestep), Tg]; v[is.na(v)] <- 0; v }
    LO <- if (!is.null(X$losses) && nrow(X$losses)) X$losses else NULL
    # a matrix of yearly series (rows: the keys present, in order; Tg C) from a table with Timestep, a key column and Mg
    ymat <- function(d, key, keys) { keys <- keys[keys %in% d[[key]]]; m <- matrix(0, length(keys), length(yy), dimnames = list(keys, NULL))
      for (k in keys) { s <- d[d[[key]] == k, .(Tg = sum(Mg) / 1e6), by = Timestep]; v <- s[match(yy, Timestep), Tg]; v[is.na(v)] <- 0; m[k, ] <- v }; m }
    B_GROUPS <- c("LULC: Emission", "LULC: Harvest", "Harvest: Agriculture", "Emission: Drained Organic Soil -> Atmosphere [Type]")   # (b): what NBP subtracts, and drained peat
    Lb <- if (is.null(LO)) NULL else ymat(LO[FlowGroup %in% B_GROUPS], "Cause", names(LOSS_COLS))
    E <- if (is.null(LO)) NULL else {
      e <- LO[FlowGroup == "LULC: Emission"][, Driver := emis_driver(TransitionType)]
      e <- rbind(e, LO[FlowGroup == "LULC: Emission Peat"][, Driver := "Fire: peat"], LO[grepl("^Emission: Drained", FlowGroup)][, Driver := "Drained peat"])
      m <- ymat(e, "Driver", c("Fire", names(EMIS_COLS)))
      if ("Fire" %in% rownames(m)) { pe <- if ("Fire: peat" %in% rownames(m)) m["Fire: peat", ] else 0
        m <- rbind(`Fire: vegetation` = m["Fire", ] - pe, m[rownames(m) != "Fire", , drop = FALSE]) }
      m[names(EMIS_COLS)[names(EMIS_COLS) %in% rownames(m)], , drop = FALSE] }
    R <- if (is.null(LO)) NULL else {
      r <- LO[FlowGroup %in% c("LULC: Harvest", "Harvest: Agriculture", "Lateral Flux")]
      r[, Kind := fcase(FlowGroup == "Harvest: Agriculture", "Crop harvest", FlowGroup == "Lateral Flux", "Lateral export (water)", Cause == "Forest harvest", "Forest harvest wood",
                        default = "Wood from land use change")]
      ymat(r, "Kind", names(REM_COLS)) }
    stack_bars <- function(M, cols, ylab, line = NULL) { M <- M[rowSums(abs(M)) > 0, , drop = FALSE]; cols <- cols[rownames(M)]
      yl <- range(c(0, colSums(pmax(M, 0)), colSums(pmin(M, 0)), line)) * 1.1
      b <- barplot(pmax(M, 0), col = cols, border = NA, ylim = yl, ylab = ylab); hgrid(); abline(h = 0, col = MUTED)
      barplot(pmax(M, 0), col = cols, border = NA, add = TRUE, axes = FALSE); if (any(M < 0)) barplot(pmin(M, 0), col = cols, border = NA, add = TRUE, axes = FALSE)
      if (!is.null(line)) lines(b, line, lwd = 2, col = "#3b6ea8")
      at <- which(yy %% 5 == 0); axis(1, at = b[at], labels = yy[at], cex.axis = .75); mark_bar(b, yy); list(b = b, M = M, cols = cols) }
    legend_means <- function(M, cols, extra = NULL) { lab <- sprintf("%s (%.3g)", rownames(M), rowMeans(M))
      if (length(extra)) under_legend(c(lab, extra), fill = c(cols, NA), lty = c(rep(NA, nrow(M)), 1), col = c(rep(NA, nrow(M)), "#3b6ea8")) else under_legend(lab, fill = cols) }
    nbp <- g("Net Biome Productivity")
    cap <- paste("(a) Net primary productivity, heterotrophic respiration and net ecosystem productivity.",
      "(b) Carbon lost each year by cause: what each transition emits and removes (fire, including peat; insects; forest harvest, its wood and slash; land use change, mostly the emissions",
      "and wood of urbanization and agricultural expansion), crop harvest (carried off the field each year and mostly respired off site within the year) and drained peat (oxidized under",
      "cropland and pasture; part of heterotrophic respiration); net biome productivity, the change in ecosystem carbon, is net ecosystem productivity less the transitions' losses and crop harvest.",
      "(c) Carbon emitted to the atmosphere by the transitions and drained peat, by driver (fire split into vegetation and peat). (d) Carbon carried off the land: wood from forest harvest and",
      "land use change (to the Forestry Sector), crop harvest (to the Agriculture Sector) and wetland carbon carried away by water (to Aquatic).",
      "(e) The mean carbon balance: net primary productivity less decomposition and lateral export is net ecosystem productivity, less the losses of (b) is net biome productivity.",
      "(f) Net biome productivity by the land cover it came from (a transition's losses count to the class the land left). Legends give each series' mean, Tg C per year.")
    chart_figure("carbon_fluxes", "Carbon fluxes", cap, 3, 2, h = 3300, draw = function() {
      # (a)
      low(); a <- cbind(NPP = g("Net Primary Productivity"), Rh = g("Emission: Total Rh"), NEP = g("Net Ecosystem Productivity"))
      plot(NA, xlim = range(yy), ylim = range(c(0, a)), xlab = "", ylab = "Tg C per year", bty = "l"); hgrid(); abline(h = 0, col = MUTED, lty = 2)
      fc <- c(NPP = "#2b8152", Rh = "#a6611a", NEP = "#3b6ea8"); for (k in colnames(a)) lines(yy, a[, k], col = fc[k], lwd = 2); mark_line()
      ptitle(1, "Productivity and respiration"); under_legend(c("Net primary productivity", "Heterotrophic respiration", "Net ecosystem productivity"), col = fc, lwd = 2)
      # (b)
      low(); has_b <- !is.null(Lb) && nrow(Lb) > 0
      L <- if (has_b) Lb else rbind(`Transition emissions` = g("LULC: Emission"), Harvest = g("LULC: Harvest"))   # a run read without the losses table
      lcol <- if (has_b) LOSS_COLS[rownames(L)] else c("#c93a1d", "#6b6b6b")
      b <- barplot(-L, col = lcol, border = NA, ylim = range(c(-colSums(L), nbp, 0)) * 1.1, ylab = "Tg C per year"); hgrid(); abline(h = 0, col = MUTED)
      lines(b, nbp, lwd = 2, col = "#3b6ea8"); at <- which(yy %% 5 == 0); axis(1, at = b[at], labels = yy[at], cex.axis = .75); mark_bar(b, yy)
      ptitle(2, sprintf("Losses by cause and net biome productivity (mean %+.3g Tg C/yr)", mean(nbp))); legend_means(L, lcol, "Net biome productivity")
      # (c)
      low()
      if (!is.null(E) && nrow(E)) { s <- stack_bars(E, EMIS_COLS, "Tg C emitted per year"); ptitle(3, sprintf("Emissions to the atmosphere by driver (mean %.3g Tg C/yr)", sum(rowMeans(s$M)))); legend_means(s$M, s$cols)
      } else { plot.new(); ptitle(3, "Emissions by driver: not in this run's output") }
      # (d)
      low()
      if (!is.null(R) && nrow(R)) { s <- stack_bars(R, REM_COLS, "Tg C carried off per year"); ptitle(4, sprintf("Carbon carried off the land (mean %.3g Tg C/yr)", sum(rowMeans(s$M)))); legend_means(s$M, s$cols)
      } else { plot.new(); ptitle(4, "Carbon carried off the land: not in this run's output") }
      # (e) the balance, as a waterfall of means
      par(mar = c(10, 5, 3, 1))
      lat <- if (!is.null(R) && "Lateral export (water)" %in% rownames(R)) mean(R["Lateral export (water)", ]) else 0
      st <- c(`Net primary productivity` = mean(g("Net Primary Productivity")), Decomposition = -mean(g("Emission: Total Rh")), `Lateral export` = -lat)
      nep <- mean(g("Net Ecosystem Productivity")); oth <- nep - sum(st); if (abs(oth) > 1e-6 * max(abs(st))) st <- c(st, Other = oth)
      lm <- if (has_b) rowMeans(Lb[rownames(Lb) != "Drained peat", , drop = FALSE]) else c(Losses = mean(g("LULC: Emission") + g("LULC: Harvest")))
      steps <- c(st, `Net ecosystem productivity` = NA, -lm, `Net biome productivity` = NA); tot <- is.na(steps)
      run <- 0; lo <- hi <- numeric(length(steps)); lvl <- numeric(length(steps))
      for (i in seq_along(steps)) { if (tot[i]) { steps[i] <- run; lo[i] <- min(0, run); hi[i] <- max(0, run) } else { lo[i] <- min(run, run + steps[i]); hi[i] <- max(run, run + steps[i]); run <- run + steps[i] }; lvl[i] <- run }
      wcol <- ifelse(tot, "#3b6ea8", ifelse(steps > 0, "#2b8152", ifelse(names(steps) %in% names(LOSS_COLS), LOSS_COLS[names(steps)], "#a6611a")))
      plot(NA, xlim = c(.5, length(steps) + .5), ylim = range(c(0, lo, hi)) * 1.15, xaxt = "n", xlab = "", ylab = "Tg C per year (mean)", bty = "l"); hgrid(); abline(h = 0, col = MUTED)
      rect(seq_along(steps) - .38, lo, seq_along(steps) + .38, hi, col = wcol, border = NA)
      segments(seq_len(length(steps) - 1) + .38, lvl[-length(lvl)], seq_len(length(steps) - 1) + 1 - .38, lvl[-length(lvl)], col = MUTED, lty = 3)
      text(seq_along(steps), hi + diff(par("usr")[3:4]) * .02, sprintf("%+.3g", steps), cex = .65, adj = c(.5, 0), col = INK)
      axis(1, at = seq_along(steps), labels = names(steps), las = 2, cex.axis = .7, tick = FALSE)
      ptitle(5, sprintf("Mean carbon balance, %d-%d", yy[1], yy[length(yy)]))
      # (f) NBP by land cover
      low()
      if (!is.null(X$nbp_cls) && nrow(X$nbp_cls)) { nc <- copy(X$nbp_cls)[, Group := balance_group(Class)]
        s <- stack_bars(ymat(nc, "Group", names(BAL_COLS)), BAL_COLS, "Tg C per year", line = nbp)
        ptitle(6, "Net biome productivity by land cover"); legend_means(s$M, s$cols, "Net biome productivity")
      } else { plot.new(); ptitle(6, "Net biome productivity by land cover: not in this run's output") } }) }

  # ---- charts: wetland methane (lucasCore 1.5; drawn when the run's wetlands released any) -----------------------------------
  # (a) carbon released as methane each year by the kind of wetland; (b) net biome productivity as CO2, and with that methane counted
  # at its CO2 equivalent instead of as CO2. Methane is part of heterotrophic respiration, so (a) is already inside NEP and NBP.
  M4 <- X$ch4
  if (!is.null(M4) && nrow(M4) && !is.null(X$flows) && nrow(X$flows) && M4[FlowGroup == "Emission: Wetland CH4", sum(Mg)] > 0) {
    y4 <- sort(unique(X$flows$Timestep)); ser <- function(d) { s <- d[, .(v = sum(Mg)), by = Timestep]; v <- s[match(y4, Timestep), v]; v[is.na(v)] <- 0; v }
    c4 <- M4[FlowGroup == "Emission: Wetland CH4"][, Kind := methane_kind(Class)]; kinds <- names(CH4_COLS)[names(CH4_COLS) %in% c4$Kind]
    Mk <- do.call(rbind, lapply(kinds, function(k) ser(c4[Kind == k]) / 1e3)); rownames(Mk) <- kinds   # Gg C as CH4 per year
    tot <- colSums(Mk) / 1e3; e4 <- ser(M4[FlowGroup == "Emission: Wetland CH4 (CO2e)"]) / 1e6          # Tg C; Tg CO2e
    wgt <- if (sum(tot) > 0 && sum(e4) > 0) sum(e4) / sum(tot) else NA_real_                               # CO2e per unit of methane carbon, as the run counted it
    extra <- e4 - 3.67 * tot                                                                                 # what methane adds over the same carbon as CO2
    nb <- ser(X$flows[FlowGroup == "Net Biome Productivity"]) / 1e6 * 3.67; rh <- ser(X$flows[FlowGroup == "Emission: Total Rh"]) / 1e6
    chart_figure("wetland_methane", "Wetland methane", paste0(
      "(a) Carbon released to the atmosphere as methane by wetland soil and litter each year, by the kind of wetland, in thousand tonnes of carbon (Gg C). It is part of heterotrophic respiration ",
      sprintf("(%.2g%% of it over the run), so it is already inside net ecosystem and net biome productivity. ", 100 * sum(tot) / sum(rh)),
      if (is.na(wgt)) "(b) Net biome productivity as CO2 (carbon x 3.67); this run has no CO2 equivalent for its methane. " else
        sprintf("(b) Net biome productivity as CO2 (carbon x 3.67), and with wetland methane counted at its CO2 equivalent (%.3g per unit of methane carbon) instead of as CO2; the bars are the difference. ", wgt),
      "Positive is uptake by the land. Legends give each series' mean per year."), 1, 2, h = 1150, draw = function() {
        low(); Ms <- Mk[rowSums(Mk) > 0, , drop = FALSE]; cs <- CH4_COLS[rownames(Ms)]
        b <- barplot(Ms, col = cs, border = NA, ylim = c(0, max(colSums(Ms)) * 1.1), ylab = "Gg C as CH4 per year"); hgrid(); barplot(Ms, col = cs, border = NA, add = TRUE, axes = FALSE)
        at <- which(y4 %% 5 == 0); axis(1, at = b[at], labels = y4[at], cex.axis = .75); mark_bar(b, y4)
        ptitle(1, sprintf("Methane from wetlands (mean %.3g Gg C/yr)", mean(colSums(Ms)))); under_legend(sprintf("%s (%.3g)", rownames(Ms), rowMeans(Ms)), fill = cs)
        low(); wm <- nb - extra
        plot(NA, xlim = range(y4) + c(-.6, .6), ylim = range(c(0, nb, wm, -extra)) * 1.08, xlab = "", ylab = "Tg CO2e per year", bty = "l"); hgrid(); abline(h = 0, col = MUTED, lty = 2)
        rect(y4 - .4, 0, y4 + .4, -extra, col = "#a0468c", border = NA)
        lines(y4, nb, col = "#3b6ea8", lwd = 2); lines(y4, wm, col = "#6a3d9a", lwd = 2); mark_line()
        ptitle(2, sprintf("NBP with methane as CO2e (mean %+.3g Tg CO2e/yr)", mean(wm)))
        under_legend(c(sprintf("NBP as CO2 (%+.3g)", mean(nb)), sprintf("Methane beyond its carbon as CO2 (%+.3g)", -mean(extra)), sprintf("NBP with methane as CO2e (%+.3g)", mean(wm))),
                     col = c("#3b6ea8", NA, "#6a3d9a"), lwd = c(2, NA, 2), fill = c(NA, "#a0468c", NA)) }) }

  # ---- charts: harvested wood products (stage 18's result on this run, when there is one) ------------------------------------
  # (a) carbon stored in products in use and in landfills and dumps, with the interval of the total; (b) NBP with and without the
  # change in that store (the production approach)
  ws <- wp_tg(X, "Stored"); wn <- nbp_products(X)
  if (nrow(ws) && nrow(wn)) {
    wu <- wp_tg(X, c("InUse", "Recovered"))[match(ws$Timestep, Timestep)]; wl <- wp_tg(X, c("Landfill", "Dump"))[match(ws$Timestep, Timestep)]
    ivl <- if (any(ws$Upper > ws$Lower)) "the shading the interval over the parameter draws" else "the published parameters (no draws)"
    chart_figure("wood_products", "Harvested wood products", paste0(sprintf("Stage 18 (Wood Products, result %d) on this run, the USFS harvested wood products model (production approach). ", attr(X$wp, "scenario")),
      "(a) Carbon stored in harvested wood products: in use (products in use and recovered for reuse) and in landfills and dumps, including what was harvested before the run and is still stored; ",
      sprintf("the dashed lines the interval of the total. (b) Net biome productivity of the ecosystem (harvest counted as a loss) and with the change in carbon stored in products added (%s). Means in Tg C per year.", ivl)),
      1, 2, h = 1150, draw = function() {
        low(); yy <- ws$Timestep; u <- wu$Tg; l <- wl$Tg; u[is.na(u)] <- 0; l[is.na(l)] <- 0
        plot(NA, xlim = range(yy), ylim = c(0, max(ws$Upper, u + l, na.rm = TRUE) * 1.05), xlab = "", ylab = "Tg C", bty = "l"); hgrid()
        polygon(c(yy, rev(yy)), c(rep(0, length(yy)), rev(l)), col = "#8c6d31", border = NA)
        polygon(c(yy, rev(yy)), c(l, rev(l + u)), col = "#d9a441", border = NA)
        if (any(ws$Upper > ws$Lower)) { lines(yy, ws$Lower, lty = 2, col = INK); lines(yy, ws$Upper, lty = 2, col = INK) }
        mark_line(); n1 <- nrow(ws)
        ptitle(1, sprintf("Carbon stored in products, %d: %.3g Tg C (%.3g-%.3g)", yy[n1], ws$Tg[n1], ws$Lower[n1], ws$Upper[n1]))
        under_legend(c("In use", "Landfills and dumps"), fill = c("#d9a441", "#8c6d31"))
        low(); yy <- wn$Timestep; dw <- wn$Tg - wn$NBP   # the change in carbon stored in products, as bars on the zero line
        plot(NA, xlim = range(yy), ylim = range(c(0, wn$NBP, wn$Lower, wn$Upper, dw)) * 1.05, xlab = "", ylab = "Tg C per year", bty = "l"); hgrid(); abline(h = 0, col = MUTED, lty = 2)
        rect(yy - .4, 0, yy + .4, dw, col = "#d9a441", border = NA)
        if (any(wn$Upper > wn$Lower)) polygon(c(yy, rev(yy)), c(wn$Lower, rev(wn$Upper)), col = adjustcolor("#2b8152", .25), border = NA)
        lines(yy, wn$NBP, col = "#3b6ea8", lwd = 2); lines(yy, wn$Tg, col = "#2b8152", lwd = 2); mark_line()
        ptitle(2, sprintf("NBP with wood products (mean %+.3g Tg C/yr)", mean(wn$Tg)))
        under_legend(c(sprintf("Ecosystem NBP (%+.3g)", mean(wn$NBP)), sprintf("Change in products (%+.3g)", mean(dw)), sprintf("NBP with products (%+.3g)", mean(wn$Tg))),
                     col = c("#3b6ea8", NA, "#2b8152"), lwd = c(2, NA, 2), fill = c(NA, "#d9a441", NA)) }) }

  # ---- charts: carbon by secondary stratum -----------------------------------------------------------------------------------
  if (!is.null(X$unit_c) && nrow(X$unit_c) > 1 && uniqueN(X$unit_c$Unit) > 1) {
    u <- dcast(X$unit_c, Unit ~ Timestep, value.var = "Mg"); setnames(u, c("Unit", "c0", "c1")); u <- merge(u, X$unit_a, by = "Unit")
    u[, `:=`(name = sub("^[^:]*: ", "", Unit), d0 = c0 / ha, d1 = c1 / ha, chg = (c1 - c0) / ha, Tg1 = c1 / 1e6)]; u <- u[order(chg)]
    chart_figure("carbon_by_unit", "Carbon by secondary stratum", sprintf("(a) Change in mean total ecosystem carbon density, %d-%d, by secondary stratum. (b) Total ecosystem carbon in %d.", y0, y1, y1),
      1, 2, h = max(960, 300 + 60 * nrow(u)), draw = function() {   # at least one chart row's height: 2 units (Great Dismal Swamp, 2026-11-10) left 420 px, less than the margins
        par(mar = c(4.5, 12, 3, 1)); barplot(u$chg, names.arg = u$name, horiz = TRUE, col = ifelse(u$chg >= 0, "#2b8152", "#a81d1a"), border = NA, cex.names = .7, xlab = "Mg C/ha")
        abline(v = 0, col = MUTED); ptitle(1, sprintf("Change in carbon density, %d-%d", y0, y1))
        o <- order(u$Tg1); barplot(u$Tg1[o], names.arg = u$name[o], horiz = TRUE, col = "#2b8152", border = NA, cex.names = .7, xlab = "Tg C")
        ptitle(2, sprintf("Total ecosystem carbon, %d", y1)) }) }

  rbindlist(K$rows) }
