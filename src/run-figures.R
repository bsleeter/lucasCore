# =============================================================================
# run-figures.R - report figures of an ST-Sim run (a historical run or a projection) on a lucasCore Build; sourced by stage 13
# (src/13-run-figures.R), and testable outside a run (dev/figures/test_run_figures.R)
# =============================================================================
# Same format as the Build figures (src/figures.R, figure_kit): "Figure N" headers, lettered panels, maps on shaded relief.
#   maps    land cover in the first and last year and the land-use change between them, harvest included | fire: times burned,
#           highest severity, last burn | harvest: times harvested, type, last harvest | total ecosystem carbon in the first and last
#           year and its change
#   charts  land area by cover group | transitions per year, simulated against the Build's record | carbon stocks | carbon fluxes |
#           carbon by secondary stratum (counties)
# load_run(lib, rid, ...) reads the run: its tables summed in SQL (iterations averaged) and its first-iteration maps by path; maps the
# run did not write (state class, fire or harvest transitions, total ecosystem carbon) leave their figure or panel out. Harvest is
# read from every mapped group named "Forest Harvest..." (the clearcut and selection [Type] groups by default), its cells classed by
# transition type name.
# =============================================================================
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })

cover_group <- function(x) { g <- sub(":.*$", "", x); g[grepl("^Forest", x)] <- "Forest"
  g[!g %in% c("Forest", "Shrubland", "Grassland", "Agriculture", "Developed", "Wetland", "Water")] <- "Barren and other"; g }
COVER_COLS <- c(Forest = "#2b8152", Shrubland = "#c9a26b", Grassland = "#e6d77a", Agriculture = "#d98b3a", Developed = "#c0392b",
                Wetland = "#5aa9b8", Water = "#3b6ea8", `Barren and other` = "#a3a3a3")
FAMILIES <- c("Urbanization", "Intensification", "Ag Expansion", "Ag Contraction", "Fire", "Forest Harvest")
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
  unit_c <- if (!is.null(stocks)) q("SELECT s.Name AS Unit, o.Timestep, SUM(o.Amount) / %d AS Mg FROM stsim_OutputStock o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId
              JOIN stsim_SecondaryStratum s ON s.SecondaryStratumId = o.SecondaryStratumId WHERE o.ScenarioId = %d AND g.Name = 'Total Ecosystem' AND o.Timestep IN (%d, %d)
              GROUP BY s.Name, o.Timestep", nit, rid, yrs[1], yrs[2]) else NULL
  unit_a <- q("SELECT s.Name AS Unit, SUM(o.Amount) / %d AS ha FROM stsim_OutputStratumState o JOIN stsim_SecondaryStratum s ON s.SecondaryStratumId = o.SecondaryStratumId
              WHERE o.ScenarioId = %d AND o.Timestep = %d GROUP BY s.Name", nit, rid, yrs[1])
  path <- function(folder, f) if (length(f) && !is.na(f[1])) file.path(dd, folder, basename(f[1])) else NA_character_
  ssm <- q("SELECT Timestep, Filename FROM stsim_OutputSpatialState WHERE ScenarioId = %d AND Iteration = 1", rid)
  fire_id <- q("SELECT TransitionGroupId FROM stsim_TransitionGroup WHERE Name = 'Fire'")$TransitionGroupId
  fm <- if (length(fire_id)) q("SELECT Timestep, Filename FROM stsim_OutputSpatialTransition WHERE ScenarioId = %d AND Iteration = 1 AND TransitionGroupId = %d", rid, fire_id[1]) else data.table()
  hm <- q("SELECT o.Timestep, o.Filename FROM stsim_OutputSpatialTransition o JOIN stsim_TransitionGroup g ON g.TransitionGroupId = o.TransitionGroupId
           WHERE o.ScenarioId = %d AND o.Iteration = 1 AND g.Name LIKE 'Forest Harvest%%'", rid)
  te <- q("SELECT o.Timestep, o.Filename FROM stsim_OutputAverageSpatialStockGroup o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId WHERE o.ScenarioId = %d AND g.Name = 'Total Ecosystem'", rid)
  list(rid = rid, nit = nit, years = yrs, sc_list = sc, tt_list = tt, area = area, trans = trans, stocks = stocks, flows = flows, unit_c = unit_c, unit_a = unit_a,
       sc0 = path("stsim_OutputSpatialState", ssm[Timestep == yrs[1], Filename]), sc1 = path("stsim_OutputSpatialState", ssm[Timestep == yrs[2], Filename]),
       fire = if (nrow(fm)) setNames(vapply(fm$Filename, function(f) path("stsim_OutputSpatialTransition", f), ""), fm$Timestep) else character(),
       harvest = if (nrow(hm)) setNames(vapply(hm$Filename, function(f) path("stsim_OutputSpatialTransition", f), ""), hm$Timestep) else character(),
       carbon0 = path("stsim_OutputAverageSpatialStockGroup", te[Timestep == yrs[1], Filename]), carbon1 = path("stsim_OutputAverageSpatialStockGroup", te[Timestep == yrs[2], Filename]))
}

# ---- the figures -----------------------------------------------------------------------------------------------------------
# X: load_run(); grid: the Build's state class map (the model grid); sc_colours: state class Name -> colour; dem; label; observed: the
# Build's transition summary (Timestep, TransitionGroup, Area km2) or NULL; run_name
run_figures <- function(X, grid, sc_colours, dem, label, observed, outdir, run_name = sprintf("result %d", X$rid)) {
  y0 <- X$years[1]; y1 <- X$years[2]; ha_cell <- prod(res(grid)) / 1e4
  NOTE <- sprintf("%s; %s, %d-%d, %d iteration%s, %g m grid.", label, run_name, y0, y1, X$nit, if (X$nit > 1) "s (tables averaged; maps of iteration 1)" else "", res(grid)[1])
  K <- figure_kit(grid, dem, outdir, NOTE); use_kit(K, environment())
  relief <- if (dem_ok) " Shaded relief from the elevation data source." else ""
  rd <- function(f) if (!is.na(f) && file.exists(f)) rast(f) else NULL
  # a legend in rows under the plot (for panels whose legends are too long for the line above them); the panel needs mar[1] >= 7
  under_legend <- function(...) { n <- length(list(...)[[1]]); legend("top", ..., ncol = if (max(nchar(list(...)[[1]])) > 20) min(n, 2) else min(n, 3), inset = c(0, 1.12), xpd = NA, bty = "n", cex = .75, border = NA) }
  low <- function() par(mar = c(8, 5, 3, 1))
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
      list(k = nb, cols = c("#fbe3a2", "#ef8f2a", "#c93a1d", "#5c0f14"), lab = c("1", "2", "3", "4+"), title = "Times burned", sub = sprintf("%.0f km2 burned at least once; grey: not burned", burned_km2)),
      list(k = ifelse(sev == 0, NA, sev), cols = c("#fbe3a2", "#ef8f2a", "#a81d1a"), lab = c("Low", "Medium", "High"), key = TRUE, title = "Highest burn severity", sub = "MTBS severity classes, as simulated"),
      list(k = ifelse(is.na(last), NA, findInterval(last, yb, rightmost.closed = TRUE)), cols = colorRampPalette(c("#fde7b0", "#e0702b", "#6b1a10"))(length(yb) - 1), lab = ylab,
           title = "Year of the last fire", sub = "grey: not burned")),
      sprintf("Fire in the run (iteration 1), from its yearly fire transition maps: how often each cell burned, its highest severity, and when it last burned.%s", relief)) }

  # ---- maps: harvest -----------------------------------------------------------------------------------------------------------
  if (any(n_harv > 0)) {
    yb <- c(y0, 1995, 2005, 2015, y1 + 1); yb <- unique(yb[yb >= y0 & yb <= y1 + 1]); ylab <- sprintf("%d-%d", head(yb, -1) + c(1, rep(0, length(yb) - 2)), tail(yb, -1) - 1)
    harv_km2 <- sum(n_harv > 0 & inz) * prod(res(el)) / 1e6; pk <- sort(unique(hkind[hkind > 0]))
    map_figure("harvest", sprintf("Forest harvest, %d-%d", y0 + 1, y1), list(
      list(k = ifelse(n_harv == 0, NA, pmin(n_harv, 3L)), cols = c("#e0b43a", "#a0612a", "#3d230b"), lab = c("1", "2", "3+"), title = "Times harvested", sub = sprintf("%.0f km2 harvested at least once; grey: not harvested", harv_km2)),
      list(k = ifelse(hkind == 0, NA, match(hkind, pk)), cols = HARV_COLS[pk], lab = HARV_LAB[pk], key = TRUE, title = "Most intensive harvest", sub = "clearcut over salvage over selection"),
      list(k = ifelse(is.na(last_h), NA, findInterval(last_h, yb, rightmost.closed = TRUE)), cols = colorRampPalette(c("#efe3bd", "#b8894a", "#4a2c10"))(length(yb) - 1), lab = ylab,
           title = "Year of the last harvest", sub = "grey: not harvested")),
      sprintf("Forest harvest in the run (iteration 1), from its yearly harvest transition maps (the Forest Harvest groups mapped by the transition group output filter): how often each cell was harvested, its most intensive harvest type, and when it was last harvested.%s", relief)) }

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
    for (j in rev(seq_along(gr))) polygon(c(yy, rev(yy)), c(cs[, j], rev(if (j > 1) cs[, j - 1] else rep(0, length(yy)))), col = COVER_COLS[gr[j]], border = NA)
    ptitle(1, "Area by cover group"); under_legend(gr, fill = COVER_COLS[gr])
    low(); D <- sweep(M, 2, M[1, ]); plot(NA, xlim = range(yy), ylim = range(D), xlab = "", ylab = sprintf("Change since %d (km2)", y0), bty = "l"); hgrid(); abline(h = 0, col = MUTED, lty = 2)
    for (g in gr) lines(yy, D[, g], col = COVER_COLS[g], lwd = 2); ptitle(2, sprintf("Change since %d", y0)); under_legend(gr, col = COVER_COLS[gr], lwd = 2) })

  # ---- charts: transitions, simulated and recorded ---------------------------------------------------------------------------
  tr <- X$trans[TransitionGroup %in% FAMILIES, .(km2 = sum(ha) / 100), by = .(Timestep, Family = TransitionGroup)]
  fams <- FAMILIES[FAMILIES %in% tr$Family]
  if (length(fams)) {
    ob <- if (!is.null(observed) && nrow(observed)) { o <- copy(observed); o[, Family := sub(":.*$", "", trimws(sub(" \\[Type\\]$", "", TransitionGroup)))]; o[Family %in% fams, .(km2 = sum(Area)), by = .(Timestep, Family)] } else NULL
    nc <- min(3, length(fams)); nr <- ceiling(length(fams) / nc); yrs <- (y0 + 1):y1
    chart_figure("transitions", "Transitions per year", sprintf("Area of each transition family per year in the run (bars)%s.", if (is.null(ob)) "" else ", and in the Build's historical record (points; the Build's transition summary, which double counted urbanization and intensification in Builds run before 24 October 2026: rerun stage 6)"),
      nr, nc, draw = function() for (i in seq_along(fams)) { s <- tr[Family == fams[i]][match(yrs, Timestep), km2]; s[is.na(s)] <- 0
        o <- if (!is.null(ob)) ob[Family == fams[i]][match(yrs, Timestep), km2] else NULL
        top <- max(c(s, o), 0.01, na.rm = TRUE) * 1.1
        b <- barplot(s, col = "#8da9c4", border = NA, space = .15, ylim = c(0, top), ylab = "km2 per year"); hgrid(); barplot(s, col = "#8da9c4", border = NA, space = .15, add = TRUE, axes = FALSE)
        at <- which(yrs %% 5 == 0); axis(1, at = b[at], labels = yrs[at], cex.axis = .75)
        if (!is.null(o)) points(b, o, pch = 16, cex = .6, col = INK)
        ptitle(i, sprintf("%s: %.0f km2 simulated%s", fams[i], sum(s), if (!is.null(o)) sprintf(", %.0f recorded", sum(o, na.rm = TRUE)) else "")) }) }

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
      lines(yy, te, lwd = 2, col = INK); ptitle(1, sprintf("Carbon stocks: %.0f to %.0f Tg C", te[1], te[length(te)])); under_legend(c(names(pc), "Total"), fill = c(pc, NA), lty = c(rep(NA, 4), 1), col = c(rep(NA, 4), INK))
      low(); d <- diff(te); b <- barplot(d, col = ifelse(d >= 0, "#2b8152", "#a81d1a"), border = NA, ylab = "Tg C per year"); hgrid(); abline(h = 0, col = MUTED)
      at <- which(yy[-1] %% 5 == 0); axis(1, at = b[at], labels = yy[-1][at], cex.axis = .75); ptitle(2, sprintf("Net ecosystem carbon balance (mean %+.2f Tg C/yr)", mean(d))) }) }

  # ---- charts: carbon fluxes -------------------------------------------------------------------------------------------------
  if (!is.null(X$flows) && nrow(X$flows)) {
    fl <- X$flows[, .(Tg = sum(Mg) / 1e6), by = .(Timestep, FlowGroup)]; yy <- sort(unique(fl$Timestep))
    g <- function(nm) { v <- fl[FlowGroup == nm][match(yy, Timestep), Tg]; v[is.na(v)] <- 0; v }
    chart_figure("carbon_fluxes", "Carbon fluxes", "(a) Net primary productivity, heterotrophic respiration and net ecosystem productivity. (b) Losses to fire emissions and harvest, and net biome productivity (net ecosystem productivity less those losses).", 1, 2, h = 1150, draw = function() {
      low(); a <- cbind(NPP = g("Net Primary Productivity"), Rh = g("Emission: Total Rh"), NEP = g("Net Ecosystem Productivity"))
      plot(NA, xlim = range(yy), ylim = range(c(0, a)), xlab = "", ylab = "Tg C per year", bty = "l"); hgrid(); abline(h = 0, col = MUTED, lty = 2)
      fc <- c(NPP = "#2b8152", Rh = "#a6611a", NEP = "#3b6ea8"); for (k in colnames(a)) lines(yy, a[, k], col = fc[k], lwd = 2)
      ptitle(1, "Productivity and respiration"); under_legend(c("Net primary productivity", "Heterotrophic respiration", "Net ecosystem productivity"), col = fc, lwd = 2)
      low(); L <- rbind(Fire = g("LULC: Emission"), Harvest = g("LULC: Harvest")); nbp <- g("Net Biome Productivity")
      b <- barplot(-L, col = c("#c93a1d", "#6b6b6b"), border = NA, ylim = range(c(-colSums(L), nbp, 0)) * 1.1, ylab = "Tg C per year"); hgrid(); abline(h = 0, col = MUTED)
      lines(b, nbp, lwd = 2, col = "#3b6ea8"); at <- which(yy %% 5 == 0); axis(1, at = b[at], labels = yy[at], cex.axis = .75)
      ptitle(2, sprintf("Losses and net biome productivity (mean %+.2f Tg C/yr)", mean(nbp)))
      under_legend(c("Fire emissions", "Harvest", "Net biome productivity"), fill = c("#c93a1d", "#6b6b6b", NA), lty = c(NA, NA, 1), col = c(NA, NA, "#3b6ea8")) }) }

  # ---- charts: carbon by secondary stratum -----------------------------------------------------------------------------------
  if (!is.null(X$unit_c) && nrow(X$unit_c) > 1 && uniqueN(X$unit_c$Unit) > 1) {
    u <- dcast(X$unit_c, Unit ~ Timestep, value.var = "Mg"); setnames(u, c("Unit", "c0", "c1")); u <- merge(u, X$unit_a, by = "Unit")
    u[, `:=`(name = sub("^[^:]*: ", "", Unit), d0 = c0 / ha, d1 = c1 / ha, chg = (c1 - c0) / ha, Tg1 = c1 / 1e6)]; u <- u[order(chg)]
    chart_figure("carbon_by_unit", "Carbon by secondary stratum", sprintf("(a) Change in mean total ecosystem carbon density, %d-%d, by secondary stratum. (b) Total ecosystem carbon in %d.", y0, y1, y1),
      1, 2, h = 300 + 60 * nrow(u), draw = function() {
        par(mar = c(4.5, 12, 3, 1)); barplot(u$chg, names.arg = u$name, horiz = TRUE, col = ifelse(u$chg >= 0, "#2b8152", "#a81d1a"), border = NA, cex.names = .7, xlab = "Mg C/ha")
        abline(v = 0, col = MUTED); ptitle(1, sprintf("Change in carbon density, %d-%d", y0, y1))
        o <- order(u$Tg1); barplot(u$Tg1[o], names.arg = u$name[o], horiz = TRUE, col = "#2b8152", border = NA, cex.names = .7, xlab = "Tg C")
        ptitle(2, sprintf("Total ecosystem carbon, %d", y1)) }) }

  rbindlist(K$rows) }
