# =============================================================================
# new-data-download.R - make a Data Download scenario (stage 15): the region's units, options, and Data Sources Home
# =============================================================================
# In Studio the same scenario is: New Scenario, Pipeline = 15 - Data Download, Study Area = the units, Data Download = the options,
# and the project's Data Sources: Data Sources Home set. Usage:
#   Rscript tools/new-data-download.R <library.ssim> --home=<folder> [--units="Pyrome: P26 Northern Sierra Nevada;..."] [--name=...]
#     [--check-only] [--datasets=A,B] [--years=1985-2025] [--buffer=10] [--models=A,B] [--run]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d = NA) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (!length(pos) || is.na(opt("home"))) stop("usage: Rscript tools/new-data-download.R <library.ssim> --home=<folder> [--units=...] [--run]")
L <- ssimLibrary(normalizePath(pos[1], winslash = "/")); P <- project(L, 1)
home <- normalizePath(opt("home"), winslash = "/", mustWork = FALSE)
d <- datasheet(P, "lucasCore_DataSource", optional = TRUE, empty = FALSE)
if (!nrow(d)) d <- data.frame(DataSourcesHome = home) else d$DataSourcesHome <- home
saveDatasheet(P, d, "lucasCore_DataSource")
units <- if (is.na(opt("units"))) character() else trimws(strsplit(opt("units"), ";")[[1]])
S <- scenario(P, opt("name", sprintf("Data Download - %s", if (length(units)) paste(units, collapse = ", ") else "CONUS")))
saveDatasheet(S, data.frame(StageNameId = "15 - Data Download", RunOrder = 1L), "core_Pipeline")
if (length(units)) saveDatasheet(S, data.frame(UnitId = units), "lucasCore_StudyArea")
y <- if (is.na(opt("years"))) c(NA, NA) else as.integer(strsplit(opt("years"), "-")[[1]])
o <- data.frame(BufferKm = as.numeric(opt("buffer", 10)), YearFrom = y[1], YearTo = y[2], Datasets = opt("datasets"), CheckOnly = "--check-only" %in% a,
                Loca2Models = opt("models"), Connections = 4L)
saveDatasheet(S, o, "lucasCore_DataDownloadOptions")
description(S) <- sprintf(paste0("Data Download (stage 15): fetches the Data Sources into Data Sources Home (%s) for %s plus %s km. Datasets: %s; years: %s; %s. ",
  "Made by tools/new-data-download.R on %s."), home, if (length(units)) paste(units, collapse = ", ") else "all of CONUS", o$BufferKm,
  if (is.na(o$Datasets)) "every one the stage fetches" else o$Datasets, if (is.na(y[1])) "1985 to the latest" else opt("years"),
  if (o$CheckOnly) "check only (nothing fetched)" else "download", format(Sys.Date()))
cat(sprintf("scenario %d: %s\n", scenarioId(S), name(S)))
if ("--run" %in% a) { r <- run(S); cat(sprintf("result %d\n", scenarioId(r))); print(datasheet(r, "lucasCore_OutputDataDownload")) }
