# =============================================================================
# strata-from-home.R - one-off (2026-11-02): the strata presets read their polygons from Data Sources Home
# =============================================================================
# Before this the presets named files on the build machine (F:/lucas-master/Data Sources/...), so nobody else could run stage 1
# or a Data Download for a study area. This
#   - writes ListFiles for the presets whose unit lists were built from their polygons (HUC6, HUC8, EPA Level III, pyromes), taken
#     from the unit list the package ships (defaults/library/project/stsim_SecondaryStratum.csv), so the names and ids stay the same
#   - gives presets.csv a DataSource column (the Data Download dataset of each preset) and blanks the presets' File
#   - blanks the same Files in the Studio template's Stratum Sources (defaults/library/project/lucasCore_StratumSource.csv)
# A library made before keeps its own Stratum Sources rows; a File it names that this machine lacks falls back to the home.
# Usage: Rscript tools/strata-from-home.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
sd <- file.path(pkg, "defaults", "strata")
pre <- fread(file.path(sd, "presets.csv"), colClasses = "character", na.strings = "")
ul <- fread(file.path(pkg, "defaults", "library", "project", "stsim_SecondaryStratum.csv"), colClasses = c(Name = "character", Id = "numeric"))
ul[, Number := as.integer(Id %/% 1e8)][, Native := as.integer(Id %% 1e8)]

home_ds <- c(States = "StatesFile", Counties = "CountiesFile", HUC6 = "WatershedsFile", HUC8 = "WatershedsFile", `EPA Level III Ecoregions` = "EcoregionsFile",
             Pyromes = "PyromesFile", `Federal Lands` = "PadusFile", `GAP Status` = "PadusFile")
lists <- c(HUC6 = "huc6-list.csv", HUC8 = "huc8-list.csv", `EPA Level III Ecoregions` = "epa-l3-list.csv", Pyromes = "pyromes-list.csv")
for (p in names(lists)) {
  r <- pre[Preset == p]; u <- ul[Number == as.integer(r$Number)]
  if (!nrow(u)) stop("no units of ", p, " in the shipped unit list")
  l <- u[, .(Name = sub(paste0("^", r$Prefix, ": "), "", Name), Id = Native)][order(Id)]
  stopifnot(!anyDuplicated(l$Id), !anyDuplicated(l$Name))
  fwrite(l, file.path(sd, lists[[p]])); cat(sprintf("%-26s %5d units -> %s\n", p, nrow(l), lists[[p]]))
}
if (!"DataSource" %in% names(pre)) pre[, DataSource := NA_character_]
pre[Preset %in% names(home_ds), `:=`(DataSource = home_ds[Preset], File = NA_character_)]
pre[Preset %in% names(lists), ListFile := lists[Preset]]
pre[Preset == "GAP Status", `:=`(Description = "PAD-US 4.0 GAP status (the GAP analysis file: one status per area, the most protected where designations overlap); other land = Not in PAD-US")]
fwrite(pre, file.path(sd, "presets.csv")); cat("presets.csv: DataSource added; File blank for", paste(names(home_ds), collapse = ", "), "\n")

tp <- file.path(pkg, "defaults", "library", "project", "lucasCore_StratumSource.csv")
t <- fread(tp, colClasses = "character", na.strings = "")
t[Name %in% names(home_ds), File := NA_character_]
t[Name %in% names(lists), ListFile := lists[Name]]
t[Name == "GAP Status", Description := pre[Preset == "GAP Status", Description]]
fwrite(t, tp); cat("lucasCore_StratumSource.csv (Studio template): File blank for the same presets\n")
