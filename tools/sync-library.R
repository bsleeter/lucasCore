# =============================================================================
# sync-library.R - bring a library made with an earlier lucasCore up to date with the current package (columns, stages, definitions)
# =============================================================================
# SyncroSim adds a new datasheet's table when a library opens, but not a new column in an existing table (the library then fails to
# open: "no such column"), and it lists only the stages that existed when the library was made. Without a package version bump and
# its update XML, this does both from the current starter (Starter/LUCAS Core (CONUS).ssim, built by tools/build_starter.R from this
# package), which is the reference schema:
#   1. a copy of the library first (<library>.ssim.bak-<date-time>)
#   2. every column of a lucasCore_ / stsim_ / core_ table in the starter that the library's table lacks: ALTER TABLE ADD COLUMN
#   3. every lucasCore transformer and stage name the library lacks, with its stage value: new ids from the library's own id counter
#      (core_Sequence)
#   4. project definitions the package defaults gained (stsim State Attribute Types): added through rsyncrosim
#   5. the stock group memberships of non-result scenarios (the Stock-Flow Definitions scenario), set to the package defaults
# Close the library in SyncroSim Studio first. Usage: Rscript tools/sync-library.R <library.ssim> [--dry-run]
# =============================================================================
suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(data.table) })
a <- commandArgs(TRUE); pos <- a[!grepl("^--", a)]; dry <- "--dry-run" %in% a
if (!length(pos)) stop("usage: Rscript tools/sync-library.R <library.ssim> [--dry-run]")
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
pkg <- normalizePath(file.path(here, ".."), winslash = "/"); ref_f <- file.path(pkg, "Starter", "LUCAS Core (CONUS).ssim")
f <- normalizePath(pos[1], winslash = "/"); if (!file.exists(ref_f)) stop("build the starter first: Rscript tools/build_starter.R")
if (!dry) { bak <- sprintf("%s.bak-%s", f, format(Sys.time(), "%Y%m%d-%H%M")); file.copy(f, bak); cat("backup:", bak, "\n") }
ref <- dbConnect(SQLite(), ref_f, flags = SQLITE_RO); con <- dbConnect(SQLite(), f)
on.exit({ dbDisconnect(ref); dbDisconnect(con) })
cols <- function(cn, t) as.data.table(dbGetQuery(cn, sprintf("PRAGMA table_info('%s')", t)))

# ---- 2. missing columns ---------------------------------------------------------------------------------------------------
tl <- intersect(grep("^(lucasCore|stsim|core)_", dbListTables(ref), value = TRUE), dbListTables(con)); added <- 0
dbBegin(con)
for (t in tl) { rc <- cols(ref, t); lc <- cols(con, t); miss <- rc[!tolower(name) %in% tolower(lc$name)]
  for (i in seq_len(nrow(miss))) { sql <- sprintf('ALTER TABLE "%s" ADD COLUMN "%s" %s', t, miss$name[i], if (nzchar(miss$type[i])) miss$type[i] else "")
    cat(if (dry) "would add" else "add", t, ".", miss$name[i], miss$type[i], "\n"); if (!dry) dbExecute(con, sql); added <- added + 1 } }

# ---- 3. missing transformers and stage names -----------------------------------------------------------------------------
rt <- as.data.table(dbGetQuery(ref, "SELECT * FROM core_Transformer WHERE PackageName = 'lucasCore'")); lt <- as.data.table(dbGetQuery(con, "SELECT * FROM core_Transformer"))
rs <- as.data.table(dbGetQuery(ref, "SELECT * FROM core_StageName")); proj <- dbGetQuery(con, "SELECT ProjectId FROM core_Project")$ProjectId
new_id <- function() { dbExecute(con, "INSERT INTO core_Sequence (Value) VALUES (0)"); dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id }
nst <- 0
for (i in which(!rt$Name %in% lt$Name)) for (p in proj) {
  cat(if (dry) "would add stage" else "add stage", rt$DisplayName[i], "(project", p, ")\n"); if (dry) next
  tr <- rt[i]; tr$TransformerId <- new_id(); tr$ProjectId <- p; dbWriteTable(con, "core_Transformer", as.data.frame(tr), append = TRUE)
  sn <- rs[TransformerId == rt$TransformerId[i]]
  if (nrow(sn)) { sn$StageNameId <- new_id(); sn$ProjectId <- p; sn$TransformerId <- tr$TransformerId; dbWriteTable(con, "core_StageName", as.data.frame(sn), append = TRUE) }
  nst <- nst + 1 }
# every stage also needs its core_StageValue row, or SyncroSim skips it silently when it is in a pipeline (the run completes in 0 s
# doing nothing); this also repairs stages added by earlier versions of this script, which wrote none
miss_sv <- as.data.table(dbGetQuery(con, "SELECT s.StageNameId, s.ProjectId, s.TransformerId, s.IsAuto, s.Name FROM core_StageName s
  JOIN core_Transformer t ON t.TransformerId = s.TransformerId WHERE t.PackageName = 'lucasCore'
  AND NOT EXISTS (SELECT 1 FROM core_StageValue v WHERE v.StageNameId = s.StageNameId)"))
for (i in seq_len(nrow(miss_sv))) { cat(if (dry) "would add stage value for" else "add stage value for", miss_sv$Name[i], "\n"); if (dry) next
  dbWriteTable(con, "core_StageValue", data.frame(StageValueId = new_id(), ProjectId = miss_sv$ProjectId[i], StageNameId = miss_sv$StageNameId[i],
                                                  TransformerId = miss_sv$TransformerId[i], RunOrder = NA_integer_, IsAuto = miss_sv$IsAuto[i]), append = TRUE) }
if (dry) dbRollback(con) else dbCommit(con)
cat(sprintf("%s %d column(s) and %d stage(s)\n", if (dry) "would add" else "added", added, nst))

# ---- 4. project definitions the package defaults gained --------------------------------------------------------------------
if (!dry) { dbDisconnect(con); on.exit(dbDisconnect(ref))
  suppressPackageStartupMessages(library(rsyncrosim))
  L <- ssimLibrary(f); P <- rsyncrosim::project(L, "Definitions")
  sat <- as.data.table(datasheet(P, "stsim_StateAttributeType")); want <- fread(file.path(pkg, "defaults", "stsim", "stsim_StateAttributeType.csv"), na.strings = "")
  miss <- want[!Name %in% sat$Name]
  if (nrow(miss)) { saveDatasheet(P, as.data.frame(miss[, intersect(names(miss), names(sat)), with = FALSE]), "stsim_StateAttributeType", append = TRUE)
    cat("added State Attribute Types:", paste(miss$Name, collapse = ", "), "\n") } else cat("State Attribute Types up to date\n")
  # ---- 5. stock group memberships of non-result scenarios (the Stock-Flow Definitions scenario) -----------------------------------
  # stage 0 writes the package's memberships only into a Build without them; a library made by new-library.R carries its own copy in the
  # Stock-Flow Definitions scenario, so a change of the package's groups (2026-10-26: DOM: Litter = the forest floor incl. AG Slow, as
  # FIADB) is copied here. Results keep the groups they ran with until re-run.
  sm <- as.data.table(scenario(L, summary = TRUE)); want_m <- fread(file.path(pkg, "defaults", "stockflow", "stsim_StockTypeGroupMembership.csv"), na.strings = "")
  key <- function(d) sort(paste(d$StockTypeId, d$StockGroupId))
  for (sid in sm[IsResult == "No", ScenarioId]) { S <- scenario(L, sid)
    have_m <- as.data.table(datasheet(S, "stsim_StockTypeGroupMembership", lookupsAsFactors = FALSE, optional = TRUE))
    if (!nrow(have_m) || identical(key(have_m), key(want_m))) next
    saveDatasheet(S, as.data.frame(want_m[, .(StockTypeId, StockGroupId)]), "stsim_StockTypeGroupMembership", append = FALSE)
    cat(sprintf("stock group memberships of scenario %d (%s) updated to the package's (%d rows)\n", sid, sm[ScenarioId == sid, Name], nrow(want_m))) }
  # ---- 6. Carbon Assumptions (to-do 21, 2026-10-27): the CBM ecozone and species type lists, and a Carbon Assumptions scenario with the
  # package's CBM Crosswalk when the project has none (as tools/new-library.R makes). Builds use it once it is one of their dependencies.
  for (sh in c("lucasCore_CbmEcozone", "lucasCore_CbmSpeciesType")) if (!nrow(suppressWarnings(datasheet(P, sh, optional = TRUE)))) {
    v <- fread(file.path(pkg, "defaults", "library", "project", paste0(sh, ".csv")), colClasses = "character"); saveDatasheet(P, as.data.frame(v), sh, append = FALSE, force = TRUE)
    cat(sprintf("%s: %d rows added\n", sh, nrow(v))) }
  sm <- as.data.table(scenario(L, summary = TRUE))
  if (!"Carbon Assumptions" %in% sm$Name) { ca <- scenario(P, "Carbon Assumptions"); v <- fread(file.path(pkg, "defaults", "cbm", "species-crosswalk.csv"), colClasses = "character")
    saveDatasheet(ca, data.frame(StateClassId = v$StateClassId, CbmEcozoneId = v$EcoBoundaryId, CbmSpeciesTypeId = v$SpeciesTypeId), "lucasCore_CbmCrosswalk")
    description(ca) <- "The assumptions behind the carbon calibration (docs/carbon-assumptions.md), filled with the package defaults. Add this scenario as a dependency of each Build."
    cat(sprintf("Carbon Assumptions scenario created (id %d, CBM Crosswalk %d rows): add it to each Build's dependencies\n", scenarioId(ca), nrow(v))) }
  st <- levels(datasheet(scenario(L, as.data.table(scenario(L, summary = TRUE))$ScenarioId[1]), "core_Pipeline", lookupsAsFactors = TRUE, optional = TRUE)$StageNameId)
  cat("stages now:", paste(st, collapse = " | "), "\n") }
