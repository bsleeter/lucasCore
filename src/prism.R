# =============================================================================
# prism.R - where the PRISM grids are in a PRISM folder, at either resolution, and which one a Build reads
# =============================================================================
# A PRISM folder (Data Sources: PRISM Folder; in a home, climate/prism) holds one or both of PRISM's grids, each in its own subfolders
# (the Data Download writes them, src/download-sources.R):
#   800 m ("us_30s")  annual-us30s/<var>/prism_<var>_us_30s_<yyyy>.tif, monthly-us30s/<var>/prism_<var>_us_30s_<yyyymm>.tif,
#                     normals-us30s/<var>/prism_<var>_us_30s_2020_avg_30y.tif
#   4 km ("us_25m")   annual-us25m/<var>/prism_<var>_us_25m_<yyyy>.tif, monthly-us25m/ppt/prism_ppt_us_25m_<yyyymm>.tif,
#                     normals/prism_<var>_us_25m_2020_avg_30y.tif (or the legacy .bil folders)
# Climate Options: PRISM Grid picks the one stages 2, 3 and 7 read (800 m since 2026-11-23, to-do "PRISM 800 m everywhere"; 4 km is
# what every Build before lucasCore 1.9 read). No rsyncrosim here: tools and tests source it.
# =============================================================================
PRISM_GRIDS <- c(`800 m` = "30s", `4 km` = "25m")

# Climate Options: PRISM Grid as a label: 1 or "800 m", 2 or "4 km"; no value (a scenario from before the choice) = 800 m
prism_choice <- function(v) { v <- if (is.null(v) || !length(v)) NA else v[1]
  if (is.na(v) || (is.character(v) && !nzchar(v))) return("800 m")
  if (is.numeric(v)) return(names(PRISM_GRIDS)[as.integer(v)])
  if (grepl("4 ?km", v, ignore.case = TRUE)) "4 km" else if (grepl("800", v)) "800 m" else NA_character_ }

prism_annual <- function(folder, res, var, year) { k <- PRISM_GRIDS[[res]]; file.path(folder, paste0("annual-us", k), var, sprintf("prism_%s_us_%s_%d.tif", var, k, as.integer(year))) }
prism_monthly <- function(folder, res, var, year, mon) { k <- PRISM_GRIDS[[res]]; file.path(folder, paste0("monthly-us", k), var, sprintf("prism_%s_us_%s_%d%02d.tif", var, k, as.integer(year), as.integer(mon))) }
# the annual 1991-2020 normal of a variable, NA when the folder has none at that resolution. 4 km: the current names under normals/
# (prism_tmean_us_25m_2020_avg_30y, renamed 2025; monthly normals carry a month and are left out), else the legacy 4 km .bil
# (PRISM_tmean_30yr_normal_4kmM4_annual_bil)
prism_normal <- function(folder, var, res = "4 km") {
  if (res == "800 m") { f <- file.path(folder, "normals-us30s", var, sprintf("prism_%s_us_30s_2020_avg_30y.tif", var)); return(if (file.exists(f)) f else NA_character_) }
  f <- Sys.glob(file.path(folder, "normals", sprintf("PRISM_%s_30yr_normal_*_annual_bil", var), "*.bil"))
  if (!length(f)) f <- list.files(file.path(folder, "normals"), sprintf("^prism_%s_us_25m_[0-9]{4}_avg_30y\\.(tif|bil)$", var), recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (length(f)) f[1] else NA_character_ }
# does the folder hold a resolution? (its annual normals of tmean and ppt: every stage that reads PRISM needs those or their years)
prism_holds <- function(folder, res) !is.na(prism_normal(folder, "tmean", res)) && !is.na(prism_normal(folder, "ppt", res))

# the resolution a Build reads: the Climate Options choice, which the folder must hold. Returns the label, or stops saying what
# the folder holds and the two ways out (the Data Download, or the other choice)
prism_pick <- function(folder, choice = "800 m") {
  if (is.na(choice) || !choice %in% names(PRISM_GRIDS)) stop("Climate Options: PRISM Grid: unrecognised choice", call. = FALSE)
  if (prism_holds(folder, choice)) return(choice)
  other <- setdiff(names(PRISM_GRIDS), choice)
  stop(sprintf("Climate Options: PRISM Grid is %s, but %s holds no %s PRISM normals (%s). %s", choice, folder, choice,
               if (prism_holds(folder, other)) sprintf("it holds the %s grids", other) else "it holds neither grid",
               if (prism_holds(folder, other)) sprintf("Run a Data Download with PrismFolder to add %s, or set PRISM Grid to %s", choice, other) else "Run a Data Download with PrismFolder"), call. = FALSE) }
