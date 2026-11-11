# P26, to-do 57: does return to forest after a stand-replacing fire follow the share of live forest of the burned pixel's own type
# around it, or is the share of any live forest as good? Forest pixels (Annual NLCD 41-43 the year before) at a first MTBS burn of
# moderate or high severity, 1986-2005, not burned again within 20 years. Live forest = NLCD forest the year after the fire; type =
# the USFS forest type group map (PSW). Shares within 150 m (about seed reach) and 450 m (P26's adjacency radius: 3 cells of 150 m),
# on the 30 m grid. Return = NLCD forest two years running, within 20 years of the fire.
# Usage: Rscript dev/fire/p26-seed-source.R <out folder>   (data home: LUCAS_DATA_HOME, else dev/libs/Data Sources)
suppressMessages({ library(terra); library(data.table) }); terraOptions(progress = 0)
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "../.."))
home <- Sys.getenv("LUCAS_DATA_HOME", file.path(pkg, "dev/libs/Data Sources")); reg <- file.path(home, "regions/Pyrome-P26-Northern-Sierra-Nevada")
out <- commandArgs(TRUE)[1]; dir.create(out, showWarnings = FALSE)
nl <- function(y) file.path(reg, sprintf("land-cover/nlcd-annual/Annual_NLCD_LndCov_%d_CU_C1V2.tif", y))
g <- rast(nl(2000)); p <- vect(file.path(home, "study-area/pyromes/Pyromes_CONUS_20200206.shp")); p <- project(p[p$PYROME == 26], crs(g))
inP <- values(rasterize(p, g), mat = FALSE) == 1; inP[is.na(inP)] <- FALSE; cells <- which(inP)
vals <- function(f) values(rast(f), mat = FALSE)
first <- integer(ncell(g)); sev <- integer(ncell(g)); reburn <- integer(ncell(g))
for (y in 1985:2024) { s <- vals(file.path(reg, sprintf("disturbance/mtbs/mtbs_CONUS_%d.tif", y))); b <- inP & !is.na(s) & s %in% 2:4
  reburn[b & first > 0 & reburn == 0] <- y; nw <- b & first == 0; first[nw] <- y; sev[nw] <- s[nw] }
ft <- rast(file.path(reg, "land-cover/forest-type-groups/PSW_ForestType.tif"))
ft <- project(crop(ft, project(as.polygons(ext(g), crs = crs(g)), crs(ft))), g, method = "near"); ftv <- values(ft, mat = FALSE)
cand <- which(inP & first %in% 1986:2005 & sev %in% 3:4 & (reburn == 0 | reburn > first + 20) & !is.na(ftv) & ftv > 0)
cat("candidates (before the forest check)", length(cand), "\n")
D <- data.table(cell = cand, fy = first[cand], sev = sev[cand], ftype = ftv[cand]); rm(first, sev, reburn)
# NLCD for the candidates: forest the year before, and every year after
yrs <- 1985:2025; N <- matrix(0L, nrow(D), length(yrs))
for (i in seq_along(yrs)) N[, i] <- vals(nl(yrs[i]))[D$cell]
D[, pre := N[cbind(seq_len(.N), match(fy - 1L, yrs))]]; keep <- D$pre %in% 41:43; D <- D[keep]; N <- N[keep, , drop = FALSE]
isF <- function(k) { i <- match(D$fy + k, yrs); v <- rep(FALSE, nrow(D)); ok <- !is.na(i); v[ok] <- N[cbind(which(ok), i[ok])] %in% 41:43; v }
back <- rep(NA_integer_, nrow(D)); f1 <- isF(1); for (k in 1:20) { f2 <- isF(k + 1); h <- is.na(back) & f1 & f2; back[h] <- k; f1 <- f2 }
D[, back20 := !is.na(back) & back <= 20][, back := back]; rm(N)
cat("burned forest pixels:", nrow(D), "\n")
# shares of live forest (NLCD forest the year after the fire) within 150 and 450 m: any type, and the pixel's own type
types <- sort(unique(D$ftype)); R <- c(150, 450)
for (r in R) { set(D, j = paste0("any", r), value = NA_real_); set(D, j = paste0("own", r), value = NA_real_) }
for (y in sort(unique(D$fy))) {
  d <- D[fy == y, which = TRUE]; e <- ext(xyFromCell(g, D$cell[d])[, 1] |> range(), xyFromCell(g, D$cell[d])[, 2] |> range()) + 600
  e <- intersect(e, ext(g)); L <- crop(rast(nl(y + 1)), e); Ff <- L %in% 41:43; land <- !(L %in% c(11, 12)) & !is.na(L)
  Tt <- crop(ft, e); xy <- xyFromCell(g, D$cell[d])
  for (r in R) {
    # 150 m: on the 30 m grid; 450 m: on P26's 150 m model grid (cell sums of 5 x 5), a 3-cell circle, as ST-Sim computes it
    agg <- if (r == 150) function(x) x else function(x) aggregate(x, 5, "sum", na.rm = TRUE)
    lan <- agg(land); w <- focalMat(lan, r, "circle"); w[w > 0] <- 1
    den <- focal(lan, w, "sum", na.rm = TRUE); a <- focal(agg(Ff), w, "sum", na.rm = TRUE) / den
    set(D, i = d, j = paste0("any", r), value = extract(a, xy)[, 1])
    own <- rep(NA_real_, length(d))
    for (t in intersect(types, D$ftype[d])) { k <- which(D$ftype[d] == t); o <- focal(agg(Ff & (Tt == t)), w, "sum", na.rm = TRUE) / den
      own[k] <- extract(o, xy[k, , drop = FALSE])[, 1] }
    set(D, i = d, j = paste0("own", r), value = own) }
  cat("fire year", y, ":", length(d), "pixels\n") }
fwrite(D, file.path(out, "seed-source.csv")); cat("done\n")
