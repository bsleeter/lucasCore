# =============================================================================
# 10-postfire-floor.R - where the model's forest floor (AG Very Fast + AG Slow) comes from after a high-severity fire
# =============================================================================
# One cell (default California Mixed Conifer, Mediterranean Mountains), P26's inputs, the fitted event table (09) and the decay
# multipliers fitted with it (out-cal-events/calibration.rds). Reports the floor just before the fire (end of the spin-up cycle), what
# the fire leaves of it, what the fire's killed live pools add, and over the next 10 years each year's inflow to the floor by source:
# decay of snags, down logs, fine woody debris and dead roots (CBM sends all woody decay to AG Slow) and turnover of the regrowing stand.
# Compared with the measured floor after high-severity fire (07). Read-only.
# Usage: Rscript dev/fia/10-postfire-floor.R [forest type group, default 370]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(sf); library(terra); library(DBI) })
a <- commandArgs(TRUE); g0 <- if (length(a)) as.integer(a[1]) else 370L
pkg <- "F:/lucasCore"; for (f in c("growth.R", "flows.R", "dom.R", "calibrate.R")) source(file.path(pkg, "src", f))
r <- readRDS(file.path(pkg, "dev/fia/out-cal-events/calibration.rds")); k <- r$cells[sc == g0]; mu <- as.list(r$M[[as.character(g0)]]$mult)
lib <- file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim"); con <- dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO)
scl <- as.data.table(dbGetQuery(con, "SELECT StateClassId, Name, Id FROM stsim_StateClass")); stl <- as.data.table(dbGetQuery(con, "SELECT StratumId, Name FROM stsim_Stratum"))
cc <- as.data.table(dbGetQuery(con, "SELECT * FROM lucasCore_CarbonCurve WHERE ScenarioId = 2")); dbDisconnect(con)
cc[, `:=`(Stratum = stl$Name[match(StratumId, stl$StratumId)], StateClass = scl$Name[match(StateClassId, scl$StateClassId)])]
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv"))[, StateClass := scl$Name[match(StateClassId, scl$Id)]]
ctx <- list(cc = cc, cw = cw, dens = fread(file.path(pkg, "defaults/growth/merch-carbon-density.csv")), cbm = file.path(pkg, "defaults/cbm"),
            fo = fread(file.path(pkg, "defaults/stockflow/stsim_FlowOrder.csv")), ev = fread(file.path(pkg, "dev/fia/event-pathways-fitted.csv"), na.strings = ""))
DECAY_GROUPS <- list(snag = c("SnagStem", "SnagBranch"), cwd = c("AGM", "BGF"), fwd = "AGF", litter = "AGVF", duff = "AGS", soil = c("BGVF", "BGS"))
S <- cal_setup(k, ctx); m <- dom_matrices(S$vals, ctx$fo, mu); vals <- scale_decay(S$vals, mu)
d <- dom_by_age(m, S$live, k$ri, S$hist, S$hist)                     # fire last: row 1 = just after the fire
# the end of the spin-up cycle, just before the fire (as dom_by_age computes it)
la <- function(a) S$live[min(a, nrow(S$live) - 1) + 1, ]; n <- nrow(m$A); Ari <- diag(n); c0 <- numeric(n)
for (aa in 0:(k$ri - 1)) { c0 <- m$A %*% c0 + m$Apost %*% (m$Tm %*% la(aa)); Ari <- m$A %*% Ari }
x0 <- solve(diag(n) - S$hist$Dd %*% Ari, S$hist$Dd %*% c0 + S$hist$Dl %*% la(k$ri)); xe <- drop(Ari %*% x0 + c0); names(xe) <- rownames(m$A)
kept <- drop(S$hist$Dd %*% xe); names(kept) <- names(xe); added <- drop(S$hist$Dl %*% la(k$ri)); names(added) <- names(xe)
cat(sprintf("%s, return interval %d yr; live pools at the fire (Mg C/ha): %s\n", k$StateClass, k$ri, paste(sprintf("%s %.1f", names(la(k$ri)), la(k$ri)), collapse = ", ")))
cat("\nForest floor at the fire (Mg C/ha):\n")
print(data.table(pool = c("AG Very Fast (leaf litter)", "AG Slow (humus)"), before = round(xe[c("AGVF", "AGS")], 1), left_by_fire = round(kept[c("AGVF", "AGS")], 1),
                 added_by_killed_live = round(added[c("AGVF", "AGS")], 1), just_after = round(d[1, c("AGVF", "AGS")], 1)))
cat(sprintf("Killed live pools into leaf litter (AG Very Fast): %s\n", paste(sprintf("%s %.2f", names(LIVE_POOLS), S$hist$Dl["AGVF", ] * la(k$ri)), collapse = ", ")))
# yearly inflow to the floor by source over the next 10 years: decay to AG Slow and turnover to AG Very Fast
dec <- function(p) { nmf <- grep(sprintf("^Decay: %s -> AG Slow$", c(AGVF = "AG Very Fast", AGF = "AG Fast", AGM = "AG Medium", SnagStem = "Snag Stem", SnagBranch = "Snag Branch")[[p]]), names(vals), value = TRUE)
  if (length(nmf)) vals[[nmf]] else 0 }
yr <- rbindlist(lapply(0:10, function(a) { x <- d[a + 1, ]
  data.table(year = a, floor = x[["AGVF"]] + x[["AGS"]], snags = x[["SnagStem"]] + x[["SnagBranch"]], from_snags = dec("SnagStem") * x[["SnagStem"]] + dec("SnagBranch") * x[["SnagBranch"]],
             from_downlogs = dec("AGM") * x[["AGM"]], from_fwd = dec("AGF") * x[["AGF"]], from_litter_humified = dec("AGVF") * x[["AGVF"]],
             from_regrowth_turnover = sum((m$Tm %*% la(a))[c("AGVF")]), humus_emitted = vals[["Emission: AG Slow -> Atmosphere"]] * x[["AGS"]],
             humus_to_mineral_soil = vals[["Transfer: AG Slow -> BG Slow"]] * x[["AGS"]]) }))
cat("\nAfter the fire, Mg C/ha (yearly flows in Mg C/ha/yr):\n"); print(yr[, lapply(.SD, function(z) round(z, 2))])
cat("\nMeasured floor after high-severity fire (07, same type): see dev/fia/out-cal-events/young-stand-replacing.csv\n")
print(fread(file.path(pkg, "dev/fia/out-cal-events/young-stand-replacing.csv"))[sc == g0 & kind == "fire", .(years, n, floor_measured = round(floor, 1), floor_model = round(floor_model, 1))])
