# =============================================================================
# phaseZ26-strata-home.R - stage 1 with the Stratum Sources polygons from Data Sources Home, against the old local files (2026-11-02)
# =============================================================================
# Needs a library whose Data Sources Home holds the strata datasets (a Data Download with StatesFile, CountiesFile, WatershedsFile, EcoregionsFile, PyromesFile, PadusFile) and the
# study area's NLCD, e.g. dev/libs/strata-home-test.ssim on the P26 home. For each secondary / tertiary pair, stage 1 runs twice
# on the study area: (home) the presets' Files blank, so the polygons come from the home; (local) the Files set to the copies on
# the build machine (D:/example/Data Sources). The strata rasters are compared cell for cell (unit ids less their offset), and
# Data Sources Used must name each strata dataset from the home in the first run.
# Usage: Rscript tests/phaseZ26-strata-home.R <library.ssim> [--units="Pyrome: P26 Northern Sierra Nevada"] [--res=150]
# =============================================================================
DS <- Sys.getenv("LUCAS_DATA_HOME", file.path(pkg, "dev/libs/Data Sources"))
suppressPackageStartupMessages({ library(rsyncrosim); library(terra); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tests/phaseZ26-strata-home.R <library.ssim> [--units=...] [--res=150]")
UNITS <- opt("units", "Pyrome: P26 Northern Sierra Nevada"); RES <- as.integer(opt("res", 150)); OFF <- 1e8
OLD <- DS
LOCAL <- c(States = "Study Areas/States/tl_2009_us_state_conus.shp", Counties = "Study Areas/Counties/tl_rd22_us_county.shp", HUC6 = "NHD/WBD_National_GDB.gdb",
           HUC8 = "NHD/WBD_National_GDB.gdb", `EPA Level III Ecoregions` = "Ecoregions/us_eco_l4_no_st.shp", Pyromes = "Pyromes/Data/Pyromes_CONUS_20200206.shp",
           `Federal Lands` = "PADUS/Federal Lands/fedlanp010g.shp", `GAP Status` = "PADUS/padus_gapstatus.shp")
PAIRS <- list(c("States", "Federal Lands"), c("HUC8", "GAP Status"), c("Counties", "EPA Level III Ecoregions"))
L <- suppressWarnings(ssimLibrary(normalizePath(pos[1], winslash = "/"))); P <- rsyncrosim::project(L, 1)
ss0 <- as.data.table(datasheet(P, "lucasCore_StratumSource", lookupsAsFactors = FALSE))
set_files <- function(local) { ss <- copy(ss0); if (local) for (n in names(LOCAL)) ss[Name == n, File := file.path(OLD, LOCAL[[n]])] else ss[Name %in% names(LOCAL), File := NA_character_]
  saveDatasheet(P, as.data.frame(ss), "lucasCore_StratumSource", append = FALSE, force = TRUE) }
run1 <- function(sec, ter, local) {
  set_files(local)
  S <- rsyncrosim::scenario(P, sprintf("Strata %s: %s / %s (%s)", if (local) "local" else "home", sec, ter, substr(UNITS, 1, 30)))
  description(S) <- sprintf("tests/phaseZ26-strata-home.R: stage 1 on %s at %d m, secondary %s, tertiary %s, Stratum Sources polygons from %s.", UNITS, RES, sec, ter,
                            if (local) "the build machine's local files" else "Data Sources Home")
  saveDatasheet(S, data.frame(SecondarySourceId = sec, TertiarySourceId = ter, Resolution = RES), "lucasCore_BuildOptions")
  saveDatasheet(S, data.frame(UnitId = UNITS), "lucasCore_StudyArea")
  saveDatasheet(S, data.frame(StageNameId = "1 - Study Area and Strata", RunOrder = 1), "core_Pipeline")
  t0 <- Sys.time(); R <- run(S); mins <- as.numeric(Sys.time() - t0, units = "mins")
  v <- as.data.table(datasheet(R, "lucasCore_OutputValidation")); u <- as.data.table(datasheet(R, "lucasCore_OutputDataSources", optional = TRUE))
  ic <- datasheet(R, "stsim_InitialConditionsSpatial")
  list(R = R, mins = mins, pass = nrow(v) > 0 && all(v$Status == "Pass"), used = u, ic = ic) }
cmp <- function(a, b) { x <- values(a, mat = FALSE) %% OFF; y <- values(b, mat = FALSE) %% OFF; k <- !is.na(x) | !is.na(y)
  c(cells = sum(k), differ = sum(xor(is.na(x), is.na(y))[k] | (x != y)[k], na.rm = TRUE)) }
out <- list()
for (p in PAIRS) {
  h <- run1(p[1], p[2], FALSE); l <- run1(p[1], p[2], TRUE)
  ds_home <- if (nrow(h$used)) unique(h$used[grepl("File$", DataSource) & DataSource %in% c("StatesFile", "CountiesFile", "WatershedsFile", "EcoregionsFile",
                                                                                         "PyromesFile", "PadusFile"), paste(DataSource, Origin)]) else character()
  for (lv in c("SecondaryStratumFileName", "TertiaryStratumFileName")) {
    d <- cmp(rast(h$ic[[lv]]), rast(l$ic[[lv]]))
    out[[length(out) + 1]] <- data.table(Pair = paste(p, collapse = " / "), Level = sub("StratumFileName", "", lv), Cells = d[["cells"]], Differ = d[["differ"]],
                                         Pct = round(100 * d[["differ"]] / d[["cells"]], 3), HomeChecks = h$pass, LocalChecks = l$pass,
                                         Minutes = round(h$mins, 1), FromHome = paste(ds_home, collapse = "; ")) }
}
set_files(FALSE)   # leave the library reading the home
print(rbindlist(out)[, !"FromHome"]); cat("\nData Sources Used (home runs):\n"); print(unique(rbindlist(out)[, .(Pair, FromHome)]))
