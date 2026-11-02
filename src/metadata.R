# =============================================================================
# metadata.R - the package's metadata tables (to-do 14, Phase 1): definitions, data dictionary, input citations
# =============================================================================
# defaults/metadata/definitions.csv  Kind, Name, Definition, Source: what each state class, transition group and type, stock and flow
#                                    type and group, and stratum means. A Name ending in "*" is a pattern: it defines every name that
#                                    starts with the part before the "*", and "{*}" in its Definition is replaced by the rest of the
#                                    name. Source is a Data Sources column (or "Strata:<preset>"), the lineage source it is mapped from.
# defaults/metadata/data-dictionary.csv  File, Column, Definition, Type, Units, Domain, NullValue: every column of every file the Data
#                                    Release stage exports (<run> and <year> in a File stand for the run and year).
# defaults/metadata/citations.csv    one row per Data Sources column and strata preset: the source citation for the lineage.
#                                    "{accessed}" in a Citation is filled with the date the home's manifest says it was downloaded.
# Plain R (data.table only), so the unit tests and the stages can both use it; each reader takes the folder of the three tables.
# =============================================================================
suppressPackageStartupMessages(library(data.table))

md_read <- function(dir, f) {
  p <- file.path(dir, f); if (!file.exists(p)) stop("metadata table ", p, " is missing")
  x <- fread(p, encoding = "UTF-8", colClasses = "character", na.strings = "")
  for (j in names(x)) set(x, which(!nzchar(trimws(x[[j]]))), j, NA_character_)   # a quoted "" is blank too
  x
}
md_definitions <- function(dir) md_read(dir, "definitions.csv")
md_dictionary <- function(dir) md_read(dir, "data-dictionary.csv")
md_citations <- function(dir) md_read(dir, "citations.csv")

# Definitions of names of one kind. In order of precedence:
#   1. own: descriptions the library holds for these names (a user's own words win), when not blank
#   2. an exact row of definitions.csv
#   3. fallback: the package's stsim default descriptions, when not blank
#   4. the longest pattern row whose prefix the name starts with, "{*}" replaced by the rest of the name
# Returns a data.table: Name, Definition, Source, From ("library", "exact", "stsim", "pattern" or NA when nothing defines it).
md_define <- function(defs, kind, names, own = NULL, fallback = NULL) {
  d <- defs[Kind == kind]; ex <- d[!endsWith(Name, "*")]; pt <- d[endsWith(Name, "*")]
  pt[, Prefix := sub("[*]$", "", Name)]; pt <- pt[order(-nchar(Prefix))]
  pick <- function(x, n) if (is.null(x) || is.null(names(x)) || is.na(x[n]) || !nzchar(trimws(x[n]))) NA_character_ else unname(x[n])
  rbindlist(lapply(names, function(n) {
    v <- pick(own, n); if (!is.na(v)) return(data.table(Name = n, Definition = v, Source = NA_character_, From = "library"))
    e <- ex[Name == n]; if (nrow(e)) return(data.table(Name = n, Definition = e$Definition[1], Source = e$Source[1], From = "exact"))
    v <- pick(fallback, n); if (!is.na(v)) return(data.table(Name = n, Definition = v, Source = NA_character_, From = "stsim"))
    p <- pt[startsWith(n, Prefix)]
    if (nrow(p)) { rest <- substring(n, nchar(p$Prefix[1]) + 1)
      return(data.table(Name = n, Definition = gsub("{*}", rest, p$Definition[1], fixed = TRUE), Source = p$Source[1], From = "pattern")) }
    data.table(Name = n, Definition = NA_character_, Source = NA_character_, From = NA_character_)
  }))
}

# The dictionary rows of one exported file: a literal name ("stocks.csv") or a map ("state-class-p26-hist-2001.tif" matches
# "state-class-<run>-<year>.tif").
md_columns <- function(dict, file) {
  pat <- function(f) paste0("^", gsub("<[a-z]+>", "[^/]+", gsub(".", "[.]", f, fixed = TRUE)), "$")
  hit <- unique(dict$File)[vapply(unique(dict$File), function(f) grepl(pat(f), file), TRUE)]
  dict[File %in% hit[1]]
}
