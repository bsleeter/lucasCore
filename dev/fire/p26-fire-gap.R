# Usage: Rscript dev/fire/p26-fire-gap.R <out folder>   (data home: LUCAS_DATA_HOME, else dev/libs/Data Sources; to-do 57)
# P26: what NLCD shows on forest after fire. Forest pixels (NLCD 41-43 the year before) burned at MTBS low / moderate / high
# severity (first MTBS burn of each pixel, 1986-2024), followed through Annual NLCD to 2025. Control: unburned forest pixels
# given the same fire-year mix, to show NLCD's own forest -> non-forest rate.
suppressMessages({ library(terra); library(data.table) }); terraOptions(progress = 0)
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "../..")); home <- Sys.getenv("LUCAS_DATA_HOME", file.path(pkg, "dev/libs/Data Sources")); reg <- file.path(home, "regions/Pyrome-P26-Northern-Sierra-Nevada")
out <- commandArgs(TRUE)[1]; dir.create(out, showWarnings = FALSE)
yrs <- 1985:2025; nl <- function(y) file.path(reg, sprintf("land-cover/nlcd-annual/Annual_NLCD_LndCov_%d_CU_C1V2.tif", y))
g <- rast(nl(2000))
p <- vect(file.path(home, "study-area/pyromes/Pyromes_CONUS_20200206.shp")); p <- project(p[p$PYROME == 26], crs(g))
cells <- which(values(rasterize(p, g), mat = FALSE) == 1); cat("P26 cells", length(cells), "\n")
rd <- function(f) { r <- rast(f); stopifnot(all.equal(ext(r), ext(g)), all(dim(r)[1:2] == dim(g)[1:2])); values(r, mat = FALSE)[cells] }

# MTBS: first burn (severity 2-4) and later burns
first <- integer(length(cells)); sev <- integer(length(cells)); nburn <- integer(length(cells)); reburn <- integer(length(cells))
for (y in 1985:2024) { s <- rd(file.path(reg, sprintf("disturbance/mtbs/mtbs_CONUS_%d.tif", y))); b <- !is.na(s) & s %in% 2:4
  nb <- b & first > 0 & reburn == 0; reburn[nb] <- y
  nw <- b & first == 0; first[nw] <- y; sev[nw] <- s[nw]; nburn[b] <- nburn[b] + 1L }
cat("burned cells", sum(first > 0), "\n")

# NLCD for burned cells and a control sample
set.seed(26); ub <- which(first == 0); ctl <- sample(ub, min(length(ub), 400000))
keep <- c(which(first > 0), ctl)
N <- matrix(as.raw(0), length(keep), length(yrs))
for (i in seq_along(yrs)) { v <- rd(nl(yrs[i])); N[, i] <- as.raw(ifelse(is.na(v[keep]), 0L, v[keep])) ; if (i %% 10 == 0) cat("NLCD", yrs[i], "\n") }
fy <- first[keep]; isctl <- seq_along(keep) > sum(first > 0)
fy[isctl] <- sample(first[first > 0], sum(isctl), replace = TRUE)   # control: the burned pixels' mix of fire years
# forest type group (USFS 2018) where it covers
ft <- rast(file.path(reg, "land-cover/forest-type-groups/PSW_ForestType.tif")); ft <- project(crop(ft, project(as.polygons(ext(g), crs = crs(g)), crs(ft))), g, method = "near")
ftv <- values(ft, mat = FALSE)[cells][keep]
D <- data.table(id = seq_along(keep), ctl = isctl, fy = fy, sev = ifelse(isctl, 0L, sev[keep]), nburn = ifelse(isctl, 0L, nburn[keep]),
                reburn = ifelse(isctl, 0L, reburn[keep]), ftype = ftv)
D[, pre := as.integer(N[cbind(id, match(fy - 1L, yrs))])]
D <- D[pre %in% 41:43]; cat("forest before the fire:", D[ctl == FALSE, .N], "burned,", D[ctl == TRUE, .N], "control\n")
cl <- function(v) fcase(v %in% 41:43, "Forest", v == 52, "Shrub", v == 71, "Grass", v %in% 21:24, "Developed", v %in% c(81, 82), "Agriculture", v == 31, "Barren", default = "Water/wetland/other")
L <- rbindlist(lapply(1:40, function(k) { d <- D[fy + k <= 2025]; if (!nrow(d)) return(NULL)
  d[, .(k = k, cls = cl(as.integer(N[cbind(id, match(fy + k, yrs))])), ctl, sev, reb = reburn > 0 & reburn <= fy + k, ftype, fy)] }))
fwrite(L[, .N, by = .(k, ctl, sev, reb, cls)], file.path(out, "by-year.csv"))
fwrite(L[, .N, by = .(k, ctl, sev, reb, ftype, cls)][k %in% c(5, 10, 15, 20, 25, 30)], file.path(out, "by-type.csv"))
# first year back to forest (NLCD forest in that year and the next), and NLCD in 2025
isF <- function(k) { i <- match(D$fy + k, yrs); v <- rep(FALSE, nrow(D)); ok <- !is.na(i); v[ok] <- as.integer(N[cbind(D$id[ok], i[ok])]) %in% 41:43; v }
back <- rep(NA_integer_, nrow(D)); f1 <- isF(1)
for (k in 1:39) { f2 <- isF(k + 1); hit <- is.na(back) & f1 & f2; back[hit] <- k; f1 <- f2 }
D[, back := back][, now := cl(as.integer(N[cbind(id, length(yrs))]))]
fwrite(D[, .(id, ctl, fy, sev, nburn, reburn, ftype, pre, back, now)], file.path(out, "pixels.csv"))
cat("done\n")
