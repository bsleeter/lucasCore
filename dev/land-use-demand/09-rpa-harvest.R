# =============================================================================
# 09-rpa-harvest.R - timber harvest in the 2020 RPA Assessment's forest products projections, as ratios to the recent past (exploratory)
# =============================================================================
# User question 2026-11-14: can RPA give alternative scenarios of timber harvest? The county land-use table (01) has none; RPA's harvest
# comes from its market model FOROM: Johnston, C.M.T., Guo, J., and Prestemon, J.P., 2023, RPA forest products market data for U.S. RPA
# Regions and the world, historical (1990-2015), and projected (2020-2070) using the Forest Resource Outlook Model (FOROM), 2nd
# Edition, https://doi.org/10.2737/RDS-2022-0073-2. One table per scenario (LM = RCP4.5-SSP1, HL = RCP8.5-SSP3, HM = RCP8.5-SSP2,
# HH = RCP8.5-SSP5): Measurement, Product, Units, Location, then a column per year (1990-2015 every year, 2020-2070 every five).
# Here: Timber harvest level (coniferous, non-coniferous and total timber, thousand m3) in the six U.S. regions of the table, each
# scenario's harvest relative to the region's mean of 2011-2015 (history is the same in every scenario).
# Writes 09-rpa-harvest-ratios.csv.
# Usage: Rscript dev/land-use-demand/09-rpa-harvest.R   (LUCAS_DATA_HOME = the Data Sources folder)
# =============================================================================
pkg <- local({ d <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))); while (!file.exists(file.path(d, "package.xml")) && dirname(d) != d) d <- dirname(d); d })
DS <- Sys.getenv("LUCAS_DATA_HOME", "E:/lucasData"); suppressPackageStartupMessages(library(data.table)); OUT <- file.path(pkg, "dev/land-use-demand"); say <- function(...) cat(sprintf(...), "\n")
SC <- c(LM = "RCP4.5-SSP1", HM = "RCP8.5-SSP2", HL = "RCP8.5-SSP3", HH = "RCP8.5-SSP5"); US <- c("North East", "North Central", "South East", "South Central", "Rocky Mountain", "Pacific Coast", "United States")
x <- rbindlist(lapply(names(SC), function(s) { d <- fread(file.path(DS, "land-use/rpa-forest-products/Data", sprintf("Ch7_%s_v2.csv", s)), header = TRUE)
  melt(d[Location %in% US], id.vars = c("Measurement", "Product", "Units", "Location"), variable.name = "Year", value.name = "Value", variable.factor = FALSE)[, `:=`(Scenario = SC[[s]], Year = as.integer(Year))] }))
say("Measurements for the U.S. regions: %s", paste(unique(x$Measurement), collapse = "; "))
h <- x[Measurement == "Timber harvest level"]; say("Timber harvest products: %s (%s)", paste(unique(h$Product), collapse = ", "), paste(unique(h$Units), collapse = ", "))
chk <- h[Year <= 2015, .(sd = sd(Value)), by = .(Product, Location, Year)]; say("History differs between scenarios: %s", if (max(chk$sd, na.rm = TRUE) > 1e-6) "yes" else "no")
# the six regions have no history in the table (projections only): their base is 2020, the first projected year; the United States' is 2011-2015
reg <- h[Year <= 2015, .(n = sum(!is.na(Value))), by = Location]; say("Locations with history 1990-2015: %s; without (base = 2020): %s", paste(reg[n > 0, Location], collapse = ", "), paste(reg[n == 0, Location], collapse = ", "))
h[, Base := if (any(!is.na(Value[Year %in% 2011:2015]))) mean(Value[Year %in% 2011:2015], na.rm = TRUE) else Value[Year == 2020], by = .(Scenario, Product, Location)]; h[, Ratio := Value / Base]
say("\nTimber harvest in the base (United States 2011-2015, regions 2020, RCP4.5-SSP1), million m3 a year (total; coniferous share):")
print(dcast(h[Scenario == SC[[1]] & Year == 2015], Location ~ Product, value.var = "Base")[, .(Location, Total = round(`total timber` / 1e3, 1), ConiferousShare = round(`coniferous timber` / `total timber`, 2))])
say("  check: the six regions sum to %.1f; United States %.1f", h[Scenario == SC[[1]] & Year == 2015 & Product == "total timber" & Location != "United States", sum(Base)] / 1e3, h[Scenario == SC[[1]] & Year == 2015 & Product == "total timber" & Location == "United States", Base] / 1e3)
for (p in c("total timber", "coniferous timber", "non-coniferous timber")) { say("\nRatio to the base (United States 2011-2015; regions 2020), %s:", p)
  print(dcast(h[Product == p & Year %in% c(2030, 2050, 2070)], Location + Scenario ~ Year, value.var = "Ratio")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)], nrows = 60) }
fwrite(h[Year >= 2011, .(Scenario, Location, Product, Year, Thousand_m3 = round(Value, 1), Ratio = round(Ratio, 4))][order(Product, Location, Scenario, Year)], file.path(OUT, "09-rpa-harvest-ratios.csv"))
say("\nUnited States, total timber, the range across scenarios by year: %s", paste(h[Location == "United States" & Product == "total timber" & Year >= 2020, .(lo = min(Ratio), hi = max(Ratio)), by = Year][Year %in% c(2020, 2030, 2040, 2050, 2060, 2070), sprintf("%d %.2f-%.2f", Year, lo, hi)], collapse = ", "))
hist <- h[Scenario == SC[[1]] & Product == "total timber" & Location == "United States" & Year <= 2015]; say("For scale, the U.S. record 1990-2015 as a ratio to 2011-2015: lowest %.2f (%d), highest %.2f (%d)", min(hist$Ratio), hist[which.min(Ratio), Year], max(hist$Ratio), hist[which.max(Ratio), Year])
pr <- x[Measurement == "Price level" & grepl("industrial roundwood", Product) & Location == "United States" & Year %in% c(2015, 2030, 2050, 2070)]
if (nrow(pr)) { say("\nU.S. industrial roundwood price, 2015 USD per m3:"); print(dcast(pr, Product + Scenario ~ Year, value.var = "Value")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 1) else v)]) }
