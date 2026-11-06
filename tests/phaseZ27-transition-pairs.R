# =============================================================================
# phaseZ27-transition-pairs.R - stage 6's land-use maps follow the class pairs of the pathways; 30 m disturbances on cells with no pathway are
# placed nearby; Ag Change is modelled over the historical period (2026-11-05)
# =============================================================================
# On the test library lucasCore-suitability.ssim (Placer, 1 km; tools/sync-library.R first, for the Ag Change types): stage 6 on the stage 5 result
# of tests/phaseZ19, then a 1985-2023 historical run. Build 47 is the before.
# Usage: Rscript tests/phaseZ27-transition-pairs.R      (REUSE=1 reuses each run that already exists)
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
f <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim"); L <- suppressWarnings(ssimLibrary(f)); P1 <- rsyncrosim::project(L, 1); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
reuse <- Sys.getenv("REUSE") == "1"
latest <- function(nm) { s <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & (Name == nm | startsWith(Name, paste0(nm, " ([")))]; if (nrow(s)) scenario(L, max(s$ScenarioId)) else NULL }
fresh <- function(nm, src) { s <- as.data.table(scenario(L, summary = TRUE)); for (id in s[IsResult == "No" & Name == nm, ScenarioId]) delete(L, scenario = id, force = TRUE); scenario(P1, nm, sourceScenario = src) }
S5 <- scenarioId(latest("Stage 5 test (site class shares)")); cat("stage 5 result", S5, "\n")
NB <- "Build test (transition pairs)"
RB <- if (reuse && !is.null(r <- latest(NB))) r else { S <- fresh(NB, 2)
  saveDatasheet(S, data.frame(StageNameId = "6 - Historical Transitions", RunOrder = 1L), "core_Pipeline")
  bo <- as.data.table(datasheet(S, "lucasCore_BuildOptions", lookupsAsFactors = FALSE, optional = TRUE)); bo <- bo[, setdiff(names(bo), c("BuildOptionsId", "ScenarioId")), with = FALSE]
  bo[, `:=`(ForestTypeMap = 1L, StandAgeSource = 1L, SiteProductivity = 1L)]; saveDatasheet(S, as.data.frame(bo), "lucasCore_BuildOptions")
  d <- as.integer(dependency(S)$ScenarioId); dependency(S) <- unique(c(S5, 47L, d))
  t0 <- Sys.time(); r <- run(S); cat(sprintf("stage 6: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))); r }
v <- as.data.table(datasheet(RB, "lucasCore_OutputValidation")); expect("stage checks pass", nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", paste(Check, Detail)], collapse = "; "))
cat(v[grepl("class pair|two land-use|no pathway|between 0 and 1", Check), sprintf("  %s: %s %s", Check, Status, Detail)], sep = "\n")
cat(logs(RB, "^Land-use change|on cells with no pathway|^Placed within|km2 over"), sep = "\n")

# the maps against a direct count of the class pairs on the annual NLCD
source(file.path(pkg, "src/transition-pairs.R"))
nl <- as.data.table(datasheet(RB, "lucasCore_OutputNlcdAnnual", lookupsAsFactors = FALSE)); setorder(nl, Year)
N <- lapply(nl$FileName, function(p) as.integer(values(rast(p), mat = FALSE))); names(N) <- nl$Year; cell_km2 <- prod(res(rast(nl$FileName[1]))) / 1e6
fam <- function(a, b) { d <- 21:24; ag <- c(81L, 82L); nat <- LU_NATURAL
  fcase(a %in% ag & b %in% nat, "Ag Contraction", a %in% nat & b %in% ag, "Ag Expansion", a %in% ag & b %in% ag & a != b, "Ag Change", a %in% c(nat, ag) & b %in% d, "Urbanization", a %in% d & b %in% d & b > a, "Intensification", default = "none") }
# counted from the class the model holds: a change with no pathway does not move it, natural to natural does
hd <- N[[1]]; cl <- list()
for (i in 2:length(N)) { b <- N[[i]]; g <- fam(hd, b); cl[[i]] <- data.table(g = g)[g != "none", .N, by = g]
  mv <- g != "none" | (hd %in% LU_NATURAL & b %in% LU_NATURAL); mv[is.na(mv)] <- FALSE; hd[mv] <- b[mv] }
cnt <- rbindlist(cl)[, .(direct = sum(N) * cell_km2), by = g]
ts <- as.data.table(datasheet(RB, "lucasCore_OutputTransitionSummary", lookupsAsFactors = FALSE)); ts[, g := sub(":.*", "", TransitionGroup)]
mp <- ts[, .(mapped = sum(Area), noPath = sum(IneligibleArea, na.rm = TRUE)), by = g]; x <- merge(mp, cnt, by = "g", all = TRUE); print(x, digits = 6)
expect("each land-use family's map area equals its class pair count", x[!is.na(direct), all(abs(mapped - direct) < 1e-6)])
sm <- as.data.table(datasheet(RB, "stsim_TransitionSpatialMultiplier", lookupsAsFactors = FALSE))
expect("Ag Change has maps", any(grepl("^Ag Change: ", sm$TransitionGroupId)) || !x[g == "Ag Change", direct > 0])
expect("the transition lists hold Ag Change", all(c("Ag Change: Cropland to Pasture", "Ag Change: Pasture to Cropland") %in% datasheet(P1, "stsim_TransitionType")$Name))

# the historical run: realized area by family, against the maps
NH <- "Historical test (transition pairs)"
RH <- if (reuse && !is.null(r <- latest(NH))) r else { H <- fresh(NH, 48); d <- as.integer(dependency(H)$ScenarioId); dependency(H) <- unique(c(scenarioId(RB), 47L, d))
  t0 <- Sys.time(); r <- run(H); cat(sprintf("historical: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins"))); r }
real <- function(r) { o <- as.data.table(datasheet(r, "stsim_OutputStratumTransition", lookupsAsFactors = FALSE)); o[grepl("[Type]", TransitionGroupId, fixed = TRUE) | grepl("^Ag Contraction: ", TransitionGroupId), .(km2 = sum(Amount) / 100), by = .(g = sub(":.*", "", TransitionGroupId))] }
b <- merge(mp, real(RH), by = "g", all = TRUE); b[, pct := round(100 * km2 / mapped, 1)]; print(b, digits = 6)
expect("Ag Contraction realized within 25% of its map, no longer far over", b[g == "Ag Contraction", is.na(mapped) || mapped < 1 || abs(km2 / mapped - 1) < 0.25])
# against the run on the old maps (tests/phaseZ23, result 470): urbanization realized 86% of its map there too, so the guard is no loss of realized area
o <- real(scenario(L, 470L)); w <- merge(b[, .(g, km2)], o, by = "g", suffixes = c("", ".old")); print(w)
expect("urbanization and fire realized at least 95% of the old maps' run", w[g %in% c("Urbanization", "Fire"), all(km2 >= 0.95 * km2.old)])
expect("intensification realized at least 95% of the old maps' run", w[g == "Intensification", km2 >= 0.95 * km2.old], w[g == "Intensification", sprintf("%.0f vs %.0f km2", km2, km2.old)])
cat(if (ok) "TRANSITION PAIRS OK\n" else "TRANSITION PAIRS FAILED\n"); if (!ok) quit(status = 1)
