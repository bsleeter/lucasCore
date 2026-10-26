# =============================================================================
# 02-pools-fia.R - why lucasCore's roots + foliage and dead wood are about half of NFCMS's (P26, 2020): FIA plots as the referee
# =============================================================================
# Pool by pool and per forest type (Mg C/ha):
#   FIA       the USGS condition table stages 2-3 fit to (down dead as in it), P26's counties, undisturbed or not, latest visit per
#             plot-condition from 2001: wood = c_ag (live aboveground, no foliage), foliage, roots = c_bg (coarse roots; FIA has no
#             fine roots), standing dead (aboveground), down dead, litter, soil organic, understory
#   lucasCore result 14's 2020 average stock maps on its 2020 forest cells: wood = Merchantable + Other Wood, foliage, roots =
#             Coarse + Fine Root, standing dead = Snag Stem + Snag Branch, down dead = DOM: Deadwood - standing, litter, soil
#   NFCMS     3.0 2020 (01-p26-2020.R's rasters): wood = AbovegroundBiomass, roots + foliage = LiveBiomass - AbovegroundBiomass, dead +
#             litter = TotalEcosystemCarbon - LiveBiomass - SoilCarbon
# Writes dev/nfcms/out/pools-by-type.csv. Read-only.
# Usage: Rscript dev/nfcms/02-pools-fia.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(DBI) })
lib <- "F:/lucasCore/dev/libs/LUCAS P26 Demo Library.ssim"; dd <- paste0(lib, ".data"); out <- "F:/lucasCore/dev/nfcms/out"; rid <- 14L; yr <- 2020L
con <- dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO)
avg <- as.data.table(dbGetQuery(con, sprintf("SELECT g.Name, o.Filename FROM stsim_OutputAverageSpatialStockGroup o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId WHERE o.ScenarioId = %d AND o.Timestep = %d", rid, yr)))
scf <- dbGetQuery(con, sprintf("SELECT Filename FROM stsim_OutputSpatialState WHERE ScenarioId = %d AND Timestep = %d AND Iteration = 1", rid, yr))$Filename
scl <- as.data.table(dbGetQuery(con, "SELECT Id, Name FROM stsim_StateClass"))
cty <- as.data.table(dbGetQuery(con, "SELECT DISTINCT SecondaryStratumId FROM stsim_OutputStratumState WHERE ScenarioId = 14")); ssn <- as.data.table(dbGetQuery(con, "SELECT SecondaryStratumId, Id FROM stsim_SecondaryStratum"))
dbDisconnect(con)
fips <- ssn[SecondaryStratumId %in% cty$SecondaryStratumId, Id] %% 1e5   # universal county id -> state x 1000 + county
fp <- function(f) list.files(file.path(dd, sprintf("Scenario-%d", rid)), paste0("^", gsub("[.]", "[.]", basename(f)), "$"), recursive = TRUE, full.names = TRUE)[1]
g <- function(nm) Reduce(`+`, lapply(avg[Name %in% nm, Filename], function(x) rast(fp(x))))
S <- rast(fp(scf))
L <- list(wood = g(c("Biomass: Merchantable [Type]", "Biomass: Other Wood [Type]")), foliage = g("Biomass: Foliage [Type]"), roots = g(c("Biomass: Coarse Root [Type]", "Biomass: Fine Root [Type]")),
          standing = g(c("DOM: Snag Stem [Type]", "DOM: Snag Branch [Type]")), dead = g("DOM: Deadwood"), litter = g("DOM: Litter"), soil = g("DOM: Soil"))
L$down <- L$dead - L$standing
nf <- function(k) rast(file.path(out, sprintf("%s-%d-lucas-nfcms-diff.tif", k, yr)))[["nfcms"]]
N <- list(wood = nf("agb"), live = nf("live"), soil = nf("soil"), tec = nf("tec"))
v <- data.table(sc = values(S, mat = FALSE))
for (k in names(L)) v[, (paste0("l_", k)) := values(L[[k]], mat = FALSE)]
for (k in names(N)) v[, (paste0("n_", k)) := values(N[[k]], mat = FALSE)]
v <- v[!is.na(sc) & sc >= 100 & sc <= 999 & !is.na(n_tec)]

# ---- FIA plots in P26's counties --------------------------------------------------------------------------------------------
f <- 2.2417
x <- as.data.table(readRDS("F:/lucas-master/Data Sources/FIA/USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds"))[(statecd * 1000 + countycd) %in% fips & invyr >= 2001 & invyr < 9999]
x[, pid := paste(statecd, unitcd, countycd, plot)]; setorder(x, pid, condid, -invyr); x <- x[!duplicated(paste(pid, condid))]
# each FIA type group to its own state class (a class fitted on pooled groups, as Western White Pine, takes only groups with no class)
cw <- fread("F:/lucasCore/defaults/growth/forest-type-crosswalk.csv")[, .(fortyp_grp = as.integer(unlist(strsplit(as.character(FiaTypeGroups), ";")))), by = StateClassId]
cw <- cw[order(fortyp_grp != StateClassId)][!duplicated(fortyp_grp)]
x <- merge(x, cw, by = "fortyp_grp"); x[, sc := StateClassId]
fia <- x[, .(plots = .N, wood = mean(c_ag_all_live_trees_short_tons_per_acre * f), foliage = mean(c_foliage_all_live_trees_short_tons_per_acre * f), roots = mean(c_bg_all_live_trees_short_tons_per_acre * f),
             standing = mean(c_ag_standing_dead_trees_short_tons_per_acre * f), down = mean(c_down_dead_tons_per_acre * f), litter = mean(c_litter_tons_per_acre * f),
             soil = mean(c_soil_org_tons_per_acre * f), understory = mean(c_understory_total_tons_per_acre * f)), by = sc]
fia_all <- x[, .(sc = 0L, plots = .N, wood = mean(c_ag_all_live_trees_short_tons_per_acre * f), foliage = mean(c_foliage_all_live_trees_short_tons_per_acre * f), roots = mean(c_bg_all_live_trees_short_tons_per_acre * f),
                 standing = mean(c_ag_standing_dead_trees_short_tons_per_acre * f), down = mean(c_down_dead_tons_per_acre * f), litter = mean(c_litter_tons_per_acre * f),
                 soil = mean(c_soil_org_tons_per_acre * f), understory = mean(c_understory_total_tons_per_acre * f))]
lu <- function(d) d[, .(cells = .N, wood = mean(l_wood), foliage = mean(l_foliage), roots = mean(l_roots), standing = mean(l_standing), down = mean(l_down), litter = mean(l_litter), soil = mean(l_soil),
                        n_wood = mean(n_wood), n_rootsfol = mean(n_live - n_wood), n_dead = mean(n_tec - n_live - n_soil), n_soil = mean(n_soil))]
lc <- rbind(lu(v)[, sc := 0L], v[, lu(.SD), by = sc])

# ---- the table --------------------------------------------------------------------------------------------------------------
t <- merge(rbind(fia_all, fia), lc, by = "sc", suffixes = c(".fia", ".lucas"))[, StateClass := ifelse(sc == 0, "All forest", scl$Name[match(sc, scl$Id)])]
r1 <- function(z) round(z, 1)
show <- t[order(-cells), .(StateClass, plots, km2 = round(cells * 0.0225),
  wood_fia = r1(wood.fia), wood_lucas = r1(wood.lucas), wood_nfcms = r1(n_wood),
  rootsfol_fia = r1(foliage.fia + roots.fia), rootsfol_lucas = r1(foliage.lucas + roots.lucas), rootsfol_nfcms = r1(n_rootsfol),
  rootsfol_share_fia = round((foliage.fia + roots.fia) / wood.fia, 2), rootsfol_share_lucas = round((foliage.lucas + roots.lucas) / wood.lucas, 2), rootsfol_share_nfcms = round(n_rootsfol / n_wood, 2),
  dead_fia = r1(standing.fia + down.fia + litter.fia), dead_lucas = r1(standing.lucas + down.lucas + litter.lucas), dead_nfcms = r1(n_dead),
  soil_fia = r1(soil.fia), soil_lucas = r1(soil.lucas), soil_nfcms = r1(n_soil), understory_fia = r1(understory))]
fwrite(show, file.path(out, "pools-by-type.csv"))
print(show[plots >= 20 | StateClass == "All forest", .(StateClass, plots, km2, wood_fia, wood_lucas, wood_nfcms, rootsfol_fia, rootsfol_lucas, rootsfol_nfcms, rootsfol_share_fia, rootsfol_share_lucas, rootsfol_share_nfcms)])
print(show[plots >= 20 | StateClass == "All forest", .(StateClass, dead_fia, dead_lucas, dead_nfcms, soil_fia, soil_lucas, soil_nfcms, understory_fia)])
d <- t[sc == 0]
cat(sprintf("\nDead pools, all forest (Mg C/ha)  FIA: standing %.1f, down %.1f (x 1/0.7 = %.1f as in current FIADB), litter %.1f | lucasCore: standing %.1f, down %.1f, litter %.1f\n",
            d$standing.fia, d$down.fia, d$down.fia / 0.7, d$litter.fia, d$standing.lucas, d$down.lucas, d$litter.lucas))
cat(sprintf("Roots and foliage, all forest  FIA: foliage %.1f, roots %.1f | lucasCore: foliage %.1f, roots %.1f\n", d$foliage.fia, d$roots.fia, d$foliage.lucas, d$roots.lucas))
