# =============================================================================
# 15-clearcut-fit.R - fit the clearcut event flows to FIA's measured dead pools 0-20 years after clearcut (Mixed Conifer and Ponderosa,
# Mediterranean Mountains, pooled), then rerun 06 and 07 with them
# =============================================================================
# Four values, everything else as the fitted event table (09):
#   snag_kept     share of standing snags (stem and branch) left standing             (LUCAS today 0: all felled)
#   snag_to_logs  of the felled snags, the share left on site as down logs / branch litter; the rest removed or burned  (today 1)
#   logs_kept     share of the existing down logs (AG Medium) kept; the rest removed or burned in site preparation   (today 1)
#   slash         share of branches, tops and foliage left on site (AG Fast / AG Very Fast)                          (09: 0.13)
# Model: the clearcut-last spin-up curve with 13's decay multipliers and snag fall, 14's fire snag shares (out-cal-share); target: 07's
# measured snags, down logs and fine woody debris after clearcut (out-cal-share/young-stand-replacing.csv), weighted by plots, each pool
# scaled by its mean. Writes dev/fia/event-pathways-fitted2.csv and reruns 06 and 07 into dev/fia/out-cal-clearcut.
# Usage: Rscript dev/fia/15-clearcut-fit.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(DBI) })
pkg <- "F:/lucasCore"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
for (f in c("growth.R", "flows.R", "dom.R", "calibrate.R")) source(file.path(pkg, "src", f))
r <- readRDS(file.path(pkg, "dev/fia/out-cal-share/calibration.rds"))
obs <- fread(file.path(pkg, "dev/fia/out-cal-share/young-stand-replacing.csv"))[kind == "harvest" & sc %in% c(370L, 220L) & years != "(20,30]"]
SNAG_FALL <- fread(file.path(pkg, "dev/fia/snag-fall-measured.csv")); FIRE_SNAG <- fread(file.path(pkg, "dev/fia/fire-snag-share.csv"))
FALLS <- c("Transfer: Snag Stem -> AG Medium", "Transfer: Snag Branch -> AG Fast")
scale_decay <- function(vals, mult = NULL) { fp <- FOREST_PATHWAYS[match(names(vals), FlowType)]; from <- names(DOM_POOLS)[match(fp$From, DOM_POOLS)]
  if (!is.null(mult)) for (g in names(mult)) { k <- !is.na(from) & from %in% DECAY_GROUPS[[g]] & !names(vals) %in% c("Transfer: AG Slow -> BG Slow", FALLS); vals[k] <- vals[k] * mult[[g]] }
  for (p in unique(na.omit(from))) { k <- !is.na(from) & from == p; t <- sum(vals[k]); if (t > 1) vals[k] <- vals[k] / t }
  vals }
DECAY_GROUPS <- list(snag = c("SnagStem", "SnagBranch"), cwd = c("AGM", "BGF"), fwd = "AGF", litter = "AGVF", duff = "AGS", soil = c("BGVF", "BGS"))
con <- dbConnect(RSQLite::SQLite(), file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim"), flags = RSQLite::SQLITE_RO)
scl <- as.data.table(dbGetQuery(con, "SELECT StateClassId, Name, Id FROM stsim_StateClass")); stl <- as.data.table(dbGetQuery(con, "SELECT StratumId, Name FROM stsim_Stratum"))
cc <- as.data.table(dbGetQuery(con, "SELECT * FROM lucasCore_CarbonCurve WHERE ScenarioId = 2")); dbDisconnect(con)
cc[, `:=`(Stratum = stl$Name[match(StratumId, stl$StratumId)], StateClass = scl$Name[match(StateClassId, scl$StateClassId)])]
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv"))[, StateClass := scl$Name[match(StateClassId, scl$Id)]]
ev0 <- fread(file.path(pkg, "dev/fia/event-pathways-fitted.csv"), na.strings = ""); for (k in names(ev0)) set(ev0, j = k, value = as.character(ev0[[k]]))   # text, blanks kept as NA
CUT <- "Forest Harvest: Forest Clearcut [Type]"
emis <- function(from, total) data.table(FromStockTypeId = from, ToStockTypeId = c("Atmosphere: CO2", "Atmosphere: CO", "Atmosphere: CH4"), TransitionGroupId = CUT,
                                         FlowTypeId = c("LULC: Emission Live CO2", "LULC: Emission Live CO", "LULC: Emission Live CH4"), Multiplier = as.character(round(total * c(0.9, 0.09, 0.01), 6)))
row <- function(from, to, v, ft) data.table(FromStockTypeId = from, ToStockTypeId = to, TransitionGroupId = CUT, FlowTypeId = ft, Multiplier = as.character(v))
clearcut_table <- function(p) {   # the clearcut rows rebuilt from the four values (merchantable: 0.97 harvested, 0.03 down logs; roots unchanged)
  e <- ev0[!(TransitionGroupId == CUT & FromStockTypeId %in% c("Biomass: Other Wood", "Biomass: Foliage", "DOM: Snag Stem", "DOM: Snag Branch", "DOM: Aboveground Medium"))]
  felled <- 1 - p$snag_kept
  rbind(e, row("Biomass: Other Wood", "DOM: Aboveground Fast", p$slash, "LULC: Mortality Live"), emis("Biomass: Other Wood", 1 - p$slash),
        row("Biomass: Foliage", "DOM: Aboveground Very Fast", p$slash, "LULC: Mortality Live"), emis("Biomass: Foliage", 1 - p$slash),
        row("DOM: Snag Stem", "DOM: Aboveground Medium", felled * p$snag_to_logs, "LULC: Transfer DOM"), emis("DOM: Snag Stem", felled * (1 - p$snag_to_logs)),
        row("DOM: Snag Branch", "DOM: Aboveground Fast", felled * p$snag_to_logs, "LULC: Transfer DOM"), emis("DOM: Snag Branch", felled * (1 - p$snag_to_logs)),
        emis("DOM: Aboveground Medium", 1 - p$logs_kept), fill = TRUE) }
setup <- function(k) { ctx <- list(cc = cc, cw = cw, dens = fread(file.path(pkg, "defaults/growth/merch-carbon-density.csv")), cbm = file.path(pkg, "defaults/cbm"),
                                   fo = fread(file.path(pkg, "defaults/stockflow/stsim_FlowOrder.csv")), ev = ev0)
  S <- cal_setup(k, ctx); f <- SNAG_FALL[Group == k$sc, StemFall] / S$vals[["Transfer: Snag Stem -> AG Medium"]]; S$vals[FALLS] <- S$vals[FALLS] * f
  s <- FIRE_SNAG[Group == k$sc, Share]; S$hist$Dl["SnagStem", "Merchantable"] <- s * 0.65 / 0.545; S$hist$Dl["SnagBranch", "Other"] <- s * 0.30 / 0.545
  list(S = S, m = dom_matrices(S$vals, ctx$fo, as.list(r$M[[as.character(k$sc)]]$mult)), k = k) }
cells <- lapply(which(r$cells$sc %in% c(370L, 220L)), function(i) setup(r$cells[i]))
pred <- function(p) { tab <- clearcut_table(p); rbindlist(lapply(cells, function(z) { H <- disturbance_matrices(tab, CUT, z$k$StateClass, z$k$ri)
  d <- dom_by_age(z$m, z$S$live, z$k$ri, z$S$hist, H)
  data.table(sc = z$k$sc, age = 0:20, standing = rowSums(d[1:21, c("SnagStem", "SnagBranch")]), cwd = d[1:21, "AGM"], fwd = d[1:21, "AGF"], floor = rowSums(d[1:21, c("AGVF", "AGS")])) }))[
  , years := as.character(cut(age, c(-1, 5, 10, 20)))][, lapply(.SD, mean), by = .(sc, years), .SDcols = c("standing", "cwd", "fwd", "floor")] }
P3 <- c("standing", "cwd", "fwd"); sc_ <- sapply(P3, function(v) weighted.mean(obs[[v]], obs$n))
loss <- function(p) { z <- merge(obs, pred(p), by = c("sc", "years"), suffixes = c("", "_m")); sum(sapply(P3, function(v) sum(z$n * ((z[[paste0(v, "_m")]] - z[[v]]) / sc_[[v]])^2))) }
today <- list(snag_kept = 0, snag_to_logs = 1, logs_kept = 1, slash = 0.13)
G <- CJ(snag_kept = c(0, 0.1, 0.2, 0.3, 0.4), snag_to_logs = c(0, 0.25, 0.5, 0.75, 1), logs_kept = c(0.2, 0.35, 0.5, 0.65, 0.8, 1), slash = c(0.04, 0.07, 0.10, 0.13))
G[, L := mapply(function(a, b, c, d) loss(list(snag_kept = a, snag_to_logs = b, logs_kept = c, slash = d)), snag_kept, snag_to_logs, logs_kept, slash)]
best <- as.list(G[which.min(L)]); cat(sprintf("misfit: 09's clearcut %.1f, best %.1f\n", loss(today), best$L)); print(G[order(L)][1:8])
z <- merge(obs, pred(best), by = c("sc", "years"), suffixes = c("", "_m")); z0 <- merge(obs, pred(today), by = c("sc", "years"), suffixes = c("", "_m"))
cat("\nAfter clearcut, measured / fitted model (09's model):\n")
print(z[order(sc, years)][, .(type = ifelse(sc == 370, "Mixed Conifer", "Ponderosa"), years, n, snags = sprintf("%.1f / %.1f (%.1f)", standing, standing_m, z0$standing_m),
        downlogs = sprintf("%.1f / %.1f (%.1f)", cwd, cwd_m, z0$cwd_m), fwd = sprintf("%.1f / %.1f (%.1f)", fwd, fwd_m, z0$fwd_m), floor = sprintf("%.1f / %.1f (%.1f)", floor, floor_m, z0$floor_m))])
tab <- clearcut_table(best); for (k in names(tab)) set(tab, j = k, value = ifelse(is.na(tab[[k]]), "", tab[[k]]))
fwrite(tab, file.path(pkg, "dev/fia/event-pathways-fitted2.csv")); cat("written dev/fia/event-pathways-fitted2.csv\n")
Sys.setenv(LUCAS_EVENT_FILE = file.path(pkg, "dev/fia/event-pathways-fitted2.csv"), LUCAS_SNAG_FALL = file.path(pkg, "dev/fia/snag-fall-measured.csv"),
           LUCAS_FIRE_SNAG = file.path(pkg, "dev/fia/fire-snag-share.csv"), LUCAS_CAL_OUT = file.path(pkg, "dev/fia/out-cal-clearcut"))
for (s in c("06-calibrate-measured.R", "07-young-stand-replacing.R")) { cat("\n==== ", s, "\n"); o <- system2(RS, file.path(pkg, "dev/fia", s), stdout = TRUE, stderr = TRUE); cat(tail(o, 3), sep = "\n") }
