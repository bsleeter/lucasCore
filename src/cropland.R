# =============================================================================
# cropland.R - growth and harvest of each 30 m Cropland Data Layer pixel from county crop growth (to-do 39 step 6; Cropland
# Productivity and Crop Harvest)
# =============================================================================
# Used by stage 8 (the maps) and dev/agriculture/03-cdl-ecodivision-sample.R, so both compute a pixel's values the same way. No
# SyncroSim calls.
#   cdl_lookup()  every (county, CDL code) pair's NPP, aboveground growth (AG) and harvest, Mg C/ha/yr: the sum over the code's crop
#                 groups (defaults/stockflow/cdl-crops.csv; "A|B" a double crop) of the county's 1985-2023 NASS values of the group
#                 (ag-county-crop-npp.csv), else its ecodivision's (ag-ecodivision-crop-npp.csv), else the group's CONUS mean; fallow 0.
#                 Groups of rg (ag-cac-county-crop-npp.csv: California's County Agricultural Commissioners' reports - tomatoes,
#                 vegetables, tree fruit, tree nuts, grapes) take the county's value only: elsewhere the code is left out (NA)
#   cdl_npp()     one CDL year (a 30 m raster) to pixel values (what = "NPP", "AG" or "Harvest"): NA where the class is left out
# =============================================================================

# geoid: county GEOIDs; eco: each county's ecodivision (a vector, NA allowed); xw, cg, eg, rg: the tables (rg optional)
cdl_lookup <- function(geoid, eco, xw, cg, eg, rg = NULL) {
  xw <- xw[!is.na(Group) & nzchar(Group)]; codes <- as.integer(xw$Code); V <- c("NPP", "AG", "Harvest")
  num <- function(d) { d <- data.table::copy(d); for (v in intersect(V, names(d))) data.table::set(d, j = v, value = as.numeric(d[[v]])); d }
  cg <- num(cg); eg <- num(eg); rg <- if (is.null(rg)) cg[0] else num(rg)
  only <- unique(rg$Group)
  if (!all(c("AG", "Harvest") %in% names(cg))) { cg[, `:=`(AG = NA_real_, Harvest = NA_real_)]; eg[, `:=`(AG = NA_real_, Harvest = NA_real_)] }
  gm <- eg[, lapply(.SD, mean), by = Group, .SDcols = V]
  key <- function(a, b) paste(a, b)
  ck <- rbind(cg[, c("GEOID", "Group", V), with = FALSE], rg[, c("GEOID", "Group", V), with = FALSE]); ck <- ck[!duplicated(key(GEOID, Group))]
  ci <- setNames(seq_len(nrow(ck)), key(ck$GEOID, ck$Group)); ei <- setNames(seq_len(nrow(eg)), key(eg$StratumId, eg$Group)); gi <- setNames(seq_len(nrow(gm)), gm$Group)
  val <- function(g, e, grp) { i <- ci[key(g, grp)]; if (!is.na(i)) return(unlist(ck[i, V, with = FALSE]))
    if (grp %in% only) return(setNames(rep(NA_real_, 3), V))
    i <- ei[key(e, grp)]; if (!is.na(i)) return(unlist(eg[i, V, with = FALSE]))
    i <- gi[grp]; if (!is.na(i)) return(unlist(gm[i, V, with = FALSE])); setNames(rep(NaN, 3), V) }
  tab <- data.table::CJ(k = seq_along(geoid), code = codes)
  m <- t(mapply(function(k, cd) { grp <- strsplit(xw$Group[match(cd, codes)], "|", fixed = TRUE)[[1]]
    if (identical(grp, "Fallow")) return(setNames(c(0, 0, 0), V)); colSums(do.call(rbind, lapply(grp, function(x) val(geoid[k], eco[k], x)))) }, tab$k, tab$code))
  if (!nrow(tab)) m <- matrix(numeric(0), 0, 3, dimnames = list(NULL, V))
  tab[, (V) := as.data.table(m)]
  bad <- tab[is.nan(NPP)]; if (nrow(bad)) stop("no NASS growth for crop groups ", paste(unique(xw$Group[match(bad$code, codes)]), collapse = ", "))
  tab[, npp := NPP]   # (the name earlier callers use)
  list(tab = tab, codes = codes) }

# r: one CDL year cropped to the window; ck: county index (position in geoid) on the same 30 m grid; lk: cdl_lookup()'s list
cdl_npp <- function(r, ck, lk, what = "NPP") {
  r <- terra::classify(r, cbind(setdiff(0:255, lk$codes), NA))
  v <- lk$tab[[what]]; ok <- !is.na(v)
  terra::classify(ck * 1000 + r, cbind(lk$tab$k[ok] * 1000 + lk$tab$code[ok], v[ok]), others = NA) }
