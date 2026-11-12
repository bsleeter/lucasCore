# Unit test: src/wood-products.R, the harvested wood products model (to-do 59, step 2).
# By-hand cases (one pulse, one half-life; a landfill year), carbon conserved through every path and draw, the spin-up's scaling,
# the triangular draws, and the published decay tables: Smith et al. 2006 Table 8 (share of a product still in use) and Table 6 (share
# of industrial roundwood in use by region), values copied from the CSV tables on Smith's CD (gtr_ne343.zip).
# Usage: Rscript tests/unit-wood-products.R   (from the package folder)
suppressPackageStartupMessages(library(data.table))
source(file.path("src", "wood-products.R"))
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
P <- wp_params(); C <- wp_draws(P, central = TRUE)

# ---- by hand: one pulse into one end use ----------------------------------------------------------------------------------------
yrs <- 2000:2100; ny <- length(yrs); eu <- P$end_uses
z <- list(eu_in = matrix(0, ny, length(eu), dimnames = list(NULL, eu)), loss_wood = rep(0, ny), loss_paper = rep(0, ny), emit_ec = rep(0, ny), emit_no = rep(0, ny))
z$eu_in[1, "new housing, single family"] <- 100
pl <- wp_pools(z, P, C, 1L, yrs)
check("one pulse into single-family housing (half-life 100) keeps 100 x 0.5^(t/100) in use", max(abs(pl$inuse[, "new housing, single family"] - 100 * 0.5^((0:100) / 100))) < 1e-9)
# the first year's discards (100 x (1 - 0.5^0.01)) go to the 2001 wood fates; 77% of what is landfilled never decays
f <- dcast(P$fates[Material == "wood" & Year == 2001], Year ~ Fate, value.var = "Fraction"); f <- unlist(f[, -1]); f <- f / sum(f)
d1 <- 100 * (1 - 0.5^0.01); sw <- P$swds[Material == "wood"]
check("year 2 landfill = discards x landfill share (fixed part 0.77 kept whole)",
      abs(pl$out[2, "LandfillFixed"] - d1 * f[["Landfills"]] * sw$LandfillFixedFraction) < 1e-9 && abs(pl$out[2, "LandfillDecaying"] - d1 * f[["Landfills"]] * (1 - sw$LandfillFixedFraction)) < 1e-9)
check("year 2 emissions = discards burned (with and without energy capture) and composted",
      abs(pl$out[2, "EmittedEnergy"] - d1 * f[["Burned with energy capture"]]) < 1e-9 && abs(pl$out[2, "EmittedNoEnergy"] - d1 * (f[["Burned without energy capture"]] + f[["Composted"]])) < 1e-9)
check("the decaying landfill part loses 0.5^(1/29) a year from the year after it arrives", abs(pl$out[3, "LandfillEmitted"] - pl$out[2, "LandfillDecaying"] * (1 - 0.5^(1 / 29))) < 1e-9)
stored <- rowSums(pl$inuse) + pl$out[, "Recovered"] + pl$out[, "LandfillDecaying"] + pl$out[, "LandfillFixed"] + pl$out[, "Dump"]
check("a pulse is conserved: stored + emitted = 100 every year", max(abs(stored + cumsum(pl$out[, "EmittedEnergy"] + pl$out[, "EmittedNoEnergy"]) - 100)) < 1e-9)

# ---- Smith 2006 Table 8: share of a product still in use 1-100 years after production (central parameters, 2002, no loss) -----
t8 <- data.table(After = c(1, 10, 30, 50, 100),
  `Softwood lumber` = c(0.973, 0.777, 0.533, 0.402, 0.234), `Hardwood lumber` = c(0.938, 0.571, 0.270, 0.163, 0.064),
  `Softwood plywood` = c(0.976, 0.798, 0.563, 0.426, 0.245), `Oriented strandboard` = c(0.983, 0.856, 0.666, 0.541, 0.349),
  `Nonstructural panels` = c(0.969, 0.741, 0.450, 0.301, 0.138), `Other industrial products` = c(0.944, 0.561, 0.177, 0.056, 0.003))
dev <- sapply(names(t8)[-1], function(p) { m <- wp_pulse(P, 2002, product = p); max(abs(m[match(t8$After, After), InUse] - t8[[p]])) })
check(sprintf("Table 8: softwood lumber, softwood plywood and other products within 0.02 (%s)", paste(sprintf("%.3f", dev[c(1, 3, 6)]), collapse = ", ")), all(dev[c(1, 3, 6)] < 0.02))
# hardwood lumber and panels keep longer than Table 8 because McKeever's 2002 end uses (more in housing) replace Smith's Table D2
check(sprintf("Table 8: hardwood lumber, OSB and nonstructural panels within 0.06 (%s)", paste(sprintf("%.3f", dev[c(2, 4, 5)]), collapse = ", ")), all(dev[c(2, 4, 5)] < 0.06))

# ---- Smith 2006 Table 6: industrial roundwood in use at production and 10 years on, by region --------------------------------
t6 <- data.table(matrix(c(
  "North Central", "HW", "Pulpwood", 0.685, 0.362,  "North Central", "HW", "Sawlog", 0.585, 0.310,
  "North Central", "SW", "Pulpwood", 0.514, 0.096,  "North Central", "SW", "Sawlog", 0.630, 0.410,
  "Northeast", "HW", "Pulpwood", 0.650, 0.308,      "Northeast", "HW", "Sawlog", 0.614, 0.331,
  "Northeast", "SW", "Pulpwood", 0.513, 0.093,      "Northeast", "SW", "Sawlog", 0.569, 0.379,
  "Pacific Northwest; Eastside", "SW", "All", 0.637, 0.405, "Pacific Northwest; Westside", "HW", "All", 0.531, 0.231,
  "Pacific Northwest; Westside", "SW", "Pulpwood", 0.500, 0.075, "Pacific Northwest; Westside", "SW", "Sawlog", 0.740, 0.489,
  "Pacific Southwest", "SW", "All", 0.675, 0.424,   "Rocky Mountain", "SW", "All", 0.704, 0.438,
  "South Central", "HW", "Pulpwood", 0.581, 0.201,  "South Central", "HW", "Sawlog", 0.587, 0.301,
  "South Central", "SW", "Pulpwood", 0.570, 0.184,  "South Central", "SW", "Sawlog", 0.629, 0.402,
  "Southeast", "HW", "Pulpwood", 0.591, 0.216,      "Southeast", "HW", "Sawlog", 0.609, 0.321,
  "Southeast", "SW", "Pulpwood", 0.553, 0.158,      "Southeast", "SW", "Sawlog", 0.636, 0.402,
  "West", "HW", "All", 0.568, 0.316), ncol = 5, byrow = TRUE))
setnames(t6, c("Region", "Wood", "LogSize", "Y0", "Y10")); t6[, `:=`(Y0 = as.numeric(Y0), Y10 = as.numeric(Y10))]
rmap <- c("North Central" = "NLS", Northeast = "NE", "Pacific Northwest; Eastside" = "PWE", "Pacific Northwest; Westside" = "PWW",
          "Pacific Southwest" = "PSW", "Rocky Mountain" = "RMN", "South Central" = "SC", Southeast = "SE", West = "RMN")
m6 <- t6[, { m <- wp_pulse(P, 2002, region = rmap[[Region]], wood = Wood, logsize = if (LogSize == "All") "Sawlog" else LogSize)
             .(M0 = m[After == 0, InUse], M10 = m[After == 10, InUse]) }, by = .(Region, Wood, LogSize, Y0, Y10)]
check(sprintf("Table 6: the share in use at production matches in all %d rows within 0.01 (max %.3f)", nrow(m6), m6[, max(abs(M0 - Y0))]), m6[, max(abs(M0 - Y0))] < 0.01)
check(sprintf("Table 6: the share in use 10 years on within 0.08 (max %.3f; end uses by year and paper's plain 2.6-year decay)", m6[, max(abs(M10 - Y10))]), m6[, max(abs(M10 - Y10))] < 0.08)

# ---- the whole model: carbon conserved, every draw, both causes, two regions and iterations --------------------------------
rem <- rbind(data.table(Iteration = 1L, Year = 1985:2030, Region = "PWW", ForestType = "Forest: Douglas-fir Group", Cause = "Harvest", Carbon = 1000),
             data.table(Iteration = 1L, Year = 1985:2030, Region = "PWW", ForestType = "Alder/Maple Group", Cause = "Clearing", Carbon = 200),
             data.table(Iteration = 2L, Year = 1985:2030, Region = "SE", ForestType = "Forest: Loblolly/Shortleaf Pine Group", Cause = "Harvest", Carbon = seq(500, 1400, length.out = 46)),
             data.table(Iteration = 2L, Year = 1985:2030, Region = "SE", ForestType = "Forest: Oak/Hickory Group", Cause = "Clearing", Carbon = 100))
D <- wp_draws(P, n = 12, seed = 7)
m <- wp_model(rem, P, D)
bal <- m$years[order(Iteration, Draw, Year)][, .(e = max(abs(cumsum(Removed) - Stored - cumsum(EmittedEnergy + EmittedNoEnergy)) / cumsum(Removed))), by = .(Iteration, Draw)]
check("carbon conserved in every iteration and draw (removed = stored + emitted, to 1e-9)", max(bal$e) < 1e-9)
check("removals of the run years are the run's own in every draw (no history multiplier)", all(abs(m$years[Source == "Run" & Iteration == 1L, Removed] - 1200) < 1e-6))
check("the draws differ and their interval brackets the central case", { cm <- wp_model(rem, P, C); s <- wp_summary(m)[Iteration == 1L & Year == 2030 & Variable == "Stored"]
      cs <- cm$years[Iteration == 1L & Year == 2030, Stored]; m$years[Iteration == 1L & Year == 2030, sd(Stored)] > 0 && s$Lower < cs && s$Upper > cs })
check("the same seed gives the same results", identical(as.data.frame(wp_model(rem, P, wp_draws(P, n = 12, seed = 7))$years), as.data.frame(m$years)))
check("history years run from 1906 and are marked History", m$years[, min(Year)] == 1906L && m$years[Year < 1985, all(Source == "History")])
check("the stock change is the change in stored carbon", m$years[order(Iteration, Draw, Year)][, max(abs(StockChange - c(Stored[1], diff(Stored)))), by = .(Iteration, Draw)][, max(V1)] < 1e-9)
check("in use by end use adds up to the draw mean in use", { a <- m$enduse[Iteration == 1L & Year == 2000, sum(InUse)]; b <- m$years[Iteration == 1L & Year == 2000, mean(InUse)]; abs(a - b) < 1e-6 * b })

# ---- land clearing: the unutilized share is emitted the year it is cleared ------------------------------------------------------
cl <- data.table(Iteration = 1L, Year = 2000L, Region = "NE", ForestType = "Oak/Hickory Group", Cause = "Clearing", Carbon = 100)
x <- wp_inputs(wp_split(cl, P), P, C, 1L, 2000L)
check("land clearing: 1 - LandClearingUtilized (0.5) of the wood emitted without energy capture that year", abs(x$emit_no - 100 * (1 - P$setting("LandClearingUtilized"))) < 1e-9)
check("land clearing: the utilized half is conserved through products", abs(x$emit_ec + sum(x$eu_in) + x$loss_wood + x$loss_paper + x$emit_no - 100) < 1e-9)

# ---- the split: wood type and log size --------------------------------------------------------------------------------------
s <- wp_split(data.table(Iteration = 1L, Year = 2000L, Region = "PWW", ForestType = c("Forest: Douglas-fir Group", "Tropical Hardwoods Group", "Made-up Group"), Cause = "Harvest", Carbon = 100), P)
g <- P$growing[Region == "PWW" & ForestTypeGroup == "Douglas-fir"]
swc <- g$SoftwoodFraction * g$SoftwoodSpecificGravity / (g$SoftwoodFraction * g$SoftwoodSpecificGravity + (1 - g$SoftwoodFraction) * g$HardwoodSpecificGravity)
s1 <- wp_split(data.table(Iteration = 1L, Year = 2000L, Region = "PWW", ForestType = "Forest: Douglas-fir Group", Cause = "Harvest", Carbon = 100), P)
check("Douglas-fir in PNW West: the softwood sawlog carbon by hand", abs(s1[Wood == "SW" & LogSize == "Sawlog", Carbon] - 100 * swc * g$SoftwoodSawtimberFraction) < 1e-9)
check("a tropical hardwood type is all hardwood", s[Wood == "SW", sum(Carbon)] < 300 - 1e-9 && abs(s[, sum(Carbon)] - 300) < 1e-9)
check("an unknown forest type takes the regional average and is reported", identical(attr(s, "unmatched"), "Made-up Group"))

# ---- the spin-up -----------------------------------------------------------------------------------------------------------
run <- wp_split(data.table(Iteration = 1L, Year = 1985:2000, Region = "NE", ForestType = "Oak/Hickory Group", Cause = "Harvest", Carbon = 50), P)
sp <- wp_spinup(run, P, start = 1985L)
h <- P$history[Region == "NE" & Year %in% 1985:1994]
check("the scale is the run's first-decade carbon over the history's volume, by wood type",
      all(sp$scale[, abs(Scale - RunCarbon / h[Wood == .BY$Wood, sum(Removals)]) < 1e-9, by = Wood]$V1))
check("the scaled history in 1950 = scale x 1950 removals", abs(sp$history[Year == 1950L & Wood == "HW", sum(Carbon)] - sp$scale[Wood == "HW", Scale] * P$history[Region == "NE" & Wood == "HW" & Year == 1950L, Removals]) < 1e-6)
check("a run whose first decade passes the end of the history stops with the year",
      inherits(e <- tryCatch(wp_spinup(wp_split(data.table(Iteration = 1L, Year = 2012:2030, Region = "NE", ForestType = "Oak/Hickory Group", Cause = "Harvest", Carbon = 50), P), P), error = identity), "error") &&
      grepl("ends in 2016", conditionMessage(e)))

# ---- triangular draws ------------------------------------------------------------------------------------------------------
tri <- wp_triangle(0.85, 1, 1.15, 0.9); Ft <- function(x) if (x <= tri[2]) (x - tri[1])^2 / ((tri[3] - tri[1]) * (tri[2] - tri[1])) else 1 - (tri[3] - x)^2 / ((tri[3] - tri[1]) * (tri[3] - tri[2]))
check("the triangle's 5% and 95% points are the table's bounds", abs(Ft(0.85) - 0.05) < 1e-9 && abs(Ft(1.15) - 0.95) < 1e-9)
tri <- wp_triangle(0.7, 1, 1.2, 0.9)
check("an asymmetric triangle too", { Fa <- function(x) if (x <= 1) (x - tri[1])^2 / ((tri[3] - tri[1]) * (1 - tri[1])) else 1 - (tri[3] - x)^2 / ((tri[3] - tri[1]) * (tri[3] - 1)); abs(Fa(0.7) - 0.05) < 1e-9 && abs(Fa(1.2) - 0.95) < 1e-9 })
set.seed(3); r <- wp_rtri(2e5, wp_triangle(0.85, 1, 1.15, 0.9))
check("sampled draws hit the bounds' 5% and 95%", abs(mean(r < 0.85) - 0.05) < 0.003 && abs(mean(r > 1.15) - 0.05) < 0.003)
check("the land-clearing share stays within 0 and 1 in every draw", { d <- wp_draws(P, n = 500, seed = 2); all(d$lcu >= 0 & d$lcu <= 1) && abs(mean(d$lcu) - 0.5) < 0.03 })

cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
