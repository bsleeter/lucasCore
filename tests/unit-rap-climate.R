# =============================================================================
# unit-rap-climate.R - the RAP fit climate response for grass and shrub growth (to-do 39 step 7; no SyncroSim)
# =============================================================================
# Checks that defaults/climate/rap-climate-coefficients.csv has a LifeForm All row for every stratum of defaults/stsim/stsim_Stratum.csv
# with finite coefficients, that the table is what tools/make_rap_climate_coefficients.R makes from the window fits (rerun it after
# refitting), that the response is 1 at normal climate and rises with precipitation, and that src/climate.R knows the choice (the
# Climate Options list and the coefficient table) and package.xml lists it.
# Usage: Rscript tests/unit-rap-climate.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
ok <- 0; bad <- 0
expect <- function(what, cond, detail = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, detail, "\n") } }
tc <- fread(file.path(pkg, "defaults/climate/rap-climate-coefficients.csv")); st <- fread(file.path(pkg, "defaults/stsim/stsim_Stratum.csv"))
all <- tc[LifeForm == "All"]
expect("every stratum has a LifeForm All row", setequal(all$Id, st$Id) && nrow(all) == nrow(st), paste(setdiff(st$Name, all$StratumId), collapse = ", "))
expect("the All coefficients are finite", all(is.finite(as.matrix(all[, .(PrecipCoef, PrecipLagCoef, TempCoef)]))))
expect("each life form has a row per stratum", all(tc[, .N, LifeForm]$N == nrow(st)) && setequal(unique(tc$LifeForm), c("All", "Annual grass", "Perennial grass", "Shrub")))
# the table is the tool's output
tmp <- tempfile(); dir.create(file.path(tmp, "defaults/climate"), recursive = TRUE); dir.create(file.path(tmp, "defaults/stsim")); dir.create(file.path(tmp, "dev/nonforest"), recursive = TRUE)
invisible(file.copy(file.path(pkg, "defaults/stsim/stsim_Stratum.csv"), file.path(tmp, "defaults/stsim"))); invisible(file.copy(file.path(pkg, "dev/nonforest/05-rap-climate-window-fits.csv"), file.path(tmp, "dev/nonforest")))
owd <- setwd(tmp); invisible(capture.output(source(file.path(pkg, "tools/make_rap_climate_coefficients.R")))); setwd(owd)
re <- fread(file.path(tmp, "defaults/climate/rap-climate-coefficients.csv"))
expect("the table matches tools/make_rap_climate_coefficients.R on the window fits", isTRUE(all.equal(re, tc, check.attributes = FALSE)))
# the response
resp <- function(r, p, pl, t) 1 + r$PrecipCoef * (p - 1) + r$PrecipLagCoef * (pl - 1) + r$TempCoef * t
expect("1 at normal climate in every ecodivision", all(abs(resp(all, 1, 1, 0) - 1) < 1e-12))
conus_like <- all[Source == "CONUS life form"]
expect("a wet year raises growth where the pool is CONUS's", !nrow(conus_like) || all(resp(conus_like, 1.3, 1, 0) > 1))
expect("the precipitation response is positive in most ecodivisions", mean(all$PrecipCoef > 0) >= 0.8, sprintf("%.0f%%", 100 * mean(all$PrecipCoef > 0)))
# the model knows it
cl <- paste(readLines(file.path(pkg, "src/climate.R")), collapse = "\n")
expect("src/climate.R offers RAP fit for non-forest growth", grepl('c("None", "Miami NPP", "RAP fit")', cl, fixed = TRUE) && grepl("rap-climate-coefficients.csv", cl, fixed = TRUE))
px <- paste(readLines(file.path(pkg, "package.xml")), collapse = "\n")
expect("package.xml lists 3:RAP fit for Non-Forest Growth", grepl('name="NonForestGrowthModel"[^>]*formula1="1:None\\|2:Miami NPP\\|3:RAP fit"', px))
cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
