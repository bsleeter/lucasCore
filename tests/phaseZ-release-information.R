# =============================================================================
# phaseZ-release-information.R - the Release Information page reaches the records, and a final release fails on a blank (to-do 14, Phase 4)
# =============================================================================
# On a COPY of a library with a Build result and a finished run: writes made-up people and scenarios to the library it is given, so never a guide library.
# Case A: everything filled in, status Approved: the stage passes, with no DRAFT in the README. Case B: status Approved with the DOI blank: the stage fails on it.
# Usage: Rscript tests/phaseZ-release-information.R "<copy of a library.ssim>" --build=<result id> --runs=<id,id> --out=<empty folder> [--every=<n>]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table); library(xml2) })
a <- commandArgs(TRUE); lib <- a[!startsWith(a, "--")][1]; arg <- function(k) sub(paste0("^--", k, "="), "", grep(paste0("^--", k, "="), a, value = TRUE))
id <- as.integer(arg("build")); runs <- as.integer(strsplit(arg("runs"), ",")[[1]]); out <- arg("out"); every <- if (length(arg("every"))) as.integer(arg("every")) else 38L
L <- suppressWarnings(ssimLibrary(lib)); P <- rsyncrosim::project(L, 1)
n <- 0L; bad <- 0L; ok <- function(what, cond) { n <<- n + 1L; if (!isTRUE(cond)) { bad <<- bad + 1L; cat("FAIL:", what, "\n") } else cat("pass:", what, "\n") }

saveDatasheet(P, data.frame(Name = c("Tester, A.", "Example, B."), Orcid = c("0000-0000-0000-0001", NA), Organization = c("Test Science Center", NA), Address = c("1 Test Road", NA), City = c("Testville", NA),
                            State = c("WA", NA), PostalCode = c("98000", NA), Phone = c("555-555-0100", NA), Email = c("tester@example.org", NA)), "lucasCore_Person")
go <- function(name, doi, folder) {
  S <- rsyncrosim::scenario(P, name); dependency(S) <- id
  saveDatasheet(S, data.frame(StageNameId = "17 - Data Release", RunOrder = 1L), "core_Pipeline")
  saveDatasheet(S, data.frame(OutputFolder = folder, MapEvery = every), "lucasCore_DataReleaseOptions")
  saveDatasheet(S, data.frame(RunScenarioId = runs), "lucasCore_DataReleaseRun")
  saveDatasheet(S, data.frame(PersonId = c("Example, B.", "Tester, A."), SortOrder = 1:2), "lucasCore_ReleaseOriginator")
  saveDatasheet(S, data.frame(ReleaseStatus = 3L, Title = "A test release title", Abstract = "A test abstract written by a person.", Purpose = "A test purpose.", ContactPersonId = "Tester, A.", ContactEmail = "group@example.org",
                              PubDate = "20270102", Version = "2.0", RevisionNotes = "A test revision.", Doi = doi, MetadataId = "USGS:test-id", IpdsNumber = "IP-000000", MethodsCitation = "Tester, A., 2027, A test methods paper.", ThemeKeywords = "test theme word", PlaceKeywords = "test place word"), "lucasCore_ReleaseInformation")
  R <- tryCatch(run(S), error = function(e) NULL)
  lr <- as.data.table(rsyncrosim::scenario(L, summary = TRUE)); lr[ParentId == scenarioId(S)][.N, ScenarioId] }

# ---- A: everything supplied --------------------------------------------------------------------------------------------------
da <- file.path(out, "a"); ra <- go("Release Information (test A)", "https://doi.org/10.5066/TEST", da)
xa <- read_xml(file.path(da, "release.xml")); tx <- function(d, p) xml_text(xml_find_all(d, p))
ok("the page's title, abstract and purpose are the parent's", tx(xa, "//citeinfo/title")[1] == "A test release title" && tx(xa, "//abstract") == "A test abstract written by a person." && tx(xa, "//purpose") == "A test purpose.")
ok("originators in row order", identical(tx(xa, "//idinfo/citation/citeinfo/origin"), c("Example, B.", "Tester, A.")))
ok("date, version and DOI", tx(xa, "//idinfo/citation/citeinfo/pubdate") == "20270102" && tx(xa, "//idinfo/citation/citeinfo/edition") == "2.0" && "https://doi.org/10.5066/TEST" %in% tx(xa, "//idinfo/citation/citeinfo/onlink"))
ok("the contact is the person, with the group email", tx(xa, "//ptcontac//cntper") == "Tester, A." && tx(xa, "//ptcontac//city") == "Testville" && tx(xa, "//ptcontac//cntemail") == "group@example.org")
ok("the ORCID is in the credit, which ends in one full stop", grepl("ORCID 0000-0000-0000-0001", tx(xa, "//datacred"), fixed = TRUE) && !grepl("..", tx(xa, "//datacred"), fixed = TRUE))
ok("the parent carries the identifier", "USGS:test-id" %in% tx(xa, "//themekey"))
ok("the extra keywords are there", "test theme word" %in% tx(xa, "//themekey") && "test place word" %in% tx(xa, "//placekey"))
ok("Approved takes the approved statement", !grepl("preliminary or provisional", tx(xa, "//distliab"), fixed = TRUE))
others <- c(list.files(da, "run.xml$", recursive = TRUE, full.names = TRUE), file.path(da, "model", "model.xml"))
ok("the run and model records name the people and carry no identifier", all(vapply(others, function(f) { x <- read_xml(f); tx(x, "//idinfo/citation/citeinfo/origin")[1] == "Example, B." && !"USGS:test-id" %in% tx(x, "//themekey") && !"USGS Metadata Identifier" %in% tx(x, "//themekt") }, TRUE)))
raw <- paste(unlist(lapply(c(file.path(da, "release.xml"), others), readLines, warn = FALSE)), collapse = "\n")
ok("no placeholder and no IPDS number in a record", !grepl("PLACEHOLDER|placeholder@|IP-000000", raw))
rd <- readLines(file.path(da, "README.txt"), warn = FALSE); ok("the README is not a draft", !any(grepl("^DRAFT", rd)) && rd[1] == "A test release title")
va <- as.data.table(datasheet(rsyncrosim::scenario(L, ra), "lucasCore_OutputValidation"))[Stage == "17 Data Release"]
ok("every check passes, the to-supply check among them", nrow(va) >= 8 && all(va$Status == "Pass") && any(grepl("no placeholder", va$Check)))
db <- DBI::dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO); ts <- DBI::dbGetQuery(db, sprintf("SELECT ToSupply FROM lucasCore_OutputDataRelease WHERE ScenarioId = %d", ra))$ToSupply; DBI::dbDisconnect(db)
ok("the stage records nothing left to supply", length(ts) == 1 && (is.na(ts) || !nzchar(ts)))

rv <- file.path(da, "review"); s <- paste(readLines(file.path(rv, "reviewer-summary.html"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
ok("the packet is written, with the IPDS number, and stays out of contents.csv", all(file.exists(file.path(rv, c("data-review-checklist.html", "metadata-review-checklist.html", "checks.csv", "mp-report.csv")))) && grepl("IP-000000", s, fixed = TRUE) && !any(grepl("^review/", fread(file.path(da, "contents.csv"))$file)))
rc <- fread(file.path(rv, "checks.csv")); ok("every must-pass review check passed, and is in Validation", all(rc[level == "must", pass] %in% TRUE) && all(rc[level == "must", what] %in% va$Check))
ok("records as text from mp", length(list.files(file.path(rv, "records-as-text"))) == length(others) + 1L)

# ---- B: a blank DOI on an Approved release -----------------------------------------------------------------------------------
db <- file.path(out, "b"); rb <- go("Release Information (test B)", NA_character_, db)
rs <- rsyncrosim::scenario(L, summary = TRUE); st <- as.data.table(rs)[ScenarioId == rb]
capture.output(l <- runLog(rsyncrosim::scenario(L, rb))); lg <- paste(l, collapse = "\n")
ok("Approved with a blank DOI fails the stage, and says so", grepl("no placeholder or drafted text is left: FAIL", lg, fixed = TRUE) && grepl("placeholder: Doi", lg, fixed = TRUE))
ok("the folder is written, so the list can be read", any(grepl("^DRAFT", readLines(file.path(db, "README.txt"), warn = FALSE))))
ok("the packet is written too, and shows the failure", grepl("Not passed", paste(readLines(file.path(db, "review", "reviewer-summary.html"), warn = FALSE), collapse = " "), fixed = TRUE))

cat(sprintf("%d checks, %d failed\n", n, bad)); cat(if (bad) "RELEASE INFORMATION FAILED\n" else "RELEASE INFORMATION OK\n")
