# check-run.R - wetland methane in an ST-Sim run: per-hectare CH4 against the targets, its response to the year's climate, and whether
# the carbon balance closes. Usage: Rscript dev/wetland-ch4/check-run.R <library.ssim> <result scenario id> [<Build result id>]
suppressPackageStartupMessages({ library(RSQLite); library(data.table) })
a <- commandArgs(TRUE); sid <- as.integer(a[2]); bid <- if (length(a) > 2) as.integer(a[3]) else NA
con <- dbConnect(SQLite(), a[1], flags = SQLITE_RO); q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
EM <- c("Wetland: Estuarine Emergent", "Wetland: Palustrine Emergent")
# the targets of the Sabine and Lacassine test area (Subtropical: Gulf and South Atlantic estuarine, Coastal Plains palustrine; the
# values of defaults/stockflow/emergent-wetland-regions.csv and defaults/spinup/wetland-ch4.csv); edit for another area or older runs
TARGET <- c(`Wetland: Estuarine Emergent` = 0.111, `Wetland: Palustrine Emergent` = 0.40)
fl <- q("SELECT o.Timestep, sc.Name Class, g.Name Grp, SUM(o.Amount) Amt FROM stsim_OutputFlow o JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId
         LEFT JOIN stsim_StateClass sc ON sc.StateClassId = o.FromStateClassId WHERE o.ScenarioId = %d GROUP BY o.Timestep, sc.Name, g.Name", sid)
ar <- q("SELECT o.Timestep, sc.Name Class, SUM(o.Amount) Area FROM stsim_OutputStratumState o JOIN stsim_StateClass sc ON sc.StateClassId = o.StateClassId WHERE o.ScenarioId = %d GROUP BY o.Timestep, sc.Name", sid)
st <- q("SELECT o.Timestep, g.Name Grp, SUM(o.Amount) Amt FROM stsim_OutputStock o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId WHERE o.ScenarioId = %d GROUP BY o.Timestep, g.Name", sid)
g <- function(grp, cls = NULL) { x <- fl[Grp == grp & (if (is.null(cls)) TRUE else Class %in% cls), .(v = sum(Amt)), by = Timestep]; setNames(x$v, x$Timestep) }
yrs <- sort(unique(fl$Timestep)); cat(sprintf("Run %d: %d-%d; study area %.0f ha, emergent wetland %.0f ha at the start (%s)\n", sid, min(yrs), max(yrs), ar[Timestep == min(Timestep), sum(Area)],
    ar[Timestep == min(Timestep) & Class %in% EM, sum(Area)], paste(ar[Timestep == min(Timestep) & Class %in% EM, sprintf("%s %.0f", sub("Wetland: ", "", Class), Area)], collapse = ", ")))

# 1. methane per hectare by class and year, against the targets
cat("\n1. Methane per hectare (Mg C/ha/yr as CH4)\n")
FW <- 0.27; tg <- function(cls) if (cls %in% names(TARGET)) TARGET[[cls]] else if (grepl("^(Disturbed: )?Wetland:? .+ Group$", cls)) FW else NA_real_   # the forested twins and their disturbed classes
pa <- merge(fl[Grp == "Emission: Wetland CH4" & Amt > 0, .(Timestep, Class, CH4 = Amt)], ar, by = c("Timestep", "Class"))[, PerHa := CH4 / Area]
print(pa[, .(Target = tg(Class[1]), MeanHa = round(mean(Area)), Mean = round(mean(PerHa), 3), Min = round(min(PerHa), 3), Max = round(max(PerHa), 3), MeanOverTarget = round(mean(PerHa) / tg(Class[1]), 3)), by = Class])
pc <- pa[Class %in% EM]; EM <- unique(pa$Class)   # from here on: every class that releases wetland methane
# the emergent classes' own flow types since lucasCore 1.10 (src/nonforest-solve.R NF_EMERGENT_TYPES), the wetland ones before and for forested wetlands
FT <- list(SoilCO2 = c("Emission: BG Slow -> Atmosphere (Wetland) [Type]", "Emission Emergent: BG Slow -> Atmosphere [Type]"), SoilCH4 = c("Emission: BG Slow -> Atmosphere CH4 [Type]", "Emission Emergent: BG Slow -> Atmosphere CH4 [Type]"),
           LitterCH4 = "Emission: BG Very Fast -> Atmosphere CH4 [Type]", LitterCO2 = c("Emission: BG Very Fast -> Atmosphere (Wetland) [Type]", "Emission Emergent: BG Very Fast -> Atmosphere [Type]"))
role <- setNames(rep(names(FT), lengths(FT)), unlist(FT))
src <- dcast(fl[Class %in% EM & Grp %in% names(role), .(Mg = sum(Amt)), by = .(Class, Flow = role[Grp])], Class ~ Flow, value.var = "Mg")
print(src[, .(Class, SoilShareOfCH4 = round(SoilCH4 / (SoilCH4 + LitterCH4), 3), CH4toCO2_belowground = round((SoilCH4 + LitterCH4) / (SoilCO2 + LitterCO2), 3))])
cat("only the emergent classes emit wetland methane:", all(fl[Grp == "Emission: Wetland CH4" & Amt > 0, Class] %in% EM), "\n")
cat("the shared soil emission flow moves nothing in the emergent classes:", !nrow(fl[Grp == "Emission: BG Slow -> Atmosphere [Type]" & Class %in% EM & Amt > 0]), "\n")

# 2. response to the year's climate: the year's methane per hectare beside the Build's study-area mean CH4 multiplier
if (!is.na(bid)) { cs <- q("SELECT Timestep, FlowGroup, Mean FROM lucasCore_OutputClimateSummary WHERE ScenarioId = %d AND FlowGroup IN ('Q10 Wetland CH4', 'Q10 Wetland Soil', 'Q10 Wetland Flows', 'Q10 Slow Flows')", bid)
  m <- merge(pc[, .(PerHa = sum(CH4) / sum(Area)), by = Timestep], dcast(cs, Timestep ~ FlowGroup, value.var = "Mean"), by = "Timestep")
  cat(sprintf("\n2. Climate: study-area mean CH4 multiplier %.3f-%.3f over the run; correlation of yearly CH4 per hectare with it %.3f\n", min(m$`Q10 Wetland CH4`), max(m$`Q10 Wetland CH4`), cor(m$PerHa, m$`Q10 Wetland CH4`)))
  wq <- if ("Q10 Wetland Flows" %in% names(m)) "Q10 Wetland Flows" else "Q10 Wetland Soil"   # the emergent classes' litter and soil since lucasCore 1.10
  print(m[, .(Timestep, CH4PerHa = round(PerHa, 4), CH4Multiplier = `Q10 Wetland CH4`, WetlandMultiplier = get(wq))]) }

# 3. carbon balance of the whole study area: the year's change in Total Ecosystem carbon against Net Biome Productivity
te <- st[Grp == "Total Ecosystem"][order(Timestep)]; d <- data.table(Timestep = te$Timestep[-1], dStock = diff(te$Amt)); nbp <- g("Net Biome Productivity")
d[, NBP := nbp[as.character(Timestep)]][, Gap := dStock - NBP]
cat(sprintf("\n3. Carbon balance, whole study area: Total Ecosystem %.0f Mg C at the start; yearly change against NBP\n", te$Amt[1]))
print(d[, .(Timestep, dStock = round(dStock), NBP = round(NBP), Gap = round(Gap, 1), GapPctOfStock = signif(100 * Gap / te$Amt[1], 2))])
cat(sprintf("largest yearly gap %.3f Mg C (%.1e %% of the stock)\n", max(abs(d$Gap)), 100 * max(abs(d$Gap)) / te$Amt[1]))
parts <- g("Net Primary Productivity") - g("Emission: Total Rh") - g("Lateral Flux"); nep <- g("Net Ecosystem Productivity")
cat(sprintf("NEP = NPP - Rh - lateral export in every year (largest gap %.2e Mg C); methane is inside Rh\n", max(abs(parts[names(nep)] - nep))))

# 4. what methane does to the CO2e balance of the emergent wetlands
ce <- g("Net Biome Productivity (CO2e)", EM); cc <- g("Net Biome Productivity", EM); ch4 <- g("Emission: Wetland CH4", EM)
cat(sprintf("\n4. Emergent wetlands, mean per year: NBP %+.0f Mg C; as CO2e %+.0f Mg; counted all as CO2 it would be %+.0f Mg CO2e. Methane %.0f Mg C accounts for %.0f of the difference (29.83 per Mg C); the rest (%.0f) is the CO and CH4 of fire\n",
            mean(cc), mean(ce), mean(cc) * 3.67, mean(ch4), 29.83 * mean(ch4), mean(cc) * 3.67 - mean(ce) - 29.83 * mean(ch4)))
dbDisconnect(con)
