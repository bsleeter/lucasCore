# =============================================================================
# make_grass_shrub.R - grassland and shrubland growth, soil decay and starting pools by ecodivision from a CONUS sample (to-do 39)
# =============================================================================
# Run from the package root: Rscript tools/make_grass_shrub.R
# Reads dev/nonforest/03-grass-shrub-sample.csv (dev/nonforest/03-grass-shrub-sample.R: RAP NPP 2014-2023 and gNATSGO soil in 3 x 3 km
# windows across CONUS, by class as stage 5 maps it) and, for each ecodivision x grassland or shrubland class:
#   targets   NPP = RAP herb + shrub NPP (the tree band left out); soil 0-30 cm and whole profile from gNATSGO. An ecodivision keeps its
#             own value with >= MIN_WINDOWS windows and >= MIN_CELLS cells of the class; otherwise the class's CONUS mean (all windows).
#             Shrubland: Post Fire Shrub (made by fire, not mapped) takes Shrubland: Non-sage's targets.
#   rates     literature only (defaults/stockflow/grass-shrub-literature.csv and chaparral-age.csv; the report "Grass and shrub turnover
#             and decay", user decisions 2026-11-06): growth split, live turnover and dead pool decay; CBM-CFS3's split of each dead
#             pool's loss; litter decay, AG Slow emission and soil decay solved so the ordered steady state (src/nonforest-solve.R)
#             holds the litter, AG Slow and gNATSGO whole-profile soil targets. Chaparral grows by age (see below). No IBIS value is used.
#   pools     the steady state of those rates (chaparral: by age after a high-severity fire). BG Slow holds the whole soil profile
#             (gNATSGO soc0_999), as it does for forest, agriculture and developed land; Deep Soil starts at 0 (user 2026-11-07: one soil
#             definition for every class; only wetland burial adds to Deep Soil)
# Writes the grass and shrub rows of defaults/stockflow/nonforest-multipliers-grassland-shrubland.csv and nonforest-net-growth.csv,
# defaults/initialstocks/grassland-shrubland.csv (by ecodivision), initialstocks/chaparral.csv (by ecodivision and age),
# defaults/stockflow/grass-shrub-targets.csv (the targets with their source and counts), grass-shrub-fit.csv and
# chaparral-growth-by-age.csv. Today's IBIS values are kept once in defaults/stockflow/legacy-ibis/ (the legacy choice); the carbon
# method presets lose their grass and shrub rows (a class-wide row would override the ecodivision values). Rerunning is harmless.
# =============================================================================
suppressPackageStartupMessages(library(data.table))
source("src/nonforest-solve.R")
MIN_WINDOWS <- 5L; MIN_CELLS <- 500L
d <- function(...) file.path("defaults", ...)
rd <- function(...) fread(d(...), colClasses = "character", na.strings = "", encoding = "UTF-8")
wr <- function(x, ...) fwrite(x, d(...), na = "", quote = "auto")

fm <- rd("stockflow", "nonforest-multipliers-grassland-shrubland.csv"); ng <- rd("stockflow", "nonforest-net-growth.csv")
pa <- rd("stockflow", "nonforest-pathways.csv"); memb <- rd("stockflow", "stsim_FlowTypeGroupMembership.csv"); ord <- rd("stockflow", "stsim_FlowOrder.csv")
st <- rd("initialstocks", "stock-types.csv"); GS <- sort(unique(fm$StateClassId)); ECO <- sort(unique(fm$StratumId))

# ---- keep the legacy values once ---------------------------------------------------------------------------------------------
L <- d("stockflow", "legacy-ibis"); dir.create(L, showWarnings = FALSE)
if (!file.exists(file.path(L, "grass-shrub-multipliers.csv"))) {
  wr(fm, "stockflow", "legacy-ibis", "grass-shrub-multipliers.csv")
  wr(ng[StateClassId %in% GS], "stockflow", "legacy-ibis", "grass-shrub-net-growth.csv")
  wr(rd("initialstocks", "grassland-shrubland.csv"), "stockflow", "legacy-ibis", "grass-shrub-initial-stocks.csv")
  for (m in c("cbm-defaults", "fia-measured")) for (f in c("nonforest-rates", "nonforest-growth")) {
    x <- rd("carbon-assumptions", m, paste0(f, ".csv")); wr(x[StateClassId %in% GS], "stockflow", "legacy-ibis", sprintf("preset-%s-%s-grass-shrub.csv", m, f)) }
  cat("Kept the legacy grassland and shrubland values in defaults/stockflow/legacy-ibis/\n") }
lm <- rd("stockflow", "legacy-ibis", "grass-shrub-multipliers.csv")

# ---- targets by ecodivision x class --------------------------------------------------------------------------------------------
s <- fread("dev/nonforest/03-grass-shrub-sample.csv")[is.na(error) & cells > 0]
s[, Npp := NppAnnual + NppPerennial + NppShrub]
agg <- function(x) x[, .(Windows = uniqueN(window), Cells = sum(cells), Treed = sum(treed, na.rm = TRUE), NPP = weighted.mean(Npp, nppCells, na.rm = TRUE),
                         NppTree = weighted.mean(NppTree, nppCells, na.rm = TRUE),
                         Soil0to30 = weighted.mean(Soil0to30, soilCells, na.rm = TRUE), Soil0to999 = weighted.mean(Soil0to999, soilCells, na.rm = TRUE)), by = StateClassId]
own <- s[, agg(.SD), by = StratumId]; conus <- agg(s)
tg <- CJ(StratumId = ECO, StateClassId = GS)
tg[, src := ifelse(StateClassId == "Shrubland: Post Fire Shrub", "Shrubland: Non-sage", StateClassId)]
tg <- merge(tg, own, by.x = c("StratumId", "src"), by.y = c("StratumId", "StateClassId"), all.x = TRUE)
tg[, Source := fifelse(!is.na(Windows) & Windows >= MIN_WINDOWS & Cells >= MIN_CELLS & is.finite(NPP) & is.finite(Soil0to999), "ecodivision sample", "CONUS class mean")]
cm <- conus[match(tg$src, StateClassId)]; fb <- which(tg$Source == "CONUS class mean")
for (k in c("NPP", "NppTree", "Soil0to30", "Soil0to999", "Windows", "Cells")) set(tg, i = fb, j = k, value = cm[[k]][fb])
tg[src != StateClassId, Source := paste(Source, "(Non-sage targets)")]
# ecodivisions where most NLCD 2001 grass and shrub cells are trees by 2014-2023 (RAP): their own values rest on the few cells left
tr <- fread("dev/nonforest/03-grass-shrub-sample.csv")[is.na(error), .(share = sum(treed, na.rm = TRUE) / (sum(cells) + sum(treed, na.rm = TRUE))), by = StratumId]
tg[, TreedShare := round(tr$share[match(StratumId, tr$StratumId)], 2)]
tg[startsWith(Source, "ecodivision") & TreedShare > 0.7, Source := paste(Source, "- few untreed cells (most of the ecodivision's NLCD 2001 grass and shrub is trees by 2014-2023)")]
tg[StateClassId == "Grassland: Irrigated Perennial", Source := paste(Source, "- small sample (RAP is not meant for irrigated land; alfalfa and irrigated pasture are Agriculture: Pasture)")]
if (anyNA(tg$NPP) || anyNA(tg$Soil0to999)) stop("no targets for: ", paste(unique(tg[is.na(NPP) | is.na(Soil0to999), src]), collapse = "; "))
# the soil target is the whole profile, in BG Slow (user 2026-11-07); Deep Soil starts at 0 (it is wetland burial only)
tg[, Deep := 0][, NPP := round(NPP, 4)]   # NPP as written, so the fit and the table agree


# ---- literature rates (defaults/stockflow/grass-shrub-literature.csv; report "Grass and shrub turnover and decay", user 2026-11-06) ----
# No IBIS value is used (IBIS stays the legacy choice in defaults/stockflow/legacy-ibis/): each class's growth split and live turnover,
# where turnover goes, and every dead pool's decay rate come from the literature table; each dead pool's loss is split between the
# atmosphere and the next pool as CBM-CFS3's defaults do (0.815 emitted for AG very fast, 0.83 for the other fast and medium pools; AG
# Slow: decay fully emitted plus 0.006/yr mixed into BG Slow; Kurz et al. 2009 via libcbm). Literature rates are continuous (k, per
# year): a year's fraction is 1 - exp(-k); dieback is a fraction of 1. Three values are solved so the ordered steady state holds a
# target: AG very fast litter's decay (aboveground litter, AG very fast + fast, = AgLitter), AG Slow's emission (= AgSlow) and BG Slow's
# emission (= the ecodivision's gNATSGO 0-30 cm soil). Turnover goes: foliage -> AG very fast; fine roots -> BG very fast; coarse
# roots -> BG fast; wood -> snag branches (SnagShareOfWood) and AG fast; a snag branch falls to AG fast (0.58 of its loss) or decays (0.42;
# CBM's fall 0.10 vs decay 0.0718). Live and litter rates are set once per class (and moisture) at the class's CONUS mean NPP; each
# ecodivision keeps them, so its live and litter carbon follow its NPP, and only its soil decay is its own.
lit <- rd("stockflow", "grass-shrub-literature.csv"); cp <- rd("stockflow", "chaparral-age.csv"); cpv <- setNames(as.numeric(cp$Value), cp$Parameter)
moist <- rd("stockflow", "ecodivision-moisture.csv"); tg[, Moisture := moist$Moisture[match(StratumId, moist$StratumId)]]
if (anyNA(tg$Moisture)) stop("no moisture class for: ", paste(unique(tg[is.na(Moisture), StratumId]), collapse = "; "))
frac <- function(k) 1 - exp(-k)
FOL <- "Biomass: Foliage"; WOOD <- "Biomass: Other Wood"; FR <- "Biomass: Fine Root"; CR <- "Biomass: Coarse Root"
AGVF <- "DOM: Aboveground Very Fast"; AGF <- "DOM: Aboveground Fast"; AGM <- "DOM: Aboveground Medium"; SB <- "DOM: Snag Branch"; SS <- "DOM: Snag Stem"
BGVF <- "DOM: Belowground Very Fast"; BGF <- "DOM: Belowground Fast"; AGS <- "DOM: Aboveground Slow"; BGS <- "DOM: Belowground Slow"
TY <- function(x) paste(x, "[Type]")
NG <- c(Foliage = TY("Net Growth Non Forest: Atmosphere -> Foliage"), Wood = TY("Net Growth Non Forest: Atmosphere -> Other Wood"), Fine = TY("Net Growth Non Forest: Atmosphere -> Fine Roots"),
        Coarse = TY("Net Growth Non Forest: Atmosphere -> Coarse Roots"), Merch = TY("Net Growth Non Forest: Atmosphere -> Merchantable"))
GROWTH_GROUPS <- unname(NG)
EM_SHARE <- c(AGVF = 0.815, other = 0.83); SNAG_FALL <- 0.10 / (0.10 + 0.0718)
params_of <- function(cls) { r <- lit[StateClassId == cls]; if (!nrow(r)) stop("no literature row for ", cls)
  if (!is.na(r$RatesOf)) { b <- params_of(r$RatesOf); b$AgLitter <- r$AgLitter; b$AgSlow <- r$AgSlow; b$StateClassId <- cls; return(b) }
  r }
# the class's rate table: every group of the class's flows, from the literature
lit_rates <- function(cls, moisture, shares = NULL) {
  r <- params_of(cls); g <- function(x) suppressWarnings(as.numeric(r[[x]]))
  m <- lm[StratumId == ECO[1] & StateClassId == cls, .(FlowGroupId, Value = 0)]
  set <- function(grp, v) { if (!grp %in% m$FlowGroupId) stop(cls, ": no group ", grp); m[FlowGroupId == grp, Value := v] }
  sh <- if (is.null(shares)) c(Foliage = g("ShareFoliage"), Wood = g("ShareWood"), Fine = g("ShareFineRoot"), Coarse = g("ShareCoarseRoot")) else shares
  for (k in names(sh)) set(NG[[k]], sh[[k]])
  set(TY("Biomass Turnover: Foliage -> AG Very Fast"), if (identical(r$kFoliage, "dieback")) 1 else frac(g("kFoliage")))
  if (!is.na(g("kWood"))) { fw <- frac(g("kWood")); s <- if (identical(r$SnagShareOfWood, "fit")) 0.5 else g("SnagShareOfWood")
    set(TY("Biomass Turnover: Other Wood -> Snag Branches"), fw * s); set(TY("Biomass Turnover: Other Wood -> AG Fast"), fw * (1 - s)) }
  set(TY("Biomass Turnover: Fine Roots -> BG Very Fast"), frac(g(if (moisture == "Moist") "kFineRootMoist" else "kFineRootDry")))
  if (!is.na(g("kCoarseRoot"))) set(TY("Biomass Turnover: Coarse Roots -> BG Fast"), frac(g("kCoarseRoot")))
  two <- function(pool, from_to_slow, k, em) { f <- frac(k); set(TY(sprintf("Emission: %s -> Atmosphere", pool)), f * em); set(TY(sprintf("Decay: %s", from_to_slow)), f * (1 - em)) }
  two("AG Very Fast", "AG Very Fast -> AG Slow", 0.5, EM_SHARE[["AGVF"]])                      # solved below
  two("AG Fast", "AG Fast -> AG Slow", if (is.na(g("kAgFast"))) 0.1435 else g("kAgFast"), EM_SHARE[["other"]])
  two("AG Medium", "AG Medium -> AG Slow", if (is.na(g("kAgMedium"))) 0.0374 else g("kAgMedium"), EM_SHARE[["other"]])
  two("BG Very Fast", "BG Very Fast -> BG Slow", g("kBgVeryFast"), EM_SHARE[["other"]])
  two("BG Fast", "BG Fast -> BG Slow", g("kBgFast"), EM_SHARE[["other"]])
  fs <- frac(if (is.na(g("kSnagBranch"))) 0.0718 + 0.10 else g("kSnagBranch"))
  set(TY("Transfer: Snag Branch -> AG Fast"), fs * SNAG_FALL); set(TY("Emission: Snag Branch -> Atmosphere"), fs * (1 - SNAG_FALL) * EM_SHARE[["other"]])
  set(TY("Decay: Snag Branch -> AG Slow"), fs * (1 - SNAG_FALL) * (1 - EM_SHARE[["other"]]))
  set(TY("Transfer: Snag Stem -> AG Medium"), 0.032); set(TY("Emission: Snag Stem -> Atmosphere"), 0.0187 * EM_SHARE[["other"]]); set(TY("Decay: Snag Stem -> AG Slow"), 0.0187 * (1 - EM_SHARE[["other"]]))
  set(TY("Emission: AG Slow -> Atmosphere"), 0.015); set(TY("Transfer: AG Slow -> BG Slow"), 0.006)
  set(TY("Emission: BG Slow -> Atmosphere"), 0.0033)
  m }
refnpp <- setNames(conus$NPP, conus$StateClassId); refnpp[["Shrubland: Post Fire Shrub"]] <- refnpp[["Shrubland: Non-sage"]]
path_of <- function(e, cls) pa[FromStratumId == e & FromStateClassId == cls]
loss_of <- function(p, m, pool) { g <- intersect(paste(unique(p[FromStockTypeId == pool, FlowTypeId]), "[Type]"), m$FlowGroupId); sum(m[FlowGroupId %in% g, Value]) }
# the litter target counts leaf and fine litter (AG very fast) for grass and the sage family (user 2026-11-06: Nagy et al. 2021 measured
# litter; fine woody debris follows its literature rate on its own), and AG very fast + fast for chaparral (its litter stocks include
# fine woody litter: Bohlman 2018, Riggan 1988)
fit_litter_slow <- function(p, m, npp, r) {
  m <- nf_fit_pool(p, m, memb, ord, npp, AGVF, as.numeric(r$AgLitter), over = if (identical(r$StateClassId, "Shrubland: Chaparral")) c(AGVF, AGF) else AGVF)$mult
  nf_fit_pool(p, m, memb, ord, npp, AGS, as.numeric(r$AgSlow), only = TY("Emission: AG Slow -> Atmosphere"))$mult }

# ---- chaparral by age (defaults/stockflow/chaparral-age.csv) ----------------------------------------------------------------
# Aboveground live at the end of the year the stand is `age`: AG(a) = AgMax x s x (1 - exp(-AgRate x (a + 1))), s = the ecodivision's
# NPP / the class's CONUS mean NPP (age 0 = the fire year: the fire resets the age, then that year's flows look up age 0). Foliage
# share f(a) = FoliageMature + FoliageYoung x exp(-FoliageDecline x (a + 1)); wood = the rest. Roots: RootShoot x mature aboveground at
# maturity, a share RootSurvival of them alive just after a fire, recovering on the aboveground curve's rate; FineRootShare of them fine.
# Turnover runs before growth (flow order 6, then 7), so growth that year is G_i(a) = B_i(a) - B_i(a - 1) x (1 - f_i); Net Growth by age
# is the sum, the growth split by age the shares; from AgeMax on the mature values. Standing dead: the share of wood turnover that stays
# standing is solved so snag branches hold SnagToLive x aboveground live at maturity. The package's high-severity fire rows for chaparral
# (defaults/stockflow/event-pathways.csv, written here) burn FireFoliage of foliage (rest to litter), FireWood of wood (rest standing),
# FireDead of litter and standing dead and FireAgSlow of AG Slow, and kill 1 - RootSurvival of the roots (to root litter). Starting pools
# by age: the mature steady state burned that way and grown on in ST-Sim's flow order (src/nonforest-solve.R nf_after_fire).
CHAP <- "Shrubland: Chaparral"; AGE_MAX <- as.integer(cpv[["AgeMax"]])
chap_live <- function(scale) { ag <- function(a) cpv[["AgMax"]] * scale * (1 - exp(-cpv[["AgRate"]] * (a + 1)))
  fsh <- function(a) cpv[["FoliageMature"]] + cpv[["FoliageYoung"]] * exp(-cpv[["FoliageDecline"]] * (a + 1))
  rm <- cpv[["RootShoot"]] * cpv[["AgMax"]] * scale; r0 <- cpv[["RootSurvival"]]
  root <- function(a) rm * (r0 + (1 - r0) * (1 - exp(-cpv[["AgRate"]] * (a + 1))))
  list(Foliage = function(a) if (a < 0) 0 else ag(a) * fsh(a), Wood = function(a) if (a < 0) 0 else ag(a) * (1 - fsh(a)),
       Fine = function(a) cpv[["FineRootShare"]] * (if (a < 0) r0 * rm else root(a)), Coarse = function(a) (1 - cpv[["FineRootShare"]]) * (if (a < 0) r0 * rm else root(a)),
       mature = c(Foliage = cpv[["AgMax"]] * scale * cpv[["FoliageMature"]], Wood = cpv[["AgMax"]] * scale * (1 - cpv[["FoliageMature"]]),
                  Fine = cpv[["FineRootShare"]] * rm, Coarse = (1 - cpv[["FineRootShare"]]) * rm)) }
POOL_OF <- c(Foliage = FOL, Wood = WOOD, Fine = FR, Coarse = CR)
chap_mature <- function(m, p, scale) { L <- chap_live(scale); f <- vapply(names(POOL_OF), function(i) loss_of(p, m, POOL_OF[[i]]), 1)
  G <- f * L$mature; list(npp = sum(G), shares = G / sum(G)) }
chap_rates <- function(p) {   # the class's rates at the CONUS mean NPP (scale 1), with the snag share and litter and AG Slow solved
  r <- params_of(CHAP); m <- lit_rates(CHAP, "Dry", shares = c(Foliage = 0.25, Wood = 0.25, Fine = 0.25, Coarse = 0.25))
  fw <- frac(as.numeric(r$kWood)); L <- chap_live(1)
  setsnag <- function(s) { m[FlowGroupId == TY("Biomass Turnover: Other Wood -> Snag Branches"), Value := fw * s]; m[FlowGroupId == TY("Biomass Turnover: Other Wood -> AG Fast"), Value := fw * (1 - s)] }
  grow <- function() { mt <- chap_mature(m, p, 1); for (k in names(mt$shares)) m[FlowGroupId == NG[[k]], Value := mt$shares[[k]]]; mt$npp }
  gap <- function(s) { setsnag(s); npp <- grow(); nf_steady(nf_flows(p, m, memb, ord), npp)$stock[[SB]] - cpv[["SnagToLive"]] * sum(L$mature[c("Foliage", "Wood")]) }
  if (sign(gap(1e-6)) == sign(gap(1))) stop(sprintf("chaparral: no share of wood turnover gives standing dead %.2f x aboveground live (%.2f at all-standing)", cpv[["SnagToLive"]], gap(1)))
  s <- uniroot(gap, c(1e-6, 1), tol = 1e-12)$root; setsnag(s); npp <- grow()
  m <- fit_litter_slow(p, m, npp, r)
  list(mult = m, snag_share = s, npp = npp) }
# Chaparral's high-severity fire as Carbon Assumptions: Disturbance Flows rows for the class (stage 3 builds every high-severity fire
# event from that sheet, or from the method's preset, defaults/carbon-assumptions/<method>/disturbance-flows.csv; a class's row for a
# from -> to pair hides the all-classes rows of that pair at every age, so every pair the presets' all-classes rows use gets a chaparral
# row, 0 where chaparral moves nothing). To = Atmosphere is the carbon burned (stage 3 splits it 90% CO2, 9% CO, 1% CH4).
fire_rows <- function() {
  gen <- rbindlist(lapply(c("cbm-defaults", "fia-measured"), function(m) rd("carbon-assumptions", m, "disturbance-flows.csv")))[Disturbance == "High-severity fire" & is.na(StratumId) & is.na(StateClassId)]
  burn <- c(setNames(rep(cpv[["FireDead"]], 4), c(AGVF, AGF, AGM, SB)), setNames(cpv[["FireFoliage"]], FOL), setNames(cpv[["FireWood"]], WOOD), setNames(cpv[["FireAgSlow"]], AGS), setNames(cpv[["FireDead"]], SS))
  keep <- c(setNames(1 - cpv[["FireFoliage"]], paste(FOL, AGVF)), setNames(1 - cpv[["FireWood"]], paste(WOOD, SB)),
            setNames(1 - cpv[["RootSurvival"]], paste(FR, BGVF)), setNames(1 - cpv[["RootSurvival"]], paste(CR, BGF)))
  pairs <- unique(rbind(unique(gen[, .(FromStockTypeId, ToStockTypeId)]),
                        data.table(FromStockTypeId = c(FOL, WOOD, FR, CR, names(burn)), ToStockTypeId = c(AGVF, SB, BGVF, BGF, rep("Atmosphere", length(burn))))))
  pairs[, Share := mapply(function(f, t) if (t == "Atmosphere") (if (f %in% names(burn)) burn[[f]] else 0) else { k <- paste(f, t); if (k %in% names(keep)) keep[[k]] else 0 }, FromStockTypeId, ToStockTypeId)]
  rows <- pairs[, .(StratumId = NA_character_, StateClassId = CHAP, Disturbance = "High-severity fire", AgeMin = NA_character_, FromStockTypeId, ToStockTypeId, Share = as.character(signif(Share, 6)))]
  list(rows = rows, fire = pairs[Share > 0, .(From = FromStockTypeId, To = ToStockTypeId, Share)]) }
FIRE <- fire_rows()
chap_age <- function(e, scale, m, deep) {
  p <- path_of(e, CHAP); L <- chap_live(scale); f <- vapply(names(POOL_OF), function(i) loss_of(p, m, POOL_OF[[i]]), 1)
  G <- t(vapply(0:(AGE_MAX - 1), function(a) vapply(names(POOL_OF), function(i) L[[i]](a) - L[[i]](a - 1) * (1 - f[[i]]), 1), f))
  mt <- chap_mature(m, p, scale)
  gr <- data.table(Age = 0:AGE_MAX, Growth = c(rowSums(G), mt$npp), Foliage = c(G[, "Foliage"] / rowSums(G), mt$shares[["Foliage"]]),
                   Wood = c(G[, "Wood"] / rowSums(G), mt$shares[["Wood"]]), Fine = c(G[, "Fine"] / rowSums(G), mt$shares[["Fine"]]), Coarse = c(G[, "Coarse"] / rowSums(G), mt$shares[["Coarse"]]))
  if (any(as.matrix(gr[, -1]) < 0)) stop("chaparral: negative growth at some age in ", e)
  rates_at <- function(a) { r <- gr[Age == min(a, AGE_MAX)]; x <- copy(m); for (k in names(POOL_OF)) x[FlowGroupId == NG[[k]], Value := r[[k]]]; x }
  growth_at <- function(a) gr[Age == min(a, AGE_MAX), Growth]
  S0 <- nf_steady(nf_flows(p, rates_at(AGE_MAX), memb, ord), mt$npp)$stock; S0[["Deep Soil"]] <- deep
  list(growth = gr, pools = nf_after_fire(p, memb, ord, rates_at, growth_at, S0, FIRE$fire, AGE_MAX), npp = mt$npp) }

# ---- class rates, then each ecodivision x class ------------------------------------------------------------------------------
refs <- list(); chap_ref <- NULL
own_rates <- lit[is.na(RatesOf), StateClassId]
for (cls in intersect(GS, own_rates)) for (mo in unique(tg$Moisture)) {
  p <- path_of(ECO[1], cls)
  if (cls == CHAP) { if (is.null(chap_ref)) chap_ref <- chap_rates(p); refs[[paste(cls, mo)]] <- chap_ref$mult; next }
  refs[[paste(cls, mo)]] <- fit_litter_slow(p, lit_rates(cls, mo), refnpp[[cls]], params_of(cls)) }
# a class with RatesOf takes that class's rates whole, its solved litter and AG Slow rates included (user 2026-11-06: Native Sage Steppe
# uses Sage's turnover, so its biomass and litter follow its NPP; its AgLitter row is then not used); only its soil decay is its own
src_of <- function(cls) { r <- lit[StateClassId == cls, RatesOf]; if (is.na(r)) cls else src_of(r) }
for (cls in setdiff(GS, own_rates)) for (mo in unique(tg$Moisture)) refs[[paste(cls, mo)]] <- refs[[paste(src_of(cls), mo)]]
fits <- list(); newm <- list(); pools <- list(); chap_g <- list(); chap_p <- list()
for (i in seq_len(nrow(tg))) {
  e <- tg$StratumId[i]; cls <- tg$StateClassId[i]; p <- path_of(e, cls); m0 <- refs[[paste(cls, tg$Moisture[i])]]
  scale <- tg$NPP[i] / refnpp[[cls]]; npp <- if (cls == CHAP) chap_ref$npp * scale else tg$NPP[i]
  m1 <- nf_fit_pool(p, m0, memb, ord, npp, BGS, tg$Soil0to999[i])$mult; m1[, Value := signif(Value, 8)]
  ss <- nf_steady(nf_flows(p, m1, memb, ord), npp)
  newm[[i]] <- copy(m1)[, `:=`(StratumId = e, StateClassId = cls)]
  if (cls == CHAP) { ca <- chap_age(e, scale, m1, tg$Deep[i]); chap_g[[e]] <- ca$growth[, StratumId := e]; chap_p[[e]] <- ca$pools[, StratumID := e] }
  else pools[[i]] <- data.table(StratumID = e, StateClassID = cls, pool = c(names(ss$stock), "Deep Soil"), Value = c(ss$stock, tg$Deep[i]))
  st0 <- ss$stock; lv <- st0[grep("^Biomass", names(st0))]
  fits[[i]] <- data.table(StratumId = e, StateClassId = cls, Moisture = tg$Moisture[i], RapNPP = round(tg$NPP[i], 4), ModelNPP = round(npp, 4),
                          Live = round(sum(lv), 3), Aboveground = round(sum(lv[intersect(c(FOL, WOOD), names(lv))]), 3), Roots = round(sum(lv[intersect(c(FR, CR), names(lv))]), 3),
                          AgLitter = round(sum(st0[intersect(c(AGVF, AGF), names(st0))]), 3), StandingDead = round(sum(st0[intersect(c(SB, SS), names(st0))]), 3),
                          AgSlow = round(st0[[AGS]], 3), Soil = round(st0[[BGS]], 2), DeepSoil = round(tg$Deep[i], 2),
                          AgVeryFastDecay = signif(loss_of(p, m1, AGVF), 4), AgSlowEmission = signif(m1[FlowGroupId == TY("Emission: AG Slow -> Atmosphere"), Value], 4),
                          SoilEmission = signif(loss_of(p, m1, BGS), 4)) }
fits <- rbindlist(fits); newm <- rbindlist(newm); pools <- rbindlist(pools); chap_g <- rbindlist(chap_g); chap_p <- rbindlist(chap_p)

# ---- write -------------------------------------------------------------------------------------------------------------------
fm2 <- copy(lm)[, AgeMin := as.character(AgeMin)][, AgeMax := as.character(AgeMax)]
fm2[newm[, .(StratumId, StateClassId, FlowGroupId, v = as.character(Value))], on = .(StratumId, StateClassId, FlowGroupId), Value := i.v]
cg <- rbindlist(lapply(names(NG), function(k) chap_g[, .(StratumId, Age, FlowGroupId = NG[[k]], Value = if (k == "Merch") 0 else get(k))]))
cg[, `:=`(StateClassId = CHAP, AgeMin = as.character(Age), AgeMax = as.character(ifelse(Age == AGE_MAX, NA, Age)), Value = as.character(signif(Value, 8)))][, Age := NULL]
fm2 <- rbind(fm2[!(StateClassId == CHAP & FlowGroupId %in% GROWTH_GROUPS)], cg, fill = TRUE)
setorder(fm2, StratumId, StateClassId, FlowGroupId, na.last = FALSE)
wr(fm2, "stockflow", "nonforest-multipliers-grassland-shrubland.csv")
ng[fits, on = .(StratumId, StateClassId), Value := as.character(i.ModelNPP)]
tmpl <- ng[StateClassId == CHAP][1]
chg <- chap_g[, .(StratumId, AgeMin = as.character(Age), AgeMax = as.character(ifelse(Age == AGE_MAX, NA, Age)), Value = as.character(round(Growth, 5)))]
chg <- cbind(tmpl[rep(1, nrow(chg)), setdiff(names(ng), c("StratumId", "AgeMin", "AgeMax", "Value")), with = FALSE], chg)[, StateClassId := CHAP]
ng <- rbind(ng[StateClassId != CHAP], chg, fill = TRUE)[, names(ng), with = FALSE]
wr(ng, "stockflow", "nonforest-net-growth.csv")
attr_of <- setNames(st$Attribute, st$StockTypeId)
pools[, StateAttributeTypeID := attr_of[pool]]
if (anyNA(pools$StateAttributeTypeID)) stop("a pool has no attribute in stock-types.csv")
out <- pools[, .(StratumID, StateClassID, StateAttributeTypeID, AgeMin = NA_character_, AgeMax = NA_character_, Value = as.character(round(Value, 4)))]
wr(out[order(StratumID, StateClassID, StateAttributeTypeID)], "initialstocks", "grassland-shrubland.csv")
chap_p <- chap_p[pool %in% names(attr_of)][, `:=`(StateClassID = CHAP, StateAttributeTypeID = attr_of[pool])]
wr(chap_p[, .(StratumID, StateClassID, StateAttributeTypeID, AgeMin = as.character(Age), AgeMax = as.character(ifelse(Age == AGE_MAX, NA, Age)), Value = as.character(round(pmax(Value, 0), 4)))][
  order(StratumID, StateAttributeTypeID, as.integer(AgeMin))], "initialstocks", "chaparral.csv")
# chaparral's fire rows (and every other grass, shrub and emergent wetland class's) are written by tools/make_nonforest_fire.R from
# defaults/stockflow/nonforest-fire.csv and chaparral-age.csv; FIRE above is the same high-severity fire, for the starting pools
wr(tg[, .(StratumId, StateClassId, Source, Moisture, Windows, Cells, TreedCellsLeftOut = Treed, EcodivisionTreedShare = TreedShare, NPP = round(NPP, 4), NppTree = round(NppTree, 4),
          Soil0to30 = round(Soil0to30, 2), Soil0to999 = round(Soil0to999, 2), DeepSoil = round(Deep, 2))], "stockflow", "grass-shrub-targets.csv")
wr(fits, "stockflow", "grass-shrub-fit.csv")
wr(chap_g[, .(StratumId, Age, Growth = round(Growth, 5), FoliageShare = round(Foliage, 5), WoodShare = round(Wood, 5), FineRootShare = round(Fine, 5), CoarseRootShare = round(Coarse, 5))],
   "stockflow", "chaparral-growth-by-age.csv")
for (m in c("cbm-defaults", "fia-measured")) for (f in c("nonforest-rates", "nonforest-growth")) {
  x <- rd("carbon-assumptions", m, paste0(f, ".csv")); wr(x[!StateClassId %in% GS], "carbon-assumptions", m, paste0(f, ".csv")) }
cat(sprintf("chaparral: standing share of wood turnover %.3f; mature NPP at the CONUS mean %.2f Mg C/ha/yr (RAP %.2f)\n", chap_ref$snag_share, chap_ref$npp, refnpp[[CHAP]]))
print(fits[, .(n = .N, RapNPP = round(median(RapNPP), 2), ModelNPP = round(median(ModelNPP), 2), Live = round(median(Live), 2), AG = round(median(Aboveground), 2), Roots = round(median(Roots), 2),
               Litter = round(median(AgLitter), 2), Dead = round(median(StandingDead), 2), AgS = round(median(AgSlow), 2), LitterK = round(median(AgVeryFastDecay), 3)), by = .(StateClassId, Moisture)])
