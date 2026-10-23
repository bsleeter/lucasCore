# =============================================================================
# new-projection-setup.R - add a Projection Setup scenario (stages 9 and 10) on top of a Build result
# =============================================================================
# The Projection Setup runs once: stage 9 makes the projection transitions and stage 10 the surfaces that place them. Projections
# (tools/new-projection.R --build=<this result>) depend on its result, so a covariate can be changed and this rerun alone.
# Usage: Rscript tools/new-projection-setup.R <library.ssim> [--build=<Build result id>] [--region="Pyrome: P26 Northern Sierra Nevada,..."]
#                                             [--resolution=30] [--method=Fitted|Rules] [--name="Projection Setup"] [--replace]
#   --region      Suitability Fitting Region units (any Stratum Source; blank = the study area)
#   --resolution  fitting resolution in m (30 = native NLCD)
#   --method      every allocated group in defaults/projection/allocation.csv uses this method (default: the file's)
# Prints the new scenario id on the last line.
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tools/new-projection-setup.R <library.ssim> [--build=<id>] [--region=...]")
L <- ssimLibrary(normalizePath(pos[1], winslash = "/")); P <- rsyncrosim::project(L, "Definitions")
sc <- as.data.table(scenario(L, summary = TRUE))
bid <- as.integer(opt("build", NA))
if (is.na(bid)) { b <- sc[IsResult == "Yes" & grepl("^Build", Name)]; if (!nrow(b)) stop("no Build result in the library"); bid <- max(b$ScenarioId) }
B <- scenario(L, bid)
if (is.na(suppressWarnings(as.data.table(datasheet(B, "lucasCore_BuildOptions")))$ProjectionEndYear[1])) stop(sprintf("Build result %d has no projection (tick Run a projection in Build Options)", bid))
nm <- opt("name", "Projection Setup")
if (nrow(sc[Name == nm & IsResult == "No"])) { if (!"--replace" %in% a) stop(sprintf("scenario '%s' exists (use --replace)", nm))
  for (i in sc[Name == nm & IsResult == "No", ScenarioId]) delete(L, scenario = i, force = TRUE) }
S <- rsyncrosim::scenario(P, nm); dependency(S) <- bid
stages <- levels(datasheet(S, "core_Pipeline", lookupsAsFactors = TRUE, optional = TRUE)$StageNameId)
if (!"10 - Transition Suitability" %in% stages) stop("this library has no stage 10 (made before it existed): make the library from a current starter")
saveDatasheet(S, data.frame(StageNameId = c("9 - Projection Transitions", "10 - Transition Suitability"), RunOrder = 1:2), "core_Pipeline")
reg <- trimws(strsplit(opt("region", ""), ",")[[1]]); reg <- reg[nzchar(reg)]
if (length(reg)) saveDatasheet(S, data.frame(UnitId = reg), "lucasCore_SuitabilityRegion")
saveDatasheet(S, data.frame(FitResolution = as.integer(opt("resolution", 30))), "lucasCore_SuitabilityOptions")
me <- opt("method", NA)
if (!is.na(me)) { al <- fread(file.path(dirname(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))))), "defaults", "projection", "allocation.csv"))
  lab <- c(Fitted = "Fitted (regression on the historical record)", Rules = "Rules (WUI and PAD weights)", None = "None (random within its strata)")[me]
  saveDatasheet(S, data.frame(TransitionGroupId = al$TransitionGroupId, Method = lab, Surface = al$Surface, EventClasses = al$EventClasses, Adjacency = toupper(al$Adjacency) == "YES"), "lucasCore_ProjectionAllocation")
  # Projection Allocation shares a feed (Transitions) with Projection Transitions, and a dependency supplies whole feeds: keep the
  # build's transitions rows (empty = the stage 9 defaults either way)
  pt <- suppressWarnings(as.data.frame(datasheet(B, "lucasCore_ProjectionTransition", lookupsAsFactors = TRUE)))
  pt <- pt[, setdiff(names(pt), c("ProjectionTransitionId", "ScenarioId")), drop = FALSE]
  if (nrow(pt)) { for (k in names(pt)) if (is.factor(pt[[k]])) pt[[k]] <- as.character(pt[[k]]); saveDatasheet(S, pt, "lucasCore_ProjectionTransition") } }
description(S) <- sprintf(paste0("Projection Setup on Build result %d (made by tools/new-projection-setup.R): stage 9 projection transitions and stage 10 surfaces. ",
  "Fitting region: %s; fitting resolution %s m; allocation: %s. Projections: tools/new-projection.R --build=<this result>."),
  bid, if (length(reg)) paste(reg, collapse = ", ") else "the study area", opt("resolution", 30), if (is.na(me)) "defaults/projection/allocation.csv" else paste(me, "for every allocated group"))
cat(sprintf("scenario '%s' on Build result %d; region %s; %s m; method %s\n", nm, bid, if (length(reg)) paste(reg, collapse = ", ") else "study area", opt("resolution", 30), if (is.na(me)) "defaults" else me))
cat(scenarioId(S), "\n")
