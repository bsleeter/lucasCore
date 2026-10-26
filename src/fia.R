# =============================================================================
# fia.R - the FIA condition tables stages 2 and 3 fit to: the USGS .Rds tables, or the same tables derived from FIA DataMart CSVs
# =============================================================================
# Growth Curve Options: FIA Data (to-do item 9; the method and its check: dev/fia/FINDINGS.md)
#   USGS condition tables (default)  Data Sources: FIA Condition Carbon and Merchantable Volume, FIA Condition Disturbance and
#                                    Treatment Codes (the two .Rds files of the USGS data release)
#   FIA DataMart                     Data Sources: FIA DataMart Folder, holding <ST>_PLOT.csv, <ST>_COND.csv and <ST>_TREE.csv of
#                                    every state to use (all 48 for the CONUS-wide pooled curves) and FIADB_REFERENCE (the zip, or
#                                    its REFERENCE folder) from apps.fs.usda.gov/fia/datamart/CSV. Per forest condition
#                                    (COND_STATUS_CD 1): plot ids and INVYR from PLOT, the ecodivision from the plot's LAT/LON in the
#                                    ecodivision map, stand age, forest type group (REF_FOREST_TYPE), disturbance and treatment codes
#                                    and the condition carbon pools from COND; live and standing dead tree carbon and net merchantable
#                                    volume from TREE, each tree x TPA_UNADJ / the condition's share of the plot size it was measured on
#                                    (microplot, subplot, macroplot). Reproduces the USGS California table (99-100% of conditions
#                                    within 1% in every field) except down dead wood.
#   Down dead carbon (DataMart only): FIADB's CARBON_DOWN_DEAD is 1/0.7 x the USGS table's in practically every condition, for a reason
#   not yet found; Growth Curve Options chooses Scaled to the USGS tables (x 0.7, default: the curves and decay calibration of the
#   USGS route) or As in FIADB. Only stage 3's decay calibration reads it.
# The derived tables are cached in the DataMart folder (fia-conditions.rds) and rebuilt when the set of CSVs or their sizes and dates
# change. Output columns are the USGS tables', so growth.R, carbon.R and calibrate.R read either source alike.
# =============================================================================

FIA_SOURCES <- c("USGS condition tables (.Rds)", "FIA DataMart (state CSVs)")
fia_choice <- function(v, labels) { if (is.null(v) || !length(v) || is.na(v[1])) return(1L)
  if (is.numeric(v)) as.integer(v[1]) else { k <- match(TRUE, startsWith(as.character(v[1]), sub(" .*", "", labels))); if (is.na(k)) 1L else k } }

# list(cond, dist) for the Growth Curve Options row opt (a list); ecodiv_file = Data Sources: Ecodivision Map
fia_tables <- function(opt, ecodiv_file) {
  if (fia_choice(opt$FiaSource, FIA_SOURCES) == 1L) {
    s <- read_data_sources(c("FiaConditionFile", "FiaDisturbanceFile"))
    say("FIA data: the USGS condition tables (%s, %s)", basename(s$FiaConditionFile), basename(s$FiaDisturbanceFile))
    return(list(cond = data.table::as.data.table(readRDS(s$FiaConditionFile)), dist = data.table::as.data.table(readRDS(s$FiaDisturbanceFile)))) }
  dm <- read_data_sources("FiaDataMartFolder")$FiaDataMartFolder
  x <- fia_datamart(dm, ecodiv_file)
  scale_dd <- fia_choice(opt$DownDeadCarbon, c("Scaled", "As")) == 1L
  if (scale_dd) x$cond[, c_down_dead_tons_per_acre := c_down_dead_tons_per_acre * 0.7]
  say("FIA data: FIA DataMart, %d states (%s), %d forest conditions, inventories %d-%d; down dead carbon %s",
      length(x$states), paste(x$states, collapse = " "), nrow(x$cond), min(x$cond$invyr), max(x$cond$invyr),
      if (scale_dd) "scaled x 0.7 to the USGS tables" else "as in FIADB (1/0.7 x the USGS tables)")
  if (length(x$states) < 48) say("FIA DataMart: %d of the 48 conterminous states - the pooled curves are not CONUS-wide", length(x$states))
  x }

# the DataMart tables, from the cache when the CSVs are unchanged
fia_datamart <- function(dm, ecodiv_file) {
  sts <- sort(unique(sub("_PLOT[.]csv$", "", list.files(dm, "^[A-Z]{2}_PLOT[.]csv$"))))
  sts <- sts[file.exists(file.path(dm, paste0(sts, "_COND.csv"))) & file.exists(file.path(dm, paste0(sts, "_TREE.csv")))]
  if (!length(sts)) fail("FIA DataMart Folder %s has no <ST>_PLOT, <ST>_COND and <ST>_TREE csv files", dm)
  fi <- file.info(file.path(dm, as.vector(outer(sts, c("_PLOT.csv", "_COND.csv", "_TREE.csv"), paste0))))
  key <- paste(basename(rownames(fi)), fi$size, as.numeric(fi$mtime), collapse = "|")
  cf <- file.path(dm, "fia-conditions.rds")
  if (file.exists(cf)) { c0 <- readRDS(cf); if (identical(c0$key, key)) { say("FIA DataMart: cached tables (%s)", cf); return(c0) } }
  t0 <- Sys.time(); ref <- fia_reference(dm)
  parts <- lapply(sts, function(s) fia_state(dm, s, ref))
  cond <- data.table::rbindlist(lapply(parts, `[[`, "cond")); dist <- data.table::rbindlist(lapply(parts, `[[`, "dist"))
  # ecodivision from the plot coordinates (FIA fuzzes them up to about 1.6 km; PLOT has no ecosubsection code)
  eco <- sf::read_sf(ecodiv_file); pts <- unique(cond[!is.na(lat) & !is.na(lon), .(plt_cn, lat, lon)])
  j <- sf::st_join(sf::st_transform(sf::st_as_sf(pts, coords = c("lon", "lat"), crs = 4269), sf::st_crs(eco)), eco["ecodiv"])
  pts[, ecodiv := as.character(j$ecodiv[match(plt_cn, j$plt_cn)])]
  cond[, ecodiv := pts$ecodiv[match(plt_cn, pts$plt_cn)]][, c("lat", "lon") := NULL]
  data.table::setcolorder(cond, c("plt_cn", "condid", "statecd", "unitcd", "countycd", "plot", "invyr", "ecodiv", "stdage", "fortyp_grp"))
  out <- list(key = key, states = sts, cond = cond, dist = dist)
  tryCatch(saveRDS(out, cf), error = function(e) say("FIA DataMart: could not cache the tables in %s (%s)", dm, conditionMessage(e)))
  say("FIA DataMart: %d states read in %.1f min", length(sts), as.numeric(Sys.time() - t0, units = "mins"))
  out }

# REF_FOREST_TYPE and REF_SPECIES, from the extracted REFERENCE folder or FIADB_REFERENCE.zip
fia_reference <- function(dm) {
  rd <- function(f) { p <- file.path(dm, "REFERENCE", f)
    if (file.exists(p)) return(data.table::fread(p))
    z <- file.path(dm, "FIADB_REFERENCE.zip"); if (!file.exists(z)) fail("FIA DataMart Folder: %s or FIADB_REFERENCE.zip is missing", p)
    td <- tempfile(); utils::unzip(z, files = f, exdir = td); data.table::fread(file.path(td, f)) }
  list(ft = rd("REF_FOREST_TYPE.csv")[, .(VALUE, TYPGRPCD)], sp = rd("REF_SPECIES.csv")[, .(SPCD, CARBON_RATIO_LIVE)]) }

# one state's forest conditions in the USGS tables' columns (plus the plot coordinates for the ecodivision)
fia_state <- function(dm, s, ref) {
  f <- function(t) file.path(dm, sprintf("%s_%s.csv", s, t))
  pl <- data.table::fread(f("PLOT"), select = c("CN", "INVYR", "STATECD", "UNITCD", "COUNTYCD", "PLOT", "LAT", "LON", "MACRO_BREAKPOINT_DIA"), colClasses = list(character = "CN"))
  cd <- data.table::fread(f("COND"), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "STDAGE", "FORTYPCD", "MICRPROP_UNADJ", "SUBPPROP_UNADJ", "MACRPROP_UNADJ",
                                                "DSTRBCD1", "TRTCD1", "CARBON_DOWN_DEAD", "CARBON_LITTER", "CARBON_SOIL_ORG", "CARBON_UNDERSTORY_AG", "CARBON_UNDERSTORY_BG"),
                          colClasses = list(character = "PLT_CN"))[COND_STATUS_CD == 1]
  tr <- data.table::fread(f("TREE"), select = c("PLT_CN", "CONDID", "SPCD", "STATUSCD", "STANDING_DEAD_CD", "DIA", "TPA_UNADJ", "CARBON_AG", "CARBON_BG", "DRYBIO_FOLIAGE", "VOLCFNET"),
                          colClasses = list(character = "PLT_CN"))[STATUSCD %in% 1:2]
  # a column empty in a whole state is read as logical (e.g. MACRPROP_UNADJ where no plot has a macroplot)
  num <- function(d, k) { k <- intersect(k, names(d)); if (length(k)) d[, (k) := lapply(.SD, as.numeric), .SDcols = k]; invisible(d) }
  num(pl, "MACRO_BREAKPOINT_DIA"); num(cd, c("MICRPROP_UNADJ", "SUBPPROP_UNADJ", "MACRPROP_UNADJ", "CARBON_DOWN_DEAD", "CARBON_LITTER", "CARBON_SOIL_ORG", "CARBON_UNDERSTORY_AG", "CARBON_UNDERSTORY_BG"))
  num(tr, c("DIA", "TPA_UNADJ", "CARBON_AG", "CARBON_BG", "DRYBIO_FOLIAGE", "VOLCFNET"))
  tr <- merge(tr, ref$sp, by = "SPCD", all.x = TRUE)
  tr <- merge(merge(tr, pl[, .(CN, MACRO_BREAKPOINT_DIA)], by.x = "PLT_CN", by.y = "CN"), cd[, .(PLT_CN, CONDID, MICRPROP_UNADJ, SUBPPROP_UNADJ, MACRPROP_UNADJ)], by = c("PLT_CN", "CONDID"))
  tr[, w := TPA_UNADJ / data.table::fifelse(DIA < 5, MICRPROP_UNADJ, data.table::fifelse(!is.na(MACRO_BREAKPOINT_DIA) & DIA >= MACRO_BREAKPOINT_DIA, MACRPROP_UNADJ, SUBPPROP_UNADJ))]
  tr <- tr[is.finite(w)]
  live <- tr[STATUSCD == 1, .(ag = sum(w * CARBON_AG, na.rm = TRUE) / 2000, bg = sum(w * CARBON_BG, na.rm = TRUE) / 2000,
                              fol = sum(w * DRYBIO_FOLIAGE * CARBON_RATIO_LIVE, na.rm = TRUE) / 2000, vol = sum(w * VOLCFNET, na.rm = TRUE)), by = .(PLT_CN, CONDID)]
  dead <- tr[STATUSCD == 2 & STANDING_DEAD_CD %in% 1, .(dag = sum(w * CARBON_AG, na.rm = TRUE) / 2000, dbg = sum(w * CARBON_BG, na.rm = TRUE) / 2000), by = .(PLT_CN, CONDID)]
  x <- merge(merge(merge(cd, pl, by.x = "PLT_CN", by.y = "CN"), live, by = c("PLT_CN", "CONDID"), all.x = TRUE), dead, by = c("PLT_CN", "CONDID"), all.x = TRUE)
  for (k in c("ag", "bg", "fol", "vol", "dag", "dbg")) x[is.na(get(k)), (k) := 0]
  list(cond = x[, .(plt_cn = PLT_CN, condid = CONDID, statecd = STATECD, unitcd = UNITCD, countycd = COUNTYCD, plot = PLOT, invyr = INVYR, lat = LAT, lon = LON,
                    stdage = STDAGE, fortyp_grp = ref$ft$TYPGRPCD[match(FORTYPCD, ref$ft$VALUE)],
                    c_understory_ag_tons_per_acre = CARBON_UNDERSTORY_AG, c_understory_bg_tons_per_acre = CARBON_UNDERSTORY_BG,
                    c_understory_total_tons_per_acre = CARBON_UNDERSTORY_AG + CARBON_UNDERSTORY_BG, c_litter_tons_per_acre = CARBON_LITTER,
                    c_soil_org_tons_per_acre = CARBON_SOIL_ORG, c_down_dead_tons_per_acre = CARBON_DOWN_DEAD,
                    net_merchantable_bole_wood_vol_live_trees_cuft_per_acre = vol,
                    c_ag_all_live_trees_short_tons_per_acre = ag, c_foliage_all_live_trees_short_tons_per_acre = fol,
                    c_bg_all_live_trees_short_tons_per_acre = bg, c_total_all_live_trees_short_tons_per_acre = ag + bg + fol,
                    c_ag_standing_dead_trees_short_tons_per_acre = dag, c_bg_standing_dead_trees_short_tons_per_acre = dbg,
                    c_total_standing_dead_trees_short_tons_per_acre = dag + dbg)],
       dist = x[, .(plt_cn = PLT_CN, condid = CONDID, dstrbcd1 = DSTRBCD1, trtcd1 = TRTCD1)]) }
