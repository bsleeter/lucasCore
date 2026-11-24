# =============================================================================
# unit-wetland-params.R - the wetland methane parameters of a scenario and their uncertainty (src/wetland-params.R; no SyncroSim)
# =============================================================================
# Usage: Rscript tests/unit-wetland-params.R   (from the package folder)
# =============================================================================
suppressPackageStartupMessages(library(data.table))
source("src/wetland-params.R"); source("src/nonforest-solve.R")
ok <- 0; bad <- 0
expect <- function(what, cond, detail = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, detail, "\n") } }
fails <- function(expr) inherits(tryCatch(expr, error = function(e) e), "error")
rd <- function(...) fread(file.path("defaults", ...), colClasses = "character", na.strings = "", encoding = "UTF-8")
reg <- rd("stockflow", "emergent-wetland-regions.csv"); fw <- rd("spinup", "wetland-ch4.csv"); zn <- rd("stockflow", "marsh-salinity-ch4.csv"); fit <- rd("stockflow", "emergent-wetland-fit.csv")
memb <- rd("stockflow", "stsim_FlowTypeGroupMembership.csv"); cf <- rd("climate", "flow-multipliers.csv")

# ---- options -------------------------------------------------------------------------------------------------------------------
o <- wetland_options()
expect("the package options are the values the model runs with: the two Q10s of the climate table, the solver's cap, the memberships' CO2e",
       o$MethaneQ10 == as.numeric(cf[FlowGroupId == "Q10 Wetland CH4", Q10]) && o$SoilQ10 == as.numeric(cf[FlowGroupId == "Q10 Wetland Flows", Q10]) && o$MethaneQ10 == 2.57 && o$SoilQ10 == 1.5 && o$MethaneCapShare == NF_CH4$max_share &&
       all(abs(as.numeric(memb[grepl("CH4$", FlowTypeId) & grepl("\\(CO2e\\)$", FlowGroupId), Value])) == o$MethaneCO2e) && o$UncertaintyDraws == 0L && !length(o$changed))
o2 <- wetland_options(data.frame(MethaneQ10 = 3.5, SoilQ10 = NA, MethaneCapShare = 0.25, MethaneCO2e = NA, UncertaintyDraws = 20))
expect("a scenario's row replaces what it fills in and leaves the rest", o2$MethaneQ10 == 3.5 && o2$SoilQ10 == 1.5 && o2$MethaneCapShare == 0.25 && o2$MethaneCO2e == 33.5 && identical(o2$UncertaintyDraws, 20L) &&
       setequal(o2$changed, c("MethaneQ10", "MethaneCapShare", "UncertaintyDraws")))
expect("a value out of range is refused (a Q10 under 1, a cap over a half)", fails(wetland_options(data.frame(MethaneQ10 = 0.5))) && fails(wetland_options(data.frame(MethaneCapShare = 0.8))))
# the Q10s by climate flow group (stages 7 and 11): the emergent classes' litter and soil take SoilQ10 (1.5 when blank); the forested
# wetland soil takes it only when the scenario sets it, else it keeps the climate table's 2.0 (NA here)
q0 <- wetland_q10s(o); q1 <- wetland_q10s(wetland_options(data.frame(SoilQ10 = 1.8)))
expect("the Q10s handed to the climate stages: methane, the emergent wetland flows, and the forested wetland soil only when the scenario sets the wetland Q10",
       identical(names(q0), c("Q10 Wetland CH4", "Q10 Wetland Flows", "Q10 Wetland Soil")) && q0[[1]] == 2.57 && q0[[2]] == 1.5 && is.na(q0[[3]]) && q1[[2]] == 1.8 && q1[[3]] == 1.8 &&
       all(names(q0) %in% cf$FlowGroupId) && as.numeric(cf[FlowGroupId == "Q10 Wetland Soil", Q10]) == 2)

# ---- targets -------------------------------------------------------------------------------------------------------------------
t0 <- wetland_class_targets(reg, fw)
expect("package targets: every emergent region and the three forested classes, as the tables have them", nrow(t0) == nrow(reg) + nrow(fw) && all(t0$Source == "package") &&
       isTRUE(all.equal(t0[StateClassId == "Wetland: Palustrine Emergent" & Region == "Coastal Plains", Target], as.numeric(reg[StateClassId == "Wetland: Palustrine Emergent" & Region == "Coastal Plains", CH4]))))
# the package ranges (drafted from the literature 2026-11-17): every class target and every salinity zone has a low and a high around it
rgs <- rd("stockflow", "wetland-methane-targets.csv"); t0r <- wetland_class_targets(reg, fw, NULL, rgs); z0 <- wetland_zone_targets(zn)
expect("the Fill file repeats the package targets, and gives every one a low and a high that straddle it", nrow(rgs) == nrow(t0) && !anyNA(t0r$Low) && !anyNA(t0r$High) && all(t0r$Low < t0r$Target & t0r$Target < t0r$High) &&
       isTRUE(all.equal(t0r$Target, t0$Target)) && isTRUE(all.equal(sort(as.numeric(rgs$Target)), sort(t0$Target))))
expect("every salinity zone target has a package range that straddles it", !anyNA(z0$Low) && !anyNA(z0$High) && all(z0$Low < z0$Target & z0$Target < z0$High))
expect("a scenario row replaces the package range with its own (none when it gives none)", wetland_class_targets(reg, fw, data.frame(StateClassId = "Wetland: Oak/Gum/Cypress Group", Region = NA, Target = 0.3, TargetLow = NA, TargetHigh = NA), rgs)[StateClassId == "Wetland: Oak/Gum/Cypress Group", is.na(Low) && is.na(High)])
sh <- data.frame(StateClassId = c("Wetland: Estuarine Emergent", "Wetland: Estuarine Emergent", "Wetland: Oak/Gum/Cypress Group"), Region = c(NA, "California", NA),
                 Target = c(0.2, 0.05, 0.3), TargetLow = c(0.1, NA, 0.1), TargetHigh = c(0.5, NA, 0.9))
t1 <- wetland_class_targets(reg, fw, sh)
expect("a class-wide row sets every region of the class, a region's own row wins there, other classes keep the package values",
       all(t1[StateClassId == "Wetland: Estuarine Emergent" & Region != "California", Target == 0.2 & Low == 0.1 & High == 0.5]) &&
       t1[StateClassId == "Wetland: Estuarine Emergent" & Region == "California", Target == 0.05 && is.na(Low)] && t1[StateClassId == "Wetland: Oak/Gum/Cypress Group", Target == 0.3 && High == 0.9] &&
       identical(t1[StateClassId == "Wetland: Palustrine Emergent", Target], t0[StateClassId == "Wetland: Palustrine Emergent", Target]) && t1[StateClassId == "Wetland: Palustrine Emergent", all(Source == "package")])
expect("a row for a class without methane, an unknown region, or a low above its target is refused",
       fails(wetland_class_targets(reg, fw, data.frame(StateClassId = "Forest: Oak/Hickory Group", Region = NA, Target = 0.1, TargetLow = NA, TargetHigh = NA))) &&
       fails(wetland_class_targets(reg, fw, data.frame(StateClassId = "Wetland: Estuarine Emergent", Region = "Atlantis", Target = 0.1, TargetLow = NA, TargetHigh = NA))) &&
       fails(wetland_class_targets(reg, fw, data.frame(StateClassId = "Wetland: Estuarine Emergent", Region = NA, Target = 0.1, TargetLow = 0.2, TargetHigh = NA))))
z1 <- wetland_zone_targets(zn, data.frame(Region = "Gulf and South Atlantic", Zone = "oligohaline", Target = 1.0, TargetLow = 0.5, TargetHigh = 1.6))
expect("salinity zone targets: the scenario's row replaces that region and zone only", z1[Region == "Gulf and South Atlantic" & Zone == "oligohaline", Target == 1 && Low == 0.5 && High == 1.6] &&
       sum(z1$Source == "scenario") == 1 && nrow(z1) == nrow(zn) && fails(wetland_zone_targets(zn, data.frame(Region = "CONUS", Zone = "fresh", Target = 1, TargetLow = NA, TargetHigh = NA))))

# ---- no refit: the share from the fitted belowground emission is the fit's own -----------------------------------------------------
f0 <- wetland_share(as.numeric(fit$CH4), as.numeric(fit$BelowgroundEmission), o$MethaneCapShare)
expect("the methane share from the target and the fitted belowground emission is the share the fit wrote (so a new target needs no refit)", max(abs(f0 - as.numeric(fit$CH4Share))) < 2e-5,
       sprintf("largest gap %.2e", max(abs(f0 - as.numeric(fit$CH4Share)))))
expect("a target beyond the cap is held at the cap", wetland_share(10, 2, 0.3) == 0.3)

# ---- the triangular draw ------------------------------------------------------------------------------------------------------
expect("triangular quantiles: the ends, the mode at its own probability, rising", tri_quantile(0, 1, 2, 5) == 1 && tri_quantile(1, 1, 2, 5) == 5 && abs(tri_quantile(0.25, 1, 2, 5) - 2) < 1e-12 &&
       !is.unsorted(tri_quantile(seq(0, 1, 0.05), 1, 2, 5)))
expect("a target without a range is itself at any quantile; a blank end is the target", all(target_at(0.9, c(0.4, 0.4), c(NA, 0.4), c(NA, NA)) == c(0.4, 0.4)) && target_at(0.01, 0.4, 0.2, NA) < 0.4 && target_at(0.99, 0.4, NA, 0.8) > 0.4)
q <- wetland_quantiles(200)
expect("the quantiles of the draws are reproducible, between 0 and 1, and leave the session's random numbers alone",
       identical(q, wetland_quantiles(200)) && all(q > 0 & q < 1) && abs(mean(q) - 0.5) < 0.08 && { set.seed(1); a <- runif(1); set.seed(1); invisible(wetland_quantiles(5)); identical(a, runif(1)) })

# ---- the factors: carbon neutral, within the cap -----------------------------------------------------------------------------------
fa <- wetland_factors(c(0.05, 0.2, 0.2), c(2, 0.5, 4), 0.3)
expect("the CO2 factor takes off what the methane factor adds, and methane stays within the cap", max(abs((1 - c(0.05, 0.2, 0.2)) * fa$co2 + c(0.05, 0.2, 0.2) * fa$ch4 - 1)) < 1e-12 &&
       all(c(0.05, 0.2, 0.2) * fa$ch4 <= 0.3 + 1e-12) && abs(fa$ch4[3] - 1.5) < 1e-12 && all(fa$co2 > 0))
bud <- data.table(StratumId = c("Subtropical", "Subtropical", "Marine"), StateClassId = c("Wetland: Estuarine Emergent", "Wetland: Palustrine Emergent", "Wetland: Estuarine Emergent"),
                  f = c(0.043, 0.103, 0.007), Target = c(0.16, 0.40, 0.025), Low = c(0.05, NA, NA), High = c(0.5, 0.9, NA))
r <- wetland_iteration_rows(bud, 50, 0.3)
expect("iteration rows: 50 draws and a closing iteration for the two classes with a range, a methane and a CO2 row each, none for the class without one",
       nrow(r) == 51 * 2 * 2 && setequal(r$FlowGroupId, WETLAND_FACTOR_GROUPS) && all(r$FlowMultiplierTypeId == METHANE_UNCERTAINTY_TYPE) && !"Marine" %in% r$StratumId && setequal(r$Iteration, 1:51))
# ST-Sim carries an iteration's rows on to later iterations, so the one after the last draw is written with factors of 1
expect("the iteration after the last draw goes back to the central targets (factors of 1)", all(r[Iteration == 51, Value] == 1) && any(r[Iteration == 50, Value] != 1))
w <- dcast(r, Iteration + StratumId + StateClassId ~ FlowGroupId, value.var = "Value"); w <- merge(w, bud, by = c("StratumId", "StateClassId"))
expect("every iteration's pair is carbon neutral for its class, and its methane stays between the low and the high and within the cap",
       w[, max(abs((1 - f) * get(WETLAND_FACTOR_GROUPS[["co2"]]) + f * get(WETLAND_FACTOR_GROUPS[["ch4"]]) - 1))] < 1e-5 &&
       w[, all(get(WETLAND_FACTOR_GROUPS[["ch4"]]) * Target >= ifelse(is.na(Low), Target, Low) - 1e-6 & get(WETLAND_FACTOR_GROUPS[["ch4"]]) * Target <= High + 1e-6 & get(WETLAND_FACTOR_GROUPS[["ch4"]]) * f <= 0.3 + 1e-6)])
m1 <- w[StateClassId == "Wetland: Estuarine Emergent", get(WETLAND_FACTOR_GROUPS[["ch4"]])]; m2 <- w[StateClassId == "Wetland: Palustrine Emergent", get(WETLAND_FACTOR_GROUPS[["ch4"]])]
expect("an iteration is high or low for every class together (one quantile), and the draws spread on both sides of the target", cor(m1, m2, method = "spearman") > 0.9 && any(m1 < 1) && any(m1 > 1) && all(m2 >= 1 - 1e-9))
expect("no ranges, or no draws: no rows", !nrow(wetland_iteration_rows(bud[3], 50, 0.3)) && !nrow(wetland_iteration_rows(bud, 0, 0.3)))

# ---- the CO2 equivalent of methane ---------------------------------------------------------------------------------------------
m2 <- ch4_co2e_memberships(memb, 36); ch <- grepl("CH4$", memb$FlowTypeId) & grepl("\\(CO2e\\)$", memb$FlowGroupId)
expect("the CO2e of methane: every CH4 flow's weight in a CO2e group is the new value with its sign kept; nothing else moves", sum(ch) > 20 &&
       all(abs(as.numeric(m2$Value[ch])) == 36) && identical(sign(as.numeric(m2$Value[ch])), sign(as.numeric(memb$Value[ch]))) && identical(m2$Value[!ch], memb$Value[!ch]) &&
       identical(ch4_co2e_memberships(memb, 33.5)$Value, memb$Value))
# the Build guard: a scenario's own stock-flow definitions against the package's (definition_gaps)
want <- list(order = rd("stockflow", "stsim_FlowOrder.csv"), members = memb, filters = rd("stockflow", "stsim_OutputFilterFlows.csv"))
fw6 <- c(outer(c("AG Very Fast", "AG Fast", "AG Slow"), c("(Wetland)", "CH4"), function(p, g) sprintf("Emission: %s -> Atmosphere %s", p, g)))
old <- list(order = want$order[!FlowTypeId %in% fw6], members = want$members[!FlowTypeId %in% fw6], filters = want$filters[!FlowGroupId %in% paste(fw6, "[Type]")])
g <- definition_gaps(want, old)
expect("complete definitions have no gaps", !length(definition_gaps(want, want)))
expect("the six forested wetland flow types exist in the package's order, memberships and filters", all(fw6 %in% want$order$FlowTypeId) && all(fw6 %in% want$members$FlowTypeId) && all(paste(fw6, "[Type]") %in% want$filters$FlowGroupId))
expect("definitions from before the forested wetland methane flows are caught in all three sheets, with the count", length(g) == 3 && all(grepl("6 missing", g)) && identical(names(g), c("flow order", "flow type group memberships", "flow output filters")))
expect("a gap in one sheet alone is named alone", identical(names(definition_gaps(want, list(order = want$order, members = old$members, filters = want$filters))), "flow type group memberships"))
cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
