# =============================================================================
# wood-products-run.R - a run's removals for the wood products model, and its figures; sourced by stage 18 (src/18-wood-products.R),
# and testable outside SyncroSim on a library file (tests/phaseZ30-wood-products.R reads one, read-only)
# =============================================================================
# wp_run_removals(lib, rid, P) reads the run's flows to Forestry Sector (flow group "LULC: Harvest": the live and dead wood harvest
# and land-use change move there) by SQL, by iteration, year, strata, state class and transition type, and returns them in the form
# src/wood-products.R takes: Iteration, Year, Region, ForestType, Cause, Carbon (Mg C).
#   Region  Smith's region of the cell: the state from the secondary stratum (a state, or a county "Name State"), else the tertiary;
#           Oregon and Washington split at the Cascade crest by the primary stratum (ecodivision: Marine and Marine Mountains are PNW
#           West). A study area whose strata name no state takes the Region option (one of the ten for every cell).
#   Cause   Clearing for Urbanization and Ag Expansion transitions (land clearing), Harvest for every other (clearcut, selection,
#           salvage).
# A stand-alone projection is joined to its historical run (find_history, src/run-figures.R): the history's flows up to the year the
# projection starts from, the projection's after it. The history's iterations are recycled when the projection has more.
# wp_figures() draws the stage's figures (the run figures' format: "Figure N" header, a note line, lettered base R panels).
# =============================================================================
suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(data.table) })

WP_CLEARING <- "^(Urbanization|Ag Expansion)"

# the run's flows to Forestry Sector, summed by iteration, year, strata, from-state class and transition type
wp_read_flows <- function(lib, rid) {
  con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); on.exit(dbDisconnect(con))
  if (!dbExistsTable(con, "stsim_OutputFlow")) stop(sprintf("scenario %d has no flow output", rid))
  g <- dbGetQuery(con, "SELECT FlowGroupId FROM stsim_FlowGroup WHERE Name = 'LULC: Harvest'")$FlowGroupId
  if (!length(g)) stop("this library has no 'LULC: Harvest' flow group: is it a lucasCore Build?")
  tert <- dbExistsTable(con, "stsim_TertiaryStratum")
  x <- as.data.table(dbGetQuery(con, sprintf(
    "SELECT o.Iteration, o.Timestep AS Year, p.Name AS Primary_, s.Name AS Secondary, %s AS Tertiary, c.Name AS Class, t.Name AS TransitionType, SUM(o.Amount) AS Carbon
     FROM stsim_OutputFlow o LEFT JOIN stsim_Stratum p ON p.StratumId = o.FromStratumId LEFT JOIN stsim_SecondaryStratum s ON s.SecondaryStratumId = o.FromSecondaryStratumId
     %s LEFT JOIN stsim_StateClass c ON c.StateClassId = o.FromStateClassId LEFT JOIN stsim_TransitionType t ON t.TransitionTypeId = o.TransitionTypeId
     WHERE o.ScenarioId = %d AND o.FlowGroupId IN (%s) GROUP BY o.Iteration, o.Timestep, p.Name, s.Name, %s, c.Name, t.Name",
    if (tert) "r.Name" else "NULL", if (tert) "LEFT JOIN stsim_TertiaryStratum r ON r.TertiaryStratumId = o.FromTertiaryStratumId" else "",
    rid, paste(g, collapse = ","), if (tert) "r.Name" else "NULL")))
  setnames(x, "Primary_", "Primary")
  nit <- dbGetQuery(con, sprintf("SELECT COUNT(DISTINCT Iteration) n FROM stsim_OutputStratumState WHERE ScenarioId = %d", rid))$n
  yr <- dbGetQuery(con, sprintf("SELECT MIN(Timestep) y0, MAX(Timestep) y1 FROM stsim_OutputStratumState WHERE ScenarioId = %d", rid))
  if (!length(nit) || !nit) stop(sprintf("scenario %d has no ST-Sim output: is it a result of an ST-Sim run?", rid))
  x <- x[Carbon > 1e-3]   # under a kilogram is rounding (a transition's flows booked to the class it made); a subset drops attributes: set them after
  setattr(x, "iterations", nit); setattr(x, "start", yr$y0); setattr(x, "end", yr$y1)
  x
}

# The Smith region of each strata combination. pkg: the package folder (its strata lists); region: the Region option or NA.
wp_regions <- function(x, P, pkg, region = NA_character_) {
  u <- unique(x[, .(Primary, Secondary, Tertiary)])
  if (!is.na(region) && nzchar(region)) {
    if (!region %in% P$regions$Region) stop(sprintf("Region '%s' is not one of %s", region, paste(P$regions$Region, collapse = ", ")))
    return(u[, Region := region][]) }
  states <- fread(file.path(pkg, "defaults", "strata", "states-list.csv")); counties <- fread(file.path(pkg, "defaults", "strata", "counties-list.csv"))
  eco <- fread(file.path(pkg, "defaults", "strata", "ecodivisions-list.csv"))
  state_of <- function(nm) { v <- sub("^[^:]*: *", "", nm); out <- rep(NA_character_, length(v))
    k <- v %in% states$Name; out[k] <- v[k]
    j <- !k & v %in% counties$Name; out[j] <- states$Name[match(counties$Id[match(v[j], counties$Name)] %/% 1000L, states$Id)]
    out }
  u[, State := state_of(Secondary)]; u[is.na(State), State := state_of(Tertiary)]
  u[State == "District of Columbia", State := "Maryland"]   # Smith's Northeast
  bad <- u[is.na(State)]
  if (nrow(bad)) stop(sprintf("the strata name no state (secondary: %s): choose the Region on the Wood Products page", paste(head(unique(bad$Secondary), 3), collapse = ", ")))
  rs <- P$regions[, .(State = unlist(strsplit(States, ";"))), by = .(Region, Ecodivisions)]
  west <- eco[Id %in% as.integer(strsplit(P$regions[Region == "PWW", Ecodivisions], ";")[[1]]), Name]
  u[, Region := rs[!duplicated(State)][match(u$State, State), Region]]
  u[State %in% c("Oregon", "Washington"), Region := fifelse(Primary %in% west, "PWW", "PWE")]
  if (u[, anyNA(Region)]) stop("no Smith region for ", paste(unique(u[is.na(Region), State]), collapse = ", "))
  u[]
}

# The run's removals (a projection joined to its historical run). Returns list(rem, start = the first year of flows, proj_start =
# the year the projection starts from (NA without one), history = the historical run id or NA, iterations, causes = carbon by
# transition type and cause, regions = carbon by region; both per iteration).
wp_run_removals <- function(lib, rid, P, pkg, region = NA_character_) {
  x <- wp_read_flows(lib, rid); start <- attr(x, "start"); end <- attr(x, "end"); nit <- attr(x, "iterations")
  hid <- if (exists("find_history")) find_history(lib, rid) else NA_integer_
  ps <- NA_integer_
  if (!is.na(hid)) { h <- wp_read_flows(lib, hid); h0 <- attr(h, "start")
    if (h0 >= start) stop(sprintf("historical run %d starts in %d, not before the projection (%d)", hid, h0, start))
    nh <- attr(h, "iterations"); h <- h[Year <= start]
    h <- rbindlist(lapply(seq_len(nit), function(i) h[Iteration == ((i - 1L) %% nh) + 1L][, Iteration := i]))
    x <- rbind(h, x[Year > start]); ps <- start; start <- h0 }
  if (!nrow(x)) stop(sprintf("run %d moved no carbon to Forestry Sector: there is no harvest or land clearing to follow", rid))
  rg <- wp_regions(x, P, pkg, region)
  x <- merge(x, rg[, .(Primary, Secondary, Tertiary, Region)], by = c("Primary", "Secondary", "Tertiary"), all.x = TRUE, sort = FALSE)
  x[, Cause := fifelse(grepl(WP_CLEARING, TransitionType), "Clearing", "Harvest")]
  rem <- x[, .(Carbon = sum(Carbon)), by = .(Iteration, Year, Region, ForestType = Class, Cause)]
  # the model's first year: the run's first flows, the year after its initial conditions (a projection: its history's)
  list(rem = rem, start = start + 1L, end = end, proj_start = ps, history = hid, iterations = nit,
       causes = x[, .(Carbon = sum(Carbon) / nit), by = .(TransitionType, Cause)][order(-Carbon)],
       regions = x[, .(Carbon = sum(Carbon) / nit), by = Region][order(-Carbon)])
}
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a

# ---- figures ---------------------------------------------------------------------------------------------------------------
# m: wp_model(); s: wp_summary(m); outdir; note: the line under each title. Returns one row per PNG (Figure, Title, Caption, FileName).
wp_figures <- function(m, s, outdir, note, proj_start = NA) {
  INK <- "#20211f"; MUTED <- "#55534c"; GRID <- "#e3e1db"
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE); rows <- list(); n <- 0L
  fig <- function(slug, title, caption, nr, nc, draw, w = 2400, h = 700 * nr + 260) {
    n <<- n + 1L; f <- file.path(outdir, sprintf("Fig%02d_%s.png", n, slug))
    png(f, width = w, height = h, res = 200, bg = "white"); on.exit(dev.off())
    par(mfrow = c(nr, nc), oma = c(0, 0, 4.2, 0), mar = c(4.5, 5, 3, 1), family = "sans", col.axis = MUTED, col.lab = INK, las = 1, cex.axis = .8, tcl = -.25, mgp = c(2.6, .5, 0))
    draw()
    mtext(sprintf("Figure %d. %s", n, title), outer = TRUE, side = 3, line = 2.4, adj = 0.01, cex = 1.15, font = 2, col = INK)
    mtext(note, outer = TRUE, side = 3, line = 1, adj = 0.01, cex = .72, col = MUTED)
    rows[[length(rows) + 1]] <<- data.table(Figure = n, Title = title, Caption = caption, FileName = f) }
  ptitle <- function(i, t) title(main = sprintf("(%s) %s", letters[i], t), adj = 0, font.main = 2, cex.main = .95, col.main = INK)
  hgrid <- function() abline(h = axTicks(2), col = GRID, lwd = .6)
  leg <- function(...) legend("topleft", ..., bty = "n", cex = .72, border = NA, inset = c(0, 0))
  A <- s[is.na(Iteration)]; v <- function(k) A[Variable == k][order(Year)]
  yy <- v("Stored")$Year; y0 <- m$start; y1 <- max(yy); sc <- 1e6   # Tg C
  mark <- function() { abline(v = y0 - 0.5, col = MUTED, lty = 2, lwd = .8); if (!is.na(proj_start)) abline(v = proj_start + 0.5, col = MUTED, lty = 3, lwd = .8) }
  pools <- c(`In use` = "InUse", Recovered = "Recovered", Landfills = "Landfill", Dumps = "Dump")
  pc <- c(`In use` = "#2b8152", Recovered = "#8cd17d", Landfills = "#8c6d31", Dumps = "#c9a26b")
  M <- sapply(pools, function(k) v(k)$Mean) / sc; cs <- t(apply(M, 1, cumsum))
  st <- v("Stored"); chg <- v("StockChange")
  fig("wood_products_stocks", "Carbon in harvested wood products",
      sprintf("(a) Carbon stored in products in use and in solid waste disposal sites (mean of the parameter draws%s), %d-%d. Before %d the stocks come from the regional harvest history scaled to the run (dashed line: the run starts). (b) Their yearly change, the storage the production approach counts (90%% interval of the draws shaded).",
              if (m$draws$central) "" else sprintf(" and run iterations; %d draws", m$draws$n), min(yy), y1, y0), 1, 2, h = 1150, draw = function() {
    plot(NA, xlim = range(yy), ylim = c(0, max(cs[, ncol(cs)], st$Upper / sc) * 1.05), xlab = "", ylab = "Tg C", bty = "l"); hgrid()
    for (j in rev(seq_len(ncol(M)))) polygon(c(yy, rev(yy)), c(cs[, j], rev(if (j > 1) cs[, j - 1] else rep(0, length(yy)))), col = pc[j], border = NA)
    polygon(c(yy, rev(yy)), c(st$Lower, rev(st$Upper)) / sc, col = adjustcolor(INK, .15), border = NA); lines(yy, st$Mean / sc, col = INK, lwd = 1.6); mark()
    ptitle(1, sprintf("Stored: %.2f Tg C in %d, %.2f in %d", st[Year == y0 - 1L, Mean] / sc %||% NA, y0 - 1L, st[Year == y1, Mean] / sc, y1)); leg(legend = names(pc), fill = pc)
    r <- chg[Year >= y0]
    plot(NA, xlim = range(r$Year), ylim = range(0, r$Lower, r$Upper) / sc * 1.05, xlab = "", ylab = "Tg C per year", bty = "l"); hgrid(); abline(h = 0, col = MUTED)
    polygon(c(r$Year, rev(r$Year)), c(r$Lower, rev(r$Upper)) / sc, col = adjustcolor("#2b8152", .25), border = NA); lines(r$Year, r$Mean / sc, col = "#2b8152", lwd = 2)
    if (!is.na(proj_start)) abline(v = proj_start + 0.5, col = MUTED, lty = 3, lwd = .8)
    ptitle(2, sprintf("Stock change in the run: mean %+.3f Tg C/yr", mean(r$Mean) / sc)) })
  rr <- function(k) v(k)[Year >= y0]
  rem <- rr("Removed"); ee <- rr("EmittedEnergy"); en <- rr("EmittedNoEnergy"); ch <- rr("StockChange")
  eu <- m$enduse[Year == y1, .(InUse = mean(InUse)), by = EndUse][order(InUse)]
  fig("wood_products_fate", "Where the removed carbon goes",
      sprintf("(a) Carbon the run moved to Forestry Sector each year (harvest and land clearing), against what the products and disposal sites emit that year (with energy capture: fuel, mill residue and discards burned for energy; without: other burning, composting, decay in landfills and dumps, and land-clearing wood not used) and the change in what they store. Emissions include the decay of wood harvested before the run. (b) Products in use in %d by end use.", y1),
      1, 2, h = 1150, draw = function() {
    yl <- range(0, rem$Mean, ee$Mean + en$Mean, ch$Mean) / sc * 1.08
    plot(NA, xlim = range(rem$Year), ylim = yl, xlab = "", ylab = "Tg C per year", bty = "l"); hgrid()
    lines(rem$Year, rem$Mean / sc, col = INK, lwd = 2); lines(ee$Year, ee$Mean / sc, col = "#c93a1d", lwd = 1.6)
    lines(en$Year, en$Mean / sc, col = "#7b4a8b", lwd = 1.6); lines(ch$Year, ch$Mean / sc, col = "#2b8152", lwd = 1.6, lty = 2)
    if (!is.na(proj_start)) abline(v = proj_start + 0.5, col = MUTED, lty = 3, lwd = .8)
    ptitle(1, sprintf("Removed: %.3f Tg C/yr; stored: %.0f%%", mean(rem$Mean) / sc, 100 * sum(ch$Mean) / sum(rem$Mean)))
    leg(legend = c("Removed", "Emitted, energy capture", "Emitted, no energy capture", "Stock change"), col = c(INK, "#c93a1d", "#7b4a8b", "#2b8152"), lty = c(1, 1, 1, 2), lwd = 1.6)
    op <- par(mar = c(4.5, 14, 3, 1)); on.exit(par(op))
    barplot(eu$InUse / sc, names.arg = eu$EndUse, horiz = TRUE, col = "#2b8152", border = NA, xlab = "Tg C", cex.names = .62, las = 1)
    ptitle(2, sprintf("In use in %d: %.2f Tg C", y1, sum(eu$InUse) / sc)) })
  rbindlist(rows)
}
