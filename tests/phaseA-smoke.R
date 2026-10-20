# =============================================================================
# phaseA-smoke.R - the package installs, a library opens, stages 0-1 run for one state and match the CONUS 1km strata
# =============================================================================
# Usage: Rscript tests/phaseA-smoke.R [scratch folder] [state] [CONUS 1km Initial Conditions folder]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(terra) })
a <- commandArgs(TRUE)
D <- if (length(a) >= 1) a[1] else "F:/lucasCore/dev/libs"
STATE <- if (length(a) >= 2) a[2] else "California"
REF <- if (length(a) >= 3) a[3] else "F:/lucas-master/Models/CONUS 1km/Data/Initial Conditions"
dir.create(D, showWarnings = FALSE, recursive = TRUE)
f <- file.path(D, "lucasCore-smoke.ssim"); unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
rs <- file.path(R.home("bin"), "Rscript.exe")
if (system2(rs, c("tools/new-library.R", shQuote(f)))) stop("new-library.R failed")
L <- ssimLibrary(f)
P <- rsyncrosim::project(L, "Definitions")
S <- rsyncrosim::scenario(P, paste("Build:", STATE))
saveDatasheet(S, data.frame(StudyAreaStates = STATE), "lucasCore_BuildOptions")
saveDatasheet(S, data.frame(StageNameId = "1 - Study Area and Strata", RunOrder = 1), "core_Pipeline")
t0 <- Sys.time(); R <- run(S); cat(sprintf("run took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
ok <- TRUE
res_id <- scenarioId(R); cat("result scenario:", res_id, "\n")
lg <- trimws(strsplit(paste(runLog(R), collapse = "
"), "
")[[1]]); lg <- lg[nzchar(lg) & !grepl("depends on|You should load", lg)]
cat("--- run log (tail) ---
", paste(tail(lg, 25), collapse = "
"), "
----------------------
")
v <- datasheet(R, "lucasCore_OutputValidation"); print(v[, c("Stage", "Check", "Status")])
if (!nrow(v) || any(v$Status != "Pass")) ok <- FALSE
for (k in c("Stratum", "SecondaryStratum", "TertiaryStratum", "StateClass", "TransitionType", "FlowType"))
  cat(sprintf("project stsim_%-18s %4d rows\n", k, nrow(datasheet(P, paste0("stsim_", k)))))
ic <- datasheet(R, "stsim_InitialConditionsSpatial"); print(ic)
summ <- datasheet(R, "lucasCore_OutputStrataSummary"); print(aggregate(Cells ~ Level, summ, sum))

# compare with the CONUS 1km strata on the same cells (the reference clipped to the state's secondary stratum)
cmp <- function(new, ref, nm) { refc <- crop(ref, new); sid <- crop(rast(file.path(REF, "SecondaryStrata.tif")), new)
  st_id <- unique(values(rast(ic$SecondaryStratumFileName), mat = FALSE)); st_id <- st_id[!is.na(st_id)]
  refc <- mask(refc, sid %in% st_id, maskvalues = FALSE)
  a <- values(new, mat = FALSE); b <- values(refc, mat = FALSE)
  cat(sprintf("%-10s new cells %7d  ref cells %7d  only-new %5d  only-ref %5d  value differs %6d (%.2f%%)\n", nm, sum(!is.na(a)), sum(!is.na(b)),
              sum(!is.na(a) & is.na(b)), sum(is.na(a) & !is.na(b)), sum(a != b, na.rm = TRUE), 100 * mean(a != b, na.rm = TRUE))) }
cmp(rast(ic$StratumFileName), rast(file.path(REF, "PrimaryStrata.tif")), "primary")
cmp(rast(ic$SecondaryStratumFileName), rast(file.path(REF, "SecondaryStrata.tif")), "secondary")
cmp(rast(ic$TertiaryStratumFileName), rast(file.path(REF, "TertiaryStrata.tif")), "tertiary")
cat(if (ok) "SMOKE OK\n" else "SMOKE FAILED\n")
