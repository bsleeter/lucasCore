# =============================================================================
# unit-prism-grid.R - the PRISM grid a Build reads (800 m or 4 km): the choice, the files, and the coast fill (2026-11-23)
# =============================================================================
# Plain R, no SyncroSim, no network. Checks that
#   - Climate Options: PRISM Grid reads as a label by number or name, and no value is 800 m (src/prism.R)
#   - the annual, monthly and normal files of each grid are where the Data Download puts them
#   - a Build reads the grid chosen only when the folder holds it, and the message says what the folder holds and what to do
#   - the package offers the choice on both pages with the same values, stages 2, 3 and 7 read it, and update 1.9 adds its columns
#   - the coast fill of a climate field reaches the same distance (about 9 km) at 800 m as at 4 km (src/climate.R, to_grid)
#   - with the real home (E:/lucasData), when it holds both grids: the ecodivision normals agree to 0.02 C and 0.5%
# Usage: Rscript tests/unit-prism-grid.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "prism.R")); source(file.path(pkg, "src", "growth.R"))
ok <- 0; bad <- 0
expect <- function(what, cond, note = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, note, "\n") } }

# ---- the choice ------------------------------------------------------------------------------------------------------------
expect("PRISM Grid: 1 and '800 m' are 800 m, 2 and '4 km' are 4 km", identical(prism_choice(1L), "800 m") && identical(prism_choice("800 m"), "800 m") && identical(prism_choice(2L), "4 km") && identical(prism_choice("4 km"), "4 km"))
expect("no value (a scenario from before the choice, an empty sheet) is 800 m", identical(prism_choice(NA), "800 m") && identical(prism_choice(NULL), "800 m") && identical(prism_choice(integer()), "800 m") && identical(prism_choice(""), "800 m"))
expect("anything else is not a choice", is.na(prism_choice("1 km")) && is.na(prism_choice(3L)))

# ---- the files -------------------------------------------------------------------------------------------------------------
expect("800 m: annual and monthly files", prism_annual("p", "800 m", "tmean", 2012) == "p/annual-us30s/tmean/prism_tmean_us_30s_2012.tif" && prism_monthly("p", "800 m", "ppt", 2012, 7) == "p/monthly-us30s/ppt/prism_ppt_us_30s_201207.tif")
expect("4 km: annual and monthly files, as every earlier version read them", prism_annual("p", "4 km", "ppt", 1999) == "p/annual-us25m/ppt/prism_ppt_us_25m_1999.tif" && prism_monthly("p", "4 km", "ppt", 1999, 11) == "p/monthly-us25m/ppt/prism_ppt_us_25m_199911.tif")
expect("several years or months at once", length(prism_annual("p", "800 m", "ppt", 1991:2020)) == 30 && identical(basename(prism_monthly("p", "800 m", "ppt", 2001, 10:12)), sprintf("prism_ppt_us_30s_2001%d.tif", 10:12)))
root <- file.path(tempdir(), "prism-grid"); unlink(root, recursive = TRUE); dir.create(root); root <- normalizePath(root, winslash = "/")
mk <- function(d, f) { dir.create(file.path(root, d, dirname(f)), recursive = TRUE, showWarnings = FALSE); writeLines("x", file.path(root, d, f)) }
for (v in c("tmean", "ppt")) { mk("old", sprintf("normals/prism_%s_us_25m_2020_avg_30y.tif", v)); mk("both", sprintf("normals/prism_%s_us_25m_2020_avg_30y.tif", v))
  for (d in c("both", "new")) { mk(d, sprintf("normals-us30s/%s/prism_%s_us_30s_2020_avg_30y.tif", v, v)); mk(d, sprintf("normals-us30s/%s/prism_%s_us_30s_202007_avg_30y.tif", v, v)) } }
mk("legacy", "normals/PRISM_tmean_30yr_normal_4kmM4_annual_bil/PRISM_tmean_30yr_normal_4kmM4_annual_bil.bil"); mk("legacy", "normals/PRISM_ppt_30yr_normal_4kmM4_annual_bil/PRISM_ppt_30yr_normal_4kmM4_annual_bil.bil")
dir.create(file.path(root, "empty")); p <- function(d) file.path(root, d)
expect("the annual normal of each grid, never a monthly one or the other grid's", basename(prism_normal(p("both"), "tmean", "800 m")) == "prism_tmean_us_30s_2020_avg_30y.tif" && basename(prism_normal(p("both"), "ppt", "4 km")) == "prism_ppt_us_25m_2020_avg_30y.tif")
expect("the legacy 4 km .bil normals still read", grepl("annual_bil[.]bil$", prism_normal(p("legacy"), "tmean", "4 km")) && prism_holds(p("legacy"), "4 km") && !prism_holds(p("legacy"), "800 m"))
expect("what a folder holds", prism_holds(p("old"), "4 km") && !prism_holds(p("old"), "800 m") && prism_holds(p("new"), "800 m") && !prism_holds(p("new"), "4 km") && prism_holds(p("both"), "800 m") && prism_holds(p("both"), "4 km") && !prism_holds(p("empty"), "4 km"))
err <- function(...) tryCatch({ prism_pick(...); "" }, error = function(e) conditionMessage(e))
expect("a Build reads the grid chosen when the folder holds it", identical(prism_pick(p("both"), "800 m"), "800 m") && identical(prism_pick(p("both"), "4 km"), "4 km") && identical(prism_pick(p("old"), "4 km"), "4 km") && identical(prism_pick(p("new")), "800 m"))
e1 <- err(p("old"), "800 m"); e2 <- err(p("new"), "4 km"); e3 <- err(p("empty"), "800 m")
expect("800 m chosen, only 4 km held: stops, names both ways out", grepl("PRISM Grid is 800 m", e1) && grepl("holds the 4 km grids", e1) && grepl("Data Download", e1) && grepl("set PRISM Grid to 4 km", e1), e1)
expect("4 km chosen, only 800 m held: stops the same way", grepl("PRISM Grid is 4 km", e2) && grepl("set PRISM Grid to 800 m", e2), e2)
expect("neither held: says so", grepl("holds neither grid", e3) && grepl("Data Download", e3), e3)
expect("an unrecognised choice stops", grepl("unrecognised", err(p("both"), NA_character_)))

# ---- the package -----------------------------------------------------------------------------------------------------------
px <- paste(readLines(file.path(pkg, "package.xml"), warn = FALSE), collapse = "\n"); rs <- function(f) paste(readLines(file.path(pkg, f), warn = FALSE), collapse = "\n")
col <- 'name="PrismGrid"[^>]*isOptional="True"[^>]*formula1="1:800 m\\|2:4 km"[^>]*defaultValue="1"'
expect("package.xml: PRISM Grid on Climate Options and on the Data Download options, optional, default 800 m", lengths(regmatches(px, gregexpr(col, px))) == 2)
sheet <- function(tr) { m <- regmatches(px, regexpr(sprintf('(?s)<transformer name="%s".*?</transformer>', tr), px, perl = TRUE)); grepl('<dataSheet name="ClimateOptions" type="Input"/>', m, fixed = TRUE) }
expect("stages 2, 3 and 7 take Climate Options as an input", sheet("GrowthCurves") && sheet("CarbonFlows") && sheet("ClimateMultipliers"))
pick <- 'prism_pick(src$PrismFolder, prism_choice(read_ds("ClimateOptions")$PrismGrid))'
expect("stages 2, 3 and 7 read the grid chosen", all(vapply(c("src/2-growth-curves.R", "src/3-carbon-flows.R", "src/7-climate-multipliers.R"), function(f) grepl(pick, rs(f), fixed = TRUE) && grepl('pkg_file("src", "prism.R")', rs(f), fixed = TRUE), TRUE)))
expect("stage 7 names no grid of its own", !grepl("us_25m|us25m|us_30s|us30s", gsub("#[^\n]*", "", rs("src/7-climate-multipliers.R"))))
expect("both pages offer the choice with the same values and default", all(vapply(c("ui/ClimateOptionsView.cs", "ui/DataDownloadView.cs"), function(f) { u <- rs(f)
  grepl('new Choice("PrismGrid", 1)', u, fixed = TRUE) && grepl("ShowChoice(m_prism)", u, fixed = TRUE) && grepl('"800 m (default)"', u, fixed = TRUE) && grepl('"4 km"', u, fixed = TRUE) }, TRUE)))
up <- rs("ui/LucasCoreUpdates.cs")
expect("update 1.9 adds the column to both sheets, with no apostrophe in its description", grepl('AddColumn(store, "lucasCore_ClimateOptions", "PrismGrid", "INTEGER")', up, fixed = TRUE) &&
       grepl('AddColumn(store, "lucasCore_DataDownloadOptions", "PrismGrid", "INTEGER")', up, fixed = TRUE) && grepl('\\[Update\\(1\\.9, "[^"\']*"\\)\\]', up))
src <- new.env(); for (f in c("datahome.R", "download.R", "download-sources.R")) sys.source(file.path(pkg, "src", f), envir = src)
expect("the Data Download reads the same choice", identical(src$prism_resolution(list(opts = data.table(PrismGrid = 2L))), "4 km") && identical(src$prism_resolution(list(opts = data.table(PrismGrid = NA_integer_))), "800 m") &&
       identical(src$prism_resolution(list(opts = data.table())), "800 m") && identical(unname(src$PRISM_RES[["800 m"]][["tok"]]), PRISM_GRIDS[["800 m"]]) && identical(unname(src$PRISM_RES[["4 km"]][["tok"]]), PRISM_GRIDS[["4 km"]]))

# ---- the coast fill ---------------------------------------------------------------------------------------------------------
# a coast running north-south at 75.75 W: climate west of it, none (sea) east of it; the model grid has land out to 75.60 W
e <- new.env(); sys.source(file.path(pkg, "src", "climate.R"), envir = e); wd <- tempfile(); dir.create(wd)
fmt <- fread(file.path(pkg, "defaults/climate/flow-multipliers.csv"), colClasses = "character", na.strings = "")
stubs <- list(write_raster = function(r, f, type) { f <- file.path(wd, f); terra::writeRaster(r, f, overwrite = TRUE); f },
              read_default = function(...) fread(file.path(pkg, "defaults", ...), colClasses = "character", na.strings = ""), check = function(...) invisible(), say = function(...) invisible(), fail = function(...) stop(sprintf(...)),
              stsim_list = function(x) if (x == "FlowGroup") data.table(Name = unique(fmt$FlowGroupId)) else data.table(Name = "x", Id = 1L),
              read_dom_parameters = function() fread(file.path(pkg, "defaults/cbm/dom-parameters.csv"), na.strings = "")[, .(StratumId = NA_character_, Pool, BaseDecayRate, ReferenceTemperature, Q10, ShareEmitted, TransferToBGSlow)])
for (n in names(stubs)) assign(n, stubs[[n]], envir = e)
for (n in c("rast", "focal", "global", "res", "project", "mask", "cover", "init", "values", "ifel", "classify")) assign(n, get(n, asNamespace("terra")), envir = e)
P <- rast(xmin = -75.80, xmax = -75.60, ymin = 36.20, ymax = 36.30, resolution = 0.002, crs = "EPSG:4269", vals = 1L)
fm <- e$climate_flows(data.frame(ForestGrowthModel = 1L, NonForestGrowthModel = 1L, DecompositionModel = 1L, WetlandGrowthModel = 3L), "t"); prm <- e$climate_params(fm, P, "t", NULL)
wt <- round(e$miami_t(22) / e$miami_t(20), 3)
reach <- function(cell) { f <- rast(xmin = -76.5, xmax = -75, ymin = 35.5, ymax = 37, resolution = cell, crs = "EPSG:4269"); x <- crds(f)[, 1]
  field <- function(v) setValues(f, ifelse(x < -75.75, v, NA)); em <- e$climate_emitter(fm, P, prm)
  em$emit(2001, field(22), field(1000), field(1000), field(20), field(1000), e$climate_normals(20, 1000), "test")
  r <- rast(em$rows[[1]]$MultiplierFileName); lon <- crds(r)[, 1]; v <- values(r, mat = FALSE); got <- abs(v - wt) < 1e-6
  list(km = (max(lon[got]) + 75.75) * 111.32 * cos(36.25 * pi / 180), at5 = all(got[lon < -75.70]), far = all(abs(v[lon > -75.62] - 1) < 1e-6), unfilled = em$unfilled) }
r4 <- reach(1 / 24); r8 <- reach(1 / 120)
expect("4 km field: land within 5 km of the coast takes its climate, land 12 km out is left at normal", r4$at5 && r4$far, sprintf("reach %.1f km", r4$km))
expect("800 m field: the same", r8$at5 && r8$far, sprintf("reach %.1f km", r8$km))
expect("the two reach about the same distance (within 2.5 km)", abs(r4$km - r8$km) < 2.5 && r8$km > 5, sprintf("%.1f km vs %.1f km", r4$km, r8$km))
cat(sprintf("  coast fill reach: 4 km field %.1f km, 800 m field %.1f km\n", r4$km, r8$km))

# ---- the real home ---------------------------------------------------------------------------------------------------------
real <- "E:/lucasData/climate/prism"; eco <- file.path(pkg, "defaults/strata/ecodivisions/EcoDivisions_Dissolve.shp")
if (prism_holds(real, "800 m") && prism_holds(real, "4 km") && file.exists(eco)) {
  a <- ecodiv_climate(eco, real, "4 km"); b <- ecodiv_climate(eco, real, "800 m"); m <- merge(a, b, by = "ecodiv", suffixes = c("4", "8"))
  expect("the real home: 19 ecodivisions, normals agree to 0.02 C and 0.5%, and no grid named reads 800 m", nrow(m) == 19 && max(abs(m$mat8 - m$mat4)) < 0.02 && max(abs(m$map8 / m$map4 - 1)) < 0.005 &&
         isTRUE(all.equal(ecodiv_climate(eco, real)$mat, b$mat)), sprintf("max %.3f C, %.2f%%", max(abs(m$mat8 - m$mat4)), 100 * max(abs(m$map8 / m$map4 - 1))))
} else cat("skip: the real home does not hold both grids at", real, "\n")

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
