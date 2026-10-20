# =============================================================================
# u-spike.R - Phase A spike (development only): how does one stage's output become another scenario's input?
# =============================================================================
# Logs what this scenario sees in stsim_InitialConditionsSpatial (its own rows, or a dependency's), then tries to save a row into
# another scenario named "Spike Target" during the run, and reads it back.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
say("library file in this run: %s", env$LibraryFilePath)
ic <- as.data.table(datasheet(scn, "stsim_InitialConditionsSpatial", optional = TRUE, lookupsAsFactors = FALSE))
say("A. stsim_InitialConditionsSpatial seen by this run: %d row(s); StratumFileName = %s; exists = %s", nrow(ic),
    if (nrow(ic)) ic$StratumFileName[1] else "-", if (nrow(ic)) file.exists(ic$StratumFileName[1]) else "-")
tg <- tryCatch(rsyncrosim::scenario(prj, "Spike Target"), error = function(e) e)
if (inherits(tg, "error")) say("B. could not open scenario 'Spike Target': %s", conditionMessage(tg)) else {
  r <- tryCatch({ saveDatasheet(tg, data.frame(StudyAreaStates = "Written by the spike stage"), ds("BuildOptions")); "saved" }, error = function(e) conditionMessage(e))
  back <- tryCatch(datasheet(tg, ds("BuildOptions"))$StudyAreaStates, error = function(e) conditionMessage(e))
  say("B. save into 'Spike Target' (id %d) during the run: %s; read back in the run: %s", scenarioId(tg), r, paste(back, collapse = ", ")) }
