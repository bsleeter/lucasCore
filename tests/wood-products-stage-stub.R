# =============================================================================
# wood-products-stage-stub.R - runs stage 18 (src/18-wood-products.R) outside SyncroSim, for tests/phaseZ30 and phaseZ31 (sourced)
# =============================================================================
# stage_18(pkg, lib, options): the stage script with SyncroSim's calls replaced - the options sheet is `options`, the output sheets are
# kept in memory, the library is only read (by SQL, read-only). Returns the sheets it wrote, its log, its checks and the error (or NULL).
# =============================================================================
stage_18 <- function(pkg, lib, options, out = tempfile("wp"), study_area = NULL) {   # study_area: the Study Area unit names the figures name
  E <- new.env(parent = globalenv()); dir.create(out)
  E$env <- list(PackageDirectory = pkg, LibraryFilePath = lib, TransferDirectory = out)
  E$sheets <- list(); E$log <- character(); E$checks <- list()
  with(E, {
    pkg_file <- function(...) file.path(env$PackageDirectory, ...)
    main_library <- function() env$LibraryFilePath
    TD <- function() env$TransferDirectory
    say <- function(...) log <<- c(log, sprintf(...))
    fail <- function(...) stop(sprintf(...), call. = FALSE)
    progressBar <- function(...) invisible()
    read_ds <- function(name, ...) if (name == "WoodProductsOptions") as.data.table(options) else if (name == "StudyArea" && length(study_area)) data.table(UnitId = study_area) else data.table()
    write_ds <- function(x, name, ...) sheets[[name]] <<- as.data.table(x)
    check <- function(stage, what, ok, detail = "") { if (length(ok) != 1 || is.na(ok)) ok <- FALSE
      checks[[length(checks) + 1]] <<- data.table(Check = what, Status = if (ok) "Pass" else "FAIL", Detail = detail); invisible(ok) }
    finish_checks <- function() invisible()
  })
  E$options <- options; E$study_area <- study_area
  code <- readLines(file.path(pkg, "src", "18-wood-products.R"))
  code <- code[!grepl("^source\\(file.path\\(rsyncrosim::ssimEnvironment", code)]   # shared.R: replaced by the stubs above
  res <- tryCatch({ eval(parse(text = code), envir = E); NULL }, error = function(e) conditionMessage(e))
  list(sheets = E$sheets, log = E$log, checks = rbindlist(E$checks), error = res)
}
# the stage's Wood Products sheet as wp_of_run (src/run-figures.R) reads it from a library: the rows over all iterations
stage_18_wp <- function(x, scenario = 0L) { w <- x$sheets$OutputWoodProducts[is.na(Iteration), .(Year, Variable, Mean, Lower, Upper)]
  setattr(w, "scenario", as.integer(scenario)); w }
