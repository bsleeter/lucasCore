# =============================================================================
# 04-cac-county-check.R - check a run's cropland growth and harvest against the California County Agricultural Commissioners'
# reports (to-do 39 step 6)
# =============================================================================
# The commissioners' reports (USDA NASS Pacific Region, AgComm, one CSV per year: YYYY08cactb00.csv) list every crop a county grows,
# orchards, vines and vegetables included, with harvested acres and production (short tons, fresh weight). Each crop is matched to a
# row of 04-cac-crop-factors.csv (first matching pattern) and
#   harvest (Mg C) = production x 0.907185 x dry matter x 0.45
#   NPP (Mg C)     = harvest / harvest index x (1 + root:shoot)     (fruit, nuts, vines: harvest index = fruit share of ANPP)
# A county row with acres but no production takes the state yield; a county yield over 3x the state's is taken as a units error
# (Solano barley 1990) and replaced by the state yield. Pasture, nursery, livestock and unspecified rows are left out.
# Area is harvested acres: a double-cropped field counts twice.
# Inputs: CAC (folder of the yearly CSVs named YYYY.csv), LIB (library), RESULT (result scenario id), COUNTY (name), YEARS (a:b).
# Writes dev/agriculture/04-cac-county-check.csv (year: model and commissioners' area, NPP, harvest).
# Usage: CAC=<folder> LIB=<ssim> RESULT=87 COUNTY=Solano YEARS=1986:1995 Rscript dev/agriculture/04-cac-county-check.R
# =============================================================================
suppressPackageStartupMessages({ library(DBI); library(data.table) })
CAC <- Sys.getenv("CAC"); LIB <- Sys.getenv("LIB"); RES <- as.integer(Sys.getenv("RESULT")); CO <- Sys.getenv("COUNTY", "Solano")
YRS <- eval(parse(text = Sys.getenv("YEARS", "1986:1995")))
rd <- function(y) { x <- fread(file.path(CAC, sprintf("%d.csv", y)), colClasses = "character", strip.white = TRUE)
  setnames(x, c("Year","Code","Crop","CountyCode","County","Acres","Yield","Prod","Price","Unit","Value")); x }
x <- rbindlist(lapply(YRS, rd)); for (v in c("Year","Acres","Yield","Prod")) set(x, j = v, value = suppressWarnings(as.numeric(gsub("[^0-9.]", "", x[[v]]))))
so <- x[County == "State Totals" & Yield > 0, .(Year, Code, SY = Yield)][x[County == CO], on = .(Year, Code)]
fa <- fread("dev/agriculture/04-cac-crop-factors.csv"); so[, k := NA_integer_]
for (i in seq_len(nrow(fa))) so[is.na(k) & grepl(fa$Pattern[i], Crop), k := i]
so <- cbind(so, fa[so$k, .(Group, DM, HI, RS)]); so[!is.na(Prod) & Prod > 0, how := "reported"]
so[how == "reported" & !is.na(SY) & Acres > 0 & Prod / Acres > 3 * SY, `:=`(Prod = Acres * SY, how = "state yield (county > 3x)")]
so[is.na(how) & !is.na(Group) & Acres > 0 & !is.na(SY), `:=`(Prod = Acres * SY, how = "state yield (none reported)")]
so[, hC := Prod * 0.907185 * DM * 0.45]; so[, nppC := fifelse(HI > 0, hC / HI * (1 + RS), 0)]
cat("Fixed rows:\n"); print(so[how != "reported", .(Year, Crop, Acres, how)])
cat("Left out (mean acres):\n"); print(so[is.na(hC) & Acres > 0, .(acres = round(sum(Acres) / length(YRS))), by = Crop][order(-acres)])
g <- so[!is.na(hC), .(kha = sum(Acres * 0.404686 * !Group %in% c("Nut hulls","Straw"), na.rm = TRUE) / length(YRS) / 1e3,
  harv = sum(hC) / length(YRS) / 1e3, npp = sum(nppC) / length(YRS) / 1e3), by = Group][order(-npp)]
cat("By group (thousand ha, thousand Mg C/yr):\n"); print(g[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 1) else v)])
yr <- so[!is.na(hC), .(cacHa = sum(Acres * 0.404686 * !Group %in% c("Nut hulls","Straw"), na.rm = TRUE), cacNpp = sum(nppC), cacHarv = sum(hC)), by = Year]
con <- dbConnect(RSQLite::SQLite(), LIB, flags = RSQLite::SQLITE_RO)
q <- function(s) as.data.table(dbGetQuery(con, s))
f <- q(sprintf("select o.Timestep Year, g.Name grp, sum(o.Amount) amt from stsim_OutputFlow o join stsim_StateClass c on c.StateClassId = o.FromStateClassId join stsim_FlowGroup g on g.FlowGroupId = o.FlowGroupId where o.ScenarioId = %d and c.Name = 'Agriculture: Cropland' and g.Name in ('Net Growth Agriculture: Total','Harvest: Agriculture') group by 1,2", RES))
a <- q(sprintf("select o.Timestep Year, sum(o.Amount) modelHa from stsim_OutputStratumState o join stsim_StateClass c on c.StateClassId = o.StateClassId where o.ScenarioId = %d and c.Name = 'Agriculture: Cropland' group by 1", RES))
dbDisconnect(con)
m <- dcast(f, Year ~ grp, value.var = "amt"); setnames(m, c("Year", "modelHarv", "modelNpp")); r <- a[m, on = "Year"][yr, on = "Year", nomatch = 0]
fwrite(r, "dev/agriculture/04-cac-county-check.csv"); mn <- r[, lapply(.SD, mean)]
cat(sprintf("%s %d-%d means: area model %.0f ha, reports %.0f harvested ha\n  NPP  model %.0f, reports %.0f Mg C/yr (%.2f vs %.2f per ha)\n  harvest model %.0f, reports %.0f Mg C/yr (%.2f vs %.2f per ha)\n  yearly correlation NPP %.2f, harvest %.2f\n",
  CO, min(YRS), max(YRS), mn$modelHa, mn$cacHa, mn$modelNpp, mn$cacNpp, mn$modelNpp / mn$modelHa, mn$cacNpp / mn$cacHa, mn$modelHarv, mn$cacHarv,
  mn$modelHarv / mn$modelHa, mn$cacHarv / mn$cacHa, r[, cor(modelNpp, cacNpp)], r[, cor(modelHarv, cacHarv)]))
