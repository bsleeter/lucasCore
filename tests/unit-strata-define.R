# =============================================================================
# unit-strata-define.R - the tertiary strata a Build adds to the project's list (src/strata.R: strata_to_define), no SyncroSim
# =============================================================================
# The Tertiary Stratum list holds only the strata Builds use: ST-Sim's summaries cost time for every secondary x tertiary stratum
# defined. Stage 1 adds the units on its tertiary strata map that the list lacks. Usage: Rscript tests/unit-strata-define.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "strata.R"))
ok <- 0; bad <- 0
expect <- function(what, cond, detail = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, detail, "\n") } }
units <- data.table(Name = c("Wilderness: Buckhorn Wilderness", "Wilderness: Not designated wilderness", "Wilderness: The Brothers Wilderness", "County: Clallam Washington"),
                    Id = c(1400000102, 1400009999, 1400000723, 300053009))
a <- strata_to_define(c(1400000102, 1400009999, NA, 1400000102), numeric(), units)
expect("an empty list gets every stratum on the map, once, with its name", nrow(a) == 2 && setequal(a$Id, c(1400000102, 1400009999)) && a$Name[a$Id == 1400009999] == "Wilderness: Not designated wilderness")
b <- strata_to_define(c(1400000102, 1400009999, 1400000723), c(1400000102, 1400009999), units)
expect("a list that has some gets only the ones it lacks", nrow(b) == 1 && b$Id == 1400000723 && b$Name == "Wilderness: The Brothers Wilderness")
expect("a list that has them all gets none", nrow(strata_to_define(c(1400000102, NA), c(1400000102, 1400009999), units)) == 0)
expect("a map of no land adds nothing", nrow(strata_to_define(c(NA, NA), numeric(), units)) == 0)
expect("an id the unit list does not know stops with the id", grepl("777", tryCatch({ strata_to_define(c(1400000102, 777), numeric(), units); "" }, error = function(e) conditionMessage(e))))
expect("ids are whole numbers within an integer (the universal ids reach 2 billion)", is.integer(a$Id) && all(a$Id > 1e9))
# the defaults a new library is filled from: the unit list in the secondary list only
man <- fread(file.path(pkg, "defaults", "library", "project", "manifest.csv"))
expect("a new library gets the national unit list as its Secondary Stratum list and no Tertiary Stratum list", "stsim_SecondaryStratum" %in% man$Datasheet && !"stsim_TertiaryStratum" %in% man$Datasheet &&
       !file.exists(file.path(pkg, "defaults", "library", "project", "stsim_TertiaryStratum.csv")) && file.exists(file.path(pkg, "defaults", "library", "project", "stsim_SecondaryStratum.csv")))
cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
