# =============================================================================
# 18-wood-products.R - stage 18: the fate of the carbon an ST-Sim run harvests (harvested wood products; to-do 59)
# =============================================================================
# The run moves harvested and land-clearing wood to the Forestry Sector stock, where nothing flows out. This stage follows it through
# products in use, landfills and dumps with the USFS harvested wood products model (src/wood-products.R; parameters and sources in
# defaults/wood-products/README.md), by year, for each run iteration and parameter draw. Not spatial.
# Its own scenario, like Run Figures: depends on the run's Build result, with Wood Products naming the run (blank = the newest result
# scenario with ST-Sim output). A stand-alone projection is joined to its historical run (its Projection Setup's Projection Start), so
# the products of the historical harvest keep decaying through the projection; two projections from one history share its years
# exactly (same draws). Before the run, each region's harvest history from 1906, scaled to the run's first decade (spin-up).
# Options (Wood Products page): the run; Region (blank = from the strata); Draws (blank = 100) and Seed; LandClearingUtilized (blank
# = 0.5); Spinup (default on). Sheet Wood Products Future: the levers of a different wood products future, each blank = its default (wp_levers in
# src/wood-products.R): LeverFromYear, LeverFullYear, LongLivedShift, LifetimeMultiplier, ExtraEnergyShare, RecoveredWood,
# RecoveredPaper, DiscardEnergyShare. The log names the ones that differ from their defaults.
# Outputs: Wood Products (pools and flows by year: mean and 90% interval of the draws, per iteration and over all), Wood Products by
# End Use (mean in use), Wood Products Spin-up (the history's scaling), Wood Products Figures (PNG).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "run-figures.R")); source(pkg_file("src", "wood-products.R")); source(pkg_file("src", "wood-products-run.R"))
STAGE <- "18 Wood Products"
progressBar(type = "begin", totalSteps = 4)

lib_file <- main_library()
opt <- read_ds("WoodProductsOptions")
o <- function(k, d = NA) if (nrow(opt) && k %in% names(opt) && !is.na(opt[[k]][1]) && !(is.character(opt[[k]][1]) && !nzchar(opt[[k]][1]))) opt[[k]][1] else d
rid <- o("RunScenarioId")
if (is.na(rid)) { con <- DBI::dbConnect(RSQLite::SQLite(), lib_file, flags = RSQLite::SQLITE_RO)
  rid <- DBI::dbGetQuery(con, "SELECT MAX(ScenarioId) id FROM stsim_OutputStratumState")$id; DBI::dbDisconnect(con)
  if (is.na(rid)) fail("Wood Products: no ST-Sim result in this library yet: run a historical run or projection first, or name one on the Wood Products page")
  say("Wood Products: no run named; following the newest ST-Sim result, scenario %d", rid) }
P <- tryCatch(wp_params(pkg_file("defaults", "wood-products")), error = function(e) fail("Wood Products: the parameter tables: %s", conditionMessage(e)))
lcu <- o("LandClearingUtilized", wp_setting(P, "LandClearingUtilized"))
if (lcu < 0 || lcu > 1) fail("Wood Products: Land clearing used must be between 0 and 1 (it is %g)", lcu)
P <- wp_set(P, "LandClearingUtilized", lcu)
nd <- as.integer(o("Draws", wp_setting(P, "Draws"))); if (nd < 0) fail("Wood Products: Draws must be 0 (the published values only) or more")
seed <- as.integer(o("Seed", 1L)); spin <- !isFALSE(as.logical(o("Spinup", TRUE)))

R <- tryCatch(wp_run_removals(lib_file, rid, P, env$PackageDirectory, o("Region", NA_character_)), error = function(e) fail("Wood Products: %s", conditionMessage(e)))
con <- DBI::dbConnect(RSQLite::SQLite(), lib_file, flags = RSQLite::SQLITE_RO)
rn <- DBI::dbGetQuery(con, sprintf("SELECT Name FROM core_Scenario WHERE ScenarioId = %d", rid))$Name; DBI::dbDisconnect(con)
rn <- if (length(rn)) sub(" \\(\\[.*$", "", rn) else sprintf("result %d", rid)
say("Run %d (%s): flows %d-%d, %d iteration(s)%s", rid, rn, R$start, R$end, R$iterations,
    if (is.na(R$history)) "" else sprintf("; a projection from %d, joined to historical run %d", R$proj_start, R$history))
say("Carbon to Forestry Sector per iteration, by transition type: %s", paste(sprintf("%s (%s) %.0f Mg C", R$causes$TransitionType, R$causes$Cause, R$causes$Carbon), collapse = "; "))
say("By Smith region: %s", paste(sprintf("%s %.0f Mg C", R$regions$Region, R$regions$Carbon), collapse = "; "))
progressBar()

# a different wood products future (lucasCore 1.5.1; the Wood Products Future sheet): the page's levers, from the projection's first year (a historical run: its own)
# unless a year is given. Blank boxes are the defaults; with none set the model runs as it always has.
fut <- read_ds("WoodProductsFuture")
of <- function(k) if (nrow(fut) && k %in% names(fut) && !is.na(fut[[k]][1])) fut[[k]][1] else NA
lev_from <- as.integer(if (!is.na(of("LeverFromYear"))) of("LeverFromYear") else if (is.na(R$proj_start)) R$start else R$proj_start + 1L)
LV <- tryCatch(wp_levers(from = lev_from, full = of("LeverFullYear"), long = of("LongLivedShift"), life = of("LifetimeMultiplier"), energy = of("ExtraEnergyShare"),
                         rec_wood = of("RecoveredWood"), rec_paper = of("RecoveredPaper"), disc_energy = of("DiscardEnergyShare")),
               error = function(e) fail("Wood Products: %s", conditionMessage(e)))
if (LV$active) {
  if (lev_from > R$end) fail("Wood Products: Apply from year (%d) is after the run's last year (%d)", lev_from, R$end)
  ly <- max(P$fates$Year); lf <- function(m) P$fates[Material == m & Year == ly & Fate == "Recovered", Fraction]
  d <- c(if (LV$long != 0) sprintf("shift to long-lived products %g (default 0)", LV$long),
         if (LV$life != 1) sprintf("product lifetime multiplier %g (default 1)", LV$life),
         if (LV$energy != 0) sprintf("extra share burned for energy %g (default 0)", LV$energy),
         if (!is.na(LV$rec_wood)) sprintf("discarded wood recovered %g (default %g, the %d value)", LV$rec_wood, lf("wood"), ly),
         if (!is.na(LV$rec_paper)) sprintf("discarded paper recovered %g (default %g, the %d value)", LV$rec_paper, lf("paper"), ly),
         if (!is.na(LV$disc_energy)) sprintf("discards burned for energy %g (default %g)", LV$disc_energy, P$fates[Material == "wood" & Year == ly & Fate == "Burned with energy capture", Fraction]))
  say("A different wood products future, %s: %s", if (is.na(LV$full) || LV$full <= LV$from) sprintf("from %d", LV$from) else sprintf("phased in from %d, fully reached in %d", LV$from, LV$full), paste(d, collapse = "; "))
  if (lev_from < R$start) say("Apply from year %d is before the run's first year (%d): the spin-up years from %d on take the levers too", lev_from, R$start, lev_from)
} else {
  say("Wood products future: every parameter at its default (the published tables)")
  if (!is.na(of("LeverFromYear")) || !is.na(of("LeverFullYear"))) say("Apply from and Fully reached by are set, but no parameter differs from its default: they change nothing")
}

D <- if (nd == 0) wp_draws(P, central = TRUE) else wp_draws(P, n = nd, seed = seed)
t0 <- Sys.time()
m <- tryCatch(wp_model(R$rem, P, D, spinup = spin, start = R$start, end = R$end, levers = LV), error = function(e) fail("Wood Products: %s", conditionMessage(e)))
say("Model: %d-%d, %d iteration(s) x %s, %.1f s", min(m$years$Year), max(m$years$Year), R$iterations,
    if (D$central) "the published values (no draws)" else sprintf("%d draws (seed %d)", D$n, seed), as.numeric(Sys.time() - t0, units = "secs"))
if (length(m$unmatched)) say("Forest types with no row of their own in Smith Table 4, given the regional average (defaults/wood-products/README.md): %s", paste(m$unmatched, collapse = "; "))
if (!is.null(m$scale)) say("Spin-up: the harvest history scaled to the run's %d-%d removals: %s", R$start, R$start + 9L,
                           paste(unique(m$scale[, sprintf("%s %s x %.3g", Region, Wood, Scale)]), collapse = "; "))
progressBar()

# ---- checks ----------------------------------------------------------------------------------------------------------------
Y <- m$years[order(Iteration, Draw, Year)]
bal <- Y[, .(e = max(abs(cumsum(Removed) - Stored - cumsum(EmittedEnergy + EmittedNoEnergy))) / max(1, sum(Removed))), by = .(Iteration, Draw)]
check(STAGE, "carbon conserved: removed = stored + emitted, every iteration and draw", max(bal$e) < 1e-9, sprintf("largest error %.1e of the removals", max(bal$e)))
rr <- Y[Source == "Run", .(r = sum(Removed)), by = .(Iteration, Draw)][, .(lo = min(r), hi = max(r)), by = Iteration]
fl <- R$rem[Year >= R$start, .(f = sum(Carbon)), by = Iteration]
check(STAGE, "the model takes in every Mg C the run moved to Forestry Sector", { k <- merge(rr, fl, by = "Iteration"); nrow(k) == R$iterations && all(abs(k$lo - k$f) < 1e-6 * k$f) && all(abs(k$hi - k$f) < 1e-6 * k$f) },
      sprintf("%.0f Mg C per iteration", mean(fl$f)))

# ---- outputs ---------------------------------------------------------------------------------------------------------------
s <- wp_summary(m, interval = wp_setting(P, "Interval"))
write_ds(s[order(Variable, Iteration, Year), .(Iteration, Year, Source, Variable, Mean, Lower, Upper, RunScenarioId = rid)], "OutputWoodProducts")
write_ds(m$enduse[, .(InUse = mean(InUse)), by = .(Year, EndUse)][order(Year, -InUse), .(Year, EndUse, InUse, RunScenarioId = rid)], "OutputWoodProductsEndUse")
# (no removals in the spin-up years, e.g. Hart Mountain 2026-11-14 with no harvest: an empty table, which SyncroSim refuses to save)
if (!is.null(m$scale) && nrow(m$scale)) write_ds(m$scale[, .(Iteration, Region, Wood, RunCarbon, HistoryVolume, Scale)], "OutputWoodProductsScale")
A <- s[is.na(Iteration)]; g <- function(k, y) { z <- A[Variable == k & Year == y]; if (nrow(z)) z else data.table(Mean = 0, Lower = 0, Upper = 0) }
say("%d: %.3f Tg C stored (%.3f-%.3f), %.3f Tg C/yr stock change; %.0f%% of what the run removed is still stored (the stock gained since %d over the removals)",
    R$end, g("Stored", R$end)$Mean / 1e6, g("Stored", R$end)$Lower / 1e6, g("Stored", R$end)$Upper / 1e6, g("StockChange", R$end)$Mean / 1e6,
    100 * (g("Stored", R$end)$Mean - g("Stored", R$start - 1L)$Mean) / A[Variable == "Removed" & Source == "Run", sum(Mean)], R$start - 1L)
progressBar()

sa <- read_ds("StudyArea"); label <- study_label(sa, "Study area")
note <- sprintf("%s. Run %d (%s), %d-%d%s. USFS harvested wood products model (production approach); %s.", label, rid, rn, R$start - 1L, R$end,
                if (is.na(R$history)) "" else sprintf(" from historical run %d", R$history),
                if (D$central) "published parameter values" else sprintf("%d parameter draws per iteration", D$n))
if (LV$active) note <- paste0(note, sprintf(" A different wood products future from %d (Wood Products page).", LV$from))
figs <- tryCatch(wp_figures(m, s, file.path(TD(), "WoodProducts"), note, proj_start = R$proj_start), error = function(e) { say("Figures not drawn: %s", conditionMessage(e)); NULL })
check(STAGE, "figures drawn", !is.null(figs) && nrow(figs) > 0 && all(file.exists(figs$FileName)), if (is.null(figs)) "" else sprintf("%d PNG", nrow(figs)))
if (!is.null(figs) && nrow(figs)) write_ds(figs[, .(Figure, Title, Caption, FileName, RunScenarioId = rid)], "OutputWoodProductsFigure")
progressBar()
finish_checks()
progressBar(type = "end")
