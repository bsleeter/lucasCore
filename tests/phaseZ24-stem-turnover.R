# =============================================================================
# phaseZ24-stem-turnover.R - to-do 32 option A: stem turnover fitted to FIA background mortality, in stages 3 and 4 (2026-10-30)
# =============================================================================
# As tests/phaseZ7-measured-dom.R (lucasCore-suitability.ssim: a copy of the Build scenario running stages 3 and 4 on Build result 47,
# Carbon Method = FIA measured dead wood, Live Turnover empty, so stage 3 takes the package's FIA-fitted stem turnover,
# tools/calibrate-stem-turnover.R), with its checks, and against phaseZ7's results with CBM turnover (dev/fia/out-z7): the stage 3
# log names the package turnover; the share of cells whose mature snags are under 0.8 x measured falls; fewer snag multipliers at the
# lower bound; every other pool stays within 0.6-1.6 of measured. Writes dev/fia/out-z24/.
# Usage: Rscript tests/phaseZ24-stem-turnover.R
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); ok <- TRUE
DM <- "F:/lucas-master/Data Sources/FIA/DataMart"; out <- "F:/lucasCore/dev/fia/out-z24"; dir.create(out, showWarnings = FALSE)
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
logs <- function(R, pat) { lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); unique(lg[grepl(pat, lg)]) }
P <- rsyncrosim::project(L, 1); d <- datasheet(P, "lucasCore_DataSource")
if (!nrow(d) || is.na(d$FiaDataMartFolder[1]) || d$FiaDataMartFolder[1] != DM) { if (!nrow(d)) d[1, ] <- NA; d$FiaDataMartFolder <- DM; saveDatasheet(P, d, "lucasCore_DataSource") }
name <- "Stage 3-4 test (FIA stem turnover)"
old <- scenario(L, summary = TRUE); for (id in old$ScenarioId[old$Name == name]) delete(L, scenario = id, force = TRUE)
S <- scenario(L, name, sourceScenario = 2)
saveDatasheet(S, data.frame(StageNameId = c("3 - Carbon Flows", "4 - Spin-up and Initial Stocks"), RunOrder = 1:2), "core_Pipeline")
saveDatasheet(S, data.frame(DeadOrganicMatterModel = 4L), "lucasCore_CarbonOptions")
dependency(S) <- c(47L, as.integer(dependency(S)$ScenarioId))
t0 <- Sys.time(); R <- run(S); cat(sprintf("stages 3-4: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
cat(logs(R, "Live Turnover|Measured dead wood|Decay calibration took|Failure|fail"), sep = "\n")
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
# against CBM turnover (phaseZ7, 2026-10-27)
expect("stage 3 took the package's FIA stem turnover", any(grepl("Live Turnover: [0-9]+ rows from the package", logs(R, "^Live Turnover"))))
b <- fread("F:/lucasCore/dev/fia/out-z7/mature-vs-measured.csv"); b0 <- fread("F:/lucasCore/dev/fia/out-z7/decay-calibration.csv")
k <- merge(b[, .(StratumId, StateClassId, n, r0 = standing_model / standing)], cmp[, .(StratumId, StateClassId, r1 = standing_model / standing)], by = c("StratumId", "StateClassId"))
cat(sprintf("\nMature snags, model / measured over %d cells with targets: median %.2f -> %.2f; under 0.8 in %d -> %d cells; plot-weighted median %.2f -> %.2f\n", nrow(k),
            median(k$r0), median(k$r1), sum(k$r0 < 0.8), sum(k$r1 < 0.8), k[, median(rep(r0, pmin(n, 500)))], k[, median(rep(r1, pmin(n, 500)))]))
expect("fewer cells with mature snags under 0.8 x measured", sum(k$r1 < 0.8) < sum(k$r0 < 0.8))
cat(sprintf("snag decay multiplier at its lower bound: %d -> %d cells; median snag multiplier %.2f -> %.2f\n", sum(b0$SnagDecayMultiplier <= 0.051), sum(dc$SnagDecayMultiplier <= 0.051),
            median(b0$SnagDecayMultiplier), median(dc$SnagDecayMultiplier)))
expect("fewer snag multipliers at the lower bound", sum(dc$SnagDecayMultiplier <= 0.051) < sum(b0$SnagDecayMultiplier <= 0.051))
print(k[order(-n)][1:15, .(cell = substr(paste(StratumId, sub("Forest: ", "", StateClassId)), 1, 55), n, before = round(r0, 2), after = round(r1, 2))])
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
