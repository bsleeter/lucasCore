# =============================================================================
# carbon.R - live-tree carbon curves and CBM pools from FIA (stage 2); no SyncroSim calls
# =============================================================================
# Decided 2026-10-20 (experiments 11-12, plan doc tab "Growth curves"): lucasbuilder converted merchantable volume to every biomass
# pool with the Boudewyn et al. (2007) equations of a Canadian species, then filled young ages with a spline from 0 - which put
# young-stand carbon at 0.13-2.4x what FIA measured at age 5. Here live-tree carbon is fitted directly from FIA, saplings included,
# so regenerating stands get carbon (and NPP) from observations:
#   total     live-tree carbon (aboveground + foliage + roots, Mg C/ha) by age per forest type x ecodivision: the stage 2 pooled model
#             with no lag (saplings carry carbon from the start), climate fallback for empty ecodivisions
#   shares    foliage and root shares of live carbon per forest type, s(t) = s_inf + (s0 - s_inf) exp(-t / tau), fitted to FIA pools
#   merch     merchantable stem carbon from the stage 2 volume curve x a US carbon density per forest type (FIA wood and bark
#             specific gravity, bark volume and carbon ratio of its species, volume-weighted; 2026-10-20 replaced the Canadian
#             Boudewyn stemwood equations). FIA merchantable volume already excludes stumps and tops, as CBM's pool does
#   other     aboveground wood minus merchantable (branches, tops, stumps, saplings, non-merchantable trees)
#   roots     coarse / fine split of Li et al. (2003), as lucasbuilder and CBM do
# =============================================================================

TONS_C_ACRE_TO_MG_HA <- 2.2417

# FIA conditions -> carbon fitting data (same filters as growth_data; the outlier cap is on live carbon)
carbon_data <- function(cond_file, dist_file, opt) {
  x <- data.table::as.data.table(readRDS(cond_file)); d <- data.table::as.data.table(readRDS(dist_file))
  x <- merge(x, d, by = c("plt_cn", "condid"), all.x = TRUE)
  x[, pid := sprintf("%02d-%d-%03d-%05d", statecd, unitcd, countycd, plot)][, ecodiv := as.character(ecodiv)]
  f <- TONS_C_ACRE_TO_MG_HA
  x[, `:=`(c_ag = c_ag_all_live_trees_short_tons_per_acre * f, c_fol = c_foliage_all_live_trees_short_tons_per_acre * f,
           c_bg = c_bg_all_live_trees_short_tons_per_acre * f, c_live = c_total_all_live_trees_short_tons_per_acre * f)]
  x <- x[!is.na(stdage) & !is.na(c_live) & !is.na(fortyp_grp) & invyr >= opt$MinInventoryYear & invyr <= 2100 &
         dstrbcd1 %in% 0 & trtcd1 %in% 0 & stdage >= 1 & stdage <= 400]
  x[, ccap := stats::quantile(c_live, opt$VolumeCapQuantile), by = fortyp_grp]; x <- x[c_live <= ccap]
  data.table::setorder(x, pid, condid, -invyr); x <- x[!duplicated(paste(pid, condid))]
  x[, .(pid, ecodiv, fortyp_grp, stdage, c_live, c_ag, c_fol, c_bg)] }

# a share of live carbon as a function of age, fitted as a ratio of sums: min sum (num - s(t) den)^2 / den. Unweighted, big plots
# dominated and foliage came out 10-20% low at every age (experiment 14); weighted, foliage and roots are within 2% from age 6
share_curve <- function(t, p) p[["s_inf"]] + (p[["s0"]] - p[["s_inf"]]) * exp(-t / p[["tau"]])
fit_share <- function(t, num, den) {
  ok <- den > 0; t <- t[ok]; num <- num[ok]; den <- den[ok]; s_all <- sum(num) / sum(den); best <- NULL
  for (st in list(c(s_all, s_all, 20), c(s_all * 2, s_all, 10), c(s_all / 2, s_all, 40))) {
    o <- stats::optim(pmin(st, c(1, 1, 200)), function(p) sum((num - share_curve(t, c(s0 = p[1], s_inf = p[2], tau = p[3])) * den)^2 / den),
                      method = "L-BFGS-B", lower = c(0, 0, 1), upper = c(1, 1, 200))
    if (is.null(best) || o$value < best$value) best <- o }
  c(s0 = best$par[1], s_inf = best$par[2], tau = best$par[3]) }

# merchantable stem carbon (Mg C/ha) from FIA net merchantable volume (m3/ha) and the state class's US carbon density (Mg C/m3:
# volume-weighted wood + bark specific gravity x live carbon ratio of its species, defaults/growth/merch-carbon-density.csv, built by
# tools/make_wood_density.R from FIA REF_SPECIES and EVALIDator). FIA merchantable volume excludes stump and top, as CBM's pool does
merch_carbon <- function(V, density) V * density

# CBM live pools by age from total live carbon, the two shares and merchantable carbon (all Mg C/ha)
cbm_pools <- function(age, live, sh_fol, sh_bg, merch_c) {
  fol <- share_curve(age, sh_fol) * live; bg <- share_curve(age, sh_bg) * live
  wood <- pmax(live - fol - bg, 0); merch <- pmin(merch_c, wood); other <- wood - merch
  p_fine <- 0.072 + 0.354 * exp(-0.060 * (bg / 0.5))           # Li et al. (2003), on root biomass (t/ha)
  data.table::data.table(Age = age, Merchantable = merch, Foliage = fol, Other = other, CoarseRoots = bg * (1 - p_fine), FineRoots = bg * p_fine,
                         TotalLive = live, MerchCapped = merch_c > wood + 1e-9) }
