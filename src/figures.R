# =============================================================================
# figures.R - report figures of a Build result (sourced by stage 12, src/12-build-figures.R; no SyncroSim calls, so it can be
# tested on a result's files and tables directly: dev/figures/test_figures.R)
# =============================================================================
# The format of lucasFireC2F's report figures (its src/report.R): each figure is one PNG headed "Figure N. Title" with a note line
# (study area, years, grid), and lettered panels. Maps sit on shaded relief of the elevation data source that runs on, light grey,
# past the study area; inside it the classes are blended into the relief, each panel has its title and subtitle above it and a
# colour strip (classed values) or a key (named classes) below. Panels go side by side, or one under another when the study area is
# wide (height / width under 0.75). Charts are base R, lettered the same way. Each figure is drawn only when its inputs are present:
#   maps    study area and strata | initial land cover (state class, forest type, stand age) | initial carbon (total, live, soil)
#   charts  area and carbon by state class | growth curves | decay calibration | land-use change | disturbance | climate | checks
# build_figures(I, outdir) returns one row per PNG (Figure, Title, Caption, FileName).
# I: strata (list of 3 SpatRasters: primary, secondary, tertiary), strata_names (list of 3 data.tables Id, Name), strata_sources
#    (secondary and tertiary source names), sc (SpatRaster), sc_list (Name, Id, Color "a,r,g,b"), age (SpatRaster), carbon_curves,
#    volume_curves, decay, stocks (named list of SpatRasters by stock type), trans, climate, validation (data.tables), dem
#    (elevation .tif), label (study area), years (start, end), result (result scenario id, for the note)
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) })
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a

INK <- "#20211f"; MUTED <- "#55534c"; GRID <- "#e3e1db"
RAMP_AGE <- colorRampPalette(c("#f5efe3", "#e9dfa6", "#b9cf86", "#6fae74", "#2f8a6f", "#1f5f63", "#22314f"))
RAMP_C <- colorRampPalette(c("#f5efe3", "#dfe6b4", "#a9cf86", "#62ab68", "#2b8152", "#195c3f", "#0f3a2b"))
RAMP_SOIL <- colorRampPalette(c("#f5efe3", "#ead7ab", "#d4ae73", "#b07f45", "#85572b", "#5a3a1c", "#33210f"))
QUAL <- c("#4e79a7", "#f28e2b", "#59a14f", "#e15759", "#b07aa1", "#76b7b2", "#edc948", "#9c755f", "#ff9da7", "#86bcb6", "#8cd17d", "#d4a6c8")
argb <- function(s) vapply(strsplit(s, ","), function(v) { v <- as.integer(v); if (length(v) == 4) rgb(v[2], v[3], v[4], maxColorValue = 255) else "#999999" }, "")
short_class <- function(x) sub(" Group$", "", sub("^Forest: ", "", x))      # "Forest: Western Oak Group" -> "Western Oak"

build_figures <- function(I, outdir) {
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  rows <- list(); n <- 0L
  done <- function(f, title, caption) rows[[length(rows) + 1]] <<- data.table(Figure = n, Title = title, Caption = caption, FileName = f)
  file_of <- function(slug) file.path(outdir, sprintf("Fig%02d_%s.png", n, slug))
  scn <- I$sc_list; scol <- setNames(argb(scn$Color), scn$Name)
  cell_km2 <- prod(res(I$sc)) / 1e6; area <- cell_km2 * sum(!is.na(values(I$sc, mat = FALSE)))
  NOTE <- sprintf("%s, %s km2 on a %g m grid; Build %s-%s%s.", I$label %||% "Study area", format(round(area), big.mark = ","), res(I$sc)[1],
                  I$years[1], I$years[2], if (is.null(I$result)) "" else sprintf(" (result %s)", I$result))

  # ---- the map frame: the study area plus 3% on each side, on a grid of ~1600 cells along its long side ------------------------
  zone <- { o <- as.polygons(!is.na(I$sc) * 1, dissolve = TRUE); st_as_sf(o[values(o)[[1]] == 1]) }
  bb <- st_bbox(zone); pad <- 0.03 * max(bb$xmax - bb$xmin, bb$ymax - bb$ymin)
  rr <- max(30, signif(max(bb$xmax - bb$xmin, bb$ymax - bb$ymin) / 1600, 2))
  el <- rast(ext(bb$xmin - pad, bb$xmax + pad, bb$ymin - pad, bb$ymax + pad), resolution = rr, crs = crs(I$sc))
  E <- ext(el); AR <- (E[4] - E[3]) / (E[2] - E[1]); WIDE <- AR < 0.75
  inz <- !is.na(values(rasterize(vect(zone), el, field = 1), mat = FALSE))
  # relief: the DEM averaged onto the frame, lit from three northerly directions; flat when there is no DEM
  hn <- rep(0.5, ncell(el))
  dem_ok <- !is.null(I$dem) && !is.na(I$dem) && file.exists(I$dem)
  if (dem_ok) { d <- rast(I$dem); d <- crop(d, project(as.polygons(E, crs = crs(el)), crs(d)))
    f <- floor(rr / res(d)[1]); if (f > 1) d <- aggregate(d, f, "mean", na.rm = TRUE); d <- project(d, el, method = "bilinear")
    slp <- terrain(d, "slope", unit = "radians"); asp <- terrain(d, "aspect", unit = "radians")
    hs <- Reduce(`+`, lapply(c(300, 337, 15), function(k) shade(slp, asp, angle = 42, direction = k))) / 3
    hv <- values(hs, mat = FALSE); qq <- quantile(hv, c(0.02, 0.98), na.rm = TRUE); hn <- pmin(pmax((hv - qq[1]) / (qq[2] - qq[1]), 0), 1); hn[is.na(hn)] <- 0.5 }
  it <- ifelse(inz, 0.58 + 0.64 * hn, 0.87 + 0.19 * hn)
  # a model-grid raster on the frame: each frame cell takes the value of the model cell under its centre (by position, so unit ids of
  # 9 digits stay exact; resampling stores them as 32-bit floats, which round them)
  at <- cellFromXY(I$sc, xyFromCell(el, seq_len(ncell(el))))
  cv <- function(r) values(r, mat = FALSE)[at]
  # an RGB image of class indices k (1..length(cols); NA = grey inside the study area) blended into the relief
  torgb <- function(k, cols) { cm <- col2rgb(cols) / 255
    R <- rep(0.925, length(k)); G <- rep(0.920, length(k)); B <- rep(0.909, length(k))
    g <- inz & is.na(k); R[g] <- 0.795; G[g] <- 0.805; B[g] <- 0.818
    s <- inz & !is.na(k); R[s] <- cm[1, k[s]]; G[s] <- cm[2, k[s]]; B[s] <- cm[3, k[s]]
    r <- rast(el, nlyr = 3); values(r) <- cbind(round(pmin(R * it, 1) * 255), round(pmin(G * it, 1) * 255), round(pmin(B * it, 1) * 255)); r }
  classed <- function(v, brk) cut(v, brk, include.lowest = TRUE, right = FALSE, labels = FALSE)
  # breaks for a continuous map: pretty steps between its 1st and 99.5th percentiles, both end classes open; each class is labelled
  # with its lower edge, as lucasFireC2F's strips are
  # equal = FALSE: equal-area classes instead (breaks at the 2nd, 10th, 20th ... 90th and 98th percentiles, rounded), for a map whose
  # values bunch, like soil carbon, where forest cells start at their type's calibrated mean
  steps <- function(v, equal = TRUE) { q <- quantile(v[inz], c(0.01, 0.995), na.rm = TRUE)
    b <- if (equal) pretty(q, n = 8) else { p <- quantile(v[inz], c(.02, seq(.1, .9, .1), .98), na.rm = TRUE); unique(ifelse(p >= 10, round(p), signif(p, 2))) }
    b <- b[b > q[1] & b < q[2]]
    if (!length(b)) b <- unique(signif(q, 2)); fm <- function(x) format(x, big.mark = ",", trim = TRUE)
    list(brk = c(-Inf, b, Inf), lab = c(paste0("<", fm(b[1])), if (length(b) > 1) fm(b[-length(b)]), paste0(">", fm(b[length(b)])))) }
  # a categorical map: the n largest classes of r named by lst (Id, Name), the rest "Other"; colours by name or a qualitative set
  cats <- function(r, lst, n = 10, colours = NULL, label = identity) {
    v <- cv(r); tab <- sort(table(v[inz & !is.na(v)]), decreasing = TRUE); top <- as.numeric(names(tab))[seq_len(min(n, length(tab)))]
    nm <- lst$Name[match(top, lst$Id)]; nm[is.na(nm)] <- paste("Id", top[is.na(nm)])
    other <- length(tab) > length(top); k <- match(v, top); if (other) k[!is.na(v) & is.na(k)] <- length(top) + 1L
    cols <- if (!is.null(colours)) unname(colours[nm]) else QUAL[(seq_along(top) - 1) %% length(QUAL) + 1]; cols[is.na(cols)] <- "#9a9a9a"
    list(k = k, cols = c(cols, if (other) "#bdbdbd"), lab = c(label(nm), if (other) "Other"), key = TRUE) }

  # ---- a map figure: panels = list(list(k, cols, lab, key, title, sub)) -----------------------------------------------------
  map_figure <- function(slug, title, panels, caption, note = NOTE, PW = if (WIDE) 1400 else if (length(panels) == 1) 900 else 520) {
    n <<- n + 1L; f <- file_of(slug); np <- length(panels); PH <- round(PW * AR)
    LM <- 40; GAP <- 40; TOP <- 150; RT <- 90
    # the legend's height: a strip, or a key of swatches flowing in columns of the widest label
    leg_h <- function(p) if (!isTRUE(p$key)) 90 else { cw <- 34 + 8.6 * max(nchar(p$lab)); nc <- max(1, floor(PW / cw)); 30 + 28 * ceiling(length(p$lab) / nc) }
    RB <- vapply(panels, leg_h, 0)
    if (WIDE) { W <- 2 * LM + PW; cellh <- RT + PH + RB; H <- TOP + sum(cellh) + GAP * (np - 1); x0s <- rep(LM, np); y0s <- H - TOP - cumsum(cellh) - GAP * (seq_len(np) - 1) + RB }
    else { W <- 2 * LM + np * PW + (np - 1) * GAP; H <- TOP + RT + PH + max(RB); x0s <- LM + (seq_len(np) - 1) * (PW + GAP); y0s <- rep(max(RB), np) }
    png(f, width = W, height = H, res = 150, bg = "white"); on.exit(dev.off())
    par(mar = c(0, 0, 0, 0), family = "sans"); plot.new(); plot.window(c(0, W), c(0, H), xaxs = "i", yaxs = "i")
    text(LM, H - 40, sprintf("Figure %d. %s", n, title), adj = c(0, .5), cex = 1.25, font = 2, col = INK)
    nt <- strwrap(note, floor((W - 2 * LM) / 9.5)); for (j in seq_along(nt)) text(LM, H - 80 - (j - 1) * 22, nt[j], adj = c(0, .5), cex = 0.72, col = MUTED)
    for (i in seq_len(np)) { p <- panels[[i]]; x0 <- x0s[i]; y0 <- y0s[i]
      par(fig = c(x0 / W, (x0 + PW) / W, y0 / H, (y0 + PH) / H), new = TRUE, mar = c(0, 0, 0, 0))
      plotRGB(torgb(p$k, p$cols), axes = FALSE, mar = NA, maxcell = Inf, smooth = TRUE)
      plot(st_geometry(zone), add = TRUE, border = INK, lwd = 1.1, col = NA)
      par(fig = c(0, 1, 0, 1), new = TRUE, mar = c(0, 0, 0, 0), xpd = NA); plot.new(); plot.window(c(0, W), c(0, H), xaxs = "i", yaxs = "i")
      tt <- strwrap(sprintf("(%s) %s", letters[i], p$title), floor(PW / 10.5)); for (j in seq_along(tt)) text(x0, y0 + PH + 60 + (length(tt) - j) * 24, tt[j], adj = c(0, .5), font = 2, cex = 0.9, col = INK)
      text(x0, y0 + PH + 30, p$sub %||% "", adj = c(0, .5), cex = 0.62, col = MUTED)
      nL <- length(p$cols)
      if (!isTRUE(p$key)) { lw <- PW / nL
        for (j in seq_len(nL)) { rect(x0 + (j - 1) * lw, y0 - 45, x0 + j * lw, y0 - 25, col = p$cols[j], border = "white"); text(x0 + (j - .5) * lw, y0 - 65, p$lab[j], cex = 0.55, col = INK) }
      } else { cw <- 34 + 8.6 * max(nchar(p$lab)); nc <- max(1, floor(PW / cw)); cw <- PW / nc
        for (j in seq_len(nL)) { cx <- x0 + ((j - 1) %% nc) * cw; cy <- y0 - 30 - ((j - 1) %/% nc) * 28
          rect(cx, cy - 9, cx + 22, cy + 9, col = p$cols[j], border = "white"); text(cx + 30, cy, p$lab[j], adj = c(0, .5), cex = 0.6, col = INK) } } }
    done(f, title, caption) }

  # ---- a chart figure: the same header, base R panels drawn by draw() in an nr x nc layout -----------------------------------
  chart_figure <- function(slug, title, caption, nr, nc, draw, w = 2400, h = 700 * nr + 260, note = NOTE) {
    n <<- n + 1L; f <- file_of(slug)
    png(f, width = w, height = h, res = 200, bg = "white"); on.exit(dev.off())
    par(mfrow = c(nr, nc), oma = c(0, 0, 4.2, 0), mar = c(4.5, 5, 3, 1), family = "sans", col.axis = MUTED, col.lab = INK, las = 1, cex.axis = .8, tcl = -.25, mgp = c(2.6, .5, 0))
    draw()
    mtext(sprintf("Figure %d. %s", n, title), outer = TRUE, side = 3, line = 2.4, adj = 0.01, cex = 1.15, font = 2, col = INK)
    mtext(note, outer = TRUE, side = 3, line = 1, adj = 0.01, cex = .72, col = MUTED)
    done(f, title, caption) }
  ptitle <- function(i, s) title(main = sprintf("(%s) %s", letters[i], s), adj = 0, font.main = 2, cex.main = .95, col.main = INK)
  hgrid <- function() abline(h = axTicks(2), col = GRID, lwd = .6)
  # a legend in one row just above the plot's top right corner, clear of the data
  top_legend <- function(...) legend("bottomright", ..., horiz = TRUE, inset = c(0, 1.01), xpd = NA, bty = "n", cex = .72, border = NA)

  relief <- if (dem_ok) " Shaded relief from the elevation data source." else ""
  vS <- cv(I$sc)
  forest <- !is.na(vS) & vS >= 100 & vS < 1000

  # ---- maps: study area and strata ---------------------------------------------------------------------------------------------
  if (!is.null(I$strata)) {
    src <- I$strata_sources %||% c(NA, NA)
    tl <- c("FIA ecodivisions (primary strata)", sprintf("%s (secondary strata)", src[1] %||% "Secondary"), sprintf("%s (tertiary strata)", src[2] %||% "Tertiary"))
    P <- list()
    for (j in seq_along(I$strata)) { r <- I$strata[[j]]; if (is.null(r) || nrow(unique(r)) < 2) next
      p <- cats(r, I$strata_names[[j]], n = 10, label = function(x) sub("^[^:]*: ", "", x)); p$title <- tl[j]
      p$sub <- sprintf("%d units%s", nrow(unique(r)), if ("Other" %in% p$lab) "; the ten largest named" else ""); P[[length(P) + 1]] <- p }
    if (length(P)) map_figure("strata", "Study area and strata", P,
      sprintf("The strata levels of the model grid; a level with a single unit is not mapped. The largest units of each are named, the rest grouped as Other.%s", relief)) }

  # ---- maps: initial land cover ------------------------------------------------------------------------------------------------
  P <- list(c(cats(I$sc, scn, n = 12, colours = scol, label = short_class), list(title = sprintf("Initial state class, %s", I$years[1]), sub = "annual NLCD with forest, grassland, shrubland and wetland types")))
  if (any(forest)) { fr <- I$sc; fr[!(fr >= 100 & fr < 1000)] <- NA
    P[[2]] <- c(cats(fr, scn, n = 10, colours = scol, label = short_class), list(title = "Forest type group", sub = "forest cells; grey: not forest")) }
  if (!is.null(I$age)) { a <- cv(I$age); a[!forest] <- NA; ab <- c(0, 1, 20, 40, 60, 80, 100, 120, 150, Inf)
    P[[length(P) + 1]] <- list(k = classed(a, ab), cols = RAMP_AGE(length(ab) - 1), lab = c("0", "1-20", "20-40", "40-60", "60-80", "80-100", "100-120", "120-150", ">150"),
                               title = "Stand age (years)", sub = "NASA CMS forest age, updated by disturbance; grey: not forest") }
  map_figure("land_cover", "Initial land cover", P,
    sprintf("(a) State class in the start year (%s), the twelve largest named. (b) Forest type groups of the forest cells. (c) Initial stand age of the forest cells.%s", I$years[1], relief))

  # ---- maps: initial carbon ----------------------------------------------------------------------------------------------------
  if (!is.null(I$stocks) && length(I$stocks)) {
    grp <- function(s) ifelse(grepl("^Biomass", s), "Live biomass", ifelse(grepl("Snag|Aboveground Medium|Belowground Fast", s), "Dead wood",
                        ifelse(grepl("Aboveground (Very Fast|Fast|Slow)", s), "Litter", "Soil")))
    sum_of <- function(k) { r <- Reduce(`+`, lapply(I$stocks[k], function(r) { r[is.na(r)] <- 0; r })); mask(r, I$sc) }
    pools <- grp(names(I$stocks)); tot <- sum_of(names(I$stocks))
    totTg <- global(tot * cell_km2 * 100, "sum", na.rm = TRUE)[[1]] / 1e6
    mp <- function(r, ramp, title, sub, equal = TRUE) { v <- cv(r); s <- steps(v, equal); list(k = classed(v, s$brk), cols = ramp(length(s$brk) - 1), lab = s$lab, title = title, sub = sub) }
    P <- list(mp(tot, RAMP_C, "Total ecosystem carbon (Mg C/ha)", sprintf("the 14 CBM pools; %.1f Tg C", totTg)))
    if (any(pools == "Live biomass")) P[[2]] <- mp(sum_of(names(I$stocks)[pools == "Live biomass"]), RAMP_C, "Live biomass carbon (Mg C/ha)", "stem, foliage, other wood and roots")
    if (any(pools == "Soil")) P[[length(P) + 1]] <- mp(sum_of(names(I$stocks)[pools == "Soil"]), RAMP_SOIL, "Soil carbon (Mg C/ha)", "belowground pools; classes of equal area", equal = FALSE)
    map_figure("initial_carbon", sprintf("Initial carbon stocks, %s", I$years[1]), P,
      sprintf("Carbon in the start year (%s): %.1f Tg C in the study area. (a, b) Classes in even steps between each map's 1st and 99.5th percentiles; the end classes are open. (c) Classes of roughly equal area: forest soil starts at its type's gSSURGO mean (stage 3 calibrates decay to it), so it varies little within a type, and other land takes gSSURGO directly.%s", I$years[1], totTg, relief)) }

  # ---- charts: area and carbon by state class ----------------------------------------------------------------------------------
  fq <- as.data.table(freq(I$sc))[, .(Id = value, km2 = count * cell_km2)][, Class := scn$Name[match(Id, scn$Id)]][order(-km2)]
  top <- head(fq, 15)
  zs <- NULL
  if (!is.null(I$stocks) && length(I$stocks)) {
    zs <- rbindlist(lapply(names(I$stocks), function(s) { z <- zonal(I$stocks[[s]], I$sc, fun = "mean", na.rm = TRUE); setnames(z, c("Id", "mean"))
      data.table(Id = z$Id, Pool = grp(s), mean = z$mean) }))[, .(mean = sum(mean, na.rm = TRUE)), by = .(Id, Pool)]
    zs <- dcast(zs[Id %in% top$Id], Id ~ Pool, value.var = "mean", fill = 0) }
  chart_figure("area_carbon_by_class", "Area and carbon by state class", sprintf("(a) Area of the 15 largest state classes in %s. (b) Their mean carbon density by pool.", I$years[1]),
    1, if (is.null(zs)) 1 else 2, h = 1150, draw = function() {
      par(mar = c(4.5, 15, 3, 1)); o <- rev(seq_len(nrow(top)))
      barplot(top$km2[o], names.arg = short_class(top$Class[o]), horiz = TRUE, col = scol[top$Class[o]], border = NA, cex.names = .7, xlab = "Area (km2)")
      abline(v = axTicks(1), col = GRID, lwd = .6); ptitle(1, "Area by state class")
      if (!is.null(zs)) { pc <- c(`Live biomass` = "#2b8152", `Dead wood` = "#a6611a", Litter = "#dfc27d", Soil = "#5a3a1c"); pc <- pc[names(pc) %in% names(zs)]
        z <- zs[match(top$Id, Id)]; m <- t(as.matrix(z[, names(pc), with = FALSE])); m[is.na(m)] <- 0
        barplot(m[, o, drop = FALSE], names.arg = short_class(top$Class[o]), horiz = TRUE, col = pc, border = NA, cex.names = .7, xlab = "Mean carbon density (Mg C/ha)")
        abline(v = axTicks(1), col = GRID, lwd = .6); ptitle(2, "Carbon density by pool")
        legend("bottomright", names(pc), fill = pc, border = NA, bty = "n", cex = .75) } })

  # ---- charts: growth curves ----------------------------------------------------------------------------------------------------
  if (!is.null(I$carbon_curves) && nrow(I$carbon_curves)) {
    cc <- I$carbon_curves; vc <- I$volume_curves
    eco <- head(cc[, .N, by = StratumId][order(-N), StratumId], 3); ne <- length(eco); hasV <- !is.null(vc) && nrow(vc)
    types <- sort(unique(cc$StateClassId)); tc <- scol[types]; tc[is.na(tc)] <- "#777777"
    chart_figure("growth_curves", "Growth curves", "Live tree carbon (CBM biomass pools) and merchantable volume by stand age for the forest types of each ecodivision, fitted to FIA.",
      if (hasV) 2 else 1, ne, h = (if (hasV) 1500 else 800) + 160, draw = function() {
        i <- 0; panel <- function(d, y, ylab, lab) for (e in eco) { i <<- i + 1; x <- d[StratumId == e]
          plot(NA, xlim = range(d$Age), ylim = c(0, max(d[[y]], na.rm = TRUE) * 1.05), xlab = "Stand age (years)", ylab = ylab, bty = "l"); hgrid()
          for (t in types) { s <- x[StateClassId == t][order(Age)]; if (nrow(s)) lines(s$Age, s[[y]], col = tc[t], lwd = 1.6) }
          ptitle(i, sprintf("%s, %s", lab, e))
          if (i == 1) legend("bottomright", short_class(types), col = tc, lwd = 2, bty = "n", cex = .65) }
        panel(cc, "TotalLive", "Live tree carbon (Mg C/ha)", "Live tree carbon")
        if (hasV) panel(vc, "MerchantableVolume", "Merchantable volume (m3/ha)", "Merchantable volume") }) }

  # ---- charts: decay calibration ------------------------------------------------------------------------------------------------
  if (!is.null(I$decay) && nrow(I$decay)) {
    dc <- I$decay; eco <- head(dc[, .N, by = StratumId][order(-N), StratumId], 3); ne <- length(eco)
    pc <- c(Snag = "#8c510a", `Down wood` = "#d8b365", `Forest floor` = "#5ab4ac", Soil = "#01665e")
    cols <- c(Snag = "SnagDecayMultiplier", `Down wood` = "DownWoodDecayMultiplier", `Forest floor` = "ForestFloorDecayMultiplier", Soil = "SoilDecayMultiplier")
    chart_figure("decay_calibration", "Dead organic matter calibration", "Decay rate multipliers of the snag, down wood, forest floor and soil pools by forest type, calibrated in stage 3 so spin-up carbon matches FIA and gSSURGO; 1 = the CBM-CFS3 default.",
      1, ne, h = 300 + 70 * max(dc[, .N, by = StratumId]$N), draw = function() {
        for (i in seq_along(eco)) { x <- dc[StratumId == eco[i]]; x <- x[order(x$SoilDecayMultiplier)]; ny <- nrow(x)
          par(mar = c(4.5, if (i == 1) 13 else 1, 3, 1))
          rg <- range(unlist(dc[, cols, with = FALSE]), 1, na.rm = TRUE)      # one scale for every panel
          plot(NA, xlim = rg, ylim = c(.5, ny + .5), log = "x", yaxt = "n", xlab = "Multiplier (log)", ylab = "", bty = "l")
          abline(v = 1, lty = 2, col = MUTED); abline(h = seq_len(ny), col = GRID, lwd = .6)
          for (k in names(cols)) points(x[[cols[k]]], seq_len(ny), pch = 16, col = pc[k], cex = 1.1)
          if (i == 1) axis(2, at = seq_len(ny), labels = short_class(x$StateClassId), cex.axis = .7, tick = FALSE)
          ptitle(i, eco[i]); if (i == ne) top_legend(names(pc), col = pc, pch = 16) } }) }

  # ---- charts: historical land-use change and disturbance -----------------------------------------------------------------------
  if (!is.null(I$trans) && nrow(I$trans)) {
    tr <- copy(I$trans); tr[, Group := trimws(sub(" \\[Type\\]$", "", TransitionGroup))]; tr[, Family := sub(":.*$", "", Group)]
    tr[, Member := ifelse(grepl(":", Group), trimws(sub("^[^:]*:", "", Group)), Group)]
    yrs <- (I$years[1] + 1):I$years[2]
    stack <- function(d, fam, cols, i) { x <- d[Family == fam, .(Area = sum(Area)), by = .(Timestep, Member)]
      m <- dcast(x, Member ~ Timestep, value.var = "Area", fill = 0); mm <- matrix(0, nrow(m), length(yrs), dimnames = list(m$Member, yrs))
      k <- intersect(colnames(m)[-1], as.character(yrs)); mm[, k] <- as.matrix(m[, k, with = FALSE])
      mm <- mm[order(match(rownames(mm), names(cols)), rownames(mm)), , drop = FALSE]      # the colour list's order (low to high severity)
      cl <- cols[rownames(mm)]; cl[is.na(cl)] <- QUAL[seq_len(sum(is.na(cl)))]
      b <- barplot(mm, col = cl, border = NA, space = .15, xaxt = "n", ylab = "Area per year (km2)"); hgrid()
      barplot(mm, col = cl, border = NA, space = .15, xaxt = "n", add = TRUE, axes = FALSE)
      at <- if (length(yrs) <= 15) seq_along(yrs) else which(yrs %% 5 == 0); axis(1, at = b[at], labels = yrs[at], cex.axis = .75)
      ptitle(i, fam); top_legend(rownames(mm), fill = cl) }
    fams <- intersect(c("Urbanization", "Intensification", "Ag Expansion", "Ag Contraction"), unique(tr$Family))
    if (length(fams)) chart_figure("land_use_change", "Historical land-use change", sprintf("Annual area of each land-use transition group, %s-%s, from annual NLCD (stage 6), by member type.", min(yrs), max(yrs)),
      ceiling(length(fams) / 2), min(2, length(fams)), draw = function() for (i in seq_along(fams)) stack(tr, fams[i], c(), i))
    dfam <- intersect(c("Fire", "Forest Harvest", "Insect"), unique(tr$Family))
    if (length(dfam)) { tr[Family %in% dfam, Member := sub("^Forest ", "", Member)]
      dcol <- c(`Low Severity` = "#fbe3a2", `Medium Severity` = "#ef8f2a", `High Severity` = "#a81d1a", Clearcut = "#3d3d3d", Selection = "#b5b5b5")
      chart_figure("disturbance", "Disturbance history", sprintf("Annual area burned by severity (MTBS) and harvested by clearcut and selection (LCMS tree removal), %s-%s, as written by stage 6.", min(yrs), max(yrs)),
        length(dfam), 1, h = 640 * length(dfam) + 260, draw = function() for (i in seq_along(dfam)) stack(tr, dfam[i], dcol, i)) } }

  # ---- charts: climate multipliers -----------------------------------------------------------------------------------------------
  if (!is.null(I$climate) && nrow(I$climate)) {
    cl <- copy(I$climate); cl[, Effect := sprintf("%s (%s)", FlowGroup, Model)]; cls <- unique(cl$Climate); eff <- unique(cl$Effect)
    ec <- setNames(QUAL[seq_along(eff)], eff)
    chart_figure("climate", "Climate multipliers", "Year-to-year growth and decomposition multipliers against each cell's 1991-2020 normal (stage 7): the study-area mean, with the range across cells shaded.",
      1, length(cls), h = 1000, draw = function() for (i in seq_along(cls)) { x <- cl[Climate == cls[i]]
        plot(NA, xlim = range(x$Timestep), ylim = range(c(x$Min, x$Max), na.rm = TRUE), xlab = "", ylab = "Multiplier (1 = normal)", bty = "l"); hgrid(); abline(h = 1, lty = 2, col = MUTED)
        for (e in eff) { s <- x[Effect == e][order(Timestep)]; if (!nrow(s)) next
          polygon(c(s$Timestep, rev(s$Timestep)), c(s$Min, rev(s$Max)), col = adjustcolor(ec[e], .15), border = NA); lines(s$Timestep, s$Mean, col = ec[e], lwd = 1.6) }
        ptitle(i, cls[i]); top_legend(eff, col = ec, lwd = 2) }) }

  # ---- charts: build checks ------------------------------------------------------------------------------------------------------
  if (!is.null(I$validation) && nrow(I$validation)) {
    v <- I$validation[, .(Checks = .N, Failed = sum(Status != "Pass")), by = Stage][order(Stage)]
    chart_figure("checks", "Build checks", "The validation checks each stage ran on its own outputs; Build Results > Validation lists each with its detail.",
      1, 1, h = 300 + 70 * nrow(v), draw = function() { par(mar = c(4.5, 14, 3, 1)); o <- rev(seq_len(nrow(v)))
        barplot(rbind(v$Checks - v$Failed, v$Failed)[, o, drop = FALSE], names.arg = v$Stage[o], horiz = TRUE, col = c("#2b8152", "#a81d1a"), border = NA, cex.names = .75, xlab = "Checks")
        ptitle(1, sprintf("%d checks, %d failed", sum(v$Checks), sum(v$Failed)))
        legend("bottomright", c("Passed", "Failed"), fill = c("#2b8152", "#a81d1a"), border = NA, bty = "n", cex = .75) }) }

  rbindlist(rows) }
