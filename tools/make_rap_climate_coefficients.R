# =============================================================================
# make_rap_climate_coefficients.R - defaults/climate/rap-climate-coefficients.csv from the RAP climate fit (to-do 39 step 7)
# =============================================================================
# Climate Options: Non-Forest Growth = RAP fit uses the tree-ring form on grass and shrub growth:
#   multiplier = 1 + PrecipCoef * (P / P normal - 1) + PrecipLagCoef * (P last year / P normal - 1) + TempCoef * (T - T normal)
# fitted to RAP NPP 1986-2023 at the 1,140 grass and shrub sample windows (dev/nonforest/04-rap-climate-sample.R, 05-rap-climate-fit.R:
# per window and life form, the year's NPP over its 1991-2020 mean on PRISM). Pooled here by ecodivision with a random-effects
# (DerSimonian-Laird) mean of the window fits:
#   LifeForm "All"   every life form's window fits together: the coefficients the model uses. A climate flow multiplier is one map
#                    per flow group and year, and every grass and shrub class grows through Net Growth Non Forest: Total, so one
#                    response per cell (a cell may change class during a run); perennial grass and shrub fitted nearly the same
#   Annual grass, Perennial grass, Shrub   kept for reference
# An ecodivision with fewer than MIN_WINDOWS window fits takes the CONUS pool of its life form (Source says which). Every stratum of
# defaults/stsim/stsim_Stratum.csv gets a row.
# Usage: Rscript tools/make_rap_climate_coefficients.R   (after dev/nonforest/05-rap-climate-fit.R)
# =============================================================================
suppressPackageStartupMessages(library(data.table))
MIN_WINDOWS <- 5
wf <- fread("dev/nonforest/05-rap-climate-window-fits.csv")
dl <- function(est, se) { ok <- is.finite(est) & is.finite(se) & se > 0; est <- est[ok]; se <- se[ok]; if (length(est) < 2) return(NA_real_)
  w <- 1 / se^2; m <- sum(w * est) / sum(w); Q <- sum(w * (est - m)^2); k <- length(est)
  tau2 <- max(0, (Q - (k - 1)) / (sum(w) - sum(w^2) / sum(w))); ws <- 1 / (se^2 + tau2); sum(ws * est) / sum(ws) }
pool <- function(x) data.table(Windows = nrow(x), PrecipCoef = dl(x$bp, x$bp_se), PrecipLagCoef = dl(x$bl, x$bl_se), TempCoef = dl(x$bt, x$bt_se))
wf <- rbind(wf, copy(wf)[, LifeForm := "All"])
conus <- wf[, pool(.SD), by = LifeForm]
st <- fread("defaults/stsim/stsim_Stratum.csv")[, .(StratumId = Name, Id)]
out <- rbindlist(lapply(unique(wf$LifeForm), function(lf) { e <- wf[LifeForm == lf, pool(.SD), by = StratumId]
  x <- merge(st, e, by = "StratumId", all.x = TRUE)[, LifeForm := lf]
  x[, Source := fifelse(!is.na(Windows) & Windows >= MIN_WINDOWS & is.finite(PrecipCoef), "ecodivision", "CONUS life form")]
  cf <- conus[LifeForm == lf]; for (k in c("PrecipCoef", "PrecipLagCoef", "TempCoef")) x[Source != "ecodivision", (k) := cf[[k]]]
  x[is.na(Windows), Windows := 0L] }))
num <- c("PrecipCoef", "PrecipLagCoef", "TempCoef"); out[, (num) := lapply(.SD, function(v) round(v, 4)), .SDcols = num]
setcolorder(out, c("StratumId", "Id", "LifeForm", "Windows", "Source", num)); setorder(out, LifeForm, StratumId)
fwrite(out, "defaults/climate/rap-climate-coefficients.csv")
print(out[LifeForm == "All"]); cat(sprintf("\nCONUS pools:\n")); print(conus[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 4) else v)])
