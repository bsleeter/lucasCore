# =============================================================================
# build.R - the lucasCore blueprint: one schematic of the package's scenarios, stages and datasheets
# =============================================================================
# Writes three files from one drawing:
#   lucascore-blueprint.svg  print figure (light colours, fonts from Google Fonts with Arial/Consolas fallbacks)
#   lucascore-blueprint.png  the same at 2x, through headless Chrome or Edge when one is installed
#   index.html               the same drawing, light/dark aware; click a stage for every datasheet it reads and writes
# Stage names, scripts, datasheet inputs and outputs and the ST-Sim column come from package.xml; the layout, stage families, the
# national data groups and the one-line descriptions are set below. Rerun after changing package.xml; a stage or an ST-Sim sheet the
# layout does not place stops the build.
# Usage: Rscript docs/blueprint/build.R [out_dir]
# =============================================================================
suppressPackageStartupMessages({ library(xml2); library(jsonlite) })
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "docs/blueprint")
pkg <- normalizePath(file.path(here, "..", ".."), winslash = "/")
args <- commandArgs(TRUE); out <- if (length(args)) args[1] else here
dir.create(out, showWarnings = FALSE, recursive = TRUE)
source(file.path(here, "style.R"))

# ---- package.xml ------------------------------------------------------------
x <- read_xml(file.path(pkg, "package.xml"))
version <- xml_attr(x, "version")
ds <- xml_find_all(x, "/package/dataSheet")
dn <- setNames(xml_attr(ds, "displayName"), xml_attr(ds, "name"))
pretty <- function(s) { if (s %in% names(dn)) return(unname(dn[[s]]))
  p <- gsub("([a-z])([A-Z])", "\\1 \\2", sub("^(stsim|core)_", "", s)); paste0(if (startsWith(s, "core_")) "SyncroSim: " else "ST-Sim: ", p) }
tr <- xml_find_all(x, "/package/transformer[@programArguments]")
st <- lapply(tr, function(t) { sh <- xml_find_all(t, "dataSheet")
  list(id = as.integer(sub(" .*", "", xml_attr(t, "displayName"))), name = sub("^[0-9]+ - ", "", xml_attr(t, "displayName")),
       script = xml_attr(t, "programArguments"), sheet = xml_attr(sh, "name"), type = xml_attr(sh, "type")) })
names(st) <- vapply(st, function(s) as.character(s$id), "")
writers <- function(sheets) sort(unique(as.integer(unlist(lapply(st, function(s) if (any(s$sheet %in% sheets & s$type %in% c("Output", "Both"))) s$id)))))

if (length(miss <- setdiff(names(st), names(fam)))) stop("stage(s) not in the blueprint layout: ", paste(miss, collapse = ", "))
where <- c(`0` = "Stock-Flow Definitions; also first in the Build pipeline (writes nothing there when the dependency has the definitions)",
  `1` = "Build", `2` = "Build, or once in the optional Growth Curves scenario shared by several builds", `3` = "Build", `4` = "Build",
  `5` = "Build", `6` = "Build", `7` = "Build", `8` = "Build",
  `9` = "Projection Setup; also Build for a continuous run (mode 1) and a projection scenario that starts from a historical run (mode 2)",
  `10` = "Projection Setup", `11` = "Projection Climate (one scenario per LOCA2 run)", `12` = "Build (last in its pipeline)",
  `13` = "A scenario on an ST-Sim run result", `14` = "A scenario on several ST-Sim run results")
desc <- c(`0` = "Writes the fixed LUCAS stock-flow definitions from defaults/stockflow: flow pathway diagram, flow order, flow and stock type groups, output options and filters.",
  `1` = "Makes the model grid at the Build cell size, cuts it to the study area, and writes the primary (FIA ecodivision), secondary and tertiary strata rasters.",
  `2` = "Fits merchantable volume curves and the live-tree carbon curves (CBM pools) for every forest state class and FIA ecodivision.",
  `3` = "Sets the stock-flow parameters (net growth, growth split, turnover, dead organic matter decay) and the full flow configuration, with decay calibrated to the Carbon Method.",
  `4` = "Spins up each ecodivision and forest state class and writes initial carbon stocks by age and last disturbance.",
  `5` = "Maps state class and stand age at the model resolution, resamples annual NLCD to the model grid, and writes the per-cell spin-up return intervals and soil carbon targets.",
  `6` = "Derives the historical transition pathways and annual transition spatial multipliers from the same resampled maps as the state classes.",
  `7` = "Writes annual climate flow spatial multipliers for the historical years from PRISM, with the Climate Options growth and decomposition methods.",
  `8` = "Maps the initial carbon stocks (ST-Sim Initial Stocks, spatial) from the stock curves, stand age and soil carbon.",
  `9` = "Sets projection transitions by drawing a whole historical year for each projection year and iteration; transition groups in one sampling set share the draw.",
  `10` = "Makes the surfaces that place projected transitions: fitted suitability (logistic GAM on the annual NLCD record) or WUI/PAD rules, with adjacency and patch sizes.",
  `11` = "Writes the climate flow spatial multipliers of the projection years from one LOCA2 run.",
  `12` = "Draws the publication figures (PNG) of a Build result.",
  `13` = "Draws report figures (PNG) of one ST-Sim run on a lucasCore Build.",
  `14` = "Draws figures (PNG) and two summary tables (carbon, land change) that compare ST-Sim runs on one Build.")

# ---- drawing helpers --------------------------------------------------------
wrap2 <- function(s) { if (nchar(s) <= 19) return(s); sp <- gregexpr(" ", s)[[1]]; k <- sp[which.min(abs(sp - nchar(s) / 2))]
  c(substr(s, 1, k - 1), substr(s, k + 1, nchar(s))) }
BW <- 172; BH <- 64
block <- function(id, x, y, ghost = FALSE) { s <- st[[as.character(id)]]; nm <- wrap2(s$name)
  ny <- if (length(nm) == 1) y + 25 else c(y + 19, y + 33)
  paste0(sprintf('<g class="stage f-%s%s" data-stage="%d" tabindex="0" role="button" aria-label="Stage %d, %s">', fam[[as.character(id)]],
                 if (ghost) " ghost" else "", id, id, esc(s$name)),
    sprintf('<rect class="sb" x="%d" y="%d" width="%d" height="%d" rx="5"/>', x, y, BW, BH),
    sprintf('<rect class="badge" x="%d" y="%d" width="24" height="20" rx="3"/>', x + 9, y + 10), TX(x + 21, y + 24, id, "badge-t", "middle"),
    paste(mapply(function(t, yy) TX(x + 41, yy, t, "sn"), nm, ny), collapse = ""), TX(x + 9, y + 54, sub("^src/", "", s$script), "ss"), "</g>") }
chip <- function(id, x, y) sprintf('<g class="chip f-%s" data-stage="%d"><rect x="%s" y="%s" width="18" height="14" rx="3"/>%s</g>',
  fam[[as.character(id)]], id, x, y, TX(x + 9, y + 10.5, id, "chip-t", "middle"))
chips <- function(ids, xr, y) paste(vapply(seq_along(ids), function(i) chip(ids[i], xr - (length(ids) - i + 1) * 21 + 3, y), ""), collapse = "")
engine <- function(xr, y) paste0(sprintf('<g class="engine"><rect x="%d" y="%d" width="54" height="18" rx="9"/>', xr - 54, y), TX(xr - 27, y + 12.5, "ST-Sim", "engine-t", "middle"), "</g>")
W <- 1600; H <- 1000
g <- character()
add <- function(...) g <<- c(g, ...)

# ---- header and legend ------------------------------------------------------
add(sprintf('<rect class="bg" width="%d" height="%d"/>', W, H),
    TX(24, 44, "lucasCore blueprint", "h1"),
    TX(24, 66, sprintf("SyncroSim 3 add-on to ST-Sim 4.5 · version %s · %d stages in src/ · the scenarios they run in and the datasheets they pass on", version, length(st)), "sub"))
leg <- function(items, y) { w <- vapply(items, function(it) 6.2 * nchar(it$label) + 30, 0); x0 <- 1576 - sum(w) + 12
  for (i in seq_along(items)) { xx <- x0 + sum(w[seq_len(i - 1)]); it <- items[[i]]
    add(if (!is.null(it$fam)) sprintf('<rect class="lg f-%s" x="%s" y="%s" width="14" height="12" rx="2"/>', it$fam, xx, y - 10)
        else if (it$kind == "bus") PATH(sprintf("M%s,%s h18", xx, y - 4), "bus", FALSE)
        else PATH(sprintf("M%s,%s h16", xx, y - 4), it$kind), TX(xx + 22, y, it$label, "lgt")) } }
leg(list(list(fam = "setup", label = "Setup"), list(fam = "land", label = "Land cover and change"), list(fam = "carbon", label = "Carbon"),
         list(fam = "climate", label = "Climate"), list(fam = "fig", label = "Figures")), 38)
leg(list(list(kind = "edge", label = "datasheet passed on"), list(kind = "dep", label = "scenario dependency"),
         list(kind = "bus", label = "shared map sheet")), 62)

# ---- national data ----------------------------------------------------------
data_groups <- list(
  list("FIA", c(1, 2, 3, 5, 6), c("FIADB DataMart (PLOT, COND, TREE)", "Condition carbon and volume (USGS)", "Disturbance and treatment codes", "FIA ecodivisions (primary strata)")),
  list("Land cover", c(1, 5, 6, 10), c("Annual NLCD", "LANDFIRE EVT 2001 and 2016", "RCMAP, C-CAP 2001", "USFS forest type groups", "NASA CMS forest age 1990")),
  list("Disturbance", c(5, 6, 8, 9, 10), c("LANDFIRE disturbance", "MTBS burn severity", "USFS LCMS annual change", "Interagency fire perimeters",
                                         "FPA-FOD fire occurrence", "FSim burn probability", "LANDFIRE fire return interval")),
  list("Climate", c(2, 3, 7, 11), c("PRISM annual and normals", "LOCA2 (scenario, model, replicate)")),
  list("Soil", c(5, 8), "gSSURGO soil organic carbon"),
  list("Covariates", c(9, 10), c("Roads and elevation (LANDFIRE)", "SILVIS WUI v4", "gNATSGO crop productivity", "USFS forest ownership")),
  list("Package defaults", c(0, 3, 4, 5, 6, 8, 9, 10), c("stockflow, stsim, strata", "carbon-assumptions, cbm, spinup", "growth, initialstocks, climate",
                                                          "landcover crosswalks", "transitions, projection rules")))
add(box(24, 104, 216, 830, "Data Sources sheet", "National data"))
y <- 172
for (i in seq_along(data_groups)) { d <- data_groups[[i]]
  if (i > 1) { add(sprintf('<line class="rule" x1="40" y1="%d" x2="224" y2="%d"/>', y - 15, y - 15)) }
  add(TX(40, y, d[[1]], "gt"))
  if (length(d[[2]]) > 5) { y <- y + 8; add(chips(d[[2]], 224, y)); y <- y + 14 } else add(chips(d[[2]], 224, y - 11))
  for (it in d[[3]]) { y <- y + 15; add(TX(40, y, it, "item")) }
  y <- y + 31 }
add(TX(40, y - 12, "(used when a sheet is left empty)", "lbl"))

# ---- definitions row --------------------------------------------------------
add(box(268, 104, 202, 136, "Scenario · dependency", "Stock-Flow Definitions"), block(0, 283, 160))
add(box(494, 104, 480, 136, "Scenario · dependency · input sheets", "Carbon Assumptions"))
ca <- c("CarbonOptions", "CbmCrosswalk", "LiveTurnover", "DisturbanceFlow", "FireSnagShare", "DecayCalibrationSetting", "FixedDecayMultiplier", "Spinup", "DomParameter")
for (i in seq_along(ca)) { cx <- 510 + ((i - 1) %% 3) * 153; cy <- 158 + ((i - 1) %/% 3) * 26
  add(sprintf('<g class="sheet" data-sheet="%s"><rect x="%d" y="%d" width="142" height="20" rx="3"/>%s</g>', ca[i], cx, cy, TX(cx + 8, cy + 14, sub("Dead Organic Matter", "DOM", dn[[ca[i]]]), "sheet-t"))) }
add(box(998, 104, 230, 136, "Scenario · optional, shared", "Growth Curves (CONUS)"), block(2, 1027, 160, ghost = TRUE))
add(PATH("M369,240 V266", "dep"), TX(375, 258, "dependency", "lbl"), PATH("M734,240 V266", "dep"), TX(740, 258, "dependency", "lbl"),
    PATH("M1113,240 V266", "dep"), TX(1119, 258, "optional dependency", "lbl"))

# ---- Build ------------------------------------------------------------------
add(box(268, 268, 960, 322, "Scenario · one per study area", "Build"))
add(TX(1212, 290, "PIPELINE", "eyebrow", "end"), TX(1212, 310, "0 › 1 › 5 › 2 › 3 › 4 › 6 › 7 › 8 › 12", "mono", "end"))
add(TX(284, 330, "LAND", "ghead"), TX(284, 574, "CARBON", "ghead"))
add(PATH("M300,446 H1020", "bus", FALSE), PATH("M1020,446 H1038", "edge"))                      # Initial Conditions Spatial
add('<line class="halo" x1="600" y1="440" x2="600" y2="452"/>')                                # 5 -> 3 crosses the bus
add(PATH("M600,398 V492"), TX(594, 482, "Return Intervals, Soil Targets", "lbl", "end"))       # 5 -> 3
add(PATH("M370,398 V442", "tap"), PATH("M520,398 V446", "tap", FALSE), PATH("M748,398 V446", "tap", FALSE),
    PATH("M920,446 V400", "tap"), PATH("M955,446 V492", "tap"))
for (cx in c(370, 520, 748, 920, 955)) add(sprintf('<circle class="dot" cx="%d" cy="446" r="3.2"/>', cx))
add(TX(612, 462, "Initial Conditions Spatial (ST-Sim maps)", "lbl"))
add(block(1, 284, 334), block(5, 473, 334), block(6, 662, 334), block(7, 851, 334), block(12, 1040, 414),
    block(2, 284, 494), block(3, 473, 494), block(4, 662, 494), block(8, 851, 494))
lane_edge <- function(x1, y, label, top) { cx <- x1 + 8.5
  add(PATH(sprintf("M%s,%s H%s", x1, y, x1 + 15)),
      if (top) PATH(sprintf("M%s,%s V330", cx, y - 8), "lead", FALSE) else PATH(sprintf("M%s,%s V566", cx, y + 8), "lead", FALSE),
      TX(cx, if (top) 326 else 577, label, "lbl", "middle")) }
lane_edge(645, 366, "Annual NLCD", TRUE)
lane_edge(456, 526, "Carbon Curves", FALSE)
lane_edge(645, 526, "Decay Calibration, Flow Multipliers", FALSE)
lane_edge(834, 526, "Initial Stock Curves", FALSE)
add(TX(1126, 494, "reads the summaries", "lbl", "middle"), TX(1126, 507, "of stages 1 to 8", "lbl", "middle"))

# ---- projection setup and climate ------------------------------------------
add(PATH("M494,590 V620", "dep"), TX(500, 610, "Build result", "lbl"), PATH("M859,590 V620", "dep"), TX(865, 610, "Build result", "lbl"))
add(box(268, 622, 452, 150, "Scenario · on the Build result", "Projection Setup"), block(9, 284, 690), block(10, 532, 690))
add(PATH("M456,722 H530"), TX(494, 714, "Projection", "lbl", "middle"), TX(494, 738, "Schedule", "lbl", "middle"))
add(box(744, 622, 230, 150, "Scenario · one per LOCA2 run", "Projection Climate"), block(11, 773, 690))

# ---- ST-Sim runs and analysis ----------------------------------------------
add(PATH("M268,560 H254 V869 H266", "dep"))
add(box(268, 804, 330, 130, "Scenario · pipeline ST-Sim", "Historical run"), engine(582, 812),
    TX(284, 870, "Depends on the Build result, then on", "txt"), TX(284, 885, "Stock-Flow Definitions (in that order).", "txt"),
    TX(284, 918, "tools/new-historical.R", "mono"))
add(PATH("M660,772 V802", "dep"), PATH("M859,772 V802", "dep"), PATH("M598,869 H620", "dep"))
add(box(622, 804, 352, 130, "Scenario · pipeline ST-Sim", "Projection run"), engine(958, 812),
    TX(638, 868, "Depends on Projection Setup, Projection Climate", "txt"), TX(638, 883, "and the Build result. Mode 1: one continuous run;", "txt"),
    TX(638, 898, "mode 2 starts from a historical run's final maps.", "txt"), TX(638, 920, "tools/new-projection.R", "mono"))
add(PATH("M974,869 H996", "dep"))
add(box(998, 622, 230, 312, "Scenarios · on run results", "Figures and comparison"), block(13, 1027, 690), block(14, 1027, 790),
    TX(1014, 882, "13 maps one run; 14 compares", "txt"), TX(1014, 897, "runs and writes carbon and", "txt"), TX(1014, 912, "land change summaries.", "txt"))

# ---- ST-Sim inputs and reports ---------------------------------------------
stsim <- list(
  Definitions = list("Flow Pathway Diagram" = "stsim_FlowPathwayDiagram", "Flow Order and Options" = c("stsim_FlowOrder", "stsim_FlowOrderOptions"),
    "Flow and Stock Type Groups" = c("stsim_FlowTypeGroupMembership", "stsim_StockTypeGroupMembership"),
    "Output Options and Filters" = c("stsim_OutputOptionsStockFlow", "stsim_OutputFilterFlows", "stsim_OutputFilterStocks", "stsim_OutputFilterTransitionGroups", "stsim_OutputOptionsSpatial")),
  "Initial conditions" = list("Initial Conditions Spatial" = "stsim_InitialConditionsSpatial", "Initial Stocks Spatial" = "stsim_InitialStockSpatial",
    "Spatial Multiprocessing tiles" = "core_SpatialMultiprocessing"),
  Transitions = list("Transitions" = "stsim_Transition", "Deterministic Transitions" = "stsim_DeterministicTransition",
    "Transition Targets" = "stsim_TransitionTarget", "Transition Spatial Multipliers" = "stsim_TransitionSpatialMultiplier",
    "Spatial Initiation Multipliers" = "stsim_TransitionSpatialInitiationMultiplier",
    "Size Distribution and Prioritization" = c("stsim_TransitionSizeDistribution", "stsim_TransitionSizePrioritization"),
    "Adjacency Settings and Multipliers" = c("stsim_TransitionAdjacencySetting", "stsim_TransitionAdjacencyMultiplier")),
  "Flows and state" = list("Flow Pathways" = "stsim_FlowPathway", "Flow Multipliers" = "stsim_FlowMultiplier",
    "Flow Spatial Multipliers" = "stsim_FlowSpatialMultiplier", "State Attribute Values" = "stsim_StateAttributeValue"))
written <- unique(unlist(lapply(st, function(s) s$sheet[grepl("^(stsim|core)_", s$sheet) & s$type %in% c("Output", "Both")])))
if (length(miss <- setdiff(written, unlist(stsim)))) stop("ST-Sim sheet(s) written but not placed in the blueprint: ", paste(miss, collapse = ", "))
reports <- list("Strata Summary" = "OutputStrataSummary", "State Class Summary" = "OutputStateClassSummary",
  "Growth and carbon curve parameters" = c("OutputGrowthParameter", "OutputCarbonParameter", "OutputGrowthReport"),
  "Decay Calibration" = "OutputDecayCalibration", "Return intervals, soil targets" = c("OutputReturnInterval", "OutputSoilTarget"),
  "Historical Transition Summary" = "OutputTransitionSummary", "Climate Multiplier Summary" = "OutputClimateSummary",
  "Initial Stock Summary" = "OutputInitialStockSummary",
  "Projection schedule, rates, fires" = c("OutputProjectionSchedule", "OutputProjectionRate", "OutputFireSize", "OutputFireSlope"),
  "Suitability maps and curves" = c("OutputSuitability", "OutputSuitabilityCurve", "OutputSuitabilityMap", "OutputPatchSize"),
  "Figures (PNG)" = c("OutputBuildFigure", "OutputRunFigure", "OutputCompareFigure"),
  "Run comparison summaries" = c("OutputCompareCarbon", "OutputCompareLand"))
row <- function(label, sheets, y) { w <- writers(sheets); if (!length(w)) stop("no stage writes ", paste(sheets, collapse = ", "))
  add(sprintf('<g class="row" data-sheet="%s" data-stages="%s">', paste(sheets, collapse = " "), paste(w, collapse = " ")),
      sprintf('<rect class="rowbg" x="1264" y="%d" width="304" height="18" rx="3"/>', y - 13), TX(1272, y, label, "rowt"), chips(w, 1560, y - 11), "</g>") }
add(box(1256, 104, 320, 830, "Written into ST-Sim", "ST-Sim inputs"))
y <- 172
for (gname in names(stsim)) { add(TX(1272, y, toupper(gname), "ghead")); y <- y + 18
  for (lab in names(stsim[[gname]])) { row(lab, stsim[[gname]][[lab]], y); y <- y + 19 }
  y <- y + 12 }
add(sprintf('<line class="rule" x1="1272" y1="%d" x2="1560" y2="%d"/>', y - 6, y - 6))
add(TX(1272, y + 18, "LUCASCORE REPORT SHEETS", "ghead")); y <- y + 36
for (lab in names(reports)) { row(lab, reports[[lab]], y); y <- y + 19 }
if (y > 934) stop("the ST-Sim column runs past its box (y = ", y, ")")

add(TX(24, 962, "Solid arrows: a datasheet one stage writes and a later stage reads. Dashed: a scenario dependency (the dependency supplies its sheets; the first one with rows wins). Chips: the stages that read a data group, or write a sheet.", "foot"),
    TX(24, 978, sprintf("Every stage also writes the Validation sheet. Generated by docs/blueprint/build.R from package.xml (lucasCore %s), %s.", version, format(Sys.Date())), "foot"))
body <- paste(c(defs, g), collapse = "\n")
head <- svg_head(W, H, "lucasCore blueprint: scenarios, stages and datasheets")
writeLines(standalone_svg(head, body), file.path(out, "lucascore-blueprint.svg"), useBytes = TRUE)

# ---- interactive page -------------------------------------------------------
sheet_list <- function(s, types) { k <- s$type %in% types & s$sheet != "OutputValidation"
  lapply(s$sheet[k], function(sh) list(sheet = sh, label = pretty(sh), from = setdiff(writers(sh), s$id),
    to = setdiff(sort(unique(as.integer(unlist(lapply(st, function(o) if (any(o$sheet == sh & o$type %in% c("Input", "Both"))) o$id))))), s$id))) }
stages_json <- lapply(st, function(s) { id <- as.character(s$id)
  list(id = s$id, name = s$name, script = s$script, family = fam[[id]], where = where[[id]], desc = desc[[id]],
       reads = sheet_list(s, "Input"), writes = sheet_list(s, "Output"), both = sheet_list(s, "Both")) })
json <- gsub("</", "<\\/", toJSON(stages_json, auto_unbox = TRUE), fixed = TRUE)
tpl <- paste(readLines(file.path(here, "template.html"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
writeLines(fill_page(tpl, paste0(head, "\n", body, "\n</svg>"), json, version, length(st), "package"), file.path(out, "index.html"), useBytes = TRUE)

render_png(file.path(out, "lucascore-blueprint.svg"), file.path(out, "lucascore-blueprint.png"), W, H)
cat("svg:", file.path(out, "lucascore-blueprint.svg"), "\nhtml:", file.path(out, "index.html"), "\n")
