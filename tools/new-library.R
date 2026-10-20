# =============================================================================
# new-library.R - create a lucasCore library: stsim + lucasCore, the stsim project definitions, library settings
# =============================================================================
# Usage: Rscript tools/new-library.R <library.ssim> [project name]
#
# Why this is not a stage: SyncroSim keeps only a run's scenario-scope output; project-scope sheets a stage saves during a run
# are discarded (Phase A spike, 2026-10-19: stage 0 saved 21 definition sheets and none persisted). The definitions are the
# CSVs the CONUS build loaded (Build LUCAS Model CONUS Annual NLCD FIA Update.Rmd L602-764), shipped in defaults/.
# A sheet that already has rows is left as it is and checked to contain every default Name.
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); if (!length(a)) stop("usage: Rscript tools/new-library.R <library.ssim> [project name]")
f <- normalizePath(a[1], winslash = "/", mustWork = FALSE); pname <- if (length(a) >= 2) a[2] else "Definitions"
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
pkgdir <- normalizePath(file.path(here, ".."), winslash = "/")
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
if (bad) stop(bad, " default names are missing from sheets that were already filled") else cat("library ready:", f, "\n")
