# =============================================================================
# add-strata-stacks.R - give a library the stacked strata sources it lacks (Land Manager, Land Designation)
# =============================================================================
# A stack (src/strata.R) is a Stratum Source made of other sources: it has no polygons or units of its own, so a library needs only its
# row in Stratum Sources (Name, Number, Prefix, Description) to offer it for the secondary and tertiary strata on Build Options. A
# library made before the stacks has no such rows; a new one gets them from defaults/library/project. This appends every stack of
# defaults/strata/presets.csv whose Name the library lacks, and nothing else: existing rows and the unit lists are left as they are.
# It stops when a stack names a source the library does not list (run tools/new-library.R <library> --rebuild-strata for those).
# Close the library in SyncroSim Studio first. Usage: Rscript tools/add-strata-stacks.R <library.ssim> [--dry-run]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tools/add-strata-stacks.R <library.ssim> [--dry-run]")
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "strata.R"))
pre <- fread(file.path(pkg, "defaults", "strata", "presets.csv"), sep = ",", colClasses = "character", na.strings = "")[!is.na(Stack)]
P <- rsyncrosim::project(suppressWarnings(ssimLibrary(normalizePath(pos[1], winslash = "/"))), "Definitions")
have <- as.data.table(datasheet(P, "lucasCore_StratumSource", optional = TRUE, lookupsAsFactors = FALSE))
if (!nrow(have)) stop("Stratum Sources is empty: run tools/new-library.R on this library")
add <- pre[!Preset %in% have$Name]
if (!nrow(add)) { cat("nothing to add: the library has", paste(pre$Preset, collapse = " and "), "\n"); quit(status = 0) }
for (i in seq_len(nrow(add))) { st <- strata_stack(list(Preset = add$Preset[i]), pkg); miss <- setdiff(c(st$members, st$rest), have$Name)
  if (length(miss)) stop(sprintf("%s stacks %s, which this library's Stratum Sources does not list: run tools/new-library.R <library> --rebuild-strata", add$Preset[i], paste(miss, collapse = ", "))) }
if (any(as.integer(add$Number) %in% as.integer(have$Number))) stop("a stack's Number is already used in this library: ", paste(add[as.integer(Number) %in% as.integer(have$Number), Preset], collapse = ", "))
new <- data.frame(Name = add$Preset, Number = as.integer(add$Number), Prefix = add$Prefix, Description = add$Description, Dissolve = FALSE, Overlap = "Last", Fill = "Default", stringsAsFactors = FALSE)
cat(sprintf("%s: %s\n", if ("--dry-run" %in% a) "would add" else "adding", paste(sprintf("%s (%s)", new$Name, new$Number), collapse = ", ")))
if (!"--dry-run" %in% a) { saveDatasheet(P, new, "lucasCore_StratumSource", append = TRUE)
  now <- as.data.table(datasheet(P, "lucasCore_StratumSource", lookupsAsFactors = FALSE)); stopifnot(all(new$Name %in% now$Name), nrow(now) == nrow(have) + nrow(new))
  cat("Stratum Sources:", nrow(now), "rows\n") }
