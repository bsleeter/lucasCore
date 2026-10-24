# =============================================================================
# phaseN-mode2.R - mode 2: a historical run made once, then a short stand-alone projection that starts from it
# =============================================================================
# In dev/libs/lucasCore-projection.ssim (phaseM's library; Build result 4 has stage 9's projection rules): a historical-only run
# (tools/new-historical.R --historical-only --bookend-maps, 1 iteration; skipped with --historical=<id>), then tools/new-projection.R
# for --years years. Checks the carbon handed over at the historical end and compares each group's projected rate with the
# historical run's.
# Usage: Rscript tests/phaseN-mode2.R [--build=4] [--historical=<result id>] [--years=10]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-projection.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
bid <- as.integer(opt("build", 4)); hid <- as.integer(opt("historical", NA)); YRS <- opt("years", "10")
L <- ssimLibrary(f)
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
mins <- function(t0) as.numeric(Sys.time() - t0, units = "mins")
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
tool <- function(script, args) { out <- system2(RS, c(file.path("F:/lucasCore/tools", script), shQuote(f), args), stdout = TRUE, stderr = TRUE)
  out <- out[!grepl("Warning|undetermined|^In ssimLibrary", out)]; cat(out, sep = "\n"); id <- as.integer(tail(out, 1)); if (is.na(id)) stop(script, " failed"); id }
runit <- function(id) { t0 <- Sys.time(); R <- tryCatch(run(scenario(L, id)), error = function(e) NULL)
  if (is.null(R)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & ParentId == id]; if (nrow(r)) cat(tail(logl(scenario(L, max(r$ScenarioId))), 50), sep = "\n"); stop("run failed") }
  cat(sprintf("%s took %.1f min (result %d)\n", name(scenario(L, id)), mins(t0), scenarioId(R))); R }

if (is.na(hid)) { RH <- runit(tool("new-historical.R", c(sprintf("--build=%d", bid), "--historical-only", "--bookend-maps", "--iterations=1", "--replace"))); hid <- scenarioId(RH)
} else RH <- scenario(L, hid)
RP <- runit(tool("new-projection.R", c(sprintf("--historical=%d", hid), "--stage9", sprintf("--build=%d", bid), sprintf("--years=%s", YRS), "--replace")))
lg <- logl(RP); cat(unique(lg[grepl("Projection Start|target by|rate by|Projection inputs|FAIL|rror", lg)]), sep = "\n")

# the hand-over: stocks in the historical end year, historical run vs the projection's first timestep
yh <- max(ds(RH, "stsim_OutputStock")$Timestep)
sk <- function(R) ds(R, "stsim_OutputStock")[Timestep == yh & StockGroupId %in% c("Biomass: Total", "DOM: Total", "Total Ecosystem"), .(Tg = sum(Amount) / 1e6 / max(Iteration)), by = StockGroupId]
hand <- merge(sk(RH)[, .(StockGroupId, Historical = Tg)], sk(RP)[, .(StockGroupId, Projection = Tg)], by = "StockGroupId")
cat(sprintf("\ncarbon in %d, historical run vs projection start (Tg):\n", yh)); print(hand[, Diff := Projection - Historical][])

# rates: each group's mean annual area, historical run vs projection
rate <- function(R, yrs) { t <- ds(R, "stsim_OutputStratumTransition"); n <- max(t$Iteration)
  t[Timestep %in% yrs, .(km2 = sum(Amount) / 100 / n / length(yrs)), by = TransitionGroupId] }
py <- (yh + 1):max(ds(RP, "stsim_OutputStock")$Timestep)
cmp <- merge(rate(RH, 1986:yh)[, .(TransitionGroupId, Historical = km2)], rate(RP, py)[, .(TransitionGroupId, Projected = km2)], by = "TransitionGroupId", all = TRUE)
for (k in c("Historical", "Projected")) cmp[is.na(get(k)), (k) := 0]
top <- c("Urbanization", "Intensification", "Ag Expansion", "Ag Contraction", "Forest Harvest", "Fire")
cat(sprintf("\nmean annual area (km2/yr): historical run 1986-%d vs projection %d-%d\n", yh, min(py), max(py))); print(cmp[TransitionGroupId %in% top][, Ratio := round(Projected / Historical, 2)][])
tot <- ds(RP, "stsim_OutputStock")[StockGroupId == "Total Ecosystem", .(Tg = sum(Amount) / 1e6), by = .(Iteration, Timestep)]
cat("\nTotal Ecosystem carbon in the projection (Tg):\n"); print(dcast(tot, Timestep ~ Iteration, value.var = "Tg"))
saveRDS(list(hand = hand, cmp = cmp, hist = hid, proj = scenarioId(RP)), "F:/lucasCore/dev/libs/test-mode2.rds")
cat("MODE 2 DONE historical", hid, "projection", scenarioId(RP), "\n")
