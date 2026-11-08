# =============================================================================
# make_rap_climate_coefficients.R - defaults/climate/rap-climate-coefficients.csv from the RAP climate fit (to-do 39 step 7)
# =============================================================================
# Climate Options: Non-Forest Growth = RAP fit, the seasonal + aridity response fitted to RAP NPP 1986-2023 at the grass and shrub
# sample windows (dev/nonforest/04-rap-climate-sample.R, 07-rap-climate-seasonal-fit.R), half variance-scaled:
#   multiplier = 1 + sum over seasons k of (Coef_k + AridCoef_k ar) s_k + (PrecipLagCoef + PrecipLagAridCoef ar) pl + TempCoef ta
#   seasons Oct-Dec (Ond), Jan-Mar (Jfm), Apr-Jun (Amj), Jul-Sep (Jas, no aridity term) of the water year ending in the year;
#   s_k = (season k's rain - its 1991-2020 normal) / the water year's normal; pl = last water year / normal - 1; ta = T - T normal;
#   ar = log(water-year normal / 500 mm), clamped to [AridMin, AridMax], the range the ecodivision's fit saw
# One fit over every life form per ecodivision: a climate flow multiplier is one map per flow group and year, every grass and shrub
# class grows through Net Growth Non Forest: Total, and separate life-form fits predicted no better (06-rap-climate-explore.R).
# An ecodivision the fit lacks (fewer than 30 windows) takes the CONUS row (Source says which). Every stratum of
# defaults/stsim/stsim_Stratum.csv gets a row.
# Usage: Rscript tools/make_rap_climate_coefficients.R   (after dev/nonforest/07-rap-climate-seasonal-fit.R)
# =============================================================================
suppressPackageStartupMessages(library(data.table))
fit <- fread("dev/nonforest/07-rap-climate-seasonal-fit.csv")
num <- c("OndCoef", "JfmCoef", "AmjCoef", "JasCoef", "PrecipLagCoef", "TempCoef", "OndAridCoef", "JfmAridCoef", "AmjAridCoef", "PrecipLagAridCoef", "AridMin", "AridMax", "Scale")
st <- fread("defaults/stsim/stsim_Stratum.csv")[, .(StratumId = Name, Id)]
out <- merge(st, fit[StratumId != "CONUS", c("StratumId", "Windows", num), with = FALSE], by = "StratumId", all.x = TRUE)
out[, Source := fifelse(is.na(Windows), "CONUS", "ecodivision")]
cf <- fit[StratumId == "CONUS"]; for (k in num) out[Source == "CONUS", (k) := cf[[k]]]
out[is.na(Windows), Windows := 0L]
out[, (num) := lapply(.SD, function(v) round(v, 4)), .SDcols = num]
setcolorder(out, c("StratumId", "Id", "Windows", "Source", num)); setorder(out, StratumId)
fwrite(out, "defaults/climate/rap-climate-coefficients.csv")
print(out)
