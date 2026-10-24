# =============================================================================
# 02-multiscenario.R - ST-Sim jobs under library multiprocessing: multi-scenario vs iteration jobs
# =============================================================================
# Uses the ST-Sim-only test scenarios of 01-isolate.R (88 base, 94 no_filter: 3 projection years on projection result 85).
#   A  EnableMultiScenario on, scenario 88 alone
#   B  EnableMultiScenario on, scenarios 88 and 94 together (one console call)
#   C  multiprocessing on, multi-scenario off, scenario 88 with 2 iterations (jobs by iteration)
# Prints each case's outcome and the failure lines. Leaves multiprocessing off afterwards.
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- ssimLibrary(f); CON <- "C:/Program Files/SyncroSim/SyncroSim.Console.exe"
mp <- function(on, jobs, multi) saveDatasheet(L, data.frame(EnableMultiprocessing = on, MaximumJobs = as.integer(jobs), EnableMultiScenario = multi), "core_Multiprocessing")
on.exit(mp(FALSE, 1, FALSE))
logl <- function(id) trimws(strsplit(paste(runLog(scenario(L, id)), collapse = "\n"), "\n")[[1]])
latest <- function(p) { s <- as.data.table(scenario(L, summary = TRUE)); max(s[IsResult == "Yes" & ParentId == p, ScenarioId]) }
show <- function(case, ids) for (p in ids) { r <- latest(p); lg <- logl(r); bad <- any(grepl("\\[Failure\\]", lg))
  cat(sprintf("%s: scenario %d -> result %d %s%s\n", case, p, r, if (bad) "FAILS" else "RUNS", if (any(grepl("creating jobs", lg))) " (ran as jobs)" else " (not split into jobs)"))
  if (bad) cat(unique(lg[grepl("Failure|xception|rror", lg)])[1:6], sep = "\n") }
run_console <- function(ids) { t0 <- Sys.time(); out <- system2(shQuote(CON), c("--run", sprintf("--lib=%s", shQuote(f)), sprintf("--sids=%s", paste(ids, collapse = ","))), stdout = TRUE, stderr = TRUE)
  cat(sprintf("  console %.1f min; %s\n", as.numeric(Sys.time() - t0, units = "mins"), paste(grep("fail", out, value = TRUE, ignore.case = TRUE), collapse = " | "))) }
mp(TRUE, 3, TRUE); run_console(88); show("A multi-scenario, one", 88)
run_console(c(88, 94)); show("B multi-scenario, two", c(88, 94))
mp(TRUE, 2, FALSE)
S <- scenario(L, 88); rc <- as.data.frame(datasheet(S, "stsim_RunControl")); rc$MaximumIteration <- 2L
saveDatasheet(S, rc[, setdiff(names(rc), c("RunControlId", "ScenarioId")), drop = FALSE], "stsim_RunControl")
run_console(88); show("C iteration jobs, 2 iterations", 88)
rc$MaximumIteration <- 1L; saveDatasheet(S, rc[, setdiff(names(rc), c("RunControlId", "ScenarioId")), drop = FALSE], "stsim_RunControl")
