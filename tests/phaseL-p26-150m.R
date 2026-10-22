# =============================================================================
# phaseL-p26-150m.R - the user's Northern Sierra pyrome model at 150 m: Build from the starter, then the historical run
# =============================================================================
# Same settings as the user's dev/libs/lucasBuild-fulltest-v2.ssim (study area Pyrome P26, Counties secondary, Pyromes tertiary, 150 m,
# 1985-2023, default options), rebuilt in a fresh starter copy so it has the current package (one Douglas-fir class, crosswalk fixes,
# Carbon Options). Growth curves are copied from the phaseJ library's Growth Curves result (same classes) instead of refitted.
# Then tools/new-historical.R --bookend-maps: a 3-year timing run first, then 1985-2023.
# Usage: Rscript tests/phaseL-p26-150m.R [--skip-build=<build result id>] [--no-timing]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasBuild-P26-150m.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
CURVES <- "F:/lucasCore/dev/libs/lucasCore-forest-map.ssim"
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
mins <- function(t0) as.numeric(Sys.time() - t0, units = "mins")
bid <- as.integer(opt("skip-build", NA))
if (is.na(bid)) {
  unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE); file.copy("F:/lucasCore/Starter/LUCAS Core (CONUS).ssim", f)
  L <- ssimLibrary(f); sc <- as.data.table(scenario(L, summary = TRUE)); B <- scenario(L, sc[Name == "Build", ScenarioId])
  saveDatasheet(B, data.frame(UnitId = "Pyrome: P26 Northern Sierra Nevada"), "lucasCore_StudyArea")
  saveDatasheet(B, data.frame(Resolution = 150L, SecondarySourceId = "Counties", TertiarySourceId = "Pyromes", StartYear = 1985L, EndYear = 2023L), "lucasCore_BuildOptions")
  g <- as.data.frame(datasheet(B, "lucasCore_GrowthOptions")); g$CurveSource <- "Copy from another library"; g$CurveLibrary <- CURVES; g$CurveScenarioId <- 4L
  saveDatasheet(B, g, "lucasCore_GrowthOptions")
  description(B) <- paste(description(B), "[tests/phaseL-p26-150m.R: the user's Northern Sierra pyrome model (as lucasBuild-fulltest-v2) at 150 m with the current package; curves copied from lucasCore-forest-map.ssim result 4.]")
  t0 <- Sys.time(); RB <- tryCatch(run(B), error = function(e) NULL); cat(sprintf("build took %.1f min\n", mins(t0)))
  if (is.null(RB)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes"]; cat(tail(logl(scenario(L, max(r$ScenarioId))), 40), sep = "\n"); stop("build failed") }
  lg <- logl(RB); cat(unique(lg[grepl("Total time: [0-9]|Study area|Forest cells|Initial carbon|Copied|Failure|rror", lg) & !grepl("post processing|saving results", lg)]), sep = "\n")
  v <- as.data.table(datasheet(RB, "lucasCore_OutputValidation")); print(v[, .(checks = .N, failed = sum(Status != "Pass")), by = Stage])
  if (!nrow(v) || any(v$Status != "Pass")) { print(v[Status != "Pass"]); stop("build failed its checks") }
  bid <- scenarioId(RB)
}
L <- ssimLibrary(f)
hist <- function(name, extra = character()) {
  out <- system2(RS, c("F:/lucasCore/tools/new-historical.R", shQuote(f), sprintf("--build=%d", bid), "--bookend-maps", "--replace", sprintf("--name=%s", shQuote(name)), extra), stdout = TRUE, stderr = TRUE)
  out <- out[!grepl("Warning|undetermined|^In ssimLibrary", out)]; cat(out, sep = "\n"); id <- as.integer(tail(out, 1)); if (is.na(id)) stop("tools/new-historical.R failed"); scenario(L, id) }
runit <- function(H) { t0 <- Sys.time(); R <- tryCatch(run(H), error = function(e) { cat("RUN FAILED:", conditionMessage(e), "\n"); NULL })
  if (is.null(R)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes"]; cat(tail(logl(scenario(L, max(r$ScenarioId))), 40), sep = "\n"); stop("run failed") }
  cat(sprintf("%s took %.1f min (result %d)\n", name(H), mins(t0), scenarioId(R))); R }
if (!"--no-timing" %in% a) {
  T <- hist("Historical timing 1985-1988"); rc <- datasheet(T, "stsim_RunControl"); rc$MaximumTimestep <- 1988L; saveDatasheet(T, rc, "stsim_RunControl")
  t0 <- Sys.time(); RT <- runit(T); per <- mins(t0) / 3; cat(sprintf("TIMING: %.1f min per year -> about %.0f min for 38 years\n", per, per * 38))
}
H <- hist("Historical 1985-2023"); RH <- runit(H)
st <- as.data.table(datasheet(RH, "stsim_OutputStock", lookupsAsFactors = FALSE))[StockGroupId == "Total Ecosystem", .(Tg = sum(Amount) / 1e6), by = Timestep]
print(st[Timestep %in% c(1985, 1995, 2005, 2015, 2023)]); cat("P26 RUN DONE build", bid, "run", scenarioId(RH), "\n")
