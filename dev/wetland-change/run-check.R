# To-do 2 step 6: a historical run with water, wetland and barren change, read from the library file.
# Area stage 6 mapped against the area the run realized, the classes' area through time, the carbon the events moved, and the
# balance of stocks against flows to and from the outside (atmosphere, aquatic, sectors).
# Usage: Rscript dev/wetland-change/run-check.R <library.ssim> <run result id> <Build result id> [baseline run result id]
suppressPackageStartupMessages({ library(DBI); library(data.table) }); options(width = 220)
a <- commandArgs(TRUE); con <- dbConnect(RSQLite::SQLite(), a[1], flags = RSQLite::SQLITE_RO); run <- as.integer(a[2]); bld <- as.integer(a[3]); base <- if (length(a) > 3) as.integer(a[4]) else NA
q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
tg <- q("SELECT TransitionGroupId id, Name FROM stsim_TransitionGroup"); sc <- q("SELECT StateClassId id, Name FROM stsim_StateClass"); tt <- q("SELECT TransitionTypeId id, Name FROM stsim_TransitionType")
st <- q("SELECT StockTypeId id, Name FROM stsim_StockType"); fg <- q("SELECT FlowGroupId id, Name FROM stsim_FlowGroup"); sg <- q("SELECT StockGroupId id, Name FROM stsim_StockGroup")
nm <- function(i, t) t$Name[match(i, t$id)]
# ---- 1. transitions: mapped by stage 6 against realized ----
ms <- q("SELECT Timestep, TransitionGroup, Area, IneligibleArea FROM lucasCore_OutputTransitionSummary WHERE ScenarioId = %d AND Source = 'WaterChange'", bld)
tr <- q("SELECT Timestep, TransitionGroupId, SUM(Amount) Amount FROM stsim_OutputStratumTransition WHERE ScenarioId = %d GROUP BY Timestep, TransitionGroupId", run)[, Group := nm(TransitionGroupId, tg)]
yr <- range(tr$Timestep); cat(sprintf("run %d: transitions in %d-%d; amounts are in the library's area units\n", run, yr[1], yr[2]))
w <- tr[grepl("^Wetland Change", Group)]
cmp <- merge(ms[Timestep <= yr[2], .(Mapped = sum(Area), OnOtherClassesAtStart = sum(IneligibleArea)), by = .(Group = TransitionGroup)], w[grepl("Type", Group), .(Realized = sum(Amount)), by = Group], by = "Group", all = TRUE)
units <- q("SELECT * FROM stsim_Terminology")$AmountUnits[1]; cat("amount units code:", units, "\n")
print(cmp); print(w[!grepl("Type", Group), .(Realized = sum(Amount)), by = Group])
# ---- 2. class area through time ----
ss <- q("SELECT Timestep, StateClassId, SUM(Amount) Amount FROM stsim_OutputStratumState WHERE ScenarioId = %d GROUP BY Timestep, StateClassId", run)[, Class := nm(StateClassId, sc)]
keep <- c("Water: All", "Barren: All", "Wetland: Estuarine Emergent", "Wetland: Palustrine Emergent"); ys <- sort(unique(ss$Timestep)); ys <- ys[unique(c(1, seq(1, length(ys), by = 5), length(ys)))]
print(dcast(ss[Class %in% keep & Timestep %in% ys], Timestep ~ Class, value.var = "Amount", fill = 0))
oth <- ss[!Class %in% keep, .(Other = sum(Amount)), by = Timestep]; cat("all other classes, first and last year:", oth[Timestep == min(Timestep), Other], oth[Timestep == max(Timestep), Other], "\n")
if (!is.na(base)) { sb <- q("SELECT Timestep, StateClassId, SUM(Amount) Amount FROM stsim_OutputStratumState WHERE ScenarioId = %d GROUP BY Timestep, StateClassId", base)[, Class := nm(StateClassId, sc)]
  yb <- max(intersect(sb$Timestep, ss$Timestep)); d <- merge(ss[Timestep == yb, .(Class, Run = Amount)], sb[Timestep == yb, .(Class, Baseline = Amount)], by = "Class", all = TRUE); d[is.na(d)] <- 0
  cat(sprintf("against baseline run %d in %d, classes that differ:\n", base, yb)); print(d[abs(Run - Baseline) > 1e-6][order(-abs(Run - Baseline))]) }
# ---- 3. carbon moved by the events ----
fl <- q("SELECT Timestep, FromStateClassId, FromStockTypeId, ToStockTypeId, TransitionTypeId, FlowGroupId, SUM(Amount) Amount FROM stsim_OutputFlow WHERE ScenarioId = %d GROUP BY Timestep, FromStateClassId, FromStockTypeId, ToStockTypeId, TransitionTypeId, FlowGroupId", run)
fl[, `:=`(From = nm(FromStockTypeId, st), To = nm(ToStockTypeId, st), Type = nm(TransitionTypeId, tt), Flow = nm(FlowGroupId, fg), Class = nm(FromStateClassId, sc))]
ev <- fl[grepl("^Wetland Change", Type) & grepl("\\[Type\\]$", Flow)]
cat("flows on Wetland Change transitions, by type, class and flow (sum over the run):\n"); print(ev[, .(Amount = sum(Amount)), by = .(Type, Class, Flow)][order(Type, -Amount)])
cat("from which pools:\n"); print(ev[, .(Amount = sum(Amount)), by = .(Type, From, To)][order(Type, -Amount)])
# ---- 4. balance: change in the ecosystem's stocks = flows in from outside - flows out to outside ----
OUT <- c("Atmosphere", "Atmosphere: CO2", "Atmosphere: CO", "Atmosphere: CH4", "Aquatic", "Forestry Sector", "Agriculture Sector")
sk <- q("SELECT Timestep, StockGroupId, SUM(Amount) Amount FROM stsim_OutputStock WHERE ScenarioId = %d GROUP BY Timestep, StockGroupId", run)[, Stock := sub(" \\[Type\\]$", "", nm(StockGroupId, sg))][grepl("\\[Type\\]$", nm(StockGroupId, sg))]
eco <- sk[!Stock %in% OUT, .(Stock = sum(Amount)), by = Timestep][order(Timestep)]
ft <- fl[grepl("\\[Type\\]$", Flow), .(Amount = sum(Amount)), by = .(Timestep, From, To)]
net <- ft[, .(In = sum(Amount[From %in% OUT & !To %in% OUT]), Out = sum(Amount[!From %in% OUT & To %in% OUT])), by = Timestep][order(Timestep)]
b <- merge(eco, net, by = "Timestep", all.x = TRUE)[, Change := Stock - shift(Stock)][, Gap := Change - (In - Out)]
cat("ecosystem carbon balance (stock change against net flow), worst years:\n"); print(b[!is.na(Gap)][order(-abs(Gap))][1:5]); cat(sprintf("largest gap %.4g against a stock of %.4g (%.2e of it)\n", b[, max(abs(Gap), na.rm = TRUE)], b$Stock[1], b[, max(abs(Gap), na.rm = TRUE)] / b$Stock[1]))
