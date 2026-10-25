# =============================================================================
# new-library.R - create a lucasCore library: stsim + lucasCore, the stsim project definitions, strata lists, library settings
# =============================================================================
# Usage: Rscript tools/new-library.R <library.ssim> [--project=Definitions] [--rebuild-strata] [--rebuild-climate] [--loca2=<folder>]
#   Strata sources: every preset in defaults/strata/presets.csv (FIA Ecodivisions, States, Counties, HUC6, HUC8, EPA Level III
#                              Ecoregions, Pyromes, Federal Lands, GAP Status) becomes a Stratum Sources row, and the stsim Secondary
#                              and Tertiary Strata lists hold every unit of every source. Scenarios pick their sources in Build Options.
#   --rebuild-strata           rewrite Stratum Sources and the unit lists (after adding a custom source row with a new Number;
#                              existing unit ids keep their meaning, so scenario data stays valid)
#   --rebuild-climate          rewrite the LOCA2 Climate Scenario and Climate Model lists from the LOCA2 folder (after adding runs)
#   --loca2                    LOCA2 folder to scan (default: the project's Data Sources value, else the package default)
#
# Why this is not a stage: SyncroSim keeps only a run's scenario-scope output; project-scope sheets a stage saves during a run
# are discarded (Phase A spike, 2026-10-19: stage 0 saved 21 definition sheets and none persisted). The definitions are the
# CSVs the CONUS build loaded (Build LUCAS Model CONUS Annual NLCD FIA Update.Rmd L602-764), shipped in defaults/.
# A sheet that already has rows is left as it is and checked to contain every default Name.
# The primary strata (FIA ecodivisions, stsim_Stratum) are fixed: the growth curves are fitted on them.
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tools/new-library.R <library.ssim> [--rebuild-strata] [--rebuild-climate]")
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
# transition simulation groups that are automatic "[Type]" groups (forest clearcut and selection: simulated and mapped as separate
# groups, not as the Forest Harvest family); SyncroSim makes the "[Type]" groups when the transition types are saved, above
sgt <- rd("stsim", "stsim_TransitionSimulationGroup-types.csv")
have <- suppressWarnings(as.data.table(datasheet(P, "stsim_TransitionSimulationGroup", optional = TRUE, lookupsAsFactors = FALSE)))
add <- setdiff(sgt$TransitionGroupId, have$TransitionGroupId)
if (length(add)) saveDatasheet(P, data.frame(TransitionGroupId = add), "stsim_TransitionSimulationGroup", append = TRUE)
cat(sprintf("%-34s %4d [Type] rows added\n", "stsim_TransitionSimulationGroup", length(add)))

# ---- Stratum Sources (every polygon source) and the universal unit lists -------------------------------------------------
# Every preset is a row; rows the user added (a custom source with its own Number) are kept. The stsim Secondary and Tertiary Strata
# lists both hold every unit of every source ("<Prefix>: <name>", Id = Number x 1e8 + id), so each scenario picks its study area
# (Study Area sheet) and its secondary and tertiary source (Build Options) without changing project data.
presets <- strata_presets(pkgdir); rebuild <- "--rebuild-strata" %in% a
if (!is.na(opt("secondary", NA)) || !is.na(opt("tertiary", NA))) cat("note: --secondary / --tertiary are no longer used: pick the sources in each scenario's Build Options\n")
have_src <- as.data.table(datasheet(P, "lucasCore_StratumSource", optional = TRUE, lookupsAsFactors = FALSE))
if (nrow(have_src) && !"Number" %in% names(have_src)) have_src <- have_src[0]      # a library made before universal lists: replace
custom <- if (nrow(have_src)) have_src[!Name %in% names(presets)] else data.table()
src <- rbind(rbindlist(lapply(presets, function(s) as.data.table(s[STRATA_COLS]))), if (nrow(custom)) setnames(copy(custom), "Name", "Preset"), fill = TRUE)
dup <- src[duplicated(Number), Preset]; if (length(dup)) stop("Stratum Sources: Number used twice (", paste(dup, collapse = ", "), ")")
desc <- rd("strata", "presets.csv")[, .(Preset, Description)]
out_src <- merge(src, desc, by = "Preset", all.x = TRUE, suffixes = c("", ".p"))
if ("Description.p" %in% names(out_src)) { out_src[is.na(Description), Description := Description.p]; out_src[, Description.p := NULL] }
setnames(out_src, "Preset", "Name"); out_src <- out_src[order(Number)]
if (!nrow(have_src) || rebuild) { saveDatasheet(P, as.data.frame(out_src[, intersect(c("Name", "Description", STRATA_COLS[-1]), names(out_src)), with = FALSE]),
                                               "lucasCore_StratumSource", append = FALSE, force = TRUE)
  cat(sprintf("%-34s %4d sources written\n", "lucasCore_StratumSource", nrow(out_src)))
} else cat(sprintf("%-34s kept (%d sources)\n", "lucasCore_StratumSource", nrow(have_src)))
rows <- sources_from_sheet(as.data.table(datasheet(P, "lucasCore_StratumSource", lookupsAsFactors = FALSE)))
have_l <- suppressWarnings(as.data.table(datasheet(P, "stsim_SecondaryStratum", optional = TRUE)))
if (nrow(have_l) && !rebuild && all(as.integer(have_l$Id) >= UNIT_OFFSET)) {
  cat(sprintf("%-34s kept (%d units)\n", "stsim_Secondary/TertiaryStratum", nrow(have_l)))
} else {
  t0 <- Sys.time(); ul <- universal_list(rows, pkgdir)
  if (anyDuplicated(ul$Name)) stop("universal unit list: duplicate names ", paste(head(ul$Name[duplicated(ul$Name)], 3), collapse = "; "))
  for (sheet in c("stsim_SecondaryStratum", "stsim_TertiaryStratum")) saveDatasheet(P, as.data.frame(ul), sheet, append = FALSE, force = TRUE)
  cat(sprintf("%-34s %4d units from %d sources (%s) in %.1f min\n", "stsim_Secondary/TertiaryStratum", nrow(ul), length(rows),
              paste(sprintf("%s %d", names(rows), vapply(rows, function(s) sum(unit_source(ul$Id) == s$Number), 0L)), collapse = ", "),
              as.numeric(Sys.time() - t0, units = "mins")))
}

# ---- LOCA2 climate scenario and model lists (Climate Options drop-downs), from the folders under the LOCA2 folder ---------------
# <gcm>/<member>/<ssp>/{pr,tasmax,tasmin}/*.monthly.nc; a model is listed when it has a historical run and at least one SSP with all
# three variables. Existing lists are kept unless --rebuild-climate (scenarios that chose a model keep pointing at its row).
loca2 <- { d <- as.data.table(datasheet(P, "lucasCore_DataSource", optional = TRUE, lookupsAsFactors = FALSE)); v <- if (nrow(d) && "Loca2Folder" %in% names(d)) d$Loca2Folder[1] else NA
  if (is.na(v) || !nzchar(v)) { xml <- paste(readLines(file.path(pkgdir, "package.xml"), warn = FALSE), collapse = "\n")
    v <- sub('.*name="Loca2Folder"[^>]*defaultValue="([^"]*)".*', "\\1", xml) }
  opt("loca2", v) }
ssp_names <- c(ssp126 = "SSP1-2.6", ssp245 = "SSP2-4.5", ssp370 = "SSP3-7.0", ssp585 = "SSP5-8.5")
has_run <- function(d) all(vapply(c("pr", "tasmax", "tasmin"), function(v) length(Sys.glob(file.path(d, v, "*.monthly.nc"))) > 0, TRUE))
runs <- if (dir.exists(loca2)) rbindlist(lapply(list.dirs(loca2, recursive = FALSE), function(g) rbindlist(lapply(list.dirs(g, recursive = FALSE), function(m) {
  s <- basename(list.dirs(m, recursive = FALSE)); s <- s[s != "historical" & vapply(file.path(m, s), has_run, TRUE)]
  if (!has_run(file.path(m, "historical")) || !length(s)) return(NULL)
  data.table(Gcm = basename(g), Member = basename(m), Ssp = s) })))) else data.table()
have_s <- suppressWarnings(as.data.table(datasheet(P, "lucasCore_ClimateScenario", optional = TRUE)))
if (!nrow(runs)) cat("LOCA2: no model runs found under", loca2, "- climate lists left empty\n") else if (nrow(have_s) && !"--rebuild-climate" %in% a) {
  cat(sprintf("%-34s kept (%d rows)\n", "lucasCore_ClimateScenario / Model", nrow(have_s)))
} else {
  sc <- unique(runs$Ssp); sc <- sc[order(sc)]
  saveDatasheet(P, data.frame(Name = ifelse(sc %in% names(ssp_names), ssp_names[sc], sc), Code = sc), "lucasCore_ClimateScenario", append = FALSE, force = TRUE)
  runs[, SspName := ifelse(Ssp %in% names(ssp_names), ssp_names[Ssp], Ssp)]
  md <- runs[order(Ssp, Member), .(r = paste(Member, collapse = ", ")), by = .(Gcm, SspName)][, .(Runs = paste(sprintf("%s: %s", SspName, r), collapse = "; ")), by = Gcm][order(Gcm)]
  saveDatasheet(P, as.data.frame(md[, .(Name = Gcm, Runs)]), "lucasCore_ClimateModel", append = FALSE, force = TRUE)
  rp <- runs[order(Gcm, Ssp), .(s = paste(SspName, collapse = ", ")), by = .(Member, Gcm)][, .(Runs = paste(sprintf("%s (%s)", Gcm, s), collapse = "; ")), by = Member][order(Member)]
  saveDatasheet(P, as.data.frame(rp[, .(Name = Member, Runs)]), "lucasCore_ClimateReplicate", append = FALSE, force = TRUE)
  cat(sprintf("%-34s %4d scenarios, %d models, %d replicates (%d runs) from %s\n", "lucasCore_ClimateScenario/Model/Rep", length(sc), nrow(md), nrow(rp), nrow(runs), loca2)) }
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
# the transition group output filter: summaries for every group, maps for the main groups only (src/transition-filter.R)
if (!nrow(suppressWarnings(datasheet(sfd, "stsim_OutputFilterTransitionGroups", optional = TRUE)))) {
  source(file.path(pkgdir, "src", "transition-filter.R"))
  tf <- transition_filter(as.data.table(datasheet(P, "stsim_TransitionGroup", lookupsAsFactors = FALSE))$Name, rd("stockflow", "main-transition-groups.csv"))
  saveDatasheet(sfd, tf, "stsim_OutputFilterTransitionGroups")
  cat(sprintf("transition group output filter: %d groups, maps for %d\n", nrow(tf), sum(tf$Spatial == "Yes"))) }
cat("library ready:", f, "\n")
