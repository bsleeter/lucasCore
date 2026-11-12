# Unit test: the wood products model against the US Greenhouse Gas Inventory (to-do 59, the national check).
# The model is fed a national harvest series and its harvested wood products stock and stock change are compared with the Inventory's
# (EPA 2021, Tables 6-9 and 6-10, production approach: the WOODCARB II model of Skog 2008). The series: each Smith region's harvest
# history (regional-harvest-history.csv) scaled, by wood type and year, so the regions sum to the national roundwood harvest from all
# sources (Oswalt et al. 2019 Table 41: 1952, 1962, 1976, 1986, 1996, 2006, 2016, linear between; before 1952 the 1952 factor), in
# carbon (cubic feet x specific gravity of the region's growing stock x 0.5, plus bark). Both values are in transcribed/.
# The two models differ in their inputs (the Inventory starts from product output and trade, from 1900, housing from 1800; this one
# from roundwood, from 1906), so the check is loose: the stock within 10%, products in use and SWDS each within 15%, the stock change within 10% (the Inventory's own 95%
# interval on the 2019 stock change is about +-26%). Results 2026-11-12: stock 0.93-0.98 of the Inventory's, products in use 0.87-0.90
# (its housing from 1800), SWDS 1.00-1.02, stock change 0.97-1.03.
# Usage: Rscript tests/unit-wood-products-national.R   (from the package folder; VERBOSE=1 prints the comparison)
suppressPackageStartupMessages(library(data.table))
source(file.path("src", "wood-products.R"))
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
P <- wp_params(); tr <- function(f) fread(file.path("defaults", "wood-products", "transcribed", f), header = TRUE)
us <- melt(tr("frus2017-us-roundwood-1952-2016.csv"), id.vars = "Wood", variable.name = "Year", value.name = "Kcf", variable.factor = FALSE)[Wood != "All"][, Year := as.integer(Year)]
epa <- tr("epa-ghgi-2021-hwp.csv")
yrs <- 1906:2016
h <- P$history[Year %in% yrs]
tot <- h[, .(Sum = sum(Removals)), by = .(Wood, Year)]
tot[, Target := approx(us[Wood == .BY$Wood, Year], us[Wood == .BY$Wood, Kcf] / 1000, Year, rule = 2)$y, by = Wood]   # million cubic feet
h <- merge(h, tot, by = c("Wood", "Year"))
# volume to carbon: million cubic feet x 28,316.8 m3 x specific gravity (t/m3) x 0.5 t C/t, plus bark (sawlog bark to wood ratio)
g <- P$growing[ForestTypeGroup == "", .(Region, sgS = SoftwoodSpecificGravity, sgH = HardwoodSpecificGravity)]
b <- merge(P$regions[, .(Region, RoundwoodRegion)], P$roundwood[LogSize == "Sawlog", .(RoundwoodRegion, Wood, Bark = BarkToWood)], by = "RoundwoodRegion", allow.cartesian = TRUE)
h <- merge(merge(h, g, by = "Region"), b[, .(Region, Wood, Bark)], by = c("Region", "Wood"))
h[, Carbon := Removals * Target / Sum * 28316.8 * fifelse(Wood == "SW", sgS, sgH) * 0.5 * (1 + Bark) / 1e6]   # MMT C
rem <- h[, .(Iteration = 1L, Year, Region, Wood, Cause = "Harvest", Carbon)]
m <- wp_model(rem, P, wp_draws(P, central = TRUE), spinup = FALSE)$years
md <- wp_model(rem, P, wp_draws(P, n = 40, seed = 11), spinup = FALSE)
s <- wp_summary(md)[is.na(Iteration)]
# the Inventory's stock is at the start of its year; the model's at the end
cmp <- function(pool, var) {
  e <- epa[Pool == pool & !is.na(Stock), .(Year, EPA = Stock)]; e[, Model := m[match(e$Year - 1L, Year), get(var)]]; e[Year - 1L <= max(yrs)] }
cs <- function(pool) { e <- epa[Pool == pool, .(Year, EPA = StockChange)]; e[, Model := m[match(e$Year, Year), StockChange]]
  e[, `:=`(Lower = s[Variable == "StockChange"][match(e$Year, Year), Lower], Upper = s[Variable == "StockChange"][match(e$Year, Year), Upper])]; e[Year <= max(yrs)] }
st <- cmp("Harvested Wood", "Stored"); pu <- cmp("Products in Use", "InUse"); ch <- cs("Harvested Wood")
m[, SWDS := Landfill + Dump]; sw <- cmp("SWDS", "SWDS")
if (Sys.getenv("VERBOSE") == "1") {
  cat("harvest in carbon (MMT C):", paste(sprintf("%d %.0f", c(1906L, 1952L, 1990L, 2005L, 2016L), m[match(c(1906L, 1952L, 1990L, 2005L, 2016L), Year), Removed]), collapse = ", "), "\n")
  cat("stock, MMT C (Inventory / model):\n"); print(st[, .(Year, EPA, Model = round(Model), Ratio = round(Model / EPA, 2))])
  cat("products in use:\n"); print(pu[, .(Year, EPA, Model = round(Model), Ratio = round(Model / EPA, 2))])
  cat("SWDS:\n"); print(sw[, .(Year, EPA, Model = round(Model), Ratio = round(Model / EPA, 2))])
  cat("stock change, MMT C/yr (model central, 90% interval of 40 draws):\n"); print(ch[, .(Year, EPA, Model = round(Model, 1), Lower = round(Lower, 1), Upper = round(Upper, 1), Ratio = round(Model / EPA, 2))]) }
check(sprintf("the national stock within 10%% of the Inventory's in 1990, 2005, 2016 (ratios %s)", paste(sprintf("%.2f", st$Model / st$EPA), collapse = " ")), all(abs(st$Model / st$EPA - 1) < 0.10))
check(sprintf("products in use and SWDS each within 15%% (ratios %s; %s)", paste(sprintf("%.2f", pu$Model / pu$EPA), collapse = " "), paste(sprintf("%.2f", sw$Model / sw$EPA), collapse = " ")), all(abs(pu$Model / pu$EPA - 1) < 0.15) && all(abs(sw$Model / sw$EPA - 1) < 0.15))
check(sprintf("the national stock change within 10%% in 1990, 2005, 2015, 2016 (ratios %s)", paste(sprintf("%.2f", ch$Model / ch$EPA), collapse = " ")), all(abs(ch$Model / ch$EPA - 1) < 0.10))
check("the stock change is a sink (stored carbon grows) in every Inventory year", all(ch$Model > 0))
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
