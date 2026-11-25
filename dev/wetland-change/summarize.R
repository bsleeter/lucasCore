suppressMessages(library(data.table)); options(width = 220)
d <- "dev/wetland-change"
a <- fread(file.path(d, "areas.csv")); ch <- fread(file.path(d, "changes.csv")); ag <- fread(file.path(d, "agreement.csv"))
st <- fread(file.path(d, "static.csv")); fl <- fread(file.path(d, "flicker.csv")); yr <- fread(file.path(d, "nlcd-yearly.csv"))
cat("\n== Class area, kha (1996 and 2021) ==\n")
print(dcast(a[Year %in% c(1996, 2021) & Class != "Other"], Region + Class ~ Product + Year, value.var = "Ha")[, lapply(.SD, function(x) if (is.numeric(x)) round(x / 1000, 1) else x)])
cat("\n== Net change 1996-2021 by pair, kha ==\n")
p <- ch[Interval == "1996-2021" & From != To & (From != "Other" | To != "Other")]
p[, Pair := paste(From, ">", To)]
print(dcast(p[From != "Other" & To != "Other" | Ha > 0], Region + Pair ~ Product, value.var = "Ha")[, .(Region, Pair, CCAP = round(`C-CAP` / 1000, 2), NLCD = round(NLCD / 1000, 2))][CCAP > 0.3 | NLCD > 0.3])
cat("\n== Wetland > Water by interval, kha ==\n")
print(dcast(ch[From == "Wetland" & To == "Water" & Interval != "1996-2021"], Region + Product ~ Interval, value.var = "Ha")[, lapply(.SD, function(x) if (is.numeric(x)) round(x / 1000, 2) else x)])
cat("\n== Water > Wetland by interval, kha ==\n")
print(dcast(ch[From == "Water" & To == "Wetland" & Interval != "1996-2021"], Region + Product ~ Interval, value.var = "Ha")[, lapply(.SD, function(x) if (is.numeric(x)) round(x / 1000, 2) else x)])
cat("\n== Cell agreement on 1996-2021 change: where one product shows the change, what the other shows (%) ==\n")
for (k in c("Wetland > Water", "Water > Wetland", "Wetland > Barren", "Barren > Water", "Water > Barren")) {
  x <- ag[Ccap == k][, .(Region, Other = Nlcd, Pct = round(100 * Ha / sum(Ha), 1), TotKha = round(sum(Ha) / 1000, 2)), by = .(R = Region)][order(Region, -Pct)][, .SD[1:3], by = Region]
  cat("\nC-CAP", k, ": NLCD shows\n"); print(x[, .(Region, TotKha, Other, Pct)])
  x <- ag[Nlcd == k][, .(Region, Other = Ccap, Pct = round(100 * Ha / sum(Ha), 1), TotKha = round(sum(Ha) / 1000, 2)), by = .(R = Region)][order(Region, -Pct)][, .SD[1:3], by = Region]
  cat("\nNLCD", k, ": C-CAP shows\n"); print(x[, .(Region, TotKha, Other, Pct)]) }
cat("\n== Static agreement 2021: % of each C-CAP class NLCD gives the same class; and the reverse ==\n")
print(st[, .(Same = sum(Ha[Ccap == Nlcd]), Tot = sum(Ha)), by = .(Region, Class = Ccap)][, .(Region, Class, CcapKha = round(Tot / 1000, 1), NlcdAgreesPct = round(100 * Same / Tot, 1))][Class != "Other"])
print(st[, .(Same = sum(Ha[Ccap == Nlcd]), Tot = sum(Ha)), by = .(Region, Class = Nlcd)][, .(Region, Class, NlcdKha = round(Tot / 1000, 1), CcapAgreesPct = round(100 * Same / Tot, 1))][Class != "Other"])
cat("\n== NLCD year by year 1996-2021 (kha) ==\n")
print(fl[, lapply(.SD, function(x) if (is.numeric(x)) round(x / 1000, 2) else x)])
cat("\n== NLCD yearly wetland > water, ha, by year ==\n")
print(dcast(yr, Year ~ Region, value.var = "WetlandToWater")[, lapply(.SD, round)])
cat("\n== NLCD yearly water > wetland, ha, by year ==\n")
print(dcast(yr, Year ~ Region, value.var = "WaterToWetland")[, lapply(.SD, round)])
