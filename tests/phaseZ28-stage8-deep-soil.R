# =============================================================================
# phaseZ28-stage8-deep-soil.R - stage 8 with Deep Soil and emergent wetland starting pools by ecodivision (to-do 39 step 1, 2026-11-06)
# =============================================================================
# On the test library lucasCore-suitability.ssim (Placer County, 1 km; grass and shrub, no emergent wetland cells): stage 8 alone on Build
# result 47. Checks: stage 8 passes its checks and writes a Deep Soil map; grass, shrub and emergent cells start at the package tables
# for their ecodivision and class; every other cell matches Build 47 cell for cell (forest Deep Soil 0). The rates themselves
# are checked in real ST-Sim by dev/nonforest/02-emergent-stsim-check.R.
# Usage: Rscript tests/phaseZ28-stage8-deep-soil.R      (REUSE=1 reuses the run when it exists)
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
f <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim"); L <- suppressWarnings(ssimLibrary(f)); P1 <- rsyncrosim::project(L, 1); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
nm <- "Stage 8 test (Deep Soil)"
s <- as.data.table(scenario(L, summary = TRUE))
R <- if (Sys.getenv("REUSE") == "1" && nrow(s[IsResult == "Yes" & startsWith(Name, paste0(nm, " ([")) ])) scenario(L, max(s[IsResult == "Yes" & startsWith(Name, paste0(nm, " ([")), ScenarioId])) else {
  for (id in s[IsResult == "No" & Name == nm, ScenarioId]) delete(L, scenario = id, force = TRUE)
  S <- scenario(P1, nm, sourceScenario = 2); saveDatasheet(S, data.frame(StageNameId = "8 - Initial Stock Maps", RunOrder = 1L), "core_Pipeline")
  d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, d))
  t0 <- Sys.time(); r <- run(S); cat(sprintf("stage 8: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))); r }
v <- as.data.table(datasheet(R, "lucasCore_OutputValidation")); expect("stage 8 checks pass", nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", paste(Check, Detail)], collapse = "; "))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); cat(unique(lg[grepl("^Initial carbon|^Soil:", lg)]), sep = "\n")
new <- as.data.table(datasheet(R, "stsim_InitialStockSpatial", lookupsAsFactors = FALSE)); old <- as.data.table(datasheet(scenario(L, 47), "stsim_InitialStockSpatial", lookupsAsFactors = FALSE))
expect("a map for every stock type of stage 8's list, Deep Soil included", setequal(new$StockTypeId, fread(file.path(pkg, "defaults/initialstocks/stock-types.csv"))$StockTypeId) && "Deep Soil" %in% new$StockTypeId)
val <- function(fn) values(rast(fn), mat = FALSE)
# grassland, shrubland and emergent wetland cells start at the package tables' pools for their ecodivision and class (by ecodivision
# since 2026-11-06: tools/make_emergent_wetland.R, tools/make_grass_shrub.R); every other cell's pools are Build 47's, cell for cell
ic <- as.data.table(datasheet(scenario(L, 47), "stsim_InitialConditionsSpatial", lookupsAsFactors = FALSE))
key <- function(sh) { x <- as.data.table(datasheet(P1, sh, includeKey = TRUE)); setNames(x$Name, x[[intersect(c("ID", "Id"), names(x))[1]]]) }
cls <- unname(key("stsim_StateClass")[as.character(val(ic$StateClassFileName))]); eco <- unname(key("stsim_Stratum")[as.character(val(ic$StratumFileName))])
ds <- val(new[StockTypeId == "Deep Soil", RasterFileName]); land <- !is.na(ds)
expect("every land cell's ecodivision and state class are named", !anyNA(cls[land]) && !anyNA(eco[land]))
stl <- fread(file.path(pkg, "defaults/initialstocks/stock-types.csv"))
tab <- rbind(fread(file.path(pkg, "defaults/initialstocks/grassland-shrubland.csv")), fread(file.path(pkg, "defaults/initialstocks/emergent-wetland.csv")),
             fread(file.path(pkg, "defaults/initialstocks/chaparral.csv")))   # chaparral by age since fire (AgeMin), the others by class
tab[, pool := stl$StockTypeId[match(StateAttributeTypeID, stl$Attribute)]]
nf <- land & cls %in% tab$StateClassID
age <- val(ic$AgeFileName); tab[, key := paste(StratumID, StateClassID, ifelse(is.na(AgeMin), "", AgeMin))]
amax <- max(tab$AgeMin, na.rm = TRUE); ckey <- paste(eco, cls, ifelse(cls %in% tab[!is.na(AgeMin), StateClassID], pmin(pmax(round(age), 0), amax), ""))
cat(sprintf("%d land cells: %d grassland, shrubland or emergent wetland (%s)\n", sum(land), sum(nf), paste(names(table(cls[nf])), table(cls[nf]), collapse = ", ")))
gtab <- 0; gold <- 0
for (k in new$StockTypeId) { x <- val(new[StockTypeId == k, RasterFileName])
  w <- tab[pool == k]; e <- w$Value[match(ckey, w$key)]; e[is.na(e) & nf] <- 0
  if (k == "DOM: Belowground Slow") e[nf & e == 0] <- NA   # a 0 class value takes gNATSGO (stage 8's rule); none of these classes has one
  gtab <- max(gtab, max(abs(x[nf] - e[nf]), na.rm = TRUE))
  if (k %in% old$StockTypeId) gold <- max(gold, max(abs(x[land & !nf] - val(old[StockTypeId == k, RasterFileName])[land & !nf]), na.rm = TRUE)) }
expect(sprintf("grass, shrub and emergent cells start at their ecodivision x class pools, Deep Soil included (largest gap %.1e Mg C/ha)", gtab), gtab < 1e-3)
expect(sprintf("every other cell's pools are Build 47's own stage 8 maps (largest gap %.1e)", gold), gold < 1e-4)
expect("Deep Soil is 0 on every other land cell (forest has no Deep Soil curve column)", all(ds[land & !nf] == 0))
expect("Deep Soil starts at 0 on every land cell (one soil definition; it holds only wetland burial during a run; user 2026-11-07)", all(ds[land] == 0))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
