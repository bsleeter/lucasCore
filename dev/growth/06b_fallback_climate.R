# Experiment 6b: bias-corrected climate fallback for empty cells, using the chosen pooled model (A and k per ecodivision,
# shared c). Leave one ecodivision out for cells with n >= 100, as in experiment 6.
#   conus          the type group's CONUS-wide curve
#   clim_A         A from a weighted linear regression on ecodivision climate (z temperature, z log precipitation); k pooled
#   clim_Ak        A and log k both regressed on climate
#   sister_clim    the sister ecodivision's pooled A, k when it has >= 300 plots, else clim_Ak
suppressPackageStartupMessages({ library(data.table); library(parallel) })
source("F:/lucasCore/dev/growth/curves.R")
FORM <- "weibull_t10"
x <- readRDS("F:/lucasCore/dev/growth/fia_prepared.rds")[undisturbed & untreated & age_ok & vol_ok & latest & sc != 201]
clim <- fread("F:/lucasCore/dev/growth/out_ecodiv_climate.csv", colClasses = c(ecodiv = "character"))
clim[, `:=`(z_t = (mat - mean(mat)) / sd(mat), z_p = (log(map) - mean(log(map))) / sd(log(map)))]
sister_of <- function(e) if (startsWith(e, "M")) substring(e, 2) else paste0("M", e)
wb <- function(t, A, k, c) ifelse(t <= 10, 0, A * (1 - exp(-k * pmax(t - 10, 0)^c)))

fit_Ak <- function(d, p0, lambda = 0.01) { eco <- sort(unique(d$ecodiv)); ie <- match(d$ecodiv, eco); E <- length(eco); pen <- lambda * nrow(d) * var(d$vol)
  obj <- function(par) { A <- par[1:E]; k <- par[E + 1:E]; pr <- wb(d$stdage, A[ie], k[ie], par[2 * E + 1])
    sum((d$vol - pr)^2) + pen * (mean(((A - p0[["A"]]) / p0[["A"]])^2) + mean(log(k / p0[["k"]])^2)) }
  o <- optim(c(rep(p0[["A"]], E), rep(p0[["k"]], E), p0[["c"]]), obj, method = "L-BFGS-B", lower = c(rep(1, E), rep(1e-6, E), 0.1),
             upper = c(rep(5000, E), rep(1, E), 4), control = list(maxit = 5000))
  data.table(ecodiv = eco, A = o$par[1:E], k = o$par[E + 1:E], c = o$par[2 * E + 1], n = d[, .N, by = ecodiv][match(eco, ecodiv), N]) }

run_ftg <- function(g) { d <- x[sc == g]; cs <- d[, .N, by = ecodiv][N >= 100]$ecodiv; if (uniqueN(d$ecodiv) < 2) return(NULL)
  rbindlist(lapply(cs, function(e) { tr <- d[ecodiv != e]; te <- d[ecodiv == e]; if (nrow(tr) < 30) return(NULL)
    p0 <- fit_form(FORM, tr$stdage, tr$vol); m <- fit_Ak(tr, p0); m <- merge(m, clim, by = "ecodiv"); ce <- clim[ecodiv == e]
    sc_ <- function(pred) c(rmse = sqrt(mean((te$vol - pred)^2)), bias = mean(pred - te$vol))
    out <- list(conus = sc_(predict_form(FORM, p0, te$stdage)))
    if (nrow(m) >= 3) {
      fa <- lm(A ~ z_t + z_p, data = m, weights = n); Ae <- max(predict(fa, ce), 0.25 * min(m$A)); Ae <- min(Ae, 1.5 * max(m$A))
      fk <- lm(log(k) ~ z_t + z_p, data = m, weights = n); ke <- exp(predict(fk, ce))
      ke <- min(max(ke, min(m$k) / 1.5), max(m$k) * 1.5)
      kp <- exp(weighted.mean(log(m$k), m$n))
      out$clim_A <- sc_(wb(te$stdage, Ae, kp, m$c[1])); out$clim_Ak <- sc_(wb(te$stdage, Ae, ke, m$c[1]))
    } else out$clim_A <- out$clim_Ak <- out$conus
    s <- sister_of(e); ms <- m[ecodiv == s]
    out$sister_clim <- if (nrow(ms) && ms$n >= 300) sc_(wb(te$stdage, ms$A, ms$k, ms$c)) else out$clim_Ak
    data.table(sc = g, ecodiv = e, n = nrow(te), method = names(out), rmse = sapply(out, `[`, "rmse"), bias = sapply(out, `[`, "bias")) })) }

cl <- makeCluster(min(20, detectCores() - 2)); clusterExport(cl, c("x", "FORM", "FORMS", "fit_form", "predict_form", "clim", "sister_of", "wb", "fit_Ak"))
invisible(clusterEvalQ(cl, library(data.table)))
r <- rbindlist(parLapply(cl, sort(unique(x$sc)), run_ftg)); stopCluster(cl)
own <- fread("F:/lucasCore/dev/growth/out_exp6_fallback.csv")[method == "own", .(sc, ecodiv, own_rmse = rmse)]
r <- merge(r, own, by = c("sc", "ecodiv")); r[, rel := rmse / own_rmse - 1]
fwrite(r, "F:/lucasCore/dev/growth/out_exp6b_fallback.csv")
print(r[, .(cells = .N, rmse = round(sqrt(weighted.mean(rmse^2, n)), 1), bias = round(weighted.mean(bias, n), 1),
            median_excess_pct = round(100 * median(rel), 1), p90_excess_pct = round(100 * quantile(rel, .9), 1)), by = method][order(rmse)])
