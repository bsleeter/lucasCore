# =============================================================================
# 11-projection-climate.R - stage 11: the climate flow spatial multipliers of the projection years, from one LOCA2 run
# =============================================================================
# A Projection Climate scenario depends on a Build result and runs this stage alone. It takes from the Build the strata grid
# (stage 1), the historical end year (Build Options) and the climate effects (Climate Options), and from its own Climate page the
# LOCA2 scenario (SSP), climate model and replicate. It writes multipliers for the historical end + 1 to the Climate page's Last Year
# (blank = 2100), each an anomaly against the climate model's own 1991-2020 normal (historical run + SSP run: the delta method), so
# 1.0 means the climate the curves and decay rates were fitted to and the series joins stage 7's PRISM years without a step from model
# bias. Projections depend on this result after their Projection Setup (tools/new-projection.R --climate): the setup has no flow spatial
# multipliers, so this result supplies that feed, and a projection needs only its own years (user decision 2026-10-24: one Build and one
# Projection Setup serve any number of climate futures).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "climate.R"))
source(pkg_file("src", "loca2.R"))
suppressPackageStartupMessages({ library(terra) })
STAGE <- "11 Projection Climate"
progressBar(type = "begin", totalSteps = 5)

opt <- read_ds("BuildOptions"); y1 <- opt$EndYear[1]
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(ic) || is.na(ic$StratumFileName[1])) fail("no strata rasters: this scenario must depend on a Build result")
P <- rast(ic$StratumFileName[1])
fm <- climate_flows(read_ds("ClimateOptions"), STAGE)
if (!nrow(fm)) { say("Every climate effect is None in the Build's Climate Options: no projection multipliers to write"); finish_checks(); progressBar(type = "end"); quit(save = "no") }

# ---- the LOCA2 run --------------------------------------------------------------------------------------------------------
pc <- as.data.table(datasheet(scn, ds("ProjectionClimate"), optional = TRUE, lookupsAsFactors = FALSE))
gv <- function(k) if (nrow(pc) && k %in% names(pc)) pc[[k]][1] else NA
sc_name <- gv("ClimateScenarioId"); gcm <- gv("ClimateModelId"); rep_name <- gv("ClimateReplicateId"); last <- gv("EndYear")
if (is.na(sc_name) || is.na(gcm)) fail("Climate: choose a Scenario (SSP) and a Climate Model")
if (is.na(last)) last <- 2100L
if (last <= y1 || last > 2100) fail("Climate: Last Year must be after the Build's historical end year (%d) and at most 2100", y1)
src <- read_data_sources(c("Loca2Folder"))
sl <- as.data.table(datasheet(prj, ds("ClimateScenario"), optional = TRUE, lookupsAsFactors = FALSE)); s <- sl[Name == sc_name]
if (!nrow(s)) fail("Climate: scenario '%s' is not in the project's Climate Scenarios list", sc_name)
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
label <- sprintf("LOCA2 %s %s %s", gcm, member, sc_name); years <- (y1 + 1):last
say("Projection climate: %s, %d-%d (the Build's historical end is %d)", label, y1 + 1, last, y1)
prm <- climate_params(fm, P, STAGE)
if (any(vapply(.checks, function(x) x$Status != "Pass", TRUE))) finish_checks()
progressBar()

# ---- LOCA2 against the climate model's own 1991-2020 normal ---------------------------------------------------------------
win <- climate_window(P)
t0 <- Sys.time(); la <- function(var, yrs) loca2_annual(src$Loca2Folder, gcm, member, s$Code, var, yrs, win)
LT <- la("tmean", 1991:2020); LP <- la("ppt", 1991:2020); LTn <- mean(LT); LPn <- mean(LP)
TT <- la("tmean", c(y1, years)); PP <- la("ppt", c(y1, years))
say("%s: annual climate read in %.1f min; model normal (1991-2020) over the study window %.1f C, %.0f mm", label,
    as.numeric(Sys.time() - t0, units = "mins"), global(LTn, "mean", na.rm = TRUE)[[1]], global(LPn, "mean", na.rm = TRUE)[[1]])
em <- climate_emitter(fm, P, prm)
lnrm <- climate_normals(LTn, LPn); Pl <- PP[[as.character(y1)]]
for (y in years) { Ty <- TT[[as.character(y)]]; Py <- PP[[as.character(y)]]; em$emit(y, Ty, Py, Pl, LTn, LPn, lnrm, label); Pl <- Py }
progressBar()

# ---- checks and the join with the Build's PRISM years --------------------------------------------------------------------
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
progressBar()

# ---- outputs: the projection years only (the Build's summary rows are not carried into this result) ------------------------
write_stsim(out$rows, "FlowSpatialMultiplier")
write_ds(summ[, .(Timestep, FlowGroup, Model, Climate, Mean = round(Mean, 4), Min, Max)], "OutputClimateSummary")
progressBar()
finish_checks()
progressBar(type = "end")
