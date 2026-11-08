# =============================================================================
# unit-rap-climate.R - the RAP fit climate response for grass and shrub growth (to-do 39 step 7; no SyncroSim)
# =============================================================================
# Checks that defaults/climate/rap-climate-coefficients.csv has a row for every stratum of defaults/stsim/stsim_Stratum.csv with finite
# coefficients, that the table is what tools/make_rap_climate_coefficients.R makes from the seasonal fit (rerun it after refitting),
# that the response is 1 at normal climate and rises with a wet winter, that the emitter in src/climate.R computes the same response
# on rasters (seasons, aridity clamp, floor at 0), and that src/climate.R and package.xml know the choice.
# Usage: Rscript tests/unit-rap-climate.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
ok <- 0; bad <- 0
expect <- function(what, cond, detail = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, detail, "\n") } }
tc <- fread(file.path(pkg, "defaults/climate/rap-climate-coefficients.csv")); st <- fread(file.path(pkg, "defaults/stsim/stsim_Stratum.csv"))
cols <- c("OndCoef", "JfmCoef", "AmjCoef", "JasCoef", "PrecipLagCoef", "TempCoef", "OndAridCoef", "JfmAridCoef", "AmjAridCoef", "PrecipLagAridCoef", "AridMin", "AridMax")
expect("every stratum has a row", setequal(tc$Id, st$Id) && nrow(tc) == nrow(st), paste(setdiff(st$Name, tc$StratumId), collapse = ", "))
expect("the coefficients are finite", all(cols %in% names(tc)) && all(is.finite(as.matrix(tc[, ..cols]))))
expect("AridMin < AridMax", all(tc$AridMin < tc$AridMax))
# the table is the tool's output
tmp <- tempfile(); dir.create(file.path(tmp, "defaults/climate"), recursive = TRUE); dir.create(file.path(tmp, "defaults/stsim")); dir.create(file.path(tmp, "dev/nonforest"), recursive = TRUE)
invisible(file.copy(file.path(pkg, "defaults/stsim/stsim_Stratum.csv"), file.path(tmp, "defaults/stsim"))); invisible(file.copy(file.path(pkg, "dev/nonforest/07-rap-climate-seasonal-fit.csv"), file.path(tmp, "dev/nonforest")))
owd <- setwd(tmp); invisible(capture.output(source(file.path(pkg, "tools/make_rap_climate_coefficients.R")))); setwd(owd)
re <- fread(file.path(tmp, "defaults/climate/rap-climate-coefficients.csv"))
expect("the table matches tools/make_rap_climate_coefficients.R on the seasonal fit", isTRUE(all.equal(re, tc, check.attributes = FALSE)))
# the response at a site: s = seasonal anomalies / water-year normal, pl, ta, ar = log(normal / 500)
resp <- function(r, s, pl, ta, ar) { ar <- pmin(pmax(ar, r$AridMin), r$AridMax)
  pmax(1 + (r$OndCoef + r$OndAridCoef * ar) * s[1] + (r$JfmCoef + r$JfmAridCoef * ar) * s[2] + (r$AmjCoef + r$AmjAridCoef * ar) * s[3] + r$JasCoef * s[4] +
       (r$PrecipLagCoef + r$PrecipLagAridCoef * ar) * pl + r$TempCoef * ta, 0) }
mid <- (tc$AridMin + tc$AridMax) / 2
expect("1 at normal climate in every ecodivision", all(abs(resp(tc, c(0, 0, 0, 0), 0, 0, mid) - 1) < 1e-12))
wet <- resp(tc, c(0.1, 0.2, 0, 0), 0, 0, mid)   # a winter 30% of the water year's normal wetter
expect("a wet winter raises growth in most ecodivisions at their middle aridity", mean(wet > 1) >= 0.8, sprintf("%.0f%%", 100 * mean(wet > 1)))
med <- tc[StratumId == "Mediterranean"]
expect("Mediterranean is fitted on its own windows", nrow(med) == 1 && med$Source == "ecodivision")
# the emitter: one year on a 3 x 3 grid of Mediterranean, built from src/climate.R's own code
src_env <- new.env(); cl <- readLines(file.path(pkg, "src/climate.R")); eval(parse(text = cl), envir = src_env)
P <- rast(nrows = 3, ncols = 3, xmin = 0, xmax = 3000, ymin = 0, ymax = 3000, crs = "EPSG:5070", vals = med$Id)
wd <- tempfile(); dir.create(wd)
local({ write_raster <- function(r, f, type) { f <- file.path(wd, f); terra::writeRaster(r, f, overwrite = TRUE); f }
  read_default <- function(...) fread(file.path(pkg, "defaults", ...)); check <- function(...) invisible(); say <- function(...) invisible(); stsim_list <- function(...) st[, .(Name, Id)]
  for (n in c("write_raster", "read_default", "check", "say", "stsim_list")) assign(n, get(n), envir = src_env)
  # the coefficients by hand (climate_params also reads the Q10 table, which this test leaves out)
  prm <- list(coef = list(`RAP fit` = lapply(src_env$RAP_COEF, function(k) init(P, med[[k]]))))
  fm <- data.table(FlowGroupId = "Net Growth Non Forest: Total", Model = "RAP fit", Role = "NonForestGrowth")
  em <- src_env$climate_emitter(fm, P, prm)
  Sn <- list(ond = init(P, 150), jfm = init(P, 250), amj = init(P, 80), jas = init(P, 20))   # a 500 mm water year: ar = 0
  S <- list(ond = init(P, 200), jfm = init(P, 350), amj = init(P, 80), jas = init(P, 20)); S1 <- Sn
  em$emit(2001, init(P, 15), init(P, 500), init(P, 500), init(P, 15), init(P, 500), list(forest = 1, nonforest = 1), "test", src_env$rap_water_year(S, S1, Sn))
  v <- values(rast(em$rows[[1]]$MultiplierFileName), mat = FALSE)
  want <- resp(med, c(50, 100, 0, 0) / 500, 0, 0, 0)
  expect("the emitter's multiplier is the table's response", all(abs(v - round(want, 3)) < 1e-6), sprintf("%.3f vs %.3f", v[1], want))
  S <- list(ond = init(P, 0), jfm = init(P, 0), amj = init(P, 0), jas = init(P, 0))   # no rain at all, after a dry year
  em$emit(2002, init(P, 18), init(P, 0), init(P, 0), init(P, 15), init(P, 500), list(forest = 1, nonforest = 1), "test", src_env$rap_water_year(S, S, Sn))
  v <- values(rast(em$rows[[2]]$MultiplierFileName), mat = FALSE)
  expect("a rainless year is floored at 0, not negative", all(v >= 0) && all(v < 1)) })
# the model knows it
cl <- paste(cl, collapse = "\n")
expect("src/climate.R offers RAP fit for non-forest growth", grepl('c("None", "Miami NPP", "RAP fit")', cl, fixed = TRUE) && grepl("rap-climate-coefficients.csv", cl, fixed = TRUE))
px <- paste(readLines(file.path(pkg, "package.xml")), collapse = "\n")
expect("package.xml lists 3:RAP fit for Non-Forest Growth", grepl('name="NonForestGrowthModel"[^>]*formula1="1:None\\|2:Miami NPP\\|3:RAP fit"', px))
cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
