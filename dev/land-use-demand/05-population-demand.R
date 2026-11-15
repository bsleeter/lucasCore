# =============================================================================
# 05-population-demand.R - urbanization from county population: a model fitted on Annual NLCD and Census estimates (exploratory)
# =============================================================================
# User 2026-11-14: a population-driven alternative that can stay at county multipliers. The idea (dev/avoided-conversion/
# ssp-projections.md, Option A, made safe for counties that stop growing):
#   new developed land a year in a county = c0 x its population + c1 x its population gain a year (0 when it loses people)
# The first term is the development that goes on without growth (roads, commerce, second homes, households getting smaller), the second
# the land new residents take. As a multiplier on the area stage 9 draws, a county's own land per person cancels:
#   ratio(county, period) = (P + L x gain) / (P_base + L x gain_base),     L = c1 / c0 (years)
# always positive, and with one national number L. Fitted and tested here on what happened:
#   NLCD      county pixels not developed in the first year and developed (21-24) in the last, 2000-2010 and 2010-2020 (04-nlcd-county-change.R)
#   Census    county population estimates 2000-2010 (intercensal) and 2010-2020 (vintage 2020)
#   test      L fitted on 2000-2010; does the ratio it gives for 2010-2020 against 2000-2010 match the ratio NLCD shows, county by county?
#   Hauer     Hauer (2019) county populations by SSP, 2020-2100 (doi:10.17605/OSF.IO/9YNFC): the ratios the model gives against 2010-2020
# Writes 05-population-fit.csv, 05-population-test-county.csv and 05-population-ratios-national.csv.
# Usage: Rscript dev/land-use-demand/05-population-demand.R   (after 04; LUCAS_DATA_HOME = the Data Sources folder)
# =============================================================================
pkg <- local({ d <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))); while (!file.exists(file.path(d, "package.xml")) && dirname(d) != d) d <- dirname(d); d })
DS <- Sys.getenv("LUCAS_DATA_HOME", "E:/lucasData"); suppressPackageStartupMessages(library(data.table))
OUT <- file.path(pkg, "dev/land-use-demand"); CA <- file.path(OUT, "cache"); say <- function(...) cat(sprintf(...), "\n")

# ---- Census: population at the start and end of each decade -----------------------------------------------------------------------
c00 <- fread(file.path(DS, "land-use/census-population/co-est00int-tot.csv"), encoding = "Latin-1")[SUMLEV == 50]
c10 <- fread(file.path(DS, "land-use/census-population/co-est2020-alldata.csv"), encoding = "Latin-1")[SUMLEV == 50]
fips <- function(d) sprintf("%02d%03d", as.integer(d$STATE), as.integer(d$COUNTY))
pop <- merge(data.table(Fips = fips(c00), P2000 = as.numeric(c00$POPESTIMATE2000), P2010a = as.numeric(c00$POPESTIMATE2010)),
             data.table(Fips = fips(c10), P2010 = as.numeric(c10$POPESTIMATE2010), P2020 = as.numeric(c10$POPESTIMATE2020)), by = "Fips")
say("Census: %d counties in both files; US %.1f M (2000), %.1f M (2010), %.1f M (2020)", nrow(pop), sum(pop$P2000) / 1e6, sum(pop$P2010) / 1e6, sum(pop$P2020) / 1e6)

# ---- NLCD: new developed land a year by county and decade ---------------------------------------------------------------------
urb <- function(y0, y1) { x <- readRDS(file.path(CA, sprintf("04-nlcd-%d-%d.rds", y0, y1)))
  cov <- x[, .(ok = sum(N[!is.na(a) & a > 0 & a < 250 & !is.na(b) & b > 0 & b < 250]) / sum(N)), by = Fips]
  x[Fips %in% cov[ok > 0.999, Fips], .(U = sum(N[!(a %in% c(21:24, 11L, 12L)) & b %in% 21:24]) * 900 / 1e6 / (y1 - y0), Dev = sum(N[a %in% 21:24]) * 900 / 1e6), by = Fips] }
u1 <- urb(2000L, 2010L); u2 <- urb(2010L, 2020L)
d <- merge(merge(pop, u1[, .(Fips, U1 = U, Dev1 = Dev)], by = "Fips"), u2[, .(Fips, U2 = U, Dev2 = Dev)], by = "Fips")
d[, `:=`(P1 = (P2000 + P2010a) / 2, G1 = pmax(P2010a - P2000, 0) / 10, P2 = (P2010 + P2020) / 2, G2 = pmax(P2020 - P2010, 0) / 10, D1 = (P2010a - P2000) / 10, D2 = (P2020 - P2010) / 10)]
say("Counties with NLCD and Census in both decades: %d; new developed land %.0f km2/yr (2000-2010), %.0f km2/yr (2010-2020); %d and %d counties lost population",
    nrow(d), sum(d$U1), sum(d$U2), sum(d$D1 < 0), sum(d$D2 < 0))

# ---- the fit: U = c0 x P + c1 x gain, no intercept, both >= 0 (weights 1 / sqrt(P): large counties do not rule the fit alone) -----------
fit <- function(U, P, G) { m <- lm(U ~ 0 + P + G, weights = 1 / sqrt(pmax(P, 1))); c0 <- max(coef(m)[["P"]], 0); c1 <- max(coef(m)[["G"]], 0)
  list(c0 = c0, c1 = c1, L = c1 / c0, r2 = cor(U, c0 * P + c1 * G)^2) }
f1 <- fit(d$U1, d$P1, d$G1); f2 <- fit(d$U2, d$P2, d$G2); fb <- fit(c(d$U1, d$U2), c(d$P1, d$P2), c(d$G1, d$G2))
ft <- rbindlist(lapply(list(`2000-2010` = f1, `2010-2020` = f2, both = fb), as.data.table), idcol = "Period")
ft[, `:=`(M2PerPersonYear = c0 * 1e6, M2PerNewResident = c1 * 1e6)]; fwrite(ft, file.path(OUT, "05-population-fit.csv"))
say("\nFit (new developed land a year = c0 x population + c1 x population gain a year):")
print(ft[, .(Period, M2PerPersonYear = round(M2PerPersonYear, 2), M2PerNewResident = round(M2PerNewResident), L_years = round(L, 1), R2 = round(r2, 2))])
say("  share of 2010-2020 development explained by the population term (no growth needed): %.0f%%", 100 * sum(f2$c0 * d$P2) / sum(f2$c0 * d$P2 + f2$c1 * d$G2))

# ---- the test: L from 2000-2010 only; the ratio of 2010-2020 to 2000-2010, by county --------------------------------------------------
L <- f1$L; d[, `:=`(Pred = (P2 + L * G2) / (P1 + L * G1), Obs = U2 / U1)]
t <- d[U1 * 10 >= 1 & is.finite(Obs)]   # counties with at least 1 km2 of new development in 2000-2010 (a ratio to less is noise)
say("\nTest, L = %.1f years from 2000-2010: the ratio 2010-2020 / 2000-2010 in %d counties with at least 1 km2 developed in 2000-2010 (%.0f%% of the development)",
    L, nrow(t), 100 * sum(t$U1) / sum(d$U1))
say("  national: observed %.2f, predicted %.2f", sum(t$U2) / sum(t$U1), sum(t$U1 * t$Pred) / sum(t$U1))
sk <- function(x, lab) { w <- x$U1; e <- log(pmax(x$Obs, 0.02)); p <- log(x$Pred); m <- sum(w * e) / sum(w)
  data.table(Counties = nrow(x), What = lab, ObsMedian = median(x$Obs), PredMedian = median(x$Pred), Spearman = cor(x$Obs, x$Pred, method = "spearman"),
             # skill: how much of the (weighted) squared log error of "every county changes like the nation" the prediction removes
             Skill = 1 - sum(w * (e - (p - sum(w * p) / sum(w) + m))^2) / sum(w * (e - m)^2), MedianAbsLogError = median(abs(e - (p - sum(w * p) / sum(w) + m)))) }
sz <- cut(t$P1, c(0, 2e4, 1e5, 5e5, Inf), labels = c("under 20 thousand people", "20-100 thousand", "100-500 thousand", "over 500 thousand"))
res <- rbind(sk(t, "all"), rbindlist(lapply(levels(sz), function(k) sk(t[sz == k], k))))
print(res[, .(What, Counties, ObsMedian = round(ObsMedian, 2), PredMedian = round(PredMedian, 2), Spearman = round(Spearman, 2), Skill = round(Skill, 2), MedianAbsLogError = round(MedianAbsLogError, 2))])
# how much of the predicted change shows up: log(observed ratio) = a + b x log(predicted ratio), for several L (L = 0: the ratio of the
# populations alone). b = 1 and a high R2 would mean the model's county ratios can be used as they are; a small b means they are far too wide
say("\nHow much of the predicted change NLCD shows (weighted by 2000-2010 development): log observed = a + b x log predicted")
el <- rbindlist(lapply(c(0, 10, 25, 50, 100, 188, 1e4), function(Lk) { p <- log((t$P2 + Lk * t$G2) / (t$P1 + Lk * t$G1)); o <- log(pmax(t$Obs, 0.02)); m <- lm(o ~ p, weights = t$U1)
  data.table(L = Lk, b = coef(m)[[2]], R2 = summary(m)$r.squared, PredSpread = diff(quantile(exp(p), c(0.05, 0.95)))) }))
print(el[, .(L_years = L, b = round(b, 2), R2 = round(R2, 3), PredictedRatio_5to95 = round(PredSpread, 2))])
say("  observed county ratios, 5%% to 95%%: %.2f to %.2f", quantile(t$Obs, 0.05), quantile(t$Obs, 0.95))
# is a county's change in development persistent at all? 1990-2000 to 2000-2010 against 2000-2010 to 2010-2020
if (file.exists(file.path(CA, "04-nlcd-1990-2000.rds"))) { u0 <- urb(1990L, 2000L); z <- merge(t, u0[, .(Fips, U0 = U)], by = "Fips")[U0 * 10 >= 1]
  say("  for scale: a county's own earlier change (2000-2010 / 1990-2000) against its later one: Spearman %.2f; its level, 2000-2010 against 2010-2020: Spearman %.2f",
      cor(z$U1 / z$U0, z$Obs, method = "spearman"), cor(z$U1, z$U2, method = "spearman")) }
# the same ratio pooled by metropolitan area and by state, for comparison with the RPA poolings
cw <- fread(file.path(pkg, "defaults/strata/msa-crosswalk.csv"), colClasses = "character")
t[, `:=`(State = substr(Fips, 1, 2), Metro = cw$Id[match(as.integer(Fips), as.integer(cw$Value))])]; t[is.na(Metro), Metro := paste0("rest-", State)]
pl <- function(by) { p <- t[, .(U1 = sum(U1), Obs = sum(U2) / sum(U1), Pred = (sum(P2) + L * sum(G2)) / (sum(P1) + L * sum(G1)), P1 = sum(P1)), by = by]; sk(p, sprintf("pooled by %s", by)) }
print(rbind(pl("Metro"), pl("State"))[, .(What, Units = Counties, Spearman = round(Spearman, 2), Skill = round(Skill, 2), MedianAbsLogError = round(MedianAbsLogError, 2))])
fwrite(d[, .(Fips, P1 = round(P1), Gain1 = round(D1, 1), P2 = round(P2), Gain2 = round(D2, 1), U1 = round(U1, 4), U2 = round(U2, 4), Observed = round(Obs, 3), Predicted = round(Pred, 3))], file.path(OUT, "05-population-test-county.csv"))

# ---- Hauer: the ratios the model gives against 2010-2020, by SSP -----------------------------------------------------------------
hf <- file.path(DS, "land-use/hauer-2019/county-total-by-year.rds")
if (file.exists(hf)) { h <- readRDS(hf); L2 <- fb$L; ssp <- grep("^SSP", names(h), value = TRUE)
  h <- melt(h, id.vars = c("GEOID", "YEAR"), measure.vars = ssp, variable.name = "Ssp", value.name = "H")[GEOID %in% d$Fips]
  # Hauer's change relative to its own 2020, on the Census 2020 population (Hauer's 2020 is itself projected, from 2015)
  h[, P := d$P2020[match(GEOID, d$Fips)] * H / H[YEAR == 2020], by = .(GEOID, Ssp)]; setorder(h, Ssp, GEOID, YEAR)
  h[, `:=`(Pm = (P + shift(P)) / 2, G = pmax(P - shift(P), 0) / 5, Step = paste(shift(YEAR), YEAR, sep = "-")), by = .(GEOID, Ssp)]; h <- h[!is.na(Pm)]
  h[, `:=`(Pb = d$P2[match(GEOID, d$Fips)], Gb = d$G2[match(GEOID, d$Fips)], Ub = d$U2[match(GEOID, d$Fips)])]; h[, Ratio := (Pm + L2 * G) / (Pb + L2 * Gb)]
  nat <- h[, .(Ratio = sum(Ub * Ratio) / sum(Ub), Q05 = quantile(Ratio, 0.05), Q50 = median(Ratio), Q95 = quantile(Ratio, 0.95), Max = max(Ratio)), by = .(Ssp, Step)]
  fwrite(nat, file.path(OUT, "05-population-ratios-national.csv"))
  say("\nHauer, L = %.1f years (both decades): the national ratio to 2010-2020 (counties weighted by their 2010-2020 development):", L2)
  print(dcast(nat[Step %in% c("2020-2025", "2030-2035", "2045-2050", "2065-2070", "2095-2100")], Ssp ~ Step, value.var = "Ratio")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])
  say("County ratios in 2065-2070 (5%%, median, 95%%, highest): %s", paste(nat[Step == "2065-2070", sprintf("%s %.2f / %.2f / %.2f / %.1f", Ssp, Q05, Q50, Q95, Max)], collapse = "; "))
  ex <- c(Placer = "06061", `Santa Clara` = "06085", Riverside = "06065", Travis = "48453", Harris = "48201", Cook = "17031")
  say("Example counties, SSP2 / SSP3 / SSP5 in 2045-2050: %s", paste(vapply(names(ex), function(k) sprintf("%s %s", k, paste(sprintf("%.2f", h[GEOID == ex[[k]] & Step == "2045-2050" & Ssp %in% c("SSP2", "SSP3", "SSP5"), Ratio]), collapse = " / ")), ""), collapse = "; "))
} else say("Hauer county totals not found (%s)", hf)
