# =============================================================================
# make_tree_ring_coefficients.R - defaults/climate/tree-ring-coefficients.csv from the ITRDB chronologies and annual PRISM
# =============================================================================
# Runs dev/climate/05-itrdb-parse.R (site table and ring-width series) and dev/climate/07-itrdb-full-period.R (per-site fits of the
# standard ring-width index on PRISM, 1895-2023, pooled by ecodivision with a random-effects mean), then writes one row per FIA
# ecodivision:
#   multiplier = 1 + PrecipCoef * (P / P normal - 1) + PrecipLagCoef * (P last year / P normal - 1) + TempCoef * (T - T normal)
# Ecodivisions with fewer than MIN_SITES sites take the pooled CONUS coefficients. Inputs: Data Sources/ITRDB/chronologies (NOAA
# NCEI ITRDB, CONUS base sites) and Data Sources/Climate/prism/annual-us25m (PRISM current release).
# Usage: Rscript tools/make_tree_ring_coefficients.R [--refit]   (without --refit, reuses dev/climate/itrdb-full-site-fits.csv)
# =============================================================================
suppressPackageStartupMessages(library(data.table))
MIN_SITES <- 10
if ("--refit" %in% commandArgs(TRUE) || !file.exists("dev/climate/itrdb-full-site-fits.csv"))
  for (s in c("dev/climate/05-itrdb-parse.R", "dev/climate/07-itrdb-full-period.R")) { cat("== running", s, "\n"); source(s, local = new.env()) }
st <- fread("dev/climate/itrdb-full-site-fits.csv")[nzchar(ecodiv)]
dl <- function(est, se) { w <- 1 / se^2; m <- sum(w * est) / sum(w); Q <- sum(w * (est - m)^2); k <- length(est)
  tau2 <- max(0, (Q - (k - 1)) / (sum(w) - sum(w^2) / sum(w))); ws <- 1 / (se^2 + tau2); sum(ws * est) / sum(ws) }
co <- function(s) data.table(PrecipCoef = dl(s$bp, s$bp_se), PrecipLagCoef = dl(s$bl, s$bl_se), TempCoef = dl(s$bt, s$bt_se), MiamiBeta = dl(s$beta, s$beta_se))
all <- co(st)
# the package's stratum list (FIA/EcoDivision_Strata.csv has a stray "M260 = Mediterranean" row)
eco <- fread("defaults/stsim/stsim_Stratum.csv")
out <- rbindlist(lapply(seq_len(nrow(eco)), function(i) { e <- eco$Name[i]; s <- st[ecodiv == e]
  if (nrow(s) >= MIN_SITES) cbind(data.table(StratumId = e, Id = eco$Id[i], Sites = nrow(s), Source = "ecodivision"), co(s))
  else cbind(data.table(StratumId = e, Id = eco$Id[i], Sites = nrow(s), Source = "CONUS pooled"), all) }))
num <- c("PrecipCoef", "PrecipLagCoef", "TempCoef", "MiamiBeta"); out[, (num) := lapply(.SD, round, 4), .SDcols = num]
fwrite(out, "defaults/climate/tree-ring-coefficients.csv"); print(out)
