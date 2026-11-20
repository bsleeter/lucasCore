# =============================================================================
# phaseZ33-build-resume.R - a Build run again copies the stages that would give the same result (src/resume.R), in a real library
# =============================================================================
# On a copy of the library's Build scenario ("Resume test: Build", cell size --resolution, one job, pipeline = --stages):
#   A. the first run: every stage runs and leaves a record (Build Results > Build Stages)
#   B. run again, nothing changed: every stage is reused from A, and every table the stages wrote is the same in B as in A
#      (rows by checksum, files by content)
#   C. Stand Age: FIA Plots, fewest plots changed (only stage 5 reads it; with the matching off it changes nothing stage 5 writes):
#      stages before 5 are reused, stage 5 runs, and the stages after it are reused when stage 5 wrote what it wrote before
#   D. Build Stage Reuse: Rebuild Every Stage = Yes: every stage runs (only with --rebuild, or a pipeline of at most two stages)
#   E. Data Sources: a path that is not there for a dataset only stage 6 reads: the Build stops at stage 6, the stages before it
#      reused; F. the path put right: the stages before 6 are reused from the failed result, stage 6 onward from the last whole Build
# Usage: Rscript tests/phaseZ33-build-resume.R <library.ssim> [--resolution=600] [--stages=0,1,5,2,3,4,6,7,8] [--rebuild]
# A scratch copy of a library only: it adds a scenario and results. --stages=0,1 is the quick form (minutes).
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tests/phaseZ33-build-resume.R <library.ssim> [--resolution=600] [--stages=0,1,...] [--rebuild]")
f <- normalizePath(pos[1], winslash = "/"); L <- suppressWarnings(ssimLibrary(f)); P <- rsyncrosim::project(L, "Definitions")
.rs <- new.env(); .rs$md5 <- new.env(); source(file.path(pkg, "src", "resume.R"))   # rs_hash: the checksum the stages use
ok <- 0; bad <- 0
expect <- function(what, cond) { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, "\n") } }
ds <- function(R, s) as.data.table(datasheet(R, s, lookupsAsFactors = FALSE, optional = TRUE))
sc <- function() as.data.table(scenario(L, summary = TRUE)); mins <- function(t0) as.numeric(Sys.time() - t0, units = "mins")
logl <- function(R) trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]])
stg <- trimws(strsplit(opt("stages", "0,1,5,2,3,4,6,7,8"), ",")[[1]])

src <- sc()[Name == "Build" & IsResult == "No", ScenarioId]; if (length(src) != 1) stop("the library needs one Build scenario")
nm <- "Resume test: Build"; for (i in sc()[Name == nm & IsResult == "No", ScenarioId]) delete(L, scenario = i, force = TRUE)
S <- rsyncrosim::scenario(P, nm, sourceScenario = src)
description(S) <- sprintf("tests/phaseZ33-build-resume.R: a coarse copy of the Build (stages %s), run several times to check that unchanged stages are reused.", paste(stg, collapse = ", "))
bo <- as.data.frame(datasheet(S, "lucasCore_BuildOptions", lookupsAsFactors = FALSE)); bo$Resolution <- as.integer(opt("resolution", 600)); bo$SpatialTiles <- 1L; saveDatasheet(S, bo, "lucasCore_BuildOptions")
names_all <- levels(datasheet(S, "core_Pipeline", lookupsAsFactors = TRUE, optional = TRUE)$StageNameId)
pick <- vapply(stg, function(k) { m <- grep(sprintf("^%s - ", k), names_all, value = TRUE); if (length(m) != 1) stop(sprintf("--stages: no single stage numbered %s", k)); m }, "")
saveDatasheet(S, data.frame(StageNameId = pick, RunOrder = seq_along(pick)), "core_Pipeline")
saveDatasheet(S, data.frame(Rebuild = "No"), "lucasCore_BuildReuse")
go <- function(what) { t0 <- Sys.time(); R <- tryCatch(run(S), error = function(e) { cat(what, "FAILED:", conditionMessage(e), "\n"); NULL })
  if (is.null(R)) { r <- sc()[IsResult == "Yes"]; cat(tail(logl(scenario(L, max(r$ScenarioId))), 30), sep = "\n"); stop(what, " failed") }
  st <- ds(R, "lucasCore_OutputBuildStage"); cat(sprintf("\n%s: result %d, %.1f min\n", what, scenarioId(R), mins(t0))); print(st[, .(Stage, Status, Minutes)], row.names = FALSE)
  v <- ds(R, "lucasCore_OutputValidation"); list(R = R, id = scenarioId(R), st = st, min = mins(t0), v = v) }
num <- function(st) sub(" .*", "", st$Stage)

# A. the first run
A <- go("A, first run")
expect("A: every stage ran and left a record", nrow(A$st) == length(stg) && all(A$st$Status == "Ran") && all(file.exists(A$st$RecordFileName)) && setequal(num(A$st), stg))
expect("A: no validation check failed", nrow(A$v) > 0 && all(A$v$Status == "Pass"))

# B. again, nothing changed
B <- go("B, nothing changed")
expect("B: every stage is reused from A", nrow(B$st) == length(stg) && all(B$st$Status == sprintf("Reused from result %d", A$id)))
expect("B: the log says so for every stage", sum(grepl(": not run again. Result ", logl(B$R), fixed = TRUE)) == length(stg))
sheets <- unique(unlist(lapply(A$st$RecordFileName, function(p) vapply(readRDS(p)$writes, function(w) w$name, ""))))
same <- vapply(sheets, function(s) identical(rs_hash(ds(A$R, s), s), rs_hash(ds(B$R, s), s)), TRUE)
expect(sprintf("B: each of the %d tables the stages wrote is the same in B as in A (files by content)", length(sheets)), length(sheets) > 0 && all(same))
if (!all(same)) cat("  differ:", paste(sheets[!same], collapse = ", "), "\n")
expect("B: the validation table is whole", nrow(B$v) == nrow(A$v) && all(B$v$Status == "Pass"))
if (length(stg) > 2) expect("B: far faster than A", B$min < 0.5 * A$min)   # (a copied stage still costs about a minute: SyncroSim starts it, it checks and writes)
cat(sprintf("  A %.1f min, B %.1f min\n", A$min, B$min))
# the checks read the library file, not a SyncroSim process a table ("... N tables read from the library file, M through SyncroSim")
cp <- regmatches(logl(B$R), regexec("([0-9]+) tables read from the library file, ([0-9]+) through SyncroSim", logl(B$R))); cp <- do.call(rbind, cp[lengths(cp) == 3])
nf <- sum(as.integer(cp[, 2])); ns <- sum(as.integer(cp[, 3])); cat(sprintf("  B: %d tables checked in the library file, %d through SyncroSim\n", nf, ns))
expect("B: at least nine in ten of the tables are checked in the library file", nrow(cp) == length(stg) && nf >= 9 * ns)

# C. a setting only stage 5 reads
if ("5" %in% stg) {
  fia <- as.data.frame(datasheet(S, "lucasCore_StandAgeFia", lookupsAsFactors = FALSE, optional = TRUE)); on <- nrow(fia) && isTRUE(startsWith(as.character(fia$FiaMatch[1]), "Yes"))
  saveDatasheet(S, data.frame(FiaMatch = if (on) "Yes" else "No", MinPlots = if (nrow(fia) && !is.na(fia$MinPlots[1]) && fia$MinPlots[1] == 25L) 26L else 25L), "lucasCore_StandAgeFia")
  C <- go("C, Stand Age: FIA Plots changed"); k5 <- match("5", stg); st <- setNames(C$st$Status, num(C$st))
  expect("C: stage 5 ran", st[["5"]] == "Ran")
  expect("C: the stages before stage 5 are reused", all(startsWith(st[stg[seq_len(k5 - 1)]], "Reused from result")))
  if (!on && k5 < length(stg)) expect("C: matching off, so stage 5 wrote what it wrote before and the stages after it are reused", all(startsWith(st[stg[(k5 + 1):length(stg)]], "Reused from result")))
  expect("C: no validation check failed", nrow(C$v) == nrow(A$v) && all(C$v$Status == "Pass")) }

# D. rebuild every stage
if ("--rebuild" %in% a || length(stg) <= 2) {
  saveDatasheet(S, data.frame(Rebuild = "Yes"), "lucasCore_BuildReuse")
  D <- go("D, Rebuild Every Stage")
  expect("D: every stage ran", nrow(D$st) == length(stg) && all(D$st$Status == "Ran"))
  expect("D: the log says no earlier result is looked at", sum(grepl("Rebuild every stage is on", logl(D$R), fixed = TRUE)) == length(stg)) }

# E. a Build that fails part way, and the run after the fix (what the reuse is for)
if ("6" %in% stg && match("6", stg) > 1) {
  k6 <- match("6", stg); before <- stg[seq_len(k6 - 1)]; last <- max(sc()[IsResult == "Yes", ScenarioId])
  src0 <- as.data.frame(datasheet(P, "lucasCore_DataSource", lookupsAsFactors = FALSE, optional = TRUE)); brk <- src0; brk$MtbsSeverityFolder <- "Z:/not/there"
  saveDatasheet(P, brk, "lucasCore_DataSource")
  t0 <- Sys.time(); invisible(tryCatch(run(S), error = function(e) NULL)); saveDatasheet(P, src0, "lucasCore_DataSource")
  e_id <- max(sc()[IsResult == "Yes", ScenarioId]); E <- scenario(L, e_id); st <- ds(E, "lucasCore_OutputBuildStage"); st <- setNames(st$Status, num(st))
  cat(sprintf("\nE, a wrong path for a dataset only stage 6 reads: result %d, %.1f min\n", e_id, mins(t0))); print(st)
  expect("E: a new result that stopped at stage 6", e_id > last && any(grepl("MtbsSeverityFolder not found", logl(E), fixed = TRUE)) && !"6" %in% names(st))
  expect("E: the stages before stage 6 were reused (the path is not theirs)", setequal(names(st), before) && all(startsWith(st, "Reused from result")))
  F <- go("F, the path put right"); st <- setNames(F$st$Status, num(F$st))
  expect("F: the stages before stage 6 are reused from the failed result", all(st[before] == sprintf("Reused from result %d", e_id)))
  expect("F: stage 6 and the stages after it are reused from the last whole Build", all(startsWith(st[stg[k6:length(stg)]], "Reused from result")) && !any(st[stg[k6:length(stg)]] == sprintf("Reused from result %d", e_id)))
  expect("F: no validation check failed", nrow(F$v) == nrow(A$v) && all(F$v$Status == "Pass")) }

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
