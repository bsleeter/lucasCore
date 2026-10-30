# =============================================================================
# 04-harvest-age-fia.R - to-do 34: stand age at harvest from FIA remeasurement, against the package's clearcut minimum ages
# =============================================================================
# CA, OR, WA, NV, ID. A cut = a condition whose current visit records cutting (TRTCD 10) with a treatment year inside the
# remeasurement interval, paired with the same CONDID at the plot's previous visit (PLOT.PREV_PLT_CN). Age at the cut = the previous
# visit's STDAGE + (treatment year - previous measurement year); type = the previous visit's forest type group; live basal area loss =
# 1 - BALIVE now / before: clearcut-like at >= 75%, partial 10-75%. Per type: counts and percentiles of age at the cut, in California
# and in all five states, by owner (private vs public); the share of clearcut-like cuts younger than today's AgeMin
# (defaults/transitions/pathways/harvest.csv). And option (b): culmination of mean annual increment of the P26 Build result's
# merchantable volume curves (age at maximum MAI, and the first age with MAI >= 95% of it, the NFMA rule), per type and ecodivision.
# Writes dev/harvest/out/harvest-age-fia.csv, harvest-age-cuts.csv, harvest-age-cmai.csv. Read-only (the P26 library is only read).
# Usage: Rscript dev/harvest/04-harvest-age-fia.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- "F:/lucasCore"; dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; out <- file.path(pkg, "dev/harvest/out"); dir.create(out, showWarnings = FALSE)
STATES <- c("CA", "OR", "WA", "NV", "ID")
norm <- function(x) sub("sgroup$", "group", gsub("[^a-z]", "", tolower(sub("^Forest: ", "", x))))   # "Other western softwoods group" = "Other Western Softwood Group"
grp <- fread(file.path(dm, "REFERENCE", "REF_FOREST_TYPE.csv"), select = c("VALUE", "TYPGRPCD"))
gnm <- fread(file.path(dm, "REFERENCE", "REF_FOREST_TYPE_GROUP.csv"), select = c("VALUE", "MEANING"))
hv <- fread(file.path(pkg, "defaults/transitions/pathways/harvest.csv"))[TransitionTypeId == "Forest Harvest: Forest Clearcut", .(Type = StateClassIdSource, AgeMin)]
hv[, key := norm(Type)]

cuts <- rbindlist(lapply(STATES, function(s) {
  pl <- fread(file.path(dm, sprintf("%s_PLOT.csv", s)), select = c("CN", "PREV_PLT_CN", "MEASYEAR"), colClasses = list(character = c("CN", "PREV_PLT_CN")))
  cd <- fread(file.path(dm, sprintf("%s_COND.csv", s)), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "STDAGE", "FORTYPCD", "OWNGRPCD", "BALIVE",
              paste0("TRTCD", 1:3), paste0("TRTYR", 1:3)), colClasses = list(character = "PLT_CN"))
  for (k in c(paste0("TRTCD", 1:3), paste0("TRTYR", 1:3), "STDAGE", "BALIVE")) set(cd, j = k, value = as.numeric(cd[[k]]))
  cd <- merge(cd, pl[, .(PLT_CN = CN, PREV_PLT_CN, MEASYEAR)], by = "PLT_CN")
  # the cutting year of each condition cut at this visit (the first TRTCD = 10 with a usable year)
  cd[, TRTYR := fcase(TRTCD1 %in% 10 & between(TRTYR1, 1900, 2100), as.numeric(TRTYR1), TRTCD2 %in% 10 & between(TRTYR2, 1900, 2100), as.numeric(TRTYR2),
                      TRTCD3 %in% 10 & between(TRTYR3, 1900, 2100), as.numeric(TRTYR3), default = NA_real_)]
  now <- cd[!is.na(TRTYR) & !is.na(PREV_PLT_CN) & nzchar(PREV_PLT_CN)]
  pre <- cd[COND_STATUS_CD == 1, .(PREV_PLT_CN = PLT_CN, CONDID, age0 = STDAGE, typ0 = FORTYPCD, own0 = OWNGRPCD, ba0 = BALIVE, y0 = MEASYEAR)]
  x <- merge(now[, .(PLT_CN, PREV_PLT_CN, CONDID, TRTYR, ba1 = BALIVE, y1 = MEASYEAR)], pre, by = c("PREV_PLT_CN", "CONDID"))
  x[TRTYR >= y0 & TRTYR <= y1 & !is.na(age0) & age0 >= 0 & !is.na(typ0)][, State := s][] }))
cuts[, age := age0 + (TRTYR - y0)]
cuts[, loss := fifelse(!is.na(ba0) & ba0 > 0, 1 - fifelse(is.na(ba1), 0, ba1) / ba0, NA_real_)]
cuts[, kind := fcase(loss >= 0.75, "clearcut-like", loss >= 0.10, "partial", default = "light")]
cuts[, owner := fifelse(own0 %in% 40, "private", "public")]
cuts <- merge(cuts, grp[, .(typ0 = VALUE, TYPGRPCD)], by = "typ0", all.x = TRUE)
cuts <- merge(cuts, gnm[, .(TYPGRPCD = VALUE, Group = MEANING)], by = "TYPGRPCD", all.x = TRUE)
cuts[, key := norm(Group)]; cuts <- merge(cuts, hv[, .(key, Type, AgeMin)], by = "key", all.x = TRUE)
cat(sprintf("%d cut conditions paired with their previous visit (%s); %d clearcut-like, %d partial; %d types without a package match: %s\n",
            nrow(cuts), paste(cuts[, .N, by = State][, sprintf("%s %d", State, N)], collapse = ", "), cuts[kind == "clearcut-like", .N], cuts[kind == "partial", .N],
            cuts[is.na(Type), uniqueN(Group)], paste(cuts[is.na(Type), unique(Group)], collapse = "; ")))
fwrite(cuts[, .(State, Type, Group, owner, kind, TRTYR, y0, y1, age0, age, ba0, ba1, loss)], file.path(out, "harvest-age-cuts.csv"))

q <- function(a, p) if (length(a)) as.numeric(quantile(a, p, type = 7)) else NA_real_
summ <- function(d) d[, .(n = .N, p10 = q(age, .1), p25 = q(age, .25), median = q(age, .5), p75 = q(age, .75)), by = .(Type, AgeMin)]
tab <- rbind(summ(cuts[kind == "clearcut-like" & State == "CA"])[, `:=`(Region = "CA", Cut = "clearcut-like")],
             summ(cuts[kind == "clearcut-like"])[, `:=`(Region = "West", Cut = "clearcut-like")],
             summ(cuts[kind == "partial" & State == "CA"])[, `:=`(Region = "CA", Cut = "partial")],
             summ(cuts[kind == "partial"])[, `:=`(Region = "West", Cut = "partial")])
below <- cuts[kind == "clearcut-like" & !is.na(AgeMin), .(below = mean(age < AgeMin)), by = .(Type, Region = fifelse(State == "CA", "CA", "other"))]
tab <- merge(tab, cuts[kind == "clearcut-like" & !is.na(AgeMin), .(BelowAgeMin = mean(age < AgeMin)), by = Type][, Region := "West"][, Cut := "clearcut-like"], by = c("Type", "Region", "Cut"), all.x = TRUE)
tab <- merge(tab, cuts[kind == "clearcut-like" & State == "CA" & !is.na(AgeMin), .(BelowAgeMin = mean(age < AgeMin)), by = Type][, Region := "CA"][, Cut := "clearcut-like"],
             by = c("Type", "Region", "Cut"), all.x = TRUE, suffixes = c("", ".ca"))
tab[is.na(BelowAgeMin), BelowAgeMin := BelowAgeMin.ca][, BelowAgeMin.ca := NULL]
own <- cuts[kind == "clearcut-like", .(n = .N, p10 = q(age, .1), median = q(age, .5)), by = .(Type, owner)]
fwrite(tab[order(Cut, Region, -n)], file.path(out, "harvest-age-fia.csv"))
options(width = 200)
cat("\nClearcut-like cuts (live basal area loss >= 75%): age at the cut, years\n"); print(tab[Cut == "clearcut-like" & n >= 5][order(Region, -n), .(Region, Type = sub("^Forest: ", "", Type), AgeMin, n, p10, p25, median, p75, BelowAgeMin = round(BelowAgeMin, 2))])
cat("\nPartial cuts (10-75% loss)\n"); print(tab[Cut == "partial" & n >= 5][order(Region, -n), .(Region, Type = sub("^Forest: ", "", Type), n, p10, p25, median, p75)])
cat("\nClearcut-like by owner (all five states)\n"); print(dcast(own[n >= 5], Type ~ owner, value.var = c("n", "p10", "median"))[order(-n_private)])

# ---- option (b): culmination of mean annual increment on the P26 Build result's merchantable volume curves ---------------------
suppressPackageStartupMessages(library(rsyncrosim))
L <- suppressWarnings(ssimLibrary("F:/lucasCore/dev/libs/LUCAS P26 Northern Sierra Nevada.ssim"))
sc <- as.data.table(scenario(L, summary = TRUE)); bid <- max(sc[IsResult == "Yes" & startsWith(Name, "P26 - Build"), ScenarioId])
vc <- as.data.table(datasheet(scenario(L, bid), "lucasCore_MerchantableVolumeCurve", lookupsAsFactors = FALSE))
cat(sprintf("\nCMAI from P26 Build result %d's merchantable volume curves (%d rows)\n", bid, nrow(vc)))
cm <- vc[Age > 0][order(StratumId, StateClassId, Age)][, mai := MerchantableVolume / Age][, .(CMAI = Age[which.max(mai)], NFMA95 = Age[which(mai >= 0.95 * max(mai))[1]],
         MaxMAI = round(max(mai), 2)), by = .(StratumId, Type = StateClassId)]
cm <- merge(cm, hv[, .(Type, AgeMin)], by = "Type", all.x = TRUE)
fwrite(cm, file.path(out, "harvest-age-cmai.csv")); print(cm[grepl("^Mediterranean", StratumId)][order(StratumId, Type), .(StratumId, Type = sub("^Forest: ", "", Type), AgeMin, CMAI, NFMA95, MaxMAI)])
