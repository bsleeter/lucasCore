# =============================================================================
# 4-initial-stocks.R - stage 4: spin-up and initial carbon stocks by age and last disturbance, per ecodivision x forest state class
# =============================================================================
# Replaces lucasbuilder's spin-up (3-spinup-pre.R, an stsim run, 4-spinup-post.R) with the CBM dead-carbon dynamics of src/dom.R:
# repeated cycles of growth to the return interval ended by high-severity fire, solved directly as their limit (fixed point), then
# the most recent disturbance - high-severity fire or clearcut - then growth to every age 0..MaximumAge. Live pools come from the
# stage 2 carbon curves; turnover and decay are the flow multipliers stage 3 wrote (read back here, so the spin-up uses exactly the
# calibrated rates the model runs with); disturbances are the LUCAS event flows. The return interval of each cell is the one stage 3
# calibrated with. Output: Initial Stock Curves, one row per cell x last disturbance x age, every pool in Mg C/ha - the table stage 8
# maps to initial stock rasters with the fire history (as the CONUS 1km build did with its fire and harvest state attribute tables).
# Needs stages 2 and 3 (same pipeline, or dependencies on their results).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
for (f in c("flows.R", "dom.R")) source(pkg_file("src", f))
STAGE <- "4 Initial Stocks"
progressBar(type = "begin", totalSteps = 4)

cc <- as.data.table(datasheet(scn, ds("CarbonCurve"), optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(cc)) fail("Live-Tree Carbon Curves are empty: run stage 2 first (same pipeline, or depend on a stage 2 result)")
dc <- as.data.table(datasheet(scn, ds("OutputDecayCalibration"), optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(dc)) fail("Decay Calibration is empty: run stage 3 first (same pipeline, or depend on a stage 3 result)")
fm <- as.data.table(datasheet(scn, "stsim_FlowMultiplier", optional = TRUE, lookupsAsFactors = FALSE))
fm <- fm[is.na(AgeMin) & grepl("^(Biomass Turnover|Decay|Emission|Transfer):", FlowGroupId) & grepl("^Forest:", StateClassId)]
if (!nrow(fm)) fail("no forest turnover and decay flow multipliers: run stage 3 first")
setnames(cc, c("StratumId", "StateClassId"), c("Stratum", "StateClass"))
fo <- fread(pkg_file("defaults", "stockflow", "stsim_FlowOrder.csv")); ev <- fread(pkg_file("defaults", "stockflow", "event-pathways.csv"), na.strings = "")
LAST <- c(Fire = "Fire: High Severity [Type]", Clearcut = "Forest Harvest: Forest Clearcut [Type]")
cells <- unique(cc[, .(Stratum, StateClass)])
cells[, ri := as.integer(dc$ReturnInterval[match(paste(Stratum, StateClass), paste(dc$StratumId, dc$StateClassId))])]
if (anyNA(cells$ri)) fail("Decay Calibration has no return interval for %d cells", cells[is.na(ri), .N])
say("Spin-up: %d cells, return intervals %d-%d yr; last disturbance: %s", nrow(cells), min(cells$ri), max(cells$ri), paste(names(LAST), collapse = ", "))
progressBar()

# ---- spin-up per cell -----------------------------------------------------------------------------------------------
POOL_COLS <- c(names(LIVE_POOLS), names(DOM_POOLS))
res <- vector("list", nrow(cells)); bal <- 0
for (i in seq_len(nrow(cells))) { s <- cells$Stratum[i]; c0 <- cells$StateClass[i]; ri <- cells$ri[i]
  x <- fm[StratumId == s & StateClassId == c0]
  vals <- setNames(as.numeric(x$Value), sub(" \\[Type\\]$", "", x$FlowGroupId))
  m <- dom_matrices(vals, fo)                                   # already calibrated: no further multipliers
  live <- as.matrix(cc[Stratum == s & StateClass == c0][order(Age), names(LIVE_POOLS), with = FALSE])
  ages <- cc[Stratum == s & StateClass == c0][order(Age), Age]
  hist <- disturbance_matrices(ev, LAST[["Fire"]], c0, ri)
  res[[i]] <- rbindlist(lapply(names(LAST), function(d) {
    dom <- dom_by_age(m, live, ri, hist, disturbance_matrices(ev, LAST[[d]], c0, ri))
    # one more check of the dynamics: a year of decay and turnover from age a lands on age a + 1
    a <- min(50L, nrow(dom) - 2L); nxt <- m$A %*% dom[a + 1, ] + m$Apost %*% (m$Tm %*% live[a + 1, ])
    bal <<- max(bal, max(abs(nxt - dom[a + 2, ])))
    data.table(StratumId = s, StateClassId = c0, TransitionGroupId = LAST[[d]], Age = ages, live, dom) })) }
out <- rbindlist(res)
out[, `:=`(TotalLive = rowSums(.SD[, names(LIVE_POOLS), with = FALSE]), TotalDOM = rowSums(.SD[, names(DOM_POOLS), with = FALSE]))]
progressBar()

# ---- checks ---------------------------------------------------------------------------------------------------------
check(STAGE, "every forest cell has stocks for each last disturbance at every age", nrow(out) == nrow(cells) * length(LAST) * uniqueN(cc$Age),
      sprintf("%d rows", nrow(out)))
check(STAGE, "every pool is finite and non-negative", all(sapply(out[, ..POOL_COLS], function(v) all(is.finite(v) & v >= -1e-9))))
check(STAGE, "one year of decay and turnover from age 50 lands on age 51", bal < 1e-8, sprintf("max error %.2e Mg C/ha", bal))
yr <- out[Age == 0, .(snag = mean(SnagStem + SnagBranch), down = mean(AGM + AGF)), by = TransitionGroupId]
check(STAGE, "fire leaves more snags at age 0 than clearcut does", yr[TransitionGroupId == LAST[["Fire"]], snag] > yr[TransitionGroupId == LAST[["Clearcut"]], snag],
      sprintf("mean snags at age 0: fire %.1f, clearcut %.1f Mg C/ha", yr[TransitionGroupId == LAST[["Fire"]], snag], yr[TransitionGroupId == LAST[["Clearcut"]], snag]))
s100 <- out[Age == 100, lapply(.SD, mean), .SDcols = c("TotalLive", "TotalDOM", "SnagStem", "AGS", "BGS")]
say("Mean stocks at age 100 (Mg C/ha): live %.1f, DOM %.1f (snag stem %.1f, AG slow %.1f, BG slow %.1f)", s100$TotalLive, s100$TotalDOM, s100$SnagStem, s100$AGS, s100$BGS)
progressBar()

r4 <- function(v) round(v, 4)
write_ds(out[, c(list(StratumId = StratumId, StateClassId = StateClassId, TransitionGroupId = TransitionGroupId, Age = Age),
                 lapply(.SD, r4)), .SDcols = c(POOL_COLS, "TotalLive", "TotalDOM")], "InitialStockCurve")
progressBar()
finish_checks()
progressBar(type = "end")
