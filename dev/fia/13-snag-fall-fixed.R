# =============================================================================
# 13-snag-fall-fixed.R - rerun the mature-stand calibration (06) and the young-stand check (07) with snag fall fixed at the measured
# rates (snag-fall-measured.csv, from 12-snag-fall.R) and the fitted event table (09); the snag multiplier then fits only snag decay
# Usage: Rscript dev/fia/13-snag-fall-fixed.R      (output: dev/fia/out-cal-snagfall)
# =============================================================================
pkg <- "F:/lucasCore"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
Sys.setenv(LUCAS_EVENT_FILE = file.path(pkg, "dev/fia/event-pathways-fitted.csv"), LUCAS_SNAG_FALL = file.path(pkg, "dev/fia/snag-fall-measured.csv"),
           LUCAS_CAL_OUT = file.path(pkg, "dev/fia/out-cal-snagfall"))
for (s in c("06-calibrate-measured.R", "07-young-stand-replacing.R")) { cat("\n==== ", s, "\n"); o <- system2(RS, file.path(pkg, "dev/fia", s), stdout = TRUE, stderr = TRUE); cat(tail(o, 8), sep = "\n") }
