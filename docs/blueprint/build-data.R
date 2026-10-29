# =============================================================================
# build-data.R - the lucasCore data blueprint: every national dataset, the stages that read it, what for, and what switches it
# =============================================================================
# Companion to build.R (stages and datasheets). Writes lucascore-data-blueprint.svg (print), lucascore-data-blueprint.png (2x) and
# data.html (light/dark; click a dataset or a stage). The dataset list, display names and default paths come from package.xml's Data
# Sources sheet; the groups, short labels, vintages and what each stage does with each dataset are set below. The build stops when
# package.xml has a Data Sources column the drawing does not place, or when a stage script and the uses below disagree about which
# columns it reads (stage 2 and 3 read the FIA columns through src/fia.R, stage 10 NCCPI also through src/nccpi.R).
# Usage: Rscript docs/blueprint/build-data.R [out_dir]
# =============================================================================
suppressPackageStartupMessages({ library(xml2); library(jsonlite) })
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "docs/blueprint")
pkg <- normalizePath(file.path(here, "..", ".."), winslash = "/")
args <- commandArgs(TRUE); out <- if (length(args)) args[1] else here
dir.create(out, showWarnings = FALSE, recursive = TRUE)
source(file.path(here, "style.R"))

x <- read_xml(file.path(pkg, "package.xml")); version <- xml_attr(x, "version")
cols <- xml_find_all(x, "/package/dataSheet[@name='DataSource']/column")
ds_display <- setNames(xml_attr(cols, "displayName"), xml_attr(cols, "name"))
ds_default <- setNames(xml_attr(cols, "defaultValue"), xml_attr(cols, "name"))

# ---- the datasets: group, label, vintage, and per stage what it is read for -------------------------------------------------------
# u(stage, role, note, alt): note = the setting that switches it; alt = TRUE when only a non-default option reads it (dashed wire)
u <- function(stage, role, note = NA_character_, alt = FALSE) list(stage = stage, role = role, note = note, alt = alt)
fia_note <- "Growth Curve Options > FIA Data: USGS condition tables (default)"
D <- list(
  list("FIA and strata", "EcodivisionFile", "FIA ecodivisions", "dissolved shapefile · StrtmId, StrtmNm", list(
    u(1, "Primary strata and the model lattice"), u(2, "Each plot's ecodivision, and the ecodivision climate the curves use"),
    u(3, "Ecodivisions of the decay calibration and their climate"), u(5, "The model lattice (the same grid as stage 1)"), u(6, "The model lattice"))),
  list("FIA and strata", "FiaConditionFile", "FIA condition carbon and volume", "USGS data release · 2024-02-12 · .Rds", list(
    u(2, "Condition carbon and merchantable volume the curves are fitted to", fia_note), u(3, "Condition carbon pools for the decay calibration", fia_note))),
  list("FIA and strata", "FiaDisturbanceFile", "FIA disturbance and treatment codes", "USGS data release · 2024-02-13 · .Rds", list(
    u(2, "Disturbance and treatment codes of each condition", fia_note), u(3, "Disturbance and treatment codes of each condition", fia_note))),
  list("FIA and strata", "FiaDataMartFolder", "FIA DataMart", "state PLOT, COND, TREE, DWM csvs + REFERENCE", list(
    u(2, "Condition tables derived from the state CSVs, in place of the USGS release", "Growth Curve Options > FIA Data: FIA DataMart", TRUE),
    u(3, "Measured down dead wood (COND_DWM_CALC) the decay is calibrated to", "Carbon Method: FIA measured dead wood (default)"))),
  list("Land cover, age and soil", "NlcdFolder", "Annual NLCD", "Collection 1 · 30 m · one map a year", list(
    u(1, "Start-year land mask, modal on the model grid"), u(5, "Annual land cover on the model grid; developed, agriculture, water and ice classes", "Build Options > Land Cover Resampling"),
    u(6, "Land-use change (class gains and losses) and the clearcut rule"), u(10, "The 30 m annual record the suitability surfaces are fitted on"))),
  list("Land cover, age and soil", "Evt2016File", "LANDFIRE EVT 2016", "LF 2.0.0 · 30 m", list(
    u(5, "Forest, shrub and grass types: the most common 30 m class in each cell", "Build Options > Forest Type Map: LANDFIRE EVT (default)"))),
  list("Land cover, age and soil", "Evt2001File", "LANDFIRE EVT 2001", "LF 1.0.5 · 30 m", list(
    u(5, "Vegetation types alongside EVT 2016", "Land Cover Crosswalks > EVT 2001"))),
  list("Land cover, age and soil", "RcmapFile", "RCMAP vegetation class", "2001", list(u(5, "Rangeland vegetation classes", "Land Cover Crosswalks > RCMAP"))),
  list("Land cover, age and soil", "CcapFile", "C-CAP land cover", "2001 · coastal wetlands", list(u(5, "Wetland types (C-CAP classes 90 and up)", "Land Cover Crosswalks > C-CAP"))),
  list("Land cover, age and soil", "ForestTypeGroupFolder", "USFS forest type groups", "NFCMS regional maps", list(
    u(5, "Forest types in place of LANDFIRE EVT", "Build Options > Forest Type Map: USFS forest type groups", TRUE))),
  list("Land cover, age and soil", "StandAgeFile", "NASA CMS forest age", "1990", list(u(5, "Stand age, averaged over each cell"))),
  list("Land cover, age and soil", "FriFile", "LANDFIRE fire return interval", "LF 2016 · FRI_REPLAC", list(
    u(5, "Replacement-fire return interval per ecodivision and forest class, for spin-up"))),
  list("Land cover, age and soil", "SoilCarbonFile", "gSSURGO soil organic carbon", "0 to 999 mm", list(
    u(5, "Mean soil carbon per ecodivision and forest class: the target stage 3 calibrates to"), u(8, "Soil carbon map for the initial soil pool"))),
  list("Disturbance", "MtbsSeverityFolder", "MTBS burn severity", "annual CONUS mosaics", list(
    u(6, "Wildfire by severity (burned share of 30 m pixels), and burned cells kept out of the clearcut rule"))),
  list("Disturbance", "LcmsFolder", "USFS LCMS annual change", "v2025-11 · 30 m · 1985 on", list(
    u(6, "Clearcut and selection harvest from Tree Removal", "defaults/transitions/sources.csv: Lcms (default)"),
    u(10, "Harvest events the clearcut and selection surfaces are fitted on", "Projection Allocation > Event Classes: LCMS (default)"))),
  list("Disturbance", "LandfireDisturbanceFolder", "LANDFIRE disturbance", "annual · US_DIST · 1999 on", list(
    u(6, "Disturbance by type, for a transition group whose source is Landfire", "defaults/transitions/sources.csv: Landfire", TRUE),
    u(10, "Event classes LANDFIRE:<type>", "Projection Allocation > Event Classes: LANDFIRE", TRUE))),
  list("Disturbance", "FirePerimeterHistoryFile", "Interagency fire perimeter history", "all years · wildfire perimeters", list(
    u(8, "Last disturbance: high-severity fire where a perimeter since 1900 covers the cell, else clearcut"),
    u(9, "Fire sizes (one per incident and year) for the projection size distribution", "Fire > Fire Method: Historical rates (default)"),
    u(10, "Recently burned pixels kept out of the fit", "Suitability Options > Burn Window"))),
  list("Disturbance", "BurnProbabilityFile", "FSim burn probability", "CONUS LF2020 · 270 m", list(
    u(9, "Burn probability that guides where projected fire spreads and starts", "Fire > Fire Method: Burn probability", TRUE))),
  list("Disturbance", "FpaFodFile", "FPA-FOD fire occurrence", "7th edition · geopackage", list(
    u(9, "Ignition density, smoothed (5 km default)", "Fire > Ignitions: FPA-FOD ignition density", TRUE))),
  list("Climate", "PrismFolder", "PRISM", "annual tmean and ppt · normals", list(
    u(2, "Ecodivision climate for the growth curves"), u(3, "Ecodivision climate for the decay calibration"),
    u(7, "Annual temperature and precipitation for the historical climate multipliers", "Climate Options"))),
  list("Climate", "Loca2Folder", "LOCA2", "GCM / member / SSP", list(
    u(11, "Projected climate of one scenario, model and replicate", "Projection > Climate"))),
  list("Covariates", "RoadsFile", "LANDFIRE roads", "LF2023 · 30 m", list(u(10, "Distance to roads covariate", "Suitability Covariates"))),
  list("Covariates", "ElevationFile", "LANDFIRE elevation", "LF2020 · 30 m", list(
    u(9, "Slope selectivity of projected fire (burned share by slope)", "Fire > Slope Selectivity (default on)"),
    u(10, "Elevation and slope covariates", "Suitability Covariates"), u(12, "Hillshade under the maps, when the path is set"))),
  list("Covariates", "WuiFolder", "SILVIS WUI blocks", "v4 · 1990 to 2020 change", list(u(10, "Housing density and WUI classes of the census blocks", "Suitability Covariates; Rule Weights"))),
  list("Covariates", "NccpiFile", "gNATSGO crop productivity", "NCCPI · 30 m", list(
    u(10, "Crop productivity covariate of ag expansion and contraction (blank path = fetched from Planetary Computer)", "Suitability Covariates"))),
  list("Covariates", "ForestOwnerFile", "USFS forest ownership", "circa 2017 · 30 m", list(u(10, "Forest owner type covariate of clearcut and selection", "Suitability Covariates"))))
names(D) <- vapply(D, `[[`, "", 2)
if (length(m <- setdiff(names(ds_display), names(D)))) stop("Data Sources column(s) not in the data blueprint: ", paste(m, collapse = ", "))
if (length(m <- setdiff(names(D), names(ds_display)))) stop("not a Data Sources column in package.xml: ", paste(m, collapse = ", "))

# ---- the stages that read data (12 stands for 12 to 14) ----------------------------------------------------------------------------
S <- list(
  `1` = list("1", "Study Area and Strata", "Model grid, land mask, primary, secondary and tertiary strata rasters", "Build Options (cell size, strata sources); Study Area"),
  `2` = list("2", "Fit Growth Curves", "Merchantable volume and live-tree carbon curves per forest class and ecodivision", "Growth Curve Options (FIA Data, fit settings)"),
  `3` = list("3", "Carbon Flows", "Stock-flow parameters and the dead organic matter decay calibration", "Carbon Method; the Carbon Assumptions sheets"),
  `5` = list("5", "Initial Conditions", "State class and stand age maps, annual NLCD on the grid, return intervals, soil targets", "Build Options (Forest Type Map, Land Cover Resampling); Land Cover Crosswalks"),
  `6` = list("6", "Historical Transitions", "Historical transition pathways, targets and annual spatial multipliers", "defaults/transitions/sources.csv (where each transition group comes from)"),
  `8` = list("8", "Initial Stock Maps", "Initial carbon stock maps by age and last disturbance", "Carbon Assumptions > Spin-up"),
  `9` = list("9", "Projection Transitions", "Projection transition targets, fire sizes and slope selectivity", "Projection Options; Projection Transitions; Fire"),
  `10` = list("10", "Transition Suitability", "Surfaces that place projected transitions, with adjacency and patch sizes", "Projection Allocation; Suitability Options and Covariates; Rule Weights"),
  `7` = list("7", "Climate Multipliers", "Historical climate flow multipliers on growth and decomposition", "Climate Options (forest and non-forest growth, decomposition)"),
  `11` = list("11", "Projection Climate", "Projection climate flow multipliers", "Projection > Climate (LOCA2 scenario, model, replicate)"),
  `12` = list("12–14", "Build, Run and Compare Figures", "PNG figures of a Build, a run, and a run comparison", "Run Figures; Compare Runs"))
scripts <- list(`2` = c("2-growth-curves.R", "fia.R"), `3` = c("3-carbon-flows.R", "fia.R"), `10` = c("10-transition-suitability.R", "nccpi.R"),
                `12` = c("12-build-figures.R", "13-run-figures.R", "14-compare-runs.R"))
src_text <- function(id) { f <- scripts[[id]]; if (is.null(f)) f <- basename(Sys.glob(file.path(pkg, "src", sprintf("%s-*.R", id))))
  paste(unlist(lapply(file.path(pkg, "src", f), readLines, warn = FALSE)), collapse = "\n") }
for (id in names(S)) { txt <- src_text(id)
  reads <- names(ds_display)[vapply(names(ds_display), function(c) grepl(c, txt, fixed = TRUE), TRUE)]
  mine <- names(D)[vapply(D, function(d) any(vapply(d[[5]], function(z) as.character(z$stage) == id, TRUE)), TRUE)]
  if (length(m <- setdiff(reads, mine))) stop(sprintf("stage %s reads %s but the data blueprint has no use for it", id, paste(m, collapse = ", ")))
  if (length(m <- setdiff(mine, reads))) stop(sprintf("the data blueprint says stage %s reads %s, but its script does not mention it", id, paste(m, collapse = ", "))) }

# ---- drawing ----------------------------------------------------------------
W <- 1600; H <- 1000
g <- character(); add <- function(...) g <<- c(g, ...)
add(sprintf('<rect class="bg" width="%d" height="%d"/>', W, H), TX(24, 44, "lucasCore data blueprint", "h1"),
    TX(24, 66, sprintf("The national datasets lucasCore reads, the stages that read them, what for, and the option that switches each one · version %s", version), "sub"))
leg <- function(items, y) { w <- vapply(items, function(it) 6.2 * nchar(it$label) + 30, 0); x0 <- 1576 - sum(w) + 12
  for (i in seq_along(items)) { xx <- x0 + sum(w[seq_len(i - 1)]); it <- items[[i]]
    add(if (!is.null(it$fam)) sprintf('<rect class="lg f-%s" x="%s" y="%s" width="14" height="12" rx="2"/>', it$fam, xx, y - 10)
        else sprintf('<path d="M%s,%s h18" class="wire f-setup%s" style="opacity:1"/>', xx, y - 4, if (it$alt) " alt" else ""), TX(xx + 24, y, it$label, "lgt")) } }
leg(list(list(fam = "setup", label = "Setup"), list(fam = "land", label = "Land cover and change"), list(fam = "carbon", label = "Carbon"),
         list(fam = "climate", label = "Climate"), list(fam = "fig", label = "Figures")), 38)
leg(list(list(alt = FALSE, label = "read with the default settings"), list(alt = TRUE, label = "read only under a non-default option")), 62)

add(box(24, 104, 600, 830, "Data Sources sheet · project scope", "National datasets"), TX(312, 146, "VINTAGE · RESOLUTION", "ghead"))
y <- 172; sy <- c(); grp <- ""
for (d in D) {
  if (d[[1]] != grp) { if (nzchar(grp)) y <- y + 12; grp <- d[[1]]; add(TX(40, y, toupper(grp), "ghead")); y <- y + 21 }
  add(sprintf('<g class="ds" data-ds="%s" tabindex="0" role="button" aria-label="%s"><rect class="dsbg" x="32" y="%d" width="584" height="22" rx="3"/>', d[[2]], esc(d[[3]]), y - 15),
      TX(40, y, d[[3]], "dsn"), TX(312, y, d[[4]], "dsv"), "</g>")
  sy[d[[2]]] <- y - 4; y <- y + 23 }
if (y > 934) stop("the dataset column runs past its box (y = ", y, ")")

BX <- 1000; BWD <- 576; BHT <- 64
by <- setNames(104 + (seq_along(S) - 1) * 76, names(S))
uses <- do.call(rbind, lapply(D, function(d) do.call(rbind, lapply(d[[5]], function(z)
  data.frame(ds = d[[2]], stage = as.character(z$stage), alt = z$alt, sy = sy[[d[[2]]]], stringsAsFactors = FALSE)))))
uses$ty <- NA_real_
for (id in names(S)) { k <- which(uses$stage == id); k <- k[order(uses$sy[k])]
  uses$ty[k] <- by[[id]] + 6 + (seq_along(k) - 0.5) * 52 / length(k) }
for (i in seq_len(nrow(uses))) { r <- uses[i, ]; f <- fam[[r$stage]]
  add(sprintf('<path class="wire f-%s%s" data-ds="%s" data-stage="%s" d="M616,%s C808,%s 808,%.1f %d,%.1f"/>', f, if (r$alt) " alt" else "",
              r$ds, r$stage, r$sy, r$sy, r$ty, BX - 2, r$ty)) }
for (n in names(sy)) add(sprintf('<circle class="sport" cx="616" cy="%s" r="3"/>', sy[[n]]))
for (id in names(S)) { s <- S[[id]]; yy <- by[[id]]; bw <- if (nchar(s[[1]]) > 2) 44 else 24
  add(sprintf('<g class="stage f-%s" data-stage="%s" tabindex="0" role="button" aria-label="Stage %s, %s">', fam[[id]], id, s[[1]], esc(s[[2]])),
      sprintf('<rect class="sb" x="%d" y="%d" width="%d" height="%d" rx="5"/>', BX, yy, BWD, BHT),
      sprintf('<rect class="badge" x="%d" y="%d" width="%d" height="20" rx="3"/>', BX + 10, yy + 9, bw), TX(BX + 10 + bw / 2, yy + 23, s[[1]], "badge-t", "middle"),
      TX(BX + 20 + bw, yy + 24, s[[2]], "sn2"), TX(BX + 12, yy + 43, s[[3]], "mk"), TX(BX + 12, yy + 57, paste("Set by:", s[[4]]), "ch"), "</g>")
  for (ty in uses$ty[uses$stage == id]) add(sprintf('<circle class="port f-%s" cx="%d" cy="%.1f" r="2.4"/>', fam[[id]], BX, ty)) }

add(TX(24, 962, "Wires run from a dataset to each stage that reads it, coloured by the stage. Vintages are those of the default paths in package.xml (Data Sources: a blank sheet uses them).", "foot"),
    TX(24, 978, sprintf("Stages 0 and 4 read no national data. Generated by docs/blueprint/build-data.R from package.xml (lucasCore %s), %s.", version, format(Sys.Date())), "foot"))
body <- paste(c(defs, g), collapse = "\n")
head <- svg_head(W, H, "lucasCore data blueprint: national datasets and the stages that read them")
svg_file <- file.path(out, "lucascore-data-blueprint.svg")
writeLines(standalone_svg(head, body), svg_file, useBytes = TRUE)

# ---- interactive page -------------------------------------------------------
dsj <- lapply(D, function(d) list(col = d[[2]], label = d[[3]], group = d[[1]], vintage = d[[4]], display = unname(ds_display[[d[[2]]]]),
  path = if (is.na(ds_default[[d[[2]]]])) "" else unname(ds_default[[d[[2]]]]),
  uses = lapply(d[[5]], function(z) list(stage = as.character(z$stage), role = z$role, note = if (is.na(z$note)) "" else z$note, alt = z$alt))))
stj <- lapply(names(S), function(id) { s <- S[[id]]
  list(id = id, label = s[[1]], name = s[[2]], family = fam[[id]], makes = s[[3]], set = s[[4]],
       reads = unname(lapply(Filter(function(d) any(vapply(d[[5]], function(z) as.character(z$stage) == id, TRUE)), D), function(d) {
         z <- Filter(function(z) as.character(z$stage) == id, d[[5]])[[1]]
         list(col = d[[2]], label = d[[3]], role = z$role, note = if (is.na(z$note)) "" else z$note, alt = z$alt) }))) })
names(stj) <- names(S)
json <- gsub("</", "<\\/", toJSON(list(datasets = unname(dsj), stages = stj), auto_unbox = TRUE), fixed = TRUE)
tpl <- paste(readLines(file.path(here, "template-data.html"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
writeLines(fill_page(tpl, paste0(head, "\n", body, "\n</svg>"), json, version, length(D)), file.path(out, "data.html"), useBytes = TRUE)

render_png(svg_file, file.path(out, "lucascore-data-blueprint.png"), W, H)
cat("svg:", svg_file, "\nhtml:", file.path(out, "data.html"), "\n")
