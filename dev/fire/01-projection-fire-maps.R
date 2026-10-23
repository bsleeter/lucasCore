# =============================================================================
# 01-projection-fire-maps.R - Placer projections for the three fire methods with annual fire maps, and a figure of them
# =============================================================================
# On the phaseO library (Projection Setup result 58, historical run 49): one 10-year, 1-iteration projection per fire method
# (1 historical rates, 2 burn probability with FPA-FOD ignitions, 3 lucasFireC2F seasons of the Sierra merge), each saving the
# spatial transitions of the three severity types every year. Figure: a row per method - the 10 years' burned cells by severity on
# a hillshade, then the three years with the most fire - beside the interagency perimeters of 2014-2023 (the last 10 real years).
# Output: dev/fire/placer-fire-maps.png (and the projections' result ids in dev/fire/projections.csv).
# Usage: Rscript dev/fire/01-projection-fire-maps.R [--years=10] [--reuse]   (--reuse: draw from the projections listed in the csv)
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(terra); library(sf) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"; OUT <- "F:/lucasCore/dev/fire"
YRS <- as.integer(opt("years", 10)); setup <- 58L; hist <- 49L
C2F <- "F:/lucas-master/Models/lucasFireC2F Dev/lucasFireC2F Sierra Nevada & Foothills.ssim"
L <- ssimLibrary(f)
SEV <- c("Fire: Low Severity [Type]", "Fire: Medium Severity [Type]", "Fire: High Severity [Type]")
methods <- list(
  list(key = "m1", label = "1. Historical rates", fo = data.frame(FireMethod = "Historical rates")),
  list(key = "m2", label = "2. Burn probability (FSim) + FPA-FOD ignitions", fo = data.frame(FireMethod = "Burn probability", IgnitionSource = "FPA-FOD ignition density")),
  list(key = "m3", label = "3. lucasFireC2F seasons (Sierra merge)", fo = data.frame(FireMethod = "lucasFireC2F seasons", C2FLibrary = C2F, C2FScenarioId = 82L)))

# --run=<scenario id>: run one scenario (the three are run in parallel, one R process each) and print its result id
if (!is.na(opt("run", NA))) { R <- run(scenario(L, as.integer(opt("run", NA)))); cat("RESULT", scenarioId(R), "\n"); quit(save = "no") }
# --create: make the three scenarios and list them; the caller runs them (--run) and then draws (--reuse)
if ("--create" %in% a) {
  ids <- rbindlist(lapply(methods, function(m) {
    out <- system2(RS, c("F:/lucasCore/tools/new-projection.R", shQuote(f), shQuote(c(sprintf("--historical=%d", hist), sprintf("--build=%d", setup), sprintf("--years=%d", YRS),
                   "--iterations=1", "--replace", sprintf("--name=Fire maps (%s)", m$key)))), stdout = TRUE, stderr = TRUE)
    pid <- as.integer(tail(out[!grepl("Warning|undetermined|^In ssimLibrary", out)], 1)); if (is.na(pid)) { cat(out, sep = "\n"); stop("new-projection.R failed") }
    S <- scenario(L, pid); saveDatasheet(S, m$fo, "lucasCore_FireOptions")
    os <- as.data.frame(datasheet(S, "stsim_OutputOptionsSpatial")); os$RasterOutputTR <- TRUE; os$RasterOutputTRTimesteps <- 1L
    saveDatasheet(S, os[, setdiff(names(os), c("OutputOptionsSpatialId", "ScenarioId")), drop = FALSE], "stsim_OutputOptionsSpatial")
    saveDatasheet(S, data.frame(TransitionGroupId = c("Fire", SEV), Summary = TRUE, Spatial = c(TRUE, NA, NA, NA)), "stsim_OutputFilterTransitionGroups")
    data.table(id = m$key, label = m$label, parent = pid) }))
  fwrite(ids, file.path(OUT, "projections.csv")); cat("PARENTS", ids$parent, "\n"); quit(save = "no") }
if (FALSE) {
  ids <- rbindlist(lapply(methods, function(m) {
    out <- system2(RS, c("F:/lucasCore/tools/new-projection.R", shQuote(f), shQuote(c(sprintf("--historical=%d", hist), sprintf("--build=%d", setup), sprintf("--years=%d", YRS),
                   "--iterations=1", "--replace", sprintf("--name=Fire maps (%s)", m$key)))), stdout = TRUE, stderr = TRUE)
    pid <- as.integer(tail(out[!grepl("Warning|undetermined|^In ssimLibrary", out)], 1)); if (is.na(pid)) { cat(out, sep = "\n"); stop("new-projection.R failed") }
    S <- scenario(L, pid); saveDatasheet(S, m$fo, "lucasCore_FireOptions")
    os <- as.data.frame(datasheet(S, "stsim_OutputOptionsSpatial")); os$RasterOutputTR <- TRUE; os$RasterOutputTRTimesteps <- 1L
    saveDatasheet(S, os[, setdiff(names(os), c("OutputOptionsSpatialId", "ScenarioId")), drop = FALSE], "stsim_OutputOptionsSpatial")
    saveDatasheet(S, data.frame(TransitionGroupId = c("Fire", SEV), Summary = TRUE, Spatial = c(TRUE, NA, NA, NA)), "stsim_OutputFilterTransitionGroups")
    t0 <- Sys.time(); R <- run(S); cat(sprintf("%s took %.1f min (result %d)\n", m$label, as.numeric(Sys.time() - t0, units = "mins"), scenarioId(R)))
    data.table(id = m$key, label = m$label, result = scenarioId(R)) }))
  fwrite(ids, file.path(OUT, "projections.csv"))
} else { ids <- fread(file.path(OUT, "projections.csv"))
  if (!"result" %in% names(ids)) { sc <- as.data.table(scenario(L, summary = TRUE)); ids[, result := vapply(parent, function(p) max(sc[IsResult == "Yes" & ParentId == p, ScenarioId]), 0L)] } }

# ---- maps ---------------------------------------------------------------------------------------------------------------
# ST-Sim maps a simulation group (Fire), not the severity types inside it; each burned cell holds its transition type's Id
tg <- as.data.table(datasheet(rsyncrosim::project(L, "Definitions"), "stsim_TransitionGroup", includeKey = TRUE))
tt <- as.data.table(datasheet(rsyncrosim::project(L, "Definitions"), "stsim_TransitionType", includeKey = TRUE))
fire_gid <- tg[Name == "Fire", TransitionGroupId]
sev_of_id <- setNames(c(Low = 1L, Medium = 2L, High = 3L)[sub("Fire: (.*) Severity", "\\1", tt[startsWith(Name, "Fire:"), Name])], tt[startsWith(Name, "Fire:"), Id])
fire_map <- function(rid, y) { p <- Sys.glob(file.path(paste0(f, ".data"), sprintf("Scenario-%d", rid), "stsim_OutputSpatialTransition", sprintf("tg_%d.it1.ts%d.tif", fire_gid, y)))
  if (!length(p)) return(NULL); x <- rast(p[1]); v <- values(x, mat = FALSE); s <- unname(sev_of_id[as.character(v)])
  if (!any(!is.na(s))) return(NULL); setValues(x, s) }
# the input fire probability ST-Sim draws from: the fire group's map x the sum of its severity maps (stage 9's multipliers)
input_prob <- function(rid, y) { sm <- as.data.table(datasheet(scenario(L, rid), "stsim_TransitionSpatialMultiplier", lookupsAsFactors = FALSE))[Iteration %in% 1L & Timestep == y]
  gm <- sm[TransitionGroupId == "Fire", MultiplierFileName]; mm <- sm[startsWith(TransitionGroupId, "Fire:"), MultiplierFileName]
  if (!length(mm)) return(NULL); s <- Reduce(`+`, lapply(mm, rast)); if (length(gm)) s <- s * rast(gm[1]); s }
y0 <- 2023L; yrs <- (y0 + 1):(y0 + YRS)
P <- rast(Sys.glob(file.path(paste0(f, ".data"), sprintf("Scenario-%d", hist), "stsim_OutputSpatialState", "sc.it1.ts2023.tif"))[1])
dem <- rast("F:/lucas-master/Data Sources/DEM/LF2020_Elev_220_CONUS/Tif/LC20_Elev_220.tif")
d <- crop(dem, project(as.polygons(ext(P) + 3000, crs = crs(P)), crs(dem)), snap = "out"); d <- aggregate(d, 3, "mean")
hs <- project(shade(terrain(d, "slope", unit = "radians"), terrain(d, "aspect", unit = "radians"), 40, 315), crs(P))
co <- st_read("F:/lucas-master/Data Sources/Study Areas/Counties/tl_rd22_us_county.shp", quiet = TRUE); co <- st_transform(co[co$GEOID == "06061", ], crs(P))
fp_src <- "F:/lucas-master/Data Sources/NIFS/InterAgencyFirePerimeterHistory_All_Years_View/InterAgencyFirePerimeterHistory_All_Years_View.shp"
fp <- st_read(fp_src, query = sprintf("SELECT FIRE_YEAR_, INCIDENT, FEATURE_CA FROM \"%s\" WHERE FIRE_YEAR_ >= 2014 AND FIRE_YEAR_ <= 2023", tools::file_path_sans_ext(basename(fp_src))), quiet = TRUE)
fp <- fp[fp$FEATURE_CA %in% c("Wildfire", "Wildfire Final Fire Perimeter", "Wildfire for Resource Benefit"), ]
fp <- st_intersection(st_make_valid(st_transform(fp, crs(P))), st_geometry(co))
COL <- c("#f2c14e", "#e07a1f", "#a1170f")   # low, medium, high
area_ha <- function(r) if (is.null(r)) 0 else global(!is.na(r), "sum")[[1]] * prod(res(r)) / 1e4

stack_fire <- lapply(ids$result, function(rid) lapply(yrs, function(y) fire_map(rid, y)))
tot <- sapply(stack_fire, function(s) sapply(s, area_ha))   # years x methods (ha)
prob <- lapply(ids$result, function(rid) { p <- lapply(yrs, function(y) input_prob(rid, y)); p <- p[!vapply(p, is.null, TRUE)]; if (length(p)) Reduce(`+`, p) / length(yrs) else NULL })
pmax_all <- max(vapply(prob, function(p) if (is.null(p)) 0 else global(p, "max", na.rm = TRUE)[[1]], 0)); pcol <- hcl.colors(50, "Inferno", rev = TRUE)
png(file.path(OUT, "placer-fire-maps.png"), width = 3000, height = 600 * (nrow(ids) + 1), res = 150)
par(mfrow = c(nrow(ids) + 1, 5), mar = c(0.5, 0.5, 2.2, 0.5), oma = c(2.5, 0, 2, 0))
base <- function(main) { plot(hs, col = grey.colors(100, 0.35, 0.95), legend = FALSE, axes = FALSE, box = FALSE, main = main, cex.main = 1.05, mar = NA)
  plot(st_geometry(co), add = TRUE, border = "grey15", lwd = 1.2) }
for (i in seq_len(nrow(ids))) {
  s <- stack_fire[[i]]; all <- NULL; for (r in s) if (!is.null(r)) all <- if (is.null(all)) r else cover(max(all, r, na.rm = TRUE), all)
  base(sprintf("%s\n%d-%d: %s ha burned", ids$label[i], min(yrs), max(yrs), format(round(sum(tot[, i])), big.mark = ",")))
  if (!is.null(all)) plot(all, col = COL, breaks = c(0.5, 1.5, 2.5, 3.5), legend = FALSE, add = TRUE)
  top <- order(-tot[, i])[1:3]
  for (j in top) { base(sprintf("%d: %s ha", yrs[j], format(round(tot[j, i]), big.mark = ","))); if (!is.null(s[[j]])) plot(s[[j]], col = COL, breaks = c(0.5, 1.5, 2.5, 3.5), legend = FALSE, add = TRUE) }
  base(sprintf("Mean input fire probability %d-%d\n(stage 9 maps; max %.3f/yr)", min(yrs), max(yrs), if (is.null(prob[[i]])) 0 else global(prob[[i]], "max", na.rm = TRUE)[[1]]))
  if (!is.null(prob[[i]])) plot(ifel(prob[[i]] > 0, prob[[i]], NA), col = pcol, range = c(0, pmax_all), legend = i == 1, add = TRUE, plg = list(title = "per yr"))
}
# the real record: interagency perimeters 2014-2023 in Placer, coloured by year
base(sprintf("Fire record 2014-2023 (interagency perimeters)\n%s ha burned in Placer", format(round(sum(as.numeric(st_area(fp))) / 1e4), big.mark = ",")))
yc <- hcl.colors(10, "YlOrRd", rev = TRUE); plot(st_geometry(fp), col = adjustcolor(yc[fp$FIRE_YEAR_ - 2013], 0.85), border = NA, add = TRUE)
plot.new(); legend("center", c("Low", "Medium", "High"), fill = COL, title = "Modeled severity", bty = "n", cex = 1.3)
plot.new(); legend("center", as.character(2014:2023), fill = yc, title = "Perimeter year", bty = "n", cex = 1.1, ncol = 2)
plot.new(); text(0.5, 0.5, sprintf("Placer County, 1 km model cells\nProjection %d-%d, 1 iteration each\nhillshade: LANDFIRE 2020 DEM", min(yrs), max(yrs)), cex = 1.2)
plot.new()
mtext("Modeled fire in the Placer projections: burned 1 km cells by severity (all years, then the three biggest years)", outer = TRUE, line = 0.3, cex = 1.2)
dev.off()
print(data.table(Year = yrs, round(tot)) |> setnames(c("Year", ids$id)))
cat("figure:", file.path(OUT, "placer-fire-maps.png"), "\n")
