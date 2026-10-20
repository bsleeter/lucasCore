# =============================================================================
# new-library.R - create a lucasCore library: stsim + lucasCore, the stsim project definitions, strata lists, library settings
# =============================================================================
# Usage: Rscript tools/new-library.R <library.ssim> [--project=Definitions] [--secondary=States] [--tertiary="Federal Lands"]
#                                    [--rebuild-strata]
#   --secondary / --tertiary   a preset name from defaults/strata/presets.csv (States, Counties, HUC6, HUC8,
#                              EPA Level III Ecoregions, Pyromes, Federal Lands, GAP Status). Defaults: States, Federal Lands
#                              (the CONUS 1km model). A custom source: edit the row in Stratum Sources, then --rebuild-strata.
#   --rebuild-strata           rewrite the stsim Secondary/Tertiary Strata lists from Stratum Sources (replaces the lists:
#                              scenario data keyed by the old strata becomes invalid)
#
# Why this is not a stage: SyncroSim keeps only a run's scenario-scope output; project-scope sheets a stage saves during a run
# are discarded (Phase A spike, 2026-10-19: stage 0 saved 21 definition sheets and none persisted). The definitions are the
# CSVs the CONUS build loaded (Build LUCAS Model CONUS Annual NLCD FIA Update.Rmd L602-764), shipped in defaults/.
# A sheet that already has rows is left as it is and checked to contain every default Name.
# The primary strata (FIA ecodivisions, stsim_Stratum) are fixed: the growth curves are fitted on them.
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tools/new-library.R <library.ssim> [--secondary=<preset>] [--tertiary=<preset>]")
f <- normalizePath(pos[1], winslash = "/", mustWork = FALSE); pname <- opt("project", "Definitions")
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
pkgdir <- normalizePath(file.path(here, ".."), winslash = "/")
source(file.path(pkgdir, "src", "strata.R"))
rd <- function(...) fread(file.path(pkgdir, "defaults", ...), sep = ",", colClasses = "character", na.strings = "", encoding = "UTF-8")

L <- if (file.exists(f)) ssimLibrary(f) else ssimLibrary(f, packages = c("stsim", "lucasCore"))
pk <- tryCatch(packages(L)$name, error = function(e) character())
if (!"lucasCore" %in% pk) addPackage(L, "lucasCore")
P <- rsyncrosim::project(L, pname)

# library settings: no multiprocessing for build stages (they read and write whole national grids), conda off
saveDatasheet(L, data.frame(EnableMultiprocessing = FALSE, MaximumJobs = 1), "core_Multiprocessing")
op <- datasheet(L, "core_Option"); op$UseConda <- FALSE; saveDatasheet(L, op, "core_Option")

man <- rd("stsim", "manifest.csv")[order(as.integer(Order))]
bad <- 0
for (i in seq_len(nrow(man))) {
  sheet <- man$Datasheet[i]; x <- rd("stsim", paste0(sheet, ".csv"))
  x <- x[, which(vapply(x, function(v) any(!is.na(v) & nzchar(v)), TRUE)), with = FALSE]
  have <- suppressWarnings(as.data.table(datasheet(P, sheet, optional = TRUE, lookupsAsFactors = FALSE)))
  # rows SyncroSim or stsim made itself: built-in distributions (IsInternal) and the automatic group of every type (IsAuto)
  # (datasheet() does not return IsAuto: an automatic group is named "<type> [Type]", and its membership row links the type to it)
  auto <- rep(FALSE, nrow(have))
  if ("IsInternal" %in% names(have)) auto <- auto | have$IsInternal %in% TRUE
  if ("Name" %in% names(have)) auto <- auto | grepl(" \\[Type\\]$", have$Name)
  gcol <- grep("GroupId$", names(have), value = TRUE); tcol <- grep("TypeId$", names(have), value = TRUE)
  if (length(gcol) == 1 && length(tcol) == 1) auto <- auto | have[[gcol]] == paste(have[[tcol]], "[Type]")
  # built-in distributions come back without IsInternal too: a sheet holding none of the default names has nothing of ours yet
  if ("Name" %in% names(have) && "Name" %in% names(x) && !any(have$Name %in% x$Name)) auto[] <- TRUE
  internal <- have[auto]
  if (nrow(have) <= nrow(internal) || sheet == "stsim_Terminology") {      # empty, or only SyncroSim's built-in rows
    if (nrow(internal) && "Name" %in% names(x)) x <- x[!Name %in% internal$Name]
    if (sheet == "stsim_Terminology") saveDatasheet(P, as.data.frame(x), sheet, append = FALSE, force = TRUE) else saveDatasheet(P, as.data.frame(x), sheet, append = TRUE)
    n <- nrow(suppressWarnings(datasheet(P, sheet, optional = TRUE)))
    cat(sprintf("%-34s %4d rows written (%d now)\n", sheet, nrow(x), n))
  } else {
    miss <- if ("Name" %in% names(x)) setdiff(x$Name, have$Name) else character()
    cat(sprintf("%-34s kept (%d rows)%s\n", sheet, nrow(have), if (length(miss)) paste(" - MISSING:", paste(head(miss, 5), collapse = ", ")) else ""))
    bad <- bad + length(miss) }
}
if (bad) stop(bad, " default names are missing from sheets that were already filled")

# ---- secondary and tertiary strata: Stratum Sources rows (from presets unless already set), then the stsim lists -----------
presets <- strata_presets(pkgdir)
src <- as.data.table(datasheet(P, "lucasCore_StratumSource", optional = TRUE, lookupsAsFactors = FALSE))
want <- c(Secondary = opt("secondary", NA), Tertiary = opt("tertiary", NA))
for (lv in names(want)) {
  if (is.na(want[[lv]]) && nrow(src) && lv %in% src$Level) next                         # keep a row the user already has
  pn <- if (is.na(want[[lv]])) c(Secondary = "States", Tertiary = "Federal Lands")[[lv]] else want[[lv]]
  if (!pn %in% names(presets)) stop(sprintf("unknown strata preset '%s'; presets: %s", pn, paste(names(presets), collapse = ", ")))
  row <- as.data.table(presets[[pn]][STRATA_COLS]); row[, Level := lv]
  src <- rbind(src[Level != lv], row, fill = TRUE)
}
keepc <- intersect(c("Level", STRATA_COLS), names(src))
saveDatasheet(P, as.data.frame(src[, ..keepc]), "lucasCore_StratumSource", append = FALSE, force = TRUE)
rebuild <- "--rebuild-strata" %in% a || !is.na(want[["Secondary"]]) || !is.na(want[["Tertiary"]])
for (lv in c("Secondary", "Tertiary")) {
  sheet <- paste0("stsim_", lv, "Stratum"); s <- strata_row(src[Level == lv])
  have <- suppressWarnings(as.data.table(datasheet(P, sheet, optional = TRUE)))
  if (nrow(have) && !rebuild) { cat(sprintf("%-34s kept (%d rows; source %s)\n", sheet, nrow(have), s$Preset)); next }
  l <- strata_list(s, pkgdir)
  saveDatasheet(P, as.data.frame(l), sheet, append = FALSE, force = TRUE)
  cat(sprintf("%-34s %4d rows written from %s\n", sheet, nrow(suppressWarnings(datasheet(P, sheet))), s$Preset))
}
cat("strata: primary = FIA ecodivisions; secondary =", src[Level == "Secondary"]$Preset, "; tertiary =", src[Level == "Tertiary"]$Preset, "\n")
cat("library ready:", f, "\n")

# ---- the Stock-Flow Definitions scenario ------------------------------------------------------------------------------
# Fixed LUCAS stock-flow definitions (flow pathway diagram, flow order, type-group memberships, output options) in a scenario that
# stage 3 scenarios depend on. Not a stage output: SyncroSim imports a stage's output sheets in alphabetical order, so flow pathways
# (computed by stage 3) would be refused before the diagram they need had been imported.
sfd <- rsyncrosim::scenario(P, "Stock-Flow Definitions")
if (!nrow(suppressWarnings(datasheet(sfd, "stsim_FlowPathwayDiagram", optional = TRUE)))) {
  for (sh in c("stsim_FlowPathwayDiagram", "stsim_FlowOrder", "stsim_FlowTypeGroupMembership", "stsim_StockTypeGroupMembership",
               "stsim_OutputOptionsStockFlow", "stsim_OutputFilterFlows", "stsim_OutputFilterStocks")) {
    x <- rd("stockflow", paste0(sh, ".csv")); x <- x[, setdiff(names(x), c("Iteration", "Timestep")), with = FALSE]
    x <- x[, which(vapply(x, function(v) any(!is.na(v) & nzchar(v)), TRUE)), with = FALSE]
    saveDatasheet(sfd, as.data.frame(x), sh) }
  saveDatasheet(sfd, data.frame(ApplyBeforeTransitions = FALSE, ApplyEquallyRankedSimultaneously = TRUE), "stsim_FlowOrderOptions")
  cat("Stock-Flow Definitions scenario created (id", scenarioId(sfd), ")\n")
} else cat("Stock-Flow Definitions scenario kept (id", scenarioId(sfd), ")\n")
cat("library ready:", f, "\n")
