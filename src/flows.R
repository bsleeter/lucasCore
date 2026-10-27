# =============================================================================
# flows.R - forest stock-flow parameters from the stage 2 carbon curves (stage 3); no SyncroSim calls
# =============================================================================
# Ported from lucasbuilder 2.0.4 2-flow-pathways.R (CBM-CFS3 structure), with US inputs where they exist (2026-10-20):
#   net growth   lucasbuilder's mass balance on the stage 2 FIA carbon pools: g_pool(t) = C_pool(t+1) - (1 - r_pool) C_pool(t), where
#                r_pool is the pool's total turnover (turnover runs before growth in the flow order). Net Growth (state attribute)
#                = sum of g_pool; each growth flow takes g_pool / g_all. A pool that shrinks (other wood as merchantable volume
#                starts) gets a negative share, as in lucasbuilder and the CONUS 1km model (user decision 2026-10-20).
#   turnover     CBM rates through each class's CBM ecozone and species (defaults/cbm/species-crosswalk.csv): no FIA source for
#                stem, branch and root turnover. Foliage fall is weighted by the class's US deciduous share (FIA species volume,
#                defaults/growth/merch-carbon-density.csv): deciduous x hardwood rate + evergreen x softwood rate.
#                Softwood / hardwood (branch rate, snag pools) from the class's lag class (east/west x softwood/hardwood).
#   DOM decay    CBM base rate x Q10 temperature modifier at the ecodivision's PRISM mean annual temperature, capped at 1;
#                (1 - PropToAtmosphere) to the next pool, the rest emitted. Stage 3b calibrates these to FIA dead-carbon stocks.
# =============================================================================

LIVE_POOLS <- c(Merchantable = "Biomass: Merchantable", Other = "Biomass: Other Wood", Foliage = "Biomass: Foliage",
                FineRoots = "Biomass: Fine Root", CoarseRoots = "Biomass: Coarse Root")
GROWTH_FLOW <- c(Merchantable = "Net Growth Forest: Atmosphere -> Merchantable", Other = "Net Growth Forest: Atmosphere -> Other Wood",
                 Foliage = "Net Growth Forest: Atmosphere -> Foliage", FineRoots = "Net Growth Forest: Atmosphere -> Fine Roots",
                 CoarseRoots = "Net Growth Forest: Atmosphere -> Coarse Roots")

# turnover rates (per year) of one state class: from the CBM ecozone and species type given (stage 3: the Carbon Assumptions' CBM
# Crosswalk row of the cell), else the package default crosswalk (defaults/cbm/species-crosswalk.csv)
turnover_rates <- function(state_class_name, softwood, deciduous, cbm_dir, ecozone = NULL, species = NULL) {
  rd <- function(f) data.table::fread(file.path(cbm_dir, f))
  m <- if (!is.null(ecozone) && !is.null(species)) data.table::data.table(EcoBoundaryId = ecozone, SpeciesTypeId = species) else rd("species-crosswalk.csv")[StateClassId == state_class_name]
  if (nrow(m) != 1) stop(sprintf("species-crosswalk.csv has %d rows for %s", nrow(m), state_class_name), call. = FALSE)
  eco <- rd("tblEcoBoundaryDefault.csv")[EcoBoundaryName == m$EcoBoundaryId]; sp <- rd("tblSpeciesTypeDefault.csv")[SpeciesTypeName == m$SpeciesTypeId]
  if (nrow(eco) != 1 || nrow(sp) != 1) stop(sprintf("CBM ecozone or species not found for %s", state_class_name), call. = FALSE)
  sw <- if (softwood) "Softwood" else "Hardwood"
  list(stem = eco$StemAnnualTurnOverRate, branch = eco[[paste0(sw, "BranchTurnOverRate")]],
       foliage = deciduous * eco$HardwoodFoliageFallRate + (1 - deciduous) * eco$SoftwoodFoliageFallRate,
       branch_to_snag = sp$BranchesToBranchSnag, fine = sp$FineRootTurnPropSlope, coarse = sp$CoarseRootTurnProp,
       stem_snag_to_dom = eco[[paste0(sw, "StemSnagToDOM")]], branch_snag_to_dom = eco[[paste0(sw, "BranchSnagToDOM")]],
       source = paste(m$SpeciesTypeId, m$EcoBoundaryId, sep = ", ")) }

# total turnover of each live pool
pool_turnover <- function(r) c(Merchantable = r$stem, Other = r$branch, Foliage = r$foliage, FineRoots = r$fine, CoarseRoots = r$coarse)

# net growth by age from a cell's pools (data.table with Age and the five pool columns, ages 0..MaxAge)
net_growth <- function(pools, r) {
  p <- pools[order(Age)]; tr <- pool_turnover(r); n <- nrow(p)
  g <- sapply(names(LIVE_POOLS), function(k) p[[k]][-1] - (1 - tr[[k]]) * p[[k]][-n])
  g <- data.table::as.data.table(g); g[, Age := p$Age[-n]]; g[, Total := rowSums(.SD), .SDcols = names(LIVE_POOLS)]
  g[] }

# dead pool parameters (Carbon Assumptions: Dead Organic Matter Parameters; to-do 21): the sheet's labels and the pool codes
DOM_POOL_CODE <- c(`AG Very Fast` = "AGVF", `BG Very Fast` = "BGVF", `AG Fast` = "AGF", `BG Fast` = "BGF", `AG Medium` = "AGM", `AG Slow` = "AGS",
                   `BG Slow` = "BGS", `Snag Stem` = "SnagStem", `Snag Branch` = "SnagBranch")
# the package default table (defaults/cbm/dom-parameters.csv, CBM-CFS3's values), in the sheet's columns
dom_parameter_default <- function(cbm_dir) { x <- data.table::fread(file.path(cbm_dir, "dom-parameters.csv"), na.strings = "")
  x[, .(StratumId = NA_character_, Pool, BaseDecayRate, ReferenceTemperature, Q10, ShareEmitted, TransferToBGSlow = as.numeric(TransferToBGSlow))] }
# one ecodivision's parameters from a table in the sheet's columns: each pool's row for the stratum, else its blank-stratum row
dom_parameters <- function(tab, stratum = NA_character_) {
  x <- tab[!is.na(StratumId) & StratumId == stratum]; x <- rbind(x, tab[is.na(StratumId) & !Pool %in% x$Pool])
  miss <- setdiff(names(DOM_POOL_CODE), x$Pool); if (length(miss)) stop("Dead Organic Matter Parameters: no row for ", paste(miss, collapse = ", "), call. = FALSE)
  x <- x[match(names(DOM_POOL_CODE), Pool)]; k <- unname(DOM_POOL_CODE)
  list(rate = stats::setNames(x$BaseDecayRate, k), ref = stats::setNames(x$ReferenceTemperature, k), q10 = stats::setNames(x$Q10, k),
       patm = stats::setNames(x$ShareEmitted, k), slow_ag_bg = x[Pool == "AG Slow", TransferToBGSlow]) }

# turnover and DOM flow multipliers of one cell: flow type -> value (decay at temperature temp_c; decay_mult scales base decay rates);
# dp: the cell's dead pool parameters (dom_parameters), else the package default. Snag parameters serve softwood and hardwood alike.
dom_flow_values <- function(r, softwood, temp_c, cbm_dir, decay_mult = NULL, dp = NULL) {
  if (is.null(dp)) dp <- dom_parameters(dom_parameter_default(cbm_dir))
  slow_ag_bg <- if (length(dp$slow_ag_bg) && !is.na(dp$slow_ag_bg)) dp$slow_ag_bg else 0
  pools <- unname(DOM_POOL_CODE); names(pools) <- pools
  rate <- sapply(names(pools), function(k) {
    m <- if (!is.null(decay_mult) && !is.null(decay_mult[[k]])) decay_mult[[k]] else 1
    min(1, m * dp$rate[[k]] * exp((temp_c - dp$ref[[k]]) * log(dp$q10[[k]]) * 0.1)) })
  patm <- dp$patm
  dec <- function(k) (1 - patm[[k]]) * rate[[k]]; emi <- function(k) patm[[k]] * rate[[k]]
  c("Biomass Turnover: Merchantable -> Snag Stems" = r$stem,
    "Biomass Turnover: Other Wood -> Snag Branches" = r$branch * r$branch_to_snag,
    "Biomass Turnover: Other Wood -> AG Fast" = r$branch * (1 - r$branch_to_snag),
    "Biomass Turnover: Foliage -> AG Very Fast" = r$foliage,
    "Biomass Turnover: Fine Roots -> AG Very Fast" = r$fine * 0.5, "Biomass Turnover: Fine Roots -> BG Very Fast" = r$fine * 0.5,
    "Biomass Turnover: Coarse Roots -> AG Fast" = r$coarse * 0.5, "Biomass Turnover: Coarse Roots -> BG Fast" = r$coarse * 0.5,
    "Decay: AG Very Fast -> AG Slow" = dec("AGVF"), "Emission: AG Very Fast -> Atmosphere" = emi("AGVF"),
    "Decay: BG Very Fast -> BG Slow" = dec("BGVF"), "Emission: BG Very Fast -> Atmosphere" = emi("BGVF"),
    "Decay: AG Fast -> AG Slow" = dec("AGF"), "Emission: AG Fast -> Atmosphere" = emi("AGF"),
    "Decay: BG Fast -> BG Slow" = dec("BGF"), "Emission: BG Fast -> Atmosphere" = emi("BGF"),
    "Decay: AG Medium -> AG Slow" = dec("AGM"), "Emission: AG Medium -> Atmosphere" = emi("AGM"),
    "Emission: AG Slow -> Atmosphere" = emi("AGS"), "Transfer: AG Slow -> BG Slow" = slow_ag_bg,
    "Emission: BG Slow -> Atmosphere" = emi("BGS"),
    "Decay: Snag Stem -> AG Slow" = dec("SnagStem"), "Emission: Snag Stem -> Atmosphere" = emi("SnagStem"), "Transfer: Snag Stem -> AG Medium" = r$stem_snag_to_dom,
    "Decay: Snag Branch -> AG Slow" = dec("SnagBranch"), "Emission: Snag Branch -> Atmosphere" = emi("SnagBranch"), "Transfer: Snag Branch -> AG Fast" = r$branch_snag_to_dom) }

# the forest base flow pathways (one set per forest state class; values come from the multipliers)
FOREST_PATHWAYS <- data.table::fread(text = "From,To,FlowType,Attribute
Atmosphere,Biomass: Coarse Root,Net Growth Forest: Atmosphere -> Coarse Roots,Net Growth
Atmosphere,Biomass: Fine Root,Net Growth Forest: Atmosphere -> Fine Roots,Net Growth
Atmosphere,Biomass: Foliage,Net Growth Forest: Atmosphere -> Foliage,Net Growth
Atmosphere,Biomass: Merchantable,Net Growth Forest: Atmosphere -> Merchantable,Net Growth
Atmosphere,Biomass: Other Wood,Net Growth Forest: Atmosphere -> Other Wood,Net Growth
Biomass: Coarse Root,DOM: Aboveground Fast,Biomass Turnover: Coarse Roots -> AG Fast,
Biomass: Coarse Root,DOM: Belowground Fast,Biomass Turnover: Coarse Roots -> BG Fast,
Biomass: Fine Root,DOM: Aboveground Very Fast,Biomass Turnover: Fine Roots -> AG Very Fast,
Biomass: Fine Root,DOM: Belowground Very Fast,Biomass Turnover: Fine Roots -> BG Very Fast,
Biomass: Foliage,DOM: Aboveground Very Fast,Biomass Turnover: Foliage -> AG Very Fast,
Biomass: Merchantable,DOM: Snag Stem,Biomass Turnover: Merchantable -> Snag Stems,
Biomass: Other Wood,DOM: Aboveground Fast,Biomass Turnover: Other Wood -> AG Fast,
Biomass: Other Wood,DOM: Snag Branch,Biomass Turnover: Other Wood -> Snag Branches,
DOM: Aboveground Fast,Atmosphere,Emission: AG Fast -> Atmosphere,
DOM: Aboveground Fast,DOM: Aboveground Slow,Decay: AG Fast -> AG Slow,
DOM: Aboveground Medium,Atmosphere,Emission: AG Medium -> Atmosphere,
DOM: Aboveground Medium,DOM: Aboveground Slow,Decay: AG Medium -> AG Slow,
DOM: Aboveground Slow,Atmosphere,Emission: AG Slow -> Atmosphere,
DOM: Aboveground Slow,DOM: Belowground Slow,Transfer: AG Slow -> BG Slow,
DOM: Aboveground Very Fast,Atmosphere,Emission: AG Very Fast -> Atmosphere,
DOM: Aboveground Very Fast,DOM: Aboveground Slow,Decay: AG Very Fast -> AG Slow,
DOM: Belowground Fast,Atmosphere,Emission: BG Fast -> Atmosphere,
DOM: Belowground Fast,DOM: Belowground Slow,Decay: BG Fast -> BG Slow,
DOM: Belowground Slow,Atmosphere,Emission: BG Slow -> Atmosphere,
DOM: Belowground Very Fast,Atmosphere,Emission: BG Very Fast -> Atmosphere,
DOM: Belowground Very Fast,DOM: Belowground Slow,Decay: BG Very Fast -> BG Slow,
DOM: Snag Branch,Atmosphere,Emission: Snag Branch -> Atmosphere,
DOM: Snag Branch,DOM: Aboveground Fast,Transfer: Snag Branch -> AG Fast,
DOM: Snag Branch,DOM: Aboveground Slow,Decay: Snag Branch -> AG Slow,
DOM: Snag Stem,Atmosphere,Emission: Snag Stem -> Atmosphere,
DOM: Snag Stem,DOM: Aboveground Medium,Transfer: Snag Stem -> AG Medium,
DOM: Snag Stem,DOM: Aboveground Slow,Decay: Snag Stem -> AG Slow,", na.strings = "")
