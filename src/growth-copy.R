# =============================================================================
# growth-copy.R - stage 2's "Copy from another library": the growth and carbon curves of a result scenario in another lucasCore library
# =============================================================================
# Reads the five sheets stage 2 writes - Merchantable Volume Curves, Live-Tree Carbon Curves, Growth and Carbon Parameters and the
# Growth Curve Report - from the source scenario (Growth Curve Options: Source Library, Source Result Scenario Id; blank = the latest
# result scenario with curves) and writes them as this stage's outputs, so stages 3 and 4 use them as if they had been fitted here.
# The source must use this library's definitions: every ecodivision x forest state class needs a curve, and every name must be in this
# library's lists. The source library must not be running. Copied curves do not follow later changes to the source.
# =============================================================================
COPY_SHEETS <- c("MerchantableVolumeCurve", "CarbonCurve", "OutputGrowthParameter", "OutputCarbonParameter")

copy_curves <- function(opt) {
  lp <- opt$CurveLibrary
  if (is.null(lp) || is.na(lp) || !nzchar(lp)) fail("Growth Curve Options: Copy from another library needs a Source Library (.ssim path)")
  lp <- normalizePath(lp, winslash = "/", mustWork = FALSE)
  if (!file.exists(lp)) fail("Source Library not found: %s", lp)
  if (identical(tolower(lp), tolower(normalizePath(env$LibraryFilePath, winslash = "/", mustWork = FALSE))))
    fail("Source Library is this library: use a Growth Curves scenario as a dependency instead")
  L2 <- suppressWarnings(rsyncrosim::ssimLibrary(lp))
  if (!"lucasCore" %in% tryCatch(rsyncrosim::packages(L2)$name, error = function(e) character())) fail("Source Library %s does not use lucasCore", basename(lp))
  sc2 <- as.data.table(rsyncrosim::scenario(L2, summary = TRUE))
  has_curves <- function(id) nrow(suppressWarnings(datasheet(rsyncrosim::scenario(L2, id), ds("OutputGrowthParameter"), optional = TRUE))) > 0
  sid <- opt$CurveScenarioId
  if (!is.null(sid) && !is.na(sid)) {
    if (!sid %in% sc2$ScenarioId) fail("Source Library %s has no scenario %d", basename(lp), sid)
    if (!has_curves(sid)) fail("Source scenario %d (%s) has no growth curves: pick a result scenario of a run that included stage 2", sid, sc2[ScenarioId == sid, Name])
  } else {
    cand <- sort(sc2[IsResult == "Yes", ScenarioId], decreasing = TRUE); sid <- NA
    for (id in cand) if (has_curves(id)) { sid <- id; break }
    if (is.na(sid)) fail("Source Library %s has no result scenario with growth curves (run stage 2 there first)", basename(lp))
  }
  S2 <- rsyncrosim::scenario(L2, sid); nm <- sc2[ScenarioId == sid, Name]
  say("Growth curves copied from %s, result scenario %d (%s)", lp, sid, nm)

  # every sheet, keeping this library's columns; names as text (the lists must match)
  got <- setNames(lapply(COPY_SHEETS, function(sh) as.data.table(datasheet(S2, ds(sh), optional = TRUE, lookupsAsFactors = FALSE))), COPY_SHEETS)
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
  # (a source library made with an older lucasCore has an older Growth Curve Options schema, which cannot be read with this one)
  o2 <- tryCatch(as.list(as.data.table(rsyncrosim::datasheet(S2, ds("GrowthOptions"), optional = TRUE, lookupsAsFactors = FALSE))),
                 error = function(e) { say("The source's Growth Curve Options could not be read (a library made with an older lucasCore): options not compared"); NULL })
  fit_cols <- c("LagYears", "MinPlotsLag", "MaximumLag", "Penalty", "MinPlotsEcodivision", "MaximumAge", "MinInventoryYear", "VolumeCapQuantile")
  diffs <- Filter(Negate(is.null), lapply(fit_cols, function(k) { a <- opt[[k]]; b <- o2[[k]]
    if (is.null(b) || !length(b)) return(NULL); if (identical(as.numeric(a), as.numeric(b)) || (all(is.na(a)) && all(is.na(b)))) NULL else sprintf("%s here %s, source %s", k, a, b) }))
  if (!is.null(o2) && length(o2) && length(diffs)) say("Growth Curve Options differ from the source's: %s", paste(diffs, collapse = "; "))
  else if (!is.null(o2) && !length(o2[[1]])) say("The source scenario's Growth Curve Options were empty (it used the package defaults)")

  for (sh in COPY_SHEETS) write_ds(got[[sh]], sh)
  rep <- as.data.table(datasheet(S2, ds("OutputGrowthReport"), optional = TRUE, lookupsAsFactors = FALSE))
  if (nrow(rep) && !is.na(rep$FileName[1]) && file.exists(rep$FileName[1])) {
    to <- file.path(TD(), basename(rep$FileName[1])); file.copy(rep$FileName[1], to, overwrite = TRUE); write_ds(data.frame(FileName = to), "OutputGrowthReport") }
  check(STAGE, "growth curves copied from another library", TRUE, sprintf("%s, scenario %d (%s): %d volume and %d carbon curve rows", basename(lp), sid, nm,
                                                                         nrow(got$MerchantableVolumeCurve), nrow(got$CarbonCurve)))
  invisible(sid) }
