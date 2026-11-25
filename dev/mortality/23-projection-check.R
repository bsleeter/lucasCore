# =============================================================================
# 23-projection-check.R - to-do 3 phase 2: does a projection place drought and insect mortality as stage 9 set it?
# =============================================================================
# Reads a finished projection (its result scenario) and the Projection Setup result it ran from, read-only, and reports:
#   1. amount   the area the run realized per iteration and year against the area the drawn rates give on the forest open at the
#               projection's start (each unit's rate x its cells in the class and at or over the minimum age)
#   2. patches  the sizes of the run's yearly patches (8-neighbour cells, from its yearly transition maps) against the size
#               distribution stage 9 wrote
#   3. spread   the share of the run's events with die-off within the adjacency radius in the window of years before, against
#               the same share for the other open cells
# Usage: Rscript dev/mortality/23-projection-check.R <library.ssim> <projection result id> <setup result id> [--min-age=20]
# =============================================================================
suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(data.table); library(terra) }); options(width = 200); terraOptions(progress = 0)
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; lib <- normalizePath(pos[1], winslash = "/"); rid <- as.integer(pos[2]); sid <- as.integer(pos[3]); mage <- as.numeric(opt("min-age", 20))
source("src/mortality.R")
con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
g <- q("select TransitionGroupId id from stsim_TransitionGroup where Name = '%s'", MORT_GROUP)$id
scl <- q("select StateClassId, Name, Id from stsim_StateClass"); st <- q("select StratumId, Name, Id from stsim_Stratum")
term <- q("select AmountUnits from stsim_Terminology")
tr <- q("select Iteration, Timestep, sum(Amount) Amount from stsim_OutputStratumTransition where ScenarioId = %d and TransitionGroupId = %d group by Iteration, Timestep", rid, g)
rc <- q("select * from stsim_RunControl where ScenarioId = %d", rid); its <- rc$MinimumIteration:rc$MaximumIteration; yrs <- (rc$MinimumTimestep + 1L):rc$MaximumTimestep
tmv <- q("select Iteration, Timestep, StratumId, StateClassId, Amount from stsim_TransitionMultiplierValue where ScenarioId = %d and TransitionGroupId = %d", sid, g)
sch <- q("select Iteration, Timestep, HistoricalYear from lucasCore_OutputProjectionSchedule where ScenarioId = %d and SamplingSet = '%s'", sid, MORT_SET)
ic <- q("select * from stsim_InitialConditionsSpatial where ScenarioId = %d", sid); smf <- q("select Timestep, MultiplierFileName f from stsim_TransitionSpatialMultiplier where ScenarioId = %d and TransitionGroupId = %d", sid, g)
sdz <- q("select MaximumArea, RelativeAmount from stsim_TransitionSizeDistribution where ScenarioId = %d and TransitionGroupId = %d order by MaximumArea", sid, g)
adj <- q("select NeighborhoodRadius r from stsim_TransitionAdjacencySetting where ScenarioId = %d and TransitionGroupId = %d", sid, g)
tst <- q("select TSTFileName f from stsim_InitialTSTSpatial where ScenarioId = %d and TransitionGroupId = %d", sid, g)
dbDisconnect(con)
dS <- file.path(paste0(lib, ".data"), sprintf("Scenario-%d", sid)); dR <- file.path(paste0(lib, ".data"), sprintf("Scenario-%d", rid))
S <- rast(file.path(dS, "stsim_InitialConditionsSpatial", ic$StateClassFileName)); vS <- values(S, mat = FALSE); vA <- values(rast(file.path(dS, "stsim_InitialConditionsSpatial", ic$AgeFileName)), mat = FALSE)
vP <- values(rast(file.path(dS, "stsim_InitialConditionsSpatial", ic$StratumFileName)), mat = FALSE); land <- !is.na(vP); km <- prod(res(S)) / 1e6; ha <- prod(res(S)) / 1e4
pw <- fread("defaults/transitions/pathways/mortality.csv"); src <- as.integer(scl$Id[match(pw$StateClassIdSource, scl$Name)]); elig <- land & vS %in% src; open0 <- elig & !is.na(vA) & vA >= mage
cat(sprintf("projection result %d on setup result %d: %d iterations, %d-%d; %d softwood cells at the start (%.0f km2), %d at or over age %g\n", rid, sid, length(its), min(yrs), max(yrs), sum(elig), sum(elig) * km, sum(open0), mage))

cat("\n===== 1. Amount: realized against the drawn rates =====\n")
cells <- data.table(StratumId = st$StratumId[match(vP[open0], as.integer(st$Id))], StateClassId = scl$StateClassId[match(vS[open0], as.integer(scl$Id))])[, .(n = .N), by = .(StratumId, StateClassId)]
ex <- merge(tmv[!is.na(StratumId)], cells, by = c("StratumId", "StateClassId"))[, .(Expected = sum(Amount * n) * km), by = .(Iteration, Timestep)]
tr[, Realized := Amount * km / ha]   # (amounts are in hectares in a library with the default terminology)
o <- merge(merge(CJ(Iteration = its, Timestep = yrs), ex, all.x = TRUE), tr[, .(Iteration, Timestep, Realized)], all.x = TRUE, by = c("Iteration", "Timestep")); o[is.na(Realized), Realized := 0]; o[is.na(Expected), Expected := 0]
o <- merge(o, sch, by = c("Iteration", "Timestep"), all.x = TRUE)
cat("by iteration (km2 over the run):\n"); print(o[, .(Expected = round(sum(Expected), 1), Realized = round(sum(Realized), 1), Ratio = round(sum(Realized) / sum(Expected), 2), DrawnYears = paste(range(HistoricalYear), collapse = "-")), by = Iteration])
cat(sprintf("all iterations: expected %.1f km2, realized %.1f km2, ratio %.2f; per year %.2f against %.2f km2\n", sum(o$Expected), sum(o$Realized), sum(o$Realized) / sum(o$Expected), sum(o$Realized) / nrow(o), sum(o$Expected) / nrow(o)))
o[, Size := cut(Expected, c(-1, 2, 5, 15, 1e9), labels = c("under 2 km2", "2-5", "5-15", "over 15"))]
cat("by the size of the year the draw gave:\n"); print(o[, .(Years = .N, Expected = round(sum(Expected), 1), Realized = round(sum(Realized), 1), Ratio = round(sum(Realized) / max(sum(Expected), 1e-9), 2)), by = Size][order(Size)])
cat(sprintf("correlation of realized with expected over the %d iteration-years: %.2f\n", nrow(o), cor(o$Expected, o$Realized)))
cat("first iteration, year by year:\n"); print(o[Iteration == its[1], .(Timestep, HistoricalYear, Expected = round(Expected, 2), Realized = round(Realized, 2))])

tf <- function(i, y) file.path(dR, "stsim_OutputSpatialTransition", sprintf("tg_%d.it%d.ts%d.tif", g, i, y))
if (!file.exists(tf(its[1], yrs[1]))) { cat("\nno yearly transition maps of the group in the result: patches and spread not checked\n"); quit(save = "no") }
cat("\n===== 2. Patch sizes: the run's yearly patches against the distribution =====\n")
ev0 <- rep(NA_integer_, ncell(S)); if (nrow(tst)) { t0 <- values(rast(file.path(dS, "stsim_InitialTSTSpatial", tst$f[1])), mat = FALSE); k <- !is.na(t0) & t0 < MORT_NEVER; ev0[k] <- rc$MinimumTimestep - t0[k] }
evs <- list(); sizes <- integer()
for (i in its) { ev <- ev0; for (y in yrs) { f <- tf(i, y); if (!file.exists(f)) next; v <- values(rast(f), mat = FALSE); k <- !is.na(v) & v > 0; if (!any(k)) next
    ev[k] <- y; sizes <- c(sizes, as.integer(table(values(patches(setValues(S, ifelse(k, 1, NA)), directions = 8), mat = FALSE)))) }
  evs[[as.character(i)]] <- ev }
br <- round(sdz$MaximumArea / ha); want <- sdz$RelativeAmount * br; b <- factor(findInterval(sizes, c(0, br), left.open = TRUE) + 0L, levels = seq_len(length(br) + 1L))
got_n <- as.integer(table(b)); got_a <- as.numeric(tapply(sizes, b, sum)); got_a[is.na(got_a)] <- 0
print(data.table(SizeToCells = c(br, Inf), WantedPatchShare = round(c(sdz$RelativeAmount / sum(sdz$RelativeAmount), 0), 3), RunPatchShare = round(got_n / sum(got_n), 3),
                 WantedAreaShare = round(c(sdz$RelativeAmount * br, 0) / sum(sdz$RelativeAmount * br), 3), RunAreaShare = round(got_a / sum(got_a), 3)))
cat(sprintf("run: %d patches, mean %.2f cells, largest %d; single cells hold %.0f%% of the area (map area %.1f km2 against %.1f km2 in the tables)\n", length(sizes), mean(sizes), max(sizes), 100 * sum(sizes == 1) / sum(sizes), sum(sizes) * km, sum(o$Realized)))

cat("\n===== 3. Spread: events beside recent die-off =====\n")
rad <- if (nrow(adj)) round(adj$r[1] / res(S)[1]) else MORTP$radius; kk <- -rad:rad; w <- outer(kk, kk, function(x, y) as.numeric(x^2 + y^2 <= rad^2)); nE <- 0; nEn <- 0; nO <- 0; nOn <- 0
for (i in its) { ev <- evs[[as.character(i)]]; for (y in yrs) { rec <- !is.na(ev) & ev < y & ev >= y - MORTP$window
    near <- if (any(rec)) values(focal(setValues(S, as.numeric(rec)), w, "sum", na.rm = TRUE), mat = FALSE) > 0 else rep(FALSE, ncell(S))
    e <- ev %in% y; op <- open0 & (is.na(ev) | ev > y); nE <- nE + sum(e); nEn <- nEn + sum(e & near); nO <- nO + sum(op); nOn <- nOn + sum(op & near) } }
cat(sprintf("events with die-off within %d cells in the %d years before: %.0f%% (%d of %d); other open cells: %.1f%%; an event is %.1f times as likely beside recent die-off\n",
            rad, MORTP$window, 100 * nEn / max(nE, 1), nEn, nE, 100 * nOn / max(nO, 1), (nEn / max(nOn, 1)) / (max(nE - nEn, 1) / max(nO - nOn, 1))))
if (nrow(smf[Timestep > rc$MinimumTimestep])) { sf <- values(rast(file.path(dS, "stsim_TransitionSpatialMultiplier", smf[Timestep > rc$MinimumTimestep, f][1])), mat = FALSE)
  e <- Reduce(`|`, lapply(evs, function(ev) !is.na(ev) & ev > rc$MinimumTimestep)); cat(sprintf("surface weight: mean %.2f on the cells that took the event in the run, %.2f on the open cells at the start\n", mean(sf[e], na.rm = TRUE), mean(sf[open0], na.rm = TRUE))) }
