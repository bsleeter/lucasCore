# =============================================================================
# resume.R - a Build stage that would give the same result again is not run again (user 2026-11-19, after a stage 6 failure on Olympic
#            cost 40 minutes of stages 0-5 a second time: "a failed build picks back up from where it errored")
# =============================================================================
# SyncroSim has no resume: a rerun of a Build starts at its first stage. Each Build stage therefore keeps a record of its run
# (Build Results > Build Stages, sheet OutputBuildStage, one .rds file a stage):
#   - every datasheet it read, with a checksum of the rows (a file a row names counts by its content, not its path);
#   - the Data Sources it read: what the Data Sources page sets for them, and the size and date of their files;
#   - the package files it used (its script, the scripts it sourced, the defaults it read), by content, and the option defaults;
#   - every datasheet it wrote, as written, and the lines it logged.
# The next run of the same scenario looks at its newest earlier results, failed ones included (a failed result keeps the sheets
# of the stages that finished). When a stage's record matches - the same rows in every sheet it read, the same data source files,
# the same code - the stage writes that record's sheets into the new result, logs its lines again, and ends. Anything else and the
# stage runs. Because a sheet counts by its content, a stage after one that ran again is still reused when that one wrote what
# it wrote before. Build Options > Rebuild every stage (sheet BuildReuse) turns the reuse off.
# What a record cannot see: a file read without the Data Sources page (none in stages 0-8), and a change to R or its packages.
# shared.R holds the hooks (datasheet, saveDatasheet, updateRunLog, pkg_file); a stage calls stage_begin() after STAGE and
# stage_done() at its end.
# =============================================================================
RS_VERSION <- 3L; RS_SHEET <- "OutputBuildStage"; RS_FILE <- "\001file|"
# sheets whose files a later stage replaces (stage 6 writes the stand age map again where a cut or fire dates a stand, and SyncroSim
# then drops stage 5's file from the result): a record keeps these files itself, so the stage can still be copied
RS_KEEP <- "stsim_InitialConditionsSpatial"

rs_me <- function() rsyncrosim::scenarioId(scn)   # the result being written
rs_off <- function(why) { if (.rs$ok) .rs$why <- why; .rs$ok <- FALSE; invisible() }
rs_md5 <- function(p) vapply(p, function(f) { i <- file.info(f); k <- paste(f, i$size, as.numeric(i$mtime)); v <- .rs$md5[[k]]
  if (is.null(v)) { v <- unname(tools::md5sum(f)); assign(k, v, envir = .rs$md5) }; v }, "", USE.NAMES = FALSE)
rs_is_file <- function(v) !is.na(v) & nzchar(v) & grepl("[/\\\\]", v) & file.exists(v) & !dir.exists(v)
# the columns of x that hold files SyncroSim keeps with the result: named ...FileName (every external file column of lucasCore and
# stsim is, and no other column). A path in any other column is text: Data Sources Used > Path names a file of the data home.
rs_file_cols <- function(x) names(x)[endsWith(names(x), "FileName") & vapply(x, function(v) is.character(v) || is.factor(v), TRUE)]

# the checksum of a sheet's rows: no keys of its own, files by content (a missing file by its name), rows in a fixed order
rs_hash <- function(x, name) { x <- as.data.frame(x, stringsAsFactors = FALSE)
  x <- x[, setdiff(names(x), c("ScenarioId", "ProjectId", paste0(sub("^[^_]*_", "", name), "Id"))), drop = FALSE]
  fc <- rs_file_cols(x)
  for (k in names(x)) { v <- x[[k]]; if (is.factor(v)) v <- as.character(v)
    if (k %in% fc) { e <- rs_is_file(v); o <- !is.na(v) & nzchar(v) & !e; v[e] <- rs_md5(v[e]); v[o] <- basename(v[o]) }
    x[[k]] <- v }
  if (nrow(x) > 1 && ncol(x)) x <- x[do.call(order, unname(as.list(x))), , drop = FALSE]
  rownames(x) <- NULL; digest::digest(x, algo = "md5") }

rs_scope <- function(obj) { cl <- class(obj)[1]
  if (cl == "Scenario") { id <- rsyncrosim::scenarioId(obj); if (id == rs_me()) "scn" else sprintf("scenario:%d", id) }
  else if (cl == "Project") "prj" else if (cl == "SsimLibrary") "lib" else NA_character_ }
rs_object <- function(scope) if (scope == "scn") scn else if (scope == "prj") prj else if (scope == "lib") lib else
  rsyncrosim::scenario(rsyncrosim::ssimLibrary(main_library()), as.integer(sub("scenario:", "", scope)))
# the object and sheet of a datasheet()/saveDatasheet() call, however its arguments were given
rs_call <- function(a, first = c("ssimObject", "name")) { nm <- names(a); if (is.null(nm)) nm <- rep("", length(a)); pos <- a[!nzchar(nm)]; out <- list()
  for (k in first) { if (k %in% nm) out[[k]] <- a[[k]] else if (length(pos)) { out[[k]] <- pos[[1]]; pos <- pos[-1] } }
  out$extra <- c(pos, a[nzchar(nm) & !nm %in% first]); out }

# shared.R's datasheet() calls this with each read: the first read of a sheet counts, and none after the stage wrote it itself
rs_note_read <- function(a, r) { cl <- rs_call(a); name <- cl$name
  if (is.null(name) || !is.character(name) || length(name) != 1 || is.na(name)) return(invisible())   # (a list of sheets, not a sheet's rows)
  if (!is.data.frame(r)) return(rs_off(sprintf("%s was not read as a table", name)))
  scope <- rs_scope(cl$ssimObject); if (is.na(scope)) return(rs_off(sprintf("%s was read from an unknown object", name)))
  if (scope == "scn" && name %in% .rs$written) return(invisible())
  key <- paste(scope, name, digest::digest(cl$extra, algo = "md5")); if (!is.null(.rs$reads[[key]])) return(invisible())
  .rs$reads[[key]] <- list(scope = scope, name = name, args = cl$extra, hash = rs_hash(r, name)); invisible() }

# shared.R's read_data_sources() calls this: of the Data Sources page, a stage depends on the home and on the columns it asked for
# (a path set or corrected for a dataset another stage reads does not run this one again)
rs_set_value <- function(d, k) if (nrow(d) && k %in% names(d) && !is.na(d[[k]][1])) as.character(d[[k]][1]) else ""
rs_note_sources <- function(d, cols) { if (!isTRUE(.rs$on)) return(invisible())
  for (k in setdiff(c("DataSourcesHome", cols), names(.rs$set))) .rs$set[[k]] <- rs_set_value(d, k); invisible() }

# shared.R's saveDatasheet() calls this before each write: the rows as given, a file by its checksum, size and name
rs_note_write <- function(obj, data, name, args) {
  if (!identical(rs_scope(obj), "scn")) stop(sprintf("%s was written outside the scenario", name))
  x <- as.data.frame(data, stringsAsFactors = FALSE)
  for (k in rs_file_cols(x)) { v <- as.character(x[[k]]); e <- rs_is_file(v)
    if (name %in% RS_KEEP) for (p in v[e]) { m <- rs_md5(p); if (is.null(.rs$keep[[m]])) .rs$keep[[m]] <- readBin(p, "raw", file.size(p)) }
    v[e] <- paste0(RS_FILE, rs_md5(v[e]), "|", file.size(v[e]), "|", basename(v[e])); x[[k]] <- v }
  list(name = name, data = x, args = args) }

# ---- what a record is compared with -----------------------------------------------------------------------------------
rs_path_sig <- function(p) { if (is.na(p) || !file.exists(p)) return("missing")
  f <- if (dir.exists(p)) list.files(p, recursive = TRUE, full.names = TRUE) else {   # a file with its companions (.shp: .dbf, .shx, ...)
    stem <- sub("[.][^.]*$", "", basename(p)); a <- list.files(dirname(p), full.names = TRUE); a[startsWith(basename(a), paste0(stem, ".")) | a == p] }
  i <- file.info(f); digest::digest(paste(basename(f), i$size, as.numeric(i$mtime))[order(f)], algo = "md5") }
rs_rel <- function(p) { root <- paste0(normalizePath(env$PackageDirectory, winslash = "/", mustWork = FALSE), "/"); p <- normalizePath(p, winslash = "/", mustWork = FALSE)
  ifelse(startsWith(tolower(p), tolower(root)), substring(p, nchar(root) + 1), NA_character_) }
rs_code_sig <- function(rel) vapply(rel, function(r) { p <- file.path(env$PackageDirectory, r)
  if (!file.exists(p)) "missing" else if (dir.exists(p)) rs_path_sig(p) else unname(tools::md5sum(p)) }, "")
rs_defaults <- function() digest::digest(lapply(c(DEFAULTED_SHEETS, "DataSource"), sheet_defaults, quiet = TRUE), algo = "md5")
rs_script <- function() { f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)); if (length(f)) f[1] else character() }

# why a record no longer holds (the first reason found), or NULL when the stage would read what it read then
rs_changed <- function(rec) {
  if (!identical(rec$defaults, rs_defaults())) return("the package's option defaults changed")
  cur <- rs_code_sig(names(rec$files)); d <- names(rec$files)[cur != unlist(rec$files)]
  if (length(d)) return(sprintf("the package's %s changed", paste(utils::head(d, 3), collapse = ", ")))
  if (length(rec$set)) { d <- tryCatch(as.data.frame(rs_datasheet(prj, ds("DataSource"), lookupsAsFactors = FALSE, optional = TRUE)), error = function(e) NULL)
    if (is.null(d)) return("Data Sources could not be read")
    for (k in names(rec$set)) if (!identical(rs_set_value(d, k), rec$set[[k]])) return(sprintf("Data Sources > %s changed", k)) }
  for (s in rec$sources) if (!identical(rs_path_sig(s$path), s$sig)) return(sprintf("the data source %s changed (%s)", s$column, s$path))
  for (r in rec$reads) { x <- tryCatch(do.call(rs_datasheet, c(list(rs_object(r$scope), r$name), r$args)), error = function(e) NULL)
    if (is.null(x) || !is.data.frame(x) || !identical(rs_hash(x, r$name), r$hash))
      return(sprintf("%s%s changed", r$name, if (r$scope == "prj") " (a project table)" else "")) }
  NULL }

# ---- reuse ------------------------------------------------------------------------------------------------------------
rs_enabled <- function() { x <- tryCatch(rs_datasheet(scn, ds("BuildReuse"), optional = TRUE, lookupsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(x) || !nrow(x) || !"Rebuild" %in% names(x)) return(TRUE)
  v <- as.character(x$Rebuild[1]); !(!is.na(v) && (v %in% c("2", "TRUE", "-1") || startsWith(v, "Yes"))) }
rs_data_dir <- function(id, sheet) file.path(paste0(main_library(), ".data"), sprintf("Scenario-%d", id), sheet)
rs_read_record <- function(L, id) {
  x <- tryCatch(as.data.frame(rs_datasheet(rsyncrosim::scenario(L, id), ds(RS_SHEET), optional = TRUE, lookupsAsFactors = FALSE)), error = function(e) NULL)
  if (is.null(x) || !nrow(x) || !all(c("Stage", "RecordFileName") %in% names(x))) return(NULL)
  f <- as.character(x$RecordFileName[x$Stage %in% STAGE]); if (!length(f)) return(NULL); f <- f[length(f)]; if (is.na(f)) return(NULL)
  if (!file.exists(f)) f <- file.path(rs_data_dir(id, ds(RS_SHEET)), basename(f)); if (!file.exists(f)) return(NULL)
  rec <- tryCatch(readRDS(f), error = function(e) NULL)
  if (is.null(rec) || !identical(rec$version, RS_VERSION) || !identical(rec$stage, STAGE)) NULL else rec }

# the files a record's sheets name, found again by content in the earlier result's folders (or this result's); NULL when one is gone
rs_find_files <- function(rec, id) { seen <- list(); out <- list()
  for (i in seq_along(rec$writes)) { w <- rec$writes[[i]]
    for (k in names(w$data)) { v <- w$data[[k]]; if (!is.character(v)) next; tk <- which(!is.na(v) & startsWith(v, RS_FILE)); if (!length(tk)) next
      dirs <- c(rs_data_dir(id, w$name), rs_data_dir(rs_me(), w$name))
      for (j in tk) { p <- strsplit(substring(v[j], nchar(RS_FILE) + 1), "|", fixed = TRUE)[[1]]; md5 <- p[1]; size <- as.numeric(p[2]); base <- paste(p[-(1:2)], collapse = "|")
        cand <- file.path(dirs, base); cand <- cand[file.exists(cand)]
        hit <- cand[file.size(cand) == size]; hit <- hit[vapply(hit, rs_md5, "") == md5]
        if (!length(hit)) { key <- paste(dirs, collapse = "|"); if (is.null(seen[[key]])) seen[[key]] <- list.files(dirs, full.names = TRUE)   # (SyncroSim renames a second file of a name: StandAge(2).tif)
          a <- seen[[key]]; a <- a[file.size(a) == size]; hit <- a[vapply(a, rs_md5, "") == md5] }
        if (!length(hit) && !is.null(rec$kept[[md5]])) { hit <- file.path(TD(), "reuse", "kept", md5, base); dir.create(dirname(hit), recursive = TRUE, showWarnings = FALSE); writeBin(rec$kept[[md5]], hit) }
        if (!length(hit)) return(list(missing = sprintf("%s (%s)", base, w$name)))
        out[[length(out) + 1]] <- list(write = i, column = k, row = j, from = hit[1], base = base) } } }
  list(files = out) }

# write a record's sheets into this result and log its lines; NULL when done, else why not
rs_replay <- function(rec, id) {
  ff <- rs_find_files(rec, id); if (!is.null(ff$missing)) return(sprintf("its file %s is no longer there", ff$missing))
  W <- rec$writes
  for (f in ff$files) { d <- file.path(TD(), "reuse", f$write); dir.create(d, recursive = TRUE, showWarnings = FALSE); to <- file.path(d, f$base)
    if (!file.exists(to) && !file.copy(f$from, to, copy.date = TRUE)) return(sprintf("its file %s could not be copied", f$base))
    W[[f$write]]$data[[f$column]][f$row] <- to }
  rsyncrosim::updateRunLog(sprintf("%s: not run again. Result %d ran it%s with the same settings and tables, the same data source files and the same code, so its %d table%s are copied into this result. Build Options > Rebuild every stage turns this off. Its log from that run:",
    STAGE, id, if (is.null(rec$ran)) "" else sprintf(" on %s", rec$ran), length(W), if (length(W) == 1) "" else "s"))
  for (l in rec$log) rsyncrosim::updateRunLog(l)
  .rs$replaying <- TRUE
  for (w in W) do.call(rsyncrosim::saveDatasheet, c(list(scn, w$data, w$name), w$args))
  m <- as.numeric(difftime(Sys.time(), .rs$t0, units = "mins")); rs_write_record(rec, sprintf("Reused from result %d", id), m)
  rsyncrosim::updateRunLog(sprintf("%s: copied in %.1f min (%.1f of them checking that nothing changed)", STAGE, m, .rs$tcheck))
  NULL }

rs_reuse <- function() {
  if (!rs_enabled()) { rsyncrosim::updateRunLog(sprintf("%s: Build Options > Rebuild every stage is on, so no earlier result is looked at", STAGE)); return(FALSE) }
  L <- rsyncrosim::ssimLibrary(main_library()); s <- data.table::as.data.table(rsyncrosim::scenario(L, summary = TRUE)); me <- rs_me()
  p <- if ("ParentId" %in% names(s)) s[ScenarioId == me, ParentId] else NA
  if (length(p) != 1 || is.na(p)) return(FALSE)
  ids <- sort(s[ParentId %in% p & ScenarioId != me, ScenarioId], decreasing = TRUE); why <- character()
  for (id in utils::head(ids, 8)) { rec <- rs_read_record(L, id); if (is.null(rec)) next
    w <- rs_changed(rec); .rs$tcheck <- as.numeric(difftime(Sys.time(), .rs$t0, units = "mins")); if (is.null(w)) w <- rs_replay(rec, id)
    if (is.null(w)) return(TRUE)
    why <- c(why, sprintf("since result %d, %s", id, w)); if (length(why) >= 3) break }
  if (length(why)) rsyncrosim::updateRunLog(sprintf("%s runs: %s", STAGE, paste(why, collapse = "; ")))
  FALSE }

rs_write_record <- function(rec, status, minutes) { f <- file.path(TD(), sprintf("build-stage-%s.rds", gsub("[^A-Za-z0-9]+", "-", STAGE))); saveRDS(rec, f)
  tryCatch(rsyncrosim::saveDatasheet(scn, data.frame(Stage = STAGE, Status = status, Minutes = round(minutes, 1), RecordFileName = f, stringsAsFactors = FALSE), ds(RS_SHEET), append = TRUE),
           error = function(e) rsyncrosim::updateRunLog(sprintf("%s: its record for a later Build was not written (%s)", STAGE, conditionMessage(e)))) }

# ---- the two calls a stage makes ----------------------------------------------------------------------------------------
stage_begin <- function() {
  .rs$t0 <- Sys.time(); .rs$replaying <- FALSE
  done <- tryCatch(rs_reuse(), error = function(e) {
    if (isTRUE(.rs$replaying)) fail("%s: copying the stage from an earlier result stopped part way (%s). Tick Build Options > Rebuild every stage and run again", STAGE, conditionMessage(e))
    rsyncrosim::updateRunLog(sprintf("%s runs: no earlier result could be looked at (%s)", STAGE, conditionMessage(e))); FALSE })
  if (isTRUE(done)) quit(save = "no", status = 0)
  .rs$reads <- list(); .rs$set <- list(); .rs$keep <- list(); .rs$writes <- list(); .rs$written <- character(); .rs$log <- character(); .rs$ok <- TRUE; .rs$on <- TRUE; invisible() }

stage_done <- function() { if (!isTRUE(.rs$on)) return(invisible()); .rs$on <- FALSE
  if (!.rs$ok) { rsyncrosim::updateRunLog(sprintf("%s: no record for a later Build to reuse (%s)", STAGE, .rs$why)); return(invisible()) }
  tryCatch({
    rel <- rs_rel(unique(c(rs_script(), file.path(env$PackageDirectory, "src", c("shared.R", "resume.R", "datahome.R")), .rs$files))); rel <- sort(unique(rel[!is.na(rel)]))
    rec <- list(version = RS_VERSION, stage = STAGE, ran = format(Sys.time(), "%d %b %Y"), result = rs_me(), defaults = rs_defaults(),
                files = as.list(rs_code_sig(rel)),
                sources = lapply(.home_cov$read, function(x) list(column = x$DataSource, path = x$Path, sig = rs_path_sig(x$Path))),
                set = .rs$set, reads = unname(.rs$reads), writes = .rs$writes, kept = .rs$keep, log = .rs$log)
    rs_write_record(rec, "Ran", as.numeric(difftime(Sys.time(), .rs$t0, units = "mins"))) },
    error = function(e) rsyncrosim::updateRunLog(sprintf("%s: no record for a later Build to reuse (%s)", STAGE, conditionMessage(e))))
  invisible() }
