# =============================================================================
# phaseZ7-measured-dom.R - stage 3's measured dead-wood calibration and stage 4's spin-up with it (to-do 19, 2026-10-27)
# =============================================================================
# On the phaseO library: a copy of the Build scenario (2) running stages 3 and 4 only, depending on Build result 47 (stage 2's curves,
# stage 5's return intervals and soil targets), Carbon Options = measured dead wood, Data Sources: FIA DataMart Folder set (with the
# <ST>_COND_DWM_CALC tables). Checks: the run passes its own checks; every cell has five multipliers in bounds, a snag fall rate and a
# level; the snag, down log and fine woody debris multipliers are shared within each ecodivision; high-severity fire has state-class
# rows for the types in defaults/spinup/fire-snag-share.csv at both age rows; the spin-up's mature dead pools (age 60-150) against the
# measured targets for the cells with the most plots. Writes dev/fia/out-z7/.
# Usage: Rscript tests/phaseZ7-measured-dom.R
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); ok <- TRUE
DM <- "F:/lucas-master/Data Sources/FIA/DataMart"; out <- "F:/lucasCore/dev/fia/out-z7"; dir.create(out, showWarnings = FALSE)
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
P <- rsyncrosim::project(L, 1); d <- datasheet(P, "lucasCore_DataSource")
if (!nrow(d) || is.na(d$FiaDataMartFolder[1]) || d$FiaDataMartFolder[1] != DM) { if (!nrow(d)) d[1, ] <- NA; d$FiaDataMartFolder <- DM; saveDatasheet(P, d, "lucasCore_DataSource") }
name <- "Stage 3-4 test (measured dead wood)"
old <- scenario(L, summary = TRUE); for (id in old$ScenarioId[old$Name == name]) delete(L, scenario = id, force = TRUE)
S <- scenario(L, name, sourceScenario = 2)
saveDatasheet(S, data.frame(StageNameId = c("3 - Carbon Flows", "4 - Spin-up and Initial Stocks"), RunOrder = 1:2), "core_Pipeline")
saveDatasheet(S, data.frame(DeadOrganicMatterModel = 4L), "lucasCore_CarbonOptions")
dependency(S) <- c(47L, as.integer(dependency(S)$ScenarioId))
t0 <- Sys.time(); R <- run(S); cat(sprintf("stages 3-4: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
cat(logs(R, "Carbon Options|Measured dead wood|snag share|Decay calibration took|No mature|Soil vs|Failure|fail"), sep = "\n")
v <- ds(R, "lucasCore_OutputValidation"); expect("stage 3 and 4 checks pass", nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", Check], collapse = "; "))
dc <- ds(R, "lucasCore_OutputDecayCalibration"); fwrite(dc, file.path(out, "decay-calibration.csv"))
M <- c("SnagDecayMultiplier", "DownWoodDecayMultiplier", "FineWoodyDecayMultiplier", "LitterDecayMultiplier", "DuffDecayMultiplier")
expect("every cell has five measured multipliers in [0.05, 20]", all(is.finite(as.matrix(dc[, ..M]))) && all(as.matrix(dc[, ..M]) >= 0.05 - 1e-6 & as.matrix(dc[, ..M]) <= 20 + 1e-6), sprintf("%d cells", nrow(dc)))
expect("every cell has a snag fall rate", all(is.finite(dc$SnagFallRate)), sprintf("range %.3f-%.3f", min(dc$SnagFallRate), max(dc$SnagFallRate)))
sh <- dc[Level == "Ecodivision", .(n = uniqueN(round(SnagDecayMultiplier, 4)) + uniqueN(round(DownWoodDecayMultiplier, 4)) + uniqueN(round(FineWoodyDecayMultiplier, 4))), by = StratumId]
expect("snag, down log and fine woody debris multipliers are shared within each ecodivision", all(sh$n == 3))
print(dc[, .N, by = Level])
fp <- ds(R, "stsim_FlowPathway"); fss <- fread("F:/lucasCore/defaults/spinup/fire-snag-share.csv")
cr <- fp[TransitionGroupId == "Fire: High Severity [Type]" & !is.na(FromStateClassId)]
expect("high-severity fire has class rows at both age rows for each listed type", uniqueN(cr$FromStateClassId) == nrow(fss) && all(cr[, uniqueN(FromAgeMin), by = FromStateClassId]$V1 == 2),
       sprintf("%d rows, %d classes", nrow(cr), uniqueN(cr$FromStateClassId)))
bal <- cr[FromAgeMin >= 11, .(s = sum(Multiplier)), by = .(FromStateClassId, FromStockTypeId)]
expect("class fire rows move the whole live wood pool", all(abs(bal$s - 1) < 1e-4), sprintf("sums %.4f-%.4f", min(bal$s), max(bal$s)))
# spin-up mature dead pools vs the measured targets (fire-last curves; cells with the most mature DWM plots)
ic <- ds(R, "lucasCore_InitialStockCurve")[TransitionGroupId == "Fire: High Severity [Type]" & Age >= 60 & Age <= 150]
mod <- ic[, .(standing = mean(SnagStem + SnagBranch), cwd = mean(AGM), fwd = mean(AGF), litter = mean(AGVF), duff = mean(AGS)), by = .(StratumId, StateClassId)]
source("F:/lucasCore/src/calibrate.R"); say <- function(...) invisible(); fail <- function(...) stop(sprintf(...)); source("F:/lucasCore/src/fia.R")
dw <- readRDS(file.path(DM, "fia-deadwood.rds")); scl <- ds(P, "stsim_StateClass"); cw <- fread("F:/lucasCore/defaults/growth/forest-type-crosswalk.csv")[, StateClass := scl$Name[match(StateClassId, scl$Id)]]
x <- dwm_targets(dw, cw, 60)$obs[, lapply(.SD, function(v) sum(v * n) / sum(n)), by = .(sc, ecodiv), .SDcols = MEAS_POOLS][, n := dwm_targets(dw, cw, 60)$obs[, .(n = sum(n)), by = .(sc, ecodiv)]$n]
x[, StateClassId := cw$StateClass[match(sc, cw$StateClassId)]]
st <- ds(P, "stsim_Stratum"); ef <- datasheet(P, "lucasCore_DataSource")$EcodivisionFile; if (is.null(ef) || is.na(ef) || !nzchar(ef)) { con <- DBI::dbConnect(RSQLite::SQLite(), "F:/lucasCore/dev/libs/LUCAS P26 Demo Library.ssim", flags = RSQLite::SQLITE_RO); ef <- DBI::dbGetQuery(con, "SELECT EcodivisionFile FROM lucasCore_DataSource")$EcodivisionFile; DBI::dbDisconnect(con) }
eco <- sf::st_drop_geometry(sf::read_sf(ef))
x[, StratumId := st$Name[match(as.integer(eco$StrtmId[match(ecodiv, eco$ecodiv)]), st$Id)]]
cmp <- merge(x, mod, by = c("StratumId", "StateClassId"), suffixes = c("", "_model"))[order(-n)]
fwrite(cmp, file.path(out, "mature-vs-measured.csv"))
cat("\nMature stands (60-150 yr), measured / spin-up, Mg C/ha - cells with the most plots:\n")
print(head(cmp[, .(cell = substr(paste(StratumId, sub("Forest: ", "", StateClassId)), 1, 45), n, snags = sprintf("%.1f / %.1f", standing, standing_model), downlogs = sprintf("%.1f / %.1f", cwd, cwd_model),
                   fwd = sprintf("%.1f / %.1f", fwd, fwd_model), litter = sprintf("%.1f / %.1f", litter, litter_model), duff = sprintf("%.1f / %.1f", duff, duff_model))], 12))
r <- cmp[n >= 100, .(pool = MEAS_POOLS, ratio = sapply(MEAS_POOLS, function(p) median(get(paste0(p, "_model")) / get(p))))]
print(r); expect("median spin-up / measured within 0.6-1.6 for every pool (cells with >= 100 plots)", all(r$ratio > 0.6 & r$ratio < 1.6))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
