# =============================================================================
# build_template.R - the File > New template library: Templates/LUCAS Core (CONUS).ssim and its preview image
# =============================================================================
# SyncroSim offers every .ssim in a package's Templates folder under File > New Library, beside "Empty Library"; choosing it copies
# the library. This one is made by tools/new-library.R, so it holds the stsim definitions, every Stratum Source with the universal
# unit lists, the LOCA2 lists of this machine's LOCA2 folder, and the Stock-Flow Definitions scenario. A user then only fills in
# a scenario's Build Options, Study Area and Climate Options. Rebuild after changing defaults/ or package.xml, and reinstall the
# package (SyncroSim.PackageManager.exe --xinstall="F:\lucasCore", SyncroSim Studio closed).
# Usage: Rscript tools/build_template.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf) })
for (v in c("PROJ_LIB", "PROJ_DATA", "GDAL_DATA")) if (grepl("syncro", tolower(Sys.getenv(v)))) Sys.unsetenv(v)
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
pkg <- normalizePath(file.path(here, ".."), winslash = "/"); td <- file.path(pkg, "Templates"); dir.create(td, showWarnings = FALSE)
name <- "LUCAS Core (CONUS)"; f <- file.path(td, paste0(name, ".ssim"))
unlink(c(f, paste0(f, c(".data", ".temp", ".backup", ".input"))), recursive = TRUE)
if (system2(file.path(R.home("bin"), "Rscript.exe"), c(shQuote(file.path(pkg, "tools", "new-library.R")), shQuote(f)))) stop("new-library.R failed")
unlink(paste0(f, c(".temp", ".backup")), recursive = TRUE)
# preview: the FIA ecodivisions (the primary strata) over CONUS
eco <- st_transform(read_sf("F:/lucas-master/Data Sources/FIA/EcoDivision_map/EcoDivisions_Dissolve.shp"), "EPSG:5070")
png(file.path(td, paste0(name, ".png")), width = 600, height = 400, bg = "white")
par(mar = c(0, 0, 2, 0)); plot(st_geometry(eco), col = hcl.colors(nrow(eco), "Dark 3", alpha = 0.8), border = "white", lwd = 0.3,
                               main = "LUCAS Core: CONUS land use and carbon")
dev.off()
cat("template:", f, "\n")
