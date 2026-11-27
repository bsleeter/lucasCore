# =============================================================================
# 03-figure-p27.R - to-do 9: the fire-season climate signal and the expected yearly burned area of a Projection Climate result
# =============================================================================
# Three panels from a Projection Climate result's Fire and Climate by Year table (OutputFireClimate): (a) the fire-season heat and
# dryness index, PRISM for the reference years and the LOCA2 run for the projection years; (b) the reference years' burned area against
# the index; (c) the expected burned area by year - the record, then the mean over iterations of the setup's random draw and of the
# climate analog draw. Burned area = the lookup's ratio x the reference mean (km2/yr, from the setup's log).
# Usage: Rscript dev/fire-climate/03-figure-p27.R <library.ssim> <Projection Climate result id> <reference mean km2> <out.png> [--title="..."]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(ggplot2); library(grid) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; L <- suppressWarnings(ssimLibrary(pos[1])); rid <- as.integer(pos[2]); mkm <- as.numeric(pos[3]); out <- pos[4]
f <- as.data.table(datasheet(scenario(L, rid), "lucasCore_OutputFireClimate")); f[, ref := AnalogYears == "reference year"]
h <- f[ref == TRUE]; p <- f[ref == FALSE]; top <- max(h$FireIndex)
# the reference palette's first three categorical slots, in order (dataviz references/palette.md), and its text and grid tokens
C_OBS <- "#2a78d6"; C_ANA <- "#eb6834"; C_RND <- "#1baf7a"; INK <- "#0b0b0b"; INK2 <- "#52514e"; GRID <- "#e4e3df"; SURF <- "#fcfcfb"
th <- theme_minimal(base_size = 11) + theme(plot.background = element_rect(fill = SURF, colour = NA), panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
  panel.grid.major.y = element_line(colour = GRID, linewidth = 0.4), axis.text = element_text(colour = INK2), axis.title = element_text(colour = INK2, size = 10),
  plot.title = element_text(colour = INK, face = "bold", size = 11.5), plot.subtitle = element_text(colour = INK2, size = 9.5), legend.position = "top", legend.justification = "left",
  legend.title = element_blank(), legend.text = element_text(colour = INK2, size = 9.5), plot.margin = margin(8, 14, 6, 8))
xr <- range(f$Timestep); y1 <- max(h$Timestep)

# (a) the index by year
d1 <- rbind(h[, .(Timestep, FireIndex, src = "PRISM (observed)")], p[, .(Timestep, FireIndex, src = "LOCA2 ACCESS-CM2 SSP2-4.5")])
d1[, src := factor(src, levels = c("PRISM (observed)", "LOCA2 ACCESS-CM2 SSP2-4.5"))]
g1 <- ggplot(d1, aes(Timestep, FireIndex, colour = src)) + geom_hline(yintercept = 0, colour = INK2, linewidth = 0.3) +
  geom_hline(yintercept = top, colour = INK2, linewidth = 0.3, linetype = "22") + annotate("text", x = xr[1], y = top, label = "hottest reference year", hjust = 0, vjust = -0.5, size = 3, colour = INK2) +
  geom_line(linewidth = 0.7) + geom_point(size = 1.8, stroke = 0) + scale_colour_manual(values = c(C_OBS, C_ANA)) + scale_x_continuous(limits = xr, breaks = seq(1990, 2040, 10)) +
  labs(title = "a  Fire-season heat and dryness", subtitle = sprintf("May-September maximum temperature and precipitation, SDs of 1984-2014; %.0f%% of projection years above the hottest on record", 100 * mean(p$FireIndex > top)),
       x = NULL, y = "Index (SD)") + th

# (b) burned area against the index, reference years
rho <- cor(h$FireIndex, h$Burned, method = "spearman"); lab <- h[order(-Burned)][1:4]; lab2 <- h[order(-FireIndex)][1:2]; lab <- unique(rbind(lab, lab2))
g2 <- ggplot(h, aes(FireIndex, Burned * mkm)) + geom_point(colour = C_OBS, size = 2.4, stroke = 0) +
  geom_text(data = lab, aes(label = Timestep, hjust = ifelse(FireIndex > 1.45, ifelse(Timestep == max(Timestep[FireIndex > 1.45]), 1.15, -0.15), 0.5), vjust = ifelse(FireIndex > 1.45, 0.5, -0.8)), colour = INK2, size = 3) + scale_y_log10(labels = scales::label_comma(), expand = expansion(mult = c(0.05, 0.12))) + scale_x_continuous(expand = expansion(mult = c(0.03, 0.07))) +
  labs(title = "b  Burned area follows the index", subtitle = sprintf("Reference years %d-%d, Spearman %.2f", min(h$Timestep), max(h$Timestep), rho), x = "Heat and dryness (SD)", y = "Burned area (km2, log)") + th

# (c) expected burned area by year
d3 <- rbind(h[, .(Timestep, km2 = Burned * mkm, src = "Observed (MTBS record)")], p[, .(Timestep, km2 = SetupBurned * mkm, src = "Projection: random draw (no climate)")],
            p[, .(Timestep, km2 = Burned * mkm, src = "Projection: climate analog draw (10 years)")])
d3[, src := factor(src, levels = c("Observed (MTBS record)", "Projection: climate analog draw (10 years)", "Projection: random draw (no climate)"))]
mn <- d3[, .(m = mean(km2)), by = .(src, per = ifelse(Timestep <= y1, "ref", "proj"))]
g3 <- ggplot(d3, aes(Timestep, km2, colour = src)) + geom_vline(xintercept = y1 + 0.5, colour = INK2, linewidth = 0.3, linetype = "22") +
  geom_hline(yintercept = mkm, colour = INK2, linewidth = 0.3) + annotate("text", x = xr[1], y = mkm, label = sprintf("reference mean %.0f km2", mkm), hjust = 0, vjust = -0.5, size = 3, colour = INK2) +
  geom_line(linewidth = 0.7) + geom_point(size = 1.8, stroke = 0) + scale_colour_manual(values = c(C_OBS, C_ANA, C_RND)) + scale_x_continuous(limits = xr, breaks = seq(1990, 2040, 10)) +
  scale_y_continuous(labels = scales::label_comma()) +
  labs(title = "c  Expected burned area each year", subtitle = sprintf("Projection years: mean of %s iterations. 2024-2043 mean: analog draw %.0f km2, random draw %.0f km2", "10",
       mn[src == levels(d3$src)[2], m], mn[src == levels(d3$src)[3], m]), x = NULL, y = "Burned area (km2)") + th

ttl <- opt("title", "Pyrome 27 (Southern Sierra Nevada): fire that follows climate")
ragg::agg_png(out, width = 2400, height = 2700, res = 220, background = SURF)
grid.newpage(); pushViewport(viewport(layout = grid.layout(4, 2, heights = unit(c(0.5, 4, 4, 4.6), "null"), widths = unit(c(1, 1), "null"))))
grid.text(ttl, x = unit(0.02, "npc"), hjust = 0, gp = gpar(fontsize = 14, fontface = "bold", col = INK), vp = viewport(layout.pos.row = 1, layout.pos.col = 1:2))
print(g1, vp = viewport(layout.pos.row = 2, layout.pos.col = 1:2)); print(g2, vp = viewport(layout.pos.row = 3, layout.pos.col = 1:2)); print(g3, vp = viewport(layout.pos.row = 4, layout.pos.col = 1:2))
invisible(dev.off()); cat("wrote", out, "\n")
