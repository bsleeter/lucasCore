# =============================================================================
# phaseZ30-wood-products.R - stage 18 (src/18-wood-products.R) on a library's runs, outside SyncroSim (to-do 59, step 3)
# =============================================================================
# Runs the stage script itself with SyncroSim's calls replaced: the options sheet comes from this script, the output sheets are kept
# in memory, and the library is only read (by SQL, read-only). So it needs no package install and changes nothing in the library.
# Default: dev/libs/lucasCore-projection.ssim, its historical run 10 and the projection 12 made from it (2 iterations).
# Checks: every stage check passes for both runs; the projection is joined to its history; the two share the history's years exactly
# (same draws); 0 draws gives the published values; a Region option overrides the strata; a bad Region and a bad share stop the stage.
# Usage: Rscript tests/phaseZ30-wood-products.R [library.ssim history_id projection_id]   (from the package folder)
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(DBI); library(RSQLite) })
pkg <- normalizePath(".", winslash = "/")
a <- commandArgs(TRUE)
lib <- if (length(a) >= 1) a[1] else file.path(dirname(dirname(dirname(pkg))), "dev", "libs", "lucasCore-projection.ssim")
if (!file.exists(lib)) lib <- file.path(pkg, "dev", "libs", "lucasCore-projection.ssim")
if (!file.exists(lib)) stop("no library: give its path (dev/libs/lucasCore-projection.ssim by default)")
HID <- if (length(a) >= 2) as.integer(a[2]) else 10L; PID <- if (length(a) >= 3) as.integer(a[3]) else 12L
n_ok <- 0; n_bad <- 0
expect <- function(what, ok, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(ok)) "PASS" else "FAIL", what, detail)); if (isTRUE(ok)) n_ok <<- n_ok + 1 else n_bad <<- n_bad + 1 }

# run the stage script with stubs for SyncroSim (tests/wood-products-stage-stub.R); returns the sheets it wrote, its log and its checks (or the error)
source(file.path(pkg, "tests", "wood-products-stage-stub.R"))
stage <- function(options) stage_18(pkg, lib, options)

t0 <- Sys.time()
H <- stage(data.frame(RunScenarioId = HID, Draws = 20L))
Pj <- stage(data.frame(RunScenarioId = PID, Draws = 20L))
cat(sprintf("two stage runs: %.1f s\n", as.numeric(Sys.time() - t0, units = "secs")))
for (r in list(list("history", H), list("projection", Pj))) { x <- r[[2]]
  expect(sprintf("the stage runs (%s)", r[[1]]), is.null(x$error), x$error %||% "")
  if (!is.null(x$error)) next
  cat(paste0("   ", grep("^Run |^Carbon to|^By Smith|^Model|^Spin-up|^Forest types|^[0-9]{4}: ", x$log, value = TRUE)), sep = "\n")
  expect(sprintf("every check passes (%s)", r[[1]]), nrow(x$checks) > 0 && all(x$checks$Status == "Pass"), paste(x$checks[Status != "Pass", paste(Check, Detail)], collapse = "; "))
  expect(sprintf("output sheets written (%s)", r[[1]]), all(c("OutputWoodProducts", "OutputWoodProductsEndUse", "OutputWoodProductsScale", "OutputWoodProductsFigure") %in% names(x$sheets)))
  expect(sprintf("figure files exist (%s)", r[[1]]), all(file.exists(x$sheets$OutputWoodProductsFigure$FileName))) }
`%||%` <- function(a, b) if (is.null(a)) b else a
if (is.null(H$error) && is.null(Pj$error)) {
  expect("the projection is joined to its historical run", any(grepl(sprintf("joined to historical run %d", HID), Pj$log)))
  w <- function(x, v, y) x$sheets$OutputWoodProducts[is.na(Iteration) & Variable == v & Year <= y][order(Year)]
  ys <- max(H$sheets$OutputWoodProducts$Year)
  a1 <- w(H, "Stored", ys); a2 <- w(Pj, "Stored", ys)
  expect("the projection shares its history's years exactly (stored carbon to the history's end)", nrow(a1) == nrow(a2) && max(abs(a1$Mean - a2$Mean)) < 1e-6 * max(a1$Mean),
         sprintf("%d years, largest difference %.2g Mg C", nrow(a1), max(abs(a1$Mean - a2$Mean))))
  expect("the projection runs past the history", max(Pj$sheets$OutputWoodProducts$Year) > ys)
}
Z <- stage(data.frame(RunScenarioId = HID, Draws = 0L))
expect("0 draws: the published values, a zero-width interval", is.null(Z$error) && Z$sheets$OutputWoodProducts[Variable == "Stored", max(Upper - Lower)] < 1e-9)
own <- sub("^By Smith region: ([A-Z]+) .*$", "\\1", grep("^By Smith region", Z$log, value = TRUE)[1]); alt <- if (identical(own, "SE")) "NE" else "SE"
R <- stage(data.frame(RunScenarioId = HID, Draws = 0L, Region = alt))
expect("a Region option overrides the strata", is.null(R$error) && any(grepl(paste0("^By Smith region: ", alt), R$log)) &&
       R$sheets$OutputWoodProducts[is.na(Iteration) & Variable == "Stored" & Year == ys, Mean] != Z$sheets$OutputWoodProducts[is.na(Iteration) & Variable == "Stored" & Year == ys, Mean])
B <- stage(data.frame(RunScenarioId = HID, Region = "XX"))
expect("a bad Region stops the stage, naming the choices", !is.null(B$error) && grepl("not one of", B$error), B$error %||% "")
B2 <- stage(data.frame(RunScenarioId = HID, LandClearingUtilized = 1.5))
expect("a land-clearing share above 1 stops the stage", !is.null(B2$error) && grepl("between 0 and 1", B2$error), B2$error %||% "")
N <- stage(data.frame(RunScenarioId = HID, Draws = 0L, Spinup = FALSE))
expect("spin-up off: the model starts with the run, storage higher than with the history decaying",
       is.null(N$error) && N$sheets$OutputWoodProducts[, min(Year)] >= 1985L && is.null(N$sheets$OutputWoodProductsScale))
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
