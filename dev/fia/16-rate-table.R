# =============================================================================
# 16-rate-table.R - the values a P26 forest stand runs with, laid out for a user-facing sheet (to-do 20), in three scopes:
#   region   (ecodivision) mean annual temperature; per DOM pool: CBM base decay rate at 10 C, Q10, rate at the region's temperature,
#            multiplier and resulting rate, split to the next pool vs the atmosphere - for CBM, the regional calibration (one set for
#            every type, out-cal-regional) and each type's own calibration (out-cal-clearcut)
#   type     live turnover rates and splits, measured snag fall, high-severity fire snag share, growth and carbon curve values
#   events   high-severity fire and clearcut: share of each pool moved to each destination (proposed flows, event-pathways-fitted2 plus
#            the per-type fire snag share), by stand age where the flows differ
# Read-only. Writes dev/fia/out-cal-clearcut/rate-table-{region,type,events}.csv and prints California Mixed Conifer.
# Usage: Rscript dev/fia/16-rate-table.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(DBI) })
pkg <- "F:/lucasCore"; cbm <- file.path(pkg, "defaults/cbm"); out <- file.path(pkg, "dev/fia/out-cal-clearcut")
for (f in c("growth.R", "flows.R", "dom.R", "calibrate.R")) source(file.path(pkg, "src", f))
r <- readRDS(file.path(out, "calibration.rds")); reg <- readRDS(file.path(pkg, "dev/fia/out-cal-regional/regional-decay.rds"))$mult
SNAG_FALL <- fread(file.path(pkg, "dev/fia/snag-fall-measured.csv")); FIRE_SNAG <- fread(file.path(pkg, "dev/fia/fire-snag-share.csv"))
FALLS <- c("Transfer: Snag Stem -> AG Medium", "Transfer: Snag Branch -> AG Fast")
G_NEW <- list(snag = c("SnagStem", "SnagBranch"), cwd = c("AGM", "BGF"), fwd = "AGF", litter = "AGVF", duff = "AGS", soil = c("BGVF", "BGS"))
grp_of <- function(p) names(G_NEW)[sapply(G_NEW, function(g) p %in% g)]
con <- dbConnect(RSQLite::SQLite(), file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim"), flags = RSQLite::SQLITE_RO); q <- function(s) as.data.table(dbGetQuery(con, s))
scl <- q("SELECT StateClassId, Name, Id FROM stsim_StateClass"); stl <- q("SELECT StratumId, Name FROM stsim_Stratum")
gp <- q("SELECT * FROM lucasCore_OutputGrowthParameter WHERE ScenarioId = 2"); cc <- q("SELECT * FROM lucasCore_CarbonCurve WHERE ScenarioId = 2"); dbDisconnect(con)
for (t in list(gp, cc)) t[, `:=`(Stratum = stl$Name[match(StratumId, stl$StratumId)], StateClass = scl$Name[match(StateClassId, scl$StateClassId)])]
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv")); dens <- fread(file.path(pkg, "defaults/growth/merch-carbon-density.csv"))
par <- fread(file.path(cbm, "tblDOMParametersDefault.csv")); slow_ag_bg <- fread(file.path(cbm, "tblSlowAGToBGTransferRate.csv"))$SlowAGToBGTransferRate
temp <- r$cells$temp[1]; nice <- function(s) sub("^DOM: ", "", s)

# ---- region: DOM pools ---------------------------------------------------------------------------------------------------------
POOL_ID <- c(AGVF = 0, BGVF = 1, AGF = 2, BGF = 3, AGM = 4, AGS = 5, BGS = 6, SnagStem = 7, SnagBranch = 8)   # softwood snags (P26 types: 3 softwood, oak uses 9/10 = same rates)
region <- rbindlist(lapply(names(POOL_ID), function(p) { z <- par[SoilPoolID == POOL_ID[[p]]]
  at <- min(1, z$OrganicMatterDecayRate * exp((temp - z$ReferenceTemp) * log(z$Q10) * 0.1)); g <- grp_of(p)
  mr <- if (g %in% names(reg)) reg[[g]] else 1
  data.table(Ecodivision = "M260", MeanTempC = round(temp, 2), Pool = nice(DOM_POOLS[[p]]), BaseRate10C = z$OrganicMatterDecayRate, Q10 = z$Q10,
             RateAtTemp = at, PctEmitted = 100 * z$PropToAtmosphere, PctToNextPool = 100 * (1 - z$PropToAtmosphere),
             NextPool = c(AGVF = "AG Slow", BGVF = "BG Slow", AGF = "AG Slow", BGF = "BG Slow", AGM = "AG Slow", AGS = "-", BGS = "-", SnagStem = "AG Slow", SnagBranch = "AG Slow")[[p]],
             RegionalMultiplier = mr, RegionalRate = at * mr) }))
region[Pool == "Aboveground Slow", Note := sprintf("plus a fixed transfer to BG Slow of %.3f /yr", slow_ag_bg)]
region[Pool %in% c("Belowground Very Fast", "Belowground Slow"), Note := "soil: fitted per cell to gSSURGO in stage 3 (not in this dev fit)"]
region[grepl("Snag", Pool), Note := "decay while standing; fall is a forest type value"]
tm <- rbindlist(lapply(seq_len(nrow(r$cells)), function(i) { k <- r$cells[i]; m <- r$M[[as.character(k$sc)]]$mult
  data.table(Pool = region$Pool, ForestType = gsub("Forest: | Group", "", k$StateClass), TypeMultiplier = sapply(names(POOL_ID), function(p) { g <- grp_of(p); if (g %in% names(m)) m[[g]] else 1 })) }))
fwrite(region, file.path(out, "rate-table-region.csv")); fwrite(tm, file.path(out, "rate-table-type-multipliers.csv"))

# ---- forest type: live turnover, snags, growth -----------------------------------------------------------------------------------
type <- rbindlist(lapply(seq_len(nrow(r$cells)), function(i) { k <- r$cells[i]; w <- cw[StateClassId == k$sc]; sw <- grepl("Softwood$", w$LagClass)
  rt <- turnover_rates(k$StateClass, sw, as.numeric(dens[StateClassId == k$sc, DeciduousShare]), cbm); st0 <- k$Stratum; sc0 <- k$StateClass; g <- gp[Stratum == st0 & StateClass == sc0]
  c1 <- cc[Stratum == st0 & StateClass == sc0][order(Age)]; at <- function(a) c1[Age == a]
  sf <- SNAG_FALL[Group == k$sc, StemFall]; bf <- rt$branch_snag_to_dom * sf / rt$stem_snag_to_dom; fs <- FIRE_SNAG[Group == k$sc, Share]
  v <- list(
    c("Live turnover", "Foliage", rt$foliage, "100% to AG Very Fast", "CBM ecozone x species (deciduous-weighted)"),
    c("Live turnover", "Branch (other wood)", rt$branch, sprintf("%.0f%% to Snag Branch, %.0f%% to AG Fast", 100 * rt$branch_to_snag, 100 * (1 - rt$branch_to_snag)), "CBM"),
    c("Live turnover", "Stem (merchantable)", rt$stem, "100% to Snag Stem", "CBM"),
    c("Live turnover", "Fine root", rt$fine, "50% to AG Very Fast, 50% to BG Very Fast", "CBM"),
    c("Live turnover", "Coarse root", rt$coarse, "50% to AG Fast, 50% to BG Fast", "CBM"),
    c("Snags", "Stem snag fall", sf, "to AG Medium", "FIA remeasured standing dead (12-snag-fall.R)"),
    c("Snags", "Branch snag fall", bf, "to AG Fast", "CBM branch rate x the stem ratio"),
    c("Snags", "High-severity fire: share of live wood left as snags", fs, sprintf("stem %.3f, branch %.3f of the pool", fs * 0.65 / 0.545, fs * 0.30 / 0.545), "fitted to FIA snags 0-20 yr after fire (14)"),
    c("Growth", "Volume curve A (m3/ha)", g$A, "V = A (1 - exp(-k (t - L)^c))", sprintf("%s, %d plots", g$Method, g$Plots)),
    c("Growth", "Volume curve k", g$k, "", ""), c("Growth", "Volume curve c", g$c, "", "shared by the type's ecodivisions"),
    c("Growth", "Lag L (yr)", g$Lag, "", g$LagSource),
    c("Growth", "Merchantable carbon density (Mg C/m3)", dens[StateClassId == k$sc, MgCPerM3], "", "FIA wood/bark specific gravity of the type's species"),
    c("Growth", "Deciduous share", dens[StateClassId == k$sc, DeciduousShare], "weights foliage fall", "FIA species volume"),
    c("Growth", "Live carbon at 50 / 100 / 150 yr (Mg C/ha)", at(100)$TotalLive, sprintf("%.0f / %.0f / %.0f", at(50)$TotalLive, at(100)$TotalLive, at(150)$TotalLive), "stage 2 carbon curve"),
    c("Growth", "Pool shares at 100 yr", NA, with(at(100), sprintf("merch %.0f%%, other %.0f%%, foliage %.0f%%, coarse root %.0f%%, fine root %.0f%%",
       100 * Merchantable / TotalLive, 100 * Other / TotalLive, 100 * Foliage / TotalLive, 100 * CoarseRoots / TotalLive, 100 * FineRoots / TotalLive)), "stage 2 share curves"))
  d <- as.data.table(do.call(rbind, v)); setnames(d, c("Group", "Item", "Value", "Detail", "Source"))
  d[, `:=`(ForestType = gsub("Forest: | Group", "", k$StateClass), Value = as.numeric(Value))]; d }))
fwrite(type, file.path(out, "rate-table-type.csv"))

# ---- events: high-severity fire and clearcut ----------------------------------------------------------------------------------
ev <- fread(file.path(pkg, "dev/fia/event-pathways-fitted2.csv"), na.strings = "")
EVG <- c(`Fire: High Severity [Type]` = "High-severity fire", `Forest Harvest: Forest Clearcut [Type]` = "Clearcut")
events <- rbindlist(lapply(seq_len(nrow(r$cells)), function(i) { k <- r$cells[i]; fs <- FIRE_SNAG[Group == k$sc, Share]
  rbindlist(lapply(names(EVG), function(gname) rbindlist(lapply(c(5, 50), function(age) {   # a young (0-10) and an older stand
    e <- ev[TransitionGroupId == gname & (is.na(FromStateClassId) | FromStateClassId == k$StateClass)]
    e[, amin := suppressWarnings(as.numeric(FromAgeMin))][is.na(amin), amin := 0]
    e <- e[amin <= age][, .SD[amin == max(amin)], by = .(FromStockTypeId, ToStockTypeId)]
    e[, Dest := fifelse(grepl("^Atmosphere", ToStockTypeId), "Atmosphere", nice(ToStockTypeId))]
    x <- e[, .(Share = sum(as.numeric(Multiplier))), by = .(From = nice(FromStockTypeId), Dest)]
    if (gname == names(EVG)[1] && age > 10) {   # the per-type snag share replaces the generic snag rows; the rest burns
      x[From == "Biomass: Merchantable" & Dest == "Snag Stem", Share := fs * 0.65 / 0.545]; x[From == "Biomass: Other Wood" & Dest == "Snag Branch", Share := fs * 0.30 / 0.545]
      for (p in c("Biomass: Merchantable", "Biomass: Other Wood")) x[From == p & Dest == "Atmosphere", Share := 1 - sum(x[From == p & Dest != "Atmosphere", Share])] }
    x[, .(ForestType = gsub("Forest: | Group", "", k$StateClass), Event = EVG[[gname]], StandAge = if (age > 10) "11+" else "0-10", From, Dest, Share)] }))))
  }))
events <- unique(events[order(ForestType, Event, StandAge, From, Dest)])
fwrite(events, file.path(out, "rate-table-events.csv"))
# the age split only matters for fire's live pools; print the older-stand rows plus fire's young-stand live rows
options(width = 220); cat("Region M260, mean temperature", round(temp, 2), "C\n"); print(region)
print(dcast(tm, Pool ~ ForestType, value.var = "TypeMultiplier"))
print(type[ForestType == "California Mixed Conifer", .(Group, Item, Value = signif(Value, 4), Detail, Source)])
w <- dcast(events[ForestType == "California Mixed Conifer"], Event + StandAge + From ~ Dest, value.var = "Share", fill = 0)
w[, Retained := 1 - rowSums(.SD), .SDcols = setdiff(names(w), c("Event", "StandAge", "From"))]; print(w[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 3) else z)])
