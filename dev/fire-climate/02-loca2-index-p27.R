# =============================================================================
# 02-loca2-index-p27.R - to-do 9: how far do LOCA2 futures move the fire-season indexes of one pyrome, in SDs of its own record?
# =============================================================================
# Fire-season (May-September) maximum temperature and precipitation, and the two together (Hot.Dry of 01-fire-climate-signal.R), of
# each LOCA2 run against the same run's 1984-2014 years (the delta method: a model's bias drops out), in SDs of the PRISM 1984-2023
# record of the pyrome. Then the burned-area multiplier exp(slope x shift) that 01's fitted slope gives, by period.
# Usage: Rscript dev/fire-climate/02-loca2-index-p27.R <01 out folder> [--pyrome=27] [--points=400]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra); library(sf) }); options(width = 200)
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
odir <- a[!grepl("^--", a)][1]; PY <- as.integer(opt("pyrome", 27)); NP <- as.integer(opt("points", 400))
source("src/loca2.R")
py <- st_read("E:/lucasData/study-area/pyromes/Pyromes_CONUS_20200206.shp", quiet = TRUE); py <- py[py$PYROME == PY, ]
set.seed(1); pts <- st_coordinates(st_transform(st_sample(st_transform(py, 5070), NP), 4326))
dt <- fread(file.path(odir, "pyrome-year.csv"))[PYROME == PY]; sc <- fread(file.path(odir, "pyrome-scores.csv"))[PYROME == PY]
pm <- dcast(readRDS(file.path(odir, "prism-pyrome.rds"))[PYROME == PY], y + m ~ v, value.var = "value")
FS <- 5:9; obs <- pm[m %in% FS & y >= 1984 & y <= 2023, .(Tmax = mean(tmax), P = sum(ppt)), by = y]; sdT <- sd(obs$Tmax); sdP <- sd(obs$P)
hd_sd <- sd(scale(obs$Tmax)[, 1] - scale(obs$P)[, 1])
runs <- CJ(gcm = list.dirs("E:/lucasData/climate/loca2", recursive = FALSE, full.names = FALSE), ssp = c("ssp245", "ssp370", "ssp585"))
out <- rbindlist(lapply(seq_len(nrow(runs)), function(i) { g <- runs$gcm[i]; s <- runs$ssp[i]
  r <- tryCatch(loca2_monthly_mean("E:/lucasData/climate/loca2", g, "r1i1p1f1", s, 1984:2100, pts), error = function(e) { message(g, " ", s, ": ", conditionMessage(e)); NULL }); if (is.null(r)) return(NULL)
  r <- as.data.table(r); f <- r[m %in% FS, .(Tmax = mean(TX), P = sum(P)), by = y]; b <- f[y <= 2014]
  f[, `:=`(zT = (Tmax - mean(b$Tmax)) / sdT, zP = -(P - mean(b$P)) / sdP)]; f[, zHD := (zT + zP) / hd_sd]
  per <- f[, .(period = cut(y, c(1983, 2014, 2040, 2070, 2100), labels = c("1984-2014", "2015-2040", "2041-2070", "2071-2100")), zT, zP, zHD)]
  per[, .(gcm = g, ssp = s, Tmax_sd = mean(zT), Precip_sd = mean(zP), HotDry_sd = mean(zHD), share_above_record = mean(zT > max(scale(obs$Tmax)[, 1]))), by = period] }))
k <- setNames(sc$slope, sc$index)
out[, `:=`(mult_Tmax = exp(k[["Tmax"]] * Tmax_sd), mult_HotDry = exp(k[["Hot.Dry"]] * HotDry_sd))]
cat(sprintf("Pyrome %d: PRISM May-September Tmax SD %.2f C, precipitation SD %.0f mm; fitted slopes Tmax %.2f, Hot.Dry %.2f (log burned area per SD)\n", PY, sdT, sdP, k[["Tmax"]], k[["Hot.Dry"]]))
print(out[order(gcm, ssp, period), lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])
fwrite(out, file.path(odir, sprintf("loca2-index-pyrome%d.csv", PY)))
