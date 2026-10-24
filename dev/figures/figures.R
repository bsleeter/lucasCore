# =============================================================================
# figures.R - publication figures of a Build result (sourced by stage 12; no SyncroSim calls, so it can be tested on a result's
# files and tables directly: dev/figures/test_figures.R)
# =============================================================================
# build_figures(I, outdir) draws each figure whose inputs are present and returns one row per PNG (Figure, Title, Caption, FileName):
#   01 study area and strata        02 initial state classes        03 stand age and forest types
#   04 growth curves                05 dead organic matter calibration
#   06 initial carbon stocks        07 historical land-use change   08 disturbance history
#   09 climate multipliers          10 build checks
# One style for all: ggplot2, 180 mm wide at 300 dpi (ragg), 8-9 pt type, state classes in their ST-Sim colours, maps with the
# study area outlined and a scale bar. Large rasters are averaged (continuous) or sampled (categorical) to at most ~1.5 million cells.
# I: strata (list of 3 SpatRasters: primary, secondary, tertiary), strata_names (list of 3 data.tables Id, Name), sc (SpatRaster),
#    sc_list (Name, Id, Color "a,r,g,b"), age (SpatRaster), carbon_curves, volume_curves, decay, stocks (named list of SpatRasters by
#    stock type), stock_summary, trans, climate, validation (data.tables), label (study area), years (start, end)
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table); library(ggplot2); library(gridExtra); library(grid); library(scales) })

FIG_W <- 180 / 25.4                     # inches: a full-width journal figure
INK <- "#222222"; MUTED <- "#666666"; RULE <- "#d9d9d9"
theme_lucas <- function(base = 8.5) theme_minimal(base_size = base, base_family = "sans") %+replace%
  theme(text = element_text(colour = INK), plot.title = element_text(face = "bold", size = base + 1, hjust = 0, margin = margin(0, 0, 4, 0)),
        plot.subtitle = element_text(colour = MUTED, size = base - 0.5, hjust = 0, margin = margin(0, 0, 6, 0)),
        axis.text = element_text(colour = MUTED, size = base - 1), axis.title = element_text(size = base - 0.5),
        panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = RULE, linewidth = 0.25),
        strip.text = element_text(face = "bold", size = base - 0.5, hjust = 0, margin = margin(2, 0, 2, 0)),
        legend.text = element_text(size = base - 1), legend.title = element_text(size = base - 0.5, face = "bold"),
        legend.key.size = unit(3.2, "mm"), plot.margin = margin(4, 6, 4, 4))
theme_map <- function(base = 8.5) theme_lucas(base) %+replace%
  theme(axis.text = element_blank(), axis.title = element_blank(), panel.grid.major = element_blank(), axis.ticks = element_blank())

argb <- function(s) vapply(strsplit(s, ","), function(v) { v <- as.integer(v); if (length(v) == 4) rgb(v[2], v[3], v[4], maxColorValue = 255) else "#999999" }, "")
km2 <- function(r) prod(res(r)) / 1e6
save_fig <- function(p, file, h) { ragg::agg_png(file, width = FIG_W, height = h, units = "in", res = 300, background = "white")
  on.exit(dev.off())
  # a map whose cells skip whole columns (forest only) has uneven gaps; ggplot warns but places the cells correctly
  withCallingHandlers(if (inherits(p, "gtable") || inherits(p, "grob")) { grid.newpage(); grid.draw(p) } else print(p),
    warning = function(w) if (grepl("uneven", conditionMessage(w))) invokeRestart("muffleWarning")); invisible(file) }

# a raster as a plotting table, reduced to at most ~1.5 million cells; coordinates snapped to the cell centres (floating-point
# drift otherwise makes ggplot see an uneven grid)
map_df <- function(r, categorical) {
  f <- ceiling(sqrt(ncell(r) / 1.5e6)); if (f > 1) r <- aggregate(r, f, fun = if (categorical) "modal" else "mean", na.rm = TRUE)
  d <- as.data.table(as.data.frame(r, xy = TRUE, na.rm = TRUE)); names(d)[3] <- "v"
  e <- ext(r); rx <- res(r)[1]; ry <- res(r)[2]
  d[, x := round(e[1] + (round((x - e[1]) / rx - 0.5) + 0.5) * rx, 2)]; d[, y := round(e[3] + (round((y - e[3]) / ry - 0.5) + 0.5) * ry, 2)]; d }

# the study area's height / width, and whether it is wide (maps then stack, legends on the right)
aspect <- function(r) { e <- ext(trim(r)); (e[4] - e[3]) / (e[2] - e[1]) }
# a panel with its title pinned to the top left (ggplot centres titles over the panel, which coord_sf shrinks to the map's shape)
quiet_grob <- function(p) withCallingHandlers(ggplotGrob(p), warning = function(w) if (grepl("uneven", conditionMessage(w))) invokeRestart("muffleWarning"))
panel <- function(p, title) arrangeGrob(quiet_grob(p + labs(title = NULL)),
  top = textGrob(title, x = unit(5, "pt"), hjust = 0, gp = gpar(fontsize = 9.5, fontface = "bold", col = INK)))
# map panels laid out by the study area's shape: wide areas one per row (legend right), others side by side (legend below)
map_layout <- function(plots, titles, ar, legend = TRUE) {
  wide <- ar < 0.8; n <- length(plots)
  plots <- lapply(plots, function(p) p + theme(legend.position = if (!legend) "none" else if (wide) "right" else "bottom"))
  g <- lapply(seq_len(n), function(k) panel(plots[[k]], titles[k]))
  if (wide) list(grob = arrangeGrob(grobs = g, ncol = 1), h = n * (FIG_W * 0.62 * ar + 0.45))
  else list(grob = arrangeGrob(grobs = g, nrow = 1), h = (FIG_W / n) * ar + 0.5 + if (legend) 1.1 else 0) }
# a map and a bar chart: side by side, or the bar chart under the map when the study area is wide
map_bar <- function(m, b, titles, ar, bar_h = 3) {
  gm <- panel(m, titles[1]); gb <- panel(b, titles[2])
  if (ar < 0.8) list(grob = arrangeGrob(gm, gb, ncol = 1, heights = c(FIG_W * 0.8 * ar + 0.4, bar_h)), h = FIG_W * 0.8 * ar + 0.4 + bar_h)
  else list(grob = arrangeGrob(gm, gb, nrow = 1, widths = c(1.15, 1)), h = max(bar_h, FIG_W * 0.53 * ar + 0.5)) }
# the study area outline and a scale bar for a map of r
outline_of <- function(r) { o <- as.polygons(!is.na(r) * 1, dissolve = TRUE); o <- o[values(o)[[1]] == 1]; st_as_sf(o) }
scale_bar <- function(o) {
  e <- unname(st_bbox(o))[c(1, 3, 2, 4)]; w <- e[2] - e[1]; len <- 10^floor(log10(w / 4)); len <- len * c(1, 2, 5)[max(which(len * c(1, 2, 5) <= w / 4))]
  x0 <- e[1] + 0.02 * w; y0 <- e[3] - 0.07 * (e[4] - e[3])     # in the strip base_map leaves under the study area
  list(annotate("segment", x = x0, xend = x0 + len, y = y0, yend = y0, linewidth = 0.8, colour = INK),
       annotate("text", x = x0 + len / 2, y = y0, label = sprintf("%g km", len / 1000), vjust = -0.6, size = 2.6, colour = INK)) }
base_map <- function(r, o) list(geom_sf(data = o, fill = NA, colour = INK, linewidth = 0.3, inherit.aes = FALSE),
                                coord_sf(crs = crs(r), datum = NA, expand = FALSE, xlim = st_bbox(o)[c(1, 3)] + c(-1, 1) * res(r)[1],
                                         ylim = st_bbox(o)[c(2, 4)] + c(-0.1 * diff(st_bbox(o)[c(2, 4)]), res(r)[2])), scale_bar(o), theme_map())

# a categorical map: the units of r named by lst (Id, Name), the largest n kept and the rest "Other"
cat_map <- function(r, lst, o, title, n = 12, colours = NULL, strip = NULL) {
  d <- map_df(r, TRUE); a <- d[, .(cells = .N), by = v][order(-cells)]
  a[, Name := lst$Name[match(v, lst$Id)]]; a[is.na(Name), Name := paste("Id", v)]
  if (!is.null(colours)) colours <- colours[a$Name]
  if (!is.null(strip)) { a[, Name := sub(strip, "", Name)]; if (!is.null(colours)) names(colours) <- sub(strip, "", names(colours)) }
  keep <- head(a$v, n); d[, Unit := ifelse(v %in% keep, a$Name[match(v, a$v)], "Other")]
  lev <- c(a$Name[a$v %in% keep], if (any(!d$v %in% keep)) "Other"); d[, Unit := factor(Unit, levels = lev)]
  pal <- if (!is.null(colours)) c(colours[match(lev, names(colours))], Other = "#bdbdbd")[seq_along(lev)] else
    setNames(c(hcl.colors(length(keep), "Dark 3"), if ("Other" %in% lev) "#bdbdbd"), lev)
  pal[is.na(pal)] <- "#bdbdbd"; names(pal) <- lev
  ggplot(d, aes(x, y, fill = Unit)) + geom_raster() + scale_fill_manual(values = pal, name = NULL) + base_map(r, o) +
    labs(title = title) + guides(fill = guide_legend(ncol = 1)) }

build_figures <- function(I, outdir) {
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  rows <- list(); add <- function(n, title, caption, file) rows[[length(rows) + 1]] <<- data.table(Figure = n, Title = title, Caption = caption, FileName = file)
  fig <- function(n, slug) file.path(outdir, sprintf("%02d-%s.png", n, slug))
  o <- outline_of(I$sc); area <- km2(I$sc) * sum(!is.na(values(I$sc, mat = FALSE))); lab <- I$label %||% "Study area"
  sub <- sprintf("%s, %s km2 at %g m", lab, format(round(area), big.mark = ","), res(I$sc)[1])
  scn <- I$sc_list; scol <- setNames(argb(scn$Color), scn$Name); AR <- aspect(I$sc)

  # ---- 01 study area and strata ---------------------------------------------------------------------------------------------
  if (!is.null(I$strata)) {
    ttl <- c("Primary strata: FIA ecodivisions", "Secondary strata", "Tertiary strata")
    k <- which(!vapply(I$strata, is.null, TRUE))
    ps <- lapply(k, function(j) cat_map(I$strata[[j]], I$strata_names[[j]], o, NULL, n = 10, strip = "^[^:]*: "))
    L <- map_layout(ps, ttl[k], AR)
    g <- arrangeGrob(L$grob, top = textGrob(sub, x = unit(5, "pt"), hjust = 0, gp = gpar(fontsize = 8, col = MUTED)))
    f <- fig(1, "strata"); save_fig(g, f, L$h + 0.3)
    add(1, "Study area and strata", sprintf("%s. The model grid's three strata levels; the largest units of each are named, the rest grouped as Other.", sub), f) }

  # ---- 02 initial state classes ---------------------------------------------------------------------------------------------
  d <- map_df(I$sc, TRUE); d[, Class := scn$Name[match(v, scn$Id)]]
  ar <- as.data.table(freq(I$sc))[, .(Class = scn$Name[match(value, scn$Id)], km2 = count * km2(I$sc))][order(-km2)]
  d[, Class := factor(Class, levels = ar$Class)]
  m <- ggplot(d, aes(x, y, fill = Class)) + geom_raster() + scale_fill_manual(values = scol, guide = "none") + base_map(I$sc, o)
  b <- ggplot(head(ar, 20), aes(km2, reorder(Class, km2), fill = Class)) + geom_col(width = 0.75) + scale_fill_manual(values = scol, guide = "none") +
    scale_x_continuous(labels = label_comma(), expand = expansion(c(0, 0.05))) + labs(x = "Area (km2)", y = NULL) + theme_lucas() +
    theme(panel.grid.major.y = element_blank())
  L <- map_bar(m, b, c("Initial state class", "Area by state class (20 largest)"), AR, bar_h = 3.4)
  f <- fig(2, "state-classes"); save_fig(L$grob, f, L$h)
  add(2, "Initial state classes", sprintf("State class in the start year (%s), from annual NLCD with forest types, grassland, shrubland and wetland detail; the 20 largest classes by area.", I$years[1]), f)

  # ---- 03 stand age and forest types ----------------------------------------------------------------------------------------
  if (!is.null(I$age)) {
    a <- map_df(I$age, FALSE); fr <- I$sc; fr[!(fr >= 100 & fr < 1000)] <- NA
    m1 <- ggplot(a, aes(x, y, fill = v)) + geom_raster() + scale_fill_viridis_c(option = "magma", direction = -1, name = "Age (yr)") + base_map(I$age, o)
    m2 <- if (global(!is.na(fr), "sum")[[1]] > 0) cat_map(fr, scn, o, NULL, n = 10, colours = scol, strip = "^Forest: ") else NULL
    L <- map_layout(Filter(Negate(is.null), list(m1, m2)), c("Initial stand age", "Forest type groups")[c(TRUE, !is.null(m2))], AR)
    f <- fig(3, "age-forest-type"); save_fig(L$grob, f, L$h)
    add(3, "Stand age and forest types", "Initial stand age (forest from the NASA CMS forest age map, updated by disturbance; 0 off forest) and the forest type group of forest cells.", f) }

  # ---- 04 growth curves -----------------------------------------------------------------------------------------------------
  if (!is.null(I$carbon_curves) && nrow(I$carbon_curves)) {
    cc <- I$carbon_curves; vc <- I$volume_curves
    p1 <- ggplot(cc, aes(Age, TotalLive, colour = StateClassId)) + geom_line(linewidth = 0.45) + facet_wrap(~StratumId) +
      scale_colour_manual(values = scol, name = NULL) + labs(x = "Stand age (years)", y = "Live tree carbon (Mg C/ha)", title = "Live tree carbon") + theme_lucas()
    p2 <- ggplot(vc, aes(Age, MerchantableVolume, colour = StateClassId)) + geom_line(linewidth = 0.45) + facet_wrap(~StratumId) +
      scale_colour_manual(values = scol, guide = "none") + labs(x = "Stand age (years)", y = expression("Merchantable volume ("*m^3*"/ha)"), title = "Merchantable volume") + theme_lucas()
    f <- fig(4, "growth-curves"); save_fig(arrangeGrob(ggplotGrob(p1 + theme(legend.position = "bottom") + guides(colour = guide_legend(ncol = 3))), ggplotGrob(p2), ncol = 1, heights = c(1.35, 1)), f, 7.2)
    add(4, "Growth curves", "Live tree carbon (CBM pools) and merchantable volume by stand age for the forest types and ecodivisions of the study area, fitted to FIA.", f) }

  # ---- 05 dead organic matter calibration ------------------------------------------------------------------------------------
  if (!is.null(I$decay) && nrow(I$decay)) {
    dc <- melt(I$decay[, .(StratumId, StateClassId, Snag = SnagDecayMultiplier, `Down wood` = DownWoodDecayMultiplier, `Forest floor` = ForestFloorDecayMultiplier, Soil = SoilDecayMultiplier)],
               id.vars = c("StratumId", "StateClassId"), variable.name = "Pool", value.name = "m")
    dc[, Type := sub("^Forest: ", "", StateClassId)]
    p <- ggplot(dc, aes(m, reorder(Type, m), colour = Pool)) + geom_vline(xintercept = 1, colour = MUTED, linewidth = 0.3, linetype = 2) +
      geom_point(size = 1.4, alpha = 0.85) + facet_wrap(~StratumId) + scale_x_log10() +
      scale_colour_manual(values = c(Snag = "#8c510a", `Down wood` = "#d8b365", `Forest floor` = "#5ab4ac", Soil = "#01665e"), name = NULL) +
      labs(x = "Decay rate multiplier (1 = CBM-CFS3 default; log scale)", y = NULL, title = "Dead organic matter decay calibration",
           subtitle = "Multipliers that bring spin-up dead wood, litter and soil carbon to FIA and gSSURGO") + theme_lucas() + theme(legend.position = "bottom")
    f <- fig(5, "decay-calibration"); save_fig(p, f, max(3.6, 0.13 * uniqueN(dc$Type) * ceiling(uniqueN(dc$StratumId) / 2) + 1.6))
    add(5, "Dead organic matter calibration", "Decay rate multipliers of the snag, down wood, forest floor and soil pools by forest type and ecodivision, calibrated in stage 3; 1 = the CBM-CFS3 default.", f) }

  # ---- 06 initial carbon stocks ---------------------------------------------------------------------------------------------
  if (!is.null(I$stocks) && length(I$stocks)) {
    tot <- Reduce(`+`, lapply(I$stocks, function(r) { r[is.na(r)] <- 0; r })); tot <- mask(tot, I$sc)
    m <- ggplot(map_df(tot, FALSE), aes(x, y, fill = v)) + geom_raster() + scale_fill_viridis_c(option = "viridis", name = "Mg C/ha") + base_map(tot, o)
    grp <- function(s) ifelse(grepl("^Biomass", s), "Live biomass", ifelse(grepl("Snag|Aboveground Medium|Belowground Fast", s), "Dead wood",
                        ifelse(grepl("Aboveground (Very Fast|Fast|Slow)", s), "Litter", "Soil")))
    zs <- rbindlist(lapply(names(I$stocks), function(s) { z <- zonal(I$stocks[[s]], I$sc, fun = "mean", na.rm = TRUE); setnames(z, c("Id", "mean"))
      data.table(Id = z$Id, Pool = grp(s), mean = z$mean) }))[, .(mean = sum(mean, na.rm = TRUE)), by = .(Id, Pool)]
    fq <- as.data.table(freq(I$sc))[, .(Id = value, km2 = count * km2(I$sc))]
    zs <- merge(zs, fq, by = "Id"); zs[, Class := scn$Name[match(Id, scn$Id)]]
    top <- zs[, .(km2 = km2[1]), by = Class][order(-km2)][1:min(.N, 15), Class]
    zs <- zs[Class %in% top]; zs[, Pool := factor(Pool, levels = c("Live biomass", "Dead wood", "Litter", "Soil"))]
    b <- ggplot(zs, aes(mean, reorder(Class, mean), fill = Pool)) + geom_col(width = 0.75) +
      scale_fill_manual(values = c(`Live biomass` = "#1b7837", `Dead wood` = "#a6611a", Litter = "#dfc27d", Soil = "#543005"), name = NULL) +
      scale_x_continuous(expand = expansion(c(0, 0.05))) + labs(x = "Mean carbon density (Mg C/ha)", y = NULL) +
      theme_lucas() + theme(legend.position = "bottom", panel.grid.major.y = element_blank())
    totTg <- sum(global(tot * km2(tot) * 100, "sum", na.rm = TRUE)[[1]]) / 1e6
    L <- map_bar(m, b, c("Initial total ecosystem carbon", "Carbon density by state class (15 largest)"), AR, bar_h = 3.4)
    f <- fig(6, "initial-stocks"); save_fig(L$grob, f, L$h)
    add(6, "Initial carbon stocks", sprintf("Carbon in the 14 CBM pools at the start (%s): total ecosystem carbon, %.1f Tg C in the study area, and the mean density of live biomass, dead wood, litter and soil by state class.", I$years[1], totTg), f) }

  # ---- 07 historical land-use change; 08 disturbance -------------------------------------------------------------------------
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
      f <- fig(7, "land-use-change"); save_fig(p, f, 5.2)
      add(7, "Historical land-use change", "Annual area of each land-use transition group from annual NLCD (the historical transitions of stage 6), by member type.", f) }
    di <- tr[Family %in% c("Fire", "Forest Harvest", "Insect"), .(Area = sum(Area)), by = .(Timestep, Family, Member)]
    if (nrow(di)) {
      yrs <- data.table(Timestep = (I$years[1] + 1):I$years[2])
      di[, Member := sub("^Forest ", "", Member)]
      p <- ggplot(di, aes(Timestep, Area, fill = Member)) + geom_col(width = 0.85) + facet_wrap(~Family, scales = "free_y", ncol = 1) +
        scale_fill_manual(values = c(`High Severity` = "#b2182b", `Medium Severity` = "#ef8a62", `Low Severity` = "#fddbc7",
                                     Clearcut = "#4d4d4d", Selection = "#bababa"), name = NULL, na.value = "#7f7f7f") +
        scale_x_continuous(limits = range(yrs$Timestep) + c(-0.5, 0.5), breaks = pretty_breaks()) +
        labs(x = NULL, y = "Area per year (km2)", title = "Disturbance history", subtitle = "Fire from MTBS burn severity; harvest from LCMS tree removal") +
        theme_lucas() + theme(legend.position = "bottom")
      f <- fig(8, "disturbance"); save_fig(p, f, 2.2 + 1.6 * uniqueN(di$Family))
      add(8, "Disturbance history", "Annual area burned by severity (MTBS) and harvested by clearcut and selection (LCMS tree removal), as written by stage 6.", f) } }

  # ---- 09 climate multipliers -----------------------------------------------------------------------------------------------
  if (!is.null(I$climate) && nrow(I$climate)) {
    cl <- copy(I$climate); cl[, Effect := sprintf("%s (%s)", FlowGroup, Model)]
    p <- ggplot(cl, aes(Timestep, Mean, colour = Effect, fill = Effect)) + geom_hline(yintercept = 1, colour = MUTED, linewidth = 0.3, linetype = 2) +
      geom_ribbon(aes(ymin = Min, ymax = Max), alpha = 0.15, colour = NA) + geom_line(linewidth = 0.55) + facet_wrap(~Climate, scales = "free_x") +
      scale_colour_brewer(palette = "Dark2", name = NULL) + scale_fill_brewer(palette = "Dark2", name = NULL) +
      labs(x = NULL, y = "Multiplier (1 = 1991-2020 normal)", title = "Climate multipliers", subtitle = "Study-area mean, with the range across cells") +
      theme_lucas() + theme(legend.position = "bottom") + guides(colour = guide_legend(ncol = 2))
    f <- fig(9, "climate"); save_fig(p, f, 3.8)
    add(9, "Climate multipliers", "Year-to-year growth and decomposition multipliers from PRISM against each cell's 1991-2020 normal (stage 7): the study-area mean and the range across cells.", f) }

  # ---- 10 build checks ------------------------------------------------------------------------------------------------------
  if (!is.null(I$validation) && nrow(I$validation)) {
    v <- I$validation[, .(Checks = .N, Failed = sum(Status != "Pass")), by = Stage][order(Stage)]
    v[, Passed := Checks - Failed]; vm <- melt(v[, .(Stage, Passed, Failed)], id.vars = "Stage", variable.name = "Status", value.name = "n")
    p <- ggplot(vm, aes(n, factor(Stage, levels = rev(v$Stage)), fill = Status)) + geom_col(width = 0.7) +
      scale_fill_manual(values = c(Passed = "#1b7837", Failed = "#b2182b"), name = NULL, drop = FALSE) + scale_x_continuous(expand = expansion(c(0, 0.05))) +
      labs(x = "Validation checks", y = NULL, title = "Build checks", subtitle = sprintf("%d checks, %d failed (Build Results > Validation lists each)", sum(v$Checks), sum(v$Failed))) +
      theme_lucas() + theme(legend.position = "bottom", panel.grid.major.y = element_blank())
    f <- fig(10, "checks"); save_fig(p, f, 3.2)
    add(10, "Build checks", "The validation checks each stage ran on its own outputs, passed and failed.", f) }

  rbindlist(rows) }
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a
