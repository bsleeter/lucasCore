# =============================================================================
# build_starter.R - the starter library: Starter/LUCAS Core (CONUS).ssim
# =============================================================================
# SyncroSim 3 has no local templates (File > New offers Empty Library and the online templates of the central package index), so
# lucasCore ships a starter library to copy and open instead. Made by tools/new-library.R, it holds the stsim definitions, every
# Stratum Source with the universal unit lists, the LOCA2 lists of this machine's LOCA2 folder and the Stock-Flow Definitions
# scenario, plus a ready "Build" scenario: depends on Stock-Flow Definitions, pipeline stages 1, 5, 2, 3, 4, 6, 7, 8, 12. A user copies
# the file, opens it (File > Open), fills in the Build scenario's Build Options, Study Area and Climate Options, and runs it.
# Rebuild after changing defaults/ or package.xml.
# Usage: Rscript tools/build_starter.R
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
pkg <- normalizePath(file.path(here, ".."), winslash = "/"); sd <- file.path(pkg, "Starter"); dir.create(sd, showWarnings = FALSE)
f <- file.path(sd, "LUCAS Core (CONUS).ssim")
unlink(c(f, paste0(f, c(".data", ".temp", ".backup", ".input"))), recursive = TRUE)
if (system2(file.path(R.home("bin"), "Rscript.exe"), c(shQuote(file.path(pkg, "tools", "new-library.R")), shQuote(f)))) stop("new-library.R failed")

L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); sc <- as.data.table(scenario(L, summary = TRUE))
B <- rsyncrosim::scenario(P, "Build"); dependency(B) <- sc[Name %in% c("Stock-Flow Definitions", "Carbon Assumptions"), ScenarioId]
description(B) <- paste(
  "Builds a LUCAS model. Before running, set: (1) Build Options - cell size, secondary and tertiary strata (blank = States, Federal Lands),",
  "historical start and end years; (2) Study Area - one row per unit of any source (blank = all of CONUS); (3) Climate Options - climate methods.",
  "Projections are set up afterwards on this Build's result: a Projection Setup (stages 9-10, end year in Run Settings) and one Projection",
  "Climate scenario per LOCA2 run (stage 11). Depends on Stock-Flow Definitions. Pipeline: 0 Stock-Flow Definitions (writes nothing here: the",
  "dependency has them), 1 Study Area and Strata, 5 Initial Conditions, 2 Growth Curves, 3 Carbon Flows, 4 Spin-up, 6 Historical Transitions,",
  "7 Climate Multipliers, 8 Initial Stock Maps. California at 1 km takes about 50 minutes.")
stages <- c("0 - Stock-Flow Definitions", "1 - Study Area and Strata", "5 - Initial Conditions", "2 - Fit Growth Curves", "3 - Carbon Flows",
            "4 - Spin-up and Initial Stocks", "6 - Historical Transitions", "7 - Climate Multipliers", "8 - Initial Stock Maps", "12 - Build Figures")
saveDatasheet(B, data.frame(StageNameId = stages, RunOrder = seq_along(stages)), "core_Pipeline")
# the option sheets show their values: one row of package.xml's defaultValues (a blank optional column stays blank; the stages use the
# same defaults for anything left empty). Strata sources are spelled out so the drop-downs show them.
xml <- paste(readLines(file.path(pkg, "package.xml"), warn = FALSE), collapse = "\n")
defaults_of <- function(sheet) { blk <- regmatches(xml, regexpr(sprintf('(?s)<dataSheet name="%s"[^>]*(?<!/)>.*?</dataSheet>', sheet), xml, perl = TRUE))
  cols <- regmatches(blk, gregexpr('<column [^>]*>', blk))[[1]]
  att <- function(tag, a) { m <- regmatches(tag, regexpr(sprintf('%s="[^"]*"', a), tag)); if (length(m)) sub('^[^"]*"(.*)"$', "\\1", m) else NA }
  v <- lapply(cols, function(tg) { d <- att(tg, "defaultValue"); if (is.na(d)) return(NULL)
    switch(att(tg, "dataType"), Integer = as.integer(d), Double = as.numeric(d), Boolean = d != "0", d) })
  names(v) <- vapply(cols, att, "", a = "name"); as.data.frame(v[!vapply(v, is.null, TRUE)]) }
bo <- defaults_of("BuildOptions"); bo$SecondarySourceId <- "States"; bo$TertiarySourceId <- "Federal Lands"
saveDatasheet(B, bo, "lucasCore_BuildOptions")
for (sh in c("ClimateOptions", "GrowthOptions", "CarbonOptions")) saveDatasheet(B, defaults_of(sh), paste0("lucasCore_", sh))
# the land cover crosswalks, editable per scenario (stage 5 logs any row that differs from this package default)
xw <- data.table::fread(file.path(pkg, "defaults", "landcover", "land-cover-crosswalks.csv"), na.strings = "")
saveDatasheet(B, as.data.frame(xw[, .(Source, Code, Description, StateClassId, Note)]), "lucasCore_LandCoverCrosswalk")
cat("Land Cover Crosswalks:", nrow(datasheet(B, "lucasCore_LandCoverCrosswalk")), "rows\n")
# optional: growth curves fitted once (stage 2 alone, CONUS) and shared by many builds. Build keeps stage 2 in its pipeline by default
# (curves refitted per library, following FIA updates); to share instead, run this, make Build depend on its result, and remove stage 2
# from Build's pipeline - stage 3 reads the curves from the dependency.
G <- rsyncrosim::scenario(P, "Growth Curves")
description(G) <- paste("Optional. Fits the FIA growth and live-tree carbon curves for all of CONUS (stage 2, about 13 minutes). Run it once,",
  "then make Build scenarios depend on its result and remove stage 2 from their pipelines, so every build uses the same curves.",
  "Without it, Build fits the curves itself (stage 2 in its pipeline). Growth Curve Options here set the fit.")
saveDatasheet(G, data.frame(StageNameId = "2 - Fit Growth Curves", RunOrder = 1L), "core_Pipeline")
saveDatasheet(G, defaults_of("GrowthOptions"), "lucasCore_GrowthOptions")
# Projection Setup: projection rules (stage 9) and where transitions go (stage 10), run once on a Build result; projections depend on it
PS <- rsyncrosim::scenario(P, "Projection Setup")
description(PS) <- paste("Run once the Build has run: add the Build result as this scenario's dependency, and set the projection end year in Run Settings (blank = 2100).",
  "Stage 9 sets the projection transitions (Projection Options, Projection Transitions); stage 10 makes the surfaces that place them",
  "(Projection Allocation: fitted regression or WUI/PAD rules; Suitability Options, Fitting Region, Covariates; Rule Weights). Projections",
  "(tools/new-projection.R, or a scenario with this result as its first dependency) use its result. Change a covariate and rerun this alone.")
saveDatasheet(PS, data.frame(StageNameId = c("9 - Projection Transitions", "10 - Transition Suitability"), RunOrder = 1:2), "core_Pipeline")
# Projection Climate: one per LOCA2 run (stage 11), on the Build result; projections depend on its result after the Projection Setup
PC <- rsyncrosim::scenario(P, "Projection Climate")
description(PC) <- paste("Run once the Build has run: add the Build result as this scenario's dependency and choose the LOCA2 scenario, climate model",
  "and replicate on the Projection > Climate page. Stage 11 writes the climate flow multipliers of the projection years (the Build's historical",
  "end + 1 to 2100) with the Build's Climate Options effects. Copy it for each climate future; projections depend on its result after the Projection Setup.")
saveDatasheet(PC, data.frame(StageNameId = "11 - Projection Climate", RunOrder = 1L), "core_Pipeline")
# the Projection pages open filled in with the package defaults (the same CSVs the stages use for an empty sheet; Reset to defaults on
# the pages reloads them). A list column takes its full label ("Target" -> "Target (area by strata)"). Build gets the Transitions feed
# too (stage 9 runs there for a continuous run); the Setup's own copy wins for the Setup, since a dependency supplies whole feeds.
list_label <- function(sheet, col, v) { blk <- regmatches(xml, regexpr(sprintf('(?s)<dataSheet name="%s"[^>]*(?<!/)>.*?</dataSheet>', sheet), xml, perl = TRUE))
  tg <- regmatches(blk, regexpr(sprintf('<column name="%s"[^>]*>', col), blk)); f1 <- sub('.*formula1="([^"]*)".*', "\\1", tg)
  labs <- sub("^[0-9]+:", "", strsplit(f1, "|", fixed = TRUE)[[1]])
  out <- vapply(v, function(x) { if (is.na(x) || !nzchar(x)) return(NA_character_); m <- labs[labs == x | startsWith(labs, paste0(x, " "))]
    if (!length(m)) stop(sprintf("%s.%s: '%s' is not a list value", sheet, col, x)); m[1] }, ""); unname(out) }
csv <- function(...) data.table::fread(file.path(pkg, "defaults", "projection", ...), na.strings = "", colClasses = "character")
tr <- csv("transitions.csv"); al <- csv("allocation.csv"); rw <- csv("rule-weights.csv")
tr_df <- data.frame(TransitionGroupId = tr$TransitionGroupId, Method = list_label("ProjectionTransition", "Method", tr$Method),
                    StrataLevel = list_label("ProjectionTransition", "StrataLevel", tr$StrataLevel), UnitSourceId = tr$UnitSource,
                    SamplingSet = tr$SamplingSet, ExcludeGap = tr$ExcludeGap)
al_df <- data.frame(TransitionGroupId = al$TransitionGroupId, Method = list_label("ProjectionAllocation", "Method", al$Method), Surface = al$Surface,
                    SourceClasses = al$SourceClasses, EventClasses = al$EventClasses, Adjacency = toupper(al$Adjacency) == "YES",
                    SizeDistribution = list_label("ProjectionAllocation", "SizeDistribution", al$SizeDistribution))
for (S in list(B, PS)) { saveDatasheet(S, tr_df, "lucasCore_ProjectionTransition"); saveDatasheet(S, al_df, "lucasCore_ProjectionAllocation") }
saveDatasheet(B, defaults_of("ProjectionOptions"), "lucasCore_ProjectionOptions")
saveDatasheet(PS, defaults_of("SuitabilityOptions"), "lucasCore_SuitabilityOptions")
cvd <- csv("covariates.csv")
saveDatasheet(PS, data.frame(Surface = cvd$Surface, Covariate = list_label("SuitabilityCovariate", "Covariate", cvd$Covariate), Include = toupper(cvd$Include) == "YES"), "lucasCore_SuitabilityCovariate")
saveDatasheet(PS, data.frame(Surface = rw$Surface, Layer = list_label("RuleWeight", "Layer", rw$Layer), Class = rw$Class, Weight = as.numeric(rw$Weight)), "lucasCore_RuleWeight")
cat(sprintf("Projection defaults: %d transitions, %d allocation rows, %d covariates, %d rule weights\n",
            nrow(datasheet(PS, "lucasCore_ProjectionTransition")), nrow(datasheet(PS, "lucasCore_ProjectionAllocation")),
            nrow(datasheet(PS, "lucasCore_SuitabilityCovariate")), nrow(datasheet(PS, "lucasCore_RuleWeight"))))
for (sh in c("BuildOptions", "ClimateOptions", "GrowthOptions", "CarbonOptions")) { cat(sh, ": "); x <- datasheet(B, paste0("lucasCore_", sh), lookupsAsFactors = FALSE)
  cat(paste(names(x), unlist(lapply(x[1, ], as.character)), sep = " = ", collapse = "; "), "\n") }
unlink(paste0(f, c(".temp", ".backup")), recursive = TRUE)
cat("starter:", f, "\n"); print(as.data.table(scenario(L, summary = TRUE))[, .(ScenarioId, Name, IsResult)])
print(datasheet(B, "core_Pipeline"))
