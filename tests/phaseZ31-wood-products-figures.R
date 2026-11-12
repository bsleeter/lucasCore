# =============================================================================
# phaseZ31-wood-products-figures.R - Run Figures and Compare Runs with stage 18's wood products (to-do 59, step 4), outside SyncroSim
# =============================================================================
# Runs stage 18 on a historical run and its projection (tests/wood-products-stage-stub.R, read-only), then draws the run figures of the
# projection (joined to its history) and the comparison figures of the two with those results in place of the library's
# (wp_of_run stubbed: the projection has a result, the history none, so the history takes its projection's).
# Checks: wp_of_run reads a library with no Wood Products result as NULL; the run figures gain the wood products figure, and lose it
# without a result; NBP with products is NBP plus the change in stored carbon; the history borrows its projection's result and agrees
# with stage 18 on the history alone; the comparison draws the wood products figure and its summary columns.
# Usage: Rscript tests/phaseZ31-wood-products-figures.R [library.ssim history_id projection_id build_id]   (from the package folder)
# Default: dev/libs/lucasCore-projection.ssim, historical run 10, projection 12, Build result 4.
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra); library(sf); library(DBI); library(RSQLite) })
pkg <- normalizePath(".", winslash = "/")
a <- commandArgs(TRUE)
lib <- if (length(a) >= 1) a[1] else file.path(dirname(dirname(dirname(pkg))), "dev", "libs", "lucasCore-projection.ssim")
if (!file.exists(lib)) lib <- file.path(pkg, "dev", "libs", "lucasCore-projection.ssim")
if (!file.exists(lib)) stop("no library: give its path (dev/libs/lucasCore-projection.ssim by default)")
HID <- if (length(a) >= 2) as.integer(a[2]) else 10L; PID <- if (length(a) >= 3) as.integer(a[3]) else 12L; BID <- if (length(a) >= 4) as.integer(a[4]) else 4L
n_ok <- 0; n_bad <- 0
expect <- function(what, ok, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(ok)) "PASS" else "FAIL", what, detail)); if (isTRUE(ok)) n_ok <<- n_ok + 1 else n_bad <<- n_bad + 1 }
source(file.path(pkg, "tests", "wood-products-stage-stub.R"))
source(file.path(pkg, "src/figures.R")); source(file.path(pkg, "src/run-figures.R")); source(file.path(pkg, "src/compare-figures.R"))

expect("wp_of_run: a run stage 18 has not followed reads as NULL", is.null(wp_of_run(lib, PID)))
H <- stage_18(pkg, lib, data.frame(RunScenarioId = HID, Draws = 20L)); Pj <- stage_18(pkg, lib, data.frame(RunScenarioId = PID, Draws = 20L))
if (!is.null(H$error) || !is.null(Pj$error)) stop("stage 18 failed: ", H$error, Pj$error)
WH <- stage_18_wp(H, 901L); WP <- stage_18_wp(Pj, 902L)

con <- dbConnect(SQLite(), lib, flags = SQLITE_RO); q <- function(s, ...) as.data.table(dbGetQuery(con, sprintf(s, ...)))
ic <- q("SELECT StateClassFileName FROM stsim_InitialConditionsSpatial WHERE ScenarioId = %d", BID)
grid <- rast(file.path(paste0(lib, ".data"), sprintf("Scenario-%d", BID), "stsim_InitialConditionsSpatial", basename(ic$StateClassFileName[1])))
scl <- q("SELECT Name, Color FROM stsim_StateClass"); dbDisconnect(con)
cols <- setNames(argb(scl$Color), scl$Name)

# ---- Run Figures: the projection joined to its history --------------------------------------------------------------------------
X <- join_runs(load_run(lib, HID), load_run(lib, PID)); X$wp <- WP
keep <- Sys.getenv("WP_FIG_OUT")   # a folder to keep the figures in (to look at them); blank = temporary
out <- if (nzchar(keep)) file.path(keep, "run") else tempfile("rf"); res <- run_figures(X, grid, cols, NULL, "Test", NULL, out, run_name = "projection")
f <- res[grepl("wood_products", basename(FileName))]
expect("run figures: the wood products figure is drawn", nrow(f) == 1 && file.exists(f$FileName), paste(res$Title, collapse = "; "))
nb <- nbp_products(X); fl <- X$flows[FlowGroup == "Net Biome Productivity", .(NBP = sum(Mg) / 1e6), by = Timestep]; sc <- wp_tg(X, "StockChange")
m <- merge(merge(fl, sc, by = "Timestep"), nb[, .(Timestep, With = Tg)], by = "Timestep")
expect("NBP with products is NBP plus the change in stored carbon, every year", nrow(m) == X$years[2] - X$years[1] && max(abs(m$With - m$NBP - m$Tg)) < 1e-9,
       sprintf("%d years; mean NBP %+.3f, with products %+.3f Tg C/yr", nrow(m), mean(m$NBP), mean(m$With)))
ws <- wp_tg(X, "Stored"); s_end <- Pj$sheets$OutputWoodProducts[is.na(Iteration) & Variable == "Stored" & Year == X$years[2], Mean] / 1e6
expect("stored carbon in the figure's final year is stage 18's", abs(ws[Timestep == X$years[2], Tg] - s_end) < 1e-9, sprintf("%.3f Tg C in %d", s_end, X$years[2]))
expect("stored carbon is read over the run's years only (the spin-up left out)", min(ws$Timestep) == X$years[1] && max(ws$Timestep) == X$years[2])
X0 <- X; X0$wp <- NULL; res0 <- run_figures(X0, grid, cols, NULL, "Test", NULL, tempfile("rf0"), run_name = "projection")
expect("run figures: no result, no wood products figure (the others unchanged)", !any(grepl("wood_products", basename(res0$FileName))) && nrow(res0) == nrow(res) - 1)

# ---- Compare Runs: the projection has a result, its history none ---------------------------------------------------------------
wp_of_run <- function(lib, rid) if (rid == PID) WP else NULL
R <- compare_runs(lib, data.table(RunScenarioId = PID))
hr <- Filter(function(r) r$hist, R)[[1]]; pr <- Filter(function(r) !r$hist, R)[[1]]
expect("compare: the history takes its projection's wood products", !is.null(hr$X$wp) && identical(attr(hr$X$wp, "scenario"), 902L))
ca <- compare_carbon(R); hh <- ca[Role == "History"]; pp <- ca[Role != "History"]
own <- H$sheets$OutputWoodProducts[is.na(Iteration) & Variable == "StockChange" & Year > hr$X$years[1] & Year <= hr$X$years[2], mean(Mean) / 1e6]
expect("compare: the history's mean change in stored carbon is stage 18's on the history alone", abs(hh$HwpStockChange - own) < 1e-6 * max(1, abs(own)),
       sprintf("%+.4f vs %+.4f Tg C/yr", hh$HwpStockChange, own))
expect("compare: NBP with products = NBP + the change in stored carbon (each run)", all(abs(ca$NbpWithProducts - ca$NBP - ca$HwpStockChange) < 1e-9),
       paste(sprintf("%s: %+.3f + %+.3f = %+.3f", ca$Role, ca$NBP, ca$HwpStockChange, ca$NbpWithProducts), collapse = "; "))
expect("compare: stored carbon at the projection's end is stage 18's", abs(pp$HwpStored - s_end) < 1e-9)
cres <- compare_figures(R, grid, NULL, "Test", if (nzchar(keep)) file.path(keep, "compare") else tempfile("cf"))
expect("compare: the wood products figure and the summary table are drawn", any(grepl("wood_products", basename(cres$FileName))) && any(grepl("carbon_summary", basename(cres$FileName))) &&
       all(file.exists(cres$FileName)), paste(cres$Title, collapse = "; "))
wp_of_run <- function(lib, rid) NULL; R0 <- compare_runs(lib, data.table(RunScenarioId = PID)); c0 <- compare_figures(R0, grid, NULL, "Test", tempfile("cf0"))
expect("compare: no results, no wood products figure, the columns blank", !any(grepl("wood_products", basename(c0$FileName))) && all(is.na(attr(c0, "carbon")$NbpWithProducts)))
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
