# Experiment 6: the curve for a cell with NO plots. Leave one ecodivision out for every cell with n >= 100: fit on the type
# group's other ecodivisions, predict the held-out cell's plots, compare with the cell's own (in-sample) fit.
#   conus     the type group's CONUS-wide curve (all other ecodivisions pooled)
#   sister    the paired ecodivision (260 <-> M260): its own fit when it has >= 100 plots, else conus
#   climate   pooled fit with an asymptote per ecodivision and shared shape; log(A) regressed on ecodivision climate
#             (PRISM 1991-2020 normals: mean temperature, log precipitation), weighted by plots; >= 3 ecodivisions, else conus
#   nearest   the climatically nearest ecodivision with >= 100 plots (standardised temperature and log precipitation): its own fit
suppressPackageStartupMessages({ library(data.table); library(parallel) })
source("F:/lucasCore/dev/growth/curves.R")
FORM <- "weibull_t10"; F <- FORMS[[FORM]]
x <- readRDS("F:/lucasCore/dev/growth/fia_prepared.rds")[undisturbed & untreated & age_ok & vol_ok & latest & sc != 201]

# ecodivision climate (cached): PRISM normals averaged over each ecodivision polygon
cf <- "F:/lucasCore/dev/growth/out_ecodiv_climate.csv"
if (!file.exists(cf)) { suppressPackageStartupMessages({ library(terra); library(sf) })
  pr <- "F:/lucas-master/Data Sources/Climate/prism/normals/"
  tm <- rast(Sys.glob(paste0(pr, "PRISM_tmean_30yr_normal_4kmM4_annual_bil/*.bil"))[1]); pp <- rast(Sys.glob(paste0(pr, "PRISM_ppt_30yr_normal_4kmM4_annual_bil/*.bil"))[1])
  eco <- vect(st_transform(read_sf("F:/lucas-master/Data Sources/FIA/EcoDivision_map/EcoDivisions_Dissolve.shp"), crs(tm)))
  cl0 <- data.table(ecodiv = eco$ecodiv, mat = terra::extract(tm, eco, fun = mean, na.rm = TRUE)[, 2], map = terra::extract(pp, eco, fun = mean, na.rm = TRUE)[, 2])
  cl0 <- cl0[, .(mat = mean(mat), map = mean(map)), by = ecodiv]; fwrite(cl0, cf) }
clim <- fread(cf, colClasses = c(ecodiv = "character")); clim[, `:=`(z_t = (mat - mean(mat)) / sd(mat), z_p = (log(map) - mean(log(map))) / sd(log(map)))]
print(clim)
sister_of <- function(e) if (startsWith(e, "M")) substring(e, 2) else paste0("M", e)

fit_shared_A <- function(d, p0) { eco <- sort(unique(d$ecodiv)); ie <- match(d$ecodiv, eco); E <- length(eco)
  obj <- function(par) { A <- par[1:E]; pr <- ifelse(d$stdage <= 10, 0, A[ie] * (1 - exp(-par[E + 1] * pmax(d$stdage - 10, 0)^par[E + 2]))); sum((d$vol - pr)^2) }
  o <- optim(c(rep(p0[["A"]], E), p0[["k"]], p0[["c"]]), obj, method = "L-BFGS-B", lower = c(rep(1, E), 1e-6, 0.1), upper = c(rep(5000, E), 1, 4), control = list(maxit = 5000))
  list(A = setNames(o$par[1:E], eco), k = o$par[E + 1], c = o$par[E + 2], n = d[, .N, by = ecodiv][match(eco, ecodiv), N]) }

run_ftg <- function(g) { d <- x[sc == g]; cs <- d[, .N, by = ecodiv][N >= 100]$ecodiv; if (uniqueN(d$ecodiv) < 2) return(NULL)
  rbindlist(lapply(cs, function(e) { tr <- d[ecodiv != e]; te <- d[ecodiv == e]; if (nrow(tr) < 30) return(NULL)
    p0 <- fit_form(FORM, tr$stdage, tr$vol); own <- fit_form(FORM, te$stdage, te$vol)
    sc_ <- function(pred) c(rmse = sqrt(mean((te$vol - pred)^2)), bias = mean(pred - te$vol))
    out <- list(conus = sc_(predict_form(FORM, p0, te$stdage)), own = sc_(predict_form(FORM, own, te$stdage)))
    s <- sister_of(e); ts <- tr[ecodiv == s]
    out$sister <- if (nrow(ts) >= 100) sc_(predict_form(FORM, fit_form(FORM, ts$stdage, ts$vol), te$stdage)) else out$conus
    m <- fit_shared_A(tr, p0); cd <- clim[match(names(m$A), ecodiv)]
    out$climate <- if (length(m$A) >= 3) { fit <- lm(log(m$A) ~ cd$z_t + cd$z_p, weights = m$n)
      ce <- clim[ecodiv == e]; Ae <- exp(sum(coef(fit) * c(1, ce$z_t, ce$z_p))); Ae <- min(Ae, 2 * max(m$A))
      sc_(ifelse(te$stdage <= 10, 0, Ae * (1 - exp(-m$k * pmax(te$stdage - 10, 0)^m$c)))) } else out$conus
    big <- tr[, .N, by = ecodiv][N >= 100]$ecodiv
    out$nearest <- if (length(big)) { cb <- clim[ecodiv %in% big]; ce <- clim[ecodiv == e]; nb <- cb$ecodiv[which.min((cb$z_t - ce$z_t)^2 + (cb$z_p - ce$z_p)^2)]
      tn <- tr[ecodiv == nb]; sc_(predict_form(FORM, fit_form(FORM, tn$stdage, tn$vol), te$stdage)) } else out$conus
    data.table(sc = g, ecodiv = e, n = nrow(te), method = names(out), rmse = sapply(out, `[`, "rmse"), bias = sapply(out, `[`, "bias")) })) }

cl <- makeCluster(min(20, detectCores() - 2)); clusterExport(cl, c("x", "FORM", "F", "FORMS", "fit_form", "predict_form", "clim", "sister_of", "fit_shared_A"))
invisible(clusterEvalQ(cl, library(data.table)))
r <- rbindlist(parLapply(cl, sort(unique(x$sc)), run_ftg)); stopCluster(cl)
fwrite(r, "F:/lucasCore/dev/growth/out_exp6_fallback.csv")
s <- r[, .(cells = .N, rmse = sqrt(weighted.mean(rmse^2, n)), bias = weighted.mean(bias, n)), by = method]
w <- r[method != "own", .SD[which.min(rmse)], by = .(sc, ecodiv)][, .N, by = method]; s[w, best_in_cells := i.N, on = "method"]
r[, rel := rmse / rmse[method == "own"] - 1, by = .(sc, ecodiv)]
s[r[, .(median_excess_pct = round(100 * median(rel), 1), p90_excess_pct = round(100 * quantile(rel, .9), 1)), by = method], on = "method", `:=`(median_excess_pct = i.median_excess_pct, p90_excess_pct = i.p90_excess_pct)]
print(s[order(rmse)])
