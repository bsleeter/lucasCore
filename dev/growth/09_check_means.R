# Old vs new curves against observed mean plot volume in age bands (same filters as stage 2)
suppressPackageStartupMessages(library(data.table))
x <- readRDS("F:/lucasCore/dev/growth/fia_prepared.rds")[undisturbed & untreated & age_ok & vol_ok & latest]
cmp <- fread("F:/lucasCore/dev/growth/out_exp8_compare_existing.csv", colClasses = c(ecodiv = "character"))
bands <- data.table(age = c(25, 50, 100, 200), lo = c(20, 45, 90, 175), hi = c(30, 55, 110, 225))
obs <- rbindlist(lapply(seq_len(nrow(bands)), function(i) x[stdage >= bands$lo[i] & stdage <= bands$hi[i], .(obs = mean(vol), n = .N), by = .(fortyp = fortyp_grp, ecodiv)][, age := bands$age[i]]))
m <- merge(cmp, obs, by = c("fortyp", "ecodiv", "age"))[n >= 20]
print(m[, .(cells = .N, plots = sum(n), obs_mean = round(weighted.mean(obs, n), 1), old_bias_pct = round(100 * (weighted.mean(old, n) / weighted.mean(obs, n) - 1), 1),
            new_bias_pct = round(100 * (weighted.mean(new, n) / weighted.mean(obs, n) - 1), 1),
            old_closer = sum(abs(old - obs) < abs(new - obs))), by = age][order(age)])
cat("\nloblolly/shortleaf 230 and exotic hardwoods 230:\n"); print(m[(fortyp == 160 | fortyp == 990) & ecodiv == "230", .(fortyp, age, n, obs = round(obs, 1), old = round(old, 1), new = round(new, 1))])
