# =============================================================================
# fit_post_disturbance.R - forest's post-disturbance settings by ecodivision (to-do 57 step 7), the P26 method on CONUS
# =============================================================================
# What NLCD shows after a stand-replacing fire in forest, from the national layers in F:/lucas-master/Data Sources:
#   - fires: MTBS perimeters, wildfires of 1986-2010 (13 or more years of record after each), up to FIRES per ecodivision (the
#     ecodivision of the fire's centre), each read over its perimeter's box (at most 40 km a side, around its centre)
#   - events: pixels NLCD shows as forest (41-43) the year before, MTBS high severity (4) in the fire year, and barren, shrub or grass
#     (31, 52, 71) that year or within two (stand-replacing as NLCD sees it, as tools/fit_reforestation_cutoff.R)
#   - return: the first year after the loss that NLCD shows forest two years running; a later high-severity reburn before that ends
#     the pixel's first-fire record (it then counts for the reburn); the record ends in 2024 (2025 is the year after)
# The share back by years since the fire is a Kaplan-Meier curve (censored at the record's end or a reburn), each fire counting as
# at most FIRE_CAP pixels. From it, the settings of src/post-disturbance.R:
#   ReturnAgeMin       the first year at least 2% are back
#   Window             the year after which the curve adds less than 5 percentage points, within the years at least 10% of the
#                      pixels are still followed; at least ReturnAgeMin + 3, at most 40
#   ReturnProbability  the yearly chance from ReturnAgeMin that gives the curve's share at Window: 1 - (1 - R(W))^(1 / (W - a + 1))
#   ReburnConversion   of the pixels reburned at high severity before returning, the share not back 20 years after the reburn (KM)
#   ShrubShare         of the pixels not back by Window (and followed that long), the share NLCD shows as shrub rather than grass
# An ecodivision short of MIN_EV events or MIN_FIRES fires takes its pair's (mountains <-> lowland), then its domain's, then CONUS's;
# the reburn and shrub shares, from fewer pixels, need MIN_RB reburned pixels, else CONUS's.
# Writes dev/fire/post-disturbance-fit.csv (the curves) and prints the settings; with --write replaces the Forest rows of
# defaults/transitions/post-disturbance-settings.csv (the shrub rows wait for RCMAP).
# Usage: Rscript tools/fit_post_disturbance.R [--fires=40] [--fire-cap=500] [--min-events=300] [--min-fires=5] [--cores=20] [--write]
# =============================================================================
suppressMessages({ library(terra); library(data.table); library(parallel) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) as.numeric(sub("^[^=]*=", "", m[1])) else d }
FIRES <- opt("fires", 40); CAP <- opt("fire-cap", 500); MIN_EV <- opt("min-events", 300); MIN_FIRES <- opt("min-fires", 5); MIN_RB <- 100; CORES <- opt("cores", 20)
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
DS <- "F:/lucas-master/Data Sources"; Y0 <- 1985; Y1 <- 2025; YLAST <- 2024; MT <- 1986:2023
nlcd_f <- setNames(vapply(Y0:Y1, function(y) list.files(file.path(DS, "NLCD", "Annual NLCD"), sprintf("^Annual_NLCD_LndCov_%d_CU_C1V.[.]tif$", y), full.names = TRUE)[1], ""), Y0:Y1)
mtbs_f <- setNames(file.path(DS, "MTBS", "Burn Severity", sprintf("mtbs_CONUS_%d.tif", MT)), MT)
stopifnot(all(file.exists(c(nlcd_f, mtbs_f))))
eco_r <- rast(file.path(DS, "FIA", "Ecodivisions_30m.tif"))
en <- unique(fread(file.path(DS, "FIA", "EcoDivision_Strata.csv"))[, .(eco = as.integer(StratumId), Ecodivision = StratumName)], by = "eco")
en[eco == 2601, Ecodivision := "Mediterranean Mountains"]

# ---- the fires: MTBS wildfires 1986-2010, their ecodivision, up to FIRES per ecodivision -------------------------------------------
pf <- sf::read_sf(file.path(DS, "MTBS", "Fire Perimeter", "mtbs_perims_DD.shp")); pf <- pf[pf$incid_type == "Wildfire" & pf$YEAR %in% 1986:2010, ]
pf <- sf::st_transform(sf::st_make_valid(pf), crs(eco_r)); ct <- suppressWarnings(sf::st_coordinates(sf::st_point_on_surface(pf)))
fires <- data.table(id = pf$event_id, year = as.integer(pf$YEAR), x = ct[, 1], y = ct[, 2], ac = as.numeric(pf$burnbndac))
bb <- t(vapply(seq_len(nrow(pf)), function(i) as.numeric(sf::st_bbox(pf[i, ])), numeric(4))); fires[, `:=`(xmin = bb[, 1], ymin = bb[, 2], xmax = bb[, 3], ymax = bb[, 4])]
fires[, eco := as.integer(extract(eco_r, as.matrix(fires[, .(x, y)]))[, 1])]; fires <- fires[eco %in% en$eco]
set.seed(57); fs <- fires[, .SD[sample(.N, min(.N, FIRES))], by = eco]
cat(sprintf("%d MTBS wildfires 1986-2010 in CONUS ecodivisions; %d sampled (up to %d per ecodivision)\n", nrow(fires), nrow(fs), FIRES))

# ---- per fire: events, return, reburn, the class at the end -----------------------------------------------------------------------
one_fire <- function(i) {
  suppressMessages({ library(terra); library(data.table) }); terraOptions(progress = 0)
  f <- fs[i]; h <- 20000; e <- ext(max(f$xmin, f$x - h), min(f$xmax, f$x + h), max(f$ymin, f$y - h), min(f$ymax, f$y + h))
  e <- ext(floor((e$xmin - 15) / 30) * 30 + 15, ceiling((e$xmax - 15) / 30) * 30 + 15, floor((e$ymin - 15) / 30) * 30 + 15, ceiling((e$ymax - 15) / 30) * 30 + 15)
  g <- rast(e, resolution = 30, crs = crs(rast(nlcd_f[[1]])))
  rd <- function(fl) { r <- rast(fl); levels(r) <- NULL; if (is.null(intersect(ext(r), e))) return(rep(NA_integer_, ncell(g)))
    r <- crop(r, e, snap = "near", extend = TRUE); if (ncell(r) != ncell(g)) r <- resample(r, g, method = "near"); as.integer(values(r, mat = FALSE)) }
  y <- f$year; ys <- as.character((y - 1):Y1); N <- vapply(ys, function(k) rd(nlcd_f[[k]]), integer(ncell(g)))
  if (is.null(dim(N))) return(NULL)
  m0 <- rd(mtbs_f[[as.character(y)]]); fo <- function(v) !is.na(v) & v >= 41 & v <= 43; nf <- function(v) v %in% c(31L, 52L, 71L)
  j0 <- 1L; jy <- 2L   # columns: y - 1, y, ...
  ev <- which(m0 %in% 4L & fo(N[, j0]) & (nf(N[, jy]) | nf(N[, jy + 1]) | nf(N[, jy + 2])))
  if (!length(ev)) return(NULL)
  later <- as.character(intersect((y + 1):max(MT), MT)); MB <- if (length(later)) vapply(later, function(k) rd(mtbs_f[[k]])[ev], integer(length(ev))) else NULL
  if (!is.null(MB) && is.null(dim(MB))) MB <- matrix(MB, nrow = length(ev))
  F <- fo(N[ev, , drop = FALSE]); dim(F) <- c(length(ev), ncol(N)); yrs <- as.integer(ys)
  first_back <- function(r, from) { k <- which(r[-length(r)] & r[-1]); k <- k[yrs[k] > from & yrs[k] <= YLAST]; if (length(k)) yrs[k[1]] else NA_integer_ }
  out <- rbindlist(lapply(seq_along(ev), function(p) { r <- F[p, ]; loss <- yrs[jy - 1 + which(!r[jy:(jy + 2)])[1]]
    rb <- if (!is.null(MB)) { k <- which(MB[p, ] %in% 4L); if (length(k)) as.integer(later[k[1]]) else NA_integer_ } else NA_integer_
    bk <- first_back(r, loss); first_end <- min(c(bk, rb, YLAST), na.rm = TRUE)
    back1 <- !is.na(bk) && (is.na(rb) || bk < rb)
    # after a reburn (not back before it): the first forest pair after the reburn's loss
    bk2 <- if (!is.na(rb) && !back1) first_back(r, rb) else NA_integer_
    list(T = first_end - y, back = back1, rb = if (!is.na(rb) && !back1) rb - y else NA_integer_, T2 = if (!is.na(rb) && !back1) (if (!is.na(bk2)) bk2 else YLAST) - rb else NA_integer_,
         back2 = !is.na(bk2), last = N[ev[p], ncol(N)]) }))
  out[, `:=`(fire = f$id, eco = f$eco, year = y)][] }
cl <- makeCluster(CORES); clusterExport(cl, c("fs", "nlcd_f", "mtbs_f", "Y1", "YLAST", "MT"))
t0 <- Sys.time(); D <- rbindlist(parLapply(cl, seq_len(nrow(fs)), one_fire)); stopCluster(cl)
cat(sprintf("%d high-severity forest loss pixels in %d fires (%.1f min)\n", nrow(D), uniqueN(D$fire), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
D[, w := min(.N, CAP) / .N, by = fire]

# ---- weighted Kaplan-Meier: share back by years since the fire -------------------------------------------------------------------
km <- function(t, ev, w, tmax = 40) { s <- 1; n0 <- sum(w); out <- data.table(t = 0:tmax, R = 0, atrisk = 1)
  for (k in 1:tmax) { r <- sum(w[t >= k]); d <- sum(w[t == k & ev]); if (r > 0) s <- s * (1 - d / r); out[t == k, `:=`(R = 1 - s, atrisk = r / n0)] }
  out }
fit <- function(x) { if (nrow(x) < MIN_EV || uniqueN(x$fire) < MIN_FIRES) return(NULL)
  k <- km(x$T, x$back, x$w); kk <- k[atrisk >= 0.1]; tm <- max(kk$t); Rm <- kk[t == tm, R]
  a0 <- kk[R >= 0.02, min(t)]; if (!is.finite(a0)) a0 <- tm
  W <- kk[t >= a0 + 3 & Rm - R < 0.05, min(t)]; if (!is.finite(W)) W <- tm; W <- max(min(W, 40), a0 + 3)
  RW <- k[t == min(W, max(k$t)), R]; p <- 1 - (1 - RW)^(1 / (W - a0 + 1))
  list(curve = k, ReturnAgeMin = a0, Window = W, ReturnProbability = round(p, 3), BackAtWindow = RW, Followed = tm, Events = nrow(x), Fires = uniqueN(x$fire)) }
fit_rb <- function(x) { r <- x[!is.na(rb)]; if (nrow(r) < MIN_RB) return(NULL); k <- km(r$T2, r$back2, r$w, 25); list(conv = round(1 - k[t == min(20, max(t)), R], 2), n = nrow(r)) }
fit_sh <- function(x, W) { s <- x[!back & T >= W & last %in% c(52L, 71L)]; if (nrow(s) < MIN_RB) return(NULL); list(share = round(s[, sum(w * (last == 52L)) / sum(w)], 2), n = nrow(s)) }
pair <- function(e) if (e >= 1000) e %/% 10 else e * 10 + 1; dom <- function(e) as.integer(substr(as.character(e), 1, 1)); D[, dm := dom(eco)]
CON <- fit(D); stopifnot(!is.null(CON)); CRB <- fit_rb(D); CSH <- fit_sh(D, CON$Window)
res <- rbindlist(lapply(c(NA, en$eco), function(e) {
  if (is.na(e)) { f <- CON; src <- "CONUS"; x <- D } else {
    f <- fit(D[eco == e]); src <- "own fires"; x <- D[eco == e]
    if (is.null(f)) { x <- D[eco %in% c(e, pair(e))]; f <- fit(x); src <- sprintf("with %s", en$Ecodivision[match(pair(e), en$eco)]) }
    if (is.null(f)) { x <- D[dm == dom(e)]; f <- fit(x); src <- sprintf("domain %d", dom(e)) }
    if (is.null(f)) { x <- D; f <- CON; src <- "CONUS" } }
  rb <- fit_rb(x) %||% CRB; sh <- fit_sh(x, f$Window) %||% CSH
  data.table(Ecodivision = if (is.na(e)) NA_character_ else en$Ecodivision[match(e, en$eco)], Window = f$Window, ReturnAgeMin = f$ReturnAgeMin, ReturnProbability = f$ReturnProbability,
             ReburnConversion = rb$conv, ShrubShare = sh$share, BackAtWindow = round(f$BackAtWindow, 2), Followed = f$Followed, Events = f$Events, Fires = f$Fires,
             OwnEvents = if (is.na(e)) nrow(D) else sum(D$eco == e), Source = src) }))
options(width = 250); print(res[, .(Ecodivision, Window, ReturnAgeMin, ReturnProbability, ReburnConversion, ShrubShare, BackAtWindow, Followed, Events, Fires, OwnEvents, Source)])
cur <- rbindlist(lapply(c(list(CONUS = D), split(D, by = "eco")), function(x) { f <- fit(x); if (is.null(f)) NULL else f$curve }), idcol = "Unit")
fwrite(cur, file.path(pkg, "dev", "fire", "post-disturbance-fit.csv"))
cat(sprintf("\nCONUS: back by 10 / 20 / 30 years %s; reburned pixels not back 20 years later %.0f%% (%d); non-returners shrub %.0f%%\n",
            paste(sprintf("%.0f%%", 100 * CON$curve[t %in% c(10, 20, 30), R]), collapse = " / "), 100 * CRB$conv, CRB$n, 100 * CSH$share))
if ("--write" %in% a) {
  st <- fread(file.path(pkg, "defaults", "transitions", "post-disturbance-settings.csv"), na.strings = "")
  new <- res[, .(ParentClass = "Forest", Ecodivision, Window, ReturnAgeMin, ReturnProbability, ReburnConversion, ShrubShare,
                 Note = sprintf("Fitted %s (tools/fit_post_disturbance.R, %s): MTBS high-severity forest loss 1986-2010 followed in NLCD; %.0f%% back by year %d; %d pixels in %d fires",
                                Source, format(Sys.Date()), 100 * BackAtWindow, Window, Events, Fires))]
  st <- rbind(new, st[ParentClass != "Forest"])
  fwrite(st, file.path(pkg, "defaults", "transitions", "post-disturbance-settings.csv")); cat("post-disturbance-settings.csv: Forest rows replaced\n") }
