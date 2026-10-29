# =============================================================================
# compare-figures.R - figures that compare ST-Sim runs on one lucasCore Build (projections under different climate futures, a
# historical run and its projections, ...); sourced by stage 14 (src/14-compare-runs.R), and testable outside a run
# (dev/figures/test_compare_figures.R)
# =============================================================================
# Same format as the Build and run figures (src/figures.R, figure_kit), one line or bar colour per run:
#   charts  total ecosystem carbon and each run's difference from the baseline | carbon fluxes per year | flux means by period |
#           transitions per year | carbon by pool | land area change by cover group | a summary table
#   maps    the baseline's final-year total ecosystem carbon and each other run's difference from it
# compare_runs(lib, runs) reads the runs (src/run-figures.R's load_run): runs is a data.table of RunScenarioId and, optionally,
# Label, Colour ("#rrggbb", or SyncroSim's "a,r,g,b") and Baseline. A run that is the historical run of another listed run (its
# Projection Setup's Projection Start) is the history: drawn in black up to the year its projections start from, and added when a
# listed projection has one that is not listed. The baseline is the run ticked Baseline, else the first run that is not a history.
# compare_figures() returns one row per PNG (Figure, Title, Caption, FileName); compare_summary() the summary table.
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
  lapply(seq_along(ids), function(i) {
    col <- colour(runs$Colour[i]); if (is.na(col)) { col <- if (hist[i]) INK else COMPARE_PAL[k %% length(COMPARE_PAL) + 1L] }
    if (!hist[i]) k <<- k + 1L
    lab <- runs$Label[i]; if (is.na(lab) || !nzchar(lab)) lab <- nm(ids[i])
    list(rid = ids[i], label = lab, col = col, hist = hist[i], base = i == b, X = load_run(lib, ids[i])) }) }

# ---- per-run series --------------------------------------------------------------------------------------------------------
te_of <- function(X) if (is.null(X$stocks)) data.table(Timestep = integer(), Tg = numeric()) else X$stocks[StockGroup == "Total Ecosystem", .(Tg = sum(Mg) / 1e6), by = Timestep][order(Timestep)]
flow_of <- function(X, g) if (is.null(X$flows)) data.table(Timestep = integer(), Tg = numeric()) else X$flows[FlowGroup == g, .(Tg = sum(Mg) / 1e6), by = Timestep][order(Timestep)]
trans_of <- function(X, f) X$trans[TransitionGroup == f, .(km2 = sum(ha) / 100), by = Timestep][order(Timestep)]
at_year <- function(d, y, v = "Tg") { x <- d[Timestep == y][[v]]; if (length(x)) x[1] else NA_real_ }

# the summary table: one row per run
compare_summary <- function(R) {
  B <- Filter(function(r) r$base, R)[[1]]; tb <- te_of(B$X)
  rbindlist(lapply(R, function(r) { X <- r$X; t <- te_of(X); y0 <- X$years[1]; y1 <- X$years[2]
    tot <- function(f) { d <- trans_of(X, f); sum(d[Timestep > y0, km2]) }
    nbp <- flow_of(X, "Net Biome Productivity")[Timestep > y0]
    data.table(RunScenarioId = r$rid, Label = r$label, Role = if (r$hist) "History" else if (r$base) "Baseline" else "Run",
               StartYear = y0, EndYear = y1, CarbonStart = at_year(t, y0), CarbonEnd = at_year(t, y1),
               CarbonChange = at_year(t, y1) - at_year(t, y0),
               VsBaseline = if (r$hist || r$base) NA_real_ else at_year(t, y1) - at_year(tb, y1),
               MeanNBP = if (nrow(nbp)) mean(nbp$Tg) else NA_real_,
               Fire = tot("Fire"), Harvest = tot("Forest Harvest"), Urbanization = tot("Urbanization")) })) }

# ---- the figures -----------------------------------------------------------------------------------------------------------
# R: compare_runs(); grid: the Build's state class map; dem; label: the study area
compare_figures <- function(R, grid, dem, label, outdir) {
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

  # ---- charts: carbon fluxes per year ----------------------------------------------------------------------------------------
  FL <- c(`Net primary productivity` = "Net Primary Productivity", `Heterotrophic respiration` = "Emission: Total Rh",
          `Net ecosystem productivity` = "Net Ecosystem Productivity", `Net biome productivity` = "Net Biome Productivity")
  if (any(vapply(R, function(r) !is.null(r$X$flows) && nrow(r$X$flows) > 0, TRUE))) {
    chart_figure("carbon_fluxes", "Carbon fluxes per year", "Net primary productivity, heterotrophic respiration, net ecosystem productivity and net biome productivity (net ecosystem productivity less fire emissions and harvest) in each run, per year.",
      2, 2, h = 1900, draw = function() for (i in seq_along(FL)) { low()
        run_lines(function(X) flow_of(X, FL[i]), "Tg C per year", i, names(FL)[i], zero = i >= 3) }) }

  # ---- charts: flux means by period ------------------------------------------------------------------------------------------
  # the history as one period, the projections by decade (2024-2030, 2031-2040, ...); a bar per run that covers the period
  per <- function(y, h) if (h) rep("hist", length(y)) else sprintf("%d", as.integer(ceiling(y / 10) * 10))
  pm <- function(r, g) { d <- flow_of(r$X, g); d <- d[Timestep > r$X$years[1]]
    if (!nrow(d)) return(NULL); d[, p := per(Timestep, r$hist)]; d[, .(Tg = mean(Tg), y0 = min(Timestep), y1 = max(Timestep)), by = p] }
  FM <- c(FL[c(1, 2, 4)], `Fire emissions` = "LULC: Emission")
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

  # ---- the summary table -----------------------------------------------------------------------------------------------------
  S <- compare_summary(R); f1 <- function(x) ifelse(is.na(x), "", sprintf("%.1f", x)); f0 <- function(x) ifelse(is.na(x), "", format(round(x), big.mark = ","))
  tab <- S[, .(Run = Label, Years = sprintf("%d-%d", StartYear, EndYear), `Carbon start` = f1(CarbonStart), `Carbon end` = f1(CarbonEnd), Change = sub("^(\\d)", "+\\1", f1(CarbonChange)),
               `vs baseline` = ifelse(Role == "Baseline", "baseline", sub("^(\\d)", "+\\1", f1(VsBaseline))), `Mean NBP` = sprintf("%+.2f", MeanNBP),
               `Fire km2` = f0(Fire), `Harvest km2` = f0(Harvest), `Urbanized km2` = f0(Urbanization))]
  chart_figure("summary", "Summary of the runs", "Total ecosystem carbon (Tg C) at the start and end of each run, its change, and the difference from the baseline in the final year; mean net biome productivity (Tg C per year); and the area of fire, forest harvest and urbanization over the run.",
    1, 1, h = 300 + 110 * nrow(tab), draw = function() { par(mar = c(0, 1, 1, 1)); plot.new(); nc <- ncol(tab); x <- c(.02, .19, .29, .38, .47, .55, .64, .72, .80, .89)[seq_len(nc)]
      y <- seq(.92, by = -min(.8 / nrow(tab), .2), length.out = nrow(tab) + 1)
      text(x, y[1], names(tab), adj = c(0, .5), font = 2, cex = .8, col = INK); abline(h = (y[1] + y[2]) / 2, col = GRID)
      for (i in seq_len(nrow(tab))) { rect(-.01, y[i + 1] - .03, .0, y[i + 1] + .03, col = cols[i], border = NA)
        text(x, y[i + 1], unlist(tab[i]), adj = c(0, .5), cex = .8, col = INK) } })

  out <- rbindlist(K$rows); attr(out, "summary") <- S; out }
