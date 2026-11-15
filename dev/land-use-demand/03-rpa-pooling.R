# =============================================================================
# 03-rpa-pooling.R - at what level should the RPA urbanization ratio be pooled: county, metropolitan area, or state? (exploratory)
# =============================================================================
# User 2026-11-14: a state ratio gives every county of California or Texas the same trend; is there something between county and state?
# Three poolings of the same RPA areas (mean of the five climate models, per the user: only the RCP-SSP pair should matter):
#   County   each county's own ratio
#   Metro    metropolitan statistical areas (defaults/strata/msa-crosswalk.csv, whole counties, the Metropolitan Areas stratum source),
#            and the counties outside any metropolitan area pooled by state ("rest of <state>")
#   State    one ratio per state
# For each: how usable the calibration rate is, how the ratios spread, and how well the unit's RPA 2012-2020 rate agrees with Annual
# NLCD (02-rpa-vs-nlcd-county.csv). Writes 03-rpa-metro-ratios.csv.
# Usage: Rscript dev/land-use-demand/03-rpa-pooling.R   (after 01 and 02)
# =============================================================================
pkg <- local({ d <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))); while (!file.exists(file.path(d, "package.xml")) && dirname(d) != d) d <- dirname(d); d })   # the package folder
suppressPackageStartupMessages(library(data.table))
OUT <- file.path(pkg, "dev/land-use-demand"); say <- function(...) cat(sprintf(...), "\n")
co <- readRDS(file.path(OUT, "cache/01-rpa-county.rds"))[Group == "Urbanization"]
co <- co[, .(PerYear = mean(PerYear)), by = .(Fips, State, Pair, Step)]   # the mean of the climate models
cw <- fread(file.path(pkg, "defaults/strata/msa-crosswalk.csv"), colClasses = "character"); ml <- fread(file.path(pkg, "defaults/strata/msa-list.csv"), colClasses = "character")
co[, Metro := cw$Id[match(Fips, sprintf("%05d", as.integer(cw$Value)))]]
co[, MetroName := ifelse(is.na(Metro), paste("rest of", State), ml$Name[match(Metro, ml$Id)])]; co[is.na(Metro), Metro := paste0("rest-", State)]
nl <- fread(file.path(OUT, "02-rpa-vs-nlcd-county.csv"), colClasses = list(character = "Fips"))[Item == "Urbanization" & !is.na(RpaKm2)]
nl[, `:=`(State = substr(Fips, 1, 2), Metro = co$Metro[match(Fips, co$Fips)])]
CAL <- "2012-2020"
pool <- function(by) { p <- co[, .(PerYear = sum(PerYear), Counties = uniqueN(Fips)), by = c(by, "Pair", "Step")]; p[, Cal := PerYear[Step == CAL], by = c(by, "Pair")]; p[, Ratio := PerYear / Cal]; p[Step != CAL] }
res <- list(County = pool("Fips"), Metro = pool(c("Metro", "MetroName")), State = pool("State")); key <- c(County = "Fips", Metro = "Metro", State = "State")
say("Urbanization ratio to 2012-2020 by pooling (units x pairs x decades; calibration rate in km2 a year):")
print(rbindlist(lapply(names(res), function(k) { p <- res[[k]]; u <- p[, .(Cal = Cal[1]), by = c(key[[k]], "Pair")]; n <- nl[, .(Nlcd = sum(NlcdKm2), Rpa = sum(RpaKm2)), by = c(key[[k]])]
  ok <- p[is.finite(Ratio)]
  data.table(Pooling = k, Units = uniqueN(p[[key[[k]]]]), ZeroCal = u[Cal == 0, uniqueN(get(key[[k]]))], Under1Km2 = u[Cal > 0 & Cal < 1, uniqueN(get(key[[k]]))],
             Q01 = round(quantile(ok$Ratio, 0.01), 2), Q05 = round(quantile(ok$Ratio, 0.05), 2), Q50 = round(median(ok$Ratio), 2), Q95 = round(quantile(ok$Ratio, 0.95), 2),
             Q99 = round(quantile(ok$Ratio, 0.99), 2), Max = round(max(ok$Ratio), 1),
             NlcdCorrelation = round(cor(n$Nlcd, n$Rpa, method = "spearman"), 2), NlcdOverRpaQ10 = round(quantile(n[Rpa > 0, Nlcd / Rpa], 0.1), 2), NlcdOverRpaQ90 = round(quantile(n[Rpa > 0, Nlcd / Rpa], 0.9), 2)) })))
# how much of the county spread is within states, and how much of that the metro pooling keeps (area-weighted, rcp85_ssp5 2060-2070)
x <- merge(res$County[Pair == "rcp85_ssp5" & Step == "2060-2070" & is.finite(Ratio), .(Fips, Cal, R = Ratio)], unique(co[, .(Fips, State, Metro)]), by = "Fips")
x[res$Metro[Pair == "rcp85_ssp5" & Step == "2060-2070"], Rm := i.Ratio, on = "Metro"]; x[res$State[Pair == "rcp85_ssp5" & Step == "2060-2070"], Rs := i.Ratio, on = "State"]
wv <- function(v, w) sum(w * (v - sum(w * v) / sum(w))^2) / sum(w)
say("\nrcp85_ssp5, 2060-2070, weighted by calibration area: variance of the county ratio %.3f; between states %.3f (%.0f%%); between metro units %.3f (%.0f%%)",
    wv(x$R, x$Cal), wv(x$Rs, x$Cal), 100 * wv(x$Rs, x$Cal) / wv(x$R, x$Cal), wv(x$Rm, x$Cal), 100 * wv(x$Rm, x$Cal) / wv(x$R, x$Cal))
m <- dcast(res$Metro, Metro + MetroName + Counties + Pair + Cal ~ Step, value.var = "Ratio"); fwrite(m[order(Metro, Pair)], file.path(OUT, "03-rpa-metro-ratios.csv"))
for (s in c("06", "48")) { say("\nState %s, rcp85_ssp5: state ratio 2060-2070 %.2f; metro units (calibration km2 a year, ratio 2030-2040, 2060-2070):", s, res$State[State == s & Pair == "rcp85_ssp5" & Step == "2060-2070", Ratio])
  ms <- unique(co[State == s, Metro]); print(m[Metro %in% ms & Pair == "rcp85_ssp5"][order(-Cal), .(MetroName = substr(MetroName, 1, 40), Counties, Cal = round(Cal, 1), `2030-2040` = round(`2030-2040`, 2), `2060-2070` = round(`2060-2070`, 2))], nrows = 60) }
