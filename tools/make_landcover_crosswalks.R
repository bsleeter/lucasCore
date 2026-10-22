# =============================================================================
# make_landcover_crosswalks.R - defaults/landcover/land-cover-crosswalks.csv: the four land cover crosswalks of stage 5 in one table
# =============================================================================
# One row per Source x Code: EVT 2016 and EVT 2001 (LANDFIRE; stage 5 takes forest types, state classes 100-999), RCMAP (grassland and
# shrubland types) and C-CAP (wetland types, state classes 90-96), with the stsim State Class name. Values of the source crosswalks
# that are not stsim state classes (EVT 61, 83, 84, 1000, 1001; C-CAP's coarse 10-80) stay blank, with the original value in Note;
# stage 5 never uses them. This table is the default of the Land Cover Crosswalks sheet, which users can edit per scenario; the four
# source CSVs in defaults/landcover stay as provenance. Rerun after editing a source CSV.
# Usage: Rscript tools/make_landcover_crosswalks.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
d <- file.path(normalizePath(file.path(here, "..")), "defaults")
sc <- fread(file.path(d, "stsim", "stsim_StateClass.csv"))
nm <- function(id) sc$Name[match(id, sc$Id)]
note <- function(id) ifelse(is.na(nm(id)) & !is.na(id), sprintf("source value %s is not an ST-Sim state class (not used)", id), NA_character_)
x16 <- fread(file.path(d, "landcover", "evt2016-crosswalk-CONUS-v2.csv")); x01 <- fread(file.path(d, "landcover", "evt2001-crosswalk-CONUS-v2.csv"))
rc <- fread(file.path(d, "landcover", "rcmap-state-class.csv")); cc <- fread(file.path(d, "landcover", "ccap-state-class-crosswalk.csv"))
out <- rbind(x16[, .(Source = "EVT 2016", Code = VALUE, Description = EVT_NAME, StateClassId = nm(ID), Note = note(ID))],
             x01[, .(Source = "EVT 2001", Code = Value, Description = EVT_Name, StateClassId = nm(ID), Note = note(ID))],
             rc[, .(Source = "RCMAP", Code = RcmapValue, Description = RcmapClass, StateClassId = nm(StateClassId), Note = note(StateClassId))],
             cc[, .(Source = "C-CAP", Code = ccapClassId, Description = ccapClassName, StateClassId = nm(stateClassId), Note = note(stateClassId))])
# codes in the rasters that the source crosswalks never listed (found by stage 5's coverage check, Placer County 2026-10-21): they were
# unmapped in the CONUS 1km build too, and stay unmapped, but are listed so every code in the data has a row
extra <- data.table(Source = c("RCMAP", "RCMAP", "RCMAP", "RCMAP", "C-CAP"), Code = c(1L, 10L, 11L, 12L, 0L),
                    Description = c("RCMAP value 1 (not a grassland or shrubland type of this RCMAP product)", "RCMAP value 10 (not a grassland or shrubland type; tree classes of the 'with tree' product)",
                                    "RCMAP value 11 (not a grassland or shrubland type; tree classes of the 'with tree' product)", "RCMAP value 12 (not a grassland or shrubland type; tree classes of the 'with tree' product)",
                                    "Background / no data"),
                    StateClassId = NA_character_, Note = "not in the source crosswalk; unmapped as in the CONUS 1km build (not used)")
out <- rbind(out, extra[!paste(Source, Code) %in% paste(out$Source, out$Code)])
out <- out[!is.na(Code)][order(match(Source, c("EVT 2016", "EVT 2001", "RCMAP", "C-CAP")), Code)]
dup <- out[duplicated(out[, .(Source, Code)])]; if (nrow(dup)) stop("duplicate Source x Code: ", paste(head(paste(dup$Source, dup$Code), 5), collapse = "; "))
fwrite(out, file.path(d, "landcover", "land-cover-crosswalks.csv"))
print(out[, .(rows = .N, mapped = sum(!is.na(StateClassId)), forest = sum(grepl("^Forest", StateClassId))), by = Source])
