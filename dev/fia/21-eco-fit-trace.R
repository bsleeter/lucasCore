# =============================================================================
# 21-eco-fit-trace.R - rerun stage 3's ecodivision fit for M330 (test library inputs) with a trace of each block step, to see where the
# litter and fine woody debris multipliers go to 20. Read-only.
# =============================================================================
source("F:/lucasCore/dev/fia/20-one-cell-loss.R", echo = FALSE)
ri_def <- fread(file.path(pkg, "defaults/spinup/return-interval.csv"))
fr <- snag_fall_rates(dw, cw)
rows <- dat$obs[ecodiv == "M330", .(mplots = sum(n)), by = sc][mplots >= 30]
rows[, StateClass := cw$StateClass[match(sc, cw$StateClassId)]][, `:=`(Stratum = "Temperate Steppe Mountains", ecodiv = "M330", temp = k$temp)]
rows <- rows[StateClass %in% cc[Stratum == "Temperate Steppe Mountains", unique(StateClass)]]
rows[, ri := as.integer(round(median(as.numeric(ri_def$ReturnInterval))))]
rows[, snag_fall := fr$cell[rows, on = c("sc", "ecodiv"), rate]][is.na(snag_fall), snag_fall := fr$type[.SD, on = "sc", rate]]
print(rows)
# the package's fit (pool by pool, flow order) on these rows, and each pool's prediction against the measurement
t0 <- Sys.time(); m <- cal_fit_measured(rows, ctx, dat); cat(sprintf("\nfit %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
print(cbind(rows[, .(type = substr(StateClass, 9, 32), mplots)], m[, lapply(.SD, function(v) round(v, 3))]))
cat(sprintf("misfit CBM %.0f -> fitted %.0f\n", sum(m$loss0), sum(m$loss1)))
pred <- rbindlist(lapply(seq_len(nrow(rows)), function(i) { S <- cal_setup(rows[i], ctx); d <- cal_dom(S, ctx$fo, as.list(unlist(m[i, ..MEAS_MULT])), 0)
  sim <- sapply(MEAS_SIM, function(p) rowSums(d[, p, drop = FALSE])); a <- dat$ages[sc == rows$sc[i] & ecodiv == "M330"]
  o <- dat$obs[sc == rows$sc[i] & ecodiv == "M330"]; w <- function(v) sum(o$n * v) / sum(o$n)
  data.table(type = substr(rows$StateClass[i], 9, 32), n = sum(o$n), pool = MEAS_POOLS, measured = sapply(MEAS_POOLS, function(p) w(o[[p]])),
             model = sapply(MEAS_POOLS, function(p) sum(a$N * sim[a$stdage + 1, p]) / sum(a$N))) }))
print(dcast(pred[, .(type, n, pool, v = sprintf("%.1f / %.1f", measured, model))], type + n ~ pool, value.var = "v")[order(-n)])
