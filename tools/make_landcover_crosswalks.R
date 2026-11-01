# =============================================================================
# make_landcover_crosswalks.R - defaults/landcover/land-cover-crosswalks.csv: the four land cover crosswalks of stage 5 in one table
# =============================================================================
# One row per Source x Code: EVT 2016 (LANDFIRE; stage 5 takes forest types, state classes 100-999), RCMAP vegetation state 1985
# (grassland and shrubland types) and C-CAP (wetland types, state classes 90-96), with the stsim State Class name. Values of the source crosswalks
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
x16 <- fread(file.path(d, "landcover", "evt2016-crosswalk-CONUS-v2.csv"))   # (EVT 2001 retired 2026-11-01: LANDFIRE no longer publishes it)
rc <- fread(file.path(d, "landcover", "rcmap-state-class.csv")); cc <- fread(file.path(d, "landcover", "ccap-state-class-crosswalk.csv"))
out <- rbind(x16[, .(Source = "EVT 2016", Code = VALUE, Description = EVT_NAME, StateClassId = nm(ID), Note = note(ID))],
             rc[, .(Source = "RCMAP", Code = RcmapValue, Description = RcmapClass, StateClassId = nm(StateClassId), Note = note(StateClassId))],
             cc[, .(Source = "C-CAP", Code = ccapClassId, Description = ccapClassName, StateClassId = nm(stateClassId), Note = note(stateClassId))])
# codes in the rasters that are not grassland or shrubland classes (RCMAP vegetation state 0, 1, 10-12) and the no-data values of
# C-CAP and the USFS map: unmapped (stage 5 fills them from NLCD and neighbours), listed so every code in the data has a row
extra <- data.table(Source = c("RCMAP", "RCMAP", "RCMAP", "RCMAP", "RCMAP", "C-CAP", "USFS Forest Type Group"), Code = c(0L, 1L, 10L, 11L, 12L, 0L, 0L),
                    Description = c("Outside the mapped area", "Sparsely Vegetated", "Savanna", "Forest", "Non-mapping region", "Background / no data", "Non-forest / no data"),
                    StateClassId = NA_character_, Note = c("not a class; unmapped (NLCD and neighbours fill)", rep("not a grassland or shrubland class; unmapped (NLCD and neighbours fill)", 4),
                                                           "not in the source crosswalk; unmapped as in the CONUS 1km build (not used)", "non-forest in the USFS map (not used)"))
out <- rbind(out, extra[!paste(Source, Code) %in% paste(out$Source, out$Code)])
# the USFS forest type group map (NFCMS regional tiles): its values are FIA forest type group codes, the same numbers as the stsim
# forest state classes, so each maps to itself (200 is the one Douglas-fir class). Codes found in the nine tiles 2026-10-21.
usfs <- c(100, 120, 140, 160, 180, 200, 220, 240, 260, 280, 300, 320, 340, 360, 370, 380, 400, 500, 600, 700, 800, 900, 910, 920, 940, 950, 980, 990)
out <- rbind(out, data.table(Source = "USFS Forest Type Group", Code = as.integer(usfs), Description = sub("^Forest: ", "", nm(usfs)), StateClassId = nm(usfs),
                             Note = ifelse(is.na(nm(usfs)), "not an ST-Sim state class (not used)", NA_character_)))
out <- out[!is.na(Code)][order(match(Source, c("EVT 2016", "RCMAP", "C-CAP", "USFS Forest Type Group")), Code)]
dup <- out[duplicated(out[, .(Source, Code)])]; if (nrow(dup)) stop("duplicate Source x Code: ", paste(head(paste(dup$Source, dup$Code), 5), collapse = "; "))
fwrite(out, file.path(d, "landcover", "land-cover-crosswalks.csv"))
print(out[, .(rows = .N, mapped = sum(!is.na(StateClassId)), forest = sum(grepl("^Forest", StateClassId))), by = Source])
