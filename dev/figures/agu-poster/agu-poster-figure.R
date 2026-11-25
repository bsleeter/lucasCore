# =============================================================================
# agu-poster-figure.R - the LUCAS panel figure for the AGU poster "USGS Western Geographic Science Center: A Leader in
# Interdisciplinary Federal Science" (2026-11-25). One landscape figure, 20 x 9.8 in, to sit in a 21 x 13 in panel with its text.
#   (a) what LUCAS reads and writes (a drawn schematic)
#   (b) land cover 2023, (c) year last burned, (d) change in ecosystem carbon 1985-2023 (maps on shaded relief)
#   (e) change in carbon stocks since 1985, (f) vegetation carbon burned, killed or cut by cause, (g) the stock against the carbon carrying capacity
# Reads a historical run in a lucasCore library (the library file and its data folder) and the elevation file its Build used.
#   Rscript dev/figures/agu-poster/agu-poster-figure.R [library.ssim] [run result id] [build result id] [out dir]
# Defaults: the Pyrome 27 (Southern Sierra Nevada) library, run 9, Build 4 (lucasCore 2.0, 300 m, one iteration).
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table); library(DBI) })
a <- commandArgs(TRUE)
LIB <- if (length(a) >= 1) a[1] else "F:/lucasCore/dev/libs/Pyrome 27.ssim"
RUN <- if (length(a) >= 2) as.integer(a[2]) else 9L
BUILD <- if (length(a) >= 3) as.integer(a[3]) else 4L
OUT <- if (length(a) >= 4) a[4] else "dev/figures/agu-poster"
PLACE <- "Southern Sierra Nevada, California"
W <- 20; H <- 9.8

INK <- "#0b0b0b"; INK2 <- "#52514e"; MUTED <- "#898781"; GRID <- "#e1e0d9"; AXIS <- "#c3c2b7"; CHIP <- "#f3f2ee"; SLATE <- "#2f4858"
C_FIRE <- "#eb6834"; C_DROUGHT <- "#6250d6"; C_HARVEST <- "#2a78d6"
C_LIVE <- "#008300"; C_DEAD <- "#9c6b1e"; C_SOIL <- "#898781"
DIV <- c("#7f3b08", "#c2752a", "#e8c08f", "#eeede9", "#a9d3a2", "#4c9f5b", "#14622f")     # loss (brown) .. neutral .. gain (green)
DIV_BRK <- c(-Inf, -100, -30, -10, 10, 30, 100, Inf)
FIRE_COLS <- c("#f6d37a", "#f0a04b", "#d9562b", "#8c1d18"); FIRE_BRK <- c(1986, 2000, 2010, 2020, 2024)
FIRE_LAB <- c("1986–99", "2000–09", "2010–19", "2020–23")
LC <- data.table(lab = c("Conifer forest", "Hardwood forest", "Disturbed", "Shrubland", "Grassland", "Farms, towns", "Barren, water"),
                 col = c("#1f6b3a", "#86b86b", "#a0522d", "#cdb97a", "#ece3a6", "#c2407a", "#cfd3d6"))
lc_of <- function(n) fifelse(grepl("^Forest: (California|Fir|Lodgepole|Ponderosa|Pinyon)", n), 1L, fifelse(grepl("^(Forest|Wetland): (Western Oak|Aspen|Elm)", n), 2L,
  fifelse(grepl("^Disturbed", n), 3L, fifelse(grepl("^Shrubland", n), 4L, fifelse(grepl("^Grassland", n), 5L, fifelse(grepl("^(Agriculture|Developed)", n), 6L, 7L))))))

# ---- tables ----------------------------------------------------------------------------------------------------------------
con <- dbConnect(RSQLite::SQLite(), LIB, flags = RSQLite::SQLITE_RO)
q <- function(s) as.data.table(dbGetQuery(con, sprintf(s, RUN)))
stk <- q("select Timestep, g.Name, sum(Amount)/1e6 Tg from stsim_OutputStock o join stsim_StockGroup g on g.StockGroupId=o.StockGroupId
          where o.ScenarioId=%d and g.Name in ('Biomass: Total','DOM: Deadwood','DOM: Litter','DOM: Soil','Total Ecosystem') group by 1,2")
flw <- q("select Timestep, g.Name, coalesce(t.Name,'') TType, sum(Amount)/1e6 Tg from stsim_OutputFlow o join stsim_FlowGroup g on g.FlowGroupId=o.FlowGroupId
          left join stsim_TransitionType t on t.TransitionTypeId=o.TransitionTypeId where o.ScenarioId=%d and g.Name in
          ('Net Primary Productivity','Emission: Total Rh','Net Biome Productivity','LULC: Emission','LULC: Mortality','LULC: Harvest') group by 1,2,3")
trn <- q("select Timestep, g.Name, sum(Amount) Ha from stsim_OutputStratumTransition o join stsim_TransitionGroup g on g.TransitionGroupId=o.TransitionGroupId
          where o.ScenarioId=%d and g.Name in ('Fire','Mortality','Forest Harvest') group by 1,2")
area <- q("select sum(Amount) Ha from stsim_OutputStratum where ScenarioId=%d and Timestep=(select min(Timestep) from stsim_OutputStratum where ScenarioId=%1$d)")$Ha
scl <- as.data.table(dbGetQuery(con, "select Id, Name from stsim_StateClass"))
fire_group <- dbGetQuery(con, "select TransitionGroupId from stsim_TransitionGroup where Name='Fire'")$TransitionGroupId
eco_group <- dbGetQuery(con, "select StockGroupId from stsim_StockGroup where Name='Total Ecosystem'")$StockGroupId
dem_file <- dbGetQuery(con, sprintf("select Path from lucasCore_OutputDataSources where ScenarioId=%d and DataSource='ElevationFile'", BUILD))$Path[1]
CAP <- as.data.table(dbGetQuery(con, sprintf("select * from lucasCore_OutputRunCapacity where RunScenarioId=%d order by Year", RUN)))   # stage 13 writes it
dbDisconnect(con)

yrs <- sort(unique(stk$Timestep)); y0 <- yrs[1]; y1 <- yrs[length(yrs)]; fy <- yrs[-1]
S <- dcast(stk, Timestep ~ Name, value.var = "Tg"); setnames(S, c("Biomass: Total", "DOM: Deadwood", "DOM: Litter", "DOM: Soil", "Total Ecosystem"), c("live", "dead", "litter", "soil", "total"))
S[, ls := litter + soil]
cause <- function(names, pat) { x <- flw[Name %in% names & grepl(pat, TType), .(Tg = sum(Tg)), by = Timestep]; x <- x[match(fy, Timestep), Tg]; x[is.na(x)] <- 0; x }
L <- data.table(Timestep = fy, fire = cause(c("LULC: Emission", "LULC: Mortality"), "^Fire"), drought = cause("LULC: Mortality", "^Mortality"),
                harvest = cause(c("LULC: Emission", "LULC: Mortality", "LULC: Harvest"), "^Forest Harvest"),
                fire_emis = cause("LULC: Emission", "^Fire"))
tot <- function(n) flw[Name == n, .(Tg = sum(Tg)), by = Timestep][match(fy, Timestep), Tg]
L[, `:=`(nbp = tot("Net Biome Productivity"), npp = tot("Net Primary Productivity"), rh = tot("Emission: Total Rh"))]
ha <- function(n) { x <- trn[Name == n][match(fy, Timestep), Ha]; x[is.na(x)] <- 0; x }
L[, `:=`(fire_ha = ha("Fire"), drought_ha = ha("Mortality"), harvest_ha = ha("Forest Harvest"))]

# ---- maps ------------------------------------------------------------------------------------------------------------------
D <- paste0(LIB, ".data/Scenario-", RUN)
sc <- rast(sprintf("%s/stsim_OutputSpatialState/sc.it1.ts%d.tif", D, y1))
eco <- function(y) rast(sprintf("%s/stsim_OutputAverageSpatialStockGroup/avgstkg_%d.it0.ts%d.tif", D, eco_group, y))
dC <- eco(y1) - eco(y0)
last <- rast(sc); values(last) <- NA_integer_; v <- rep(NA_integer_, ncell(sc))
for (y in fy) { f <- sprintf("%s/stsim_OutputSpatialTransition/tg_%d.it1.ts%d.tif", D, fire_group, y); if (!file.exists(f)) next
  b <- values(rast(f), mat = FALSE); v[!is.na(b) & b > 0] <- y }
values(last) <- v
burned_share <- sum(!is.na(v)) / sum(!is.na(values(sc, mat = FALSE)))
# everything is drawn on a grid twice as fine, so the relief is smoother than the model cells
g2 <- disagg(sc, 2); inside <- !is.na(values(g2, mat = FALSE))
dem <- crop(rast(dem_file), ext(sc) + 3000); dem <- resample(aggregate(dem, 5, "mean"), g2, "bilinear")
hs <- shade(terrain(dem, "slope", unit = "radians"), terrain(dem, "aspect", unit = "radians"), angle = 45, direction = 315)
mult <- pmin(1.12, pmax(0.55, values(hs, mat = FALSE) / sin(pi / 4))); mult[is.na(mult)] <- 1
img <- function(k, cols, blank = "#eeede9") {       # k: class index per cell of g2 (NA inside the study area = blank)
  rgbm <- col2rgb(c(cols, blank)) / 255; k[is.na(k)] <- length(cols) + 1L
  o <- array(1, c(nrow(g2), ncol(g2), 3))
  for (j in 1:3) { x <- pmin(1, rgbm[j, k] * mult); x[!inside] <- 1; o[, , j] <- matrix(x, nrow(g2), ncol(g2), byrow = TRUE) }
  o }
on2 <- function(r) values(disagg(r, 2), mat = FALSE)
k_lc <- lc_of(scl$Name[match(on2(sc), scl$Id)])
k_fire <- findInterval(on2(last), FIRE_BRK, rightmost.closed = TRUE); k_fire[k_fire == 0] <- NA
k_dc <- findInterval(on2(dC), DIV_BRK)
outline <- as.polygons(ifel(is.na(sc), NA, 1)); og <- as.data.table(geom(outline))
lc_share <- tabulate(lc_of(scl$Name[match(na.omit(values(sc, mat = FALSE)), scl$Id)]), 7); lc_share <- lc_share / sum(lc_share)

# ---- numbers for the caption ---------------------------------------------------------------------------------------------------
num <- c(sprintf("Area %.0f km2; %d-%d; cell %g m", area / 100, y0, y1, res(sc)[1]),
  sprintf("Total ecosystem carbon %.1f -> %.1f Tg C (%+.1f); peak %.1f in %d", S$total[1], S[.N, total], S[.N, total] - S$total[1], max(S$total), S[which.max(total), Timestep]),
  sprintf("Live %.1f -> %.1f (peak %.1f in %d); dead wood %.1f -> %.1f; litter+soil %.1f -> %.1f", S$live[1], S[.N, live], max(S$live), S[which.max(live), Timestep], S$dead[1], S[.N, dead], S$ls[1], S[.N, ls]),
  sprintf("Mean NPP %.2f, Rh %.2f, NBP %+.3f Tg C/yr; years with NBP < 0: %d of %d", mean(L$npp), mean(L$rh), mean(L$nbp), sum(L$nbp < 0), nrow(L)),
  sprintf("Fire: %.0f kha burned in all (cells x years), %.0f%% of cells burned at least once; %d: %.0f kha, %.1f Tg C burned or killed (%.1f emitted)", sum(L$fire_ha) / 1e3, 100 * burned_share,
          L[which.max(fire_ha), Timestep], max(L$fire_ha) / 1e3, L[which.max(fire_ha), fire], L[which.max(fire_ha), fire_emis]),
  sprintf("Fire totals: %.1f Tg C burned or killed, %.1f emitted; 2020-21: %.1f and %.1f", sum(L$fire), sum(L$fire_emis), L[Timestep %in% 2020:2021, sum(fire)], L[Timestep %in% 2020:2021, sum(fire_emis)]),
  sprintf("Drought and insects: %.2f Tg C killed in all, %.2f in 2016-2019 (peak %.2f in %d); %.1f kha", sum(L$drought), L[Timestep %in% 2016:2019, sum(drought)], max(L$drought), L[which.max(drought), Timestep], sum(L$drought_ha) / 1e3),
  sprintf("Harvest: %.2f Tg C in all; %.1f kha", sum(L$harvest), sum(L$harvest_ha) / 1e3),
  sprintf("NBP %d: %+.1f; %d: %+.1f", 2020L, L[Timestep == 2020, nbp], 2021L, L[Timestep == 2021, nbp]),
  sprintf("Carrying capacity (live, dead wood, litter) %.1f Tg C, upper bound %.1f; stock %.1f%% of it in %d, %.1f%% in %d (peak), %.1f%% in %d; deficit %d %.1f Tg C: disturbed land %.1f, land use %.1f, cover %.1f, live %.1f, dead %.1f",
          CAP$Capacity[1], CAP$UpperBound[1], CAP$RealisedShare[1], CAP$Year[1], max(CAP$RealisedShare), CAP[which.max(RealisedShare), Year], CAP[.N, RealisedShare], CAP[.N, Year], CAP[.N, Year], CAP[.N, Deficit],
          CAP[.N, DeficitDisturbed], CAP[.N, DeficitLandUse], CAP[.N, DeficitCover], CAP[.N, DeficitLive], CAP[.N, DeficitDead]),
  sprintf("Land cover %d: %s", y1, paste(sprintf("%s %.0f%%", LC$lab, 100 * lc_share), collapse = "; ")))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE); writeLines(num, file.path(OUT, "agu-poster-numbers.txt")); cat(num, sep = "\n")

# ---- drawing ---------------------------------------------------------------------------------------------------------------
rrect <- function(x0, y0, x1, y1, r = .09, col = NA, border = NA, lwd = 1) { t <- seq(0, pi / 2, length.out = 12)
  polygon(c(x1 - r + r * cos(t), x0 + r - r * sin(t), x0 + r - r * cos(t), x1 - r + r * sin(t)),
          c(y1 - r + r * sin(t), y1 - r + r * cos(t), y0 + r - r * sin(t), y0 + r - r * cos(t)), col = col, border = border, lwd = lwd) }
ptitle <- function(x, y, letter, s, unit = NULL) { text(x, y, sprintf("(%s) %s", letter, s), adj = c(0, 0), font = 2, cex = 1.3, col = INK)
  if (!is.null(unit)) text(x, y - .27, unit, adj = c(0, 0), cex = 1.05, col = INK2) }

draw <- function() {
  par(mar = c(0, 0, 0, 0), xaxs = "i", yaxs = "i", family = "sans", xpd = NA); plot.new(); plot.window(c(0, W), c(0, H))

  # (a) the schematic ------------------------------------------------------------------------------------------------------
  x0 <- .2; x1 <- 4.25; ptitle(x0, H - .5, "a", "One model, many disciplines")
  chips <- list(c("Forest inventory", "FIA field plots: tree growth,", "live and dead carbon pools"),
                c("Satellite records", "Annual NLCD, LANDFIRE, MTBS, LCMS:", "land cover, fire, harvest, tree die-off"),
                c("Climate", "PRISM history and LOCA2 futures:", "growth and decay respond to weather"),
                c("Soils and terrain", "gNATSGO soil carbon,", "wetlands, elevation"),
                c("People", "Land-use demand and population", "scenarios for projections"))
  text(x0, H - .98, "NATIONAL DATA", adj = c(0, 0), cex = .95, col = MUTED, font = 2)
  y <- H - 1.1; ch <- .92; gap <- .1
  for (c3 in chips) { rrect(x0, y - ch, x1, y, col = CHIP); rect(x0, y - ch + .09, x0 + .07, y - .09, col = SLATE, border = NA)
    text(x0 + .22, y - .25, c3[1], adj = c(0, .5), font = 2, cex = 1.12, col = INK)
    text(x0 + .22, y - .51, c3[2], adj = c(0, .5), cex = .95, col = INK2); text(x0 + .22, y - .73, c3[3], adj = c(0, .5), cex = .95, col = INK2)
    y <- y - ch - gap }
  xm <- (x0 + x1) / 2; arrow <- function(ya, yb) arrows(xm, ya, xm, yb, length = .11, lwd = 2.5, col = SLATE)
  arrow(y + .04, y - .26); y <- y - .32
  rrect(x0, y - 1.72, x1, y, col = SLATE)
  text(x0 + .22, y - .3, "LUCAS", adj = c(0, .5), font = 2, cex = 1.35, col = "white")
  text(x1 - .2, y - .3, "lucasCore + ST-Sim", adj = c(1, .5), cex = .95, col = "#c9d3d9")
  lines3 <- c("Every cell, every year:", "land cover and stand age,", "fire, drought, harvest, land-use change,", "carbon in live, dead and soil pools")
  for (i in seq_along(lines3)) text(x0 + .22, y - .62 - (i - 1) * .27, lines3[i], adj = c(0, .5), cex = 1.0, col = "white", font = if (i == 1) 2 else 1)
  y <- y - 1.72; arrow(y - .04, y - .34); y <- y - .4
  rrect(x0, y - 1.02, x1, y, col = "white", border = SLATE, lwd = 2)
  text(x0 + .22, y - .26, "Maps and annual carbon accounts", adj = c(0, .5), font = 2, cex = 1.08, col = INK)
  text(x0 + .22, y - .53, "for any U.S. region, 1985 to today,", adj = c(0, .5), cex = .95, col = INK2)
  text(x0 + .22, y - .76, "and projected under future scenarios", adj = c(0, .5), cex = .95, col = INK2)

  # (b) to (d) the maps ----------------------------------------------------------------------------------------------------
  mh <- 7.72; mw <- mh * ncol(sc) / nrow(sc); cw <- 2.9; mx <- 4.6 + (0:2) * cw; my <- 1.2; e <- ext(sc)
  amap <- function(i, k, cols, letter, title, unit) { xl <- mx[i] + (cw - mw) / 2 - .1
    rasterImage(img(k, cols), xl, my, xl + mw, my + mh, interpolate = FALSE)
    for (p in split(og, list(og$geom, og$part, og$hole), drop = TRUE))
      lines(xl + (p$x - e[1]) / (e[2] - e[1]) * mw, my + (p$y - e[3]) / (e[4] - e[3]) * mh, col = "#3a3a38", lwd = .8)
    ptitle(mx[i], H - .5, letter, title, unit); xl }
  sw <- function(x, y, col, w = .26, h = .17) rect(x, y - h / 2, x + w, y + h / 2, col = col, border = "#00000030", lwd = .5)
  xl <- amap(1, k_lc, LC$col, "b", sprintf("Land cover, %d", y1), sprintf("%s km\u00b2 at %g m", format(round(area / 100, -2), big.mark = ","), res(sc)[1]))
  for (j in seq_len(nrow(LC))) { cx <- mx[1] - .1 + ((j - 1) %/% 4) * 1.6; cy <- .98 - ((j - 1) %% 4) * .25; sw(cx, cy, LC$col[j]); text(cx + .34, cy, LC$lab[j], adj = c(0, .5), cex = .92, col = INK2) }
  # a 100 km scale bar under the first map's key column gap
  amap(2, k_fire, FIRE_COLS, "c", "Year last burned", sprintf("%.0f%% of the area, %d–%d", 100 * burned_share, fy[1], y1))
  bw <- .62; for (j in 1:4) { rect(mx[2] + (j - 1) * bw, .78, mx[2] + j * bw, .98, col = FIRE_COLS[j], border = "white", lwd = 1.5)
    text(mx[2] + (j - .5) * bw, .6, FIRE_LAB[j], cex = .82, col = INK2) }
  sw(mx[2], .26, "#eeede9", w = .3); text(mx[2] + .4, .26, "not burned", adj = c(0, .5), cex = .92, col = INK2)
  amap(3, k_dc, DIV, "d", "Carbon change", sprintf("%d to %d, all pools", y0, y1))
  bw <- .37; for (j in 1:7) rect(mx[3] + (j - 1) * bw, .78, mx[3] + j * bw, .98, col = DIV[j], border = "white", lwd = 1.5)
  for (j in 1:6) text(mx[3] + j * bw, .6, sub("-", "−", sprintf("%+d", as.integer(DIV_BRK[j + 1]))), cex = .82, col = INK2)
  text(mx[3], .26, "loss", adj = c(0, .5), cex = .92, col = INK2); text(mx[3] + 7 * bw, .26, "gain", adj = c(1, .5), cex = .92, col = INK2)
  text(mx[3] + 3.5 * bw, .26, "Mg C per hectare", cex = .92, col = INK2)
  sbl <- 50000 / (e[2] - e[1]) * mw   # scale bar, in the empty upper right of the first map
  sbx <- xl + mw - sbl - .02; sby <- my + mh - .55; 
  segments(sbx, sby, sbx + sbl, sby, lwd = 2.5, col = INK2, lend = 1); text(sbx + sbl / 2, sby + .16, "50 km", cex = .88, col = INK2)

  # (e) to (g) the charts --------------------------------------------------------------------------------------------------
  cx0 <- 13.35; cx1 <- 19.95; tops <- c(H - .22, 6.4, 3.22); ph <- c(3.2, 3.2, 3.2)
  chart <- function(i, ylim, letter, title, unit, body, xlabs = FALSE) {
    par(fig = c(cx0 / W, cx1 / W, (tops[i] - ph[i]) / H, tops[i] / H), new = TRUE, mai = c(.42, .62, .78, 1.85), xaxs = "i", yaxs = "i", xpd = FALSE, mgp = c(2, .55, 0), las = 1)
    plot(NA, xlim = c(y0 - .2, y1 + .8), ylim = ylim, axes = FALSE, xlab = "", ylab = "")
    tk <- pretty(ylim, 4); tk <- tk[tk >= ylim[1] & tk <= ylim[2]]; abline(h = tk, col = GRID, lwd = 1)
    axis(2, tk, labels = sub("^-", "\u2212", format(tk)), lwd = 0, cex.axis = 1.08, col.axis = INK2)
    axis(1, seq(1990, 2020, 10), lwd = 0, lwd.ticks = 1, col.ticks = AXIS, tck = -.03, cex.axis = 1.08, col.axis = INK2)
    u <- par("usr"); par(xpd = NA)
    text(u[1] - xinch(.5), u[4] + yinch(.5), sprintf("(%s) %s", letter, title), adj = c(0, 0), font = 2, cex = 1.3, col = INK)
    text(u[1] - xinch(.5), u[4] + yinch(.2), unit, adj = c(0, 0), cex = 1.05, col = INK2)
    body(u); par(xpd = FALSE) }
  key <- function(u, labs, cols, top = u[4], line = FALSE) for (j in seq_along(labs)) { yy <- top - yinch(.12 + (j - 1) * .3); xx <- u[2] + xinch(.14)
    if (line) segments(xx, yy, xx + xinch(.24), yy, col = cols[j], lwd = 4, lend = 1) else rect(xx, yy - yinch(.08), xx + xinch(.24), yy + yinch(.08), col = cols[j], border = NA)
    text(xx + xinch(.32), yy, labs[j], adj = c(0, .5), cex = .98, col = INK2) }

  d <- S[, .(Timestep, total = total - total[1], live = live - live[1], dead = dead - dead[1], ls = ls - ls[1])]
  chart(1, c(-10, 25), "e", "Change in carbon since 1985", "Tg C (teragrams of carbon)", function(u) {
    segments(u[1], 0, u[2], 0, col = AXIS, lwd = 1.5)
    lines(d$Timestep, d$ls, col = C_SOIL, lwd = 2.5); lines(d$Timestep, d$dead, col = C_DEAD, lwd = 2.5); lines(d$Timestep, d$live, col = C_LIVE, lwd = 2.5)
    lines(d$Timestep, d$total, col = INK, lwd = 4)
    end <- d[.N]; lab <- c(total = "All pools", live = "Live plants", dead = "Dead wood", ls = "Litter and soil"); cols <- c(total = INK, live = C_LIVE, dead = C_DEAD, ls = C_SOIL)
    yv <- unlist(end[, .(total, live, dead, ls)]); o <- order(yv); yl <- yv[o]; mingap <- (u[4] - u[3]) * .115
    for (j in 2:4) if (yl[j] - yl[j - 1] < mingap) yl[j] <- yl[j - 1] + mingap
    for (j in 1:4) { n <- names(yl)[j]; points(y1, yv[n], pch = 21, bg = cols[n], col = "white", cex = 1.5, lwd = 1.5)
      segments(y1 + .5, yv[n], y1 + 1.6, yl[j], col = cols[n], lwd = 1.2)
      text(y1 + 1.9, yl[j], sprintf("%s %s", lab[n], sub("-", "\u2212", sprintf("%+.0f", yv[n]))), adj = c(0, .5), cex = .98, col = INK2, font = if (n == "total") 2 else 1) } })

  M <- t(as.matrix(L[, .(fire, drought, harvest)])); top <- colSums(M)
  chart(2, c(0, ceiling(max(top) / 2) * 2), "f", "Plant carbon burned, killed or cut", "Tg C per year, by cause", function(u) {
    base <- rep(0, ncol(M)); cols <- c(C_FIRE, C_DROUGHT, C_HARVEST)
    for (j in 1:3) { rect(fy - .38, base, fy + .38, base + M[j, ], col = cols[j], border = NA); base <- base + M[j, ] }
    segments(u[1], 0, u[2], 0, col = AXIS, lwd = 1.5); key(u, c("Wildfire", "Drought, insects", "Timber harvest"), cols)
    iy <- which.max(top); text(fy[iy] - 1, top[iy] * .88, sprintf("%d fires:\n%.0f Tg C", fy[iy], top[iy]), adj = c(1, .5), cex = .98, col = INK2)
    dp <- L[Timestep %in% 2016:2019]; ty <- max(top[fy %in% 2016:2019]) + (u[4] - u[3]) * .32
    text(2010.5, ty, sprintf("drought die-off\n2016–19: %.1f Tg C", sum(dp$drought)), adj = c(1, .5), cex = .98, col = INK2)
    segments(2010.9, ty, 2016.6, top[fy == 2017] + (u[4] - u[3]) * .04, col = MUTED, lwd = 1.2) })

  pk <- CAP[which.max(RealisedShare)]; gap <- CAP[.N]
  chart(3, c(floor(min(CAP$RealisedShare) / 5) * 5 - 5, 101.5), "g", "Carbon against the carrying capacity", "% of what natural vegetation and fire would hold", function(u) {
    segments(u[1], 100, u[2], 100, col = INK, lwd = 2); text(u[1] + .6, 98.6, "carrying capacity", adj = c(0, .5), cex = .98, col = INK2)
    lines(CAP$Year, CAP$RealisedShare, col = SLATE, lwd = 4)
    pts <- rbind(CAP[1], pk, gap); points(pts$Year, pts$RealisedShare, pch = 21, bg = SLATE, col = "white", cex = 1.5, lwd = 1.5)
    text(pts$Year + c(.8, 0, -.6), pts$RealisedShare + (u[4] - u[3]) * .085, sprintf("%.0f%%", pts$RealisedShare), cex = .98, col = INK2, font = 2)
    text(u[2] + xinch(.14), u[4] - yinch(.05), sprintf("Capacity: %.0f Tg C\nin live plants, dead\nwood and litter\n\n%d: %.0f Tg C below,\n%s on land\nrecovering from\ndisturbance", gap$Capacity, gap$Year, gap$Deficit,
         if (gap$DeficitDisturbed / gap$Deficit > .5) "over half of it" else sprintf("%.0f%% of it", 100 * gap$DeficitDisturbed / gap$Deficit)), adj = c(0, 1), cex = .98, col = INK2) })
}

png(file.path(OUT, "agu-poster-lucas-figure.png"), width = W, height = H, units = "in", res = 300, type = "cairo", pointsize = 12); draw(); invisible(dev.off())
cairo_pdf(file.path(OUT, "agu-poster-lucas-figure.pdf"), width = W, height = H, pointsize = 12); draw(); invisible(dev.off())
cat("written to", normalizePath(OUT), "\n")
