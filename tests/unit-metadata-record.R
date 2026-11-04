# =============================================================================
# unit-metadata-record.R - the model record (to-do 14, Phase 2): content model, CSDGM writer, mp
# =============================================================================
# Plain R, no SyncroSim, no network. A made-up Build (run log, settings, checks, Data Sources Used) checks that
#   - the run log gives the versions, the date and each stage's own lines, without checks, timing lines or absolute paths
#   - the record's tables are sound: valid citation dates, every record default named, keywords from known thesauri
#   - the lineage is the Data Sources Used rows (inferred from the home only when there are none, and then said so), each process
#     step names only sources the lineage has, and Use Constraints notes come only from inputs the Build read
#   - placeholders are listed; the XML has the seven CSDGM sections in order, no absolute path, and (when mp is found) no mp errors
# Usage: Rscript tests/unit-metadata-record.R [--mp=<path to mp.exe>]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(xml2) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "datahome.R")); source(file.path(pkg, "src", "metadata.R")); source(file.path(pkg, "src", "metadata-record.R"))
a <- grep("^--mp=", commandArgs(TRUE), value = TRUE); if (length(a)) options(lucas.mp = sub("^--mp=", "", a[1]))
ok <- 0; bad <- 0
expect <- function(what, cond, detail = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, detail, "\n") } }
md <- file.path(pkg, "defaults", "metadata")

# ---- the run log ------------------------------------------------------------------------------------------------------------
log <- c("RunLog", "SyncroSim Version: 3.1.29.0", "Packages:", "core -> 3.1.29", "lucasCore -> 1.0.1", "stsim -> 4.5.4", "",
  "[Warning] The package 'lucasCore' was built for an undetermined version of SyncroSim", "-----", "STARTING SIMULATION: 11/02/2026 : 10:10:25 PM", "-----",
  "START TRANSFORMER: 1 - Study Area and Strata", "Strata: primary = FIA ecodivisions; secondary = States; tertiary = Federal Lands",
  "Study area: County: Placer California (40 x 60 cells of 1000 m)", "1 Study Area - study area has cells: pass 2000 cells",
  "1 - Study Area and Strata post processing => Total time: 00:00:00", "1 - Study Area and Strata Total time: 00:01:10", "END TRANSFORMER: 1 - Study Area and Strata",
  "START TRANSFORMER: 3 - Carbon Flows", "FIA DataMart: cached tables (D:/example/Data Sources/FIA/DataMart/fia-conditions.rds)",
  "Decay calibration: 56 cells, 12 with >= 200 FIA plots (own fit)", "3 Carbon Flows - decay fits: pass 56 cells", "3 - Carbon Flows Total time: 00:02:00",
  "END TRANSFORMER: 3 - Carbon Flows", "SIMULATION COMPLETE", "Total simulation time: 00:03:10")
lg <- md_parse_log(log)
expect("log: versions", identical(c(lg$syncrosim, lg$stsim, lg$lucasCore), c("3.1.29.0", "4.5.4", "1.0.1")))
expect("log: start date as YYYYMMDD", identical(lg$date, "20261102"))
expect("log: two stages, numbered", identical(vapply(lg$stages, `[[`, "", "number"), c("1", "3")))
l3 <- lg$stages[[2]]$lines
expect("log: checks and timing lines dropped", !any(grepl(": pass|Total time", unlist(lapply(lg$stages, `[[`, "lines")))))
expect("log: stage run time kept", identical(lg$stages[[1]]$time, "00:01:10"))
expect("log: absolute paths cut to the file name", any(grepl("(fia-conditions.rds)", l3, fixed = TRUE)) && !any(grepl("lucas-master", l3)), paste(l3, collapse = " | "))
B <- intToUtf8(92)
expect("scrub: two paths on a line, folders with spaces", identical(md_scrub_paths(paste0("read C:", B, "Users", B, "someone", B, "My Docs", B, "a.tif and F:/x/y.csv, then")),
                                                                    "read a.tif and y.csv, then"))
expect("scrub leaves URLs alone",identical(md_scrub_paths("see https://doi.org/10.5066/P94UXNTS"), "see https://doi.org/10.5066/P94UXNTS"))
expect("sentences: full stops added once", identical(md_sentences(c("a b", "c.", "")), "a b. c."))

# ---- the tables -------------------------------------------------------------------------------------------------------------
cit <- md_citations(md); def <- md_record_defaults(md); kw <- md_keywords(md); uc <- md_use_constraints(md)
expect("every citation date is YYYY[MM[DD]] or Unknown", all(md_valid_date(cit$PubDate)), paste(cit[!md_valid_date(PubDate), paste(Column, PubDate)], collapse = "; "))
need <- c("Originator", "Publisher", "PubPlace", "Doi", "MetadataId", "MethodsCitation", "SoftwareCitation", "ContactPerson", "ContactOrg",
          "ContactAddress", "ContactCity", "ContactState", "ContactPostal", "ContactPhone", "ContactEmail", "AccessConstraints", "UseConstraints",
          "DistributorOrg", "DistributorAddress", "DistributorCity", "DistributorState", "DistributorPostal", "DistributorPhone", "DistributorEmail", "Liability")
expect("record defaults: every field present and filled", all(need %in% def$Field) && !anyNA(def[Field %in% need, Value]), paste(setdiff(need, def$Field), collapse = ", "))
expect("keywords: known thesauri only", all(kw$Thesaurus %in% c("USGS Thesaurus", "ISO 19115 Topic Category", "None")))
expect("keywords: at least one USGS Thesaurus term", any(kw$Thesaurus == "USGS Thesaurus"))
expect("use constraints name Data Sources columns", all(uc$Column %in% cit$Column), paste(setdiff(uc$Column, cit$Column), collapse = ", "))

# ---- the content model ------------------------------------------------------------------------------------------------------
facts <- list(lib = "Placer.ssim", result_id = 9L, result_name = "Build ([1] @ 02-Nov-2026)", parent_id = 1L,
  build = list(Resolution = 1000, StartYear = 1985, EndYear = 2023), study_area = "County: Placer California",
  validation = data.table(Stage = c("1 Study Area", "3 Carbon Flows"), Check = c("study area has cells", "decay fits"), Status = "Pass", Detail = ""),
  sources_used = data.table(Stage = c("1 Study Area", "1 Study Area", "3 Carbon Flows", "3 Carbon Flows"),
                            DataSource = c("EcodivisionFile", "StatesFile", "FiaDataMartFolder", "PrismFolder"),
                            Origin = c("package", "top", "top", "top"), Path = NA_character_, Note = c(NA, NA, "cached tables", NA)),
  log = lg, state_classes = data.table(Id = c(41L, 82L), Name = c("Forest: Ponderosa Pine Group", "Agriculture: Cropland"), Description = NA_character_),
  map_values = c(41, 82), grid = list(rows = 60, cols = 40, cell = 1000, land_cells = 2000, west = -121.5, east = -120, south = 38.7, north = 39.3),
  states = "California", home = "home", manifests = data.table(Column = c("StatesFile", "PrismFolder", "WuiFolder"), Dataset = "", Version = "", Method = "direct",
  Downloaded = c("2026-11-02T13:00:35", "2026-11-01T09:00:00", "2026-11-01T09:00:00"), Status = "done", Origin = "top"))
x <- md_model_content(facts, md)
abbr <- vapply(x$quality$sources, `[[`, "", "abbrev")
expect("lineage = the Data Sources Used columns", setequal(abbr, facts$sources_used$DataSource), paste(abbr, collapse = ", "))
expect("no inferred-lineage note when Data Sources Used has rows", !any(grepl("predates", x$notes)))
expect("every process step names only lineage sources", all(unlist(lapply(x$quality$steps, `[[`, "srcused")) %in% abbr))
expect("stage 3's step names its two sources", setequal(x$quality$steps[[2]]$srcused, c("FiaDataMartFolder", "PrismFolder")))
expect("access date from the manifest", grepl("Accessed 2026-11-02", x$quality$sources[[which(abbr == "StatesFile")]]$citation$othercit))
expect("Use Constraints: PRISM noted (read)", grepl("PRISM Climate Group", x$useconst))
expect("Use Constraints: no note for an input not read (LOCA2, C-CAP, FSim)", !grepl("CMIP6|C-CAP|FSim", x$useconst))
expect("placeholders listed (DOI, contact phone)", all(c("placeholder: Doi", "placeholder: ContactPhone") %in% x$draft))
expect("drafted text listed", all(c("drafted: title", "drafted: abstract") %in% x$draft))
expect("place keywords: the states", "California" %in% x$place[[1]]$keys)
expect("state class entity: one value per mapped class", length(x$entities[[1]]$attrs[[1]]$domain$values) == 2)
expect("state classes defined", !any(grepl("not defined", vapply(x$entities[[1]]$attrs[[1]]$domain$values, `[[`, "", "definition"))))
# the access date is the copy the Build read, not the newest in the home; a copy supplied by hand says so
f4 <- facts; f4$sources_used <- data.table(Stage = "5 Initial Conditions", DataSource = c("RcmapFile", "PrismFolder"), Origin = c("regions/A", "the top of the home"), Path = NA_character_, Note = NA_character_)
f4$manifests <- data.table(Column = c("RcmapFile", "RcmapFile", "PrismFolder"), Dataset = "", Version = "", Method = c("direct", "by hand", "direct"),
                           Downloaded = c("2026-11-01T14:59:00", "2026-11-02T20:13:26", "2026-11-01T09:00:00"), Status = "done", Origin = c("regions/A", "regions/B", "top"))
cit4 <- function(f, col) { s <- md_model_content(f, md)$quality$sources; s[[which(vapply(s, `[[`, "", "abbrev") == col)]]$citation$othercit }
expect("access date: the region the Build read, not the newest", grepl("Accessed 2026-11-01", cit4(f4, "RcmapFile")))
expect("access date: the top of the home matches its manifest", grepl("Accessed 2026-11-01", cit4(f4, "PrismFolder")))
f5 <- f4; f5$sources_used$Origin[1] <- "regions/B"
expect("a copy supplied by hand says so", grepl("Downloaded by hand from the source.*2026-11-02", cit4(f5, "RcmapFile")))
f6 <- f4; f6$sources_used$Origin[1] <- "set"
expect("a file not read from the home has no access date", is.na(cit4(f6, "RcmapFile")))
# where mp comes from: the option (--mp=), then the page's setting in the home, then LUCAS_MP, then the PATH
local({ old <- options(lucas.mp = NULL); oe <- Sys.getenv("LUCAS_MP"); on.exit({ options(old); Sys.setenv(LUCAS_MP = oe) })
  h <- tempfile("mp-home"); dir.create(h); writeLines(c("Key,Value", "LfpsEmail,a@b.c", "MpPath,C:/tools/page/mp.exe"), file.path(h, "settings.csv"))
  Sys.setenv(LUCAS_MP = "C:/tools/env/mp.exe")
  expect("mp: the page's setting beats LUCAS_MP", identical(md_mp_default(h), "C:/tools/page/mp.exe"))
  expect("mp: a home with no setting falls to LUCAS_MP", identical(md_mp_default(tempdir()), "C:/tools/env/mp.exe"))
  expect("mp: no home falls to LUCAS_MP", identical(md_mp_default(), "C:/tools/env/mp.exe"))
  options(lucas.mp = "C:/tools/opt/mp.exe"); expect("mp: --mp= beats the page's setting", identical(md_mp_default(h), "C:/tools/opt/mp.exe"))
  options(lucas.mp = NULL); expect("mp: a saved path that is gone is not run", is.null(md_mp("x.xml", md_mp_default(h)))) })
# stage 1's software line goes to the record's software, not its process steps
sw <- md_parse_log(c("START TRANSFORMER: 1 - Study Area and Strata", "Software: R 4.6.1; lucasCore commit abc1234", "Strata: x", "END TRANSFORMER: 1 - Study Area and Strata"))
expect("software line read from the log", identical(sw$software, "R 4.6.1; lucasCore commit abc1234"))
expect("software line left out of the stage's text", identical(sw$stages[[1]]$lines, "Strata: x"))
f7 <- facts; f7$log$software <- sw$software
expect("native names R and the commit", grepl("R 4.6.1; lucasCore commit abc1234$", md_model_content(f7, md)$native))
expect("an older log still names R", grepl("; R$", x$native))
f2 <- facts; f2$sources_used <- data.table(Stage = character(), DataSource = character(), Origin = character(), Path = character(), Note = character())
x2 <- md_model_content(f2, md)
expect("no Data Sources Used: lineage inferred from the home, and said so", any(grepl("predates", x2$notes)) &&
       setequal(vapply(x2$quality$sources, `[[`, "", "abbrev"), c("EcodivisionFile", "StatesFile", "PrismFolder", "WuiFolder")))
f3 <- facts; f3$validation <- rbind(facts$validation, data.table(Stage = "3 Carbon Flows", Check = "soil fit", Status = "Fail", Detail = ""))
x3 <- md_model_content(f3, md)
expect("a failed check is named in Logical Consistency and noted", grepl("soil fit", x3$quality$logic) && any(grepl("did not pass", x3$notes)))

# ---- the CSDGM record ---------------------------------------------------------------------------------------------------------
doc <- md_csdgm(x); tmp <- tempfile(fileext = ".xml"); write_xml(doc, tmp)
top <- xml_name(xml_children(xml_root(doc)))
expect("CSDGM sections in order", identical(top, c("idinfo", "dataqual", "spdoinfo", "spref", "eainfo", "distinfo", "metainfo")), paste(top, collapse = ","))
txt <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
expect("no absolute path in the record", !grepl("(?<![A-Za-z])[A-Za-z]:[/\\\\]", txt, perl = TRUE))
expect("srcused all match a srccitea", all(xml_text(xml_find_all(doc, "//srcused")) %in% xml_text(xml_find_all(doc, "//srccitea"))))
expect("DOI in the citation onlink and networkr", identical(xml_text(xml_find_first(doc, "/metadata/idinfo/citation/citeinfo/onlink")),
                                                             xml_text(xml_find_first(doc, "//networkr"))))
expect("metadata identifier in its own theme keyword set", xml_text(xml_find_first(doc, "//theme[themekt='USGS Metadata Identifier']/themekey")) == "USGS:PLACEHOLDER")
m <- md_mp(tmp)
if (is.null(m)) cat("skip: mp not found (pass --mp= or set LUCAS_MP)\n") else
  expect("mp: no errors", !any(m$Level == "Error"), paste(head(m$Message, 5), collapse = " | "))

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
