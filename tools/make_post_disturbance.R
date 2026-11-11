# =============================================================================
# make_post_disturbance.R - the post-disturbance state classes (to-do 57, user decisions 2026-11-11)
# =============================================================================
# High-severity fire moves a forest or shrub cell into its type's disturbed class ("Disturbed: <type>", Id 2000 + the type's Id);
# age resets, so in the class age is years since the disturbance. From there a cell
#   - returns to its type (Post-disturbance: Forest Return / Shrub Return), each year with a chance from ReturnAgeMin to the window's
#     end, age carried over;
#   - converts at the window's end (Post-disturbance: Conversion): disturbed forest to its ecodivision's shrub class (ShrubShare) or
#     grass class, disturbed sage, sage steppe and chaparral to Grassland: Annual, disturbed Non-sage to its ecodivision's grass class;
#   - converts at a high-severity reburn inside the window (ReburnConversion of the reburns; the rest start again at age 0).
# Settings: defaults/transitions/post-disturbance-settings.csv (window, return, reburn, by parent class) and
# post-disturbance-regions.csv (each ecodivision's shrub and grass class). Rerunnable: every disturbed row is written again.
# Carbon rows (stage 3) are not written here.
# Usage: Rscript tools/make_post_disturbance.R            (from the repository root)
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
D <- function(...) file.path(pkg, "defaults", ...)
rd <- function(f) fread(f, sep = ",", colClasses = "character", na.strings = NULL, encoding = "UTF-8", fill = TRUE)
wr <- function(x, f) { for (k in names(x)) set(x, which(x[[k]] == ""), k, NA_character_); fwrite(x, f, quote = "auto", na = ""); cat(sprintf("%-62s %d rows\n", sub(paste0(pkg, "/"), "", f), nrow(x))) }
PFX <- "Disturbed: "; RET_F <- "Post-disturbance: Forest Return"; RET_S <- "Post-disturbance: Shrub Return"; CONV <- "Post-disturbance: Conversion"
SHRUB_PARENTS <- c("Shrubland: Sage", "Shrubland: Native Sage Steppe", "Shrubland: Invaded Sage Steppe", "Shrubland: Non-sage", "Shrubland: Chaparral")

# ---- the classes ------------------------------------------------------------------------------------------------------------
sc <- rd(D("stsim", "stsim_StateClass.csv")); sc <- sc[!startsWith(Name, PFX)]
par <- sc[(as.integer(Id) >= 100 & as.integer(Id) <= 999) | Name %in% SHRUB_PARENTS]
stopifnot(nrow(par) == 36, all(SHRUB_PARENTS %in% par$Name))
par[, kind := fifelse(as.integer(Id) >= 100, "Forest", "Shrub")]
# Y label: the parent's, except the wetland twins, whose own Y label is the upland type's ("Spruce/Fir Group")
par[, ylab := fifelse(StateLabelXId == "Wetland", paste("Wetland", StateLabelYId), StateLabelYId)]
par[, `:=`(dname = paste0(PFX, ylab), did = as.character(2000L + as.integer(Id)))]
stopifnot(!anyDuplicated(par$dname), !any(par$did %in% sc$Id))
new_sc <- par[, .(Name = dname, StateLabelXId = "Disturbed", StateLabelYId = ylab, Id = did,
                  Color = fifelse(kind == "Forest", "255,196,170,120", "255,236,220,170"), Legend = "", Description = "", IsAutoName = "")]
sc <- rbind(sc, new_sc); setorder(sc, Name); wr(sc, D("stsim", "stsim_StateClass.csv"))
lx <- rd(D("stsim", "stsim_StateLabelX.csv")); if (!"Disturbed" %in% lx$Name) { lx <- rbind(lx, data.table(Name = "Disturbed", Description = "")); setorder(lx, Name) }
wr(lx, D("stsim", "stsim_StateLabelX.csv"))
ly <- rd(D("stsim", "stsim_StateLabelY.csv")); add <- setdiff(par$ylab, ly$Name)
if (length(add)) { ly <- rbind(ly, data.table(Name = add, Description = "Disturbed")); setorder(ly, Name) }
wr(ly, D("stsim", "stsim_StateLabelY.csv"))

# ---- transition types and groups --------------------------------------------------------------------------------------------
tt <- rd(D("stsim", "stsim_TransitionType.csv")); keep_id <- setNames(tt$Id, tt$Name)
tt <- tt[!Name %in% c(RET_F, RET_S, CONV)]
ids <- vapply(c(RET_F, RET_S, CONV), function(n) if (!is.na(keep_id[n])) keep_id[[n]] else NA_character_, "")
free <- setdiff(1015:1999, as.integer(tt$Id)); ids[is.na(ids)] <- as.character(free[seq_len(sum(is.na(ids)))])
tt <- rbind(tt, data.table(Name = c(RET_F, RET_S, CONV), Id = ids, Color = c("255,34,139,34", "255,189,183,107", "255,178,34,34"), Legend = "", Description = ""))
wr(tt, D("stsim", "stsim_TransitionType.csv"))
tg <- rd(D("stsim", "stsim_TransitionGroup.csv")); grps <- c("Post-disturbance", RET_F, RET_S, CONV)
tg <- rbind(tg[!Name %in% grps], data.table(Name = grps, Description = "", IsAuto = "")); setorder(tg, Name); wr(tg, D("stsim", "stsim_TransitionGroup.csv"))
ttg <- rd(D("stsim", "stsim_TransitionTypeGroup.csv")); ttg <- ttg[!TransitionTypeId %in% c(RET_F, RET_S, CONV)]
ttg <- rbind(ttg, data.table(TransitionTypeId = c(RET_F, RET_F, RET_S, RET_S, CONV, CONV),
                             TransitionGroupId = c(RET_F, "Post-disturbance", RET_S, "Post-disturbance", CONV, "Post-disturbance"), IsAuto = ""))
wr(ttg, D("stsim", "stsim_TransitionTypeGroup.csv"))

# ---- settings ---------------------------------------------------------------------------------------------------------------
st <- fread(D("transitions", "post-disturbance-settings.csv")); rg <- fread(D("transitions", "post-disturbance-regions.csv"))
eco <- rd(D("strata", "ecodivisions-list.csv"))$Name; stopifnot(setequal(rg$Ecodivision, eco))
par[, set := fifelse(kind == "Forest", "Forest", Name)]; stopifnot(all(par$set %in% st$ParentClass))
par <- merge(par, st[, .(set = ParentClass, Window, ReturnAgeMin, ReturnProbability, ReburnConversion, ShrubShare)], by = "set")
stopifnot(all(c(rg$ShrubClass, rg$GrassClass, "Grassland: Annual") %in% sc$Name))
# conversion destinations by ecodivision, each with its share
dest <- rbindlist(lapply(seq_len(nrow(par)), function(i) { p <- par[i]
  if (p$kind == "Forest") rbind(rg[, .(StratumIdSource = Ecodivision, To = ShrubClass, Share = p$ShrubShare)], rg[, .(StratumIdSource = Ecodivision, To = GrassClass, Share = 1 - p$ShrubShare)])[, From := p$dname]
  else if (p$Name == "Shrubland: Non-sage") rg[, .(StratumIdSource = Ecodivision, To = GrassClass, Share = 1, From = p$dname)]
  else data.table(StratumIdSource = NA_character_, To = "Grassland: Annual", Share = 1, From = p$dname) }))
dest <- dest[Share > 0]

# ---- pathways ---------------------------------------------------------------------------------------------------------------
PW <- c("Iteration", "Timestep", "StratumIdSource", "StateClassIdSource", "StratumIdDest", "StateClassIdDest", "SecondaryStratumId", "TertiaryStratumId",
        "TransitionTypeId", "Probability", "Proportion", "AgeMin", "AgeMax", "AgeRelative", "AgeReset", "TSTMin", "TSTMax", "TSTRelative")
pw <- function(...) { x <- data.table(...); for (k in setdiff(PW, names(x))) set(x, j = k, value = NA_character_); x[, lapply(.SD, as.character), .SDcols = PW] }
fmt <- function(v) sub("\\.?0+$", "", formatC(v, format = "f", digits = 6))
# return (probability 1 at any age in the window; the chance is a multiplier: NLCD maps in history, by age in projections), conversion at the window's end
ret <- par[, pw(StateClassIdSource = dname, StateClassIdDest = Name, TransitionTypeId = fifelse(kind == "Forest", RET_F, RET_S),
                Probability = "1", AgeMax = Window - 1L, AgeReset = "No")]   # any age in the window: historical runs follow NLCD (stage 6); projections set the chance by age (ReturnAgeMin, ReturnProbability; stage 9)
conv <- merge(dest, par[, .(From = dname, Window)], by = "From")[, pw(StratumIdSource = StratumIdSource, StateClassIdSource = From, StateClassIdDest = To,
            TransitionTypeId = CONV, Probability = "1", Proportion = fmt(Share), AgeMin = Window, AgeReset = "No")]
wr(rbind(ret, conv), D("transitions", "pathways", "post-disturbance.csv"))
# fire: high severity moves the parent to its disturbed class; in the disturbed class a high-severity reburn converts ReburnConversion
# of the cells (by the conversion shares) and starts the rest again at age 0; medium and low severity keep the class and its age
fire <- rd(D("transitions", "pathways", "fire.csv")); fire <- fire[!startsWith(StateClassIdSource, PFX)]
hi <- fire$TransitionTypeId == "Fire: High Severity" & fire$StateClassIdSource %in% par$Name
set(fire, which(hi), "StateClassIdDest", par$dname[match(fire$StateClassIdSource[hi], par$Name)])
reb <- merge(dest, par[, .(From = dname, ReburnConversion)], by = "From")
reb <- rbind(reb[, pw(StratumIdSource = StratumIdSource, StateClassIdSource = From, StateClassIdDest = To, TransitionTypeId = "Fire: High Severity",
                      Probability = "1", Proportion = fmt(Share * ReburnConversion), AgeReset = "Yes")],
             par[, pw(StateClassIdSource = dname, StateClassIdDest = dname, TransitionTypeId = "Fire: High Severity", Probability = "1",
                      Proportion = fmt(1 - ReburnConversion), AgeReset = "Yes")])
# a class with conversion rows by ecodivision needs its stay row in each ecodivision too, so the proportions add up there
byeco <- unique(dest[!is.na(StratumIdSource), From])
reb <- rbind(reb[!(StateClassIdSource %in% byeco & StateClassIdDest == StateClassIdSource)],
             CJ(From = byeco, StratumIdSource = eco)[par, on = .(From = dname), nomatch = 0][, pw(StratumIdSource = StratumIdSource, StateClassIdSource = From,
                StateClassIdDest = From, TransitionTypeId = "Fire: High Severity", Probability = "1", Proportion = fmt(1 - ReburnConversion), AgeReset = "Yes")])
ml <- par[, .(t = c("Fire: Medium Severity", "Fire: Low Severity")), by = dname][, pw(StateClassIdSource = dname, StateClassIdDest = dname, TransitionTypeId = t,
                                                                                 Probability = "1", AgeReset = "No")]
wr(rbind(fire, reb, ml), D("transitions", "pathways", "fire.csv"))
# urbanization and agricultural expansion: as the parent class
for (f in c("urbanization.csv", "ag-expansion.csv")) { x <- rd(D("transitions", "pathways", f)); x <- x[!startsWith(StateClassIdSource, PFX)]
  y <- x[StateClassIdSource %in% par$Name][, StateClassIdSource := par$dname[match(StateClassIdSource, par$Name)]]
  wr(rbind(x, y), D("transitions", "pathways", f)) }

# ---- diagram, CO2 and definitions -------------------------------------------------------------------------------------------
loc <- rd(D("transitions", "state-locations.csv")); loc <- loc[!startsWith(StateClassIdSource, PFX)]
par[, col := fifelse(kind == "Forest", "I", "J")]
setorder(par, kind, Name); par[, loc := paste0(col, seq_len(.N)), by = col]
loc <- rbind(loc, par[, .(Iteration = NA, Timestep = NA, StratumIdSource = NA, StateClassIdSource = dname, StratumIdDest = NA, StateClassIdDest = dname,
                          AgeMin = NA, AgeMax = NA, Location = loc)], fill = TRUE)
stopifnot(!anyDuplicated(loc$Location)); wr(loc, D("transitions", "state-locations.csv"))
# CO2: disturbed forest grows as its ecodivision's shrub class (Non-sage's rows; Chaparral has none), disturbed shrub as its parent
co <- rd(D("climate", "co2-classes.csv")); co <- co[!startsWith(StateClassId, PFX)]
src_of <- par[, .(dname, from = fifelse(kind == "Forest", "Shrubland: Non-sage", Name))]
y <- merge(src_of, co, by.x = "from", by.y = "StateClassId")[, .(StateClassId = dname, Type, FlowGroupId)]
wr(rbind(co, y), D("climate", "co2-classes.csv"))
# CO2 betas: rerun tools/make_co2_default_betas.R after this tool (it reads co2-classes.csv)
# definitions: edited as text lines (a read and rewrite through fread/fwrite doubles the escaped quotes of other rows)
de <- data.table(Kind = c("StateClass", "TransitionType", "TransitionType", "TransitionType", rep("TransitionGroup", 4)),
  Name = c("Disturbed: *", RET_F, RET_S, CONV, grps),
  Definition = c("Land of the {*} after a stand-replacing disturbance (high-severity fire), waiting either to return to it or to convert to non-forest or grassland. Age counts the years since the disturbance. No cell starts in it in the default Build (to-do 57).",
                 "A disturbed forest class returns to its forest type, its age (years since the disturbance) carried over.",
                 "A disturbed shrub class returns to its shrub type, its age carried over.",
                 "A disturbed class that has not returned by the end of its window converts: disturbed forest to its ecodivision's shrub or grass class, disturbed sage, sage steppe and chaparral to annual grass, disturbed non-sage to its ecodivision's grass class.",
                 "Every way out of a disturbed class: return or conversion.", "Return of disturbed forest to its forest type.",
                 "Return of disturbed shrubland to its shrub type.", "Conversion of disturbed land that has not returned by the end of its window."),
  Source = "")
fdef <- D("metadata", "definitions.csv"); L <- readLines(fdef, encoding = "UTF-8")
key <- paste0("^", de$Kind, ",", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", de$Name), ",")
L <- L[!Reduce(`|`, lapply(key, function(k) grepl(k, L)))]
q <- function(s) paste0('"', gsub('"', '""', s, fixed = TRUE), '"')
writeLines(c(L, de[, paste(Kind, Name, q(Definition), Source, sep = ",")]), fdef, useBytes = TRUE)
cat(sprintf("%-62s %d rows\n", "defaults/metadata/definitions.csv", length(L) + nrow(de) - 1L))
cat(sprintf("%d disturbed classes (%d forest, %d shrub)\n", nrow(par), sum(par$kind == "Forest"), sum(par$kind == "Shrub")))
