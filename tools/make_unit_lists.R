# =============================================================================
# make_unit_lists.R - unit lists and crosswalks of the managed-unit and metro presets (to-do 59; user 2026-11-13: "Build your four
# plus tribal lands and BLM, separate numbers", "add MSAs as 17")
# =============================================================================
# Writes defaults/strata/<key>-list.csv (Name, Id) and, for the text-keyed sources, <key>-crosswalk.csv (Value, Id):
#   fws-refuges        FWS Refuges (11)        PAD-US layer fws_units, Unit_Nm: the refuge system (refuges, wetland management
#                                                districts, waterfowl production areas); not hatcheries or other FWS land
#   dod-installations  DoD Installations (12)   PAD-US layer dod_units (installation boundaries, Des_Tp MIL), Unit_Nm
#   national-forests   National Forests (13)    PAD-US layer usfs_units, Unit_Nm of national forests and grasslands
#   wilderness         Wilderness (14)          PAD-US layer wilderness, Unit_Nm
#   tribal-lands       Tribal Lands (15)        TribalLandsFile layer tribal_lands: ids are AIANNHCE (list only, no crosswalk)
#   blm-ncl            BLM National Conservation Lands (16)  PAD-US layer blm_ncl, Unit_Nm
#   msa                Metropolitan Areas (17)  OMB July 2023 delineation (list1_2023.xlsx): county GEOID -> metro CBSA code
# Ids are stable: a name (or county) already in a crosswalk keeps its id, new ones take the next, and units gone from the source stay
# listed so scenario data keeps its meaning. Names differing only in accents or case share an id. Id 99999 (Ids 9999 for the PAD-US
# sources) is the land of no unit (the preset's DefaultId, Fill = Default). National Parks keep tools/make_nps_units.R.
# Usage: Rscript tools/make_unit_lists.R [--padus=<padus4-units.gpkg>] [--tribal=<tribal-lands.gpkg>] [--omb=<list1_2023.xlsx>]
# =============================================================================
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(TRUE); opt <- function(k) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else NA }
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
sd <- file.path(pkg, "defaults", "strata")
key <- function(x) tolower(iconv(x, "UTF-8", "ASCII//TRANSLIT"))

# a text-keyed source (names): list and crosswalk with stable ids, as tools/make_nps_units.R
name_list <- function(stem, label, u, none_id, none_name) {
  u <- sort(unique(trimws(u[!is.na(u) & nzchar(trimws(u))])))
  x <- data.table(Value = u, k = key(u), accented = u != iconv(u, "UTF-8", "ASCII//TRANSLIT"))
  cwf <- file.path(sd, paste0(stem, "-crosswalk.csv"))
  old <- if (file.exists(cwf)) fread(cwf, encoding = "UTF-8", colClasses = c(Value = "character", Id = "integer")) else data.table(Value = character(), Id = integer())
  old <- old[Id != none_id]; old[, k := key(Value)]
  ids <- unique(old[, .(k, Id)]); stopifnot(!anyDuplicated(ids$k))
  nk <- sort(setdiff(unique(x$k), ids$k)); nxt <- max(c(0L, ids$Id)) + seq_along(nk); if (any(nxt >= none_id)) stop(label, ": too many units for the default id")
  ids <- rbind(ids, data.table(k = nk, Id = nxt))
  cw <- unique(rbind(old[, .(Value, Id)], x[, .(Value, Id = ids$Id[match(k, ids$k)])]))[order(Id, Value)]
  nm <- x[order(-accented, Value)][, .(Name = Value[1]), by = k][, Id := ids$Id[match(k, ids$k)]]
  gone <- setdiff(ids$k, x$k)
  nm <- rbind(nm[, .(Name, Id)], old[k %in% gone, .(Name = Value[1]), by = .(k, Id)][, .(Name, Id)], data.table(Name = none_name, Id = none_id))[order(Id)]
  stopifnot(!anyDuplicated(nm$Id), !anyDuplicated(nm$Name))
  fwrite(cw, cwf); fwrite(nm, file.path(sd, paste0(stem, "-list.csv")))
  cat(sprintf("%s: %d units (%d new%s) -> defaults/strata/%s-list.csv, %s-crosswalk.csv\n", label, nrow(nm) - 1L, length(nk),
              if (length(gone)) sprintf(", %d no longer in the source, kept", length(gone)) else "", stem, stem)) }

# ---- PAD-US units -------------------------------------------------------------------------------------------------------
# PAD-US designation types kept (checked on PAD-US 4.0, 2026-11-13): FWS refuges (NWR), conservation areas such as Grasslands WMA
# (NCA) and waterfowl production areas and wetland management districts (RMA), not hatcheries (FOTH) or Farm Service Agency
# interests; BLM national monuments, national conservation areas and wilderness study areas (not ACECs, which are not National
# Conservation Lands, nor the river corridors of Wild and Scenic Rivers)
FWS_TYPES <- c("NWR", "NCA", "RMA"); BLM_TYPES <- c("NM", "NCA", "WSA")
if (!is.na(opt("padus"))) { g <- opt("padus")
  q <- function(layer, cols = "Unit_Nm") as.data.table(sf::st_drop_geometry(sf::read_sf(g, query = sprintf("SELECT DISTINCT %s FROM %s", paste(cols, collapse = ", "), layer))))
  fws <- q("fws_units", c("Unit_Nm", "Des_Tp")); cat("FWS designation types:", paste(fws[, .N, by = Des_Tp][order(-N), sprintf("%s %d", Des_Tp, N)], collapse = ", "), "\n")
  name_list("fws-refuges", "FWS Refuges", fws[Des_Tp %in% FWS_TYPES & !grepl("Hatchery|Farm Service Agency", Unit_Nm), Unit_Nm], 9999L, "Not National Wildlife Refuge System land")
  name_list("dod-installations", "DoD Installations", q("dod_units")$Unit_Nm, 9999L, "Not Department of Defense land")
  fs <- q("usfs_units", c("Unit_Nm", "Des_Tp")); cat("USFS designation types:", paste(fs[, .N, by = Des_Tp][order(-N), sprintf("%s %d", Des_Tp, N)], collapse = ", "), "\n")
  name_list("national-forests", "National Forests", fs[Des_Tp %in% c("NF", "NG") & grepl("National (Forest|Grassland)s?$", trimws(Unit_Nm)), Unit_Nm], 9999L, "Not National Forest System land")
  name_list("wilderness", "Wilderness", q("wilderness")$Unit_Nm, 9999L, "Not designated wilderness")
  blm <- q("blm_ncl", c("Unit_Nm", "Des_Tp")); cat("BLM designation types:", paste(blm[, .N, by = Des_Tp][order(-N), sprintf("%s %d", Des_Tp, N)], collapse = ", "), "\n")
  name_list("blm-ncl", "BLM National Conservation Lands", blm[Des_Tp %in% BLM_TYPES, Unit_Nm], 9999L, "Not BLM National Conservation Lands") }

# ---- tribal lands: ids are AIANNHCE; a reservation's name, else its trust land's -------------------------------------------
if (!is.na(opt("tribal"))) {
  t <- as.data.table(sf::st_drop_geometry(sf::read_sf(opt("tribal"), query = "SELECT AIANNHCE, NAMELSAD, CLASSFP, COMPTYP FROM tribal_lands")))
  t <- t[order(AIANNHCE, COMPTYP != "R")][, .(Name = NAMELSAD[1], st = any(CLASSFP == "D4")), by = .(Id = as.integer(AIANNHCE))]
  stopifnot(!anyDuplicated(t$Name), all(t$Id < 99999L))
  lf <- file.path(sd, "tribal-lands-list.csv"); old <- if (file.exists(lf)) fread(lf) else data.table(Name = character(), Id = integer())
  out <- rbind(t[, .(Name, Id)], old[!Id %in% c(t$Id, 99999L)], data.table(Name = "Not tribal land", Id = 99999L))[order(Id)]
  fwrite(out, lf); cat(sprintf("Tribal Lands: %d units (%d state reservations) -> defaults/strata/tribal-lands-list.csv\n", nrow(out) - 1L, sum(t$st))) }

# ---- metropolitan statistical areas: OMB July 2023, counties by GEOID ------------------------------------------------------
# Connecticut: the delineation uses the 2022 planning regions, the Counties preset (TIGER 2022 redistricting) the eight old counties;
# each old county takes the metro of the planning region holding most of it (Litchfield and Windham: mostly non-metro regions)
CT_OLD <- c(`09001` = "14860", `09003` = "25540", `09005` = NA, `09007` = "25540", `09009` = "35300", `09011` = "35980", `09013` = "25540", `09015` = NA)
if (!is.na(opt("omb"))) {
  x <- as.data.table(readxl::read_excel(opt("omb"), skip = 2))
  x <- x[`Metropolitan/Micropolitan Statistical Area` == "Metropolitan Statistical Area" & !`FIPS State Code` %in% c("02", "15", "72")]
  cw <- x[, .(Value = paste0(`FIPS State Code`, `FIPS County Code`), Id = as.integer(`CBSA Code`), Title = `CBSA Title`)]
  cw <- rbind(cw[!startsWith(Value, "09")], data.table(Value = names(CT_OLD), Id = as.integer(CT_OLD))[!is.na(Id)], fill = TRUE)
  ttl <- unique(x[, .(Id = as.integer(`CBSA Code`), Name = `CBSA Title`)])
  counties <- fread(file.path(sd, "counties-list.csv"), colClasses = c(Id = "character"))[, Value := sprintf("%05d", as.integer(Id))]
  miss <- setdiff(cw$Value, counties$Value); if (length(miss)) cat("note: delineation counties not in the Counties list:", paste(miss, collapse = ", "), "\n")
  cw <- cw[Value %in% counties$Value][order(Id, Value), .(Value, Id)]
  nm <- rbind(ttl[Id %in% cw$Id], data.table(Id = 99999L, Name = "Not in a metropolitan area"))[order(Id), .(Name, Id)]
  stopifnot(!anyDuplicated(nm$Id), !anyDuplicated(nm$Name), !anyDuplicated(cw$Value))
  fwrite(cw, file.path(sd, "msa-crosswalk.csv")); fwrite(nm, file.path(sd, "msa-list.csv"))
  dropped <- setdiff(ttl$Id, cw$Id)
  cat(sprintf("Metropolitan Areas: %d metros from %d counties -> defaults/strata/msa-list.csv, msa-crosswalk.csv%s\n", nrow(nm) - 1L, nrow(cw),
              if (length(dropped)) sprintf(" (no county here: %s)", paste(ttl[Id %in% dropped, Name], collapse = "; ")) else "")) }
