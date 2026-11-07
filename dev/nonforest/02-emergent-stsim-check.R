# =============================================================================
# 02-emergent-stsim-check.R - does ST-Sim hold the regional emergent wetland rates at their fitted steady state? (to-do 39 step 1)
# =============================================================================
# src/nonforest-solve.R fits the emergent wetland rates to targets by stepping a year in flow order (flows of one order from the
# stocks at the start of their step, as ApplyEquallyRankedSimultaneously = TRUE). This runs real ST-Sim on the package tables to
# check that: a synthetic non-spatial library (stsim only, no lucasCore stages) with 10 cells of each emergent class in five
# ecodivisions (Marine, Mediterranean, Subtropical, Warm Continental, Prairie), the package's emergent flow pathways, flow
# multipliers, flow order, flow groups and Net Growth, starting from defaults/initialstocks/emergent-wetland.csv, no transitions,
# 30 years. Expected: every pool stays at its starting value each year, and Deep Soil gains the region's burial rate each year
# (stockflow/emergent-wetland-fit.csv).
# Result 2026-11-06 (stsim 4.5.4): PASS. Every pool other than Deep Soil stays at its starting value for 30 years (largest relative
# gap 2.2e-6, single-precision noise) and Deep Soil gains the fitted burial each year (1.10 Marine, 1.04 Mediterranean, 1.62 elsewhere
# for estuarine; 0.5 West and Interior Plains, 1.0 Coastal Plains and Eastern for palustrine; largest gap 6.7e-6). So the solver's flow
# order rules are ST-Sim's. Note: ST-Sim deals the non-spatial cells out by chance (4-18 per stratum x class here): divide by the
# counts in stsim_OutputStratumState, not the requested share.
# 2026-11-06, with five grassland and shrubland classes added (Natural Perennial, Annual, Sage, Chaparral, Non-sage; the RAP and
# gNATSGO tables of tools/make_grass_shrub.R): PASS. Largest gap 1.1e-4 Mg C/ha (Sage BG very fast litter, 0.1155 written for a steady
# state of 0.11553: the 4-decimal rounding of the starting pools); Deep Soil gains nothing in grass and shrub (no inflow).
# 2026-11-06, literature rates and chaparral by age (cells starting at ages 0, 5, 30, 80 and 2 by ecodivision, growth and rates by age):
# PASS. Chaparral follows an R run of the same 30 years to 9.8e-6 Mg C/ha, so ST-Sim looks up a cell's growth and rates at its age at the
# start of each year (age 0 the year after a reset), and takes the age-100 row (AgeMax blank) from 100 on.
# Usage: Rscript dev/nonforest/02-emergent-stsim-check.R   (makes dev/libs/emergent-wetland-test.ssim, replacing it)
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
rd <- function(...) fread(file.path(pkg, "defaults", ...), colClasses = "character", na.strings = "", encoding = "UTF-8")
f <- file.path(pkg, "dev", "libs", "emergent-wetland-test.ssim"); dir.create(dirname(f), showWarnings = FALSE)
if (file.exists(f)) unlink(c(f, paste0(f, ".data"), paste0(f, ".temp")), recursive = TRUE)
EM <- c("Wetland: Estuarine Emergent", "Wetland: Palustrine Emergent"); ECO <- c("Marine", "Mediterranean", "Subtropical", "Warm Continental", "Prairie")
# 2026-11-06: grassland and shrubland classes too (tools/make_grass_shrub.R)
GS <- c("Grassland: Natural Perennial", "Grassland: Annual", "Shrubland: Sage", "Shrubland: Chaparral", "Shrubland: Non-sage"); CL <- c(EM, GS)
YEARS <- 30L; CELLS <- 10L

pa <- rd("stockflow", "nonforest-pathways.csv")[FromStratumId %in% ECO & FromStateClassId %in% CL]
fm <- rbind(rd("stockflow", "nonforest-multipliers-wetland.csv"), rd("stockflow", "nonforest-multipliers-grassland-shrubland.csv"), fill = TRUE)[StratumId %in% ECO & StateClassId %in% CL]
ng <- rd("stockflow", "nonforest-net-growth.csv")[StratumId %in% ECO & StateClassId %in% CL]
ini <- rbind(rd("initialstocks", "emergent-wetland.csv"), rd("initialstocks", "grassland-shrubland.csv"), rd("initialstocks", "chaparral.csv"))[StratumID %in% ECO & StateClassID %in% CL]; st <- rd("initialstocks", "stock-types.csv")
# chaparral grows by age (2026-11-06): its cells start at a different age in each ecodivision and are compared with an R run of the same years
CHAP <- "Shrubland: Chaparral"; CHAP_AGE <- c(Marine = 0L, Mediterranean = 5L, Subtropical = 30L, `Warm Continental` = 80L, Prairie = 2L)
memb <- rd("stockflow", "stsim_FlowTypeGroupMembership.csv"); ord <- rd("stockflow", "stsim_FlowOrder.csv")
fit <- rd("stockflow", "emergent-wetland-fit.csv")[StratumId %in% ECO]
ftypes <- unique(pa$FlowTypeId); stocks <- unique(c(pa$FromStockTypeId, pa$ToStockTypeId))
groups <- unique(fm$FlowGroupId[!endsWith(fm$FlowGroupId, " [Type]")])   # "<pool> ->" groups; ST-Sim makes the [Type] groups itself

L <- suppressWarnings(ssimLibrary(f, packages = "stsim")); P <- rsyncrosim::project(L, "Definitions")
sv <- function(x, s, tgt = P) saveDatasheet(tgt, as.data.frame(x), s)
sv(data.table(Name = ECO, Id = seq_along(ECO)), "stsim_Stratum")
lx <- sub(": .*$", "", CL); ly <- sub("^[^:]*: ", "", CL)
sv(data.table(Name = unique(lx)), "stsim_StateLabelX"); sv(data.table(Name = unique(ly)), "stsim_StateLabelY")
sv(data.table(Name = CL, StateLabelXId = lx, StateLabelYId = ly, Id = seq_along(CL)), "stsim_StateClass")
sv(data.table(Name = stocks), "stsim_StockType"); sv(data.table(Name = ftypes), "stsim_FlowType")
if (length(groups)) sv(data.table(Name = groups), "stsim_FlowGroup")
sv(data.table(Name = c("Net Growth", unique(st$Attribute))), "stsim_StateAttributeType")

S <- scenario(P, "Emergent wetlands, no transitions")
gm <- memb[FlowTypeId %in% ftypes & FlowGroupId %in% groups]
if (nrow(gm)) sv(gm[, .(FlowTypeId, FlowGroupId, Value = as.numeric(Value))], "stsim_FlowTypeGroupMembership", S)
sv(ord[FlowTypeId %in% ftypes, .(FlowTypeId, Order = as.numeric(Order))], "stsim_FlowOrder", S)
sv(data.table(ApplyBeforeTransitions = FALSE, ApplyEquallyRankedSimultaneously = TRUE), "stsim_FlowOrderOptions", S)
sv(data.table(MinimumTimestep = 0L, MaximumTimestep = YEARS, MinimumIteration = 1L, MaximumIteration = 1L, IsSpatial = FALSE), "stsim_RunControl", S)
sv(data.table(StateClassIdSource = CL, StateClassIdDest = CL, Location = paste0("A", seq_along(CL))), "stsim_DeterministicTransition", S)
n <- length(ECO) * length(CL) * CELLS
sv(data.table(TotalAmount = n, NumCells = n, CalcFromDist = FALSE), "stsim_InitialConditionsNonSpatial", S)
sv(CJ(StratumId = ECO, StateClassId = CL)[, AgeMin := ifelse(StateClassId == CHAP, CHAP_AGE[StratumId], 50L)][, `:=`(AgeMax = AgeMin, RelativeAmount = CELLS)], "stsim_InitialConditionsNonSpatialDistribution", S)
sav <- rbind(ng[, .(StratumId, StateClassId, StateAttributeTypeId = "Net Growth", AgeMin = as.integer(AgeMin), AgeMax = as.integer(AgeMax), Value = as.numeric(Value))],
             ini[, .(StratumId = StratumID, StateClassId = StateClassID, StateAttributeTypeId = StateAttributeTypeID, AgeMin = as.integer(AgeMin), AgeMax = as.integer(AgeMax), Value = as.numeric(Value))])
sv(sav, "stsim_StateAttributeValue", S)
sv(st[StockTypeId %in% stocks, .(StockTypeId, StateAttributeTypeId = Attribute)], "stsim_InitialStockNonSpatial", S)
sv(data.table(StockTypeId = stocks, Location = sprintf("%s%d", LETTERS[(seq_along(stocks) - 1) %/% 5 + 1], (seq_along(stocks) - 1) %% 5 + 1)), "stsim_FlowPathwayDiagram", S)
sv(pa[, .(FromStratumId, FromStateClassId, FromStockTypeId, ToStockTypeId, StateAttributeTypeId, FlowTypeId, Multiplier = as.numeric(Multiplier))], "stsim_FlowPathway", S)
sv(fm[FlowGroupId %in% c(groups, paste(ftypes, "[Type]")), .(StratumId, StateClassId, AgeMin = as.integer(AgeMin), AgeMax = as.integer(AgeMax), FlowGroupId, Value = as.numeric(Value))], "stsim_FlowMultiplier", S)
sv(data.table(SummaryOutputFL = TRUE, SummaryOutputFLTimesteps = 1L, SummaryOutputST = TRUE, SummaryOutputSTTimesteps = 1L), "stsim_OutputOptionsStockFlow", S)
sv(data.table(SummaryOutputSC = TRUE, SummaryOutputSCTimesteps = 1L), "stsim_OutputOptions", S)
sv(data.table(StageNameId = "ST-Sim", RunOrder = 1L), "core_Pipeline", S)
t0 <- Sys.time(); R <- run(S); cat(sprintf("ST-Sim: %.1f s\n", as.numeric(Sys.time() - t0, units = "secs")))

# ---- every pool per cell, each year, against its starting value ----------------------------------------------------------
os <- as.data.table(datasheet(R, "stsim_OutputStock", lookupsAsFactors = FALSE))
grp <- if ("StockGroupId" %in% names(os)) "StockGroupId" else "StockTypeId"
os <- os[get(grp) %in% paste(stocks, "[Type]") | get(grp) %in% stocks][, pool := sub(" \\[Type\\]$", "", get(grp))]
# cells per stratum x class: ST-Sim deals the cells out by chance, so count them (no transitions: the same every year)
nc <- as.data.table(datasheet(R, "stsim_OutputStratumState", lookupsAsFactors = FALSE))[Timestep == 1, .(cells = sum(Amount)), by = .(StratumId, StateClassId)]
print(nc)
x <- merge(os[, .(v = sum(Amount)), by = .(Timestep, StratumId, StateClassId, pool)], nc, by = c("StratumId", "StateClassId"))[, v := v / cells]
x <- x[!pool %in% c("Atmosphere", "Aquatic")]   # sinks outside the ecosystem accumulate
start <- ini[StateClassID != CHAP, .(StratumId = StratumID, StateClassId = StateClassID, pool = st$StockTypeId[match(StateAttributeTypeID, st$Attribute)], v0 = as.numeric(Value))]
z <- merge(x, start, by = c("StratumId", "StateClassId", "pool"), all.x = TRUE)[is.na(v0), v0 := 0]
steady <- z[pool != "Deep Soil" & Timestep >= 1 & StateClassId != CHAP]
steady[, gap := abs(v - v0) / pmax(v0, 1e-3)]
cat(sprintf("pools other than Deep Soil: largest relative gap from the starting value over %d years = %.2e\n", YEARS, max(steady$gap)))
print(steady[, .(maxgap = max(gap)), by = .(StratumId, StateClassId)][order(-maxgap)])
ds <- z[pool == "Deep Soil" & StateClassId != CHAP][order(StratumId, StateClassId, Timestep)][, gain := v - shift(v), by = .(StratumId, StateClassId)][Timestep >= 1]
ds <- merge(ds[, .(gain = mean(gain, na.rm = TRUE), first = gain[2], last = gain[.N]), by = .(StratumId, StateClassId)],
            fit[, .(StratumId, StateClassId, Burial = as.numeric(Burial))], by = c("StratumId", "StateClassId"), all.x = TRUE)[is.na(Burial), Burial := 0]   # grass and shrub: Deep Soil only holds the soil below 30 cm
print(ds)
cat(sprintf("Deep Soil gain per year vs the fitted burial: largest gap %.2e Mg C/ha/yr\n", max(abs(ds$gain - ds$Burial))))
# starting pools are written to 4 decimals, so a small pool may sit up to 5e-5 Mg C/ha off its steady state
cat(sprintf("largest absolute gap %.1e Mg C/ha\n", max(abs(steady$v - steady$v0))))
# ---- chaparral: each cell against an R run of the same years from its starting age (rates and growth looked up at the cell's age) ----
source(file.path(pkg, "src", "nonforest-solve.R"))
cgap <- 0
for (e in ECO) { a0 <- CHAP_AGE[[e]]; p <- pa[FromStratumId == e & FromStateClassId == CHAP]; mm <- fm[StratumId == e & StateClassId == CHAP]
  rates_at <- function(a) { r <- mm[is.na(AgeMin) | as.integer(AgeMin) == min(a, 100L)]; r[!(is.na(AgeMin) & FlowGroupId %in% r[!is.na(AgeMin), FlowGroupId]), .(FlowGroupId, Value)] }
  grow_at <- function(a) as.numeric(ng[StratumId == e & StateClassId == CHAP & as.integer(AgeMin) == min(a, 100L), Value])
  s0 <- ini[StratumID == e & StateClassID == CHAP & as.integer(AgeMin) == min(a0, 100L)]; S <- setNames(as.numeric(s0$Value), st$StockTypeId[match(s0$StateAttributeTypeID, st$Attribute)])
  for (t in seq_len(YEARS)) { mp <- nf_annual_map(nf_flows(p, rates_at(a0 + t - 1L), memb, ord), grow_at(a0 + t - 1L))
    v <- setNames(rep(0, length(mp$pools)), mp$pools); v[intersect(names(S), mp$pools)] <- S[intersect(names(S), mp$pools)]; S2 <- (mp$M %*% v + mp$c)[, 1]; S[names(S2)] <- S2
    got <- x[StratumId == e & StateClassId == CHAP & Timestep == t]; k <- intersect(got$pool, names(S))
    cgap <- max(cgap, max(abs(got$v[match(k, got$pool)] - S[k]))) } }
cat(sprintf("chaparral (ages %s at the start, %d years): largest gap from the R run %.1e Mg C/ha\n", paste(CHAP_AGE, collapse = ", "), YEARS, cgap))
ok <- all(steady$gap < 1e-4 | abs(steady$v - steady$v0) < 5e-4) && max(abs(ds$gain - ds$Burial)) < 1e-4 && cgap < 1e-3
cat(if (ok) "PASS: ST-Sim holds every emergent pool at the fitted steady state and buries at the target rate\n" else "FAIL\n")
fwrite(z, file.path(pkg, "dev", "nonforest", "02-emergent-stsim-check-result.csv"))
