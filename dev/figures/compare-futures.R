# =============================================================================
# compare-futures.R - one chart set comparing projections that share a historical run: total ecosystem carbon, net primary
# productivity and net biome productivity per year, the history once and one line per future from the projection start. Read-only.
# A first version of the "compare futures" option for stage 13.
# Usage: Rscript dev/figures/compare-futures.R <library.ssim> <build result id> <out dir> <label=projection result id> ...
#   e.g. Rscript dev/figures/compare-futures.R "dev/libs/LUCAS P26 Demo Library.ssim" 2 out "Normal climate=19" "SSP2-4.5=27" "SSP5-8.5=28"
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra); library(sf); library(DBI); library(RSQLite) })
a <- commandArgs(TRUE); lib <- a[1]; bid <- as.integer(a[2]); out <- a[3]; runs <- a[-(1:3)]
lab <- sub("=.*$", "", runs); rid <- as.integer(sub("^.*=", "", runs))
source("F:/lucasCore/src/figures.R"); source("F:/lucasCore/src/run-figures.R")
con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
ic <- q("SELECT StateClassFileName FROM stsim_InitialConditionsSpatial WHERE ScenarioId = %d", bid)
grid <- rast(file.path(paste0(lib, ".data"), sprintf("Scenario-%d", bid), "stsim_InitialConditionsSpatial", basename(ic$StateClassFileName[1])))
dem <- q("SELECT ElevationFile FROM lucasCore_DataSource")$ElevationFile[1]; dbDisconnect(con)

P <- lapply(rid, function(r) load_run(lib, r)); hid <- unique(vapply(rid, function(r) find_history(lib, r), 1L))
if (length(hid) != 1 || is.na(hid)) stop("the projections must share one historical run")
H <- load_run(lib, hid); ys <- unique(vapply(P, function(p) p$years[1], 1)); if (length(ys) != 1 || H$years[2] != ys) stop("the projections must start where the history ends")
series <- function(X, what) { if (what == "te") { s <- X$stocks[StockGroup == "Total Ecosystem", .(v = sum(Mg) / 1e6), by = Timestep] }
  else { g <- c(npp = "Net Primary Productivity", nbp = "Net Biome Productivity")[what]; s <- X$flows[FlowGroup == g, .(v = sum(Mg) / 1e6), by = Timestep] }
  s[order(Timestep)] }
cols <- c("#55534c", "#3b6ea8", "#c93a1d", "#2b8152", "#7a76b8")[seq_along(rid)]
NOTE <- sprintf("P26 Northern Sierra Nevada; historical run %d, %d-%d (black), then %d projections, %d-%d (dashed line), one iteration each.", hid, H$years[1], ys, length(rid), ys + 1, P[[1]]$years[2])
K <- figure_kit(grid, dem, out, NOTE); use_kit(K, environment())
panel <- function(i, what, ylab, ttl) {
  h <- series(H, what); pp <- lapply(P, series, what = what)
  rng <- range(c(h$v, unlist(lapply(pp, `[[`, "v"))), na.rm = TRUE)
  plot(NA, xlim = c(H$years[1], P[[1]]$years[2]), ylim = rng + c(-.03, .03) * diff(rng), xlab = "", ylab = ylab, bty = "l"); hgrid()
  if (what == "nbp") abline(h = 0, col = MUTED, lty = 3)
  abline(v = ys, col = MUTED, lty = 2); lines(h$Timestep, h$v, lwd = 2, col = INK)
  for (k in seq_along(pp)) { s <- rbind(h[Timestep == ys], pp[[k]][Timestep > ys]); lines(s$Timestep, s$v, lwd = 2, col = cols[k]) }
  end <- vapply(pp, function(s) mean(s[Timestep > ys, v]), 1)
  ptitle(i, ttl); legend("topleft", sprintf("%s (%s %.2f)", lab, if (what == "te") "2050:" else "mean", if (what == "te") vapply(pp, function(s) s[.N, v], 1) else end),
                         col = cols, lwd = 2, bty = "n", cex = .75) }
chart_figure("compare_futures", "Climate futures compared",
  sprintf("(a) Total ecosystem carbon (Tg C), (b) net primary productivity and (c) net biome productivity (Tg C per year): the historical run to %d, then one line per projection. The projections share the Projection Setup (the same drawn land-use, harvest and fire years) and differ only in their climate flow multipliers.", ys),
  1, 3, h = 900, draw = function() { par(mar = c(4, 5, 3, 1))
    panel(1, "te", "Tg C", "Total ecosystem carbon"); panel(2, "npp", "Tg C per year", "Net primary productivity"); panel(3, "nbp", "Tg C per year", "Net biome productivity") })
for (k in seq_along(P)) { s <- series(P[[k]], "te"); n <- series(P[[k]], "npp"); b <- series(P[[k]], "nbp")
  cat(sprintf("%-16s carbon 2050 %.1f Tg C; NPP %d-%d mean %.2f Tg C/yr (sd %.2f); NBP mean %+.2f\n", lab[k], s[.N, v], ys + 1, P[[k]]$years[2],
              mean(n[Timestep > ys, v]), sd(n[Timestep > ys, v]), mean(b[Timestep > ys, v]))) }
cat("done:", out, "\n")
