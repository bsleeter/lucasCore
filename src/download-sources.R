# =============================================================================
# download-sources.R - the Data Download handlers: where each dataset comes from and how it lands at its place (to-do 12)
# =============================================================================
# One handler per Data Sources column (src/download.R runs them). URLs checked 2026-10-31 (implementation plan, phase 3). Each
# handler's plan lists its files: url, file (the name in the download folder) and fetch (FALSE: read remotely, not downloaded).
# finish writes the files the stages read, with the names they read today, and returns the dataset's place (folder or file).
# Rasters inside zips are read where they sit (GDAL /vsizip//vsicurl/, byte ranges) and only the region is written: a 26 MB
# forest type tile comes out of a 2 GB regional zip without fetching the zip. National copies (no Study Area, or Keep national
# copies) fetch the whole zips instead. Handlers marked national = TRUE always keep the whole files: FIA DataMart (the growth curves
# fit on every state), PRISM (the growth curves' ecodivision climate covers CONUS) and LOCA2 (cut to its own regions).
# =============================================================================

# GDAL reading remote archives: Box and some servers answer HEAD with 404, so GDAL asks with ranged GETs
gdal_remote <- function() Sys.setenv(CPL_VSIL_CURL_USE_HEAD = "NO", GDAL_HTTP_MAX_RETRY = "5", GDAL_HTTP_RETRY_DELAY = "10", GDAL_HTTP_TIMEOUT = "600",
                                     CPL_VSIL_CURL_ALLOWED_EXTENSIONS = ".zip,.tif,.dbf,.nc", GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR")
remote_member <- function(url, member) sprintf("/vsizip//vsicurl/%s/%s", url, member)

# the 48 conterminous states and DC by FIPS (TIGER STATEFP)
CONUS_STATES <- c(`01` = "AL", `04` = "AZ", `05` = "AR", `06` = "CA", `08` = "CO", `09` = "CT", `10` = "DE", `11` = "DC", `12` = "FL", `13` = "GA",
  `16` = "ID", `17` = "IL", `18` = "IN", `19` = "IA", `20` = "KS", `21` = "KY", `22` = "LA", `23` = "ME", `24` = "MD", `25` = "MA", `26` = "MI",
  `27` = "MN", `28` = "MS", `29` = "MO", `30` = "MT", `31` = "NE", `32` = "NV", `33` = "NH", `34` = "NJ", `35` = "NM", `36` = "NY", `37` = "NC",
  `38` = "ND", `39` = "OH", `40` = "OK", `41` = "OR", `42` = "PA", `44` = "RI", `45` = "SC", `46` = "SD", `47` = "TN", `48` = "TX", `49` = "UT",
  `50` = "VT", `51` = "VA", `53` = "WA", `54` = "WV", `55` = "WI", `56` = "WY")

# the states the region touches, from the project's States stratum source; every state for CONUS or when there is no States source
region_states <- function(ctx) {
  if (is.null(ctx$region$poly)) return(unname(CONUS_STATES))
  s <- tryCatch({ rows <- sources_from_sheet(data.table::as.data.table(rsyncrosim::datasheet(ctx$prj, "lucasCore_StratumSource", optional = TRUE, lookupsAsFactors = FALSE)))
    rows[["States"]] }, error = function(e) NULL)
  if (is.null(s)) { ctx$log("  no States stratum source: taking every state"); return(unname(CONUS_STATES)) }
  sp <- sf::st_transform(strata_polygons(s, env$PackageDirectory, bbox = sf::st_bbox(ctx$region$poly)), 5070)
  hit <- sp[lengths(sf::st_intersects(sp, ctx$region$poly)) > 0, ]
  st <- unname(CONUS_STATES[sprintf("%02d", as.integer(hit$StratumId))]); st[!is.na(st)] }

# the years asked of an annual dataset, within what the source has
years_of <- function(ctx, have) { y1 <- if (is.na(ctx$years[2])) max(have) else ctx$years[2]; intersect(have, ctx$years[1]:y1) }

clipping <- function(ctx) !is.null(ctx$region$poly) && !ctx$keep

# a raster from a zip: the region read remotely, or (national) the whole zip fetched and the member unpacked. A remote read can
# break deep in a large zip (TreeMap's 5.4 GB zip64, 2026-10-31: a deflate error 12,000 rows in): then the whole zip is fetched
# (resumable) and clipped here
zip_raster <- function(ctx, items, i, member, dest) {
  if (clipping(ctx)) { gdal_remote()
    ok <- tryCatch({ clip_raster(remote_member(items$url[i], member), dest, ctx$region); TRUE }, error = function(e) { ctx$log(sprintf("  remote read of %s failed (%s): fetching the zip", basename(member), conditionMessage(e))); FALSE })
    if (ok) return(dest)
    fetch_files(items$url[i], items$dest[i], ctx$connections, ctx$log)
    x <- unzip_to(items$dest[i], file.path(ctx$dl, "unzip"), member); clip_raster(x, dest, ctx$region); unlink(x); return(dest) }
  x <- unzip_to(items$dest[i], file.path(ctx$dl, "unzip"), member); dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  file.rename(x, dest); dest }
# a dbf attribute table from a zip, read remotely (OGR) and written back, or unpacked from the fetched zip
zip_dbf <- function(ctx, items, i, member, dest) {
  if (clipping(ctx) && !file.exists(items$dest[i])) { gdal_remote(); x <- sf::st_drop_geometry(sf::read_sf(remote_member(items$url[i], member)))
    foreign::write.dbf(as.data.frame(x), dest); dest } else { x <- unzip_to(items$dest[i], file.path(ctx$dl, "unzip"), member); file.rename(x, dest); dest } }

BOX <- "https://usfs-public.box.com/shared/static/%s.zip"
RDS <- "https://www.fs.usda.gov/rds/archive/products/%s/%s"

download_handlers <- function() {
  H <- list()

  # ---- NFCMS v3 forest type groups: one tile per FIA region, read from its regional zip ----------------------------------
  nfcms <- c(PSW = "w6932ioy4vym4al2e3tr534almkh3dvs", PNW = "7izvs0615i8fovgv2sx1cnvzewmuqg7j", NE = "fw87536re6tj11lxdt04aixw6yrlkzln",
             NLS = "v861gwms9fq68sitl0r3vs2v3moxeu9x", NPS = "1ti822foipef1w9qs05tdo3olv7quin7", RMN = "141vgz2rz2u4mbeqodsu5w9wsejf8uy1",
             RMS = "ari2g6yf4bt4io0gw2nt5qzrb5gxqspp", SC = "w2qwgoq527nkuesv4xu6ppcy5d2bkui5", SE = "qecyblmgdpmovp2g67ze0sx594rtixo2")
  H$ForestTypeGroupFolder <- list(column = "ForestTypeGroupFolder", name = "USFS forest type groups (NFCMS v3)", version = "v3 (RDS-2025-0019)",
    note = "v3 tiles; the tiles on the build machine predate v3. No .vat.dbf ships with v3 (stage 5 reads the raw codes)",
    plan = function(ctx) data.table::data.table(url = sprintf(BOX, nfcms), file = paste0(names(nfcms), ".zip"), region = names(nfcms), fetch = !clipping(ctx)),
    finish = function(ctx, items) {
      gdal_remote(); dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE); n <- 0
      for (i in seq_len(nrow(items))) { m <- sprintf("Data/%s/%s_ForestType.tif", items$region[i], items$region[i]); dest <- file.path(ctx$place, basename(m))
        if (clipping(ctx)) { r <- terra::rast(remote_member(items$url[i], m))
          b <- terra::project(terra::vect(sf::st_as_sfc(sf::st_bbox(setNames(ctx$region$box, c("xmin", "ymin", "xmax", "ymax")), crs = sf::st_crs(5070)))), terra::crs(r))
          e <- terra::intersect(terra::ext(b), terra::ext(r)); if (is.null(e)) next
          v <- terra::global(terra::crop(r, e), "notNA")[[1]]; if (!isTRUE(v > 0)) { ctx$log(sprintf("  %s: no forest type cells in the region", items$region[i])); next } }
        zip_raster(ctx, items, i, m, dest); n <- n + 1; ctx$log(sprintf("  %s_ForestType.tif", items$region[i])) }
      if (!n) stop("no NFCMS region tile covers the region", call. = FALSE)
      ctx$place })

  # ---- TreeMap 2016: the raster and its attribute table (the plots), from one zip ------------------------------------
  H$TreeMapFolder <- list(column = "TreeMapFolder", name = "TreeMap 2016", version = "2016 (RDS-2021-0074)",
    plan = function(ctx) data.table::data.table(url = sprintf(BOX, "yz7h8b8v92scoqfwukjyulokaevzo6v6"), file = "TreeMap2016.zip", fetch = !clipping(ctx)),
    finish = function(ctx, items) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE)
      zip_raster(ctx, items, 1, "Data/TreeMap2016.tif", file.path(ctx$place, "TreeMap2016.tif"))
      zip_dbf(ctx, items, 1, "Data/TreeMap2016.tif.vat.dbf", file.path(ctx$place, "TreeMap2016.tif.vat.dbf")); ctx$place })

  # ---- FIA DataMart: four tables of every state, and the reference tables (national: the growth curves use every state) ---
  H$FiaDataMartFolder <- list(column = "FiaDataMartFolder", name = "FIA DataMart (all states)", national = TRUE, version = "FIADB (replaced in place)",
    note = "All 48 states: PLOT, COND, TREE, COND_DWM_CALC; FIADB_REFERENCE.zip kept zipped",
    plan = function(ctx) { st <- setdiff(unname(CONUS_STATES), "DC"); tb <- c("PLOT", "COND", "TREE", "COND_DWM_CALC")
      x <- data.table::CJ(st = st, tb = tb)[, .(url = sprintf("https://apps.fs.usda.gov/fia/datamart/CSV/%s_%s.zip", st, tb), file = sprintf("%s_%s.zip", st, tb))]
      rbind(x, data.table::data.table(url = "https://apps.fs.usda.gov/fia/datamart/CSV/FIADB_REFERENCE.zip", file = "FIADB_REFERENCE.zip"))[, fetch := TRUE][] },
    finish = function(ctx, items) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE)
      for (i in seq_len(nrow(items))) { if (items$file[i] == "FIADB_REFERENCE.zip") { file.copy(items$dest[i], file.path(ctx$place, items$file[i]), overwrite = TRUE); next }
        utils::unzip(items$dest[i], exdir = ctx$place) }
      for (f in c("fia-sites.rds", "fia-conditions.rds", "fia-deadwood.rds")) unlink(file.path(ctx$place, f))   # caches of the old tables
      ctx$place })

  # ---- MTBS burn severity mosaics: one ScienceBase item a year (no byte ranges: each zip is fetched whole, 2-10 MB) -------
  H$MtbsSeverityFolder <- list(column = "MtbsSeverityFolder", name = "MTBS burn severity", version = "ScienceBase 5e91dee782ce172707f02cdd",
    plan = function(ctx) { j <- jsonlite::fromJSON("https://www.sciencebase.gov/catalog/items?parentId=5e91dee782ce172707f02cdd&format=json&max=200&fields=title,files", simplifyVector = FALSE)$items
      x <- data.table::rbindlist(lapply(j, function(it) { y <- as.integer(regmatches(it$title, regexpr("(?<=for )[0-9]{4}", it$title, perl = TRUE)))
        if (!length(y)) return(NULL); f <- Filter(function(f) identical(f$name, sprintf("mtbs_CONUS_%d.zip", y)), it$files); if (!length(f)) return(NULL)
        data.table::data.table(year = y, url = sprintf("https://www.sciencebase.gov/catalog/file/get/%s?name=%s", it$id, f[[1]]$name), file = f[[1]]$name) }))
      x[year %in% years_of(ctx, x$year)][order(year)][, fetch := TRUE][] },
    finish = function(ctx, items) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE)
      for (i in seq_len(nrow(items))) { t <- sprintf("mtbs_CONUS_%d.tif", items$year[i]); x <- unzip_to(items$dest[i], file.path(ctx$dl, "unzip"), t)
        clip_raster(x, file.path(ctx$place, t), if (clipping(ctx)) ctx$region else list(poly = NULL)); unlink(x) }
      ctx$place })

  # ---- LCMS annual change: one zip a year, read remotely ------------------------------------------------------------
  H$LcmsFolder <- list(column = "LcmsFolder", name = "USFS LCMS annual change", version = "v2025-11",
    plan = function(ctx) { y <- years_of(ctx, 1985:2025)
      data.table::data.table(year = y, url = sprintf("https://data.fs.usda.gov/geodata/LCMS/LCMS_CONUS_v2025-11_Change_Annual_%d.zip", y), file = sprintf("LCMS_%d.zip", y), fetch = !clipping(ctx)) },
    finish = function(ctx, items) {
      for (i in seq_len(nrow(items))) { t <- sprintf("LCMS_CONUS_v2025-11_Change_%d.tif", items$year[i])
        zip_raster(ctx, items, i, t, file.path(ctx$place, items$year[i], t)); ctx$log(sprintf("  LCMS %d", items$year[i])) }
      ctx$place })

  # ---- FSim burn probability (CONUS 270 m), read remotely ---------------------------------------------------------------
  H$BurnProbabilityFile <- list(column = "BurnProbabilityFile", name = "FSim burn probability", version = "RDS-2016-0034-3",
    plan = function(ctx) data.table::data.table(url = sprintf(RDS, "RDS-2016-0034-3", "RDS-2016-0034-3.zip"), file = "fsim.zip", fetch = !clipping(ctx)),
    finish = function(ctx, items) zip_raster(ctx, items, 1, "Data/I_FSim_CONUS_LF2020_270m/CONUS_BP.tif", file.path(ctx$place, "CONUS_BP.tif")))

  # ---- FPA-FOD: the GeoPackage (fetched: a database is slow to read through a remote zip), its Fires layer clipped -------
  H$FpaFodFile <- list(column = "FpaFodFile", name = "FPA-FOD fire occurrence", version = "RDS-2013-0009.7",
    plan = function(ctx) data.table::data.table(url = sprintf(RDS, "RDS-2013-0009.7", "RDS-2013-0009.7_Data_Format3_GPKG.zip"), file = "fpafod.zip", fetch = TRUE),
    finish = function(ctx, items) { x <- unzip_to(items$dest[1], file.path(ctx$dl, "unzip"), "Data/FPA_FOD_20260615.gpkg"); dest <- file.path(ctx$place, "FPA_FOD_20260615.gpkg")
      if (clipping(ctx)) clip_vector(x, dest, ctx$region, layer = "Fires") else { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE); file.rename(x, dest) }
      dest })

  # ---- PRISM: annual tmean and ppt (4 km, "us_25m") and the 1991-2020 normals, national (small) ------------------------
  # from PRISM's HTTP mirror (sizes and byte ranges; the web service blocks a file fetched twice in 24 h). Stage 7 needs the year
  # before the first year, and 1991-2020 for its normal
  H$PrismFolder <- list(column = "PrismFolder", name = "PRISM annual climate and normals", national = TRUE, version = "PRISM AN (us_25m, 4 km)",
    plan = function(ctx) { last <- as.integer(format(Sys.Date(), "%Y")) - 1L; y <- sort(unique(c(years_of(ctx, 1895:last), 1991:2020, min(years_of(ctx, 1895:last)) - 1L)))
      a <- data.table::CJ(var = c("tmean", "ppt"), year = y)[, .(var, year, url = sprintf("https://data.prism.oregonstate.edu/time_series/us/an/4km/%s/monthly/%d/prism_%s_us_25m_%d.zip", var, year, var, year),
                                                                 file = sprintf("prism_%s_us_25m_%d.zip", var, year))]
      n <- data.table::data.table(var = c("tmean", "ppt"), year = NA_integer_, url = sprintf("https://data.prism.oregonstate.edu/normals/us/4km/%s/monthly/prism_%s_us_25m_2020_avg_30y.zip", c("tmean", "ppt"), c("tmean", "ppt")),
                                  file = sprintf("prism_%s_us_25m_2020_avg_30y.zip", c("tmean", "ppt")))
      rbind(a, n)[, fetch := TRUE][] },
    finish = function(ctx, items) {
      for (i in seq_len(nrow(items))) utils::unzip(items$dest[i], exdir = if (is.na(items$year[i])) file.path(ctx$place, "normals") else file.path(ctx$place, "annual-us25m", items$var[i]))
      ctx$place })

  # ---- LOCA2: monthly pr, tasmax, tasmin of each model's historical and SSP runs. The UCSD regional cut when the region
  # lies in one ("west" holds California), else the CONUS files. tasmax and tasmin regional files end ".monthly.west.nc": saved
  # as ".west.monthly.nc" so src/loca2.R's "*.monthly.nc" finds them ------------------------------------------------------
  H$Loca2Folder <- list(column = "Loca2Folder", name = "LOCA2 climate projections", national = TRUE, version = "LOCA2 (UCSD)",
    plan = function(ctx) {
      lst <- function(x, d) { v <- if (nrow(ctx$opts) && x %in% names(ctx$opts)) ctx$opts[[x]][1] else NA; if (is.na(v) || !nzchar(v)) d else trimws(strsplit(v, ",")[[1]]) }
      models <- lst("Loca2Models", tryCatch(as.character(rsyncrosim::datasheet(ctx$prj, "lucasCore_ClimateModel", optional = TRUE)$Name), error = function(e) character()))
      if (!length(models)) stop("Data Download: list the LOCA2 models (the project's Climate Model list is empty)", call. = FALSE)
      scen <- lst("Loca2Scenarios", c("ssp245", "ssp370", "ssp585")); want_mem <- lst("Loca2Member", "r1i1p1f1")[1]
      ll <- if (is.null(ctx$region$poly)) NULL else region_box_ll(ctx$region)
      west <- !is.null(ll) && ll[1] >= -124.69 && ll[3] <= -113.75 && ll[2] >= 31.94 && ll[4] <= 42.06
      base <- if (west) "https://cirrus.ucsd.edu/~pierce/LOCA2/CONUS_regions_split/%s/west/0p0625deg/%s/%s/%s/" else "https://cirrus.ucsd.edu/~pierce/LOCA2/NAmer/%s/0p0625deg/%s/%s/%s/"
      ctx$log(sprintf("  LOCA2: %s files, %d models x %d runs", if (west) "west regional" else "CONUS", length(models), length(scen) + 1))
      # members differ by model (CNRM-ESM2-1 has r1i1p1f2): the asked member when the model has it, else its first
      member_of <- function(g) { d <- sub("%s/%s/%s/$", "", sprintf(base, g, "%s", "%s", "%s")); h <- tryCatch(rawToChar(curl::curl_fetch_memory(d)$content), error = function(e) "")
        m <- unique(regmatches(h, gregexpr("(?<=href=\")r[0-9]+i[0-9]+p[0-9]+f[0-9]+(?=/\")", h, perl = TRUE))[[1]])
        if (!length(m) || want_mem %in% m) return(want_mem)
        ctx$log(sprintf("  LOCA2: %s has no %s; taking %s", g, want_mem, m[1])); m[1] }
      data.table::rbindlist(lapply(models, function(g) { mem <- member_of(g); data.table::rbindlist(lapply(c("historical", scen), function(r) data.table::rbindlist(lapply(c("pr", "tasmax", "tasmin"), function(v) {
        d <- sprintf(base, g, mem, r, v); h <- tryCatch(rawToChar(curl::curl_fetch_memory(d)$content), error = function(e) "")
        f <- unique(regmatches(h, gregexpr(sprintf('%s[.][^"]*?[.](west[.]monthly|monthly[.]west|monthly)[.]nc(?=")', v), h, perl = TRUE))[[1]])
        if (!length(f)) { ctx$log(sprintf("  LOCA2: no %s %s %s %s files", g, mem, r, v)); return(NULL) }
        data.table::data.table(url = paste0(d, f), file = file.path(g, mem, r, v, sub("[.]monthly[.]west[.]nc$", ".west.monthly.nc", f))) })))) }))[, fetch := TRUE][] },
    finish = function(ctx, items) { for (i in seq_len(nrow(items))) { dest <- file.path(ctx$place, items$file[i]); dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
        file.rename(items$dest[i], dest) }
      ctx$place })

  # ---- SILVIS WUI: one geodatabase per state the region touches ---------------------------------------------------------
  H$WuiFolder <- list(column = "WuiFolder", name = "SILVIS WUI v4 (by state)", version = "v4, 1990-2020",
    plan = function(ctx) { st <- region_states(ctx)
      data.table::data.table(url = sprintf("https://geoserver.silvis.forest.wisc.edu/geodata/wui_change_2020_v4/zip/fgdb/%s_wui_block_1990_2020_change_v4_fgdb.zip", st),
                             file = sprintf("%s_wui_block_1990_2020_change_v4_fgdb.zip", st), fetch = TRUE) },
    finish = function(ctx, items) { for (i in seq_len(nrow(items))) utils::unzip(items$dest[i], exdir = ctx$place); ctx$place })

  # ---- USFS forest ownership circa 2017, read remotely, with its attribute table ---------------------------------------
  H$ForestOwnerFile <- list(column = "ForestOwnerFile", name = "USFS forest ownership 2017", version = "circa 2017 (RDS-2020-0044)",
    plan = function(ctx) data.table::data.table(url = sprintf(RDS, "RDS-2020-0044", "RDS-2020-0044.zip"), file = "owner.zip", fetch = !clipping(ctx)),
    finish = function(ctx, items) { dest <- file.path(ctx$place, "forest_own1.tif")
      zip_raster(ctx, items, 1, "Data/forest_own1/forest_own1.tif", dest)
      zip_dbf(ctx, items, 1, "Data/forest_own1/forest_own1.tif.vat.dbf", paste0(dest, ".vat.dbf")); dest })
  H }
