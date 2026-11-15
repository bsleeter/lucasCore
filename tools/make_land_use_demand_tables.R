# =============================================================================
# make_land_use_demand_tables.R - the Land Use Demand tables the package ships (defaults/land-use-demand), from the published files
# =============================================================================
# User 2026-11-15: "This is making me reconsider adding all the ICLUS and RPA data to the download. Seems like this is just bloat when
# the tables could just ship with the package." Stage 9 reads a few megabytes of five published sources that never change (fixed
# editions), and getting them took 7.5 GB of downloads. This script reduces each source to what the stage reads; the ratios are still
# computed in the stage (src/land-use-demand.R), from these tables. A Data Sources path set by the user still wins (another edition).
#
# Usage:  Rscript tools/make_land_use_demand_tables.R <folder> [--iclus-maps=<folder of the unzipped ICLUS runs> --counties=<county polygons>]
# <folder> holds the published files (any of them; a table whose source is missing is left as it is):
#   rpa-2020/county_landuse_projections_RPA.rds     RDS-2023-0026.zip > Data/   https://doi.org/10.2737/RDS-2023-0026
#   rpa-forest-products/Ch7_{LM,HM,HL,HH}_v2.csv    RDS-2022-0073-2.zip > Data/ https://doi.org/10.2737/RDS-2022-0073-2
#   iclus/iclus_v211_county_new_developed.csv       made here from the maps with --iclus-maps (src/iclus.R: 4 zips, 6.6 GB,
#                                                   https://www.epa.gov/gcx/iclus-downloads; unzip each run into the folder)
#   hauer-2019/SSP_asrc.csv                         SSP_asrc.zip, https://doi.org/10.17605/OSF.IO/9YNFC (or hauer_county_ssp_totals.csv)
#   census-population/co-est2020-alldata.csv        https://www2.census.gov/programs-surveys/popest/datasets/2010-2020/counties/totals/
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
a <- commandArgs(TRUE); opt <- function(k) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else NA_character_ }
src <- a[!grepl("^--", a)]; if (!length(src)) stop("usage: Rscript tools/make_land_use_demand_tables.R <folder with the published files>")
src <- normalizePath(src[1], winslash = "/"); out <- file.path(pkg, "defaults", "land-use-demand"); dir.create(out, showWarnings = FALSE, recursive = TRUE)
source(file.path(pkg, "src", "land-use-demand.R"))
made <- list(); note <- function(table, source, rows) { made[[table]] <<- data.table(Table = table, Source = basename(source), SourceMd5 = unname(tools::md5sum(source)), Rows = rows, Made = as.character(Sys.Date()))
  cat(sprintf("%s: %d rows, %.2f MB\n", table, rows, file.size(file.path(out, table)) / 1e6)) }

# ---- RPA land use: new urban land a year by county, step and future (km2; from crop, pasture, range and forest) ------------------
f <- file.path(src, "rpa-2020", "county_landuse_projections_RPA.rds")
if (file.exists(f)) { x <- readRDS(f); steps <- c(DEMAND_CAL, DEMAND_STEPS)
  d <- rbindlist(lapply(names(x), function(s) rbindlist(lapply(steps, function(st) { m <- simplify2array(unclass(x[[s]][[st]]))
    yrs <- as.integer(sub(".*-", "", st)) - as.integer(sub("-.*", "", st))
    data.table(Fips = dimnames(m)[[3]], Step = st, Future = s, PerYear = colSums(m[c("cr", "ps", "rg", "fr"), "ur", , drop = FALSE], dims = 2) * DEMAND_KM2 / yrs) }))))
  w <- dcast(d, Fips + Step ~ Future, value.var = "PerYear"); for (k in names(x)) set(w, j = k, value = signif(w[[k]], 6))
  fwrite(w[order(Fips, Step)], file.path(out, "rpa-county-urbanization.csv")); note("rpa-county-urbanization.csv", f, nrow(w)) }

# ---- RPA forest products: total timber harvest of the six US regions, by scenario ----------------------------------------------
fs <- file.path(src, "rpa-forest-products", DEMAND_HARVEST_FILE)
if (all(file.exists(fs))) { h <- rbindlist(lapply(seq_along(fs), function(i) { t <- fread(fs[i], header = TRUE)
    cbind(Scenario = names(DEMAND_HARVEST_FILE)[i], t[Measurement == "Timber harvest level" & Product == "total timber" & Location %in% names(DEMAND_HARVEST_REGIONS)]) }), fill = TRUE)
  fwrite(h, file.path(out, "rpa-timber-harvest.csv")); note("rpa-timber-harvest.csv", fs[1], nrow(h)) }

# ---- ICLUS: new land in classes 12-16 by county and decade, a column per run (km2) --------------------------------------------
f <- file.path(src, "iclus", "iclus_v211_county_new_developed.csv")
if (!is.na(opt("iclus-maps"))) { suppressPackageStartupMessages(library(sf)); source(file.path(pkg, "src", "iclus.R"))
  if (is.na(opt("counties"))) stop("--iclus-maps needs --counties=<county polygons with a GEOID field>")
  tab <- iclus_county_table(opt("iclus-maps"), read_sf(opt("counties")), id = "GEOID", workers = max(1L, min(16L, parallel::detectCores() - 2L)), log = function(...) cat(sprintf(...), "\n"))
  dir.create(dirname(f), showWarnings = FALSE, recursive = TRUE); fwrite(tab[order(Run, Fips, Year)], f) }
if (file.exists(f)) { t <- fread(f, colClasses = list(character = "Fips")); w <- dcast(t, Fips + Year ~ Run, value.var = "Km2")
  for (k in setdiff(names(w), c("Fips", "Year"))) set(w, j = k, value = round(w[[k]], 4))
  fwrite(w[order(Fips, Year)], file.path(out, "iclus-county-new-developed.csv")); note("iclus-county-new-developed.csv", f, nrow(w)) }

# ---- Hauer 2019: county population by SSP and year (people) ---------------------------------------------------------------------
f <- file.path(src, "hauer-2019", "SSP_asrc.csv"); f2 <- file.path(src, "hauer-2019", "hauer_county_ssp_totals.csv")
if (file.exists(f)) { d <- fread(f, select = c("YEAR", "GEOID", paste0("SSP", 1:5)), colClasses = list(character = "GEOID"))
  tot <- d[, lapply(.SD, sum), by = .(GEOID = sprintf("%05d", as.integer(GEOID)), YEAR), .SDcols = paste0("SSP", 1:5)]
} else if (file.exists(f2)) { tot <- fread(f2, colClasses = list(character = "GEOID")); f <- f2 } else tot <- NULL
if (!is.null(tot)) { for (k in paste0("SSP", 1:5)) set(tot, j = k, value = round(tot[[k]], 3))   # (as published to 3 decimals: coarser rounding moves the ratios of the smallest counties)
  fwrite(tot[order(GEOID, YEAR)], file.path(out, "hauer-county-population.csv")); note("hauer-county-population.csv", f, nrow(tot)) }

# ---- Census: county population on 1 July 2010 and 2020 ---------------------------------------------------------------------------
f <- file.path(src, "census-population", "co-est2020-alldata.csv")
if (file.exists(f)) { cn <- fread(f, encoding = "Latin-1")[SUMLEV == 50, .(SUMLEV, STATE, COUNTY, STNAME, CTYNAME, POPESTIMATE2010, POPESTIMATE2020)]
  fwrite(cn, file.path(out, "census-county-population.csv"), bom = FALSE); note("census-county-population.csv", f, nrow(cn)) }

# what each table was made from (the files' checksums), beside them
if (length(made)) { m <- rbindlist(made); rf <- file.path(out, "made-from.csv")
  old <- if (file.exists(rf)) fread(rf, colClasses = "character")[!Table %in% m$Table] else NULL
  fwrite(rbind(old, m[, lapply(.SD, as.character)], fill = TRUE)[order(Table)], rf); cat("wrote", out, "\n") } else cat("no published file found under", src, "\n")
