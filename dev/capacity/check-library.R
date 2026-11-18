# =============================================================================
# check-library.R - the carbon carrying capacity (src/capacity.R) of an existing Build result, and a run against it, outside SyncroSim
# =============================================================================
# Read-only on the library. Rebuilds what stage 8 passes to capacity_build() from the Build result's own files (its initial stock maps,
# stock curves, return intervals, productivity multipliers and ReforestType map), so a Build made before the capacity existed can be
# looked at without rerunning it; with a run, draws the run figures with the capacity figures in them.
# Usage: Rscript dev/capacity/check-library.R <library.ssim> [build result id] [run result id] [out dir] [BpS .tif] [own | bps]
#   own | bps: how natural grassland, shrubland and barren land counts (Carbon Capacity Options; blank = own)
#   build id: blank or 0 = the newest result with initial stock maps; run id: blank or 0 = none; BpS: blank = the library's Data
#   Sources path, else the first LC20_BPS_220.tif under its Data Sources Home
# =============================================================================
pkg <- local({ d <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))); while (!file.exists(file.path(d, "package.xml")) && dirname(d) != d) d <- dirname(d); d })
suppressPackageStartupMessages({ library(data.table); library(terra); library(sf); library(DBI); library(RSQLite) })
a <- commandArgs(TRUE); lib <- normalizePath(a[1], winslash = "/"); arg <- function(i, d) if (length(a) >= i && nzchar(a[i]) && a[i] != "0") a[i] else d
for (f in c("capacity.R", "reforestation.R", "figures.R", "run-figures.R")) source(file.path(pkg, "src", f))
read_default <- function(...) fread(file.path(pkg, "defaults", ...), sep = ",", colClasses = "character", na.strings = "", encoding = "UTF-8")
con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
bid <- as.integer(arg(2, q("SELECT MAX(ScenarioId) id FROM stsim_InitialStockSpatial")$id)); rid <- as.integer(arg(3, NA)); outdir <- arg(4, file.path(tempdir(), "capacity-check"))
dir.create(outdir, showWarnings = FALSE, recursive = TRUE); say <- function(...) cat(sprintf(...), "\n")
dd <- function(sheet, f) file.path(paste0(lib, ".data"), sprintf("Scenario-%d", bid), sheet, basename(f))
say("Library %s, Build result %d%s", basename(lib), bid, if (is.na(rid)) "" else sprintf(", run %d", rid))

scl <- q("SELECT StateClassId AS Id, Name, Color FROM stsim_StateClass"); stl <- q("SELECT StratumId AS Id, Name FROM stsim_Stratum"); sec <- q("SELECT SecondaryStratumId AS Id, Name FROM stsim_SecondaryStratum")
scl_id <- q("SELECT StateClassId AS Pk, ID AS Id, Name FROM stsim_StateClass")   # rasters hold ID, tables the key
ic <- q("SELECT * FROM stsim_InitialConditionsSpatial WHERE ScenarioId = %d", bid); if (!nrow(ic)) stop("result ", bid, " has no Initial Conditions Spatial")
P <- rast(dd("stsim_InitialConditionsSpatial", ic$StratumFileName[1])); S <- rast(dd("stsim_InitialConditionsSpatial", ic$StateClassFileName[1]))
stl_id <- q("SELECT StratumId AS Pk, ID AS Id, Name FROM stsim_Stratum"); sec_id <- q("SELECT SecondaryStratumId AS Pk, ID AS Id, Name FROM stsim_SecondaryStratum")
vP <- values(P, mat = FALSE); land <- !is.na(vP); sname <- stl_id$Name[match(vP, stl_id$Id)]; cname <- scl_id$Name[match(values(S, mat = FALSE), scl_id$Id)]
secn <- if (!is.na(ic$SecondaryStratumFileName[1])) sec_id$Name[match(values(rast(dd("stsim_InitialConditionsSpatial", ic$SecondaryStratumFileName[1])), mat = FALSE), sec_id$Id)] else NULL
say("Grid: %d land cells of %g m", sum(land), res(P)[1])

# the starting pools, from the Build's initial stock maps
st <- read_default("initialstocks", "stock-types.csv")
isp <- q("SELECT t.Name AS StockTypeId, s.RasterFileName FROM stsim_InitialStockSpatial s JOIN stsim_StockType t ON t.StockTypeId = s.StockTypeId WHERE s.ScenarioId = %d", bid)
out <- matrix(0, ncell(P), nrow(st), dimnames = list(NULL, st$StockTypeId))
for (i in seq_len(nrow(isp))) if (isp$StockTypeId[i] %in% st$StockTypeId) out[, isp$StockTypeId[i]] <- values(rast(dd("stsim_InitialStockSpatial", isp$RasterFileName[i])), mat = FALSE)
out[is.na(out)] <- 0
# stock curves and return intervals, by name
cv <- q("SELECT s.Name AS StratumId, c.Name AS StateClassId, g.Name AS TransitionGroupId, v.* FROM lucasCore_InitialStockCurve v JOIN stsim_Stratum s ON s.StratumId = v.StratumId
         JOIN stsim_StateClass c ON c.StateClassId = v.StateClassId JOIN stsim_TransitionGroup g ON g.TransitionGroupId = v.TransitionGroupId WHERE v.ScenarioId = %d", bid)
cv <- cv[, !duplicated(names(cv)), with = FALSE]; if (!nrow(cv)) stop("result ", bid, " has no Initial Stock Curves")
ri <- rbind(q("SELECT s.Name AS StratumId, c.Name AS StateClassId, v.ReturnInterval FROM lucasCore_OutputDecayCalibration v JOIN stsim_Stratum s ON s.StratumId = v.StratumId
               JOIN stsim_StateClass c ON c.StateClassId = v.StateClassId WHERE v.ScenarioId = %d", bid)[, ReturnInterval := as.numeric(ReturnInterval)],
            read_default("spinup", "return-interval.csv")[, .(StratumId = Stratum, StateClassId = StateClass, ReturnInterval = as.numeric(ReturnInterval))])
# the productivity multipliers and the ReforestType map
fsm <- q("SELECT t.Name AS Type, m.MultiplierFileName AS f FROM stsim_FlowSpatialMultiplier m JOIN stsim_FlowMultiplierType t ON t.FlowMultiplierTypeId = m.FlowMultiplierTypeId WHERE m.ScenarioId = %d", bid)
mv <- function(type) { f <- fsm[Type == type, f]; if (!length(f)) return(NULL); p <- dd("stsim_FlowSpatialMultiplier", f[1]); if (!file.exists(p)) return(NULL); say("%s multiplier: %s", type, basename(p)); values(rast(p), mat = FALSE) }
lcl <- q("SELECT ReforestTypeFileName AS f FROM lucasCore_OutputLandCoverLayers WHERE ScenarioId = %d", bid)
rtf <- if (nrow(lcl) && !is.na(lcl$f[1])) dd("lucasCore_OutputLandCoverLayers", lcl$f[1]) else NA
reach <- if (!is.na(rtf) && file.exists(rtf)) scl_id$Name[match(values(rast(rtf), mat = FALSE), scl_id$Id)] else NULL
# LANDFIRE BpS
src <- q("SELECT * FROM lucasCore_DataSource"); bps <- arg(5, if (nrow(src) && "BpsFile" %in% names(src)) src$BpsFile[1] else NA)
if (is.na(bps) && nrow(src) && !is.na(src$DataSourcesHome[1])) { f <- list.files(src$DataSourcesHome[1], "^LC20_BPS_220[.]tif$", recursive = TRUE, full.names = TRUE)
  if (length(f)) { e <- as.polygons(ext(P), crs = crs(P)); ok <- vapply(f, function(p) { r <- rast(p); relate(project(e, crs(r)), as.polygons(ext(r), crs = crs(r)), "within")[1, 1] }, TRUE)
    bps <- if (any(ok)) f[ok][1] else NA } }
say("BpS: %s", bps); ra <- q("SELECT RiparianAs FROM lucasCore_ReforestationOptions WHERE ScenarioId = %d", bid)$RiparianAs
dbDisconnect(con)
lt <- function(f) { x <- read_default("initialstocks", f); setnames(x, gsub("ID$", "Id", names(x))); x[, `:=`(Value = as.numeric(Value), AgeMin = suppressWarnings(as.integer(AgeMin)))][StateAttributeTypeId %in% st$Attribute] }

t0 <- Sys.time()
cb <- capacity_build(P = P, land = land, sname = sname, cname = cname, pname = capacity_parent(cname, scl_id), out = out, st = st, cv = cv, ri = ri,
  membership = read_default("stockflow", "stsim_StockTypeGroupMembership.csv"), steady = lt("grassland-shrubland.csv"), aged = rbind(lt("chaparral.csv"), lt("shrub-age.csv"), fill = TRUE),
  regions = read_default("transitions", "post-disturbance-regions.csv"), m_site = mv("Site Productivity"), m_gs = mv("Grass and Shrub Productivity"), reach = reach,
  bps_file = bps, bps = bps_lookup(read_default("landcover", "LF20_BPS_220.csv"), read_default("landcover", "bps-groups.csv")), bps_groups = read_default("landcover", "bps-groups.csv"),
  riparian_as = if (length(ra) && ra[1] %in% 2) "non-forest" else "forest", secondary = secn, say = say, natural = arg(6, "own"))
say("capacity_build: %.0f s", as.numeric(Sys.time() - t0, units = "secs"))
stopifnot(all(is.finite(cb$capacity[land]) & cb$capacity[land] >= 0))
cat("\nCarbon Capacity by Type\n"); print(cb$type, nrows = 60)
cat("\nCarbon Capacity Summary\n"); print(cb$summary, nrows = 80)
wr <- function(v, f) { p <- file.path(outdir, f); writeRaster(setValues(rast(P), v), p, overwrite = TRUE, datatype = "FLT4S"); p }
maps <- data.table(CapacityFileName = wr(cb$capacity, "CarbonCapacity.tif"), UpperBoundFileName = wr(cb$upper, "CarbonCapacityUpperBound.tif"),
                   StartStockFileName = wr(cb$start, "CarbonCapacityStartStock.tif"), LiveFileName = wr(cb$live, "CarbonCapacityLive.tif"), ForestShareFileName = wr(cb$forest_share, "CarbonCapacityForestShare.tif"))
say("\nMaps in %s", outdir)

if (!is.na(rid)) {
  X <- load_run(lib, rid); hid <- find_history(lib, rid)
  if (!is.na(hid)) { H <- load_run(lib, hid); if (H$years[2] == X$years[1]) X <- join_runs(H, X) }
  X$cap <- capacity_maps(maps); cs <- capacity_series(X$stocks, X$cap$total, X$cap$upper_total)
  if (is.null(cs)) say("run %d has no stock output for the capacity pools", rid) else { cat("\nRun against the capacity (Tg C)\n"); print(cs[c(1, .N)])
    for (e in list(list(X$years[1], X$sc0, X$hl0), list(X$years[2], X$sc1, X$hl1))) { cy <- capacity_year(X$cap, e[[2]], e[[3]], X$sc_list)
      if (is.null(cy)) say("%d: no maps for the deficit by cause", e[[1]]) else say("%d: deficit by cause from the maps: %s (sum %.2f; the tables give %.2f)", e[[1]],
        paste(sprintf("%s %+.2f", names(cy$split), cy$split), collapse = ", "), sum(cy$split), cs[Timestep == e[[1]], Deficit]) } }
  res <- run_figures(X, S, setNames(argb(scl$Color), scl$Name), NULL, "Study area", NULL, file.path(outdir, "figures"), run_name = sprintf("result %d", rid))
  print(res[grepl("capacity", basename(FileName)), .(Figure, Title, File = basename(FileName))]) }
