# =============================================================================
# 06-calibrate-measured.R - decay calibration against FIA's MEASURED dead pools in mature stands only (user decision 2026-10-26)
# =============================================================================
# For P26's main forest types in the Mediterranean Mountains ecodivision, on P26's own inputs (Build result 2: carbon curves, return
# intervals, soil targets; ecodivision temperature from PRISM), two calibrations side by side:
#   current   stage 3 as it is (src/calibrate.R cal_fit): condition-table standing dead, modelled down dead and litter, every age band,
#             fire/clearcut mix fitted; FIA-consistent grouping (src/dom.R FIA_DOM)
#   measured  five multipliers, one per measured pool: snags (decay and fall), down logs (AG Medium + BG Fast) to coarse woody debris +
#             piles, fine woody debris (AG Fast), litter (AG Very Fast), duff (AG Slow); targets from California's down woody material
#             plots (COND_DWM_CALC) and measured standing dead, stand age >= 60 only, no recorded fire or harvest at the plot in the past
#             30 years; the spin-up's last disturbance is high-severity fire (no clearcut share)
# then soil to gSSURGO for each. Checks the young stands against the measured years since fire and since harvest (fire-last and
# clearcut-last curves). Writes dev/fia/out-cal/ (multipliers, fit tables, figure). Read-only.
# Usage: Rscript dev/fia/06-calibrate-measured.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(sf); library(terra); library(DBI) })
pkg <- "F:/lucasCore"; dm <- "F:/lucas-master/Data Sources/FIA/DataMart"
# dev variants (09-fit-events.R): LUCAS_CAL_OUT = output folder, LUCAS_EVENT_FILE = event flow table in place of the package's
out <- Sys.getenv("LUCAS_CAL_OUT", file.path(pkg, "dev/fia/out-cal")); dir.create(out, showWarnings = FALSE)
event_file <- Sys.getenv("LUCAS_EVENT_FILE", file.path(pkg, "defaults/stockflow/event-pathways.csv")); cat("event flows:", event_file, "\n")
for (f in c("growth.R", "flows.R", "dom.R", "calibrate.R")) source(file.path(pkg, "src", f))
# LUCAS_SNAG_FALL (dev, 13-snag-fall-fixed.R): a csv of measured annual stem snag fall rates per FIA forest type group (Group, StemFall).
# Snag fall is then fixed at that rate (branch snags scaled alike relative to CBM's rates) and the snag multiplier scales only decay and
# emission of the snags, not their fall.
snag_file <- Sys.getenv("LUCAS_SNAG_FALL", "")
if (nzchar(snag_file)) {
  SNAG_FALL <- fread(snag_file); cat("snag fall fixed from", snag_file, ":", paste(sprintf("%d %.3f", SNAG_FALL$Group, SNAG_FALL$StemFall), collapse = ", "), "\n")
  FALLS <- c("Transfer: Snag Stem -> AG Medium", "Transfer: Snag Branch -> AG Fast")
  scale_decay <- function(vals, mult = NULL) {   # dom.R's, with the snag fall transfers left out of the multipliers
    fp <- FOREST_PATHWAYS[match(names(vals), FlowType)]; from <- names(DOM_POOLS)[match(fp$From, DOM_POOLS)]
    if (!is.null(mult)) for (g in names(mult)) { k <- !is.na(from) & from %in% DECAY_GROUPS[[g]] & !names(vals) %in% c("Transfer: AG Slow -> BG Slow", FALLS); vals[k] <- vals[k] * mult[[g]] }
    for (p in unique(na.omit(from))) { k <- !is.na(from) & from == p; t <- sum(vals[k]); if (t > 1) vals[k] <- vals[k] / t }
    vals }
  cal_setup0 <- cal_setup
  cal_setup <- function(k, ctx) { S <- cal_setup0(k, ctx); r <- SNAG_FALL[Group == k$sc, StemFall]
    if (length(r)) { f <- r / S$vals[["Transfer: Snag Stem -> AG Medium"]]; S$vals[FALLS] <- S$vals[FALLS] * f }
    S }
}
lib <- file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim"); MIN_AGE <- 60L; RECENT <- 30L
TYPES <- c(`370` = "California Mixed Conifer Group", `260` = "Fir/Spruce/Mountain Hemlock Group", `220` = "Ponderosa Pine Group", `920` = "Western Oak Group")
STRATUM <- "Mediterranean Mountains"; ECODIV <- "M260"

# ---- P26's inputs -------------------------------------------------------------------------------------------------------------
con <- dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO); q <- function(s) as.data.table(dbGetQuery(con, s))
scl <- q("SELECT StateClassId, Name, Id FROM stsim_StateClass"); stl <- q("SELECT StratumId, Name, Id FROM stsim_Stratum")
cc <- q("SELECT * FROM lucasCore_CarbonCurve WHERE ScenarioId = 2"); ri5 <- q("SELECT * FROM lucasCore_OutputReturnInterval WHERE ScenarioId = 2")
so5 <- q("SELECT * FROM lucasCore_OutputSoilTarget WHERE ScenarioId = 2"); ds <- q("SELECT PrismFolder, EcodivisionFile FROM lucasCore_DataSource"); dbDisconnect(con)
nm <- function(id, t) t$Name[match(id, t[[1]])]
cc[, `:=`(Stratum = nm(StratumId, stl), StateClass = nm(StateClassId, scl))]
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv")); dens <- fread(file.path(pkg, "defaults/growth/merch-carbon-density.csv"))
cw[, StateClass := scl$Name[match(StateClassId, scl$Id)]]
clim <- ecodiv_climate(ds$EcodivisionFile, ds$PrismFolder)
ctx <- list(cc = cc, cw = cw, dens = dens, cbm = file.path(pkg, "defaults/cbm"), fo = fread(file.path(pkg, "defaults/stockflow/stsim_FlowOrder.csv")),
            ev = fread(event_file, na.strings = ""))
cells <- data.table(sc = as.integer(names(TYPES)), StateClass = paste0("Forest: ", TYPES), Stratum = STRATUM, ecodiv = ECODIV, temp = clim$mat[match(ECODIV, clim$ecodiv)])
cells[, ri := as.integer(round(as.numeric(ri5$ReturnInterval[match(paste(STRATUM, StateClass), paste(nm(ri5$StratumId, stl), nm(ri5$StateClassId, scl)))])))]
cells[, soil_target := as.numeric(so5$SoilTarget[match(paste(STRATUM, StateClass), paste(nm(so5$StratumId, stl), nm(so5$StateClassId, scl)))])]
cat(sprintf("Cells: %s; return intervals %s yr; %s %.1f C\n", paste(sub("Forest: ", "", cells$StateClass), collapse = ", "), paste(cells$ri, collapse = "/"), ECODIV, cells$temp[1]))

# ---- measured targets: DWM plots, mature, no recent fire or harvest ----------------------------------------------------------------
LB <- 0.000453592 * 2.471
w <- unique(fread(file.path(dm, "CA_COND_DWM_CALC.csv"), select = c("PLT_CN", "CONDID", "MEASYEAR", "CWD_CARBON_COND", "PILE_CARBON_COND", "FWD_SM_CARBON_COND",
            "FWD_MD_CARBON_COND", "FWD_LG_CARBON_COND", "DUFF_CARBON", "LITTER_CARBON"), colClasses = list(character = "PLT_CN")), by = c("PLT_CN", "CONDID"))
for (k in grep("CARBON", names(w), value = TRUE)) w[, (k) := as.numeric(get(k)) * LB]
w[, `:=`(cwd = CWD_CARBON_COND + fifelse(is.na(PILE_CARBON_COND), 0, PILE_CARBON_COND), fwd = FWD_SM_CARBON_COND + FWD_MD_CARBON_COND + FWD_LG_CARBON_COND, litter = LITTER_CARBON, duff = DUFF_CARBON)]
cd <- fread(file.path(dm, "CA_COND.csv"), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "STDAGE", "FORTYPCD", paste0("DSTRBCD", 1:3), paste0("DSTRBYR", 1:3), paste0("TRTCD", 1:3), paste0("TRTYR", 1:3)),
            colClasses = list(character = "PLT_CN"))
pl <- fread(file.path(dm, "CA_PLOT.csv"), select = c("CN", "STATECD", "UNITCD", "COUNTYCD", "PLOT"), colClasses = list(character = "CN"))[, loc := paste(STATECD, UNITCD, COUNTYCD, PLOT)]
ft <- fread(file.path(dm, "REFERENCE", "REF_FOREST_TYPE.csv"), select = c("VALUE", "TYPGRPCD"))
cache <- readRDS(file.path(dm, "fia-conditions.rds"))$cond[statecd == 6, .(plt_cn, condid, ecodiv, standing = c_ag_standing_dead_trees_short_tons_per_acre * 2.2417)]
h <- merge(cd, pl[, .(CN, loc)], by.x = "PLT_CN", by.y = "CN")
ev <- unique(rbindlist(lapply(1:3, function(i) rbind(
  h[get(paste0("DSTRBCD", i)) %in% 30:32 & get(paste0("DSTRBYR", i)) %between% c(1900, 2030), .(loc, year = get(paste0("DSTRBYR", i)), kind = "fire")],
  h[get(paste0("TRTCD", i)) %in% 10 & get(paste0("TRTYR", i)) %between% c(1900, 2030), .(loc, year = get(paste0("TRTYR", i)), kind = "harvest")]))))
x <- merge(merge(merge(w, cd[COND_STATUS_CD == 1], by = c("PLT_CN", "CONDID")), pl[, .(CN, loc)], by.x = "PLT_CN", by.y = "CN"), cache, by.x = c("PLT_CN", "CONDID"), by.y = c("plt_cn", "condid"))
x[, grp := ft$TYPGRPCD[match(FORTYPCD, ft$VALUE)]]
since <- function(kd) merge(x[, .(PLT_CN, CONDID, loc, MEASYEAR)], ev[kind == kd], by = "loc", allow.cartesian = TRUE)[year <= MEASYEAR, .(ys = min(MEASYEAR - year)), by = .(PLT_CN, CONDID)]
x <- merge(x, setnames(since("fire"), "ys", "since_fire"), by = c("PLT_CN", "CONDID"), all.x = TRUE)
x <- merge(x, setnames(since("harvest"), "ys", "since_harvest"), by = c("PLT_CN", "CONDID"), all.x = TRUE)
x <- x[ecodiv == ECODIV & grp %in% cells$sc]
MB <- c(MIN_AGE, 80, 100, 150, 300)
mat <- x[STDAGE >= MIN_AGE & STDAGE <= 300 & !(since_fire <= RECENT & !is.na(since_fire)) & !(since_harvest <= RECENT & !is.na(since_harvest)) & !is.na(cwd) & !is.na(standing)]
mat[, band := cut(STDAGE, MB, include.lowest = TRUE)]
MPOOLS <- c("standing", "cwd", "fwd", "litter", "duff")
obs <- mat[, c(list(n = .N), lapply(.SD, mean, na.rm = TRUE)), by = .(sc = grp, band), .SDcols = MPOOLS]
ages <- mat[, .N, by = .(sc = grp, band, stdage = STDAGE)]
cat("Measured targets (Mg C/ha), stand age >= 60, no fire or harvest in the past 30 yr:\n"); print(obs[order(sc, band)][, lapply(.SD, function(z) if (is.numeric(z)) round(z, 1) else z)])

# ---- the measured-pool calibration: five decay groups, fire as the last disturbance -----------------------------------------------
DECAY_GROUPS <- list(snag = c("SnagStem", "SnagBranch"), cwd = c("AGM", "BGF"), fwd = "AGF", litter = "AGVF", duff = "AGS", soil = c("BGVF", "BGS"))   # dev only: replaces dom.R's
SIM <- list(standing = c("SnagStem", "SnagBranch"), cwd = "AGM", fwd = "AGF", litter = "AGVF", duff = "AGS")   # measured pools (no dead roots on transects)
fit_measured <- function(k) {
  S <- cal_setup(k, ctx); ob <- obs[sc == k$sc]; ag <- ages[sc == k$sc]; scale <- sapply(MPOOLS, function(p) weighted.mean(ob[[p]], ob$n))
  pred <- function(par) { mult <- as.list(setNames(exp(par), c("snag", "cwd", "fwd", "litter", "duff")))
    d <- cal_dom(S, ctx$fo, mult, 0); sim <- sapply(SIM, function(p) rowSums(d[, p, drop = FALSE]))
    ag[, lapply(setNames(names(SIM), names(SIM)), function(p) sum(N * sim[stdage + 1, p]) / sum(N)), by = band] }
  loss <- function(par) { m <- merge(ob, pred(par), by = "band", suffixes = c("", "_sim")); sum(sapply(MPOOLS, function(p) sum(m$n * ((m[[paste0(p, "_sim")]] - m[[p]]) / scale[[p]])^2))) }
  l0 <- loss(rep(0, 5)); o <- optim(rep(0, 5), loss, method = "L-BFGS-B", lower = rep(log(0.05), 5), upper = rep(log(20), 5), control = list(maxit = 500))
  list(mult = setNames(exp(o$par), c("snag", "cwd", "fwd", "litter", "duff")), loss0 = l0, loss1 = o$value, fit = merge(ob, pred(o$par), by = "band", suffixes = c("", "_sim"))) }
t0 <- Sys.time(); M <- lapply(seq_len(nrow(cells)), function(i) fit_measured(cells[i])); names(M) <- cells$sc
cat(sprintf("\nmeasured-pool calibration: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))

# ---- the current calibration on the same inputs (dom.R's groups, modelled targets, every band, fitted clearcut share) ----------------
DECAY_GROUPS <- list(snag = c("SnagStem", "SnagBranch"), cwd = c("AGM", "BGF"), floor = c("AGVF", "AGF", "AGS"), soil = c("BGVF", "BGS"))
fx <- list(cond = readRDS(file.path(dm, "fia-conditions.rds"))$cond, dist = readRDS(file.path(dm, "fia-conditions.rds"))$dist)
fx$cond[, c_down_dead_tons_per_acre := c_down_dead_tons_per_acre * fread(file.path(pkg, "defaults/growth/down-dead-state-factors.csv"))[, setNames(Factor, StateCode)][as.character(statecd)]]
dat <- fia_dom_data(fx$cond, fx$dist, list(MinInventoryYear = 1997), cw)
t0 <- Sys.time(); C <- lapply(seq_len(nrow(cells)), function(i) cal_fit(cells[i], ctx, dat)); names(C) <- cells$sc
cat(sprintf("current calibration: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))

# ---- results ----------------------------------------------------------------------------------------------------------------------
mt <- rbindlist(lapply(names(M), function(s) data.table(type = sub(" Group", "", TYPES[[s]]), current_snag = C[[s]]$snag, current_downwood = C[[s]]$cwd, current_floor = C[[s]]$floor,
  current_clearcut = C[[s]]$clearcut, new_snag = M[[s]]$mult[["snag"]], new_downlogs = M[[s]]$mult[["cwd"]], new_fwd = M[[s]]$mult[["fwd"]], new_litter = M[[s]]$mult[["litter"]],
  new_duff = M[[s]]$mult[["duff"]], new_misfit_cut = 1 - M[[s]]$loss1 / M[[s]]$loss0)))
cat("\nDecay multipliers (1 = CBM default):\n"); print(mt[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 2) else z)]); fwrite(mt, file.path(out, "multipliers.csv"))
fits <- rbindlist(lapply(names(M), function(s) M[[s]]$fit[, type := sub(" Group", "", TYPES[[s]])]))
cat("\nMature-stand fit, measured vs new calibration (Mg C/ha):\n")
print(fits[, .(type = substr(type, 1, 18), band, n, standing = sprintf("%.1f / %.1f", standing, standing_sim), downlogs = sprintf("%.1f / %.1f", cwd, cwd_sim), fwd = sprintf("%.1f / %.1f", fwd, fwd_sim),
               litter = sprintf("%.1f / %.1f", litter, litter_sim), duff = sprintf("%.1f / %.1f", duff, duff_sim))])
fwrite(fits, file.path(out, "mature-fit.csv"))

# young stands: the new calibration's fire-last and clearcut-last curves against years since fire / harvest, and the current one's
DECAY_GROUPS <- list(snag = c("SnagStem", "SnagBranch"), cwd = c("AGM", "BGF"), fwd = "AGF", litter = "AGVF", duff = "AGS", soil = c("BGVF", "BGS"))
YB <- c(-1, 5, 10, 20, 30)
young <- rbindlist(lapply(seq_len(nrow(cells)), function(i) { k <- cells[i]; S <- cal_setup(k, ctx); mu <- as.list(M[[as.character(k$sc)]]$mult)
  m <- dom_matrices(S$vals, ctx$fo, mu); fire <- dom_by_age(m, S$live, k$ri, S$hist, S$hist); harv <- dom_by_age(m, S$live, k$ri, S$hist, S$harv)
  mod <- function(d, kd) data.table(sc = k$sc, kind = kd, age = 0:30, standing = rowSums(d[1:31, c("SnagStem", "SnagBranch")]), cwd = d[1:31, "AGM"], fwd = d[1:31, "AGF"], floor = rowSums(d[1:31, c("AGVF", "AGS")]))
  rbind(mod(fire, "fire"), mod(harv, "harvest")) }))
young[, years := cut(age, YB)]; ym <- young[, lapply(.SD, mean), by = .(sc, kind, years), .SDcols = c("standing", "cwd", "fwd", "floor")]
yo <- rbind(x[!is.na(since_fire) & since_fire <= 30, .(kind = "fire", sc = grp, years = cut(since_fire, YB), standing, cwd, fwd, floor = litter + duff)],
            x[!is.na(since_harvest) & since_harvest <= 30, .(kind = "harvest", sc = grp, years = cut(since_harvest, YB), standing, cwd, fwd, floor = litter + duff)])
yo <- yo[, c(list(n = .N), lapply(.SD, mean, na.rm = TRUE)), by = .(sc, kind, years), .SDcols = c("standing", "cwd", "fwd", "floor")]
yy <- merge(yo, ym, by = c("sc", "kind", "years"), suffixes = c("", "_model"))[order(sc, kind, years)]
cat("\nYoung stands (check, not fitted): measured / new model, by years since the last fire or harvest:\n")
print(yy[n >= 5, .(type = substr(sub("Forest: ", "", TYPES[as.character(sc)]), 1, 18), kind, years, n, standing = sprintf("%.1f / %.1f", standing, standing_model), downlogs = sprintf("%.1f / %.1f", cwd, cwd_model),
              fwd = sprintf("%.1f / %.1f", fwd, fwd_model), floor = sprintf("%.1f / %.1f", floor, floor_model))])
fwrite(yy, file.path(out, "young-check.csv"))
saveRDS(list(cells = cells, M = M, C = C, obs = obs, young = young, yo = yo), file.path(out, "calibration.rds"))
