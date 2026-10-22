# =============================================================================
# export-carbon-summary.R - carbon budget tables and bookend stock maps from a historical ST-Sim result, for charts and reports
# =============================================================================
# Writes to <out>:
#   carbon-fluxes.csv  Year, NPP, Rh, NEP, FireEmissions, Harvest, NECB (Tg C/yr) and the same per area (g C/m2/yr, *_gm2); NECB is the
#                      model's Net Biome Productivity flow group, which equals the yearly change in Total Ecosystem carbon (checked)
#   carbon-stocks.csv  Year, Live, DOM, Soil, Total (Tg C): stock groups Biomass: Total, DOM: No Soil, DOM: Soil, Total Ecosystem
#   carbon-map.csv     the Total Ecosystem map (Mg C/ha) in the first and last year and mean annual NECB (g C/m2/yr, the stock change
#                      over the years), block-averaged by --aggregate to keep the file small: Col, Row, Stock<y0>, Stock<y1>, NECB
#   carbon-map-grid.json  the map grid: columns, rows, cell size (m), origin, CRS, years
# Usage: Rscript tools/export-carbon-summary.R <library.ssim> <result scenario id> <out folder> [--aggregate=5]
# The run needs Total Ecosystem stock maps in its first and last year (tools/new-historical.R --bookend-maps makes them).
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (length(pos) < 3) stop("usage: Rscript tools/export-carbon-summary.R <library.ssim> <result id> <out folder> [--aggregate=5]")
f <- normalizePath(pos[1], winslash = "/"); rid <- as.integer(pos[2]); out <- pos[3]; dir.create(out, showWarnings = FALSE, recursive = TRUE)
fact <- as.integer(opt("aggregate", 5))
L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions"); R <- scenario(L, rid)
ds <- function(s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
nit <- function(x) max(x$Iteration)

ip <- ds("stsim_InitialConditionsSpatialProperties"); land_ha <- NA
st <- ds("stsim_OutputStock"); fl <- ds("stsim_OutputFlow")
sg <- c(Live = "Biomass: Total", DOM = "DOM: No Soil", Soil = "DOM: Soil", Total = "Total Ecosystem")
stk <- dcast(st[StockGroupId %in% sg, .(Tg = sum(Amount) / nit(st) / 1e6), by = .(Year = Timestep, StockGroupId)], Year ~ StockGroupId, value.var = "Tg")
setnames(stk, sg, names(sg)); setcolorder(stk, c("Year", names(sg)))
fg <- c(NPP = "Net Primary Productivity", Rh = "Emission: Total Rh", NEP = "Net Ecosystem Productivity", FireEmissions = "LULC: Emission",
        Harvest = "LULC: Harvest", NECB = "Net Biome Productivity")
flx <- dcast(fl[FlowGroupId %in% fg, .(Tg = sum(Amount) / nit(fl) / 1e6), by = .(Year = Timestep, FlowGroupId)], Year ~ FlowGroupId, value.var = "Tg", fill = 0)
setnames(flx, fg, names(fg)); setcolorder(flx, c("Year", names(fg)))
# NECB must close the budget: the change in Total Ecosystem carbon from the year before
chk <- merge(flx[, .(Year, NECB)], stk[order(Year), .(Year, dS = Total - data.table::shift(Total))], by = "Year")
gap <- chk[, max(abs(NECB - dS), na.rm = TRUE)]; cat(sprintf("NECB vs stock change: max difference %.2e Tg C\n", gap)); if (gap > 1e-3) stop("NECB does not close the carbon budget")

# the stock maps (Mg C/ha); per-area fluxes use the mapped area (cells with a Total Ecosystem value)
dir_s <- file.path(paste0(f, ".data"), sprintf("Scenario-%d", rid), "stsim_OutputAverageSpatialStockGroup")
ids <- as.data.table(datasheet(P, "stsim_StockGroup", includeKey = TRUE)); tid <- ids[Name == "Total Ecosystem", StockGroupId]
yrs <- range(stk$Year); fs <- file.path(dir_s, sprintf("avgstkg_%d.it0.ts%d.tif", tid, yrs))
if (!all(file.exists(fs))) stop("no Total Ecosystem maps for ", paste(yrs, collapse = " and "), ": make the run with tools/new-historical.R --bookend-maps")
s0 <- rast(fs[1]); s1 <- rast(fs[2]); cell_ha <- prod(res(s0)) / 1e4
area_m2 <- global(!is.na(s0), "sum", na.rm = TRUE)[[1]] * cell_ha * 1e4
cat(sprintf("map: %d x %d cells of %g m, %.0f km2 mapped; check: %.3f Tg in the %d map vs %.3f Tg in the table\n", ncol(s0), nrow(s0), res(s0)[1], area_m2 / 1e6,
            global(s0, "sum", na.rm = TRUE)[[1]] * cell_ha / 1e6, yrs[1], stk[Year == yrs[1], Total]))
for (k in names(fg)) flx[, (paste0(k, "_gm2")) := round(get(k) * 1e12 / area_m2, 1)]
fwrite(flx[, lapply(.SD, function(v) if (is.double(v)) round(v, 4) else v)], file.path(out, "carbon-fluxes.csv"))
fwrite(stk[, lapply(.SD, function(v) if (is.double(v)) round(v, 3) else v)], file.path(out, "carbon-stocks.csv"))

necb <- (s1 - s0) / diff(yrs) * 100   # Mg C/ha/yr -> g C/m2/yr
m <- c(s0, s1, necb); if (fact > 1) m <- aggregate(m, fact, mean, na.rm = TRUE)
v <- as.data.table(cbind(rowColFromCell(m, seq_len(ncell(m))), values(m)))
setnames(v, c("Row", "Col", paste0("Stock", yrs[1]), paste0("Stock", yrs[2]), "NECB")); v <- v[!is.na(get(paste0("Stock", yrs[1])))]
v[, (3:4) := lapply(.SD, round, 1), .SDcols = 3:4][, NECB := round(NECB, 1)]
fwrite(v[, c("Col", "Row", paste0("Stock", yrs), "NECB"), with = FALSE], file.path(out, "carbon-map.csv"))
jsonlite::write_json(list(columns = ncol(m), rows = nrow(m), cellSize = res(m)[1], xmin = xmin(m), ymax = ymax(m), crs = "EPSG:5070",
                          firstYear = yrs[1], lastYear = yrs[2], modelCellSize = res(s0)[1]), file.path(out, "carbon-map-grid.json"), auto_unbox = TRUE)
cat(sprintf("wrote %s: %d flux years, %d map cells (%g m display cells)\n", out, nrow(flx), nrow(v), res(m)[1]))
print(flx[, .(Year, NPP, Rh, NEP, NECB)][c(1, .N)])
