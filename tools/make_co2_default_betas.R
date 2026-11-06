# =============================================================================
# make_co2_default_betas.R - defaults/climate/co2-default-betas.csv: the betas of every class and age band, Low / Central / High
# =============================================================================
# What stage 11 computes from co2-betas.csv, co2-classes.csv, co2-age-bands.csv and co2-ecm-share.csv (src/co2.R co2_betas), written
# out so the Climate page can load them into its CO2 Betas grid (ui/ProjectionClimateView.cs). One blank-stratum row per class (and age
# band for forest), at the CONUS ECM share; and, for forest classes with an ecodivision ECM share, a row per ecodivision and band.
# Rerun after changing any of those four tables (tests/unit-co2.R checks the file matches them).
# Usage: Rscript tools/make_co2_default_betas.R   (from the package folder)
# =============================================================================
suppressPackageStartupMessages(library(data.table))
source("src/co2.R")
d <- function(f) fread(file.path("defaults", "climate", f), na.strings = "", encoding = "UTF-8")
fwrite(co2_default_table(d("co2-classes.csv"), d("co2-betas.csv"), d("co2-age-bands.csv"), d("co2-ecm-share.csv")),
       file.path("defaults", "climate", "co2-default-betas.csv"))
cat("wrote defaults/climate/co2-default-betas.csv\n")
