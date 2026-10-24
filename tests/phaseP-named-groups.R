# =============================================================================
# phaseP-named-groups.R - named-group targets: one area per named group, the type mix from the spatial allocation (or historical shares)
# =============================================================================
# On the phaseO library (dev/libs/lucasCore-suitability.ssim: Build result 5, historical run 7), two Fitted Projection Setups - Historical
# Type Shares off (the default) and on - and a --years projection from each, without rerunning the history. Prints the projection
# targets per group, and each member type's share of its named group's projected area beside its historical share.
# Usage: Rscript tests/phaseP-named-groups.R [--build=5] [--historical=7] [--years=10]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; RS <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
bid <- as.integer(opt("build", 5)); hid <- as.integer(opt("historical", 7)); YRS <- opt("years", "10")
L <- ssimLibrary(f)
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE))
runit <- function(id) { t0 <- Sys.time(); R <- tryCatch(run(scenario(L, id)), error = function(e) NULL)
  if (is.null(R)) { r <- as.data.table(scenario(L, summary = TRUE))[IsResult == "Yes" & ParentId == id]; if (nrow(r)) cat(tail(logl(scenario(L, max(r$ScenarioId))), 50), sep = "\n"); stop("run failed: ", id) }
  cat(sprintf("%s took %.1f min (result %d)\n", name(scenario(L, id)), as.numeric(Sys.time() - t0, units = "mins"), scenarioId(R))); R }
tool <- function(script, args) { out <- system2(RS, c(file.path("F:/lucasCore/tools", script), shQuote(f), shQuote(args)), stdout = TRUE, stderr = TRUE)
  out <- out[!grepl("Warning|undetermined|^In ssimLibrary", out)]; cat(out, sep = "\n"); id <- as.integer(tail(out, 1)); if (is.na(id)) stop(script, " failed"); id }

ttg <- as.data.table(datasheet(rsyncrosim::project(L, "Definitions"), "stsim_TransitionTypeGroup", lookupsAsFactors = FALSE))
named <- c("Urbanization", "Intensification", "Ag Expansion", "Ag Contraction")
type_of <- function(g) sub(" [Type]", "", g, fixed = TRUE)
mix <- function(tr, lab) { tr <- tr[endsWith(TransitionGroupId, " [Type]"), .(Area = sum(Amount)), by = .(Type = type_of(TransitionGroupId))]
  tr[, Group := ttg[TransitionGroupId %in% named][match(Type, TransitionTypeId), TransitionGroupId]]
  tr[!is.na(Group)][, .(Type, Share = Area / sum(Area), Area), by = Group][, Run := lab][] }
H <- scenario(L, hid); hy <- range(ds(H, "stsim_OutputStratumTransition")$Timestep)
hist <- mix(ds(H, "stsim_OutputStratumTransition"), "historical")

out <- list(hist)
for (sh in c(FALSE, TRUE)) { lab <- if (sh) "shares on" else "shares off"
  sid <- tool("new-projection-setup.R", c(sprintf("--build=%d", bid), "--method=Fitted", sprintf("--name=Projection Setup (named, %s)", lab), "--replace",
                                          "--region=Pyrome: P26 Northern Sierra Nevada"))
  S <- scenario(L, sid); po <- as.data.frame(datasheet(S, "lucasCore_ProjectionOptions")); po[1, "HistoricalTypeShares"] <- sh; po[1, "Iterations"] <- 2L
  saveDatasheet(S, po, "lucasCore_ProjectionOptions")
  RS1 <- runit(sid); lg <- logl(RS1)
  cat(unique(lg[grepl("members|split|target by|rate by|Projection Allocation|Not Target|rror|FAIL", lg)]), sep = "\n")
  pid <- tool("new-projection.R", c(sprintf("--historical=%d", hid), "--stage9", sprintf("--build=%d", scenarioId(RS1)), sprintf("--years=%s", YRS), "--replace", sprintf("--name=Projection (named, %s)", lab)))
  RP <- runit(pid)
  tt <- ds(RP, "stsim_TransitionTarget"); y1 <- max(hy)
  cat("projection targets (mean per year, iteration 1):\n"); print(tt[Timestep > y1 & Iteration %in% 1L, .(MeanAmount = sum(Amount) / uniqueN(Timestep)), by = TransitionGroupId])
  out[[lab]] <- mix(ds(RP, "stsim_OutputStratumTransition")[Timestep > y1], lab) }
res <- dcast(rbindlist(out), Group + Type ~ Run, value.var = "Share")
cat(sprintf("\nmember type shares of each named group's area (historical %d-%d vs %s projection years, both iterations):\n", hy[1], hy[2], YRS)); print(res, digits = 2)
tot <- rbindlist(out)[, .(Area = sum(Area)), by = .(Group, Run)]; tot[Run == "historical", Area := Area / diff(hy)]; tot[Run != "historical", Area := Area / (as.integer(YRS) * 2)]
cat("\nmean area per year by named group (amount units):\n"); print(dcast(tot, Group ~ Run, value.var = "Area"), digits = 3)
cat("NAMED GROUPS DONE\n")
