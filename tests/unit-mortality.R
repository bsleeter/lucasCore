# Fast test of the drought and insect mortality rule and its placement (src/mortality.R; no SyncroSim).
# Run: Rscript tests/unit-mortality.R (from the package root)
suppressPackageStartupMessages({ library(terra); library(data.table) }); source("src/mortality.R"); terraOptions(progress = 0)
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))

# ---- options and lines ---------------------------------------------------------------------------------------------------
o <- mortality_options(data.table())
check("blank page: on, ranked selection, the shipped lines", o$enabled && o$placement == "ranked" && is.na(o$line) && is.na(o$pj_line) && is.na(o$min_age))
o2 <- mortality_options(data.table(Enabled = FALSE, Placement = "Fraction as probability", CanopyLossLine = 0.3, MinimumAge = 10))
check("the page's values are read", !o2$enabled && o2$placement == "probability" && o2$line == 0.3 && o2$min_age == 10)
check("a line outside 0.01-1 stops", inherits(tryCatch(mortality_options(data.table(CanopyLossLine = 1.5)), error = function(e) e), "error"))
tab <- fread("defaults/transitions/mortality-lines.csv", colClasses = list(character = "Ecodivision"))
check("the shipped table has a softwood and a pinyon/juniper line for the same ecodivisions, all between 0.1 and 0.6",
      setequal(tab[ForestGroups == "conifer", Ecodivision], tab[ForestGroups == "pinyon/juniper", Ecodivision]) && all(tab$Line > 0.1 & tab$Line < 0.6) && !anyDuplicated(tab[, .(Ecodivision, ForestGroups)]))
eco <- data.table(ecodiv = c("M260", "M330", "230"), StrtmId = c(2601L, 3301L, 230L))
ml <- mortality_lines(tab, eco, o)
check("an ecodivision with no row has no line (no event in the East)", setequal(ml$ecodiv, c("M260", "M330")) && near(ml[ecodiv == "M260", line], tab[Ecodivision == "M260" & ForestGroups == "conifer", Line]))
ml2 <- mortality_lines(tab, eco, o2)
check("the page's line replaces the shipped ones and leaves pinyon/juniper's", all(ml2$line == 0.3) && near(ml2$pj_line, ml$pj_line) && nrow(ml2) == 2)
check("years: canopy at y and y - 5, NLCD at y - 5 and LCMS in between are needed, from 1990", identical(mortality_years(1988:1993, function(y) y != 1987, function(y) TRUE, function(y) TRUE), c(1990L, 1991L, 1993L)))

# ---- the 30 m rule on a small made-up grid ----------------------------------------------------------------------------------
# 20 x 20 pixels in blocks of 10 (4 block cells). Rows of test pixels in the top-left block; everything else is not softwood forest.
td <- file.path(tempdir(), "mort"); dir.create(td, showWarnings = FALSE)
E <- c(-2000010, -2000010 + 600, 2000010, 2000010 + 600)   # on the 30 m lattice (origin 15, 15 is not needed here: files and extent agree)
tpl <- rast(ext(E), resolution = 30, crs = "EPSG:5070"); wr <- function(v, name) { f <- file.path(td, name); writeRaster(setValues(tpl, v), f, overwrite = TRUE, datatype = "INT2U"); f }
px <- function(r, c) (r - 1L) * 20L + c; N <- 400L; yrs <- 1985:2001
ft <- rep(65535L, N); ft[1:60] <- 220L; ft[px(1, 7)] <- 180L; ft[px(1, 8)] <- 500L                    # softwood in rows 1-3; a pinyon/juniper and a hardwood pixel
nl <- rep(42L, N); nl[px(1, 9)] <- 52L                                                            # one pixel not forest in NLCD
tc <- function(y) { v <- rep(60L, N)
  if (y >= 1992) v[px(1, 1)] <- 30L          # loses half in 1992 with stress: the event, once
  if (y >= 1992) v[px(1, 2)] <- 45L          # loses a quarter: under the line
  if (y >= 1992) v[px(1, 3)] <- 30L          # loses half, no stress
  if (y >= 1992) v[px(1, 4)] <- 30L          # loses half with stress, burned in 1993 (the year after)
  if (y >= 1990) v[px(1, 5)] <- 30L          # cut in 1990 (canopy falls then), stress in 1991: the cut rules it out, and nothing falls later
  v[px(1, 6)] <- if (y >= 1992) 8L else 15L  # loses half but started under the 20% floor
  if (y >= 1992) v[px(1, 7)] <- 35L          # pinyon/juniper loses 42%: under its own line
  if (y >= 1992) v[c(px(1, 8), px(1, 9))] <- 30L   # hardwood, and not forest in NLCD
  if (y >= 1996) v[px(2, 1)] <- 20L          # a later event in the same block
  if (y >= 1992) v[px(1, 1)] <- if (y >= 1999) 10L else 30L   # the first pixel falls again in 1999: no second event
  v }
lc <- function(y) { v <- rep(0L, N); if (y == 1991) v[c(px(1, 1), px(1, 2), px(1, 4), px(1, 5), px(1, 6), px(1, 7), px(1, 8), px(1, 9))] <- 12L
  if (y == 1995) v[px(2, 1)] <- 4L; if (y == 1998) v[px(1, 1)] <- 12L; if (y == 1990) v[px(1, 5)] <- 9L; v }
mt <- function(y) { v <- rep(0L, N); if (y == 1993) v[px(1, 4)] <- 3L; v }
files <- function(fn, tag) setNames(lapply(yrs, function(y) wr(fn(y), sprintf("%s-%d.tif", tag, y))), yrs)
ey <- 1990:2000
a <- list(clear = function() NULL, E = E, fact = 10L, nr = 20L, nc = 20L, step = 10L, rows = c(0, 10), ft = wr(ft, "ft.tif"), eco = rep(2601L, 4), lines = data.frame(StrtmId = 2601L, line = 0.4, pj_line = 0.474), pj = 180L,
          all = 1985:2001, lc = files(lc, "lc"), mt = files(mt, "mt"), tc = files(tc, "tc"), nl = setNames(lapply(ey - 5L, function(y) wr(nl, sprintf("nl-%d.tif", y))), ey - 5L), years = ey, out = 1991:2000,
          span = 5L, floor = 20L, named = MORT$named, stress = MORT$stress, burn = MORT$burn)
b1 <- mortality_band(1, a); b2 <- mortality_band(2, a); cnt <- rbind(b1$counts, b2$counts); colnames(cnt) <- a$out
check("only the pixel with stress, a loss over the line and no other cause is flagged, in its first year", cnt[1, "1992"] == 1 && sum(cnt[, "1992"]) == 1)
check("a later pixel is flagged in its own year, and the first is not flagged again when it falls further", cnt[1, "1996"] == 1 && sum(cnt) == 2)
check("the yearly totals agree with the block counts", near(b1$total + b2$total, unname(colSums(cnt))))
check("blocks with no softwood forest hold nothing", all(cnt[2:4, ] == 0))
a2 <- a; a2$out <- 1996:2000; c2 <- rbind(mortality_band(1, a2)$counts, mortality_band(2, a2)$counts)
check("a later start year still knows the earlier event (the rule runs from 1990)", sum(c2) == 1 && c2[1, 1] == 1)
a3 <- a; a3$lines$pj_line <- 0.4; c3 <- mortality_band(1, a3)$counts
check("pinyon/juniper is judged on its own line", sum(c3[, a$out == 1992]) == 2)
a4 <- a; a4$eco <- rep(230L, 4); check("an ecodivision with no line has no event", sum(mortality_band(1, a4)$counts) == 0)

# ---- ranked selection ---------------------------------------------------------------------------------------------------
sh <- c(0.9, 0.6, 0.5, 0.2, 0, 0.8); cls <- c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE); old <- c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE); room <- c(1, 1, 1, 1, 1, 1)
s <- mortality_select(sh, cls, old, room, 0, cls)
check("the area flagged on a cell with no pathway is added to the year's area and lands on the next-ranked cells", near(s$moved, 0.8) && near(s$target, 2.5) && identical(s$sel, c(1L, 2L)) && near(s$carry, 0.5))
check("the share on a stand under the minimum age is set aside and reported", near(s$young, 0.5) && near(s$flagged, 3.0) && s$again == 0)
can2 <- cls; can2[1] <- FALSE; s1 <- mortality_select(sh, can2, old, room, 0, cls)
check("a cell that already had the event is not chosen and its later flags are not counted again", !1L %in% s1$sel && near(s1$again, 0.9) && near(s1$target, 0.6 + 0.2 + 0.8) && identical(s1$sel, 2L))
s2 <- mortality_select(c(0.9, 0.6, 0, 0.2, 0, 0), cls, old, room, 0.7, cls)
check("the carry adds to the next year's area", near(s2$target, 2.4) && identical(s2$sel, c(1L, 2L)) && near(s2$carry, 0.4))
room2 <- c(0.5, 1, 1, 1, 1, 1); s3 <- mortality_select(c(0.9, 0.6, 0, 0.2, 0, 0), cls, old, room2, 0, cls)
check("a cell with a fire or harvest that year is not chosen, and only its free share counts", !1L %in% s3$sel && near(s3$held, 0.4) && near(s3$target, 1.3) && identical(s3$sel, 2L))
s4 <- mortality_select(c(0, 0, 0), rep(TRUE, 3), rep(TRUE, 3), rep(1, 3), 0.6)
check("with nothing flagged the carry waits", !length(s4$sel) && near(s4$carry, 0.6))
s5 <- mortality_select(c(0.3, 0.3), rep(TRUE, 2), rep(TRUE, 2), rep(1, 2), 5)
check("no more cells are taken than have a flagged share", length(s5$sel) == 2 && near(s5$carry, 3.6))

# ---- package files ------------------------------------------------------------------------------------------------------
pw <- fread("defaults/transitions/pathways/mortality.csv", colClasses = "character", na.strings = ""); sc <- fread("defaults/stsim/stsim_StateClass.csv", colClasses = "character")
tt <- fread("defaults/stsim/stsim_TransitionType.csv", colClasses = "character"); tg <- fread("defaults/stsim/stsim_TransitionTypeGroup.csv", colClasses = "character")
check("the type and its group are in the definitions, and the Insect types are gone", MORT_TYPE %in% tt$Name && tg[TransitionTypeId == MORT_TYPE, TransitionGroupId] == "Mortality" && !any(grepl("^Insect", tt$Name)) && !anyDuplicated(tt$Id))
check("every pathway goes from a softwood forest class to its own disturbed class, with age reset", all(pw$TransitionTypeId == MORT_TYPE) && all(c(pw$StateClassIdSource, pw$StateClassIdDest) %in% sc$Name) &&
      all(sub("^(Forest|Wetland): ", "", pw$StateClassIdSource) == sub("^Disturbed: (Wetland )?", "", pw$StateClassIdDest)) && all(pw$AgeReset == "Yes") && all(pw$Probability == "1") &&
      all(as.integer(sc$Id[match(pw$StateClassIdSource, sc$Name)]) < 400))
so <- fread("defaults/transitions/sources.csv"); check("the group has its source", so[TransitionGroupId == MORT_GROUP, Source] == MORT_SOURCE)
ev <- fread("defaults/stockflow/event-pathways.csv", colClasses = "character", na.strings = "")[TransitionGroupId == MORT_GROUP]
mv <- ev[, .(share = sum(as.numeric(Multiplier))), by = FromStockTypeId]
check("the event moves the same share of each live tree pool to dead pools and emits nothing", nrow(mv) == 5 && all(abs(mv$share - 0.83) < 1e-9) && all(grepl("^DOM: ", ev$ToStockTypeId)) && all(ev$FlowTypeId == "LULC: Mortality Live"))

# ---- projections (lucasCore 2.0.2; stage 9): options, block draws, rates, patch sizes, the surface, the spread ----------------------
suppressPackageStartupMessages(library(mgcv))
p0 <- mortality_projection_options(data.table())
check("blank page: historical rates in blocks of 5, the Projection Options reference years, clustered", p0$projection == "rates" && p0$block == 5L && is.na(p0$ref_start) && is.na(p0$ref_end) && p0$clustered)
p1 <- mortality_projection_options(data.table(Projection = "Off", BlockYears = 10, ReferenceStartYear = 2001, ReferenceEndYear = 2023, ProjectionPlacement = "Random cells"))
check("the projection settings are read, by label", p1$projection == "off" && p1$block == 10L && p1$ref_start == 2001L && p1$ref_end == 2023L && !p1$clustered)
p2 <- mortality_projection_options(data.table(Projection = 2L, ProjectionPlacement = 1L))
check("and by number", p2$projection == "off" && p2$clustered)
check("a reference start after the end stops", inherits(tryCatch(mortality_projection_options(data.table(ReferenceStartYear = 2020, ReferenceEndYear = 2000)), error = function(e) e), "error"))
check("a block length of 0 stops", inherits(tryCatch(mortality_projection_options(data.table(BlockYears = 0)), error = function(e) e), "error"))

refy <- 1986:2023; py <- 2024:2100
b <- mortality_blocks(refy, py, 200L, 5L, 7L)
check("every iteration has one drawn year for every projection year, all of them reference years", nrow(b) == 200L * length(py) && all(b$HistoricalYear %in% refy) && all(b[, .N, by = Iteration]$N == length(py)))
blk_ok <- function(d, ref, len) { p <- match(d$HistoricalYear, ref); s <- (diff(p) - 1L) %% length(ref); all(s[seq_along(s) %% len != 0] == 0) }
check("the years inside a block are consecutive, running on from the last reference year to the first", all(b[, blk_ok(.SD, refy, 5L), by = Iteration]$V1))
check("a block does not always follow on from the one before", any(b[, { p <- match(HistoricalYear, refy); s <- (diff(p) - 1L) %% length(refy); any(s[seq_along(s) %% 5L == 0] != 0) }, by = Iteration]$V1))
check("the seed repeats the draws, and another seed changes them", identical(b, mortality_blocks(refy, py, 200L, 5L, 7L)) && !identical(b$HistoricalYear, mortality_blocks(refy, py, 200L, 5L, 8L)$HistoricalYear))
fq <- as.numeric(table(factor(b$HistoricalYear, levels = refy))) / nrow(b)
check("every reference year is drawn about equally often (within a third of 1 in 38 over 200 iterations)", all(abs(fq * length(refy) - 1) < 0.33))
check("a block of 1 draws single years; a block longer than the projection gives one run", blk_ok(mortality_blocks(refy, 2024:2030, 1L, 50L, 1L), refy, 50L) && nrow(mortality_blocks(refy, py, 3L, 1L, 1L)) == 3L * length(py))

# open cells: eligible, no event before the year, old enough (start age carried forward)
ev6 <- c(NA, 1990L, 2000L, NA, NA); el6 <- c(TRUE, TRUE, TRUE, FALSE, TRUE); a6 <- c(50L, 50L, 50L, 50L, 5L)
check("open in 1995: not the cell that died in 1990, not an ineligible cell, not a stand still under the minimum age", identical(mortality_open(ev6, el6, a6, 20, 1985L, 1995L), c(TRUE, FALSE, TRUE, FALSE, FALSE)))
check("the young stand is open once it reaches the minimum age (5 in 1985 is 20 in 2001)", identical(mortality_open(ev6, el6, a6, 20, 1985L, 2001L), c(TRUE, FALSE, FALSE, FALSE, TRUE)))

# rates: two large units and a small one in ecodivision 1, one small unit alone in ecodivision 2
E <- matrix(c(10, 0, 1, 2,   20, 5, 0, 0), 4, dimnames = list(c("a", "b", "c", "d"), c("2001", "2002"))); N <- matrix(c(1000, 2000, 50, 40,   990, 2000, 49, 38), 4)
rt <- mortality_rate_table(E, N, eco = c(1, 1, 1, 2), cells0 = c(1000, 2000, 50, 40), small = 100)
check("a unit's rate is its events over its open cells", near(rt$rate["a", ], c(`2001` = 10 / 1000, `2002` = 20 / 990)) && near(unname(rt$rate["b", "2002"]), 5 / 2000))
check("a small unit takes the pooled rate of its ecodivision's units", rt$pooled[3] && near(unname(rt$rate["c", ]), c(11 / 3050, 25 / 3039)))
check("a small unit alone in its ecodivision keeps what it has", rt$pooled[4] && near(unname(rt$rate["d", ]), c(2 / 40, 0)))
check("the overall rate is all events over all open cells", near(unname(rt$all), c(13 / 3090, 25 / 3077)))
check("a unit with no open cells has rate 0, and no rate is over 1", mortality_rate_table(matrix(c(0, 5), 2), matrix(c(0, 3), 2), c(1, 2), c(500, 500), 100)$rate[1, 1] == 0 && max(mortality_rate_table(matrix(c(0, 5), 2), matrix(c(0, 3), 2), c(1, 2), c(500, 500), 100)$rate) <= 1)

# patch sizes on a 10 x 10 grid: 2001 has a patch of 3 (one joined by a corner) and a single cell; 2002 a patch of 6; they are not joined across years
G <- rast(nrows = 10, ncols = 10, xmin = 0, xmax = 3000, ymin = 0, ymax = 3000, crs = "EPSG:5070"); cl <- function(r, c) (r - 1L) * 10L + c
evg <- rep(NA_integer_, 100); evg[c(cl(1, 1), cl(1, 2), cl(2, 3), cl(8, 8))] <- 2001L; evg[c(cl(5, 1), cl(5, 2), cl(5, 3), cl(6, 1), cl(6, 2), cl(6, 3))] <- 2002L
sz <- mortality_sizes(evg, G, 2001:2002)
check("yearly patches: 8-neighbour cells of one year, by size class", sz$n == 3L && sz$max == 6L && identical(sz$table[Patches > 0, MaximumCells], c(1L, 3L, 10L)) && near(sz$single, 1 / 10) && near(sum(sz$table$AreaShare), 1))
check("only the reference years count, and none gives no table", mortality_sizes(evg, G, 2002L)$n == 1L && is.null(mortality_sizes(evg, G, 1999L)))

# the surface: on a 100 x 100 grid the chance of the event rises with one covariate and ignores another
set.seed(3); G2 <- rast(nrows = 100, ncols = 100, xmin = 0, xmax = 30000, ymin = 0, ymax = 30000, crs = "EPSG:5070"); nc2 <- 10000L
x1 <- runif(nc2); x2 <- runif(nc2); pool <- rep(TRUE, nc2); pool[1:500] <- FALSE; un <- rep(c(1, 2), each = nc2 / 2)
evs <- pool & runif(nc2) < 0.02 * exp(3 * (x1 - 0.5)); X <- data.table(Dense = x1, Noise = x2, Flat = 1)
sf <- mortality_surface(evs, pool, un, X, X, 1L)
check("the surface averages 1 over the pool cells of every unit", !is.null(sf) && all(abs(tapply(sf$w[pool], un[pool], mean) - 1) < 1e-9))
check("it rises with the covariate that drives the event and has skill; a covariate with one value is left out", cor(sf$w[pool], x1[pool]) > 0.8 && sf$auc > 0.65 && sf$top10 > 0.2 && !"Flat" %in% sf$covariates)
check("the weights stay within the clamp of the median, and every cell has one", all(is.finite(sf$w)) && max(sf$w[pool]) / stats::median(sf$w[pool]) <= MORTP$clamp * 1.5)
check("too few events, or no usable covariate, gives no surface", is.null(mortality_surface(pool & seq_len(nc2) %in% 501:520, pool, un, X, X)) && is.null(mortality_surface(evs, pool, un, data.table(Flat = rep(1, nc2)))))
Xn <- copy(X)[, Dense := 1 - Dense]; sfn <- mortality_surface(evs, pool, un, X, Xn, 1L)
check("the surface is placed on the covariates as they are now", cor(sfn$w[pool], x1[pool]) < -0.8)
ws <- mortality_scale(c(2, 4, NA, 10, 30, 5), c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE), c(1, 1, 1, 2, 2, NA))
check("scaling: mean 1 over each unit's pool cells, 1 where there is no weight, the overall scale outside the units", near(ws[1:2], c(2, 4) / 3) && ws[3] == 1 && near(ws[4:5], c(0.5, 1.5)) && near(ws[6], 5 / 11.5))

# the spread: events seeded at random in 2001, then in 2002-2004 a cell beside recent die-off is 20 times as likely
set.seed(5); evc <- rep(NA_integer_, nc2); landc <- rep(TRUE, nc2); evc[sample(nc2, 150)] <- 2001L; w3 <- matrix(1, 3, 3)
for (y in 2002:2004) { rec <- !is.na(evc) & evc < y; nb <- values(focal(setValues(G2, as.numeric(rec)), w3, "sum", na.rm = TRUE), mat = FALSE) > 0
  evc[is.na(evc) & runif(nc2) < ifelse(nb, 0.06, 0.003)] <- y }
openc <- function(y) is.na(evc) | evc >= y; r_y <- vapply(2002:2004, function(y) sum(evc %in% y) / sum(openc(y)), 0)
sp <- mortality_spread(evc, landc, G2, 2002:2004, openc, function(y) rep(r_y[y - 2001L], nc2), radius = 1L, window = 3L)
check("the curve is below 1 with no recent die-off near and well above it beside some, and does not fall as the share rises",
      !is.null(sp) && sp$classes$Multiplier[1] < 1 && max(sp$classes$Multiplier) > 3 && all(diff(sp$classes$Multiplier[-1]) >= -1e-9) && all(diff(sp$curve$AttributeValue) > 0))
check("the rate and the curve together return the events that happened", near(sum(sp$classes$Expected * sp$classes$Multiplier), sum(sp$classes$Events)) && near(sum(sp$classes$Events), sum(evc %in% 2002:2004)))
check("the first point of the curve above none is one neighbour's share", near(sp$curve$AttributeValue[2], round(1 / sp$cells, 4)) && sp$curve$AttributeValue[1] == 0 && max(sp$curve$AttributeValue) == 1)
evr <- rep(NA_integer_, nc2); evr[sample(nc2, 40)] <- 2002L
check("too few events near earlier ones gives no curve", is.null(mortality_spread(evr, landc, G2, 2002:2004, function(y) is.na(evr) | evr >= y, function(y) rep(0.004, nc2), radius = 1L)))

# what the package ships for projections
check("the state attribute for the spread is among the package's definitions", MORT_ATTR %in% fread("defaults/stsim/stsim_StateAttributeType.csv")$Name)
ptd <- fread("defaults/projection/transitions.csv"); check("Projection Transitions has the group's row, in its own sampling set", nrow(ptd[TransitionGroupId == MORT_GROUP & Method == "Probability" & SamplingSet == MORT_SET]) == 1L)
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
