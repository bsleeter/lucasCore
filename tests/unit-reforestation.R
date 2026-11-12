# Unit test: src/reforestation.R, forest potential from LANDFIRE BpS (to-do 57: the reforestation transition), and the BpsFile
# Data Source's rows (package.xml, data-sources.csv, endpoints.csv, citations.csv, the download handler).
# Usage: Rscript tests/unit-reforestation.R   (from the package folder)
suppressPackageStartupMessages(library(data.table))
read_default <- function(...) fread(file.path("defaults", ...), encoding = "UTF-8")
source(file.path("src", "reforestation.R"))
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
tab <- read_default("landcover", "LF20_BPS_220.csv"); grp <- read_default("landcover", "bps-groups.csv"); lk <- bps_lookup(tab, grp)
check("the BpS table has every LF2020 value once", nrow(tab) == 2189 && !anyDuplicated(tab$VALUE))
check("every GROUPVEG in the table has a row in bps-groups.csv", all(setdiff(unique(tab$GROUPVEG), c(NA, "")) %in% grp$GROUPVEG))
check("every potential is a known one", all(lk$Potential %in% BPS_POTENTIAL))
v <- function(g) tab[GROUPVEG == g, VALUE][1]
p <- bps_potential(c(v("Conifer"), v("Hardwood-Conifer"), v("Peatland Forest"), v("Shrubland"), v("Grassland"), v("Sparse"), v("Riparian"), v("Savanna"), v("Open Water"), -9999L, 99999L, NA), lk)
check("forest groups read as forest", all(p[1:3] == "forest"))
check("shrub, grass and sparse read as non-forest", all(p[4:6] == "non-forest"))
check("riparian and savanna read as forest by default", all(p[7:8] == "forest"))
check("water, fill, unknown values and NA read as other", all(p[9:12] == "other"))
check("riparian and savanna read as non-forest when set", all(bps_potential(c(v("Riparian"), v("Savanna")), lk, "non-forest") == "non-forest"))
check("a bad riparian setting stops", inherits(try(bps_potential(1L, lk, "maybe"), silent = TRUE), "try-error"))
check("Hawaii types with no GROUPVEG read as other", all(bps_potential(tab[is.na(GROUPVEG) | GROUPVEG == "", VALUE], lk) == "other"))
g2 <- rbind(grp, data.table(GROUPVEG = "Conifer", Potential = "forest", Note = ""))
check("a GROUPVEG listed twice stops", inherits(try(bps_lookup(tab, g2), silent = TRUE), "try-error"))
g3 <- copy(grp)[GROUPVEG == "Sparse", Potential := "sparse"]
check("an unknown potential stops", inherits(try(bps_lookup(tab, g3), silent = TRUE), "try-error"))
# the Data Source is wired everywhere a LANDFIRE layer is
x <- readLines("package.xml"); check("package.xml has the BpsFile column", any(grepl('<column name="BpsFile"', x, fixed = TRUE)))
check("data-sources.csv has a BpsFile row with a home place", fread(file.path("defaults", "library", "data-sources.csv"))[Column == "BpsFile", nzchar(HomePath)])
ep <- fread(file.path("defaults", "download", "endpoints.csv"))[Column == "BpsFile"]
check("endpoints.csv has a BpsFile row for the LFPS layer LF2020_BPS", nrow(ep) == 1 && ep$Product == "LF2020_BPS" && ep$Method == "lfps")
check("citations.csv has a BpsFile citation", nrow(fread(file.path("defaults", "metadata", "citations.csv"))[Column == "BpsFile"]) == 1)
check("the download handler fetches LF2020_BPS", any(grepl('H$BpsFile <- lf_single("BpsFile"', readLines(file.path("src", "download-sources.R")), fixed = TRUE)))
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
