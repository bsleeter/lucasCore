# =============================================================================
# phaseZ23-harvest-age.R - to-do 34: minimum harvest ages from FIA (defaults/transitions/harvest-age.csv) in stage 6 (2026-10-30)
# =============================================================================
# On the test library lucasCore-suitability.ssim (Placer, 1 km): two Builds running stage 6 on a stage 5 result (phaseZ19) and Build 47, one with the
# package values and one with a Minimum Harvest Age row (mixed conifer clearcut 70 yr in all ecodivisions). Build 47 (old ages:
# mixed conifer clearcut 92, no selection minimum) is the before.
# Checks: stage checks pass; strata everywhere or nowhere (every pathway, deterministic too, in every ecodivision); every clearcut minimum is the lower of FIA and the study area maps (at least 1 km2 of mapped cuts); every
# selection minimum is at most clearcut - 10 and at least 5; the pathways carry the table (ponderosa selection as a Mediterranean
# Mountains stratum row, no blank-stratum row); the page row replaces mixed conifer clearcut where no ecodivision row wins; less than
# half of each harvest group's expected area is below its minimum; a 1985-2023 historical run cuts at least as much clearcut as Build 47's.
# Usage: Rscript tests/phaseZ23-harvest-age.R      (REUSE=1 reuses each run that already exists)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- suppressWarnings(ssimLibrary(f)); P1 <- rsyncrosim::project(L, 1); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
reuse <- Sys.getenv("REUSE") == "1"
latest <- function(nm) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & (Name == nm | startsWith(Name, paste0(nm, " ([")))]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
fresh <- function(nm, src) { s <- as.data.table(scenario(L, summary = TRUE)); for (id in s[IsResult == "No" & Name == nm, ScenarioId]) delete(L, scenario = id, force = TRUE); scenario(P1, nm, sourceScenario = src) }
# stage 5 alone on Build 47 (tests/phaseZ19-site-class-shares.R; LANDFIRE EVT types, NASA CMS ages): its stand age map is stage 5's own
S5 <- scenarioId(latest("Stage 5 test (site class shares)")); cat("stage 5 result", S5, "
")
NB <- c(pkg = "Build test (harvest age)", page = "Build test (harvest age, page row)")
build <- function(k) { if (reuse && !is.null(r <- latest(NB[[k]]))) return(r)
  S <- fresh(NB[[k]], 2)
  saveDatasheet(S, data.frame(StageNameId = "6 - Historical Transitions", RunOrder = 1L), "core_Pipeline")
  bo <- as.data.table(datasheet(S, "lucasCore_BuildOptions", lookupsAsFactors = FALSE, optional = TRUE)); bo <- bo[, setdiff(names(bo), c("BuildOptionsId", "ScenarioId")), with = FALSE]
  bo[, `:=`(ForestTypeMap = 1L, StandAgeSource = 1L, SiteProductivity = 1L)]; saveDatasheet(S, as.data.frame(bo), "lucasCore_BuildOptions")
  if (k == "page") saveDatasheet(S, data.frame(StateClassId = "Forest: California Mixed Conifer Group", TransitionTypeId = "Forest Harvest: Forest Clearcut", AgeMin = 70L), "lucasCore_MinimumHarvestAge")
  d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(S5, 47L, d))   # stage 5 from S5 (its age map not yet raised by any stage 6)
  t0 <- Sys.time(); r <- run(S); cat(sprintf("Build %s: %.1f min\n", k, as.numeric(Sys.time() - t0, units = "mins"))); r }
RB <- lapply(c(pkg = "pkg", page = "page"), build); B47 <- scenario(L, 47)

for (k in names(RB)) { v <- as.data.table(datasheet(RB[[k]], "lucasCore_OutputValidation")); expect(sprintf("Build %s: stage checks pass", k), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", paste(Check, Detail)], collapse = "; ")) }
cat(logs(RB$pkg, "^Minimum harvest|^Harvest minimum|^  .*cells raised|^Forest Harvest"), sep = "\n")
cat(logs(RB$page, "^Minimum Harvest Age page|^Harvest minimum age: [0-9]+ cells"), sep = "\n")
tr <- function(r) as.data.table(datasheet(r, "stsim_Transition", lookupsAsFactors = FALSE, optional = TRUE))
t1 <- tr(RB$pkg); t2 <- tr(RB$page); t0 <- tr(B47)
am <- function(t, cls, tt, eco = NA) { x <- t[StateClassIdSource == cls & TransitionTypeId == tt]; if ("StratumIdSource" %in% names(x)) x <- if (is.na(eco)) x[is.na(StratumIdSource)] else x[StratumIdSource %in% eco]; x$AgeMin }
MC <- "Forest: California Mixed Conifer Group"; PP <- "Forest: Ponderosa Pine Group"; CC <- "Forest Harvest: Forest Clearcut"; SE <- "Forest Harvest: Forest Selection"
cat(sprintf("mixed conifer clearcut: Build 47 %s; package rows %s; page rows %s\n", paste(t0[StateClassIdSource == MC & TransitionTypeId == CC, AgeMin], collapse = ","),
            paste(t1[StateClassIdSource == MC & TransitionTypeId == CC, sprintf("%s:%s", StratumIdSource, AgeMin)], collapse = " "), paste(t2[StateClassIdSource == MC & TransitionTypeId == CC, sprintf("%s:%s", StratumIdSource, AgeMin)], collapse = " ")))
oh <- as.data.table(datasheet(RB$pkg, "lucasCore_OutputHarvestAge", lookupsAsFactors = FALSE)); print(oh)
expect("every clearcut minimum is the lower of FIA and the study area maps", oh[TransitionTypeId == CC, all(AgeMin == pmin(FiaAge, ifelse(StudyAreaKm2 >= 1, StudyAreaAge, NA), na.rm = TRUE))])
ccv <- function(e, t) { k <- match(paste(e, t), oh[TransitionTypeId == CC, paste(StratumId, StateClassId)]); k0 <- match(t, oh[TransitionTypeId == CC & is.na(StratumId), StateClassId])
  ifelse(is.na(k), oh[TransitionTypeId == CC & is.na(StratumId)]$AgeMin[k0], oh[TransitionTypeId == CC]$AgeMin[k]) }
expect("every selection minimum is at most clearcut - 10 and at least 5", oh[TransitionTypeId == SE, all(AgeMin <= pmax(5, ccv(StratumId, StateClassId) - 10) & AgeMin >= 5)])
expect("the pathways carry the table: mixed conifer clearcut and selection", setequal(t1[StateClassIdSource == MC & TransitionTypeId == CC, AgeMin], oh[StateClassId == MC & TransitionTypeId == CC, AgeMin]) &&
       setequal(t1[StateClassIdSource == MC & TransitionTypeId == SE, AgeMin], oh[StateClassId == MC & TransitionTypeId == SE, AgeMin]))
expect("ponderosa selection: a Mediterranean Mountains stratum row and no blank-stratum row", length(am(t1, PP, SE, "Mediterranean Mountains")) == 1 && !length(am(t1, PP, SE)))
expect("page row: mixed conifer clearcut 70 where no ecodivision row wins, and selection there 60 or less", any(t2[StateClassIdSource == MC & TransitionTypeId == CC, AgeMin] == 70) &&
       all(am(t2, MC, SE, "Mediterranean") <= 60))
# strata everywhere or nowhere (ST-Sim takes a cell's stratum rows in place of the blank-stratum rows; P26 Build 50 mixed them and lost half its fire)
E <- unique(t1$StratumIdSource); n0 <- nrow(t0[!TransitionTypeId %in% c(CC, SE)])
expect("every pathway row has an ecodivision, and each ecodivision has every pathway", !anyNA(t1$StratumIdSource) && length(E) > 1 &&
       t1[, .N, by = StratumIdSource][, uniqueN(N) == 1 && N[1] == nrow(t0)], t1[, paste(StratumIdSource, .N, collapse = "; "), ])
expect("other pathways unchanged (each ecodivision has Build 47's rows apart from harvest)", t1[!TransitionTypeId %in% c(CC, SE), .N, by = StratumIdSource][, all(N == n0)])
dt <- as.data.table(datasheet(RB$pkg, "stsim_DeterministicTransition", lookupsAsFactors = FALSE)); d0 <- as.data.table(datasheet(B47, "stsim_DeterministicTransition", lookupsAsFactors = FALSE))
expect("deterministic transitions by ecodivision too, Build 47's rows in each", "StratumIdSource" %in% names(dt) && !anyNA(dt$StratumIdSource) && setequal(unique(dt$StratumIdSource), E) &&
       dt[, .N, by = StratumIdSource][, all(N == nrow(d0))])
blk <- function(r) as.data.table(datasheet(r, "lucasCore_OutputTransitionSummary", lookupsAsFactors = FALSE))[grepl("Harvest", TransitionGroup), .(Expected = sum(Area), Blocked = sum(AgeBlockedArea, na.rm = TRUE)), by = TransitionGroup]
b1 <- blk(RB$pkg); print(b1)
expect("expected area below the minimum is under half of each harvest group", b1[, all(Blocked < 0.5 * Expected)], b1[, paste(sprintf("%s %.0f%%", sub(" [Type]", "", sub("^.*: ", "", TransitionGroup), fixed = TRUE), 100 * Blocked / Expected), collapse = "; ")])
age <- function(r) { ic <- as.data.table(datasheet(r, "stsim_InitialConditionsSpatial", optional = TRUE)); values(rast(file.path(paste0(f, ".data"), sprintf("Scenario-%d", scenarioId(r)), "stsim_InitialConditionsSpatial", basename(ic$AgeFileName[1]))), mat = FALSE) }
a1 <- age(RB$pkg); a0 <- age(B47)
cat(sprintf("start ages: %d cells differ from Build 47's; mean forest age %.1f (Build 47 %.1f)\n", sum(a1 != a0, na.rm = TRUE), mean(a1, na.rm = TRUE), mean(a0, na.rm = TRUE)))
# the realized harvest of a 1985-2023 historical run on the package Build, against Build 47's (result 49) and the LCMS area
NH <- "Historical test (harvest age)"
RH <- if (reuse && !is.null(r <- latest(NH))) r else { H <- fresh(NH, 48); d <- as.integer(dependency(H)$ScenarioId); dependency(H) <- unique(c(scenarioId(RB$pkg), 47L, d))
  t0 <- Sys.time(); r <- run(H); cat(sprintf("historical: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))); r }
real <- function(r) as.data.table(datasheet(r, "stsim_OutputStratumTransition", lookupsAsFactors = FALSE))[grepl("[Type]", TransitionGroupId, fixed = TRUE) & grepl("Harvest", TransitionGroupId), .(km2 = sum(Amount) / 100), by = TransitionGroupId]
h <- merge(merge(real(scenario(L, 49)), real(RH), by = "TransitionGroupId", suffixes = c(".B47", ".new")), b1[, .(TransitionGroupId = TransitionGroup, LCMS = Expected)], by = "TransitionGroupId"); print(h)
expect("historical run: clearcut realized at least as much as with Build 47's ages", h[grepl("Clearcut", TransitionGroupId), km2.new >= 0.95 * km2.B47])
oth <- function(r) as.data.table(datasheet(r, "stsim_OutputStratumTransition", lookupsAsFactors = FALSE))[grepl("[Type]", TransitionGroupId, fixed = TRUE) & grepl("^(Fire|Urbanization)", TransitionGroupId), .(km2 = sum(Amount) / 100), by = .(K = sub(":.*", "", TransitionGroupId))]
o <- merge(oth(scenario(L, 49)), oth(RH), by = "K", suffixes = c(".B47", ".new")); print(o)
expect("historical run: fire and urbanization within 5% of Build 47's", o[, all(abs(km2.new / km2.B47 - 1) < 0.05)])
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
