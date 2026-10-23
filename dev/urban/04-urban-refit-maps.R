# =============================================================================
# 04-urban-refit-maps.R - maps of 03's urbanization and Open Space suitability (log colour scale) and the out-of-sample capture
# =============================================================================
# Per model: the 150 m multiplier over P26 and a 30 m zoom (Grass Valley / Nevada City), each with that model's 2013-2023 events on
# top (same exclusions as the fit: GAP 1-3 land is 0, recent burns left out); then both capture curves (map from 2012 conditions,
# scored on 2013-2023, fit on 1986-2012). Usage: Rscript dev/urban/04-urban-refit-maps.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table); library(ggplot2) })
OUT <- "F:/lucasCore/dev/urban"; CA <- file.path(OUT, "cache"); DEVALL <- 21:24
n12 <- rast(file.path(CA, "nlcd_2012.tif")); n23 <- rast(file.path(CA, "nlcd_2023.tif")); gap <- rast(file.path(CA, "gap.tif"))
burn <- Reduce(`|`, lapply(2009:2023, function(k) rast(file.path(CA, sprintf("burn_%d.tif", k))) > 0))
base <- !(n12 %in% c(DEVALL, 11, 12)) & !is.na(n12) & !(gap %in% 1:3) & !burn
TYPES <- list(urban = list(to = 22:24, label = "Urbanization (to Developed Low, Medium or High)"), openspace = list(to = 21L, label = "Developed Open Space"))
pal <- c("#F6F3EC", "#F1D9B5", "#E6A86A", "#CF6A3A", "#A83A2A", "#6A1F1F")
th <- theme_void(base_size = 10) + theme(plot.title = element_text(face = "bold", size = 11), plot.subtitle = element_text(colour = "#6B6B6B", size = 8.5),
  legend.position = "bottom", legend.key.width = unit(1.6, "cm"), legend.key.height = unit(0.25, "cm"), plot.background = element_rect(fill = "white", colour = NA))
wr <- function(x) paste(strwrap(x, 95), collapse = "
")
lscale <- function(name) scale_fill_gradientn(colours = pal, limits = c(0, 1), breaks = seq(0, 1, 0.25), oob = scales::squish, name = name)
# PAD-US GAP 1-3 (protected from conversion) in black: at 150 m, cells mostly GAP 1-3
g150 <- as.data.frame(aggregate(gap %in% 1:3, 5, mean, na.rm = TRUE) > 0.5, xy = TRUE, na.rm = TRUE); names(g150)[3] <- "g"; g150 <- g150[g150$g == 1, ]
gv <- st_coordinates(st_transform(st_sfc(st_point(c(-121.03, 39.24)), crs = 4326), crs(n12))); z <- ext(gv[1] - 9000, gv[1] + 9000, gv[2] - 9000, gv[2] + 9000)
for (tp in names(TYPES)) {
  to <- TYPES[[tp]]$to; ev <- base & (n23 %in% to)
  s150 <- rast(file.path(OUT, sprintf("%s-suitability-p26-150m.tif", tp)))
  d <- as.data.frame(s150, xy = TRUE, na.rm = TRUE); names(d)[3] <- "s"
  nw <- as.data.frame(aggregate(ev, 5, max, na.rm = TRUE), xy = TRUE, na.rm = TRUE); names(nw)[3] <- "n"; nw <- nw[nw$n > 0, ]
  p1 <- ggplot() + geom_tile(data = d, aes(x, y, fill = s)) + geom_tile(data = g150, aes(x, y), fill = "black") + geom_point(data = nw, aes(x, y), size = 0.08, colour = "#1F4E79", alpha = 0.7) + lscale("Multiplier") +
    coord_equal() + labs(title = paste(strwrap(sprintf("%s suitability, P26 (150 m, for 2024)", TYPES[[tp]]$label), 60), collapse = "
"), subtitle = wr(sprintf("Blue: 150 m cells with this change 2013-2023 (%.1f km2 of 30 m pixels). Black: PAD-US GAP 1-3, no conversion allowed (multiplier 0).", global(ev, "sum", na.rm = TRUE)[[1]] * 9e-4))) + th
  ggsave(file.path(OUT, sprintf("%s-suitability-p26-150m.png", tp)), p1, width = 6.5, height = 12, dpi = 170)
  s30 <- crop(rast(file.path(OUT, sprintf("%s-suitability-p26-30m.tif", tp))), z)
  dz <- as.data.frame(clamp(s30 / global(s30, fun = function(x) quantile(x[x > 0], 0.995, na.rm = TRUE))[[1]], 0, 1), xy = TRUE, na.rm = TRUE); names(dz)[3] <- "s"
  dv <- as.data.frame(crop(n23 %in% DEVALL, z), xy = TRUE, na.rm = TRUE); names(dv)[3] <- "d"; dv <- dv[dv$d == 1, ]
  nz <- as.data.frame(crop(ev, z), xy = TRUE, na.rm = TRUE); names(nz)[3] <- "n"; nz <- nz[nz$n == 1, ]
  gz <- as.data.frame(crop(gap %in% 1:3, z), xy = TRUE, na.rm = TRUE); names(gz)[3] <- "g"; gz <- gz[gz$g == 1, ]
  p2 <- ggplot() + geom_tile(data = dz, aes(x, y, fill = s)) + geom_tile(data = gz, aes(x, y), fill = "black") + geom_tile(data = dv, aes(x, y), fill = "#8C8C8C") + geom_tile(data = nz, aes(x, y), fill = "#1F4E79") +
    lscale("Suitability, scaled") + coord_equal() + labs(title = sprintf("%s, 30 m: Grass Valley and Nevada City (18 x 18 km)", TYPES[[tp]]$label),
    subtitle = wr("Grey: developed in 2023. Blue: this change 2013-2023. Black: PAD-US GAP 1-3 (no conversion). Colour: suitability of undeveloped land.")) + th
  ggsave(file.path(OUT, sprintf("%s-suitability-p26-zoom.png", tp)), p2, width = 7.5, height = 8, dpi = 170)
}
r <- readRDS(file.path(OUT, "refit-metrics.rds")); cp <- rbindlist(lapply(r, `[[`, "cap"))
lab <- vapply(names(r), function(k) sprintf("%s: top 1%% holds %.0f%%, top 10%% holds %.0f%% (%.1f km2)", TYPES[[k]]$label, 100 * r[[k]]$top[1], 100 * r[[k]]$top[3], r[[k]]$km2), "")
cp[, Type := factor(Type, vapply(TYPES, `[[`, "", "label"), lab)]
p3 <- ggplot(cp, aes(100 * land, 100 * got, colour = Type)) + geom_abline(slope = 1, intercept = 0, colour = "#8C8C8C", linetype = "22") + geom_line(linewidth = 0.9) +
  scale_colour_manual(values = c("#A83A2A", "#2F6DB5"), name = NULL) + coord_cartesian(xlim = c(0, 50)) +
  labs(x = "Most suitable eligible land, % (ranked by the 2012 map)", y = "Share of 2013-2023 change captured, %", title = "Out-of-sample test: how much 2013-2023 change the 2012 map captures",
       subtitle = "P26, 30 m. Fit on 1986-2012; map from 2012 conditions. Dashed: random placement.") +
  theme_minimal(base_size = 10) + theme(panel.grid.minor = element_blank(), legend.position = "bottom", legend.direction = "vertical", plot.title = element_text(face = "bold"), plot.background = element_rect(fill = "white", colour = NA))
ggsave(file.path(OUT, "urban-refit-capture-p26.png"), p3, width = 6.5, height = 5, dpi = 170)
cat("maps written\n")
