# =============================================================================
# metadata-record.R - the model record (to-do 14, Phase 2): one FGDC CSDGM record per Build, from one content model
# =============================================================================
# md_build_facts(lib, sid)          reads a Build result through rsyncrosim: settings, study area, Validation, Data Sources Used, the run
#                                   log, the state class list, the model grid and the states it covers (the only part needing SyncroSim)
# md_model_content(facts, dir)      the content model: a plain R list holding every element of the record. Writers serialize it:
#                                   CSDGM now (md_csdgm), ISO 19115 later, from the same list
# md_csdgm(content)                 the CSDGM XML document (xml2), elements in the order the standard sets
# md_mp(xml, mp)                    runs the USGS metadata parser (mp) on a written record: one row per Error or Warning
# What only a person can supply (names, contact, DOI, abstract wording) comes from defaults/metadata/record-defaults.csv until the
# Release Information page exists (Phase 4). content$draft lists every element still a placeholder or drafted by the generator, and
# content$notes what the generator had to infer; a final release must have neither (Phase 5).
# Metadata must not interpret results (USGS model-output guidance, 2018): drafted text says what was done, never what it means.
# =============================================================================
suppressPackageStartupMessages(library(data.table))
if (!exists("md_read")) stop("source src/metadata.R before src/metadata-record.R")

`%||%` <- function(a, b) if (is.null(a) || !length(a) || (length(a) == 1 && is.na(a))) b else a

# ---- the run log ----------------------------------------------------------------------------------------------------------
# SyncroSim's run log of a Build result: the versions in its header, the start date, and each stage's own lines (checks and
# SyncroSim's timing lines dropped). Absolute paths are cut to their file names: the review checklists bar paths and user names.
# Folder names may hold spaces ("Data Sources"); the file name ends at a space, comma, semicolon or bracket.
md_scrub_paths <- function(x) gsub("(?<![A-Za-z])[A-Za-z]:[/\\\\](?:[^/\\\\:,;()<>\"]*[/\\\\])*([^/\\\\ ,;()<>\"]+)", "\\1", x, perl = TRUE)
md_parse_log <- function(lines) {
  lines <- sub("\\s+$", "", lines); lines <- lines[nzchar(lines)]
  ver <- function(p) { v <- sub(paste0("^", p, " -> "), "", grep(paste0("^", p, " -> "), lines, value = TRUE)); v[1] %||% NA_character_ }
  st <- grep("^STARTING SIMULATION: ", lines, value = TRUE)[1]
  date <- if (is.na(st)) NA_character_ else format(as.Date(sub("^STARTING SIMULATION: ([0-9/]+).*", "\\1", st), "%m/%d/%Y"), "%Y%m%d")
  a <- grep("^START TRANSFORMER: ", lines); b <- grep("^END TRANSFORMER: ", lines)
  stages <- lapply(seq_along(a), function(i) {
    name <- sub("^START TRANSFORMER: ", "", lines[a[i]]); end <- b[b > a[i]][1] %||% length(lines)
    body <- if (end > a[i] + 1) lines[(a[i] + 1):(end - 1)] else character()
    tm <- grep(" Total time: ", body, value = TRUE); tm <- tm[startsWith(tm, name) & !grepl("post processing|saving results", tm)]
    body <- body[!grepl(": (pass|fail|FAIL|warn)( |$)", body) & !grepl("=> Total time:| Total time: |^-+$", body) & !startsWith(body, "[Warning]")]
    body <- body[!grepl(paste0("^[0-9]+ [A-Za-z -]+: wrote "), body)]
    list(name = name, number = sub(" - .*", "", name), lines = md_scrub_paths(body), time = sub(".* Total time: ", "", tm[1] %||% NA_character_))
  })
  list(syncrosim = sub("^SyncroSim Version: ", "", grep("^SyncroSim Version: ", lines, value = TRUE)[1] %||% NA_character_),
       core = ver("core"), stsim = ver("stsim"), lucasCore = ver("lucasCore"), date = date, stages = stages,
       total = sub("^Total simulation time: ", "", grep("^Total simulation time: ", lines, value = TRUE)[1] %||% NA_character_))
}

# ---- facts from a Build result (rsyncrosim) ---------------------------------------------------------------------------------
md_build_facts <- function(lib, sid) {
  suppressPackageStartupMessages({ library(rsyncrosim); library(terra) })
  L <- suppressWarnings(ssimLibrary(lib)); S <- scenario(L, sid); P <- rsyncrosim::project(L, projectId(S))
  sc <- as.data.table(scenario(L)); me <- sc[ScenarioId == sid]
  if (!nrow(me) || me$IsResult != "Yes") stop("scenario ", sid, " is not a result scenario: the model record describes a Build result")
  ds <- function(x, s = S) { d <- tryCatch(as.data.table(datasheet(s, x, optional = TRUE)), error = function(e) data.table())
    for (j in names(d)) if (is.factor(d[[j]])) set(d, j = j, value = as.character(d[[j]])); d }
  invisible(capture.output(rl <- runLog(S))); log <- md_parse_log(unlist(strsplit(paste(rl, collapse = "\n"), "\r?\n")))
  if (!any(vapply(log$stages, function(s) s$number == "1", TRUE))) stop("scenario ", sid, " has no stage 1 in its run log: not a Build result")
  sc_cls <- ds("stsim_StateClass", P)
  home <- ds("lucasCore_DataSource", P)$DataSourcesHome[1] %||% NA_character_

  # the model grid: the Build's state class map
  ic <- datasheet(S, "stsim_InitialConditionsSpatial", optional = TRUE)
  if (!nrow(ic) || is.na(ic$StateClassFileName[1])) stop("scenario ", sid, " has no initial state class map")
  r <- rast(ic$StateClassFileName[1])
  land <- global(!is.na(r), "sum", na.rm = TRUE)[1, 1]
  ll <- ext(terra::project(densify(as.polygons(ext(r), crs = crs(r)), 5000), "EPSG:4326"))
  vals <- sort(unique(values(r, mat = FALSE))); vals <- vals[!is.na(vals)]

  # states the study area covers (place keywords), from the home's TIGER states
  states <- character()
  shp <- if (!is.na(home)) Sys.glob(file.path(home, "study-area", "states", "*.shp")) else character()
  if (length(shp)) {
    pts <- spatSample(r, 4000, "random", na.rm = TRUE, as.points = TRUE, values = FALSE)
    sv <- vect(shp[1]); nm <- intersect(c("NAME", "NAME10", "STATE_NAME"), names(sv))[1]
    hit <- relate(sv, terra::project(pts, crs(sv)), "intersects")
    states <- sort(unique(sv[[nm]][[1]][rowSums(hit) > 0]))
  }

  # the home's manifests: when each dataset was downloaded (citation access dates)
  man <- data.table()
  if (!is.na(home)) for (f in c(file.path(home, "manifest.csv"), Sys.glob(file.path(home, "regions", "*", "manifest.csv")))) {
    if (!file.exists(f)) next
    m <- fread(f, colClasses = "character")[, .(Column, Dataset, Version, Method, Downloaded, Status)]
    m[, Origin := if (dirname(f) == home) "top" else paste0("regions/", basename(dirname(f)))]; man <- rbind(man, m)
  }

  list(lib = basename(lib), result_id = sid, result_name = me$Name, parent_id = me$ParentId,
       build = as.list(ds("lucasCore_BuildOptions")[1]), study_area = ds("lucasCore_StudyArea")$UnitId,
       validation = ds("lucasCore_OutputValidation"), sources_used = ds("lucasCore_OutputDataSources"), log = log,
       state_classes = sc_cls[, .(Id, Name, Description = if ("Description" %in% names(sc_cls)) Description else NA_character_)],
       map_values = vals,
       grid = list(rows = nrow(r), cols = ncol(r), cell = res(r)[1], land_cells = land,
                   west = ll$xmin, east = ll$xmax, south = ll$ymin, north = ll$ymax),
       states = states, home = home, manifests = man)
}

# ---- the content model -----------------------------------------------------------------------------------------------------
md_record_defaults <- function(dir) { x <- md_read(dir, "record-defaults.csv"); x[, Placeholder := toupper(Placeholder) == "TRUE"]; x }
md_keywords <- function(dir) md_read(dir, "keywords.csv")
md_use_constraints <- function(dir) md_read(dir, "use-constraints.csv")

# Log lines as running text: each ends in a full stop unless it already ends in punctuation
md_sentences <- function(l) { l <- trimws(l[nzchar(trimws(l))]); paste(ifelse(grepl("[.;:!?]$", l), l, paste0(l, ".")), collapse = " ") }

md_valid_date <- function(x) !is.na(x) & (grepl("^[0-9]{4}([0-9]{2}([0-9]{2})?)?$", x) | x %in% c("Unknown", "Unpublished material"))

# One lineage source: a citations.csv row as a CSDGM citation, its access date from the home's manifest. by_hand: the file came
# from the source by hand (a captcha, say), and Data Download only clipped it
md_source <- function(cit, column, accessed, contribution, by_hand = FALSE) {
  c1 <- cit[Column == column]
  if (!nrow(c1)) return(NULL)
  link <- if (!is.na(c1$Doi)) paste0("https://doi.org/", c1$Doi) else c1$OnlineLink
  list(abbrev = column,
       citation = list(origin = trimws(strsplit(c1$Originator, ";", fixed = TRUE)[[1]]), pubdate = c1$PubDate, title = c1$Title,
                       edition = c1$Edition, geoform = c1$GeoForm, pubplace = c1$PubPlace, publish = c1$Publisher,
                       othercit = if (is.na(accessed)) NA_character_ else if (by_hand) sprintf("Downloaded by hand from the source and clipped by the lucasCore Data Download stage, %s.", accessed)
                                  else sprintf("Accessed %s through the lucasCore Data Download stage.", accessed),
                       onlink = link[!is.na(link)]),
       typesrc = "Online", time = c1$PubDate, current = "publication date", contribution = contribution)
}

md_model_content <- function(facts, dir) {
  def <- md_record_defaults(dir); D <- function(f) def[Field == f, Value][1]
  draft <- character(); notes <- character()
  ph <- def[Placeholder == TRUE, Field]; if (length(ph)) draft <- c(draft, paste("placeholder:", ph))
  b <- facts$build; g <- facts$grid; lg <- facts$log; v <- facts$validation
  res <- b$Resolution %||% g$cell; y0 <- b$StartYear; y1 <- b$EndYear
  units <- facts$study_area; if (!length(units)) units <- "the conterminous United States"
  where <- paste(sub("^[^:]+: ", "", units), collapse = ", ")
  strata_line <- grep("^Strata: ", unlist(lapply(lg$stages, `[[`, "lines")), value = TRUE)[1]
  strata <- if (is.na(strata_line)) "FIA ecodivisions and the Build Options strata" else sub("^Strata: ", "", strata_line)
  km2 <- round(g$land_cells * res^2 / 1e6)
  version <- lg$lucasCore %||% "unknown"
  contact <- list(person = D("ContactPerson"), org = D("ContactOrg"), addrtype = "mailing and physical", address = D("ContactAddress"),
                  city = D("ContactCity"), state = D("ContactState"), postal = D("ContactPostal"), country = "US",
                  phone = D("ContactPhone"), email = D("ContactEmail"))

  # identification
  title <- sprintf("LUCAS model of %s, %s-%s, at %s-meter resolution: inputs built with lucasCore %s", where, y0, y1, res, version)
  abstract <- paste(
    sprintf("This record describes a LUCAS (Land Use and Carbon Scenario Simulator) model of %s, built with the lucasCore package (version %s) for the ST-Sim state-and-transition simulation model in SyncroSim.", where, version),
    sprintf("The model covers %s square kilometers of land in %s cells of %s meters (%s rows by %s columns, NAD83 Conus Albers) and the years %s to %s.",
            format(km2, big.mark = ","), format(g$land_cells, big.mark = ","), res, g$rows, g$cols, y0, y1),
    sprintf("Strata: %s.", strata),
    "Its inputs are annual land-use and land-cover state classes and stand ages; forest growth curves fitted to Forest Inventory and Analysis (FIA) plots; carbon flows and decay rates calibrated to FIA dead wood and soil carbon; initial stocks of 14 carbon pools; historical transition rates and spatial multipliers; and climate multipliers.",
    "Together they are the ST-Sim inputs for historical simulations and projections of land use and carbon.")
  draft <- c(draft, "drafted: title", "drafted: abstract", "drafted: purpose")
  purpose <- "To document the inputs, settings and processing of the model, so that its simulations can be reproduced and their outputs traced to their sources."
  stage_names <- vapply(lg$stages, `[[`, "", "name")
  supplinf <- sprintf("Built as the result scenario \"%s\" (id %s) of the SyncroSim library \"%s\", stages %s. Total build time %s.",
                      facts$result_name, facts$result_id, facts$lib, paste(stage_names, collapse = "; "), lg$total %||% "not recorded")

  kw <- md_keywords(dir)
  theme <- lapply(unique(kw$Thesaurus), function(t) list(thesaurus = t, keys = kw[Thesaurus == t, Term]))
  theme <- c(theme, list(list(thesaurus = "USGS Metadata Identifier", keys = D("MetadataId"))))
  place <- list(list(thesaurus = "Common geographic areas", keys = c("United States", facts$states)),
                list(thesaurus = "None", keys = sub("^[^:]+: ", "", units)))
  if (!length(facts$states)) notes <- c(notes, "no states found for the place keywords (no TIGER states in Data Sources Home)")

  # lineage sources: Data Sources Used, else inferred from the home's manifests
  cit <- md_citations(dir); use <- md_use_constraints(dir)
  du <- facts$sources_used
  stage_of <- function(n) { s <- lg$stages[vapply(lg$stages, function(x) x$number == n, TRUE)]; if (length(s)) s[[1]]$name else paste("stage", n) }
  if (nrow(du)) {
    du[, Number := sub("^([0-9]+).*", "\\1", Stage)]
    srcs <- du[, .(Stages = paste(unique(Number), collapse = ","), Note = paste(unique(na.omit(Note)), collapse = "; "), Origin = Origin[1]), by = DataSource]
  } else {
    m <- facts$manifests[Status == "done" & Column %in% cit$Column]
    srcs <- data.table(DataSource = unique(c("EcodivisionFile", m$Column)), Stages = NA_character_, Note = "", Origin = NA_character_)
    notes <- c(notes, "this Build predates the Data Sources Used output: the lineage sources are every dataset in Data Sources Home, not the ones the Build read; run the Build again")
  }
  # the manifest row of the folder the Build read: another region's copy has its own date. No Data Sources Used: the newest
  held <- function(col, origin) { m <- facts$manifests[Column == col & Status == "done" & !is.na(Downloaded)]
    if (!is.na(origin)) m <- m[Origin == sub("^the top of the home$", "top", origin)]
    m[order(Downloaded)][seq_len(nrow(m)) == nrow(m)] }
  sources <- Filter(Negate(is.null), lapply(seq_len(nrow(srcs)), function(i) {
    col <- srcs$DataSource[i]; h <- held(col, srcs$Origin[i])
    st <- if (is.na(srcs$Stages[i])) "Read by the Build" else paste0("Read by ", paste(vapply(strsplit(srcs$Stages[i], ",")[[1]], stage_of, ""), collapse = "; "))
    md_source(cit, col, if (nrow(h)) substr(h$Downloaded, 1, 10) else NA_character_, paste0(st, if (nzchar(srcs$Note[i])) paste0(" (", srcs$Note[i], ")") else "", "."),
              by_hand = nrow(h) > 0 && identical(h$Method, "by hand"))
  }))
  miss <- setdiff(srcs$DataSource, cit$Column); if (length(miss)) notes <- c(notes, paste("no citation for", paste(miss, collapse = ", ")))
  bad <- vapply(sources, function(s) !md_valid_date(s$citation$pubdate), TRUE)
  if (any(bad)) notes <- c(notes, paste("citation date not YYYY[MM[DD]]:", paste(vapply(sources[bad], `[[`, "", "abbrev"), collapse = ", ")))
  used_cols <- vapply(sources, `[[`, "", "abbrev")
  useconst <- paste(c(D("UseConstraints"), use[Column %in% used_cols, Note]), collapse = " ")

  # process steps: one per stage, from the run log
  steps <- lapply(lg$stages, function(s) {
    desc <- paste0(s$name, " (lucasCore ", version, ", ST-Sim ", lg$stsim %||% "?", ", SyncroSim ", lg$syncrosim %||% "?",
                   if (!is.na(s$time)) paste0("; run time ", s$time) else "", "). ", md_sentences(s$lines))
    used <- if (nrow(du)) intersect(unique(du[Number == s$number, DataSource]), used_cols) else character()
    list(desc = desc, srcused = used, date = lg$date %||% format(Sys.Date(), "%Y%m%d"))
  })

  # data quality
  n_pass <- sum(v$Status == "Pass"); n_bad <- nrow(v) - n_pass
  by_stage <- v[, .(N = .N, Bad = sum(Status != "Pass")), by = Stage]
  logic <- paste0(sprintf("The Build ran %d validation checks: %d passed and %d did not. ", nrow(v), n_pass, n_bad),
                  paste(sprintf("%s: %d checks%s", by_stage$Stage, by_stage$N, ifelse(by_stage$Bad > 0, sprintf(" (%d not passed)", by_stage$Bad), ", all passed")), collapse = "; "), ".",
                  if (n_bad) paste0(" Not passed: ", paste(sprintf("%s - %s (%s)", v[Status != "Pass", Stage], v[Status != "Pass", Check], v[Status != "Pass", Status]), collapse = "; "), ".") else "")
  if (n_bad) notes <- c(notes, sprintf("%d validation checks did not pass", n_bad))
  acc_pat <- "^(Land cover resampling|Developed land|Decay calibration|Initial carbon|Study area: [0-9]+ of)"
  acc <- unlist(lapply(lg$stages, function(s) grep(acc_pat, s$lines, value = TRUE)))
  attracc <- paste("Each Build stage compares its products with their sources and records the result as validation checks (see Logical Consistency). Comparisons the Build reports:", md_sentences(acc))
  complete <- sprintf("The model covers %s land cells of %s meters in %s. Cells outside the study area carry no data. Every land cell has a primary, secondary and tertiary stratum, a state class, a stand age and all 14 carbon pools (checked by the Build).",
                      format(g$land_cells, big.mark = ","), res, where)
  horizpa <- sprintf("Not assessed. Positions are inherited from the inputs (mostly 30-meter rasters, and vector strata) as resampled to the %s-meter model grid in NAD83 Conus Albers (EPSG:5070).", res)

  # entities: the state class map, and the definitions table
  defs <- md_definitions(dir)
  scl <- facts$state_classes[Id %in% facts$map_values | !length(facts$map_values)]
  own <- setNames(scl$Description, scl$Name)
  sd <- md_define(defs, "StateClass", scl$Name, own = own)
  if (anyNA(sd$Definition)) notes <- c(notes, paste("state classes with no definition:", paste(sd[is.na(Definition), Name], collapse = ", ")))
  dict <- md_dictionary(dir); dcol <- md_columns(dict, "definitions.csv")
  entities <- list(
    list(label = "State class map", definition = sprintf("The Build's initial state class map: a %s-meter raster whose cell values are ST-Sim state class ids.", res),
         defsrc = "lucasCore", attrs = list(list(label = "Value", definition = "State class id", defsrc = "lucasCore",
           domain = list(type = "enum", values = lapply(seq_len(nrow(scl)), function(i) list(value = as.character(scl$Id[i]),
             definition = paste0(scl$Name[i], ": ", sd$Definition[i] %||% "not defined"), source = "lucasCore definitions.csv")))))),
    list(label = "definitions.csv", definition = "What every state class, transition group and type, stock and flow type and group, and stratum of the model means.",
         defsrc = "lucasCore", attrs = lapply(seq_len(nrow(dcol)), function(i) list(label = dcol$Column[i], definition = dcol$Definition[i],
           defsrc = "lucasCore", domain = list(type = "unrep", text = dcol$Domain[i] %||% "Free text.")))))
  overview <- list(eaover = "The model's classifications (state classes, transition groups and types, stock and flow types and groups, and strata) are defined in definitions.csv; the columns of the tables a release exports are defined in data-dictionary.csv. Both accompany this record.",
                   eadetcit = "lucasCore package tables defaults/metadata/definitions.csv and data-dictionary.csv.")

  today <- format(Sys.Date(), "%Y%m%d")
  list(
    citation = list(origin = trimws(strsplit(D("Originator"), ";", fixed = TRUE)[[1]]), pubdate = today, title = title,
                    edition = NA_character_, geoform = "raster digital data", pubplace = D("PubPlace"), publish = D("Publisher"),
                    othercit = NA_character_, onlink = D("Doi"),
                    lworkcit = list(origin = "Sleeter, B.M.", pubdate = "Unpublished material", title = D("MethodsCitation"),
                                    geoform = "publication", othercit = NA_character_, onlink = character())),
    abstract = abstract, purpose = purpose, supplinf = supplinf,
    time = list(begdate = as.character(y0), enddate = as.character(y1), current = "ground condition"),
    status = list(progress = "Complete", update = "None planned"),
    bounding = list(west = round(g$west, 4), east = round(g$east, 4), north = round(g$north, 4), south = round(g$south, 4)),
    theme = theme, place = place, accconst = D("AccessConstraints"), useconst = useconst, contact = contact,
    native = sprintf("SyncroSim %s; ST-Sim %s; lucasCore %s; R", lg$syncrosim %||% "?", lg$stsim %||% "?", version),
    crossref = list(origin = "Sleeter, B.M.", pubdate = substr(lg$date %||% today, 1, 4), title = gsub("{version}", version, D("SoftwareCitation"), fixed = TRUE),
                    geoform = "software", othercit = NA_character_, onlink = "https://github.com/bsleeter/lucasCore"),
    quality = list(attracc = attracc, logic = logic, complete = complete, horizpa = horizpa, sources = sources, steps = steps),
    raster = list(rows = g$rows, cols = g$cols, cell = res),
    entities = entities, overview = overview,
    distribution = list(contact = list(org = D("DistributorOrg"), addrtype = "mailing and physical", address = D("DistributorAddress"),
                                       city = D("DistributorCity"), state = D("DistributorState"), postal = D("DistributorPostal"),
                                       country = "US", phone = D("DistributorPhone"), email = D("DistributorEmail")),
                        liability = D("Liability"), formname = "GeoTIFF; CSV", network = D("Doi"), fees = "None"),
    metadata = list(date = today, contact = contact, standard = "FGDC Content Standard for Digital Geospatial Metadata", version = "FGDC-STD-001-1998"),
    draft = draft, notes = notes)
}

# ---- the CSDGM writer ---------------------------------------------------------------------------------------------------
md_csdgm <- function(x) {
  suppressPackageStartupMessages(library(xml2))
  doc <- xml_new_root("metadata")
  add <- function(p, name, text = NULL) { n <- xml_add_child(p, name); if (!is.null(text)) xml_text(n) <- as.character(text); invisible(n) }
  opt <- function(p, name, text) if (length(text) && !is.na(text[1]) && nzchar(text[1])) add(p, name, text)
  citeinfo <- function(p, c) {
    ci <- add(p, "citeinfo"); for (o in c$origin) add(ci, "origin", o)
    add(ci, "pubdate", c$pubdate); add(ci, "title", c$title); opt(ci, "edition", c$edition); add(ci, "geoform", c$geoform)
    if (!is.null(c$publish) && !is.na(c$publish)) { pi <- add(ci, "pubinfo"); add(pi, "pubplace", c$pubplace %||% "Unknown"); add(pi, "publish", c$publish) }
    opt(ci, "othercit", c$othercit); for (l in c$onlink) add(ci, "onlink", l)
    if (!is.null(c$lworkcit)) citeinfo(add(ci, "lworkcit"), c$lworkcit)
    ci }
  cntinfo <- function(p, k) {
    ci <- add(p, "cntinfo")
    if (!is.null(k$person)) { pp <- add(ci, "cntperp"); add(pp, "cntper", k$person); add(pp, "cntorg", k$org) } else add(add(ci, "cntorgp"), "cntorg", k$org)
    ad <- add(ci, "cntaddr"); add(ad, "addrtype", k$addrtype); add(ad, "address", k$address); add(ad, "city", k$city)
    add(ad, "state", k$state); add(ad, "postal", k$postal); add(ad, "country", k$country)
    add(ci, "cntvoice", k$phone); add(ci, "cntemail", k$email); ci }

  id <- add(doc, "idinfo"); citeinfo(add(id, "citation"), x$citation)
  de <- add(id, "descript"); add(de, "abstract", x$abstract); add(de, "purpose", x$purpose); opt(de, "supplinf", x$supplinf)
  tp <- add(id, "timeperd"); rd <- add(add(tp, "timeinfo"), "rngdates"); add(rd, "begdate", x$time$begdate); add(rd, "enddate", x$time$enddate)
  add(tp, "current", x$time$current)
  s <- add(id, "status"); add(s, "progress", x$status$progress); add(s, "update", x$status$update)
  bb <- add(add(id, "spdom"), "bounding"); for (k in c("west", "east", "north", "south")) add(bb, paste0(k, "bc"), x$bounding[[k]])
  kw <- add(id, "keywords")
  for (t in x$theme) { th <- add(kw, "theme"); add(th, "themekt", t$thesaurus); for (k in t$keys) add(th, "themekey", k) }
  for (t in x$place) { pl <- add(kw, "place"); add(pl, "placekt", t$thesaurus); for (k in t$keys) add(pl, "placekey", k) }
  add(id, "accconst", x$accconst); add(id, "useconst", x$useconst)
  cntinfo(add(id, "ptcontac"), x$contact)
  add(id, "native", x$native)
  citeinfo(add(id, "crossref"), x$crossref)

  q <- x$quality; dq <- add(doc, "dataqual")
  add(add(dq, "attracc"), "attraccr", q$attracc); add(dq, "logic", q$logic); add(dq, "complete", q$complete)
  add(add(add(dq, "posacc"), "horizpa"), "horizpar", q$horizpa)
  li <- add(dq, "lineage")
  for (s1 in q$sources) {
    si <- add(li, "srcinfo"); citeinfo(add(si, "srccite"), s1$citation); add(si, "typesrc", s1$typesrc)
    st <- add(si, "srctime"); add(add(add(st, "timeinfo"), "sngdate"), "caldate", s1$time); add(st, "srccurr", s1$current)
    add(si, "srccitea", s1$abbrev); add(si, "srccontr", s1$contribution)
  }
  for (p1 in q$steps) { ps <- add(li, "procstep"); add(ps, "procdesc", p1$desc); for (u in p1$srcused) add(ps, "srcused", u); add(ps, "procdate", p1$date) }

  sp <- add(doc, "spdoinfo"); add(sp, "direct", "Raster")
  ri <- add(sp, "rastinfo"); add(ri, "rasttype", "Grid Cell"); add(ri, "rowcount", x$raster$rows); add(ri, "colcount", x$raster$cols)

  hs <- add(add(doc, "spref"), "horizsys"); pl <- add(hs, "planar"); mp <- add(pl, "mapproj")
  add(mp, "mapprojn", "Albers Conical Equal Area"); al <- add(mp, "albers")
  add(al, "stdparll", "29.5"); add(al, "stdparll", "45.5"); add(al, "longcm", "-96.0"); add(al, "latprjo", "23.0"); add(al, "feast", "0.0"); add(al, "fnorth", "0.0")
  pc <- add(pl, "planci"); add(pc, "plance", "row and column"); cr <- add(pc, "coordrep"); add(cr, "absres", x$raster$cell); add(cr, "ordres", x$raster$cell)
  add(pc, "plandu", "meters")
  gd <- add(hs, "geodetic"); add(gd, "horizdn", "North American Datum of 1983"); add(gd, "ellips", "Geodetic Reference System 80")
  add(gd, "semiaxis", "6378137.0"); add(gd, "denflat", "298.257222101")

  ea <- add(doc, "eainfo")
  for (e in x$entities) {
    dt <- add(ea, "detailed"); et <- add(dt, "enttyp"); add(et, "enttypl", e$label); add(et, "enttypd", e$definition); add(et, "enttypds", e$defsrc)
    for (a in e$attrs) {
      at <- add(dt, "attr"); add(at, "attrlabl", a$label); add(at, "attrdef", a$definition); add(at, "attrdefs", a$defsrc)
      dv <- add(at, "attrdomv")
      if (a$domain$type == "enum") { xml_remove(dv); for (v1 in a$domain$values) { ed <- add(add(at, "attrdomv"), "edom")
          add(ed, "edomv", v1$value); add(ed, "edomvd", v1$definition); add(ed, "edomvds", v1$source) } }
      else add(dv, "udom", a$domain$text)
    }
  }
  ov <- add(ea, "overview"); add(ov, "eaover", x$overview$eaover); add(ov, "eadetcit", x$overview$eadetcit)

  di <- add(doc, "distinfo"); cntinfo(add(di, "distrib"), x$distribution$contact); add(di, "distliab", x$distribution$liability)
  so <- add(di, "stdorder"); dg <- add(so, "digform"); add(add(dg, "digtinfo"), "formname", x$distribution$formname)
  add(add(add(add(add(dg, "digtopt"), "onlinopt"), "computer"), "networka"), "networkr", x$distribution$network)
  add(so, "fees", x$distribution$fees)

  mi <- add(doc, "metainfo"); add(mi, "metd", x$metadata$date); cntinfo(add(mi, "metc"), x$metadata$contact)
  add(mi, "metstdn", x$metadata$standard); add(mi, "metstdv", x$metadata$version)
  doc
}

# ---- the USGS metadata parser --------------------------------------------------------------------------------------------
# mp: the option lucas.mp, else the environment variable LUCAS_MP, else mp on the PATH (ArcGIS ships an older copy: check the version)
md_mp_default <- function() { p <- getOption("lucas.mp", Sys.getenv("LUCAS_MP", unset = "")); if (nzchar(p)) p else unname(Sys.which("mp")) }
md_mp <- function(xml, mp = md_mp_default()) {
  if (is.na(mp) || !file.exists(mp)) return(NULL)
  err <- tempfile(fileext = ".txt"); on.exit(unlink(err))
  system2(mp, c("-e", shQuote(err), shQuote(xml)), stdout = FALSE, stderr = FALSE)
  l <- if (file.exists(err)) readLines(err, warn = FALSE) else character()
  l <- l[grepl("^(Error|Warning)", l)]
  data.table(Level = sub("^(Error|Warning).*", "\\1", l), Message = l)
}
