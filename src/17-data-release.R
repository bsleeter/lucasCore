# =============================================================================
# 17-data-release.R - stage 17: chosen runs of a Build as a data release folder, with a CSDGM record each (to-do 14, Phase 3)
# =============================================================================
# Its own scenario: pipeline stage 17 alone, dependency the Build result, the runs on the Data Release page. Writes src/release.R's folder and saves
# one row per file to Release Contents, and one summary row to Data Release. Uploads nothing: the folder goes to ScienceBase by hand.
# It runs after the Build and the runs have ended, because it reads their run logs. mp runs when the Data Sources page names it; an error
# from mp fails the stage. The Release Information page supplies the names, DOI and wording: a Draft lists what is blank and runs on, while Provisional and
# Approved fail on it (the folder is written first, so the list can be read).
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "metadata.R")); source(pkg_file("src", "metadata-record.R")); source(pkg_file("src", "release.R")); source(pkg_file("src", "release-review.R"))
STAGE <- "17 Data Release"
progressBar(type = "begin", totalSteps = 3)

lib <- main_library()
s <- as.data.table(rsyncrosim::scenario(ssimLibrary(lib), summary = TRUE))
id <- intersect(run_dependencies(), s[IsResult == "Yes", ScenarioId])
if (!length(id)) fail("no Build result: add the Build result as this scenario's dependency")
if (length(id) > 1) say("%d results among the dependencies: the release describes the first, %d", length(id), id[1])
runs <- read_ds("DataReleaseRun")
if (!nrow(runs) || all(is.na(runs$RunScenarioId))) fail("Data Release: list the runs to release on the Data Release page")
opt <- read_ds("DataReleaseOptions")
pick <- function(k) if (nrow(opt) && k %in% names(opt) && !is.na(opt[[k]][1])) opt[[k]][1] else NA
out <- pick("OutputFolder"); if (is.na(out) || !nzchar(out)) out <- file.path(dirname(lib), paste(tools::file_path_sans_ext(basename(lib)), "data release"))
every <- pick("MapEvery"); if (is.na(every)) every <- 1L
if (every < 1) fail("Data Release: maps every %s years: give 1 or more", every)
if (dir.exists(out) && length(list.files(out))) fail("Data Release: %s already holds files: choose an empty folder, so that a release never mixes two runs of this stage", out)
progressBar()

r <- tryCatch(rl_release(lib, id[1], unique(na.omit(runs$RunScenarioId)), out, pkg_file("defaults", "metadata"), every = as.integer(every),
                         console = file.path(rsyncrosim::filepath(rsyncrosim::session()), "SyncroSim.Console.exe"), say = function(m) say("%s", m), info_scenario = rsyncrosim::scenarioId(scn)),
              error = function(e) fail("Data Release: %s", conditionMessage(e)))
progressBar()

bad <- sum(r$mp$Level == "Error"); warns <- sum(r$mp$Level == "Warning")
mp <- if (!r$mp_found) "not run: mp not found (set it on the Data Sources page)" else paste(c(sprintf("%d records: %d errors, %d warnings", length(r$records), bad, warns), head(r$mp$Message, 5)), collapse = "; ")
say("Release: %s, %d files, %.2f GB; mp %s", r$out, nrow(r$contents), sum(r$contents$bytes) / 1e9, mp)
say("Release status: %s%s", r$status, if (!is.na(r$ipds) && nzchar(r$ipds)) sprintf("; IPDS %s", r$ipds) else "")
if (length(r$draft)) say("Still placeholder or drafted: %s", paste(r$draft, collapse = "; "))
for (i in which(r$status != "Draft" | r$checks$Check != RL_DRAFT_CHECK)) check(STAGE, r$checks$Check[i], r$checks$Pass[i], r$checks$Detail[i])
check(STAGE, "mp finds no errors (or mp is not installed)", bad == 0L, mp)
v <- r$review[Level == "must"]
if (r$status == "Draft") { for (i in which(v$Pass %in% FALSE)) say("Review check not passed yet: %s. %s", v$What[i], v$Detail[i]) } else for (i in seq_len(nrow(v))) check(STAGE, v$What[i], v$Pass[i] %in% c(TRUE, NA), v$Detail[i])
say("Review packet: %s", file.path(r$out, "review", "reviewer-summary.html"))
write_ds(r$contents[, .(File = file, Product = product, Bytes = bytes, Sha256 = sha256)], "OutputReleaseContents")
write_ds(data.table(Folder = r$out, Runs = paste(vapply(r$runs, function(x) x$slug, ""), collapse = "; "), Files = nrow(r$contents), SizeGb = round(sum(r$contents$bytes) / 1e9, 3), Mp = mp, ToSupply = paste(r$draft, collapse = "; ")), "OutputDataRelease")
progressBar()
finish_checks()
progressBar(type = "end")
