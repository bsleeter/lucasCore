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
  if (clipping(ctx) && !file.exists(items$dest[i])) { gdal_remote()
    ok <- tryCatch({ clip_raster(remote_member(items$url[i], member), dest, ctx$region); TRUE }, error = function(e) { ctx$log(sprintf("  remote read of %s failed (%s): fetching the zip", basename(member), conditionMessage(e))); FALSE })
    if (ok) return(dest)
    gc(); unlink(paste0(dest, c("", ".aux.xml")))   # the broken attempt's partial file
    fetch_files(items$url[i], items$dest[i], ctx$connections, ctx$log)
    x <- unzip_to(items$dest[i], file.path(ctx$dl, "unzip"), member); clip_raster(x, dest, ctx$region); unlink(x); return(dest) }
  x <- unzip_to(items$dest[i], file.path(ctx$dl, "unzip"), member)
  if (clipping(ctx)) { clip_raster(x, dest, ctx$region); unlink(x); return(dest) }
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE); file.rename(x, dest); dest }
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
    # fetched whole even for a region: its 4 GB raster is deflated, so a remote read streams nearly all of it, and one broke
    # 12,000 rows in (2026-10-31); the zip comes down in minutes
    plan = function(ctx) data.table::data.table(url = sprintf(BOX, "yz7h8b8v92scoqfwukjyulokaevzo6v6"), file = "TreeMap2016.zip", fetch = TRUE),
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
      # the runs UCSD serves (defaults/download/loca2-catalog.csv, tools/loca2-catalog.R): members differ by model (CNRM-ESM2-1 has
      # r1i1p1f2), and three models have no monthly files in the west cut, so those runs come from the CONUS tree. Blank = one run:
      # the project's first Climate Model UCSD serves (else the catalog's first), ssp245, and each model's r1i1p1f1, else its first;
      # asked members a model lacks fall back the same way
      cat2 <- data.table::fread(pkg_file("defaults", "download", "loca2-catalog.csv"))
      pm <- tryCatch(as.character(rsyncrosim::datasheet(ctx$prj, "lucasCore_ClimateModel", optional = TRUE)$Name), error = function(e) character())
      models <- lst("Loca2Models", c(intersect(sort(pm), cat2$Model), sort(unique(cat2$Model)))[1])
      scen <- lst("Loca2Scenarios", "ssp245"); want_mem <- lst("Loca2Member", character())
      ll <- if (is.null(ctx$region$poly)) NULL else region_box_ll(ctx$region)
      west <- !is.null(ll) && ll[1] >= -124.69 && ll[3] <= -113.75 && ll[2] >= 31.94 && ll[4] <= 42.06
      miss <- setdiff(models, cat2$Model); if (length(miss)) ctx$log(sprintf("  LOCA2: not in the UCSD catalog, skipped: %s", paste(miss, collapse = ", ")))
      first <- function(m) if ("r1i1p1f1" %in% m) "r1i1p1f1" else m[1]
      runs <- data.table::rbindlist(lapply(intersect(models, cat2$Model), function(g) { m <- unique(cat2[Model == g, Member])
        mem <- if (length(want_mem)) intersect(want_mem, m) else first(m)
        if (!length(mem)) { mem <- first(m); ctx$log(sprintf("  LOCA2: %s has none of %s; taking %s", g, paste(want_mem, collapse = ", "), mem)) }
        cat2[Model == g & Member %in% mem & Scenario %in% c("historical", scen)] }))
      gone <- unique(runs[, .(Model, Member)])[, .(Scenario = c("historical", scen)), by = .(Model, Member)][!runs, on = .(Model, Member, Scenario)]
      if (nrow(gone)) ctx$log(sprintf("  LOCA2: UCSD has no %s", paste(gone$Model, gone$Member, gone$Scenario, collapse = ", ")))
      runs[, tree := if (west) ifelse(West == "yes", "west", "conus") else "conus"]
      ctx$log(sprintf("  LOCA2: %d runs of %d models (%d west regional, %d CONUS)", nrow(runs), data.table::uniqueN(runs$Model), sum(runs$tree == "west"), sum(runs$tree == "conus")))
      base <- c(west = "https://cirrus.ucsd.edu/~pierce/LOCA2/CONUS_regions_split/%s/west/0p0625deg/%s/%s/%s/", conus = "https://cirrus.ucsd.edu/~pierce/LOCA2/NAmer/%s/0p0625deg/%s/%s/%s/")
      data.table::rbindlist(lapply(seq_len(nrow(runs)), function(k) data.table::rbindlist(lapply(c("pr", "tasmax", "tasmin"), function(v) {
        g <- runs$Model[k]; mem <- runs$Member[k]; r <- runs$Scenario[k]
        d <- sprintf(base[[runs$tree[k]]], g, mem, r, v); h <- tryCatch(rawToChar(curl::curl_fetch_memory(d)$content), error = function(e) "")
        f <- unique(regmatches(h, gregexpr(sprintf('%s[.][^"]*?[.](west[.]monthly|monthly[.]west|monthly)[.]nc(?=")', v), h, perl = TRUE))[[1]])
        if (!length(f)) { ctx$log(sprintf("  LOCA2: no %s %s %s %s files", g, mem, r, v)); return(NULL) }
        data.table::data.table(url = paste0(d, f), file = file.path(g, mem, r, v, sub("[.]monthly[.]west[.]nc$", ".west.monthly.nc", f))) }))))[, fetch := TRUE][] },
    # in place = at the size files.csv recorded for it (a file put there by hand, unrecorded, is fetched again)
    have = function(ctx, items) recorded(ctx, "Loca2Folder", file.path(ctx$place, items$file)),
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

  # ==== clipped by the source (phase 4): nothing national is fetched; each needs a Study Area ===============================

  # ---- Annual NLCD land cover (Collection 1.2) by WCS 1.0.0, one coverage a year, in tiles on the 30 m grid -----------------
  H$NlcdFolder <- list(column = "NlcdFolder", name = "Annual NLCD land cover", version = "Collection 1.2 (C1V2)", method = "wcs",
    note = "Clipped by MRLC's WCS; C1V2 for every year (the only collection published)",
    plan = function(ctx) { need_region(ctx, "Annual NLCD")
      have <- as.integer(substr(regmatches(x <- rawToChar(curl::curl_fetch_memory(paste0(NLCD_WCS, "?service=WCS&version=1.0.0&request=DescribeCoverage&coverage=", NLCD_COV))$content),
        gregexpr("(?<=<gml:timePosition>)[0-9]{4}", x, perl = TRUE))[[1]], 1, 4))
      y <- years_of(ctx, sort(unique(have)))
      data.table::data.table(year = y, url = NLCD_WCS, file = sprintf("Annual_NLCD_LndCov_%d_CU_C1V2.tif", y), fetch = FALSE) },
    have = function(ctx, items) recorded(ctx, "NlcdFolder", file.path(ctx$place, items$file)),
    finish = function(ctx, items) {
      tl <- grid_tiles(ctx$region$box, c(-2415585, 3314805), 30, 4000)
      for (i in seq_len(nrow(items))) { y <- items$year[i]
        u <- sprintf("%s?service=WCS&version=1.0.0&request=GetCoverage&coverage=%s&crs=EPSG:5070&bbox=%.0f,%.0f,%.0f,%.0f&width=%d&height=%d&time=%d-01-01T00:00:00.000Z&format=GeoTIFF",
                     NLCD_WCS, NLCD_COV, tl$xmin, tl$ymin, tl$xmax, tl$ymax, tl$nx, tl$ny, y)
        parts <- file.path(ctx$dl, y, sprintf("tile%02d.tif", seq_len(nrow(tl))))
        fetch_files(u, parts, ctx$connections, ctx$log, sizes = rep(NA_real_, length(u)))
        mosaic_to(parts, file.path(ctx$place, items$file[i]), "INT1U"); unlink(dirname(parts[1]), recursive = TRUE)
        ctx$log(sprintf("  NLCD %d (%d tiles)", y, nrow(tl))) }
      ctx$place })

  # ---- LANDFIRE layers by LANDFIRE Product Service jobs (the job clips; output on LANDFIRE's own grid) -----------------
  lf_single <- function(column, name, layer, version, out) list(column = column, name = name, version = version, method = "lfps",
    plan = function(ctx) { need_region(ctx, name); lfps_email(ctx); data.table::data.table(url = LFPS, file = out, layer = layer, fetch = FALSE) },
    finish = function(ctx, items) { b <- lfps_job(ctx, items$layer)
      dest <- file.path(ctx$place, out); write_band(b, 1, dest); dest })
  H$Evt2016File <- lf_single("Evt2016File", "LANDFIRE EVT 2016", "LF2016_EVT", "LF 2.0.0 (LF2016_EVT)", "LC16_EVT_200.tif")
  H$FriFile <- lf_single("FriFile", "LANDFIRE mean fire return interval", "LF2016_FRI", "LF 2016 (LF2016_FRI)", "LC16_FRI_200.tif")
  H$ElevationFile <- lf_single("ElevationFile", "LANDFIRE elevation", "LF2020_Elev", "LF 2020 (LF2020_Elev)", "LC20_Elev_220.tif")
  H$RoadsFile <- lf_single("RoadsFile", "LANDFIRE roads", "LF2023_Roads", "LF 2023 (LF2023_Roads)", "LF2023_Roads_CONUS.tif")

  # disturbance: one layer a year (LF2001_Dist99 ... LF2025_Dist25), all the missing years in one job; each year laid out as the
  # stages read it (US_DIST<year>/<name>/Tif and CSV_Data), with the attribute table shipped in defaults/landfire/disturbance
  H$LandfireDisturbanceFolder <- list(column = "LandfireDisturbanceFolder", name = "LANDFIRE annual disturbance", version = "LF2001_Dist99 to LF2025_Dist25", method = "lfps",
    note = "Attribute tables from the package (defaults/landfire/disturbance); 2023 and 2025 tables are the provisional editions'",
    plan = function(ctx) { need_region(ctx, "LANDFIRE disturbance"); lfps_email(ctx)
      p <- jsonlite::fromJSON(paste0(LFPS, "/products"))$products; l <- grep("^LF[0-9]{4}_Dist[0-9]{2}$", p$layerName, value = TRUE)
      yy <- as.integer(sub(".*_Dist", "", l)); yr <- ifelse(yy > 80, 1900L + yy, 2000L + yy)
      x <- data.table::data.table(year = yr, layer = l)[year %in% years_of(ctx, yr)][order(year)]
      x[, `:=`(url = LFPS, file = sprintf("US_DIST%d/LF%d_Dist/Tif/LF%d_Dist.tif", year, year, year), fetch = FALSE)][] },
    have = function(ctx, items) recorded(ctx, "LandfireDisturbanceFolder", file.path(ctx$place, items$file)),
    finish = function(ctx, items) { b <- lfps_job(ctx, items$layer)
      for (i in seq_len(nrow(items))) { y <- items$year[i]; write_band(b, i, file.path(ctx$place, items$file[i]))
        csv <- pkg_file("defaults", "landfire", "disturbance", sprintf("US_DIST%d.csv", y)); cd <- file.path(ctx$place, sprintf("US_DIST%d/LF%d_Dist/CSV_Data", y, y))
        dir.create(cd, recursive = TRUE, showWarnings = FALSE); file.copy(csv, file.path(cd, sprintf("LF%d_Dist.csv", y)), overwrite = TRUE) }
      ctx$place })

  # ---- NIFC Interagency Fire Perimeter History by ArcGIS REST, paged (2,000 features a page), to a GeoPackage -----------
  # from the six decade services: the All Years View holds only 342 perimeters from 2020 on (2026-11-01; the 2020s service has
  # 18,484), so it no longer matches the shapefile the build machine downloaded
  H$FirePerimeterHistoryFile <- list(column = "FirePerimeterHistoryFile", name = "Interagency fire perimeter history", version = "InterAgencyFirePerimeterHistory decade services (1979 and prior to 2020s)", method = "rest",
    plan = function(ctx) data.table::data.table(url = NIFC[1], file = "InterAgencyFirePerimeterHistory.gpkg", fetch = FALSE),
    finish = function(ctx, items) {
      geo <- if (is.null(ctx$region$poly)) "" else { b <- region_box_ll(ctx$region)
        sprintf("&geometry=%f,%f,%f,%f&geometryType=esriGeometryEnvelope&inSR=4326&spatialRel=esriSpatialRelIntersects", b[1], b[2], b[3], b[4]) }
      parts <- lapply(NIFC, function(s) {
        q <- function(extra) curl::curl_fetch_memory(sprintf("%s/query?where=1%%3D1%s%s", s, geo, extra))
        n <- jsonlite::fromJSON(rawToChar(q("&returnCountOnly=true&f=json")$content))$count
        if (!n) return(NULL)
        pages <- lapply(seq(0, n - 1, by = 2000), function(o) { for (k in 1:4) { r <- tryCatch(q(sprintf("&outFields=*&orderByFields=OBJECTID&resultOffset=%d&resultRecordCount=2000&outSR=4326&f=geojson", o)), error = function(e) NULL)
            if (!is.null(r) && r$status_code == 200) return(sf::read_sf(rawToChar(r$content), quiet = TRUE)); Sys.sleep(5 * k) }
          stop(sprintf("fire perimeters: %s page at %d failed", basename(dirname(dirname(s))), o), call. = FALSE) })
        x <- do.call(rbind, pages)
        if (nrow(x) != n) stop(sprintf("fire perimeters: %d of %d features came from %s", nrow(x), n, basename(dirname(dirname(s)))), call. = FALSE)
        ctx$log(sprintf("  %s: %d perimeters", sub("_Read_Only$", "", basename(dirname(dirname(s)))), n)); x })
      parts <- Filter(Negate(is.null), parts); keep <- Reduce(intersect, lapply(parts, names))
      x <- sf::st_transform(do.call(rbind, lapply(parts, function(p) p[, keep])), 5070)
      dest <- file.path(ctx$place, items$file[1]); dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE); if (file.exists(dest)) file.remove(dest)
      sf::write_sf(x, dest, layer = "perimeters"); dest })

  # ---- NOAA C-CAP 2001 (cloud-optimized GeoTIFF): the region read where it sits, or the whole file fetched for CONUS ------
  H$CcapFile <- list(column = "CcapFile", name = "C-CAP land cover 2001", version = "C-CAP Regional 2001", method = "cog",
    plan = function(ctx) data.table::data.table(url = CCAP, file = "conus_2001_ccap_landcover.tif", fetch = !clipping(ctx)),
    finish = function(ctx, items) { dest <- file.path(ctx$place, items$file[1])
      clip_raster(if (clipping(ctx)) paste0("/vsicurl/", CCAP) else items$dest[1], dest, if (clipping(ctx)) ctx$region else list(poly = NULL)) })

  # ---- gNATSGO (Planetary Computer): soil organic carbon and crop productivity, the region's 10 m tiles cropped -----------
  gnatsgo <- function(column, name, asset, out, note) list(column = column, name = name, version = "gNATSGO July 2020 (gnatsgo-rasters)", method = "stac", note = note,
    plan = function(ctx) { need_region(ctx, name); data.table::data.table(url = PC_STAC, file = out, fetch = FALSE) },
    finish = function(ctx, items) { dest <- file.path(ctx$place, out); gnatsgo_region(ctx, asset, dest); dest })
  H$SoilCarbonFile <- gnatsgo("SoilCarbonFile", "gNATSGO soil organic carbon", "soc0_999", "gnatsgo_soc0_999.tif", "gNATSGO soc0_999 (gSSURGO with its gaps filled), not the gSSURGO file of the build machine")
  H$NccpiFile <- gnatsgo("NccpiFile", "gNATSGO crop productivity (NCCPI)", "nccpi3all", "gnatsgo_nccpi3all.tif", "nccpi3all at 10 m; stage 10 reads it onto its 30 m grid")

  # ==== behind a login (phase 5) ==========================================================================================

  # ---- NASA CMS forest age 1990 (ORNL DAAC 1829): the FIA-region tiles touching the region (boxes from NASA's CMR), fetched
  # with an Earthdata token, checked against the DAAC's public sha256 files, clipped and mosaicked into one raster -------------
  H$StandAgeFile <- list(column = "StandAgeFile", name = "NASA CMS forest age 1990", version = "ORNL DAAC 1829 (10.3334/ORNLDAAC/1829)", method = "login",
    plan = function(ctx) {
      g <- jsonlite::fromJSON(sprintf("https://cmr.earthdata.nasa.gov/search/granules.json?collection_concept_id=%s&page_size=200&readable_granule_name=*_age_1990.tif&options%%5Breadable_granule_name%%5D%%5Bpattern%%5D=true", CMS_AGE), simplifyVector = FALSE)$feed$entry
      t <- data.table::rbindlist(lapply(g, function(e) { b <- as.numeric(strsplit(e$boxes[[1]], " ")[[1]])   # south west north east
        u <- Filter(function(l) grepl("/protected/.*_age_1990[.]tif$", l$href), e$links)
        if (!length(u)) NULL else data.table::data.table(src = u[[1]]$href, s = b[1], w = b[2], n = b[3], e = b[4]) }))
      if (!nrow(t)) stop("NASA CMR lists no 1990 forest age tiles", call. = FALSE)
      if (!is.null(ctx$region$poly)) { ll <- region_box_ll(ctx$region); t <- t[w < ll[3] & e > ll[1] & s < ll[4] & n > ll[2]] }
      tok <- edl_token(ctx)
      t[, `:=`(url = vapply(src, edl_signed, "", token = tok), file = basename(src), fetch = TRUE)][] },
    finish = function(ctx, items) {
      for (i in seq_len(nrow(items))) { h <- tryCatch(strsplit(rawToChar(curl::curl_fetch_memory(sub("/protected/", "/public/", paste0(items$src[i], ".sha256")))$content), "\\s+")[[1]][1], error = function(e) NA)
        if (!is.na(h) && !identical(tolower(h), digest::digest(file = items$dest[i], algo = "sha256"))) { unlink(items$dest[i]); stop(sprintf("%s: sha256 does not match the DAAC's; rerun to fetch it again", items$file[i]), call. = FALSE) } }
      # (CMR's lon/lat boxes overlap: a tile can touch the region's box yet hold no age there; those are left out of the mosaic)
      parts <- unlist(lapply(seq_len(nrow(items)), function(i) { p <- tryCatch(clip_raster(items$dest[i], file.path(ctx$dl, "clip", items$file[i]), if (clipping(ctx)) ctx$region else list(poly = NULL)), error = function(e) NA_character_)
        if (is.na(p) || !isTRUE(terra::global(terra::rast(p), "notNA")[[1]] > 0)) NULL else p }))
      if (!length(parts)) stop("no forest age tile holds cells in the region", call. = FALSE)
      dest <- file.path(ctx$place, "cms_age_1990.tif"); r <- terra::rast(parts[1])
      if (length(parts) == 1) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE); file.copy(parts, dest, overwrite = TRUE) } else mosaic_to(parts, dest, terra::datatype(r))
      ctx$log(sprintf("  forest age 1990: %d regional tiles (%s)", nrow(items), paste(sub("_age_1990.tif", "", items$file), collapse = ", "))); dest })
  H }

# ---- service helpers (phase 4) ----------------------------------------------------------------------------------------------
NLCD_WCS <- "https://dmsdata.cr.usgs.gov/geoserver/mrlc_Land-Cover-Native_conus_year_data/wcs"
NLCD_COV <- "mrlc_Land-Cover-Native_conus_year_data:Land-Cover-Native_conus_year_data"
LFPS <- "https://lfps.usgs.gov/api"
NIFC <- sprintf("https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/%s/FeatureServer/0", c("InterAgencyFirePerimeterHistory_1979_And_Prior_Read_Only",
  "InteragencyFirePerimeterHistory_1980s_Read_Only", "InteragencyFirePerimeterHistory_1990s_Read_Only", "InteragencyFirePerimeterHistor_2000s_Read_Only",
  "InteragencyFirePerimeterHistory_2010s_Read_Only", "InterAgencyFirePerimeterHistory_2020s_Read_Only"))
CCAP <- "https://ocmgeodatastor1.blob.core.windows.net/ccap/bulk_download/C-CAP_Regional_30-meter_Data/C-CAP_Regional_Land_Cover_Classification/CONUS/conus_2001_ccap_landcover.tif"
PC_STAC <- "https://planetarycomputer.microsoft.com/api/stac/v1"

CMS_AGE <- "C2389890387-ORNL_CLOUD"   # NASA CMR collection of ORNL DAAC 1829

# the Earthdata token: EARTHDATA_TOKEN in the environment, else the home folder's settings.csv (the Data Download page writes it).
# A token is made at urs.earthdata.nasa.gov (Generate Token) and lasts 60 days
edl_token <- function(ctx) { t <- Sys.getenv("EARTHDATA_TOKEN"); if (!nzchar(t)) t <- home_setting(ctx$home, "EarthdataToken")
  if (is.na(t) || !nzchar(t)) stop("NASA CMS forest age needs an Earthdata login: make a token at urs.earthdata.nasa.gov (Generate Token) and enter it on the Data Download page, or set EARTHDATA_TOKEN", call. = FALSE)
  t }

# a protected DAAC url to the signed url it redirects to: the token goes with this first request only (the signed url takes no
# header, and some storage refuses one), so the fetch after it is the ordinary resumable one
edl_signed <- function(url, token) {
  h <- curl::new_handle(followlocation = FALSE, range = "0-0", timeout = 60); curl::handle_setheaders(h, Authorization = paste("Bearer", token))
  r <- curl::curl_fetch_memory(url, handle = h); loc <- curl::parse_headers_list(r$headers)[["location"]]
  if (r$status_code %in% c(401, 403) || (!is.null(loc) && grepl("urs[.]earthdata", loc)))
    stop("Earthdata refused the token (tokens last 60 days): make a new one at urs.earthdata.nasa.gov and enter it on the Data Download page", call. = FALSE)
  if (r$status_code < 300 || r$status_code >= 400 || is.null(loc)) stop(sprintf("%s: the DAAC answered %d, not a redirect", basename(url), r$status_code), call. = FALSE)
  loc }

need_region <- function(ctx, what) if (is.null(ctx$region$poly))
  stop(sprintf("%s is clipped by its source for a Study Area; for all of CONUS fetch the national files by hand", what), call. = FALSE)

# the planned files already recorded in files.csv at their recorded size (a hand-placed, unrecorded file is fetched again)
recorded <- function(ctx, column, paths) { f <- read_files(ctx$home)[Column == column]
  rel <- substring(normalizePath(paths, winslash = "/", mustWork = FALSE), nchar(normalizePath(ctx$home, winslash = "/")) + 2)
  b <- f$Bytes[match(rel, f$Path)]; !is.na(b) & file.exists(paths) & file.size(paths) == as.numeric(b) }

# the region's box snapped outward to a grid (origin = the grid's top-left corner), cut into tiles of at most `px` cells a side
grid_tiles <- function(box, origin, cell, px) {
  x0 <- origin[1] + floor((box[1] - origin[1]) / cell) * cell; x1 <- origin[1] + ceiling((box[3] - origin[1]) / cell) * cell
  y1 <- origin[2] - floor((origin[2] - box[4]) / cell) * cell; y0 <- origin[2] - ceiling((origin[2] - box[2]) / cell) * cell
  xs <- seq(x0, x1, by = px * cell); if (tail(xs, 1) < x1) xs <- c(xs, x1); ys <- seq(y1, y0, by = -px * cell); if (tail(ys, 1) > y0) ys <- c(ys, y0)
  t <- data.table::CJ(i = seq_len(length(xs) - 1), j = seq_len(length(ys) - 1))
  t[, `:=`(xmin = xs[i], xmax = xs[i + 1], ymax = ys[j], ymin = ys[j + 1])][, `:=`(nx = as.integer(round((xmax - xmin) / cell)), ny = as.integer(round((ymax - ymin) / cell)))][] }

# tiles on one grid into one compressed GeoTIFF
mosaic_to <- function(parts, dest, datatype) { dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  v <- terra::vrt(parts, filename = tempfile(fileext = ".vrt"))
  terra::writeRaster(v, dest, overwrite = TRUE, datatype = datatype, gdal = c("COMPRESS=DEFLATE", "TILED=YES", "BIGTIFF=IF_SAFER")); dest }

# a band of a multi-band job output written as its own file
write_band <- function(b, i, dest) { dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  terra::writeRaster(b[[i]], dest, overwrite = TRUE, datatype = terra::datatype(b)[i], gdal = c("COMPRESS=DEFLATE", "TILED=YES", "BIGTIFF=IF_SAFER")); dest }

# the LFPS email: the Data Download page keeps it in the home folder's settings.csv
lfps_email <- function(ctx) { e <- home_setting(ctx$home, "LfpsEmail")
  if (is.na(e) || !grepl("@", e)) stop("LANDFIRE: enter an email address on the Data Download page (LANDFIRE Product Service jobs need one)", call. = FALSE)
  e }

# one LANDFIRE Product Service job: the layers over the region's lon/lat box in EPSG:5070 at 30 m, which is LANDFIRE's own CONUS grid
# (cells on the national files' 15 m offset, no resampling; without it LFPS reprojects to an Albers centred on the box);
# waits for it (polling every 15 s, up to 3 hours), fetches its zip and returns the multi-band raster, one band per layer in order
lfps_job <- function(ctx, layers) {
  b <- region_box_ll(ctx$region); j <- function(u) jsonlite::fromJSON(rawToChar(curl::curl_fetch_memory(u)$content), simplifyVector = TRUE)
  s <- j(sprintf("%s/job/submit?Email=%s&Layer_List=%s&Area_of_Interest=%s&Output_Projection=5070&Resample_Resolution=30", LFPS, curl::curl_escape(lfps_email(ctx)), curl::curl_escape(paste(layers, collapse = ";")),
                 curl::curl_escape(sprintf("%.5f %.5f %.5f %.5f", b[1], b[2], b[3], b[4]))))
  if (is.null(s$jobId)) stop(sprintf("LFPS refused the job: %s", paste(unlist(s$message), collapse = "; ")), call. = FALSE)
  ctx$log(sprintf("  LFPS job %s: %d layers", s$jobId, length(layers))); t0 <- Sys.time(); last <- ""
  repeat { Sys.sleep(15); st <- tryCatch(j(sprintf("%s/job/status?JobId=%s", LFPS, s$jobId)), error = function(e) list(status = "unreachable"))
    if (!identical(st$status, last)) { ctx$log(sprintf("  LFPS job: %s", st$status)); last <- st$status }
    if (grepl("Succeeded", st$status)) break
    if (grepl("Failed|Cancel", st$status)) stop(sprintf("LFPS job %s failed: %s", s$jobId, paste(grep("ERROR", unlist(st$messages), value = TRUE), collapse = "; ")), call. = FALSE)
    if (difftime(Sys.time(), t0, units = "hours") > 3) stop(sprintf("LFPS job %s still %s after 3 hours", s$jobId, st$status), call. = FALSE) }
  z <- file.path(ctx$dl, "lfps.zip"); fetch_files(st$outputFile, z, 1, ctx$log, sizes = NA_real_)
  x <- unzip_to(z, file.path(ctx$dl, "lfps")); r <- terra::rast(grep("[.]tif$", x, value = TRUE)[1])
  if (terra::nlyr(r) != length(layers)) stop(sprintf("LFPS job returned %d bands for %d layers", terra::nlyr(r), length(layers)), call. = FALSE)
  r }

# a gNATSGO asset over the region: the STAC items (10 m tiles in EPSG:5070) touching its box, each cropped, then mosaicked
gnatsgo_region <- function(ctx, asset, dest) {
  b <- region_box_ll(ctx$region); feats <- list(); u <- sprintf("%s/search?collections=gnatsgo-rasters&bbox=%f,%f,%f,%f&limit=100", PC_STAC, b[1], b[2], b[3], b[4])
  while (!is.null(u)) { p <- jsonlite::fromJSON(u, simplifyVector = FALSE); feats <- c(feats, p$features)
    nx <- Filter(function(l) identical(l$rel, "next"), p$links); u <- if (length(nx)) nx[[1]]$href else NULL }
  if (!length(feats)) stop("no gNATSGO tiles over the region", call. = FALSE)
  dir.create(ctx$dl, recursive = TRUE, showWarnings = FALSE)
  tok <- jsonlite::fromJSON("https://planetarycomputer.microsoft.com/api/sas/v1/token/soils/gnatsgo")$token
  box <- terra::vect(sf::st_as_sfc(sf::st_bbox(setNames(ctx$region$box, c("xmin", "ymin", "xmax", "ymax")), crs = sf::st_crs(5070))))
  parts <- Filter(Negate(is.null), lapply(feats, function(f) { h <- f$assets[[asset]]$href; if (is.null(h)) return(NULL)
    r <- terra::rast(sprintf("/vsicurl/%s?%s", h, tok)); e <- terra::intersect(terra::ext(terra::project(box, terra::crs(r))), terra::ext(r)); if (is.null(e)) return(NULL)
    terra::crop(r, e, snap = "out", filename = tempfile(tmpdir = ctx$dl, fileext = ".tif"), gdal = "COMPRESS=DEFLATE") }))
  ctx$log(sprintf("  %s: %d tiles", asset, length(parts)))
  mosaic_to(vapply(parts, terra::sources, ""), dest, terra::datatype(parts[[1]])) }
