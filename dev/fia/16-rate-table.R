# =============================================================================
# 16-rate-table.R - the annual turnover and DOM rates each P26 forest type runs with, laid out by pool: CBM defaults (at the
# ecodivision's temperature), the current stage 3 calibration (re-run with the FIA grouping and the fire fix, 06's "current"), and the
# proposed measured-pool calibration (out-cal-clearcut: five decay multipliers, measured snag fall). For a user-facing rate table
# (region x forest type -> live turnover and DOM rates). Read-only; writes dev/fia/out-cal-clearcut/rate-table.csv.
# Usage: Rscript dev/fia/16-rate-table.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(DBI) })
pkg <- "F:/lucasCore"
for (f in c("growth.R", "flows.R", "dom.R", "calibrate.R")) source(file.path(pkg, "src", f))
r <- readRDS(file.path(pkg, "dev/fia/out-cal-clearcut/calibration.rds"))
SNAG_FALL <- fread(file.path(pkg, "dev/fia/snag-fall-measured.csv")); FALLS <- c("Transfer: Snag Stem -> AG Medium", "Transfer: Snag Branch -> AG Fast")
scale_with <- function(vals, mult, groups, fixed) {   # dom.R's scale_decay with given groups; 'fixed' flows keep their value
  fp <- FOREST_PATHWAYS[match(names(vals), FlowType)]; from <- names(DOM_POOLS)[match(fp$From, DOM_POOLS)]
  for (g in names(mult)) { k <- !is.na(from) & from %in% groups[[g]] & !names(vals) %in% c("Transfer: AG Slow -> BG Slow", fixed); vals[k] <- vals[k] * mult[[g]] }
  for (p in unique(na.omit(from))) { k <- !is.na(from) & from == p; t <- sum(vals[k]); if (t > 1) vals[k] <- vals[k] / t }
  vals }
G_CUR <- list(snag = c("SnagStem", "SnagBranch"), cwd = c("AGM", "BGF"), floor = c("AGVF", "AGF", "AGS"), soil = c("BGVF", "BGS"))
G_NEW <- list(snag = c("SnagStem", "SnagBranch"), cwd = c("AGM", "BGF"), fwd = "AGF", litter = "AGVF", duff = "AGS", soil = c("BGVF", "BGS"))
con <- dbConnect(RSQLite::SQLite(), file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim"), flags = RSQLite::SQLITE_RO)
scl <- as.data.table(dbGetQuery(con, "SELECT StateClassId, Name, Id FROM stsim_StateClass")); dbDisconnect(con)
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv")); dens <- fread(file.path(pkg, "defaults/growth/merch-carbon-density.csv"))
cw[, StateClass := scl$Name[match(StateClassId, scl$Id)]]
tab <- rbindlist(lapply(seq_len(nrow(r$cells)), function(i) { k <- r$cells[i]; sw <- grepl("Softwood$", cw[StateClassId == k$sc, LagClass])
  rt <- turnover_rates(k$StateClass, sw, as.numeric(dens[StateClassId == k$sc, DeciduousShare]), file.path(pkg, "defaults/cbm"))
  v0 <- dom_flow_values(rt, sw, k$temp, file.path(pkg, "defaults/cbm"))
  cur <- r$C[[as.character(k$sc)]]; vc <- scale_with(v0, list(snag = cur$snag, cwd = cur$cwd, floor = cur$floor), G_CUR, character())
  vn <- v0; vn[FALLS] <- vn[FALLS] * SNAG_FALL[Group == k$sc, StemFall] / v0[["Transfer: Snag Stem -> AG Medium"]]
  vn <- scale_with(vn, as.list(r$M[[as.character(k$sc)]]$mult), G_NEW, FALLS)
  fp <- FOREST_PATHWAYS[match(names(v0), FlowType)]
  data.table(Ecodivision = k$ecodiv, Stratum = k$Stratum, ForestType = sub("Forest: ", "", k$StateClass), TempC = round(k$temp, 1),
             From = fp$From, To = fp$To, FlowType = names(v0), CBM = unname(scale_with(v0, list(), G_CUR, character())), Current = unname(vc), Proposed = unname(vn)) }))
fwrite(tab, file.path(pkg, "dev/fia/out-cal-clearcut/rate-table.csv"))
options(width = 220); print(tab[ForestType == "California Mixed Conifer Group", .(From, To, CBM = round(CBM, 4), Current = round(Current, 4), Proposed = round(Proposed, 4))])
cat("temp", r$cells$temp[1], "\n"); print(r$cells)
