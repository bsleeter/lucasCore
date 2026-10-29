# =============================================================================
# unit-growth-mature-rates.R - fast checks of to-dos 28-30 (Mature Age by Forest Type, Growth Inputs, Carbon Rates), no SyncroSim
# =============================================================================
#   1. Growth Inputs: the preset rows (what Fill writes) give exactly the package defaults; a change reaches the tables; a type the
#      package has no inputs for stops with an error
#   2. the fine root share: blank = Li et al. (2003) exactly as before; a fixed share is used as given
#   3. Mature Age by Forest Type: no rows = the previous dwm_targets (git HEAD src/calibrate.R) exactly; rows at the single value change
#      nothing; a row of 80 yr for one type drops only that type's young mature plots; an ecodivision row wins over its type's row
#   4. Carbon Rates: each row's rate is the flow value the model runs with, and decay rows = base x temperature effect x multiplier x share
# Usage: Rscript tests/unit-growth-mature-rates.R
# =============================================================================
suppressPackageStartupMessages(library(data.table)); pkg <- "F:/lucasCore"; ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
for (f in c("growth.R", "carbon.R", "flows.R", "dom.R", "calibrate.R")) source(file.path(pkg, "src", f))
rd <- function(...) fread(file.path(pkg, "defaults", ...), colClasses = "character", na.strings = "")
git_env <- function(file) { e <- new.env(); tf <- tempfile(fileext = ".R"); writeLines(system2("git", c("-C", pkg, "show", paste0("HEAD:src/", file)), stdout = TRUE), tf); sys.source(tf, envir = e); e }
cw0 <- rd("growth", "forest-type-crosswalk.csv"); den0 <- rd("growth", "merch-carbon-density.csv")
scl <- fread(file.path(pkg, "defaults", "stsim", "stsim_StateClass.csv"), colClasses = "character")[, .(Id, Name)]

# 1. Growth Inputs
pre <- fread(file.path(pkg, "defaults", "carbon-assumptions", "fia-measured", "growth-inputs.csv"), colClasses = "character", na.strings = "")
g <- growth_inputs(cw0, den0, pre, scl)
expect("preset Growth Inputs = the package defaults (crosswalk)", identical(g$cw, cw0))
expect("preset Growth Inputs = the package defaults (density, deciduous share)", identical(g$dens, den0))
expect("preset Growth Inputs: nothing reported as changed, no fixed fine root share", !length(g$changed) && all(is.na(g$fine)), paste(g$changed, collapse = "; "))
g0 <- growth_inputs(cw0, den0, NULL, scl); expect("empty sheet = the package defaults", identical(g0$cw, cw0) && identical(g0$dens, den0))
u <- copy(pre)[1:2]; u[1, `:=`(FiaTypeGroups = "100; 120", GrowthClass = "2", MerchCarbonDensity = "0.25", FineRootShare = "0.1")]; u[2, GrowthClass := "West Hardwood"]
g1 <- growth_inputs(cw0, den0, u, scl); s1 <- cw0$StateClassId[1]; s2 <- cw0$StateClassId[2]
expect("a change reaches the tables", g1$cw[StateClassId == s1, FiaTypeGroups] == "100;120" && g1$cw[StateClassId == s1, LagClass] == "EastHardwood" &&
       g1$cw[StateClassId == s2, LagClass] == "WestHardwood" && as.numeric(g1$dens[StateClassId == s1, MgCPerM3]) == 0.25 && g1$fine[[s1]] == 0.1 && is.na(g1$fine[[s2]]),
       paste(g1$changed, collapse = " | "))
expect("only the changed types differ", identical(g1$cw[-(1:2)], cw0[-(1:2)]) && identical(g1$dens[-1], den0[-1]))
e <- tryCatch(growth_inputs(cw0, den0, data.table(StateClassId = "Grassland: Annual", FiaTypeGroups = "1", GrowthClass = "1", MerchCarbonDensity = "1", DeciduousShare = "0"), scl), error = conditionMessage)
expect("a type without package growth inputs stops with an error", is.character(e) && grepl("no package growth inputs", e), if (is.character(e)) e else "")
e <- tryCatch(growth_inputs(cw0, den0, pre[1][, FiaTypeGroups := "1x0"], scl), error = conditionMessage)
expect("malformed FIA groups stop with an error", is.character(e) && grepl("codes separated", e))

# 2. fine root share
age <- 0:150; live <- 200 * (1 - exp(-0.03 * age)); sf <- c(s0 = 0.1, s_inf = 0.04, tau = 20); sb <- c(s0 = 0.3, s_inf = 0.2, tau = 30)
old <- git_env("carbon.R")
a <- old$cbm_pools(age, live, sf, sb, 0.4 * live); b <- cbm_pools(age, live, sf, sb, 0.4 * live); b2 <- cbm_pools(age, live, sf, sb, 0.4 * live, NA_real_)
expect("blank fine root share = Li et al. exactly as before", identical(a, b) && identical(a, b2))
f <- cbm_pools(age, live, sf, sb, 0.4 * live, 0.25)
expect("a fixed fine root share is used as given", max(abs(f$FineRoots - 0.25 * (f$FineRoots + f$CoarseRoots))) < 1e-12 && max(abs(f$TotalLive - b$TotalLive)) < 1e-12)

# 3. Mature Age by Forest Type
dwf <- "F:/lucas-master/Data Sources/FIA/DataMart/fia-deadwood.rds"
if (file.exists(dwf)) {
  dw <- readRDS(dwf); oc <- git_env("calibrate.R")
  key <- function(x) x$obs[, band := as.character(band)][order(sc, ecodiv, band)]
  same <- function(a, b) isTRUE(all.equal(key(a), key(b), check.attributes = FALSE))
  a <- oc$dwm_targets(dw, cw0, 60, 30); b <- dwm_targets(dw, cw0, 60, 30)
  expect("no rows = the previous targets exactly", same(a, b), sprintf("%d target rows, %d plots", nrow(a$obs), sum(a$obs$n)))
  by0 <- data.table(sc = cw0$StateClassId, ecodiv = NA_character_, age = 60L, recent = 30L)
  expect("rows at the single values change nothing", same(dwm_targets(dw, cw0, 60, 30), dwm_targets(dw, cw0, 60, 30, by0)))
  s <- b$obs[, .(n = sum(n)), by = sc][which.max(n), sc]
  c80 <- dwm_targets(dw, cw0, 60, 30, data.table(sc = s, ecodiv = NA_character_, age = 80L, recent = 30L))
  n <- function(x, k) x$obs[sc == k, sum(n)]; old80 <- b$ages[sc == s & stdage >= 80, sum(N)]   # the same plots from 80 yr (the outlier cap stays the 60-yr set's)
  expect("an 80-yr row for one type: that type from 80 yr, the others as at 60", n(c80, s) == old80 && all(sapply(setdiff(unique(b$obs$sc), s), function(k) n(c80, k) == n(b, k))),
         sprintf("type %s: %d -> %d plots", s, n(b, s), n(c80, s)))
  e1 <- unique(b$obs[sc == s, ecodiv])[1]
  ce <- dwm_targets(dw, cw0, 60, 30, data.table(sc = s, ecodiv = c(NA, e1), age = c(80L, 60L), recent = 30L))
  expect("an ecodivision row wins over its type's row", ce$obs[sc == s & ecodiv == e1, sum(n)] == b$obs[sc == s & ecodiv == e1, sum(n)] &&
         ce$obs[sc == s & ecodiv != e1, sum(n)] == c80$obs[sc == s & ecodiv != e1, sum(n)], sprintf("ecodivision %s", e1))
} else cat("SKIP  Mature Age checks: no", dwf, "\n")

# 4. Carbon Rates
cbm <- file.path(pkg, "defaults", "cbm"); sp <- rd("cbm", "species-crosswalk.csv")[1]
r <- turnover_rates(sp$StateClassId, TRUE, 0.1, cbm, sp$EcoBoundaryId, sp$SpeciesTypeId); dp <- dom_parameters(dom_parameter_default(cbm))
mult <- list(snag = 0.8, cwd = 1.3, fwd = 2, litter = 0.5, duff = 1.1, soil = 0.7)
v <- scale_decay(set_snag_fall(dom_flow_values(r, TRUE, 8, cbm, dp = dp), 0.06), mult, SNAG_FALL_FLOWS)
x <- rate_rows(v, r, dp, 8, mult, "litter", "Ecodivision", "gSSURGO target", "Cell (300 snags)")
expect("one row per flow, rate = the value the model runs with", nrow(x) == length(v) && identical(x$Rate, unname(v)))
d <- x[!is.na(BaseRate)]; k <- names(DOM_POOLS)[match(d$FromStockTypeId, DOM_POOLS)]; share <- ifelse(d$Process == "Emission", dp$patm[k], 1 - dp$patm[k])
tot <- x[, .(t = sum(Rate)), by = FromStockTypeId]; capped <- d$FromStockTypeId %in% tot[t > 1 - 1e-9, FromStockTypeId]
expect("decay rows: rate = base x temperature effect x multiplier x share", max(abs((d$BaseRate * d$TemperatureEffect * d$Multiplier * share - d$Rate)[!capped])) < 1e-12, sprintf("%d rows", sum(!capped)))
src <- function(pool, proc) x[FromStockTypeId == DOM_POOLS[[pool]] & Process == proc, Source][1]
expect("sources: litter fixed by the user, soil from gSSURGO, snag fall measured, turnover CBM",
       grepl("fixed by the user", src("AGVF", "Decay")) && grepl("gSSURGO", src("BGS", "Emission")) && grepl("^Measured snag fall", src("SnagStem", "Transfer")) &&
       grepl("calibrated \\(Ecodivision\\)", src("AGM", "Decay")) && all(grepl("^CBM", x[Process == "Biomass Turnover", Source])),
       paste(unique(x$Source), collapse = " | "))
ru <- turnover_rates(sp$StateClassId, TRUE, 0.1, cbm, sp$EcoBoundaryId, sp$SpeciesTypeId, list(FoliageTurnover = 0.2))
xu <- rate_rows(dom_flow_values(ru, TRUE, 8, cbm, dp = dp), ru, dp, 8, list())
expect("a Live Turnover value shows as the user's", grepl("^User", xu[grepl("Foliage", FromStockTypeId), Source]) && xu[grepl("Foliage", FromStockTypeId), Rate] == 0.2)
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
