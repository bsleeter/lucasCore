suppressMessages(library(data.table)); options(width = 230)
d <- "dev/wetland-change/rules"
y <- rbindlist(lapply(list.files(d, "-yearly.csv$", full.names = TRUE), fread)); f <- rbindlist(lapply(list.files(d, "-flips.csv$", full.names = TRUE), fread))
r2 <- function(x) if (is.numeric(x)) round(x, 2) else x
# split rules: one rule on the wetland side, another on the other side
split <- function(name, wet, oth) { a <- rbind(y[Rule == wet & Side == "Wetland"], y[Rule == oth & Side == "Other"]); b <- rbind(f[Rule == wet & Side == "Wetland"], f[Rule == oth & Side == "Other"])
  list(copy(a)[, Rule := name], copy(b)[, Rule := name]) }
sp <- list(split("Split: hold 5 wetland, 70/30 other", "Hold 5 years", "Two lines 70/30"), split("Split: hold 5 wetland, yearly other", "Hold 5 years", "Yearly 50"),
  split("Split: 80/20 wetland, 60/40 other", "Two lines 80/20", "Two lines 60/40"))
y <- rbind(y, rbindlist(lapply(sp, `[[`, 1))); f <- rbind(f, rbindlist(lapply(sp, `[[`, 2)))
yr <- y[Year %in% 1996:2021, .(WaterKha = sum(WaterKha), ToKha = sum(ToKha), FromKha = sum(FromKha), EqKha = sum(EqKha)), by = .(Region, Rule, Year)]
s <- yr[, .(Gross = sum(ToKha + FromKha), Net = abs(sum(ToKha - FromKha)), RangeShare = (max(WaterKha) - min(WaterKha)) / (max(EqKha) - min(EqKha)), Corr = cor(WaterKha, EqKha)), by = .(Region, Rule)]
s <- merge(s, f[, .(Once = sum(Once), More = sum(Twice + More)), by = .(Region, Rule)], by = c("Region", "Rule"))
cat("\n== Whole box by rule, 1996-2021 (kha) ==\n"); print(s[order(Region, Rule)][, lapply(.SD, r2)], nrows = 100)
cat("\n== Gross change by side (kha), 1996-2021 ==\n")
print(dcast(y[Year %in% 1996:2021 & !grepl("Split", Rule), .(Gross = sum(ToKha + FromKha)), by = .(Region, Side, Rule)], Region + Side ~ Rule, value.var = "Gross")[, lapply(.SD, r2)])
cat("\n== Area on each side (kha) and share of the swing in open-water area that sits on the other side ==\n")
print(y[Rule == "Yearly 50" & Year %in% 1996:2021, .(EqRange = max(EqKha) - min(EqKha), EqMean = mean(EqKha)), by = .(Region, Side)][, lapply(.SD, r2)])
