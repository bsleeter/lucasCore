# =============================================================================
# 15-projection-empirical.R - to-do 3: what the historical record implies for the empirical projection method
# =============================================================================
# The empirical method (stage 9) draws blocks of historical years and gives each rate unit the share of its eligible forest
# that had the event in the drawn year. Three things it needs are measured here from the decided rule's yearly record
# (08-rule-combined.R --write, rule-<tag>-by-group.csv: per year and forest type group, the eligible forest still open to the
# event and the area flagged):
#   1. the yearly rates by forest type group (the table stage 9 would draw from)
#   2. how long episodes last (year-to-year correlation, runs of high years), for the block length
#   3. how much the projected mean depends on the reference period, and what block length does to a projection
#      (block draws of --horizon years, --sims times: the total, its spread between iterations, and the worst five years)
# The first year of the record is left out: it also collects pixels that crossed the line earlier.
# Usage: Rscript dev/mortality/15-projection-empirical.R <rule-...-by-group.csv> [--horizon=77] [--sims=2000] [--blocks=1,3,5,10]
# =============================================================================
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- a[!grepl("^--", a)][1]; H <- as.integer(opt("horizon", 77)); NS <- as.integer(opt("sims", 2000)); BL <- as.integer(strsplit(opt("blocks", "1,3,5,10"), ",")[[1]]); options(width = 220); set.seed(1)
NAMES <- c(`180` = "Pinyon/juniper", `200` = "Douglas-fir", `220` = "Ponderosa pine", `240` = "Western white pine", `260` = "Fir/spruce/mtn hemlock", `280` = "Lodgepole pine", `340` = "Redwood", `360` = "Other western softwoods", `370` = "California mixed conifer")
d <- fread(f)[Year > min(Year)]; d[, name := fifelse(as.character(group) %in% names(NAMES), NAMES[as.character(group)], paste("group", group))]
cat(sprintf("%s: %d-%d, %d forest type groups\n", basename(f), min(d$Year), max(d$Year), uniqueN(d$group)))
all <- d[, .(forest_km2 = sum(forest_km2), flagged_km2 = sum(flagged_km2)), by = Year][, rate := 100 * flagged_km2 / forest_km2]

cat("\n===== 1. Yearly rate (% of the eligible forest still open to the event), by forest type group =====\n")
g <- d[, .(forest_km2 = round(mean(forest_km2)), mean_pct = round(100 * sum(flagged_km2) / sum(forest_km2), 3), median_pct = round(100 * median(flagged_km2 / forest_km2), 3), max_pct = round(100 * max(flagged_km2 / forest_km2), 2),
           max_year = Year[which.max(flagged_km2 / forest_km2)], total_flagged_km2 = round(sum(flagged_km2), 1), top5_years_share_pct = round(100 * sum(sort(flagged_km2, decreasing = TRUE)[1:5]) / sum(flagged_km2))), by = name][forest_km2 >= 20][order(-forest_km2)]
print(g)
cat(sprintf("all groups: mean %.3f%% a year, median %.3f%%, highest %.2f%% in %d; the five highest years hold %.0f%% of the area; cumulative over the record %.1f%% of the forest\n",
            100 * sum(all$flagged_km2) / sum(all$forest_km2), median(all$rate), max(all$rate), all$Year[which.max(all$rate)], 100 * sum(sort(all$flagged_km2, decreasing = TRUE)[1:5]) / sum(all$flagged_km2), sum(all$rate)))
cat("\nyearly rate, all groups (%):\n"); print(setNames(round(all$rate, 2), all$Year))

cat("\n===== 2. How long episodes last =====\n")
ac <- function(x, k) cor(head(x, -k), tail(x, -k)); cat("correlation of a year's rate with the rate k years later, all groups: ", paste(sprintf("k=%d %.2f", 1:6, vapply(1:6, function(k) ac(all$rate, k), 0)), collapse = "; "), "\n")
big <- g$name[1:min(3, nrow(g))]; for (n in big) { x <- d[name == n][order(Year), flagged_km2 / forest_km2]; cat(sprintf("  %s: %s\n", n, paste(sprintf("k=%d %.2f", 1:5, vapply(1:5, function(k) ac(x, k), 0)), collapse = "; "))) }
hi <- all$rate > 2 * median(all$rate); r <- rle(hi); runs <- data.table(len = r$lengths, hi = r$values, end = all$Year[cumsum(r$lengths)])[hi == TRUE][, start := end - len + 1]
cat(sprintf("years over twice the median rate: %d of %d, in %d runs: %s\n", sum(hi), length(hi), nrow(runs), paste(sprintf("%d-%d (%d yr)", runs$start, runs$end, runs$len), collapse = ", ")))

cat("\n===== 3a. The mean rate by reference period =====\n")
yr <- range(all$Year); per <- list(c(yr[1], yr[2]), c(yr[1], 2000), c(2001, 2010), c(2011, yr[2]), c(2001, yr[2]), c(yr[1], 2010), c(2003, yr[2]))
print(rbindlist(lapply(per, function(p) { x <- all[Year >= p[1] & Year <= p[2]]; data.table(period = sprintf("%d-%d", p[1], p[2]), years = nrow(x), mean_pct_per_year = round(100 * sum(x$flagged_km2) / sum(x$forest_km2), 3),
  km2_per_year = round(mean(x$flagged_km2), 1), over_horizon_pct = round(100 * (1 - (1 - sum(x$flagged_km2) / sum(x$forest_km2))^H), 1)) })))
cat(sprintf("(over_horizon: the share of the forest that would have the event once in %d years at that mean rate, each cell at most once)\n", H))

cat(sprintf("\n===== 3b. Block draws from the whole record: %d projection years, %d iterations =====\n", H, NS))
x <- all$rate; n <- length(x); h5 <- max(frollsum(x, 5), na.rm = TRUE)
sim <- function(b) { t(vapply(seq_len(NS), function(i) { s <- integer(0); while (length(s) < H) { st <- sample.int(n, 1); s <- c(s, ((st - 1 + 0:(b - 1)) %% n) + 1) }; v <- x[s[1:H]]
  c(total = sum(v), worst5 = max(frollsum(v, 5), na.rm = TRUE), years_high = sum(v > 2 * median(x))) }, numeric(3))) }
print(rbindlist(lapply(BL, function(b) { m <- sim(b); data.table(block_years = b, total_mean = round(mean(m[, 1]), 1), total_p05 = round(quantile(m[, 1], 0.05), 1), total_p95 = round(quantile(m[, 1], 0.95), 1),
  spread_cv_pct = round(100 * sd(m[, 1]) / mean(m[, 1]), 1), worst5yr_median = round(median(m[, 2]), 2), share_of_iterations_reaching_record_worst5_pct = round(100 * mean(m[, 2] >= 0.999 * h5), 1)) })))
cat(sprintf("totals are the summed yearly rates (%% of forest) over the %d years; the record's worst five consecutive years sum to %.2f%%. Blocks wrap from the last year to the first.\n", H, h5))
