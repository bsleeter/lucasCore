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
#   Down dead carbon (DataMart only): FIADB's CARBON_DOWN_DEAD is a model (Smith and Heath 2008, from live tree carbon); the USGS tables
#   hold it times one constant per state (0.17-2.05, all 48 states: dev/fia/FINDINGS.md), consistent with the national GHG inventory's
#   state field/model adjustment (Domke et al. 2013). Growth Curve Options: Adjusted to field measurements (default; those factors,
#   defaults/growth/down-dead-state-factors.csv, as the USGS route) or As in FIADB. Only stage 3's decay calibration reads it.
# The derived tables are cached in the DataMart folder (fia-conditions.rds) and rebuilt when the set of CSVs or their sizes and dates
# change. Output columns are the USGS tables', so growth.R, carbon.R and calibrate.R read either source alike.
# =============================================================================

FIA_METHOD <- "2026-10-26b"   # bump when the derivation changes (the cache is rebuilt)
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
  adjust_dd <- fia_choice(opt$DownDeadCarbon, c("Adjusted", "As")) == 1L
  if (adjust_dd) {   # each state's field/model factor (defaults/growth/down-dead-state-factors.csv); a state without one keeps the model value
    sf <- read_default("growth", "down-dead-state-factors.csv")
    x$cond[, f := as.numeric(sf$Factor)[match(statecd, as.integer(sf$StateCode))]]   # read_default reads text
    miss <- x$cond[is.na(f), unique(statecd)]; if (length(miss)) say("Down dead carbon: no state factor for state code(s) %s - FIADB's model value kept", paste(miss, collapse = ", "))
    x$cond[is.na(f), f := 1][, c_down_dead_tons_per_acre := c_down_dead_tons_per_acre * f][, f := NULL] }
  say("FIA data: FIA DataMart, %d states (%s), %d forest conditions, inventories %d-%d; down dead carbon %s",
      length(x$states), paste(x$states, collapse = " "), nrow(x$cond), min(x$cond$invyr), max(x$cond$invyr),
      if (adjust_dd) "adjusted to field measurements by state (as in the USGS tables)" else "as FIADB's model (Smith and Heath 2008), unadjusted")
  if (length(x$states) < 48) say("FIA DataMart: %d of the 48 conterminous states - the pooled curves are not CONUS-wide", length(x$states))
  x }

# the DataMart tables, from the cache when the CSVs are unchanged
fia_datamart <- function(dm, ecodiv_file) {
  sts <- sort(unique(sub("_PLOT[.]csv$", "", list.files(dm, "^[A-Z]{2}_PLOT[.]csv$"))))
  sts <- sts[file.exists(file.path(dm, paste0(sts, "_COND.csv"))) & file.exists(file.path(dm, paste0(sts, "_TREE.csv")))]
  if (!length(sts)) fail("FIA DataMart Folder %s has no <ST>_PLOT, <ST>_COND and <ST>_TREE csv files", dm)
  fi <- file.info(file.path(dm, as.vector(outer(sts, c("_PLOT.csv", "_COND.csv", "_TREE.csv"), paste0))))
  key <- paste(c(FIA_METHOD, basename(rownames(fi)), fi$size, as.numeric(fi$mtime)), collapse = "|")   # the method version: a change rebuilds the cache
  cf <- file.path(dm, "fia-conditions.rds")
  if (file.exists(cf)) { c0 <- readRDS(cf); if (identical(c0$key, key)) { say("FIA DataMart: cached tables (%s)", cf); return(c0) } }
  t0 <- Sys.time(); ref <- fia_reference(dm)
  parts <- lapply(sts, function(s) fia_state(dm, s, ref))
  cond <- data.table::rbindlist(lapply(parts, `[[`, "cond")); dist <- data.table::rbindlist(lapply(parts, `[[`, "dist"))
  # ecodivision from the plot coordinates (FIA fuzzes them up to about 1.6 km; PLOT has no ecosubsection code)
  eco <- sf::read_sf(ecodiv_file); pts <- unique(cond[!is.na(lat) & !is.na(lon), .(plt_cn, lat, lon)])
  j <- sf::st_join(sf::st_transform(sf::st_as_sf(pts, coords = c("lon", "lat"), crs = 4269), sf::st_crs(eco)), eco["ecodiv"])
  pts[, ecodiv := as.character(j$ecodiv[match(plt_cn, j$plt_cn)])]
  # a fuzzed location just off the map (coasts, lake shores; 250 CONUS conditions) takes the nearest ecodivision, as the USGS table has one for every plot
  off <- pts[is.na(ecodiv), which = TRUE]
  if (length(off)) { p <- sf::st_transform(sf::st_as_sf(pts[off], coords = c("lon", "lat"), crs = 4269), sf::st_crs(eco))
    pts[off, ecodiv := as.character(eco$ecodiv[sf::st_nearest_feature(p, eco)])] }
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

# ---- measured dead wood (to-do 19, 2026-10-27; docs/dom-calibration-proposal.md) ------------------------------------------------
# From the DataMart folder, for the states that have <ST>_COND_DWM_CALC.csv (FIA's down woody material plots, 2001-):
#   dwm   per forest condition with a DWM visit: coarse woody debris + piles (-> AG medium), fine woody debris (three size classes,
#         -> AG fast), litter (-> AG very fast), duff (-> AG slow), Mg C/ha; with stand age, forest type group, ecodivision and measured
#         standing dead carbon from the condition tables (fia_datamart), and the years since the last fire (DSTRBCD 30-32) and the last
#         cutting (TRTCD 10) recorded at the plot location at any visit
#   fall  remeasured standing dead trees (STATUSCD 2, STANDING_DEAD_CD 1) and their record at the next visit (PREV_TRE_CN): fallen
#         (down, or no longer tallied with RECONCILECD 5-6) or still standing; carbon weight, years between visits, fire-killed
#         (AGENTCD 30-39 or a fire at the location in the 10 years before) - for snag fall rates (calibrate.R snag_fall_rates)
# Cached in the DataMart folder (fia-deadwood.rds), rebuilt when the files change.
FIA_DW_METHOD <- "2026-10-27"
LB_AC_TO_MG_HA <- 0.000453592 * 2.471

fia_dead_wood <- function(dm, base) {
  sts <- sort(sub("_COND_DWM_CALC[.]csv$", "", list.files(dm, "^[A-Z]{2}_COND_DWM_CALC[.]csv$")))
  sts <- intersect(sts, base$states)
  if (!length(sts)) return(NULL)
  fi <- file.info(file.path(dm, as.vector(outer(sts, c("_COND_DWM_CALC.csv", "_PLOT.csv", "_COND.csv", "_TREE.csv"), paste0))))
  key <- paste(c(FIA_DW_METHOD, base$key, basename(rownames(fi)), fi$size, as.numeric(fi$mtime)), collapse = "|")
  cf <- file.path(dm, "fia-deadwood.rds")
  if (file.exists(cf)) { c0 <- readRDS(cf); if (identical(c0$key, key)) { say("FIA dead wood: cached tables (%s)", cf); return(c0) } }
  t0 <- Sys.time(); parts <- lapply(sts, function(s) fia_state_dead_wood(dm, s))
  info <- base$cond[, .(plt_cn, condid, ecodiv, stdage, fortyp_grp, standing = c_ag_standing_dead_trees_short_tons_per_acre * TONS_C_ACRE)]
  dwm <- merge(data.table::rbindlist(lapply(parts, `[[`, "dwm")), info, by = c("plt_cn", "condid"))
  fall <- merge(data.table::rbindlist(lapply(parts, `[[`, "fall")), info[, .(plt_cn, condid, ecodiv, fortyp_grp)], by = c("plt_cn", "condid"))
  out <- list(key = key, states = sts, dwm = dwm, fall = fall)
  tryCatch(saveRDS(out, cf), error = function(e) say("FIA dead wood: could not cache the tables in %s (%s)", dm, conditionMessage(e)))
  say("FIA dead wood: %d states read in %.1f min (%d DWM conditions, %d remeasured snags)", length(sts), as.numeric(Sys.time() - t0, units = "mins"), nrow(dwm), nrow(fall))
  out }
TONS_C_ACRE <- 2.2417

fia_state_dead_wood <- function(dm, s) {
  f <- function(t) file.path(dm, sprintf("%s_%s.csv", s, t))
  num <- function(d, k) { k <- intersect(k, names(d)); if (length(k)) d[, (k) := lapply(.SD, as.numeric), .SDcols = k]; invisible(d) }
  pl <- data.table::fread(f("PLOT"), select = c("CN", "MEASYEAR", "REMPER", "STATECD", "UNITCD", "COUNTYCD", "PLOT"), colClasses = list(character = "CN"))
  pl[, loc := paste(STATECD, UNITCD, COUNTYCD, PLOT)]; num(pl, "REMPER")
  cd <- data.table::fread(f("COND"), select = c("PLT_CN", "CONDID", paste0("DSTRBCD", 1:3), paste0("DSTRBYR", 1:3), paste0("TRTCD", 1:3), paste0("TRTYR", 1:3)),
                          colClasses = list(character = "PLT_CN"))
  num(cd, c(paste0("DSTRBCD", 1:3), paste0("DSTRBYR", 1:3), paste0("TRTCD", 1:3), paste0("TRTYR", 1:3)))
  h <- merge(cd, pl[, .(CN, loc)], by.x = "PLT_CN", by.y = "CN")
  ev <- unique(data.table::rbindlist(lapply(1:3, function(i) rbind(
    h[get(paste0("DSTRBCD", i)) %in% 30:32 & data.table::between(get(paste0("DSTRBYR", i)), 1900, 2100), .(loc, year = get(paste0("DSTRBYR", i)), kind = "fire")],
    h[get(paste0("TRTCD", i)) %in% 10 & data.table::between(get(paste0("TRTYR", i)), 1900, 2100), .(loc, year = get(paste0("TRTYR", i)), kind = "cut")]))))
  since <- function(x, kd) { m <- merge(x[, .(id, loc, y)], ev[kind == kd], by = "loc", allow.cartesian = TRUE)[year <= y]; m[, .(ys = min(y - year)), by = id] }
  # DWM conditions
  w <- data.table::fread(f("COND_DWM_CALC"), select = c("PLT_CN", "CONDID", "MEASYEAR", "CWD_CARBON_COND", "PILE_CARBON_COND", "FWD_SM_CARBON_COND",
                                                        "FWD_MD_CARBON_COND", "FWD_LG_CARBON_COND", "DUFF_CARBON", "LITTER_CARBON"), colClasses = list(character = "PLT_CN"))
  w <- unique(w, by = c("PLT_CN", "CONDID")); kc <- grep("CARBON", names(w), value = TRUE); num(w, kc); w[, (kc) := lapply(.SD, `*`, LB_AC_TO_MG_HA), .SDcols = kc]
  w <- merge(w, pl[, .(CN, loc)], by.x = "PLT_CN", by.y = "CN")
  w[, `:=`(id = .I, y = MEASYEAR)]
  sf <- since(w, "fire"); sc <- since(w, "cut")
  w[, `:=`(since_fire = sf$ys[match(id, sf$id)], since_cut = sc$ys[match(id, sc$id)])]
  dwm <- w[, .(plt_cn = PLT_CN, condid = CONDID, measyear = MEASYEAR, cwd = CWD_CARBON_COND + data.table::fifelse(is.na(PILE_CARBON_COND), 0, PILE_CARBON_COND),
               fwd = FWD_SM_CARBON_COND + FWD_MD_CARBON_COND + FWD_LG_CARBON_COND, litter = LITTER_CARBON, duff = DUFF_CARBON, since_fire, since_cut)]
  # remeasured snags
  tr <- data.table::fread(f("TREE"), select = c("CN", "PREV_TRE_CN", "PLT_CN", "CONDID", "STATUSCD", "STANDING_DEAD_CD", "AGENTCD", "TPA_UNADJ", "CARBON_AG", "RECONCILECD"),
                          colClasses = list(character = c("CN", "PREV_TRE_CN", "PLT_CN")))
  num(tr, c("STANDING_DEAD_CD", "AGENTCD", "TPA_UNADJ", "CARBON_AG", "RECONCILECD"))
  s1 <- merge(tr[STATUSCD == 2 & STANDING_DEAD_CD %in% 1 & is.finite(CARBON_AG) & is.finite(TPA_UNADJ), .(CN, PLT_CN, CONDID, AGENTCD, wC = CARBON_AG * TPA_UNADJ / 2000 * TONS_C_ACRE)],
              pl[, .(CN, y = MEASYEAR, loc)], by.x = "PLT_CN", by.y = "CN")
  s2 <- merge(tr[!is.na(PREV_TRE_CN) & nzchar(PREV_TRE_CN), .(PREV_TRE_CN, PLT_CN2 = PLT_CN, status2 = STATUSCD, standing2 = STANDING_DEAD_CD, reconcile = RECONCILECD)],
              pl[, .(CN, y2 = MEASYEAR, remper = REMPER)], by.x = "PLT_CN2", by.y = "CN")
  p <- merge(s1, s2, by.x = "CN", by.y = "PREV_TRE_CN")[status2 %in% 2 | (status2 %in% 0 & reconcile %in% c(5, 6))]
  p[, `:=`(fell = !(status2 %in% 2 & standing2 %in% 1), yrs = data.table::fifelse(is.finite(remper) & remper > 0, remper, as.numeric(y2 - y)), id = .I)]
  p <- p[yrs > 0]
  lf <- merge(p[, .(id, loc, y)], ev[kind == "fire"], by = "loc", allow.cartesian = TRUE)[year <= y & y - year <= 10, unique(id)]
  fall <- p[, .(plt_cn = PLT_CN, condid = CONDID, wC, fell, yrs, fire_killed = id %in% lf | AGENTCD %in% 30:39)]
  list(dwm = dwm, fall = fall) }
