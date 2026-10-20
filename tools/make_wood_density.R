# =============================================================================
# make_wood_density.R - merchantable stem carbon per m3 of FIA net merchantable volume, per forest state class (stage 2)
# =============================================================================
# Usage: Rscript tools/make_wood_density.R [reference folder]   (default: F:/lucas-master/Data Sources/FIA/Reference)
# Inputs (public FIA data, downloaded 2026-10-20):
#   REF_SPECIES.csv   FIA DataMart: wood and bark specific gravity (green volume, dry weight), bark volume as % of wood volume,
#                     live-tree carbon ratio, per species
#   EVALIDator_netmerchvol_foresttypegroup_x_species.json   net merchantable bole volume of live trees on forest land (snum 574171)
#                     by forest type group x species, most recent evaluation of the 48 CONUS states
# Output: defaults/growth/merch-carbon-density.csv - Mg C per m3 = sum over species of volume share x (wood SG + bark SG x bark%/100)
#   x carbon ratio (SG x 1 t/m3 water = dry t/m3). FIA merchantable volume runs from a 1-ft stump to a 4-in top, inside bark,
#   so it already matches CBM's merchantable pool (stem without stump and top); bark is added here, as CBM includes it.
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })
a <- commandArgs(TRUE); ref <- if (length(a)) a[1] else "F:/lucas-master/Data Sources/FIA/Reference"
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
pkg <- normalizePath(file.path(here, ".."), winslash = "/")
sp <- fread(file.path(ref, "REF_SPECIES.csv"))[, .(SPCD, COMMON_NAME, SFTWD_HRDWD, WOOD_SG = WOOD_SPGR_GREENVOL_DRYWT, BARK_SG = BARK_SPGR_GREENVOL_DRYWT,
                                                 BARK_PCT = BARK_VOL_PCT, CRATIO = CARBON_RATIO_LIVE)]
ev <- as.data.table(fromJSON(file.path(ref, "EVALIDator_netmerchvol_foresttypegroup_x_species.json"))$estimates)
ev[, `:=`(fortyp_grp = as.integer(sub("^`(\\d+).*", "\\1", GRP1)), SPCD = as.integer(sub("^`\\d+ SPCD (\\d+).*", "\\1", GRP2)))]
ev <- ev[!is.na(fortyp_grp) & !is.na(SPCD) & ESTIMATE > 0, .(fortyp_grp, SPCD, vol_ft3 = ESTIMATE, plots = PLOT_COUNT)]
d <- merge(ev, sp, by = "SPCD", all.x = TRUE)
miss <- d[is.na(WOOD_SG) | is.na(CRATIO), .(vol = sum(vol_ft3)), by = .(SPCD, COMMON_NAME)]
if (nrow(miss)) cat(sprintf("species without wood properties (%.3f%% of volume, left out): %s\n", 100 * sum(miss$vol) / sum(d$vol_ft3), paste(head(miss$SPCD, 10), collapse = ", ")))
d <- d[!is.na(WOOD_SG) & !is.na(CRATIO)][is.na(BARK_SG), BARK_SG := 0][is.na(BARK_PCT), BARK_PCT := 0]
d[, c_per_m3 := (WOOD_SG + BARK_SG * BARK_PCT / 100) * CRATIO]
grp <- d[, .(c_per_m3 = sum(vol_ft3 * c_per_m3) / sum(vol_ft3), wood_sg = sum(vol_ft3 * WOOD_SG) / sum(vol_ft3),
             bark_share = sum(vol_ft3 * BARK_SG * BARK_PCT / 100) / sum(vol_ft3 * (WOOD_SG + BARK_SG * BARK_PCT / 100)),
             species = .N, top_species = paste(head(COMMON_NAME[order(-vol_ft3)], 3), collapse = "; "), volume_bcf = sum(vol_ft3) / 1e9), by = fortyp_grp]
cw <- fread(file.path(pkg, "defaults", "growth", "forest-type-crosswalk.csv"), colClasses = "character")
# a state class takes its own FIA group's species mix when it has one (240 Western White Pine: its own species, though its curves
# are fitted on all western softwoods); otherwise the volume-weighted mix of every group in its set
out <- rbindlist(lapply(seq_len(nrow(cw)), function(i) { g <- as.integer(strsplit(cw$FiaTypeGroups[i], ";")[[1]])
  own <- as.integer(cw$StateClassId[i]); if (own == 201L) own <- 200L; if (own == 950L) own <- 970L
  use <- if (own %in% grp$fortyp_grp) own else g; x <- d[fortyp_grp %in% use]
  data.table(StateClassId = cw$StateClassId[i], StateClassName = cw$StateClassName[i], FiaGroupsUsed = paste(use, collapse = ";"),
             MgCPerM3 = round(sum(x$vol_ft3 * x$c_per_m3) / sum(x$vol_ft3), 4), WoodSG = round(sum(x$vol_ft3 * x$WOOD_SG) / sum(x$vol_ft3), 3),
             BarkCarbonShare = round(sum(x$vol_ft3 * x$BARK_SG * x$BARK_PCT / 100) / sum(x$vol_ft3 * (x$WOOD_SG + x$BARK_SG * x$BARK_PCT / 100)), 3),
             Species = uniqueN(x$SPCD), TopSpecies = paste(head(x[, .(v = sum(vol_ft3)), by = COMMON_NAME][order(-v), COMMON_NAME], 3), collapse = "; "),
             VolumeBillionFt3 = round(sum(x$vol_ft3) / 1e9, 2)) }))
fwrite(out, file.path(pkg, "defaults", "growth", "merch-carbon-density.csv"))
options(width = 200); print(out[, .(StateClassName, FiaGroupsUsed, MgCPerM3, WoodSG, BarkCarbonShare, Species, TopSpecies)])
