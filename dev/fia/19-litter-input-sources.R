# =============================================================================
# 19-litter-input-sources.R - why the measured calibration drives leaf litter and fine woody debris decay to its bound in many cells:
# yearly carbon entering AG Very Fast (leaf litter) and AG Fast (fine woody debris) in a 100-year-old stand, by source, against the
# measured stock (FIA down woody material, mature stands). At steady state, loss rate = input / stock, so input / measured stock is the
# loss rate the model needs; divided by CBM's rate at the ecodivision's temperature it is the multiplier the fit is asked for.
# Cells: the test library's (phaseZ7) with the most plots, and P26's Mixed Conifer. Read-only. Usage: Rscript dev/fia/19-litter-input-sources.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(DBI) })
pkg <- "F:/lucasCore"; for (f in c("growth.R", "flows.R", "dom.R")) source(file.path(pkg, "src", f))
q <- function(lib, s) { con <- dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO); on.exit(dbDisconnect(con)); as.data.table(dbGetQuery(con, s)) }
p26 <- file.path(pkg, "dev/libs/LUCAS P26 Demo Library.ssim"); tl <- file.path(pkg, "dev/libs/lucasCore-suitability.ssim")
ds <- q(p26, "SELECT PrismFolder, EcodivisionFile FROM lucasCore_DataSource"); clim <- ecodiv_climate(ds$EcodivisionFile, ds$PrismFolder)
eco <- unique(sf::st_drop_geometry(sf::read_sf(ds$EcodivisionFile))[, c("ecodiv", "StrtmId")])
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv")); dens <- fread(file.path(pkg, "defaults/growth/merch-carbon-density.csv"))
cmp <- fread(file.path(pkg, "dev/fia/out-z7/mature-vs-measured.csv"))[order(-n)][1:12]
cmp <- rbind(cmp, data.table(StratumId = "Mediterranean Mountains", StateClassId = "Forest: California Mixed Conifer Group", sc = 370L, ecodiv = "M260",
                             fwd = 2.9, litter = 8.9, n = 1951), fill = TRUE)   # P26 Mixed Conifer, measured means (06)
get_cc <- function(lib, scn) { x <- q(lib, sprintf("SELECT c.*, s.Name AS Stratum, k.Name AS StateClass FROM lucasCore_CarbonCurve c JOIN stsim_Stratum s ON s.StratumId = c.StratumId JOIN stsim_StateClass k ON k.StateClassId = c.StateClassId WHERE c.ScenarioId = %d AND c.Age = 100", scn)) }
cc <- rbind(get_cc(tl, 47), get_cc(p26, 2))
par <- fread(file.path(pkg, "defaults/cbm/tblDOMParametersDefault.csv"))
k_at <- function(id, t) { z <- par[SoilPoolID == id]; min(1, z$OrganicMatterDecayRate * exp((t - z$ReferenceTemp) * log(z$Q10) * 0.1)) }
res <- rbindlist(lapply(seq_len(nrow(cmp)), function(i) { x <- cmp[i]; l <- cc[Stratum == x$StratumId & StateClass == x$StateClassId][1]
  w <- cw[StateClassId == x$sc]; sw <- grepl("Softwood$", w$LagClass); r <- turnover_rates(x$StateClass, sw, dens[StateClassId == x$sc, DeciduousShare], file.path(pkg, "defaults/cbm"))
  t <- clim$mat[match(x$ecodiv, clim$ecodiv)]
  fol <- l$Foliage * r$foliage; fr <- l$FineRoots * r$fine * 0.5; br <- l$Other * r$branch * (1 - r$branch_to_snag); crt <- l$CoarseRoots * r$coarse * 0.5
  data.table(cell = substr(paste(x$ecodiv, sub("Forest: | Group", "", sub(" Group", "", x$StateClassId))), 1, 34), temp = round(t, 1),
             litter_in_foliage = fol, litter_in_fineroots = fr, litter_measured = x$litter, litter_k_needed = (fol + fr) / x$litter, litter_k_cbm = k_at(0, t),
             fwd_in_branches = br, fwd_in_coarseroots = crt, fwd_measured = x$fwd, fwd_k_needed = (br + crt) / x$fwd, fwd_k_cbm = k_at(2, t)) }))
options(width = 250)
cat("Yearly inputs at age 100 (Mg C/ha/yr; live turnover only - snag branch fall adds to fine woody debris), measured stock (Mg C/ha), loss rate needed vs CBM:\n")
print(res[, .(cell, temp, `litter in: foliage` = round(litter_in_foliage, 2), `fine roots` = round(litter_in_fineroots, 2), `roots %` = round(100 * litter_in_fineroots / (litter_in_foliage + litter_in_fineroots)),
              measured = round(litter_measured, 1), `k needed` = round(litter_k_needed, 2), `k CBM` = round(litter_k_cbm, 2), `x CBM` = round(litter_k_needed / litter_k_cbm, 1))])
print(res[, .(cell, `fwd in: branches` = round(fwd_in_branches, 2), `coarse roots` = round(fwd_in_coarseroots, 2), `roots %` = round(100 * fwd_in_coarseroots / (fwd_in_branches + fwd_in_coarseroots)),
              measured = round(fwd_measured, 1), `k needed` = round(fwd_k_needed, 2), `k CBM` = round(fwd_k_cbm, 2), `x CBM` = round(fwd_k_needed / fwd_k_cbm, 1),
              `k needed, no roots` = round(fwd_in_branches / fwd_measured, 2), `x CBM, no roots` = round(fwd_in_branches / fwd_measured / fwd_k_cbm, 1))])
print(res[, .(cell, `litter k needed, no roots` = round(litter_in_foliage / litter_measured, 2), `x CBM, no roots` = round(litter_in_foliage / litter_measured / litter_k_cbm, 1))])
fwrite(res, file.path(pkg, "dev/fia/out-z7/litter-input-sources.csv"))
