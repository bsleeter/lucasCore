# Experiment 11: young-stand carbon. lucasbuilder's route (stage 2 volume -> Boudewyn et al. 2007 CBM equations for the Canadian
# species/ecozone each US type is mapped to -> foliage and "other" smoothed for young ages -> roots from Li et al. 2003) against
# what FIA measured: live-tree carbon (aboveground + foliage + roots, saplings >= 1 in included) by stand age, same plots.
suppressPackageStartupMessages(library(data.table))
source("F:/lucasCore/src/growth.R")
P <- file.path(Sys.getenv("LOCALAPPDATA"), "SyncroSim/Packages/lucasbuilder/2.0.4/data")
rd <- function(f) fread(file.path(P, f))
spp <- rd("tblSpeciesTypeDefault.csv"); spu <- rd("tblSPUDefault.csv"); ecb <- rd("tblEcoBoundaryDefault.csv"); adm <- rd("tblAdminBoundaryDefault.csv")
ftt <- rd("tblForestTypeDefault.csv"); bsp <- rd("tblBioTotalStemwoodSpeciesTypeDefault.csv"); bgn <- rd("tblBioTotalStemwoodGenusDefault.csv"); bft <- rd("tblBioTotalStemwoodForestTypeDefault.csv")
map <- unique(fread("F:/lucas-builder/Data/LUCAS Carbon Budget Model/Spatial Unit and Species Type FIA Update.csv")[, .(EcoBoundaryId, AdminBoundaryId, SpeciesTypeId, StateClassId)], by = "StateClassId")

# lucasbuilder 2.0.4 2-flow-pathways.R L234-L780, ported (imputeTS spline/hyman interpolation -> stats::splinefun hyman)
lb_params <- function(m) {
  sid <- spp[SpeciesTypeName == m$SpeciesTypeId]; aid <- adm[AdminBoundaryName == m$AdminBoundaryId]
  spuid <- spu[AdminBoundaryID == aid$AdminBoundaryID & EcoBoundaryID == ecb[EcoBoundaryName == m$EcoBoundaryId, EcoBoundaryID], SPUID]
  row <- if (grepl("- Genus type", m$SpeciesTypeId)) bgn[DefaultSPUID == spuid & DefaultGenusID == sid$GenusID] else bsp[DefaultSPUID == spuid & DefaultSpeciesTypeID == sid$SpeciesTypeID]
  if (!nrow(row)) row <- bgn[DefaultSPUID == spuid & DefaultGenusID == sid$GenusID]
  if (!nrow(row)) row <- bft[DefaultSPUID == spuid & DefaultForestTypeID == sid$ForestTypeID]
  ft <- ftt[ForestTypeID == sid$ForestTypeID, ForestTypeName]
  list(row = row[1], ft = ft, top = aid[[paste0(ft, "TopProportion")]] / 100, stump = aid[[paste0(ft, "StumpProportion")]] / 100) }
smooth_young <- function(age, y, vol, minVolume) {
  min1 <- max(age[vol <= minVolume]); mins <- age[which(diff(sign(diff(y))) == 2)]
  m <- if (!length(mins) || min(mins) > 50) min1 else max(min1, min(mins))
  s <- ifelse(age <= m, NA, y); s[age == 0] <- 0
  ok <- !is.na(s)
  if (all(diff(s[ok]) >= 0)) s[!ok] <- stats::splinefun(age[ok], s[ok], method = "hyman")(age[!ok]) else s[!ok] <- stats::approx(age[ok], s[ok], age[!ok])$y
  s }
lb_carbon <- function(age, V, p) { r <- p$row
  b_m <- r$A * V^r$B
  nmf <- pmin(r$k_nonmerch + r$a_nonmerch * b_m^r$b_nonmerch, r$cap_nonmerch); b_nm <- nmf * b_m; b_n <- b_nm - b_m
  sf <- pmin(r$k_sap + r$a_sap * b_nm^r$b_sap, r$cap_sap); b_s <- sf * b_nm - b_nm
  b_sw <- b_m + b_n + b_s
  e1 <- exp(r$a1 + r$a2 * V + r$a3 * log(V + 5)); e2 <- exp(r$b1 + r$b2 * V + r$b3 * log(V + 5)); e3 <- exp(r$c1 + r$c2 * V + r$c3 * log(V + 5))
  den <- 1 + e1 + e2 + e3; b <- b_sw * den
  b_bark <- b * e1 / den; b_br <- b * e2 / den; b_fol <- b * e3 / den
  b_bark_m <- b_bark * b_m / b_sw; b_bark_ns <- b_bark * (b_n + b_s) / b_sw
  b_mC <- (b_m + b_bark_m) * (1 - p$top - p$stump)
  b_oth <- (b_m + b_bark_m) * (p$top + p$stump) + b_br + b_n + b_s + b_bark_ns
  fix <- function(z) { z[!is.finite(z)] <- 0; z }
  b_fol <- fix(b_fol); b_oth <- fix(b_oth); b_mC <- fix(b_mC)
  raw_ag <- b_mC + b_fol + b_oth
  b_folS <- smooth_young(age, b_fol, V, r$min_volume); b_othS <- smooth_young(age, b_oth, V, r$min_volume)
  ag <- b_mC + b_folS + b_othS
  roots <- if (p$ft == "Softwood") 0.222 * ag else 1.576 * ag^0.615
  data.table(age, V, c_merch = 0.5 * b_mC, c_foliage = 0.5 * b_folS, c_other = 0.5 * b_othS, c_roots = 0.5 * roots,
             c_live = 0.5 * (ag + roots), c_live_unsmoothed = 0.5 * (raw_ag + (if (p$ft == "Softwood") 0.222 * raw_ag else 1.576 * raw_ag^0.615))) }

# stage 2 curves and FIA live-tree carbon
cur <- fread("F:/lucasCore/dev/libs/growth-curves.csv"); par <- fread("F:/lucasCore/dev/libs/growth-parameters.csv")
codes <- fread("F:/lucas-master/Data Sources/FIA/EcoDivision_Strata.csv", colClasses = "character"); st <- fread("F:/lucasCore/defaults/stsim/stsim_Stratum.csv")
cur[, ecodiv := codes$ecodiv[match(as.character(st$Id[match(StratumId, st$Name)]), codes$StratumId)]]
cw <- fread("F:/lucasCore/defaults/growth/forest-type-crosswalk.csv", colClasses = "character")
D <- "F:/lucas-master/Data Sources/FIA/"
x <- as.data.table(readRDS(paste0(D, "USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds")))
x <- merge(x, as.data.table(readRDS(paste0(D, "USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds"))), by = c("plt_cn", "condid"))
x <- x[dstrbcd1 %in% 0 & trtcd1 %in% 0 & !is.na(stdage) & stdage >= 1 & stdage <= 400 & invyr >= 1997]
x[, pid := sprintf("%02d-%d-%03d-%05d", statecd, unitcd, countycd, plot)]; setorder(x, pid, condid, -invyr); x <- x[!duplicated(paste(pid, condid))]
x[, `:=`(c_live = c_total_all_live_trees_short_tons_per_acre * 2.2417, vol = net_merchantable_bole_wood_vol_live_trees_cuft_per_acre * 0.0699725, ecodiv = as.character(ecodiv))]

cells <- data.table(sc = c("160", "200", "500", "120", "220", "800", "100", "260"), ecodiv = c("230", "M240", "220", "210", "M330", "210", "210", "M240"))
ages <- c(5, 10, 15, 20, 30, 50, 80, 120)
out <- rbindlist(lapply(seq_len(nrow(cells)), function(i) { sc <- cells$sc[i]; e <- cells$ecodiv[i]; nm <- cw[StateClassId == sc, StateClassName]
  m <- map[StateClassId == paste0("Forest: ", nm)]; p <- lb_params(m)
  cv <- cur[StateClassId == paste0("Forest: ", nm) & ecodiv == e][order(Age)]
  lb <- lb_carbon(cv$Age, cv$MerchantableVolume, p)
  g <- as.integer(strsplit(cw[StateClassId == sc, FiaTypeGroups], ";")[[1]]); d <- x[fortyp_grp %in% g & ecodiv == e]
  lag <- par[StateClassId == paste0("Forest: ", nm)][1, Lag]
  rbindlist(lapply(ages, function(a) { w <- if (a <= 20) 2 else 5; o <- d[abs(stdage - a) <= w]
    data.table(type = nm, ecodiv = e, canadian_eq = paste(m$SpeciesTypeId, m$AdminBoundaryId, sep = ", "), lag = round(lag, 1), age = a, plots = nrow(o),
               fia_vol = round(mean(o$vol), 1), curve_vol = round(lb[age == a, V], 1),
               fia_liveC = round(mean(o$c_live), 1), lb_liveC = round(lb[age == a, c_live], 1), lb_unsmoothed = round(lb[age == a, c_live_unsmoothed], 1)) })) }))
fwrite(out, "F:/lucasCore/dev/growth/out_exp11_young_carbon.csv")
options(width = 220); print(out)
cat("\nratio lucasbuilder live C / FIA live C by age (median over cells)\n")
print(out[plots >= 20, .(cells = .N, median_ratio = round(median(lb_liveC / fia_liveC), 2), min = round(min(lb_liveC / fia_liveC), 2), max = round(max(lb_liveC / fia_liveC), 2),
                         fia_C_per_m3 = round(median(fia_liveC / pmax(fia_vol, 1)), 2)), by = age])
