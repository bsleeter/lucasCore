# To-do 57: how big is reforestation? Natural non-forest (NLCD 31, 52, 71, 95) that becomes forest (41-43, 90) two years running and
# stays forest in at least 2/3 of the years after (the regrowth rule's persistence test), on the model grid, 1986-2023. Each cell's first
# such event is sorted by what the record shows before it: a fire (MTBS burned, LCMS wildfire or prescribed fire) or harvest (LCMS
# Tree Removal) on at least a quarter of the cell since 1985 (post-fire return and harvest regrowth: covered already), or nothing
# recorded (the reforestation transition's share): non-forest since the start (disturbance before 1985, or encroachment) or forest
# earlier in the record and lost with no recorded cause.
# Usage: Rscript dev/fire/reforestation-size.R <label> <strata.tif> <model NLCD folder or "30m"> <region folder> [<label> ...] (groups of four)
suppressMessages({ library(terra); library(data.table); library(parallel) })
a <- commandArgs(TRUE); yrs <- 1985:2023; FOR <- c(41:43, 90); NAT <- c(31, 52, 71, 95)
for (k in seq(1, length(a), 4)) { lab <- a[k]; sf <- a[k + 1]; mnl <- a[k + 2]; reg <- a[k + 3]
  S <- rast(sf); land <- which(!is.na(values(S, mat = FALSE))); ha <- prod(res(S)) / 1e4
  cl <- makeCluster(19)
  lay <- parLapply(cl, yrs, function(y, sf, mnl, reg) { library(terra); terraOptions(progress = 0, memfrac = 0.04); S <- rast(sf)
    win <- function(r) crop(r, project(as.polygons(ext(S) + 500, crs = crs(S)), crs(r)), snap = "out")
    f30 <- function(r, codes) { levels(r) <- NULL; project(win(r) %in% codes, S, method = "average") }
    nl <- if (mnl == "30m") { r <- rast(list.files(file.path(reg, "land-cover", "nlcd-annual"), sprintf("_%d_CU_", y), full.names = TRUE)[1]); levels(r) <- NULL; project(win(r), S, method = "mode") } else rast(file.path(mnl, sprintf("NLCD_%d.tif", y)))
    mf <- file.path(reg, "disturbance", "mtbs", sprintf("mtbs_CONUS_%d.tif", y)); lf <- list.files(file.path(reg, "disturbance", "lcms", y), "Change", full.names = TRUE)
    burn <- if (file.exists(mf)) values(f30(rast(mf), 2:4), mat = FALSE) else rep(0, ncell(S))
    lc <- if (length(lf)) rast(lf[1]) else NULL
    fire2 <- if (!is.null(lc)) values(f30(lc, 6:7), mat = FALSE) else 0; cut <- if (!is.null(lc)) values(f30(lc, 9), mat = FALSE) else rep(0, ncell(S))
    list(nl = values(nl, mat = FALSE), fire = pmax(burn, fire2, na.rm = TRUE), cut = cut) }, sf = sf, mnl = mnl, reg = reg)
  stopCluster(cl)
  N <- sapply(lay, function(x) x$nl[land]); Fi <- sapply(lay, function(x) x$fire[land]) >= 0.25; Cu <- sapply(lay, function(x) x$cut[land]) >= 0.25
  Fi[is.na(Fi)] <- FALSE; Cu[is.na(Cu)] <- FALSE; ny <- length(yrs)
  f <- matrix(N %in% FOR, nrow(N)); nat <- matrix(N %in% NAT, nrow(N))
  ev <- rep(NA_integer_, nrow(N)); flick <- rep(FALSE, nrow(N))
  for (t in 2:(ny - 1)) { c0 <- is.na(ev) & nat[, t - 1] & f[, t] & f[, t + 1]; if (!any(c0)) next
    sh <- rowMeans(f[c0, t:ny, drop = FALSE]) >= 2 / 3; i <- which(c0); ev[i[sh]] <- t; flick[i[!sh]] <- TRUE }
  e <- which(!is.na(ev)); t <- ev[e]
  before <- function(M) vapply(seq_along(e), function(j) any(M[e[j], seq_len(t[j] - 1)]), TRUE)
  fb <- before(Fi); cb <- before(Cu); wasF <- vapply(seq_along(e), function(j) any(f[e[j], seq_len(t[j] - 1)]), TRUE)
  D <- data.table(year = yrs[t], start = N[e, 1], kind = fifelse(fb, "after fire", fifelse(cb, "after harvest", fifelse(wasF, "no record: lost forest in the record", "no record: non-forest since 1985"))))
  cat(sprintf("\n== %s: %.0f kha of land; NLCD forest %.0f kha in 1985, %.0f kha in 2023; natural non-forest %.0f kha in 1985\n", lab, length(land) * ha / 1e3,
              sum(f[, 1]) * ha / 1e3, sum(f[, ny]) * ha / 1e3, sum(nat[, 1]) * ha / 1e3))
  cat(sprintf("   reforestation events 1986-2022 (first per cell): %.1f kha; failed the persistence test (flicker): %.1f kha\n", nrow(D) * ha / 1e3, sum(flick & is.na(ev)) * ha / 1e3))
  print(D[, .(kha = round(.N * ha / 1e3, 1), kha_per_yr = round(.N * ha / 1e3 / 37, 2)), by = kind][order(-kha)])
  cat("   no record, non-forest since 1985: by NLCD class in 1985 and by period of the event (kha)\n")
  x <- D[kind == "no record: non-forest since 1985"]
  if (nrow(x)) print(dcast(x[, .(kha = round(.N * ha / 1e3, 1)), by = .(NLCD_1985 = c(`31` = "Barren", `52` = "Shrub", `71` = "Grass", `95` = "Emergent wetland")[as.character(start)],
          period = cut(year, c(1985, 1995, 2005, 2015, 2023), labels = c("1986-95", "1996-2005", "2006-15", "2016-22")))], NLCD_1985 ~ period, value.var = "kha", fill = 0))
  y <- D[kind %like% "^no record" & year >= 2006, .N * ha / 1e3 / length(2006:2022)]
  cat(sprintf("   unrecorded reforestation 2006-2022: %.2f kha a year (%.3f%% of the 2005 natural non-forest a year)\n", y, 100 * y / (sum(nat[, 21]) * ha / 1e3))) }
