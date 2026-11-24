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
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
