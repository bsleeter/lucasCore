# =============================================================================
# make_nps_units.R - the National Parks preset's unit list and crosswalk, from PAD-US 4.0 (user 2026-11-12: a single National Park as
# the study area; refuges and DoD installations to follow the same way)
# =============================================================================
# Reads layer nps_units (Unit_Nm of National Park Service fee land) from the PadusUnitsFile GeoPackage a Data Download wrote, and
# writes defaults/strata/nps-units-list.csv (Name, Id) and nps-units-crosswalk.csv (Value, Id). Names that differ only in accents
# or letter case (PAD-US has both "César E. Chávez National Monument" and "Cesar E. Chavez National Monument") share an id, listed
# under the accented spelling. Ids are stable: a name already in the crosswalk keeps its id and new names take the next ones, so
# scenario data stays valid when the list grows. Id 9999 is the land of no unit (the preset's DefaultId: Fill = Default).
# Usage: Rscript tools/make_nps_units.R <padus4-units.gpkg>
# =============================================================================
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(TRUE); if (!length(a)) stop("usage: Rscript tools/make_nps_units.R <padus4-units.gpkg>")
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
sd <- file.path(pkg, "defaults", "strata"); NONE <- 9999L; NONE_NAME <- "Not National Park Service land"
u <- sf::read_sf(a[1], query = "SELECT DISTINCT Unit_Nm FROM nps_units")$Unit_Nm
u <- sort(unique(trimws(u[!is.na(u) & nzchar(trimws(u))])))
key <- function(x) tolower(iconv(x, "UTF-8", "ASCII//TRANSLIT"))
x <- data.table(Value = u, k = key(u), accented = u != iconv(u, "UTF-8", "ASCII//TRANSLIT"))
cwf <- file.path(sd, "nps-units-crosswalk.csv")
old <- if (file.exists(cwf)) fread(cwf, encoding = "UTF-8", colClasses = c(Value = "character", Id = "integer")) else data.table(Value = character(), Id = integer())
old <- old[Id != NONE]; old[, k := key(Value)]
ids <- unique(old[, .(k, Id)]); stopifnot(!anyDuplicated(ids$k))
nk <- sort(setdiff(unique(x$k), ids$k)); nxt <- max(c(0L, ids$Id)) + seq_along(nk); if (any(nxt >= NONE)) stop("more than 9,998 units: move the default id")
ids <- rbind(ids, data.table(k = nk, Id = nxt))
cw <- unique(rbind(old[, .(Value, Id)], x[, .(Value, Id = ids$Id[match(k, ids$k)])]))[order(Id, Value)]
# the listed name: the accented spelling where there is one
nm <- x[order(-accented, Value)][, .(Name = Value[1]), by = k][, Id := ids$Id[match(k, ids$k)]]
gone <- setdiff(ids$k, x$k); if (length(gone)) cat(sprintf("note: %d units in the crosswalk are no longer in PAD-US (kept, so their ids stay): %s\n", length(gone), paste(head(gone, 5), collapse = "; ")))
nm <- rbind(nm[, .(Name, Id)], old[k %in% gone, .(Name = Value[1]), by = .(k, Id)][, .(Name, Id)], data.table(Name = NONE_NAME, Id = NONE))[order(Id)]
stopifnot(!anyDuplicated(nm$Id), !anyDuplicated(nm$Name))
fwrite(cw, cwf)
fwrite(nm, file.path(sd, "nps-units-list.csv"))
cat(sprintf("National Parks: %d units (%d new), %d names in the crosswalk -> defaults/strata/nps-units-list.csv, nps-units-crosswalk.csv\n",
            nrow(nm) - 1L, length(nk), nrow(cw)))
