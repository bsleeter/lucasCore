# =============================================================================
# unit-wetland-climate.R - the climate response of emergent marsh growth (to-do 54; Climate Options: Wetland Growth; no SyncroSim)
# =============================================================================
# Checks that Climate Options, the climate flow table, src/climate.R and the options page know the choice; that a scenario without a
# value takes the default; that the Temperature response is 1 at the normal and about 4% per degree C; and that the emitter writes,
# for Temperature and Miami NPP, the temperature response in the cells that start as estuarine emergent marsh and Miami NPP elsewhere.
# Usage: Rscript tests/unit-wetland-climate.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
ok <- 0; bad <- 0
expect <- function(what, cond, detail = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, detail, "\n") } }
px <- paste(readLines(file.path(pkg, "package.xml")), collapse = "\n"); cl <- readLines(file.path(pkg, "src/climate.R")); ui <- paste(readLines(file.path(pkg, "ui/ClimateOptionsView.cs")), collapse = "\n")
fmt <- fread(file.path(pkg, "defaults/climate/flow-multipliers.csv"), colClasses = "character", na.strings = "")
memb <- fread(file.path(pkg, "defaults/stockflow/stsim_FlowTypeGroupMembership.csv"), colClasses = "character")
OPT <- c("None", "Miami NPP", "Temperature", "Temperature and Miami NPP"); G <- "Net Growth Wetland: Total"
expect("package.xml: Wetland Growth with the four choices, optional, default 3 (Temperature)",
       grepl('name="WetlandGrowthModel"[^>]*isOptional="True"[^>]*formula1="1:None\\|2:Miami NPP\\|3:Temperature\\|4:Temperature and Miami NPP"[^>]*defaultValue="3"', px))
expect("the climate flow table gives the marsh growth group the WetlandGrowth role, once", fmt[Role == "WetlandGrowth", .N == 1 && FlowGroupId == G])
expect("only the two emergent marsh growth flows are in that group (forested wetlands grow on the forest flows)",
       setequal(memb[FlowGroupId == G, FlowTypeId], paste("Net Growth Wetland Emergent: Atmosphere ->", c("Foliage", "Fine Roots"))))
expect("the options page offers the same four choices with the same default", grepl('new Choice("WetlandGrowthModel", 3)', ui, fixed = TRUE) && grepl('ShowChoice(m_wetland)', ui, fixed = TRUE) &&
       all(vapply(OPT[c(1, 2, 4)], function(o) grepl(sprintf('"%s"', o), ui, fixed = TRUE), TRUE)) && grepl('"Temperature (default)"', ui, fixed = TRUE))
expect("stages 7 and 11 pass the scenario's state class map to the climate parameters", all(vapply(c("7-climate-multipliers.R", "11-projection-climate.R"), function(f)
       any(grepl("climate_params(fm, P, STAGE, ic$StateClassFileName[1])", readLines(file.path(pkg, "src", f)), fixed = TRUE)), TRUE)))

e <- new.env(); eval(parse(text = cl), envir = e); wd <- tempfile(); dir.create(wd); said <- character()
st <- data.table(Name = c("Subtropical"), Id = 1L); scl <- data.table(Name = c("Wetland: Estuarine Emergent", "Wetland: Palustrine Emergent"), Id = c(96L, 95L))
stubs <- list(write_raster = function(r, f, type) { f <- file.path(wd, f); terra::writeRaster(r, f, overwrite = TRUE); f },
              read_default = function(...) fread(file.path(pkg, "defaults", ...), colClasses = "character", na.strings = ""), check = function(...) invisible(),
              say = function(...) said <<- c(said, sprintf(...)), fail = function(...) stop(sprintf(...)),
              stsim_list = function(x) if (x == "StateClass") scl else if (x == "FlowGroup") data.table(Name = unique(fmt$FlowGroupId)) else st,
              read_dom_parameters = function() fread(file.path(pkg, "defaults/cbm/dom-parameters.csv"), na.strings = "")[, .(StratumId = NA_character_, Pool, BaseDecayRate, ReferenceTemperature, Q10, ShareEmitted, TransferToBGSlow)])
for (n in names(stubs)) assign(n, stubs[[n]], envir = e)
expect("the choices in src/climate.R are the package's, in order", identical(e$WETLAND_GROWTH, OPT))
base <- data.frame(ForestGrowthModel = 1L, NonForestGrowthModel = 1L, DecompositionModel = 1L)
mdl <- function(co) { f <- e$climate_flows(co, "t"); f[FlowGroupId == G, Model] }
expect("a scenario without a Wetland Growth value takes the default (Temperature)", identical(mdl(base), OPT[3]) && identical(mdl(cbind(base, WetlandGrowthModel = NA_integer_)), OPT[3]))
expect("each choice by number and by label; None drops the marsh growth group", identical(mdl(cbind(base, WetlandGrowthModel = 3L)), OPT[3]) && identical(mdl(cbind(base, WetlandGrowthModel = "Miami NPP")), OPT[2]) &&
       !length(mdl(cbind(base, WetlandGrowthModel = 1L))))
# the Temperature response: 1 at the normal, rising, about 4% per degree C near 15 C
tr <- function(t, tn) e$miami_t(t) / e$miami_t(tn)
expect("Temperature: 1 at the normal, more growth when warmer, 3 to 5% per degree C between 10 and 25 C", tr(18, 18) == 1 && tr(19, 18) > 1 && tr(17, 18) < 1 &&
       all(vapply(c(10, 15, 20, 25), function(t) tr(t + 1, t) - 1, 1) > 0.03 & vapply(c(10, 15, 20, 25), function(t) tr(t + 1, t) - 1, 1) < 0.05))
# the emitter on a 2 x 2 grid: the left column starts as estuarine emergent marsh, the right as palustrine
P <- rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2000, ymin = 0, ymax = 2000, crs = "EPSG:5070", vals = 1L)
S <- setValues(rast(P), c(96L, 95L, 96L, 95L)); sf <- file.path(wd, "sc.tif"); writeRaster(S, sf, overwrite = TRUE)
run <- function(choice, sc_file, Ty, Py, Tn = 20, Pn = 1500) { fm <- e$climate_flows(cbind(base, WetlandGrowthModel = choice), "t"); prm <- e$climate_params(fm, P, "t", sc_file)
  em <- e$climate_emitter(fm, P, prm); em$emit(2001, init(P, Ty), init(P, Py), init(P, Pn), init(P, Tn), init(P, Pn), e$climate_normals(Tn, Pn), "test")
  values(rast(em$rows[[1]]$MultiplierFileName), mat = FALSE) }
v0 <- run(4L, sf, 20, 1500); expect("Temperature and Miami NPP: 1 in every cell at the normal climate", all(abs(v0 - 1) < 1e-6))
# a year 2 C warmer and much drier: tidal cells follow temperature (up), inland cells Miami NPP (down: precipitation is the smaller term)
v <- run(4L, sf, 22, 900); wt <- round(tr(22, 20), 3); wm <- round(e$miami(22, 900, TRUE) / e$miami(20, 1500, TRUE), 3)
expect("a warm dry year: the tidal cells grow more (the temperature response), the inland cells less (Miami NPP)", all(abs(v[c(1, 3)] - wt) < 1e-6) && all(abs(v[c(2, 4)] - wm) < 1e-6) && wt > 1 && wm < 1,
       sprintf("%s vs %.3f / %.3f", paste(v, collapse = " "), wt, wm))
expect("Temperature: the same response in every cell, tidal or not", all(abs(run(3L, sf, 22, 900) - wt) < 1e-6))
expect("Miami NPP: the same response in every cell", all(abs(run(2L, sf, 22, 900) - wm) < 1e-6))
said <- character(); v <- run(4L, NULL, 22, 900)
expect("without a state class map every cell takes Miami NPP, and the log says so", all(abs(v - wm) < 1e-6) && any(grepl("no state class map", said)))
cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
