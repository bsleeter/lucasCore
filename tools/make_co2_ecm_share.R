# =============================================================================
# make_co2_ecm_share.R - defaults/climate/co2-ecm-share.csv: each forest type group's ectomycorrhizal (ECM) share of live basal area
# =============================================================================
# The CO2 fertilization multiplier (stage 11, to-do 46) weights the ECM and AM betas of a forest class by this share. From the FIA
# DataMart <ST>_TREE.csv tables: live trees (STATUSCD 1, DIA >= 1 in) on forest conditions measured 2010 or later, basal area
# = 0.005454 x DIA^2 x TPA_UNADJ (sq ft per acre). Each tree's ECM fraction comes from its species code in
# defaults/climate/co2-mycorrhiza-species.csv, the species list of Jo et al. 2019 (Sci. Adv. 5:eaav6358, doi:10.1126/sciadv.aav6358;
# data doi:10.4231/R76D5R7S, CC0): EM = 1, AM = 0, AM+EM = 0.5 (as Jo et al. split them), and ericoid (ERM) and non-mycorrhizal (NM)
# trees left out of the share, as Jo et al. computed AM / (AM + EM) basal area. A species the list lacks takes its genus's fraction
# from defaults/climate/co2-mycorrhiza-genus.csv, which follows Jo et al.'s genus choices (genera not listed there are AM = 0).
# The conditions (plot, forest type group, ecodivision) are the cached tables of src/fia.R (fia-conditions.rds in the DataMart folder).
# Writes one row per forest type group x ecodivision with at least MIN_COND conditions, and one CONUS row per group (StratumId blank).
# Usage: Rscript tools/make_co2_ecm_share.R "<FIA DataMart folder>"
# =============================================================================
suppressPackageStartupMessages(library(data.table))
MIN_COND <- 30
dm <- commandArgs(TRUE)[1]; if (is.na(dm) || !dir.exists(dm)) stop("usage: Rscript tools/make_co2_ecm_share.R <FIA DataMart folder>")
pkg <- if (file.exists("package.xml")) "." else stop("run from the package folder")

td <- tempfile(); dir.create(td); unzip(file.path(dm, "FIADB_REFERENCE.zip"), c("REF_SPECIES.csv"), exdir = td)
sp <- fread(file.path(td, "REF_SPECIES.csv"), select = c("SPCD", "GENUS"))
jo <- fread(file.path(pkg, "defaults", "climate", "co2-mycorrhiza-species.csv"), na.strings = "")
gen <- fread(file.path(pkg, "defaults", "climate", "co2-mycorrhiza-genus.csv"), na.strings = "")
g <- match(sp$GENUS, gen$Genus); sp[, Ecm := gen$Ecm[g]][is.na(g), Ecm := 0]   # a listed genus with a blank Ecm (ERM, NM) stays NA: left out
sp[, Source := "genus table"]; i <- match(sp$SPCD, jo$SPCD); sp[!is.na(i), `:=`(Ecm = jo$Ecm[i[!is.na(i)]], Source = "Jo et al. 2019")]
cat(sprintf("species: %d from Jo et al. 2019 (%d ERM/NM left out), the rest by genus\n", sp[Source != "genus table", .N], sp[Source != "genus table" & is.na(Ecm), .N]))
cc <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[invyr >= 2010, .(PLT_CN = as.character(plt_cn), CONDID = as.integer(condid), ecodiv, grp = fortyp_grp)]
sts <- sub("_TREE.csv$", "", list.files(dm, "^[A-Z]{2}_TREE.csv$"))
t0 <- Sys.time()
ba <- rbindlist(lapply(sts, function(s) {
  tr <- fread(file.path(dm, paste0(s, "_TREE.csv")), select = c("PLT_CN", "CONDID", "INVYR", "STATUSCD", "SPCD", "DIA", "TPA_UNADJ"),
              colClasses = c(PLT_CN = "character"), showProgress = FALSE)
  tr <- tr[INVYR >= 2010 & STATUSCD == 1 & !is.na(DIA) & DIA >= 1 & !is.na(TPA_UNADJ)]
  tr[, b := 0.005454 * DIA^2 * TPA_UNADJ][, k := match(SPCD, sp$SPCD)][, Ecm := sp$Ecm[k]]
  tr[is.na(k), Ecm := 0]                         # a code REF_SPECIES lacks: AM, as an unlisted genus
  tr <- tr[!is.na(Ecm)]                          # ERM and NM trees are not in the share
  r <- tr[, .(ba = sum(b), ecm = sum(b * Ecm)), by = .(PLT_CN, CONDID)]
  cat(sprintf("%s: %d trees, %d conditions (%.1f min)\n", s, nrow(tr), nrow(r), as.numeric(Sys.time() - t0, units = "mins"))); r }))
x <- merge(ba, cc, by = c("PLT_CN", "CONDID"))[ba > 0 & !is.na(grp)]
cat(sprintf("%d forest conditions with live trees joined to the condition table\n", nrow(x)))
# each condition weighted by its basal area (the share of basal area across the group's conditions)
eco <- fread(file.path(pkg, "defaults", "stsim", "stsim_Stratum.csv")); scl <- fread(file.path(pkg, "defaults", "stsim", "stsim_StateClass.csv"))
grp_name <- function(g) scl$Name[match(g, scl$Id)]
us <- x[, .(StratumId = NA_character_, Conditions = .N, EcmShare = sum(ecm) / sum(ba)), by = grp]
ed <- x[, .(Conditions = .N, EcmShare = sum(ecm) / sum(ba)), by = .(grp, ecodiv)][Conditions >= MIN_COND]
ed[, code := ifelse(grepl("^M", ecodiv), paste0(sub("^M", "", ecodiv), "1"), as.character(ecodiv))][, StratumId := eco$Name[match(code, as.character(eco$Id))]]   # mountain divisions: M240 = 2401
if (ed[is.na(StratumId), .N]) cat(sprintf("ecodivision codes not in the stratum list (dropped): %s\n", paste(ed[is.na(StratumId), unique(ecodiv)], collapse = ", ")))
out <- rbind(us, ed[!is.na(StratumId), .(grp, StratumId, Conditions, EcmShare)])
out[, StateClassId := grp_name(grp)]
if (out[is.na(StateClassId), .N]) cat(sprintf("forest type groups without a state class (dropped): %s\n", paste(out[is.na(StateClassId), unique(grp)], collapse = ", ")))
out <- out[!is.na(StateClassId)][order(StateClassId, !is.na(StratumId), StratumId), .(StateClassId, StratumId, Conditions, EcmShare = round(EcmShare, 3))]
fwrite(out, file.path(pkg, "defaults", "climate", "co2-ecm-share.csv"))
print(out[is.na(StratumId)])
