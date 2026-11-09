# =============================================================================
# 11-projection-climate.R - stage 11: the climate and CO2 flow multipliers of the projection years, from one LOCA2 run and its SSP
# =============================================================================
# A Projection Climate scenario depends on a Build result and runs this stage alone. It takes from the Build the strata grid
# (stage 1), the historical end year (Build Options) and the climate effects (Climate Options), and from its own Climate page the
# LOCA2 scenario (SSP), climate model and replicate. It writes multipliers for the historical end + 1 to the Climate page's Last Year
# (blank = 2100), each an anomaly against the climate model's own 1991-2020 normal (historical run + SSP run: the delta method), so
# 1.0 means the climate the curves and decay rates were fitted to and the series joins stage 7's PRISM years without a step from model
# bias. Projections depend on this result after their Projection Setup (tools/new-projection.R --climate): the setup has no flow spatial
# multipliers, so this result supplies that feed, and a projection needs only its own years (user decision 2026-10-24: one Build and one
# Projection Setup serve any number of climate futures).
# CO2 fertilization (to-do 46, src/co2.R): the Climate page's CO2 series (blank = Central) multiplies growth by 1 + beta ln(CO2 / the
# CO2 of the historical end year), CO2 from the SSP, beta by vegetation type, ECM share and stand age. The rows go to stsim_FlowMultiplier
# with the Build's own rows (this result's rows hide the Build's), so a projection that depends on this result gets both; the No Climate
# projection, which does not, gets no CO2 (user decision 2026-11-06).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "climate.R"))
source(pkg_file("src", "loca2.R"))
source(pkg_file("src", "co2.R"))
suppressPackageStartupMessages({ library(terra) })
STAGE <- "11 Projection Climate"
progressBar(type = "begin", totalSteps = 6)

opt <- read_ds("BuildOptions"); y1 <- opt$EndYear[1]
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StratumFileName[1])) fail("no strata rasters: this scenario must depend on a Build result")
P <- rast(ic$StratumFileName[1])
fm <- climate_flows(read_ds("ClimateOptions"), STAGE)

# ---- the run: SSP, model and replicate --------------------------------------------------------------------------------------
pc <- as.data.table(datasheet(scn, ds("ProjectionClimate"), optional = TRUE, lookupsAsFactors = FALSE))
gv <- function(k) if (nrow(pc) && k %in% names(pc)) pc[[k]][1] else NA
sc_name <- gv("ClimateScenarioId"); gcm <- gv("ClimateModelId"); rep_name <- gv("ClimateReplicateId"); last <- gv("EndYear")
co2_choice <- co2_series_name(gv("Co2Series"))
if (is.na(sc_name)) fail("Climate: choose a Scenario (SSP)")
if (is.na(last)) last <- 2100L
if (last <= y1 || last > 2100) fail("Climate: Last Year must be after the Build's historical end year (%d) and at most 2100", y1)
sl <- as.data.table(datasheet(prj, ds("ClimateScenario"), optional = TRUE, lookupsAsFactors = FALSE)); s <- sl[Name == sc_name]
if (!nrow(s)) fail("Climate: scenario '%s' is not in the project's Climate Scenarios list", sc_name)
years <- (y1 + 1):last
if (!nrow(fm)) say("Every climate effect is None in the Build's Climate Options: no climate multipliers, CO2 only")
if (!nrow(fm) && co2_choice == "None") { say("CO2 fertilization is None too: nothing to write"); finish_checks(); progressBar(type = "end"); quit(save = "no") }
out <- list(rows = data.table(), summ = data.table())
if (nrow(fm)) {
  if (is.na(gcm)) fail("Climate: choose a Climate Model")
  src <- read_data_sources(c("Loca2Folder"))
  members <- basename(list.dirs(file.path(src$Loca2Folder, gcm), recursive = FALSE))
  have <- members[vapply(members, function(m) loca2_has_run(src$Loca2Folder, gcm, m, s$Code), TRUE)]
  rnum <- function(m) as.integer(sub("^r([0-9]+).*", "\\1", m)); have <- have[order(rnum(have), have)]
  if (!length(have)) {
    ml <- as.data.table(datasheet(prj, ds("ClimateModel"), optional = TRUE, lookupsAsFactors = FALSE))
    ok <- ml$Name[vapply(ml$Name, function(g) any(vapply(basename(list.dirs(file.path(src$Loca2Folder, g), recursive = FALSE)),
                                                         function(m) loca2_has_run(src$Loca2Folder, g, m, s$Code), TRUE)), TRUE)]
    fail("LOCA2 has no %s run of %s under %s. Models with %s: %s", sc_name, gcm, src$Loca2Folder, sc_name, paste(ok, collapse = ", ")) }
  if (is.na(rep_name)) { member <- have[1]; say("Replicate: blank, so %s (the lowest-numbered of %s with %s)", member, paste(have, collapse = ", "), sc_name)
  } else if (!rep_name %in% have) { fail("LOCA2 has no %s run of %s replicate %s. Replicates with %s: %s", sc_name, gcm, rep_name, sc_name, paste(have, collapse = ", "))
  } else member <- rep_name
  label <- sprintf("LOCA2 %s %s %s", gcm, member, sc_name)
  say("Projection climate: %s, %d-%d (the Build's historical end is %d)", label, y1 + 1, last, y1)
  prm <- climate_params(fm, P, STAGE)
  if (any(vapply(.checks, function(x) x$Status != "Pass", TRUE))) finish_checks()
}
progressBar()

# ---- LOCA2 against the climate model's own 1991-2020 normal ---------------------------------------------------------------
if (nrow(fm)) {
  win <- climate_window(P)
  t0 <- Sys.time(); la <- function(var, yrs) loca2_annual(src$Loca2Folder, gcm, member, s$Code, var, yrs, win)
  LT <- la("tmean", 1991:2020); LP <- la("ppt", 1991:2020); LTn <- mean(LT); LPn <- mean(LP)
  TT <- la("tmean", c(y1, years)); PP <- la("ppt", c(y1, years))
  say("%s: annual climate read in %.1f min; model normal (1991-2020) over the study window %.1f C, %.0f mm", label,
      as.numeric(Sys.time() - t0, units = "mins"), global(LTn, "mean", na.rm = TRUE)[[1]], global(LPn, "mean", na.rm = TRUE)[[1]])
  em <- climate_emitter(fm, P, prm)
  lnrm <- climate_normals(LTn, LPn); Pl <- PP[[as.character(y1)]]
  # RAP fit: the October-September water year's rain by season from the same monthly files, against the model's own 1991-2020 normals
  SS <- NULL; if ("RAP fit" %in% fm$Model) { SS <- la("ppt_seasons", c(y1, years)); Sn <- lapply(la("ppt_seasons", 1991:2020), mean)
    say("RAP fit: water-year precipitation by season from %s monthly", label) }
  for (y in years) { Ty <- TT[[as.character(y)]]; Py <- PP[[as.character(y)]]
    wy <- if (is.null(SS)) NULL else rap_water_year(lapply(SS, `[[`, as.character(y)), lapply(SS, `[[`, as.character(y - 1)), Sn)
    em$emit(y, Ty, Py, Pl, LTn, LPn, lnrm, label, wy); Pl <- Py }
}
progressBar()

# ---- checks and the join with the Build's PRISM years --------------------------------------------------------------------
if (nrow(fm)) {
  out <- climate_finish(em, fm, P, STAGE); summ <- out$summ
  hist <- as.data.table(datasheet(scn, ds("OutputClimateSummary"), optional = TRUE, lookupsAsFactors = FALSE))
  if (nrow(hist) && "Climate" %in% names(hist)) {
    # reported, not tested: the last observed decade is one realization of the weather and the model's first decade another, with warming on top
    j <- merge(hist[Climate == "PRISM" & Timestep > y1 - 10, .(hist = mean(Mean)), by = FlowGroup],
               summ[Timestep <= y1 + 10, .(proj = mean(Mean)), by = FlowGroup], by = "FlowGroup")
    if (nrow(j)) say("Join (mean of the last historical decade -> the first projected decade): %s", paste(sprintf("%s %.3f -> %.3f", j$FlowGroup, j$hist, j$proj), collapse = "; "))
  }
  for (g in fm$FlowGroupId) with(summ[FlowGroup == g], say("%s (%s) projection: mean %.3f in %d-%d, %.3f in %d-%d", g, Model[1],
    mean(Mean[Timestep <= min(Timestep) + 9]), min(Timestep), min(Timestep) + 9, mean(Mean[Timestep > max(Timestep) - 10]), max(Timestep) - 9, max(Timestep)))
}
progressBar()

# ---- CO2 fertilization (src/co2.R) ----------------------------------------------------------------------------------------
co2 <- NULL
if (co2_choice == "None") say("CO2 fertilization: None (growth does not respond to CO2)") else {
  rdc <- function(f) fread(pkg_file("defaults", "climate", f), na.strings = "", encoding = "UTF-8")
  if (!"CO2" %in% stsim_list("FlowMultiplierType")$Name) fail("CO2 fertilization: the library has no Flow Multiplier Type 'CO2' - run tools/sync-library.R on it")
  cap <- suppressWarnings(as.numeric(gv("Co2Ceiling"))); refp <- suppressWarnings(as.numeric(gv("Co2Reference")))
  ser <- tryCatch(co2_series(rdc("co2-ssp.csv"), s$Code, years, y1, refp, cap), error = function(e) fail("CO2 fertilization: %s", conditionMessage(e)))
  stl <- stsim_list("Stratum"); idc <- intersect(c("Id", "ID", "StratumId"), names(stl))[1]
  strata <- stl$Name[match(setdiff(unique(values(P, na.rm = TRUE)[, 1]), NA), stl[[idc]])]
  if (anyNA(strata) || !length(strata)) fail("CO2 fertilization: strata raster values not in the Stratum list")
  cl <- rdc("co2-classes.csv")[StateClassId %in% stsim_list("StateClass")$Name]
  bad <- setdiff(unique(cl$FlowGroupId), stsim_list("FlowGroup")$Name)
  if (length(bad)) fail("CO2 fertilization: flow groups not in the library: %s", paste(bad, collapse = "; "))
  adj <- as.data.table(datasheet(scn, ds("Co2Adjustment"), optional = TRUE, lookupsAsFactors = FALSE))
  if (nrow(adj)) { adj[, AgeBand := co2_band_id(AgeBand)]
    bad <- adj[!StateClassId %in% cl$StateClassId, unique(StateClassId)]
    check(STAGE, "every CO2 Betas row names a class that grows (forest, shrubland, grassland, wetland, agriculture)", !length(bad), paste(bad, collapse = "; ")) }
  bands <- rdc("co2-age-bands.csv")
  bt <- co2_betas(cl, strata, co2_choice, rdc("co2-betas.csv"), bands, rdc("co2-ecm-share.csv"), if (nrow(adj)) adj else NULL)
  rows <- co2_rows(bt, ser, bands)
  lr <- ser$LnRatio[nrow(ser)]; bt[, LastMultiplier := round(pmax(0, 1 + Beta * lr), 4)]
  check(STAGE, "CO2 multipliers are between 0.5 and 2", all(between(rows$Value, 0.5, 2)), sprintf("range %.3f-%.3f", min(rows$Value), max(rows$Value)))
  say("CO2 fertilization: %s series, %s CO2 %.1f ppm in %d -> %.1f ppm in %d%s; reference %.1f ppm (%s)", co2_choice, sc_name, ser$CO2[1], years[1],
      ser$CO2[nrow(ser)], last, if (!is.na(cap)) sprintf(", held at the %.0f ppm ceiling", cap) else "", ser$Ref[1],
      if (!is.na(refp)) "the Climate page" else sprintf("the SSP's %d CO2", y1))
  for (ty in unique(bt$Type)) with(bt[Type == ty], say("  %s: beta %.3f-%.3f; multiplier in %d %.3f-%.3f", ty, min(Beta), max(Beta), last, min(LastMultiplier), max(LastMultiplier)))
  say("  CO2 Betas table: %s", if (nrow(adj)) sprintf("%d rows; %d of %d betas differ from the %s defaults", nrow(adj), bt[Source == "CO2 Betas table (edited)", .N], nrow(bt), co2_choice) else sprintf("empty, so the %s defaults", co2_choice))
  say("CO2 fertilization: %d flow multiplier rows (%d classes, %d strata, age bands for forest)", nrow(rows), uniqueN(rows$StateClassId), length(strata))
  co2 <- list(rows = rows, bt = bt, ser = ser)
}
progressBar()

# ---- outputs: the projection years only (the Build's summary rows are not carried into this result) ------------------------
if (nrow(out$rows) && "Climate" %in% stsim_list("FlowMultiplierType")$Name) out$rows[, FlowMultiplierTypeId := "Climate"]
# this scenario's rows hide the Build's, so the Build's Site Productivity and Grass and Shrub Productivity multipliers (stage 8) come along
spm <- dependency_multipliers(c("Site Productivity", "Grass and Shrub Productivity", "Cropland Productivity", "Crop Harvest", "Crop Mix", "Tidal Marsh Productivity"))
spv <- opt$SiteProductivity[1]
if (is.null(spm) && !is.null(spv) && !is.na(spv) && (identical(suppressWarnings(as.integer(spv)), 2L) || startsWith(as.character(spv), "TreeMap")))
  fail("Site Productivity is on in the Build Options, but no dependency has its flow multiplier: depend on a Build result that ran stage 8")
if (!is.null(spm)) { out$rows <- rbind(out$rows, spm[, intersect(names(spm), c("Timestep", "FlowGroupId", "FlowMultiplierTypeId", "MultiplierFileName")), with = FALSE], fill = TRUE)
  say("%s: the Build's flow multiplier carried over (%s)", paste(unique(spm$FlowMultiplierTypeId), collapse = " and "), paste(unique(spm$FlowGroupId), collapse = ", ")) }
if (nrow(out$rows)) write_stsim(out$rows, "FlowSpatialMultiplier")
if (nrow(out$summ)) write_ds(out$summ[, .(Timestep, FlowGroup, Model, Climate, Mean = round(Mean, 4), Min, Max)], "OutputClimateSummary")
if (!is.null(co2)) {
  # the Build's flow multipliers (stage 3: every carbon rate) come along, or this result's CO2 rows would hide them
  bfm <- dependency_rows("stsim_FlowMultiplier")
  if (is.null(bfm)) fail("CO2 fertilization: no dependency has flow multipliers (stage 3): depend on a Build result")
  if ("FlowMultiplierTypeId" %in% names(bfm)) bfm <- bfm[is.na(FlowMultiplierTypeId) | FlowMultiplierTypeId != "CO2"]
  bfm <- bfm[, setdiff(names(bfm), c("FlowMultiplierId", "ScenarioId")), with = FALSE]
  say("Flow multipliers: the Build's %d rows carried over, with %d CO2 rows", nrow(bfm), nrow(co2$rows))
  write_stsim(rbind(bfm, co2$rows, fill = TRUE), "FlowMultiplier")
  write_ds(co2$bt[, .(StateClassId, StratumId, AgeBand = CO2_BANDS(bands)[match(AgeBand, bands$AgeBand)], VegetationType = Type,
                      EcmShare, Beta, Source, LastMultiplier)], "OutputCo2Beta")
  write_ds(co2$ser[, .(Timestep, Scenario = sc_name, Co2 = CO2, Co2Used = Used, Reference = Ref, LnRatio = round(LnRatio, 5))], "OutputCo2Series")
}
progressBar()
finish_checks()
progressBar(type = "end")
