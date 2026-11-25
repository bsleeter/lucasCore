# =============================================================================
# new-projection-climate.R - add a Projection Climate scenario (stage 11) on top of a Build result
# =============================================================================
# One per climate future: stage 11 writes the climate flow multipliers of the projection years from one LOCA2 run (scenario, climate
# model, replicate), using the Build's Climate Options effects. Projections depend on its result after the Projection Setup (tools/new-projection.R
# --climate=<this result>), so one Build and one Projection Setup serve any number of climate futures (user decision 2026-10-24).
# In Studio the same scenario is: New Scenario, Dependencies = the Build result, Pipeline = 11 - Projection Climate, and the
# Projection > Climate page filled in.
# Usage: Rscript tools/new-projection-climate.R <library.ssim> --scenario="SSP2-4.5" --model=ACCESS-CM2 [--build=<Build result id>]
#                                               [--replicate=r1i1p1f1] [--last=2100] [--name="..."] [--replace]
#                                               [--setup=<Projection Setup result id> [--timing=0.3] [--amount=50]]
#   --setup   a Projection Setup result whose Mortality page hands the timing and amount of drought and insect mortality to the
#             Projection Climate result (lucasCore 2.0.3): this scenario then also depends on it, below the Build, and writes the drawn
#             years for projections from that setup. --timing (0 to 1) and --amount (percent) are the two settings of its Mortality
#             and Climate page; without them the setup's blocks stay as drawn
# Prints the new scenario id on the last line.
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tools/new-projection-climate.R <library.ssim> --scenario=<SSP> --model=<GCM> [--build=<id>]")
L <- ssimLibrary(normalizePath(pos[1], winslash = "/")); P <- rsyncrosim::project(L, "Definitions")
sc <- as.data.table(scenario(L, summary = TRUE))
bid <- as.integer(opt("build", NA))
if (is.na(bid)) { b <- sc[IsResult == "Yes" & grepl("Build", Name, fixed = TRUE)]; if (!nrow(b)) stop("no Build result in the library"); bid <- max(b$ScenarioId) }
if (!bid %in% sc[IsResult == "Yes", ScenarioId]) stop(sprintf("scenario %d is not a result scenario", bid))
ssp <- opt("scenario", NA); gcm <- opt("model", NA); rep <- opt("replicate", NA); last <- as.integer(opt("last", NA))
if (is.na(ssp) || is.na(gcm)) stop("--scenario and --model are required (the names in the project's Climate Scenarios and Climate Models lists)")
lst <- function(s) as.data.table(datasheet(P, s, lookupsAsFactors = FALSE))$Name
if (!ssp %in% lst("lucasCore_ClimateScenario")) stop(sprintf("scenario '%s' is not in Climate Scenarios: %s", ssp, paste(lst("lucasCore_ClimateScenario"), collapse = ", ")))
if (!gcm %in% lst("lucasCore_ClimateModel")) stop(sprintf("model '%s' is not in Climate Models: %s", gcm, paste(lst("lucasCore_ClimateModel"), collapse = ", ")))
if (!is.na(rep) && !rep %in% lst("lucasCore_ClimateReplicate")) stop(sprintf("replicate '%s' is not in Climate Replicates", rep))
nm <- opt("name", sprintf("Climate %s %s%s", ssp, gcm, if (is.na(rep)) "" else paste0(" ", rep)))
if (nrow(sc[Name == nm & IsResult == "No"])) { if (!"--replace" %in% a) stop(sprintf("scenario '%s' exists (use --replace)", nm))
  for (i in sc[Name == nm & IsResult == "No", ScenarioId]) delete(L, scenario = i, force = TRUE) }
sid <- as.integer(opt("setup", NA)); if (!is.na(sid) && !sid %in% sc[IsResult == "Yes", ScenarioId]) stop("--setup must be a result scenario id (a Projection Setup result)")
S <- rsyncrosim::scenario(P, nm); dependency(S) <- c(bid, if (!is.na(sid)) sid)
stages <- levels(datasheet(S, "core_Pipeline", lookupsAsFactors = TRUE, optional = TRUE)$StageNameId)
if (!"11 - Projection Climate" %in% stages) stop("this library has no stage 11 (made before it existed): update the package and reopen the library")
saveDatasheet(S, data.frame(StageNameId = "11 - Projection Climate", RunOrder = 1L), "core_Pipeline")
pc <- data.frame(ClimateScenarioId = ssp, ClimateModelId = gcm, ClimateReplicateId = if (is.na(rep)) NA_character_ else rep, EndYear = last)
pc <- pc[, vapply(pc, function(v) !all(is.na(v)), TRUE), drop = FALSE]
saveDatasheet(S, pc, "lucasCore_ProjectionClimate")
mt <- suppressWarnings(as.numeric(opt("timing", NA))); ma <- suppressWarnings(as.numeric(opt("amount", NA)))
if (!is.na(mt) || !is.na(ma)) { if (is.na(sid)) stop("--timing and --amount need --setup=<Projection Setup result id>")
  mc <- data.frame(TimingStrength = mt, AmountPercent = ma); saveDatasheet(S, mc[, vapply(mc, function(v) !all(is.na(v)), TRUE), drop = FALSE], "lucasCore_MortalityClimate") }
description(S) <- sprintf(paste0("Projection climate: LOCA2 %s, %s, replicate %s, the Build's historical end + 1 to %s. Depends on the Build result '%s' (%d): its strata ",
  "grid, historical end year and Climate Options effects. Pipeline: stage 11 alone. Projections depend on this result after the Projection Setup (tools/new-projection.R --climate). ",
  "Made by tools/new-projection-climate.R."), ssp, gcm, if (is.na(rep)) "lowest-numbered with the scenario" else rep, if (is.na(last)) "2100" else last,
  sc[ScenarioId == bid, Name], bid)
cat(sprintf("scenario '%s' created: depends on Build result %d%s; stage 11\n", nm, bid, if (is.na(sid)) "" else sprintf(" and Projection Setup result %d (mortality timing %s, increase in dry periods %s%%)", sid, if (is.na(mt)) "0" else mt, if (is.na(ma)) "0" else ma)))
cat(scenarioId(S), "\n")
