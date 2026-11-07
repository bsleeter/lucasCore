# =============================================================================
# phaseZ29-chaparral-age.R - stage 5 gives chaparral cells their years since fire (to-do 39, 2026-11-06)
# =============================================================================
# On the test library lucasCore-suitability.ssim (Placer County, 1 km): stage 5 alone on Build result 47. Checks: stage 5 passes its
# checks; every chaparral cell's age is the start year minus the year of the last interagency fire perimeter (1900 to the start year)
# over its centre, or start year - 1900 where none burned; forest cells keep an age of at least 1 and every other cell 0.
# Usage: Rscript tests/phaseZ29-chaparral-age.R      (REUSE=1 reuses the run when it exists)
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra); library(sf) })
f <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim"); L <- suppressWarnings(ssimLibrary(f)); P1 <- rsyncrosim::project(L, 1); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
nm <- "Stage 5 test (chaparral age)"
s <- as.data.table(scenario(L, summary = TRUE))
R <- if (Sys.getenv("REUSE") == "1" && nrow(s[IsResult == "Yes" & startsWith(Name, paste0(nm, " ([")) ])) scenario(L, max(s[IsResult == "Yes" & startsWith(Name, paste0(nm, " ([")), ScenarioId])) else {
  for (id in s[IsResult == "No" & Name == nm, ScenarioId]) delete(L, scenario = id, force = TRUE)
  S <- scenario(P1, nm, sourceScenario = 2); saveDatasheet(S, data.frame(StageNameId = "5 - Initial Conditions", RunOrder = 1L), "core_Pipeline")
  d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(47L, d))
  t0 <- Sys.time(); r <- run(S); cat(sprintf("stage 5: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))); r }
v <- as.data.table(datasheet(R, "lucasCore_OutputValidation")); expect("stage 5 checks pass", nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", paste(Check, Detail)], collapse = "; "))
lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); cat(unique(lg[grepl("^Chaparral age", lg)]), sep = "\n")
ic <- as.data.table(datasheet(R, "stsim_InitialConditionsSpatial", lookupsAsFactors = FALSE))
S <- rast(ic$StateClassFileName[1]); A <- rast(ic$AgeFileName[1])
key <- function(sh) { x <- as.data.table(datasheet(P1, sh, includeKey = TRUE)); setNames(x$Name, x[[intersect(c("ID", "Id"), names(x))[1]]]) }
cls <- unname(key("stsim_StateClass")[as.character(values(S, mat = FALSE))]); va <- values(A, mat = FALSE)
y0 <- as.integer(datasheet(R, "lucasCore_BuildOptions")$StartYear[1]); isC <- cls %in% "Shrubland: Chaparral"
expect("the study area has chaparral cells", sum(isC) > 0, sprintf("%d", sum(isC)))
# the perimeter file stage 5 read (its Data Sources Used), read as src/shared.R read_fire_perimeters does
du <- as.data.table(datasheet(R, "lucasCore_OutputDataSources", lookupsAsFactors = FALSE))
fpf <- du[DataSource == "FirePerimeterHistoryFile", Path][1]
if (!is.na(fpf) && file.exists(fpf)) {
  lay <- st_layers(fpf)$name[1]; have <- names(st_read(fpf, query = sprintf('SELECT * FROM "%s" WHERE FID = 0', lay), quiet = TRUE))
  yf <- intersect(c("FIRE_YEAR_INT", "FIRE_YEAR_"), have)[1]
  fp <- st_read(fpf, query = sprintf('SELECT * FROM "%s" WHERE %s >= 1900 AND %s <= %d AND %s <> 9999', lay, yf, yf, y0, yf), quiet = TRUE); fp$yr <- as.integer(fp[[yf]])
  fp <- st_make_valid(st_transform(fp, crs(S)))
  last <- values(rasterize(vect(fp), rast(S), field = "yr", fun = "max"), mat = FALSE)
  want <- ifelse(is.na(last), y0 - 1900, y0 - last)
  expect("every chaparral cell's age is its years since the last fire perimeter (start year - 1900 where none)", all(va[isC] == want[isC]),
         sprintf("%d of %d match; %d burned since 1900", sum(va[isC] == want[isC]), sum(isC), sum(isC & !is.na(last))))
} else expect("the Build's fire perimeter file is readable", FALSE, paste("FirePerimeterHistoryFile:", fpf))
expect("every other non-forest cell has age 0", all(va[!isC & !is.na(cls) & !(cls %in% grep("^Forest|Wetland: .*Forested", unique(cls), value = TRUE))] == 0))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
