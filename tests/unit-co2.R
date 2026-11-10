# Fast test of the CO2 fertilization multiplier (no SyncroSim). Run: Rscript tests/unit-co2.R (from the package root)
suppressPackageStartupMessages(library(data.table))
source("src/co2.R")
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
d <- function(f) fread(file.path("defaults", "climate", f), na.strings = "", encoding = "UTF-8")
tab <- d("co2-ssp.csv"); cl <- d("co2-classes.csv"); bands <- d("co2-age-bands.csv"); betas <- d("co2-betas.csv"); ecm <- d("co2-ecm-share.csv")

# ---- the package tables -----------------------------------------------------------------------------------------------------
scl <- fread("defaults/stsim/stsim_StateClass.csv"); fg <- fread("defaults/stsim/stsim_FlowGroup.csv")
check("every CO2 class is a package state class", all(cl$StateClassId %in% scl$Name))
check("every CO2 class has a flow group the package defines", all(cl$FlowGroupId %in% fg$Name))
check("every class type has betas", all(c(setdiff(cl$Type, "Forest"), "Forest", "Forest ECM young", "Forest ECM mature", "Forest AM young", "Forest AM mature") %in% betas$Type))
check("Low <= Central <= High for every type", betas[, all(Low <= Central & Central <= High)])
check("the accepted Central table (2026-11-06): forest 0.25, shrub 0.15, grass 0.30, pasture 0.35, crops 0.20, wetlands 0.20",
      isTRUE(all.equal(betas[match(c("Forest", "Shrub", "Grassland", "Pasture", "Crops", "Woody wetland", "Emergent wetland"), Type), Central], c(0.25, 0.15, 0.30, 0.35, 0.20, 0.20, 0.20))))
jo <- d("co2-mycorrhiza-species.csv")
check("the Jo et al. 2019 species list: 379 codes; quaking aspen (746) EM, red maple (316) AM, honey locust (552) half, sourwood (711) left out",
      nrow(jo) == 379 && jo[SPCD == 746, Ecm] == 1 && jo[SPCD == 316, Ecm] == 0 && jo[SPCD == 552, Ecm] == 0.5 && is.na(jo[SPCD == 711, Ecm]))
check("ECM shares are between 0 and 1 and name forest classes", ecm[, all(between(EcmShare, 0, 1)) && all(grepl("^(Forest: |Wetland: .+ Group$)", StateClassId))])
check("the age bands cover every age once", bands$AgeMin[1] == 0 && all(bands$AgeMin[-1] == head(bands$AgeMax, -1) + 1) && is.na(tail(bands$AgeMax, 1)))
check("Meinshausen 2020 SSP CO2 in 2100: 602.8 / 867.2 / 1135.2 ppm", isTRUE(all.equal(co2_ppm(tab, "ssp245", 2100), 602.78)) &&
      isTRUE(all.equal(co2_ppm(tab, "ssp370", 2100), 867.19)) && isTRUE(all.equal(co2_ppm(tab, "ssp585", 2100), 1135.21)))
check("years to 2014 come from the historical series", co2_ppm(tab, "ssp245", 2010) == tab[Scenario == "historical" & Year == 2010, CO2])

# ---- the series -------------------------------------------------------------------------------------------------------------
s <- co2_series(tab, "ssp585", 2024:2100, 2023, ref_ppm = 425.62)
check("the report's worked 2100 multipliers at beta 0.25 from 425.62 ppm: 1.087 / 1.178 / 1.245",
      isTRUE(all.equal(round(1 + 0.25 * sapply(c("ssp245", "ssp370", "ssp585"), function(x) co2_series(tab, x, 2100, 2023, 425.62)$LnRatio), 3), c(1.087, 1.178, 1.245), check.attributes = FALSE)))
s0 <- co2_series(tab, "ssp245", 2024:2100, 2023)
check("blank reference = the SSP's CO2 in the historical end year", s0$Ref[1] == co2_ppm(tab, "ssp245", 2023))
sc <- co2_series(tab, "ssp585", 2024:2100, 2023, cap = 600)
check("the ceiling holds CO2 at 600 ppm", max(sc$Used) == 600 && max(sc$CO2) > 1000)
check("an unknown SSP stops", inherits(tryCatch(co2_series(tab, "ssp999", 2024, 2023), error = function(e) e), "error"))
check("series names: blank = Central, 1 = None, 'high' = High", co2_series_name(NA) == "Central" && co2_series_name(1L) == "None" && co2_series_name("high") == "High")
check("age bands from number, label or plain range", identical(co2_band_id(c("2", "5 (101+)", "101+", NA)), c(2L, 5L, 5L, NA)))
check("age band labels sort in age order (the CO2 Betas grid sorts by label)", identical(sort(CO2_BAND_LABELS), CO2_BAND_LABELS) && identical(CO2_BANDS(bands), CO2_BAND_LABELS))
check("package.xml lists the same age band labels", grepl(paste(sprintf("%d:%s", 1:5, CO2_BAND_LABELS), collapse = "|"), paste(readLines("package.xml", warn = FALSE), collapse = "\n"), fixed = TRUE))

# ---- betas ------------------------------------------------------------------------------------------------------------------
st <- c("Marine", "Marine Mountains")
bt <- co2_betas(cl, st, "Central", betas, bands, ecm)
check("one beta per class x stratum x band", nrow(bt) == nrow(cl) * 2 * nrow(bands) && !anyDuplicated(bt[, .(StateClassId, StratumId, AgeBand)]))
df <- bt[StateClassId == "Forest: Douglas-fir Group" & StratumId == "Marine"]; e <- ecm[StateClassId == "Forest: Douglas-fir Group" & StratumId == "Marine", EcmShare]
check("forest: young = ECM share mix of 0.45 and 0.30", isTRUE(all.equal(df[AgeBand == 1, Beta], round(e * 0.45 + (1 - e) * 0.30, 4))))
check("forest: mature (76+) = ECM share mix of 0.30 and 0.15", isTRUE(all.equal(df[AgeBand %in% 4:5, Beta], rep(round(e * 0.30 + (1 - e) * 0.15, 4), 2))))
check("forest betas fall with age", all(diff(df$Beta) <= 0))
check("the ecodivision share is used where there is one, else CONUS", bt[StateClassId == "Forest: Douglas-fir Group" & StratumId == "Marine", EcmShare[1]] == e &&
      { b2 <- co2_betas(cl, "Nowhere", "Central", betas, bands, ecm); b2[StateClassId == "Forest: Douglas-fir Group", EcmShare[1]] == ecm[StateClassId == "Forest: Douglas-fir Group" & is.na(StratumId), EcmShare] })
nos <- setdiff(cl[Type == "Forest", StateClassId], ecm$StateClassId)
check("a forest class with no ECM share takes the Forest row at every age", !length(nos) || all(bt[StateClassId %in% nos, Beta] == 0.25))
check("shrub, grass and wetlands: one beta at every age", bt[Type != "Forest", uniqueN(Beta), by = StateClassId][, all(V1 == 1)])
check("Low and High bracket Central", all(co2_betas(cl, st, "Low", betas, bands, ecm)$Beta <= bt$Beta) && all(co2_betas(cl, st, "High", betas, bands, ecm)$Beta >= bt$Beta))
adj <- data.table(StateClassId = c("Shrubland: Chaparral", "Shrubland: Chaparral", "Forest: Douglas-fir Group"), StratumId = c(NA, "Marine", NA), AgeBand = c(NA, NA, 1L), Beta = c(0.05, 0.08, 0.6))
ba <- co2_betas(cl, st, "Central", betas, bands, ecm, adj)
check("an adjustment sets every stratum and band; a stratum row wins", all(ba[StateClassId == "Shrubland: Chaparral" & StratumId == "Marine", Beta] == 0.08) &&
      all(ba[StateClassId == "Shrubland: Chaparral" & StratumId == "Marine Mountains", Beta] == 0.05))
check("a band row changes only that band", all(ba[StateClassId == "Forest: Douglas-fir Group" & AgeBand == 1, Beta] == 0.6) &&
      identical(ba[StateClassId == "Forest: Douglas-fir Group" & AgeBand > 1, Beta], bt[StateClassId == "Forest: Douglas-fir Group" & AgeBand > 1, Beta]))
check("None is not a beta series", inherits(tryCatch(co2_betas(cl, st, "None", betas, bands, ecm), error = function(e) e), "error"))

# ---- the CO2 Betas table the Climate page loads (defaults/climate/co2-default-betas.csv) ------------------------------------
dt <- d("co2-default-betas.csv")
check("co2-default-betas.csv matches the tables (rerun tools/make_co2_default_betas.R if not)",
      isTRUE(all.equal(dt, co2_default_table(cl, betas, bands, ecm), check.attributes = FALSE)))
# what ui/ProjectionClimateView.cs Expected() loads for a series and the study area's strata
page_rows <- function(series, strata) rbindlist(lapply(unique(dt$StateClassId), function(c) {
  us <- dt[StateClassId == c & is.na(StratumId)]; loc <- dt[StateClassId == c & StratumId %in% strata]
  val <- function(st, band) { l <- loc[StratumId == st & identical(AgeBand, AgeBand) & ((is.na(AgeBand) & is.na(band)) | AgeBand %in% band)]; if (nrow(l)) l[[series]] else us[(is.na(AgeBand) & is.na(band)) | AgeBand %in% band][[series]] }
  same <- !nrow(loc) || all(vapply(seq_len(nrow(us)), function(i) uniqueN(vapply(strata, function(st) val(st, us$AgeBand[i]), 0)) == 1, TRUE))
  if (same) data.table(StateClassId = c, StratumId = NA_character_, AgeBand = us$AgeBand, Beta = if (nrow(loc)) vapply(us$AgeBand, function(b) val(strata[1], b), 0) else us[[series]])
  else rbindlist(lapply(strata, function(st) data.table(StateClassId = c, StratumId = st, AgeBand = us$AgeBand, Beta = vapply(us$AgeBand, function(b) val(st, b), 0)))) }))
for (sr in c("Low", "Central", "High")) {
  pr <- page_rows(sr, st)[, AgeBand := co2_band_id(AgeBand)]
  b0 <- co2_betas(cl, st, sr, betas, bands, ecm); b1 <- co2_betas(cl, st, sr, betas, bands, ecm, pr)
  check(sprintf("%s: the page's table gives stage 11 the same betas, none marked edited", sr), isTRUE(all.equal(b0$Beta, b1$Beta)) && !any(b1$Source == "CO2 Betas table (edited)")) }
pr <- page_rows("Central", st)
check("the page's table: one row per class (and band for forest) where strata agree, per stratum where the ECM share differs",
      pr[StateClassId == "Shrubland: Chaparral", .N] == 1 && pr[StateClassId == "Forest: Hemlock/Sitka Spruce Group", all(!is.na(StratumId)) && .N == 10])
check("an edited row is marked edited", { e <- copy(pr)[, AgeBand := co2_band_id(AgeBand)][StateClassId == "Shrubland: Chaparral", Beta := 0.05]
  co2_betas(cl, st, "Central", betas, bands, ecm, e)[StateClassId == "Shrubland: Chaparral", all(Source == "CO2 Betas table (edited)") && all(Beta == 0.05)] })

# ---- flow multiplier rows ---------------------------------------------------------------------------------------------------
r <- co2_rows(bt, s0, bands)
check("rows are type CO2, every projection year", all(r$FlowMultiplierTypeId == "CO2") && setequal(r$Timestep, 2024:2100))
check("a class with one beta: blank stratum and age", r[StateClassId == "Shrubland: Chaparral", all(is.na(StratumId) & is.na(AgeMin))] && r[StateClassId == "Shrubland: Chaparral", .N] == 77)
check("forest rows: every stratum x band (no blank fallbacks)", r[StateClassId == "Forest: Douglas-fir Group", !anyNA(StratumId) && !anyNA(AgeMin) && .N == 77 * 2 * 5])
check("no two rows match the same class, stratum, age and year", !anyDuplicated(r[, .(Timestep, StateClassId, StratumId, AgeMin)]))
v <- r[StateClassId == "Grassland: Natural Perennial" & Timestep == 2100, Value]
check("value = 1 + beta ln(CO2 / ref) (grassland 0.30, 2100)", isTRUE(all.equal(v, round(1 + 0.30 * log(602.78 / s0$Ref[1]), 4))))
check("the first year is close to 1", r[Timestep == 2024, all(between(Value, 1, 1.01))])
low <- co2_series(tab, "ssp119", 2024:2100, 2023)
check("CO2 below the reference (SSP1-1.9 late century) slows growth", all(co2_rows(bt, low, bands)[Timestep == 2100, Value] < 1))
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
