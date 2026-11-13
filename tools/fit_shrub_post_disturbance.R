# =============================================================================
# fit_shrub_post_disturbance.R - the shrub classes' post-disturbance settings from RCMAP cover after fire (to-do 57 step 7)
# =============================================================================
# How shrub cover comes back after fire, from MTBS and the RCMAP V8 cover time series (Data Source RcmapCoverFolder, the home's
# national copy: land-cover/rcmap-cover/<sagebrush|shrub>/rcmap_<component>_<year>.tif):
#   - fires: MTBS wildfires of 1986-2010 whose centre is in RCMAP's western US, up to FIRES per ecodivision, each over its perimeter's
#     box (at most 40 km a side); severity SEV (default high, 4; --severity=3,4 adds moderate: to-do 61 asks whether shrub fires reach
#     "high" in MTBS)
#   - class before the fire (mean cover of the three years before): sage family where sagebrush is at least 5% and at least half the
#     shrub cover; else chaparral where shrub is at least 10% in the Mediterranean ecodivisions, Non-sage where shrub is at least 10%
#     elsewhere; other pixels are left out
#   - loss: cover (sagebrush for the sage family, all shrub for the others) the year after the fire below half its pre-fire level
#   - return: the first year cover is back to at least RECOVER (default 0.5) of its pre-fire level two years running; a reburn at the
#     same severity before that ends the first-fire record; the record ends in 2024 (2025 the year after)
# Then, by class, the settings of src/post-disturbance.R as tools/fit_post_disturbance.R does for forest (Kaplan-Meier share back by
# years since the fire, each fire at most FIRE_CAP pixels; ReturnAgeMin, Window, ReturnProbability, ReburnConversion). The sage
# family's three classes share one fit (RCMAP cover does not separate native from invaded steppe). Writes dev/fire/
# shrub-post-disturbance-fit.csv; with --write replaces the shrub rows of defaults/transitions/post-disturbance-settings.csv.
# Usage: Rscript tools/fit_shrub_post_disturbance.R [--home=E:/lucasData] [--fires=60] [--severity=4] [--recover=0.5] [--cores=20] [--write]
# =============================================================================
suppressMessages({ library(terra); library(data.table); library(parallel) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub("^[^=]*=", "", m[1]) else d }
HOME <- opt("home", "E:/lucasData"); FIRES <- as.numeric(opt("fires", 60)); SEV <- as.integer(strsplit(opt("severity", "4"), ",")[[1]]); RECOVER <- as.numeric(opt("recover", 0.5))
CAP <- 500; MIN_EV <- 300; MIN_FIRES <- 5; MIN_RB <- 100; CORES <- as.numeric(opt("cores", 20))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
DS <- "F:/lucas-master/Data Sources"; YLAST <- 2024; MT <- 1986:2023; RY <- 1985:2025
rc <- file.path(HOME, "land-cover", "rcmap-cover"); sage_f <- setNames(file.path(rc, "sagebrush", sprintf("rcmap_sagebrush_%d.tif", RY)), RY)
shrub_f <- setNames(file.path(rc, "shrub", sprintf("rcmap_shrub_%d.tif", RY)), RY); mtbs_f <- setNames(file.path(DS, "MTBS", "Burn Severity", sprintf("mtbs_CONUS_%d.tif", MT)), MT)
miss <- c(sage_f, shrub_f)[!file.exists(c(sage_f, shrub_f))]; if (length(miss)) stop(sprintf("RCMAP cover missing (%d files, e.g. %s): run a Data Download of RcmapCoverFolder", length(miss), miss[1]))
eco_r <- rast(file.path(DS, "FIA", "Ecodivisions_30m.tif"))
en <- unique(fread(file.path(DS, "FIA", "EcoDivision_Strata.csv"))[, .(eco = as.integer(StratumId), Ecodivision = StratumName)], by = "eco"); en[eco == 2601, Ecodivision := "Mediterranean Mountains"]
MED <- c(260L, 2601L)

# ---- fires in RCMAP's extent ----------------------------------------------------------------------------------------------------
r0 <- rast(shrub_f[[1]]); pf <- sf::read_sf(file.path(DS, "MTBS", "Fire Perimeter", "mtbs_perims_DD.shp")); pf <- pf[pf$incid_type == "Wildfire" & pf$YEAR %in% 1986:2010, ]
pf <- sf::st_transform(sf::st_make_valid(pf), crs(r0)); ct <- suppressWarnings(sf::st_coordinates(sf::st_point_on_surface(pf)))
fires <- data.table(id = pf$event_id, year = as.integer(pf$YEAR), x = ct[, 1], y = ct[, 2])
bb <- t(vapply(seq_len(nrow(pf)), function(i) as.numeric(sf::st_bbox(pf[i, ])), numeric(4))); fires[, `:=`(xmin = bb[, 1], ymin = bb[, 2], xmax = bb[, 3], ymax = bb[, 4])]
e0 <- ext(r0); fires <- fires[x > e0$xmin & x < e0$xmax & y > e0$ymin & y < e0$ymax]
fires[, eco := as.integer(extract(eco_r, as.matrix(fires[, .(x, y)]))[, 1])]; fires <- fires[eco %in% en$eco]
set.seed(57); fs <- fires[, .SD[sample(.N, min(.N, FIRES))], by = eco]
cat(sprintf("%d MTBS wildfires 1986-2010 in RCMAP's extent; %d sampled (up to %g per ecodivision); severity %s; recovery to %.0f%% of pre-fire cover\n",
            nrow(fires), nrow(fs), FIRES, paste(SEV, collapse = ","), 100 * RECOVER))

one_fire <- function(i) {
  suppressMessages({ library(terra); library(data.table) }); terraOptions(progress = 0)
  f <- fs[i]; h <- 20000; e <- ext(max(f$xmin, f$x - h), min(f$xmax, f$x + h), max(f$ymin, f$y - h), min(f$ymax, f$y + h))
  g0 <- rast(shrub_f[[1]]); e <- align(e, g0, snap = "out"); g <- crop(g0, e)
  rd <- function(fl) { r <- rast(fl); levels(r) <- NULL; if (is.null(intersect(ext(r), e))) return(rep(NA_real_, ncell(g)))
    r <- crop(r, e, snap = "out", extend = TRUE); if (!compareGeom(r, g, stopOnError = FALSE)) r <- resample(r, g, method = "near"); as.numeric(values(r, mat = FALSE)) }
  y <- f$year; m0 <- rd(mtbs_f[[as.character(y)]]); burn <- which(m0 %in% SEV); if (!length(burn)) return(NULL)
  pre <- as.character((y - 3):(y - 1)); post <- as.character(y:2025)
  cov <- function(fl, yy) { v <- sapply(yy, function(k) rd(fl[[k]])[burn]); if (is.null(dim(v))) v <- matrix(v, nrow = length(burn)); v[v > 100] <- NA; v }
  sP <- rowMeans(cov(sage_f, pre), na.rm = TRUE); hP <- rowMeans(cov(shrub_f, pre), na.rm = TRUE)
  cls <- ifelse(!is.na(sP) & sP >= 5 & sP >= 0.5 * hP, "Sage family", ifelse(!is.na(hP) & hP >= 10, if (f$eco %in% MED) "Chaparral" else "Non-sage", NA_character_))
  k <- which(!is.na(cls)); if (!length(k)) return(NULL)
  sage <- cls[k] == "Sage family"; base <- ifelse(sage, sP[k], hP[k])
  S1 <- cov(sage_f, post)[k, , drop = FALSE]; H1 <- cov(shrub_f, post)[k, , drop = FALSE]; C <- S1; C[!sage, ] <- H1[!sage, ]
  loss <- C[, 2] < 0.5 * base; k <- k[loss %in% TRUE]; if (!length(k)) return(NULL)
  C <- C[loss %in% TRUE, , drop = FALSE]; base <- base[loss %in% TRUE]; cl <- cls[k]
  later <- as.character(intersect((y + 1):max(MT), MT)); MB <- if (length(later)) sapply(later, function(z) rd(mtbs_f[[z]])[burn[k]]) else NULL
  if (!is.null(MB) && is.null(dim(MB))) MB <- matrix(MB, nrow = length(k)); yrs <- as.integer(post)
  rbindlist(lapply(seq_along(k), function(p) { ok <- C[p, ] >= RECOVER * base[p]; ok[is.na(ok)] <- FALSE
    j <- which(ok[-length(ok)] & ok[-1]); j <- j[yrs[j] > y & yrs[j] <= YLAST]; bk <- if (length(j)) yrs[j[1]] else NA_integer_
    rb <- if (!is.null(MB)) { q <- which(MB[p, ] %in% SEV); if (length(q)) as.integer(later[q[1]]) else NA_integer_ } else NA_integer_
    back1 <- !is.na(bk) && (is.na(rb) || bk < rb); fe <- min(c(bk, rb, YLAST), na.rm = TRUE)
    bk2 <- if (!is.na(rb) && !back1) { j2 <- which(ok[-length(ok)] & ok[-1]); j2 <- j2[yrs[j2] > rb & yrs[j2] <= YLAST]; if (length(j2)) yrs[j2[1]] else NA_integer_ } else NA_integer_
    list(class = cl[p], T = fe - y, back = back1, rb = if (!is.na(rb) && !back1) rb - y else NA_integer_,
         T2 = if (!is.na(rb) && !back1) (if (!is.na(bk2)) bk2 else YLAST) - rb else NA_integer_, back2 = !is.na(bk2), base = base[p]) }))[, `:=`(fire = f$id, eco = f$eco, year = y)][] }
cl <- makeCluster(CORES); clusterExport(cl, c("fs", "sage_f", "shrub_f", "mtbs_f", "SEV", "RECOVER", "YLAST", "MT", "MED"))
t0 <- Sys.time(); D <- rbindlist(parLapply(cl, seq_len(nrow(fs)), one_fire)); stopCluster(cl)
cat(sprintf("%d burned shrub pixels that lost cover, in %d fires (%.1f min): %s\n", nrow(D), uniqueN(D$fire), as.numeric(difftime(Sys.time(), t0, units = "mins")),
            paste(D[, .N, by = class][, sprintf("%s %d", class, N)], collapse = ", ")))
D[, w := min(.N, CAP) / .N, by = fire]
km <- function(t, ev, w, tmax = 38) { s <- 1; n0 <- sum(w); out <- data.table(t = 0:tmax, R = 0, atrisk = 1)
  for (k in 1:tmax) { r <- sum(w[t >= k]); d <- sum(w[t == k & ev]); if (r > 0) s <- s * (1 - d / r); out[t == k, `:=`(R = 1 - s, atrisk = r / n0)] }
  out }
fit <- function(x) { if (nrow(x) < MIN_EV || uniqueN(x$fire) < MIN_FIRES) return(NULL)
  k <- km(x$T, x$back, x$w); kk <- k[atrisk >= 0.1]; tm <- max(kk$t); Rm <- kk[t == tm, R]
  a0 <- kk[R >= 0.02, min(t)]; if (!is.finite(a0)) a0 <- tm
  W <- kk[t >= a0 + 3 & Rm - R < 0.05, min(t)]; if (!is.finite(W)) W <- tm; W <- max(min(W, 40), a0 + 3)
  RW <- k[t == min(W, max(k$t)), R]; p <- 1 - (1 - RW)^(1 / (W - a0 + 1))
  rb <- x[!is.na(rb)]; conv <- if (nrow(rb) >= MIN_RB) { k2 <- km(rb$T2, rb$back2, rb$w, 25); round(1 - k2[t == min(15, max(t)), R], 2) } else NA_real_
  list(curve = k, row = data.table(Window = W, ReturnAgeMin = a0, ReturnProbability = round(p, 3), ReburnConversion = conv, BackAtWindow = round(RW, 2), Followed = tm,
                                   Events = nrow(x), Fires = uniqueN(x$fire), Reburned = nrow(rb), PreCover = round(stats::weighted.mean(x$base, x$w), 1))) }
F <- lapply(c(`Sage family` = "Sage family", Chaparral = "Chaparral", `Non-sage` = "Non-sage"), function(k) fit(D[class == k]))
options(width = 250); res <- rbindlist(lapply(names(F), function(k) if (is.null(F[[k]])) data.table(Class = k, Note = "too few events") else cbind(Class = k, F[[k]]$row)), fill = TRUE); print(res)
cur <- rbindlist(lapply(names(F), function(k) if (is.null(F[[k]])) NULL else F[[k]]$curve[, Class := k]))
fwrite(cur, file.path(pkg, "dev", "fire", "shrub-post-disturbance-fit.csv"))
print(dcast(cur[t %in% c(2, 5, 10, 15, 20, 25, 30)], Class ~ t, value.var = "R")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])
if ("--write" %in% a) {
  sp <- fread(file.path(pkg, "defaults", "transitions", "post-disturbance-settings.csv"), na.strings = "")
  map <- c(`Shrubland: Sage` = "Sage family", `Shrubland: Native Sage Steppe` = "Sage family", `Shrubland: Invaded Sage Steppe` = "Sage family", `Shrubland: Non-sage` = "Non-sage", `Shrubland: Chaparral` = "Chaparral")
  for (pc in names(map)) { r <- res[Class == map[[pc]]]; if (!nrow(r) || is.na(r$Window[1])) next
    sp[ParentClass == pc & is.na(Ecodivision), `:=`(Window = r$Window, ReturnAgeMin = r$ReturnAgeMin, ReturnProbability = r$ReturnProbability,
       ReburnConversion = if (is.na(r$ReburnConversion)) ReburnConversion else r$ReburnConversion,
       Note = sprintf("Fitted (tools/fit_shrub_post_disturbance.R, %s): RCMAP %s cover after MTBS severity %s fire 1986-2010, back to %.0f%% of pre-fire cover; %.0f%% back by year %d; %d pixels in %d fires%s",
                      format(Sys.Date()), if (map[[pc]] == "Sage family") "sagebrush" else "shrub", paste(SEV, collapse = ","), 100 * RECOVER, 100 * r$BackAtWindow, r$Window, r$Events, r$Fires,
                      if (map[[pc]] == "Sage family") "; one fit for the sage family (RCMAP cover does not separate native from invaded steppe)" else ""))] }
  fwrite(sp, file.path(pkg, "defaults", "transitions", "post-disturbance-settings.csv")); cat("post-disturbance-settings.csv: shrub rows replaced\n") }
