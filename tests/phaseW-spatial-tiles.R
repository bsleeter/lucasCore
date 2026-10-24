# =============================================================================
# phaseW-spatial-tiles.R - spatial multiprocessing: tiles of whole units of a chosen Build Options strata level
# =============================================================================
# On the phaseO library: a quick Projection Setup (Build 47, hand-over from historical run 49, --method=None) with 2 spatial tiles of
# Tertiary units, then a 3-year ST-Sim-only projection with library multiprocessing on (multi-scenario off). Checks: stage 9 sets
# every Target group's strata to Tertiary and writes the tile mask of whole tertiary units; the projection runs on the tiles.
# Usage: Rscript tests/phaseW-spatial-tiles.R [--level=Tertiary] [--tiles=2]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
lvl <- opt("level", "Tertiary"); ntile <- as.integer(opt("tiles", 2))
L <- ssimLibrary(f)
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
tool <- function(script, args) { out <- system2(RS, c(file.path("F:/lucasCore/tools", script), shQuote(f), shQuote(args)), stdout = TRUE, stderr = TRUE)
  out <- out[!grepl("Warning|undetermined|^In ssimLibrary|row names|short variable", out)]; id <- as.integer(tail(out, 1)); if (is.na(id)) { cat(out, sep = "\n"); stop(script, " failed") }; id }
sid <- tool("new-projection-setup.R", c("--build=47", "--historical=49", "--method=None", "--name=Projection Setup (tiles test)", "--replace"))
saveDatasheet(scenario(L, sid), data.frame(Iterations = 1L, SpatialTiles = ntile, SpatialTilesStrata = lvl), "lucasCore_ProjectionOptions")
R1 <- run(scenario(L, sid)); lg <- trimws(strsplit(paste(runLog(R1), collapse = "\n"), "\n")[[1]])
cat(unique(lg[grepl("Spatial tiles|tile strata|Failure", lg)]), sep = "\n")
m <- ds(R1, "core_SpatialMultiprocessing"); print(m)
if (nrow(m)) { r <- rast(m$MaskFileName[1]); print(freq(r)) }
tt <- ds(R1, "stsim_TransitionTarget")[Timestep > 2023]; print(tt[, .(rows = .N, tertiary_units = uniqueN(TertiaryStratumId)), by = TransitionGroupId])
pid <- tool("new-projection.R", c(sprintf("--build=%d", scenarioId(R1)), "--years=3", "--replace", "--name=Projection (tiles test)"))
cat("projection scenario", pid, "\n")
