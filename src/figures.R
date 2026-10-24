# =============================================================================
# figures.R - publication figures of a Build result (sourced by stage 12, src/12-build-figures.R; no SyncroSim calls, so it can be
# tested on a result's files and tables directly: dev/figures/test_figures.R)
# =============================================================================
# build_figures(I, outdir) draws each figure whose inputs are present, one map or chart per PNG, and returns one row per PNG
# (Figure, Title, Caption, FileName), numbered in this order:
#   maps:   primary / secondary / tertiary strata, initial state class, stand age, forest type groups,
#           total ecosystem carbon, live biomass carbon, soil carbon
#   charts: area by state class, live tree carbon curves, merchantable volume curves, decay calibration, carbon density by state
#           class, land-use change, disturbance history, climate multipliers, build checks
# One style for all: ggplot2 at 300 dpi (ragg), 8-9 pt type, state classes in their ST-Sim colours. Maps are sized to the study
# area's own shape (legend on the right; tall areas narrower, never over 180 mm wide or ~190 mm high), drawn over a hillshade of the
# DEM (I$dem; plain if it is missing), with the study area outlined and a scale bar beneath. A strata level with one unit is not
# mapped. Large rasters are averaged (continuous) or sampled (categorical) to at most ~1.5 million cells.
# I: strata (list of 3 SpatRasters: primary, secondary, tertiary), strata_names (list of 3 data.tables Id, Name), sc (SpatRaster),
#    sc_list (Name, Id, Color "a,r,g,b"), age (SpatRaster), carbon_curves, volume_curves, decay, stocks (named list of SpatRasters by
#    stock type), stock_summary, trans, climate, validation (data.tables), dem (elevation .tif), label (study area), years (start, end)
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table); library(ggplot2); library(grid); library(scales) })

MM <- 1 / 25.4
FIG_W <- 180 * MM                       # inches: a full-width journal figure
MAP_W <- 128 * MM; MAP_HMAX <- 165 * MM; LEG_W <- 52 * MM
INK <- "#222222"; MUTED <- "#666666"; RULE <- "#d9d9d9"
theme_lucas <- function(base = 8.5) theme_minimal(base_size = base, base_family = "sans") %+replace%
  theme(text = element_text(colour = INK), plot.title = element_text(face = "bold", size = base + 1, hjust = 0, margin = margin(0, 0, 4, 0)),
        plot.subtitle = element_text(colour = MUTED, size = base - 0.5, hjust = 0, margin = margin(0, 0, 6, 0)), plot.title.position = "plot",
        axis.text = element_text(colour = MUTED, size = base - 1), axis.title = element_text(size = base - 0.5),
        panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = RULE, linewidth = 0.25),
        strip.text = element_text(face = "bold", size = base - 0.5, hjust = 0, margin = margin(2, 0, 2, 0)),
        legend.text = element_text(size = base - 1), legend.title = element_text(size = base - 0.5, face = "bold"),
        legend.key.size = unit(3.2, "mm"), plot.margin = margin(4, 6, 4, 4))
theme_map <- function(base = 8.5) theme_lucas(base) %+replace%
  theme(axis.text = element_blank(), axis.title = element_blank(), panel.grid.major = element_blank(), axis.ticks = element_blank(),
        legend.position = "right", legend.justification = c(0, 0.5), legend.key.size = unit(3.6, "mm"))

argb <- function(s) vapply(strsplit(s, ","), function(v) { v <- as.integer(v); if (length(v) == 4) rgb(v[2], v[3], v[4], maxColorValue = 255) else "#999999" }, "")
km2 <- function(r) prod(res(r)) / 1e6
uneven <- function(w) if (grepl("uneven", conditionMessage(w))) invokeRestart("muffleWarning")   # gappy maps (forest only): placed correctly
save_fig <- function(p, file, h, w = FIG_W) { ragg::agg_png(file, width = w, height = h, units = "in", res = 300, background = "white")
  on.exit(dev.off()); withCallingHandlers(print(p), warning = uneven); invisible(file) }

# a raster as a plotting table, reduced to at most ~1.5 million cells; coordinates snapped to the cell centres
map_df <- function(r, categorical) {
  f <- ceiling(sqrt(ncell(r) / 1.5e6)); if (f > 1) r <- aggregate(r, f, fun = if (categorical) "modal" else "mean", na.rm = TRUE)
  d <- as.data.table(as.data.frame(r, xy = TRUE, na.rm = TRUE)); names(d)[3] <- "v"
  e <- ext(r); rx <- res(r)[1]; ry <- res(r)[2]
  d[, x := round(e[1] + (round((x - e[1]) / rx - 0.5) + 0.5) * rx, 2)]; d[, y := round(e[3] + (round((y - e[3]) / ry - 0.5) + 0.5) * ry, 2)]; d }

# the study area outline, its hillshade, and the map frame around it -------------------------------------------------------------
outline_of <- function(r) { o <- as.polygons(!is.na(r) * 1, dissolve = TRUE); o <- o[values(o)[[1]] == 1]; st_as_sf(o) }
# the DEM averaged onto a grid ~1400 cells along the study area's long side, lit from the northwest at 45 degrees, as the shadow
# (0 = the most lit 2%, 1 = the darkest 2%) the maps are darkened by
hillshade <- function(dem_file, r, o) {
  if (is.null(dem_file) || is.na(dem_file) || !file.exists(dem_file)) return(NULL)
  b <- st_bbox(o); rr <- max(30, signif(max(b[3] - b[1], b[4] - b[2]) / 1400, 2))
  g <- rast(ext(b[1], b[3], b[2], b[4]) + 4 * rr, resolution = rr, crs = crs(r))
  dem <- rast(dem_file); dem <- crop(dem, project(as.polygons(ext(g), crs = crs(g)), crs(dem)))
  f <- floor(rr / res(dem)[1]); if (f > 1) dem <- aggregate(dem, f, "mean", na.rm = TRUE)
  dem <- project(dem, g, method = "bilinear")
  hs <- mask(shade(terrain(dem, "slope", unit = "radians"), terrain(dem, "aspect", unit = "radians"), angle = 45, direction = 315), vect(o))
  d <- map_df(hs, FALSE); q <- quantile(d$v, c(0.02, 0.98), na.rm = TRUE)
  d[, shadow := pmin(1, pmax(0, (q[2] - v) / (q[2] - q[1])))]; d[, .(x, y, shadow)] }
scale_bar <- function(o) {
  e <- unname(st_bbox(o))[c(1, 3, 2, 4)]; w <- e[2] - e[1]; len <- 10^floor(log10(w / 4)); len <- len * c(1, 2, 5)[max(which(len * c(1, 2, 5) <= w / 4))]
  x0 <- e[1] + 0.02 * w; y0 <- e[3] - 0.65 * strip(o)           # in the strip base_map leaves under the study area
  list(annotate("segment", x = x0, xend = x0 + len, y = y0, yend = y0, linewidth = 0.8, colour = INK),
       annotate("segment", x = c(x0, x0 + len), xend = c(x0, x0 + len), y = y0, yend = y0 + 0.012 * (e[4] - e[3]), linewidth = 0.5, colour = INK),
       annotate("text", x = x0 + len / 2, y = y0, label = sprintf("%g km", len / 1000), vjust = -0.6, size = 2.6, colour = INK)) }
# added after the data layer: the relief over it, the outline, the frame (study area plus a strip below for the scale bar)
base_map <- function(r, o, H) { b <- st_bbox(o)
  list(if (!is.null(H)) list(geom_raster(data = H, aes(x, y, alpha = shadow), fill = "black", inherit.aes = FALSE), scale_alpha(range = c(0, 0.5), guide = "none")),
       geom_sf(data = o, fill = NA, colour = INK, linewidth = 0.3, inherit.aes = FALSE),
       coord_sf(crs = crs(r), datum = NA, expand = FALSE, xlim = b[c(1, 3)] + c(-1, 1) * res(r)[1],
                ylim = b[c(2, 4)] + c(-strip(o), res(r)[2])), scale_bar(o), theme_map()) }
# the depth of that strip: 7% of the study area's longer side
strip <- function(o) { b <- st_bbox(o); 0.07 * unname(max(b[3] - b[1], b[4] - b[2])) }
# a map's PNG size from the study area's shape: 128 mm of map (narrower when that would make it over 165 mm high) plus the legend
map_size <- function(o, leg = LEG_W) { b <- st_bbox(o); ar <- unname((b[4] - b[2] + strip(o)) / (b[3] - b[1]))
  w <- min(MAP_W, FIG_W - leg); h <- w * ar; if (h > MAP_HMAX) { h <- MAP_HMAX; w <- h / ar }; c(w = w + leg, h = h + 0.45) }

# a categorical map: the units of r named by lst (Id, Name), the largest n kept and the rest "Other"
cat_map <- function(r, lst, o, H, title, n = 12, colours = NULL, strip = NULL) {
  d <- map_df(r, TRUE); a <- d[, .(cells = .N), by = v][order(-cells)]
  a[, Name := lst$Name[match(v, lst$Id)]]; a[is.na(Name), Name := paste("Id", v)]
  if (!is.null(colours)) colours <- colours[a$Name]
  if (!is.null(strip)) { a[, Name := sub(strip, "", Name)]; if (!is.null(colours)) names(colours) <- sub(strip, "", names(colours)) }
  keep <- head(a$v, n); d[, Unit := ifelse(v %in% keep, a$Name[match(v, a$v)], "Other")]
  lev <- c(a$Name[a$v %in% keep], if (any(!d$v %in% keep)) "Other"); d[, Unit := factor(Unit, levels = lev)]
  pal <- if (!is.null(colours)) c(colours[match(lev, names(colours))], Other = "#bdbdbd")[seq_along(lev)] else
    setNames(c(hcl.colors(length(keep), "Set 2"), if ("Other" %in% lev) "#bdbdbd"), lev)
  pal[is.na(pal)] <- "#bdbdbd"; names(pal) <- lev
  ggplot(d, aes(x, y, fill = Unit)) + geom_raster() + scale_fill_manual(values = pal, name = NULL) + base_map(r, o, H) +
    labs(title = title) + guides(fill = guide_legend(ncol = 1)) }
# a continuous map with a colour bar
num_map <- function(r, o, H, title, name, option = "viridis", direction = 1, limits = NULL)
  ggplot(map_df(r, FALSE), aes(x, y, fill = v)) + geom_raster() +
    scale_fill_viridis_c(option = option, direction = direction, name = name, limits = limits, oob = squish) + base_map(r, o, H) + labs(title = title) +
    guides(fill = guide_colourbar(barheight = unit(32, "mm"), barwidth = unit(3.2, "mm")))

build_figures <- function(I, outdir) {
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  rows <- list(); n <- 0L
  emit <- function(p, slug, title, caption, h, w = FIG_W) { n <<- n + 1L; f <- file.path(outdir, sprintf("%02d-%s.png", n, slug))
    save_fig(p, f, h, w); rows[[n]] <<- data.table(Figure = n, Title = title, Caption = caption, FileName = f) }
  o <- outline_of(I$sc); H <- hillshade(I$dem, I$sc, o)
  # the legend's width beside the map: colour bars ~26 mm, named legends by their longest name (the map is otherwise centred in
  # spare width)
  map <- function(p, slug, title, caption) {
    leg <- if (is.factor(p$data$Unit)) min(LEG_W * 1.3, (12 + 1.55 * max(nchar(levels(p$data$Unit)))) * MM) else 26 * MM
    sz <- map_size(o, leg)
    emit(p, slug, title, caption, sz["h"], sz["w"]) }
  area <- km2(I$sc) * sum(!is.na(values(I$sc, mat = FALSE))); lab <- I$label %||% "Study area"
  sub <- sprintf("%s, %s km2 at %g m", lab, format(round(area), big.mark = ","), res(I$sc)[1])
  relief <- if (is.null(H)) "" else " Shaded relief from the elevation data source."
  scn <- I$sc_list; scol <- setNames(argb(scn$Color), scn$Name)

  # ---- maps -----------------------------------------------------------------------------------------------------------------
  if (!is.null(I$strata)) {
    lv <- c("Primary strata: FIA ecodivisions", "Secondary strata", "Tertiary strata"); sl <- c("primary", "secondary", "tertiary")
    for (j in seq_along(I$strata)) { r <- I$strata[[j]]; if (is.null(r) || nrow(unique(r)) < 2) next
      map(cat_map(r, I$strata_names[[j]], o, H, lv[j], n = 10, strip = "^[^:]*: ") + labs(subtitle = sub), paste0("strata-", sl[j]), lv[j],
          sprintf("%s. %s of the model grid; the largest ten units are named, the rest grouped as Other.%s", sub, lv[j], relief)) } }
  d <- map_df(I$sc, TRUE); d[, Class := scn$Name[match(v, scn$Id)]]
  ar <- as.data.table(freq(I$sc))[, .(Class = scn$Name[match(value, scn$Id)], km2 = count * km2(I$sc))][order(-km2)]
  d[, Class := factor(Class, levels = ar$Class)]
  map(cat_map(I$sc, scn, o, H, "Initial state class", n = 14, colours = scol) + labs(subtitle = sprintf("%s, %s", lab, I$years[1])), "state-class",
      "Initial state class", sprintf("State class in the start year (%s), from annual NLCD with forest types, grassland, shrubland and wetland detail; the 14 largest classes named.%s", I$years[1], relief))
  if (!is.null(I$age)) {
    map(num_map(I$age, o, H, "Initial stand age", "Age (yr)", option = "magma", direction = -1), "stand-age", "Initial stand age",
        sprintf("Initial stand age: forest from the NASA CMS forest age map, updated by disturbance; 0 off forest.%s", relief))
    fr <- I$sc; fr[!(fr >= 100 & fr < 1000)] <- NA
    if (global(!is.na(fr), "sum")[[1]] > 0)
      map(cat_map(fr, scn, o, H, "Forest type groups", n = 10, colours = scol, strip = "^Forest: "), "forest-type", "Forest type groups",
          sprintf("Forest type group of the forest cells in the start year (USFS forest type groups).%s", relief)) }
  if (!is.null(I$stocks) && length(I$stocks)) {
    grp <- function(s) ifelse(grepl("^Biomass", s), "Live biomass", ifelse(grepl("Snag|Aboveground Medium|Belowground Fast", s), "Dead wood",
                        ifelse(grepl("Aboveground (Very Fast|Fast|Slow)", s), "Litter", "Soil")))
    sum_of <- function(k) { r <- Reduce(`+`, lapply(I$stocks[k], function(r) { r[is.na(r)] <- 0; r })); mask(r, I$sc) }
    tot <- sum_of(names(I$stocks)); totTg <- global(tot * km2(tot) * 100, "sum", na.rm = TRUE)[[1]] / 1e6
    lim <- c(0, quantile(values(tot, mat = FALSE), 0.995, na.rm = TRUE))
    map(num_map(tot, o, H, "Initial total ecosystem carbon", "Mg C/ha", limits = lim) + labs(subtitle = sprintf("%.1f Tg C, %s", totTg, I$years[1])),
        "carbon-total", "Initial total ecosystem carbon", sprintf("Carbon in the 14 CBM pools at the start (%s): %.1f Tg C in the study area. Colours stop at the 99.5th percentile.%s", I$years[1], totTg, relief))
    live <- names(I$stocks)[grp(names(I$stocks)) == "Live biomass"]; soil <- names(I$stocks)[grp(names(I$stocks)) == "Soil"]
    if (length(live)) map(num_map(sum_of(live), o, H, "Initial live biomass carbon", "Mg C/ha", option = "viridis"), "carbon-live", "Initial live biomass carbon",
                          sprintf("Carbon in the live biomass pools (merchantable, foliage, other wood, coarse and fine roots) at the start (%s).%s", I$years[1], relief))
    if (length(soil)) map(num_map(sum_of(soil), o, H, "Initial soil carbon", "Mg C/ha", option = "cividis"), "carbon-soil", "Initial soil carbon",
                          sprintf("Carbon in the slow soil pools at the start (%s), calibrated to gSSURGO.%s", I$years[1], relief)) }

  # ---- charts ---------------------------------------------------------------------------------------------------------------
  top <- head(ar, 20)
  b <- ggplot(top, aes(km2, reorder(Class, km2), fill = Class)) + geom_col(width = 0.75) + scale_fill_manual(values = scol, guide = "none") +
    scale_x_continuous(labels = label_comma(), expand = expansion(c(0, 0.05))) + labs(x = "Area (km2)", y = NULL, title = "Area by state class",
    subtitle = sprintf("%s, %s; the %d largest classes", lab, I$years[1], nrow(top))) + theme_lucas() + theme(panel.grid.major.y = element_blank())
  emit(b, "state-class-area", "Area by state class", sprintf("Area of each state class in the start year (%s).", I$years[1]), 1.2 + 0.17 * nrow(top))
  if (!is.null(I$carbon_curves) && nrow(I$carbon_curves)) {
    cc <- I$carbon_curves; vc <- I$volume_curves; nf <- uniqueN(cc$StratumId); rows_f <- ceiling(nf / min(nf, 3))
    leg <- guides(colour = guide_legend(ncol = 3)); cls <- scale_colour_manual(values = scol, name = NULL, labels = function(x) sub("^Forest: ", "", x))
    p <- ggplot(cc, aes(Age, TotalLive, colour = StateClassId)) + geom_line(linewidth = 0.5) + facet_wrap(~StratumId, ncol = min(nf, 3)) + cls +
      labs(x = "Stand age (years)", y = "Live tree carbon (Mg C/ha)", title = "Live tree carbon by stand age") + theme_lucas() + theme(legend.position = "bottom") + leg
    emit(p, "growth-carbon", "Live tree carbon curves", "Live tree carbon (CBM biomass pools) by stand age for the forest types and ecodivisions of the study area, fitted to FIA.", 1.6 + 2.4 * rows_f)
    if (!is.null(vc) && nrow(vc)) {
      p <- ggplot(vc, aes(Age, MerchantableVolume, colour = StateClassId)) + geom_line(linewidth = 0.5) + facet_wrap(~StratumId, ncol = min(nf, 3)) + cls +
        labs(x = "Stand age (years)", y = expression("Merchantable volume ("*m^3*"/ha)"), title = "Merchantable volume by stand age") + theme_lucas() + theme(legend.position = "bottom") + leg
      emit(p, "growth-volume", "Merchantable volume curves", "Merchantable volume by stand age for the forest types and ecodivisions of the study area, fitted to FIA; the curves CBM converts to biomass.", 1.6 + 2.4 * rows_f) } }
  if (!is.null(I$decay) && nrow(I$decay)) {
    dc <- melt(I$decay[, .(StratumId, StateClassId, Snag = SnagDecayMultiplier, `Down wood` = DownWoodDecayMultiplier, `Forest floor` = ForestFloorDecayMultiplier, Soil = SoilDecayMultiplier)],
               id.vars = c("StratumId", "StateClassId"), variable.name = "Pool", value.name = "m")
    dc[, Type := sub("^Forest: ", "", StateClassId)]
    p <- ggplot(dc, aes(m, reorder(Type, m), colour = Pool)) + geom_vline(xintercept = 1, colour = MUTED, linewidth = 0.3, linetype = 2) +
      geom_point(size = 1.4, alpha = 0.85) + facet_wrap(~StratumId) + scale_x_log10() +
      scale_colour_manual(values = c(Snag = "#8c510a", `Down wood` = "#d8b365", `Forest floor` = "#5ab4ac", Soil = "#01665e"), name = NULL) +
      labs(x = "Decay rate multiplier (1 = CBM-CFS3 default; log scale)", y = NULL, title = "Dead organic matter decay calibration",
           subtitle = "Multipliers that bring spin-up dead wood, litter and soil carbon to FIA and gSSURGO") + theme_lucas() + theme(legend.position = "bottom")
    emit(p, "decay-calibration", "Dead organic matter calibration", "Decay rate multipliers of the snag, down wood, forest floor and soil pools by forest type and ecodivision, calibrated in stage 3; 1 = the CBM-CFS3 default.",
         max(3.2, 0.13 * uniqueN(dc$Type) * ceiling(uniqueN(dc$StratumId) / 2) + 1.6)) }
  if (!is.null(I$stocks) && length(I$stocks)) {
    zs <- rbindlist(lapply(names(I$stocks), function(s) { z <- zonal(I$stocks[[s]], I$sc, fun = "mean", na.rm = TRUE); setnames(z, c("Id", "mean"))
      data.table(Id = z$Id, Pool = grp(s), mean = z$mean) }))[, .(mean = sum(mean, na.rm = TRUE)), by = .(Id, Pool)]
    fq <- as.data.table(freq(I$sc))[, .(Id = value, km2 = count * km2(I$sc))]
    zs <- merge(zs, fq, by = "Id"); zs[, Class := scn$Name[match(Id, scn$Id)]]
    tc <- zs[, .(km2 = km2[1]), by = Class][order(-km2)][1:min(.N, 15), Class]
    zs <- zs[Class %in% tc]; zs[, Pool := factor(Pool, levels = c("Live biomass", "Dead wood", "Litter", "Soil"))]
    p <- ggplot(zs, aes(mean, reorder(Class, mean), fill = Pool)) + geom_col(width = 0.75) +
      scale_fill_manual(values = c(`Live biomass` = "#1b7837", `Dead wood` = "#a6611a", Litter = "#dfc27d", Soil = "#543005"), name = NULL) +
      scale_x_continuous(expand = expansion(c(0, 0.05))) + labs(x = "Mean carbon density (Mg C/ha)", y = NULL, title = "Carbon density by state class",
      subtitle = sprintf("The %d largest classes, %s", length(tc), I$years[1])) + theme_lucas() + theme(legend.position = "bottom", panel.grid.major.y = element_blank())
    emit(p, "carbon-by-class", "Carbon density by state class", sprintf("Mean density of live biomass, dead wood, litter and soil carbon at the start (%s) by state class.", I$years[1]), 1.6 + 0.17 * length(tc)) }
  if (!is.null(I$trans) && nrow(I$trans)) {
    tr <- copy(I$trans); tr[, Group := trimws(sub(" \\[Type\\]$", "", TransitionGroup))]; tr[, Family := sub(":.*$", "", Group)]
    tr[, Member := ifelse(grepl(":", Group), trimws(sub("^[^:]*:", "", Group)), Group)]
    lu <- tr[Family %in% c("Urbanization", "Intensification", "Ag Expansion", "Ag Contraction"), .(Area = sum(Area)), by = .(Timestep, Family, Member)]
    if (nrow(lu)) {
      lu[, Family := factor(Family, levels = c("Urbanization", "Intensification", "Ag Expansion", "Ag Contraction"))]
      p <- ggplot(lu, aes(Timestep, Area, fill = Member)) + geom_col(width = 0.85) + facet_wrap(~Family, scales = "free_y", ncol = 2) +
        scale_fill_manual(values = setNames(hcl.colors(uniqueN(lu$Member), "Dark 3"), sort(unique(lu$Member))), name = NULL) +
        scale_x_continuous(breaks = pretty_breaks()) + labs(x = NULL, y = "Area per year (km2)", title = "Historical land-use change",
        subtitle = sprintf("%s, %s-%s, from annual NLCD", lab, I$years[1] + 1, I$years[2])) + theme_lucas() + theme(legend.position = "bottom")
      emit(p, "land-use-change", "Historical land-use change", "Annual area of each land-use transition group from annual NLCD (the historical transitions of stage 6), by member type.", 1.8 + 1.8 * ceiling(uniqueN(lu$Family) / 2)) }
    di <- tr[Family %in% c("Fire", "Forest Harvest", "Insect"), .(Area = sum(Area)), by = .(Timestep, Family, Member)]
    if (nrow(di)) {
      di[, Member := sub("^Forest ", "", Member)]
      p <- ggplot(di, aes(Timestep, Area, fill = Member)) + geom_col(width = 0.85) + facet_wrap(~Family, scales = "free_y", ncol = 1) +
        scale_fill_manual(values = c(`High Severity` = "#b2182b", `Medium Severity` = "#ef8a62", `Low Severity` = "#fddbc7",
                                     Clearcut = "#4d4d4d", Selection = "#bababa"), name = NULL, na.value = "#7f7f7f") +
        scale_x_continuous(limits = c(I$years[1] + 0.5, I$years[2] + 0.5), breaks = pretty_breaks()) +
        labs(x = NULL, y = "Area per year (km2)", title = "Disturbance history", subtitle = "Fire from MTBS burn severity; harvest from LCMS tree removal") +
        theme_lucas() + theme(legend.position = "bottom")
      emit(p, "disturbance", "Disturbance history", "Annual area burned by severity (MTBS) and harvested by clearcut and selection (LCMS tree removal), as written by stage 6.", 1.6 + 1.5 * uniqueN(di$Family)) } }
  if (!is.null(I$climate) && nrow(I$climate)) {
    cl <- copy(I$climate); cl[, Effect := sprintf("%s (%s)", FlowGroup, Model)]
    p <- ggplot(cl, aes(Timestep, Mean, colour = Effect, fill = Effect)) + geom_hline(yintercept = 1, colour = MUTED, linewidth = 0.3, linetype = 2) +
      geom_ribbon(aes(ymin = Min, ymax = Max), alpha = 0.15, colour = NA) + geom_line(linewidth = 0.55) + facet_wrap(~Climate, scales = "free_x") +
      scale_colour_brewer(palette = "Dark2", name = NULL) + scale_fill_brewer(palette = "Dark2", name = NULL) +
      labs(x = NULL, y = "Multiplier (1 = 1991-2020 normal)", title = "Climate multipliers", subtitle = "Study-area mean, with the range across cells") +
      theme_lucas() + theme(legend.position = "bottom") + guides(colour = guide_legend(ncol = 2))
    emit(p, "climate", "Climate multipliers", "Year-to-year growth and decomposition multipliers from PRISM against each cell's 1991-2020 normal (stage 7): the study-area mean and the range across cells.", 3.6) }
  if (!is.null(I$validation) && nrow(I$validation)) {
    v <- I$validation[, .(Checks = .N, Failed = sum(Status != "Pass")), by = Stage][order(Stage)]
    v[, Passed := Checks - Failed]; vm <- melt(v[, .(Stage, Passed, Failed)], id.vars = "Stage", variable.name = "Status", value.name = "n")
    p <- ggplot(vm, aes(n, factor(Stage, levels = rev(v$Stage)), fill = Status)) + geom_col(width = 0.7) +
      scale_fill_manual(values = c(Passed = "#1b7837", Failed = "#b2182b"), name = NULL, drop = FALSE) + scale_x_continuous(expand = expansion(c(0, 0.05))) +
      labs(x = "Validation checks", y = NULL, title = "Build checks", subtitle = sprintf("%d checks, %d failed (Build Results > Validation lists each)", sum(v$Checks), sum(v$Failed))) +
      theme_lucas() + theme(legend.position = "bottom", panel.grid.major.y = element_blank())
    emit(p, "checks", "Build checks", "The validation checks each stage ran on its own outputs, passed and failed.", 1.6 + 0.2 * nrow(v)) }

  rbindlist(rows) }
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a
