suppressMessages(library(data.table)); options(width = 230)
d <- "dev/wetland-change/drift"; args <- commandArgs(trailingOnly = TRUE)
s <- rbindlist(lapply(list.files(d, "-series.csv$", full.names = TRUE), fread)); tm <- rbindlist(lapply(list.files(d, "-timing.csv$", full.names = TRUE), fread))
era <- function(y) cut(y, c(1993, 1998, 2002, 2012, 2021, 2025), c("1994-98 L5", "1999-02 L5+L7", "2003-12 L5+L7 gaps", "2013-21 L7+L8", "2022-25 L8+L9"))
s[, Era := era(Year)]; r1 <- function(x) if (is.numeric(x)) round(x, 1) else x
cat("\n== Clear looks per year, by era ==\n"); print(dcast(s[Set == "Unchanged other land", .(Obs = mean(Obs)), by = .(Region, Era)], Region ~ Era, value.var = "Obs")[, lapply(.SD, r1)])
for (v in c("Open", "Partial")) for (st in c("Unchanged water", "Unchanged marsh", "Unchanged other land", "Unchanged barren")) {
  cat("\n==", v, "water share (%),", st, ", by era ==\n")
  print(dcast(s[Set == st & Kha > 0.5, .(x = mean(get(v))), by = .(Region, Era)], Region ~ Era, value.var = "x")[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)]) }
cat("\n== Louisiana, year by year: open share of unchanged marsh, C-CAP loss cells and DSWE loss cells ==\n")
print(dcast(s[grepl("Louisiana", Region) & Set %in% c("Unchanged marsh", "C-CAP marsh loss", "DSWE marsh loss")], Year ~ Region + Set, value.var = "Open")[, lapply(.SD, r1)])
cat("\n== Year the DSWE marsh loss happened (kha; last year below the 50% line) ==\n")
print(dcast(tm, Year ~ Region, value.var = "Kha", fill = 0)[, lapply(.SD, function(x) round(x, 2))])
if (length(args)) { g <- fread(args[1]); setnames(g, trimws(names(g))); g <- g[, .(Msl = mean(as.numeric(MSL), na.rm = TRUE), n = sum(!is.na(as.numeric(MSL)))), by = Year][n >= 10]
  x <- merge(s[Region == "Louisiana delta plain" & Set %in% c("Unchanged marsh", "Unchanged water", "Unchanged other land")], g, by = "Year")
  cat("\n== Delta plain against Grand Isle yearly mean sea level (m, station datum MSL) ==\n")
  print(g[, .(Year, Msl = round(Msl, 3))][Year %in% c(1994, 2000, 2005, 2010, 2015, 2020, 2024)])
  cat(sprintf("Sea level trend %.1f mm/yr\n", 1000 * coef(lm(Msl ~ Year, g))[2]))
  dt <- function(y, t) resid(lm(y ~ t))
  print(x[, .(CorrOpen = cor(Open, Msl), CorrOpenDetrended = cor(dt(Open, Year), dt(Msl, Year)), CorrTotalDetrended = cor(dt(Open + Partial, Year), dt(Msl, Year)),
    OpenPerMetre = coef(lm(Open ~ Msl))[2], OpenTrendPerDecade = 10 * coef(lm(Open ~ Year))[2], OpenTrendGivenSeaLevel = 10 * coef(lm(Open ~ Year + Msl))[2]), by = Set][, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)]) }
