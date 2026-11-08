# =============================================================================
# 05-cac-county-crop-npp.R - California county growth of the crops NASS's county survey leaves out (tomatoes, other vegetables, tree
# fruit, tree nuts, grapes), from the County Agricultural Commissioners' reports (to-do 39 step 6; user 2026-11-08)
# =============================================================================
# The reports (USDA NASS Pacific Region, AgComm: one CSV a year, YYYY08cactb00.csv and later names; saved as CAC/YYYY.csv) list every
# crop of every county with harvested acres and production (short tons, fresh weight; dried plums and figs dried). Each row matched
# to dev/agriculture/04-cac-crop-factors.csv (first pattern) gives
#   harvest (Mg C) = production x 0.907185 x dry matter x 0.45;   AG = harvest / harvest index;   NPP = AG x (1 + root:shoot)
# (fruit, nuts, grapes: the harvest index is the fruit's share of aboveground growth; a tree's wood increment is not counted: the
# model grows cropland as one herbaceous class). Almond hulls add to Tree nuts' harvest only. A county row with acres and no
# production takes the state yield; a county yield over 3x the state's is a units slip and takes the state yield.
# By county and Cropland Data Layer group (defaults/stockflow/cdl-crops.csv): NPP, AG and harvest per harvested ha over every year,
# weighted by acres. No fallback: outside California, or in a county without the group, the CDL classes stay left out (stage 8
# fills them from nearby cropland).
# Input: CAC (folder of the yearly CSVs; formats of 1986-2020 read, 2021 on differ). Writes dev/agriculture/05-cac-county-crop-npp.csv;
# tools/make_agriculture.R copies it to defaults/stockflow/ag-cac-county-crop-npp.csv.
# Usage: CAC=<folder> Rscript dev/agriculture/05-cac-county-crop-npp.R
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages(library(data.table)); options(width = 200)
CAC <- Sys.getenv("CAC"); YRS <- 1986:2020; if (!dir.exists(CAC)) stop("set CAC")
GROUP <- c(Tomatoes = "^TOMATOES", `Tree nuts` = "^Nuts$|^Nut hulls$", Grapes = "^Vine$", `Tree fruit` = "^Fruit", Vegetables = "^Vegetable$")
rd <- function(y) { f <- file.path(CAC, sprintf("%d.csv", y)); if (!file.exists(f)) return(NULL)
  x <- fread(f, colClasses = "character", strip.white = TRUE)[, 1:11]
  setnames(x, c("Year","Code","Crop","CountyCode","County","Acres","Yield","Prod","Price","Unit","Value")); x }
x <- rbindlist(lapply(YRS, rd)); for (v in c("Year","Acres","Yield","Prod","CountyCode")) set(x, j = v, value = suppressWarnings(as.numeric(gsub("[^0-9.]", "", x[[v]]))))
x[, Crop := toupper(trimws(Crop))]; cat(sprintf("%d rows, years %s\n", nrow(x), paste(range(x$Year, na.rm = TRUE), collapse = "-")))
so <- x[County == "State Totals" & Yield > 0, .(Year, Code, SY = Yield)][x[County != "State Totals" & !is.na(CountyCode) & CountyCode < 999], on = .(Year, Code)]
fa <- fread(file.path(pkg, "dev/agriculture/04-cac-crop-factors.csv")); so[, k := NA_integer_]
for (i in seq_len(nrow(fa))) so[is.na(k) & grepl(fa$Pattern[i], Crop), k := i]
so <- cbind(so, fa[so$k, .(Group, DM, HI, RS)])
so[, cdl := NA_character_]; so[grepl("^TOMATOES", Crop), cdl := "Tomatoes"]
for (g in names(GROUP)[-1]) so[is.na(cdl) & !is.na(Group) & grepl(GROUP[[g]], Group), cdl := g]
so <- so[!is.na(cdl)]
so[!is.na(Prod) & Prod > 0, how := "reported"]
so[how == "reported" & !is.na(SY) & Acres > 0 & Prod / Acres > 3 * SY, `:=`(Prod = Acres * SY, how = "state")]
so[is.na(how) & Acres > 0 & !is.na(SY), `:=`(Prod = Acres * SY, how = "state")]
so <- so[!is.na(Prod) & Prod > 0]
so[, hC := Prod * 0.907185 * DM * 0.45]; so[, agC := fifelse(HI > 0, hC / HI, 0)]; so[, nppC := agC * (1 + RS)]
so[, ha := fifelse(Group == "Nut hulls", 0, fcoalesce(Acres, 0) * 0.40468564)]
cat(sprintf("rows used %d (%.1f%% at the state yield)\n", nrow(so), 100 * so[, mean(how == "state")]))
out <- so[, .(ha = sum(ha), npp = sum(nppC), ag = sum(agC), harv = sum(hC), Years = uniqueN(Year)), by = .(GEOID = sprintf("06%03d", as.integer(CountyCode)), Group = cdl)][ha > 0]
out <- out[, .(GEOID, StateClassId = "Agriculture: Cropland", Group, NPP = round(npp / ha, 4), AG = round(ag / ha, 4), Harvest = round(harv / ha, 4), Years, MeanHa = round(ha / Years))]
setorder(out, GEOID, Group); fwrite(out, file.path(pkg, "dev/agriculture/05-cac-county-crop-npp.csv"))
print(out[, .(counties = .N, NPP_median = round(median(NPP), 2), NPP_weighted = round(weighted.mean(NPP, MeanHa), 2), harvShareOfAG = round(sum(Harvest * MeanHa) / sum(AG * MeanHa), 2), kha = round(sum(MeanHa) / 1e3)), by = Group])
cat("wrote dev/agriculture/05-cac-county-crop-npp.csv\n")
