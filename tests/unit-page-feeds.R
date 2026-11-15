# =============================================================================
# unit-page-feeds.R - every sheet a page reads from its data feed is in that feed (package.xml)
# =============================================================================
# this.DataFeed.GetDataSheet(name) returns null for a sheet outside the page's feed. A page with a second sheet needs a <dataFeed> holding both, as Studio otherwise
# closes on the first use of it (found 2026-11-03: Add a run on the Data Release page). Plain R, no SyncroSim. Usage: Rscript tests/unit-page-feeds.R
# =============================================================================
suppressPackageStartupMessages(library(xml2))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
x <- read_xml(file.path(pkg, "package.xml")); feeds <- list()
for (n in xml_find_all(x, "//dataSheet[@viewClassName]")) feeds[[sub("^lucasCoreUI[.]", "", xml_attr(n, "viewClassName"))]] <- paste0("lucasCore_", xml_attr(n, "name"))
for (n in xml_find_all(x, "//dataFeed[@viewClassName]")) feeds[[sub("^lucasCoreUI[.]", "", xml_attr(n, "viewClassName"))]] <- paste0("lucasCore_", xml_attr(xml_find_all(n, "./dataSheet"), "name"))
declared <- paste0("lucasCore_", xml_attr(xml_find_all(x, "//dataSheet[@name][not(parent::dataFeed)][not(parent::transformer)]"), "name"))
known <- c("lucasCore_CbmCrosswalk", "lucasCore_GrowthInput", "lucasCore_DecayCalibrationSetting")   # LiveTurnoverView, MatureAgeView: null falls back to package defaults, no crash
bad <- 0L; seen <- 0L
for (f in list.files(file.path(pkg, "ui"), "[.]cs$", full.names = TRUE)) {
  s <- readLines(f, warn = FALSE, encoding = "UTF-8"); txt <- paste(s, collapse = "\n")
  classes <- sub(".*class (\\w+) *:.*", "\\1", grep("class \\w+ *: *\\w*View\\b", s, value = TRUE)); classes <- intersect(classes, names(feeds)); if (!length(classes)) next
  m <- regmatches(s, gregexpr('const string (\\w+) *= *"(lucasCore_\\w+)"', s)); cn <- unlist(m); const <- setNames(sub('.*"(.*)"', "\\1", cn), sub("const string (\\w+) *=.*", "\\1", cn))
  use <- unlist(regmatches(txt, gregexpr('DataFeed[.]GetDataSheet\\(("lucasCore_\\w+"|[A-Z][A-Z_0-9]*)\\)', txt)))
  use <- sub('DataFeed[.]GetDataSheet\\("?(\\w+)"?\\)', "\\1", use); use <- as.character(ifelse(use %in% names(const), const[use], use))
  have <- unique(unlist(feeds[classes])); miss <- setdiff(use[startsWith(use, "lucasCore_")], c(have, known)); seen <- seen + length(unique(use))
  if (length(miss)) { bad <- bad + 1L; cat(sprintf("FAIL: %s reads %s, outside its feed (%s)\n", basename(f), paste(miss, collapse = ", "), paste(have, collapse = ", "))) }
  gone <- setdiff(use[startsWith(use, "lucasCore_")], declared); if (length(gone)) { bad <- bad + 1L; cat(sprintf("FAIL: %s reads undeclared %s\n", basename(f), paste(gone, collapse = ", "))) }
}
# SyncroSim's own data feed rules (SyncroSim.Core): a feed has a view class and assembly, at least two sheets, each sheet in one feed
# only, and its sheets share its data scope. Found 2026-11-14: a Natural Change feed of one sheet stopped Studio loading the package
# ("A datafeed requires at least two datasheets"); the console loads it regardless, so only this test or Studio catches it
scope <- function(n) { s <- xml_attr(n, "dataScope"); if (is.na(s)) "Scenario" else s }
defs <- xml_find_all(x, "//dataSheet[@name][not(parent::dataFeed)][not(parent::transformer)]"); def_scope <- setNames(vapply(defs, scope, ""), xml_attr(defs, "name"))
in_feed <- character()
for (n in xml_find_all(x, "//dataFeed")) {
  fn <- xml_attr(n, "name"); sh <- xml_attr(xml_find_all(n, "./dataSheet"), "name")
  if (is.na(xml_attr(n, "viewClassName")) || is.na(xml_attr(n, "viewClassAssembly"))) { bad <- bad + 1L; cat(sprintf("FAIL: feed %s has no viewClassName/viewClassAssembly\n", fn)) }
  if (length(sh) < 2) { bad <- bad + 1L; cat(sprintf("FAIL: feed %s has %d sheet (a feed needs two; put the view on the sheet instead)\n", fn, length(sh))) }
  dup <- intersect(sh, in_feed); if (length(dup)) { bad <- bad + 1L; cat(sprintf("FAIL: feed %s repeats %s, already in another feed\n", fn, paste(dup, collapse = ", "))) }
  in_feed <- c(in_feed, sh)
  fs <- scope(n); off <- sh[!is.na(def_scope[sh]) & def_scope[sh] != fs]
  if (length(off)) { bad <- bad + 1L; cat(sprintf("FAIL: feed %s (%s) holds %s of another data scope\n", fn, fs, paste(off, collapse = ", "))) }
}
cat(sprintf("%d sheet uses checked, %d files failed\n", seen, bad)); if (bad) quit(status = 1)
