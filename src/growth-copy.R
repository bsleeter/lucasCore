# =============================================================================
# growth-copy.R - stage 2's "Copy from another library": the growth and carbon curves of a result scenario in another lucasCore library
# =============================================================================
# Reads the five sheets stage 2 writes - Merchantable Volume Curves, Live-Tree Carbon Curves, Growth and Carbon Parameters and the
# Growth Curve Report - from the source scenario (Growth Curve Options: Source Library, Source Result Scenario Id; blank = the latest
# result scenario with curves) and writes them as this stage's outputs, so stages 3 and 4 use them as if they had been fitted here.
# The source is read straight from its SQLite file, not opened through SyncroSim: a library made with an earlier lucasCore has an older
# schema, and SyncroSim refuses to open it with this one (found 2026-10-22 when new Data Source columns were added). Ecodivision and
# state class ids are turned into names through the source's own lists. The source must use this library's definitions: every
# ecodivision x forest state class needs a curve, and every name must be in this library's lists. Copied curves do not follow later
# changes to the source.
# =============================================================================
COPY_SHEETS <- c("MerchantableVolumeCurve", "CarbonCurve", "OutputGrowthParameter", "OutputCarbonParameter")

copy_curves <- function(opt) {
  lp <- opt$CurveLibrary
  if (is.null(lp) || is.na(lp) || !nzchar(lp)) fail("Growth Curve Options: Copy from another library needs a Source Library (.ssim path)")
  lp <- normalizePath(lp, winslash = "/", mustWork = FALSE)
  if (!file.exists(lp)) fail("Source Library not found: %s", lp)
  if (identical(tolower(lp), tolower(main_library())))
    fail("Source Library is this library: use a Growth Curves scenario as a dependency instead")
  con <- DBI::dbConnect(RSQLite::SQLite(), lp, flags = RSQLite::SQLITE_RO); on.exit(DBI::dbDisconnect(con), add = TRUE)
  tb <- DBI::dbListTables(con); q <- function(sql) as.data.table(DBI::dbGetQuery(con, sql))
  if (!all(paste0("lucasCore_", COPY_SHEETS) %in% tb)) fail("Source Library %s does not use lucasCore (or predates growth curves)", basename(lp))
  sc2 <- q("SELECT ScenarioId, Name FROM core_Scenario")
  with_curves <- q("SELECT DISTINCT ScenarioId FROM lucasCore_OutputGrowthParameter")$ScenarioId
  sid <- opt$CurveScenarioId
  if (!is.null(sid) && !is.na(sid)) {
    if (!sid %in% sc2$ScenarioId) fail("Source Library %s has no scenario %d", basename(lp), sid)
    if (!sid %in% with_curves) fail("Source scenario %d (%s) has no growth curves: pick a result scenario of a run that included stage 2", sid, sc2[ScenarioId == sid, Name])
  } else {
    if (!length(with_curves)) fail("Source Library %s has no result scenario with growth curves (run stage 2 there first)", basename(lp))
    sid <- max(with_curves)
  }
  nm <- sc2[ScenarioId == sid, Name]
  say("Growth curves copied from %s, result scenario %d (%s)", lp, sid, nm)

  # every sheet, keeping this library's columns; ecodivision and state class ids -> names through the source's lists
  str2 <- q("SELECT StratumId, Name FROM stsim_Stratum"); scl2 <- q("SELECT StateClassId, Name FROM stsim_StateClass")
  got <- setNames(lapply(COPY_SHEETS, function(sh) { x <- q(sprintf("SELECT * FROM lucasCore_%s WHERE ScenarioId = %d", sh, sid))
    if ("StratumId" %in% names(x)) x[, StratumId := str2$Name[match(StratumId, str2$StratumId)]]
    if ("StateClassId" %in% names(x)) x[, StateClassId := scl2$Name[match(StateClassId, scl2$StateClassId)]]
    x }), COPY_SHEETS)
  for (sh in COPY_SHEETS) { keep <- names(as.data.table(datasheet(scn, ds(sh), optional = TRUE, empty = TRUE)))
    if (length(keep)) got[[sh]] <- got[[sh]][, intersect(keep, names(got[[sh]])), with = FALSE] }
  cw <- read_default("growth", "forest-type-crosswalk.csv"); scl <- stsim_list("StateClass"); stl <- stsim_list("Stratum")
  want <- CJ(StratumId = stl$Name, StateClassId = scl$Name[match(cw$StateClassId, scl$Id)])
  for (sh in c("MerchantableVolumeCurve", "CarbonCurve")) { x <- got[[sh]]
    bad <- setdiff(unique(c(x$StratumId, x$StateClassId)), c(stl$Name, scl$Name))
    have <- unique(x[, .(StratumId, StateClassId)]); miss <- fsetdiff(want, have)
    check(STAGE, sprintf("copied %s use this library's ecodivisions and state classes", sh), !length(bad), paste(head(bad, 5), collapse = "; "))
    check(STAGE, sprintf("copied %s cover every forest state class x ecodivision", sh), !nrow(miss) && nrow(x) > 0,
          sprintf("%d of %d cells%s", nrow(have), nrow(want), if (nrow(miss)) paste0("; missing e.g. ", paste(head(paste(miss$StratumId, miss$StateClassId, sep = " / "), 3), collapse = "; ")) else "")) }
  if (any(vapply(.checks, function(x) x$Status != "Pass", TRUE))) finish_checks()

  # the source's own Growth Curve Options: differences from this scenario's (stage 3 reads this scenario's for its FIA dead-carbon data)
  o2 <- if ("lucasCore_GrowthOptions" %in% tb) as.list(q(sprintf("SELECT * FROM lucasCore_GrowthOptions WHERE ScenarioId = %d", sid))) else NULL
  fit_cols <- c("LagYears", "MinPlotsLag", "MaximumLag", "Penalty", "MinPlotsEcodivision", "MaximumAge", "MinInventoryYear", "VolumeCapQuantile")
  diffs <- Filter(Negate(is.null), lapply(fit_cols, function(k) { a <- opt[[k]]; b <- o2[[k]]
    if (is.null(b) || !length(b)) return(NULL); if (identical(as.numeric(a), as.numeric(b)) || (all(is.na(a)) && all(is.na(b)))) NULL else sprintf("%s here %s, source %s", k, a, b) }))
  if (!is.null(o2) && length(o2) && length(diffs)) say("Growth Curve Options differ from the source's: %s", paste(diffs, collapse = "; "))
  else if (!is.null(o2) && !length(o2[[1]])) say("The source scenario's Growth Curve Options were empty (it used the package defaults)")

  for (sh in COPY_SHEETS) write_ds(got[[sh]], sh)
  rep <- if ("lucasCore_OutputGrowthReport" %in% tb) q(sprintf("SELECT FileName FROM lucasCore_OutputGrowthReport WHERE ScenarioId = %d", sid)) else data.table()
  rf <- if (nrow(rep) && !is.na(rep$FileName[1])) file.path(paste0(lp, ".data"), sprintf("Scenario-%d", sid), "lucasCore_OutputGrowthReport", basename(rep$FileName[1])) else NA_character_
  if (!is.na(rf) && file.exists(rf)) { to <- file.path(TD(), basename(rf)); file.copy(rf, to, overwrite = TRUE); write_ds(data.frame(FileName = to), "OutputGrowthReport") }
  check(STAGE, "growth curves copied from another library", TRUE, sprintf("%s, scenario %d (%s): %d volume and %d carbon curve rows", basename(lp), sid, nm,
                                                                         nrow(got$MerchantableVolumeCurve), nrow(got$CarbonCurve)))
  invisible(got) }   # the copied sheets: stage 2 needs the carbon curves for site productivity (outputs reach the library only after the run)
