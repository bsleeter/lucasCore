# =============================================================================
# export-project-defaults.R - write a library's Stratum Sources, strata unit lists and LOCA2 lists to defaults/library/project
# =============================================================================
# A library made in Studio (File > New > Empty Library, then add lucasCore) is filled from defaults/ by ui/LibrarySetup.cs, which
# cannot run R: the unit lists (6,221 units read from the polygon sources) and the LOCA2 lists (a scan of the LOCA2 folder) are built
# by tools/new-library.R and shipped here as tables. Rerun after new-library.R --rebuild-strata or --rebuild-climate, from the starter.
# Usage: Rscript tools/export-project-defaults.R ["Starter/LUCAS Core (CONUS).ssim"]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE)
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
pkgdir <- normalizePath(file.path(here, ".."), winslash = "/")
f <- if (length(a)) a[1] else file.path(pkgdir, "Starter", "LUCAS Core (CONUS).ssim")
P <- rsyncrosim::project(ssimLibrary(normalizePath(f, winslash = "/")), "Definitions")
out <- file.path(pkgdir, "defaults", "library", "project"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
sheets <- c("lucasCore_StratumSource", "stsim_SecondaryStratum", "stsim_TertiaryStratum", "lucasCore_ClimateScenario",
            "lucasCore_ClimateModel", "lucasCore_ClimateReplicate")
for (s in sheets) {
  x <- as.data.table(datasheet(P, s, lookupsAsFactors = FALSE)); if (!nrow(x)) stop(s, " is empty in ", f)
  fwrite(x, file.path(out, paste0(s, ".csv")), na = "")
  cat(sprintf("%-28s %5d rows\n", s, nrow(x))) }
fwrite(data.table(Order = seq_along(sheets), Datasheet = sheets, Scope = "Project"), file.path(out, "manifest.csv"))
cat("wrote", out, "\n")
