# =============================================================================
# 02-urban-suitability-maps.R - maps of 01's urbanization suitability for P26, with the 2013-2023 new development on top
# =============================================================================
# Panels: the 150 m multiplier over P26 (the scale a 150 m model would use) with cells that gained development 2013-2023; a 30 m
# zoom around Grass Valley / Nevada City; the share of new development that fell in the most suitable land (capture curve) for the
# final model, with random placement for reference. GAP 1-3 cells are 0.
# Usage: Rscript dev/urban/02-urban-suitability-maps.R
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table); library(ggplot2) })
OUT <- "F:/lucasCore/dev/urban"; CA <- file.path(OUT, "cache"); DEV <- 21:24
S30 <- rast(file.path(OUT, "urban-suitability-p26-30m.tif")); S150 <- rast(file.path(OUT, "urban-suitability-p26-150m.tif"))
n12 <- rast(file.path(CA, "nlcd_2012.tif")); n23 <- rast(file.path(CA, "nlcd_2023.tif"))
new <- !(n12 %in% c(DEV, 11, 12)) & (n23 %in% DEV) & !is.na(n12)
gap <- rast(file.path(CA, "gap.tif"))
cat(sprintf("new development 2013-2023: %.1f km2\n", global(new, "sum", na.rm = TRUE)[[1]] * 9e-4))

# capture: share of 2013-2023 new development in the top x%% of eligible land by suitability (eligible in 2012, not GAP 1-3)
el <- !(n12 %in% c(DEV, 11, 12)) & !is.na(n12) & !(gap %in% 1:3)
v <- data.table(s = values(S30, mat = FALSE), e = values(el, mat = FALSE), n = values(new, mat = FALSE))[e == 1 & !is.na(s)]
setorder(v, -s); v[, `:=`(land = seq_len(.N) / .N, got = cumsum(n) / sum(n))]
cap <- v[unique(round(seq(1, .N, length.out = 400)))]
for (q in c(0.01, 0.05, 0.10, 0.25)) cat(sprintf("top %2.0f%% of eligible land holds %.0f%% of 2013-2023 new development\n", 100 * q, 100 * v[which(land >= q)[1], got]))
cat(sprintf("new development on GAP 1-3 land 2013-2023: %.2f km2\n", global(new & gap %in% 1:3, "sum", na.rm = TRUE)[[1]] * 9e-4))

th <- theme_void(base_size = 10) + theme(plot.title = element_text(face = "bold", size = 11), plot.subtitle = element_text(colour = "#6B6B6B", size = 8.5),
  legend.position = "bottom", legend.key.width = unit(1.6, "cm"), legend.key.height = unit(0.25, "cm"), plot.background = element_rect(fill = "white", colour = NA))
pal <- c("#F6F3EC", "#F1D9B5", "#E6A86A", "#CF6A3A", "#A83A2A", "#6A1F1F")

# 150 m over P26
d <- as.data.frame(S150, xy = TRUE, na.rm = TRUE); names(d)[3] <- "s"
nw <- as.data.frame(aggregate(new, 5, max, na.rm = TRUE), xy = TRUE, na.rm = TRUE); names(nw)[3] <- "n"; nw <- nw[nw$n > 0, ]
p1 <- ggplot() + geom_raster(data = d, aes(x, y, fill = s)) + geom_point(data = nw, aes(x, y), size = 0.05, colour = "#1F4E79", alpha = 0.6) +
  scale_fill_gradientn(colours = pal, limits = c(0, 1), name = "Urbanization multiplier (0-1)") + coord_equal() +
  labs(title = "Urbanization suitability, P26 (150 m multiplier for 2024)", subtitle = "Blue dots: 150 m cells that gained development 2013-2023 (NLCD). GAP 1-3 land is 0.") + th
ggsave(file.path(OUT, "urban-suitability-p26-150m.png"), p1, width = 6.5, height = 12, dpi = 170)

# 30 m zoom: Grass Valley / Nevada City
gv <- st_transform(st_sfc(st_point(c(-121.03, 39.24)), crs = 4326), crs(S30)); xy <- st_coordinates(gv)
z <- ext(xy[1] - 9000, xy[1] + 9000, xy[2] - 9000, xy[2] + 9000)
dz <- as.data.frame(crop(S30, z), xy = TRUE, na.rm = TRUE); names(dz)[3] <- "s"; dz$s <- pmin(dz$s / quantile(dz$s[dz$s > 0], 0.995), 1)
dv <- as.data.frame(crop(n23 %in% DEV, z), xy = TRUE, na.rm = TRUE); names(dv)[3] <- "d"; dv <- dv[dv$d == 1, ]
nz <- as.data.frame(crop(new, z), xy = TRUE, na.rm = TRUE); names(nz)[3] <- "n"; nz <- nz[nz$n == 1, ]
p2 <- ggplot() + geom_raster(data = dz, aes(x, y, fill = s)) + geom_raster(data = dv, aes(x, y), fill = "#8C8C8C") + geom_raster(data = nz, aes(x, y), fill = "#1F4E79") +
  scale_fill_gradientn(colours = pal, limits = c(0, 1), name = "Suitability (scaled)") + coord_equal() +
  labs(title = "30 m detail: Grass Valley and Nevada City (18 x 18 km)", subtitle = "Grey: developed in 2023. Blue: became developed 2013-2023. Colour: suitability of undeveloped land.") + th
ggsave(file.path(OUT, "urban-suitability-p26-zoom.png"), p2, width = 7.5, height = 8, dpi = 170)

# capture curve
p3 <- ggplot(cap, aes(100 * land, 100 * got)) + geom_abline(slope = 1, intercept = 0, colour = "#8C8C8C", linetype = "22") + geom_line(colour = "#A83A2A", linewidth = 0.9) +
  coord_cartesian(xlim = c(0, 50)) + labs(x = "Most suitable eligible land, % (ranked by the model)", y = "Share of 2013-2023 new development, %",
  title = "How much new development the suitability map captures", subtitle = "P26, 30 m. Dashed: random placement. Final model (fitted on 1986-2023, so this is in-sample).") +
  theme_minimal(base_size = 10) + theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"), plot.background = element_rect(fill = "white", colour = NA))
ggsave(file.path(OUT, "urban-capture-p26.png"), p3, width = 6.5, height = 4.5, dpi = 170)
cat("maps written\n")
