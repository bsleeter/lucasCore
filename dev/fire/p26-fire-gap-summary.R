# Usage: Rscript dev/fire/p26-fire-gap-summary.R <out folder of p26-fire-gap.R>   (to-do 57)
suppressMessages(library(data.table)); o <- commandArgs(TRUE)[1]; ha <- 0.09
S <- c(`0` = "Control (unburned)", `2` = "Low", `3` = "Moderate", `4` = "High")
P <- fread(file.path(o, "pixels.csv")); Y <- fread(file.path(o, "by-year.csv")); T <- fread(file.path(o, "by-type.csv"))
cat("Burned forest (NLCD forest the year before), first MTBS burn 1986-2024, P26:\n")
print(P[ctl == FALSE, .(kha = round(.N * ha / 1e3, 1), reburned_pct = round(100 * mean(reburn > 0), 1)), by = .(Severity = S[as.character(sev)])][order(Severity)])
w <- function(d) dcast(d[, .(N = sum(N)), by = .(k, g, cls)][, p := round(100 * N / sum(N), 1), by = .(k, g)], k + g ~ cls, value.var = "p", fill = 0)
cat("\nNLCD class k years after the fire, % (pixels not reburned by then):\n")
x <- Y[reb == FALSE & k %in% c(1, 3, 5, 10, 15, 20, 25, 30)][, g := S[as.character(sev)]]
print(w(x)[, c("k", "g", "Forest", "Shrub", "Grass", "Barren", "Developed", "Agriculture", "Water/wetland/other"), with = FALSE][order(g, k)])
cat("\nSame, reburned pixels (all severities):\n"); print(w(Y[reb == TRUE & ctl == FALSE & k %in% c(5, 10, 15, 20, 25)][, g := "Reburned"])[, .(k, Forest, Shrub, Grass)])
cat("\nBack to NLCD forest (2 years running), fires 1986-2005 (20+ years to see):\n")
print(P[fy <= 2005, .(n_kha = round(.N * ha / 1e3, 1), back_pct = round(100 * mean(!is.na(back)), 1), median_years = as.numeric(median(back, na.rm = TRUE)),
        q75_years = as.numeric(quantile(back, 0.75, na.rm = TRUE)), forest_2025_pct = round(100 * mean(now == "Forest"), 1)), by = .(g = S[as.character(sev)], reburned = reburn > 0)][order(g, reburned)])
cat("\nNot NLCD forest in 2025, kha (burned pixels; control rate applied to the same area for NLCD's own drift):\n")
cr <- P[ctl == TRUE, mean(now != "Forest")]
z <- P[ctl == FALSE, .(kha = .N * ha / 1e3, nonforest_kha = sum(now != "Forest") * ha / 1e3), by = .(g = S[as.character(sev)])]
z[, excess_kha := nonforest_kha - cr * kha]; print(z[, lapply(.SD, round, 1), by = g]); cat(sprintf("control: %.1f%% not forest in 2025\n", 100 * cr))
print(z[, .(burned_kha = sum(kha), nonforest_2025_kha = sum(nonforest_kha), excess_kha = sum(excess_kha))])
cat("\nBy forest type group (USFS), high severity, not reburned, % NLCD forest at 10 and 20 years (types with >= 2,000 pixels):\n")
tt <- T[reb == FALSE & sev %in% c(0, 4) & k %in% c(10, 20)][, .(N = sum(N), F = sum(N[cls == "Forest"])), by = .(ftype, sev, k)][N >= 2000]
print(dcast(tt[, .(ftype, g = paste0(S[as.character(sev)], " ", k, "y"), v = round(100 * F / N))], ftype ~ g, value.var = "v")[order(ftype)])
