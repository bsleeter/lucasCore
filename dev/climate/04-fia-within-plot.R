# =============================================================================
# 04-fia-within-plot.R - within-plot design: the same plot's growth in its wetter vs drier remeasurement intervals
# =============================================================================
#   resid = beta * exp * (X - 1) + FE(plot) + FE(state x second-visit year)
# Plots with 2+ kept intervals only. Plot fixed effects remove everything persistent about the plot and its county (site, curve bias,
# survivor effect), so beta comes from how one plot's growth anomaly moves with its own interval climate. Placebo as in 03.
# =============================================================================
suppressPackageStartupMessages({ library(data.table) })
OUT <- "F:/lucasCore/dev/climate"
pr <- fread(file.path(OUT, "fia-pairs.csv")); cl <- fread(file.path(OUT, "county-climate.csv"))
pr[, GEOID := as.integer(sub("^([0-9]+)-.*$", "\\1", p)) * 1000 + as.integer(sub("^[0-9]+-[0-9]+-([0-9]+)-.*$", "\\1", p))]
pr[, resid := obs_rate - exp_rate][, id := .I]
iv <- pr[, .(Year = (invyr + 1):(invyr + dt)), by = .(id, GEOID)]
pl <- merge(iv, cl, by = c("GEOID", "Year"))[, .(miami_next = mean(miami), pratio_next = mean(pratio), tanom_next = mean(tanom), ny = .N), by = id]
pr <- merge(pr, pl, by = "id", all.x = TRUE); pr[ny != dt | is.na(ny), c("miami_next", "pratio_next", "tanom_next") := NA]
pr[, west := as.integer(substr(gsub("M", "", ecodiv), 1, 1)) >= 3]
# demean within plot and within state-year (alternating projections) instead of thousands of dummies
demean <- function(dd, cols, g1, g2, it = 30) { for (k in seq_len(it)) for (g in c(g1, g2)) dd[, (cols) := lapply(.SD, function(v) v - mean(v)), by = g, .SDcols = cols]; dd }
fit <- function(dd, v, label) {
  dd <- dd[!is.na(get(v))]; dd[, npl := .N, by = p]; dd <- dd[npl >= 2]
  dd[, z := if (grepl("tanom", v)) exp_rate * get(v) else exp_rate * (get(v) - 1)]
  # expected growth falls as the stand ages, so within a plot z moves with exp_rate as much as with X: control for exp_rate and
  # stand age so beta comes from the climate term only
  dd[, `:=`(sy = paste(statecd, invyr), e1 = exp_rate, a1 = age0, a2 = age0^2)]
  dd <- demean(dd[, .(p, sy, resid, z, e1, a1, a2)], c("resid", "z", "e1", "a1", "a2"), "p", "sy")
  m <- lm(resid ~ 0 + z + e1 + a1 + a2, dd); k <- uniqueN(dd$p) + uniqueN(dd$sy)
  se <- summary(m)$coef["z", 2] * sqrt((nrow(dd) - 1) / (nrow(dd) - 1 - k))   # degrees of freedom for the absorbed effects
  data.table(subset = label, index = v, pairs = nrow(dd), plots = uniqueN(dd$p), beta = round(coef(m)[["z"]], 2), se = round(se, 2)) }
sets <- list(CONUS = pr, East = pr[west == FALSE], West = pr[west == TRUE])
res <- rbindlist(lapply(names(sets), function(k) rbindlist(lapply(c("miami", "pratio", "tanom", "miami_next", "pratio_next", "tanom_next"), function(v) fit(copy(sets[[k]]), v, k)))))
print(dcast(res, index ~ subset, value.var = c("beta", "se")))
print(res[index == "miami", .(subset, pairs, plots)])
fwrite(res, file.path(OUT, "fia-within-plot.csv"))
