# =============================================================================
# download-sources.R - the Data Download handlers: where each dataset comes from and how it lands at its place (to-do 12)
# =============================================================================
# One handler per Data Sources column (src/download.R runs them). URLs checked 2026-10-31 (implementation plan, phase 3). Each
# handler's plan lists its files: url, file (the name in the download folder) and fetch (FALSE: read remotely, not downloaded).
# finish writes the files the stages read, with the names they read today, and returns the dataset's place (folder or file).
# Rasters inside zips are read where they sit (GDAL /vsizip//vsicurl/, byte ranges) and only the region is written: a 26 MB
# forest type tile comes out of a 2 GB regional zip without fetching the zip. National copies (no Study Area, or Keep national
# copies) fetch the whole zips instead. Handlers marked national = TRUE always keep the whole files, at the top of the home:
# FIA DataMart (the growth curves fit on every state), PRISM (the growth curves' ecodivision climate covers CONUS), LOCA2 (cut to
# its own regions) and FPA-FOD (fetched whole anyway: a GeoPackage is too slow to read through a remote zip). FSim is read
# remotely and clipped: its 1.6 GB zip is never fetched for a region.
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
whole_conus <- function(ctx) is.null(ctx$region$poly)   # all of CONUS (Home layout National): the sources' national files

# the one GeoTIFF in a downloaded zip, unpacked to dest (sidecars left behind, as the region's files have none). R's unzip may
# refuse a member over 4 GB (LANDFIRE elevation): then Windows' tar, which reads zip64
zip_tif <- function(ctx, zip, dest) {
  m <- utils::unzip(zip, list = TRUE)$Name; t <- m[grepl("[.]tif$", m, ignore.case = TRUE)]
  if (length(t) != 1) stop(sprintf("%s holds %d .tif files (%s); expected one", basename(zip), length(t), paste(head(t, 4), collapse = ", ")), call. = FALSE)
  ex <- file.path(ctx$dl, "unzip"); dir.create(ex, recursive = TRUE, showWarnings = FALSE); x <- file.path(ex, t)
  ok <- tryCatch({ utils::unzip(zip, files = t, exdir = ex); file.exists(x) && file.size(x) > 0 }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!ok) { unlink(x); system2("tar", c("-xf", shQuote(zip), "-C", shQuote(ex), shQuote(t)))
    if (!file.exists(x)) stop(sprintf("could not unpack %s from %s", t, basename(zip)), call. = FALSE) }
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  if (!file.rename(x, dest)) stop(sprintf("could not move %s to its place", basename(t)), call. = FALSE)
  unlink(ex, recursive = TRUE); dest }

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

# a shapefile (the .shp and every sidecar of its name) from a downloaded zip or .tar.gz, unpacked flat into place; returns the .shp
shp_from_archive <- function(ctx, archive, member, place) {
  tar <- grepl("[.]tar[.]gz$|[.]tgz$", archive)
  m <- if (tar) utils::untar(archive, list = TRUE) else utils::unzip(archive, list = TRUE)$Name
  stem <- sub("[.]shp$", "", member, ignore.case = TRUE); want <- m[startsWith(m, paste0(stem, "."))]
  if (!any(tolower(want) == tolower(member))) stop(sprintf("%s lacks %s", basename(archive), member), call. = FALSE)
  ex <- file.path(ctx$dl, "unpack"); unlink(ex, recursive = TRUE); dir.create(ex, recursive = TRUE)
  if (tar) utils::untar(archive, files = want, exdir = ex) else utils::unzip(archive, files = want, exdir = ex)
  dir.create(place, recursive = TRUE, showWarnings = FALSE)
  for (f in want) if (!file.rename(file.path(ex, f), file.path(place, basename(f)))) stop(sprintf("could not move %s to its place", basename(f)), call. = FALSE)
  unlink(ex, recursive = TRUE); file.path(place, basename(member)) }

# vector layers of a downloaded zip (read in place through /vsizip/) copied into one GeoPackage, with only the named fields. The first
# layer of the source when `layers` is NULL, written as `names` (default: the source layer names)
layers_to_gpkg <- function(archive, inner, layers, fields, dest, names = layers) {
  src <- sprintf("/vsizip/%s/%s", normalizePath(archive, winslash = "/"), inner)
  if (is.null(layers)) { layers <- sf::st_layers(src)$name[1]; if (is.null(names)) names <- layers }
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE); unlink(dest)
  for (i in seq_along(layers)) sf::gdal_utils("vectortranslate", src, dest, options = c(if (i > 1) "-update", "-nln", names[i], "-select", paste(fields[[i]], collapse = ","),
                                                                                         "-nlt", "CONVERT_TO_LINEAR", "-nlt", "PROMOTE_TO_MULTI", layers[i]), quiet = TRUE)
  dest }

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
  H$FpaFodFile <- list(column = "FpaFodFile", name = "FPA-FOD fire occurrence", national = TRUE, version = "RDS-2013-0009.7",
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
      # monthly precipitation (2026-11-07, to-do 39 step 7): the October-September water year of the RAP fit grass and shrub response;
      # the region's years from the October before the first, and 1990-2020 for the water-year normal
      y0 <- min(years_of(ctx, 1895:last)); ym <- sort(unique(c(max(y0 - 2L, 1981L):last, 1990:2020)))   # the first year's lag needs October two years before
      m <- data.table::CJ(year = ym, mon = 1:12)[, .(var = "ppt", year, url = sprintf("https://data.prism.oregonstate.edu/time_series/us/an/4km/ppt/monthly/%d/prism_ppt_us_25m_%d%02d.zip", year, year, mon),
                                                       file = sprintf("prism_ppt_us_25m_%d%02d.zip", year, mon), monthly = TRUE)]
      rbind(a[, monthly := FALSE], n[, monthly := FALSE], m)[, fetch := TRUE][] },
    # in place = the tif a zip unpacks to, at its recorded size: a rerun fetches only what is new (the monthly files, first time)
    have = function(ctx, items) recorded(ctx, "PrismFolder", file.path(ctx$place, prism_dir(items), sub("[.]zip$", ".tif", items$file))),
    finish = function(ctx, items) {
      d <- prism_dir(items); for (i in seq_len(nrow(items))) utils::unzip(items$dest[i], exdir = file.path(ctx$place, d[i]))
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

  # ---- RCMAP vegetation state 1985 (USGS, Ecological Potential ver. 2.0): fetched whole (ScienceBase serves no byte ranges) and
  # clipped. It covers the western US rangelands; a region outside it gets no file, and stage 5 takes grassland and shrubland
  # types from NLCD there. Since 2026-11-02 ScienceBase answers 404 for this item's files and its new download page wants a person
  # (a captcha, or a sign-in), so while the address stays gone the zip (or its tif) comes from <home>/supplied, put there by hand; the manifest says so
  # ---------------------------------------------------------------------------------------------------
  H$RcmapFile <- list(column = "RcmapFile", name = "RCMAP vegetation state 1985", version = "ver. 2.0, July 2025 (10.5066/P13OMU52)",
    plan = function(ctx) { b <- ctx$region$box   # the map's extent in EPSG:5070 (checked 2026-11-01): no download for a region east of it
      if (!is.null(ctx$region$poly) && (b[1] > 592484 || b[3] < -2875426 || b[2] > 3290176 || b[4] < 309856))
        stop("the region lies outside RCMAP's western US rangelands: no file is needed (stage 5 takes grassland and shrubland types from NLCD)", call. = FALSE)
      own <- file.path(ctx$home, "supplied", c("1985_vegetation_state.zip", RCMAP_TIF)); own <- own[file.exists(own)]
      if (length(own)) return(data.table::data.table(url = RCMAP_URL, file = basename(own[1]), fetch = FALSE, supplied = own[1],
        note = sprintf("Supplied by hand as %s: ScienceBase's download page asks for a captcha", basename(own[1]))))
      if (url_gone(RCMAP_URL)) stop(sprintf("by hand: ScienceBase no longer serves this file to a script. Open %s in a browser, download 1985_vegetation_state.zip (883 MB; it may ask you to tick a captcha or sign in), put it in %s and run again",
                                            RCMAP_ITEM, file.path(ctx$home, "supplied")), call. = FALSE)
      data.table::data.table(url = RCMAP_URL, file = "1985_vegetation_state.zip", fetch = TRUE) },
    finish = function(ctx, items) { m <- RCMAP_TIF; dest <- file.path(ctx$place, m)
      own <- "supplied" %in% names(items); from <- if (own) items$supplied[1] else items$dest[1]
      x <- if (grepl("[.]tif$", from)) from else unzip_to(from, file.path(ctx$dl, "unzip"), m)
      if (own && any(abs(as.vector(terra::ext(terra::rast(x))) - RCMAP_EXT) > 1)) stop(sprintf("%s is not the RCMAP map: its extent is not RCMAP's", basename(x)), call. = FALSE)
      if (clipping(ctx)) { r <- terra::rast(x); b <- terra::project(terra::vect(sf::st_as_sfc(sf::st_bbox(setNames(ctx$region$box, c("xmin", "ymin", "xmax", "ymax")), crs = sf::st_crs(5070)))), terra::crs(r))
        e <- terra::intersect(terra::ext(b), terra::ext(r))
        if (is.null(e) || !isTRUE(terra::global(terra::crop(r, e) %in% 2:9, "sum", na.rm = TRUE)[[1]] > 0))
          stop("the region lies outside RCMAP's western US rangelands: no file is needed (stage 5 takes grassland and shrubland types from NLCD)", call. = FALSE)
        clip_raster(x, dest, ctx$region) } else { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE); if (x == from) file.copy(x, dest) else file.rename(x, dest) }
      if (x != from) unlink(x); dest })

  # ---- USFS forest ownership circa 2017, read remotely, with its attribute table ---------------------------------------
  H$ForestOwnerFile <- list(column = "ForestOwnerFile", name = "USFS forest ownership 2017", version = "circa 2017 (RDS-2020-0044)",
    plan = function(ctx) data.table::data.table(url = sprintf(RDS, "RDS-2020-0044", "RDS-2020-0044.zip"), file = "owner.zip", fetch = !clipping(ctx)),
    finish = function(ctx, items) { dest <- file.path(ctx$place, "forest_own1.tif")
      zip_raster(ctx, items, 1, "Data/forest_own1/forest_own1.tif", dest)
      zip_dbf(ctx, items, 1, "Data/forest_own1/forest_own1.tif.vat.dbf", paste0(dest, ".vat.dbf")); dest })

  # ---- the Stratum Sources presets' polygons (study areas, secondary and tertiary strata): national, at the top of the home ------
  # Stage 15 runs these before it works out the region (the region is the Study Area units' polygons). Files named as the presets
  # read them; each preset's DataSource (defaults/strata/presets.csv) names its dataset here.
  strata_shp <- function(column, name, version, url, file, member) list(column = column, name = name, national = TRUE, version = version,
    plan = function(ctx) data.table::data.table(url = url, file = file, fetch = TRUE),
    finish = function(ctx, items) shp_from_archive(ctx, items$dest[1], member, ctx$place))
  H$StatesFile <- strata_shp("StatesFile", "TIGER/Line states 2009", "TIGER/Line 2009 (tl_2009_us_state)",
                             "https://www2.census.gov/geo/tiger/TIGER2009/tl_2009_us_state.zip", "tl_2009_us_state.zip", "tl_2009_us_state.shp")
  H$CountiesFile <- strata_shp("CountiesFile", "TIGER/Line counties 2022", "TIGER/Line 2022 redistricting (tl_rd22_us_county)",
                               "https://www2.census.gov/geo/tiger/TIGER_RD18/LAYER/COUNTY/tl_rd22_us_county.zip", "tl_rd22_us_county.zip", "tl_rd22_us_county.shp")
  H$EcoregionsFile <- strata_shp("EcoregionsFile", "EPA Level IV ecoregions", "EPA Level IV (us_eco_l4_no_st, 2024-11)",
                                 "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/us/us_eco_l4.zip", "us_eco_l4.zip", "us_eco_l4_no_st.shp")
  H$PyromesFile <- strata_shp("PyromesFile", "Pyromes", "RDS-2020-0020", sprintf(RDS, "RDS-2020-0020", "RDS-2020-0020.zip"), "pyromes.zip",
                              "Data/Pyromes_CONUS_20200206.shp")
  # WBD: the 2.8 GB national zip; its HU6 and HU8 layers go to one GeoPackage (layers WBDHU6, WBDHU8, as the presets name them)
  H$WatershedsFile <- list(column = "WatershedsFile", name = "WBD watersheds (HU6, HU8)", national = TRUE, version = "WBD national GDB (HU6, HU8)",
    note = "The national zip is replaced in place each month; the home keeps the snapshot it fetched",
    plan = function(ctx) data.table::data.table(url = "https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.zip",
                                                file = "WBD_National_GDB.zip", fetch = TRUE),
    finish = function(ctx, items) { gdb <- grep("[.]gdb/?$", unique(dirname(utils::unzip(items$dest[1], list = TRUE)$Name)), value = TRUE)[1]
      if (is.na(gdb)) stop("WBD_National_GDB.zip holds no .gdb", call. = FALSE)
      layers_to_gpkg(items$dest[1], gdb, c("WBDHU6", "WBDHU8"), list(c("huc6", "name"), c("huc8", "name")), file.path(ctx$place, "wbd_hu6_hu8.gpkg")) })
  # PAD-US 4.0, for two presets: the state geodatabases (ScienceBase "PAD-US 4.0 State Downloads"; the national files and the
  # flattened GAP analysis file are served only through ScienceBase's web page, 2026-11-02). Each state's combined Fee, Designation,
  # Easement, DOD, tribal and NGP layer goes into one GeoPackage, as two layers:
  #   gap_status    GAP_Sts, without the Proclamation boundaries (not land designations); polygons overlap, and the GAP Status preset
  #                 takes the most protected (Overlap = Min)
  #   federal_fee   Own_Name, the fee land owned by a federal agency or a tribe (Own_Type FED or TRIB): the Federal Lands preset, mapped
  #                 to its managers by federal-lands-crosswalk.csv (TRIB = BIA, the Indian lands of the National Atlas map it replaced)
  PADUS_LAYERS <- list(gap_status = "SELECT GAP_Sts FROM \"%s\" WHERE Category <> 'Proclamation'",
                       federal_fee = "SELECT Own_Name FROM \"%s\" WHERE Category = 'Fee' AND Own_Type IN ('FED', 'TRIB')")
  H$PadusFile <- list(column = "PadusFile", name = "PAD-US 4.0 (GAP status, federal and tribal fee land)", national = TRUE,
    version = "PAD-US 4.0 state geodatabases (gap_status, federal_fee)",
    plan = function(ctx) { st <- unname(CONUS_STATES)
      data.table::data.table(url = sprintf("https://www.sciencebase.gov/catalog/file/get/652d4f80d34e44db0e2ee45c?name=PADUS4_0_State_%s_GDB.zip", st),
                             file = sprintf("PADUS4_0_State_%s_GDB.zip", st), fetch = TRUE) },
    finish = function(ctx, items) { dest <- file.path(ctx$place, "padus4.gpkg"); dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE); unlink(dest)
      for (i in seq_len(nrow(items))) { m <- utils::unzip(items$dest[i], list = TRUE)$Name
        gdb <- unique(sub("([.]gdb)/.*$", "\\1", m[grepl("[.]gdb/", m)]))[1]
        if (is.na(gdb)) stop(sprintf("%s holds no geodatabase", items$file[i]), call. = FALSE)
        src <- sprintf("/vsizip/%s/%s", normalizePath(items$dest[i], winslash = "/"), gdb)
        lay <- grep("^PADUS4_0Comb_", sf::st_layers(src)$name, value = TRUE)[1]
        if (is.na(lay)) stop(sprintf("%s has no PADUS4_0Comb_ layer", items$file[i]), call. = FALSE)
        # (ogr2ogr cannot -select while appending: each layer is an -sql query)
        for (k in names(PADUS_LAYERS)) sf::gdal_utils("vectortranslate", src, dest, quiet = TRUE,
          options = c(if (file.exists(dest)) "-update", if (i > 1) "-append", "-nln", k, "-sql", sprintf(PADUS_LAYERS[[k]], lay), "-nlt", "CONVERT_TO_LINEAR", "-nlt", "PROMOTE_TO_MULTI", "-t_srs", "EPSG:5070")) }
      ctx$log(sprintf("  PAD-US 4.0: %d states into %s (layers %s)", nrow(items), basename(dest), paste(names(PADUS_LAYERS), collapse = ", "))); dest })

  # ==== clipped by the source (phase 4) for a region; for all of CONUS (Home layout National) the sources' national files =====

  # ---- Annual NLCD land cover (Collection 1.2) by WCS 1.0.0, one coverage a year, in tiles on the 30 m grid -----------------
  H$NlcdFolder <- list(column = "NlcdFolder", name = "Annual NLCD land cover", version = "Collection 1.2 (C1V2)", method = "wcs",
    note = "Clipped by MRLC's WCS; C1V2 for every year (the only collection published)",
    plan = function(ctx) {
      have <- as.integer(substr(regmatches(x <- rawToChar(curl::curl_fetch_memory(paste0(NLCD_WCS, "?service=WCS&version=1.0.0&request=DescribeCoverage&coverage=", NLCD_COV))$content),
        gregexpr("(?<=<gml:timePosition>)[0-9]{4}", x, perl = TRUE))[[1]], 1, 4))
      y <- years_of(ctx, sort(unique(have))); out <- sprintf("Annual_NLCD_LndCov_%d_CU_C1V2.tif", y)
      # all of CONUS: MRLC's national zip a year (1.4 GB each), on the national grid the 150 m blocks are anchored to
      if (whole_conus(ctx)) return(data.table::data.table(year = y, url = sprintf(NLCD_BUNDLE, y), file = sub("[.]tif$", ".zip", out), out = out, fetch = TRUE))
      data.table::data.table(year = y, url = NLCD_WCS, file = out, out = out, fetch = FALSE) },
    have = function(ctx, items) recorded(ctx, "NlcdFolder", file.path(ctx$place, items$out)),
    finish = function(ctx, items) {
      if (whole_conus(ctx)) { for (i in seq_len(nrow(items))) { d <- zip_tif(ctx, items$dest[i], file.path(ctx$place, items$out[i]))
          e <- as.vector(terra::ext(terra::rast(d)))
          if (any(abs(e - NLCD_NATIONAL_EXT) > 1)) stop(sprintf("NLCD %d: the national file's extent (%s) is not the national NLCD grid", items$year[i], paste(round(e), collapse = ", ")), call. = FALSE)
          unlink(items$dest[i]); ctx$log(sprintf("  NLCD %d (national)", items$year[i])) }
        return(ctx$place) }
      tl <- grid_tiles(ctx$region$box, c(-2415585, 3314805), 30, 4000)
      # under load the WCS now and then answers a full-size tile with no data (P26 2026-11-01: one tile each in 2001, 2003 and 2009).
      # NLCD's no-data cells are the same every year, so each tile's count of class cells must equal the most seen in any year;
      # a tile short of it is fetched again
      classed <- function(p) { v <- terra::values(terra::rast(p), mat = FALSE); sum(!is.na(v) & v >= 11 & v <= 95) }
      ref <- rep(0, nrow(tl)); got <- matrix(NA_real_, nrow(items), nrow(tl)); zero_ok <- rep(FALSE, nrow(tl))   # zero_ok: blank after 4 tries (outside CONUS)
      one_year <- function(i) { y <- items$year[i]
        u <- sprintf("%s?service=WCS&version=1.0.0&request=GetCoverage&coverage=%s&crs=EPSG:5070&bbox=%.0f,%.0f,%.0f,%.0f&width=%d&height=%d&time=%d-01-01T00:00:00.000Z&format=GeoTIFF",
                     NLCD_WCS, NLCD_COV, tl$xmin, tl$ymin, tl$xmax, tl$ymax, tl$nx, tl$ny, y)
        parts <- file.path(ctx$dl, y, sprintf("tile%02d.tif", seq_len(nrow(tl))))
        fetch_files(u, parts, 1, ctx$log, sizes = rep(NA_real_, length(u)))   # one tile at a time: the WCS answers 404 under parallel load (2026-11-01)
        n <- vapply(parts, classed, 0)
        for (try in 1:4) { bad <- which(n < ref | (n == 0 & !zero_ok)); if (!length(bad)) break
          ctx$log(sprintf("  NLCD %d: tile %s came back with %s class cells (expected %s); fetching again", y, paste(bad, collapse = ", "),
                          paste(n[bad], collapse = ", "), paste(ref[bad], collapse = ", ")))
          Sys.sleep(10 * try); file.remove(parts[bad]); fetch_files(u[bad], parts[bad], 1, ctx$log, sizes = rep(NA_real_, length(bad)))
          n[bad] <- vapply(parts[bad], classed, 0) }
        if (any(n < ref)) stop(sprintf("NLCD %d: tile %s still short of class cells after 4 tries", y, paste(which(n < ref), collapse = ", ")), call. = FALSE)
        ref <<- pmax(ref, n); got[i, ] <<- n; zero_ok <<- zero_ok | n == 0
        mosaic_to(parts, file.path(ctx$place, items$out[i]), "INT1U", c(min(tl$xmin), min(tl$ymin), max(tl$xmax), max(tl$ymax)), tiles = tl); unlink(dirname(parts[1]), recursive = TRUE)
        ctx$log(sprintf("  NLCD %d (%d tiles)", y, nrow(tl))) }
      for (i in seq_len(nrow(items))) one_year(i)
      # a year fetched before a later year raised a tile's count is fetched again
      for (i in which(apply(got, 1, function(n) any(n < ref)))) { ctx$log(sprintf("  NLCD %d: a tile has fewer class cells than in later years; fetching it again", items$year[i])); one_year(i) }
      ctx$place })

  # ---- LANDFIRE layers by LANDFIRE Product Service jobs (the job clips; output on LANDFIRE's own grid) -----------------
  # (all of CONUS: LANDFIRE's full-extent zip of the layer, `zip` under landfire.gov/data-downloads)
  lf_single <- function(column, name, layer, version, out, zip) list(column = column, name = name, version = version, method = "lfps",
    plan = function(ctx) { if (whole_conus(ctx)) return(data.table::data.table(url = sprintf("%s/%s", LF_DL, zip), file = basename(zip), fetch = TRUE))
      lfps_email(ctx); data.table::data.table(url = LFPS, file = out, layer = layer, fetch = FALSE) },
    finish = function(ctx, items) { dest <- file.path(ctx$place, out)
      if (whole_conus(ctx)) { zip_tif(ctx, items$dest[1], dest); unlink(items$dest[1]); return(dest) }
      b <- lfps_job(ctx, items$layer); write_band(b, 1, dest); dest })
  H$Evt2016File <- lf_single("Evt2016File", "LANDFIRE EVT 2016", "LF2016_EVT", "LF 2.0.0 (LF2016_EVT)", "LC16_EVT_200.tif", "CONUS_LF2016/LF2016_EVT_CONUS.zip")
  H$FriFile <- lf_single("FriFile", "LANDFIRE mean fire return interval", "LF2016_FRI", "LF 2016 (LF2016_FRI)", "LC16_FRI_200.tif", "CONUS_LF2016/LF2016_FRI_CONUS.zip")
  H$ElevationFile <- lf_single("ElevationFile", "LANDFIRE elevation", "LF2020_Elev", "LF 2020 (LF2020_Elev)", "LC20_Elev_220.tif", "CONUS_Topo_LF2020/LF2020_Elev_CONUS.zip")
  H$RoadsFile <- lf_single("RoadsFile", "LANDFIRE roads", "LF2023_Roads", "LF 2023 (LF2023_Roads)", "LF2023_Roads_CONUS.tif", "CONUS_LF2023/LF2023_Roads_CONUS.zip")

  # disturbance: one layer a year (LF2001_Dist99 ... LF2025_Dist25), all the missing years in one job; each year laid out as the
  # stages read it (US_DIST<year>/<name>/Tif and CSV_Data), with the attribute table shipped in defaults/landfire/disturbance
  H$LandfireDisturbanceFolder <- list(column = "LandfireDisturbanceFolder", name = "LANDFIRE annual disturbance", version = "LF2001_Dist99 to LF2025_Dist25", method = "lfps",
    note = "Attribute tables from the package (defaults/landfire/disturbance); the 2023 and 2025 tables are the provisional editions', whose codes match the final rasters (2025's final table is the same text, checked 2026-11-01; LANDFIRE publishes no final 2023 table)",
    plan = function(ctx) { if (!whole_conus(ctx)) lfps_email(ctx)
      p <- jsonlite::fromJSON(paste0(LFPS, "/products"))$products; l <- grep("^LF[0-9]{4}_Dist[0-9]{2}$", p$layerName, value = TRUE)
      yy <- as.integer(sub(".*_Dist", "", l)); yr <- ifelse(yy > 80, 1900L + yy, 2000L + yy)
      x <- data.table::data.table(year = yr, layer = l)[year %in% years_of(ctx, yr)][order(year)]
      x[, out := sprintf("US_DIST%d/LF%d_Dist/Tif/LF%d_Dist.tif", year, year, year)]
      # all of CONUS: LANDFIRE's national zip a year, named as the LFPS layer (LF2001_Dist99_CONUS.zip ... LF2025_Dist25_CONUS.zip)
      if (whole_conus(ctx)) x[, `:=`(url = sprintf("%s/CONUS_Disturbance/%s_CONUS.zip", LF_DL, layer), file = paste0(layer, "_CONUS.zip"), fetch = TRUE)][]
      else x[, `:=`(url = LFPS, file = out, fetch = FALSE)][] },
    have = function(ctx, items) recorded(ctx, "LandfireDisturbanceFolder", file.path(ctx$place, items$out)),
    # (LFPS takes at most 15 layers a job: the years go in jobs of up to 15, each job's zip unpacked into its own folder)
    finish = function(ctx, items) {
      dist_csv <- function(y) { csv <- pkg_file("defaults", "landfire", "disturbance", sprintf("US_DIST%d.csv", y)); cd <- file.path(ctx$place, sprintf("US_DIST%d/LF%d_Dist/CSV_Data", y, y))
        dir.create(cd, recursive = TRUE, showWarnings = FALSE); file.copy(csv, file.path(cd, sprintf("LF%d_Dist.csv", y)), overwrite = TRUE) }
      if (whole_conus(ctx)) { for (i in seq_len(nrow(items))) { zip_tif(ctx, items$dest[i], file.path(ctx$place, items$out[i])); dist_csv(items$year[i]); unlink(items$dest[i])
          ctx$log(sprintf("  LANDFIRE disturbance %d (national)", items$year[i])) }
        return(ctx$place) }
      for (ch in split(seq_len(nrow(items)), ceiling(seq_len(nrow(items)) / 15))) { b <- lfps_job(ctx, items$layer[ch])
        for (k in seq_along(ch)) { i <- ch[k]; y <- items$year[i]; write_band(b, k, file.path(ctx$place, items$out[i])); dist_csv(y) }
        rm(b); gc(); unlink(file.path(ctx$dl, c("lfps.zip", "lfps")), recursive = TRUE) }
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

  # ---- RAP partitioned NPP v3 (Robinson et al. 2019; CC0): one 4-band 30 m cloud-optimized GeoTIFF a year from 1986 (annual
  # herbaceous, perennial herbaceous, shrub, tree; value / 1000 = Mg C/ha/yr; 65535 no data), each read for the region where it
  # sits. About 75 GB a year for CONUS, so not fetched whole. Grows like NLCD: a rerun asking for more years fetches only those.
  # Stage 8 reads 2014-2023 (Grass and Shrub Productivity); all years kept for a climate response fitted to RAP (to-do 39 step 7)
  H$RapNppFolder <- list(column = "RapNppFolder", name = "RAP vegetation NPP v3", version = "RAP vegetation NPP v3", method = "cog", clips = TRUE,
    note = "Read for the region only from the University of Montana's cloud-optimized GeoTIFFs (bands: annual herbaceous, perennial herbaceous, shrub, tree NPP; value / 1000 = Mg C/ha/yr; 65535 no data)",
    plan = function(ctx) {
      if (whole_conus(ctx)) stop("RAP NPP is about 75 GB a year for all of CONUS and is read for a region only: run the Data Download with a Study Area (Home layout By region)", call. = FALSE)
      last <- as.integer(format(Sys.Date(), "%Y")); cand <- years_of(ctx, 1986:last)
      y <- cand[!vapply(sprintf(RAP_NPP, cand), url_gone, TRUE)]
      if (!length(y)) stop("RAP lists no NPP years for these years", call. = FALSE)
      data.table::data.table(year = y, url = sprintf(RAP_NPP, y), file = sprintf("rap-npp-v3-%d.tif", y), fetch = FALSE) },
    have = function(ctx, items) recorded(ctx, "RapNppFolder", file.path(ctx$place, items$file)),
    finish = function(ctx, items) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE)
      for (i in seq_len(nrow(items))) { for (k in 1:4) { ok <- tryCatch({ clip_raster(paste0("/vsicurl/", items$url[i]), file.path(ctx$place, items$file[i]), ctx$region); TRUE },
            error = function(e) { ctx$log(sprintf("  RAP NPP %d: %s (try %d)", items$year[i], conditionMessage(e), k)); FALSE }); if (ok) break; Sys.sleep(10 * k) }
        if (!ok) stop(sprintf("RAP NPP %d could not be read", items$year[i]), call. = FALSE)
        ctx$log(sprintf("  RAP NPP %d", items$year[i])) }
      ctx$place })

  # ---- USDA NASS Cropland Data Layer: one national 30 m GeoTIFF a year (in a 1.6-2.0 GB zip), kept whole at the top of the home
  # (user 2026-11-07: 2014-2023 nationally, 2026-11-08: to 2025; read remotely a zip this size does not answer, and CropScape's clip service did not).
  # Stage 8 crops its window (Build Options: Cropland Productivity); only CDL_YEARS are fetched
  H$CdlFolder <- list(column = "CdlFolder", name = "USDA NASS Cropland Data Layer", national = TRUE, version = "CDL 30 m national releases",
    note = "National 30 m crop type a year (EPSG:5070; 0 background); the years 2014-2025 that stage 8 reads (2025: NASS's 30 m version of its 10 m layer)",
    plan = function(ctx) { y <- intersect(years_of(ctx, 2008:2025), CDL_YEARS)
      if (!length(y)) stop(sprintf("the Cropland Data Layer years stage 8 reads are %d-%d: ask for years that include them", min(CDL_YEARS), max(CDL_YEARS)), call. = FALSE)
      data.table::data.table(year = y, url = sprintf(CDL_ZIP, y), file = sprintf("%d_30m_cdls.zip", y), out = sprintf("%d_30m_cdls.tif", y), fetch = TRUE) },
    have = function(ctx, items) recorded(ctx, "CdlFolder", file.path(ctx$place, items$out)),
    finish = function(ctx, items) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE)
      for (i in seq_len(nrow(items))) { zip_tif(ctx, items$dest[i], file.path(ctx$place, items$out[i])); unlink(items$dest[i]); ctx$log(sprintf("  CDL %d (national)", items$year[i])) }
      ctx$place })

  # ---- USGS tidal marsh NPP (Woltz et al. 2023, ScienceBase): one 163 MB zip holding a zip per map (all, estuarine, palustrine
  # marsh); the estuarine and palustrine GeoTIFFs are unpacked and kept whole at the top of the home (they are national 30 m maps,
  # mostly empty; stage 8 crops them) -------------------------------------------------------------------------------------------
  H$TidalMarshNppFolder <- list(column = "TidalMarshNppFolder", name = "USGS tidal marsh NPP", national = TRUE, version = "2024 release (10.5066/P9I1PCLS), 2015 map",
    note = "Total NPP (gC/m2/yr) of estuarine and palustrine emergent tidal marsh, 30 m CONUS, for Build Options: Tidal Marsh Productivity (stage 8)",
    plan = function(ctx) data.table::data.table(url = "https://www.sciencebase.gov/catalog/file/get/6419e82ed34eb496d1d29caf?name=NPP_CONUSTidalMarshes.zip",
                                                file = "NPP_CONUSTidalMarshes.zip", fetch = TRUE),
    have = function(ctx, items) recorded(ctx, "TidalMarshNppFolder", file.path(ctx$place, sprintf("NPP_CONUSTidal%s_gCm2.tif", c("EEM", "PEM")))),
    finish = function(ctx, items) { dir.create(ctx$place, recursive = TRUE, showWarnings = FALSE); ex <- file.path(ctx$dl, "tidal")
      for (k in c("EEM", "PEM")) { inner <- unzip_to(items$dest[1], ex, sprintf("NPP_CONUSTidal%s_gCm2.tif.zip", k))
        zip_tif(ctx, inner, file.path(ctx$place, sprintf("NPP_CONUSTidal%s_gCm2.tif", k))); unlink(inner) }
      unlink(ex, recursive = TRUE); unlink(items$dest[1]); ctx$place })

  # ---- gNATSGO (Planetary Computer): soil organic carbon and crop productivity, the region's 10 m tiles cropped; for all of
  # CONUS every tile (357, about 10 GB a layer) fetched and written as one 10 m GeoTIFF ---------------------------------------
  gnatsgo <- function(column, name, asset, out, note) list(column = column, name = name, version = "gNATSGO July 2020 (gnatsgo-rasters)", method = "stac", note = note,
    plan = function(ctx) { if (whole_conus(ctx)) return(gnatsgo_tiles(asset)); data.table::data.table(url = PC_STAC, file = out, fetch = FALSE) },
    finish = function(ctx, items) { dest <- file.path(ctx$place, out); if (whole_conus(ctx)) gnatsgo_national(ctx, items, dest) else gnatsgo_region(ctx, asset, dest); dest })
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
RCMAP_ITEM <- "https://www.sciencebase.gov/catalog/item/6849f4f6d4be026f96d9dcca"
RCMAP_URL <- "https://www.sciencebase.gov/catalog/file/get/6849f4f6d4be026f96d9dcca?name=1985_vegetation_state.zip"
RCMAP_TIF <- "1985_vegetation_state_20250608.tif"
RCMAP_EXT <- c(-2875426, 592484, 309856, 3290176)   # xmin, xmax, ymin, ymax in EPSG:5070
NLCD_WCS <- "https://dmsdata.cr.usgs.gov/geoserver/mrlc_Land-Cover-Native_conus_year_data/wcs"
NLCD_COV <- "mrlc_Land-Cover-Native_conus_year_data:Land-Cover-Native_conus_year_data"
LFPS <- "https://lfps.usgs.gov/api"
NIFC <- sprintf("https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/%s/FeatureServer/0", c("InterAgencyFirePerimeterHistory_1979_And_Prior_Read_Only",
  "InteragencyFirePerimeterHistory_1980s_Read_Only", "InteragencyFirePerimeterHistory_1990s_Read_Only", "InteragencyFirePerimeterHistor_2000s_Read_Only",
  "InteragencyFirePerimeterHistory_2010s_Read_Only", "InterAgencyFirePerimeterHistory_2020s_Read_Only"))
# where a PRISM item unpacks: the normals, monthly precipitation, or the annual files of its variable
prism_dir <- function(items) ifelse(is.na(items$year), "normals", ifelse(items$monthly %in% TRUE, "monthly-us25m/ppt", file.path("annual-us25m", items$var)))
RAP_NPP <- "https://rangeland.ntsg.umt.edu/data/rap/rap-vegetation-npp/v3/vegetation-npp-v3-%d.tif"
CDL_ZIP <- "https://www.nass.usda.gov/sites/default/files/Research_and_Science/Cropland/Release/datasets/%d_30m_cdls.zip"
CDL_YEARS <- 2014:2025   # the years stage 8's Cropland Productivity reads
CCAP <- "https://ocmgeodatastor1.blob.core.windows.net/ccap/bulk_download/C-CAP_Regional_30-meter_Data/C-CAP_Regional_Land_Cover_Classification/CONUS/conus_2001_ccap_landcover.tif"
PC_STAC <- "https://planetarycomputer.microsoft.com/api/stac/v1"
# national files (Home layout National; checked 2026-11-02)
NLCD_BUNDLE <- "https://www.mrlc.gov/downloads/sciweb1/shared/mrlc/data-bundles/Annual_NLCD_LndCov_%d_CU_C1V2.zip"
NLCD_NATIONAL_EXT <- c(-2415585, 2384415, 164805, 3314805)   # xmin, xmax, ymin, ymax: the national grid (shared.R, grid_blocks)
LF_DL <- "https://landfire.gov/data-downloads"

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


# the planned files already recorded in files.csv at their recorded size (a hand-placed, unrecorded file is fetched again)
recorded <- function(ctx, column, paths) { st <- if (is.null(ctx$store)) ctx$home else ctx$store; f <- read_files(st)[Column == column]
  rel <- substring(normalizePath(paths, winslash = "/", mustWork = FALSE), nchar(normalizePath(st, winslash = "/")) + 2)
  b <- f$Bytes[match(rel, f$Path)]; !is.na(b) & file.exists(paths) & file.size(paths) == as.numeric(b) }

# the region's box snapped outward to a grid (origin = the grid's top-left corner), cut into tiles of at most `px` cells a side
grid_tiles <- function(box, origin, cell, px) {
  x0 <- origin[1] + floor((box[1] - origin[1]) / cell) * cell; x1 <- origin[1] + ceiling((box[3] - origin[1]) / cell) * cell
  y1 <- origin[2] - floor((origin[2] - box[4]) / cell) * cell; y0 <- origin[2] - ceiling((origin[2] - box[2]) / cell) * cell
  xs <- seq(x0, x1, by = px * cell); if (tail(xs, 1) < x1) xs <- c(xs, x1); ys <- seq(y1, y0, by = -px * cell); if (tail(ys, 1) > y0) ys <- c(ys, y0)
  t <- data.table::CJ(i = seq_len(length(xs) - 1), j = seq_len(length(ys) - 1))
  t[, `:=`(xmin = xs[i], xmax = xs[i + 1], ymax = ys[j], ymin = ys[j + 1])][, `:=`(nx = as.integer(round((xmax - xmin) / cell)), ny = as.integer(round((ymax - ymin) / cell)))][] }

# tiles on one grid into one compressed GeoTIFF. tiles (grid_tiles rows, one per part): each part is given the corners it was asked
# with, after its size is checked, instead of the ones its server wrote: the NLCD WCS rounds them, and a thin last row of tiles (6 rows
# in P26) landed a row high, its first row over the row above (P26 2026-11-02: 508 cells of the region's row 12000 were national row 12001)
mosaic_to <- function(parts, dest, datatype, box = NULL, tiles = NULL) { dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  if (!is.null(tiles)) { stopifnot(nrow(tiles) == length(parts))
    parts <- vapply(seq_along(parts), function(i) { r <- terra::rast(parts[i])
      if (terra::nrow(r) != tiles$ny[i] || terra::ncol(r) != tiles$nx[i]) stop(sprintf("tile %d came back %d x %d cells, not the %d x %d asked for", i, terra::ncol(r), terra::nrow(r), tiles$nx[i], tiles$ny[i]), call. = FALSE)
      v1 <- tempfile(fileext = ".vrt"); sf::gdal_utils("translate", parts[i], v1, options = c("-of", "VRT", "-a_ullr", tiles$xmin[i], tiles$ymax[i], tiles$xmax[i], tiles$ymin[i])); v1 }, "") }
  v <- terra::vrt(parts, filename = tempfile(fileext = ".vrt"))
  # box (xmin, ymin, xmax, ymax): the grid the tiles were asked on. The NLCD WCS writes tile corners with too few digits, which
  # left the mosaic 0.2 m off the 30 m grid (res 30.000003) and moved 150 m blocks by a pixel (P26 2026-11-01: 6.6% of cells)
  if (!is.null(box)) { stopifnot(abs(terra::xmin(v) - box[1]) < 1, abs(terra::ymax(v) - box[4]) < 1); terra::set.ext(v, terra::ext(box[1], box[3], box[2], box[4])) }   # set.ext keeps the cell values (ext<- drops them)
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
# the gNATSGO tiles (STAC items) over a lon/lat box, and a read token for them
pc_tiles <- function(b) { feats <- list(); u <- sprintf("%s/search?collections=gnatsgo-rasters&bbox=%f,%f,%f,%f&limit=100", PC_STAC, b[1], b[2], b[3], b[4])
  while (!is.null(u)) { p <- jsonlite::fromJSON(u, simplifyVector = FALSE); feats <- c(feats, p$features)
    nx <- Filter(function(l) identical(l$rel, "next"), p$links); u <- if (length(nx)) nx[[1]]$href else NULL }
  feats }
pc_token <- function() jsonlite::fromJSON("https://planetarycomputer.microsoft.com/api/sas/v1/token/soils/gnatsgo")$token
# all of CONUS: every tile of the asset, fetched whole (signed urls)
gnatsgo_tiles <- function(asset) { feats <- pc_tiles(c(-125, 24, -66, 50)); tok <- pc_token()
  h <- vapply(feats, function(f) if (is.null(f$assets[[asset]])) NA_character_ else f$assets[[asset]]$href, "")
  data.table::data.table(url = paste0(h, "?", tok), file = paste0(vapply(feats, function(f) f$id, ""), ".tif"), fetch = TRUE)[!is.na(h)] }
# the tiles joined (a VRT) and written as one compressed 10 m GeoTIFF by GDAL itself (BigTIFF: about 1.3e11 cells)
gnatsgo_national <- function(ctx, items, dest) {
  v <- file.path(ctx$dl, "national.vrt"); sf::gdal_utils("buildvrt", items$dest, v)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  sf::gdal_utils("translate", v, dest, options = c("-co", "COMPRESS=DEFLATE", "-co", "TILED=YES", "-co", "BIGTIFF=YES", "-co", "NUM_THREADS=ALL_CPUS"))
  ctx$log(sprintf("  %s: %d tiles joined (national)", basename(dest), nrow(items))); dest }

gnatsgo_region <- function(ctx, asset, dest) {
  feats <- pc_tiles(region_box_ll(ctx$region))
  if (!length(feats)) stop("no gNATSGO tiles over the region", call. = FALSE)
  dir.create(ctx$dl, recursive = TRUE, showWarnings = FALSE)
  tok <- pc_token()
  box <- terra::vect(sf::st_as_sfc(sf::st_bbox(setNames(ctx$region$box, c("xmin", "ymin", "xmax", "ymax")), crs = sf::st_crs(5070))))
  parts <- Filter(Negate(is.null), lapply(feats, function(f) { h <- f$assets[[asset]]$href; if (is.null(h)) return(NULL)
    r <- terra::rast(sprintf("/vsicurl/%s?%s", h, tok)); e <- terra::intersect(terra::ext(terra::project(box, terra::crs(r))), terra::ext(r)); if (is.null(e)) return(NULL)
    terra::crop(r, e, snap = "out", filename = tempfile(tmpdir = ctx$dl, fileext = ".tif"), gdal = "COMPRESS=DEFLATE") }))
  ctx$log(sprintf("  %s: %d tiles", asset, length(parts)))
  mosaic_to(vapply(parts, terra::sources, ""), dest, terra::datatype(parts[[1]])) }
