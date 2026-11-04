# =============================================================================
# release.R - the data release (to-do 14, Phase 3): chosen runs of a Build as a folder laid out for ScienceBase, with a CSDGM record each
# =============================================================================
# rl_release(lib, build, runs, figures, out, dir, ...)  writes the whole folder; stage 17 and tools/data-release.R both call it:
#   <out>/README.txt  release.xml  contents.csv  model/  historical/<run>/  projections/<run>/  comparison/  archive/
# Reads the library by read-only SQL and the runs' maps from its data folder, and writes nothing to the library.
# The columns exported are exactly those of defaults/metadata/data-dictionary.csv: rl_check_tables compares each header with it.
# ScienceBase holds 100 files per item, so each map variable of a run is one zip of its yearly cloud-optimized GeoTIFFs.
# Metadata must not interpret results (USGS model-output guidance, 2018): the records say what was done and what was compared, not what it means.
# What only a person can supply comes from the Release Information page (rl_read_info), over record-defaults.csv; what is still missing is listed in draft.
# Release status: a Draft lists it; Provisional and Approved fail on it. The metadata identifier goes on the parent record only: ScienceBase assigns each
# item its own, so the run and model records carry none rather than a copy of the parent's.
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(DBI); library(RSQLite) })
if (!exists("md_model_content")) stop("source src/metadata.R and src/metadata-record.R before src/release.R")

rl_slug <- function(x) gsub("^-+|-+$", "", gsub("[^a-z0-9]+", "-", tolower(x)))
rl_ro <- function(lib) dbConnect(SQLite(), lib, flags = SQLITE_RO)

# ---- the runs -------------------------------------------------------------------------------------------------------------
# The historical run a projection starts from, else NA: the same rule as run-figures.R's find_history
rl_history <- function(con, rid) {
  if (!dbExistsTable(con, "lucasCore_ProjectionStart")) return(NA_integer_)
  q <- function(s, ...) dbGetQuery(con, sprintf(s, ...))
  par <- q("SELECT ScenarioId FROM core_ScenarioResult WHERE ResultId = %d", rid)$ScenarioId
  ids <- c(rid, par, if (length(par)) q("SELECT DependencyId FROM core_ScenarioDependency WHERE ScenarioId = %d ORDER BY Priority", par[1])$DependencyId)
  for (i in ids) { h <- q("SELECT HistoricalScenarioId FROM lucasCore_ProjectionStart WHERE ScenarioId = %d", i)$HistoricalScenarioId
    if (length(h) && !is.na(h[1])) return(as.integer(h[1])) }
  NA_integer_ }

rl_run_info <- function(con, rid) {
  n <- dbGetQuery(con, sprintf("SELECT Name FROM core_Scenario WHERE ScenarioId = %d", rid))$Name
  if (!length(n)) stop("result ", rid, " is not in this library")
  a <- dbGetQuery(con, sprintf("SELECT MIN(Timestep) y0, MAX(Timestep) y1, MIN(Iteration) i0, MAX(Iteration) i1 FROM stsim_OutputStratumState WHERE ScenarioId = %d", rid))
  if (is.na(a$y0)) stop("result ", rid, " has no ST-Sim output: list result scenarios of historical runs or projections")
  name <- sub(" \\(\\[.*$", "", n); h <- rl_history(con, rid)
  # the run's settings, for its process step: its parent's dependencies name the Build, the setup and the climate it ran on
  par <- dbGetQuery(con, sprintf("SELECT ScenarioId FROM core_ScenarioResult WHERE ResultId = %d", rid))$ScenarioId
  dep <- if (length(par)) dbGetQuery(con, sprintf("SELECT s.Name FROM core_ScenarioDependency d JOIN core_Scenario s ON s.ScenarioId = d.DependencyId WHERE d.ScenarioId = %d ORDER BY d.Priority", par[1]))$Name else character()
  tiles <- dbGetQuery(con, sprintf("SELECT COUNT(*) n FROM core_SpatialMultiprocessing WHERE ScenarioId = %d AND MaskFileName IS NOT NULL", rid))$n
  settings <- sprintf("Simulated %d to %d, %d iteration%s%s%s%s.", a$y0, a$y1, a$i1, if (a$i1 > 1) "s" else "", if (tiles) ", on spatial multiprocessing tiles" else "",
                      if (!is.na(h)) sprintf(", starting from historical result %d", h) else "",
                      if (length(dep)) paste0("; the scenario depends on: ", paste(sub(" \\(\\[.*$", "", dep), collapse = ", ")) else "")
  list(id = rid, name = name, slug = rl_slug(name), history = h, kind = if (is.na(h)) "historical" else "projection",
       folder = if (is.na(h)) "historical" else "projections", years = c(a$y0, a$y1), iterations = c(a$i0, a$i1), settings = settings) }

# Two results of one scenario have one name: the later takes its id
rl_unique_slugs <- function(runs) { s <- vapply(runs, `[[`, "", "slug"); d <- s %in% s[duplicated(s)]
  for (i in which(d)) runs[[i]]$slug <- sprintf("%s-%d", s[i], runs[[i]]$id)
  runs }

# ---- tables ---------------------------------------------------------------------------------------------------------------
rl_table_sql <- function(table, rid) {
  strata <- function(a = "") sprintf("LEFT JOIN stsim_Stratum p ON p.StratumId = o.%sStratumId LEFT JOIN stsim_SecondaryStratum s ON s.SecondaryStratumId = o.%sSecondaryStratumId LEFT JOIN stsim_TertiaryStratum t ON t.TertiaryStratumId = o.%sTertiaryStratumId", a, a, a)
  head <- "o.Iteration AS iteration, o.Timestep AS year, p.Name AS primary_stratum, s.Name AS secondary_stratum, t.Name AS tertiary_stratum"
  switch(table,
    "state-classes.csv" = sprintf("SELECT %s, c.Name AS state_class, SUM(o.Amount) AS area_ha FROM stsim_OutputStratumState o %s JOIN stsim_StateClass c ON c.StateClassId = o.StateClassId WHERE o.ScenarioId = %d GROUP BY 1, 2, 3, 4, 5, 6 ORDER BY 1, 2, 3, 4, 5, 6", head, strata(), rid),
    "transitions.csv"   = sprintf("SELECT %s, g.Name AS transition_group, SUM(o.Amount) AS area_ha FROM stsim_OutputStratumTransition o %s JOIN stsim_TransitionGroup g ON g.TransitionGroupId = o.TransitionGroupId WHERE o.ScenarioId = %d GROUP BY 1, 2, 3, 4, 5, 6 ORDER BY 1, 2, 3, 4, 5, 6", head, strata(), rid),
    "stocks.csv"        = sprintf("SELECT %s, c.Name AS state_class, g.Name AS stock_group, SUM(o.Amount) AS carbon_t FROM stsim_OutputStock o %s JOIN stsim_StateClass c ON c.StateClassId = o.StateClassId JOIN stsim_StockGroup g ON g.StockGroupId = o.StockGroupId WHERE o.ScenarioId = %d GROUP BY 1, 2, 3, 4, 5, 6, 7 ORDER BY 1, 2, 3, 4, 5, 6, 7", head, strata(), rid),
    "flows.csv"         = sprintf("SELECT %s, c.Name AS state_class, y.Name AS transition_type, g.Name AS flow_group, SUM(o.Amount) AS carbon_t FROM stsim_OutputFlow o %s JOIN stsim_StateClass c ON c.StateClassId = o.FromStateClassId LEFT JOIN stsim_TransitionType y ON y.TransitionTypeId = o.TransitionTypeId JOIN stsim_FlowGroup g ON g.FlowGroupId = o.FlowGroupId WHERE o.ScenarioId = %d GROUP BY 1, 2, 3, 4, 5, 6, 7, 8 ORDER BY 1, 2, 3, 4, 5, 6, 7, 8", head, strata("From"), rid),
    stop("no export for ", table)) }

# One table to CSV in chunks (a run's flows are millions of rows), with what the record needs: rows, and each number column's range
rl_write_table <- function(con, table, rid, slug, out, chunk = 5e5L) {
  f <- file.path(out, table); unlink(f); rows <- 0; rng <- list(); cols <- NULL
  res <- dbSendQuery(con, rl_table_sql(table, rid)); on.exit(dbClearResult(res))
  repeat {
    d <- as.data.table(dbFetch(res, n = chunk)); if (!nrow(d) && rows > 0) break
    d <- cbind(run = rep(slug, nrow(d)), d); cols <- names(d)
    num <- intersect(names(d), c("area_ha", "carbon_t")); for (j in num) set(d, j = j, value = round(d[[j]], 4))
    for (j in intersect(names(d), c("iteration", "year", num))) if (nrow(d)) { r <- range(d[[j]], na.rm = TRUE); rng[[j]] <- range(c(rng[[j]], r)) }
    fwrite(d, f, append = rows > 0, na = "NA", bom = FALSE); rows <- rows + nrow(d)
    if (dbHasCompleted(res)) break
  }
  list(file = table, path = f, rows = rows, ranges = rng, columns = cols) }

rl_check_tables <- function(stats, dict) unlist(lapply(stats, function(s) {
  want <- md_columns(dict, s$file)$Column
  if (identical(s$columns, want)) character() else sprintf("%s: columns %s, the dictionary has %s", s$file, paste(s$columns, collapse = ","), paste(want, collapse = ",")) }))

# ---- maps ---------------------------------------------------------------------------------------------------------------
# What a run's data folder holds. Group maps carry the group's id, averages iteration 0 (the mean across iterations)
RL_MAPS <- rbindlist(list(
  list("state-class", "stsim_OutputSpatialState", "^sc[.]", "dictionary", "INT4S"),
  list("age", "stsim_OutputSpatialAge", "^age[.]", "dictionary", "INT4S"),
  list("transition", "stsim_OutputSpatialTransition", "^tg_", "stsim_TransitionGroup", "INT4S"),
  list("carbon", "stsim_OutputAverageSpatialStockGroup", "^avgstkg_", "stsim_StockGroup", "FLT4S"),
  list("flow", "stsim_OutputAverageSpatialFlowGroup", "^avgflog_", "stsim_FlowGroup", "FLT4S")))
setnames(RL_MAPS, c("Variable", "Folder", "Pattern", "Groups", "Type"))

# One row per map file of the run. years NULL = every year (the settled default)
rl_map_files <- function(data, rid, years = NULL) {
  x <- rbindlist(lapply(seq_len(nrow(RL_MAPS)), function(i) { m <- RL_MAPS[i]; d <- file.path(data, sprintf("Scenario-%d", rid), m$Folder)
    f <- if (dir.exists(d)) list.files(d, pattern = paste0(m$Pattern, ".*[.]tif$")) else character()
    if (!length(f)) return(NULL)
    data.table(Variable = m$Variable, Type = m$Type, Table = m$Groups, Path = file.path(d, f),
               GroupId = suppressWarnings(as.integer(sub("^[a-z]+_([0-9]+)[.].*$", "\\1", f))),
               Iteration = as.integer(sub("^.*[.]it([0-9]+)[.].*$", "\\1", f)), Year = as.integer(sub("^.*[.]ts([0-9]+)[.]tif$", "\\1", f))) }))
  if (!nrow(x)) return(x)
  if (!is.null(years)) x <- x[Year %in% years]
  x }

# Each variable (each group of a group variable) of the run as one zip of COGs in EPSG:5070, -9999 for no data. Returns one row per zip
rl_zip <- function(folder, zipfile) {
  unlink(zipfile); z <- Sys.which("zip")
  if (nzchar(z)) { w <- setwd(folder); on.exit(setwd(w)); system2(z, c("-q", "-0", "-r", shQuote(normalizePath(dirname(zipfile), winslash = "/") |> file.path(basename(zipfile))), ".")) }
  else if (.Platform$OS.type == "windows") system2("powershell", c("-NoProfile", "-Command", shQuote(sprintf("Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::CreateFromDirectory('%s','%s',[IO.Compression.CompressionLevel]::NoCompression,$false)", normalizePath(folder), file.path(normalizePath(dirname(zipfile)), basename(zipfile))))))
  else stop("no zip program found")
  if (!file.exists(zipfile)) stop("could not write ", zipfile)
  zipfile }

rl_write_maps <- function(files, con, slug, out, say = message) {
  suppressPackageStartupMessages(library(terra))
  if (!nrow(files)) return(data.table())
  dir.create(out, showWarnings = FALSE, recursive = TRUE); terraOptions(progress = 0)
  many <- length(unique(files[Iteration > 0L, Iteration])) > 1L
  names_of <- function(tbl, ids) { idc <- sub("^stsim_", "", tbl); dbGetQuery(con, sprintf("SELECT %sId AS Id, Name FROM %s WHERE %sId IN (%s)", idc, tbl, idc, paste(unique(ids), collapse = ","))) }
  gr <- files[, .(N = .N), by = .(Variable, Type, Table, GroupId)]
  rbindlist(lapply(seq_len(nrow(gr)), function(i) { g <- gr[i]
    h <- files[Variable == g$Variable & (is.na(GroupId) | GroupId == g$GroupId)]
    group <- if (is.na(g$GroupId)) NA_character_ else { n <- names_of(g$Table, g$GroupId)$Name; if (length(n)) n else sprintf("group-%d", g$GroupId) }
    stem <- paste(c(g$Variable, if (!is.na(group)) rl_slug(group), slug), collapse = "-")
    tmp <- tempfile("map", tmpdir = out); dir.create(tmp); on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    lo <- Inf; hi <- -Inf; cells <- NA_real_
    for (k in seq_len(nrow(h))) {
      r <- rast(h$Path[k]); mm <- minmax(r, compute = TRUE); if (is.finite(mm[1, 1])) { lo <- min(lo, mm[1, 1]); hi <- max(hi, mm[2, 1]) }
      f <- paste0(stem, if (many && h$Iteration[k] > 0L) sprintf("-it%d", h$Iteration[k]) else "", "-", h$Year[k], ".tif")
      writeRaster(r, file.path(tmp, f), filetype = "COG", datatype = g$Type, NAflag = -9999, gdal = "COMPRESS=DEFLATE", overwrite = TRUE)
    }
    z <- rl_zip(tmp, file.path(out, paste0(stem, ".zip"))); unlink(tmp, recursive = TRUE)
    data.table(Variable = g$Variable, Group = group, File = basename(z), Path = z, Maps = nrow(h), Min = lo, Max = hi, Year0 = min(h$Year), Year1 = max(h$Year)) })) }

# ---- definitions ----------------------------------------------------------------------------------------------------------
# definitions.csv of this library: every name of every kind, code = the value in the maps (state classes, transition types)
# Strata: only those the runs hold, since a library's strata lists can hold all of the United States. "X [Type]" is the group ST-Sim makes
# of the one type X, so it takes X's definition
rl_definitions <- function(con, dir, runs) {
  defs <- md_definitions(dir); ids <- paste(runs, collapse = ",")
  one <- function(kind, tbl, code = FALSE, where = "") { f <- dbListFields(con, tbl)
    d <- as.data.table(dbGetQuery(con, sprintf("SELECT Name, %s AS Code, %s AS Description FROM %s %s", if (code) "Id" else "NULL", if ("Description" %in% f) "Description" else "NULL", tbl, where)))
    if (!nrow(d)) return(NULL)
    e <- md_define(defs, kind, d$Name, own = setNames(as.character(d$Description), d$Name))
    data.table(kind = kind, name = d$Name, code = d$Code, definition = e$Definition, source = e$Source) }
  used <- function(tbl, col) one("Stratum", tbl, where = sprintf("WHERE %s IN (SELECT DISTINCT %s FROM stsim_OutputStratumState WHERE ScenarioId IN (%s))", col, col, ids))
  x <- rbindlist(list(one("StateClass", "stsim_StateClass", TRUE), one("TransitionGroup", "stsim_TransitionGroup"), one("TransitionType", "stsim_TransitionType", TRUE),
                      one("StockType", "stsim_StockType"), one("StockGroup", "stsim_StockGroup"), one("FlowType", "stsim_FlowType"), one("FlowGroup", "stsim_FlowGroup"),
                      used("stsim_Stratum", "StratumId"), used("stsim_SecondaryStratum", "SecondaryStratumId"), used("stsim_TertiaryStratum", "TertiaryStratumId")))
  for (p in list(c("TransitionGroup", "TransitionType"), c("StockGroup", "StockType"), c("FlowGroup", "FlowType"))) {
    i <- which(x$kind == p[1] & is.na(x$definition) & endsWith(x$name, " [Type]")); if (!length(i)) next
    m <- x[kind == p[2]][match(sub(" \\[Type\\]$", "", x$name[i]), name)]
    set(x, i, "definition", ifelse(is.na(m$definition), NA_character_, paste0("The one ", tolower(sub("(Transition|Stock|Flow)Type", "\\1", p[2])), " type of this name: ", m$definition))); set(x, i, "source", m$source) }
  x[!duplicated(x[, .(kind, name)])] }

# ---- quality --------------------------------------------------------------------------------------------------------------
# Simulated against recorded area of each transition group over the run's years. Numbers only. The record: the Build's Transition Summary
rl_transition_compare <- function(con, build, rid) {
  rec <- as.data.table(dbGetQuery(con, sprintf("SELECT Timestep, TransitionGroup, Area FROM lucasCore_OutputTransitionSummary WHERE ScenarioId = %d", build)))
  sim <- as.data.table(dbGetQuery(con, sprintf("SELECT o.Timestep, g.Name AS TransitionGroup, SUM(o.Amount) / 100.0 / COUNT(DISTINCT o.Iteration) AS Sim FROM stsim_OutputStratumTransition o JOIN stsim_TransitionGroup g ON g.TransitionGroupId = o.TransitionGroupId WHERE o.ScenarioId = %d GROUP BY 1, 2", rid)))
  if (!nrow(rec) || !nrow(sim)) return(data.table())
  # the record holds a mix of groups and [Type] groups: both roll up to the family, the name before the colon, which is itself a simulated group
  rec[, Family := sub(":.*$", "", TransitionGroup)]
  x <- merge(sim[TransitionGroup %in% rec$Family, .(Simulated = sum(Sim), Y0 = min(Timestep), Y1 = max(Timestep)), by = .(Family = TransitionGroup)],
             rec[Timestep %in% sim$Timestep, .(Recorded = sum(Area)), by = Family], by = "Family")
  setnames(x, "Family", "TransitionGroup"); x[Recorded > 0][order(-Recorded)] }

# A run's tables against its maps: each year's mapped area and Total Ecosystem carbon, computed from the maps of the first iteration
rl_map_table_check <- function(con, files, rid, cell_ha) {
  suppressPackageStartupMessages(library(terra))
  y <- files[Variable == "state-class", Year]; if (!length(y)) return(list(ok = NA, detail = "no state class maps"))
  y <- y[length(y)]; sc <- files[Variable == "state-class" & Year == y][1]
  area <- dbGetQuery(con, sprintf("SELECT SUM(Amount) a FROM stsim_OutputStratumState WHERE ScenarioId = %d AND Iteration = %d AND Timestep = %d", rid, sc$Iteration, y))$a
  mapped <- global(!is.na(rast(sc$Path)), "sum", na.rm = TRUE)[1, 1] * cell_ha
  d <- abs(mapped - area) / area
  list(ok = d < 1e-6, detail = sprintf("%d: %.0f ha in the table, %.0f ha in the state class map", y, area, mapped)) }

# ---- the records ----------------------------------------------------------------------------------------------------------
# One entity per exported file: number columns carry the range actually found, the others the dictionary's domain
rl_entity <- function(dict, file, stats = NULL, label = file) {
  cols <- md_columns(dict, file); if (!nrow(cols)) stop("no dictionary rows for ", file)
  list(label = label, definition = sprintf("Columns of %s.", label), defsrc = "lucasCore data-dictionary.csv",
       attrs = lapply(seq_len(nrow(cols)), function(i) { c1 <- cols[i]; r <- stats$ranges[[c1$Column]]
         dom <- if (!is.null(r) && all(is.finite(r))) list(type = "range", min = format(r[1], scientific = FALSE, trim = TRUE), max = format(r[2], scientific = FALSE, trim = TRUE), units = c1$Units)
                else list(type = "unrep", text = c1$Domain %||% "Free text.")
         list(label = c1$Column, definition = paste0(c1$Definition, if (!is.na(c1$NullValue)) sprintf(" No data: %s.", c1$NullValue) else ""), defsrc = "lucasCore", domain = dom) })) }

rl_model_source <- function(x) {
  list(abbrev = "Model record", citation = x$citation, typesrc = "Online", time = substr(x$metadata$date, 1, 8), current = "publication date",
       contribution = "The Build this run simulates: its inputs, their sources and every Build stage. See model/model.xml.") }

# The first state class map's enumerated codes
rl_state_entity <- function(defs, dict, label) {
  d <- defs[kind == "StateClass" & !is.na(code)]; cols <- md_columns(dict, label)
  list(label = label, definition = cols$Definition[1], defsrc = "lucasCore", attrs = list(list(label = "Value", definition = cols$Definition[1], defsrc = "lucasCore",
    domain = list(type = "enum", values = lapply(seq_len(nrow(d)), function(i) list(value = as.character(d$code[i]), definition = paste0(d$name[i], ": ", d$definition[i] %||% "not defined"), source = "lucasCore definitions.csv")))))) }

rl_run_content <- function(model, run, facts, tables, maps, cmp, runlog, defs, dict, where) {
  x <- model; h <- run$kind == "historical"; yrs <- run$years; nit <- run$iterations[2]
  x$citation$title <- sprintf("LUCAS %s simulation \"%s\" of %s, %s-%s", run$kind, run$name, where, yrs[1], yrs[2])
  x$abstract <- paste(sprintf("This record describes the outputs of one %s simulation of land use and carbon in %s, %s to %s, %s Monte Carlo iteration%s, on the LUCAS model described in the model record.", run$kind, where, yrs[1], yrs[2], nit, if (nit > 1) "s" else ""),
                      "Tables give area by state class, area by transition group, carbon by stock group and carbon by flow group for each year and stratum; maps give the same variables by model cell where the run wrote them.")
  x$purpose <- "To make the outputs of the simulation available with the settings and inputs that produced them."
  x$supplinf <- sprintf("Result scenario \"%s\" (id %s) of the SyncroSim library \"%s\". Run time %s.", run$name, run$id, facts$lib, runlog$total %||% "not recorded")
  x$time <- list(begdate = as.character(yrs[1]), enddate = as.character(yrs[2]), current = "model output")
  x$draft <- c(setdiff(model$draft, c("drafted: title", "drafted: abstract", "drafted: purpose")), sprintf("drafted: title, abstract, purpose of %s", run$slug))
  x$notes <- model$notes[0]

  attracc <- if (!h) "This is a projection: its years have no record to compare with."
    else if (!nrow(cmp)) "No record of transition areas to compare with."
    else paste0("Area of each transition group simulated by this run against the record the Build read (Transition Summary), ", cmp$Y0[1], "-", cmp$Y1[1], ", in square kilometers: ",
                paste(sprintf("%s %s simulated, %s recorded", cmp$TransitionGroup, format(round(cmp$Simulated), big.mark = ",", trim = TRUE), format(round(cmp$Recorded), big.mark = ",", trim = TRUE)), collapse = "; "), ".")
  rows <- vapply(tables, function(s) sprintf("%s %s rows", s$file, format(s$rows, big.mark = ",", trim = TRUE)), "")
  vars <- if (nrow(maps)) paste(sprintf("%s (%d maps)", maps[, .(N = sum(Maps)), by = Variable]$Variable, maps[, .(N = sum(Maps)), by = Variable]$N), collapse = ", ") else "none"
  x$quality <- list(attracc = attracc,
    logic = "Every column written is the data dictionary's, checked by name when the release was written. The checksums are in contents.csv. Validation checks on the Build are in the model record.",
    complete = sprintf("Tables: %s, every year and iteration. Maps the run wrote: %s. A cell's value is -9999 outside the study area. Group maps of stocks and flows are the mean across iterations.", paste(rows, collapse = "; "), vars),
    horizpa = x$quality$horizpa, sources = list(rl_model_source(model)),
    steps = lapply(runlog$stages, function(s) list(desc = paste0(s$name, " (lucasCore ", runlog$lucasCore %||% "?", ", ST-Sim ", runlog$stsim %||% "?", ", SyncroSim ", runlog$syncrosim %||% "?", "). ", run$settings, " ", if (startsWith(s$name, "ST-Sim")) "" else md_sentences(s$lines[!startsWith(s$lines, "[")])), srcused = "Model record", date = runlog$date %||% format(Sys.Date(), "%Y%m%d"))))
  r_of <- function(v) { m <- maps[Variable == v]; list(ranges = list(value = c(min(m$Min), max(m$Max)))) }
  ent <- lapply(tables, function(s) rl_entity(dict, s$file, s))
  if (nrow(maps[Variable == "state-class"])) ent <- c(ent, list(rl_state_entity(defs, dict, "state-class-<run>-<year>.tif")))
  for (p in list(c("age", "age-<run>-<year>.tif"), c("transition", "transition-<group>-<run>-<year>.tif"), c("carbon", "carbon-<group>-<run>-<year>.tif"), c("flow", "flow-<group>-<run>-<year>.tif")))
    if (nrow(maps[Variable == p[1]])) ent <- c(ent, list(rl_entity(dict, p[2], r_of(p[1]))))
  x$entities <- ent
  x$overview$eaover <- "Names in the tables and codes in the maps are defined in definitions.csv, and columns in data-dictionary.csv, in the release's model folder."
  x$distribution$formname <- "CSV; zip of cloud-optimized GeoTIFF; PNG"
  x }

# The parent record: the release as a whole
# The Release Information page and its people, as fields of record-defaults.csv and of the parent record (Phase 4). sid: the scenario holding the page
rl_read_info <- function(con, sid) {
  sid <- as.integer(sid); info <- list()
  got <- function(t) dbExistsTable(con, t)
  if (got("lucasCore_ReleaseInformation")) { i <- dbGetQuery(con, sprintf("SELECT * FROM lucasCore_ReleaseInformation WHERE ScenarioId = %d", sid))
    if (nrow(i)) info <- lapply(as.list(i[1, setdiff(names(i), c("ScenarioId", "ReleaseInformationId")), drop = FALSE]), as.character) }
  code <- suppressWarnings(as.integer(info$ReleaseStatus %||% NA)); info$ReleaseStatus <- if (is.na(code)) "Draft" else c("Draft", "Provisional", "Approved")[code]
  blank <- function(v) length(v) != 1 || is.na(v) || !nzchar(trimws(v))
  if (got("lucasCore_Person") && got("lucasCore_ReleaseOriginator")) {
    o <- dbGetQuery(con, sprintf("SELECT p.* FROM lucasCore_ReleaseOriginator o JOIN lucasCore_Person p ON p.PersonId = o.PersonId WHERE o.ScenarioId = %d ORDER BY o.SortOrder IS NULL, o.SortOrder, o.ReleaseOriginatorId", sid))
    if (nrow(o)) { info$Originator <- paste(o$Name, collapse = "; ")
      who <- vapply(seq_len(nrow(o)), function(k) paste(c(o$Name[k], if (!blank(o$Organization[k])) o$Organization[k], if (!blank(o$Orcid[k])) paste("ORCID", o$Orcid[k])), collapse = ", "), "")
      if (any(!is.na(o$Orcid) | !is.na(o$Organization))) info$Credit <- sub("[.]*$", ".", paste0("Originators: ", paste(who, collapse = "; "))) }
    if (!blank(info$ContactPersonId)) { p <- dbGetQuery(con, sprintf("SELECT * FROM lucasCore_Person WHERE PersonId = %d", as.integer(info$ContactPersonId)))
      if (nrow(p)) { map <- c(ContactPerson = "Name", ContactOrg = "Organization", ContactAddress = "Address", ContactCity = "City", ContactState = "State", ContactPostal = "PostalCode", ContactPhone = "Phone")
        for (f in names(map)) info[[f]] <- as.character(p[[map[[f]]]][1])
        if (blank(info$ContactEmail)) info$ContactEmail <- as.character(p$Email[1]) } } }
  info }

rl_no_id <- function(x) { x$theme <- Filter(function(t) t$thesaurus != "USGS Metadata Identifier", x$theme); x }

# What is still to supply for the whole release: the placeholders, and the release text the generator drafted
rl_to_supply <- function(model, info) {
  d <- setdiff(model$draft, c("drafted: title", "drafted: abstract", "drafted: purpose"))
  for (k in c("Title", "Abstract", "Purpose")) if (!md_supplied(info, k)) d <- c(d, paste("drafted: release", tolower(k)))
  if (!md_supplied(info, "IpdsNumber")) d <- c(d, "to supply: IpdsNumber")
  d }

rl_parent_content <- function(model, runs, where, info = NULL) {
  x <- model; y0 <- min(vapply(runs, function(r) r$years[1], 0)); y1 <- max(vapply(runs, function(r) r$years[2], 0))
  x$citation$title <- sprintf("LUCAS simulations of land use and carbon in %s, %s-%s", where, y0, y1)
  x$abstract <- paste(sprintf("This data release holds %d simulation%s of land use and carbon in %s made with the LUCAS model (lucasCore package for ST-Sim in SyncroSim): %s.", length(runs), if (length(runs) > 1) "s" else "", where,
                              paste(vapply(runs, function(r) sprintf("%s (%s, %s-%s)", r$name, r$kind, r$years[1], r$years[2]), ""), collapse = "; ")),
                      "It holds the model record, each simulation's tables and maps with its own record, the figures and the model archive.")
  x$purpose <- "To make the simulations available with the model, inputs and settings that produced them."
  x$supplinf <- "See README.txt for the folders and contents.csv for every file, with its size and SHA-256 checksum."
  if (md_supplied(info, "Title")) x$citation$title <- trimws(info$Title)
  if (md_supplied(info, "Abstract")) x$abstract <- trimws(info$Abstract)
  if (md_supplied(info, "Purpose")) x$purpose <- trimws(info$Purpose)
  if (md_supplied(info, "RevisionNotes")) x$supplinf <- paste0(x$supplinf, " Revision notes: ", trimws(info$RevisionNotes))
  if (md_supplied(info, "AssociatedPublications")) x$supplinf <- paste0(x$supplinf, " Associated publications: ", trimws(info$AssociatedPublications))
  x$time <- list(begdate = as.character(y0), enddate = as.character(y1), current = "model output")
  x$draft <- c(setdiff(model$draft, c("drafted: title", "drafted: abstract", "drafted: purpose")), "drafted: release title, abstract, purpose")
  x$quality$sources <- list(rl_model_source(model)); x$quality$steps <- list(list(desc = "The release folder was written by the lucasCore Data Release stage from the simulations' result scenarios.", srcused = "Model record", date = format(Sys.Date(), "%Y%m%d")))
  x$quality$attracc <- "See each simulation's record."; x$quality$logic <- "See each simulation's record."
  x$quality$complete <- "Every simulation named in the abstract, whole, with the products listed in contents.csv."
  x$entities <- list(); x$overview$eaover <- "Each table and map is described in its simulation's record; names and codes in model/definitions.csv and columns in model/data-dictionary.csv."
  x$distribution$formname <- "CSV; zip of cloud-optimized GeoTIFF; PNG; XML"
  x }

# ---- figures --------------------------------------------------------------------------------------------------------------
# The results to take figures and comparisons from, the newest of each: Build Figures on this Build, Run Figures of a released run, and a
# comparison of released runs only
rl_find_results <- function(con, build, runs) {
  ids <- paste(runs, collapse = ",")
  q <- function(s, ...) dbGetQuery(con, sprintf(s, ...))
  has <- function(t) dbExistsTable(con, t)
  bf <- if (has("lucasCore_OutputBuildFigure")) q("SELECT MAX(f.ScenarioId) id FROM lucasCore_OutputBuildFigure f JOIN core_ScenarioResult r ON r.ResultId = f.ScenarioId JOIN core_ScenarioDependency d ON d.ScenarioId = r.ScenarioId WHERE d.DependencyId = %d", build)$id else NA
  rf <- if (has("lucasCore_OutputRunFigure")) q("SELECT MAX(ScenarioId) id FROM lucasCore_OutputRunFigure WHERE RunScenarioId IN (%s) GROUP BY RunScenarioId", ids)$id else integer()
  cf <- integer()
  if (has("lucasCore_OutputCompareFigure") && has("lucasCore_CompareRunOptions")) for (i in sort(unique(q("SELECT ScenarioId FROM lucasCore_OutputCompareFigure")$ScenarioId), decreasing = TRUE)) {
    if (all(q("SELECT RunScenarioId FROM lucasCore_CompareRunOptions WHERE ScenarioId = %d", i)$RunScenarioId %in% runs)) { cf <- i; break } }
  list(build = bf[!is.na(bf)], run = rf, compare = cf) }

# Figures of the listed results, each sent to the folder its result belongs to
rl_copy_figures <- function(con, data, ids, where_run) {
  have <- function(t) dbExistsTable(con, t); got <- character()
  for (id in ids) for (t in c("lucasCore_OutputBuildFigure", "lucasCore_OutputRunFigure", "lucasCore_OutputCompareFigure")) { if (!have(t)) next
    d <- as.data.table(dbGetQuery(con, sprintf("SELECT * FROM %s WHERE ScenarioId = %d", t, id))); if (!nrow(d)) next
    for (i in seq_len(nrow(d))) { out <- where_run(t, d[i])
      if (is.null(out)) next
      dir.create(out, showWarnings = FALSE, recursive = TRUE)
      f <- file.path(data, sprintf("Scenario-%d", id), t, basename(d$FileName[i]))
      if (file.exists(f)) { file.copy(f, file.path(out, tolower(basename(f))), overwrite = TRUE); got <- c(got, file.path(out, tolower(basename(f)))) } } }
  got }

# ---- the comparison -------------------------------------------------------------------------------------------------------
# The comparison result's two tables, with the run's short name for its id and the dictionary's column names
RL_COMPARE <- list("compare-carbon.csv" = c(table = "lucasCore_OutputCompareCarbon", role = "Role", start_year = "StartYear", end_year = "EndYear", carbon_start = "CarbonStart", carbon_end = "CarbonEnd", carbon_change = "CarbonChange", vs_baseline = "VsBaseline", biomass_change = "BiomassChange", dom_soil_change = "DomSoilChange", npp = "NPP", nep = "NEP", lulc_loss = "LulcLoss", nbp = "NBP"),
                   "compare-land.csv" = c(table = "lucasCore_OutputCompareLand", role = "Role", start_year = "StartYear", end_year = "EndYear", fire = "Fire", harvest = "Harvest", urbanization = "Urbanization", forest_change = "ForestChange", developed_change = "DevelopedChange"))
rl_write_compare <- function(con, id, runs, out, dict) {
  dir.create(out, showWarnings = FALSE, recursive = TRUE)
  lapply(names(RL_COMPARE), function(f) { m <- RL_COMPARE[[f]]; t <- m[["table"]]; m <- m[names(m) != "table"]
    d <- as.data.table(dbGetQuery(con, sprintf("SELECT * FROM %s WHERE ScenarioId = %d", t, id)))
    slug <- vapply(d$RunScenarioId, function(r) { w <- Filter(function(x) x$id == r, runs); if (length(w)) w[[1]]$slug else sprintf("result-%d", r) }, "")
    e <- data.table(run = slug); for (k in names(m)) set(e, j = k, value = d[[m[[k]]]])
    fwrite(e, file.path(out, f), na = "NA")
    num <- setdiff(names(e), c("run", "role")); rng <- list(); for (k in num) if (any(!is.na(e[[k]]))) rng[[k]] <- range(e[[k]], na.rm = TRUE)
    list(file = f, path = file.path(out, f), rows = nrow(e), ranges = rng, columns = names(e)) }) }

rl_compare_content <- function(parent, stats, dict, where, runs) {
  x <- rl_no_id(parent); x$citation$title <- sprintf("Comparison of LUCAS simulations of %s", where)
  x$abstract <- paste0("Figures and summary tables comparing these simulations: ", paste(vapply(runs, `[[`, "", "name"), collapse = "; "), ".")
  x$purpose <- "To set the simulations side by side."; x$supplinf <- NA_character_
  x$quality$complete <- "One row per simulation in each table."; x$entities <- lapply(stats, function(s) rl_entity(dict, s$file, s))
  x }

# ---- the model archive ----------------------------------------------------------------------------------------------------
rl_archive <- function(lib, out, console) {
  dir.create(out, showWarnings = FALSE, recursive = TRUE); bk <- paste0(lib, ".backup"); before <- if (dir.exists(bk)) list.files(bk, full.names = TRUE) else character()
  st <- system2(console, c("--backup", sprintf("--lib=\"%s\"", lib), "--extdata"), stdout = TRUE, stderr = TRUE)
  new <- setdiff(if (dir.exists(bk)) list.files(bk, full.names = TRUE) else character(), before)
  if (!length(new)) stop("no backup written: ", paste(st, collapse = " "))
  for (f in new) { ok <- file.rename(f, file.path(out, basename(f))); if (!ok) { file.copy(f, file.path(out, basename(f))); unlink(f) } }
  writeLines(c("How to rerun these simulations", "",
    "1. Install SyncroSim, its stsim package and the lucasCore version named in the records.",
    "2. Restore the .ssimbak backup in this folder into a new library (SyncroSim Studio, File menu).",
    "3. Open the library. The result scenarios named in the records hold these runs; their parent scenarios hold the settings.",
    "4. Run a parent scenario to repeat a simulation. Land change is stochastic, so a rerun gives a new draw from the same model."), file.path(out, "how-to-rerun.txt"))
  file.path(out, basename(new)) }

# ---- the whole release ----------------------------------------------------------------------------------------------------
rl_write_xml <- function(x, f) { dir.create(dirname(f), showWarnings = FALSE, recursive = TRUE); xml2::write_xml(md_csdgm(x), f); f }

rl_readme <- function(parent, runs, draft, out) { there <- function(...) dir.exists(file.path(out, ...)); c(
  parent$citation$title, strrep("=", nchar(parent$citation$title)), "",
  strwrap(parent$abstract, 90), "",
  if (length(draft)) c("DRAFT: this folder is not ready to publish. Still to supply:", paste0("  - ", draft), "") else character(),
  "Folders", "-------", "release.xml       the parent metadata record (FGDC CSDGM)", "contents.csv      every file, with its size and SHA-256 checksum",
  "model/            the Build: model.xml, definitions.csv, data-dictionary.csv, validation.csv, data-sources-used.csv, figures",
  vapply(runs, function(r) sprintf("%-17s %s, %s-%s: run.xml, %s", paste0(r$folder, "/", r$slug, "/"), r$kind, r$years[1], r$years[2],
    paste(c("tables/", if (there(r$folder, r$slug, "maps")) "maps/", if (there(r$folder, r$slug, "figures")) "figures/"), collapse = ", ")), ""),
  if (there("comparison")) "comparison/       comparison figures and tables, where the runs were compared",
  if (there("archive")) "archive/          the SyncroSim library backup and how to rerun it", "",
  if (any(vapply(runs, function(r) there(r$folder, r$slug, "maps"), TRUE))) c("Maps: each zip in maps/ holds one variable's yearly cloud-optimized GeoTIFFs, EPSG:5070, no data -9999.", "File names give the variable, the group, the run and the year.", ""),
  "How to cite: see the citation in release.xml.") }

rl_contents <- function(out, rows = list()) {
  f <- list.files(out, recursive = TRUE, all.files = FALSE); f <- f[f != "contents.csv"]
  d <- data.table(file = f, product = sub("/.*$", "", f), bytes = file.size(file.path(out, f)))
  d[!grepl("/", file), product := "release"]
  d[, sha256 := vapply(file.path(out, file), function(p) digest::digest(file = p, algo = "sha256"), "")]
  fwrite(d, file.path(out, "contents.csv")); d }

# content checks (the mp check comes on top). Each row: Check, Pass, Detail
RL_DRAFT_CHECK <- "no placeholder or drafted text is left"   # a Draft release lists it; stage 17 fails on it for Provisional and Approved
rl_checks <- function(contents, defs, stats_issues, xml, draft, maps_check) {
  a <- function(check, pass, detail = "") data.table(Check = check, Pass = isTRUE(pass), Detail = paste(detail, collapse = "; "))
  by_item <- contents[, .N, by = .(item = sub("^([^/]+/[^/]+)/.*$", "\\1", file))]; big <- contents[bytes > 30e9]
  undef <- defs[is.na(definition)]; raw <- unlist(lapply(xml, readLines, warn = FALSE))
  rbind(a("every table's columns match the data dictionary", !length(stats_issues), stats_issues),
        a("every name has a definition", !nrow(undef), if (nrow(undef)) sprintf("%d names without one: %s", nrow(undef), paste(head(undef$name, 8), collapse = ", ")) else ""),
        a("a table's area matches its state class map", all(unlist(maps_check$ok) %in% c(TRUE, NA)), unlist(maps_check$detail)),
        a("no folder holds more than ScienceBase's 100 files", max(by_item$N) <= 100, paste(by_item[N > 100, sprintf("%s: %d", item, N)], collapse = ", ")),
        a("no file passes ScienceBase's 30 GB", !nrow(big), big$file),
        a("no machine path in a record", !any(grepl("[A-Za-z]:[/\\\\][A-Za-z]", raw)), head(grep("[A-Za-z]:[/\\\\][A-Za-z]", raw, value = TRUE), 3)),
        a(RL_DRAFT_CHECK, !length(draft), draft)) }

rl_release <- function(lib, build, runs, out, dir, every = 1L, years = NULL, maps = TRUE, archive = TRUE, console = NA_character_, say = message, info_scenario = NA_integer_) {
  lib <- normalizePath(lib, winslash = "/"); data <- paste0(lib, ".data"); dict <- md_dictionary(dir)
  dir.create(out, showWarnings = FALSE, recursive = TRUE)
  con <- rl_ro(lib); on.exit(dbDisconnect(con))
  info <- if (is.na(info_scenario)) NULL else rl_read_info(con, info_scenario)
  facts <- md_build_facts(lib, build); whole <- md_model_content(facts, dir, info); model <- rl_no_id(whole)
  R <- rl_unique_slugs(lapply(runs, function(r) rl_run_info(con, r)))
  where <- paste(sub("^[^:]+: ", "", facts$study_area), collapse = ", "); if (!nzchar(where)) where <- "the conterminous United States"
  home_mp <- md_mp_default(facts$home); xml <- character(); issues <- character(); checks <- list(ok = list(), detail = list())

  # the model
  mdir <- file.path(out, "model"); dir.create(mdir, showWarnings = FALSE)
  defs <- rl_definitions(con, dir, runs); fwrite(defs, file.path(mdir, "definitions.csv"), na = "NA"); fwrite(dict, file.path(mdir, "data-dictionary.csv"), na = "NA")
  fwrite(setnames(facts$validation[, .(Stage, Check, Status, Detail)], tolower), file.path(mdir, "validation.csv"), na = "NA")
  su <- facts$sources_used
  if (nrow(su)) fwrite(su[, .(stage = Stage, data_source = DataSource, origin = Origin, files = Files, bytes = Bytes, sha256 = Sha256, note = Note)], file.path(mdir, "data-sources-used.csv"), na = "NA")
  xml <- c(xml, rl_write_xml(model, file.path(mdir, "model.xml")))
  say(sprintf("Model: definitions of %d names; record model.xml", nrow(defs)))

  # the runs
  L <- suppressWarnings(rsyncrosim::ssimLibrary(lib))
  for (r in R) { d <- file.path(out, r$folder, r$slug); tb <- file.path(d, "tables"); dir.create(tb, showWarnings = FALSE, recursive = TRUE)
    say(sprintf("Run %d (%s): %s-%s", r$id, r$slug, r$years[1], r$years[2]))
    st <- lapply(c("state-classes.csv", "transitions.csv", "stocks.csv", "flows.csv"), function(t) rl_write_table(con, t, r$id, r$slug, tb))
    issues <- c(issues, rl_check_tables(st, dict))
    say(paste(vapply(st, function(s) sprintf("%s %s rows", s$file, format(s$rows, big.mark = ",", trim = TRUE)), ""), collapse = ", "))
    y <- if (!is.null(years)) years else if (every > 1L) unique(c(seq(r$years[1], r$years[2], by = every), r$years[2])) else NULL
    fm <- rl_map_files(data, r$id, y)
    m <- if (maps) rl_write_maps(fm, con, r$slug, file.path(d, "maps"), say) else data.table(Variable = character(), Maps = integer(), Min = numeric(), Max = numeric())
    if (maps) say(sprintf("%d map zips, %d maps", nrow(m), sum(m$Maps)))
    k <- rl_map_table_check(con, fm, r$id, facts$grid$cell^2 / 1e4); checks$ok <- c(checks$ok, k$ok); checks$detail <- c(checks$detail, sprintf("%s: %s", r$slug, k$detail))
    invisible(capture.output(rl <- rsyncrosim::runLog(rsyncrosim::scenario(L, r$id)))); lg <- md_parse_log(unlist(strsplit(paste(rl, collapse = "\n"), "\r?\n")))
    cmp <- if (r$kind == "historical") rl_transition_compare(con, build, r$id) else data.table()
    xml <- c(xml, rl_write_xml(rl_run_content(model, r, facts, st, m, cmp, lg, defs, dict, where), file.path(d, "run.xml")))
  }

  # figures, each with its run
  loc <- function(t, row) { if (t == "lucasCore_OutputBuildFigure") return(file.path(mdir, "figures"))
    if (t == "lucasCore_OutputCompareFigure") return(file.path(out, "comparison", "figures"))
    w <- Filter(function(r) identical(as.integer(r$id), as.integer(row$RunScenarioId)), R); if (length(w)) file.path(out, w[[1]]$folder, w[[1]]$slug, "figures") else NULL }
  found <- rl_find_results(con, build, runs)
  fig <- rl_copy_figures(con, data, unlist(found), loc); say(sprintf("%d figures copied, from results %s", length(fig), paste(unlist(found), collapse = ", ")))

  # the parent, the archive, the readme and the contents
  parent <- rl_parent_content(whole, R, where, info); xml <- c(xml, rl_write_xml(parent, file.path(out, "release.xml")))
  if (length(found$compare)) { cs <- rl_write_compare(con, found$compare, R, file.path(out, "comparison"), dict); issues <- c(issues, rl_check_tables(cs, dict))
    xml <- c(xml, rl_write_xml(rl_compare_content(parent, cs, dict, where, R), file.path(out, "comparison", "comparison.xml"))) }
  if (archive) { a <- rl_archive(lib, file.path(out, "archive"), console); say(sprintf("Model archive: %s", paste(basename(a), collapse = ", "))) }
  draft <- unique(rl_to_supply(model, info)); writeLines(rl_readme(parent, R, draft, out), file.path(out, "README.txt"))
  contents <- rl_contents(out); chk <- rl_checks(contents, defs, issues, xml, draft, checks)
  mp <- rbindlist(lapply(xml, function(f) { m <- md_mp(f, home_mp); if (is.null(m) || !nrow(m)) NULL else cbind(Record = sub(paste0(out, "/"), "", f, fixed = TRUE), m) }))
  if (!nrow(mp)) mp <- data.table(Record = character(), Level = character(), Message = character())   # none found: no NA row, and sum(Level == "Error") is 0
  list(out = out, runs = R, contents = contents, checks = chk, mp = mp, records = xml, draft = draft, status = info$ReleaseStatus %||% "Draft", ipds = info$IpdsNumber %||% NA_character_, mp_found = !is.na(home_mp) && file.exists(home_mp)) }
