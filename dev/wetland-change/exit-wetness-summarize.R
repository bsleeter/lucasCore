suppressMessages(library(data.table)); options(width = 220)
x <- rbindlist(lapply(list.files("dev/wetland-change/rules", "-exit.csv$", full.names = TRUE), fread))
BIN <- c("under 1", "1 to 5", "5 to 20", "20 to 50", "50 or more"); x[, Bin := factor(Bin, BIN)]
tab <- function(d, by) { t <- dcast(d[, .(Kha = sum(Kha)), by = c(by, "Bin")], as.formula(paste(paste(by, collapse = " + "), "~ Bin")), value.var = "Kha", fill = 0)
  t[, Total := rowSums(.SD), .SDcols = intersect(BIN, names(t))]; b <- intersect(BIN, names(t)); t[, (b) := lapply(.SD, function(v) round(100 * v / Total)), .SDcols = b]; t[, Total := round(Total, 2)]; t[Total >= 0.05] }
cat("\n== Share (%) of water-to-land pixels by mean open water over the next five land years; Total in kha ==\n")
cat("\n-- by region and side --\n"); print(tab(x, c("Region", "Side")), nrows = 100)
cat("\n-- by C-CAP 2021 class (coastal boxes where C-CAP maps the pixel) --\n"); print(tab(x[Ccap != "None"], c("Region", "Ccap")), nrows = 100)
cat("\n-- by NLCD class four years after --\n"); print(tab(x, c("Region", "Nlcd")), nrows = 100)
cat("\n-- all coastal boxes together, by C-CAP class --\n"); print(tab(x[Ccap != "None" & !Region %in% c("Sierra Nevada reservoirs", "Great Salt Lake")], "Ccap"))
cat("\n-- mean years on land in the five-year window --\n"); print(x[, .(LandYears = round(weighted.mean(MeanLandYears, Kha), 2)), by = .(Region, Side)])
