# =============================================================================
# disturbed-carbon.R - carbon flows of the post-disturbance classes (stage 3; to-do 57, user decisions 2026-11-11)
# =============================================================================
# A disturbed class ("Disturbed: <type>", Id 2000 + its parent's; tools/make_post_disturbance.R) has no rows of its own in the
# package's tables: stage 3 derives them each Build from the rows it already has, so they follow the parents' when those change.
#   - disturbed shrub class: every non-forest row of its parent (pathways, growth split, turnover and decay, net growth, the parent's
#     own fire rows), the scenario's Grassland, Shrubland and Wetland Carbon edits included;
#   - disturbed forest class: live carbon grows as its ecodivision's shrub class (post-disturbance-regions.csv): that class's growth
#     pathways, growth split, live turnover and net growth; its dead wood, decay and soil are its forest type's (the forest pathways'
#     dead organic matter rows and the rates stage 3 built for the type in each ecodivision, burial where the type has it). Its fire
#     rows are the all-class (forest) rows, so a reburn burns the forest's dead wood as it would in the forest class.
# Only the study area's ecodivisions are written, and a disturbed forest class only where its forest type has rates.
# =============================================================================

DISTURBED_ID0 <- 2000L
LIVE_GROUPS <- "^(Net Growth Non Forest: |Biomass Turnover: )"

# the disturbed classes of a state class list (Name, Id), with their parent and kind
disturbed_classes <- function(scl) {
  id <- suppressWarnings(as.integer(scl$Id)); d <- scl[!is.na(id) & id >= DISTURBED_ID0 & id < DISTURBED_ID0 + 1000L]
  if (!nrow(d)) return(data.table::data.table(D = character(), parent = character(), kind = character()))
  p <- scl[match(as.integer(d$Id) - DISTURBED_ID0, id)]
  x <- data.table::data.table(D = d$Name, parent = p$Name, kind = ifelse(as.integer(p$Id) >= 100L & as.integer(p$Id) <= 999L, "Forest", "Shrub"))
  x[!is.na(parent)] }

# rows of a table copied for the disturbed classes: x keyed by class column cc and stratum column sc; src: D, from, Eco (NA = every
# ecodivision); keep: which of the source class's rows a forest D takes
copy_for <- function(x, cc, sc, src, keep = NULL) {
  if (!nrow(src) || !nrow(x)) return(x[0])
  data.table::rbindlist(lapply(seq_len(nrow(src)), function(i) { s <- src[i]
    y <- x[x[[cc]] == s$from & (is.na(s$Eco) | (!is.na(x[[sc]]) & x[[sc]] == s$Eco))]
    if (!is.null(keep) && s$kind == "Forest") y <- y[keep(y)]
    if (nrow(y)) data.table::set(y, j = cc, value = s$D)
    y }), fill = TRUE) }

# dc: disturbed_classes(); rg: post-disturbance-regions.csv; study: the study area's ecodivisions (NULL = all); nfp, gs_m, nf_g: the
# non-forest pathways, multipliers and net growth as stage 3 has them; fm_d: the forest turnover and decay multipliers stage 3 built;
# fpw: FOREST_PATHWAYS; burial: forest classes with burial; ev: the event pathways (all-class and class rows)
disturbed_carbon <- function(dc, rg, study, nfp, gs_m, nf_g, fm_d, fpw, burial = character(), ev = NULL, burial_flow = "Stabilization: BG Slow -> Deep Soil") {
  eco <- if (is.null(study)) unique(rg$Ecodivision) else intersect(rg$Ecodivision, study)
  fo <- dc[kind == "Forest" & parent %in% fm_d$StateClassId]; sh <- dc[kind == "Shrub"]
  src <- rbind(sh[, .(D, from = parent, Eco = NA_character_, kind)],
               data.table::CJ(D = fo$D, Eco = eco)[rg, on = .(Eco = Ecodivision), nomatch = 0][, .(D, from = ShrubClass, Eco, kind = "Forest")])
  in_study <- function(x, sc) if (is.null(study) || !nrow(x)) x else x[is.na(x[[sc]]) | x[[sc]] %in% study]
  fp <- copy_for(nfp, "FromStateClassId", "FromStratumId", src, function(y) !startsWith(y$FromStockTypeId, "DOM: "))
  fp_dom <- data.table::rbindlist(lapply(seq_len(nrow(fo)), function(i) {
    p <- fpw[startsWith(From, "DOM: ") & (FlowType != burial_flow | fo$parent[i] %in% burial)]
    p[, .(FromStateClassId = fo$D[i], FromStockTypeId = From, ToStockTypeId = To, StateAttributeTypeId = Attribute, FlowTypeId = FlowType, Multiplier = "1")] }))
  fm <- copy_for(gs_m, "StateClassId", "StratumId", src, function(y) grepl(LIVE_GROUPS, y$FlowGroupId))
  fm_dom <- fm_d[StateClassId %in% fo$parent & !grepl("^Biomass Turnover: ", FlowGroupId)]
  fm_dom[, StateClassId := fo$D[match(StateClassId, fo$parent)]]
  sav <- copy_for(nf_g, "StateClassId", "StratumId", src)
  evd <- if (is.null(ev) || !nrow(sh)) NULL else copy_for(ev[!is.na(FromStateClassId)], "FromStateClassId", "FromStratumId", sh[, .(D, from = parent, Eco = NA_character_, kind)])
  list(fp = rbind(in_study(fp, "FromStratumId"), fp_dom, fill = TRUE), fm = rbind(in_study(fm, "StratumId"), fm_dom, fill = TRUE),
       sav = in_study(sav, "StratumId"), ev = evd, forest = fo$D, shrub = sh$D) }
