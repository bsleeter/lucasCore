suppressMessages(library(data.table)); options(width = 220)
x <- rbindlist(lapply(list.files("dev/wetland-change/rules", "-exitp.csv$", full.names = TRUE), fread))
BIN <- c("under 1", "1 to 5", "5 to 10", "10 to 20", "20 to 40", "40 or more"); x[, Bin := factor(Bin, BIN)]
INLAND <- c("Sierra Nevada reservoirs", "Great Salt Lake")
# share of a group's pixels at or over each line of mean partial water in the five land years after leaving water
over <- function(d, by) { t <- d[, .(Kha = sum(Kha)), by = c(by, "Bin")][, Tot := sum(Kha), by = by]
  r <- t[, .(Total = round(Tot[1], 2), Over5 = round(100 * sum(Kha[as.integer(Bin) >= 3]) / Tot[1]), Over10 = round(100 * sum(Kha[as.integer(Bin) >= 4]) / Tot[1]),
    Over20 = round(100 * sum(Kha[as.integer(Bin) >= 5]) / Tot[1]), Over40 = round(100 * sum(Kha[as.integer(Bin) >= 6]) / Tot[1])), by = by]; r[Total >= 0.05] }
cat("\n== % of water-to-land pixels with mean partial water at or over a line (next five land years); Total kha ==\n")
cat("\n-- coastal boxes together, by C-CAP 2021 class --\n"); print(over(x[Ccap != "None" & !Region %in% INLAND], "Ccap"))
cat("\n-- coastal boxes together, C-CAP class by side --\n"); print(over(x[Ccap != "None" & !Region %in% INLAND], c("Side", "Ccap"))[order(Side, Ccap)])
cat("\n-- each coastal box, C-CAP wetland against barren --\n"); print(over(x[Ccap %in% c("Wetland", "Barren") & !Region %in% INLAND], c("Region", "Ccap"))[order(Region, Ccap)])
cat("\n-- inland boxes by side and NLCD class four years after --\n"); print(over(x[Region %in% INLAND], c("Region", "Side", "Nlcd"))[order(Region, Side, Nlcd)])
cat("\n-- by the era the pixel left water (coastal, C-CAP wetland and barren; inland away from wetland) --\n")
print(over(x[Ccap %in% c("Wetland", "Barren") & !Region %in% INLAND], c("Ccap", "Era"))[order(Ccap, Era)]); print(over(x[Region %in% INLAND & Side == "Away from wetland"], c("Region", "Era"))[order(Region, Era)])
cat("\n-- away from wetland only (where the rule now says Barren): what a partial-water line would turn to wetland --\n")
print(over(x[Side == "Away from wetland"], c("Region"))[order(Region)])
