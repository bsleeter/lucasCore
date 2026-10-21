# =============================================================================
# 03-fia-growth-climate-fe.R - the 02 fit with fixed effects that remove region-period confounding, plus a placebo
# =============================================================================
#   resid = beta * exp * (X - 1) + FE(ecodivision x forest type) + FE(state x second-visit year)
# beta then comes only from differences between counties' interval climate within a state and measurement year. Placebo: X from
# the FOLLOWING interval (years after the second visit), which cannot have caused the growth: its beta should be about 0.
# =============================================================================
suppressPackageStartupMessages(library(data.table))
OUT <- "F:/lucasCore/dev/climate"
pr <- fread(file.path(OUT, "fia-pairs.csv")); cl <- fread(file.path(OUT, "county-climate.csv"))
pr[, GEOID := as.integer(sub("^([0-9]+)-[0-9]+-([0-9]+)-.*$", "\\1", p)) * 1000 + as.integer(sub("^[0-9]+-[0-9]+-([0-9]+)-.*$", "\\1", p))]
pr[, resid := obs_rate - exp_rate][, id := .I]
# placebo climate: the dt years after the second visit
iv <- pr[, .(Year = (invyr + 1):(invyr + dt)), by = .(id, GEOID)]
pl <- merge(iv, cl, by = c("GEOID", "Year"))[, .(miami_next = mean(miami), pratio_next = mean(pratio), tanom_next = mean(tanom), ny = .N), by = id]
pr <- merge(pr, pl, by = "id", all.x = TRUE); pr[ny != dt, c("miami_next", "pratio_next", "tanom_next") := NA]
pr[, `:=`(fe1 = paste(ecodiv, sc_name), fe2 = paste(statecd, invyr), west = as.integer(substr(gsub("M", "", ecodiv), 1, 1)) >= 3)]
z_of <- function(dd, v) if (grepl("tanom", v)) dd$exp_rate * dd[[v]] else dd$exp_rate * (dd[[v]] - 1)
fit <- function(dd, v, label) { dd <- dd[!is.na(get(v))]; dd[, z := z_of(dd, v)]
  m <- lm(resid ~ z + factor(fe1) + factor(fe2), dd); s <- summary(m)$coef["z", ]
  data.table(subset = label, index = v, n = nrow(dd), beta = round(s[1], 2), se = round(s[2], 2)) }
sets <- list(CONUS = pr, East = pr[west == FALSE], West = pr[west == TRUE])
res <- rbindlist(lapply(names(sets), function(k) rbindlist(lapply(c("miami", "pratio", "tanom", "miami_next", "pratio_next", "tanom_next"), function(v) fit(copy(sets[[k]]), v, k)))))
print(dcast(res, index ~ subset, value.var = c("beta", "se")))
cat("\nn:", paste(res[index == "miami", paste(subset, n)], collapse = ", "), "\n(tanom per degree C)\n")
fwrite(res, file.path(OUT, "fia-growth-climate-fe.csv"))
