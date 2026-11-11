# Summary of p26-seed-source.R: return within 20 years by the share of own-type and of any live forest around each burned pixel.
# Usage: Rscript dev/fire/p26-seed-source-summary.R <out folder of p26-seed-source.R>
suppressMessages(library(data.table)); D <- fread(file.path(commandArgs(TRUE)[1], "seed-source.csv"))
D <- D[complete.cases(D[, .(any150, own150, any450, own450)])]; D[, y := as.integer(back20)]
D[, Sev := c(`3` = "Moderate", `4` = "High")[as.character(sev)]]; D[, Type := factor(ftype)]
cat(sprintf("Burned forest pixels: %d (%.1f kha); back to forest within 20 years: %.1f%%\n", nrow(D), nrow(D) * 0.09 / 1e3, 100 * mean(D$y)))
print(D[, .(kha = round(.N * 0.09 / 1e3, 1), back20_pct = round(100 * mean(y), 1)), by = Sev])
cat("\nMean share around burned pixels (live forest the year after the fire):\n")
print(D[, lapply(.SD, function(v) round(mean(v), 3)), .SDcols = c("any150", "own150", "any450", "own450")])
auc <- function(p, y) { r <- rank(p); n1 <- as.numeric(sum(y)); n0 <- as.numeric(length(y)) - n1; (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
fit <- function(f) { m <- glm(f, binomial, D); c(dev_expl_pct = round(100 * (1 - m$deviance / m$null.deviance), 2), AUC = round(auc(fitted(m), D$y), 3), AIC = round(AIC(m))) }
cat("\nReturn within 20 years, logistic fits (each share as a smooth: natural spline, 3 df):\n")
suppressMessages(library(splines))
M <- list(`severity + type only` = y ~ Sev + Type,
          `any 150 m` = y ~ Sev + Type + ns(any150, 3), `own 150 m` = y ~ Sev + Type + ns(own150, 3), `any + own 150 m` = y ~ Sev + Type + ns(any150, 3) + ns(own150, 3),
          `any 450 m` = y ~ Sev + Type + ns(any450, 3), `own 450 m` = y ~ Sev + Type + ns(own450, 3), `any + own 450 m` = y ~ Sev + Type + ns(any450, 3) + ns(own450, 3))
print(rbindlist(lapply(names(M), function(k) as.list(c(model = k, fit(M[[k]]))))))
cat("\nReturn within 20 years (%) by share bin (pixels in brackets):\n")
b <- function(v) cut(v, c(-Inf, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.8, Inf), right = FALSE)
x <- rbind(D[, .(pred = "any 450 m", bin = b(any450), y)], D[, .(pred = "own 450 m", bin = b(own450), y)],
           D[, .(pred = "any 150 m", bin = b(any150), y)], D[, .(pred = "own 150 m", bin = b(own150), y)])
print(dcast(x[, .(v = sprintf("%.1f (%s)", 100 * mean(y), format(.N, big.mark = ","))), by = .(pred, bin)], bin ~ pred, value.var = "v"))
cat("\nWhere the two disagree (450 m): any-forest share at least 0.25 above the own-type share:\n")
D[, gap := any450 - own450]
print(D[, .(kha = round(.N * 0.09 / 1e3, 1), back20_pct = round(100 * mean(y), 1), any = round(mean(any450), 2), own = round(mean(own450), 2)),
        by = .(group = fifelse(gap >= 0.25, "other types around (gap >= 0.25)", "mostly own type (gap < 0.25)"))])
cat("  same any-forest share, split by own-type share (any450 in 0.3-0.6):\n")
print(D[any450 >= 0.3 & any450 < 0.6, .(kha = round(.N * 0.09 / 1e3, 1), back20_pct = round(100 * mean(y), 1)), by = .(own_share = cut(own450 / any450, c(0, 0.25, 0.5, 0.75, 1.01), right = FALSE))][order(own_share)])
cat("\nBy forest type group (450 m): pixels, return %, mean any and own shares:\n")
print(D[, .(kha = round(.N * 0.09 / 1e3, 1), back20_pct = round(100 * mean(y), 1), any = round(mean(any450), 2), own = round(mean(own450), 2)), by = ftype][kha > 1][order(ftype)])
