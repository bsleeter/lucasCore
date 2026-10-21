# =============================================================================
# loca2.R - annual climate from LOCA2 monthly NetCDF files (stage 7 projections)
# =============================================================================
# Layout: <LOCA2 folder>/<gcm>/<member>/<historical|ssp>/<pr|tasmax|tasmin>/<var>.<gcm>.<period>.<member>.<years>.LOCA_16thdeg_*.monthly.nc
# Grid: 1/16 degree, longitudes 0-360 (shifted to -180..180 here). pr in kg m-2 s-1 (monthly mean rate; x days x 86400 = mm per month),
# tasmax/tasmin in K. Annual T = mean of the 12 monthly (tasmax + tasmin) / 2, in C (as PRISM's annual mean); annual P = sum of the
# monthly totals, in mm. Years 1950-2014 come from the historical run, 2015-2100 from the SSP run.
# =============================================================================

# monthly files of one variable for a run, with the years each covers
loca2_files <- function(folder, gcm, member, run, var) {
  f <- Sys.glob(file.path(folder, gcm, member, run, var, "*.monthly.nc"))
  if (!length(f)) return(data.table(file = character(), y0 = integer(), y1 = integer()))
  yr <- regmatches(basename(f), regexpr("[0-9]{4}-[0-9]{4}", basename(f)))
  data.table(file = f, y0 = as.integer(substr(yr, 1, 4)), y1 = as.integer(substr(yr, 6, 9))) }

# the runs of a model: TRUE if the historical run and the SSP run both have all three variables
loca2_has_run <- function(folder, gcm, member, ssp)
  all(vapply(c("historical", ssp), function(r) all(vapply(c("pr", "tasmax", "tasmin"), function(v) nrow(loca2_files(folder, gcm, member, r, v)) > 0, TRUE)), TRUE))

# annual series of "tmean" (C) or "ppt" (mm) for the years asked, cropped to `win` (a lon/lat extent), one layer per year named by year
loca2_annual <- function(folder, gcm, member, ssp, var, years, win) {
  run_of <- function(y) if (y <= 2014) "historical" else ssp
  read_var <- function(v) {
    out <- list()
    for (run in unique(vapply(years, run_of, ""))) { yrs <- years[vapply(years, run_of, "") == run]; fs <- loca2_files(folder, gcm, member, run, v)
      for (i in seq_len(nrow(fs))) { want <- yrs[yrs >= fs$y0[i] & yrs <= fs$y1[i]]; if (!length(want)) next
        r <- terra::rast(fs$file[i]); e <- terra::ext(r)
        if (terra::xmax(e) > 180) terra::ext(r) <- terra::ext(terra::xmin(e) - 360, terra::xmax(e) - 360, terra::ymin(e), terra::ymax(e))
        tm <- terra::time(r); yy <- as.integer(format(tm, "%Y")); keep <- which(yy %in% want)
        r <- terra::crop(r[[keep]], win); tm <- tm[keep]; yy <- yy[keep]
        if (v == "pr") { mo <- as.integer(format(tm, "%m")); days <- as.integer(format(as.Date(paste(yy + (mo == 12), mo %% 12 + 1, 1, sep = "-")) - 1, "%d"))
          r <- r * (days * 86400) }   # one value per layer: mm in each month
        out[[length(out) + 1]] <- terra::tapp(r, index = yy, fun = if (v == "pr") "sum" else "mean") } }
    miss <- setdiff(years, as.integer(sub("^X", "", unlist(lapply(out, names)))))
    if (length(miss)) stop(sprintf("LOCA2 %s %s %s %s: no monthly data for %s", gcm, member, ssp, v, paste(range(miss), collapse = "-")), call. = FALSE)
    x <- terra::rast(out); names(x) <- sub("^X", "", names(x)); x[[as.character(years)]] }
  if (var == "ppt") return(read_var("pr"))
  (read_var("tasmax") + read_var("tasmin")) / 2 - 273.15 }
