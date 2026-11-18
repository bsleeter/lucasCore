# check-projection.R - wetland carbon and methane through a run, by period: per-hectare methane, growth, belowground CO2, soil stock,
# burial and lateral export of each class that releases methane, and whether the carbon balance closes every year.
# Usage: Rscript dev/wetland-ch4/check-projection.R <library.ssim> <result scenario id> [<climate result id>] [period length, default 20]
suppressPackageStartupMessages({ library(RSQLite); library(data.table) })
a <- commandArgs(TRUE); sid <- as.integer(a[2]); cid <- if (length(a) > 2) as.integer(a[3]) else NA; step <- if (length(a) > 3) as.integer(a[4]) else 20L
con <- dbConnect(SQLite(), a[1], flags = SQLITE_RO); q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
fl <- q("SELECT o.Timestep, sc.Name Class, g.Name Grp, SUM(o.Amount) Amt FROM stsim_OutputFlow o JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId
         LEFT JOIN stsim_StateClass sc ON sc.StateClassId = o.FromStateClassId WHERE o.ScenarioId = %d GROUP BY o.Timestep, sc.Name, g.Name", sid)
gr <- q("SELECT o.Timestep, sc.Name Class, SUM(o.Amount) Amt FROM stsim_OutputFlow o JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId
         LEFT JOIN stsim_StateClass sc ON sc.StateClassId = o.ToStateClassId WHERE o.ScenarioId = %d AND g.Name = 'Net Primary Productivity' GROUP BY o.Timestep, sc.Name", sid)
ar <- q("SELECT o.Timestep, sc.Name Class, SUM(o.Amount) Area FROM stsim_OutputStratumState o JOIN stsim_StateClass sc ON sc.StateClassId = o.StateClassId WHERE o.ScenarioId = %d GROUP BY o.Timestep, sc.Name", sid)
st <- q("SELECT o.Timestep, sc.Name Class, g.Name Grp, SUM(o.Amount) Amt FROM stsim_OutputStock o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId
         LEFT JOIN stsim_StateClass sc ON sc.StateClassId = o.StateClassId WHERE o.ScenarioId = %d GROUP BY o.Timestep, sc.Name, g.Name", sid)
cls <- fl[Grp == "Emission: Wetland CH4" & Amt > 0, unique(Class)]; y0 <- min(fl$Timestep); y1 <- max(fl$Timestep)
per <- function(y) { b <- y0 + step * ((y - y0) %/% step); sprintf("%d-%d", b, pmin(b + step - 1, y1)) }
G <- c(CH4 = "Emission: Wetland CH4", SourceCO2 = "Emission: Wetland Methane Source CO2", Rh = "Emission: Total Rh", Lateral = "Lateral Flux", Burial = "Stabilization: BG Slow -> Deep Soil [Type]")
fl[Grp == "Emission: Wetland Belowground CO2", Grp := G[["SourceCO2"]]]   # the group's name in runs made before the forest floor became a methane source
x <- rbind(fl[Class %in% cls & Grp %in% G, .(Timestep, Class, k = names(G)[match(Grp, G)], Amt)], gr[Class %in% cls, .(Timestep, Class, k = "NPP", Amt)],
           st[Class %in% cls & Grp %in% c("DOM: Belowground Slow [Type]", "Total Ecosystem"), .(Timestep, Class, k = ifelse(Grp == "Total Ecosystem", "Ecosystem", "ActiveSoil"), Amt)])
x <- merge(x, ar, by = c("Timestep", "Class"))[, v := Amt / Area][, Period := per(Timestep)]
w <- dcast(x[, .(v = mean(v), ha = round(mean(Area))), by = .(Class, Period, k)], Class + Period + ha ~ k, value.var = "v")
if (!"SourceCO2" %in% names(w)) w[, SourceCO2 := NA_real_]
w[, Class := sub("Wetland: ", "", Class)]
cat(sprintf("Run %d, %d-%d: per hectare of each class that releases methane, period means (Mg C/ha/yr; stocks Mg C/ha)\n", sid, y0, y1))
print(w[, .(Class, Period, ha, NPP = round(NPP, 2), Rh = round(Rh, 2), CH4 = round(CH4, 3), SourceCO2 = round(SourceCO2, 2), CH4toCO2 = round(CH4 / SourceCO2, 3), Burial = round(Burial, 3), Lateral = round(Lateral, 3),
              ActiveSoil = round(ActiveSoil, 1), Ecosystem = round(Ecosystem, 1))])
te <- st[Grp == "Total Ecosystem", .(Amt = sum(Amt)), by = Timestep][order(Timestep)]; nbp <- fl[Grp == "Net Biome Productivity", .(v = sum(Amt)), by = Timestep]
d <- merge(data.table(Timestep = te$Timestep[-1], dStock = diff(te$Amt)), nbp, by = "Timestep")[, Gap := dStock - v]
cat(sprintf("\nCarbon balance, whole study area, %d years: largest yearly gap between the change in Total Ecosystem carbon and NBP %.3f Mg C (%.1e %% of %.0f Mg C)\n", nrow(d), max(abs(d$Gap)), 100 * max(abs(d$Gap)) / te$Amt[1], te$Amt[1]))
tot <- fl[Class %in% cls & Grp %in% c("Net Biome Productivity", "Net Biome Productivity (CO2e)", "Emission: Wetland CH4"), .(v = sum(Amt)), by = .(Period = per(Timestep), Grp)]
ny <- fl[, .(n = uniqueN(Timestep)), by = .(Period = per(Timestep))]; tot <- merge(tot, ny, by = "Period")[, v := v / n]
print(dcast(tot, Period ~ Grp, value.var = "v")[, lapply(.SD, function(z) if (is.numeric(z)) round(z) else z)])
if (!is.na(cid)) { cs <- q("SELECT Timestep, FlowGroup, Mean FROM lucasCore_OutputClimateSummary WHERE ScenarioId = %d", cid)
  if (nrow(cs)) { cat("\nClimate multipliers, study-area mean by period\n"); print(dcast(cs[Timestep >= y0 & Timestep <= y1, .(m = round(mean(Mean), 3)), by = .(Period = per(Timestep), FlowGroup)], Period ~ FlowGroup, value.var = "m")) } }
dbDisconnect(con)
