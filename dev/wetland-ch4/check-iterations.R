# check-iterations.R - the Wetland Methane page's settings in an ST-Sim run with several iterations: methane per hectare by class and
# iteration (the uncertainty draws), the carbon balance of each iteration, the CO2 equivalent weight, and where forested methane comes from.
# Usage: Rscript dev/wetland-ch4/check-iterations.R <library.ssim> <result scenario id>
suppressPackageStartupMessages({ library(RSQLite); library(data.table) })
a <- commandArgs(TRUE); sid <- as.integer(a[2])
con <- dbConnect(SQLite(), a[1], flags = SQLITE_RO); q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
fl <- q("SELECT o.Iteration, o.Timestep, sc.Name Class, g.Name Grp, SUM(o.Amount) Amt FROM stsim_OutputFlow o JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId
         LEFT JOIN stsim_StateClass sc ON sc.StateClassId = o.FromStateClassId WHERE o.ScenarioId = %d GROUP BY o.Iteration, o.Timestep, sc.Name, g.Name", sid)
ar <- q("SELECT o.Iteration, o.Timestep, sc.Name Class, SUM(o.Amount) Area FROM stsim_OutputStratumState o JOIN stsim_StateClass sc ON sc.StateClassId = o.StateClassId WHERE o.ScenarioId = %d GROUP BY o.Iteration, o.Timestep, sc.Name", sid)
st <- q("SELECT o.Iteration, o.Timestep, g.Name Grp, SUM(o.Amount) Amt FROM stsim_OutputStock o JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId WHERE o.ScenarioId = %d GROUP BY o.Iteration, o.Timestep, g.Name", sid)
cat(sprintf("Run %d: %d-%d, iterations %s\n", sid, min(fl$Timestep), max(fl$Timestep), paste(sort(unique(fl$Iteration)), collapse = ", ")))

cat("\n1. Methane per hectare by class and iteration (Mg C/ha/yr as CH4, mean of the run's years)\n")
pa <- merge(fl[Grp == "Emission: Wetland CH4" & Amt > 0, .(Iteration, Timestep, Class, CH4 = Amt)], ar, by = c("Iteration", "Timestep", "Class"))
pi <- pa[, .(PerHa = sum(CH4) / sum(Area), Ha = round(mean(Area))), by = .(Class, Iteration)]
w <- dcast(pi, Class ~ paste0("it", Iteration), value.var = "PerHa"); w <- merge(pi[, .(Ha = Ha[1]), by = Class], w, by = "Class")
print(w[order(-Ha)][, lapply(.SD, function(v) if (is.numeric(v)) round(v, 3) else v)])

cat("\n2. Source pool loss by class and iteration: CO2 + CH4 from the methane source pools (Mg C/ha/yr); the draws move the split, not the total\n")
src <- fl[grepl("-> Atmosphere (\\(Wetland\\)|CH4) \\[Type\\]$", Grp), .(Loss = sum(Amt)), by = .(Class, Iteration, Timestep)]
src <- merge(src, ar, by = c("Iteration", "Timestep", "Class"))[, .(PerHa = sum(Loss) / sum(Area)), by = .(Class, Iteration)]
w2 <- dcast(src, Class ~ paste0("it", Iteration), value.var = "PerHa"); print(w2[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 3) else v)])

cat("\n3. Where the methane comes from (share of the class's methane, all iterations)\n")
by_pool <- fl[grepl("-> Atmosphere CH4 \\[Type\\]$", Grp) & Amt > 0, .(Mg = sum(Amt)), by = .(Class, Pool = sub("^Emission: (.+) -> Atmosphere CH4 \\[Type\\]$", "\\1", Grp))]
by_pool[, Share := round(Mg / sum(Mg), 3), by = Class]; print(dcast(by_pool, Class ~ Pool, value.var = "Share", fill = 0))

cat("\n4. CO2 equivalent weight: Emission: Wetland CH4 (CO2e) over Emission: Wetland CH4\n")
r <- merge(fl[Grp == "Emission: Wetland CH4 (CO2e)", .(e = sum(Amt)), by = Iteration], fl[Grp == "Emission: Wetland CH4", .(c = sum(Amt)), by = Iteration], by = "Iteration")
print(r[, .(Iteration, CO2ePerMgC = round(e / c, 3))])

cat("\n5. Carbon balance by iteration: yearly change in Total Ecosystem against Net Biome Productivity (Mg C)\n")
te <- st[Grp == "Total Ecosystem"][order(Iteration, Timestep)]; d <- te[, .(Timestep = Timestep[-1], dStock = diff(Amt)), by = Iteration]
nbp <- fl[Grp == "Net Biome Productivity", .(NBP = sum(Amt)), by = .(Iteration, Timestep)]; d <- merge(d, nbp, by = c("Iteration", "Timestep"))
print(d[, .(Stock0 = round(te[Iteration == .BY$Iteration, Amt[1]]), MeanNBP = round(mean(NBP)), LargestGap = signif(max(abs(dStock - NBP)), 3)), by = Iteration])
dbDisconnect(con)
