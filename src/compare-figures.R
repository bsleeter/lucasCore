# =============================================================================
# compare-figures.R - figures that compare ST-Sim runs on one lucasCore Build (projections under different climate futures, a
# historical run and its projections, ...); sourced by stage 14 (src/14-compare-runs.R), and testable outside a run
# (dev/figures/test_compare_figures.R)
# =============================================================================
# Same format as the Build and run figures (src/figures.R, figure_kit), one line or bar colour per run:
#   charts  total ecosystem carbon and each run's difference from the baseline | carbon fluxes per year | harvested wood products and
#           NBP with them (runs with a stage 18 result) | flux means by period |
#           transitions per year | carbon by pool | land area change by cover group | a carbon summary table | a land change summary table
#   maps    the baseline's final-year total ecosystem carbon and each other run's difference from it
# compare_runs(lib, runs) reads the runs (src/run-figures.R's load_run): runs is a data.table of RunScenarioId and, optionally,
# Label, Colour ("#rrggbb", or SyncroSim's "a,r,g,b") and Baseline. A run that is the historical run of another listed run (its
# Projection Setup's Projection Start) is the history: drawn in black up to the year its projections start from, and added when a
# listed projection has one that is not listed. The baseline is the run ticked Baseline, else the first run that is not a history.
# compare_figures() returns one row per PNG (Figure, Title, Caption, FileName), with the two summary tables as its attributes "carbon"
# (compare_carbon) and "land" (compare_land).
# =============================================================================

COMPARE_PAL <- c("#4e79a7", "#f28e2b", "#e15759", "#59a14f", "#b07aa1", "#76b7b2", "#edc948", "#9c755f")

compare_runs <- function(lib, runs) {
  runs <- as.data.table(runs)
  for (k in c("Label", "Colour")) if (!k %in% names(runs)) runs[, (k) := NA_character_]
  if (!"Baseline" %in% names(runs)) runs[, Baseline := FALSE]
  runs <- runs[!is.na(RunScenarioId)][!duplicated(RunScenarioId)]
  if (!nrow(runs)) stop("no runs listed")
  hid <- vapply(runs$RunScenarioId, function(r) find_history(lib, r), NA_integer_)
  add <- setdiff(unique(na.omit(hid)), runs$RunScenarioId)
  if (length(add)) runs <- rbind(data.table(RunScenarioId = add, Label = NA_character_, Colour = NA_character_, Baseline = FALSE), runs, fill = TRUE)
  ids <- runs$RunScenarioId; hist <- ids %in% hid
  if (all(hist)) stop("every run listed is the historical run of another: list at least one projection")
  b <- which(!hist & runs$Baseline %in% c(TRUE, 1, -1)); b <- if (length(b)) b[1] else which(!hist)[1]
  con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); on.exit(dbDisconnect(con))
  nm <- function(r) { n <- dbGetQuery(con, sprintf("SELECT Name FROM core_Scenario WHERE ScenarioId = %d", r))$Name
    if (!length(n)) sprintf("Result %d", r) else sub("^[^-]* - ", "", sub(" \\(\\[.*$", "", n)) }
  colour <- function(s) if (is.na(s) || !nzchar(s)) NA_character_ else if (grepl(",", s)) argb(s) else s
  k <- 0L
  out <- lapply(seq_along(ids), function(i) {
    col <- colour(runs$Colour[i]); if (is.na(col)) { col <- if (hist[i]) INK else COMPARE_PAL[k %% length(COMPARE_PAL) + 1L] }
    if (!hist[i]) k <<- k + 1L
    lab <- runs$Label[i]; if (is.na(lab) || !nzchar(lab)) lab <- nm(ids[i])
    X <- load_run(lib, ids[i]); X$wp <- wp_of_run(lib, ids[i])   # stage 18's newest result on the run, or NULL
    list(rid = ids[i], label = lab, col = col, hist = hist[i], base = i == b, X = X) })
  # a history with no wood products result of its own takes a projection's: stage 18 on a projection runs its history's years too,
  # with the same draws, so the two agree there (wp_tg keeps each run to its own years)
  for (i in which(hist)) if (is.null(out[[i]]$X$wp)) for (j in which(!hist)) {
    if (!is.null(out[[j]]$X$wp) && identical(find_history(lib, ids[j]), ids[i])) { out[[i]]$X$wp <- out[[j]]$X$wp; break } }
  out }

# ---- per-run series --------------------------------------------------------------------------------------------------------
te_of <- function(X) if (is.null(X$stocks)) data.table(Timestep = integer(), Tg = numeric()) else X$stocks[StockGroup == "Total Ecosystem", .(Tg = sum(Mg) / 1e6), by = Timestep][order(Timestep)]
flow_of <- function(X, g) if (is.null(X$flows)) data.table(Timestep = integer(), Tg = numeric()) else X$flows[FlowGroup == g, .(Tg = sum(Mg) / 1e6), by = Timestep][order(Timestep)]
# a cause of carbon loss (run-figures.R loss_cause: Fire, Forest harvest, Land use change, Crop harvest, ...): "cause:<name>"
cause_of <- function(X, k) if (is.null(X$losses)) data.table(Timestep = integer(), Tg = numeric()) else X$losses[Cause == k, .(Tg = sum(Mg) / 1e6), by = Timestep][order(Timestep)]
# wetland methane of a run per year (lucasCore 1.5; src/run-figures.R's load_run reads it by class): in Gg C, and the run's net biome
# productivity as CO2 with that methane counted at its CO2 equivalent instead of as CO2 (Tg CO2e)
ch4_of <- function(X) if (is.null(X$ch4) || !nrow(X$ch4)) data.table(Timestep = integer(), Gg = numeric()) else X$ch4[FlowGroup == "Emission: Wetland CH4", .(Gg = sum(Mg) / 1e3), by = Timestep][order(Timestep)]
nbp_co2e_of <- function(X) { n <- flow_of(X, "Net Biome Productivity"); if (!nrow(n)) return(data.table(Timestep = integer(), Tg = numeric()))
  g <- function(grp) { d <- if (is.null(X$ch4) || !nrow(X$ch4)) NULL else X$ch4[FlowGroup == grp, .(v = sum(Mg) / 1e6), by = Timestep]; v <- if (is.null(d)) NA_real_ else d$v[match(n$Timestep, d$Timestep)]; v[is.na(v)] <- 0; v }
  data.table(Timestep = n$Timestep, Tg = 3.67 * n$Tg - (g("Emission: Wetland CH4 (CO2e)") - 3.67 * g("Emission: Wetland CH4"))) }
series_of <- function(X, g) if (startsWith(g, "cause:")) cause_of(X, sub("^cause:", "", g)) else flow_of(X, g)
trans_of <- function(X, f) X$trans[TransitionGroup == f, .(km2 = sum(ha) / 100), by = Timestep][order(Timestep)]
at_year <- function(d, y, v = "Tg") { x <- d[Timestep == y][[v]]; if (length(x)) x[1] else NA_real_ }

# the summary tables, one row per run: compare_carbon - total ecosystem carbon (Tg C) at the start and end, its change and the
# difference from the baseline, the change in live biomass and in dead wood, litter and soil, and mean annual fluxes over the run (Tg C
# per year: NPP, NEP, losses to land-use and land-cover change = fire emissions + harvest, NBP); compare_land - area burned, harvested
# and urbanized over the run, and the change in forest and developed area (km2)
role_of <- function(r) if (r$hist) "History" else if (r$base) "Baseline" else "Run"
compare_carbon <- function(R) {
  B <- Filter(function(r) r$base, R)[[1]]; tb <- te_of(B$X)
  pool <- function(X, g, y) { if (is.null(X$stocks)) return(NA_real_); v <- X$stocks[StockGroup %in% g & Timestep == y, sum(Mg)] / 1e6; if (length(v)) v else NA_real_ }
  rbindlist(lapply(R, function(r) { X <- r$X; t <- te_of(X); y0 <- X$years[1]; y1 <- X$years[2]
    mf <- function(g) { d <- flow_of(X, g)[Timestep > y0]; if (nrow(d)) mean(d$Tg) else NA_real_ }
    dom <- c("DOM: Deadwood", "DOM: Litter", "DOM: Soil")
    data.table(RunScenarioId = r$rid, Label = r$label, Role = role_of(r), StartYear = y0, EndYear = y1,
               CarbonStart = at_year(t, y0), CarbonEnd = at_year(t, y1), CarbonChange = at_year(t, y1) - at_year(t, y0),
               VsBaseline = if (r$hist || r$base) NA_real_ else at_year(t, y1) - at_year(tb, y1),
               BiomassChange = pool(X, "Biomass: Total", y1) - pool(X, "Biomass: Total", y0), DomSoilChange = pool(X, dom, y1) - pool(X, dom, y0),
               NPP = mf("Net Primary Productivity"), NEP = mf("Net Ecosystem Productivity"),
               LulcLoss = sum(mf("LULC: Emission"), mf("LULC: Harvest"), na.rm = TRUE), NBP = mf("Net Biome Productivity"),
               HwpStored = at_year(wp_tg(X, "Stored"), y1), HwpStockChange = { d <- wp_tg(X, "StockChange")[Timestep > y0]; if (nrow(d)) mean(d$Tg) else NA_real_ },
               NbpWithProducts = { d <- nbp_products(X)[Timestep > y0]; if (nrow(d)) mean(d$Tg) else NA_real_ }) })) }
compare_land <- function(R) {
  rbindlist(lapply(R, function(r) { X <- r$X; y0 <- X$years[1]; y1 <- X$years[2]
    tot <- function(f) { d <- trans_of(X, f); sum(d[Timestep > y0, km2]) }
    grp <- function(g, y) { a <- X$area[Timestep == y]; sum(a[cover_group(Class) == g, ha]) / 100 }
    data.table(RunScenarioId = r$rid, Label = r$label, Role = role_of(r), StartYear = y0, EndYear = y1,
               Fire = tot("Fire"), Harvest = tot("Forest Harvest"), Urbanization = tot("Urbanization"),
               ForestChange = grp("Forest", y1) - grp("Forest", y0), DevelopedChange = grp("Developed", y1) - grp("Developed", y0)) })) }

# compare_cost - management cost-effectiveness (to-do 58 cost follow-ups, user 2026-11-13): per projection, the Management Actions'
# money over the run from ST-Sim's transition attribute output (types "Management Cost: *" and "Management Revenue: *", USD;
# Output Options > Transition attributes), per iteration: costs, revenue and net cost (costs - revenue), each against the
# baseline's; and the carbon gained over the baseline, on two bases: total ecosystem carbon at the end (Mg C), and that plus the carbon
# stored in harvested wood products (stage 18 on both runs; NA without). USD per
# Mg C = the extra net cost / the carbon gained, from the iteration mean, its range from the iterations' lowest and highest net cost
# (each iteration draws its own costs: the cost range, Beta per iteration). No carbon gained: no ratio. NULL when no run has costs.
management_money <- function(lib, rid, y0) {
  con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); on.exit(dbDisconnect(con))
  if (!dbExistsTable(con, "stsim_OutputTransitionAttribute")) return(NULL)
  d <- as.data.table(dbGetQuery(con, sprintf("SELECT o.Iteration, a.Name AS Attr, SUM(o.Amount) AS USD FROM stsim_OutputTransitionAttribute o
    JOIN stsim_TransitionAttributeType a ON a.TransitionAttributeTypeId = o.TransitionAttributeTypeId
    WHERE o.ScenarioId = %d AND o.Timestep > %d AND (a.Name LIKE 'Management Cost:%%' OR a.Name LIKE 'Management Revenue:%%') GROUP BY o.Iteration, a.Name", rid, y0)))
  if (!nrow(d)) return(NULL)
  d[, .(Cost = sum(USD[startsWith(Attr, "Management Cost:")]), Revenue = sum(USD[startsWith(Attr, "Management Revenue:")])), by = Iteration][, Net := Cost - Revenue][] }
compare_cost <- function(R, lib) {
  P <- Filter(function(r) !r$hist, R); B <- Filter(function(r) r$base, R)[[1]]
  M <- lapply(P, function(r) management_money(lib, r$rid, r$X$years[1])); names(M) <- vapply(P, function(r) as.character(r$rid), "")
  if (all(vapply(M, is.null, TRUE))) return(NULL)
  zero <- data.table(Iteration = 1L, Cost = 0, Revenue = 0, Net = 0)
  mb <- M[[as.character(B$rid)]]; if (is.null(mb)) mb <- zero
  tb <- te_of(B$X)
  rbindlist(lapply(P, function(r) { m <- M[[as.character(r$rid)]]; if (is.null(m)) m <- zero
    y1 <- r$X$years[2]; gain <- if (r$base) NA_real_ else (at_year(te_of(r$X), y1) - at_year(tb, y1)) * 1e6
    # the second basis (user 2026-11-13: "against ecosystem carbon and ecosystem + HWP"): plus the carbon stored in harvested wood
    # products (in use, landfills and dumps; stage 18 on both runs) at the end, the run's minus the baseline's. Salvage moves dead
    # wood into products, which ecosystem carbon alone counts as lost
    hw <- function(X) if (is.null(X$wp)) NA_real_ else at_year(wp_tg(X, "Stored"), y1) * 1e6
    gain_p <- if (r$base) NA_real_ else gain + (hw(r$X) - hw(B$X))
    # each iteration against the baseline's same iteration when both have the same ones (a baseline from the same setup draws
    # shares each iteration's historical years, so the pairs differ by the action, not the draw), else against the baseline's mean
    paired <- !r$base && nrow(mb) > 1 && setequal(m$Iteration, mb$Iteration)
    xn <- if (paired) m$Net - mb$Net[match(m$Iteration, mb$Iteration)] else m$Net - mean(mb$Net); net <- mean(xn)
    per <- function(v, g = gain) if (r$base || is.na(g) || g <= 0) NA_real_ else v / g
    data.table(RunScenarioId = r$rid, Label = r$label, Role = role_of(r), Iterations = r$X$nit,
               Cost = mean(m$Cost), Revenue = mean(m$Revenue), NetCost = mean(m$Net),
               NetCostLow = min(m$Net), NetCostHigh = max(m$Net),
               ExtraNetCost = if (r$base) NA_real_ else net, CarbonGain = gain,
               UsdPerMgC = per(net), UsdPerMgCLow = per(min(xn)), UsdPerMgCHigh = per(max(xn)), UsdPerMgCO2e = per(net) / (44 / 12),
               CarbonGainWithProducts = gain_p, UsdPerMgCWithProducts = per(net, gain_p), UsdPerMgCWithProductsLow = per(min(xn), gain_p),
               UsdPerMgCWithProductsHigh = per(max(xn), gain_p), UsdPerMgCO2eWithProducts = per(net, gain_p) / (44 / 12)) })) }

# ---- the figures -----------------------------------------------------------------------------------------------------------
# R: compare_runs(); grid: the Build's state class map; dem; label: the study area; cap: the Build's carbon capacity maps
# (src/capacity.R's capacity_maps()) or NULL: with them, the figure of each run against the carrying capacity and the table in
# attribute "capacity" (compare_capacity)
compare_figures <- function(R, grid, dem, label, outdir, cap = NULL) {
  B <- Filter(function(r) r$base, R)[[1]]; P <- Filter(function(r) !r$hist, R); O <- Filter(function(r) !r$hist && !r$base, R)
  H <- Filter(function(r) r$hist, R)
  ps <- sort(unique(vapply(P, function(r) r$X$years[1], 0)))      # the projections' start years (the joins with their history)
  nit <- max(vapply(R, function(r) r$X$nit, 0))
  NOTE <- sprintf("%s; %s; baseline %s; %d iteration%s, %g m grid.", label, sprintf("results %s", paste(vapply(R, function(r) sprintf("%d", r$rid), ""), collapse = ", ")),
    B$label, nit, if (nit > 1) "s (tables averaged; maps of iteration 1)" else "", res(grid)[1])
  K <- figure_kit(grid, dem, outdir, NOTE); use_kit(K, environment())
  relief <- if (dem_ok) " Shaded relief from the elevation data source." else ""
  rd <- function(f) if (!is.na(f) && file.exists(f)) rast(f) else NULL
  labs <- vapply(R, `[[`, "", "label"); cols <- vapply(R, `[[`, "", "col")
  # line widths: the history thin; the projections from thick to thin in list order, so a run drawn over an identical one leaves its edge showing
  np <- sum(!vapply(R, `[[`, TRUE, "hist")); lwds <- numeric(length(R)); lwds[!vapply(R, `[[`, TRUE, "hist")] <- seq(3.4, 1.6, length.out = max(np, 2))[seq_len(np)]; lwds[lwds == 0] <- 1.6
  under_legend <- function(..., ncol = NULL) { n <- length(list(...)[[1]]); legend("top", ..., ncol = ncol %||% (if (max(nchar(list(...)[[1]])) > 20) min(n, 2) else min(n, 4)), inset = c(0, 1.12), xpd = NA, bty = "n", cex = .75, border = NA) }
  low <- function() par(mar = c(8, 5, 3, 1))
  mark_line <- function() for (x in ps) { abline(v = x, col = MUTED, lty = 2); mtext("projection", side = 3, at = x, adj = -0.05, line = -1.1, cex = .6, col = MUTED) }
  xr <- range(unlist(lapply(R, function(r) r$X$years)))
  # one line per run over its years; a projection's line starts from its history's value in the start year, so the lines join
  # fill: years of the run with no row are zero (transitions), so a line does not bridge them; legend: draw the legend under the panel
  run_lines <- function(get, ylab, title_i, title, zero = FALSE, fill = FALSE, legend = TRUE) {
    S <- lapply(R, function(r) { d <- get(r$X); if (fill) { yy <- (r$X$years[1] + 1):r$X$years[2]; d <- data.table(Timestep = yy, v = d[[2]][match(yy, d[[1]])]); d[is.na(v), v := 0] }; d })
    yl <- range(c(unlist(lapply(S, `[[`, 2)), if (zero) 0), na.rm = TRUE)
    plot(NA, xlim = xr, ylim = yl, xlab = "", ylab = ylab, bty = "l"); hgrid(); if (zero) abline(h = 0, col = MUTED, lty = 2)
    for (i in seq_along(R)) if (nrow(S[[i]])) lines(S[[i]][[1]], S[[i]][[2]], col = cols[i], lwd = lwds[i])
    mark_line(); ptitle(title_i, title); if (legend) under_legend(labs, col = cols, lwd = 2, ncol = 2) }

  # ---- charts: total ecosystem carbon, and the difference from the baseline ------------------------------------------------
  tb <- te_of(B$X); ye <- B$X$years[2]
  if (nrow(tb)) {
    dif <- lapply(O, function(r) { t <- te_of(r$X); m <- merge(t, tb, by = "Timestep", suffixes = c("", "_b")); m[, .(Timestep, d = Tg - Tg_b)] })
    end_d <- vapply(dif, function(d) at_year(d, ye, "d"), 0)
    chart_figure("carbon", "Total ecosystem carbon", sprintf("(a) Total ecosystem carbon (all 14 CBM pools) in each run%s. (b) Each run's difference from the baseline (%s), year by year.",
        if (nit > 1) ", the projections' Monte Carlo range shaded" else "", B$label), 1, 2, h = 1150, draw = function() {
      low(); S <- lapply(R, function(r) te_of(r$X)); yl <- range(unlist(lapply(S, `[[`, "Tg")), na.rm = TRUE)
      plot(NA, xlim = xr, ylim = yl, xlab = "", ylab = "Tg C", bty = "l"); hgrid()
      for (i in seq_along(R)) { it <- R[[i]]$X$te_it
        if (!R[[i]]$hist && !is.null(it)) { q <- it[, .(lo = min(Tg), hi = max(Tg)), by = Timestep][order(Timestep)]; polygon(c(q$Timestep, rev(q$Timestep)), c(q$lo, rev(q$hi)), col = adjustcolor(cols[i], .2), border = NA) } }
      for (i in seq_along(R)) lines(S[[i]]$Timestep, S[[i]]$Tg, col = cols[i], lwd = if (R[[i]]$hist) 1.6 else 2)
      mark_line(); ptitle(1, sprintf("Total ecosystem carbon, %d: %s Tg C", ye, paste(sprintf("%.0f", vapply(P, function(r) at_year(te_of(r$X), r$X$years[2]), 0)), collapse = " / ")))
      under_legend(labs, col = cols, lwd = 2)
      low()
      if (length(O)) { yl <- range(c(0, unlist(lapply(dif, `[[`, "d"))), na.rm = TRUE)
        plot(NA, xlim = range(tb$Timestep), ylim = yl, xlab = "", ylab = sprintf("Tg C, run minus %s", B$label), bty = "l"); hgrid(); abline(h = 0, col = B$col, lwd = 2)
        for (j in seq_along(O)) lines(dif[[j]]$Timestep, dif[[j]]$d, col = O[[j]]$col, lwd = 2)
        ptitle(2, sprintf("Difference from %s in %d: %s", B$label, ye, paste(sprintf("%+.1f", end_d), collapse = ", ")))
        under_legend(c(B$label, vapply(O, `[[`, "", "label")), col = c(B$col, vapply(O, `[[`, "", "col")), lwd = 2)
      } else { plot.new(); text(.5, .5, "Only one run besides the history: nothing to difference", col = MUTED) } }) }

  # ---- maps: the baseline's final carbon, and each run's difference from it -------------------------------------------------
  cb <- rd(B$X$carbon1)
  if (!is.null(cb)) {
    vb <- cv(cb); s <- steps(vb); tot <- function(v) sum(v[inz], na.rm = TRUE) * prod(res(el)) / 1e4 / 1e6
    D <- lapply(O, function(r) { c1 <- rd(r$X$carbon1); if (is.null(c1) || r$X$years[2] != ye) NULL else cv(c1) - vb }); keep <- !vapply(D, is.null, TRUE)
    if (any(keep)) {
      m <- unname(quantile(abs(unlist(lapply(D[keep], function(d) d[inz]))), 0.99, na.rm = TRUE)); m <- if (is.finite(m) && m > 0) m else 1
      b <- unique(signif(m * c(-1, -.5, -.2, -.05, .05, .2, .5, 1), 1)); dbrk <- c(-Inf, b, Inf); fm <- function(x) format(x, trim = TRUE)
      dlab <- c(paste0("<", fm(b[1])), ifelse(abs(b[-length(b)] + b[-1]) < 1e-9, paste0("±", fm(b[-1])), fm(b[-length(b)])), paste0(">", fm(b[length(b)])))
      PN <- c(list(list(k = classed(vb, s$brk), cols = RAMP_C(length(s$brk) - 1), lab = s$lab, title = sprintf("%s, %d (Mg C/ha)", B$label, ye), sub = sprintf("%.1f Tg C; the baseline", tot(vb)))),
              Map(function(r, d) list(k = classed(d, dbrk), cols = RAMP_CHG(length(dbrk) - 1), lab = dlab, title = sprintf("%s minus %s (Mg C/ha)", r$label, B$label),
                                      sub = sprintf("%+.1f Tg C; brown less, green more", tot(d))), O[keep], D[keep]))
      map_figure("carbon_difference", sprintf("Total ecosystem carbon in %d, against the baseline", ye), PN,
        sprintf("(a) Total ecosystem carbon in the baseline run's final year. (%s) Each other run's final-year carbon minus the baseline's, cell by cell (iteration 1; one scale, to the 99th percentile of the differences).%s",
                paste(letters[seq_len(sum(keep)) + 1], collapse = ", "), relief)) } }

  # ---- charts: carbon against the carrying capacity (cap: capacity_maps() of the Build result; src/capacity.R) -----------------
  # (a) each run's live biomass, dead wood and litter as a share of the capacity; (b) each projection's deficit in its last year by cause
  Cc <- if (!is.null(cap) && exists("compare_capacity", mode = "function")) compare_capacity(R, cap) else NULL
  if (!is.null(Cc)) {
    Pc <- Cc[Role != "History"]; has_split <- !anyNA(Pc$DeficitLandUse)
    chart_figure("carbon_capacity", "Carbon against the carrying capacity", paste0(
      "The carrying capacity is what the land would hold in live biomass, dead wood and litter under its potential natural vegetation and natural fire regime (the Build's Carbon Capacity maps: for forest, the mean stock of a landscape of ",
      sprintf("the type burning at its natural stand-replacing fire return interval; soil is not counted; fixed at the Build's historical climate): %.1f Tg C here%s. ", cap$total, if (is.na(cap$upper_total)) "" else sprintf(", %.1f at the old-growth end of the curves", cap$upper_total)),
      "(a) Each run's stock of those pools as a share of the capacity. ",
      if (has_split) "(b) Each projection's deficit (capacity less stock) in its last year by cause, from its maps: developed and farmed land; disturbed land waiting to return to its cover; and, on land in its potential cover, live biomass (for forest, stands younger or older than the natural regime's mean age, and their stocking) apart from dead wood and litter (which also follow stand age: a landscape under its natural regime holds recently burned stands, rich in dead wood, and old ones; and, in part, the disturbance the Build starts each stand after, Carbon Assumptions: Spin-up). A cause's value is net of land above its capacity; and natural grassland, shrubland and barren land whose capacity is mostly forest (forest at the start that has since converted and, when Carbon Capacity Options counts it so, land LANDFIRE BpS maps as forest potential)." else
        "(b) Each projection's deficit (capacity less stock) in its last year."), 1, 2, h = 1150, draw = function() {
      low(); run_lines(function(X) capacity_series(X$stocks, cap$total)[, .(Timestep, RealisedShare)], "% of the carrying capacity", 1, legend = FALSE,
        sprintf("Share of the capacity, %d: %s%%", ye, paste(sprintf("%.0f", Pc$ShareEnd), collapse = " / "))); under_legend(labs, col = cols, lwd = 2, ncol = 2)
      low(); pcol <- vapply(P, `[[`, "", "col")
      if (has_split) { S <- as.matrix(Pc[, CAPACITY_CAUSE_COLS, with = FALSE]); colnames(S) <- CAPACITY_CAUSE_LABELS; S <- S[, colSums(abs(S)) > 1e-9, drop = FALSE]
        barplot(S, beside = TRUE, col = pcol, border = NA, ylim = range(c(0, S)) * 1.15, ylab = "Tg C below the capacity", cex.names = .75); hgrid(); abline(h = 0, col = MUTED)
        barplot(S, beside = TRUE, col = pcol, border = NA, add = TRUE, axes = FALSE, names.arg = rep("", ncol(S)))
      } else { barplot(Pc$DeficitEnd, col = pcol, border = NA, ylim = range(c(0, Pc$DeficitEnd)) * 1.15, ylab = "Tg C below the capacity"); hgrid(); abline(h = 0, col = MUTED) }
      ptitle(2, sprintf("Deficit in the last year: %s Tg C", paste(sprintf("%.1f", Pc$DeficitEnd), collapse = " / "))); under_legend(Pc$Label, fill = pcol) }) }

  # ---- charts: carbon fluxes per year ----------------------------------------------------------------------------------------
  FL <- c(`Net primary productivity` = "Net Primary Productivity", `Heterotrophic respiration` = "Emission: Total Rh",
          `Net ecosystem productivity` = "Net Ecosystem Productivity", `Net biome productivity` = "Net Biome Productivity")
  if (any(vapply(R, function(r) !is.null(r$X$flows) && nrow(r$X$flows) > 0, TRUE))) {
    chart_figure("carbon_fluxes", "Carbon fluxes per year", "Net primary productivity, heterotrophic respiration, net ecosystem productivity and net biome productivity (net ecosystem productivity less what transitions emit and remove, and crop harvest) in each run, per year.",
      2, 2, h = 1900, draw = function() for (i in seq_along(FL)) { low()
        run_lines(function(X) flow_of(X, FL[i]), "Tg C per year", i, names(FL)[i], zero = i >= 3) }) }

  # ---- charts: harvested wood products (runs with a stage 18 result) ---------------------------------------------------------
  has_wp <- vapply(R, function(r) !is.null(r$X$wp), TRUE)
  if (any(has_wp)) {
    miss <- vapply(R[!has_wp], `[[`, "", "label")
    chart_figure("wood_products", "Harvested wood products", paste0("Stage 18 (Wood Products) on each run, the USFS harvested wood products model (production approach): ",
      "(a) carbon stored in harvested wood products, in use and in landfills and dumps, including what was harvested before the run and is still stored; ",
      "(b) net biome productivity with the change in that store added (the ecosystem's NBP counts harvest as a loss).",
      if (length(miss)) sprintf(" No Wood Products result on %s: run stage 18 on it to add it.", paste(miss, collapse = ", ")) else ""),
      1, 2, h = 1150, draw = function() {
        low(); run_lines(function(X) wp_tg(X, "Stored")[, .(Timestep, Tg)], "Tg C", 1, legend = FALSE,
          sprintf("Carbon stored in wood products, %d: %s Tg C", ye, paste(vapply(P, function(r) sprintf("%.3g", at_year(wp_tg(r$X, "Stored"), r$X$years[2])), ""), collapse = " / ")))
        under_legend(labs, col = cols, lwd = 2, ncol = 1)
        low(); run_lines(function(X) nbp_products(X)[, .(Timestep, Tg)], "Tg C per year", 2, "Net biome productivity with wood products", zero = TRUE, legend = FALSE) }) }

  # ---- charts: wetland methane (runs whose wetlands released any) ------------------------------------------------------------
  has_m <- vapply(R, function(r) sum(ch4_of(r$X)$Gg) > 0, TRUE)
  if (any(has_m)) {
    miss <- vapply(R[!has_m], `[[`, "", "label")
    pmean <- function(get, v) vapply(P, function(r) { d <- get(r$X); d <- d[Timestep > r$X$years[1]]; if (nrow(d)) sprintf("%.3g", mean(d[[v]])) else "-" }, "")
    chart_figure("wetland_methane", "Wetland methane", paste0("(a) Carbon released to the atmosphere as methane by wetland soil and litter in each run, per year, in thousand tonnes of carbon (Gg C); ",
      "it is part of heterotrophic respiration, so it is already inside net ecosystem and net biome productivity. ",
      "(b) Net biome productivity as CO2 (carbon x 3.67) with that methane counted at its CO2 equivalent instead of as CO2; positive is uptake by the land. Titles give each projection's mean.",
      if (length(miss)) sprintf(" No wetland methane in %s (a run made before lucasCore 1.5, or one without wetlands).", paste(miss, collapse = ", ")) else ""),
      1, 2, h = 1150, draw = function() {
        low(); run_lines(function(X) ch4_of(X), "Gg C as CH4 per year", 1, sprintf("Methane from wetlands (mean %s Gg C/yr)", paste(pmean(ch4_of, "Gg"), collapse = " / ")), zero = TRUE, legend = FALSE)
        under_legend(labs, col = cols, lwd = 2, ncol = 1)
        low(); run_lines(function(X) nbp_co2e_of(X), "Tg CO2e per year", 2, sprintf("NBP with methane as CO2e (mean %s Tg CO2e/yr)", paste(pmean(nbp_co2e_of, "Tg"), collapse = " / ")), zero = TRUE, legend = FALSE) }) }

  # ---- charts: flux means by period ------------------------------------------------------------------------------------------
  # the history as one period, the projections by decade (2024-2030, 2031-2040, ...); a bar per run that covers the period
  per <- function(y, h) if (h) rep("hist", length(y)) else sprintf("%d", as.integer(ceiling(y / 10) * 10))
  pm <- function(r, g) { d <- series_of(r$X, g); d <- d[Timestep > r$X$years[1]]
    if (!nrow(d)) return(NULL); d[, p := per(Timestep, r$hist)]; d[, .(Tg = mean(Tg), y0 = min(Timestep), y1 = max(Timestep)), by = p] }
  FM <- c(FL[c(1, 2, 4)], `Fire emissions (with peat)` = "cause:Fire")   # LULC: Emission until 2026-11-10: every transition's emissions, labelled fire
  if (any(vapply(R, function(r) !is.null(r$X$flows) && nrow(r$X$flows) > 0, TRUE))) {
    Z <- lapply(FM, function(g) lapply(R, pm, g = g))
    pers <- unique(rbindlist(lapply(Z[[1]], function(z) if (!is.null(z)) z[, .(p, y0, y1)])))[order(p != "hist", p)]
    pers <- pers[, .(y0 = min(y0), y1 = max(y1)), by = p]; plab <- sprintf("%d-%d", pers$y0, pers$y1)
    chart_figure("flux_means", "Carbon fluxes by period", sprintf("Mean annual flux in each period: %s; one bar per run that covers the period.", if (length(H)) "the history as one period, the projections by decade" else "by decade"),
      2, 2, h = 1900, draw = function() for (i in seq_along(FM)) { low()
        M <- sapply(pers$p, function(p) vapply(Z[[i]], function(z) if (is.null(z)) NA_real_ else z$Tg[match(p, z$p)], 0))
        M <- matrix(M, nrow = length(R)); yl <- range(c(0, M), na.rm = TRUE) * 1.1
        bp <- barplot(M, beside = TRUE, col = cols, border = NA, ylim = yl, names.arg = plab, cex.names = .75, ylab = "Tg C per year"); hgrid(); abline(h = 0, col = MUTED)
        barplot(M, beside = TRUE, col = cols, border = NA, add = TRUE, axes = FALSE, names.arg = rep("", ncol(M)))
        ptitle(i, names(FM)[i]); under_legend(labs, fill = cols) }) }

  # ---- charts: transitions per year ------------------------------------------------------------------------------------------
  fams <- FAMILIES[vapply(FAMILIES, function(f) any(vapply(R, function(r) nrow(trans_of(r$X, f)) > 0 && sum(trans_of(r$X, f)$km2) > 0, TRUE)), TRUE)]
  if (length(fams)) { nc <- min(3, length(fams)); nr <- ceiling(length(fams) / nc)
    chart_figure("transitions", "Transitions per year", "Area of each transition family per year in each run (a year with none is zero); titles give each projection's total. Runs whose lines lie on top of each other had the same area: the projections are drawn thick to thin.", nr, nc, h = 950 * nr + 260,
      draw = function() for (i in seq_along(fams)) { low()
        tt <- vapply(P, function(r) { d <- trans_of(r$X, fams[i]); sum(d[Timestep > r$X$years[1], km2]) }, 0)
        run_lines(function(X) trans_of(X, fams[i]), "km2 per year", i, fill = TRUE, title = sprintf("%s: %s km2", fams[i], paste(sprintf("%.0f", tt), collapse = " / "))) }) }

  # ---- charts: carbon by pool ------------------------------------------------------------------------------------------------
  pools <- c(`Live biomass` = "Biomass: Total", `Dead wood` = "DOM: Deadwood", Litter = "DOM: Litter", Soil = "DOM: Soil")
  pool_at <- function(X, y) vapply(pools, function(g) { if (is.null(X$stocks)) return(NA_real_); v <- X$stocks[StockGroup == g & Timestep == y, sum(Mg)] / 1e6; if (length(v)) v else NA_real_ }, 0)
  if (!is.null(B$X$stocks) && nrow(B$X$stocks)) {
    y0 <- min(ps); M0 <- pool_at(B$X, y0); ME <- sapply(P, function(r) pool_at(r$X, r$X$years[2])); colnames(ME) <- vapply(P, `[[`, "", "label")
    chart_figure("carbon_pools", "Carbon by pool", sprintf("(a) Carbon in each pool in %d, where the projections start, and in each projection's final year. (b) The change in each pool over the projection.", y0), 1, 2, h = 1150, draw = function() {
      low(); M <- cbind(M0, ME); colnames(M)[1] <- sprintf("%d", y0); pc <- c(INK, vapply(P, `[[`, "", "col"))
      barplot(t(M), beside = TRUE, col = pc, border = NA, ylab = "Tg C", ylim = c(0, max(M, na.rm = TRUE) * 1.1)); hgrid()
      barplot(t(M), beside = TRUE, col = pc, border = NA, add = TRUE, axes = FALSE); ptitle(1, sprintf("Carbon by pool, %d and %d", y0, ye)); under_legend(colnames(M), fill = pc)
      low(); D <- ME - M0; yl <- range(c(0, D), na.rm = TRUE) * 1.15
      barplot(t(D), beside = TRUE, col = pc[-1], border = NA, ylab = "Tg C", ylim = yl); hgrid(); abline(h = 0, col = MUTED)
      barplot(t(D), beside = TRUE, col = pc[-1], border = NA, add = TRUE, axes = FALSE); ptitle(2, sprintf("Change by pool, %d-%d", y0, ye)); under_legend(colnames(ME), fill = pc[-1]) }) }

  # ---- charts: land area change by cover group -------------------------------------------------------------------------------
  grp_at <- function(X, y) { a <- X$area[Timestep == y]; a[, g := cover_group(Class)]; a[, .(km2 = sum(ha) / 100), by = g] }
  G <- lapply(P, function(r) { a <- grp_at(r$X, r$X$years[1]); b <- grp_at(r$X, r$X$years[2]); m <- merge(a, b, by = "g", all = TRUE, suffixes = c("_0", "_1")); m[is.na(m)] <- 0; m[, .(g, d = km2_1 - km2_0)] })
  gr <- names(COVER_COLS)[names(COVER_COLS) %in% unlist(lapply(G, function(m) m[abs(d) > 0.5, g]))]
  if (length(gr)) {
    M <- sapply(G, function(m) m[match(gr, g), d]); M <- matrix(M, nrow = length(gr), dimnames = list(gr, vapply(P, `[[`, "", "label"))); M[is.na(M)] <- 0
    chart_figure("land_area", "Land area change by cover group", sprintf("Change in the area of each land cover group over each projection (%d-%d).", min(ps), ye), 1, 1, h = 1150, draw = function() {
      low(); yl <- range(c(0, M)) * 1.15; barplot(t(M), beside = TRUE, col = vapply(P, `[[`, "", "col"), border = NA, ylab = "km2", ylim = yl); hgrid(); abline(h = 0, col = MUTED)
      barplot(t(M), beside = TRUE, col = vapply(P, `[[`, "", "col"), border = NA, add = TRUE, axes = FALSE)
      ptitle(1, sprintf("Change in area, %d-%d", min(ps), ye)); under_legend(colnames(M), fill = vapply(P, `[[`, "", "col")) }) }

  # ---- the summary tables: carbon, and land change -----------------------------------------------------------------------------
  # a table figure: a colour swatch per run, a header of two lines (name, unit), columns spaced by their widest entry
  table_figure <- function(slug, title, caption, tab, units) {
    chart_figure(slug, title, caption, 1, 1, h = 380 + 110 * nrow(tab), draw = function() {
      par(mar = c(0, 1, 1, 1)); plot.new()
      # each column as wide as its widest text as drawn (bold header, unit, entries) and a gap; the whole scaled down to fit when the
      # run names are long or the columns many (2026-11-12: counted characters let the bold headers and a long run name overlap)
      cx <- .8; gap <- strwidth("MM", cex = cx)
      wd <- vapply(seq_along(tab), function(j) max(strwidth(names(tab)[j], cex = cx * .975, font = 2), strwidth(c(units[j], tab[[j]]), cex = cx)), 0) + gap
      k <- min(1, .96 / sum(wd)); cx <- cx * k; wd <- wd * k
      x <- .03 + c(0, cumsum(wd)[-length(wd)])
      rj <- c(FALSE, rep(TRUE, ncol(tab) - 1)); xr <- ifelse(rj, x + wd - gap * k / 2, x)   # numbers right-aligned
      y <- seq(.77, by = -min(.66 / nrow(tab), .17), length.out = nrow(tab))
      for (j in seq_along(tab)) { text(xr[j], .95, names(tab)[j], adj = c(as.numeric(rj[j]), .5), font = 2, cex = cx * .975, col = INK)
        text(xr[j], .90, units[j], adj = c(as.numeric(rj[j]), .5), cex = cx * .83, col = MUTED) }
      abline(h = .855, col = GRID)
      for (i in seq_len(nrow(tab))) { rect(.005, y[i] - .025, .02, y[i] + .025, col = cols[i], border = NA)
        for (j in seq_along(tab)) text(xr[j], y[i], tab[[j]][i], adj = c(as.numeric(rj[j]), .5), cex = cx, col = INK) } }) }
  f1 <- function(x) ifelse(is.na(x), "", sprintf("%.1f", x)); s1 <- function(x) ifelse(is.na(x), "", sprintf("%+.1f", x))
  s2 <- function(x) ifelse(is.na(x), "", sprintf("%+.2f", x)); f2 <- function(x) ifelse(is.na(x), "", sprintf("%.2f", x))
  f0 <- function(x) ifelse(is.na(x), "", format(round(x), big.mark = ",")); s0 <- function(x) ifelse(is.na(x), "", paste0(ifelse(round(x) > 0, "+", ""), format(round(x), big.mark = ",", trim = TRUE)))
  Cb <- compare_carbon(R); Ld <- compare_land(R)
  ct <- Cb[, .(Run = Label, Years = sprintf("%d-%d", StartYear, EndYear), `Carbon end` = f1(CarbonEnd), Change = s1(CarbonChange),
           `vs baseline` = ifelse(Role == "Baseline", "baseline", s1(VsBaseline)), `Live biomass` = s1(BiomassChange), `Dead & soil` = s1(DomSoilChange),
           NPP = f2(NPP), NEP = s2(NEP), `LULC losses` = f2(LulcLoss), NBP = s2(NBP))]
  cu <- c("", "", "Tg C", "Tg C", "Tg C", "change, Tg C", "change, Tg C", "Tg C/yr", "Tg C/yr", "Tg C/yr", "Tg C/yr")
  ccap <- "Total ecosystem carbon at the end of each run, its change over the run and the difference from the baseline in the final year; the change in live biomass and in dead wood, litter and soil over the run; and mean annual fluxes over the run: net primary productivity, net ecosystem productivity, losses to land-use and land-cover change (fire emissions and harvest) and net biome productivity (net ecosystem productivity less those losses)"
  if (any(has_wp)) { ct[, `:=`(HWP = s2(Cb$HwpStockChange), `NBP + HWP` = s2(Cb$NbpWithProducts))]; cu <- c(cu, "Tg C/yr", "Tg C/yr")
    ccap <- paste0(ccap, "; with stage 18's wood products, the mean change in carbon stored in harvested wood products (HWP) and net biome productivity with it added (blank: no Wood Products result on the run)") }
  table_figure("carbon_summary", "Carbon summary", paste0(ccap, "."), ct, cu)
  table_figure("land_summary", "Land change summary", "Area burned, harvested and urbanized over each run (summed over its years, so land burned twice counts twice), and the change in forest and developed land area from the first to the last year of the run.",
    Ld[, .(Run = Label, Years = sprintf("%d-%d", StartYear, EndYear), Burned = f0(Fire), Harvested = f0(Harvest), Urbanized = f0(Urbanization),
           Forest = s0(ForestChange), Developed = s0(DevelopedChange))],
    c("", "", "km2", "km2", "km2", "change, km2", "change, km2"))

  out <- rbindlist(K$rows); attr(out, "carbon") <- Cb; attr(out, "land") <- Ld; attr(out, "capacity") <- Cc; out }
