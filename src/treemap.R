# =============================================================================
# treemap.R - TreeMap: each forest pixel's FIA plot, and through it a forest type, stand age and site class (to-do 35, with 10)
# =============================================================================
# TreeMap (USFS, 30 m; 2016 = RDS-2021-0074) imputes an FIA plot to every forest pixel. Its raster holds a plot id (Value) and its
# attribute table (TreeMap2016.tif.vat.dbf) the plot visit (CN = FIA PLT_CN) and TreeMap's forest type (FORTYPCD). The plot's
# forested condition in FIA DataMart COND gives:
#   forest type  FORTYPCD -> forest type group (REF_FOREST_TYPE)             stand age  STDAGE (at the plot's inventory year)
#   site class   SITECLCD, the site's potential growth: 1 = 225+ cu ft/ac/yr, 2 = 165-224, 3 = 120-164, 4 = 85-119, 5 = 50-84,
#                6 = 20-49, 7 = 0-19
# A plot can hold several forested conditions: the one whose FORTYPCD is TreeMap's, else the largest (CONDPROP_UNADJ).
# The condition fields come from fia_sites(): every forested condition of every state's <ST>_COND.csv, cached in the DataMart folder
# (fia-sites.rds, rebuilt when the COND files change) - COND only, so it builds in a minute or two, and it also gives stage 2 the site
# class of its fitting plots. Phase 0 (docs/treemap-plan.md): every P26 TreeMap pixel joins a forested condition with a site class.
# No SyncroSim calls here, so tests can source this file; say() is used when it exists.
# =============================================================================

TREEMAP_SITES_METHOD <- "2026-10-30"   # bump when fia_sites() changes (the cache is rebuilt)
SITE_CLASS_LABELS <- c(`1` = "225+", `2` = "165-224", `3` = "120-164", `4` = "85-119", `5` = "50-84", `6` = "20-49", `7` = "0-19")   # cu ft/ac/yr

tm_say <- function(...) if (exists("say", mode = "function")) say(...) else message(sprintf(...))

# every forested condition (COND_STATUS_CD 1) of every state in the DataMart folder dm: plt_cn, condid, condprop, fortypcd,
# fortyp_grp, invyr, stdage (at invyr), siteclcd, st
fia_sites <- function(dm) {
  cf <- list.files(dm, "^[A-Z]{2}_COND[.]csv$", full.names = TRUE)
  if (!length(cf)) stop(sprintf("FIA DataMart Folder %s has no <ST>_COND.csv files", dm), call. = FALSE)
  fi <- file.info(cf); key <- paste(c(TREEMAP_SITES_METHOD, basename(cf), fi$size, as.numeric(fi$mtime)), collapse = "|")
  cache <- file.path(dm, "fia-sites.rds")
  if (file.exists(cache)) { c0 <- readRDS(cache); if (identical(c0$key, key)) return(c0$sites) }
  t0 <- Sys.time()
  ft <- fia_forest_types(dm)
  x <- data.table::rbindlist(lapply(cf, function(f)
    data.table::fread(f, select = c("PLT_CN", "CONDID", "INVYR", "COND_STATUS_CD", "CONDPROP_UNADJ", "FORTYPCD", "STDAGE", "SITECLCD"),
                      colClasses = list(character = "PLT_CN"), showProgress = FALSE)[COND_STATUS_CD == 1][, st := substr(basename(f), 1, 2)]))
  x <- x[, .(plt_cn = PLT_CN, condid = CONDID, condprop = as.numeric(CONDPROP_UNADJ), fortypcd = FORTYPCD,
             fortyp_grp = ft$TYPGRPCD[match(FORTYPCD, ft$VALUE)], invyr = INVYR, stdage = STDAGE, siteclcd = SITECLCD, st)]
  tryCatch(saveRDS(list(key = key, sites = x), cache), error = function(e) tm_say("FIA sites: could not cache in %s (%s)", dm, conditionMessage(e)))
  tm_say("FIA sites: %d forested conditions from %d states' COND in %.1f min", nrow(x), length(cf), as.numeric(Sys.time() - t0, units = "mins"))
  x }

# REF_FOREST_TYPE (VALUE -> TYPGRPCD), from the extracted REFERENCE folder or FIADB_REFERENCE.zip (as fia.R's fia_reference)
fia_forest_types <- function(dm) {
  p <- file.path(dm, "REFERENCE", "REF_FOREST_TYPE.csv")
  if (!file.exists(p)) { z <- file.path(dm, "FIADB_REFERENCE.zip")
    if (!file.exists(z)) stop(sprintf("FIA DataMart Folder: %s or FIADB_REFERENCE.zip is missing", p), call. = FALSE)
    td <- tempfile(); utils::unzip(z, files = "REF_FOREST_TYPE.csv", exdir = td); p <- file.path(td, "REF_FOREST_TYPE.csv") }
  data.table::fread(p, select = c("VALUE", "TYPGRPCD")) }

# the TreeMap raster and attribute table in folder tm_dir (year: 2016 -> TreeMap2016.tif and TreeMap2016.tif.vat.dbf)
treemap_files <- function(tm_dir, year = 2016) {
  r <- file.path(tm_dir, sprintf("TreeMap%d.tif", year)); v <- paste0(r, ".vat.dbf")
  miss <- c(r, v)[!file.exists(c(r, v))]
  if (length(miss)) stop(sprintf("TreeMap: %s not found (Data Sources: TreeMap Folder)", paste(miss, collapse = ", ")), call. = FALSE)
  list(raster = r, vat = v) }

# TreeMap's plot ids over a template raster's extent (in TreeMap's own 30 m grid and CRS), its colour table and levels dropped
treemap_crop <- function(tm_dir, template, year = 2016) {
  tm <- terra::rast(treemap_files(tm_dir, year)$raster)
  w <- terra::project(terra::as.polygons(terra::ext(template), crs = terra::crs(template)), terra::crs(tm))
  x <- terra::crop(tm, w); levels(x) <- NULL; x }

# one row per TreeMap plot id in ids: the plot's chosen forested condition (TreeMap's type, else the largest) with its forest type,
# group, stand age and site class; sites = fia_sites(dm). matched = the condition's type is TreeMap's.
treemap_plots <- function(tm_dir, ids, sites, year = 2016) {
  vat <- data.table::as.data.table(foreign::read.dbf(treemap_files(tm_dir, year)$vat, as.is = TRUE))
  vat <- vat[Value %in% ids, .(Value = as.integer(Value), plt_cn = as.character(CN), tm_fortypcd = as.integer(FORTYPCD))]
  m <- merge(vat, sites, by = "plt_cn", allow.cartesian = TRUE)
  m[, matched := fortypcd == tm_fortypcd]
  m <- m[order(Value, -matched, -condprop)][!duplicated(Value)]
  out <- merge(vat, m[, .(Value, condid, fortypcd, fortyp_grp, invyr, stdage, siteclcd, st, matched)], by = "Value", all.x = TRUE)
  out[is.na(matched), matched := FALSE][] }

# pixel shares (pixels = data.table of Value and n, e.g. from terra::freq) joined to a condition, matching TreeMap's type, with a
# site class and with a stand age: what stage 5 logs and checks
treemap_coverage <- function(pixels, plots) {
  p <- merge(pixels, plots, by = "Value", all.x = TRUE); tot <- sum(p$n)
  list(pixels = tot, joined = p[!is.na(condid), sum(n)] / tot, matched = p[matched %in% TRUE, sum(n)] / tot,
       site = p[!is.na(siteclcd), sum(n)] / tot, age = p[!is.na(stdage), sum(n)] / tot, plots = p[!is.na(condid), data.table::uniqueN(plt_cn)]) }
