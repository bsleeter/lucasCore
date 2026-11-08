# =============================================================================
# cropland.R - growth of each 30 m Cropland Data Layer pixel from NASS county crop growth (to-do 39 step 6; Cropland Productivity)
# =============================================================================
# Used by stage 8 (the map) and dev/agriculture/03-cdl-ecodivision-sample.R (the ecodivision means it is divided by), so both compute
# a pixel's growth the same way. No SyncroSim calls.
#   cdl_lookup()  every (county, CDL code) pair's growth, Mg C/ha/yr: the sum over the code's crop groups (defaults/stockflow/
#                 cdl-crops.csv; "A|B" a double crop) of the county's 1985-2023 NASS growth of the group (ag-county-crop-npp.csv), else
#                 its ecodivision's (ag-ecodivision-crop-npp.csv), else the group's CONUS mean; fallow 0
#   cdl_npp()     one CDL year (a 30 m raster) to pixel growth: NA where the class is left out (not surveyed by NASS) or no county
# =============================================================================

# co: county polygons (GEOID) in the CDL's CRS; eco: each county's ecodivision (a vector, NA allowed); xw, cg, eg: the tables
cdl_lookup <- function(geoid, eco, xw, cg, eg) {
  xw <- xw[!is.na(Group) & nzchar(Group)]; codes <- as.integer(xw$Code)
  gm <- eg[, .(NPP = mean(as.numeric(NPP))), by = Group]
  ck <- setNames(as.numeric(cg$NPP), paste(cg$GEOID, cg$Group)); ek <- setNames(as.numeric(eg$NPP), paste(eg$StratumId, eg$Group)); gk <- setNames(gm$NPP, gm$Group)
  val <- function(g, e, grp) { v <- ck[paste(g, grp)]; if (!is.na(v)) return(v); v <- ek[paste(e, grp)]; if (!is.na(v)) return(v); gk[[grp]] }
  tab <- data.table::CJ(k = seq_along(geoid), code = codes)
  tab[, npp := mapply(function(k, cd) { grp <- strsplit(xw$Group[match(cd, codes)], "|", fixed = TRUE)[[1]]
    if (identical(grp, "Fallow")) return(0); sum(vapply(grp, function(x) unname(val(geoid[k], eco[k], x)), 0)) }, k, code)]
  if (anyNA(tab$npp)) stop("no NASS growth for crop groups ", paste(unique(xw$Group[match(tab[is.na(npp), code], codes)]), collapse = ", "))
  list(tab = tab, codes = codes) }

# r: one CDL year cropped to the window; ck: county index (position in geoid) on the same 30 m grid; lk: cdl_lookup()'s list
cdl_npp <- function(r, ck, lk) {
  r <- terra::classify(r, cbind(setdiff(0:255, lk$codes), NA))
  terra::classify(ck * 1000 + r, cbind(lk$tab$k * 1000 + lk$tab$code, lk$tab$npp), others = NA) }
