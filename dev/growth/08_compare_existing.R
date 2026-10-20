# Compare stage 2 curves with the 68 existing fits (Calculate Growth Curves - Weibull.R, Data Sources/FIA/Growth Model/Fitted Models)
suppressPackageStartupMessages(library(data.table))
G <- "F:/lucas-master/Data Sources/FIA/Growth Model/Fitted Models/"
old <- rbindlist(lapply(list.files(G, "csv$", full.names = TRUE), function(f) fread(f, colClasses = c(Ecodivision = "character"))[, .(fortyp = TypeGroupCode, ecodiv = Ecodivision, age = Stand_Age_Years, old = Predicted_Volume)]))
new <- fread("F:/lucasCore/dev/libs/growth-curves.csv"); par <- fread("F:/lucasCore/dev/libs/growth-parameters.csv")
cw <- fread("F:/lucasCore/defaults/growth/forest-type-crosswalk.csv")
eco <- unique(fread("F:/lucas-master/Data Sources/FIA/EcoDivision_Strata.csv", colClasses = "character")[, .(ecodiv, StratumName)])
st <- fread("F:/lucasCore/defaults/stsim/stsim_Stratum.csv"); eco <- data.table(ecodiv = c(st$Name), sid = st$Id)
# map stsim names -> ecodiv codes and state class names -> FIA codes
codes <- fread("F:/lucas-master/Data Sources/FIA/EcoDivision_Strata.csv", colClasses = "character")
code_of <- setNames(codes$ecodiv, as.character(codes$StratumId))
new[, ecodiv := code_of[as.character(st$Id[match(StratumId, st$Name)])]]
new[, fortyp := cw$StateClassId[match(sub("^Forest: ", "", StateClassId), cw$StateClassName)]]
par[, ecodiv := code_of[as.character(st$Id[match(StratumId, st$Name)])]][, fortyp := cw$StateClassId[match(sub("^Forest: ", "", StateClassId), cw$StateClassName)]]
cmp <- merge(old[age %in% c(25, 50, 100, 200)], new[Age %in% c(25, 50, 100, 200), .(fortyp, ecodiv, age = Age, new = MerchantableVolume)], by = c("fortyp", "ecodiv", "age"))
cmp <- merge(cmp, par[, .(fortyp, ecodiv, Method, Plots)], by = c("fortyp", "ecodiv"))
cat("cells compared:", uniqueN(cmp[, .(fortyp, ecodiv)]), "(old fits not matched:", uniqueN(old[, .(fortyp, ecodiv)]) - uniqueN(cmp[, .(fortyp, ecodiv)]), ")\n")
print(unique(old[, .(fortyp, ecodiv)])[!cmp, on = c("fortyp", "ecodiv")])
cmp[, ratio := new / old]
print(cmp[old > 0, .(cells = .N, median_ratio = round(median(ratio), 3), p10 = round(quantile(ratio, .1), 3), p90 = round(quantile(ratio, .9), 3),
                     mean_old = round(mean(old), 1), mean_new = round(mean(new), 1)), by = age][order(age)])
cat("\nlargest differences at age 100:\n"); print(cmp[age == 100][order(-abs(log(ratio)))][1:12, .(fortyp, ecodiv, Method, Plots, old = round(old, 1), new = round(new, 1), ratio = round(ratio, 2))])
fwrite(cmp, "F:/lucasCore/dev/growth/out_exp8_compare_existing.csv")
