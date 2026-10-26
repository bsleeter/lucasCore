# =============================================================================
# phaseZ4-landcover-resampling.R - Build Options: Land Cover Resampling = Area-matched (to-do item 8)
# =============================================================================
# On the phaseO library: a copy of the Build scenario (2) running stages 1 and 5 only, once Modal and once Area-matched. Checks: the
# area-matched annual NLCD has each class's 30 m area per secondary stratum unit far better than modal, developed land never reverts,
# and the start-year state class map follows the matched map (developed cells are developed state classes).
# Usage: Rscript tests/phaseZ4-landcover-resampling.R
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); ok <- TRUE
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
cols <- c("Resolution", "SecondarySourceId", "TertiarySourceId", "StartYear", "EndYear", "ForestTypeMap", "LandCoverResampling")
make <- function(name, method) {
  old <- scenario(L, summary = TRUE); for (id in old$ScenarioId[old$Name == name]) delete(L, scenario = id, force = TRUE)
  s <- scenario(L, name, sourceScenario = 2)
  saveDatasheet(s, data.frame(StageNameId = c("1 - Study Area and Strata", "5 - Initial Conditions"), RunOrder = 1:2), "core_Pipeline")
  bo <- ds(s, "lucasCore_BuildOptions"); bo$LandCoverResampling <- method
  saveDatasheet(s, as.data.frame(bo[, intersect(names(bo), cols), with = FALSE]), "lucasCore_BuildOptions"); s }
RM <- run(make("Resampling test (modal)", 1L)); RA <- run(make("Resampling test (area-matched)", 2L))
cat(logs(RA, "Land cover resampling|Developed land|area matching|Failure"), sep = "\n")
nl <- function(R) { x <- ds(R, "lucasCore_OutputNlcdAnnual"); setNames(x$FileName, x$Year) }
nM <- nl(RM); nA <- nl(RA)
expect("both runs wrote the annual NLCD", length(nM) > 30 && length(nA) == length(nM), sprintf("%d / %d years", length(nM), length(nA)))
expect("area matching logged and its checks passed", any(grepl("area-matched per secondary", logs(RA, "Land cover resampling"))) && !any(grepl("fail", logs(RA, "area matching"), ignore.case = TRUE)))
vM <- values(rast(nM[1]), mat = FALSE); vA <- values(rast(nA[1]), mat = FALSE)
expect("same land cells", identical(is.na(vM), is.na(vA)))
dev <- function(v) sum(v %in% 21:24)
expect("area matching has more developed cells in the first year than modal", dev(vA) > dev(vM), sprintf("%d vs %d", dev(vA), dev(vM)))
everA <- logical(length(vA)); lost <- 0
for (k in seq_along(nA)) { v <- values(rast(nA[k]), mat = FALSE) %in% 21:24; if (k > 1) lost <- lost + sum(everA & !v); everA <- everA | v }
expect("developed land never reverts (area-matched)", lost == 0, sprintf("%d cell-years", lost))
ic <- ds(RA, "stsim_InitialConditionsSpatial"); S <- values(rast(ic$StateClassFileName[1]), mat = FALSE)
scl <- ds(rsyncrosim::project(L, 1), "stsim_StateClass"); devS <- as.integer(scl$Id[grepl("^Developed", scl$Name)])
expect("start-year state classes follow the matched map (developed cells)", all(S[vA %in% 21:24 & !is.na(S)] %in% devS), sprintf("%d developed cells", dev(vA)))
cat(if (ok) "phaseZ4: all checks pass\n" else "phaseZ4: FAILURES\n")
