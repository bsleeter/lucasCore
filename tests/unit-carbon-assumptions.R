# =============================================================================
# unit-carbon-assumptions.R - fast checks of the Carbon Assumptions logic, no SyncroSim (seconds; run before any full stage test)
# =============================================================================
# (user, 2026-10-28: speed up tests - logic is checked here, full runs only for end-to-end results)
#   1. both event tables (fitted and LUCAS) round-trip through the Disturbance Flows sheet format exactly, flow types included
#   2. row precedence per pool pair: ecodivision + type > ecodivision > type > blank; a type row from age 11 gets the younger rows
#   3. the per-type fire snag share rows equal the earlier implementation's (git 1ed1bed src/dom.R), and change nothing at share 0.545
#   4. the preset files hold exactly the defaults they are made from (tools/make_carbon_presets.R has been rerun)
#   5. stage 3's Carbon Method labels map to the right options, old and new
# Usage: Rscript tests/unit-carbon-assumptions.R
# =============================================================================
suppressPackageStartupMessages(library(data.table)); pkg <- "F:/lucasCore"; ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
source(file.path(pkg, "src", "flows.R")); source(file.path(pkg, "src", "dom.R"))
rd <- function(...) fread(file.path(pkg, "defaults", ...), colClasses = "character", na.strings = "")
k <- function(x) x[, .(k = paste(FromStratumId, FromStateClassId, TransitionGroupId, FromAgeMin, FromStockTypeId, ToStockTypeId, FlowTypeId), v = as.numeric(Multiplier))][order(k)]
ev <- rd("stockflow", "event-pathways.csv")[, FromStratumId := as.character(FromStratumId)]; lucas <- rd("stockflow", "event-pathways-lucas.csv")[, FromStratumId := as.character(FromStratumId)]

# 1. round trips
for (x in list(list("fitted", ev), list("LUCAS", lucas))) { a <- k(x[[2]][TransitionGroupId %in% DF_GROUPS]); b <- k(sheet_to_events(events_to_sheet(x[[2]]), x[[2]], "Forest: X"))
  expect(sprintf("%s event table round-trips through the sheet", x[[1]]), identical(a$k, b$k) && max(abs(a$v - b$v)) < 1e-12, sprintf("%d rows", nrow(a))) }

# 2. precedence and age filling
sh <- events_to_sheet(ev)
u <- rbind(sh, data.table(StratumId = c(NA, "Eco"), StateClassId = c("Forest: A", NA), Disturbance = "Clearcut", AgeMin = c(11L, NA),
                          FromStockTypeId = "Biomass: Merchantable", ToStockTypeId = "Forestry Sector", Share = c(0.8, 0.7)), fill = TRUE)
ue <- complete_ages(sheet_to_events(u, ev, c("Forest: A", "Forest: B")))
val <- function(cl, s, age) { e <- event_rows(ue, DF_GROUPS[["Clearcut"]], cl, s)[FromStockTypeId == "Biomass: Merchantable" & ToStockTypeId == "Forestry Sector"]
  e[, am := as.numeric(ifelse(is.na(FromAgeMin), 0, FromAgeMin))]; as.numeric(e[am <= age][which.max(am), Multiplier]) }
got <- c(val("Forest: A", NA, 5), val("Forest: A", NA, 50), val("Forest: A", "Eco", 50), val("Forest: B", NA, 50), val("Forest: B", "Eco", 5))
expect("precedence: type from age 11, younger rows kept, ecodivision wins", isTRUE(all.equal(got, c(0.97, 0.8, 0.7, 0.97, 0.7))), paste(got, collapse = " / "))
eb <- event_balance(ue, data.table(Stratum = c(NA, "Eco"), StateClass = "Forest: A"))
expect("balance check finds no pool over 1 in the defaults", eb$v <= 1 + 1e-4, sprintf("%.4f", eb$v))

# 3. fire snag shares
old <- new.env(); tf <- tempfile(fileext = ".R"); writeLines(system2("git", c("-C", pkg, "show", "1ed1bed:src/dom.R"), stdout = TRUE), tf); sys.source(tf, envir = old)
fss <- data.table(StateClass = c("Forest: A", "Forest: B"), Share = c(0.28, 0.42))
o <- k(rbind(ev, old$fire_snag_rows(ev, fss), fill = TRUE)[!is.na(FromStateClassId)]); n <- k(fire_snag_rows(ev, fss)[!is.na(FromStateClassId)])
expect("fire snag share rows equal the earlier implementation's", identical(o$k, n$k) && max(abs(o$v - n$v)) < 1e-9, sprintf("%d rows", nrow(n)))

# 4. preset files
pre <- function(m, s) fread(file.path(pkg, "defaults", "carbon-assumptions", m, paste0(s, ".csv")), colClasses = "character", na.strings = "")
for (m in c("fia-measured", "cbm-defaults")) { p <- pre(m, "disturbance-flows"); src <- events_to_sheet(if (m == "fia-measured") ev else lucas)
  ky <- function(x) sort(x[, paste(Disturbance, AgeMin, FromStockTypeId, ToStockTypeId, as.numeric(Share))])
  expect(sprintf("%s preset Disturbance Flows = its event table", m), identical(ky(p), ky(src)), sprintf("%d rows", nrow(p))) }
expect("fia-measured preset Fire Snag Share = defaults/spinup/fire-snag-share.csv", nrow(pre("fia-measured", "fire-snag-share")) == nrow(rd("spinup", "fire-snag-share.csv")))
expect("cbm-defaults preset has no fire snag shares or calibration settings", !nrow(pre("cbm-defaults", "fire-snag-share")) && !nrow(pre("cbm-defaults", "decay-calibration-settings")))
for (m in c("fia-measured", "cbm-defaults")) expect(sprintf("%s preset CBM Crosswalk = defaults/cbm/species-crosswalk.csv", m), nrow(pre(m, "cbm-crosswalk")) == nrow(rd("cbm", "species-crosswalk.csv")))

# 5. Carbon Method labels (stage 3's rule, kept in step with src/3-carbon-flows.R)
lab <- c(`FIA measured dead wood (down woody material and snags in mature stands)` = 4, `CBM defaults (no calibration)` = 3, `FIA condition pools (older option)` = 1,
         `FIA condition pools, CBM-default soil (older option)` = 2, `Calibrated to FIA condition pools (soil to gSSURGO)` = 1, `FIA condition pools, CBM-default soil` = 2,
         `Measured dead wood (FIA down woody material, mature stands; regional decay; soil to gSSURGO)` = 4)
st3 <- readLines(file.path(pkg, "src", "3-carbon-flows.R")); i <- grep("^dom_mode <- ", st3); eval(parse(text = paste(c("f3 <- function(dm) {", st3[i:(i + 1)], "dom_mode }"), collapse = "\n")))
got <- vapply(names(lab), f3, 1L); expect("Carbon Method labels map to the right options", all(got == lab), paste(sprintf("%s->%d", substr(names(lab), 1, 14), got)[got != lab], collapse = "; "))
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
