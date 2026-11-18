# =============================================================================
# unit-stand-age.R - stand age where the age map cannot know it, and the Stand Age Options (src/stand-age.R; stage 5)
# =============================================================================
# Plain R, made-up cells, no SyncroSim. Checks the options (defaults, labels and numbers, bad values), the Unknown Ages table, the
# percentiles of the unburned forest (own type, the ecodivision's when a type has too few cells), and the order of the rules of
# age_assign: raster, forest type value, earlier age map, percentile, the age map.
# Usage: Rscript tests/unit-stand-age.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "stand-age.R"))
ok <- 0; bad <- 0
expect <- function(what, cond) { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, "\n") } }
err <- function(e) inherits(try(e, silent = TRUE), "try-error")

# ---- options ------------------------------------------------------------------------------------------------------------------
o <- age_options(data.table())
expect("options: an empty sheet is the centre pixel, estimate unknown ages, the 75th percentile, no raster", o$aggregate == "centre" && o$unknown == "default" && o$percentile == 75 && is.na(o$raster) && is.na(o$raster_year))
o <- age_options(data.table(Aggregation = 2L, UnknownRule = 2L, UnknownPercentile = 50L, AgeRasterFile = "x.tif", AgeRasterYear = 1987L))
expect("options: numbers", o$aggregate == "mean" && o$unknown == "source" && o$percentile == 50 && o$raster == "x.tif" && o$raster_year == 1987L)
o <- age_options(data.table(Aggregation = "Mean of the cell's pixels", UnknownRule = "Keep the age map's value", UnknownPercentile = NA, AgeRasterFile = NA))
expect("options: the list labels rsyncrosim gives", o$aggregate == "mean" && o$unknown == "source" && o$percentile == 75 && is.na(o$raster))
expect("options: an unknown choice and a percentile out of range are errors", err(age_options(data.table(Aggregation = "Median"))) && err(age_options(data.table(UnknownPercentile = 100L))))
px <- xml2::read_xml(file.path(pkg, "package.xml")); f1 <- function(k) xml2::xml_attr(xml2::xml_find_first(px, sprintf("//dataSheet[@name='StandAgeOptions']/column[@name='%s']", k)), "formula1")
lab <- function(v) paste(sprintf("%d:%s", seq_along(v), v), collapse = "|")
expect("package.xml: the two lists' labels are the ones the code reads", identical(f1("Aggregation"), lab(AGE_AGGREGATION)) && identical(f1("UnknownRule"), lab(AGE_UNKNOWN)))

# ---- the Unknown Ages table ---------------------------------------------------------------------------------------------------
tt <- age_type_table(data.table(StratumId = c(NA, "Marine", ""), StateClassId = c("Forest: A", "Forest: A", "Forest: B"), Age = c(250, 180, 120)))
expect("type table: a blank ecodivision is every ecodivision", nrow(tt) == 3 && sum(is.na(tt$StratumId)) == 2)
expect("type table: empty gives no rows", nrow(age_type_table(data.frame())) == 0)
expect("type table: a missing age, an age out of range and a duplicate are errors", err(age_type_table(data.table(StateClassId = "Forest: A", Age = NA))) &&
       err(age_type_table(data.table(StateClassId = "Forest: A", Age = 0))) && err(age_type_table(data.table(StateClassId = c("Forest: A", "Forest: A"), Age = c(100, 200)))))

# ---- percentiles of the unburned forest -----------------------------------------------------------------------------------------
set.seed(1); n <- 400
eco <- rep(c("Marine", "Prairie"), each = n / 2); cls <- rep(c("Forest: A", "Forest: B", "Forest: A", "Forest: C"), times = c(150, 50, 190, 10)); age <- c(1:150, 201:250, 1:190, 291:300)
p <- age_percentiles(eco, cls, age, rep(TRUE, n), 75)
g <- function(e, c) p[StratumId == e & (if (is.na(c)) is.na(StateClassId) else StateClassId %in% c), Age]
expect("percentiles: a type's own 75th percentile", abs(g("Marine", "Forest: A") - quantile(1:150, .75)) < 1e-9 && abs(g("Marine", "Forest: B") - quantile(201:250, .75)) < 1e-9)
expect("percentiles: a type with too few cells takes its ecodivision's forest", abs(g("Prairie", "Forest: C") - quantile(c(1:190, 291:300), .75)) < 1e-9)
expect("percentiles: an all-types row per ecodivision", abs(g("Marine", NA) - quantile(c(1:150, 201:250), .75)) < 1e-9)
expect("percentiles: only the cells asked for", abs(age_percentiles(eco, cls, age, age <= 100, 50)[StratumId == "Marine" & StateClassId %in% "Forest: A", Age] - 50.5) < 1e-9)
expect("percentiles: a higher percentile is older", age_percentiles(eco, cls, age, rep(TRUE, n), 90)[1, Age] > p[1, Age])
expect("percentiles: no cells, no rows", nrow(age_percentiles(eco, cls, age, rep(FALSE, n))) == 0)

# ---- the rules, in order -----------------------------------------------------------------------------------------------------------
# cells: 1 unburned forest; 2-6 forest burned in 1988; 7 forest burned in 2000; 8 not forest; 9 forest burned in 1988, of a type with no percentile
forest <- c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE); ecoc <- rep("Marine", 9); clsc <- c(rep("Forest: A", 4), "Forest: B", "Forest: A", "Forest: A", "Grassland: Annual", "Forest: Z")
agec <- c(90, 95, 100, 105, 110, 115, 120, 0, 125); burn <- c(NA, 1988, 1988, 1988, 1988, 1988, 2000, NA, 1988)
pct <- data.table(StratumId = "Marine", StateClassId = c("Forest: A", NA), Age = c(140, 160), Cells = c(100L, 300L))
a <- age_assign(forest, ecoc, clsc, agec, burn, pct = pct)
expect("assign: unburned forest and land that is not forest keep the age map's value", a$age[1] == 90 && a$rule[1] == "source" && a$age[8] == 0 && is.na(a$rule[8]))
expect("assign: burned forest takes the percentile of its type", all(a$age[c(2, 3, 4, 6, 7)] == 140) && all(a$rule[c(2, 3, 4, 6, 7)] == "percentile"))
expect("assign: a type with no percentile of its own takes the ecodivision's", a$age[5] == 160 && a$age[9] == 160)
a <- age_assign(forest, ecoc, clsc, agec, burn, pct = pct, earlier_age = c(NA, 60, NA, NA, NA, NA, 210, NA, NA), earlier_year = 1990L)
expect("assign: an earlier age map is used only where it predates the fire", a$age[7] == 210 && a$rule[7] == "earlier" && a$age[2] == 140 && a$rule[2] == "percentile")
tt <- age_type_table(data.table(StratumId = c(NA, "Marine"), StateClassId = c("Forest: A", "Forest: B"), Age = c(250, 300)))
a <- age_assign(forest, ecoc, clsc, agec, burn, pct = pct, earlier_age = c(NA, 60, NA, NA, NA, NA, 210, NA, NA), earlier_year = 1990L, type_table = tt)
expect("assign: the user's forest type value comes before the earlier map and the percentile", all(a$age[c(2, 3, 4, 6, 7)] == 250) && a$age[5] == 300 && all(a$rule[2:7] == "type"))
expect("assign: a type the user gave no value keeps the default rule", a$age[9] == 160 && a$rule[9] == "percentile")
expect("assign: the user's value does not touch unburned forest", a$age[1] == 90)
a <- age_assign(forest, ecoc, clsc, agec, burn, pct = pct, type_table = tt, raster_age = c(33, 44, NA, NA, NA, NA, NA, 55, NA))
expect("assign: the raster wins wherever it has a value, on burned and unburned forest, and not off forest", a$age[1] == 33 && a$age[2] == 44 && all(a$rule[1:2] == "raster") && a$age[3] == 250 && a$age[8] == 0)
a <- age_assign(forest, ecoc, clsc, agec, burn, pct = pct, type_table = tt, unknown = "source", raster_age = c(33, rep(NA, 8)))
expect("assign: 'keep the age map's value' leaves burned forest alone, the raster still applies", all(a$age[2:7] == agec[2:7]) && all(a$rule[2:7] == "source") && a$age[1] == 33)
a <- age_assign(forest, ecoc, clsc, agec, burn)
expect("assign: with nothing to go on, the age map's value", all(a$age == agec) && all(a$rule[forest] == "source"))
a <- age_assign(c(TRUE, TRUE), c("Marine", "Marine"), c("Forest: A", "Forest: A"), c(0.2, 5000), c(NA, NA))
expect("assign: forest ages are whole years, at least 1 and capped", all(a$age == c(1, 1000)))
s <- age_summary(clsc, age_assign(forest, ecoc, clsc, agec, burn, pct = pct)$rule, age_assign(forest, ecoc, clsc, agec, burn, pct = pct)$age, agec)
expect("summary: a row per forest type and rule, with the cells and both mean ages", nrow(s) == 4 && s[StateClassId == "Forest: A" & Rule == AGE_RULES[["percentile"]], Cells] == 5 &&
       s[StateClassId == "Forest: A" & Rule == AGE_RULES[["percentile"]], MeanAge] == 140 && s[StateClassId == "Forest: A" & Rule == AGE_RULES[["percentile"]], SourceAge] == 107)

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
