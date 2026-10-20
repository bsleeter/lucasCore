# =============================================================================
# phaseA-smoke.R - a library is created, stage 1 runs, and (for state strata) matches the CONUS 1km strata
# =============================================================================
# Usage: Rscript tests/phaseA-smoke.R [--units="California"] [--secondary=States] [--tertiary="Federal Lands"] [--dir=dev/libs]
#   --units      study area: secondary strata names, comma-separated (blank = all of CONUS)
#   With --secondary=States the strata are compared with the CONUS 1km model on the same cells.
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(terra) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
D <- opt("dir", "F:/lucasCore/dev/libs"); UNITS <- opt("units", "California")
SEC <- opt("secondary", "States"); TER <- opt("tertiary", "Federal Lands")
REF <- "F:/lucas-master/Models/CONUS 1km/Data/Initial Conditions"
dir.create(D, showWarnings = FALSE, recursive = TRUE)
tag <- gsub("[^A-Za-z0-9]+", "-", paste(SEC, TER, substr(UNITS, 1, 20)))
f <- file.path(D, sprintf("lucasCore-smoke-%s.ssim", tag)); unlink(c(f, paste0(f, c(".data", ".temp", ".backup"))), recursive = TRUE)
rs <- file.path(R.home("bin"), "Rscript.exe")
if (system2(rs, c("tools/new-library.R", shQuote(f), shQuote(paste0("--secondary=", SEC)), shQuote(paste0("--tertiary=", TER))))) stop("new-library.R failed")
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions")
S <- rsyncrosim::scenario(P, paste("Build:", substr(UNITS, 1, 60)))
saveDatasheet(S, data.frame(StudyAreaUnits = UNITS), "lucasCore_BuildOptions")
saveDatasheet(S, data.frame(StageNameId = "1 - Study Area and Strata", RunOrder = 1), "core_Pipeline")
t0 <- Sys.time(); R <- run(S); cat(sprintf("run took %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); lg <- lg[nzchar(lg) & !grepl("depends on|You should load|conda|undetermined|ssimLibrary", lg)]
cat("--- run log ---\n", paste(lg[grepl("Strata:|Study area|NLCD|filled|crosswalk|1 Study Area|Error|Failure", lg)], collapse = "\n"), "\n---------------\n")
v <- datasheet(R, "lucasCore_OutputValidation"); ok <- nrow(v) > 0 && all(v$Status == "Pass")
summ <- datasheet(R, "lucasCore_OutputStrataSummary")
for (lv in c("Primary", "Secondary", "Tertiary")) { x <- summ[summ$Level == lv, ]
  cat(sprintf("%-9s %3d units, %7d cells: %s\n", lv, nrow(x), sum(x$Cells), paste(head(paste0(x$Name, " (", x$Cells, ")")[order(-x$Cells)], 6), collapse = "; "))) }
ic <- datasheet(R, "stsim_InitialConditionsSpatial")
if (SEC == "States" && nrow(ic)) {
  cmp <- function(new, ref, nm) { refc <- crop(ref, new); sid <- crop(rast(file.path(REF, "SecondaryStrata.tif")), new)
    st_id <- unique(values(rast(ic$SecondaryStratumFileName), mat = FALSE)); st_id <- st_id[!is.na(st_id)]
    refc <- mask(refc, sid %in% st_id, maskvalues = FALSE)
    a <- values(new, mat = FALSE); b <- values(refc, mat = FALSE)
    cat(sprintf("vs CONUS 1km %-9s only-new %5d  only-ref %5d  value differs %6d (%.2f%%)\n", nm,
                sum(!is.na(a) & is.na(b)), sum(is.na(a) & !is.na(b)), sum(a != b, na.rm = TRUE), 100 * mean(a != b, na.rm = TRUE))) }
  cmp(rast(ic$StratumFileName), rast(file.path(REF, "PrimaryStrata.tif")), "primary")
  cmp(rast(ic$SecondaryStratumFileName), rast(file.path(REF, "SecondaryStrata.tif")), "secondary")
  if (TER == "Federal Lands") cmp(rast(ic$TertiaryStratumFileName), rast(file.path(REF, "TertiaryStrata.tif")), "tertiary")
}
cat(if (ok) "SMOKE OK\n" else "SMOKE FAILED\n")
