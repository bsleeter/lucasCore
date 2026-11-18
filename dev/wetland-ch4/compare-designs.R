# =============================================================================
# compare-designs.R - emergent wetland methane: the package's design (direct Q10s on the pools) against the ratio design, under a
# step warming
# =============================================================================
# Run from the package root: Rscript dev/wetland-ch4/compare-designs.R
# No SyncroSim: every design is stepped with src/nonforest-solve.R (ST-Sim's flow order) from the package's fitted steady state.
#   Direct     the package's design (user 2026-11-16): BG Slow and BG Very Fast each have a CO2 emission flow and a CH4 emission flow
#              straight to the atmosphere, each with its own Q10: CH4 3.83 from both pools; CO2 from root litter at the litter's Q10
#              (2.0, as always); CO2 from soil at the wetland soil Q10. Away from the normal climate the pools' losses change.
#   Direct, soil Q10 2   the package's values
#   Direct, soil Q10 1   the same with CBM's BG Slow Q10 (defaults/cbm/dom-parameters.csv: 1.0): soil CO2 without a response
#   Ratio      the design it replaced, rebuilt here: both pools emit into a holding stock (Wetland Gas), a share leaves as CH4 and
#              the rest as CO2; the share carries the Q10 of the CH4 to CO2 split (1.5); soil emission has no Q10. No pool's loss
#              changes because of methane.
# At the normal climate the three are the same model (the same shares of each pool's loss), so they start from the same pools and meet
# the same CH4 targets.
# Warming: a step of DT degrees C held for YEARS years (every Q10 multiplier = Q10 ^ (DT / 10), as src/climate.R writes them).
# Writes dev/wetland-ch4/compare-designs.csv (one row per budget x design x year 1, 10, 50, 100) and compare-designs.png (the two
# Gulf coast budgets over time).
# =============================================================================
suppressPackageStartupMessages(library(data.table)); source("src/nonforest-solve.R")
DT <- 2; YEARS <- 100; Q_CH4 <- 3.83; Q_RATIO <- 1.5; Q_SLOW <- 2; Q_FAST <- 2.65; out_dir <- file.path("dev", "wetland-ch4")
rd <- function(...) fread(file.path("defaults", ...), colClasses = "character", na.strings = "", encoding = "UTF-8")
pa <- rd("stockflow", "nonforest-pathways.csv"); memb <- rd("stockflow", "stsim_FlowTypeGroupMembership.csv")[, .(FlowTypeId, FlowGroupId)]; ord <- rd("stockflow", "stsim_FlowOrder.csv")[, .(FlowTypeId, Order)]
fm <- rd("stockflow", "nonforest-multipliers-wetland.csv"); fit <- fread("defaults/stockflow/emergent-wetland-fit.csv")
g4 <- NF_CH4; ty <- function(x) paste(x, "[Type]"); SOIL <- "DOM: Belowground Slow"; GAS <- "Wetland Gas"; G_CH4 <- "Gas: CH4"; G_CO2 <- "Gas: CO2"

# the ratio design's extra definitions: the gas leaves after both emissions have filled it, CH4 first (with the ratio's Q10), then CO2
memb_r <- rbind(memb, data.table(FlowTypeId = G_CH4, FlowGroupId = "Q10 Ratio")); ord_r <- rbind(ord, data.table(FlowTypeId = c(G_CH4, G_CO2), Order = c("6.8", "6.9")))
# where each emission goes, so the year's CO2 can be read off: belowground CO2 and aboveground CO2 as sinks of their own
track <- function(p) { p <- copy(p); p[ToStockTypeId == "Atmosphere" & FlowTypeId %in% c(g4$co2, G_CO2), ToStockTypeId := "CO2 belowground"]
  p[ToStockTypeId == "Atmosphere", ToStockTypeId := "CO2 aboveground"]; p }

one <- function(i) { e <- fit$StratumId[i]; cls <- fit$StateClassId[i]; npp <- fit$NPP[i]
  p <- pa[FromStratumId == e & FromStateClassId == cls]; m <- fm[StratumId == e & StateClassId == cls, .(FlowGroupId, Value)]
  # the ratio design: each pool's whole emission share (CO2 + CH4) into the gas; the CH4 fraction of the gas
  pr <- copy(p)[!FlowTypeId %in% g4$ch4][FlowTypeId %in% g4$co2, ToStockTypeId := GAS]; tpl <- pr[FlowTypeId == g4$co2[["soil"]]][, `:=`(FromStockTypeId = GAS, Multiplier = "1")]
  pr <- rbind(pr, copy(tpl)[, `:=`(ToStockTypeId = g4$sink, FlowTypeId = G_CH4)], copy(tpl)[, `:=`(ToStockTypeId = "Atmosphere", FlowTypeId = G_CO2)])
  mr <- copy(m)[, Value := as.numeric(Value)]; c4 <- mr$Value[match(ty(g4$ch4), mr$FlowGroupId)]; c2 <- mr$Value[match(ty(g4$co2), mr$FlowGroupId)]
  mr[match(ty(g4$co2), FlowGroupId), Value := c2 + c4]; mr <- rbind(mr[!FlowGroupId %in% ty(g4$ch4)], data.table(FlowGroupId = ty(G_CH4), Value = sum(c4) / sum(c2 + c4) * 0 + fit$CH4Share[i]))
  designs <- list(
    Ratio = list(p = track(pr), m = mr, memb = memb_r, ord = ord_r, warm = c(`Q10 Ratio` = Q_RATIO, `Q10 Wetland Soil` = 1)),
    `Direct, soil Q10 1` = list(p = track(p), m = m, memb = memb, ord = ord, warm = c(`Q10 Wetland CH4` = Q_CH4, `Q10 Wetland Soil` = 1)),
    `Direct, soil Q10 2` = list(p = track(p), m = m, memb = memb, ord = ord, warm = c(`Q10 Wetland CH4` = Q_CH4, `Q10 Wetland Soil` = 2)))
  rbindlist(lapply(names(designs), function(k) { d <- designs[[k]]
    flows <- function(v) nf_flows(d$p, rbind(d$m, data.table(FlowGroupId = names(v), Value = as.character(v))), d$memb, d$ord)
    ss <- nf_steady(flows(c(x = 1)[0]), npp); S <- c(ss$stock, setNames(rep(0, length(ss$sink)), names(ss$sink)))
    q <- c(`Q10 Slow Flows` = Q_SLOW, `Q10 Fast Flows` = Q_FAST, d$warm)^(DT / 10); mp <- nf_annual_map(flows(q), npp); S <- S[mp$pools]
    yr <- vector("list", YEARS); for (y in seq_len(YEARS)) { S1 <- (mp$M %*% S + mp$c)[, 1]; yr[[y]] <- c(S1 - S, soil = S1[[SOIL]]); S <- S1 }
    y <- as.data.table(do.call(rbind, yr)); n <- ss$sink
    data.table(StratumId = e, StateClassId = cls, Design = k, Year = seq_len(YEARS), CH4 = y[[g4$sink]], CO2bg = y[["CO2 belowground"]], CO2ag = y[["CO2 aboveground"]],
               Burial = y[["Deep Soil"]], Lateral = y[["Aquatic"]], Soil = y$soil,
               CH4_0 = n[[g4$sink]], CO2bg_0 = n[["CO2 belowground"]], CO2ag_0 = n[["CO2 aboveground"]], Burial_0 = n[["Deep Soil"]], Soil_0 = ss$stock[[SOIL]]) })) }
X <- rbindlist(lapply(seq_len(nrow(fit)), one))
# the same steady state in every design (the same pools, and CH4 and CO2 to the rounding of the written shares)
st <- unique(X[, .(StratumId, StateClassId, Design, CH4_0, CO2bg_0, Soil_0, Burial_0)])
stopifnot(st[, .(d = max(CH4_0) - min(CH4_0), s = max(Soil_0) - min(Soil_0), cc = max(CO2bg_0) - min(CO2bg_0)), by = .(StratumId, StateClassId)][, max(d, s, cc)] < 1e-4)
q10 <- function(now, base) (now / base)^(10 / DT)
X[, `:=`(FluxQ10 = q10(CH4, CH4_0), RatioQ10 = q10(CH4 / CO2bg, CH4_0 / CO2bg_0), RatioAllQ10 = q10(CH4 / (CO2bg + CO2ag), CH4_0 / (CO2bg_0 + CO2ag_0)), SoilChange = Soil - Soil_0)]
fwrite(X[Year %in% c(1, 10, 50, 100), .(StratumId, StateClassId, Design, Year, CH4_0 = round(CH4_0, 4), CH4 = round(CH4, 4), CO2bg_0 = round(CO2bg_0, 4), CO2bg = round(CO2bg, 4),
         FluxQ10 = round(FluxQ10, 3), RatioQ10 = round(RatioQ10, 3), RatioAllQ10 = round(RatioAllQ10, 3), Soil_0 = round(Soil_0, 2), SoilChange = round(SoilChange, 3),
         Burial_0 = round(Burial_0, 4), Burial = round(Burial, 4))], file.path(out_dir, "compare-designs.csv"))
r <- function(x, d = 2) sprintf(paste0("%.", d, "f to %.", d, "f"), min(x), max(x))
cat(sprintf("Step warming of %g C held %d years; CH4 Q10 %g (direct), ratio Q10 %g; %d budgets\n", DT, YEARS, Q_CH4, Q_RATIO, nrow(fit)))
for (yy in c(1, 50)) { cat(sprintf("\nYear %d\n", yy))
  print(X[Year == yy, .(CH4 = r(CH4, 3), FluxQ10 = r(FluxQ10), RatioQ10_bg = r(RatioQ10), RatioQ10_all = r(RatioAllQ10), SoilChange = r(SoilChange, 2), SoilPct = r(100 * SoilChange / Soil_0, 2),
                        BurialPct = r(100 * (Burial / Burial_0 - 1), 2)), by = .(StateClassId, Design)]) }

# figure: the two Gulf coast budgets (Subtropical), CH4 and soil carbon through the century
G <- X[StratumId == "Subtropical"]; cols <- c(Ratio = "#3b6ea8", `Direct, soil Q10 1` = "#d98b3a", `Direct, soil Q10 2` = "#c0392b")
png(file.path(out_dir, "compare-designs.png"), 1800, 1300, res = 200); par(mfrow = c(2, 2), mar = c(4, 4.4, 2.6, 1), mgp = c(2.5, 0.7, 0), las = 1, bty = "l")
for (cls in unique(G$StateClassId)) { g <- G[StateClassId == cls]; nm <- sub("^Wetland: ", "", cls)
  plot(NA, xlim = c(0, YEARS), ylim = range(c(g$CH4, g$CH4_0)) * c(0.97, 1.03), xlab = sprintf("Years at +%g C", DT), ylab = "CH4 (Mg C/ha/yr)", main = sprintf("%s: methane", nm), cex.main = 1)
  abline(h = g$CH4_0[1], lty = 2, col = "grey50"); for (k in names(cols)) lines(g[Design == k, Year], g[Design == k, CH4], col = cols[k], lwd = 2)
  if (cls == G$StateClassId[1]) legend("topright", c(names(cols), "Normal climate"), col = c(cols, "grey50"), lwd = c(2, 2, 2, 1), lty = c(1, 1, 1, 2), bty = "n", cex = 0.8)
  plot(NA, xlim = c(0, YEARS), ylim = range(c(g$SoilChange, 0)) * 1.05, xlab = sprintf("Years at +%g C", DT), ylab = "Change in soil carbon (Mg C/ha)", main = sprintf("%s: soil to 1 m", nm), cex.main = 1)
  abline(h = 0, lty = 2, col = "grey50"); for (k in names(cols)) lines(g[Design == k, Year], g[Design == k, SoilChange], col = cols[k], lwd = 2) }
invisible(dev.off())
