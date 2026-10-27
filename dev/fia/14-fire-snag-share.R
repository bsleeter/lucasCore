# =============================================================================
# 14-fire-snag-share.R - fit, per forest type, the share of live aboveground wood a high-severity fire leaves as snags, to FIA's
# measured snags 0-20 years after high-severity fire; then rerun the mature-stand calibration (06) and the young-stand check (07) with it
# =============================================================================
# Model as in 13 (fitted event table, snag fall at the measured rates, decay multipliers from out-cal-snagfall), the fire-last spin-up
# curve; target: 07's measured snags after high-severity fire in the 0-5, 5-10 and 10-20 year bins (out-cal-snagfall/
# young-stand-replacing.csv), weighted by plots. Grid 0.10-0.70. Writes dev/fia/fire-snag-share.csv and reruns 06 and 07 into
# dev/fia/out-cal-share.
# Usage: Rscript dev/fia/14-fire-snag-share.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(DBI) })
pkg <- "F:/lucasCore"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
for (f in c("growth.R", "flows.R", "dom.R", "calibrate.R")) source(file.path(pkg, "src", f))
r <- readRDS(file.path(pkg, "dev/fia/out-cal-snagfall/calibration.rds")); obs <- fread(file.path(pkg, "dev/fia/out-cal-snagfall/young-stand-replacing.csv"))[kind == "fire" & years != "(20,30]"]
SNAG_FALL <- fread(file.path(pkg, "dev/fia/snag-fall-measured.csv")); FALLS <- c("Transfer: Snag Stem -> AG Medium", "Transfer: Snag Branch -> AG Fast")
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
ctx <- list(cc = cc, cw = cw, dens = fread(file.path(pkg, "defaults/growth/merch-carbon-density.csv")), cbm = file.path(pkg, "defaults/cbm"),
            fo = fread(file.path(pkg, "defaults/stockflow/stsim_FlowOrder.csv")), ev = fread(file.path(pkg, "dev/fia/event-pathways-fitted.csv"), na.strings = ""))
BIN <- function(a) cut(a, c(-1, 5, 10, 20))
fit <- rbindlist(lapply(seq_len(nrow(r$cells)), function(i) { k <- r$cells[i]; S <- cal_setup(k, ctx)
  f <- SNAG_FALL[Group == k$sc, StemFall] / S$vals[["Transfer: Snag Stem -> AG Medium"]]; S$vals[FALLS] <- S$vals[FALLS] * f
  m <- dom_matrices(S$vals, ctx$fo, as.list(r$M[[as.character(k$sc)]]$mult)); o <- obs[sc == k$sc]
  curve <- function(s) { H <- S$hist; H$Dl["SnagStem", "Merchantable"] <- s * 0.65 / 0.545; H$Dl["SnagBranch", "Other"] <- s * 0.30 / 0.545
    d <- dom_by_age(m, S$live, k$ri, H, H); data.table(age = 0:20, snags = rowSums(d[1:21, c("SnagStem", "SnagBranch")]), logs = d[1:21, "AGM"])[, years := as.character(BIN(age))][, .(snags = mean(snags), logs = mean(logs)), by = years] }
  grid <- seq(0.10, 0.70, 0.02)
  sse <- sapply(grid, function(s) { z <- merge(o, curve(s), by = "years", suffixes = c("", "_m")); sum(z$n * (z$snags - z$standing)^2) })
  best <- grid[which.min(sse)]; z <- merge(o, curve(best), by = "years", suffixes = c("", "_m")); z0 <- merge(o, curve(0.545), by = "years", suffixes = c("", "_m"))
  data.table(Group = k$sc, type = sub("Forest: ", "", k$StateClass), Share = best, plots = sum(o$n),
             snags = paste(sprintf("%s: %.0f / %.0f (was %.0f)", z$years, z$standing, z$snags_m, z0$snags_m), collapse = "; "),
             logs = paste(sprintf("%s: %.0f / %.0f (was %.0f)", z$years, z$cwd, z$logs, z0$logs), collapse = "; ")) }))
cat("Fitted high-severity fire snag share per type (measured / model, Mg C/ha, by years since fire):\n"); options(width = 250); print(fit)
fwrite(fit[, .(Group, Share, Source = paste0(type, ": fitted to ", plots, " plots, 0-20 yr after high-severity fire, Mediterranean Mountains (14-fire-snag-share.R)"))], file.path(pkg, "dev/fia/fire-snag-share.csv"))
Sys.setenv(LUCAS_EVENT_FILE = file.path(pkg, "dev/fia/event-pathways-fitted.csv"), LUCAS_SNAG_FALL = file.path(pkg, "dev/fia/snag-fall-measured.csv"),
           LUCAS_FIRE_SNAG = file.path(pkg, "dev/fia/fire-snag-share.csv"), LUCAS_CAL_OUT = file.path(pkg, "dev/fia/out-cal-share"))
for (s in c("06-calibrate-measured.R", "07-young-stand-replacing.R")) { cat("\n==== ", s, "\n"); o <- system2(RS, file.path(pkg, "dev/fia", s), stdout = TRUE, stderr = TRUE); cat(tail(o, 4), sep = "\n") }
