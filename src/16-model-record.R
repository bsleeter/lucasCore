# =============================================================================
# 16-model-record.R - stage 16: the FGDC CSDGM metadata record of a Build result (to-do 14)
# =============================================================================
# Writes src/metadata-record.R's record of the Build result this scenario depends on, and saves it to Model Record with what mp said, what is
# still a placeholder or drafted, and what the record had to infer. Export > LUCAS Core > Model Record saves the XML to a folder.
# It reads the Build's run log, which exists only once that run has ended, so this stage has a scenario of its own: pipeline stage 16 alone,
# dependency the Build result. tools/model-record.R writes the same record outside a run.
# mp runs when LUCAS_MP or the option lucas.mp names it, or it is on the PATH; an error from mp fails the stage, and no mp only says so.
# =============================================================================
source(file.path(rsyncrosim::ssimEnvironment()$PackageDirectory, "src", "shared.R"))
source(pkg_file("src", "metadata.R")); source(pkg_file("src", "metadata-record.R"))
STAGE <- "16 Model Record"
progressBar(type = "begin", totalSteps = 2)

s <- as.data.table(rsyncrosim::scenario(ssimLibrary(main_library()), summary = TRUE))
id <- intersect(run_dependencies(), s[IsResult == "Yes", ScenarioId])
if (!length(id)) fail("no Build result: add the Build result as this scenario's dependency (a Build's own log exists only once it has ended, so this stage cannot be in its pipeline)")
if (length(id) > 1) say("%d results among the dependencies: the record describes the first, %d", length(id), id[1])
progressBar()

r <- md_write_record(main_library(), id[1], file.path(TD(), "ModelRecord"), pkg_file("defaults", "metadata"), sprintf("model-record-%d.xml", id[1]))
m <- r$mp; x <- r$content; bad <- if (is.null(m)) 0L else sum(m$Level == "Error")
mp <- if (is.null(m)) "not run: mp not found (set LUCAS_MP to mp.exe)" else paste(c(sprintf("%d errors, %d warnings", bad, sum(m$Level == "Warning")), head(m$Message, 5)), collapse = "; ")
say("Model record: %s for Build result %d, %d lineage sources, %d process steps; mp %s", basename(r$file), id[1], length(x$quality$sources), length(x$quality$steps), mp)
if (length(x$draft)) say("Still placeholder or drafted: %s", paste(x$draft, collapse = "; "))
if (length(x$notes)) say("The record had to infer: %s", paste(x$notes, collapse = "; "))
check(STAGE, "the record is written, with lineage sources and process steps", file.exists(r$file) && length(x$quality$sources) > 0 && length(x$quality$steps) > 0, basename(r$file))
check(STAGE, "mp finds no errors (or mp is not installed)", bad == 0L, mp)
write_ds(data.table(BuildResult = id[1], FileName = r$file, Mp = mp, ToSupply = paste(x$draft, collapse = "; "), Notes = paste(x$notes, collapse = "; ")), "OutputModelRecord")
progressBar()
finish_checks()
progressBar(type = "end")
