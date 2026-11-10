# =============================================================================
# make_wetland_forest.R - the forested wetland twins of three forest type groups (to-do 53, user 2026-11-09/10)
# =============================================================================
# Hydric FIA conditions (physiographic class 31-39) of the Spruce/Fir (120), Oak/Gum/Cypress (600) and Elm/Ash/Cottonwood (700)
# groups take their own codes 121, 601 and 701 (src/fia.R fia_hydric_group), and run as the classes Wetland: Spruce/Fir Group,
# Wetland: Oak/Gum/Cypress Group and Wetland: Elm/Ash/Cottonwood Group. Their Ids lie in 100-999, so growth, spin-up and stage 8 treat
# them as forest. User: "all the transitions that exist for those three forest classes will need to be updated for their wetland
# counterparts" - so every row of an upland class in the defaults below is copied for its twin, with the class (and its Ag
# Contraction transition types) renamed. A twin row already in a file is replaced, so the tool reruns when upland rows change.
# Rows fitted from FIA by other tools (stem turnover, ECM share, harvest ages) are copies of the upland values until that tool is
# rerun on the split conditions; land cover crosswalks are not copied (stage 5 assigns the twins on wetland cells).
# Usage: Rscript tools/make_wetland_forest.R            (from the repository root)
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
D <- function(...) file.path(pkg, "defaults", ...)

TW <- data.table(Up = c(120L, 600L, 700L), Id = c(121L, 601L, 701L), Group = c("Spruce/Fir Group", "Oak/Gum/Cypress Group", "Elm/Ash/Cottonwood Group"),
                 Color = c("255,140,170,60", "255,40,120,130", "255,140,90,40"), Loc = c("H14", "H15", "H16"))
TW[, `:=`(UpName = paste0("Forest: ", Group), Name = paste0("Wetland: ", Group))]
# names an upland row may hold, and the twin's
nm <- c(setNames(TW$Name, TW$UpName),
        setNames(paste0("Ag Contraction Cropland: Wetland ", TW$Group), paste0("Ag Contraction Cropland: ", TW$Group)),
        setNames(paste0("Ag Contraction Pasture: Wetland ", TW$Group), paste0("Ag Contraction Pasture: ", TW$Group)))

rd <- function(f) fread(f, sep = ",", colClasses = "character", na.strings = NULL, encoding = "UTF-8", fill = TRUE)
wr <- function(x, f) { for (k in names(x)) set(x, which(x[[k]] == ""), k, NA_character_); fwrite(x, f, quote = "auto", na = ""); cat(sprintf("%-62s %d rows\n", sub(paste0(pkg, "/"), "", f), nrow(x))) }
# rows naming an upland class (or its transition types) copied for the twin, after any old twin rows are dropped;
# ids: extra exact-value replacements in named columns, e.g. list(StateClassId = c(`120` = "121"))
twin_file <- function(f, ids = list(), skip_col = character()) {
  x <- rd(f); cols <- setdiff(names(x), skip_col)
  is_tw <- Reduce(`|`, lapply(cols, function(k) x[[k]] %in% nm)) & !Reduce(`|`, lapply(cols, function(k) x[[k]] %in% names(nm)))
  if (length(ids)) is_tw <- is_tw | Reduce(`|`, lapply(names(ids), function(k) x[[k]] %in% ids[[k]]))
  x <- x[!is_tw]
  up <- Reduce(`|`, lapply(cols, function(k) x[[k]] %in% names(nm)))
  if (length(ids)) up <- up | Reduce(`|`, lapply(names(ids), function(k) x[[k]] %in% names(ids[[k]])))
  y <- copy(x[up])
  for (k in cols) { h <- y[[k]] %in% names(nm); if (any(h)) set(y, which(h), k, unname(nm[y[[k]][h]])) }
  for (k in names(ids)) { h <- y[[k]] %in% names(ids[[k]]); if (any(h)) set(y, which(h), k, unname(ids[[k]][y[[k]][h]])) }
  wr(rbind(x, y), f); invisible(y) }
grp <- setNames(as.character(TW$Id), as.character(TW$Up))

# ---- definitions ----------------------------------------------------------------------------------------------------------------
sc <- rd(D("stsim", "stsim_StateClass.csv")); sc <- sc[!Id %in% TW$Id]
sc <- rbind(sc, TW[, .(Name, StateLabelXId = "Wetland", StateLabelYId = Group, Id = as.character(Id), Color, Legend = "", Description = "", IsAutoName = "")])
setorder(sc, Name); wr(sc, D("stsim", "stsim_StateClass.csv"))
tt <- rd(D("stsim", "stsim_TransitionType.csv")); tt <- tt[!Name %in% nm]
new <- tt[Name %in% names(nm)][, Name := unname(nm[Name])]
used <- as.integer(tt$Id); new[, Id := as.character(setdiff(1009:1999, used)[seq_len(.N)])]
wr(rbind(tt, new), D("stsim", "stsim_TransitionType.csv"))
twin_file(D("stsim", "stsim_TransitionTypeGroup.csv"))

# ---- growth and carbon ----------------------------------------------------------------------------------------------------------
x <- rd(D("growth", "forest-type-crosswalk.csv")); x <- x[!StateClassId %in% TW$Id]
y <- x[StateClassId %in% TW$Up][, `:=`(StateClassName = paste("Wetland", StateClassName), FiaTypeGroups = grp[FiaTypeGroups],
                                       Note = "forested wetland twin: hydric FIA conditions (physiographic class 31-39) of the upland group (to-do 53)", StateClassId = grp[StateClassId])]
wr(rbind(x, y), D("growth", "forest-type-crosswalk.csv"))
x <- rd(D("growth", "merch-carbon-density.csv")); x <- x[!StateClassId %in% TW$Id]
y <- x[StateClassId %in% TW$Up][, `:=`(StateClassName = paste("Wetland", StateClassName), StateClassId = grp[StateClassId])]
wr(rbind(x, y), D("growth", "merch-carbon-density.csv"))
for (m in c("cbm-defaults", "fia-measured")) {
  twin_file(D("carbon-assumptions", m, "cbm-crosswalk.csv"))
  twin_file(D("carbon-assumptions", m, "growth-inputs.csv"), ids = list(FiaTypeGroups = grp)) }
twin_file(D("carbon-assumptions", "fia-measured", "live-turnover.csv"))
twin_file(D("cbm", "species-crosswalk.csv"))
for (f in c("co2-classes.csv", "co2-ecm-share.csv")) twin_file(D("climate", f))   # then tools/make_co2_default_betas.R writes the betas table
for (f in c("return-interval.csv", "soil-targets.csv")) twin_file(D("spinup", f))

# ---- transitions ----------------------------------------------------------------------------------------------------------------
twin_file(D("transitions", "harvest-age.csv"))
for (f in c("ag-contraction", "ag-expansion", "fire", "harvest", "urbanization")) twin_file(D("transitions", "pathways", paste0(f, ".csv")))
x <- rd(D("transitions", "state-locations.csv")); x <- x[!StateClassIdSource %in% TW$Name]
x <- rbind(x, TW[, .(Iteration = "", Timestep = "", StratumIdSource = "", StateClassIdSource = Name, StratumIdDest = "", StateClassIdDest = Name,
                     AgeMin = "", AgeMax = "", Location = Loc)])
wr(x, D("transitions", "state-locations.csv"))
cat("done\n")
