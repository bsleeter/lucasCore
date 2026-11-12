# To-do 57 step 6: live carbon at the reforestation transition, on the Lassen Build (full Build result). The transition triggers no
# flows and resets age to 0, so a reforesting cell keeps its grass or shrub live carbon (Other Wood, Foliage, Fine Root, Coarse Root)
# and grows on its forest type's curve from age 0. Stage 3's net growth is a mass balance (g(t) = C(t+1) - (1 - r) C(t)), so the
# cell follows curve(t) + carried x (1 - r)^t pool by pool: no jump, the carried carbon fades at the forest pool's turnover rate.
# This compares, per reforesting cell: the carried live carbon (stage 8, 1985), the destination curve at ages 0-30, and what is left
# of the carried carbon after 5, 10 and 20 years. Usage: Rscript dev/reforestation/carbon-at-transition.R <full Build result id>
suppressMessages({ library(rsyncrosim); library(terra); library(data.table) })
id <- as.integer(commandArgs(TRUE)[1]); L <- ssimLibrary("F:/lucasCore/dev/libs/lassen/Lassen.ssim", summary = FALSE); s <- scenario(L, id)
ic <- datasheet(s, "stsim_InitialConditionsSpatial"); lc <- datasheet(s, "lucasCore_OutputLandCoverLayers"); nl <- datasheet(s, "lucasCore_OutputNlcdAnnual")
st <- as.data.table(datasheet(s, "stsim_InitialStockSpatial")); cc <- as.data.table(datasheet(s, "lucasCore_CarbonCurve", lookupsAsFactors = FALSE))
cr <- as.data.table(datasheet(s, "lucasCore_OutputCarbonRate", lookupsAsFactors = FALSE)); P <- rast(ic$StratumFileName[1])
S <- rast(ic$StateClassFileName[1]); n0 <- rast(nl$FileName[nl$Year == 1985]); RT <- rast(lc$ReforestTypeFileName[1])
N <- rast(nl$FileName); first <- app(N >= 41 & N <= 43, function(x) { k <- which(x[-length(x)] & x[-1]); k <- k[k >= 2]; if (length(k)) k[1] - 1 else NA })
rf <- which(values(S < 100 & n0 %in% c(31, 52, 71, 95) & !is.na(first), mat = FALSE) %in% 1)
POOL <- c(Other = "Biomass: Other Wood", Foliage = "Biomass: Foliage", FineRoots = "Biomass: Fine Root", CoarseRoots = "Biomass: Coarse Root", Merchantable = "Biomass: Merchantable")
carried <- as.data.table(lapply(POOL, function(k) { f <- st[StockTypeId == k, RasterFileName]; if (length(f)) values(rast(f[1]), mat = FALSE)[rf] else rep(0, length(rf)) }))
scl <- as.data.table(datasheet(rsyncrosim::project(L, 1), "stsim_StateClass")); stl <- as.data.table(datasheet(rsyncrosim::project(L, 1), "stsim_Stratum"))
D <- cbind(data.table(cell = rf, from = scl$Name[match(values(S, mat = FALSE)[rf], scl$Id)], type = scl$Name[match(values(RT, mat = FALSE)[rf], scl$Id)],
                      eco = stl$Name[match(values(P, mat = FALSE)[rf], stl$Id)], first = values(first, mat = FALSE)[rf]), carried)
D[, carried_live := Other + Foliage + FineRoots + CoarseRoots + Merchantable]
cat(sprintf("%d reforesting cells; carried live carbon (Mg C/ha): median %.1f, range %.1f-%.1f; by start class:\n", nrow(D), median(D$carried_live), min(D$carried_live), max(D$carried_live)))
print(D[, .(cells = .N, live = round(median(carried_live), 1), other_wood = round(median(Other), 1), foliage = round(median(Foliage), 2), roots = round(median(FineRoots + CoarseRoots), 1)), by = from])
# the destination curves at ages 0-30 and the forest pools' turnover
cur <- cc[StratumId %in% unique(D$eco) & StateClassId %in% unique(D$type) & Age %in% c(0, 5, 10, 20, 30), .(eco = StratumId, type = StateClassId, Age, TotalLive)]
cat("\ndestination curves, live carbon (Mg C/ha) at age:\n"); print(dcast(cur, eco + type ~ Age, value.var = "TotalLive")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 1) else v)])
tr <- cr[Process %like% "urnover" & FromStockTypeId %in% POOL & StateClassId %in% unique(D$type), .(r = sum(Rate)), by = .(eco = StratumId, type = StateClassId, pool = names(POOL)[match(FromStockTypeId, POOL)])]
cat("\nforest live turnover (per year) of the destination types:\n"); print(dcast(tr, eco + type ~ pool, value.var = "r")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 3) else v)])
left <- function(t) { m <- merge(melt(D[, c("cell", "eco", "type", names(POOL)), with = FALSE], id.vars = c("cell", "eco", "type"), variable.name = "pool", value.name = "E"), tr, by = c("eco", "type", "pool"), all.x = TRUE)
  m[is.na(r), r := 0][, .(left = sum(E * (1 - r)^t)), by = cell]$left }
cat(sprintf("\ncarried carbon left (median of cells): after 5 years %.1f, 10 years %.1f, 20 years %.1f Mg C/ha (of %.1f)\n", median(left(5)), median(left(10)), median(left(20)), median(D$carried_live)))
cv <- function(a) cc[match(paste(D$eco, D$type, a), paste(StratumId, StateClassId, Age)), TotalLive]
cat(sprintf("model at 10 years after the transition (curve(10) + carried left) vs curve(10) alone: median %.1f vs %.1f Mg C/ha; vs curve at age 10 + the years NLCD took to show forest (median %d): %.1f\n",
            median(cv(10) + left(10)), median(cv(10)), as.integer(median(D$first)), median(cv(pmin(10 + D$first, max(cc$Age))), na.rm = TRUE)))
fwrite(D, file.path("dev", "reforestation", "carbon-at-transition-lassen.csv"))
