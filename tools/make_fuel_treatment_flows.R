# tools/make_fuel_treatment_flows.R - defaults/fuel-treatments/flows.csv from the research's pool shares (dev/fuel-treatments/research.md, table 2); run from the repository root, then tools/make_fuel_treatments.R
suppressPackageStartupMessages(library(data.table))
EM <- c(CO2 = 0.9, CO = 0.09, CH4 = 0.01)   # consumed carbon (Prichard et al. 2020 emission factors, ~90 / 9 / 0.7%), as the model's fire flows
burnt <- function(t, from, share, live) data.table(Treatment = t, FromStockTypeId = from, ToStockTypeId = paste0("Atmosphere: ", names(EM)),
  FlowTypeId = paste0("LULC: Emission ", if (live) "Live " else "DOM ", names(EM)), Multiplier = round(share * EM, 6))
mv <- function(t, from, to, share, ft = "LULC: Mortality Live") data.table(Treatment = t, FromStockTypeId = from, ToStockTypeId = to, FlowTypeId = ft, Multiplier = share)
thin <- function(t) { R <- 0.25; slash <- 0.9   # 25% of live biomass cut; 80% of the merchantable cut to the mill; slash piled and burned, 90% consumed
  rbind(mv(t, "Biomass: Merchantable", "Forestry Sector", R * 0.8, "LULC: Harvest Live"),
        burnt(t, "Biomass: Merchantable", R * 0.2 * slash, TRUE), mv(t, "Biomass: Merchantable", "DOM: Aboveground Medium", R * 0.2 * (1 - slash)),
        burnt(t, "Biomass: Other Wood", R * slash, TRUE), mv(t, "Biomass: Other Wood", "DOM: Aboveground Fast", R * (1 - slash)),
        burnt(t, "Biomass: Foliage", R * slash, TRUE), mv(t, "Biomass: Foliage", "DOM: Aboveground Very Fast", R * (1 - slash)),
        mv(t, "Biomass: Fine Root", "DOM: Aboveground Very Fast", R / 2), mv(t, "Biomass: Fine Root", "DOM: Belowground Very Fast", R / 2),
        mv(t, "Biomass: Coarse Root", "DOM: Aboveground Fast", R / 2), mv(t, "Biomass: Coarse Root", "DOM: Belowground Fast", R / 2)) }
burn <- function(t) { M <- 0.05   # litter 80%, fine woody debris 60%, coarse 30%, snag branches 30%, snag stems 5% consumed; foliage scorch 2%; 5% of live trees killed
  rbind(burnt(t, "DOM: Aboveground Very Fast", 0.8, FALSE), burnt(t, "DOM: Aboveground Fast", 0.6, FALSE), burnt(t, "DOM: Aboveground Medium", 0.3, FALSE),
        burnt(t, "DOM: Snag Branch", 0.3, FALSE), burnt(t, "DOM: Snag Stem", 0.05, FALSE), burnt(t, "Biomass: Foliage", 0.02, TRUE),   # snags 30% and 5% consumed; crown scorch 2% of foliage
        mv(t, "Biomass: Merchantable", "DOM: Snag Stem", M), mv(t, "Biomass: Other Wood", "DOM: Snag Branch", M), mv(t, "Biomass: Foliage", "DOM: Aboveground Very Fast", M),
        mv(t, "Biomass: Fine Root", "DOM: Belowground Very Fast", M), mv(t, "Biomass: Coarse Root", "DOM: Belowground Fast", M)) }
fl <- rbind(thin("Mechanical thinning"), burn("Prescribed burn"), thin("Thin and burn"), burn("Thin and burn"))
fl[, Treatment := c("Mechanical thinning" = "Fuel Treatment: Mechanical Thinning", "Prescribed burn" = "Fuel Treatment: Prescribed Burn", "Thin and burn" = "Fuel Treatment: Thin and Burn")[Treatment]]
# no pool loses more than its stock (thin and burn: the burn's live mortality on top of the thinning's 25%)
chk <- fl[, .(s = sum(Multiplier)), by = .(Treatment, FromStockTypeId)]; stopifnot(all(chk$s <= 1 + 1e-9))
fwrite(fl, "defaults/fuel-treatments/flows.csv"); cat(nrow(fl), "flow rows\n"); print(chk)
