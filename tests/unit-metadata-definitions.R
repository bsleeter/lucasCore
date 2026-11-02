# =============================================================================
# unit-metadata-definitions.R - the metadata tables (to-do 14, Phase 1: definitions, data dictionary, input citations)
# =============================================================================
# Plain R, no SyncroSim, no network. Checks that
#   - every name in the package's stsim lists (state classes, transition groups and types, stock and flow types and groups, primary
#     strata) and a unit of every strata preset has a definition, with no "{*}" left and no duplicate rows
#   - the precedence: a library's own description, then an exact row, then the stsim default description, then the longest pattern
#   - every Source names a Data Sources column or a strata preset, and (once citations.csv exists) every one of those has a citation
#   - the data dictionary: one row per file x column, known types, domains that name a real kind, short file names, and map names
#     match their pattern
# Usage: Rscript tests/unit-metadata-definitions.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
source(file.path(pkg, "src", "metadata.R"))
ok <- 0; bad <- 0
expect <- function(what, cond, detail = "") { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, detail, "\n") } }
md <- file.path(pkg, "defaults", "metadata"); st <- function(f) fread(file.path(pkg, "defaults", "stsim", f), encoding = "UTF-8")
defs <- md_definitions(md); dict <- md_dictionary(md)
KINDS <- c("StateClass", "TransitionGroup", "TransitionType", "StockType", "StockGroup", "FlowType", "FlowGroup", "Stratum")

# ---- definitions --------------------------------------------------------------------------------------------------------
expect("every row has a known kind", all(defs$Kind %in% KINDS), paste(setdiff(defs$Kind, KINDS), collapse = ", "))
expect("no kind x name is defined twice", !anyDuplicated(defs[, .(Kind, Name)]), paste(defs[duplicated(defs[, .(Kind, Name)]), Name], collapse = "; "))
expect("every definition has text", all(nzchar(trimws(defs$Definition))))
lists <- list(StateClass = "stsim_StateClass.csv", TransitionGroup = "stsim_TransitionGroup.csv", TransitionType = "stsim_TransitionType.csv",
              StockType = "stsim_StockType.csv", StockGroup = "stsim_StockGroup.csv", FlowType = "stsim_FlowType.csv", FlowGroup = "stsim_FlowGroup.csv",
              Stratum = "stsim_Stratum.csv")
for (k in names(lists)) {
  x <- st(lists[[k]]); fb <- if ("Description" %in% names(x)) setNames(as.character(x$Description), x$Name) else NULL
  r <- md_define(defs, k, x$Name, fallback = fb)
  miss <- r[is.na(Definition)]; left <- r[grepl("{*}", Definition, fixed = TRUE)]
  expect(sprintf("%s: all %d names defined", k, nrow(r)), !nrow(miss), paste(head(miss$Name, 8), collapse = "; "))
  expect(sprintf("%s: no {*} left", k), !nrow(left), paste(head(left$Name, 5), collapse = "; "))
}
pre <- fread(file.path(pkg, "defaults", "strata", "presets.csv"))
units <- unlist(lapply(seq_len(nrow(pre)), function(i) { f <- pre$ListFile[i]
  nm <- if (!is.na(f) && nzchar(f)) fread(file.path(pkg, "defaults", "strata", f))$Name[1] else "Example (000000)"; paste0(pre$Prefix[i], ": ", nm) }))
r <- md_define(defs, "Stratum", units)
expect(sprintf("a unit of every strata preset is defined (%d presets)", nrow(pre)), all(r$From == "pattern") && !anyNA(r$Definition), paste(r[is.na(Definition), Name], collapse = "; "))
expect("a prefixed unit takes its prefix's pattern, not the primary-stratum one", grepl("US state", md_define(defs, "Stratum", "State: Nevada")$Definition))
expect("the pattern fills in the name", grepl("Ponderosa Pine Group", md_define(defs, "StateClass", "Forest: Ponderosa Pine Group")$Definition, fixed = TRUE))

# ---- precedence ---------------------------------------------------------------------------------------------------------
n <- c("Fire", "Forest: Redwood Group", "Annual Net Emissions (CO2e)", "Water: All")
r <- md_define(defs, "TransitionGroup", "Fire", own = c(Fire = "My fire definition"))
expect("a library's own description wins", r$From == "library" && r$Definition == "My fire definition")
r <- md_define(defs, "TransitionGroup", "Fire", own = c(Fire = "  "))
expect("a blank library description does not", r$From == "exact")
r <- md_define(defs, "FlowGroup", "Annual Net Emissions (CO2e)", fallback = c(`Annual Net Emissions (CO2e)` = "Includes all gasses"))
expect("the stsim default description beats a pattern", r$From == "stsim")
r <- md_define(defs, "StockType", "Atmosphere", fallback = c(Atmosphere = "Used for baseline flows"))
expect("an exact row beats the stsim default description", r$From == "exact")
expect("a name nothing defines comes back NA", is.na(md_define(defs, "StockType", "Not A Stock")$Definition))

# ---- sources and citations ----------------------------------------------------------------------------------------------
ds <- fread(file.path(pkg, "defaults", "library", "data-sources.csv"))
keys <- ds$Column
src <- unique(na.omit(defs$Source))
expect("every Source is a Data Sources column (strata presets: their Data Download dataset)", all(src %in% keys), paste(setdiff(src, keys), collapse = ", "))
cf <- file.path(md, "citations.csv")
if (file.exists(cf)) {
  ct <- md_citations(md); need <- keys
  expect("every Data Sources column has a citation", all(need %in% ct$Column), paste(setdiff(need, ct$Column), collapse = ", "))
  expect("no citation for a column that does not exist", all(ct$Column %in% keys), paste(setdiff(ct$Column, keys), collapse = ", "))
  expect("every citation has an originator, date and title", !anyNA(ct[, .(Originator, PubDate, Title)]))
  dois <- na.omit(ct$Doi); expect("DOIs are bare 10.x/...", all(grepl("^10[.][0-9]+/", dois)), paste(dois[!grepl("^10[.][0-9]+/", dois)], collapse = ", "))
} else cat("skip: citations.csv not written yet\n")

# ---- data dictionary ----------------------------------------------------------------------------------------------------
expect("one row per file x column", !anyDuplicated(dict[, .(File, Column)]))
expect("types are integer, real or text", all(dict$Type %in% c("integer", "real", "text")))
dk <- sub("^definitions[.]csv kind ([A-Za-z]+).*$", "\\1", grep("^definitions[.]csv kind", dict$Domain, value = TRUE))
expect("every 'definitions.csv kind' domain names a kind", all(dk %in% KINDS), paste(setdiff(dk, KINDS), collapse = ", "))
expect("every amount column has units", all(nzchar(dict[grepl("^(area|carbon)", Column) | Column == "value" & Type == "real", Units])))
expect("file names (run and year filled in) are 35 characters or fewer",
       all(nchar(gsub("<year>", "2023", gsub("<run>", "hist", gsub("<group>", "biomass", dict$File)))) <= 35))
expect("a map name matches its pattern", nrow(md_columns(dict, "state-class-hist-2001.tif")) == 1 && nrow(md_columns(dict, "stocks.csv")) > 1)
expect("an unknown file matches nothing", nrow(md_columns(dict, "other.csv")) == 0)

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
