# =============================================================================
# quick-test.R - test a change without a full Build: rerun only the Build stages it touches, then a short historical run
# =============================================================================
# (user, 2026-11-07: in test libraries rerun only the stages a change touches, and run 5-10 historical years.) Makes
#   1. "Quick test: stages <s>": depends on a Build result, pipeline = only the given stages; it reads everything else from that
#      result (the result holds the Build's inputs and every stage's outputs). Its own outputs hide the result's, so a stage that
#      appends to a shared sheet carries the result's rows over first (stage 8: the Flow Spatial Multipliers; stage 11 does the same)
#   2. "Quick test: <N> years": tools/new-historical.R --build=<1's result> --also=<Stock-Flow Definitions>,<the Build result> --years=N
# and runs both, printing the result ids and minutes. Inputs come from the Build result as it ran: to test an option, change it in
# the Build scenario and use --options, which copies that scenario's options sheets into the quick test first.
# Usage: Rscript tools/quick-test.R <library.ssim> --stages=8[,3,...] [--build=<Build result id>] [--years=10] [--options] [--no-run]
#   --build    the Build result to start from (default: the newest result whose name starts with "Build")
#   --options  the Build scenario's current options sheets (its parent's), not the result's copies
#   --no-run   make the scenarios only
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tools/quick-test.R <library.ssim> --stages=8 [--build=<id>] [--years=10]")
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
lib <- normalizePath(pos[1], winslash = "/"); L <- suppressWarnings(ssimLibrary(lib)); P <- rsyncrosim::project(L, "Definitions")
sc <- as.data.table(scenario(L, summary = TRUE))
bid <- as.integer(opt("build", NA))
if (is.na(bid)) { b <- sc[IsResult == "Yes" & startsWith(Name, "Build")]; if (!nrow(b)) stop("no Build result in the library"); bid <- max(b$ScenarioId) }
stg <- trimws(strsplit(opt("stages", ""), ",")[[1]]); if (!length(stg) || !all(nzchar(stg))) stop("--stages: the Build stages to rerun, by number (8, or 3,4,8)")
yrs <- as.integer(opt("years", 10))

# 1. the stages
S <- rsyncrosim::scenario(P, sprintf("Quick test: stages %s", paste(stg, collapse = ", ")))
# the library's Stock-Flow Definitions scenario first, when it has one: tools/sync-library.R keeps it current, while the Build result
# holds the stock-flow definitions of its own day (2026-11-07: ST-Sim refused a pathway to the new Agriculture Sector stock, which
# the Build's flow diagram lacked; a stage cannot add rows to its input sheets: SyncroSim keeps the dependency's)
sfd <- sc[Name == "Stock-Flow Definitions" & IsResult == "No", ScenarioId][1]
dependency(S) <- c(if (!is.na(sfd)) sfd, bid)
names_all <- levels(datasheet(S, "core_Pipeline", lookupsAsFactors = TRUE, optional = TRUE)$StageNameId)
pick <- vapply(stg, function(k) { m <- grep(sprintf("^%s - ", k), names_all, value = TRUE); if (length(m) != 1) stop(sprintf("--stages: no single stage numbered %s", k)); m }, "")
saveDatasheet(S, data.frame(StageNameId = pick, RunOrder = seq_along(pick)), "core_Pipeline")
# the Build's option sheets, copied into the quick test: a rerun stage did not see the Build result's Growth Options through the
# dependency (2026-11-07: stage 3 fell back to the default FIA source, which the home lacks), so every Build-stage options sheet is
# copied from the result, or with --options from the Build scenario (its current options)
src_id <- bid
if ("--options" %in% a) { src_id <- sc[ScenarioId == bid, ParentId]; if (is.na(src_id)) stop("--options: the Build result has no parent scenario") }
for (sh in paste0("lucasCore_", c("BuildOptions", "ClimateOptions", "GrowthOptions", "CarbonOptions", "FireOptions", "HarvestAgeOptions", "StudyAreaOptions"))) {
  x <- datasheet(scenario(L, src_id), sh, optional = TRUE); if (nrow(x)) saveDatasheet(S, x, sh) }
description(S) <- sprintf("Quick test (tools/quick-test.R): reruns %s on top of Build result %d, which supplies everything else.", paste(pick, collapse = "; "), bid)
cat(sprintf("scenario %d: %s, on Build result %d\n", scenarioId(S), paste(pick, collapse = "; "), bid))
if ("--no-run" %in% a) quit(save = "no")
t0 <- Sys.time(); R1 <- run(S); r1 <- scenarioId(R1)
cat(sprintf("stages: %.1f min, result %d\n", as.numeric(difftime(Sys.time(), t0, units = "mins")), r1))

# 2. the short run
rs <- system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(here, "new-historical.R")), shQuote(lib), sprintf("--build=%d", r1), sprintf("--also=%s", paste(c(if (!is.na(sfd)) sfd, bid), collapse = ",")),
              sprintf("--years=%d", yrs), "--historical-only", "--raster-every=0", "--replace", shQuote(sprintf("--name=Quick test: %d years", yrs))), stdout = TRUE, stderr = TRUE)
cat(rs, sep = "\n"); hid <- suppressWarnings(as.integer(trimws(tail(rs, 1)))); if (is.na(hid)) stop("new-historical.R did not make the run")
t0 <- Sys.time(); R2 <- run(scenario(L, hid)); cat(sprintf("historical: %.1f min, result %d\n", as.numeric(difftime(Sys.time(), t0, units = "mins")), scenarioId(R2)))
cat(r1, scenarioId(R2), "\n")
