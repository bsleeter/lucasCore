# =============================================================================
# make_wood_products.R - the harvested wood products parameters (to-do 59, step 1), from the USFS sources
# =============================================================================
# Writes defaults/wood-products/*.csv (see its README.md) from two downloads, read and never copied into the package whole:
#   --smith=<folder>  the CD tables of Smith, Heath, Skog and Birdsey 2006 (GTR NE-343), gtr_ne343.zip from
#                     https://www.nrs.fs.usda.gov/pubs/downloads/gtr_ne343.zip, unzipped (Table_4.csv, Table_5.csv, Table_D*.csv)
#   --hwpc=<folder>   a clone of the USFS HWP-C calculator in R (HWP-C vR; https://github.com/jeremygroom/HWP-C-vR): its regional
#                     templates (HWP Data/Templates) and the California, Oregon and Washington inputs (HWP Data/ExistingData)
# What comes from where (README.md has the full list):
#   Smith 2006      regions' growing-stock factors (Table 4, D8), roundwood factors (Table 5), roundwood to primary products (D6)
#   HWP-C vR        end-use ratios by year (McKeever 2009; McKeever and Howard 2011), end-use half-lives (Smith 2006 Table D3),
#                   discard fates by year (Skog 2008 Tables 6a, 6b), landfill and dump parameters (Skog 2008 Table 7), the 8% loss
#                   when placed in use, the Monte Carlo ranges (Stockmann et al. 2012 Table 9), and three state harvest histories
# The HWP-C regional templates' primary product ratios are not used: where Smith's Table D6 has no row for a region they copy another
# product class (Rocky Mountain and PNW East hardwood go 100% to fuel) or carry state values (Pacific Southwest). This script takes
# Table D6 itself and fills its gaps with Smith's own West hardwood row, the region Smith defines as RMN, RMS, PWE and PSW (Fig. 1).
# Usage: Rscript tools/make_wood_products.R --smith=<gtr_ne343 folder> --hwpc=<HWP-C-vR folder>
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(readxl) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
arg <- function(k) { a <- grep(paste0("^--", k, "="), commandArgs(TRUE), value = TRUE); if (!length(a)) stop("give --", k, "=<folder>"); sub("^[^=]*=", "", a[1]) }
smith <- arg("smith"); hwpc <- arg("hwpc")
out <- file.path(pkg, "defaults", "wood-products"); dir.create(out, showWarnings = FALSE)
w <- function(x, f) { fwrite(x, file.path(out, f), na = ""); cat(sprintf("%-28s %6d rows\n", f, nrow(x))) }
sm <- function(f) { x <- fread(file.path(smith, f), na.strings = c("", "--")); setnames(x, gsub("\\s+", " ", trimws(names(x)))); x[, names(x)[1] := trimws(get(names(x)[1]))] }
tpl_file <- function(region) { f <- list.files(file.path(hwpc, "HWP Data", "Templates", region), "[.]xlsx$", full.names = TRUE); if (length(f) != 1) stop("no single template in ", region); f }
rt <- function(region, sheet) as.data.table(suppressMessages(read_excel(tpl_file(region), sheet)))
commit <- tryCatch(system2("git", c("-C", shQuote(hwpc), "rev-parse", "--short", "HEAD"), stdout = TRUE), error = function(e) "unknown")

# ---- regions --------------------------------------------------------------------------------------------------------------
# Smith 2006 Fig. 1 defines ten regions on a map; the state lists below are lucasCore's reading of it (the RPA / FORCARB regions),
# checked against Smith's Table 4: Northern Prairie States has ponderosa pine (the Black Hills: South Dakota and Nebraska are NPS),
# Rocky Mountain North has hemlock-Sitka spruce (northern Idaho). Oregon and Washington split at the Cascade crest: the Marine
# ecodivisions (240, 2401) are PNW West, the rest PNW East. Merged regions (Fig. 1): North Central = NLS + NPS; Pacific Coast = PWW +
# PWE + PSW; Rocky Mountain = RMN + RMS; South = SE + SC; West = RMN + RMS + PWE + PSW.
regions <- data.table(
  Region = c("NE", "NLS", "NPS", "SE", "SC", "RMN", "RMS", "PSW", "PWE", "PWW"),
  Name = c("Northeast", "Northern Lake States", "Northern Prairie States", "Southeast", "South Central", "Rocky Mountain, North",
           "Rocky Mountain, South", "Pacific Southwest", "Pacific Northwest, East", "Pacific Northwest, West"),
  GrowingStockRegion = c("Northeast", "Northern Lake States", "Northern Prairie States", "Southeast", "South Central", "Rocky Mountain; North",
                         "Rocky Mountain; South", "Pacific Southwest", "Pacific Northwest; East", "Pacific Northwest; West"),
  RoundwoodRegion = c("Northeast", "North Central", "North Central", "South", "South", "Rocky Mountain", "Rocky Mountain", "Pacific Coast", "Pacific Coast", "Pacific Coast"),
  ProductRegion = c("Northeast", "North Central", "North Central", "Southeast", "South Central", "Rocky Mountain", "Rocky Mountain", "Pacific Southwest",
                    "Pacific Northwest; East", "Pacific Northwest; West"),
  West = c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE),
  States = c("Connecticut;Delaware;Maine;Maryland;Massachusetts;New Hampshire;New Jersey;New York;Ohio;Pennsylvania;Rhode Island;Vermont;West Virginia",
             "Michigan;Minnesota;Wisconsin",
             "Illinois;Indiana;Iowa;Kansas;Missouri;Nebraska;North Dakota;South Dakota",
             "Florida;Georgia;North Carolina;South Carolina;Virginia",
             "Alabama;Arkansas;Kentucky;Louisiana;Mississippi;Oklahoma;Tennessee;Texas",
             "Idaho;Montana", "Arizona;Colorado;Nevada;New Mexico;Utah;Wyoming", "California",
             "Oregon;Washington", "Oregon;Washington"),
  Ecodivisions = c(rep("", 8), "not 240;2401", "240;2401"))
sl <- fread(file.path(pkg, "defaults", "strata", "states-list.csv"))
st <- unlist(strsplit(regions$States, ";")); if (length(bad <- setdiff(st, sl$Name))) stop("states not in defaults/strata/states-list.csv: ", paste(bad, collapse = ", "))
if (length(miss <- setdiff(sl$Name, c(st, "District of Columbia")))) stop("states in no region: ", paste(miss, collapse = ", "))
w(regions, "regions.csv")

# ---- growing stock: softwood share, sawtimber share and specific gravity by region and forest type group (Smith Table 4, D8) --
t4 <- sm("Table_4.csv"); setnames(t4, c("Region", "ForestTypeGroup", "SoftwoodFraction", "SoftwoodSawtimberFraction", "HardwoodSawtimberFraction",
                                        "SoftwoodSpecificGravity", "HardwoodSpecificGravity"))
t4[, `:=`(Region = trimws(Region), ForestTypeGroup = trimws(ForestTypeGroup))][ForestTypeGroup == "Ponderosa Pine", ForestTypeGroup := "Ponderosa pine"]   # PSW spells it so
d8 <- sm("Table_D8.csv"); setnames(d8, c("Region", "SoftwoodFraction", "SoftwoodSawtimberFraction", "HardwoodSawtimberFraction", "SoftwoodSpecificGravity", "HardwoodSpecificGravity"))
gs <- rbind(t4[Region != "West", .(Region = regions$Region[match(Region, regions$GrowingStockRegion)], ForestTypeGroup, SoftwoodFraction, SoftwoodSawtimberFraction,
                                   HardwoodSawtimberFraction, SoftwoodSpecificGravity, HardwoodSpecificGravity, Source = "Smith 2006 Table 4")],
            # Table 4's West rows: types found across RMN, RMS, PWE and PSW, where the region has no row of its own for the type
            rbindlist(lapply(regions[West == TRUE, Region], function(r) t4[Region == "West", .(Region = r, ForestTypeGroup, SoftwoodFraction, SoftwoodSawtimberFraction,
                                   HardwoodSawtimberFraction, SoftwoodSpecificGravity, HardwoodSpecificGravity, Source = "Smith 2006 Table 4 (West)")])),
            d8[, .(Region = regions$Region[match(trimws(Region), regions$GrowingStockRegion)], ForestTypeGroup = "", SoftwoodFraction, SoftwoodSawtimberFraction,
                   HardwoodSawtimberFraction, SoftwoodSpecificGravity, HardwoodSpecificGravity, Source = "Smith 2006 Table D8 (regional average)")])
if (anyNA(gs$Region)) stop("growing-stock rows with a region not in regions.csv")
gs <- gs[!duplicated(gs[, .(Region, tolower(ForestTypeGroup))])]   # a region's own row before the West row
w(gs, "growing-stock.csv")

# lucasCore forest classes to Smith's forest type groups (forested wetland classes share their upland group's row; classes with no
# Smith group take the regional average, with their wood type fixed where the class names it)
sc <- fread(file.path(pkg, "defaults", "stsim", "stsim_StateClass.csv"))
grp <- unique(sub("^(Forest|Wetland): ", "", grep("^(Forest|Wetland): .* Group$", sc$Name, value = TRUE)))
smith_name <- c(`Alder/Maple Group` = "Alder-maple", `Aspen/Birch Group` = "Aspen-birch", `California Mixed Conifer Group` = "Mixed conifer",
  `Douglas-fir Group` = "Douglas-fir", `Elm/Ash/Cottonwood Group` = "Elm-ash-cottonwood", `Fir/Spruce/Mountain Hemlock Group` = "Fir-spruce-m.hemlock",
  `Hemlock/Sitka Spruce Group` = "Hemlock-Sitka spruce", `Loblolly/Shortleaf Pine Group` = "Loblolly-shortleaf pine", `Lodgepole Pine Group` = "Lodgepole pine",
  `Longleaf/Slash Pine Group` = "Longleaf-slash pine", `Maple/Beech/Birch Group` = "Maple-beech-birch", `Oak/Gum/Cypress Group` = "Oak-gum-cypress",
  `Oak/Hickory Group` = "Oak-hickory", `Oak/Pine Group` = "Oak-pine", `Pinyon/Juniper Group` = "Pinyon-juniper", `Ponderosa Pine Group` = "Ponderosa pine",
  `Redwood Group` = "Redwood", `Spruce/Fir Group` = "Spruce-fir", `Tanoak/Laurel Group` = "Tanoak-laurel", `Western Larch Group` = "Western larch",
  `Western Oak Group` = "Western oak", `Western White Pine Group` = "Western white pine", `White/Red/Jack Pine Group` = "White-red-jack pine")
wood_of <- c(`Exotic Softwoods Group` = "SW", `Other Western Softwood Group` = "SW", `Exotic Hardwoods Group` = "HW", `Other Western Hardwoods Group` = "HW",
             `Tropical Hardwoods Group` = "HW")
xw <- data.table(ForestType = sort(grp))[, `:=`(ForestTypeGroup = unname(smith_name[ForestType]), Wood = unname(wood_of[ForestType]))]
xw[is.na(ForestTypeGroup), ForestTypeGroup := ""][is.na(Wood), Wood := ""]
if (length(bad <- xw[ForestTypeGroup == "" & Wood == "", ForestType])) stop("forest types with neither a Smith group nor a wood type: ", paste(bad, collapse = ", "))
if (length(bad <- setdiff(tolower(xw[nzchar(ForestTypeGroup), ForestTypeGroup]), tolower(gs$ForestTypeGroup)))) stop("Smith groups not in Table 4: ", paste(bad, collapse = ", "))
xw[, Note := fifelse(nzchar(ForestTypeGroup), "", sprintf("no Smith group: the regional average sawtimber shares and specific gravity, all %s", Wood))]
w(xw, "forest-type-crosswalk.csv")

# ---- roundwood factors by roundwood region (Smith Table 5) ------------------------------------------------------------------
t5 <- sm("Table_5.csv"); setnames(t5, c("RoundwoodRegion", "Wood", "LogSize", "IndustrialRoundwoodRatio", "BarkToWood", "RemovedAsRoundwood", "FuelwoodRatio"))
t5[, LogSize := fifelse(LogSize == "Saw log", "Sawlog", LogSize)]
w(t5, "roundwood-factors.csv")

# ---- roundwood to primary products (Smith Table D6; gaps filled with Smith's West hardwood row) --------------------------------
d6 <- sm("Table_D6.csv"); setnames(d6, c("ProductRegion", "Wood", "LogSize", "Softwood lumber", "Hardwood lumber", "Softwood plywood", "Hardwood plywood",
                                         "Oriented strandboard", "Nonstructural panels", "Other industrial products", "Wood pulp", "Fuel and other emissions"))
d6[, `:=`(ProductRegion = trimws(ProductRegion), LogSize = fcase(LogSize == "SL", "Sawlog", LogSize == "PW", "Pulpwood", default = LogSize))]
pp <- rbindlist(lapply(seq_len(nrow(regions)), function(i) { r <- regions[i]
  rbindlist(lapply(c("SW", "HW"), function(wd) rbindlist(lapply(c("Sawlog", "Pulpwood"), function(ls) {
    x <- d6[ProductRegion == r$ProductRegion & Wood == wd & LogSize %in% c(ls, "All")]; src <- sprintf("Smith 2006 Table D6 (%s, %s, %s)", r$ProductRegion, wd, x$LogSize[1])
    if (!nrow(x) && wd == "HW" && r$West) { x <- d6[ProductRegion == "West" & Wood == "HW"]; src <- "Smith 2006 Table D6 (West, HW, All: Fig. 1 West = RMN, RMS, PWE, PSW)" }
    if (!nrow(x) && r$Region == "PWW" && wd == "SW") stop("PNW West softwood missing")
    if (nrow(x) != 1) stop(sprintf("Table D6: %d rows for %s %s %s", nrow(x), r$Region, wd, ls))
    melt(x[, -(1:3)], measure.vars = names(x)[-(1:3)], variable.name = "Product", value.name = "Fraction", variable.factor = FALSE)[
      , .(Region = r$Region, Wood = wd, LogSize = ls, Product, Fraction, Source = src)] })))) }))
chk <- pp[, .(s = sum(Fraction)), by = .(Region, Wood, LogSize)]
if (any(abs(chk$s - 1) > 0.002)) stop("Table D6 fractions do not sum to 1: ", paste(chk[abs(s - 1) > 0.002, sprintf("%s %s %s %.3f", Region, Wood, LogSize, s)], collapse = "; "))
w(pp[Fraction > 0], "primary-products.csv")

# ---- end-use ratios by year (HWP-C vR; national: McKeever 2009, McKeever and Howard 2011; the same in every regional template) -
REG <- "Rocky_Mountain"
rc <- rt(REG, "RatioCategories"); setnames(rc, c("TP", "PP", "EU", "TimberProduct", "PrimaryProduct", "EndUse"))
eur <- rt(REG, "EndUseRatios"); setnames(eur, 1, "EU")
eu <- melt(eur, id.vars = "EU", variable.name = "Year", value.name = "Ratio", variable.factor = FALSE)[, Year := as.integer(as.numeric(Year))]
eu <- merge(eu, rc[TP <= 4], by = "EU")[, Wood := fifelse(grepl("^softwood", TimberProduct), "SW", "HW")]
# the HWP-C product names to Table D6's: lumber and plywood by wood type, the other products alike for both
prod <- function(p, wd) fcase(p == "lumber", paste(fifelse(wd == "SW", "Softwood", "Hardwood"), "lumber"), p == "plywood", paste(fifelse(wd == "SW", "Softwood", "Hardwood"), "plywood"),
                             p == "oriented strandboard (OSB)", "Oriented strandboard", p == "non-structural panels", "Nonstructural panels",
                             p == "other industrial products", "Other industrial products", p == "wood pulp", "Wood pulp", p == "fuelwood and other", "Fuel and other emissions")
eu[, Product := prod(PrimaryProduct, Wood)]
# one set per product: sawtimber and pulpwood rows of a product must agree wherever both carry it
one <- eu[, .(Ratio = unique(round(Ratio, 6))), by = .(Product, EndUse, Year, LogSize = fifelse(grepl("sawtimber", TimberProduct), "saw", "pulp"))]
dup <- dcast(one, Product + EndUse + Year ~ LogSize, value.var = "Ratio", fun.aggregate = function(v) v[1])
LP <- c("Softwood lumber", "Hardwood lumber", "Softwood plywood", "Hardwood plywood")
bad <- dup[!is.na(saw) & !is.na(pulp) & abs(saw - pulp) > 1e-6 & !Product %in% LP]
if (nrow(bad)) stop("end-use ratios differ between sawtimber and pulpwood for ", paste(unique(bad$Product), collapse = ", "))
# lumber and plywood: HWP-C gives the sawtimber rows the McKeever end uses and the pulpwood rows 100% 'other', a placeholder (its
# templates make lumber from pulpwood only where they copy the sawtimber product ratios). Lumber is lumber whatever log it came from,
# so every product takes the end uses of its sawtimber rows (OSB, made only from pulpwood, its pulpwood rows)
if (nrow(dup[Product %in% LP & !is.na(pulp) & pulp > 0 & EndUse != "other, n/a"])) stop("pulpwood lumber or plywood has end uses besides 'other': check the rule above")
eur_out <- dup[, .(Product, EndUse, Year, Ratio = fifelse(is.na(saw), pulp, saw))][order(Product, EndUse, Year)]
s <- eur_out[, .(s = sum(Ratio)), by = .(Product, Year)]; if (any(abs(s$s - 1) > 1e-3)) stop("end-use ratios do not sum to 1")
for (r in setdiff(list.files(file.path(hwpc, "HWP Data", "Templates")), c(REG, "Template.xlsx"))) {   # national: every template the same
  if (!dir.exists(file.path(hwpc, "HWP Data", "Templates", r))) next
  e2 <- rt(r, "EndUseRatios"); if (!isTRUE(all.equal(as.data.frame(e2), as.data.frame(rt(REG, "EndUseRatios")), check.attributes = FALSE))) stop("end-use ratios differ in template ", r) }
w(eur_out[Ratio > 0 | EndUse == "fuelwood and other"], "end-use-ratios.csv")

# ---- end-use half-lives (HWP-C vR: Smith 2006 Table D3) ----------------------------------------------------------------------
hl <- rt(REG, "EU_HalfLives"); setnames(hl, c("EU", "HalfLife")); hl <- unique(merge(hl, rc[TP <= 4, .(EU, EndUse)], by = "EU")[, .(EndUse, HalfLife)])
if (anyDuplicated(hl$EndUse)) stop("an end use with two half-lives")
hl[, Basis := fcase(EndUse == "fuelwood and other", "burned in the year produced, with energy capture", EndUse == "wood pulp", "paper (Smith 2006 Table D3: 2.6 years)",
                    default = "Smith 2006 Table D3")]
w(hl[order(-HalfLife)], "end-use-half-lives.csv")

# ---- discards: fates by year (Skog 2008 Tables 6a, 6b, as HWP-C vR holds them), landfill and dump decay (Skog 2008 Table 7) ----
df <- rt(REG, "DiscardFates"); setnames(df, 1:2, c("Material", "Fate"))
df <- melt(df, id.vars = c("Material", "Fate"), variable.name = "Year", value.name = "Fraction", variable.factor = FALSE)[, Year := as.integer(as.numeric(Year))]
df[, Fate := fcase(Fate == "DEC", "Burned with energy capture", Fate == "BWoEC", "Burned without energy capture", default = Fate)]
s <- df[, .(s = sum(Fraction)), by = .(Material, Year)]; if (any(abs(s$s - 1) > 0.011)) stop("discard fates do not sum to 1: ", paste(s[abs(s - 1) > 0.011, sprintf("%s %d %.2f", Material, Year, s)], collapse = "; "))
w(df[order(Material, Fate, Year)], "discard-fates.csv")
dh <- rt(REG, "Discard_HalfLives"); setnames(dh, c("Material", "DumpHalfLife", "LandfillFixedFraction", "LandfillHalfLife", "RecoveredHalfLife"))
w(dh, "swds.csv")

# ---- settings and uncertainty -------------------------------------------------------------------------------------------------
op <- rt(REG, "HWP_MODEL_OPTIONS")
# LandClearingUtilized: the share of the wood removed by land clearing (urbanization, agricultural expansion) that becomes roundwood.
# No USFS source gives it: TPO reports only the unutilized part ("other removals", growing stock removed by cultural operations or
# timberland clearing, Oswalt et al. 2019 Table 40) and counts the utilized part in roundwood products without saying where it came
# from. lucasCore's assumption is half, with a wide range (uncertainty.csv); the rest is emitted in the year cleared.
w(data.table(Setting = c("LossInUseWood", "LossInUsePaper", "Draws", "Interval", "LandClearingUtilized"),
             Value = c(op$PIU.WOOD.LOSS, op$PIU.PAPER.LOSS, op$N.ITER, op$MC.CI.REPORT, 0.5),
             Note = c("share of solid wood lost when placed in use, discarded that year (Stockmann et al. 2012)", "the same for paper (none)",
                      "parameter draws per run iteration (HWP-C vR default)", "the interval reported (90%)",
                      "share of land-clearing wood that becomes roundwood (lucasCore assumption: no published value; the rest is emitted when cleared)")), "settings.csv")
mc <- rt(REG, "MonteCarloValues"); setnames(mc, c("ParameterId", "Parameter", "Paper", "FirstYear", "LastYear", "Min", "Mode", "Max", "Interval"))
mc[, Material := fcase(Paper == 1, "paper", Paper == 0, "wood", default = "")][, Paper := NULL]
w(rbind(mc[, .(Parameter, Material, FirstYear, LastYear, Min = round(Min, 4), Mode, Max = round(Max, 4), Interval,
               Note = "triangular multiplier on the parameter, Min and Max the 90% bounds (Stockmann et al. 2012 Table 9)")],
        data.table(Parameter = "LandClearingUtilized", Material = "", FirstYear = NA, LastYear = NA, Min = 0.2, Mode = 1, Max = 1.8, Interval = 0.9,
                   Note = "lucasCore: a wide triangular multiplier on the assumed share (0.1 to 0.9 at the 90% bounds), as no source gives it")), "uncertainty.csv")

# ---- harvest histories where the HWP-C state inventories have them (thousand board feet, Scribner; board feet per cubic foot) ---
hist <- rbindlist(lapply(list(c("California", "CA_Inputs_HWP_Model.xlsx", "Loeffler et al. 2019"), c("Oregon", "Oregon_Inputs_HWP_Model.xlsx", "Morgan et al. 2021"),
                              c("Washington", "WA_Inputs_HWP_Model.xlsx", "Nichols et al. 2020")), function(s) {
  f <- file.path(hwpc, "HWP Data", "ExistingData", s[2]); h <- as.data.table(suppressMessages(read_excel(f, "Harvest_MBF"))); b <- as.data.table(suppressMessages(read_excel(f, "BFCF")))
  h <- h[!is.na(Total), .(State = s[1], Year = as.integer(Year), HarvestMBF = round(Total))]
  h[, BoardFeetPerCubicFoot := vapply(Year, function(y) { k <- b[StartYear <= y & EndYear >= y, Conversion]; if (length(k)) k[1] else b$Conversion[if (y < min(b$StartYear)) 1 else nrow(b)] }, 0)]
  h[, Source := sprintf("%s, via HWP-C vR (%s)", s[3], commit)] }))
w(hist, "state-harvest-history.csv")

# ---- the 1906-on harvest history of each Smith region, for the stage's spin-up (to-do 59) ------------------------------------
# Only its shape matters: the stage scales a region's series to the run's own removals over the run's first decade. So each region
# takes the nearest published series, in million cubic feet of growing-stock removals (the quantity ST-Sim's harvest flow is):
#   1952-1997  Haynes 2003 Table 16 removals of the RPA region (North, South, Rocky Mountains, Pacific Coast) by wood type, times the
#              subregion's share of the region's harvest in Haynes Table 13 (Northeast, North Central, Southeast, South Central,
#              North and South Rocky Mountains, PNW West and East, Pacific Southwest; hardwood West as one), linear between the years
#   1906-1951  the 1956 Historical Forestry Statistics Table 15 lumber production of the Census region nearest the Smith region,
#              spliced to the 1952 removals (its 1950-54 mean = the 1952 value), split by wood type as in 1952; 1948 (total only)
#              linear between 1947 and 1949
#   1998-2016  outside the Pacific: the 1997 value times the change of the FRUS 2017 (Oswalt et al. 2019) Table 35 subregion from
#              1996 to 2006 and 2016, linear between (Rocky Mountain total, as Haynes's Rocky Mountains include the Great Plains)
#   Pacific    the state harvest histories above (California for PSW, Oregon plus Washington for PNW West and East, split as Table 13
#              splits them), 1906-2019, in cubic feet, split by wood type as Haynes Table 16 splits the Pacific Coast
# The transcribed tables are in transcribed/ (README.md says how each was checked). Before 1952 lumber stands for all products
# (pulpwood was a smaller share then), and the Rocky Mountains of Table 16 include the Great Plains; both only bend the shape.
tr <- function(f) fread(file.path(out, "transcribed", f), header = TRUE)
rem <- melt(tr("rpa-removals-by-region-1952-1997.csv"), id.vars = c("Region", "Wood"), variable.name = "Year", value.name = "Removals", variable.factor = FALSE)[, Year := as.integer(Year)]
hv <- melt(tr("rpa-harvest-by-subregion-1952-1996.csv"), id.vars = c("Subregion", "Wood"), variable.name = "Year", value.name = "Harvest", variable.factor = FALSE)[, Year := as.integer(Year)]
hv[Year == 1996L, Year := 1997L]   # Table 13's last year beside Table 16's
lum <- tr("lumber-by-census-region-1905-1954.csv"); lum[, (names(lum)[2:10]) := lapply(.SD, as.numeric), .SDcols = 2:10]
px <- data.table(Region = regions$Region,
  RpaRegion = c("North", "North", "North", "South", "South", "Rocky Mountains", "Rocky Mountains", "Pacific Coast", "Pacific Coast", "Pacific Coast"),
  SubregionSW = c("Northeast", "North Central", "North Central", "Southeast", "South Central", "North Rocky Mountains", "South Rocky Mountains",
                  "Pacific Southwest", "Pacific Northwest East", "Pacific Northwest West"),
  SubregionHW = c("Northeast", "North Central", "North Central", "Southeast", "South Central", "West", "West", "West", "West", "West"),
  Lumber = c("NewEngland+MiddleAtlantic", "Lake", "Central", "SouthAtlantic", "South", "RockyMountain", "RockyMountain", "", "", ""),
  States = c("", "", "", "", "", "", "", "California", "Oregon+Washington", "Oregon+Washington"),
  Frus = c("Northeast", "North Central", "North Central", "Southeast", "South Central", "Rocky Mountain total", "Rocky Mountain total", "", "", ""))
frus <- tr("frus2017-removals-by-subregion-1976-2016.csv")   # thousand cubic feet
sub_of <- list(North = c("Northeast", "North Central"), South = c("Southeast", "South Central"), `Rocky Mountains` = c("North Rocky Mountains", "South Rocky Mountains"),
               `Pacific Coast` = c("Pacific Northwest West", "Pacific Northwest East", "Pacific Southwest"))
YRS <- sort(unique(rem$Year)); interp <- function(x, y, at) approx(x, y, at, rule = 2)$y
share <- function(p, wd) {   # the subregion's share of its RPA region's harvest in each Table 13 year (hardwood West: the whole region)
  s <- if (wd == "SW") p$SubregionSW else p$SubregionHW; if (s == "West") return(rep(1, length(YRS)))
  vapply(YRS, function(y) hv[Wood == wd & Year == y & Subregion == s, Harvest] / hv[Wood == wd & Year == y & Subregion %in% sub_of[[p$RpaRegion]], sum(Harvest)], 0) }
lum[Year == 1948L, (names(lum)[3:10]) := lapply(names(lum)[3:10], function(k) interp(lum[Year %in% c(1947L, 1949L), Year], lum[Year %in% c(1947L, 1949L), get(k)], 1948))]
lum[, `NewEngland+MiddleAtlantic` := NewEngland + fifelse(is.na(MiddleAtlantic), 0, MiddleAtlantic)]
hist_c <- hist[, .(Year, State, Mcf = HarvestMBF * 1000 / BoardFeetPerCubicFoot / 1e6)]
LASTP <- hist_c[, max(Year), by = State][, min(V1)]
reg_hist <- rbindlist(lapply(seq_len(nrow(px)), function(i) { p <- px[i]
  survey <- rbindlist(lapply(c("SW", "HW"), function(wd) data.table(Wood = wd, Year = YRS, Removals = rem[Region == p$RpaRegion & Wood == wd][order(Year), Removals] * share(p, wd))))
  if (nzchar(p$States)) {   # Pacific: the state series, split by subregion share and wood type
    st <- strsplit(p$States, "+", fixed = TRUE)[[1]]; y <- 1906:LASTP; tot <- hist_c[State %in% st & Year %in% y, .(Mcf = sum(Mcf)), by = Year][order(Year)]
    if (nrow(tot) != length(y)) stop("state history has gaps for ", p$Region)
    sh <- if (length(st) > 1) interp(YRS, share(p, "SW"), y) else rep(1, length(y))
    pc <- rem[Region == "Pacific Coast"]; hw <- interp(YRS, pc[Wood == "HW"][order(Year), Removals] / (pc[Wood == "HW"][order(Year), Removals] + pc[Wood == "SW"][order(Year), Removals]), y)
    return(rbind(data.table(Region = p$Region, Wood = "SW", Year = y, Removals = tot$Mcf * sh * (1 - hw), Basis = sprintf("%s harvest (state inventory)%s", p$States, if (length(st) > 1) " x Haynes 2003 Table 13 subregion share" else "")),
                 data.table(Region = p$Region, Wood = "HW", Year = y, Removals = tot$Mcf * sh * hw, Basis = sprintf("%s harvest (state inventory), hardwood share of Haynes 2003 Table 16 Pacific Coast", p$States)))) }
  # after 1997: the 1997 value times the FRUS 2017 Table 35 subregion's change from 1996, at 2006 and 2016, linear between
  f35 <- function(wd, y) frus[Subregion == p$Frus & Wood == wd, get(as.character(y))] / frus[Subregion == p$Frus & Wood == wd, `1996`]
  ext <- rbindlist(lapply(c("SW", "HW"), function(wd) data.table(Wood = wd, Year = c(2006L, 2016L), Removals = survey[Wood == wd & Year == max(YRS), Removals] * c(f35(wd, 2006), f35(wd, 2016)))))
  sv <- rbind(survey, ext)[order(Wood, Year)]; y2 <- 1952:2016
  after <- rbindlist(lapply(c("SW", "HW"), function(wd) data.table(Region = p$Region, Wood = wd, Year = y2, Removals = interp(sv[Wood == wd, Year], sv[Wood == wd, Removals], y2),
                 Basis = fifelse(y2 <= max(YRS), sprintf("Haynes 2003 Table 16 %s removals x Table 13 %s share", p$RpaRegion, if (wd == "SW") p$SubregionSW else p$SubregionHW),
                                 sprintf("the 1997 value x FRUS 2017 Table 35 %s change from 1996", p$Frus)))))
  L <- lum[, .(Year, L = get(p$Lumber))]; k <- survey[Year == 1952L, sum(Removals)] / L[Year %in% 1950:1954, mean(L)]; f_hw <- survey[Year == 1952L & Wood == "HW", Removals] / survey[Year == 1952L, sum(Removals)]
  y1 <- 1906:1951; before <- rbind(data.table(Region = p$Region, Wood = "SW", Year = y1, Removals = L[match(y1, Year), L] * k * (1 - f_hw)),
                                   data.table(Region = p$Region, Wood = "HW", Year = y1, Removals = L[match(y1, Year), L] * k * f_hw))[
    , Basis := sprintf("1956 Historical Forestry Statistics Table 15 lumber, %s, spliced to the 1952 removals", p$Lumber)]
  rbind(before, after) }))
if (reg_hist[, anyNA(Removals) || any(Removals < 0)]) stop("regional harvest history has missing or negative values")
w(reg_hist[, Removals := round(Removals, 2)][order(Region, Wood, Year)], "regional-harvest-history.csv")
# the shape check: where a state series and Haynes overlap (California and PSW, Oregon plus Washington and PNW), they should move together
for (r in c("PSW", "PWW")) { a <- reg_hist[Region == r & Year %in% YRS, .(v = sum(Removals)), by = Year]
  p <- px[Region == r]; b <- vapply(YRS, function(y) sum(rem[Region == p$RpaRegion & Year == y, Removals] * c(SW = share(p, "SW")[match(y, YRS)], HW = 1)[rem[Region == p$RpaRegion & Year == y, Wood]]), 0)
  cat(sprintf("%s: state series vs Haynes in the survey years, correlation %.2f, ratio %s\n", r, cor(a$v, b), paste(sprintf("%.2f", a$v / b), collapse = " "))) }
# FRUS 2017 and Haynes should agree where both give a year (1976, and 1996 against Haynes's 1997): their ratio by subregion
for (r in c("Northeast", "North Central", "Southeast", "South Central")) for (wd in c("SW", "HW")) {
  reg <- names(sub_of)[vapply(sub_of, function(v) r %in% v, TRUE)]
  hr <- vapply(c(1976L, 1997L), function(y) rem[Region == reg & Wood == wd & Year == y, Removals] * hv[Subregion == r & Wood == wd & Year == y, Harvest] /
                                            hv[Subregion %in% sub_of[[reg]] & Wood == wd & Year == y, sum(Harvest)], 0)
  fr <- unlist(frus[Subregion == r & Wood == wd, .(`1976`, `1996`)]) / 1000
  cat(sprintf("FRUS 2017 / Haynes, %s %s: 1976 %.2f, 1996/97 %.2f\n", r, wd, fr[1] / hr[1], fr[2] / hr[2])) }
cat("HWP-C vR commit", commit, "\n")
