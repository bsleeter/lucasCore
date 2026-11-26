suppressMessages(library(data.table)); options(width = 230)
d <- "dev/wetland-change"; rd <- function(f) fread(file.path(d, f))
s <- rd("dswe-series.csv"); h <- rd("dswe-hist.csv"); st <- rd("dswe-stability.csv"); rf <- rd("dswe-referee.csv"); ov <- rd("dswe-overlap.csv")
r2 <- function(x) if (is.numeric(x)) round(x, 2) else x
cat("\n== Regions in each table ==\n"); print(sapply(list(series = s, hist = h, stability = st, referee = rf, overlap = ov), function(x) uniqueN(x$Region)))
cat("\n== Yearly water area 1994-2025, kha: DSWE open-water equivalent against NLCD water ==\n")
print(s[, .(DsweMin = min(DsweOpenHa) / 1000, DsweMax = max(DsweOpenHa) / 1000, NlcdMin = min(NlcdWaterHa) / 1000, NlcdMax = max(NlcdWaterHa) / 1000,
  Corr = cor(DsweOpenHa, NlcdWaterHa), Dswe9597 = mean(DsweOpenHa[Year %in% 1995:1997]) / 1000, Dswe2022 = mean(DsweOpenHa[Year %in% 2020:2022]) / 1000,
  Nlcd9597 = mean(NlcdWaterHa[Year %in% 1995:1997]) / 1000, Nlcd2022 = mean(NlcdWaterHa[Year %in% 2020:2022]) / 1000,
  PartialMean = mean(DswePartialHa) / 1000, ObsMin = min(MeanObs), ObsMax = max(MeanObs)), by = Region][, lapply(.SD, r2)])
cat("\n== Trend of yearly water area, ha per year (linear, 1996-2021) ==\n")
print(s[Year %in% 1996:2021, .(DsweOpen = coef(lm(DsweOpenHa ~ Year))[2], DsweOpenPlusPartial = coef(lm(I(DsweOpenHa + DswePartialHa) ~ Year))[2],
  NlcdWater = coef(lm(NlcdWaterHa ~ Year))[2], NlcdWetland = coef(lm(NlcdWetlandHa ~ Year))[2], NlcdBarren = coef(lm(NlcdBarrenHa ~ Year))[2]), by = Region][, lapply(.SD, function(x) if (is.numeric(x)) round(x) else x)])
cat("\n== Does a water line hold year to year, 1996-2021 (kha) ==\n")
print(st[, .(Region, Rule, Start = WaterStartKha, End = WaterEndKha, GrossTo = GrossToWaterKha, GrossFrom = GrossFromWaterKha, NetTo = NetToWaterKha, NetFrom = NetFromWaterKha,
  GrossOverNet = (GrossToWaterKha + GrossFromWaterKha) / (NetToWaterKha + NetFromWaterKha), Once = ChangedOnceKha, More = ChangedTwiceKha + ChangedMoreKha)][, lapply(.SD, r2)])
cat("\n== Cells that changed 1996 > 2021 in each product (kha) ==\n"); print(ov[, lapply(.SD, r2)])
cat("\n== DSWE as referee: mean open-water share (3-year mean, %) of the cells each product calls changed ==\n")
g <- function(x, lab) x[, .(Set = lab, Kha = sum(Kha), Open96 = weighted.mean(Open96, Kha), Open21 = weighted.mean(Open21, Kha), Partial96 = weighted.mean(Partial96, Kha), Partial21 = weighted.mean(Partial21, Kha)), by = Region]
ref <- rbind(g(rf[Ccap == "Wetland > Water"], "C-CAP wetland > water"), g(rf[Nlcd == "Wetland > Water"], "NLCD wetland > water"),
  g(rf[Ccap == "Wetland > Water" & Nlcd == "Wetland > Water"], "both wetland > water"),
  g(rf[Ccap == "Wetland > Water" & Nlcd == "Wetland > Wetland"], "C-CAP only (NLCD stays wetland)"), g(rf[Nlcd == "Wetland > Water" & Ccap == "Wetland > Wetland"], "NLCD only (C-CAP stays wetland)"),
  g(rf[Ccap == "Water > Wetland"], "C-CAP water > wetland"), g(rf[Nlcd == "Water > Wetland"], "NLCD water > wetland"),
  g(rf[Nlcd == "Wetland > Wetland"], "NLCD wetland, no change"), g(rf[Nlcd == "Water > Water"], "NLCD water, no change"),
  g(rf[Nlcd == "Barren > Barren"], "NLCD barren, no change"), g(rf[Nlcd == "Water > Barren"], "NLCD water > barren"), g(rf[Nlcd == "Barren > Water"], "NLCD barren > water"),
  g(rf[Ccap == "Barren > Barren"], "C-CAP barren, no change"))
print(ref[order(Region)][, lapply(.SD, r2)], nrows = 200)
cat("\n== Threshold on DSWE open water (2021, 3-year mean): agreement with each product's water, % of kept cells; best line ==\n")
thr <- rbindlist(lapply(1:10, function(t) h[Year == 2021, .(T = (t - 1) * 10, NlcdAgree = 100 * sum(Ha[(Open >= t) == (Nlcd == "Water")]) / sum(Ha),
  CcapAgree = 100 * sum(Ha[Ccap != "None" & (Open >= t) == (Ccap == "Water")]) / sum(Ha[Ccap != "None"])), by = Region]))
print(dcast(thr, Region ~ T, value.var = "NlcdAgree")[, lapply(.SD, r2)]); print(dcast(thr, Region ~ T, value.var = "CcapAgree")[, lapply(.SD, r2)])
cat("\n== DSWE inside each NLCD class, 2021: mean open and partial share, and the share of the class over a line ==\n")
mid <- c(0, seq(5, 95, 10))
print(h[Year == 2021, .(Kha = sum(Ha) / 1000, OpenMean = weighted.mean(mid[Open + 1], Ha), PartialMean = weighted.mean(mid[Partial + 1], Ha),
  PctOpenOver50 = 100 * sum(Ha[Open >= 6]) / sum(Ha), PctPartialOver10 = 100 * sum(Ha[Partial >= 2]) / sum(Ha), PctPartialOver30 = 100 * sum(Ha[Partial >= 4]) / sum(Ha),
  PctDry = 100 * sum(Ha[Open <= 1 & Partial <= 1]) / sum(Ha)), by = .(Region, Nlcd)][order(Region, Nlcd)][, lapply(.SD, r2)], nrows = 100)
cat("\n== Same inside each C-CAP class, 2021 ==\n")
print(h[Year == 2021 & Ccap != "None", .(Kha = sum(Ha) / 1000, OpenMean = weighted.mean(mid[Open + 1], Ha), PartialMean = weighted.mean(mid[Partial + 1], Ha),
  PctOpenOver50 = 100 * sum(Ha[Open >= 6]) / sum(Ha), PctPartialOver10 = 100 * sum(Ha[Partial >= 2]) / sum(Ha), PctPartialOver30 = 100 * sum(Ha[Partial >= 4]) / sum(Ha),
  PctDry = 100 * sum(Ha[Open <= 1 & Partial <= 1]) / sum(Ha)), by = .(Region, Ccap)][order(Region, Ccap)][, lapply(.SD, r2)], nrows = 100)
