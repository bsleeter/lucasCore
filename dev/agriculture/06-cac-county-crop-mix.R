# =============================================================================
# 06-cac-county-crop-mix.R - each California county's yearly crop mix from the County Agricultural Commissioners' reports, for the
# Crop Mix multiplier (to-do 39 step 6; user 2026-11-08: vary the crop mix through time)
# =============================================================================
# The Cropland Productivity and Crop Harvest maps hold the crops of the Cropland Data Layer years (2014 on). Before that a county
# grew other crops and left less land fallow (Solano 1986-1995: more sugar beets, corn and tomatoes, fewer orchards; 79 thousand
# harvested ha against 52 thousand in 2014-2020), so the maps alone run its 1986-1995 growth about 30% low.
# Every crop of every county and year (matched to dev/agriculture/04-cac-crop-factors.csv, as 05-cac-county-crop-npp.R) is valued at
# a fixed rate: the crop's mean NPP, aboveground growth and harvest per harvested ha in that county over every year. The yearly sums
#   NPP, AG, Harvest (Mg C) = sum over crops of harvested ha x the crop's fixed rate
# change only with the crop mix and the harvested area, not with yields (the yearly Crop Yield index carries those). Almond hulls and
# straw add their reported harvest. Stage 8 divides NPP by the county's cropland area on the model's annual NLCD that year and by the
# same over the CDL years, which gives the Crop Mix growth multiplier; harvest / AG over its CDL-years value gives the harvest one.
# Input: CAC (folder of the yearly CSVs, 1986-2020; 2021 on use another format). Writes dev/agriculture/06-cac-county-crop-mix.csv;
# tools/make_agriculture.R copies it to defaults/stockflow/ag-cac-county-crop-mix.csv.
# Usage: CAC=<folder> Rscript dev/agriculture/06-cac-county-crop-mix.R
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), winslash = "/")
suppressPackageStartupMessages(library(data.table)); options(width = 200)
CAC <- Sys.getenv("CAC"); YRS <- 1986:2020; if (!dir.exists(CAC)) stop("set CAC")
rd <- function(y) { f <- file.path(CAC, sprintf("%d.csv", y)); if (!file.exists(f)) return(NULL)
  x <- fread(f, colClasses = "character", strip.white = TRUE)[, 1:11]
  setnames(x, c("Year","Code","Crop","CountyCode","County","Acres","Yield","Prod","Price","Unit","Value")); x }
x <- rbindlist(lapply(YRS, rd)); for (v in c("Year","Acres","Yield","Prod","CountyCode")) set(x, j = v, value = suppressWarnings(as.numeric(gsub("[^0-9.]", "", x[[v]]))))
x[, Crop := toupper(trimws(Crop))]
so <- x[County == "State Totals" & Yield > 0, .(Year, Code, SY = Yield)][x[County != "State Totals" & !is.na(CountyCode) & CountyCode < 999], on = .(Year, Code)]
fa <- fread(file.path(pkg, "dev/agriculture/04-cac-crop-factors.csv")); so[, k := NA_integer_]
for (i in seq_len(nrow(fa))) so[is.na(k) & grepl(fa$Pattern[i], Crop), k := i]
so <- cbind(so, fa[so$k, .(Group, DM, HI, RS)])[!is.na(Group)]
so[!is.na(Prod) & Prod > 0, how := "reported"]
so[how == "reported" & !is.na(SY) & Acres > 0 & Prod / Acres > 3 * SY, `:=`(Prod = Acres * SY, how = "state")]
so[is.na(how) & Acres > 0 & !is.na(SY), `:=`(Prod = Acres * SY, how = "state")]
so <- so[!is.na(Prod) & Prod > 0]
so[, hC := Prod * 0.907185 * DM * 0.45]; so[, agC := fifelse(HI > 0, hC / HI, 0)]; so[, nppC := agC * (1 + RS)]
so[, ha := fifelse(Group %in% c("Nut hulls", "Straw"), 0, fcoalesce(Acres, 0) * 0.40468564)]
so[, GEOID := sprintf("06%03d", as.integer(CountyCode))]
# fixed rates: the crop's mean per harvested ha in the county over every year
rt <- so[ha > 0, .(rN = sum(nppC) / sum(ha), rA = sum(agC) / sum(ha), rH = sum(hC) / sum(ha)), by = .(GEOID, Crop)]
so <- rt[so, on = .(GEOID, Crop)]
out <- so[, .(HarvestedHa = round(sum(ha)), NPP = round(sum(ha * rN, na.rm = TRUE)), AG = round(sum(ha * rA, na.rm = TRUE)),
              Harvest = round(sum(ha * rH, na.rm = TRUE) + sum(hC[ha == 0]))), by = .(GEOID, Year)][NPP > 0]
out[Harvest > AG, Harvest := AG]   # hulls or straw with almost no crop counted (Inyo 2019, Mono)
setorder(out, GEOID, Year); fwrite(out, file.path(pkg, "dev/agriculture/06-cac-county-crop-mix.csv"))
b <- out[Year %in% 2014:2020, .(bN = mean(NPP), bS = sum(Harvest) / sum(AG)), by = GEOID]
s <- b[out, on = "GEOID"][, .(Growth8695 = round(mean(NPP[Year <= 1995]) / bN[1], 2), Harvest8695 = round(sum(Harvest[Year <= 1995]) / sum(AG[Year <= 1995]) / bS[1], 2)), by = GEOID]
cat(sprintf("%d counties, %d county-years; 1986-1995 over 2014-2020 (before dividing by cropland area): growth median %.2f (10%% %.2f, 90%% %.2f), harvested share median %.2f\n",
            uniqueN(out$GEOID), nrow(out), median(s$Growth8695, na.rm = TRUE), quantile(s$Growth8695, 0.1, na.rm = TRUE), quantile(s$Growth8695, 0.9, na.rm = TRUE), median(s$Harvest8695, na.rm = TRUE)))
print(s[GEOID == "06095"]); cat("wrote dev/agriculture/06-cac-county-crop-mix.csv\n")
