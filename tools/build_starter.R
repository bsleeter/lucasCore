# =============================================================================
# build_starter.R - the starter library: Starter/LUCAS Core (CONUS).ssim
# =============================================================================
# SyncroSim 3 has no local templates (File > New offers Empty Library and the online templates of the central package index), so
# lucasCore ships a starter library to copy and open instead. Made by tools/new-library.R, it holds the stsim definitions, every
# Stratum Source with the universal unit lists, the LOCA2 lists of this machine's LOCA2 folder and the Stock-Flow Definitions
# scenario, plus a ready "Build" scenario: depends on Stock-Flow Definitions, pipeline stages 1, 5, 2, 3, 4, 6, 7, 8. A user copies
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
B <- rsyncrosim::scenario(P, "Build"); dependency(B) <- sc[Name == "Stock-Flow Definitions", ScenarioId]
description(B) <- paste(
  "Builds a LUCAS model. Before running, set: (1) Build Options - cell size, secondary and tertiary strata (blank = States, Federal Lands),",
  "historical start and end years, projection end year (blank = no projection); (2) Study Area - one row per unit of any source (blank = all",
  "of CONUS); (3) Climate Options - climate methods, and the projection scenario, climate model and replicate when projecting.",
  "Depends on Stock-Flow Definitions. Pipeline: 1 Study Area and Strata, 5 Initial Conditions, 2 Growth Curves, 3 Carbon Flows,",
  "4 Spin-up, 6 Historical Transitions, 7 Climate Multipliers, 8 Initial Stock Maps. California at 1 km takes about 50 minutes.")
stages <- c("1 - Study Area and Strata", "5 - Initial Conditions", "2 - Fit Growth Curves", "3 - Carbon Flows", "4 - Spin-up and Initial Stocks",
            "6 - Historical Transitions", "7 - Climate Multipliers", "8 - Initial Stock Maps")
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
for (sh in c("BuildOptions", "ClimateOptions", "GrowthOptions", "CarbonOptions")) { cat(sh, ": "); x <- datasheet(B, paste0("lucasCore_", sh), lookupsAsFactors = FALSE)
  cat(paste(names(x), unlist(lapply(x[1, ], as.character)), sep = " = ", collapse = "; "), "\n") }
unlink(paste0(f, c(".temp", ".backup")), recursive = TRUE)
cat("starter:", f, "\n"); print(as.data.table(scenario(L, summary = TRUE))[, .(ScenarioId, Name, IsResult)])
print(datasheet(B, "core_Pipeline"))
