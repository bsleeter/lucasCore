# to-do 57 step 5: of the regrowing cells, how many does a fire perimeter date (DisturbedStart Fire against All)?
suppressMessages({library(terra); library(data.table); library(sf)})
pkg <- "F:/lucasCore/.claude/worktrees/lucascore-syncrosim-todo-f02a9f"; source(file.path(pkg, "src", "regrowth-age.R"))
fail <- function(...) stop(sprintf(...)); eval(parse(text = paste(readLines(file.path(pkg, "src", "shared.R"))[grep("^read_fire_perimeters <-", readLines(file.path(pkg, "src", "shared.R"))):(grep("^read_fire_perimeters <-", readLines(file.path(pkg, "src", "shared.R"))) + 9)], collapse = "\n")))
rg <- regrowth_settings(fread(file.path(pkg, "defaults/landcover/regrowth-age.csv"))); y0 <- 1985L; win <- 30L
run <- function(lab, icd, nl, fpf) {
  S <- rast(file.path(icd, "StateClass.tif")); yrs <- 1985:2023
  vS <- values(S, mat = FALSE); fo <- which(!is.na(vS) & vS >= 100 & vS <= 999)
  N <- sapply(yrs, function(y) values(nl(y, S), mat = FALSE)[fo]); rc <- which(N[, 1] %in% c(31, 52, 71))
  ra <- regrowth_age(N[rc, , drop = FALSE], yrs, rg$lag, rg$share, rg$nonforest_years); hit <- !is.na(ra)
  fp <- read_fire_perimeters(fpf, y0 - win, y0); fp <- st_make_valid(st_transform(fp, crs(S)))
  lf <- as.integer(values(rasterize(vect(fp), S, field = "yr", fun = "max"), mat = FALSE)[fo[rc[hit]]])
  ds <- disturbed_start(ra[hit], lf, y0, rg$lag, win, "All"); ha <- prod(res(S)) / 1e4
  cat(sprintf("== %s: %d regrowing cells (%.1f kha); inside a %d-%d perimeter: %.1f kha; dated (return within %d years of the fire): %.1f kha (%.0f%%)\n",
    lab, sum(hit), sum(hit) * ha / 1e3, y0 - win, y0, sum(!is.na(lf)) * ha / 1e3, win, sum(ds$dated) * ha / 1e3, 100 * mean(ds$dated)))
  if (any(ds$dated)) { cat("   fire years of the dated cells:\n"); print(table(cut(lf[ds$dated], c(1954, 1965, 1975, 1980, 1985)))) 
    cat(sprintf("   dated cells' age: regrowth rule median %d, years since fire median %d\n", as.integer(median(ra[hit][ds$dated])), as.integer(median(ds$age[ds$dated])))) } }
P <- "F:/lucasCore/dev/libs/LUCAS P26 Northern Sierra Nevada.ssim.data/Scenario-53"; DS <- "F:/lucasCore/dev/libs/Data Sources/regions"
run("P26", file.path(P, "stsim_InitialConditionsSpatial"), function(y, S) rast(file.path(P, sprintf("lucasCore_OutputNlcdAnnual/NLCD_%d.tif", y))),
    file.path(DS, "Pyrome-P26-Northern-Sierra-Nevada/disturbance/fire-perimeters/InterAgencyFirePerimeterHistory.gpkg"))
G <- "F:/lucasCore/dev/libs/Puget Lowlands.ssim.data/Scenario-59"; reg <- file.path(DS, "EPA-L3-Puget-Lowland")
run("Puget", file.path(G, "stsim_InitialConditionsSpatial"),
    function(y, S) project(crop(rast(file.path(reg, sprintf("land-cover/nlcd-annual/Annual_NLCD_LndCov_%d_CU_C1V2.tif", y))), project(as.polygons(ext(S), crs = crs(S)), "EPSG:5070")), S, method = "mode"),
    file.path(reg, "disturbance/fire-perimeters/InterAgencyFirePerimeterHistory.gpkg"))
