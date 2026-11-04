# =============================================================================
# unit-release-review.R - the content checks and review packet of src/release-review.R on a small made-up release (to-do 14, Phase 5)
# =============================================================================
# Plain R, no SyncroSim. A clean release passes every must-pass check; then each fault is put in and must be caught by its own check, so that no check only ever passes.
# Usage: Rscript tests/unit-release-review.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(DBI); library(RSQLite); library(terra); library(xml2) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
for (f in c("datahome.R", "metadata.R", "metadata-record.R", "release.R", "release-review.R")) source(file.path(pkg, "src", f))
dir <- file.path(pkg, "defaults", "metadata"); dict <- md_dictionary(dir)
n <- 0L; bad <- 0L; ok <- function(what, cond) { n <<- n + 1L; if (!isTRUE(cond)) { bad <<- bad + 1L; cat("FAIL:", what, "\n") } }

rec <- function(f, west = "-122", pub = "20270101", net = "https://doi.org/10.5066/TEST", mail = "a@usgs.gov", phone = "253-555-0100", useconst = "CC0 1.0 Universal.", keep_thes = TRUE, entities = character(), over = "") {
  dir.create(dirname(f), showWarnings = FALSE, recursive = TRUE)
  writeLines(sprintf("<metadata><idinfo><citation><citeinfo><origin>A</origin><pubdate>%s</pubdate><title>T</title><edition>1.0</edition><lworkcit><citeinfo><title>M</title></citeinfo></lworkcit></citeinfo></citation><timeperd><timeinfo><rngdates><begdate>2000</begdate><enddate>2001</enddate></rngdates></timeinfo></timeperd><spdom><bounding><westbc>%s</westbc><eastbc>E</eastbc><northbc>N</northbc><southbc>S</southbc></bounding></spdom><keywords>%s<place><placekt>Common geographic areas</placekt><placekey>Washington</placekey></place></keywords><accconst>None</accconst><useconst>%s</useconst><ptcontac><cntinfo><cntvoice>%s</cntvoice><cntemail>%s</cntemail></cntinfo></ptcontac><native>SyncroSim 3; ST-Sim 4; lucasCore 1</native></idinfo><dataqual><lineage><srcinfo><srccitea>x</srccitea></srcinfo></lineage></dataqual><eainfo>%s<overview><eaover>-9999 no data. %s</eaover></overview></eainfo><distinfo><distliab>L</distliab><stdorder><digform><digtopt><onlinopt><computer><networka><networkr>%s</networkr></networka></computer></onlinopt></digtopt></digform></stdorder></distinfo><metainfo><metd>20270101</metd></metainfo></metadata>",
    pub, west, if (keep_thes) "<theme><themekt>USGS Thesaurus</themekt><themekey>carbon</themekey></theme>" else "", useconst, phone, mail, paste(sprintf("<detailed><enttyp><enttypl>%s</enttypl></enttyp></detailed>", gsub(">", "&gt;", gsub("<", "&lt;", entities, fixed = TRUE), fixed = TRUE)), collapse = ""), over, net), f) }

make <- function(out, ...) { unlink(out, recursive = TRUE); for (d in c("historical/h/tables", "historical/h/maps", "model")) dir.create(file.path(out, d), recursive = TRUE, showWarnings = FALSE)
  r <- rast(nrows = 4, ncols = 4, xmin = -2e6, xmax = -1.9e6, ymin = 2.9e6, ymax = 3e6, crs = "EPSG:5070", vals = rep(c(1L, 2L), 8)); m <- file.path(tempdir(), "state-class-h-2000.tif")
  writeRaster(r, m, overwrite = TRUE, datatype = "INT4S", NAflag = -9999, filetype = "COG"); old <- setwd(dirname(m)); utils::zip(normalizePath(file.path(out, "historical/h/maps"), winslash = "/", mustWork = TRUE) |> file.path("state-class-h.zip"), basename(m), flags = "-q"); setwd(old)
  fwrite(data.table(run = "h", iteration = 1L, year = 2000L, primary_stratum = "P", secondary_stratum = "S", tertiary_stratum = "T", state_class = "A", area_ha = 2.25), file.path(out, "historical/h/tables/state-classes.csv"))
  writeLines("zips hold maps", file.path(out, "README.txt"))
  ll <- ext(project(as.polygons(ext(r), crs = crs(r)), "EPSG:4326")); xm <- function(f, over = "", ...) { rec(f, west = ll$xmin, over = over, ...); s <- readLines(f); s <- sub("<eastbc>E", paste0("<eastbc>", ll$xmax), s); s <- sub("<northbc>N", paste0("<northbc>", ll$ymax), s); writeLines(sub("<southbc>S", paste0("<southbc>", ll$ymin), s), f) }
  xm(file.path(out, "release.xml"), over = "README.txt release.xml model.xml run.xml", ...); xm(file.path(out, "model/model.xml")); xm(file.path(out, "historical/h/run.xml"), entities = c("state-classes.csv", "state-class-<run>-<year>.tif"))
  invisible(out) }
contents <- function(out) { f <- setdiff(list.files(out, recursive = TRUE), "contents.csv"); f <- f[!startsWith(f, "review/")]; data.table(file = f, product = "x", bytes = file.size(file.path(out, f)), sha256 = "") }
runs <- list(list(id = 1L, name = "H", slug = "h", folder = "historical", kind = "historical", years = c(2000L, 2001L), iterations = c(1L, 1L)))
defs <- data.table(kind = "StateClass", name = c("A", "B"), code = 1:2, definition = "d", source = "s")
base <- data.table(Check = c("every name has a definition", "every table's columns match the data dictionary", "a table's area matches its state class map"), Pass = TRUE, Detail = "")
info <- list(ReleaseStatus = "Approved", MethodsCitation = "M")
run_checks <- function(out, ...) { x <- file.path(out, c("release.xml", "model/model.xml", "historical/h/run.xml")); rl_review_checks(out, contents(out), x, runs, defs, dict, base, info, links = FALSE) }
tmp <- tempfile("review-test"); dir.create(tmp); out <- normalizePath(file.path(tmp), winslash = "/")
rd <- file.path(out, "rel"); make(rd); clean <- run_checks(rd)
ok("a clean release passes every must-pass check", all(clean[Level == "must", Pass] %in% TRUE))
if (any(!clean[Level == "must", Pass] %in% TRUE)) print(clean[Level == "must" & !Pass %in% TRUE])
ok("no must-pass check holds NA on a release with maps", !anyNA(clean[Level == "must", Pass]))
caught <- function(id) { x <- run_checks(rd); isFALSE(x[Check == id, Pass]) }
edit <- function(file, a, b) { f <- file.path(rd, file); writeLines(sub(a, b, readLines(f), fixed = TRUE), f) }
tb <- "historical/h/tables/state-classes.csv"; t0 <- fread(file.path(rd, tb))

fwrite(rbind(t0, t0), file.path(rd, tb)); ok("duplicate rows are caught", caught("tables")); make(rd)
fwrite(copy(t0)[, state_class := " A"], file.path(rd, tb)); ok("stray spaces are caught", caught("tables")); make(rd)
fwrite(copy(t0)[, area_ha := as.character(area_ha)][, area_ha := "lots"], file.path(rd, tb)); ok("text in a number column is caught", caught("tables")); make(rd)
fwrite(copy(t0)[, area_ha := -1], file.path(rd, tb)); ok("a negative area is caught", caught("ranges")); make(rd)
fwrite(copy(t0)[, year := 1999L], file.path(rd, tb)); ok("a year outside the run is caught", caught("ranges")); make(rd)
fwrite(copy(t0)[, area_ha := NA], file.path(rd, tb), na = "NA"); ok("an undefined blank is caught", caught("nulls") || caught("tables")); make(rd)
setnames(t0, "run", "run"); x <- copy(t0); setnames(x, "state_class", "state class"); fwrite(x, file.path(rd, tb)); ok("a space in a column name is caught", caught("labels")); make(rd)
edit("release.xml", "<westbc>", "<westbc>-1"); ok("wrong bounding coordinates are caught", caught("bounding")); make(rd)
edit("historical/h/run.xml", "<pubdate>20270101", "<pubdate>20270202"); ok("publication dates that disagree are caught", caught("dates")); make(rd)
edit("release.xml", "<pubdate>20270101", "<pubdate>2027-01-01"); ok("a date in the wrong format is caught", caught("dates")); make(rd)
edit("release.xml", "<begdate>2000", "<begdate>2000"); edit("release.xml", "<enddate>2001", "<enddate>2000"); ok("a run outside the parent's years is caught", caught("dates")); make(rd)
edit("model/model.xml", "<themekt>USGS Thesaurus</themekt>", "<themekt>Other</themekt>"); ok("a record with no USGS Thesaurus term is caught", caught("keywords")); make(rd)
edit("model/model.xml", "ST-Sim 4; ", ""); ok("a missing software version is caught", caught("native")); make(rd)
edit("historical/h/run.xml", "<srcinfo><srccitea>x</srccitea></srcinfo>", ""); ok("a record with no sources is caught", caught("lineage")); make(rd)
edit("release.xml", "CC0 1.0 Universal.", "All rights reserved."); ok("a missing CC0 statement is caught", caught("license")); make(rd)
edit("release.xml", "<distliab>L</distliab>", "<distliab></distliab>"); ok("a blank liability statement is caught", caught("statements")); make(rd)
edit("release.xml", "10.5066/TEST", "10.5066/PLACEHOLDER"); ok("a placeholder DOI is caught", caught("network")); make(rd)
edit("release.xml", "a@usgs.gov", "placeholder@usgs.gov"); ok("a placeholder email is caught", caught("contact")); make(rd)
edit("release.xml", "253-555-0100", "000-000-0000"); ok("a placeholder phone is caught", caught("contact")); make(rd)
writeLines("x", file.path(rd, "extra.csv")); ok("a file no record names is caught", caught("files")); make(rd)
edit("historical/h/run.xml", "<enttypl>state-classes.csv", "<enttypl>gone.csv"); ok("a record naming an absent file is caught", caught("files")); make(rd)
writeLines("x", file.path(rd, "model/a report.docx")); ok("a closed format is caught", caught("formats")); ok("a space in a file name is advice, and caught", caught("names")); make(rd)
writeLines("not a zip", file.path(rd, "README.txt")); writeLines("nothing", file.path(rd, "README.txt")); ok("a README that does not mention the zips is caught", caught("compressed")); make(rd)
defs0 <- defs; defs <- defs[1]; ok("a map value with no definition is caught", caught("vat")); defs <- defs0
r <- rast(file.path(tempdir(), "state-class-h-2000.tif")); f2 <- file.path(tempdir(), "x", "state-class-h-2000.tif"); dir.create(dirname(f2), showWarnings = FALSE); writeRaster(project(r, "EPSG:4326"), f2, overwrite = TRUE, datatype = "INT4S"); old <- setwd(dirname(f2)); unlink(file.path(rd, "historical/h/maps/state-class-h.zip")); utils::zip(file.path(rd, "historical/h/maps/state-class-h.zip"), basename(f2), flags = "-q"); setwd(old)
ok("a map in another projection is caught", caught("crs")); ok("a map that is not cloud-optimized is caught", caught("open")); make(rd)
writeLines("broken", file.path(rd, "model/model.xml")) -> z; ok("a broken record stops the checks", inherits(tryCatch(run_checks(rd), error = function(e) e), "error")); make(rd)
info$MethodsCitation <- NA; ok("a missing methods citation is caught", caught("methods")); info$MethodsCitation <- "M"
base2 <- copy(base); base$Pass[1] <- FALSE; ok("a stage check that failed carries over", caught("definitions")); base <- base2

# ---- the packet --------------------------------------------------------------------------------------------------------------
cl <- fread(file.path(dir, "review-checklists.csv"), na.strings = "NA")
ok("the checklists hold both USGS lists", setequal(unique(cl$Checklist), c("Data review", "Metadata review")) && nrow(cl) > 100)
ok("every Check id in the checklists is one the stage answers", all(na.omit(unique(cl$Check)) %in% clean$Check))
make(rd); chk <- run_checks(rd); rows <- rl_checklist_rows(dir, chk)
ok("no row is left without a finding", !anyNA(rows$Finding))
ok("the stage answers some items and leaves the rest", any(rows$Finding == "Stage: yes") && any(rows$Finding == "For the reviewer"))
ok("sections that do not apply say so", all(rows[Section == "Vector", Finding] == "Not applicable to this release"))
ok("whether anything is interpretive stays with the reviewer", all(rows[grepl("interpretive", Item) & Applies == "Yes", Finding] == "For the reviewer"))
p <- rl_parent_content(list(citation = list(title = "My <title>"), abstract = "", purpose = "", supplinf = "", time = list(), quality = list(), overview = list(), distribution = list(), theme = list(), draft = character()), runs, "Here", list(Title = "My <title>"))
cmp <- list(H = data.table(TransitionGroup = c("Harvest", "Urban"), Y0 = 2001L, Y1 = 2001L, Simulated = c(50, 99), Recorded = c(100, 100)))
fct <- list(validation = data.table(Stage = "1", Check = "c", Status = c("Pass", "FAIL"), Detail = ""))
mod <- list(native = "SyncroSim 3", quality = list(sources = list(1, 2), steps = list(1), logic = "Logic."), notes = "an inferred thing")
rl_review_packet(rd, dir, contents(rd), chk, data.table(Record = character(), Level = character(), Message = character()), runs, cmp, fct, mod, p, c("placeholder: Doi"), list(ReleaseStatus = "Draft", IpdsNumber = "IP-123"), file.path(rd, "release.xml"), NA_character_)
ok("the packet's files are there", all(file.exists(file.path(rd, "review", c("reviewer-summary.html", "data-review-checklist.html", "metadata-review-checklist.html", "checks.csv", "mp-report.csv", "checklist-answers.csv")))))
s <- paste(readLines(file.path(rd, "review", "reviewer-summary.html"), encoding = "UTF-8"), collapse = "\n")
ok("the summary carries the IPDS number", grepl("IP-123", s, fixed = TRUE))
ok("a difference over 10% is a limit to weigh, and one under is not", grepl("Harvest: simulated area -50%", s, fixed = TRUE) && !grepl("Urban: simulated area", s, fixed = TRUE))
ok("a Build check not passed, an inference and what is left to supply are listed", grepl("Build check not passed", s, fixed = TRUE) && grepl("an inferred thing", s, fixed = TRUE) && grepl("placeholder: Doi", s, fixed = TRUE))
ok("text is escaped in the HTML", grepl("My &lt;title&gt;", s, fixed = TRUE))
ok("the summary says one iteration is one draw", grepl("one Monte Carlo iteration", s, fixed = TRUE))
d <- paste(readLines(file.path(rd, "review", "data-review-checklist.html"), encoding = "UTF-8"), collapse = "\n"); ok("the boxes stay empty for the reviewer", !grepl("&#9745;", d, fixed = TRUE) && grepl("&#9744;", d, fixed = TRUE))
ok("review/ stays out of contents.csv", !any(startsWith(rl_contents(rd)$file, "review/")))
unlink(tmp, recursive = TRUE)
cat(sprintf("%d checks, %d failed\n", n, bad)); if (bad) quit(status = 1)
